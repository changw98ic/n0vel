# Branch And Release Workflow

This repository now uses a simple local-first Git workflow.

## Default Branch

- Default branch: `main`

## Branch Naming

Use short, purpose-first branch names:

- `feat/<topic>` for feature work
- `fix/<topic>` for bug fixes
- `docs/<topic>` for documentation-only work
- `chore/<topic>` for maintenance
- `release/<version>` for release preparation

Examples:

- `feat/local-event-log`
- `fix/project-import-overwrite-guard`
- `docs/release-workflow`
- `release/v0.1.0`

## Daily Flow

1. Start from the latest `main`
2. Create a focused branch
3. Make changes in small reviewable commits
4. Run local verification before opening or merging work
5. Merge back to `main` only after verification passes

Commands:

```bash
git checkout main
git pull --ff-only
git checkout -b feat/my-change
```

## Required Verification

Recommended local verification:

```bash
flutter analyze
flutter test
make verify-macos
```

Use `make verify-macos` before release work because it covers:

- `flutter pub get`
- `flutter analyze --no-pub`
- `flutter test --no-pub -r compact`
- `xcodebuild test`
- `flutter build macos --no-pub`

CI also runs the same macOS verification flow through:

- `.github/workflows/verify-macos.yml`

## Release Preparation

Use a release branch when preparing a versioned snapshot:

```bash
git checkout main
git pull --ff-only
git checkout -b release/v0.1.0
```

On the release branch:

1. Update version metadata if needed
2. Run full verification
3. Confirm docs and release notes are current
4. Merge or fast-forward the approved state into `main`
5. Create the release tag from `main`

Suggested commands:

```bash
git checkout main
git pull --ff-only
make verify-macos
git tag -a v0.1.0 -m "Release v0.1.0"
git show v0.1.0 --stat
```

## First Release Baseline

Until a richer release pipeline exists, treat a release as complete when all of the following are true:

- `main` is green locally
- `main` is green in GitHub Actions
- the release tag points at the verified commit
- the macOS app builds successfully from that tag

## Real Story Validation Before Release

If a release depends on story-generation behavior, save the cloud Ollama `/v1`
credentials in the local `setting.json` file before tagging:

```bash
cat > setting.json <<'EOF'
OLLAMA_API_KEY=...
OLLAMA_BASE_URL=https://ollama.com/v1
REAL_AI_MODEL=kimi-k2.6
REAL_AI_TIMEOUT_MS=180000
REAL_AI_MAX_CONCURRENT_REQUESTS=1
EOF

RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
```

Expected outcome:

- the run completes a real three-chapter generation flow
- repo-visible artifacts are written under
  `artifacts/real_validation/three_chapter_run/`
- key outputs exist for inspection:
  `chapters/chapter-01.md`, `chapters/chapter-02.md`,
  `chapters/chapter-03.md`, `reports/run-report.md`,
  `reports/artifact-index.md`, `runtime/live-status.md`
- `setting.json` is the default configuration source and `OLLAMA_*`
  environment variables remain optional overrides

## Out Of Scope

This workflow does not yet include:

- automatic version bumping
- release artifact upload
- signed macOS packaging
- changelog generation
- in-app release UI
