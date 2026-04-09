import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../features/reading_mode/domain/reading_models.dart';

class ReadingSettingsPanel extends StatefulWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onChanged;
  final VoidCallback onClose;

  const ReadingSettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<ReadingSettingsPanel> createState() => _ReadingSettingsPanelState();
}

class _ReadingSettingsPanelState extends State<ReadingSettingsPanel> {
  late ReadingSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final textColor = _getTextColor();

    return Container(
      color: bgColor,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读设置',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: textColor),
          ),
          SizedBox(height: 16.h),
          Text(
            '字体大小 ${_settings.fontSize.toStringAsFixed(1)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Slider(
            value: _settings.fontSize,
            min: 12,
            max: 32,
            divisions: 20,
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(fontSize: value));
              widget.onChanged(_settings);
            },
          ),
          SizedBox(height: 16.h),
          Text(
            '字体',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            initialValue: _settings.fontFamily,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
            items: const [
              DropdownMenuItem(value: 'serif', child: Text('衬线')),
              DropdownMenuItem(value: 'kai', child: Text('楷体')),
              DropdownMenuItem(value: 'fang', child: Text('仿宋')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => _settings = _settings.copyWith(fontFamily: value),
                );
                widget.onChanged(_settings);
              }
            },
          ),
          SizedBox(height: 16.h),
          Text(
            '行高 ${_settings.lineHeight.toStringAsFixed(1)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Slider(
            value: _settings.lineHeight,
            min: 1.0,
            max: 3.0,
            divisions: 20,
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(lineHeight: value));
              widget.onChanged(_settings);
            },
          ),
          SizedBox(height: 16.h),
          Text(
            '页边距 ${_settings.pageMargin.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Slider(
            value: _settings.pageMargin,
            min: 8,
            max: 32,
            divisions: 24,
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(pageMargin: value));
              widget.onChanged(_settings);
            },
          ),
          SizedBox(height: 24.h),
          Text(
            '背景',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: textColor),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReadingBackground.values.map((bg) {
              final isSelected = _settings.background == bg;
              return GestureDetector(
                onTap: () {
                  setState(
                    () => _settings = _settings.copyWith(background: bg),
                  );
                  widget.onChanged(_settings);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _parseColor(bg.value),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: _getContrastColor(bg))
                      : null,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),
          Text(
            '屏幕方向',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          SizedBox(height: 8.h),
          DropdownButtonFormField<ScreenOrientation>(
            initialValue: _settings.orientation,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
            items: ScreenOrientation.values
                .map(
                  (orientation) => DropdownMenuItem(
                    value: orientation,
                    child: Text(orientation.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => _settings = _settings.copyWith(orientation: value),
                );
                widget.onChanged(_settings);
              }
            },
          ),
          SizedBox(height: 16.h),
          SwitchListTile(
            title: Text('自动滚动', style: TextStyle(color: textColor)),
            subtitle: Text(
              '滚动速度 ${_settings.autoScrollSpeed}',
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
            ),
            value: _settings.autoScroll,
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(autoScroll: value));
              widget.onChanged(_settings);
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: widget.onClose,
                child: const Text('关闭'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    return _parseColor(_settings.background.value);
  }

  Color _getTextColor() {
    return _settings.background == ReadingBackground.dark
        ? Colors.white
        : Colors.black87;
  }

  Color _parseColor(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Color _getContrastColor(ReadingBackground bg) {
    return bg == ReadingBackground.dark ? Colors.white : Colors.black54;
  }
}
