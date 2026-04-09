import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/settings/domain/character.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/domain/relationship.dart' as domain;

class CreateRelationshipDialog extends StatefulWidget {
  final String workId;
  final VoidCallback onCreated;

  const CreateRelationshipDialog({super.key, required this.workId, required this.onCreated});

  @override
  State<CreateRelationshipDialog> createState() => _CreateRelationshipDialogState();
}

class _CreateRelationshipDialogState extends State<CreateRelationshipDialog> {
  String? _characterAId;
  String? _characterBId;
  domain.RelationType _relationType = domain.RelationType.neutral;
  bool _isLoading = false;
  List<Character> _characters = [];
  bool _isLoadingCharacters = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    final repo = Get.find<CharacterRepository>();
    final characters = await repo.getCharactersByWorkId(widget.workId);
    if (mounted) setState(() { _characters = characters; _isLoadingCharacters = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.settings_createRelationshipTitle),
      content: SizedBox(
        width: 400,
        child: _isLoadingCharacters
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _characterDropdown(s.settings_characterA, _characterAId, (v) => setState(() => _characterAId = v)),
                  SizedBox(height: 16.h),
                  _characterDropdown(s.settings_characterB, _characterBId, (v) => setState(() => _characterBId = v)),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<domain.RelationType>(
                    initialValue: _relationType,
                    decoration: InputDecoration(labelText: s.settings_relationshipType, border: const OutlineInputBorder()),
                    items: domain.RelationType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _relationType = v); },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: Text(s.settings_cancel)),
        FilledButton(
          onPressed: _isLoading || _characterAId == null || _characterBId == null ? null : _create,
          child: Text(s.settings_create),
        ),
      ],
    );
  }

  Widget _characterDropdown(String label, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _characters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _create() async {
    final s = S.of(context)!;
    if (_characterAId == null || _characterBId == null) return;
    setState(() => _isLoading = true);
    try {
      final repo = Get.find<RelationshipRepository>();
      await repo.createRelationship(
        workId: widget.workId,
        characterAId: _characterAId!,
        characterBId: _characterBId!,
        relationType: _relationType,
        changeReason: s.settings_manuallyCreated,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.settings_relationshipCreated)));
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.settings_createFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class EditRelationshipDialog extends StatefulWidget {
  final domain.RelationshipHead relationship;
  final VoidCallback onUpdated;

  const EditRelationshipDialog({super.key, required this.relationship, required this.onUpdated});

  @override
  State<EditRelationshipDialog> createState() => _EditRelationshipDialogState();
}

class _EditRelationshipDialogState extends State<EditRelationshipDialog> {
  late domain.RelationType _relationType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _relationType = widget.relationship.relationType;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AlertDialog(
      title: Text(s.settings_editRelationshipTitle),
      content: SizedBox(
        width: 400,
        child: DropdownButtonFormField<domain.RelationType>(
          initialValue: _relationType,
          decoration: InputDecoration(labelText: s.settings_relationshipType, border: const OutlineInputBorder()),
          items: domain.RelationType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
          onChanged: (v) { if (v != null) setState(() => _relationType = v); },
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: Text(s.settings_cancel)),
        FilledButton(onPressed: _isLoading ? null : _save, child: Text(s.settings_save)),
      ],
    );
  }

  Future<void> _save() async {
    final s = S.of(context)!;
    setState(() => _isLoading = true);
    try {
      final repo = Get.find<RelationshipRepository>();
      await repo.updateRelationship(headId: widget.relationship.id, newRelationType: _relationType, changeReason: s.settings_manuallyEdited);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.settings_relationshipUpdated)));
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.settings_updateFailedGeneric(e.toString()))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
