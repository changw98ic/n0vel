#!/usr/bin/env bash
# ========================================================================
# auto-team-24h.sh — 24-Hour Autonomous Multi-Agent Team
# Coordinates: Claude Code (glm-5.1) + Claude-Kimi (kimi-k2.6) + Codex (gpt-5.3-codex-spark)
# Project: novel-wirter
# ========================================================================
set -uo pipefail

# === Configuration ===
PROJECT_DIR="/Users/chengwen/dev/novel-wirter"
STATE_DIR="$PROJECT_DIR/.auto-team"
LOG_DIR="$STATE_DIR/logs"
QUEUE="$STATE_DIR/queue.json"
LOCKDIR="$STATE_DIR/queue.lock"
WORKTREE_DIR="$STATE_DIR/worktrees"
CLAUDE_KIMI_SETTINGS="$STATE_DIR/claude-kimi-settings.json"
WORK_DIR="${WORK_DIR:-$PROJECT_DIR}"
TMUX_SESSION="auto-team-24h"
CHECK_SEC=600          # 10 minutes between monitor ticks
MAX_HOURS=24
STALL_SEC=1800         # 30 minutes before task is considered stalled
MAX_ATTEMPTS=3
COOLDOWN_THRESHOLD=15      # attempts before worker goes on cooldown
COOLDOWN_SEC=3600           # 1 hour cooldown
AUTO_MERGE="${AUTO_MERGE:-0}"
WORKER_IDLE_SLEEP="${WORKER_IDLE_SLEEP:-5}"
WORKER_DONE_SLEEP="${WORKER_DONE_SLEEP:-5}"
START_STAGGER_SLEEP="${START_STAGGER_SLEEP:-1}"
AUTO_TEAM_USE_TMUX="${AUTO_TEAM_USE_TMUX:-1}"
WORKERS=(
  "claude-glm-1:implement,test"
  "claude-kimi-2:implement,test"
  "claude-kimi-3:implement,test"
  "codex-1:planner"
  "codex-2:implement,test"
  "codex-3:implement,test"
  "codex-4:implement,test"
)

# Gemini CLI is configured externally to use the local proxy via the shell environment.
CLAUDE_KIMI_BASE_URL="${CLAUDE_KIMI_BASE_URL:-https://ollama.com}"
CLAUDE_KIMI_API_KEY="${CLAUDE_KIMI_API_KEY:-baf79223bc3e4b889694dfbe7051cdf3.OKK-u5n6ciPrUvdBC0wLM0Cz}"
CLAUDE_KIMI_MODEL="${CLAUDE_KIMI_MODEL:-kimi-k2.6}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.5}"
CODEX_REASONING="${CODEX_REASONING:-xhigh}"

# Planner / optimization review
PLANNER_CYCLE_SEC=3600
OPTIMIZATION_FILE="$STATE_DIR/optimization-suggestions.md"
OPTIMIZATION_REVIEW="$STATE_DIR/optimization-review.md"

# Per-role timeouts (seconds)
TIMEOUT_IMPLEMENT=900  # 15 min idle — complex code changes
TIMEOUT_REVIEW=600      # 10 min — read-only analysis
TIMEOUT_TEST=900        # 15 min — run + fix cycle

# === Logging ===
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  mkdir -p "$LOG_DIR"
  echo "$msg" >> "$LOG_DIR/orchestrator.log"
  echo "$msg"
}

# === Heartbeat & Query IPC ===
heartbeat() {
  local agent="$1"
  local task_id="${2:-null}"
  echo "{\"ts\":$(date +%s),\"task_id\":$task_id}" > "$STATE_DIR/${agent}.heartbeat"
}

heartbeat_alive() {
  local agent="$1"
  local hb_file="$STATE_DIR/${agent}.heartbeat"
  if [ -f "$hb_file" ]; then
    local last
    last=$(jq -r '.ts' "$hb_file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    [ $((now - last)) -lt 900 ] && return 0
  fi
  pgrep -f "auto-team-24h.sh.*$agent" >/dev/null 2>&1
}

get_stall_timeout() {
  local agent="$1"
  local f="$STATE_DIR/${agent}.stall_timeout"
  if [ -f "$f" ]; then
    cat "$f"
  else
    echo "$STALL_SEC"
  fi
}

bump_stall_timeout() {
  local agent="$1"
  local current
  current=$(get_stall_timeout "$agent")
  local max_stall=$((STALL_SEC * 4))
  local new_stall=$((current * 2))
  [ "$new_stall" -gt "$max_stall" ] && new_stall="$max_stall"
  echo "$new_stall" > "$STATE_DIR/${agent}.stall_timeout"
  log "  $agent stall timeout bumped to ${new_stall}s"
}

reset_stall_timeout() {
  local agent="$1"
  rm -f "$STATE_DIR/${agent}.stall_timeout"
}

# Worker-side: check if monitor left a query, respond if so
check_query() {
  local agent="$1"
  local qfile="$STATE_DIR/${agent}.query"
  [ -f "$qfile" ] || return 0

  local task_id="null"
  if [ -f "$STATE_DIR/${agent}.heartbeat" ]; then
    task_id=$(jq -r '.task_id // null' "$STATE_DIR/${agent}.heartbeat" 2>/dev/null || echo "null")
  fi

  echo "{\"ts\":$(date +%s),\"pid\":$$,\"task_id\":$task_id}" > "$STATE_DIR/${agent}.response"
  rm -f "$qfile"
  log "  $agent responded to monitor query (task=$task_id)"
}

# Monitor-side: send a query and wait for response
# Returns 0 if response received, 1 if timeout
send_query_and_wait() {
  local agent="$1"
  local qfile="$STATE_DIR/${agent}.query"
  local rfile="$STATE_DIR/${agent}.response"
  rm -f "$rfile"
  echo "$(date +%s)" > "$qfile"
  log "  Sent query to $agent, waiting 60s for response..."

  local waited=0
  while [ "$waited" -lt 60 ]; do
    if [ -f "$rfile" ]; then
      local rcontent
      rcontent=$(cat "$rfile")
      log "  $agent responded: $rcontent"
      rm -f "$qfile" "$rfile"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  rm -f "$qfile" "$rfile"
  return 1
}

# === File Locking (mkdir-based, portable macOS/Linux) ===
lock_acquire() {
  local max_wait=30 waited=0
  while ! mkdir "$LOCKDIR" 2>/dev/null; do
    sleep 0.5
    waited=$((waited + 1))
    if [ $waited -ge $((max_wait * 2)) ]; then
      local owner_pid=""
      [ -f "$LOCKDIR/owner.pid" ] && owner_pid=$(cat "$LOCKDIR/owner.pid" 2>/dev/null || true)
      if [ -z "$owner_pid" ]; then
        log "WARNING: force-removing stale lock with no owner pid"
        rmdir "$LOCKDIR" 2>/dev/null
      elif ! kill -0 "$owner_pid" 2>/dev/null; then
        log "WARNING: force-removing stale lock owned by dead pid $owner_pid"
        rm -f "$LOCKDIR/owner.pid" 2>/dev/null
        rmdir "$LOCKDIR" 2>/dev/null
      fi
      waited=0
    fi
  done
  echo "$$" > "$LOCKDIR/owner.pid"
}
lock_release() { rm -f "$LOCKDIR/owner.pid" 2>/dev/null; rmdir "$LOCKDIR" 2>/dev/null; }

# === Queue Operations (lock-protected) ===
q_locked() {
  local filter="$1"
  shift
  mkdir -p "$STATE_DIR"
  lock_acquire
  local current updated
  current=$(cat "$QUEUE" 2>/dev/null || echo '[]')
  updated=$(echo "$current" | jq "$@" "$filter" 2>/dev/null) || { lock_release; log "ERROR: jq failed"; return 1; }
  echo "$updated" > "${QUEUE}.tmp" && mv "${QUEUE}.tmp" "$QUEUE"
  lock_release
}

q_read() {
  mkdir -p "$STATE_DIR"
  [ -f "$QUEUE" ] && cat "$QUEUE" || echo '[]'
}

q_count() {
  local status="$1"
  q_read | jq --arg status "$status" '[.[] | select(.status == $status)] | length'
}

# === Atomic Task Claim ===
# Claims the next pending task for a given agent. Returns task_id or empty.
# This is a single atomic operation under the mkdir lock — no race condition.
claim_next_task() {
  local agent="$1" allowed_roles="$2"
  mkdir -p "$STATE_DIR"
  local claimed_id=""
  lock_acquire
  local current tid
  current=$(cat "$QUEUE" 2>/dev/null || echo '[]')

  # Build jq role array from comma-separated allowed_roles
  local roles_json
  roles_json=$(echo "$allowed_roles" | jq -R 'split(",")')

  tid=$(echo "$current" | jq -r --argjson roles "$roles_json" '
    def actionable:
      (.milestone | test("^(#\\s+.*(PRD|Test Spec)|##\\s+(Commands|Concrete checks|Design verification|Documentation verification|Failure Conditions|Goal|Goals|Interaction families that must be covered|Manual verification|Manual or build verification|Notes|Pass Condition|Required Checks|Required automated coverage|Residual risks|Risks|Scope|Success Criteria|Suggested Test Layers|Test Strategy|Users|Verification Goal|Verification goals|Verification Steps|Verification targets|Visual checks)|###\\s+([0-9]+\\.\\s+.*Check|In Scope|Out Of Scope|Unit|Integration))"; "i") | not);
    [.[] | select(.status == "pending" and (.role as $r | $roles | index($r)) and actionable)]
    | .[0].id // empty
  ')

  if [ -n "$tid" ] && [ "$tid" != "null" ]; then
    local updated now_epoch baseline_sha
    now_epoch=$(date +%s)
    baseline_sha=$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || echo "")
    updated=$(echo "$current" | jq \
      --arg agent "$agent" \
      --arg baseline_sha "$baseline_sha" \
      --argjson tid "$tid" \
      --argjson now "$now_epoch" '
      map(if .id == $tid then
        .status = "in_progress"
        | .agent = $agent
        | .attempt = (.attempt + 1)
        | .started_epoch = $now
        | .baseline_sha = $baseline_sha
      else . end)
    ')
    echo "$updated" > "${QUEUE}.tmp" && mv "${QUEUE}.tmp" "$QUEUE"
    claimed_id="$tid"
  fi
  lock_release
  echo "$claimed_id"
}

complete_task() {
  local task_id="$1"
  q_locked '
    map(if .id == $task_id then
      .status = "completed"
      | .completed_epoch = $now
    else . end)
  ' --argjson task_id "$task_id" --argjson now "$(date +%s)"
}

fail_task() {
  local task_id="$1" error="$2"
  local safe_error
  safe_error=$(echo "$error" | head -1)
  q_locked '
    map(if .id == $task_id then
      .status = "failed"
      | .error = $error
    else . end)
  ' --argjson task_id "$task_id" --arg error "$safe_error"
}

reset_task() {
  local task_id="$1" error="${2:-}"
  [ -n "$error" ] && log "  reset_task $task_id: $error"
  q_locked '
    map(if .id == $task_id then
      .status = "pending"
      | .agent = null
      | .started_epoch = 0
      | .baseline_sha = null
      | .total_attempts = ((.total_attempts // 0) + 1)
    else . end)
  ' --argjson task_id "$task_id"
}

# === Plan Discovery ===
discover_plans() {
  if [ -d "$PROJECT_DIR/.omx/tasks" ] && [ -n "$(find "$PROJECT_DIR/.omx/tasks" -name "*.md" -type f 2>/dev/null)" ]; then
    find "$PROJECT_DIR/.omx/tasks" -name "*.md" -type f | sort
  else
    find "$PROJECT_DIR/docs/superpowers/plans" \
          "$PROJECT_DIR/.omx/plans" \
          -name "*.md" -type f 2>/dev/null | sort
  fi
}

extract_milestones() {
  local plan_file="$1"
  grep -E '^## (Task [0-9]+:|Integration Checkpoint|Expected Final Shape)' "$plan_file" \
    | sed 's/^## //' \
    | sed 's/\*\*//g' \
    | sed 's/`//g'
}

classify_role() {
  local text="$1"
  if echo "$text" | grep -qi "review\|audit\|inspect\|report\|lint\|health"; then
    echo "review"
  elif echo "$text" | grep -qi "test\|verify\|smoke\|check\|valid"; then
    echo "test"
  else
    echo "implement"
  fi
}

build_queue() {
  log "=== Building task queue ==="
  local tasks='[]'
  local id=0
  local plan_count=0

  while IFS= read -r plan_file; do
    [ -z "$plan_file" ] && continue
    plan_count=$((plan_count + 1))
    local plan_name
    plan_name=$(basename "$plan_file" .md)
    log "Parsing plan [$plan_count]: $plan_name"

    while IFS= read -r milestone; do
      [ -z "$milestone" ] && continue
      id=$((id + 1))
      local role
      role=$(classify_role "$milestone")

      tasks=$(echo "$tasks" | jq \
        --arg id "$id" \
        --arg plan "$plan_name" \
        --arg file "$plan_file" \
        --arg milestone "$milestone" \
        --arg role "$role" \
        '. + [{
          id: ($id | tonumber),
          plan: $plan,
          file: $file,
          milestone: $milestone,
          role: $role,
          status: "pending",
          agent: null,
          attempt: 0,
          started_epoch: 0,
          completed_epoch: 0,
          total_attempts: 0,
          error: null
        }]')
    done < <(extract_milestones "$plan_file")
  done < <(discover_plans)

  q_locked ". as \$dummy | $tasks"
  local total impl review test
  total=$(echo "$tasks" | jq length)
  impl=$(echo "$tasks" | jq '[.[] | select(.role == "implement")] | length')
  review=$(echo "$tasks" | jq '[.[] | select(.role == "review")] | length')
  test=$(echo "$tasks" | jq '[.[] | select(.role == "test")] | length')
  log "Queue ready: $total tasks (implement=$impl review=$review test=$test)"
}

# === Agent Prompt Generation ===
build_prompt() {
  local agent="$1" task_id="$2"
  local agent_type="${agent%%-*}"
  local task
  task=$(q_read | jq --argjson task_id "$task_id" '.[] | select(.id == $task_id)')
  local milestone plan_file
  milestone=$(echo "$task" | jq -r '.milestone')
  plan_file=$(echo "$task" | jq -r '.file')
  local role
  role=$(echo "$task" | jq -r '.role')
  local project_dir="$WORK_DIR"
  local plan_content=""
  if [ -f "$plan_file" ]; then
    plan_content=$(sed -n '1,260p' "$plan_file")
  fi

  case "$agent_type" in
    claude)
      cat <<PROMPT
你是 novel-wirter 项目的自动化开发 agent。

计划文件: $plan_file
当前任务: $milestone

要求:
1. 先读取计划文件，理解完整上下文和前序依赖
2. 实现当前里程碑描述的所有功能
3. 实现完成后执行: cd $project_dir && flutter analyze --no-pub && flutter test --no-pub
4. 测试通过后: git add -A && git commit -m "feat: $milestone"
5. 如果测试失败，修复后重试，最多 3 次
6. 全部完成后在最后一行输出: TASK_COMPLETE

项目目录: $project_dir
当前分支: \$(git branch --show-current)
PROMPT
      ;;
    codex)
      cat <<PROMPT
Working on the novel-wirter project at $project_dir.

Plan file: $plan_file
Task: $milestone

Instructions:
1. Read the plan file for full context
2. Implement the milestone requirements
3. Run: cd $project_dir && flutter analyze --no-pub && flutter test --no-pub
4. If tests pass, commit changes
5. If tests fail, fix and retry up to 3 times
6. Print TASK_COMPLETE when done

Project directory: $project_dir
Current branch: \$(git branch --show-current)
PROMPT
      ;;
  esac
}

# === Agent Execution ===
get_timeout() {
  local role="$1"
  case "$role" in
    implement) echo "$TIMEOUT_IMPLEMENT" ;;
    review)    echo "$TIMEOUT_REVIEW" ;;
    test)      echo "$TIMEOUT_TEST" ;;
    *)         echo "$TIMEOUT_IMPLEMENT" ;;
  esac
}

write_claude_kimi_settings() {
  mkdir -p "$STATE_DIR"
  cat > "$CLAUDE_KIMI_SETTINGS" <<JSON
{
  "env": {
    "ANTHROPIC_BASE_URL": "$CLAUDE_KIMI_BASE_URL",
    "ANTHROPIC_API_KEY": "$CLAUDE_KIMI_API_KEY",
    "ANTHROPIC_AUTH_KEY": "$CLAUDE_KIMI_API_KEY",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$CLAUDE_KIMI_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$CLAUDE_KIMI_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$CLAUDE_KIMI_MODEL",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
JSON
}

portable_timeout() {
  local timeout_sec="$1"
  shift

  if command -v gtimeout &>/dev/null; then
    gtimeout "$timeout_sec" "$@"
    return $?
  fi

  local marker
  marker=$(mktemp "${TMPDIR:-/tmp}/auto-team-timeout.XXXXXX") || return 1
  rm -f "$marker"

  "$@" &
  local cmd_pid=$!
  (
    sleep "$timeout_sec"
    if kill -0 "$cmd_pid" 2>/dev/null; then
      touch "$marker"
      kill "$cmd_pid" 2>/dev/null || true
      sleep 2
      kill -9 "$cmd_pid" 2>/dev/null || true
    fi
  ) &
  local timer_pid=$!

  wait "$cmd_pid"
  local status=$?
  kill "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true

  if [ -f "$marker" ]; then
    rm -f "$marker"
    return 124
  fi
  rm -f "$marker"
  return "$status"
}

prepare_worker_worktree() {
  local agent="$1"
  local worker_branch="${agent}-worker"
  local worker_dir="$WORKTREE_DIR/$worker_branch"

  mkdir -p "$WORKTREE_DIR"
  git -C "$PROJECT_DIR" worktree prune 2>/dev/null || true
  git -C "$PROJECT_DIR" fetch origin 2>/dev/null || true

  if [ ! -e "$worker_dir/.git" ]; then
    rm -rf "$worker_dir"
    if git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$worker_branch"; then
      if ! git -C "$PROJECT_DIR" worktree add "$worker_dir" "$worker_branch" >> "$LOG_DIR/orchestrator.log" 2>&1; then
        log "⚠️ Worker $agent failed to add existing worktree $worker_dir ($worker_branch)"
        return 1
      fi
    else
      if ! git -C "$PROJECT_DIR" worktree add -b "$worker_branch" "$worker_dir" main >> "$LOG_DIR/orchestrator.log" 2>&1; then
        log "⚠️ Worker $agent failed to create worktree $worker_dir ($worker_branch)"
        return 1
      fi
    fi
  fi

  WORK_DIR="$worker_dir"
  export WORK_DIR
  cd "$WORK_DIR" || return 1
}

cleanup_worktrees() {
  local worker
  for worker in "${WORKERS[@]}"; do
    local agent="${worker%%:*}"
    local worker_branch="${agent}-worker"
    local worker_dir="$WORKTREE_DIR/$worker_branch"
    if [ -d "$worker_dir" ]; then
      git -C "$PROJECT_DIR" worktree remove --force "$worker_dir" 2>/dev/null || rm -rf "$worker_dir"
      log "  removed worktree $worker_dir"
    fi
  done
  git -C "$PROJECT_DIR" worktree prune 2>/dev/null || true
}

run_agent() {
  local agent="$1" task_id="$2"
  local agent_type="${agent%%-*}"
  local task
  task=$(q_read | jq --argjson task_id "$task_id" '.[] | select(.id == $task_id)')
  local role
  role=$(echo "$task" | jq -r '.role')
  local timeout_sec
  timeout_sec=$(get_timeout "$role")

  local prompt
  prompt=$(build_prompt "$agent" "$task_id")
  local log_file="$LOG_DIR/${agent}-task${task_id}-$(date +%s).log"
  local exit_code=0

  log "🚀 $agent starting task $task_id (idle-timeout=${timeout_sec}s)"
  cd "$WORK_DIR" || return 1
  heartbeat "$agent"

  # Idle timeout watchdog: kill only if log file stops growing
  local idle watchdog_pid
  idle=0
  local prev_size=0
  (
    while true; do
      sleep 30
      if ! [ -f "$log_file" ]; then continue; fi
      local cur_size
      cur_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
      if [ "$cur_size" -eq "$prev_size" ]; then
        idle=$((idle + 30))
      else
        idle=0
      fi
      prev_size=$cur_size
      if [ "$idle" -ge "$timeout_sec" ]; then
        # Find and kill the agent process (child of current shell group)
        pkill -P $$ -f "claude\|codex" 2>/dev/null || true
        break
      fi
    done
  ) &
  watchdog_pid=$!

  case "$agent_type" in
    claude)
      if [[ "$agent" == claude-kimi-* ]]; then
        env \
          -u ANTHROPIC_AUTH_TOKEN \
          -u ANTHROPIC_BASE_URL \
          -u ANTHROPIC_CUSTOM_HEADERS \
          -u CLAUDE_CODE_OAUTH_TOKEN \
          ANTHROPIC_BASE_URL="$CLAUDE_KIMI_BASE_URL" \
          ANTHROPIC_AUTH_TOKEN="$CLAUDE_KIMI_API_KEY" \
          ANTHROPIC_DEFAULT_SONNET_MODEL="$CLAUDE_KIMI_MODEL" \
          CLAUDE_CODE_SIMPLE=1 \
          claude -p "$prompt" --dangerously-skip-permissions \
          > "$log_file" 2>&1 || exit_code=$?
      else
        claude -p "$prompt" --dangerously-skip-permissions \
          > "$log_file" 2>&1 || exit_code=$?
      fi
      ;;
    codex)
      codex exec -m "$CODEX_MODEL" -c "model_reasoning_effort=\"$CODEX_REASONING\"" "$prompt" \
        > "$log_file" 2>&1 || exit_code=$?
      ;;
  esac
  kill "$watchdog_pid" 2>/dev/null || true
  tail -200 "$log_file" 2>/dev/null || true

  # Record result in heartbeat
  heartbeat "$agent"
  return $exit_code
}

verify_task() {
  local task_id="$1"
  local task
  task=$(q_read | jq --argjson task_id "$task_id" '.[] | select(.id == $task_id)')
  local role
  role=$(echo "$task" | jq -r '.role')
  local baseline_sha
  baseline_sha=$(echo "$task" | jq -r '.baseline_sha // empty')

  cd "$WORK_DIR" || return 1

  # Review tasks always succeed (output is the review itself)
  [ "$role" = "review" ] && return 0

  # For implementation/test tasks:
  # Check 1: agent committed something (new commits on branch)
  local head_sha
  head_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
  if [ -n "$baseline_sha" ] && [ -n "$head_sha" ] && [ "$head_sha" != "$baseline_sha" ]; then
    log "  verify: new commit detected"
    # Check 2: flutter analyze passes (only fail on error-level issues)
    if command -v flutter &>/dev/null; then
      flutter analyze --no-pub > "$LOG_DIR/verify-task${task_id}.log" 2>&1 || true
      if grep -q " error •" "$LOG_DIR/verify-task${task_id}.log"; then
        log "  verify: flutter analyze found errors"
        return 1
      fi
    fi
    return 0
  fi

  # No new commit — check for uncommitted changes (agent might have failed to commit)
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    log "  verify: uncommitted changes found, committing"
    git add -A && git commit -m "feat: task $task_id (auto-commit)" 2>/dev/null
    return 0
  fi

  log "  verify: no changes detected"
  return 1
}

# === Worker Loop (runs in tmux window) ===
worker_loop() {
  local agent="$1"
  local allowed_roles="$2"  # e.g. "implement" or "implement,test" or "review"
  local worker_branch="${agent}-worker"

  log "🔧 Worker $agent (roles: $allowed_roles) started"

  # Create an isolated worktree per worker to avoid checkout races.
  prepare_worker_worktree "$agent" || exit 1
  log "🔧 Worker $agent in worktree: $WORK_DIR"
  log "🔧 Worker $agent on branch: $(git -C "$WORK_DIR" branch --show-current)"

  # Write PID file for monitor to track
  echo "$$" > "$STATE_DIR/${agent}.pid"

  local current_task_id="null"
  while true; do
    heartbeat "$agent" "$current_task_id"
    check_query "$agent"

    [ ! -f "$QUEUE" ] && { sleep "$CHECK_SEC"; continue; }

    # Atomically claim next task
    local task_id
    task_id=$(claim_next_task "$agent" "$allowed_roles")

    if [ -z "$task_id" ] || [ "$task_id" = "null" ]; then
      local pending in_progress
      pending=$(q_count "pending")
      in_progress=$(q_count "in_progress")
      if [ "$pending" -eq 0 ] && [ "$in_progress" -eq 0 ]; then
        log "🏁 Worker $agent: all tasks done"
        break
      fi
      sleep "$WORKER_IDLE_SLEEP"
      continue
    fi

    current_task_id="$task_id"

    # Log high attempt count for observability
    local attempts
    attempts=$(q_read | jq --argjson task_id "$task_id" '.[] | select(.id == $task_id) | .attempt')
    if [ "$attempts" -gt 3 ]; then
      log "⚠️ Task $task_id has been attempted $attempts times"
    fi

    # Cooldown: if task has been retried too many times, worker rests (claude workers exempt)
    if [ "$attempts" -ge "$COOLDOWN_THRESHOLD" ] && [[ ! "$agent" =~ ^claude-[0-9] ]]; then
      log "😴 Worker $agent: task $task_id hit ${attempts} attempts (threshold ${COOLDOWN_THRESHOLD}) — cooldown ${COOLDOWN_SEC}s"
      reset_task "$task_id" "cooldown after ${attempts} attempts"
      touch "$STATE_DIR/${agent}.cooldown"
      current_task_id="null"
      sleep "$COOLDOWN_SEC"
      rm -f "$STATE_DIR/${agent}.cooldown"
      continue
    fi

    # Execute task
    if run_agent "$agent" "$task_id"; then
      if verify_task "$task_id"; then
        complete_task "$task_id"
        log "✅ $agent completed task $task_id"
        if [ "$AUTO_MERGE" = "1" ]; then
          # Merge worker branch back to main after each successful task.
          if git -C "$PROJECT_DIR" checkout main 2>/dev/null; then
            if git -C "$PROJECT_DIR" merge "$worker_branch" --no-edit 2>/dev/null; then
              log "  merged to main"
            else
              git -C "$PROJECT_DIR" merge --abort 2>/dev/null || true
              log "  ⚠️ merge conflict merging $worker_branch to main; merge aborted"
            fi
          else
            log "  ⚠️ could not checkout main to merge $worker_branch"
          fi
        else
          log "  merge skipped (AUTO_MERGE=0)"
        fi
      else
        log "⚠️ $agent task $task_id verification failed"
        reset_task "$task_id" "verification failed"
      fi
    else
      reset_task "$task_id" "agent $agent exited with error"
      log "❌ $agent failed task $task_id, returned to pool"
    fi

    current_task_id="null"
    sleep "$WORKER_DONE_SLEEP"
  done

  log "🔧 Worker $agent stopped"
}

# === Planner Worker Loop (codex-1, hourly cycle) ===
planner_loop() {
  local agent="$1"
  local allowed_roles="test"  # planner only claims test tasks from queue

  log "📋 Planner $agent started (cycle: ${PLANNER_CYCLE_SEC}s)"

  prepare_worker_worktree "$agent" || exit 1
  log "📋 Planner $agent in worktree: $WORK_DIR"
  echo "$$" > "$STATE_DIR/${agent}.pid"

  while true; do
    heartbeat "$agent" "null"
    check_query "$agent"

    local pending in_progress
    pending=$(q_count "pending")
    in_progress=$(q_count "in_progress")

    if [ "$pending" -gt 0 ] || [ "$in_progress" -gt 0 ]; then
      # Unfinished tasks exist → claim a test task from queue
      local task_id
      task_id=$(claim_next_task "$agent" "$allowed_roles")

      if [ -n "$task_id" ] && [ "$task_id" != "null" ]; then
        log "📋 Planner $agent executing test task $task_id"
        if run_agent "$agent" "$task_id"; then
          if verify_task "$task_id"; then
            complete_task "$task_id"
            log "✅ Planner $agent completed test task $task_id"
          else
            reset_task "$task_id" "planner verification failed"
          fi
        else
          reset_task "$task_id" "planner agent exited with error"
        fi
      else
        log "📋 Planner $agent: no test tasks available, waiting"
      fi
    else
      # No unfinished tasks → run full project optimization review
      log "📋 Planner $agent: all tasks done, running optimization review"
      run_planner_review
    fi

    sleep "$PLANNER_CYCLE_SEC"
  done
}

run_planner_review() {
  local log_file="$LOG_DIR/planner-review-$(date +%s).log"
  local project_dir="$WORK_DIR"

  local prompt
  read -r -d '' prompt <<'REVIEW_PROMPT' || true
你是项目规划和优化分析专家，负责对 novel-wirter 项目进行全面检查。

请执行以下步骤：
1. 运行 `flutter analyze --no-pub` 检查代码质量，记录所有 warning 和 error
2. 运行 `flutter test --no-pub` 检查测试状态，记录失败和跳过的测试
3. 分析项目结构，检查以下方面：
   - 性能瓶颈（不必要的重建、阻塞操作、内存泄漏）
   - 代码重复（相似逻辑、可提取的公共组件）
   - 架构问题（职责不清、过度耦合、缺失的抽象）
   - 测试覆盖（缺失的测试场景、脆弱的测试）
   - 潜在 bug（空安全、边界条件、竞态条件）
4. 将分析结果写入 REVIEW_FILE，格式为 markdown：
   - 每条建议包含：问题描述、影响文件和行号、具体修复建议、优先级（高/中/低）
   - 按优先级排序，高优先级在前

最后将完整结果写入环境变量 REVIEW_FILE 指定的文件路径。
REVIEW_PROMPT

  # Substitute the review file path
  prompt="${prompt/REVIEW_FILE/$OPTIMIZATION_FILE}"

  log "📋 Planner running optimization review..."
  cd "$WORK_DIR" || return 1

  portable_timeout "$TIMEOUT_REVIEW" codex exec -m "$CODEX_MODEL" -c "model_reasoning_effort=\"$CODEX_REASONING\"" "$prompt" \
    > "$log_file" 2>&1 || true

  tail -100 "$log_file" 2>/dev/null || true

  if [ -f "$OPTIMIZATION_FILE" ] && [ -s "$OPTIMIZATION_FILE" ]; then
    log "📋 Optimization suggestions written to $OPTIMIZATION_FILE"
    # Notify kimi-5 reviewer by writing a flag file
    echo "$(date +%s)" > "$STATE_DIR/optimization-pending.flag"
  else
    log "📋 Planner review produced no suggestions"
  fi
}

# === Reviewer Worker Loop (claude-kimi-5, optimization review + normal work) ===
reviewer_worker_loop() {
  local agent="$1"
  local allowed_roles="$2"
  local worker_branch="${agent}-worker"

  log "🔍 Reviewer $agent (roles: $allowed_roles) started"

  prepare_worker_worktree "$agent" || exit 1
  log "🔍 Reviewer $agent in worktree: $WORK_DIR"
  log "🔍 Reviewer $agent on branch: $(git -C "$WORK_DIR" branch --show-current)"
  echo "$$" > "$STATE_DIR/${agent}.pid"

  local current_task_id="null"
  while true; do
    heartbeat "$agent" "$current_task_id"
    check_query "$agent"

    # Priority 1: Check if optimization review is pending
    if [ -f "$OPTIMIZATION_FILE" ] && [ -s "$OPTIMIZATION_FILE" ]; then
      log "🔍 Reviewer $agent: optimization suggestions found, starting review"
      run_optimization_review "$agent"

      # Clear the pending flag
      rm -f "$STATE_DIR/optimization-pending.flag"
      sleep "$WORKER_DONE_SLEEP"
      continue
    fi

    # Priority 2: Normal task claiming
    [ ! -f "$QUEUE" ] && { sleep "$CHECK_SEC"; continue; }

    local task_id
    task_id=$(claim_next_task "$agent" "$allowed_roles")

    if [ -z "$task_id" ] || [ "$task_id" = "null" ]; then
      local pending in_progress
      pending=$(q_count "pending")
      in_progress=$(q_count "in_progress")
      if [ "$pending" -eq 0 ] && [ "$in_progress" -eq 0 ]; then
        log "🔍 Reviewer $agent: all tasks done"
        break
      fi
      sleep "$WORKER_IDLE_SLEEP"
      continue
    fi

    current_task_id="$task_id"

    local attempts
    attempts=$(q_read | jq --argjson task_id "$task_id" '.[] | select(.id == $task_id) | .attempt')
    if [ "$attempts" -gt 3 ]; then
      log "⚠️ Task $task_id has been attempted $attempts times"
    fi

    # Cooldown: if task has been retried too many times, worker rests (claude workers exempt)
    if [ "$attempts" -ge "$COOLDOWN_THRESHOLD" ] && [[ ! "$agent" =~ ^claude-[0-9] ]]; then
      log "😴 Reviewer $agent: task $task_id hit ${attempts} attempts — cooldown ${COOLDOWN_SEC}s"
      reset_task "$task_id" "cooldown after ${attempts} attempts"
      touch "$STATE_DIR/${agent}.cooldown"
      current_task_id="null"
      sleep "$COOLDOWN_SEC"
      rm -f "$STATE_DIR/${agent}.cooldown"
      continue
    fi

    if run_agent "$agent" "$task_id"; then
      if verify_task "$task_id"; then
        complete_task "$task_id"
        log "✅ $agent completed task $task_id"
        if [ "$AUTO_MERGE" = "1" ]; then
          if git -C "$PROJECT_DIR" checkout main 2>/dev/null; then
            if git -C "$PROJECT_DIR" merge "$worker_branch" --no-edit 2>/dev/null; then
              log "  merged to main"
            else
              git -C "$PROJECT_DIR" merge --abort 2>/dev/null || true
              log "  ⚠️ merge conflict, aborted"
            fi
          fi
        else
          log "  merge skipped (AUTO_MERGE=0)"
        fi
      else
        reset_task "$task_id" "verification failed"
      fi
    else
      reset_task "$task_id" "agent $agent exited with error"
      log "❌ $agent failed task $task_id, returned to pool"
    fi

    current_task_id="null"
    sleep "$WORKER_DONE_SLEEP"
  done

  log "🔍 Reviewer $agent stopped"
}

run_optimization_review() {
  local agent="$1"
  local log_file="$LOG_DIR/${agent}-optimization-review-$(date +%s).log"
  local project_dir="$WORK_DIR"

  local suggestions
  suggestions=$(cat "$OPTIMIZATION_FILE")

  local prompt
  read -r -d '' prompt <<REVIEW_PROMPT || true
你是代码优化审核专家。规划 agent 对 novel-wirter 项目提出了以下优化建议：

--- 优化建议 START ---
$suggestions
--- 优化建议 END ---

请逐条审核这些建议：
1. 建议是否合理（是否真的是问题，还是误报）
2. 建议的修复方案是否正确和完整
3. 优先级评估是否恰当（过高还是过低）
4. 是否有遗漏的风险或副作用

将审核结果写入 $OPTIMIZATION_REVIEW，格式为 markdown：
- 对每条建议给出：通过/驳回/修改（附理由）
- 如有修改建议，给出修正后的版本
- 总结：哪些应该立即执行，哪些可以推迟
REVIEW_PROMPT

  log "🔍 $agent reviewing optimization suggestions..."

  portable_timeout "$TIMEOUT_REVIEW" env \
    -u ANTHROPIC_AUTH_TOKEN \
    -u ANTHROPIC_BASE_URL \
    -u ANTHROPIC_CUSTOM_HEADERS \
    -u CLAUDE_CODE_OAUTH_TOKEN \
    ANTHROPIC_BASE_URL="$CLAUDE_KIMI_BASE_URL" \
    ANTHROPIC_AUTH_TOKEN="$CLAUDE_KIMI_API_KEY" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$CLAUDE_KIMI_MODEL" \
    CLAUDE_CODE_SIMPLE=1 \
    claude --bare --model sonnet -p "$prompt" --dangerously-skip-permissions \
    > "$log_file" 2>&1 || true

  tail -100 "$log_file" 2>/dev/null || true

  # Consume the suggestions file after review
  rm -f "$OPTIMIZATION_FILE"

  if [ -f "$OPTIMIZATION_REVIEW" ] && [ -s "$OPTIMIZATION_REVIEW" ]; then
    log "🔍 Optimization review completed: $OPTIMIZATION_REVIEW"
  else
    log "🔍 Optimization review completed (no output file)"
  fi
}

# === Worker Respawn ===
respawn_worker() {
  local agent="$1"
  local allowed_roles="$2"

  # 1. Find and kill the worker process
  local pid=""
  if [ -f "$STATE_DIR/${agent}.pid" ]; then
    pid=$(cat "$STATE_DIR/${agent}.pid" 2>/dev/null || true)
  fi
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    pid=$(pgrep -f "auto-team-24h.sh.*$agent" 2>/dev/null || true)
  fi

  if [ -n "$pid" ]; then
    log "  Killing worker $agent (pid=$pid)"
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
    pkill -P "$pid" 2>/dev/null || true
  else
    log "  No PID found for worker $agent, proceeding to respawn"
  fi

  # 2. Reset any in-progress task assigned to this agent
  local my_task_id
  my_task_id=$(q_read | jq -r --arg agent "$agent" '
    [.[] | select(.status == "in_progress" and .agent == $agent)] | .[0].id // empty
  ')
  if [ -n "$my_task_id" ] && [ "$my_task_id" != "null" ]; then
    reset_task "$my_task_id" "worker $agent killed (stall timeout)"
    log "  Reset task $my_task_id back to pending"
  fi

  # 3. Auto-commit any uncommitted progress before reset
  local worker_branch="${agent}-worker"
  local worker_dir="$WORKTREE_DIR/$worker_branch"
  if [ -d "$worker_dir" ]; then
    cd "$worker_dir" || true
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || \
       [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
      git add -A 2>/dev/null || true
      git commit -m "wip: auto-save progress before worker reset" --allow-empty 2>/dev/null || true
      log "  Auto-committed uncommitted progress for $agent"
    fi
    git reset --hard 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    git fetch origin 2>/dev/null || true
    git rebase origin/main 2>/dev/null || { git rebase --abort 2>/dev/null || true; }
    log "  Reset worktree for $agent"
  fi
  cd "$PROJECT_DIR" || true

  # 4. Clean up stale state files
  rm -f "$STATE_DIR/${agent}.pid"
  rm -f "$STATE_DIR/${agent}.heartbeat"
  rm -f "$STATE_DIR/${agent}.query"
  rm -f "$STATE_DIR/${agent}.response"
  reset_stall_timeout "$agent"

  # 5. Recreate tmux window and respawn worker
  tmux kill-window -t "$TMUX_SESSION:$agent" 2>/dev/null || true
  sleep 1

  tmux new-window -t "$TMUX_SESSION" -n "$agent" -c "$PROJECT_DIR"

  # Determine entry point
  local entry_point="_worker"
  [ "$agent" = "codex-1" ] && entry_point="_planner"
  [ "$agent" = "claude-kimi-5" ] && entry_point="_reviewer"

  if [[ "$agent" == claude-kimi-* ]]; then
    tmux send-keys -t "$TMUX_SESSION:$agent" \
      "env -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u ANTHROPIC_CUSTOM_HEADERS -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_KIMI_BASE_URL='$CLAUDE_KIMI_BASE_URL' CLAUDE_KIMI_API_KEY='$CLAUDE_KIMI_API_KEY' CLAUDE_KIMI_MODEL='$CLAUDE_KIMI_MODEL' bash '$PROJECT_DIR/scripts/auto-team-24h.sh' $entry_point '$agent' '$allowed_roles'" Enter
  else
    tmux send-keys -t "$TMUX_SESSION:$agent" \
      "bash '$PROJECT_DIR/scripts/auto-team-24h.sh' $entry_point '$agent' '$allowed_roles'" Enter
  fi

  log "  Respawned worker $agent in tmux window"
}

# === Monitor Loop ===
monitor_loop() {
  local start_epoch
  start_epoch=$(date +%s)
  local max_seconds=$((MAX_HOURS * 3600))
  local tick=0

  log "📊 Monitor started (max ${MAX_HOURS}h, check every $((CHECK_SEC / 60))min)"

  while true; do
    local now elapsed
    now=$(date +%s)
    elapsed=$(( now - start_epoch ))
    tick=$((tick + 1))

    # Time limit
    if [ $elapsed -ge $max_seconds ]; then
      log "⏰ Time limit reached ($((elapsed / 3600))h). Stopping."
      generate_report
      cmd_stop
      return
    fi

    # Count statuses
    local pending in_progress completed failed total
    pending=$(q_count "pending")
    in_progress=$(q_count "in_progress")
    completed=$(q_count "completed")
    failed=$(q_count "failed")
    total=$((pending + in_progress + completed + failed))

    log "📊 Tick $tick | $((elapsed / 60))min elapsed | total=$total pending=$pending active=$in_progress done=$completed fail=$failed"

    # Detect stalled workers using adaptive heartbeat + query mechanism
    local now_epoch
    now_epoch=$(date +%s)

    local worker
    for worker in "${WORKERS[@]}"; do
      local agent="${worker%%:*}"
      local hb_file="$STATE_DIR/${agent}.heartbeat"
      [ -f "$hb_file" ] || continue

      local hb_ts
      hb_ts=$(jq -r '.ts' "$hb_file" 2>/dev/null || echo 0)
      local agent_stall
      agent_stall=$(get_stall_timeout "$agent")

      if [ $((now_epoch - hb_ts)) -gt "$agent_stall" ]; then
        log "⚠️ Worker $agent stalled (no heartbeat for $((now_epoch - hb_ts))s, timeout=${agent_stall}s)"

        # Get allowed roles for respawn
        local allowed_roles=""
        local w
        for w in "${WORKERS[@]}"; do
          if [ "${w%%:*}" = "$agent" ]; then
            allowed_roles="${w#*:}"
            break
          fi
        done

        # Send query, wait 60s for response
        if send_query_and_wait "$agent"; then
          # Worker is alive, double its stall timeout
          bump_stall_timeout "$agent"
        else
          # Worker is unresponsive, kill + respawn
          log "💀 Worker $agent unresponsive, killing and respawning"
          respawn_worker "$agent" "$allowed_roles"
        fi
      fi
    done

    # Check if tmux session still alive
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      log "🚨 tmux session died, stopping monitor"
      generate_report
      return
    fi

    # All done? (tasks never permanently fail — they go back to pool)
    if [ "$pending" -eq 0 ] && [ "$in_progress" -eq 0 ] && [ "$completed" -gt 0 ]; then
      log "🎉 All tasks completed!"
      log "  final merge skipped (AUTO_MERGE=0)"
      generate_report
      cmd_stop
      return
    fi

    sleep "$CHECK_SEC"
  done
}

# === Report Generation ===
generate_report() {
  local report="$STATE_DIR/report.md"
  local start_ts end_ts duration="N/A"
  start_ts=$(q_read | jq -r '[.[] | select(.started_epoch > 0) | .started_epoch] | min // 0')
  end_ts=$(q_read | jq -r '[.[] | select(.completed_epoch > 0) | .completed_epoch] | max // 0')
  if [ "$start_ts" != "0" ] && [ "$end_ts" != "0" ]; then
    duration="$(( (end_ts - start_ts) / 60 )) minutes"
  fi

  {
    echo "# Auto-Team 24H Report"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Duration: $duration"
    echo ""

    q_read | jq -r '
      "## Summary",
      "",
      "| Metric | Count |",
      "|--------|-------|",
      "| Total  | \(length) |",
      "| Completed | \([.[] | select(.status == "completed")] | length) |",
      "| Failed | \([.[] | select(.status == "failed")] | length) |",
      "| Pending | \([.[] | select(.status == "pending")] | length) |",
      "",
      "## Failed Tasks",
      "",
      (.[] | select(.status == "failed") | "- Task \(.id): \(.milestone)\n  Error: \(.error // "unknown")\n  Plan: \(.plan)"),
      "",
      "## Completed Tasks",
      "",
      (.[] | select(.status == "completed") | "- [x] Task \(.id): \(.milestone) (by \(.agent))")
    '

    echo ""
    echo "## Logs"
    echo ""
    echo "Agent logs: \`$LOG_DIR/\`"
    echo "Orchestrator log: \`$LOG_DIR/orchestrator.log\`"
    echo ""
    echo "## How to Resume"
    echo ""
    echo "\`\`\`bash"
    echo "cd $PROJECT_DIR"
    echo "./scripts/auto-team-24h.sh start  # auto-resumes from existing queue"
    echo "\`\`\`"
  } > "$report"

  log "📝 Report saved to $report"
  cat "$report"
}

# === Lifecycle Commands ===
cmd_start() {
  mkdir -p "$STATE_DIR" "$LOG_DIR"

  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    log "Session $TMUX_SESSION already running. Use '$0 stop' first."
    log "Attach with: tmux attach -t $TMUX_SESSION"
    return 1
  fi

  # Build queue (only if not resuming)
  if [ -f "$QUEUE" ]; then
    local existing_pending
    existing_pending=$(q_count "pending")
    if [ "$existing_pending" -gt 0 ]; then
      log "Found existing queue with $existing_pending pending tasks — resuming"
    else
      log "Rebuilding queue (no pending tasks in existing queue)"
      build_queue
    fi
  else
    build_queue
  fi

  # Reset any in_progress tasks from a crashed run
  local stuck
  stuck=$(q_count "in_progress")
  if [ "$stuck" -gt 0 ]; then
    log "Resetting $stuck in_progress tasks from previous run"
    q_locked 'map(if .status == "in_progress" then .status = "pending" | .agent = null | .started_epoch = 0 | .baseline_sha = null else . end)'
  fi

  local total
  total=$(q_read | jq length)
  if [ "$total" -eq 0 ]; then
    log "No tasks found. Check plan files exist."
    return 1
  fi

  if [ "$AUTO_TEAM_USE_TMUX" -eq 1 ]; then
    if ! tmux new-session -d -s "$TMUX_SESSION" -c "$PROJECT_DIR" >/dev/null 2>&1; then
      log "⚠️ Falling back to NO_TMUX mode (tmux not available in this runtime)."
      AUTO_TEAM_USE_TMUX=0
    else
      tmux kill-session -t "$TMUX_SESSION" >/dev/null 2>&1 || true
      tmux new-session -d -s "$TMUX_SESSION" -c "$PROJECT_DIR" >/dev/null 2>&1
      tmux rename-window -t "$TMUX_SESSION:0" "monitor"
    fi
  fi

  if [ "$AUTO_TEAM_USE_TMUX" -eq 0 ]; then
    log "=========================================="
    log "🚀 Team launched in background (no tmux): $TMUX_SESSION"
    log "=========================================="
    log "  Workers:  ${WORKERS[*]}"
    log "  Sleep:    idle=${WORKER_IDLE_SLEEP}s done=${WORKER_DONE_SLEEP}s"
    log "  Merge:    AUTO_MERGE=$AUTO_MERGE"
    log "------------------------------------------"
    log "  Status:   $0 status"
    log "  Stop:     $0 stop"
    log "  Report:   $0 report"
    log "------------------------------------------"
  fi

  local worker agent roles entry_point
  for worker in "${WORKERS[@]}"; do
    agent="${worker%%:*}"
    roles="${worker#*:}"

    # Determine entry point
    entry_point="_worker"
    [ "$agent" = "codex-1" ] && entry_point="_planner"
    [ "$agent" = "claude-kimi-5" ] && entry_point="_reviewer"

    if [ "$AUTO_TEAM_USE_TMUX" -eq 1 ]; then
      tmux new-window -t "$TMUX_SESSION" -n "$agent" -c "$PROJECT_DIR"
      if [[ "$agent" == claude-kimi-* ]]; then
        tmux send-keys -t "$TMUX_SESSION:$agent" \
          "env -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u ANTHROPIC_CUSTOM_HEADERS -u CLAUDE_CODE_OAUTH_TOKEN CLAUDE_KIMI_BASE_URL='$CLAUDE_KIMI_BASE_URL' CLAUDE_KIMI_API_KEY='$CLAUDE_KIMI_API_KEY' CLAUDE_KIMI_MODEL='$CLAUDE_KIMI_MODEL' bash '$PROJECT_DIR/scripts/auto-team-24h.sh' $entry_point '$agent' '$roles'" Enter
      else
        tmux send-keys -t "$TMUX_SESSION:$agent" \
          "bash '$PROJECT_DIR/scripts/auto-team-24h.sh' $entry_point '$agent' '$roles'" Enter
      fi
    else
      if [[ "$agent" == claude-kimi-* ]]; then
        env -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u ANTHROPIC_CUSTOM_HEADERS -u CLAUDE_CODE_OAUTH_TOKEN \
          CLAUDE_KIMI_BASE_URL="$CLAUDE_KIMI_BASE_URL" CLAUDE_KIMI_API_KEY="$CLAUDE_KIMI_API_KEY" CLAUDE_KIMI_MODEL="$CLAUDE_KIMI_MODEL" \
          nohup bash "$PROJECT_DIR/scripts/auto-team-24h.sh" "$entry_point" "$agent" "$roles" \
            >> "$LOG_DIR/${agent}-background.log" 2>&1 </dev/null &
      else
        nohup bash "$PROJECT_DIR/scripts/auto-team-24h.sh" "$entry_point" "$agent" "$roles" \
          >> "$LOG_DIR/${agent}-background.log" 2>&1 </dev/null &
      fi
    fi
    sleep "$START_STAGGER_SLEEP"
  done

  # Start monitor
  if [ "$AUTO_TEAM_USE_TMUX" -eq 1 ]; then
    tmux send-keys -t "$TMUX_SESSION:monitor" \
      "bash '$PROJECT_DIR/scripts/auto-team-24h.sh' _monitor" Enter

    log "=========================================="
    log "🚀 Team launched in tmux: $TMUX_SESSION"
    log "=========================================="
    log "  Workers:  ${WORKERS[*]}"
    log "  Sleep:    idle=${WORKER_IDLE_SLEEP}s done=${WORKER_DONE_SLEEP}s"
    log "  Merge:    AUTO_MERGE=$AUTO_MERGE"
    log "------------------------------------------"
    log "  Attach:   tmux attach -t $TMUX_SESSION"
    log "  Status:   $0 status"
    log "  Stop:     $0 stop"
    log "  Report:   $0 report"
    log "=========================================="
  fi
}

cmd_stop() {
  if [ "$AUTO_TEAM_USE_TMUX" -eq 1 ]; then
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      tmux kill-session -t "$TMUX_SESSION"
      log "🛑 Stopped session $TMUX_SESSION"
    else
      log "Session $TMUX_SESSION not running"
    fi
  else
    local worker
    for worker in "${WORKERS[@]}"; do
      local agent="${worker%%:*}"
      if [ -f "$STATE_DIR/${agent}.pid" ]; then
        local pid
        pid=$(cat "$STATE_DIR/${agent}.pid" 2>/dev/null || true)
        if [ -n "${pid:-}" ]; then
          kill -TERM "$pid" 2>/dev/null || true
          kill -9 "$pid" 2>/dev/null || true
        fi
      fi
      rm -f "$STATE_DIR/${agent}.pid" "$STATE_DIR/${agent}.heartbeat" "$STATE_DIR/${agent}.query" "$STATE_DIR/${agent}.response" "$STATE_DIR/${agent}.cooldown" 2>/dev/null || true
    done
    log "🛑 Stopped background workers (no tmux mode)"
  fi
  cleanup_worktrees
}

cmd_status() {
  if [ ! -f "$QUEUE" ]; then
    echo "No queue found. Run '$0 start' first."
    return 1
  fi

  echo ""
  echo "=== Auto-Team Status ==="
  echo ""

  q_read | jq -r '
    "Total:    \(. | length)",
    "Done:     \([.[] | select(.status == "completed")] | length)",
    "Active:   \([.[] | select(.status == "in_progress")] | length)",
    "Failed:   \([.[] | select(.status == "failed")] | length)",
    "Pending:  \([.[] | select(.status == "pending")] | length)",
    "",
    if ([.[] | select(.status == "in_progress")] | length) > 0 then
      "Active Tasks:",
      (.[] | select(.status == "in_progress") | "  [\(.agent)] #\(.id) \(.milestone) (attempt \(.attempt))"),
      ""
    else "" end,
    if ([.[] | select(.status == "failed")] | length) > 0 then
      "Failed Tasks:",
      (.[] | select(.status == "failed") | "  #\(.id) \(.milestone) — \(.error // "unknown")"),
      ""
    else "" end,
    "Next Up:",
    ([.[] | select(.status == "pending")] | .[:5][] | "  #\(.id) [\(.role)] \(.milestone)")
  '

  # Heartbeat status
  echo ""
  local worker
  for worker in "${WORKERS[@]}"; do
    local agent="${worker%%:*}"
    if heartbeat_alive "$agent"; then
      if [ -f "$STATE_DIR/${agent}.cooldown" ]; then
        echo "  $agent: cooldown (sleeping 1h)"
      else
        echo "  $agent: alive"
      fi
    else
      echo "  $agent: dead or not started"
    fi
  done

  echo ""
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "tmux session: RUNNING (attach: tmux attach -t $TMUX_SESSION)"
  else
    echo "tmux session: NOT RUNNING"
  fi
  echo ""
}

cmd_report() {
  if [ -f "$STATE_DIR/report.md" ]; then
    cat "$STATE_DIR/report.md"
  else
    echo "No report yet. Run '$0 start' first."
  fi
}

# === Signal Handling ===
cleanup() {
  log "Received signal, cleaning up..."
  # Don't kill tmux on signal — let it keep running
  exit 0
}
trap cleanup SIGINT SIGTERM

# === Entry Point ===
case "${1:-help}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  report)  cmd_report ;;

  _worker)    worker_loop "$2" "$3" ;;
  _planner)   planner_loop "$2" "$3" ;;
  _reviewer)  reviewer_worker_loop "$2" "$3" ;;
  _monitor)   monitor_loop ;;

  help|*)
    echo ""
    echo "auto-team-24h.sh — 24-Hour Autonomous Multi-Agent Team"
    echo ""
    echo "Usage: $0 {start|stop|status|report}"
    echo ""
    echo "  start   Build task queue from plans, launch agents in tmux"
    echo "  stop    Kill all agents and tmux session"
    echo "  status  Show task progress, agent heartbeats"
    echo "  report  Generate and show progress report"
    echo ""
    echo "Architecture:"
    echo "  tmux session: $TMUX_SESSION"
    echo "  ├── monitor       — health checks every 10 min, stalled task recovery"
    echo "  ├── claude-1/2    — implement + test (glm-5.1)"
    echo "  ├── claude-kimi-1~4 — implement + test (kimi-k2.6)"
    echo "  ├── codex-1       — hourly planner: test tasks / optimization review (gpt-5.3-codex-spark)"
    echo "  └── codex-2       — implement + test (gpt-5.3-codex-spark)"
    echo ""
    echo "Safety:"
    echo "  - Each worker uses its own git worktree and branch (<agent>-worker)"
    echo "  - Task claiming is atomic (mkdir-lock protected)"
    echo "  - Automatic merge is disabled by default (AUTO_MERGE=0)"
    echo "  - Resume support: re-run 'start' to continue unfinished queue"
    echo ""
    echo "Plans scanned:"
    echo "  $PROJECT_DIR/docs/superpowers/plans/*.md"
    echo "  $PROJECT_DIR/.omx/plans/*.md"
    echo ""
    ;;
esac
