import 'ai/agent/agent_service.dart';
import 'ai/models/model_tier.dart';
import 'writer_guidance_loader.dart';

/// Team 执行状态
enum TeamState {
  /// 规划中：分解任务、分配成员
  planning,

  /// 派发中：将子任务分配给成员
  dispatching,

  /// 执行中：成员并行/顺序执行
  executing,

  /// 聚合中：合并成员产出
  aggregating,

  /// 校验中：最终审查
  verifying,

  /// 完成
  completed,

  /// 失败
  failed,
}

/// 成员角色定义
class TeamMember {
  final String name;
  final String agentId;
  final String roleDescription;

  const TeamMember({
    required this.name,
    required this.agentId,
    required this.roleDescription,
  });
}

/// 成员产出物
class MemberArtifact {
  final String memberName;
  final String content;
  final bool success;
  final String? error;

  const MemberArtifact({
    required this.memberName,
    required this.content,
    required this.success,
    this.error,
  });
}

/// Team 执行计划
class TeamPlan {
  final String objective;
  final List<TeamMember> members;
  final List<TeamSubTask> subTasks;
  final String verifierAgentId;

  const TeamPlan({
    required this.objective,
    required this.members,
    required this.subTasks,
    required this.verifierAgentId,
  });
}

/// 子任务
class TeamSubTask {
  final String id;
  final String description;
  final String assignee;
  final AIFunction function;
  final ModelTier tier;
  final List<String> dependsOn;

  const TeamSubTask({
    required this.id,
    required this.description,
    required this.assignee,
    this.function = AIFunction.chat,
    this.tier = ModelTier.middle,
    this.dependsOn = const [],
  });
}

/// Team 执行上下文（状态机持有）
class TeamExecutionContext {
  final String teamId;
  final TeamPlan plan;
  TeamState state;
  final Map<String, MemberArtifact> artifacts;
  String? verifierResult;
  String? errorMessage;

  TeamExecutionContext({
    required this.teamId,
    required this.plan,
    this.state = TeamState.planning,
    Map<String, MemberArtifact>? artifacts,
  }) : artifacts = artifacts ?? {};
}

/// Team 状态机
/// 管理 team 执行全流程：plan → dispatch → execute → aggregate → verify → complete
class TeamStateMachine {
  final AgentService _agentService;
  final WriterGuidanceLoader _guidanceLoader;

  TeamStateMachine({
    required AgentService agentService,
    WriterGuidanceLoader? guidanceLoader,
  })  : _agentService = agentService,
        _guidanceLoader = guidanceLoader ?? WriterGuidanceLoader();

  /// 执行完整 team 流程
  Future<TeamExecutionContext> execute(TeamExecutionContext ctx) async {
    try {
      // Phase 1: Planning
      ctx.state = TeamState.planning;
      final teamGuidance = await _guidanceLoader.loadTeamGuidance(ctx.teamId);

      // Phase 2: Dispatching
      ctx.state = TeamState.dispatching;

      // Phase 3: Executing — 按依赖拓扑执行子任务
      ctx.state = TeamState.executing;
      final completed = <String>{};
      for (var round = 0; round < ctx.plan.subTasks.length; round++) {
        var progressed = false;
        for (final task in ctx.plan.subTasks) {
          if (completed.contains(task.id) || ctx.artifacts.containsKey(task.id)) {
            continue;
          }
          // 检查依赖是否全部完成
          if (!task.dependsOn.every(completed.contains)) {
            continue;
          }

          // 构造 prompt，注入前序产出
          final prompt = _buildTaskPrompt(task, ctx.artifacts, teamGuidance);

          final response = await _agentService.orchestrate(
            task: prompt,
            function: task.function,
            tier: task.tier,
            systemPrompt: _buildSystemPrompt(task, teamGuidance),
          );

          ctx.artifacts[task.id] = MemberArtifact(
            memberName: task.assignee,
            content: response.content,
            success: true,
          );
          completed.add(task.id);
          progressed = true;
        }

        if (!progressed && completed.length < ctx.plan.subTasks.length) {
          ctx.state = TeamState.failed;
          ctx.errorMessage = '存在无法满足的依赖关系，任务无法继续。';
          return ctx;
        }
        if (completed.length >= ctx.plan.subTasks.length) break;
      }

      // Phase 4: Aggregating
      ctx.state = TeamState.aggregating;

      // Phase 5: Verifying
      ctx.state = TeamState.verifying;
      if (ctx.plan.verifierAgentId.isNotEmpty) {
        final verificationPrompt = _buildVerificationPrompt(ctx);
        final verificationResponse = await _agentService.orchestrate(
          task: verificationPrompt,
          function: AIFunction.review,
          tier: ModelTier.middle,
        );
        ctx.verifierResult = verificationResponse.content;
      }

      // Phase 6: Completed
      ctx.state = TeamState.completed;
      return ctx;
    } catch (e) {
      ctx.state = TeamState.failed;
      ctx.errorMessage = 'Team 执行失败: $e';
      return ctx;
    }
  }

  /// 构造子任务 prompt
  String _buildTaskPrompt(
    TeamSubTask task,
    Map<String, MemberArtifact> artifacts,
    String teamGuidance,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('## 任务');
    buffer.writeln(task.description);
    buffer.writeln();

    // 注入依赖产出
    if (task.dependsOn.isNotEmpty) {
      buffer.writeln('## 前序产出');
      for (final depId in task.dependsOn) {
        final artifact = artifacts[depId];
        if (artifact != null) {
          buffer.writeln('### $depId (${artifact.memberName})');
          buffer.writeln(artifact.content);
          buffer.writeln();
        }
      }
    }

    return buffer.toString();
  }

  /// 构造 system prompt
  String? _buildSystemPrompt(TeamSubTask task, String teamGuidance) {
    final parts = <String>[];
    parts.add('你是团队中的 ${task.assignee}，负责完成指定任务。');
    if (teamGuidance.trim().isNotEmpty) {
      parts.add(teamGuidance.trim());
    }
    return parts.join('\n\n');
  }

  /// 构造校验 prompt
  String _buildVerificationPrompt(TeamExecutionContext ctx) {
    final buffer = StringBuffer();
    buffer.writeln('请校验以下团队产出的质量和一致性：');
    buffer.writeln();
    buffer.writeln('## 目标');
    buffer.writeln(ctx.plan.objective);
    buffer.writeln();
    buffer.writeln('## 成员产出');
    for (final entry in ctx.artifacts.entries) {
      buffer.writeln('### ${entry.key} (${entry.value.memberName})');
      buffer.writeln(entry.value.content);
      buffer.writeln();
    }
    buffer.writeln('请检查：');
    buffer.writeln('1. 各部分内容是否完整，没有占位内容');
    buffer.writeln('2. 风格和用词是否一致');
    buffer.writeln('3. 角色行为是否前后一致（无 OOC）');
    buffer.writeln('4. 剧情逻辑是否连贯');
    return buffer.toString();
  }

  // ── 预定义 Team Plan 工厂 ──

  /// 长篇小说团队计划
  static TeamPlan longformBookPlan({
    required String bookTitle,
    required String genre,
    required int chapterCount,
  }) {
    return TeamPlan(
      objective: '创建长篇小说《$bookTitle》，$genre 类型，共 $chapterCount 章',
      members: const [
        TeamMember(name: 'planner', agentId: 'planner-agent', roleDescription: '规划大纲和章节结构'),
        TeamMember(name: 'writer', agentId: 'writer-agent', roleDescription: '撰写章节正文'),
        TeamMember(name: 'reviewer', agentId: 'reviewer-agent', roleDescription: '审查质量和一致性'),
      ],
      subTasks: [
        TeamSubTask(
          id: 'outline',
          description: '为《$bookTitle》创建 $chapterCount 章的大纲，包含每章主要事件、角色出场和节奏定位。',
          assignee: 'planner',
          function: AIFunction.planning,
          tier: ModelTier.thinking,
        ),
        TeamSubTask(
          id: 'chapters',
          description: '根据大纲，逐章撰写《$bookTitle》的完整正文，每章 2000-3000 字。',
          assignee: 'writer',
          function: AIFunction.entityCreation,
          tier: ModelTier.thinking,
          dependsOn: ['outline'],
        ),
        TeamSubTask(
          id: 'review',
          description: '审查全部章节的一致性、节奏和可读性，提出改进建议。',
          assignee: 'reviewer',
          function: AIFunction.review,
          tier: ModelTier.middle,
          dependsOn: ['chapters'],
        ),
      ],
      verifierAgentId: 'reviewer-agent',
    );
  }

  /// 审查团队计划
  static TeamPlan reviewPlan({required String contentDescription}) {
    return TeamPlan(
      objective: '多角度审查：$contentDescription',
      members: const [
        TeamMember(name: 'extractor', agentId: 'extractor-agent', roleDescription: '提取设定和角色信息'),
        TeamMember(name: 'reviewer', agentId: 'reviewer-agent', roleDescription: '审查内容质量'),
      ],
      subTasks: [
        TeamSubTask(
          id: 'extract',
          description: '从内容中提取角色、地点、物品等设定信息，建立设定基线。',
          assignee: 'extractor',
          function: AIFunction.extraction,
          tier: ModelTier.middle,
        ),
        TeamSubTask(
          id: 'review',
          description: '基于提取的设定基线，审查内容的一致性、逻辑和节奏。',
          assignee: 'reviewer',
          function: AIFunction.review,
          tier: ModelTier.middle,
          dependsOn: ['extract'],
        ),
      ],
      verifierAgentId: 'reviewer-agent',
    );
  }
}
