import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_calibration_harness.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_policy.dart';

const _corpusId = 'literary-quality-dev-zh-synthetic-v1';
const _rubricVersion = 'scene-literary-quality-rubric-v1';
const _rootPath = 'test/fixtures/story_quality/dev_v1';

const _voices = <String>[
  'closeUrbanSuspense',
  'restrainedEpicFantasy',
  'colloquialAdventure',
  'technicalSpeculative',
  'lyricalRuralMystery',
];

const _familyCounts = <String, int>{
  'causalMainlineHard': 30,
  'povKnowledge': 30,
  'worldObjectTime': 30,
  'motivationRelationship': 30,
  'craftWeakness': 50,
  'styleChoice': 50,
  'effectiveDeviation': 30,
  'prettyHollow': 30,
  'highScoreDisguisedBad': 20,
};

const _negativeControls = <String>[
  'unreliableNarrator',
  'nonlinearTime',
  'multiplePov',
  'freeIndirectDiscourse',
  'declaredRuleException',
];

Future<void> main() async {
  final root = Directory(_rootPath);
  final fixturesDirectory = Directory('${root.path}/fixtures');
  await fixturesDirectory.create(recursive: true);

  final fixturesByFamily = <String, List<Map<String, Object?>>>{};
  final provenance = <Map<String, Object?>>[];
  var ordinal = 0;
  for (final family in _familyCounts.keys) {
    final fixtures = <Map<String, Object?>>[];
    for (
      var familyIndex = 0;
      familyIndex < _familyCounts[family]!;
      familyIndex += 1
    ) {
      ordinal += 1;
      final voice = _voices[(ordinal - 1) % _voices.length];
      final negativeControl = family == 'styleChoice'
          ? _negativeControls[familyIndex ~/ 10]
          : null;
      final fixtureId = 'lq-${ordinal.toString().padLeft(3, '0')}-$family';
      final provenanceId = 'prov-${ordinal.toString().padLeft(3, '0')}';
      final prose = _proseFor(
        family: family,
        familyIndex: familyIndex,
        voice: voice,
        negativeControl: negativeControl,
      );
      final expectation = _expectationFor(family, familyIndex);
      final contractDeclaration = _contractDeclaration(
        family: family,
        negativeControl: negativeControl,
        familyIndex: familyIndex,
      );
      final identity = <String, Object?>{
        'schemaVersion': 1,
        'fixtureId': fixtureId,
        'primaryFamily': family,
        'voiceTag': voice,
        'anchorScore': expectation.anchorScore,
        'negativeControl': negativeControl,
        'provenanceId': provenanceId,
        'prose': prose,
        'expectedFindingClasses': expectation.findingClasses,
        'expectedSeverity': expectation.severity,
        'expectedBlocked': expectation.blocked,
        'expectedReleaseEligible': expectation.releaseEligible,
        'contractDeclaration': contractDeclaration,
        'defectSummary': expectation.defectSummary,
        'anchorRationale': expectation.anchorRationale,
      };
      fixtures.add({
        ...identity,
        'fixtureHash': AppLlmCanonicalHash.domainHash(
          'literary-quality-development-fixture-v1',
          identity,
        ),
      });

      final provenanceIdentity = <String, Object?>{
        'schemaVersion': 1,
        'provenanceId': provenanceId,
        'sourceKind': 'synthetic',
        'licenseStatus': 'projectOwned',
        'allowedUses': const ['evaluation', 'calibration'],
        'createdForTesting': true,
        'namedWorkImitation': false,
        'sourceBodyHash': AppLlmCanonicalHash.domainHash(
          'literary-fixture-source-body-v1',
          prose,
        ),
      };
      provenance.add({
        ...provenanceIdentity,
        'provenanceHash': AppLlmCanonicalHash.domainHash(
          'literary-quality-fixture-provenance-v1',
          provenanceIdentity,
        ),
      });
    }
    fixturesByFamily[family] = fixtures;
  }

  final fixtureShards = <String>[];
  for (final entry in fixturesByFamily.entries) {
    final relativePath = 'fixtures/${_snakeCase(entry.key)}.jsonl';
    fixtureShards.add(relativePath);
    await _writeJsonLines(File('${root.path}/$relativePath'), entry.value);
  }
  fixtureShards.sort();
  await _writeJsonLines(File('${root.path}/provenance.jsonl'), provenance);

  final fixtures = fixturesByFamily.values.expand((items) => items).toList();
  final fixtureHashes =
      fixtures.map((item) => item['fixtureHash']! as String).toList()..sort();
  final provenanceHashes =
      provenance.map((item) => item['provenanceHash']! as String).toList()
        ..sort();
  final fixtureSetHash = AppLlmCanonicalHash.domainHash(
    'literary-quality-fixture-set-v1',
    fixtureHashes,
  );
  final provenanceSetHash = AppLlmCanonicalHash.domainHash(
    'literary-quality-provenance-set-v1',
    provenanceHashes,
  );
  final corpusIdentity = <String, Object?>{
    'artifactVersion': LiteraryQualityFixtureContract.artifactVersion,
    'corpusId': _corpusId,
    'rubricVersion': _rubricVersion,
    'parserRelease': LiteraryQualityFixtureContract.parserRelease,
    'thresholdPolicyVersion': LiteraryQualityPolicy.thresholdPolicyVersion,
    'sourceAdmissionPolicy':
        LiteraryQualityFixtureContract.sourceAdmissionPolicy,
    'uniqueFixtureCount': fixtures.length,
    'fixtureSetHash': fixtureSetHash,
    'provenanceSetHash': provenanceSetHash,
    'certificationFence': false,
  };
  final corpusHash = AppLlmCanonicalHash.domainHash(
    'literary-quality-development-corpus-v1',
    corpusIdentity,
  );
  final manifest = <String, Object?>{
    'artifactVersion': LiteraryQualityFixtureContract.artifactVersion,
    'corpusId': _corpusId,
    'rubricVersion': _rubricVersion,
    'parserRelease': LiteraryQualityFixtureContract.parserRelease,
    'thresholdPolicyVersion': LiteraryQualityPolicy.thresholdPolicyVersion,
    'sourceAdmissionPolicy':
        LiteraryQualityFixtureContract.sourceAdmissionPolicy,
    'uniqueFixtureCount': fixtures.length,
    'primaryFamilyMinimums':
        LiteraryQualityFixtureContract.primaryFamilyMinimums,
    'negativeControlMinimums':
        LiteraryQualityFixtureContract.negativeControlMinimums,
    'minimumVoiceCount': 5,
    'minimumFixturesPerVoice': 20,
    'requiredAnchorScores':
        LiteraryQualityFixtureContract.requiredAnchorScores.toList()..sort(),
    'fixtureShards': fixtureShards,
    'provenanceFile': 'provenance.jsonl',
    'fixtureSetHash': fixtureSetHash,
    'provenanceSetHash': provenanceSetHash,
    'corpusHash': corpusHash,
    'certificationFence': false,
    'formalHumanAdjudicatedHardCount': 0,
    'formalHumanAdjudicatedNonHardCount': 0,
  };
  await _writePrettyJson(File('${root.path}/manifest.json'), manifest);

  final primaryCounts = _counts(
    fixtures.map((item) => item['primaryFamily']! as String),
  );
  final voiceCounts = _counts(
    fixtures.map((item) => item['voiceTag']! as String),
  );
  final negativeCounts = _counts(
    fixtures.map((item) => item['negativeControl']).whereType<String>(),
  );
  final anchorCounts = _counts(
    fixtures.map((item) => (item['anchorScore']! as int).toString()),
  );
  final calibrationIdentity = <String, Object?>{
    'artifactVersion': 'literary-calibration-development-v1',
    'corpusHash': corpusHash,
    'uniqueItemCount': fixtures.length,
    'primaryClassCounts': primaryCounts,
    'voiceTagCounts': voiceCounts,
    'negativeControlCounts': negativeCounts,
    'anchorCounts': anchorCounts,
    'metricStatus': 'pendingRealEvaluatorRun',
    'metrics': const <String, Object?>{},
    'humanAdjudicatedHardDecisions': 0,
    'humanAdjudicatedNonHardDecisions': 0,
    'formalCertificationEligible': false,
    'limitation':
        'Synthetic development coverage only. It does not satisfy the '
        'separate 300 hard and 300 non-hard human-adjudicated certification '
        'decisions, and it contains no fabricated evaluator metrics.',
  };
  await _writePrettyJson(File('${root.path}/calibration-development.json'), {
    ...calibrationIdentity,
    'artifactHash': AppLlmCanonicalHash.domainHash(
      'literary-calibration-development-v1',
      calibrationIdentity,
    ),
  });

  stdout.writeln(
    'Generated ${fixtures.length} fixtures at ${root.path}; corpus=$corpusHash',
  );
}

({
  int anchorScore,
  List<String> findingClasses,
  String severity,
  bool blocked,
  bool releaseEligible,
  String defectSummary,
  String anchorRationale,
})
_expectationFor(String family, int familyIndex) => switch (family) {
  'causalMainlineHard' => (
    anchorScore: 60,
    findingClasses: const ['hardError'],
    severity: 'blocker',
    blocked: true,
    releaseEligible: false,
    defectSummary: 'The visible outcome contradicts the fixed causal bridge.',
    anchorRationale:
        '60 anchor: one mainline blocker survives otherwise readable prose.',
  ),
  'povKnowledge' => (
    anchorScore: 60,
    findingClasses: const ['hardError'],
    severity: 'blocker',
    blocked: true,
    releaseEligible: false,
    defectSummary: 'Limited POV states knowledge with no admitted source.',
    anchorRationale:
        '60 anchor: one explicit knowledge-boundary blocker controls status.',
  ),
  'worldObjectTime' => (
    anchorScore: 75,
    findingClasses: const ['hardError'],
    severity: 'blocker',
    blocked: true,
    releaseEligible: false,
    defectSummary: 'Object, time, or world-rule state contradicts authority.',
    anchorRationale:
        '75 anchor: polished local sentences cannot offset one rule blocker.',
  ),
  'motivationRelationship' => (
    anchorScore: 75,
    findingClasses: familyIndex.isEven
        ? const ['hardError']
        : const ['craftWeakness'],
    severity: familyIndex.isEven ? 'blocker' : 'major',
    blocked: familyIndex.isEven,
    releaseEligible: false,
    defectSummary:
        'A relationship turn has no pressure, resistance, or trigger.',
    anchorRationale:
        '75 anchor: one major or blocking motivation bridge is missing.',
  ),
  'craftWeakness' => (
    anchorScore: familyIndex.isEven ? 85 : 90,
    findingClasses: const ['craftWeakness'],
    severity: familyIndex.isEven ? 'major' : 'minor',
    blocked: false,
    releaseEligible: false,
    defectSummary:
        'The scene functions but pressure or paragraph work is weak.',
    anchorRationale: familyIndex.isEven
        ? '85 anchor: one evidence-backed major craft weakness needs repair.'
        : '90 anchor: one bounded minor weakness remains after a complete turn.',
  ),
  'styleChoice' => (
    anchorScore: 95,
    findingClasses: const ['styleChoice'],
    severity: 'note',
    blocked: false,
    releaseEligible: true,
    defectSummary:
        'Declared experimental narration is a permitted style choice.',
    anchorRationale:
        '95 anchor: no defect; the unusual form is explicitly authorized.',
  ),
  'effectiveDeviation' => (
    anchorScore: 95,
    findingClasses: const ['effectiveDeviation'],
    severity: 'note',
    blocked: false,
    releaseEligible: true,
    defectSummary: 'A bounded rhythm deviation performs its declared function.',
    anchorRationale:
        '95 anchor: planned deviation works and has a stated return condition.',
  ),
  'prettyHollow' => (
    anchorScore: 75,
    findingClasses: const ['craftWeakness'],
    severity: 'major',
    blocked: false,
    releaseEligible: false,
    defectSummary:
        'Atmosphere is present but goal, pressure, and turn are absent.',
    anchorRationale:
        '75 anchor: fluent prose contains one scene-wide structural major.',
  ),
  'highScoreDisguisedBad' => (
    anchorScore: 95,
    findingClasses: const ['hardError'],
    severity: 'blocker',
    blocked: true,
    releaseEligible: false,
    defectSummary: 'Surface polish conceals a fixed-promise contradiction.',
    anchorRationale:
        '95 surface anchor: high craft appearance never cancels a blocker.',
  ),
  _ => throw ArgumentError('unknown family: $family'),
};

String _contractDeclaration({
  required String family,
  required String? negativeControl,
  required int familyIndex,
}) {
  if (negativeControl != null) {
    return switch (negativeControl) {
      'unreliableNarrator' =>
        'POV policy admits an unreliable first-person account; contradiction '
            'inside the account is not objective-world evidence.',
      'nonlinearTime' =>
        'Scene contract declares one labelled flashback before returning to '
            'the present at the closing line.',
      'multiplePov' =>
        'POV policy admits rotating limited viewpoints separated by an '
            'explicit section break.',
      'freeIndirectDiscourse' =>
        'POV policy admits free indirect discourse for the current focal '
            'character only.',
      'declaredRuleException' =>
        'World contract admits backup cell exception rule-${familyIndex + 1} '
            'for this device and this scene.',
      _ => throw ArgumentError('unknown negative control: $negativeControl'),
    };
  }
  return switch (family) {
    'effectiveDeviation' =>
      'Scene craft contract authorizes deviation-${familyIndex + 1} until '
          'the immediate threat resolves, then requires normal cadence.',
    'styleChoice' => 'The project voice explicitly admits this form.',
    _ =>
      'Fixed scene contract requires a visible goal, resistance, trigger, '
          'consequence, and continuity with the stated facts.',
  };
}

String _proseFor({
  required String family,
  required int familyIndex,
  required String voice,
  required String? negativeControl,
}) {
  final number = familyIndex + 11;
  final names = ['林岑', '周桥', '阿澈', '弥珊', '贺原'];
  final name = names[familyIndex % names.length];
  final texture = switch (voice) {
    'closeUrbanSuspense' => '雨水沿消防梯一格格敲下来',
    'restrainedEpicFantasy' => '远塔的钟声压过荒原',
    'colloquialAdventure' => '风把破招牌吹得直打摆子',
    'technicalSpeculative' => '冷却泵的频谱在屏上收成一条细线',
    'lyricalRuralMystery' => '稻埂上的雾贴着水面慢慢挪',
    _ => throw ArgumentError('unknown voice: $voice'),
  };
  final marker = '编号${number.toString().padLeft(2, '0')}';
  if (negativeControl != null) {
    return switch (negativeControl) {
      'unreliableNarrator' =>
        '我当然没有碰那只刻着$marker的匣子。至少昨夜的我这样相信。'
            '$texture；等我摊开掌心，铜锈已经钻进指纹，我只好承认记忆又替我撒了谎。',
      'nonlinearTime' =>
        '三年前，$name在$marker门牌下听见同一句警告。那时他没有回头。'
            '——现在。$texture，他把钥匙压进锁孔，终于接上那次迟到的选择。',
      'multiplePov' =>
        '$name看见$marker灯闪了两次，认定同伴已经撤离。\n\n***\n\n'
            '隔墙的周桥却守着未发出的信号；$texture，她决定再等十秒。',
      'freeIndirectDiscourse' =>
        '$name摸到口袋里的$marker票根。又是这种便宜把戏，谁会信？'
            '$texture，他的脚却停在门槛外，像在等自己先把谎话说完。',
      'declaredRuleException' =>
        '总闸落下，走廊全黑，只有装有$marker备用电芯的定位器仍亮着。'
            '$texture，$name按合同写明的三分钟余量发出了坐标。',
      _ => throw ArgumentError('unknown negative control: $negativeControl'),
    };
  }
  return switch (family) {
    'causalMainlineHard' =>
      '$texture。$name刚确认刻着$marker的防火门仍从外侧反锁，下一句却已站在门内，'
          '中间没有钥匙、破拆、旁路或时间跳转。他把密封账册举给众人，仿佛门从未存在。',
    'povKnowledge' =>
      '$texture。$name隔着三层墙望不见周桥，却准确知道她正想起$marker旧案、'
          '准备在第七秒撒谎；现场没有通讯、预判依据或全知叙述授权。',
    'worldObjectTime' =>
      '$texture。停电记录写明电梯在二十分钟前烧毁，$name仍按下$marker楼层，'
          '轿厢立刻无声升起；正文没有备用电源、维修完成或规则例外。',
    'motivationRelationship' =>
      '$texture。周桥上一刻还因$marker证据指认$name害死兄长，下一刻便把唯一退路交给他，'
          '既无新证据，也无代价、试探或不得不合作的压力。',
    'craftWeakness' =>
      '$texture。$name要拿到$marker底片，守门人也拒绝放行。两人把旧条件又说了一遍，'
          '再把各自的担心解释了一遍；冲突成立，却没有新的筹码，场面停在原处。',
    'effectiveDeviation' =>
      '$marker。灯灭。门响。$name贴墙，屏住气。脚步逼近，一步，两步——'
          '枪口越过门缝时，他猛地拉下喷淋阀。水声盖住追兵，危险过去，句子重新舒展开来。',
    'prettyHollow' =>
      '$texture，玻璃上的水痕把$marker霓虹揉成一团缓慢的火。$name想起许多旧事，'
          '又把它们逐一放下。景物和心绪都很完整，但他没有目标、阻碍、选择或状态变化。',
    'highScoreDisguisedBad' =>
      '$texture。$name用$marker银扣封好信，动作干净得像收起一线月光。'
          '然而固定主线规定他必须保护仍活着的周桥，正文却把她写成十年前已经下葬，'
          '并以此结束所有营救行动。',
    _ => throw ArgumentError('family needs a negative control: $family'),
  };
}

String _snakeCase(String value) => value.replaceAllMapped(
  RegExp(r'([a-z0-9])([A-Z])'),
  (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
);

Map<String, int> _counts(Iterable<String> values) {
  final result = <String, int>{};
  for (final value in values) {
    result[value] = (result[value] ?? 0) + 1;
  }
  return result;
}

Future<void> _writeJsonLines(
  File file,
  Iterable<Map<String, Object?>> values,
) async {
  await file.parent.create(recursive: true);
  final body = values.map(jsonEncode).join('\n');
  await file.writeAsString('$body\n');
}

Future<void> _writePrettyJson(File file, Map<String, Object?> value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}
