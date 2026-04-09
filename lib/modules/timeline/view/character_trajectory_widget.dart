import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/timeline/data/timeline_repository.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/settings/domain/character.dart' as domain;

/// 角色轨迹组件
class CharacterTrajectoryWidget extends StatefulWidget {
  final String workId;

  const CharacterTrajectoryWidget({super.key, required this.workId});

  @override
  State<CharacterTrajectoryWidget> createState() =>
      _CharacterTrajectoryWidgetState();
}

class _CharacterTrajectoryWidgetState
    extends State<CharacterTrajectoryWidget> {
  String? _selectedCharacterId;
  List<domain.Character> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);
    try {
      final repository = Get.find<CharacterRepository>();
      final characters = await repository.getCharactersByWorkId(widget.workId);
      if (mounted) {
        setState(() {
          _characters = characters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 角色选择器
        Container(
          padding: EdgeInsets.all(16.w),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                  initialValue: _selectedCharacterId,
                  decoration: InputDecoration(
                    labelText: S.of(context)!.timeline_selectCharacter,
                    border: OutlineInputBorder(),
                  ),
                  items: _characters.map((char) {
                    return DropdownMenuItem(
                      value: char.id,
                      child: Text(char.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCharacterId = value);
                  },
                ),
        ),

        // 轨迹显示
        Expanded(
          child: _selectedCharacterId == null
              ? Center(child: Text(S.of(context)!.timeline_pleaseSelectCharacter))
              : _TrajectoryView(characterId: _selectedCharacterId!),
        ),
      ],
    );
  }
}

/// 轨迹视图
class _TrajectoryView extends StatelessWidget {
  final String characterId;

  const _TrajectoryView({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: S.of(context)!.timeline_trajectory),
              Tab(text: S.of(context)!.timeline_cultivationProgress),
              Tab(text: S.of(context)!.timeline_relationshipChanges),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TrajectoryTab(characterId: characterId),
                _ProgressTab(characterId: characterId),
                _RelationshipTab(characterId: characterId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨迹标签页
class _TrajectoryTab extends StatefulWidget {
  final String characterId;

  const _TrajectoryTab({required this.characterId});

  @override
  State<_TrajectoryTab> createState() => _TrajectoryTabState();
}

class _TrajectoryTabState extends State<_TrajectoryTab> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final repository = Get.find<TimelineRepository>();
      final events = await repository.getCharacterEvents(widget.characterId);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return Center(child: Text(S.of(context)!.timeline_noEventRecords));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final isLast = index == _events.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              // 时间线
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16.w),
              // 内容
              Expanded(
                child: Card(
                  margin: EdgeInsets.only(bottom: 16.h),
                  child: ListTile(
                    leading: event['locationId'] != null
                        ? const Icon(Icons.place)
                        : const Icon(Icons.event),
                    title: Text(event['name'] ?? 'Unknown'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event['chapterId'] != null)
                          Text(S.of(context)!.timeline_chapter(event['chapterId'])),
                        if (event['storyTime'] != null) Text(event['storyTime']),
                        if (event['description'] != null &&
                            event['description'].toString().isNotEmpty)
                          Text(
                            event['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 修为进度标签页
class _ProgressTab extends StatelessWidget {
  final String characterId;

  const _ProgressTab({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(S.of(context)!.timeline_cultivationProgressDisplay));
  }
}

/// 关系变化标签页
class _RelationshipTab extends StatelessWidget {
  final String characterId;

  const _RelationshipTab({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(S.of(context)!.timeline_relationshipChangesDisplay));
  }
}
