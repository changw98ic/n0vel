import '../tools/tool_definition.dart';

class AgentPlanningPromptBuilder {
  const AgentPlanningPromptBuilder();

  String buildPlanUserPrompt({
    required String task,
    required List<ToolDefinition> tools,
    required String workId,
  }) {
    final toolList = tools.map((t) => '- ${t.name}: ${t.description}').join('\n');
    final workContext = workId.isNotEmpty
        ? '当前作品 ID: $workId'
        : '当前没有作品上下文；如需操作具体作品，请先规划 list_works 或 create_work。';

    return '''
任务: $task

可用工具:
$toolList

$workContext

请输出一个尽可能短的执行计划，只包含完成任务所需的关键步骤。''';
  }

  String buildPlanSystemPrompt() {
    return '''
你是小说写作助手的任务规划器。
请把任务拆成最少且必要的步骤，并优先使用可用工具。
输出优先使用 JSON 数组，每项格式为:
{"step":"步骤描述","tool":"工具名或空","depends_on":[前置步骤索引]}

要求:
- `tool` 只能填写可用工具中的名称，不确定时留空
- `depends_on` 使用 0-based 索引
- 不要输出 markdown 代码块
- 如果 JSON 不方便，也可退化为编号步骤列表''';
  }

  String buildSynthesisUserPrompt({
    required String task,
    required List<String> plan,
    required List<String> observations,
  }) {
    final planText = plan.asMap().entries.map((e) => '  ${e.key + 1}. ${e.value}').join('\n');
    final obsText = observations.join('\n');

    return '''
任务: $task

执行计划:
$planText

执行结果:
$obsText''';
  }

  String buildSynthesisSystemPrompt() {
    return '''
你是小说写作助手的总结器。
请基于计划和执行结果，给出最终中文答复。
要求:
- 只保留用户需要知道的结果
- 不要虚构未完成的动作
- 若存在失败或缺失信息，明确说明影响''';
  }

  String get reflectSystemPrompt => '''
你是执行质量审查器。
请判断结果是否达标，并严格按以下三行输出：
PASS: yes 或 no
EVALUATION: 一句话评价
FEEDBACK: 若未通过，给出下一轮改进建议；若已通过，写 none''';

  String buildStepReflectionUserPrompt({
    required String stepTask,
    required String stepResult,
    required bool stepSuccess,
  }) {
    return '''
目标步骤: $stepTask
步骤是否成功: ${stepSuccess ? 'yes' : 'no'}
步骤结果:
$stepResult

请判断该步骤是否已经足以支持继续执行。''';
  }

  String buildSynthesisReflectionUserPrompt({
    required String task,
    required List<String> plan,
    required List<String> observations,
    required String synthesis,
  }) {
    final planText = plan.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final obsText = observations.join('\n');

    return '''
任务: $task

原计划:
$planText

执行结果:
$obsText

最终答复:
$synthesis

请判断最终答复是否完整、准确且与执行结果一致。''';
  }

  String buildAdditionalPlanUserPrompt({
    required String originalTask,
    required List<String> originalPlan,
    required List<String> observations,
    required String feedback,
    required List<ToolDefinition> tools,
    required String workId,
  }) {
    final toolList = tools.map((t) => '- ${t.name}: ${t.description}').join('\n');
    final completedPlan = originalPlan.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final workContext = workId.isNotEmpty ? '当前作品 ID: $workId' : '当前没有作品上下文';

    return '''
原始任务: $originalTask

已执行计划:
$completedPlan

已知结果:
${observations.join('\n')}

反思反馈:
$feedback

$workContext

可用工具:
$toolList

请只输出“还需要补做的新增步骤”，一行一个。
如果不需要新增步骤，只输出 NONE。''';
  }

  String buildAdditionalPlanSystemPrompt() {
    return '''
你是补充计划生成器。
请根据反思反馈，只产出新增的必要步骤。
要求:
- 不要重复已有步骤
- 一行一个步骤
- 如果无需新增步骤，只输出 NONE''';
  }
}
