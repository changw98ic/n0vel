import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'ai_detection_state.dart';
import '../../../../../features/ai_detection/data/detection_service.dart';
import '../../../../../features/ai_detection/domain/detection_result.dart';

class AIDetectionLogic extends BaseController {
  final AIDetectionState state = AIDetectionState();
  late final TabController tabController;

  @override
  void onInit() {
    super.onInit();
    state.chapterId.value = Get.parameters['chapterId'] ?? '';
    // Content will be passed via arguments
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    state.content.value = args['content'] ?? '';
    // TabController will be created in the view with TickerProvider
    analyze();
  }

  Future<void> analyze() async {
    state.isAnalyzing.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final service = AIStyleDetectionService(
      forbiddenPatterns: state.detectForbiddenPatterns.value ? null : const <ForbiddenPattern>[],
      punctuationLimits: state.detectPunctuationAbuse.value ? null : const <PunctuationLimit>[],
      aiVocabulary: state.detectAiVocabulary.value ? null : const <AIVocabulary>[],
    );

    final report = service.analyze(state.content.value, state.chapterId.value);
    state.report.value = report;
    state.isAnalyzing.value = false;
  }

  Future<void> openSettings(BuildContext context) async {
    final result = await showDialog<_DetectionSettings>(
      context: context,
      builder: (context) => _DetectionSettingsDialog(
        settings: _DetectionSettings(
          detectForbiddenPatterns: state.detectForbiddenPatterns.value,
          detectPunctuationAbuse: state.detectPunctuationAbuse.value,
          detectAiVocabulary: state.detectAiVocabulary.value,
        ),
      ),
    );

    if (result != null) {
      state.detectForbiddenPatterns.value = result.detectForbiddenPatterns;
      state.detectPunctuationAbuse.value = result.detectPunctuationAbuse;
      state.detectAiVocabulary.value = result.detectAiVocabulary;
      await analyze();
    }
  }

  List<DetectionResult> buildOtherResults(DetectionReport report) {
    return [
      ...report.getResultsByType(DetectionType.perspectiveIssue),
      ...report.getResultsByType(DetectionType.pacingIssue),
      ...report.getResultsByType(DetectionType.standardizedOutput),
    ];
  }

  int otherIssueCount(DetectionReport report) {
    return buildOtherResults(report).length;
  }
}

class _DetectionSettings {
  final bool detectForbiddenPatterns;
  final bool detectPunctuationAbuse;
  final bool detectAiVocabulary;

  const _DetectionSettings({
    required this.detectForbiddenPatterns,
    required this.detectPunctuationAbuse,
    required this.detectAiVocabulary,
  });

  _DetectionSettings copyWith({
    bool? detectForbiddenPatterns,
    bool? detectPunctuationAbuse,
    bool? detectAiVocabulary,
  }) {
    return _DetectionSettings(
      detectForbiddenPatterns: detectForbiddenPatterns ?? this.detectForbiddenPatterns,
      detectPunctuationAbuse: detectPunctuationAbuse ?? this.detectPunctuationAbuse,
      detectAiVocabulary: detectAiVocabulary ?? this.detectAiVocabulary,
    );
  }
}

class _DetectionSettingsDialog extends StatefulWidget {
  final _DetectionSettings settings;

  const _DetectionSettingsDialog({required this.settings});

  @override
  State<_DetectionSettingsDialog> createState() => _DetectionSettingsDialogState();
}

class _DetectionSettingsDialogState extends State<_DetectionSettingsDialog> {
  late _DetectionSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.aiDetection_detectionSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text(s.aiDetection_enableForbiddenPatterns),
            value: _settings.detectForbiddenPatterns,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(detectForbiddenPatterns: value);
              });
            },
          ),
          SwitchListTile(
            title: Text(s.aiDetection_enablePunctuationAbuse),
            value: _settings.detectPunctuationAbuse,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(detectPunctuationAbuse: value);
              });
            },
          ),
          SwitchListTile(
            title: Text(s.aiDetection_enableAiVocabulary),
            value: _settings.detectAiVocabulary,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(detectAiVocabulary: value);
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(s.aiConfig_cancel),
        ),
        FilledButton(
          onPressed: () => Get.back(result: _settings),
          child: Text(s.aiDetection_apply),
        ),
      ],
    );
  }
}
