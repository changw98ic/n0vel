import '../domain/scene_models.dart';
import 'evaluation/agent_evaluation_failure_taxonomy.dart';

enum QualityRepairCategory {
  causalTransition,
  characterMotivation,
  prose,
  style,
  imagery,
  rhythm,
  faithfulness,
  coherence,
  character,
  completeness,
}

/// Frozen mapping from an independent quality score to an actionable rewrite
/// contract. The repair model receives concrete edit operations instead of a
/// generic request to "make the scene better".
abstract final class QualityRepairPolicy {
  static const releaseId = 'quality-targeted-repair-v3';

  static String feedbackFor(SceneQualityScore score) {
    final summary = score.summary.trim();
    final categories = <QualityRepairCategory>{
      if (score.prose < 95) QualityRepairCategory.prose,
      if (score.styleScore < 95) QualityRepairCategory.style,
      if (score.imageryScore < 95) QualityRepairCategory.imagery,
      if (score.rhythmScore < 95) QualityRepairCategory.rhythm,
      if (score.faithfulnessScore < 95) QualityRepairCategory.faithfulness,
      if (score.coherence < 95) QualityRepairCategory.coherence,
      if (score.character < 95) QualityRepairCategory.character,
      if (score.completeness < 95) QualityRepairCategory.completeness,
    };
    if (_containsAny(summary, const [
      '转折',
      '临界',
      '动机',
      '说服',
      '坍缩',
      '被迫',
      '选择',
      '偏软',
      '落地',
    ])) {
      categories
        ..add(QualityRepairCategory.causalTransition)
        ..add(QualityRepairCategory.characterMotivation);
    }
    final failureCodes = <String>{
      if (score.coherence < 95 ||
          _containsAny(summary, const ['转折', '因果', '触发', '跳转']))
        'quality.causal_gap',
      if (score.character < 95) 'character.voice_or_knowledge',
      if (score.faithfulnessScore < 95) 'quality.faithfulness_gap',
      if (score.completeness < 95) 'planner.missing_required_beat',
      if (_containsAny(summary, const ['重复', '复述', '同义反复']))
        'quality.repetition',
      if (_containsAny(summary, const ['说明式对白', '解释性对白', '信息倾倒']))
        'quality.expository_dialogue',
    };
    final repairPlan = failureCodes.isEmpty
        ? null
        : AgentEvaluationFailureTaxonomy.repairPlanFor(
            AgentEvaluationFailureTaxonomy.classify(failureCodes),
          );

    const causalTransitionDirective =
        '在人物由抵抗转为选择的位置补齐连续因果链：新证据或压力 → 仍然抵抗并暴露代价 → '
        '明确触发点 → 可见反应 → 不可逆的选择或行动。至少补一句把人物推过临界点的对白，'
        '并立刻写出该选择造成的后果；禁止用“他终于被说服了”一类叙述直接跳过转折。';
    final directives = <String>[
      if (categories.contains(QualityRepairCategory.causalTransition))
        causalTransitionDirective,
      if (categories.contains(QualityRepairCategory.characterMotivation))
        '人物改变立场前必须让读者看见其风险、损失或欲望被击中；行动必须由该动机触发，不能只因作者需要而发生。',
      if (categories.contains(QualityRepairCategory.coherence))
        '逐段检查“因为上一动作/信息，所以角色采取下一行动”；补缺失的触发动作，删除没有前因的跳转。',
      if (categories.contains(QualityRepairCategory.completeness))
        '把本场目标写成可观察的落地结果：角色实际交出、说出、打开、带路或拒绝，并让结尾压力由该结果产生。',
      if (categories.contains(QualityRepairCategory.character))
        '保持既定谈判位势和角色语言；弱势方只能在具体压力下让步，不能无因取得主导或突然合作。',
      if (categories.contains(QualityRepairCategory.prose))
        '用动作、物件状态和对白反应替换抽象心理解释；每个新增句子必须推进事实、选择、关系或压力。',
      if (categories.contains(QualityRepairCategory.style))
        '遵守项目文风与视角边界；删除不属于当前叙述声音的词汇、时代错位表达和泛化的 AI 腔。',
      if (categories.contains(QualityRepairCategory.imagery))
        '逐个检查比喻和拟人：必须服务当前 POV、感官和动作；删除混喻、陈词滥调、无指向的华丽修辞。',
      if (categories.contains(QualityRepairCategory.rhythm))
        '调整句长、段落和对白间隔；删除连续同构句与解释堆叠，让每段产生新的动作、信息或压力。',
      if (categories.contains(QualityRepairCategory.faithfulness))
        '逐句回溯场景概要、已接受节拍、角色知识和世界事实；删除无依据的新事实，修正时间、地点、人物知道范围的矛盾。',
    ];

    final frozenRepair = repairPlan == null
        ? ''
        : '失败分类=${repairPlan.primaryCode}；taxonomy='
              '${repairPlan.taxonomyReleaseHash}；repairPolicy='
              '${repairPlan.repairPolicyId}；最多${repairPlan.maxAttempts}次；'
              '只允许修改=${repairPlan.allowedScopes.join(',')}；'
              '必须重验=${repairPlan.revalidationStages.join(',')}；'
              'repairPlanHash=${repairPlan.planHash}。\n';
    return '【质量定向修订协议：$releaseId】上一版不得进入候选。'
        '综合${score.overall}（需≥95），文笔${score.prose}、连贯${score.coherence}、'
        '角色${score.character}、完整${score.completeness}、文风${score.styleScore}、'
        '修辞${score.imageryScore}、节奏${score.rhythmScore}、忠实${score.faithfulnessScore}（每项需≥90）。'
        '独立评分意见：$summary\n'
        '$frozenRepair'
        '只重写评分指出的弱段并输出一份完整正文；保留已通过的事实、角色关系、对白轮数和硬门，'
        '不要全面换故事，也不要只替换同义词。\n'
        '${directives.map((value) => '• $value').join('\n')}\n'
        '交稿前核对：修订位置必须形成新的可见动作/对白/后果，且不得引入新事实冲突。';
  }

  static bool _containsAny(String source, List<String> needles) =>
      needles.any(source.contains);
}
