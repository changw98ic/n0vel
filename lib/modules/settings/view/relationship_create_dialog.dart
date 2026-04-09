import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/settings/domain/character.dart';
import '../../../features/settings/domain/relationship.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/data/relationship_repository.dart';
import '../../../core/models/value_objects/emotion_dimensions.dart';

/// 关系创建对话框
class RelationshipCreateDialog extends StatefulWidget {
  final String workId;
  final String characterId;

  const RelationshipCreateDialog({
    super.key,
    required this.workId,
    required this.characterId,
  });

  @override
  State<RelationshipCreateDialog> createState() => _RelationshipCreateDialogState();
}

class _RelationshipCreateDialogState extends State<RelationshipCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _targetCharacterId;
  RelationType _selectedRelationType = RelationType.neutral;
  int _affection = 50;
  int _trust = 50;
  int _respect = 50;
  int _fear = 0;
  final _changeReasonController = TextEditingController();
  List<Character> _characters = [];
  bool _isLoadingCharacters = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  @override
  void dispose() {
    _changeReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    final repo = Get.find<CharacterRepository>();
    final characters = await repo.getCharactersByWorkId(widget.workId);
    if (mounted) {
      setState(() {
        _characters = characters;
        _isLoadingCharacters = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建关系'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingCharacters)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildCharacterSelector(),
                const SizedBox(height: 16),
                const Text('关系类型 *'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RelationType.values.map((type) {
                    final isSelected = _selectedRelationType == type;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedRelationType = type);
                      },
                      selectedColor: _getRelationColor(type).withValues(alpha: 0.2),
                      avatar: isSelected
                          ? Icon(
                              _getRelationIcon(type),
                              size: 16,
                              color: _getRelationColor(type),
                            )
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '情感维度',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                _EmotionSlider(
                  label: '好感',
                  value: _affection,
                  color: Colors.pink,
                  icon: Icons.favorite,
                  onChanged: (value) => setState(() => _affection = value),
                ),
                _EmotionSlider(
                  label: '信任',
                  value: _trust,
                  color: Colors.blue,
                  icon: Icons.handshake,
                  onChanged: (value) => setState(() => _trust = value),
                ),
                _EmotionSlider(
                  label: '尊敬',
                  value: _respect,
                  color: Colors.amber,
                  icon: Icons.military_tech,
                  onChanged: (value) => setState(() => _respect = value),
                ),
                _EmotionSlider(
                  label: '恐惧',
                  value: _fear,
                  color: Colors.red,
                  icon: Icons.warning,
                  onChanged: (value) => setState(() => _fear = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _changeReasonController,
                  decoration: const InputDecoration(
                    labelText: '建立原因',
                    hintText: '描述建立这个关系的原因',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('创建')),
      ],
    );
  }

  Widget _buildCharacterSelector() {
    final otherCharacters = _characters
        .where((c) => c.id != widget.characterId)
        .toList();

    if (otherCharacters.isEmpty) {
      return const Text('暂无其他角色可选择');
    }

    return DropdownButtonFormField<String>(
      initialValue: _targetCharacterId,
      decoration: const InputDecoration(
        labelText: '选择角色 *',
        border: OutlineInputBorder(),
      ),
      items: otherCharacters.map((char) {
        return DropdownMenuItem(
          value: char.id,
          child: Text(char.name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _targetCharacterId = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请选择角色';
        }
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_targetCharacterId == null) {
      return;
    }

    try {
      final repository = Get.find<RelationshipRepository>();

      final emotionDimensions = EmotionDimensions(
        affection: _affection,
        trust: _trust,
        respect: _respect,
        fear: _fear,
      );

      await repository.createRelationship(
        workId: widget.workId,
        characterAId: widget.characterId,
        characterBId: _targetCharacterId!,
        relationType: _selectedRelationType,
        emotionDimensions: emotionDimensions,
        changeReason: _changeReasonController.text.trim().isEmpty
            ? null
            : _changeReasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('关系创建成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Color _getRelationColor(RelationType type) {
    return switch (type) {
      RelationType.enemy || RelationType.hostile => Colors.red,
      RelationType.neutral => Colors.grey,
      RelationType.acquaintance => Colors.blue,
      RelationType.friendly => Colors.lightBlue,
      RelationType.friend => Colors.green,
      RelationType.closeFriend => Colors.teal,
      RelationType.lover => Colors.pink,
      RelationType.family => Colors.amber,
      RelationType.mentor => Colors.purple,
      RelationType.rival => Colors.orange,
    };
  }

  IconData _getRelationIcon(RelationType type) {
    return switch (type) {
      RelationType.enemy => Icons.warning,
      RelationType.hostile => Icons.flash_on,
      RelationType.neutral => Icons.remove,
      RelationType.acquaintance => Icons.waving_hand,
      RelationType.friendly => Icons.sentiment_satisfied,
      RelationType.friend => Icons.sentiment_very_satisfied,
      RelationType.closeFriend => Icons.favorite,
      RelationType.lover => Icons.favorite_border,
      RelationType.family => Icons.family_restroom,
      RelationType.mentor => Icons.school,
      RelationType.rival => Icons.emoji_events,
    };
  }
}

/// 情感维度滑块
class _EmotionSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final ValueChanged<int> onChanged;

  const _EmotionSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: color,
              onChanged: (value) => onChanged(value.toInt()),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
