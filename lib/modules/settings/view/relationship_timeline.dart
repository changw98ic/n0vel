import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/domain/relationship.dart';
import 'relationship_timeline_sections.dart';

class RelationshipTimelineView extends StatefulWidget {
  final String characterId;
  final String workId;

  const RelationshipTimelineView({
    super.key,
    required this.characterId,
    required this.workId,
  });

  @override
  State<RelationshipTimelineView> createState() =>
      _RelationshipTimelineViewState();
}

class _RelationshipTimelineViewState extends State<RelationshipTimelineView> {
  List<RelationshipHead> _relationships = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repo = Get.find<RelationshipRepository>();
      final relationships =
          await repo.getRelationshipsByCharacterId(widget.characterId);
      if (mounted) {
        setState(() {
          _relationships = relationships;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text('鍔犺浇澶辫触: $_loadError'));
    }
    if (_relationships.isEmpty) {
      return const RelationshipTimelineEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _relationships.length,
      itemBuilder: (context, index) => RelationshipTimelineCard(
        relationship: _relationships[index],
        workId: widget.workId,
        currentCharacterId: widget.characterId,
        onRefresh: _loadRelationships,
      ),
    );
  }
}
