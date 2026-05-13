import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_shell.dart';

class TransferStatusDescriptor {
  const TransferStatusDescriptor({
    required this.header,
    required this.tone,
    required this.title,
    required this.message,
    required this.detailTitle,
    required this.detailLines,
  });

  final String header;
  final String tone;
  final String title;
  final String message;
  final String detailTitle;
  final List<String> detailLines;
}

class ImportExportFieldRow extends StatelessWidget {
  const ImportExportFieldRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class ImportExportPathValueText extends StatelessWidget {
  const ImportExportPathValueText({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final separator = Platform.pathSeparator;
    final separatorIndex = value.lastIndexOf(separator);
    final fileName = separatorIndex == -1
        ? value
        : value.substring(separatorIndex + 1);
    final directory = separatorIndex == -1
        ? ''
        : value.substring(0, separatorIndex);
    final directoryLabel = _compactDirectoryLabel(directory, separator);

    return Tooltip(
      message: value,
      waitDuration: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (directory.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              directoryLabel,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

String _compactDirectoryLabel(String directory, String separator) {
  if (directory.isEmpty) return directory;
  final parts = directory
      .split(separator)
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.length <= 2) return directory;
  final prefix = directory.startsWith(separator)
      ? '$separator…$separator'
      : '…$separator';
  return '$prefix${parts.last}';
}

class ImportExportStatusCard extends StatelessWidget {
  const ImportExportStatusCard({required this.descriptor, required this.accent, super.key});

  final TransferStatusDescriptor descriptor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.header,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  descriptor.tone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(descriptor.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(descriptor.message, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: appPanelDecoration(
              context,
              color: desktopPalette(context).surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descriptor.detailTitle,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < descriptor.detailLines.length; index++) ...[
                  Text(
                    descriptor.detailLines[index],
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                  if (index != descriptor.detailLines.length - 1)
                    const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImportExportGuidanceCard extends StatelessWidget {
  const ImportExportGuidanceCard({required this.descriptor, required this.accent, super.key});

  final TransferStatusDescriptor descriptor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descriptor.detailTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in descriptor.detailLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImportExportResultLog extends StatelessWidget {
  const ImportExportResultLog({required this.descriptor, required this.accent, super.key});

  final TransferStatusDescriptor descriptor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      descriptor.header,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      descriptor.tone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${descriptor.title} · ${descriptor.message}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              descriptor.detailLines.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

String safeExportFileStem(String title) {
  final buffer = StringBuffer();
  for (final rune in title.runes) {
    final isDigit = rune >= 0x30 && rune <= 0x39;
    final isUpper = rune >= 0x41 && rune <= 0x5A;
    final isLower = rune >= 0x61 && rune <= 0x7A;
    final isCjk = rune >= 0x4E00 && rune <= 0x9FFF;
    if (isDigit || isUpper || isLower || isCjk || rune == 0x5F) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write('_');
    }
  }
  final stem = buffer.toString();
  return stem.isEmpty ? 'untitled' : stem;
}

class ImportExportFormatDropdown<T> extends StatelessWidget {
  const ImportExportFormatDropdown({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String title;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showDialog<T>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final palette = desktopPalette(dialogContext);
        return DesktopModalDialog(
          title: title,
          width: 360,
          body: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final (itemValue, label) = items[index];
              final selected = itemValue == value;
              return OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(itemValue),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: selected ? palette.primary : palette.tertiaryText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              );
            },
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final selectedLabel = items
        .firstWhere((item) => item.$1 == value, orElse: () => items.first)
        .$2;

    return Semantics(
      button: true,
      label: '$title：$selectedLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.elevated,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(selectedLabel, style: theme.textTheme.bodyMedium)),
                  Icon(Icons.expand_more, size: 16, color: palette.tertiaryText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
