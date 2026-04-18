/// Driver workflow test script
/// Calls app service extensions via VM Service WebSocket (with isolateId)
/// Usage: dart run tool/driver_workflow.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _vmServiceWsUri = 'ws://127.0.0.1:54204/N5UiIBtKeGM=/ws';

Future<void> main() async {
  final socket = await WebSocket.connect(_vmServiceWsUri);
  print('Connected to VM Service');

  int _nextId = 0;
  String? isolateId;
  final _pending = <int, Completer<Map<String, dynamic>>>{};

  // Background listener
  socket.listen(
    (data) {
      try {
        final resp = jsonDecode(data as String) as Map<String, dynamic>;
        final id = resp['id'];
        if (id != null && _pending.containsKey(id)) {
          if (resp.containsKey('error')) {
            _pending[id]!.completeError(resp['error']);
          } else {
            _pending[id]!.complete(resp['result'] as Map<String, dynamic>);
          }
          _pending.remove(id);
        }
      } catch (_) {}
    },
    onError: (e) => print('WS error: $e'),
  );

  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params) async {
    final id = ++_nextId;
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;

    socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': {...params, if (isolateId != null) 'isolateId': isolateId},
    }));

    return c.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => {'status': 'error', 'message': 'RPC timeout'},
    );
  }

  // 1) Get isolate ID
  final vm = await rpc('getVM', {});
  final isolates = (vm['isolates'] as List?) ?? [];
  isolateId = (isolates[0] as Map)['id'] as String;
  print('Isolate: $isolateId');

  Future<Map<String, dynamic>> callExt(String name, Map<String, String> params) =>
      rpc(name, params);

  Future<bool> waitForGeneration({Duration timeout = const Duration(seconds: 120)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final state = await callExt('ext.test.chatState', {});
        final isGenerating = state['isGenerating'] as bool? ?? false;
        if (!isGenerating) {
          print('\n  Done. Messages: ${state['messageCount']}');
          for (final r in (state['toolResults'] as List? ?? [])) {
            final m = r as Map;
            print('  Tool: ${m['success'] == true ? 'OK' : 'FAIL'} - ${m['summary']}');
          }
          final lastMsg = state['lastMessage'] as String?;
          if (lastMsg != null && lastMsg.isNotEmpty) {
            final p = lastMsg.length > 300 ? '${lastMsg.substring(0, 300)}...' : lastMsg;
            print('  Reply: $p');
          }
          return true;
        }
        stdout.write('.');
      } catch (_) {
        stdout.write('x');
      }
    }
    print('\n  TIMEOUT');
    return false;
  }

  void step(String n, String desc) {
    print('\n${'=' * 60}');
    print('  STEP $n: $desc');
    print('${'=' * 60}');
  }

  print('Starting full AI-driven workflow test...\n');

  // STEP 0: Navigate
  step('0', 'Navigate to AI Assistant tab');
  final nav = await callExt('ext.test.navigate', {'tab': 'AI 助手'});
  print('  -> status=${nav['status']}, index=${nav['index']}');
  await Future.delayed(const Duration(seconds: 2));

  // STEP 1: Create Work
  step('1', 'Create Work (作品)');
  await callExt('ext.test.chat', {
    'message': '请帮我创建一部新的小说作品，名称为"星辰变"，这是一部玄幻修真小说，讲述主角秦羽从凡人修炼成神的故事。',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 2: Create Volume
  step('2', 'Create Volume (卷)');
  await callExt('ext.test.chat', {
    'message': '请为"星辰变"创建第一卷"凡人界"，描述为主角秦羽在凡人世界的修炼历程。',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 3: Create Chapter
  step('3', 'Create Chapter (章节)');
  await callExt('ext.test.chat', {
    'message': '请在第一卷"凡人界"下创建第一章"潜龙出渊"，内容是秦羽在云雾山庄的少年时期，发现自己无法修炼内功，但他遇到了一只奇异的灵兽小黑。',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 4: Create Characters
  step('4', 'Create Characters (角色)');
  await callExt('ext.test.chat', {
    'message': '请帮我创建以下角色：\n'
        '1. 秦羽 - 男主角，云雾山庄三少爷，性格坚毅隐忍，虽天生无法修炼内功但意志坚定\n'
        '2. 小黑 - 奇异灵兽，秦羽的伙伴，外表是一只黑色小鹰，实际是神兽变异\n'
        '3. 项央 - 秦羽的父亲，云雾山庄庄主，东极圣皇，威严深沉\n'
        '4. 姜立 - 女主角，秦羽的挚爱，来自神界的姜氏一族，温婉聪慧',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 5: Scene + Dialogue
  step('5', 'Create Scene & Dialogue (场景+对话)');
  await callExt('ext.test.chat', {
    'message': '请为第一章"潜龙出渊"写一段场景对话：\n'
        '场景：秦羽在后山悬崖边独自练剑，小黑在一旁看着。项央悄然来到崖边观察儿子。秦羽发现父亲后，父子之间有一段关于"强者之路"的对话。\n\n'
        '要求：\n'
        '- 体现秦羽内心的倔强和压抑\n'
        '- 项央作为父亲和圣皇的双重身份带来的复杂情感\n'
        '- 小黑偶尔的灵性反应\n'
        '- 对话要自然，有潜台词',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 6: Relationships
  step('6', 'Create Relationships (关系)');
  await callExt('ext.test.chat', {
    'message': '请为我创建以下角色之间的关系：\n'
        '1. 秦羽和项央：父子关系，项央对秦羽有深沉的父爱但因身份原因不善表达\n'
        '2. 秦羽和小黑：伙伴灵兽契约关系，彼此信赖\n'
        '3. 秦羽和姜立：恋人关系，后期的灵魂伴侣\n'
        '4. 项央和姜立：未来的翁媳关系',
  });
  print('  Waiting for AI...');
  if (!await waitForGeneration()) { await socket.close(); exit(1); }

  // STEP 7: Plot Review
  step('7', 'Run Plot Review (剧情审查)');
  await callExt('ext.test.chat', {
    'message': '请对第一章"潜龙出渊"进行全面剧情审查，包括：\n'
        '1. 设定一致性检查：世界观、修炼体系是否自洽\n'
        '2. 角色OOC检测：角色言行是否符合设定\n'
        '3. 文风质量：是否有AI写作痕迹\n'
        '4. 情节逻辑：情节推进是否合理\n'
        '5. 读者体验：叙事节奏、悬念设置\n'
        '请给出评分和具体的修改建议。',
  });
  print('  Waiting for AI (extended timeout)...');
  if (!await waitForGeneration(timeout: const Duration(seconds: 180))) {
    await socket.close();
    exit(1);
  }

  // SUMMARY
  print('\n${'#' * 60}');
  print('  FULL AI-DRIVEN WORKFLOW COMPLETE');
  print('${'#' * 60}');
  print('  [0] Navigated to AI Assistant tab');
  print('  [1] Work: 星辰变');
  print('  [2] Volume: 第一卷 凡人界');
  print('  [3] Chapter: 第一章 潜龙出渊');
  print('  [4] Characters: 秦羽, 小黑, 项央, 姜立');
  print('  [5] Scene & Dialogue: 悬崖练剑父子对话');
  print('  [6] Relationships: 父子, 灵兽伙伴, 恋人, 翁媳');
  print('  [7] Plot Review: 全面审查完成');
  print('${'#' * 60}\n');

  await socket.close();
  print('Done!');
}
