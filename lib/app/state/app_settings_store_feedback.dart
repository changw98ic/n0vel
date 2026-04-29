import 'app_settings_models.dart';
import 'app_settings_storage.dart';
import 'app_settings_store_utils.dart';

({
  AppSettingsPersistenceIssue issue,
  String? detail,
  String? summary,
  AppSettingsFeedback feedback,
}) feedbackForSaveResult(AppSettingsSaveResult result) {
  switch (result.issue) {
    case AppSettingsPersistenceIssue.none:
      return (
        issue: result.issue,
        detail: result.detail,
        summary: null,
        feedback: const AppSettingsFeedback(
          title: '保存成功',
          message: '新配置会从下一次 AI 请求开始生效。',
          tone: AppSettingsFeedbackTone.success,
        ),
      );
    case AppSettingsPersistenceIssue.fileReadFailed:
      return (
        issue: result.issue,
        detail: result.detail,
        summary: '设置文件当前不可读，无法确认保存结果。',
        feedback: AppSettingsFeedback(
          title: '设置文件状态异常',
          message: withDetail('设置文件当前不可读，无法确认保存结果。', result.detail),
          tone: AppSettingsFeedbackTone.error,
        ),
      );
    case AppSettingsPersistenceIssue.fileWriteFailed:
      return (
        issue: result.issue,
        detail: result.detail,
        summary: '设置文件写入失败，本次修改未能持久化到 settings.json。',
        feedback: AppSettingsFeedback(
          title: '设置保存失败',
          message: withDetail(
            '设置文件写入失败，本次修改未能持久化到 settings.json。',
            result.detail,
          ),
          tone: AppSettingsFeedbackTone.error,
        ),
      );
  }
}

({
  AppSettingsPersistenceIssue issue,
  String? detail,
  String? summary,
  AppSettingsFeedback feedback,
}) feedbackForLoadIssue(
  AppSettingsPersistenceIssue issue,
  String? detail,
) {
  switch (issue) {
    case AppSettingsPersistenceIssue.none:
      return (
        issue: issue,
        detail: detail,
        summary: null,
        feedback: const AppSettingsFeedback(),
      );
    case AppSettingsPersistenceIssue.fileReadFailed:
      return (
        issue: issue,
        detail: detail,
        summary: '无法读取 settings.json，请检查文件内容是否损坏。',
        feedback: AppSettingsFeedback(
          title: '设置文件读取失败',
          message: withDetail('无法读取 settings.json，请检查文件内容是否损坏。', detail),
          tone: AppSettingsFeedbackTone.error,
        ),
      );
    case AppSettingsPersistenceIssue.fileWriteFailed:
      return (
        issue: issue,
        detail: detail,
        summary: '无法写入 settings.json，请检查磁盘或目录权限。',
        feedback: AppSettingsFeedback(
          title: '设置文件写入失败',
          message: withDetail('无法写入 settings.json，请检查磁盘或目录权限。', detail),
          tone: AppSettingsFeedbackTone.error,
        ),
      );
  }
}
