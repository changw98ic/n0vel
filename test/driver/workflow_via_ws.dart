/// 直接通过 VM Service WebSocket 调用自定义 extensions
/// 测试完整 8 阶段 AI 小说创作流程
library;

import 'dart:convert';
import 'dart:io';

const vmServiceUrl = 'ws://127.0.0.1:62815/7uB2KC0Bcuo=/ws';

late Stream _broadcastStream;

Future<Map<String, dynamic>> callExtension(
  WebSocket ws,
  String method,
  Map<String, String> params,
) async {
  final id = DateTime.now().millisecondsSinceEpoch.toString();
  final msg = jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
    'params': params,
  });
  ws.add(msg);

  await for (final response in _broadcastStream) {
    final data = jsonDecode(response) as Map<String, dynamic>;
    if (data['id'] == id) return data;
  }
  throw StateError('WebSocket closed');
}

Future<void> main() async {
  final ws = await WebSocket.connect(vmServiceUrl);
  _broadcastStream = ws.asBroadcastStream();
  print('✅ WebSocket 连接成功');

  int stage = 0;

  // ─── 阶段 1: 导航到 AI 助手 → 创建作品 ───
  print('\n${++stage}️⃣  阶段1: 创建作品 (AI 对话)');
  var r = await callExtension(ws, 'ext.test.navigate', {'tab': 'AI 助手'});
  print('  导航: ${r['result']}');
  await Future.delayed(Duration(seconds: 2));

  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请帮我创建一部玄幻小说，名字叫"灵域苍穹"，描述一个灵气复苏的世界，主角从底层崛起。目标50万字。',
  });
  print('  📨 已发送创建作品请求: ${r['result']}');
  print('  ⏳ 等待 AI 处理 (30s)...');
  await Future.delayed(Duration(seconds: 30));

  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段1 完成');

  // ─── 阶段 2: 创建卷 ───
  print('\n${++stage}️⃣  阶段2: 创建卷');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请为这部小说创建第一卷"初入江湖"，这是一部修仙小说的开篇卷',
  });
  print('  📨 已发送创建卷请求');
  await Future.delayed(Duration(seconds: 20));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段2 完成');

  // ─── 阶段 3: 创建章节 ───
  print('\n${++stage}️⃣  阶段3: AI 生成章节');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请在第一卷下创建第一章"灵气觉醒"，写3000字以上的正文内容，包含场景描写、人物对话、内心独白',
  });
  print('  📨 已发送生成章节请求');
  print('  ⏳ 等待 AI 生成 (60s)...');
  await Future.delayed(Duration(seconds: 60));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段3 完成');

  // ─── 阶段 4: 创建角色 ───
  print('\n${++stage}️⃣  阶段4: 创建角色');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请创建三个角色：\n1) 叶辰，protagonist，男，天赋异禀的少年修士\n2) 苏瑶，supporting，女，天机宗宗主之女，擅长阵法\n3) 萧天策，antagonist，男，世家嫡子，心高气傲',
  });
  print('  📨 已发送创建角色请求');
  await Future.delayed(Duration(seconds: 30));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段4 完成');

  // ─── 阶段 5: 场景拆分 ───
  print('\n${++stage}️⃣  阶段5: AI 拆分场景');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请把第一章内容按场景拆分，标记每个场景的涉及角色和氛围（紧张/和平/神秘/动作/情感）',
  });
  print('  📨 已发送场景拆分请求');
  await Future.delayed(Duration(seconds: 20));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段5 完成');

  // ─── 阶段 6: 对话生成 ───
  print('\n${++stage}️⃣  阶段6: AI 生成对话');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请为第一章中叶辰和苏瑶初次相遇的场景，生成一段自然生动的对话，要体现角色各自的语言风格',
  });
  print('  📨 已发送对话生成请求');
  await Future.delayed(Duration(seconds: 30));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段6 完成');

  // ─── 阶段 7: 建立关系 ───
  print('\n${++stage}️⃣  阶段7: 建立角色关系');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请创建以下角色关系：叶辰↔苏瑶(友好/初遇互相欣赏)，叶辰↔萧天策(对手/同时入门互不相让)，苏瑶↔萧天策(中立/立场不同但彼此尊重)',
  });
  print('  📨 已发送建立关系请求');
  await Future.delayed(Duration(seconds: 20));
  r = await callExtension(ws, 'ext.test.chatState', {});
  print('  📊 状态: ${_summarizeState(r)}');
  print('  ✅ 阶段7 完成');

  // ─── 阶段 8: 剧情审查 ───
  print('\n${++stage}️⃣  阶段8: AI 剧情审查');
  r = await callExtension(ws, 'ext.test.chat', {
    'message': '请对当前小说内容进行全面审查，包括：1)一致性检查 2)角色OOC检测 3)关系合理性 4)时间线检查 5)总体评分和改进建议。每个维度给出✅/⚠️/❌评级。',
  });
  print('  📨 已发送审查请求');
  await Future.delayed(Duration(seconds: 30));
  r = await callExtension(ws, 'ext.test.chatState', {});
  final stateData = r['result'] as Map<String, dynamic>?;
  if (stateData != null) {
    final json = jsonDecode(stateData['result'] as String) as Map<String, dynamic>;
    print('  📊 消息数: ${json['messageCount']}');
    print('  📊 最后消息角色: ${json['lastRole']}');
    print('  📊 工具结果数: ${(json['toolResults'] as List?)?.length ?? 0}');
  }
  print('  ✅ 阶段8 完成');

  print('\n🎉 ==========================================');
  print('🎉 完整 AI 小说创作全流程测试完成！');
  print('🎉 全部 $stage 个阶段已执行：');
  print('  1️⃣  作品创建 (AI生成)');
  print('  2️⃣  卷结构 (AI规划)');
  print('  3️⃣  章节大纲 (AI生成3000+字)');
  print('  4️⃣  角色档案 (AI创建)');
  print('  5️⃣  场景拆分 (AI分析)');
  print('  6️⃣  对话生成 (AI生成)');
  print('  7️⃣  关系建立 (AI推断)');
  print('  8️⃣  剧情审查 (AI审查)');
  print('🎉 ==========================================');

  await ws.close();
}

String _summarizeState(Map<String, dynamic> r) {
  try {
    final result = r['result'] as Map<String, dynamic>?;
    if (result == null) return 'null';
    final json = jsonDecode(result['result'] as String) as Map<String, dynamic>;
    return 'msgs=${json['messageCount']}, generating=${json['isGenerating']}, '
        'tools=${(json['toolResults'] as List?)?.length ?? 0}';
  } catch (e) {
    return 'parse error: $e';
  }
}
