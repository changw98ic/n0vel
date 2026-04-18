import '../../features/settings/domain/character.dart';
import 'batch_chapter_orchestrator.dart';

class FullNovelPromptBuilder {
  const FullNovelPromptBuilder._();

  static String buildWorldbuildingPrompt({
    required String title,
    required String genre,
    String? style,
    String? description,
  }) => '''
璇蜂负涓€閮?${genre}绫诲瀷灏忚銆?${title}銆嬭璁″畬鏁寸殑涓栫晫瑙傝瀹氥€?
${style != null ? '椋庢牸鍋忓ソ: $style' : ''}
${description != null ? '浣滃搧绠€浠? $description' : ''}

璇疯緭鍑轰互涓嬪唴瀹癸紙姣忛」鑷冲皯 200 瀛楋級锛?
## 鍔涢噺浣撶郴
锛堜慨鐐?榄旀硶/瓒呰兘鍔涗綋绯汇€佺瓑绾у垝鍒嗐€侀檺鍒舵潯浠讹級

## 涓栫晫鍦扮悊
锛堜富瑕佸浗瀹?鍦板尯銆侀噸瑕佸湴鐐广€佸湴鍥炬瑙堬級

## 鍘嗗彶鑳屾櫙
锛堥噸澶т簨浠躲€佹椂闂寸嚎銆佷笂鍙や紶璇达級

## 绀句細缁撴瀯
锛堥樁灞傘€佺粍缁囥€佹斂娌讳綋绯汇€佺粡娴庡舰鎬侊級

## 鏍稿績璁惧畾
锛堢嫭鐗圭殑涓栫晫瑙傝绱犮€佺蹇屻€佷紶璇达級
''';

  static String buildCharacterDesignPrompt({
    required String title,
    required String genre,
    required String worldRaw,
  }) => '''
璇蜂负${genre}灏忚銆?${title}銆嬭璁′互涓嬭鑹诧紝姣忎釜瑙掕壊浠?JSON 瀵硅薄褰㈠紡杈撳嚭銆?
## 涓栫晫瑙傝儗鏅?${_truncate(worldRaw, 2000)}

## 杈撳嚭瑕佹眰
璇疯緭鍑轰竴涓?JSON 鏁扮粍锛屽寘鍚互涓嬭鑹诧細
1. 涓昏 (protagonist) 脳 1
2. 涓昏鍙嶆淳 (majorAntagonist) 脳 1
3. 閰嶈 (supporting) 脳 3
4. 榫欏 (minor) 脳 2

姣忎釜瑙掕壊鏍煎紡锛?{
  "name": "濮撳悕",
  "tier": "protagonist|majorAntagonist|supporting|minor",
  "gender": "鎬у埆",
  "age": "骞撮緞",
  "identity": "韬唤/鑱屼笟",
  "bio": "200瀛椾互鍐呯殑绠€浠?,
  "aliases": ["鍒悕1"],
  "personality": ["鎬ф牸鍏抽敭璇?", "鎬ф牸鍏抽敭璇?"]
}

璇风‘淇濊鑹蹭箣闂存湁娼滃湪鐨勫啿绐佸拰鍏崇郴銆備粎杈撳嚭 JSON 鏁扮粍锛屼笉瑕佽緭鍑哄叾浠栧唴瀹广€?''';

  static String buildEntityCreationPrompt({
    required String title,
    required String genre,
    required String worldRaw,
    required String characterNames,
  }) => '''
璇蜂负${genre}灏忚銆?${title}銆嬭璁′互涓嬪疄浣擄紝浠?JSON 鏍煎紡杈撳嚭銆?
## 涓栫晫瑙?${_truncate(worldRaw, 1500)}

## 宸叉湁瑙掕壊
$characterNames

璇疯緭鍑轰互涓?JSON 缁撴瀯锛?{
  "locations": [
    {"name": "鍦扮偣鍚?, "type": "绫诲瀷锛堝煄甯?灞辫剦/绉樺绛夛級", "parentName": null, "description": "鎻忚堪", "importantPlaces": ["瀛愬湴鐐?"]},
    {"name": "瀛愬湴鐐瑰悕", "type": "绫诲瀷", "parentName": "鐖跺湴鐐瑰悕", "description": "鎻忚堪", "importantPlaces": []}
  ],
  "items": [
    {"name": "鐗╁搧鍚?, "type": "姝﹀櫒/娉曞疂/涓硅嵂绛?, "rarity": "绋€鏈夊害", "description": "鎻忚堪", "abilities": ["鑳藉姏1"], "holderName": "鎸佹湁鑰呰鑹插悕锛堝彲閫夛級"}
  ],
  "factions": [
    {"name": "鍔垮姏鍚?, "type": "瀹楅棬/瀹舵棌/鐜嬫湞绛?, "description": "鎻忚堪", "traits": ["鐗瑰緛1"], "leaderName": "棣栭瑙掕壊鍚嶏紙鍙€夛級", "memberNames": ["鎴愬憳瑙掕壊鍚?]}
  ]
}

瑕佹眰锛?-5 涓湴鐐癸紙鍚眰绾у叧绯伙級銆?-5 涓墿鍝併€?-4 涓娍鍔涖€備粎杈撳嚭 JSON銆?''';

  static String buildPlotPlanningPrompt({
    required String title,
    required String genre,
    required int chapterCount,
    required String worldRaw,
    required String characterDescription,
  }) => '''
璇蜂负${genre}灏忚銆?${title}銆嬭璁?${chapterCount} 绔犵殑澶х翰銆?
## 涓栫晫瑙?${_truncate(worldRaw, 1500)}

## 瑙掕壊
$characterDescription

## 杈撳嚭瑕佹眰
璇疯緭鍑轰竴涓?JSON 鏁扮粍锛屽寘鍚?$chapterCount 涓珷鑺傚ぇ绾诧細
[
  {
    "index": 1,
    "title": "绔犺妭鏍囬",
    "plotSummary": "100-150瀛楃殑鎯呰妭姒傝",
    "keyEvents": "鍏抽敭浜嬩欢锛岀敤鍒嗗彿鍒嗛殧",
    "hook": "鏈珷閽╁瓙/鎮康"
  }
]

瑕佹眰锛?- 绗?绔狅細涓昏鍑哄満鍜屼笘鐣岃灞曠ず
- 鍓?绔狅細寤虹珛涓荤嚎鍐茬獊
- 涓棿绔犺妭锛氭帹杩涘墽鎯呫€佽鑹插彂灞曘€佹彮绀虹瀵?- 鍊掓暟2绔狅細楂樻疆鍜屽喅鎴?- 鏈€鍚庝竴绔狅細鏀舵潫鍜屼綑闊?- 浼忕瑪瑕佸墠鍚庡懠搴?
浠呰緭鍑?JSON 鏁扮粍銆?''';

  static String buildStoryContext({
    required String title,
    required String genre,
    String? style,
    required String characterDescription,
    required String worldRaw,
    required String outlineDescription,
  }) => '''
## 浣滃搧淇℃伅
鏍囬: $title
绫诲瀷: $genre
${style != null ? '椋庢牸: $style' : ''}

## 涓昏瑙掕壊
$characterDescription

## 涓栫晫瑙傛憳瑕?${_truncate(worldRaw, 1000)}

## 绔犺妭澶х翰
$outlineDescription
''';

  static String buildOutlineText(List<ChapterOutline> outlines) {
    return outlines.asMap().entries.map((entry) {
      final outline = entry.value;
      return '绗?${outline.index}绔? ${outline.title}\n${outline.plotSummary}\n浜嬩欢: ${outline.keyEvents}\n閽╁瓙: ${outline.hook}';
    }).join('\n\n');
  }

  static String buildConsistencyPrompt(String content) =>
      '璇锋鏌ヤ互涓嬪皬璇村唴瀹圭殑涓€鑷存€ч棶棰橈紙璁惧畾鍐茬獊銆侀€昏緫鐭涚浘銆佹椂闂寸嚎閿欒绛夛級锛歕n\n$content';

  static String buildOocPrompt({
    required String characterDescription,
    required String content,
  }) => '璇锋鏌ヤ互涓嬪唴瀹逛腑瑙掕壊琛屼负鏄惁绗﹀悎璁惧畾锛歕n\n瑙掕壊璁惧畾:\n$characterDescription\n\n绔犺妭鍐呭:\n$content';

  static String buildPacingPrompt(String content) =>
      '璇峰垎鏋愪互涓嬪皬璇村唴瀹圭殑鍙欎簨鑺傚锛堝揩鎱㈠垎甯冦€佸紶寮涙湁搴︺€侀挬瀛愯缃瓑锛夛細\n\n$content';

  static String buildQualityReport({
    required String consistency,
    required String ooc,
    required String pacing,
  }) => '# 璐ㄩ噺瀹℃煡鎶ュ憡\n\n## 涓€鑷存€ф鏌n$consistency\n\n## 瑙掕壊琛屼负妫€鏌n$ooc\n\n## 鑺傚鍒嗘瀽\n$pacing';

  static String buildCharacterNameSummary(
    Iterable<({String name, CharacterTier tier})> characters,
  ) {
    return characters.take(5).map((entry) => '${entry.name}(${entry.tier.label})').join('?');
  }

  static String buildCharacterBioSummary(
    Iterable<({String name, CharacterTier tier, String? bio})> characters,
  ) {
    return characters.map((entry) => '- ${entry.name}(${entry.tier.label}): ${entry.bio ?? ""}').join('\n');
  }

  static String buildStoryCharacterSummary(
    Iterable<({String name, CharacterTier tier})> characters,
  ) {
    return characters.map((entry) => '${entry.name}(${entry.tier.label})').join('?');
  }

  static String buildMainCharacterDescription(
    Iterable<({String name, String? bio})> characters,
  ) {
    return characters.map((entry) => '${entry.name}: ${entry.bio ?? ""}').join('\n');
  }

  static String buildOutlineDescription(List<ChapterOutline> outlines) {
    return outlines
        .map((outline) => '绗?${outline.index}绔犮€?${outline.title}銆? ${outline.plotSummary}')
        .join('\n');
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength);
  }
}

class FullNovelParsing {
  const FullNovelParsing._();

  static String? extractJsonArray(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }

  static String? extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }

  static CharacterTier parseTier(String tier) {
    return switch (tier.toLowerCase()) {
      'protagonist' => CharacterTier.protagonist,
      'majorantagonist' || 'major_antagonist' => CharacterTier.majorAntagonist,
      'antagonist' => CharacterTier.antagonist,
      'supporting' => CharacterTier.supporting,
      _ => CharacterTier.minor,
    };
  }

  static List<int> selectPovChapterIndices(int chapterCount) {
    final selectedIndices = <int>{};
    if (chapterCount > 0) {
      selectedIndices.add(0);
    }
    if (chapterCount > 5) {
      selectedIndices.add(chapterCount ~/ 2);
    }
    if (chapterCount > 2) {
      selectedIndices.add((chapterCount * 0.75).floor().clamp(0, chapterCount - 1));
    }
    return selectedIndices.toList()..sort();
  }
}
