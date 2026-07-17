import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';

final class PurposeBuiltProductionProtocolClient implements AppLlmClient {
  var calls = 0;
  final List<String> systemPrompts = <String>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    final system = request.messages.first.content;
    final user = request.messages.last.content;
    systemPrompts.add(system);
    String text;
    if (system.contains('scene plan polisher')) {
      text = '目标：追查七号仓账本\n冲突：守门人阻拦\n推进：获得仓库编号\n约束：保持因果';
    } else if (user.contains('任务：scene_roleplay_turn')) {
      text =
          '意图：逼问\n可见动作：逼近半步\n对白：七号仓账本在哪\n'
          '内心：必须查清\n正文片段：林舟逼近半步，盯住守门人追问七号仓账本的去向。';
    } else if (user.contains('任务：scene_roleplay_arbitrate')) {
      text = '事实：守门人交代七号仓编号\n状态：调查推进\n压力：升级\n收束：是';
    } else if (system.contains('scene beat resolver')) {
      text = '[动作] 林舟封住退路\n[事实] 守门人交代七号仓编号';
    } else if (user.contains('任务：scene_stage_narration')) {
      text =
          '舞台事实：七号仓门闩已被压回原位\n'
          '环境氛围：冷雨敲击铁门，巷口车灯忽明忽暗\n'
          '可见证据：门框内侧留有新刻编号与一道新鲜划痕\n'
          '边界：仅记录公开环境和物证，不替角色作出决定';
    } else if (system.contains('scene editor') ||
        user.contains('任务：language_polish')) {
      text = purposeBuiltProductionProtocolProse();
    } else if (system.contains('scene judge review') ||
        system.contains('scene consistency review') ||
        system.contains('scene reader-flow review') ||
        system.contains('scene lexicon review')) {
      text = '决定：PASS\n原因：七号仓线索、人物动机与因果推进完整。';
    } else if (system.contains('quality scorer for Chinese novel scenes')) {
      text =
          '文笔：96\n连贯：96\n角色：96\n完整：96\n文风：96\n修辞：96\n'
          '节奏：96\n忠实：96\n综合：96\n总结：质量门通过。';
    } else {
      text = '决定：PASS\n原因：生产协议检查通过。';
    }
    return AppLlmChatResult.success(
      text: text,
      latencyMs: 5,
      promptTokens: 20,
      completionTokens: 10,
      totalTokens: 30,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class PurposeBuiltIndependentJudgeClient implements AppLlmClient {
  var calls = 0;
  final List<AppLlmChatRequest> requests = <AppLlmChatRequest>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    requests.add(request);
    return const AppLlmChatResult.success(
      text:
          '{"scores":{"proseReadability":96,"plotCausality":96},'
          '"summary":"独立盲评通过。"}',
      latencyMs: 3,
      promptTokens: 30,
      completionTokens: 12,
      totalTokens: 42,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release judge disables streaming');
}

String purposeBuiltProductionProtocolProse() =>
    agentEvaluationPurposeBuiltReleaseProse();
