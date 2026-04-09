import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/work/data/work_repository.dart';
import '../../../features/work/domain/work.dart';

class WorkFormPage extends StatefulWidget {
  final String? workId;

  const WorkFormPage({super.key, this.workId});

  @override
  State<WorkFormPage> createState() => _WorkFormPageState();
}

class _WorkFormPageState extends State<WorkFormPage> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.workId != null ? s.work_editWork : s.work_createWork,
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            Work? existingWork;
            if (widget.workId != null) {
              final repository = Get.find<WorkRepository>();
              existingWork = await repository.getWorkById(widget.workId!);
            }

            if (!mounted) {
              return;
            }

            final result = await showDialog<WorkFormResult>(
              context: navigator.context,
              builder: (context) => WorkFormDialog(existingWork: existingWork),
            );

            if (!mounted || result == null) {
              return;
            }
            navigator.pop(result);
          },
          child: Text(s.work_openForm),
        ),
      ),
    );
  }
}

class WorkFormResult {
  final Work work;
  final bool isEditing;

  const WorkFormResult({required this.work, required this.isEditing});
}

class WorkFormDialog extends StatefulWidget {
  final Work? existingWork;

  const WorkFormDialog({super.key, this.existingWork});

  @override
  State<WorkFormDialog> createState() => _WorkFormDialogState();
}

class _WorkFormDialogState extends State<WorkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetWordsController;

  WorkType _selectedType = WorkType.novel;
  String? _coverPath;
  bool _isSubmitting = false;

  bool get isEditing => widget.existingWork != null;
  bool get hasCustomCover =>
      _coverPath != null && _coverPath!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final work = widget.existingWork;
    _nameController = TextEditingController(text: work?.name ?? '');
    _descriptionController = TextEditingController(
      text: work?.description ?? '',
    );
    _targetWordsController = TextEditingController(
      text: work?.targetWords?.toString() ?? '',
    );
    if (work != null) {
      _selectedType = WorkType.values.firstWhere(
        (entry) => entry.name == work.type,
        orElse: () => WorkType.novel,
      );
      _coverPath = work.coverPath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetWordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(isEditing ? s.work_editWork : s.work_createWork),
      content: SizedBox(
        width: 420.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _pickCoverImage,
                    child: Container(
                      width: 120.w,
                      height: 160.h,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: hasCustomCover
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.file(
                                File(_coverPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildCoverPlaceholder(),
                              ),
                            )
                          : _buildCoverPlaceholder(),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Center(
                  child: Text(
                    hasCustomCover ? s.work_customCover : s.work_defaultCover,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _pickCoverImage,
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(
                        hasCustomCover
                            ? s.work_changeCover
                            : s.work_uploadCover,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    TextButton.icon(
                      onPressed: _isSubmitting || !hasCustomCover
                          ? null
                          : () => setState(() => _coverPath = null),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(s.work_useDefaultCover),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '${s.work_workName} *',
                    hintText: s.work_workNameHint,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.work_workNameRequired;
                    }
                    if (value.length > 100) {
                      return s.work_workNameTooLong;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<WorkType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: s.work_workType,
                    border: OutlineInputBorder(),
                  ),
                  items: WorkType.values.map((type) {
                    return DropdownMenuItem<WorkType>(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: s.work_workDescription,
                    hintText: s.work_workDescriptionHint,
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _targetWordsController,
                  decoration: InputDecoration(
                    labelText: s.work_targetWords,
                    hintText: s.work_targetWordsHint,
                    border: OutlineInputBorder(),
                    suffixText: s.work_targetWordsUnit,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final number = int.tryParse(value);
                      if (number == null || number <= 0) {
                        return s.work_targetWordsInvalid;
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(s.work_cancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? s.work_save : s.work_create),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    final s = S.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_stories_rounded,
          size: 34.sp,
          color: Theme.of(context).colorScheme.outline,
        ),
        SizedBox(height: 8.h),
        Text(
          s.work_defaultCoverLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Text(
          s.work_uploadLater,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() => _coverPath = image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.work_pickImageFailed(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = Get.find<WorkRepository>();
      final description = _descriptionController.text.trim();
      final targetWords = _targetWordsController.text.trim().isEmpty
          ? null
          : int.tryParse(_targetWordsController.text.trim());

      late final Work savedWork;
      if (isEditing) {
        savedWork = await repository.updateWork(
          widget.existingWork!.id,
          UpdateWorkParams(
            name: _nameController.text.trim(),
            type: _selectedType.name,
            description: description.isEmpty ? null : description,
            coverPath: hasCustomCover ? _coverPath : null,
            targetWords: targetWords,
          ),
        );
      } else {
        savedWork = await repository.createWork(
          CreateWorkParams(
            name: _nameController.text.trim(),
            type: _selectedType.name,
            description: description.isEmpty ? null : description,
            coverPath: hasCustomCover ? _coverPath : null,
            targetWords: targetWords,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        WorkFormResult(work: savedWork, isEditing: isEditing),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.work_saveFailed(e.toString()))),
        );
      }
    }
  }
}
