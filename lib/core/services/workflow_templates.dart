import 'workflow_service.dart';
import 'workflow_template_batch_helpers.dart';
import 'ai/models/model_tier.dart';

/// 工作流模板库
///
/// 预定义常用写作工作流，可直接传给 [WorkflowService.run()]。
/// 每个模板是一个工厂方法，返回 [List<WorkflowNode>]，
/// 调用方只需传入小说内容、作品ID等参数即可获得完整工作流。
///
/// 节点类型说明：
/// - [AINode] — 调用AI，promptTemplate 中用 {variable} 引用上下文变量
/// - [ConditionNode] — 条件分支
/// - [ParallelNode] — 并行执行多个分支
/// - [ReviewNode] — 暂停等待人工审核
/// - [DataNode] — 对上下文执行数据处理
/// - [AgentNode] — ReAct自主循环节点
class WorkflowTemplates {
  WorkflowTemplates._();

  // ============================================================
  // 模板1：智能审稿流水线
  // ============================================================

  /// 智能审稿流水线
  ///
  /// 适用场景：对已完成章节进行全方位质量审查。
  ///
  /// 流程：
  /// 1. 设定一致性检查 — 检查世界观、时间线、力量体系等设定是否自洽
  /// 2. 角色OOC检测 — 检测角色言行是否符合已建立的性格与背景
  /// 3. AI文风检测 — 检测文本中的AI写作痕迹（"值得注意的是"等套话）
  /// 4. 审稿总结 — 综合以上三项结果生成结构化审稿报告
  /// 5. 人工审核 — 暂停供作者阅读报告并决定是否通过
  static List<WorkflowNode> reviewPipeline({
    required String chapterContent,
    required String workId,
  }) {
    return [
      AINode(
        id: 'consistency_check',
        name: '设定一致性检查',
        index: 0,
        promptTemplate: '你是一位严谨的小说设定审核专家。请检查以下小说内容中的设定一致性问题，'
            '包括但不限于：世界观规则矛盾、时间线错乱、力量体系冲突、'
            '地理/环境描述前后不一致等。\n\n'
            '请以列表形式输出发现的问题，每条包含：\n'
            '- 问题描述\n'
            '- 涉及原文段落（简要引用）\n'
            '- 修改建议\n\n'
            '如果没有发现问题，请明确说明"未发现设定一致性问题"。\n\n'
            '---\n$chapterContent\n---',
        outputVariable: 'consistency_result',
        modelTier: 'middle',
        function: AIFunction.consistencyCheck,
      ),
      AINode(
        id: 'ooc_check',
        name: '角色OOC检测',
        index: 1,
        promptTemplate: '你是一位资深的小说角色分析专家。请检测以下内容中角色行为是否符合角色设定，'
            '是否存在OOC（Out of Character）问题。\n\n'
            '请关注以下方面：\n'
            '- 角色语言风格是否与性格一致（例如：高冷角色突然话多）\n'
            '- 角色行为动机是否合理（是否符合其价值观和目标）\n'
            '- 角色之间的关系互动是否与已建立的关系一致\n'
            '- 角色能力表现是否符合设定范围\n\n'
            '请以列表形式输出，每条包含：角色名、OOC描述、原文引用、修改建议。\n\n'
            '---\n$chapterContent\n---\n\n'
            '参考（设定一致性检查结果）：\n{consistency_result}',
        outputVariable: 'ooc_result',
        modelTier: 'middle',
        function: AIFunction.oocDetection,
      ),
      AINode(
        id: 'style_check',
        name: 'AI文风检测',
        index: 2,
        promptTemplate: '你是一位AI文本检测专家。请检测以下小说内容中的AI写作痕迹。\n\n'
            '常见AI写作痕迹包括：\n'
            '- 套话与过渡语滥用（"值得注意的是"、"总而言之"、"不禁"等）\n'
            '- 情感描述过于直白和堆砌\n'
            '- 修辞手法重复单一\n'
            '- 句式结构过于工整对称\n'
            '- 描写缺乏具体细节，偏向泛泛而谈\n'
            '- 对话过于书面化，缺乏口语感\n\n'
            '请对每个检测到的AI痕迹给出：\n'
            '- 原文引用\n'
            '- 问题类型\n'
            '- 修改建议（提供更自然的写法）\n\n'
            '---\n$chapterContent\n---',
        outputVariable: 'style_result',
        modelTier: 'fast',
        function: AIFunction.aiStyleDetection,
      ),
      AINode(
        id: 'summary',
        name: '审稿总结',
        index: 3,
        promptTemplate: '你是一位小说审稿主编。请综合以下三份审稿报告，生成一份完整的审稿总结。\n\n'
            '要求：\n'
            '1. 按严重程度（高/中/低）对问题分类汇总\n'
            '2. 每个问题附带简要修改方向\n'
            '3. 给出整体质量评分（1-10）和总评语\n'
            '4. 最后给出3-5条优先修改建议\n\n'
            '=== 设定一致性检查 ===\n{consistency_result}\n\n'
            '=== 角色OOC检测 ===\n{ooc_result}\n\n'
            '=== AI文风检测 ===\n{style_result}',
        outputVariable: 'review_summary',
        modelTier: 'thinking',
        function: AIFunction.review,
      ),
      ReviewNode(
        id: 'human_review',
        name: '人工审核',
        index: 4,
        reviewVariable: 'review_summary',
        approvedVariable: 'approved',
      ),
    ];
  }

  // ============================================================
  // 模板2：章节续写+审校
  // ============================================================

  /// 章节续写+审校
  ///
  /// 适用场景：AI辅助续写章节内容，并自动进行多轮自审。
  ///
  /// 流程：
  /// 1. 续写生成 — 根据前文和写作要求生成续写内容
  /// 2. 自审 — AI对续写内容进行自我审查
  /// 3. 修改建议 — 根据自审结果生成具体修改方案
  /// 4. 人工确认 — 暂停供作者确认续写内容
  static List<WorkflowNode> continuationWithReview({
    required String previousContent,
    required String continuationRequest,
    String writingStyle = '',
    int targetWords = 2000,
  }) {
    return [
      AINode(
        id: 'continuation',
        name: '续写生成',
        index: 0,
        promptTemplate: '你是一位经验丰富的网络小说作家。请根据以下前文内容和续写要求，'
            '续写约$targetWords字的章节内容。\n\n'
            '写作要求：\n'
            '- 保持与前文一致的叙事风格和节奏\n'
            '- 自然衔接前文情节，不要重复已有内容\n'
            '- 注意场景描写、动作细节和对话的自然度\n'
            '- 避免AI写作痕迹（套话、过度修辞、对称句式等）\n'
            '${writingStyle.isNotEmpty ? "- 写作风格参考：$writingStyle\n" : ""}'
            '续写方向：$continuationRequest\n\n'
            '---前文---\n$previousContent\n---前文结束---',
        outputVariable: 'continuation_draft',
        modelTier: 'thinking',
        function: AIFunction.continuation,
      ),
      AINode(
        id: 'self_review',
        name: '续写自审',
        index: 1,
        promptTemplate: '你是一位严格的小说编辑。请审查以下AI续写内容的质量，'
            '重点关注以下方面：\n\n'
            '1. 衔接自然度：续写内容与前文的衔接是否流畅自然\n'
            '2. 情节合理性：情节发展是否合乎逻辑，有无突兀转折\n'
            '3. 角色一致性：角色言行是否符合其性格设定\n'
            '4. 文笔质量：描写是否生动具体，对话是否自然\n'
            '5. 节奏控制：叙事节奏是否得当，有无拖沓或仓促\n'
            '6. AI痕迹：是否存在明显的AI写作痕迹\n\n'
            '请对每项给出评分（1-5）和具体问题说明。\n\n'
            '---前文---\n$previousContent\n---前文结束---\n\n'
            '---续写内容---\n{continuation_draft}\n---续写结束---',
        outputVariable: 'self_review_result',
        modelTier: 'middle',
        function: AIFunction.review,
      ),
      AINode(
        id: 'revision_suggestions',
        name: '修改建议',
        index: 2,
        promptTemplate: '根据以下续写内容和自审结果，请给出具体的修改建议和修改后的段落。\n\n'
            '要求：\n'
            '- 针对自审中发现的每个问题，给出具体的修改方案\n'
            '- 对于需要重写的段落，直接提供修改后的文本\n'
            '- 保持修改后的文本与原文风格一致\n'
            '- 标注每处修改的原因\n\n'
            '---续写内容---\n{continuation_draft}\n---续写结束---\n\n'
            '---自审结果---\n{self_review_result}\n---自审结束---',
        outputVariable: 'revision_suggestions',
        modelTier: 'thinking',
        function: AIFunction.continuation,
      ),
      ReviewNode(
        id: 'human_confirm',
        name: '人工确认',
        index: 3,
        reviewVariable: 'revision_suggestions',
        approvedVariable: 'continuation_approved',
        retryNodeIndex: 0,
      ),
    ];
  }

  // ============================================================
  // 模板3：角色入场检查
  // ============================================================

  /// 角色入场检查
  ///
  /// 适用场景：在发布章节前，检查出场角色的设定一致性和关系准确性。
  ///
  /// 流程：
  /// 1. 角色识别 — 识别章节中所有出场角色
  /// 2. 逐角色设定检查 — 对每个出场角色检查设定一致性
  /// 3. 角色关系校验 — 检查角色间互动是否符合已建立的关系
  /// 4. 汇总提醒 — 生成角色相关问题汇总报告
  static List<WorkflowNode> characterEntranceCheck({
    required String chapterContent,
    required String workId,
    String characterProfiles = '',
  }) {
    return [
      AINode(
        id: 'character_identify',
        name: '出场角色识别',
        index: 0,
        promptTemplate: '请识别以下小说章节中所有出场角色（包括被提及但未直接登场的角色）。\n\n'
            '对每个角色请列出：\n'
            '- 角色名（含别名/绰号）\n'
            '- 出场类型（直接登场 / 被提及 / 背景出现）\n'
            '- 在本章节的主要行为/发言摘要\n'
            '- 与其他角色的互动列表\n\n'
            '请以JSON数组格式输出，每个元素包含 name、appearanceType、actions、interactions 字段。\n\n'
            '---\n$chapterContent\n---',
        outputVariable: 'identified_characters',
        modelTier: 'fast',
        function: AIFunction.entityExtraction,
      ),
      AINode(
        id: 'character_consistency',
        name: '角色设定一致性检查',
        index: 1,
        promptTemplate: '你是一位小说设定守护者。请根据以下角色信息和章节内容，'
            '逐一检查每个出场角色的设定一致性。\n\n'
            '检查维度：\n'
            '- 外貌描写是否与角色卡一致\n'
            '- 语言风格是否符合角色性格（如：口癖、说话方式）\n'
            '- 能力展示是否在设定范围内\n'
            '- 行为动机是否与其价值观/目标一致\n'
            '- 心理活动描写是否符合角色思维模式\n\n'
            '${characterProfiles.isNotEmpty ? "角色设定参考：\n$characterProfiles\n\n" : ""}'
            '---章节内容---\n$chapterContent\n---章节结束---\n\n'
            '---出场角色---\n{identified_characters}\n---出场角色结束---',
        outputVariable: 'character_consistency_result',
        modelTier: 'middle',
        function: AIFunction.oocDetection,
      ),
      AINode(
        id: 'relationship_check',
        name: '角色关系校验',
        index: 2,
        promptTemplate: '请检查以下章节中角色之间的关系互动是否合理。\n\n'
            '需要关注的方面：\n'
            '- 称呼是否正确（如：师徒、主从、朋友之间的称呼）\n'
            '- 态度和语气是否符合角色间的关系亲疏\n'
            '- 互动行为是否符合关系发展阶段的逻辑\n'
            '- 是否有角色间关系突然转变而无合理解释\n'
            '- 是否违反已建立的阵营/立场关系\n\n'
            '---章节内容---\n$chapterContent\n---章节结束---\n\n'
            '---出场角色---\n{identified_characters}\n---出场角色结束---\n\n'
            '参考（角色设定一致性检查结果）：\n{character_consistency_result}',
        outputVariable: 'relationship_check_result',
        modelTier: 'middle',
        function: AIFunction.consistencyCheck,
      ),
      AINode(
        id: 'entrance_summary',
        name: '角色问题汇总',
        index: 3,
        promptTemplate: '请综合以下检查结果，生成角色入场检查的汇总报告。\n\n'
            '报告要求：\n'
            '1. 按角色分组列出所有发现的问题\n'
            '2. 每个问题标注严重程度（严重/中等/轻微）\n'
            '3. 给出具体的修改建议\n'
            '4. 如有关键设定错误，在最前面以醒目标记提醒\n'
            '5. 最后给出整体角色塑造评价\n\n'
            '=== 角色设定一致性检查 ===\n{character_consistency_result}\n\n'
            '=== 角色关系校验 ===\n{relationship_check_result}',
        outputVariable: 'entrance_check_summary',
        modelTier: 'middle',
        function: AIFunction.review,
      ),
    ];
  }

  // ============================================================
  // 模板4：多章节批量审校
  // ============================================================

  /// 多章节批量审校
  ///
  /// 适用场景：对多个章节同时进行审校，利用并行处理加速。
  ///
  /// 流程：
  /// 1. 并行审校 — 每个章节独立运行审校分支（一致性 + 文风 + 角色检查）
  /// 2. 汇总报告 — 合并所有章节的审校结果，生成总报告
  ///
  /// [chapterContents] 的 key 为章节标识（如章节号或标题），value 为章节正文。
  static List<WorkflowNode> batchReview({
    required Map<String, String> chapterContents,
    required String workId,
  }) {
    // ????????????????????
    final branches =
        WorkflowTemplateBatchHelpers.buildBatchReviewBranches(chapterContents);

    // ???????prompt ????????????????????
    final chapterResultSection =
        WorkflowTemplateBatchHelpers.buildBatchResultSection(
      chapterContents.keys,
    );

    return [
      ParallelNode(
        id: 'parallel_batch_review',
        name: '并行审校全部章节',
        index: 0,
        branches: branches,
      ),
      AINode(
        id: 'batch_summary',
        name: '批量审校汇总',
        index: 1,
        promptTemplate: '请综合以下${chapterContents.length}个章节的审校结果，'
            '生成一份批量审校总报告。\n\n'
            '报告结构：\n'
            '1. 各章节质量评分一览表（表格形式）\n'
            '2. 跨章节共性问题（如有多章出现同类问题）\n'
            '3. 各章节独立问题汇总\n'
            '4. 整体改进优先级建议（按影响程度排序）\n'
            '5. 总体质量趋势评价（质量是在提升/下降/波动）\n\n'
            '各章节审校结果：\n'
            '$chapterResultSection',
        outputVariable: 'batch_review_summary',
        modelTier: 'thinking',
        function: AIFunction.review,
      ),
    ];
  }

  // ============================================================
  // 模板5：角色对话生成
  // ============================================================

  /// 角色对话生成
  ///
  /// 适用场景：为特定场景生成角色之间的对话，并自动检查语风一致性。
  ///
  /// 流程：
  /// 1. 场景分析 — 分析场景背景、角色状态和对话目的
  /// 2. 对话生成 — 根据分析结果生成符合角色性格的对话
  /// 3. 语风一致性检查 — 检查每个角色的对话风格是否与设定一致
  /// 4. 对话润色 — 根据检查结果对对话进行润色优化
  /// 5. 人工确认 — 暂停供作者确认最终对话内容
  static List<WorkflowNode> dialogueGeneration({
    required String sceneDescription,
    required String workId,
    String characterProfiles = '',
    String contextContent = '',
  }) {
    return [
      AINode(
        id: 'scene_analysis',
        name: '场景分析',
        index: 0,
        promptTemplate: '你是一位小说场景分析师。请分析以下对话场景，为对话生成做准备。\n\n'
            '分析内容：\n'
            '1. 场景环境：时间、地点、氛围\n'
            '2. 在场角色：每个角色的当前状态（情绪、目的、立场）\n'
            '3. 对话核心冲突/主题：本场对话要传达的核心信息或推进的情节\n'
            '4. 角色间张力：对话中存在的潜在冲突、隐瞒、试探等\n'
            '5. 对话节奏建议：何时快节奏交锋、何时慢节奏抒情\n\n'
            '${contextContent.isNotEmpty ? "前文上下文：\n$contextContent\n\n" : ""}'
            '场景描述：\n$sceneDescription\n\n'
            '${characterProfiles.isNotEmpty ? "角色设定参考：\n$characterProfiles\n" : ""}',
        outputVariable: 'scene_analysis_result',
        modelTier: 'middle',
        function: AIFunction.dialogue,
      ),
      AINode(
        id: 'dialogue_generate',
        name: '对话生成',
        index: 1,
        promptTemplate: '你是一位擅长写对话的小说家。请根据以下场景分析和角色设定，'
            '生成一段自然生动的角色对话。\n\n'
            '写作要求：\n'
            '- 每个角色的语言风格必须鲜明且与设定一致\n'
            '- 对话要有潜台词和张力，避免直白无味\n'
            '- 对话节奏要有变化：有短句交锋也有长段独白\n'
            '- 适当穿插动作描写和表情描写，增强画面感\n'
            '- 对话要推动情节发展或揭示角色内心\n'
            '- 避免AI套话和书面化口语\n\n'
            '---场景分析---\n{scene_analysis_result}\n---场景分析结束---\n\n'
            '${characterProfiles.isNotEmpty ? "---角色设定---\n$characterProfiles\n---角色设定结束---\n\n" : ""}'
            '场景描述：$sceneDescription',
        outputVariable: 'dialogue_draft',
        modelTier: 'thinking',
        function: AIFunction.dialogue,
      ),
      AINode(
        id: 'voice_consistency',
        name: '语风一致性检查',
        index: 2,
        promptTemplate: '请检查以下对话中每个角色的语言风格是否与角色设定一致。\n\n'
            '检查维度：\n'
            '- 用词习惯：是否使用了符合角色身份/教育的词汇\n'
            '- 句式偏好：长短句、口语化程度是否与角色性格匹配\n'
            '- 口癖/语气词：是否包含角色特有的语言习惯\n'
            '- 情感表达：表达情绪的方式是否符合角色性格\n'
            '- 知识范围：角色提及的信息是否在其应该知道的范围内\n\n'
            '请逐角色分析，指出不协调的台词并给出修改建议。\n\n'
            '${characterProfiles.isNotEmpty ? "---角色设定---\n$characterProfiles\n---角色设定结束---\n\n" : ""}'
            '---对话内容---\n{dialogue_draft}\n---对话结束---',
        outputVariable: 'voice_check_result',
        modelTier: 'middle',
        function: AIFunction.review,
      ),
      AINode(
        id: 'dialogue_polish',
        name: '对话润色',
        index: 3,
        promptTemplate: '请根据语风一致性检查的结果，对以下对话进行润色修改。\n\n'
            '润色原则：\n'
            '- 只修改有问题的部分，保留已经很好的台词\n'
            '- 修改后的台词要更加自然口语化\n'
            '- 确保每个角色的"声音"有辨识度\n'
            '- 增加必要的动作和表情描写来衬托对话\n'
            '- 保持对话的节奏感和张力\n\n'
            '---原始对话---\n{dialogue_draft}\n---原始对话结束---\n\n'
            '---语风检查结果---\n{voice_check_result}\n---语风检查结束---',
        outputVariable: 'dialogue_final',
        modelTier: 'thinking',
        function: AIFunction.dialogue,
      ),
      ReviewNode(
        id: 'dialogue_confirm',
        name: '对话确认',
        index: 4,
        reviewVariable: 'dialogue_final',
        approvedVariable: 'dialogue_approved',
        retryNodeIndex: 1,
      ),
    ];
  }

  // ============================================================
  // 模板6：设定提取流水线
  // ============================================================

  /// 设定提取流水线
  ///
  /// 适用场景：从已有文本中自动提取世界观设定，包括角色、地点、物品、事件等，
  /// 建立结构化的设定档案。适合新作品建档或补全遗漏设定。
  ///
  /// 流程：
  /// 1. 并行提取 — 同时提取角色、地点/场景、物品/道具、重要事件
  /// 2. 关系梳理 — 分析提取结果中各实体之间的关系
  /// 3. 结构化汇总 — 将所有设定整理为结构化档案
  /// 4. 人工确认 — 暂停供作者审核确认提取结果
  static List<WorkflowNode> extractionPipeline({
    required String textContent,
    required String workId,
  }) {
    return [
      ParallelNode(
        id: 'parallel_extraction',
        name: '并行提取设定',
        index: 0,
        branches: [
          AINode(
            id: 'extract_characters',
            name: '提取角色',
            index: 0,
            promptTemplate: '请从以下文本中提取所有角色信息，建立角色档案。\n\n'
                '对每个角色请提取：\n'
                '- 姓名（含别名/绰号/代号）\n'
                '- 外貌特征（从文中提到的描写中提取）\n'
                '- 性格特点（从言行中推断）\n'
                '- 能力/技能（文中展示的）\n'
                '- 身份/职业\n'
                '- 阵营/归属\n'
                '- 重要物品（角色持有或关联的）\n'
                '- 首次登场位置（章节/段落引用）\n\n'
                '请以结构化格式输出，每个角色一个条目。\n\n'
                '---\n$textContent\n---',
            outputVariable: 'extracted_characters',
            modelTier: 'middle',
            function: AIFunction.entityExtraction,
          ),
          AINode(
            id: 'extract_locations',
            name: '提取地点/场景',
            index: 1,
            promptTemplate: '请从以下文本中提取所有地点和场景信息。\n\n'
                '对每个地点/场景请提取：\n'
                '- 名称（含别称）\n'
                '- 类型（城市/自然景观/建筑/室内等）\n'
                '- 地理位置描述\n'
                '- 环境特征（气候、氛围、风格）\n'
                '- 重要事件（在该地点发生的关键剧情）\n'
                '- 关联角色（常出现在此的角色）\n\n'
                '请以结构化格式输出。\n\n'
                '---\n$textContent\n---',
            outputVariable: 'extracted_locations',
            modelTier: 'fast',
            function: AIFunction.entityExtraction,
          ),
          AINode(
            id: 'extract_items',
            name: '提取物品/道具',
            index: 2,
            promptTemplate: '请从以下文本中提取所有重要的物品和道具信息。\n\n'
                '重点关注：\n'
                '- 武器/装备（名称、属性、持有者）\n'
                '- 关键道具（推动剧情的物品）\n'
                '- 特殊物品（具有特殊能力或意义的物品）\n'
                '- 消耗品（药剂、食物等有特殊描述的）\n\n'
                '对每个物品请提取：\n'
                '- 名称（含别称）\n'
                '- 类型\n'
                '- 外观描述\n'
                '- 功能/效果\n'
                '- 当前持有者\n'
                '- 来源/获得方式\n\n'
                '请以结构化格式输出。\n\n'
                '---\n$textContent\n---',
            outputVariable: 'extracted_items',
            modelTier: 'fast',
            function: AIFunction.entityExtraction,
          ),
          AINode(
            id: 'extract_events',
            name: '提取重要事件',
            index: 3,
            promptTemplate: '请从以下文本中提取所有重要剧情事件。\n\n'
                '对每个事件请提取：\n'
                '- 事件名称（简短概括）\n'
                '- 发生时间（文本中的时间点或相对顺序）\n'
                '- 发生地点\n'
                '- 参与角色\n'
                '- 事件经过简述（100字以内）\n'
                '- 事件结果/影响\n'
                '- 伏笔/悬念（如有）\n\n'
                '请按时间顺序排列，以结构化格式输出。\n\n'
                '---\n$textContent\n---',
            outputVariable: 'extracted_events',
            modelTier: 'middle',
            function: AIFunction.extraction,
          ),
        ],
      ),
      AINode(
        id: 'relationship_analysis',
        name: '关系梳理',
        index: 1,
        promptTemplate: '请根据以下提取结果，梳理各实体之间的关系网络。\n\n'
            '请分析以下关系类型：\n'
            '- 角色之间的关系（师徒、朋友、敌对、恋人、亲属等）\n'
            '- 角色与地点的关系（居住地、势力范围等）\n'
            '- 角色与物品的关系（持有、追求、守护等）\n'
            '- 事件与角色的关系（参与者、受益者、受害者等）\n'
            '- 事件之间的因果关系\n\n'
            '请以关系图的形式描述，每条关系包含：源实体、关系类型、目标实体、关系描述。\n\n'
            '=== 角色 ===\n{extracted_characters}\n\n'
            '=== 地点 ===\n{extracted_locations}\n\n'
            '=== 物品 ===\n{extracted_items}\n\n'
            '=== 事件 ===\n{extracted_events}',
        outputVariable: 'relationships',
        modelTier: 'thinking',
        function: AIFunction.consistencyCheck,
      ),
      AINode(
        id: 'structured_summary',
        name: '结构化汇总',
        index: 2,
        promptTemplate: '请将以下所有提取和梳理结果整合为一份完整的结构化设定档案。\n\n'
            '档案格式要求：\n'
            '1. 按类别分组（角色、地点、物品、事件、关系）\n'
            '2. 每个类别内按重要性排序\n'
            '3. 标注信息的完整程度（完整/部分/待补充）\n'
            '4. 标注可能存在矛盾的信息\n'
            '5. 列出需要作者确认或补充的设定空白\n\n'
            '=== 角色提取 ===\n{extracted_characters}\n\n'
            '=== 地点提取 ===\n{extracted_locations}\n\n'
            '=== 物品提取 ===\n{extracted_items}\n\n'
            '=== 事件提取 ===\n{extracted_events}\n\n'
            '=== 关系梳理 ===\n{relationships}',
        outputVariable: 'extraction_summary',
        modelTier: 'thinking',
        function: AIFunction.extraction,
      ),
      ReviewNode(
        id: 'extraction_confirm',
        name: '设定提取确认',
        index: 3,
        reviewVariable: 'extraction_summary',
        approvedVariable: 'extraction_approved',
        retryNodeIndex: 0,
      ),
    ];
  }
}
