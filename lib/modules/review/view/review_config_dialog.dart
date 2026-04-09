import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

/// 审查配置对话框
class ReviewConfigDialog extends StatefulWidget {
  const ReviewConfigDialog({super.key});

  @override
  State<ReviewConfigDialog> createState() => _ReviewConfigDialogState();
}

class _ReviewConfigDialogState extends State<ReviewConfigDialog> {
  bool _autoReview = true;
  bool _enableNotifications = true;
  int _reviewDepth = 2;

  static const String _keyAutoReview = 'review_config_auto_review';
  static const String _keyEnableNotifications = 'review_config_enable_notifications';
  static const String _keyReviewDepth = 'review_config_depth';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoReview = prefs.getBool(_keyAutoReview) ?? true;
      _enableNotifications = prefs.getBool(_keyEnableNotifications) ?? true;
      _reviewDepth = prefs.getInt(_keyReviewDepth) ?? 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.review_config_title),
      content: SizedBox(
        width: 500.w,
        child: ListView(
          shrinkWrap: true,
          children: [
            SwitchListTile(
              title: Text(s.review_config_autoReview),
              subtitle: Text(s.review_config_autoReviewSubtitle),
              value: _autoReview,
              onChanged: (value) {
                setState(() => _autoReview = value);
              },
            ),
            SwitchListTile(
              title: Text(s.review_config_notifications),
              subtitle: Text(s.review_config_notificationsSubtitle),
              value: _enableNotifications,
              onChanged: (value) {
                setState(() => _enableNotifications = value);
              },
            ),
            SizedBox(height: 16.h),
            Text(s.review_config_depth),
            SizedBox(height: 8.h),
            Slider(
              value: _reviewDepth.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '${_getDepthLabel(_reviewDepth, s)}',
              onChanged: (value) {
                setState(() => _reviewDepth = value.toInt());
              },
            ),
            Text(
              _getDepthDescription(_reviewDepth, s),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.editor_cancel),
        ),
        FilledButton(
          onPressed: () async {
            await _saveConfig();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.review_config_saved)),
              );
            }
          },
          child: Text(s.editor_save),
        ),
      ],
    );
  }

  String _getDepthLabel(int depth, S s) {
    switch (depth) {
      case 1:
        return s.review_config_depth_quick;
      case 2:
        return s.review_config_depth_standard;
      case 3:
        return s.review_config_depth_detailed;
      case 4:
        return s.review_config_depth_deep;
      case 5:
        return s.review_config_depth_comprehensive;
      default:
        return s.review_config_depth_standard;
    }
  }

  String _getDepthDescription(int depth, S s) {
    switch (depth) {
      case 1:
        return s.review_config_depthDescription_1;
      case 2:
        return s.review_config_depthDescription_2;
      case 3:
        return s.review_config_depthDescription_3;
      case 4:
        return s.review_config_depthDescription_4;
      case 5:
        return s.review_config_depthDescription_5;
      default:
        return s.review_config_depthDescription_2;
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoReview, _autoReview);
    await prefs.setBool(_keyEnableNotifications, _enableNotifications);
    await prefs.setInt(_keyReviewDepth, _reviewDepth);
    debugPrint('Saving review config: auto=$_autoReview, notifications=$_enableNotifications, depth=$_reviewDepth');
  }
}
