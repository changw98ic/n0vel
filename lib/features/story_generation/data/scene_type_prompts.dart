import 'scene_type_classifier.dart';

/// Prompt supplements tailored to each [SceneType].
///
/// Provides director, editorial, and review prompt additions that are
/// injected alongside the base prompts to give type-specific guidance.
class SceneTypePrompts {
  const SceneTypePrompts();

  /// Director prompt supplement for the given [sceneType].
  String directorSupplement(SceneTypeResult sceneType) {
    return switch (sceneType.primaryType) {
      SceneType.dialogue => _dialogueDirector,
      SceneType.action => _actionDirector,
      SceneType.introspective => _introspectiveDirector,
      SceneType.transitional => _transitionalDirector,
      SceneType.climactic => _climacticDirector,
      SceneType.mystery => _mysteryDirector,
      SceneType.romance => _romanceDirector,
    };
  }

  /// Review criteria supplement for the given [sceneType].
  String reviewCriteria(SceneTypeResult sceneType) {
    return switch (sceneType.primaryType) {
      SceneType.dialogue => _dialogueReview,
      SceneType.action => _actionReview,
      SceneType.introspective => _introspectiveReview,
      SceneType.transitional => _transitionalReview,
      SceneType.climactic => _climacticReview,
      SceneType.mystery => _mysteryReview,
      SceneType.romance => _romanceReview,
    };
  }

  // -- Director supplements ---------------------------------------------------

  static const _dialogueDirector =
      '【对话场景指引】\n'
      '- 对话必须推动剧情或揭示角色性格，避免无意义的寒暄\n'
      '- 每个角色的语言风格应明显区分（用词、句式、语气）\n'
      '- 潜台词比直接表达更有力量——让角色说一半、藏一半\n'
      '- 对话节奏要有变化：短句交锋 + 偶尔长段独白\n'
      '- 通过动作描写打断对话，避免纯对话堆砌';

  static const _actionDirector =
      '【动作/冲突场景指引】\n'
      '- 动作描写要有画面感——使用短句、动词、感官细节\n'
      '- 节奏紧凑，每段推进冲突升级\n'
      '- 角色的行动必须符合其能力和性格\n'
      '- 穿插心理活动，避免纯机械式动作描写\n'
      '- 注意空间感和时间感，让读者不会迷失';

  static const _introspectiveDirector =
      '【内心独白场景指引】\n'
      '- 使用意识流、回忆闪回、感官触发等手法\n'
      '- 内心活动要具体——回忆画面、身体感受、联想\n'
      '- 节奏缓慢但要有推进——每个段落都应深化角色认知\n'
      '- 避免直接告诉读者角色的情感——通过细节暗示\n'
      '- 可适当使用环境描写映射内心状态';

  static const _transitionalDirector =
      '【过渡/衔接场景指引】\n'
      '- 简洁高效，快速完成时空转换\n'
      '- 用一两个感官细节锚定新环境\n'
      '- 过渡中暗示时间流逝的痕迹（季节、光线、人物变化）\n'
      '- 避免冗长的路程描写——跳跃式推进\n'
      '- 在过渡中埋入微小伏笔或情绪铺垫';

  static const _climacticDirector =
      '【高潮/转折场景指引】\n'
      '- 这是情感爆发的顶点——所有铺垫在此汇聚\n'
      '- 节奏从慢到快，推向爆发点后急停\n'
      '- 关键转折要出人意料但合乎逻辑\n'
      '- 角色在极限状态下的反应最能体现性格\n'
      '- 用感官过载描写高潮体验——声音、光线、触感全开';

  static const _mysteryDirector =
      '【悬疑/探秘场景指引】\n'
      '- 信息释放要克制——给线索但不要给答案\n'
      '- 营造不安氛围：异常的寂静、不协调的细节\n'
      '- 角色的推理过程要让读者能跟随但不一定能猜到\n'
      '- 误导和红鲱鱼要有逻辑支撑，不能硬凹\n'
      '- 每个场景至少留下一个未解的悬念钩子';

  static const _romanceDirector =
      '【情感/亲密场景指引】\n'
      '- 情感发展要有铺垫——从微小的肢体语言开始\n'
      '- 用环境氛围烘托情感（光线、声音、气味）\n'
      '- 对话要含蓄有层次——说出口的和没说出口的都重要\n'
      '- 避免过度直白的情感表达——留白比铺满更动人\n'
      '- 角色的脆弱时刻最能打动读者';

  // -- Review criteria -------------------------------------------------------

  static const _dialogueReview =
      '【对话场景审查标准】\n'
      '- 对话是否有推动力？删掉这段对话后剧情是否受损？\n'
      '- 角色声音是否可辨识？遮住名字能否分辨说话人？\n'
      '- 是否存在信息倾倒（exposition dump）？\n'
      '- 对话密度是否过高？需要更多动作/环境描写穿插？';

  static const _actionReview =
      '【动作场景审查标准】\n'
      '- 动作序列是否有画面感？读者能否在脑中放映？\n'
      '- 节奏是否紧凑？有无冗余描写拖慢速度？\n'
      '- 角色行为是否在能力范围内？\n'
      '- 空间和时间是否清晰？读者能否追踪位置？';

  static const _introspectiveReview =
      '【内心独白审查标准】\n'
      '- 是否避免了直接陈述情感（"他很伤心"）？\n'
      '- 内心活动是否具体而非抽象？\n'
      '- 是否有推进感？还是原地踏步？\n'
      '- 长度是否合适？过长的内心独白会拖慢节奏';

  static const _transitionalReview =
      '【过渡场景审查标准】\n'
      '- 是否足够简洁？能否再缩减？\n'
      '- 时空转换是否清晰？读者能否理解新场景？\n'
      '- 是否有信息浪费？过渡中是否可嵌入有用信息？';

  static const _climacticReview =
      '【高潮场景审查标准】\n'
      '- 情感爆发是否有足够的铺垫支撑？\n'
      '- 转折是否出人意料但逻辑自洽？\n'
      '- 高潮后的余波是否有留白？\n'
      '- 节奏是否从渐进推向爆发？';

  static const _mysteryReview =
      '【悬疑场景审查标准】\n'
      '- 线索释放是否适度？不是太多也不是太少？\n'
      '- 氛围是否营造到位？读者是否感到不安？\n'
      '- 角色的推理是否合理？\n'
      '- 是否留下了有效的悬念钩子？';

  static const _romanceReview =
      '【情感场景审查标准】\n'
      '- 情感发展是否有铺垫？还是突然升温？\n'
      '- 是否避免了过度直白？\n'
      '- 环境描写是否烘托了情感？\n'
      '- 角色的脆弱面是否自然展现？';
}
