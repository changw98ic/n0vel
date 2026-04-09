import 'package:get/get.dart';
import '../../../../../features/ai_detection/domain/detection_result.dart';

class AIDetectionState {
  final chapterId = RxString('');
  final content = RxString('');
  final report = Rx<DetectionReport?>(null);
  final isAnalyzing = RxBool(false);
  final detectForbiddenPatterns = RxBool(true);
  final detectPunctuationAbuse = RxBool(true);
  final detectAiVocabulary = RxBool(true);
}
