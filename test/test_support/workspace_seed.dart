import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

const seededProjectId = 'project-moon-echo';
const seededSceneId = 'scene-03-witness-room';
const seededInitialDraft = '她推开仓库门，雨水顺着袖口滴进掌心，远处码头的雾灯像一根迟疑的针。';

InMemoryAppWorkspaceStorage seededWorkspaceStorage() {
  return _SeededWorkspaceStorage(seededWorkspaceJson());
}

InMemoryAppVersionStorage seededVersionStorage({
  String projectId = seededProjectId,
}) {
  final storage = _SeededVersionStorage();
  final data = {
    'entries': [
      const VersionEntry(label: '初始版本', content: seededInitialDraft).toJson(),
    ],
  };
  unawaited(storage.save(data, projectId: ''));
  unawaited(storage.save(data, projectId: projectId));
  unawaited(storage.save(data, projectId: '$projectId::$seededSceneId'));
  return storage;
}

class _SeededWorkspaceStorage extends InMemoryAppWorkspaceStorage {
  _SeededWorkspaceStorage(this._data);

  Map<String, Object?>? _data;

  @override
  Future<Map<String, Object?>?> load() {
    final data = _data;
    return SynchronousFuture(
      data == null ? null : Map<String, Object?>.from(data),
    );
  }

  @override
  Future<void> save(Map<String, Object?> data) {
    _data = Map<String, Object?>.from(data);
    return SynchronousFuture(null);
  }

  @override
  Future<void> clear() {
    _data = null;
    return SynchronousFuture(null);
  }
}

class _SeededVersionStorage extends InMemoryAppVersionStorage {
  final Map<String, Map<String, Object?>> _records = {};

  @override
  Future<Map<String, Object?>?> load({required String projectId}) {
    final data = _records[projectId];
    return SynchronousFuture(
      data == null ? null : Map<String, Object?>.from(data),
    );
  }

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) {
    _records[projectId] = Map<String, Object?>.from(data);
    return SynchronousFuture(null);
  }

  @override
  Future<void> clear({String? projectId}) {
    if (projectId == null) {
      _records.clear();
    } else {
      _records.remove(projectId);
    }
    return SynchronousFuture(null);
  }

  @override
  Future<void> clearProject(String projectId) {
    final sceneScopePrefix = '$projectId::';
    _records.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
    return SynchronousFuture(null);
  }
}

Map<String, Object?> seededWorkspaceJson() {
  const projects = [
    ProjectRecord(
      id: seededProjectId,
      sceneId: seededSceneId,
      title: '月潮回声',
      genre: '都市悬疑',
      summary: '调查记者追查旧港账本，在雨夜里逼近真相。',
      recentLocation: '第 3 章 · 证人房间对峙',
      lastOpenedAtMs: 3000,
    ),
    ProjectRecord(
      id: 'project-salt-harbor',
      sceneId: 'scene-salt-01',
      title: '盐港档案',
      genre: '群像推理',
      summary: '盐港旧案重新浮出水面。',
      recentLocation: '第 1 章 · 档案室',
      lastOpenedAtMs: 2000,
    ),
    ProjectRecord(
      id: 'project-ash-weather',
      sceneId: 'scene-ash-01',
      title: '灰烬天气',
      genre: '近未来',
      summary: '灰雨笼罩的城市里，幸存者寻找失踪信标。',
      recentLocation: '第 2 章 · 灰雨街区',
      lastOpenedAtMs: 1000,
    ),
  ];

  const scenes = {
    seededProjectId: [
      SceneRecord(
        id: seededSceneId,
        chapterLabel: '第 3 章',
        title: '证人房间对峙',
        summary: '柳溪在证人房间逼问账本去向，岳刃露出破绽。',
      ),
      SceneRecord(
        id: 'scene-03-rain-dock',
        chapterLabel: '第 3 章',
        title: '雨夜码头',
        summary: '雨夜码头的雾灯下，线索被递交给柳溪。',
      ),
      SceneRecord(
        id: 'scene-07-balcony-conflict',
        chapterLabel: '第 3 章',
        title: '阳台争执',
        summary: '阳台上爆发争执，人物关系出现裂缝。',
      ),
    ],
    'project-salt-harbor': [
      SceneRecord(
        id: 'scene-salt-01',
        chapterLabel: '第 1 章',
        title: '档案室',
        summary: '旧案档案被重新调出。',
      ),
    ],
    'project-ash-weather': [
      SceneRecord(
        id: 'scene-ash-01',
        chapterLabel: '第 2 章',
        title: '灰雨街区',
        summary: '灰雨街区出现异常信号。',
      ),
    ],
  };

  const characters = {
    seededProjectId: [
      CharacterRecord(
        id: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        note: '擅长从沉默里逼出破绽。',
        linkedSceneIds: [seededSceneId],
      ),
      CharacterRecord(
        id: 'char-yueren',
        name: '岳刃',
        role: '线人',
        note: '知道账本去向，却不愿立刻交代。',
        linkedSceneIds: [seededSceneId],
      ),
    ],
  };

  const worldNodes = {
    seededProjectId: [
      WorldNodeRecord(
        id: 'world-old-port-rule',
        title: '旧港规则',
        type: '规则',
        detail: '旧港交易必须通过账本暗号确认。',
        linkedSceneIds: [seededSceneId],
      ),
    ],
  };

  const auditIssues = {
    seededProjectId: [
      AuditIssueRecord(
        id: 'audit-scene-pressure',
        title: '冲突压力不足',
        evidence: '证人房间对峙需要更清晰的压力升级。',
        target: '第 3 章 · 证人房间对峙',
      ),
    ],
  };

  return {
    'projects': [for (final project in projects) project.toJson()],
    'charactersByProject': {
      for (final entry in characters.entries)
        entry.key: [for (final character in entry.value) character.toJson()],
    },
    'scenesByProject': {
      for (final entry in scenes.entries)
        entry.key: [for (final scene in entry.value) scene.toJson()],
    },
    'worldNodesByProject': {
      for (final entry in worldNodes.entries)
        entry.key: [for (final node in entry.value) node.toJson()],
    },
    'auditIssuesByProject': {
      for (final entry in auditIssues.entries)
        entry.key: [for (final issue in entry.value) issue.toJson()],
    },
    'projectStyles': const <String, Object?>{},
    'projectAuditStates': const <String, Object?>{},
    'projectTransferState': ProjectTransferState.ready.name,
    'currentProjectId': seededProjectId,
  };
}
