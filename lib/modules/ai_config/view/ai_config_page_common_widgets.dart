import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/ai_config/domain/model_config.dart';

const aiConfigFailureColor = Colors.red;

Color aiConfigResultColor(bool success) => success ? Colors.green : Colors.red;

String aiConfigDefaultEndpointForProvider(String? providerType) {
  return switch (providerType) {
    'openai' => 'https://api.openai.com/v1',
    'anthropic' => 'https://api.anthropic.com/v1',
    'ollama' => 'http://localhost:11434/api',
    _ => '',
  };
}

Future<void> showAIConfigLoadingDialog({
  required BuildContext context,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          SizedBox(width: 16.w),
          Text(message),
        ],
      ),
    ),
  );
}

List<DropdownMenuItem<ModelTier>> buildAIConfigTierMenuItems() {
  return ModelTier.values.map((tier) {
    return DropdownMenuItem<ModelTier>(
      value: tier,
      child: Row(
        children: [
          Icon(tier.icon, size: 16.sp, color: tier.color),
          SizedBox(width: 8.w),
          Text(tier.displayName),
        ],
      ),
    );
  }).toList();
}

class AIConfigTierCardHeader extends StatelessWidget {
  final ModelTier tier;
  final String testLabel;
  final VoidCallback onTestConnection;

  const AIConfigTierCardHeader({
    super.key,
    required this.tier,
    required this.testLabel,
    required this.onTestConnection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: tier.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(tier.icon, color: tier.color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tier.displayName, style: theme.textTheme.titleMedium),
              Text(tier.description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onTestConnection,
          icon: Icon(Icons.wifi_find, size: 18.sp),
          label: Text(testLabel),
        ),
      ],
    );
  }
}

class AIConfigUsageStatContent extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AIConfigUsageStatContent({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32.sp),
        SizedBox(height: 8.h),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
