import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  group('workspace store module logic', () {
    test('record codecs preserve values and apply fallbacks', () {
      final project = const ProjectRecord(
        id: 'project-alpha',
        sceneId: 'scene-alpha',
        title: '原项目',
        genre: '悬疑',
        summary: '原摘要',
        recentLocation: '第 1 章 / 场景 01 · 原场景',
        lastOpenedAtMs: 42,
      ).copyWith(title: '已改标题', lastOpenedAtMs: 99);
      expect(project.toJson()['title'], '已改标题');
      expect(project.toJson()['lastOpenedAtMs'], 99);

      final decodedProject = ProjectRecord.fromJson({
        'title': '导入项目',
        'lastOpenedAtMs': 'bad-opened-at',
      });
      expect(decodedProject.id, startsWith('project-'));
      expect(decodedProject.sceneId, startsWith('scene-'));
      expect(decodedProject.title, '导入项目');
      expect(decodedProject.lastOpenedAtMs, greaterThan(0));

      final scene = SceneRecord.fromJson(const {});
      expect(scene.chapterLabel, '第 1 章 / 场景 01');
      expect(scene.title, '等待命名');

      final decodedCharacter = CharacterRecord.fromJson({
        'name': 'Alpha 01',
        'linkedSceneIds': ['scene-1', '', 'scene-2'],
      });
      expect(decodedCharacter.id, 'character-alpha-01');
      expect(decodedCharacter.linkedSceneIds, ['scene-1', 'scene-2']);
      expect(decodedCharacter.copyWith(role: '侦探').toJson()['role'], '侦探');

      final decodedWorldNode = WorldNodeRecord.fromJson({
        'title': 'Harbor Gate',
        'linkedSceneIds': ['scene-3'],
      });
      expect(decodedWorldNode.id, 'world-harbor-gate');
      expect(decodedWorldNode.linkedSceneIds, ['scene-3']);
      expect(decodedWorldNode.copyWith(type: '规则').toJson()['type'], '规则');

      final decodedAuditIssue = AuditIssueRecord.fromJson({
        'title': 'Issue 01',
        'status': 'ignored',
      });
      expect(decodedAuditIssue.id, 'audit-issue-01');
      expect(decodedAuditIssue.status, AuditIssueStatus.ignored);
      expect(decodedAuditIssue.isOpen, isFalse);
      expect(decodedAuditIssue.lastAction, '等待处理');

      final decodedStyle = StyleProfileRecord.fromJson({
        'name': 'Noir',
        'jsonData': {'version': '1.0'},
      });
      expect(decodedStyle.id, 'style-noir');
      expect(decodedStyle.jsonData, {'version': '1.0'});
      expect(decodedStyle.copyWith(source: 'json').toJson()['source'], 'json');
    });

    test(
      'scene getters and operations guard invalid selection and keep ordering stable',
      () {
        final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
        addTearDown(store.dispose);

        final originalProjectId = store.currentProjectId;
        store.selectProject('missing-project');
        store.openProject('missing-project');
        expect(store.currentProjectId, originalProjectId);

        store.importJson({
          'projects': [
            {
              'id': 'project-broken',
              'sceneId': 'scene-missing',
              'title': '损坏项目',
              'genre': '测试',
              'summary': '测试摘要',
              'recentLocation': '第 9 章 / 场景 99 · 不存在场景',
              'lastOpenedAtMs': 1,
            },
          ],
          'charactersByProject': const <String, Object?>{},
          'scenesByProject': {
            'project-broken': [
              {
                'id': 'scene-real',
                'chapterLabel': '第 1 章 / 场景 01',
                'title': '真实场景',
                'summary': '真实摘要',
              },
            ],
          },
          'worldNodesByProject': const <String, Object?>{},
          'auditIssuesByProject': const <String, Object?>{},
          'projectStyles': const <String, Object?>{},
          'projectAuditStates': const <String, Object?>{},
          'projectTransferState': 'ready',
          'currentProjectId': 'project-broken',
        });

        expect(store.currentProject.id, 'project-broken');
        expect(store.currentScene.id, 'scene-real');
        store.moveCurrentSceneDown();
        expect(store.scenes.single.id, 'scene-real');

        store.selectProject('project-yangang');
        expect(store.canDeleteCurrentScene, isFalse);
        final singleSceneId = store.currentProject.sceneId;
        store.deleteCurrentScene();
        expect(store.currentProject.sceneId, singleSceneId);

        store.selectProject('project-yuechao');
        final initialSceneCount = store.scenes.length;
        store.createScene('新增场景');
        final createdSceneId = store.currentProject.sceneId;
        expect(store.scenes, hasLength(initialSceneCount + 1));
        expect(store.currentScene.title, '新增场景');

        store.renameCurrentScene('   ');
        expect(store.currentScene.title, '新增场景');
        store.updateCurrentSceneChapterLabel('   ');
        expect(store.currentScene.chapterLabel, contains('场景'));
        store.updateCurrentSceneSummary('   ');
        expect(store.currentScene.summary, '等待补充场景目标、冲突和收束条件。');

        final createdIndex = store.scenes.indexWhere(
          (scene) => scene.id == createdSceneId,
        );
        expect(createdIndex, greaterThan(0));

        store.moveCurrentSceneUp();
        final afterMoveUp = store.scenes.indexWhere(
          (scene) => scene.id == createdSceneId,
        );
        expect(afterMoveUp, createdIndex - 1);

        store.moveCurrentSceneDown();
        final afterMoveDown = store.scenes.indexWhere(
          (scene) => scene.id == createdSceneId,
        );
        expect(afterMoveDown, createdIndex);

        store.deleteCurrentScene();
        expect(
          store.scenes.any((scene) => scene.id == createdSceneId),
          isFalse,
        );
      },
    );

    test(
      'character and world-node updates preserve fallback values and linked scenes',
      () {
        final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
        addTearDown(store.dispose);

        store.createCharacter();
        final createdCharacter = store.characters.first;
        store.updateCharacter(
          characterId: createdCharacter.id,
          name: '   ',
          role: '主调查员',
          referenceSummary: '新的场景引用',
        );
        final updatedCharacter = store.characters.firstWhere(
          (character) => character.id == createdCharacter.id,
        );
        expect(updatedCharacter.name, createdCharacter.name);
        expect(updatedCharacter.role, '主调查员');
        expect(updatedCharacter.referenceSummary, '新的场景引用');

        store.setCharacterSceneLinked(
          characterId: createdCharacter.id,
          sceneId: 'scene-05-witness-room',
          linked: true,
        );
        expect(
          store.characters
              .firstWhere((character) => character.id == createdCharacter.id)
              .linkedSceneIds,
          contains('scene-05-witness-room'),
        );
        store.setCharacterSceneLinked(
          characterId: createdCharacter.id,
          sceneId: 'scene-05-witness-room',
          linked: false,
        );
        expect(
          store.characters
              .firstWhere((character) => character.id == createdCharacter.id)
              .linkedSceneIds,
          isNot(contains('scene-05-witness-room')),
        );

        store.createWorldNode();
        final createdNode = store.worldNodes.first;
        store.updateWorldNode(
          nodeId: createdNode.id,
          title: '   ',
          detail: '更新后的规则细节',
          referenceSummary: '更新后的引用',
        );
        final updatedNode = store.worldNodes.firstWhere(
          (node) => node.id == createdNode.id,
        );
        expect(updatedNode.title, createdNode.title);
        expect(updatedNode.detail, '更新后的规则细节');
        expect(updatedNode.referenceSummary, '更新后的引用');

        store.setWorldNodeSceneLinked(
          nodeId: createdNode.id,
          sceneId: 'scene-03-rainy-dock',
          linked: true,
        );
        expect(
          store.worldNodes
              .firstWhere((node) => node.id == createdNode.id)
              .linkedSceneIds,
          contains('scene-03-rainy-dock'),
        );
        store.setWorldNodeSceneLinked(
          nodeId: createdNode.id,
          sceneId: 'scene-03-rainy-dock',
          linked: false,
        );
        expect(
          store.worldNodes
              .firstWhere((node) => node.id == createdNode.id)
              .linkedSceneIds,
          isNot(contains('scene-03-rainy-dock')),
        );
      },
    );

    test(
      'style workflow validates questionnaire and json imports, profile selection, and intensity bounds',
      () {
        final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
        addTearDown(store.dispose);

        final defaultProfileId = store.selectedStyleProfileId;
        store.selectStyleProfile('missing-profile');
        expect(store.selectedStyleProfileId, defaultProfileId);

        store.setStyleInputMode(StyleInputMode.questionnaire);
        expect(store.styleInputMode, StyleInputMode.questionnaire);
        store.toggleStyleQuestionnaireTag('genre_tags', '奇幻');
        expect(
          store.styleQuestionnaireDraft['genre_tags'] as List<Object?>,
          contains('奇幻'),
        );

        store.updateStyleQuestionnaireField('genre_tags', const <String>[]);
        store.generateStyleProfileFromQuestionnaire();
        expect(
          store.styleWorkflowState,
          StyleWorkflowState.missingRequiredFields,
        );
        expect(store.styleWorkflowMessage, contains('主要体裁'));

        store.updateStyleQuestionnaireField('genre_tags', const ['悬疑']);
        store.generateStyleProfileFromQuestionnaire();
        expect(store.styleProfiles, hasLength(2));

        store.selectStyleProfile(defaultProfileId);
        expect(store.selectedStyleProfileId, defaultProfileId);

        store.setStyleJsonDraft('');
        store.importStyleFromJsonDraft();
        expect(store.styleWorkflowState, StyleWorkflowState.empty);

        store.setStyleJsonDraft('{bad-json');
        store.importStyleFromJsonDraft();
        expect(store.styleWorkflowState, StyleWorkflowState.jsonError);

        store.setStyleJsonDraft('[]');
        store.importStyleFromJsonDraft();
        expect(store.styleWorkflowState, StyleWorkflowState.validationFailed);

        store.setStyleJsonDraft(jsonEncode({'version': '2.0'}));
        store.importStyleFromJsonDraft();
        expect(store.styleWorkflowState, StyleWorkflowState.unsupportedVersion);

        store.setStyleJsonDraft(
          jsonEncode({
            'version': '1.0',
            'name': '缺字段风格',
            'language': 'zh-CN',
            'genre_tags': const [],
            'pov_mode': 'third_person_limited',
            'dialogue_ratio': 'medium',
            'description_density': 'medium',
            'emotional_intensity': 'medium',
            'rhythm_profile': 'tight',
            'taboo_patterns': const [],
          }),
        );
        store.importStyleFromJsonDraft();
        expect(
          store.styleWorkflowState,
          StyleWorkflowState.missingRequiredFields,
        );

        final withUnknownField = _validStyleJson(name: '导入风格二')
          ..['unknown_key'] = 'ignored';
        store.setStyleJsonDraft(jsonEncode(withUnknownField));
        store.importStyleFromJsonDraft();
        expect(
          store.styleWorkflowState,
          StyleWorkflowState.unknownFieldsIgnored,
        );
        expect(store.styleProfiles.first.source, 'json');
        expect(
          store.styleWarningMessages.any(
            (warning) => warning.contains('已忽略未知字段'),
          ),
          isTrue,
        );

        store.setStyleJsonDraft(jsonEncode(_validStyleJson(name: '导入风格三')));
        store.importStyleFromJsonDraft();
        expect(store.styleWorkflowState, StyleWorkflowState.maxProfilesReached);
        expect(store.styleProfiles, hasLength(3));

        store.decreaseStyleIntensity();
        expect(store.styleIntensity, 1);
        store.increaseStyleIntensity();
        store.increaseStyleIntensity();
        store.increaseStyleIntensity();
        expect(store.styleIntensity, 3);

        store.bindStyleToProject();
        expect(store.styleBindingFeedback, contains('当前强度 3x'));
        store.bindStyleToScene();
        expect(
          store.styleWorkflowState,
          StyleWorkflowState.sceneOverrideNotice,
        );
      },
    );

    test(
      'audit workflow filters, jumps, resolves, and ignores with real state transitions',
      () {
        final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
        addTearDown(store.dispose);

        final initialSelectedId = store.selectedAuditIssue.id;
        store.selectAuditIssue(-1);
        store.selectAuditIssueById('missing-issue');
        store.selectAuditIssueById(initialSelectedId);
        expect(store.selectedAuditIssue.id, initialSelectedId);

        store.setAuditFilter(AuditIssueFilter.resolved);
        expect(store.filteredAuditIssues, isEmpty);
        store.setAuditFilter(AuditIssueFilter.all);

        store.selectAuditIssue(0);
        store.jumpToSelectedAuditScene();
        expect(store.currentProject.sceneId, 'scene-05-witness-room');
        expect(store.auditActionFeedback, contains('已跳转到关联场景'));

        store.selectAuditIssue(1);
        store.jumpToSelectedAuditScene();
        expect(store.auditActionFeedback, contains('未能定位'));

        store.markSelectedAuditIssueResolved();
        expect(store.selectedAuditIssue.status, AuditIssueStatus.resolved);

        store.setAuditFilter(AuditIssueFilter.resolved);
        expect(store.filteredAuditIssues, hasLength(1));
        expect(
          store.filteredAuditIssues.single.status,
          AuditIssueStatus.resolved,
        );

        store.setAuditFilter(AuditIssueFilter.all);
        store.updateSelectedAuditIgnoreReason('');
        store.ignoreSelectedAuditIssue();
        expect(store.auditActionFeedback, '请先填写忽略原因。');

        store.updateSelectedAuditIgnoreReason('已与设定核对，无需继续追踪。');
        expect(store.selectedAuditIssue.ignoreReason, '已与设定核对，无需继续追踪。');
        store.ignoreSelectedAuditIssue();
        expect(store.selectedAuditIssue.status, AuditIssueStatus.ignored);
        expect(store.auditActionFeedback, contains('已忽略当前问题'));
      },
    );

    test(
      'importJson and importProjectJson apply legacy fallbacks, fill missing resources, and overwrite projects',
      () {
        final store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
        addTearDown(store.dispose);

        store.importJson({
          'projects': [
            <Object?, Object?>{
              'id': 'project-imported',
              'sceneId': 'scene-imported',
              'title': '导入项目',
              'genre': '实验',
              'summary': '导入摘要',
              'recentLocation': '第 7 章 / 场景 03 · 导入场景',
              'lastOpenedAtMs': 3,
            },
          ],
          'characters': [
            <Object?, Object?>{'name': 'Alpha 01'},
          ],
          'worldNodes': [
            <Object?, Object?>{'title': 'Harbor Gate'},
          ],
          'auditIssues': [
            <Object?, Object?>{
              'title': 'Issue 01',
              'evidence': '证据',
              'target': '场景 03',
            },
          ],
          'styleInputMode': 'json',
          'styleIntensity': 3,
          'styleBindingFeedback': 'legacy-style-feedback',
          'selectedAuditIssueIndex': 9,
          'auditActionFeedback': 'legacy-audit-feedback',
          'projectTransferState': 'minorVersionWarning',
          'currentProjectId': 'project-imported',
        });

        expect(store.currentProjectId, 'project-imported');
        expect(store.characters.first.name, 'Alpha 01');
        expect(store.worldNodes.first.title, 'Harbor Gate');
        expect(store.auditIssues.first.title, 'Issue 01');
        expect(store.styleInputMode, StyleInputMode.json);
        expect(store.styleIntensity, 3);
        expect(store.styleBindingFeedback, 'legacy-style-feedback');
        expect(store.auditActionFeedback, 'legacy-audit-feedback');
        expect(
          store.projectTransferState,
          ProjectTransferState.minorVersionWarning,
        );
        expect(store.currentScene.id, 'scene-imported');
        expect(store.selectedAuditIssueIndex, 0);

        final beforeNoopImport = store.currentProject.title;
        store.importProjectJson(const {}, overwriteExisting: false);
        expect(store.currentProject.title, beforeNoopImport);

        final importedProjectJson = {
          'projects': [
            <Object?, Object?>{
              'id': 'project-extra',
              'sceneId': 'scene-extra',
              'title': '额外项目',
              'genre': '悬疑',
              'summary': '额外摘要',
              'recentLocation': '第 2 章 / 场景 02 · 额外场景',
              'lastOpenedAtMs': 1,
            },
          ],
          'charactersByProject': {
            'project-extra': [
              <Object?, Object?>{'name': 'Beta 01'},
            ],
          },
          'scenesByProject': {
            'project-extra': [
              <Object?, Object?>{
                'id': 'scene-extra',
                'chapterLabel': '第 2 章 / 场景 02',
                'title': '额外场景',
                'summary': '额外场景摘要',
              },
            ],
          },
          'worldNodesByProject': {
            'project-extra': [
              <Object?, Object?>{'title': 'Outer Dock'},
            ],
          },
          'auditIssuesByProject': {
            'project-extra': [
              <Object?, Object?>{
                'title': 'Issue Extra',
                'evidence': '证据',
                'target': '场景 02',
              },
            ],
          },
          'projectStyles': const <String, Object?>{},
          'projectAuditStates': const <String, Object?>{},
        };

        store.importProjectJson(importedProjectJson, overwriteExisting: false);
        expect(store.currentProjectId, 'project-extra');
        expect(store.characters.first.name, 'Beta 01');
        expect(store.worldNodes.first.title, 'Outer Dock');
        expect(store.auditIssues.first.title, 'Issue Extra');

        store.importProjectJson({
          ...importedProjectJson,
          'projects': [
            <Object?, Object?>{
              'id': 'project-extra',
              'sceneId': 'scene-extra',
              'title': '覆盖后的项目',
              'genre': '现实',
              'summary': '覆盖摘要',
              'recentLocation': '第 2 章 / 场景 02 · 覆盖场景',
              'lastOpenedAtMs': 2,
            },
          ],
        }, overwriteExisting: true);

        expect(store.currentProject.title, '覆盖后的项目');
        expect(store.currentProject.genre, '现实');

        store.importJson({
          'projects': [
            <Object?, Object?>{
              'id': 'project-profile-fallback',
              'sceneId': 'scene-profile',
              'title': '风格项目',
              'genre': '悬疑',
              'summary': '摘要',
              'recentLocation': '第 1 章 / 场景 01 · 风格场景',
              'lastOpenedAtMs': 3,
            },
          ],
          'charactersByProject': const <String, Object?>{},
          'scenesByProject': {
            'project-profile-fallback': [
              <Object?, Object?>{
                'id': 'scene-profile',
                'chapterLabel': '第 1 章 / 场景 01',
                'title': '风格场景',
                'summary': '摘要',
              },
            ],
          },
          'worldNodesByProject': const <String, Object?>{},
          'auditIssuesByProject': const <String, Object?>{},
          'projectStyles': {
            'project-profile-fallback': {
              'styleProfiles': [
                <Object?, Object?>{
                  'id': 'style-imported',
                  'name': '导入风格',
                  'source': 'json',
                  'jsonData': _validStyleJson(name: '导入风格'),
                },
              ],
              'selectedStyleProfileId': 'missing-selected-id',
            },
          },
          'projectAuditStates': const <String, Object?>{},
          'currentProjectId': 'project-profile-fallback',
        });

        expect(store.selectedStyleProfile, isNotNull);
        expect(store.selectedStyleProfile!.id, 'style-imported');
      },
    );
  });
}

Map<String, Object?> _validStyleJson({required String name}) {
  return {
    'version': '1.0',
    'name': name,
    'language': 'zh-CN',
    'genre_tags': ['悬疑'],
    'pov_mode': 'third_person_limited',
    'dialogue_ratio': 'medium',
    'description_density': 'medium',
    'emotional_intensity': 'medium',
    'rhythm_profile': 'tight',
    'taboo_patterns': ['过度抒情'],
    'sentence_length_preference': 'short_medium',
    'tone_keywords': ['压迫'],
    'narrative_distance': 'close',
    'notes': '测试风格',
  };
}
