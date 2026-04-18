import '../../modules/editor/model/chapter.dart';
import '../../modules/work/model/work.dart';
import 'ai/agent/agent_service.dart';
import 'ai/models/model_tier.dart' show AIFunction, ModelTier;

class ChapterFrameworkWorkflowRunner {
  final AgentService _agentService;

  ChapterFrameworkWorkflowRunner({required AgentService agentService})
      : _agentService = agentService;

  Future<String> generateFramework({
    required Chapter newChapter,
    Work? workInfo,
    Chapter? lastChapter,
  }) async {
    final contextBuffer = StringBuffer();
    if (workInfo != null) {
      contextBuffer.writeln('浣滃搧鍚嶇О锛?{workInfo.name}');
      if (workInfo.description?.isNotEmpty == true) {
        contextBuffer.writeln('浣滃搧绠€浠嬶細${workInfo.description}');
      }
      contextBuffer.writeln();
    }
    if (lastChapter != null && lastChapter.content != null) {
      final lastContent = lastChapter.content!;
      contextBuffer.writeln('涓婁竴绔犮€?{lastChapter.title}銆嬫湯灏惧唴瀹癸細');
      contextBuffer.writeln(
        lastContent.length > 1500
            ? lastContent.substring(lastContent.length - 1500)
            : lastContent,
      );
      contextBuffer.writeln();
    }

    final prompt = '''璇锋牴鎹互涓嬩俊鎭紝涓烘柊绔犺妭銆?{newChapter.title}銆嬬敓鎴愪竴涓缁嗙殑鍐欎綔妗嗘灦銆?${contextBuffer.toString()}
瑕佹眰锛?- 鍏堢粰鍑烘湰绔犵殑銆愭牳蹇冨啿绐?鎮康銆戯紙1-2鍙ワ級
- 鐒跺悗鍒楀嚭 4-6 涓満鏅?娈佃惤鐨勫ぇ绾茶鐐癸紝姣忎釜鍖呭惈锛?  - 鍦烘櫙绠€杩帮紙鍋氫粈涔堬級
  - 鎯呯华/姘涘洿鎻愮ず
  - 棰勮瀛楁暟鑼冨洿
- 鏈€鍚庣粰鍑恒€愭湰绔犵粨灏鹃挬瀛愩€戯紙鍚稿紩璇昏€呯户缁槄璇荤殑鎮康鎴栬浆鎶橈級
- 鎬诲瓧鏁版帶鍒跺湪 400-600 瀛楃殑妗嗘灦鎻忚堪

璇风敤浠ヤ笅鏍煎紡杈撳嚭锛?## 鏍稿績鍐茬獊
...

## 鍦烘櫙澶х翰
### 鍦烘櫙 1锛歔鏍囬]
- 鍐呭绠€杩帮細...
- 姘涘洿锛?..
- 棰勮瀛楁暟锛?..

### 鍦烘櫙 2锛歔鏍囬]
...

## 缁撳熬閽╁瓙
...''';

    final response = await _agentService.orchestrate(
      task: prompt,
      function: AIFunction.continuation,
      tier: ModelTier.middle,
    );

    return response.content.trim();
  }

  Future<String> generateFromPrompt(String prompt) async {
    final response = await _agentService.orchestrate(
      task: prompt,
      function: AIFunction.continuation,
      tier: ModelTier.middle,
    );
    return response.content.trim();
  }
}

