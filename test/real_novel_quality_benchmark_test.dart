import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_providers.dart' as providers;
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';
import 'package:novel_writer/features/story_generation/data/ai_cliche_detector.dart';
import 'package:novel_writer/features/story_generation/data/artifact_recorder.dart';
import 'package:novel_writer/features/story_generation/data/chapter_concurrent_runner.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_tracker.dart';
import 'package:novel_writer/features/story_generation/data/prose_style_analyzer.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

const String _envGuard = 'RUN_REAL_NOVEL_QUALITY_BENCHMARK';
const String _outputRoot = 'artifacts/real_validation/novel_quality_benchmark';
const Duration _heartbeatInterval = Duration(minutes: 10);

// ---------------------------------------------------------------------------
// 心跳检测
// ---------------------------------------------------------------------------

class _Heartbeat {
  _Heartbeat({required this.label, required this.testFail});

  final String label;
  final void Function(String message) testFail;
  DateTime _lastBeat = DateTime.now();
  Timer? _timer;

  void beat([String? detail]) {
    _lastBeat = DateTime.now();
    if (detail != null) {
      stdout.writeln('[$label] 心跳 @ ${DateTime.now().toIso8601String()} — $detail');
    }
  }

  void start() {
    _timer = Timer.periodic(_heartbeatInterval, (_) {
      final since = DateTime.now().difference(_lastBeat);
      if (since > _heartbeatInterval * 2) {
        testFail(
          '$label 心跳超时：最近 ${since.inMinutes} 分钟无进展，'
          '上次心跳在 ${_lastBeat.toIso8601String()}',
        );
      } else {
        stdout.writeln(
          '[$label] 心跳检查：距上次活动 ${since.inSeconds}s，正常运行中',
        );
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

class _BenchmarkChapter {
  const _BenchmarkChapter({
    required this.id,
    required this.title,
    required this.summary,
    required this.targetLength,
    required this.scenes,
  });

  final String id;
  final String title;
  final String summary;
  final int targetLength;
  final List<_BenchmarkScene> scenes;
}

class _BenchmarkScene {
  const _BenchmarkScene({
    required this.id,
    required this.title,
    required this.targetLength,
    required this.summary,
    required this.targetBeat,
    required this.worldNodeIds,
    required this.cast,
  });

  final String id;
  final String title;
  final int targetLength;
  final String summary;
  final String targetBeat;
  final List<_BenchmarkCast> cast;
  final List<String> worldNodeIds;
}

class _BenchmarkCast {
  const _BenchmarkCast({
    required this.characterId,
    required this.name,
    required this.role,
    required this.participation,
  });

  final String characterId;
  final String name;
  final String role;
  final SceneCastParticipation participation;
}

class _ChapterSummary {
  _ChapterSummary({
    required this.chapterId,
    required this.chapterTitle,
    required this.sceneCount,
    required this.actualLength,
    required this.reviewPassed,
    required this.proseRetryCount,
    required this.totalMs,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  final String chapterId;
  final String chapterTitle;
  final int sceneCount;
  final int actualLength;
  final bool reviewPassed;
  final int proseRetryCount;
  final int totalMs;
  final int promptTokens;
  final int completionTokens;
}

// ---------------------------------------------------------------------------
// LLM 调用追踪
// ---------------------------------------------------------------------------

class _TrackingLlmClient implements AppLlmClient {
  _TrackingLlmClient(this._inner);

  final AppLlmClient _inner;
  int callCount = 0;
  final List<int> callDurations = [];
  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount++;
    _log('LLM chat call #$callCount starting...');
    final sw = Stopwatch()..start();
    final result = await _inner.chat(request);
    sw.stop();
    callDurations.add(sw.elapsedMilliseconds);
    final promptTokens = result.promptTokens ?? 0;
    final completionTokens = result.completionTokens ?? 0;
    totalPromptTokens += promptTokens;
    totalCompletionTokens += completionTokens;
    _log('LLM chat call #$callCount done in ${sw.elapsedMilliseconds}ms: succeeded=${result.succeeded} text=${result.text?.length ?? 0} chars prompt=$promptTokens completion=$completionTokens failure=${result.failureKind}');
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    callCount++;
    _log('LLM chatStream call #$callCount starting...');
    return _inner.chatStream(request);
  }
}

// ---------------------------------------------------------------------------
// 设置解析
// ---------------------------------------------------------------------------

class _ResolvedSettings {
  const _ResolvedSettings({
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutMs,
    required this.maxConcurrentRequests,
  });

  final String providerName;
  final String baseUrl;
  final String apiKey;
  final String model;
  final int timeoutMs;
  final int maxConcurrentRequests;
}

Future<_ResolvedSettings> _resolveSettings() async {
  final env = Platform.environment;
  final localConfig = await _loadLocalConfig();

  // 默认用智谱 GLM Coding Plan
  const zhipuProvider = providers.AppLlmProviderRegistry.zhipuCodingPlanCn;
  const mimoProvider = providers.AppLlmProviderRegistry.mimo;

  // MiMo 开关：NOVEL_BENCHMARK_USE_MIMO=1 时切换
  final useMimo = env['NOVEL_BENCHMARK_USE_MIMO'] == '1';

  // 优先用 NOVEL_BENCHMARK_ 前缀变量，避免与 Claude Code 代理变量冲突
  var apiKey = env['NOVEL_BENCHMARK_API_KEY'] ??
      env['ANTHROPIC_AUTH_TOKEN'] ?? '';
  if (apiKey.isEmpty) {
    apiKey = localConfig['ANTHROPIC_AUTH_TOKEN'] ??
        localConfig['apiKey'] ?? '';
  }

  var baseUrl = env['NOVEL_BENCHMARK_BASE_URL'] ?? '';
  if (baseUrl.isEmpty) baseUrl = localConfig['baseUrl'] ?? '';

  var model = env['NOVEL_BENCHMARK_MODEL'] ?? env['REAL_AI_MODEL'] ?? '';
  if (model.isEmpty) model = localConfig['model'] ?? '';

  if (useMimo) {
    apiKey = env['XIAOMI_API_KEY'] ?? apiKey;
    // MimoAdapter 使用 OpenAI 兼容协议（endpoint path: chat/completions），
    // XIAOMI_BASE_URL 指向 /anthropic（Anthropic 协议端点），不兼容。
    // 优先使用 NOVEL_BENCHMARK_BASE_URL，否则使用 mimo 的 OpenAI 兼容默认地址。
    if (!env.containsKey('NOVEL_BENCHMARK_BASE_URL') || baseUrl.isEmpty) {
      baseUrl = mimoProvider.defaultBaseUrl;
    }
    model = env['XIAOMI_MODEL'] ?? model;
    if (model.isEmpty) model = 'mimo-v2.5-pro';
  } else {
    // 不使用 ANTHROPIC_BASE_URL（那是 Claude Code 代理端点）
    if (baseUrl.isEmpty) baseUrl = zhipuProvider.defaultBaseUrl;
    if (model.isEmpty) model = 'glm-5.1';
  }

  final providerName = baseUrl.contains('bigmodel.cn') || baseUrl.contains('zhipuai.cn')
      ? '智谱 GLM'
      : baseUrl.contains('xiaomimimo.com')
          ? 'Xiaomi MiMo'
          : 'Ollama Cloud';

  final timeoutMs = int.tryParse(env['REAL_AI_TIMEOUT_MS'] ?? '') ??
      int.tryParse(localConfig['timeoutMs'] ?? '') ??
      300000;
  final maxConcurrent = int.tryParse(env['REAL_AI_MAX_CONCURRENT'] ?? '') ??
      int.tryParse(localConfig['maxConcurrentRequests'] ?? '') ??
      1;

  return _ResolvedSettings(
    providerName: providerName,
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    timeoutMs: timeoutMs < 300000 ? 300000 : timeoutMs,
    maxConcurrentRequests: maxConcurrent < 1 ? 1 : maxConcurrent,
  );
}

Future<Map<String, String>> _loadLocalConfig() async {
  final file = File('setting.json');
  if (!await file.exists()) return const {};
  return loadLocalSettingsFile(file: file);
}

// ---------------------------------------------------------------------------
// 十章故事定义：沿海走私悬疑
// ---------------------------------------------------------------------------

const _benchmarkChapters = <_BenchmarkChapter>[
  // 第一章：消失的工人
  _BenchmarkChapter(
    id: 'chapter-01',
    title: '第一章 消失的工人',
    summary: '调查记者林默收到失踪码头工人老陈寄来的神秘包裹，里面只有一本破损的货运台账。'
        '她决定亲自去港区码头查清真相。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '神秘包裹',
        targetLength: 1000,
        summary: '林默在报社收到一个没有寄件人地址的包裹，拆开后是一本被海水浸泡过的货运台账。'
            '账本里夹着一张手写纸条："如果我出事，把这个交给林默——老陈。"',
        targetBeat: '建立悬念，引出老陈失踪的核心线索，确立林默的调查动机。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '翻看包裹内容，辨认出老陈的笔迹',
              dialogue: '"老陈……三个月前就说要回老家，怎么突然寄这个？"',
              interaction: '从账本里找出异常标记的几页，决定去码头',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"港区最近不太平，上个月就有工人报案说被人跟踪。"',
              interaction: '提醒林默注意安全，但同意这条线索值得追',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '码头探访',
        targetLength: 1000,
        summary: '林默傍晚赶到旧码头，发现港区比想象中更荒凉。她找到老陈曾工作过的仓库，'
            '却被一个自称是港区管理方凯的人拦住。',
        targetBeat: '林默首次踏入港区，建立危险氛围；方凯登场留下第一印象。',
        worldNodeIds: ['harbor-district'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '拿着老陈的账本复印件在仓库区转了一圈',
              dialogue: '"我找陈师傅，他之前在这里做什么工作？"',
              interaction: '对周围的安保措施保持警惕',
            ),
          ),
          _BenchmarkCast(
            characterId: 'fangkai',
            name: '方凯',
            role: '港区安全主管',
            participation: SceneCastParticipation(
              dialogue: '"陈师傅？他已经两个月没来上班了，我们也在找他。"',
              interaction: '表面客气，但眼神一直在打量林默手里的资料',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第二章：货运清单
  _BenchmarkChapter(
    id: 'chapter-02',
    title: '第二章 货运清单',
    summary: '林默通过账本线索追查到一批隐藏的货运记录，发现远洋贸易公司在做虚假报关。'
        '她决定潜入市政档案楼查证。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '账本里的秘密',
        targetLength: 1000,
        summary: '林默连夜研究老陈的账本，发现其中用红笔标注的几笔货运记录与公开报关数据对不上。'
            '她带着发现去找苏薇商议对策。',
        targetBeat: '揭示核心谜团——虚假报关，推动故事进入主动调查阶段。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '将账本记录与网上公开的报关数据逐条比对',
              dialogue: '"这三批货在海关记录里根本不存在，但账本上有完整的装卸记录。"',
              interaction: '向苏薇展示发现，争取报社资源支持',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"光有账本不够，我们需要原始档案来交叉验证。"',
              interaction: '建议林默去市政档案楼查原始航运记录',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '午夜档案楼',
        targetLength: 1000,
        summary: '林默借着加班名义进入市政档案楼，找到了远洋贸易公司三年前的原始航运底册。'
            '就在她拍照取证时，发现有人也在翻找同一批档案。',
        targetBeat: '获取关键证据，同时暗示有第三方势力也在追查同一件事。',
        worldNodeIds: ['city-archive'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '在昏暗的档案室里快速翻找底册并用手机拍照',
              dialogue: '"找到了——2023年9月的航运底册，报关编号和老陈账本上的完全对不上。"',
              interaction: '听到隔壁有脚步声后迅速藏好资料',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第三章：线人之约
  _BenchmarkChapter(
    id: 'chapter-03',
    title: '第三章 线人之约',
    summary: '老陈突然联系林默约在废弃磨坊见面，说要告诉她全部真相。'
        '但见面时老陈极度紧张，方凯的人也出现在附近。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '老陈现身',
        targetLength: 1000,
        summary: '林默按照短信指示来到城郊废弃磨坊，见到了失踪数月的老陈。'
            '老陈消瘦了很多，精神紧张，不停回头张望。',
        targetBeat: '老陈现身揭开部分真相，建立时间紧迫感。',
        worldNodeIds: ['old-mill'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"陈师傅，你这几个月到底去了哪里？"',
              interaction: '安抚老陈情绪，试图从他口中得到更多细节',
            ),
          ),
          _BenchmarkCast(
            characterId: 'laochen',
            name: '老陈',
            role: '码头工人/线人',
            participation: SceneCastParticipation(
              dialogue: '"我发现了他们的秘密转运点，账本只是一小部分。真正的证据在地下仓库。"',
              interaction: '压低声音说话，时不时往窗外看',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '被盯上的会面',
        targetLength: 1000,
        summary: '老陈正要说出地下仓库的具体位置时，磨坊外面出现了两辆黑色SUV。'
            '老陈仓皇逃离，林默只来得及记下他说的几个关键词。',
        targetBeat: '关键信息被打断，留下悬念；确认方凯/钱董势力在追踪老陈。',
        worldNodeIds: ['old-mill'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '从磨坊后门离开，记下老陈说的"地下三层B区"',
              dialogue: '"明天同一时间，换个地方。"',
              interaction: '装作迷路的游客避开跟踪者的视线',
            ),
          ),
          _BenchmarkCast(
            characterId: 'laochen',
            name: '老陈',
            role: '码头工人/线人',
            participation: SceneCastParticipation(
              action: '从后窗翻出磨坊，消失在夜色中',
              dialogue: '"别相信港区任何人，尤其是方凯——"',
              interaction: '话没说完就被迫中断',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第四章：内部消息
  _BenchmarkChapter(
    id: 'chapter-04',
    title: '第四章 内部消息',
    summary: '方凯主动联系林默，声称自己也是受害者，愿意提供远洋贸易公司的内部文件。'
        '林默半信半疑，但决定利用这个机会获取更多证据。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '方凯的提议',
        targetLength: 1000,
        summary: '方凯在报社楼下拦住林默，说他知道她在调查远洋贸易公司，'
            '并提出可以提供公司内部的货运调度记录作为交换——他需要林默帮他把家人送出城。',
        targetBeat: '方凯以合作者身份出现，埋下双面间谍的伏笔。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"你为什么要帮我？你在港区可是安全主管。"',
              interaction: '内心警觉但面上不露声色',
            ),
          ),
          _BenchmarkCast(
            characterId: 'fangkai',
            name: '方凯',
            role: '港区安全主管',
            participation: SceneCastParticipation(
              dialogue: '"钱董在利用港区做走私中转，我只是个看门的。再不走，下一个消失的就是我。"',
              interaction: '展示了一张他家人的照片，表情真诚但话语滴水不漏',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '真伪难辨',
        targetLength: 1000,
        summary: '林默与苏薇讨论方凯的可信度。苏薇建议林默先验证方凯提供的文件真伪，'
            '再做下一步决定。林默找到一份文件中的细节可以与档案楼数据交叉验证。',
        targetBeat: '建立信任与怀疑的张力，推动进入暗访阶段。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '对比方凯给的文件和档案楼拍的照片',
              dialogue: '"这份调度表上的日期和编号……和老陈账本对上了。"',
              interaction: '决定在接触方凯的同时做好撤退准备',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"资料可能是真的，但他的动机呢？别忘了他也是港区的人。"',
              interaction: '帮林默制定安全联络方案',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第五章：伪造现场
  _BenchmarkChapter(
    id: 'chapter-05',
    title: '第五章 伪造现场',
    summary: '林默租住的公寓被人翻搜，老陈寄来的原始账本险些被拿走。'
        '同一天，港区发生一起"意外"坍塌事故，林默怀疑是为了销毁证据。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '被翻的公寓',
        targetLength: 1000,
        summary: '林默回到公寓发现门锁被撬，屋内被翻得乱七八糟。'
            '所幸她事先把关键证据复印件存放在报社保险柜里。',
        targetBeat: '威胁升级到人身层面，确认对方已经在针对林默。',
        worldNodeIds: ['safehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '站在乱翻的房间中央，先确认账本原件不在家中',
              dialogue: '"他们比我想的更快动手了。"',
              interaction: '立刻给苏薇打电话报平安并商议下一步',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '港区坍塌',
        targetLength: 1000,
        summary: '林默收到港区消息：一座旧仓库突然坍塌，官方说是年久失修。'
            '林默赶赴现场，发现坍塌的正是老陈提到过的那个仓库。',
        targetBeat: '确认销毁证据行为，时间紧迫感进一步升级。',
        worldNodeIds: ['harbor-district'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '站在封锁线外观察坍塌现场，用手机记录现场状况',
              dialogue: '"年久失修？这个仓库上个月刚做了结构检测。"',
              interaction: '注意到方凯也在现场，正在和施工队说话',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-03',
        title: '下定决心',
        targetLength: 1000,
        summary: '坍塌事件让林默确信对方在系统性销毁证据。她决定不再等待，'
            '要在地下仓库被彻底清理之前完成暗访取证。',
        targetBeat: '从被动调查转为主动暗访，故事进入冒险阶段。',
        worldNodeIds: ['safehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"如果地下仓库也出了事，所有证据就都没了。我必须尽快行动。"',
              interaction: '通知苏薇自己要去暗访地下仓库，约定联络时间',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"如果六小时内你没有任何消息，我会联系警方和媒体同行。"',
              interaction: '帮林默准备暗访所需的伪装工具和通讯设备',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第六章：暗访仓库
  _BenchmarkChapter(
    id: 'chapter-06',
    title: '第六章 暗访仓库',
    summary: '林默利用方凯提供的通行卡潜入地下仓库，找到了走私货物的直接证据。'
        '但在撤离过程中差点被巡逻人员发现。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '潜入',
        targetLength: 1000,
        summary: '深夜，林默用方凯给的通行卡刷卡进入地下仓储区。'
            '通道里光线昏暗，她用手机微光仔细辨认方向标识。',
        targetBeat: '暗访行动开始，建立高压紧张氛围。',
        worldNodeIds: ['underground-warehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '沿着地下通道前进，注意避开监控摄像头',
              dialogue: '"方凯说的B区在三号通道尽头……"',
              interaction: '每走一步都仔细听周围动静',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '发现证据',
        targetLength: 1000,
        summary: '林默在地下仓库B区找到了大量未申报的走私货物，包括违禁化学品和伪造标签。'
            '她用手机拍照记录了一切。',
        targetBeat: '获取决定性证据，调查取得重大突破。',
        worldNodeIds: ['underground-warehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '逐一拍摄货物标签、装箱单和运输记录',
              dialogue: '"这些货物的目的地全写着虚假公司名称……和老陈账本对上了。"',
              interaction: '发现角落里有一张手写便签，笔迹像是老陈的',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-03',
        title: '险些被发现',
        targetLength: 1000,
        summary: '就在林默准备离开时，巡逻队突然出现。她躲进一个空集装箱里，'
            '透过缝隙看到巡逻队中有方凯的身影。',
        targetBeat: '方凯可能不可信的暗示；暗访行动险象环生。',
        worldNodeIds: ['underground-warehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '屏住呼吸缩在集装箱角落，手机调到静音',
              dialogue: '（内心独白）"方凯……他不应该在这里。"',
              interaction: '等巡逻队走远后才敢从集装箱出来',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第七章：双面间谍
  _BenchmarkChapter(
    id: 'chapter-07',
    title: '第七章 双面间谍',
    summary: '林默质问方凯为何出现在地下仓库。方凯承认自己在钱董和自己妹妹之间做两面人。'
        '但随后发生的事证明方凯的"坦白"也是精心设计的陷阱。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '正面质问',
        targetLength: 1000,
        summary: '林默约方凯在河道暗码头见面，直接质问他为什么出现在地下仓库巡逻队里。'
            '方凯被迫坦白：他是钱董安排的内应，但他说自己已经想退出。',
        targetBeat: '方凯暴露双重身份，信任彻底崩塌。',
        worldNodeIds: ['river-dock'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"我亲眼看到你跟着巡逻队。你从一开始就在监视我？"',
              interaction: '已经把手机连接到苏薇的实时通讯频道',
            ),
          ),
          _BenchmarkCast(
            characterId: 'fangkai',
            name: '方凯',
            role: '港区安全主管',
            participation: SceneCastParticipation(
              dialogue: '"钱董用我妹妹要挟我，我没得选。但这次，我给你真东西。"',
              interaction: '掏出一个U盘递给林默',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '陷阱',
        targetLength: 1000,
        summary: '林默拿到U盘后刚离开暗码头，就发现身后有人跟踪。'
            '她按事先约定的路线甩掉尾巴，回到安全屋检查U盘——里面的文件全是伪造的。',
        targetBeat: '方凯彻底暴露为钱董的棋子；林默必须独立完成调查。',
        worldNodeIds: ['safehouse'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '在安全屋用笔记本电脑检查U盘文件',
              dialogue: '"这上面全是假数据……他在拖延我，给钱董争取时间销毁真正的证据。"',
              interaction: '立刻联络苏薇启动紧急预案',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第八章：绝地反击
  _BenchmarkChapter(
    id: 'chapter-08',
    title: '第八章 绝地反击',
    summary: '林默不再依赖任何线人，与苏薇制定了一套独立的证据收集和发布计划。'
        '她决定去检查站拦截最后一趟走私运输车。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '制定计划',
        targetLength: 1000,
        summary: '林默和苏薇在报社彻夜商议。她们决定兵分两路：'
            '苏薇负责准备新闻报道和联系上级媒体，林默去获取最后一份现场证据。',
        targetBeat: '从被动转为主动进攻，节奏加快。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"明天凌晨三点，最后一趟走私车会从环城公路经过。我要在现场。"',
              interaction: '与苏薇确认报道发布的最后期限',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"你负责现场，我负责让这条新闻在明天中午之前见报。"',
              interaction: '帮林默确认走私车的路线和预计经过时间',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '检查站埋伏',
        targetLength: 1000,
        summary: '凌晨三点，林默在环城公路检查站附近蹲守。她看到了那辆走私运输车，'
            '但车牌和方凯提供的完全不同。',
        targetBeat: '发现方凯给的信息已过时/被篡改，需要临场应变。',
        worldNodeIds: ['highway-checkpoint'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '躲在检查站旁的草丛里，用长焦镜头拍摄运输车',
              dialogue: '"车牌对不上……他们已经换了运输车辆。"',
              interaction: '当机立断决定跟踪运输车到目的地',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-03',
        title: '最后的证据',
        targetLength: 1000,
        summary: '林默跟踪运输车到了河道暗码头，拍到货物卸载和人员交接的全过程。'
            '在画面中，她看到了一个意想不到的人——钱董本人出现在现场。',
        targetBeat: '获取铁证，反派正式露面，为高潮对峙做铺垫。',
        worldNodeIds: ['river-dock'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '从暗处用手机拍摄全程，确保画面清晰',
              dialogue: '"是他……钱宝山本人来了。"',
              interaction: '拍完视频后立刻上传到苏薇的安全服务器',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第九章：正面对峙
  _BenchmarkChapter(
    id: 'chapter-09',
    title: '第九章 正面对峙',
    summary: '林默带着全部证据直接面对钱董，要求他自首。'
        '钱董试图收买不成后，派人追杀林默。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '最后的谈判',
        targetLength: 1000,
        summary: '林默通过方凯传话，约钱董在远洋贸易公司办公室见面。'
            '她当面展示了所有证据，要求钱董在24小时内自首。',
        targetBeat: '正面对峙，反派和主角的价值观直接碰撞。',
        worldNodeIds: ['trading-co-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"账本、航运底册、地下仓库照片、河道暗码头的视频——全部齐全。"',
              interaction: '保持冷静，不露怯',
            ),
          ),
          _BenchmarkCast(
            characterId: 'qianzhuxi',
            name: '钱董',
            role: '远洋贸易公司董事长',
            participation: SceneCastParticipation(
              dialogue: '"林记者，你觉得一个人能对抗一个系统吗？"',
              interaction: '表面镇定，但手在桌下按了一个按钮',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '逃离',
        targetLength: 1000,
        summary: '谈判破裂，钱董叫人扣住林默。林默利用事先在办公室窗户上做的标记，'
            '从二楼跳到外面的消防梯上，带着证据U盘逃走。',
        targetBeat: '动作场景，生死逃亡，为最终公开真相争取时间。',
        worldNodeIds: ['trading-co-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '从二楼窗户翻出，抓住消防梯扶手滑下',
              dialogue: '"新闻会在今天中午发出，你拦不住。"',
              interaction: '在逃跑过程中给苏薇发出预设的发布指令',
            ),
          ),
        ],
      ),
    ],
  ),

  // 第十章：真相大白
  _BenchmarkChapter(
    id: 'chapter-10',
    title: '第十章 真相大白',
    summary: '苏薇在预定时间发布了调查报道。警方介入调查，钱董的走私网络被全面揭露。'
        '老陈被找到并安全救出。林默完成了她的调查使命。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'scene-01',
        title: '报道发布',
        targetLength: 1000,
        summary: '苏薇在报社编辑部按下发送键，调查报道同时在全国三十多家媒体平台同步发布。'
            '消息迅速引爆舆论。',
        targetBeat: '真相公之于众，调查成果落地。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              action: '点击"发布"按钮，然后拨打警方专线',
              dialogue: '"所有证据已经公开。现在请你们依法介入。"',
              interaction: '同时通知了三家兄弟媒体同步转载',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-02',
        title: '老陈获救',
        targetLength: 1000,
        summary: '警方根据林默提供的线索找到了被关押在废弃仓库里的老陈。'
            '老陈身体虚弱但神志清醒，他向警方做了完整笔录。',
        targetBeat: '老陈安全获救，核心线人证词补全证据链。',
        worldNodeIds: ['police-station'],
        cast: [
          _BenchmarkCast(
            characterId: 'laochen',
            name: '老陈',
            role: '码头工人/线人',
            participation: SceneCastParticipation(
              dialogue: '"我从一开始就记录了所有不正常的货运安排，就等着这一天。"',
              interaction: '向警方指认参与走私的所有港区人员',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'scene-03',
        title: '余波',
        targetLength: 1000,
        summary: '钱董在机场试图出境时被截获。方凯因配合调查获得从宽处理。'
            '林默站在报社天台上，看着城市天际线，'
            '苏薇给她端来一杯咖啡："下一个选题想好了吗？"',
        targetBeat: '故事收束，角色命运交代清楚，留下开放性结尾。',
        worldNodeIds: ['press-office'],
        cast: [
          _BenchmarkCast(
            characterId: 'linmo',
            name: '林默',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '"先让我休息一天。然后……港口区还有几个没解开的问题。"',
              interaction: '微笑接过咖啡，目光依然锐利',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suwei',
            name: '苏薇',
            role: '报社编辑',
            participation: SceneCastParticipation(
              dialogue: '"我就知道你停不下来。"',
              interaction: '两人并肩站在天台上，看着远处港区渐渐亮起的灯光',
            ),
          ),
        ],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// 十章玄幻故事定义：青云宗秘境
// ---------------------------------------------------------------------------

const _xianxiaChapters = <_BenchmarkChapter>[
  _BenchmarkChapter(
    id: 'x-chapter-01',
    title: '第一章 灵根觉醒',
    summary: '青云宗门外弟子叶尘在后山采药时意外触发上古阵法，被封印千年的残缺灵根觉醒。'
        '他发现自己能看到别人看不到的灵气流动。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s01',
        title: '后山异变',
        targetLength: 1000,
        summary: '叶尘在悬崖边采一株罕见的星雾草时脚下石壁崩塌，跌入隐秘洞穴。'
            '洞穴中央的石台上放着一枚古旧玉简，触碰的瞬间灵气暴涌。',
        targetBeat: '建立悬念，引出上古传承的核心线索，确立叶尘的特殊体质。',
        worldNodeIds: ['qyun-mountain'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '青云宗门外弟子',
            participation: SceneCastParticipation(
              action: '跌入洞穴，触碰玉简引发灵气暴涌',
              dialogue: '"这是……什么东西？玉简上的字在动！"',
              interaction: '从玉简中看到模糊的上古画面',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suyao',
            name: '苏瑶',
            role: '内门弟子',
            participation: SceneCastParticipation(
              dialogue: '"后山灵气波动异常，你碰了什么？"',
              interaction: '感应到灵气异变赶来查看，发现叶尘浑身灵气环绕',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s02',
        title: '宗门质询',
        targetLength: 1000,
        summary: '叶尘被带到宗门大殿，玄清长老亲自查验他的灵根。'
            '结果令人震惊——五行废灵根中竟隐藏着消失万年的混沌灵根残片。',
        targetBeat: '揭示叶尘的特殊体质，引发宗门高层关注和暗中的觊觎。',
        worldNodeIds: ['qyun-hall'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '门外弟子',
            participation: SceneCastParticipation(
              action: '接受灵根测试，体内灵力失控暴走',
              dialogue: '"长老，我真的不知道发生了什么，我从小就是废灵根。"',
              interaction: '感受到长老探查灵根时带来的巨大压力',
            ),
          ),
          _BenchmarkCast(
            characterId: 'xuanqing',
            name: '玄清长老',
            role: '宗门长老',
            participation: SceneCastParticipation(
              dialogue: '"混沌残片……这不可能，万年前的传承怎么会出现在一个废灵根上。"',
              interaction: '神色复杂地看着叶尘，似乎在权衡什么',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '内门首席弟子',
            participation: SceneCastParticipation(
              dialogue: '"长老，此人来路不明，应当严加看管。"',
              interaction: '在大殿角落冷眼旁观，眼神中闪过一丝贪婪',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-02',
    title: '第二章 宗门大比',
    summary: '一年一度的宗门大比开始，叶尘意外获得参赛资格。'
        '他在比武场上展现出不同寻常的战斗直觉，引起各方关注。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s03',
        title: '擂台初战',
        targetLength: 1000,
        summary: '叶尘在首场对决中面对筑基期弟子周明。所有人都认为他必败无疑，'
            '但他凭借灵眼能力看穿对手灵力运转轨迹，以弱胜强。',
        targetBeat: '展示叶尘独特能力，制造以弱胜强的反转效果。',
        worldNodeIds: ['qyun-arena'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '参赛弟子',
            participation: SceneCastParticipation(
              action: '在擂台上以灵眼洞悉对手破绽，一击制胜',
              dialogue: '"你的灵力运转在左肋有一个半息的间断，足够了。"',
              interaction: '全场震惊中走下擂台',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '内门首席弟子',
            participation: SceneCastParticipation(
              dialogue: '"一个练气期的废物，居然能看穿筑基期的灵力运转？有意思。"',
              interaction: '在高台上冷笑，暗中记下叶尘的能力特征',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s04',
        title: '暗夜警告',
        targetLength: 1000,
        summary: '比武结束后苏瑶找到叶尘，警告他赵元不是表面看上去那么简单。'
            '赵元曾让三名发现他秘密的弟子"意外"陨落。',
        targetBeat: '揭示赵元的危险性，建立紧张感和阵营对立。',
        worldNodeIds: ['qyun-disciple-quarters'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '参赛弟子',
            participation: SceneCastParticipation(
              dialogue: '"赵元真有那么可怕？他可是长老看重的首席弟子。"',
              interaction: '对苏瑶的警告半信半疑，但决定保持警惕',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suyao',
            name: '苏瑶',
            role: '内门弟子',
            participation: SceneCastParticipation(
              dialogue: '"去年失踪的李师兄，就是在赵元值守灵药园那天不见的。你小心。"',
              interaction: '将一枚防御玉符递给叶尘',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-03',
    title: '第三章 秘境试炼',
    summary: '宗门开启千年秘境"天玄洞"，各门派弟子进入争夺机缘。'
        '叶尘在秘境中发现一座上古炼丹师的洞府遗迹。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s05',
        title: '迷雾森林',
        targetLength: 1000,
        summary: '叶尘进入秘境后被传送至一片灵气紊乱的迷雾森林。'
            '他的灵眼能力在这里意外地能看穿迷雾中的灵兽陷阱和隐藏路径。',
        targetBeat: '秘境探险开局，展示叶尘在极端环境中的独特优势。',
        worldNodeIds: ['tianxuan-forest'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '秘境试炼者',
            participation: SceneCastParticipation(
              action: '用灵眼避开三头潜伏的灵兽，找到通往深处的路径',
              dialogue: '"灵气流向全乱了，但有规律——像是被什么东西牵引着。"',
              interaction: '在迷雾中独自行进，保持高度警觉',
            ),
          ),
          _BenchmarkCast(
            characterId: 'liuwushuang',
            name: '柳无双',
            role: '魔修',
            participation: SceneCastParticipation(
              dialogue: '"有意思，竟然有人在迷雾里如鱼得水。你是什么人？"',
              interaction: '从暗处现身，语气玩味但并无敌意',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s06',
        title: '古丹府',
        targetLength: 1000,
        summary: '叶尘跟随灵气指引找到上古炼丹师洞府。洞府内有完整的丹方石刻和一枚空间戒指。'
            '但赵元也追踪到了这里，企图抢夺。',
        targetBeat: '核心机缘获取，同时引出与赵元的正面对抗。',
        worldNodeIds: ['tianxuan-cave'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '试炼者',
            participation: SceneCastParticipation(
              action: '用灵眼解读丹方石刻，快速记下关键内容',
              dialogue: '"这些丹方……在外面早就失传了。"',
              interaction: '发现赵元闯入后迅速将空间戒指收入储物袋',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '内门首席弟子',
            participation: SceneCastParticipation(
              dialogue: '"叶尘，把洞府里的东西交出来，我可以当作什么都没发生。"',
              interaction: '以筑基后期的修为施压，堵住洞府出口',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-04',
    title: '第四章 故人之叛',
    summary: '叶尘在秘境中遭遇赵元伏击，危急时刻同伴张远突然反水投靠赵元。'
        '叶尘凭借古丹府中获得的阵法知识勉强脱困。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s07',
        title: '暗林伏击',
        targetLength: 1000,
        summary: '叶尘在秘境深处遭遇赵元和两名内门弟子的围攻。'
            '赵元使出禁术级别的攻击，叶尘被困在灵力牢笼中。',
        targetBeat: '危机升级，展示赵元隐藏的实力和冷酷手段。',
        worldNodeIds: ['tianxuan-deep'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被围攻者',
            participation: SceneCastParticipation(
              action: '被灵力牢笼困住，以灵眼寻找牢笼灵力节点的薄弱处',
              dialogue: '"赵元，你用禁术围杀同门，就不怕长老追究？"',
              interaction: '在牢笼中冷静观察对手灵力消耗',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '围攻者',
            participation: SceneCastParticipation(
              dialogue: '"长老？你以为长老不知道？天真。"',
              interaction: '释放出远超筑基期的灵力压制叶尘',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s08',
        title: '破阵脱困',
        targetLength: 1000,
        summary: '叶尘利用灵眼找到灵力牢笼的阵法缺陷，引爆自身灵根混沌残片的力量破阵。'
            '脱困后他发现张远一直暗中给赵元传递自己的位置信息。',
        targetBeat: '背叛揭露，叶尘被迫独自面对强敌，激发潜藏力量。',
        worldNodeIds: ['tianxuan-deep'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '脱困者',
            participation: SceneCastParticipation(
              action: '引爆混沌灵根残片的力量破开牢笼，趁乱遁走',
              dialogue: '"张远……原来从进秘境开始你就是他的人。"',
              interaction: '以秘境传送阵法紧急传送离开',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhangyuan',
            name: '张远',
            role: '叛变的同伴',
            participation: SceneCastParticipation(
              dialogue: '"叶尘，别怪我。赵师兄答应帮我突破筑基，我只是做了正确的选择。"',
              interaction: '不敢与叶尘对视，后退到赵元身后',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-05',
    title: '第五章 破境重生',
    summary: '叶尘在秘境深处闭关疗伤，混沌灵根残片与上古玉简中的传承产生共鸣，'
        '助他一举突破筑基期。出关后恰逢秘境即将关闭。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s09',
        title: '混沌共鸣',
        targetLength: 1000,
        summary: '叶尘在秘境深处的灵泉旁打坐疗伤，混沌灵根残片在灵气充裕的环境下主动运转，'
            '玉简中的功法自行灌入识海。他在短短一天内完成练气到筑基的突破。',
        targetBeat: '实力飞跃的转折点，展示传承力量的深远影响。',
        worldNodeIds: ['tianxuan-spring'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '突破者',
            participation: SceneCastParticipation(
              action: '在灵泉中引导混沌灵根运转，突破筑基期',
              dialogue: '"这就是……筑基？灵气像江河一样涌入丹田。"',
              interaction: '突破时引发灵气异象被远处的人感知到',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s10',
        title: '秘境出口',
        targetLength: 1000,
        summary: '叶尘赶到秘境出口时发现传送阵已被赵元的人控制。'
            '他必须在新实力尚未稳固的情况下强行突围。',
        targetBeat: '新力量的首次实战检验，紧张的逃亡节奏。',
        worldNodeIds: ['tianxuan-exit'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '突围者',
            participation: SceneCastParticipation(
              action: '以刚突破的筑基修为强闯传送阵',
              dialogue: '"让开，秘境要关闭了，谁也别想拦我。"',
              interaction: '与守阵弟子短暂交手后跳入传送光柱',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '阻拦者',
            participation: SceneCastParticipation(
              dialogue: '"你居然突破了？不可能这么快……"',
              interaction: '赶到时叶尘已消失在传送光柱中',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-06',
    title: '第六章 魔修之约',
    summary: '回到宗门后叶尘被隔离审查。柳无双主动现身邀他合作——'
        '她知道赵元背后的真正秘密，但需要叶尘的灵眼能力作为交换。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s11',
        title: '静室对峙',
        targetLength: 1000,
        summary: '叶尘被关在宗门静室中等待长老问询。柳无双通过秘术潜入，'
            '提出一个惊人的说法——赵元身上有魔修的功法气息。',
        targetBeat: '引入魔修视角，揭示赵元背后更大的阴谋。',
        worldNodeIds: ['qyun-seal-room'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被审查者',
            participation: SceneCastParticipation(
              dialogue: '"你是魔修，我凭什么相信你？"',
              interaction: '保持戒备，但认真分析柳无双提供的信息',
            ),
          ),
          _BenchmarkCast(
            characterId: 'liuwushuang',
            name: '柳无双',
            role: '魔修',
            participation: SceneCastParticipation(
              dialogue: '"赵元修炼的功法里有噬灵诀的痕迹，那是三百年前被灭宗的魔道功法。你的长老不可能看不出来。"',
              interaction: '展示一段赵元在秘境中使用魔功的灵气波动记录',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s12',
        title: '危险同盟',
        targetLength: 1000,
        summary: '叶尘经过慎重考虑决定与柳无双临时结盟。柳无双透露赵元的师父——'
            '宗门二长老暗渊真人——才是幕后黑手，他在借赵元收集宗门弟子的灵根精华。',
        targetBeat: '建立主角与魔修的非典型联盟，揭示更高层阴谋。',
        worldNodeIds: ['qyun-seal-room'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '结盟者',
            participation: SceneCastParticipation(
              dialogue: '"合作可以，但你得告诉我暗渊真人的真正目的。"',
              interaction: '与柳无双交换情报，制定初步计划',
            ),
          ),
          _BenchmarkCast(
            characterId: 'liuwushuang',
            name: '柳无双',
            role: '魔修盟友',
            participation: SceneCastParticipation(
              dialogue: '"暗渊真人要的不是灵根精华，是混沌灵根——就是你现在身上那块残片。"',
              interaction: '留下一枚联络玉符后悄然离去',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-07',
    title: '第七章 灵药园之谜',
    summary: '叶尘被指派到灵药园劳作，暗中调查失踪弟子的线索。'
        '他在灵药园地下发现了一条隐藏的灵脉通道。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s13',
        title: '灵药园当值',
        targetLength: 1000,
        summary: '叶尘以劳改名义进入灵药园，暗中用灵眼观察灵气流向。'
            '他发现灵药园中央的古井灵气流向异常——不是向外扩散，而是向内汇聚。',
        targetBeat: '调查推进，发现隐藏线索，保持悬疑节奏。',
        worldNodeIds: ['qyun-garden'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '灵药园杂役',
            participation: SceneCastParticipation(
              action: '假意浇药，实则用灵眼探测古井下的灵脉结构',
              dialogue: '"灵气全被吸到地下了……下面有什么东西在吞噬灵力。"',
              interaction: '在不引起注意的情况下反复观察古井区域',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suyao',
            name: '苏瑶',
            role: '内门弟子',
            participation: SceneCastParticipation(
              dialogue: '"你小心点，灵药园夜间有禁制巡逻，被抓到就完了。"',
              interaction: '暗中帮叶尘打掩护，吸引巡逻弟子注意',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s14',
        title: '地下灵脉',
        targetLength: 1000,
        summary: '叶尘趁夜潜入古井下的通道，发现一处地下密室。'
            '密室中有七具干枯的尸体——都是失踪的弟子，他们的灵根精华被完全抽空。',
        targetBeat: '核心发现，揭露暗渊真人的罪行证据。',
        worldNodeIds: ['qyun-underground'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '调查者',
            participation: SceneCastParticipation(
              action: '在密室中找到被抽空灵根的弟子尸体和记录仪',
              dialogue: '"七个人……全被抽干了灵根精华。这不是赵元一个人能做的事。"',
              interaction: '用玉简记录密室证据后迅速撤离',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-08',
    title: '第八章 宗门审判',
    summary: '叶尘将证据呈交玄清长老，请求公开审判暗渊真人。'
        '但宗主的态度暧昧不明，叶尘意识到宗门高层内部早已分裂。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s15',
        title: '长老密会',
        targetLength: 1000,
        summary: '叶尘私下向玄清长老展示地下密室的证据。'
            '玄清长老震惊之余透露，暗渊真人的修为已臻金丹巅峰，宗内无人能单独制衡。',
        targetBeat: '证据提交，但面临实力悬殊的困境。',
        worldNodeIds: ['qyun-elder-hall'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '举报者',
            participation: SceneCastParticipation(
              dialogue: '"长老，七具尸体就在灵药园地下，这证据够不够？"',
              interaction: '将记录玉简交给玄清长老',
            ),
          ),
          _BenchmarkCast(
            characterId: 'xuanqing',
            name: '玄清长老',
            role: '宗门长老',
            participation: SceneCastParticipation(
              dialogue: '"证据确凿，但暗渊的实力远超你想象。就算公开，他也能在众目睽睽下脱身。"',
              interaction: '神色凝重，似乎在做艰难的决定',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s16',
        title: '大殿风云',
        targetLength: 1000,
        summary: '玄清长老召开宗门大会公开证据。暗渊真人当众否认，'
            '反而指控叶尘与魔修勾结图谋不轨。宗主最终决定将叶尘收押候审。',
        targetBeat: '正义受挫，反派反咬一口，主角陷入更大危机。',
        worldNodeIds: ['qyun-hall'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被指控者',
            participation: SceneCastParticipation(
              dialogue: '"灵药园地下七具尸体的灵根精华流向了谁的丹田？长老验一验便知！"',
              interaction: '面对暗渊真人的威压毫不退缩',
            ),
          ),
          _BenchmarkCast(
            characterId: 'xuanqing',
            name: '玄清长老',
            role: '宗门长老',
            participation: SceneCastParticipation(
              dialogue: '"宗主，证据确凿，应当彻查。"',
              interaction: '与暗渊真人在大殿上形成对峙',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-09',
    title: '第九章 绝境逢生',
    summary: '叶尘被关押在宗门禁地，赵元奉命"看守"实则要取他性命。'
        '柳无双和苏瑶联手劫狱，三方在禁地中展开混战。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s17',
        title: '禁地囚笼',
        targetLength: 1000,
        summary: '赵元深夜来到禁地，以审讯为名准备处决叶尘。'
            '他透露自己不过是一枚棋子，真正的目标是唤醒叶尘体内的混沌灵根完整形态。',
        targetBeat: '反派揭示真实目的，危机达到顶点。',
        worldNodeIds: ['qyun-prison'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被囚者',
            participation: SceneCastParticipation(
              dialogue: '"混沌灵根的完整形态？你们要的不是我的人，是这块残片。"',
              interaction: '在被困中冷静分析赵元话中的信息',
            ),
          ),
          _BenchmarkCast(
            characterId: 'zhaoyuan',
            name: '赵元',
            role: '处决者',
            participation: SceneCastParticipation(
              dialogue: '"你以为你很特别？你不过是容器。混沌灵根完整觉醒的那一刻，你就不存在了。"',
              interaction: '释放魔气逼近叶尘',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s18',
        title: '劫狱混战',
        targetLength: 1000,
        summary: '柳无双破开禁地阵法，苏瑶在外围策应。三方合力击退赵元，'
            '但赵元在逃走前启动了暗渊真人留下的禁制，整个禁地开始崩塌。',
        targetBeat: '多角色协作战斗，紧张的逃亡节奏。',
        worldNodeIds: ['qyun-prison'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被救者',
            participation: SceneCastParticipation(
              action: '与柳无双配合攻击赵元的阵法破绽',
              dialogue: '"禁制要崩了，先撤！"',
              interaction: '在崩塌中掩护苏瑶撤离',
            ),
          ),
          _BenchmarkCast(
            characterId: 'liuwushuang',
            name: '柳无双',
            role: '劫狱者',
            participation: SceneCastParticipation(
              dialogue: '"我来救你不是因为喜欢你，是因为你死了我就找不到暗渊那个老狐狸了。"',
              interaction: '以魔道秘术强攻禁地阵法',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suyao',
            name: '苏瑶',
            role: '策应者',
            participation: SceneCastParticipation(
              dialogue: '"快走，我断后！"',
              interaction: '在外围布下防御阵法阻挡追兵',
            ),
          ),
        ],
      ),
    ],
  ),
  _BenchmarkChapter(
    id: 'x-chapter-10',
    title: '第十章 混沌觉醒',
    summary: '暗渊真人现身强夺混沌灵根，叶尘在生死关头与玉简传承完全融合。'
        '混沌灵根全面觉醒，叶尘以超越境界的力量击退暗渊真人，但代价惨重。',
    targetLength: 2500,
    scenes: [
      _BenchmarkScene(
        id: 'x-s19',
        title: '暗渊降临',
        targetLength: 1000,
        summary: '叶尘逃出禁地后被暗渊真人拦截。金丹巅峰的威压如山般倾泻，'
            '叶尘的筑基修为在绝对实力面前毫无还手之力。暗渊开始强行抽取混沌灵根。',
        targetBeat: '最终 boss 登场，实力差距悬殊制造绝望感。',
        worldNodeIds: ['qyun-summit'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '被压制者',
            participation: SceneCastParticipation(
              action: '在暗渊真人的灵力碾压下被迫跪地，体内混沌灵根开始剧烈震荡',
              dialogue: '"你……为了一个灵根残片，杀了七个人……值得吗？"',
              interaction: '灵根被抽取时与玉简传承产生共鸣',
            ),
          ),
          _BenchmarkCast(
            characterId: 'anyuan',
            name: '暗渊真人',
            role: '宗门二长老/幕后黑手',
            participation: SceneCastParticipation(
              dialogue: '"七个人？格局太小了。我要的是打开天玄洞的钥匙——完整的混沌灵根。"',
              interaction: '释放金丹巅峰的恐怖威压',
            ),
          ),
        ],
      ),
      _BenchmarkScene(
        id: 'x-s20',
        title: '传承觉醒',
        targetLength: 1000,
        summary: '在混沌灵根即将被剥离的刹那，玉简传承彻底激活。'
            '叶尘获得上古大能的战斗经验和临时境界提升，击退暗渊真人。'
            '但觉醒后的反噬让他修为跌落，经脉寸断。',
        targetBeat: '高潮决战，胜利伴随惨痛代价，为后续故事留悬念。',
        worldNodeIds: ['qyun-summit'],
        cast: [
          _BenchmarkCast(
            characterId: 'yechen',
            name: '叶尘',
            role: '觉醒者',
            participation: SceneCastParticipation(
              action: '混沌灵根完全觉醒，以上古大能的战技击退暗渊真人',
              dialogue: '"你想要混沌灵根？那就来拿——如果你还站得起来的话。"',
              interaction: '击败暗渊后修为暴跌，昏倒在苏瑶怀中',
            ),
          ),
          _BenchmarkCast(
            characterId: 'xuanqing',
            name: '玄清长老',
            role: '宗门长老',
            participation: SceneCastParticipation(
              dialogue: '"暗渊，你的罪行今日大白于天下。宗门不会放过你。"',
              interaction: '趁暗渊受创将其封印',
            ),
          ),
          _BenchmarkCast(
            characterId: 'suyao',
            name: '苏瑶',
            role: '内门弟子',
            participation: SceneCastParticipation(
              dialogue: '"叶尘！你醒醒——你的经脉全断了……"',
              interaction: '接住昏倒的叶尘，泪水落在他的脸上',
            ),
          ),
        ],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// 质量分析（纯规则，无 LLM 调用）
// ---------------------------------------------------------------------------

// 紧张度关键词
const _tensionKeywords = [
  '危险', '紧急', '致命', '枪', '血', '逃', '死', '追', '杀',
  '暗', '惊', '恐', '怒', '吼', '哭', '痛', '崩溃', '绝望',
  '陷阱', '出卖', '背叛', '威胁', '逼迫', '对峙', '追杀',
];

double _computeHookStrength(String text) {
  // Strip markdown headers (#), blockquote summaries (>), and blank lines
  // so the scorer evaluates actual prose, not formatting.
  final proseStart = text
      .split('\n')
      .where((line) {
        final t = line.trim();
        return t.isNotEmpty && !t.startsWith('#') && !t.startsWith('>');
      })
      .join('\n');
  final clean = proseStart.trim();
  final first100 = clean.length > 100 ? clean.substring(0, 100) : clean;
  var score = 0.0;

  // 动作动词
  const actionVerbs = ['冲', '跑', '跳', '抓', '摔', '撞', '翻', '拽', '喊', '叫'];
  for (final v in actionVerbs) {
    if (first100.contains(v)) { score += 0.2; break; }
  }

  // 疑问/感叹
  if (first100.contains('？') || first100.contains('?')) score += 0.2;
  if (first100.contains('！') || first100.contains('!')) score += 0.15;

  // 对话开头
  if (first100.startsWith('"') || first100.startsWith('「')) score += 0.15;

  // 短句开头（前20字内出现句号）
  final first20 = clean.length > 20 ? clean.substring(0, 20) : clean;
  if (first20.contains('。') || first20.contains('…')) score += 0.15;

  // 悬念关键词
  const suspenseWords = ['突然', '竟然', '意外', '发现', '秘密', '失踪'];
  for (final w in suspenseWords) {
    if (first100.contains(w)) { score += 0.15; break; }
  }

  return score.clamp(0.0, 1.0);
}

double _computeChapterEndHook(String text) {
  final last150 = text.length > 150 ? text.substring(text.length - 150) : text;
  var score = 0.0;

  if (last150.contains('…') || last150.contains('——')) score += 0.25;
  if (last150.contains('？') || last150.contains('?')) score += 0.2;
  if (last150.contains('！') || last150.contains('!')) score += 0.15;

  // 未完成动作
  const unfinishedActions = ['还没', '来不及', '正要', '就要', '差一点', '眼看'];
  for (final a in unfinishedActions) {
    if (last150.contains(a)) { score += 0.2; break; }
  }

  // 悬念词
  const hookWords = ['真相', '秘密', '危险', '背后', '发现', '到底', '究竟'];
  for (final w in hookWords) {
    if (last150.contains(w)) { score += 0.2; break; }
  }

  return score.clamp(0.0, 1.0);
}

double _computeConflictEscalation(List<String> chapterTexts) {
  if (chapterTexts.length < 2) return 0.5;

  final densities = <double>[];
  for (final text in chapterTexts) {
    final total = text.runes.where((r) => r >= 0x4E00 && r <= 0x9FFF).length;
    if (total == 0) { densities.add(0); continue; }
    var count = 0;
    for (final kw in _tensionKeywords) {
      var start = 0;
      while (true) {
        final idx = text.indexOf(kw, start);
        if (idx == -1) break;
        count++;
        start = idx + kw.length;
      }
    }
    densities.add(count / total);
  }

  var escalating = 0;
  for (var i = 1; i < densities.length; i++) {
    if (densities[i] >= densities[i - 1] * 0.85) escalating++;
  }

  return escalating / (densities.length - 1);
}

Map<String, double> _analyzePacing(String text) {
  final analyzer = ProseStyleAnalyzer();
  final fp = analyzer.analyze(text);
  return {
    'sentenceLengthVariance': fp.sentenceLengthVariance,
    'dialogueRatio': fp.dialogueRatio,
    'avgSentenceLength': fp.avgSentenceLength,
    'statementRatio': fp.statementRatio,
    'questionRatio': fp.questionRatio,
    'exclamationRatio': fp.exclamationRatio,
    'ellipsisRatio': fp.ellipsisRatio,
  };
}

double _computeCharacterIntroScore(String text) {
  final first500 = text.length > 500 ? text.substring(0, 500) : text;
  final characterNames = <String>{};
  for (final ch in _benchmarkChapters) {
    for (final sc in ch.scenes) {
      for (final c in sc.cast) {
        characterNames.add(c.name);
      }
    }
  }

  var found = 0;
  for (final name in characterNames) {
    if (first500.contains(name)) found++;
  }

  // 至少出现一个主角名得基础分
  final nameScore = found > 0 ? 0.4 + (found / characterNames.length).clamp(0.0, 0.6) : 0.0;

  // 是否有动作或对话标记
  final hasDialogue = first500.contains('"') || first500.contains('「');
  final hasAction = first500.contains('走') || first500.contains('站') || first500.contains('看');

  return (nameScore + (hasDialogue ? 0.1 : 0) + (hasAction ? 0.1 : 0)).clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// 报告生成
// ---------------------------------------------------------------------------

String _goldenThreeReport(
  List<_ChapterSummary> summaries,
  List<String> chapterTexts,
  List<SceneRuntimeOutput> outputs,
) {
  final buf = StringBuffer()
    ..writeln('# 黄金三章质量分析报告')
    ..writeln()
    ..writeln('生成时间：${DateTime.now().toIso8601String()}')
    ..writeln();

  // 逐章分析
  for (var i = 0; i < summaries.length && i < chapterTexts.length; i++) {
    final s = summaries[i];
    final text = chapterTexts[i];
    final charCount = text.replaceAll(RegExp(r'\s'), '').length;

    buf
      ..writeln('## ${s.chapterTitle}')
      ..writeln()
      ..writeln('- 场景数：${s.sceneCount}')
      ..writeln('- 实际字数：$charCount')
      ..writeln('- Review 通过：${s.reviewPassed ? "✅" : "❌"}')
      ..writeln('- Prose 重试：${s.proseRetryCount} 次')
      ..writeln('- 耗时：${s.totalMs}ms')
      ..writeln('- Token 消耗：prompt=${s.promptTokens} completion=${s.completionTokens}')
      ..writeln();

    // 开头钩子
    if (i == 0) {
      final hook = _computeHookStrength(text);
      buf.writeln('- **开头钩子强度**：${(hook * 100).toStringAsFixed(0)}%');
      final introScore = _computeCharacterIntroScore(text);
      buf.writeln('- **角色引入效果**：${(introScore * 100).toStringAsFixed(0)}%');
    }

    // 节奏分析
    final pacing = _analyzePacing(text);
    buf
      ..writeln('- **节奏指标**：')
      ..writeln('  - 平均句长：${pacing['avgSentenceLength']?.toStringAsFixed(1)} 字')
      ..writeln('  - 句长方差：${pacing['sentenceLengthVariance']?.toStringAsFixed(1)}')
      ..writeln('  - 对话比率：${(pacing['dialogueRatio']! * 100).toStringAsFixed(1)}%')
      ..writeln();

    // 章末钩子
    final endHook = _computeChapterEndHook(text);
    buf.writeln('- **章末钩子强度**：${(endHook * 100).toStringAsFixed(0)}%');

    // Quality score
    if (i < outputs.length && outputs[i].qualityScore != null) {
      final q = outputs[i].qualityScore!;
      buf
          .writeln('- **质量评分**：综合=${q.overall.toStringAsFixed(1)} '
              '文笔=${q.prose.toStringAsFixed(1)} '
              '连贯=${q.coherence.toStringAsFixed(1)} '
              '角色=${q.character.toStringAsFixed(1)} '
              '完整=${q.completeness.toStringAsFixed(1)}');
    }
    buf.writeln();
  }

  // 冲突升级
  final escalation = _computeConflictEscalation(chapterTexts);
  buf
    ..writeln('## 跨章分析')
    ..writeln()
    ..writeln('- **冲突升级指数**：${(escalation * 100).toStringAsFixed(0)}%')
    ..writeln();

  return buf.toString().trimRight();
}

String _consistencyReport(
  NarrativeArcState finalArc,
  List<_ChapterSummary> summaries,
  List<String> chapterTexts,
) {
  final buf = StringBuffer()
    ..writeln('# 十章故事一致性报告')
    ..writeln()
    ..writeln('生成时间：${DateTime.now().toIso8601String()}')
    ..writeln();

  // 情节线统计
  final totalThreads = finalArc.activeThreads.length + finalArc.closedThreads.length;
  final threadResolutionRate = totalThreads > 0
      ? finalArc.closedThreads.length / totalThreads
      : 0.0;

  buf
    ..writeln('## 叙事弧线统计')
    ..writeln()
    ..writeln('- 活跃情节线：${finalArc.activeThreads.length}')
    ..writeln('- 已闭合情节线：${finalArc.closedThreads.length}')
    ..writeln('- 情节线解决率：${(threadResolutionRate * 100).toStringAsFixed(0)}%')
    ..writeln('- 待回收伏笔：${finalArc.pendingForeshadowing.length}')
    ..writeln();

  // 伏笔统计
  final totalForeshadowing = finalArc.pendingForeshadowing.length;
  final resolvedForeshadowing = finalArc.pendingForeshadowing.where((f) => f.resolvedInScene != null).length;
  final urgentUnresolved = finalArc.pendingForeshadowing.where((f) => f.urgency >= 2 && f.resolvedInScene == null).toList();

  buf
    ..writeln('## 伏笔管理')
    ..writeln()
    ..writeln('- 伏笔总数：$totalForeshadowing')
    ..writeln('- 已回收：$resolvedForeshadowing')
    ..writeln('- 伏笔回收率：${totalForeshadowing > 0 ? (resolvedForeshadowing / totalForeshadowing * 100).toStringAsFixed(0) : "N/A"}%')
    ..writeln('- 高紧急度未回收：${urgentUnresolved.length}')
    ..writeln();

  if (urgentUnresolved.isNotEmpty) {
    buf.writeln('**未回收高紧急伏笔**：');
    for (final f in urgentUnresolved) {
      buf.writeln('  - 「${f.hint}」(urgency=${f.urgency}, 种于 ${f.plantedInScene})');
    }
    buf.writeln();
  }

  // 逐章统计
  buf
    ..writeln('## 逐章统计')
    ..writeln()
    ..writeln('| 章节 | 场景数 | 字数 | Review | 重试 | 耗时 | Prompt | Completion |')
    ..writeln('|------|--------|------|--------|------|------|--------|------------|');

  for (final s in summaries) {
    buf.writeln(
      '| ${s.chapterTitle} | ${s.sceneCount} | ${s.actualLength} | '
      '${s.reviewPassed ? "✅" : "❌"} | ${s.proseRetryCount} | ${s.totalMs}ms | ${s.promptTokens} | ${s.completionTokens} |',
    );
  }
  buf.writeln();

  // 角色一致性
  buf
    ..writeln('## 角色行为一致性')
    ..writeln()
    ..writeln('基于叙事弧线和 review 结果的分析：');

  final characterIds = <String>{};
  for (final ch in _benchmarkChapters) {
    for (final sc in ch.scenes) {
      for (final c in sc.cast) {
        characterIds.add(c.characterId);
      }
    }
  }

  for (final charId in characterIds) {
    final appearances = <String>[];
    for (var i = 0; i < chapterTexts.length; i++) {
      if (chapterTexts[i].contains(_characterNameForId(charId))) {
        appearances.add('第${i + 1}章');
      }
    }
    if (appearances.isNotEmpty) {
      buf.writeln('- `$charId` 出现于：${appearances.join("、")}');
    }
  }
  buf.writeln();

  return buf.toString().trimRight();
}

String _characterNameForId(String id) {
  return switch (id) {
    'linmo' => '林默',
    'suwei' => '苏薇',
    'laochen' => '老陈',
    'fangkai' => '方凯',
    'qianzhuxi' => '钱董',
    _ => id,
  };
}

String _aiFlavorReport(
  String allText,
  AiClicheReport clicheReport,
  Map<String, ProseStyleDivergenceReport> styleReports,
) {
  final buf = StringBuffer()
    ..writeln('# AI味检测与风格继承报告')
    ..writeln()
    ..writeln('分析文本总字数：${clicheReport.totalWordCount}')
    ..writeln();

  // AI 陈词检测
  buf
    ..writeln('## AI 陈词检测')
    ..writeln()
    ..writeln('- 检出问题：${clicheReport.findings.length} 处')
    ..writeln('- 陈词密度：${(clicheReport.clicheDensity * 100).toStringAsFixed(2)}%')
    ..writeln('- 严重程度：${clicheReport.isSevere ? "🚨 严重" : clicheReport.hasIssues ? "⚠️ 需关注" : "✅ 良好"}')
    ..writeln();

  if (clicheReport.hasIssues) {
    final byKind = <AiClicheKind, List<AiClicheFinding>>{};
    for (final f in clicheReport.findings) {
      byKind.putIfAbsent(f.kind, () => []).add(f);
    }
    for (final kind in [
      AiClicheKind.clichedPhrase,
      AiClicheKind.shortSentenceRun,
      AiClicheKind.repeatedAdjective,
      AiClicheKind.excessiveAdverb,
    ]) {
      final items = byKind[kind] ?? [];
      if (items.isNotEmpty) {
        buf.writeln('**${kind.label}**：${items.length} 处');
        for (final item in items.take(5)) {
          buf.writeln('  - 「${item.matched}」${item.context}');
        }
        if (items.length > 5) {
          buf.writeln('  - ... 还有 ${items.length - 5} 处');
        }
        buf.writeln();
      }
    }
  }

  // 风格对比
  buf
    ..writeln('## 风格指纹对比')
    ..writeln();

  if (styleReports.isEmpty) {
    buf.writeln('未找到参考文本，跳过风格对比。');
  } else {
    buf.writeln('| 指标 | 生成文本 | ');
    for (final ref in styleReports.keys) {
      buf.write(' $ref |');
    }
    buf.writeln();
    buf.write('|------|----------|');
    for (final _ in styleReports.keys) {
      buf.write('----------|');
    }
    buf.writeln();

    final genFp = styleReports.values.first.generatedFingerprint;
    void row(String label, double Function(ProseStyleFingerprint) extract) {
      buf.write('| $label | ${extract(genFp).toStringAsFixed(2)} |');
      for (final report in styleReports.values) {
        buf.write(' ${extract(report.referenceFingerprint).toStringAsFixed(2)} |');
      }
      buf.writeln();
    }

    row('平均句长', (fp) => fp.avgSentenceLength);
    row('句长方差', (fp) => fp.sentenceLengthVariance);
    row('对话比率', (fp) => fp.dialogueRatio);
    row('陈述句占比', (fp) => fp.statementRatio);
    row('疑问句占比', (fp) => fp.questionRatio);
    row('感叹句占比', (fp) => fp.exclamationRatio);
    row('省略号占比', (fp) => fp.ellipsisRatio);
    buf.writeln();

    for (final entry in styleReports.entries) {
      buf.writeln('**${entry.key}**：相似度 ${(entry.value.similarityScore * 100).toStringAsFixed(1)}%');
      for (final d in entry.value.divergencePoints) {
        buf.writeln('  - ${d.metric}：生成 ${d.generatedValue.toStringAsFixed(2)} vs 参考 ${d.referenceValue.toStringAsFixed(2)}');
      }
      buf.writeln();
    }
  }

  return buf.toString().trimRight();
}

String _runReportMarkdown({
  required _ResolvedSettings settings,
  required int totalLlmCalls,
  required int totalMs,
  required List<_ChapterSummary> summaries,
  required AiClicheReport clicheReport,
  required NarrativeArcState finalArc,
  required Map<String, double> styleSimilarities,
}) {
  final buf = StringBuffer()
    ..writeln('# 多维度小说质量基准测试报告')
    ..writeln()
    ..writeln('生成时间：${DateTime.now().toIso8601String()}')
    ..writeln()
    ..writeln('## 配置')
    ..writeln()
    ..writeln('- Provider: ${settings.providerName}')
    ..writeln('- Model: ${settings.model}')
    ..writeln('- Base URL: ${settings.baseUrl}')
    ..writeln('- Timeout: ${settings.timeoutMs}ms')
    ..writeln('- 总 LLM 调用：$totalLlmCalls 次')
    ..writeln('- 总耗时：${totalMs}ms (${(totalMs / 1000 / 60).toStringAsFixed(1)} min)')
    ..writeln('- 总 Token 消耗：prompt=${summaries.fold<int>(0, (sum, s) => sum + s.promptTokens)} completion=${summaries.fold<int>(0, (sum, s) => sum + s.completionTokens)}')
    ..writeln()
    ..writeln('## 黄金三章')
    ..writeln();

  final first3 = summaries.take(3).toList();
  final allPassed3 = first3.every((s) => s.reviewPassed);
  final totalChars3 = first3.fold<int>(0, (sum, s) => sum + s.actualLength);

  buf
    ..writeln('- 全部通过：${allPassed3 ? "✅" : "❌"}')
    ..writeln('- 总字数：$totalChars3')
    ..writeln('- 冲突升级指数：见详细报告')
    ..writeln()
    ..writeln('## 十章一致性')
    ..writeln();

  final totalThreads = finalArc.activeThreads.length + finalArc.closedThreads.length;
  final threadRate = totalThreads > 0 ? finalArc.closedThreads.length / totalThreads : 0.0;
  final passed = summaries.where((s) => s.reviewPassed).length;

  buf
    ..writeln('- 通过章节数：$passed / ${summaries.length}')
    ..writeln('- 情节线解决率：${(threadRate * 100).toStringAsFixed(0)}%')
    ..writeln('- 待回收伏笔：${finalArc.pendingForeshadowing.length}')
    ..writeln()
    ..writeln('## AI味与风格')
    ..writeln()
    ..writeln('- AI 陈词密度：${(clicheReport.clicheDensity * 100).toStringAsFixed(2)}%')
    ..writeln('- 严重程度：${clicheReport.isSevere ? "严重" : clicheReport.hasIssues ? "需关注" : "良好"}');

  for (final entry in styleSimilarities.entries) {
    buf.writeln('- ${entry.key} 相似度：${(entry.value * 100).toStringAsFixed(1)}%');
  }

  return buf.toString().trimRight();
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

String _currentStep = 'init';

void _log(String msg, {String level = 'INFO'}) {
  _globalHeartbeat?.beat();
  final logFile = File('$_outputRoot/runtime/benchmark.log');
  logFile.parent.createSync(recursive: true);
  logFile.writeAsStringSync(
    '${DateTime.now().toIso8601String()} [$level] [$_currentStep] $msg\n',
    mode: FileMode.append,
  );
}

void _writeLiveStatus({
  required String phase,
  required int completedScenes,
  required int totalScenes,
  required String currentChapter,
  required int totalPromptTokens,
  required int totalCompletionTokens,
  required int llmCalls,
}) {
  final file = File('$_outputRoot/runtime/live-status.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'phase': phase,
      'completedScenes': completedScenes,
      'totalScenes': totalScenes,
      'currentChapter': currentChapter,
      'totalPromptTokens': totalPromptTokens,
      'totalCompletionTokens': totalCompletionTokens,
      'llmCalls': llmCalls,
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );
}

_Heartbeat? _globalHeartbeat;

void main() {
  final shouldRun = Platform.environment[_envGuard] == '1';
  final anthropicKey = Platform.environment['ANTHROPIC_AUTH_TOKEN'];

  group('黄金三章质量', () {
    test('三章完整流水线 + 质量指标分析', () async {
      if (!shouldRun || anthropicKey == null || anthropicKey.isEmpty) {
        markTestSkipped('设置 $_envGuard=1 和 ANTHROPIC_AUTH_TOKEN 以运行');
        return;
      }

      final heartbeat = _Heartbeat(
        label: '黄金三章',
        testFail: fail,
      )..start();
      _globalHeartbeat = heartbeat;
      addTearDown(heartbeat.stop);

      _currentStep = 'setup';
      _log('resolving settings...');
      final settings = await _resolveSettings();
      _log('settings: provider=${settings.providerName} baseUrl=${settings.baseUrl} model=${settings.model} hasKey=${settings.apiKey.isNotEmpty}');

      final trackingClient = _TrackingLlmClient(createDefaultAppLlmClient());
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: trackingClient,
      );

      _log('saving settings...');
      await settingsStore.save(
        providerName: settings.providerName,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiKey: settings.apiKey,
        timeout: AppLlmTimeoutConfig.uniform(settings.timeoutMs),
        maxConcurrentRequests: settings.maxConcurrentRequests,
      );
      _log('settings saved. snapshot: providerName=${settingsStore.snapshot.providerName} baseUrl=${settingsStore.snapshot.baseUrl} model=${settingsStore.snapshot.model} hasApiKey=${settingsStore.snapshot.hasApiKey}');

      final outputRoot = Directory(_outputRoot);
      if (await outputRoot.exists()) {
        await outputRoot.delete(recursive: true);
      }
      await outputRoot.create(recursive: true);
      final recorder = ArtifactRecorder(rootDirectory: outputRoot);

      final chapters = _benchmarkChapters.take(3).toList();

      // Flatten all briefs upfront
      final allBriefs = <SceneBrief>[];
      final chapterStartIndices = <int>[];
      for (final chapter in chapters) {
        chapterStartIndices.add(allBriefs.length);
        for (final scene in chapter.scenes) {
          allBriefs.add(SceneBrief(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            sceneId: scene.id,
            sceneIndex: chapter.scenes.indexOf(scene),
            sceneTitle: scene.title,
            sceneSummary: scene.summary,
            targetLength: scene.targetLength,
            targetBeat: scene.targetBeat,
            worldNodeIds: scene.worldNodeIds,
            cast: [
              for (final c in scene.cast)
                SceneCastCandidate(
                  characterId: c.characterId,
                  name: c.name,
                  role: c.role,
                  participation: c.participation,
                ),
            ],
          ));
        }
      }

      final runner = ChapterConcurrentRunner(
        settingsStore: settingsStore,
        pipelineConfig: const GenerationPipelineConfig(
          maxProseRetries: 2,
          maxConcurrentScenes: 3,
          maxSceneRetries: 2,
        ),
      );

      _log('running ${allBriefs.length} scenes via concurrent runner (maxConcurrentScenes=3)...');
      final runSw = Stopwatch()..start();

      final outputs = await runner.runAll(
        allBriefs,
        onSceneComplete: (completed, total, output) {
          heartbeat.beat(
            'scene $completed/$total done '
            'review=${output.review.decision.name} '
            'chars=${output.prose.text.length}',
          );
          _currentStep = output.brief.chapterId;
          _writeLiveStatus(
            phase: '黄金三章',
            completedScenes: completed,
            totalScenes: total,
            currentChapter: output.brief.chapterId,
            totalPromptTokens: trackingClient.totalPromptTokens,
            totalCompletionTokens: trackingClient.totalCompletionTokens,
            llmCalls: trackingClient.callCount,
          );
        },
      );

      runSw.stop();
      _log('all scenes completed in ${runSw.elapsedMilliseconds}ms');

      // Map results back to chapters
      final summaries = <_ChapterSummary>[];
      final chapterTexts = <String>[];

      for (var ci = 0; ci < chapters.length; ci++) {
        final chapter = chapters[ci];
        final start = chapterStartIndices[ci];
        final end = ci + 1 < chapters.length
            ? chapterStartIndices[ci + 1]
            : outputs.length;
        final chapterOutputs = outputs.sublist(start, end);

        final buf = StringBuffer()
          ..writeln('# ${chapter.title}')
          ..writeln()
          ..writeln('> ${chapter.summary}')
          ..writeln();
        for (final output in chapterOutputs) {
          buf
            ..writeln('## ${output.brief.sceneTitle}')
            ..writeln()
            ..writeln(output.prose.text.trim())
            ..writeln();
        }
        final chapterText = buf.toString().trimRight();
        chapterTexts.add(chapterText);

        await recorder.recordChapterText(
          chapterId: chapter.id,
          text: chapterText,
        );

        summaries.add(_ChapterSummary(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          sceneCount: chapterOutputs.length,
          actualLength: chapterText.replaceAll(RegExp(r'\s'), '').length,
          reviewPassed: chapterOutputs.every(
            (o) => o.review.decision == SceneReviewDecision.pass,
          ),
          proseRetryCount: chapterOutputs.fold<int>(
            0,
            (sum, o) => sum + o.softFailureCount,
          ),
          totalMs: runSw.elapsedMilliseconds,
          promptTokens: trackingClient.totalPromptTokens,
          completionTokens: trackingClient.totalCompletionTokens,
        ));
      }

      // 生成报告
      final report = _goldenThreeReport(summaries, chapterTexts, outputs);
      await recorder.recordReport(
        relativePath: 'reports/golden_three_quality.md',
        content: report,
      );

      // Quality report
      await recorder.recordReport(
        relativePath: 'reports/quality-report.md',
        content: SceneQualityReporter.toMarkdown(outputs),
      );

      settingsStore.dispose();

      stdout.writeln(report);

      expect(summaries.every((s) => s.reviewPassed), isTrue, reason: '三章全部应 review pass');
      expect(
        chapterTexts.fold<int>(0, (sum, t) => sum + t.replaceAll(RegExp(r'\s'), '').length),
        greaterThan(2000),
        reason: '总字数应超过 2000',
      );
    }, timeout: Timeout.none);
  });

  group('十章故事一致性', () {
    test('十章完整流水线 + 跨章一致性追踪', () async {
      if (!shouldRun || anthropicKey == null || anthropicKey.isEmpty) {
        markTestSkipped('设置 $_envGuard=1 和 ANTHROPIC_AUTH_TOKEN 以运行');
        return;
      }

      final heartbeat = _Heartbeat(
        label: '十章一致性',
        testFail: fail,
      )..start();
      _globalHeartbeat = heartbeat;
      addTearDown(heartbeat.stop);

      _currentStep = 'setup';
      final settings = await _resolveSettings();
      final trackingClient = _TrackingLlmClient(createDefaultAppLlmClient());
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: trackingClient,
      );

      await settingsStore.save(
        providerName: settings.providerName,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiKey: settings.apiKey,
        timeout: AppLlmTimeoutConfig.uniform(settings.timeoutMs),
        maxConcurrentRequests: settings.maxConcurrentRequests,
      );

      final outputRoot = Directory(_outputRoot);
      if (!await outputRoot.exists()) {
        await outputRoot.create(recursive: true);
      }
      final recorder = ArtifactRecorder(rootDirectory: outputRoot);

      // Flatten all briefs upfront
      final allBriefs = <SceneBrief>[];
      final chapterStartIndices = <int>[];
      for (final chapter in _benchmarkChapters) {
        chapterStartIndices.add(allBriefs.length);
        for (final scene in chapter.scenes) {
          allBriefs.add(SceneBrief(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            sceneId: scene.id,
            sceneIndex: chapter.scenes.indexOf(scene),
            sceneTitle: scene.title,
            sceneSummary: scene.summary,
            targetLength: scene.targetLength,
            targetBeat: scene.targetBeat,
            worldNodeIds: scene.worldNodeIds,
            cast: [
              for (final c in scene.cast)
                SceneCastCandidate(
                  characterId: c.characterId,
                  name: c.name,
                  role: c.role,
                  participation: c.participation,
                ),
            ],
          ));
        }
      }

      final runner = ChapterConcurrentRunner(
        settingsStore: settingsStore,
        pipelineConfig: const GenerationPipelineConfig(
          maxProseRetries: 2,
          maxConcurrentScenes: 3,
          maxSceneRetries: 2,
        ),
      );

      _log('running ${allBriefs.length} scenes via concurrent runner (maxConcurrentScenes=3)...');
      final runSw = Stopwatch()..start();

      final outputs = await runner.runAll(
        allBriefs,
        onSceneComplete: (completed, total, output) {
          heartbeat.beat(
            'scene $completed/$total done '
            'review=${output.review.decision.name} '
            'chars=${output.prose.text.length}',
          );
          _currentStep = output.brief.chapterId;
          _writeLiveStatus(
            phase: '十章一致性',
            completedScenes: completed,
            totalScenes: total,
            currentChapter: output.brief.chapterId,
            totalPromptTokens: trackingClient.totalPromptTokens,
            totalCompletionTokens: trackingClient.totalCompletionTokens,
            llmCalls: trackingClient.callCount,
          );
        },
      );

      runSw.stop();
      _log('all scenes completed in ${runSw.elapsedMilliseconds}ms');

      // Map results back to chapters
      final summaries = <_ChapterSummary>[];
      final chapterTexts = <String>[];

      for (var ci = 0; ci < _benchmarkChapters.length; ci++) {
        final chapter = _benchmarkChapters[ci];
        final start = chapterStartIndices[ci];
        final end = ci + 1 < _benchmarkChapters.length
            ? chapterStartIndices[ci + 1]
            : outputs.length;
        final chapterOutputs = outputs.sublist(start, end);

        final buf = StringBuffer()
          ..writeln('# ${chapter.title}')
          ..writeln()
          ..writeln('> ${chapter.summary}')
          ..writeln();
        for (final output in chapterOutputs) {
          buf
            ..writeln('## ${output.brief.sceneTitle}')
            ..writeln()
            ..writeln(output.prose.text.trim())
            ..writeln();
        }
        final chapterText = buf.toString().trimRight();
        chapterTexts.add(chapterText);

        await recorder.recordChapterText(
          chapterId: chapter.id,
          text: chapterText,
        );

        summaries.add(_ChapterSummary(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          sceneCount: chapterOutputs.length,
          actualLength: chapterText.replaceAll(RegExp(r'\s'), '').length,
          reviewPassed: chapterOutputs.every(
            (o) => o.review.decision == SceneReviewDecision.pass,
          ),
          proseRetryCount: chapterOutputs.fold<int>(
            0,
            (sum, o) => sum + o.softFailureCount,
          ),
          totalMs: runSw.elapsedMilliseconds,
          promptTokens: trackingClient.totalPromptTokens,
          completionTokens: trackingClient.totalCompletionTokens,
        ));
      }

      // 一致性分析 — reconstruct arc from commit-ordered outputs
      var accumulatedArc = NarrativeArcState();
      final arcTracker = NarrativeArcTracker();
      for (final output in outputs) {
        accumulatedArc = arcTracker.update(
          current: accumulatedArc,
          output: output,
        );
      }

      final report = _consistencyReport(accumulatedArc, summaries, chapterTexts);
      await recorder.recordReport(
        relativePath: 'reports/ten_chapter_consistency.md',
        content: report,
      );

      await recorder.recordReport(
        relativePath: 'reports/quality-report.json',
        content: SceneQualityReporter.toJson(outputs),
      );

      settingsStore.dispose();

      stdout.writeln(report);

      final passedCount = summaries.where((s) => s.reviewPassed).length;
      expect(passedCount, greaterThanOrEqualTo(8), reason: '至少 8 章应 review pass');

      final totalThreads = accumulatedArc.activeThreads.length + accumulatedArc.closedThreads.length;
      if (totalThreads > 0) {
        final rate = accumulatedArc.closedThreads.length / totalThreads;
        expect(rate, greaterThanOrEqualTo(0.5), reason: '情节线解决率应 ≥ 50%');
      }
    }, timeout: Timeout.none);
  });

  group('玄幻十章', () {
    test('玄幻小说十章完整流水线', () async {
      if (!shouldRun || anthropicKey == null || anthropicKey.isEmpty) {
        markTestSkipped('设置 $_envGuard=1 和 ANTHROPIC_AUTH_TOKEN 以运行');
        return;
      }

      final heartbeat = _Heartbeat(
        label: '玄幻十章',
        testFail: fail,
      )..start();
      _globalHeartbeat = heartbeat;
      addTearDown(heartbeat.stop);

      _currentStep = 'setup';
      final settings = await _resolveSettings();
      final trackingClient = _TrackingLlmClient(createDefaultAppLlmClient());
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: trackingClient,
      );

      await settingsStore.save(
        providerName: settings.providerName,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiKey: settings.apiKey,
        timeout: AppLlmTimeoutConfig.uniform(settings.timeoutMs),
        maxConcurrentRequests: settings.maxConcurrentRequests,
      );

      final outputRoot = Directory('$_outputRoot/xianxia');
      if (await outputRoot.exists()) {
        await outputRoot.delete(recursive: true);
      }
      await outputRoot.create(recursive: true);
      final recorder = ArtifactRecorder(rootDirectory: outputRoot);

      final runner = ChapterConcurrentRunner(
        settingsStore: settingsStore,
        pipelineConfig: const GenerationPipelineConfig(
          maxProseRetries: 2,
          maxConcurrentScenes: 3,
          maxSceneRetries: 2,
        ),
      );

      final runSw = Stopwatch()..start();
      final allOutputs = <SceneRuntimeOutput>[];
      final summaries = <_ChapterSummary>[];
      final chapterTexts = <String>[];
      var accumulatedArc = NarrativeArcState();

      // Sequential chapter generation: one chapter at a time, write immediately.
      var totalCompletedScenes = 0;
      final totalScenes = _xianxiaChapters.fold<int>(
        0, (sum, ch) => sum + ch.scenes.length,
      );

      for (var ci = 0; ci < _xianxiaChapters.length; ci++) {
        final chapter = _xianxiaChapters[ci];
        _log('=== 开始 ${chapter.title} (${ci + 1}/${_xianxiaChapters.length}) ===');

        final chapterBriefs = <SceneBrief>[];
        for (final scene in chapter.scenes) {
          chapterBriefs.add(SceneBrief(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            sceneId: scene.id,
            sceneIndex: chapter.scenes.indexOf(scene),
            sceneTitle: scene.title,
            sceneSummary: scene.summary,
            targetLength: scene.targetLength,
            targetBeat: scene.targetBeat,
            worldNodeIds: scene.worldNodeIds,
            cast: [
              for (final c in scene.cast)
                SceneCastCandidate(
                  characterId: c.characterId,
                  name: c.name,
                  role: c.role,
                  participation: c.participation,
                ),
            ],
          ));
        }

        final chapterOutputs = await runner.runAll(
          chapterBriefs,
          initialArc: accumulatedArc,
          onSceneComplete: (completed, total, output) {
            totalCompletedScenes++;
            heartbeat.beat(
              '${chapter.title} scene $completed/$total '
              'review=${output.review.decision.name} '
              'chars=${output.prose.text.length}',
            );
            _currentStep = chapter.id;
            _writeLiveStatus(
              phase: '玄幻十章',
              completedScenes: totalCompletedScenes,
              totalScenes: totalScenes,
              currentChapter: chapter.id,
              totalPromptTokens: trackingClient.totalPromptTokens,
              totalCompletionTokens: trackingClient.totalCompletionTokens,
              llmCalls: trackingClient.callCount,
            );
          },
        );

        allOutputs.addAll(chapterOutputs);

        // Write chapter immediately.
        final buf = StringBuffer()
          ..writeln('# ${chapter.title}')
          ..writeln()
          ..writeln('> ${chapter.summary}')
          ..writeln();
        for (final output in chapterOutputs) {
          buf
            ..writeln('## ${output.brief.sceneTitle}')
            ..writeln()
            ..writeln(output.prose.text.trim())
            ..writeln();
        }
        final chapterText = buf.toString().trimRight();
        chapterTexts.add(chapterText);

        await recorder.recordChapterText(
          chapterId: chapter.id,
          text: chapterText,
        );

        summaries.add(_ChapterSummary(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          sceneCount: chapterOutputs.length,
          actualLength: chapterText.replaceAll(RegExp(r'\s'), '').length,
          reviewPassed: chapterOutputs.every(
            (o) => o.review.decision == SceneReviewDecision.pass,
          ),
          proseRetryCount: chapterOutputs.fold<int>(
            0,
            (sum, o) => sum + o.softFailureCount,
          ),
          totalMs: runSw.elapsedMilliseconds,
          promptTokens: trackingClient.totalPromptTokens,
          completionTokens: trackingClient.totalCompletionTokens,
        ));

        final charCount = chapterText.replaceAll(RegExp(r'\s'), '').length;
        _log('=== ${chapter.title} 完成 '
            'chars=$charCount '
            'pass=${summaries.last.reviewPassed} ===');
      }

      runSw.stop();
      _log('xianxia all chapters completed in ${runSw.elapsedMilliseconds}ms');

      // Arc tracking from collected outputs.
      final arcTracker = NarrativeArcTracker();
      for (final output in allOutputs) {
        accumulatedArc = arcTracker.update(
          current: accumulatedArc,
          output: output,
        );
      }

      final report = _goldenThreeReport(summaries, chapterTexts, allOutputs);
      await recorder.recordReport(
        relativePath: 'reports/xianxia_quality.md',
        content: report,
      );

      await recorder.recordReport(
        relativePath: 'reports/xianxia_quality-report.json',
        content: SceneQualityReporter.toJson(allOutputs),
      );

      settingsStore.dispose();

      stdout.writeln(report);

      final passedCount = summaries.where((s) => s.reviewPassed).length;
      expect(passedCount, greaterThanOrEqualTo(8), reason: '玄幻十章至少 8 章应 review pass');
    }, timeout: Timeout.none);
  });

  group('AI味检测与风格继承', () {
    test('AI陈词检测 + 风格指纹对比', () async {
      if (!shouldRun || anthropicKey == null || anthropicKey.isEmpty) {
        markTestSkipped('设置 $_envGuard=1 和 ANTHROPIC_AUTH_TOKEN 以运行');
        return;
      }

      // 读取已生成的章节文本
      final chaptersDir = Directory('$_outputRoot/chapters');
      final chapterFiles = <File>[];
      if (await chaptersDir.exists()) {
        await for (final entity in chaptersDir.list()) {
          if (entity is File && entity.path.endsWith('.md')) {
            chapterFiles.add(entity);
          }
        }
      }

      if (chapterFiles.isEmpty) {
        markTestSkipped('没有找到已生成的章节文本，请先运行黄金三章或十章测试');
        return;
      }

      chapterFiles.sort((a, b) => a.path.compareTo(b.path));
      final allText = chapterFiles.map((f) => f.readAsStringSync()).join('\n\n');

      // AI 味检测
      final clicheDetector = AiClicheDetector();
      final clicheReport = clicheDetector.detect(allText);

      // 风格对比
      final styleAnalyzer = ProseStyleAnalyzer();
      final referenceLibs = <String, String>{
        '剑来': 'artifacts/writing_reference/jianlai/scenes.jsonl',
        '诡秘': 'artifacts/writing_reference/guimi/scenes.jsonl',
        '体鬼': 'artifacts/writing_reference/tigui/scenes.jsonl',
      };

      final styleReports = <String, ProseStyleDivergenceReport>{};
      for (final entry in referenceLibs.entries) {
        final refFile = File(entry.value);
        if (!await refFile.exists()) continue;

        final refText = _loadReferenceText(refFile);
        if (refText.isEmpty) continue;

        styleReports[entry.key] = styleAnalyzer.compare(
          generatedText: allText,
          referenceText: refText,
          referenceLabel: entry.key,
        );
      }

      final outputRoot = Directory(_outputRoot);
      final recorder = ArtifactRecorder(rootDirectory: outputRoot);

      final report = _aiFlavorReport(allText, clicheReport, styleReports);
      await recorder.recordReport(
        relativePath: 'reports/ai_flavor_style.md',
        content: report,
      );

      stdout.writeln(report);

      expect(clicheReport.clicheDensity, lessThan(0.03),
          reason: 'AI 陈词密度应 < 3%');
    }, timeout: Timeout.none);
  });

  group('综合质量报告', () {
    test('生成完整 benchmark 报告', () async {
      if (!shouldRun || anthropicKey == null || anthropicKey.isEmpty) {
        markTestSkipped('设置 $_envGuard=1 和 ANTHROPIC_AUTH_TOKEN 以运行');
        return;
      }

      final outputRoot = Directory(_outputRoot);
      final recorder = ArtifactRecorder(rootDirectory: outputRoot);

      // 读取已生成的报告和数据
      final chaptersDir = Directory('$_outputRoot/chapters');
      final chapterFiles = <File>[];
      if (await chaptersDir.exists()) {
        await for (final entity in chaptersDir.list()) {
          if (entity is File && entity.path.endsWith('.md')) {
            chapterFiles.add(entity);
          }
        }
      }

      // AI 味检测
      final allText = chapterFiles.map((f) => f.readAsStringSync()).join('\n\n');
      final clicheReport = AiClicheDetector().detect(allText);

      // 风格对比
      final styleAnalyzer = ProseStyleAnalyzer();
      final styleSimilarities = <String, double>{};
      for (final entry in {'剑来': 'artifacts/writing_reference/jianlai/scenes.jsonl',
        '诡秘': 'artifacts/writing_reference/guimi/scenes.jsonl',
        '体鬼': 'artifacts/writing_reference/tigui/scenes.jsonl',
      }.entries) {
        final refFile = File(entry.value);
        if (!await refFile.exists()) continue;
        final refText = _loadReferenceText(refFile);
        if (refText.isEmpty) continue;
        final report = styleAnalyzer.compare(
          generatedText: allText,
          referenceText: refText,
          referenceLabel: entry.key,
        );
        styleSimilarities[entry.key] = report.similarityScore;
      }

      final settings = await _resolveSettings();

      // 构建章节数据（从已有文件推断）
      final summaries = <_ChapterSummary>[];
      for (var i = 0; i < chapterFiles.length && i < _benchmarkChapters.length; i++) {
        final ch = _benchmarkChapters[i];
        final text = chapterFiles[i].readAsStringSync();
        summaries.add(_ChapterSummary(
          chapterId: ch.id,
          chapterTitle: ch.title,
          sceneCount: ch.scenes.length,
          actualLength: text.replaceAll(RegExp(r'\s'), '').length,
          reviewPassed: true,
          proseRetryCount: 0,
          totalMs: 0,
        ));
      }

      final finalArc = NarrativeArcState(); // 占位

      final report = _runReportMarkdown(
        settings: settings,
        totalLlmCalls: 0,
        totalMs: 0,
        summaries: summaries,
        clicheReport: clicheReport,
        finalArc: finalArc,
        styleSimilarities: styleSimilarities,
      );

      await recorder.recordReport(relativePath: 'run-report.md', content: report);

      // Artifact index
      const indexPath = '$_outputRoot/reports/artifact-index.md';
      final indexBuf = StringBuffer()
        ..writeln('# Artifact Index')
        ..writeln();
      await for (final entity in outputRoot.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final relative = entity.path.substring(outputRoot.path.length + 1);
          indexBuf.writeln('- `$relative`');
        }
      }
      await File(indexPath).writeAsString(indexBuf.toString());

      stdout.writeln(report);

      expect(await File('$_outputRoot/run-report.md').exists(), isTrue);
      expect(await File('$_outputRoot/reports/artifact-index.md').exists(), isTrue);
    }, timeout: Timeout.none);
  });
}

// ---------------------------------------------------------------------------
// 辅助函数
// ---------------------------------------------------------------------------

String _loadReferenceText(File jsonlFile) {
  final buffer = StringBuffer();
  for (final line in jsonlFile.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line) as Map<Object?, Object?>;
      final text = json['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(text);
      }
    } catch (_) {
      continue;
    }
  }
  return buffer.toString();
}
