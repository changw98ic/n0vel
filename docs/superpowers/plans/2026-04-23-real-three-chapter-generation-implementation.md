# Real Three-Chapter Dynamic Agent Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real, outline-driven three-chapter generation pipeline that uses dynamic scene agents, real cloud Ollama calls, full review gates, invalidation on setting changes, and repo-visible validation artifacts.

**Architecture:** Add two new persistent state layers under `lib/app/state` for story outlines and generation state, then add a feature-scoped orchestration layer under `lib/features/story_generation/data` for dynamic cast resolution, director/role/prose/review execution, invalidation handling, and artifact recording. Reuse the existing real settings, workspace, draft, history, version, scene-context, logging, and import-export modules instead of replacing them.

**Tech Stack:** Flutter/Dart, sqlite3, existing AppLlmClient/AppSettingsStore, existing AppEventLog, zip/unzip import-export flow, flutter_test

---

## File Structure

### New files

- `lib/app/state/story_outline_storage.dart`
  - Storage interface and in-memory fallback for chapter/scene outline data
- `lib/app/state/story_outline_storage_io.dart`
  - SQLite-backed outline persistence in the authoring database
- `lib/app/state/story_outline_storage_stub.dart`
  - Non-IO fallback
- `lib/app/state/story_outline_store.dart`
  - Runtime store for chapter outlines, scene briefs, and declared scene cast
- `lib/app/state/story_generation_storage.dart`
  - Storage interface and in-memory fallback for generation state
- `lib/app/state/story_generation_storage_io.dart`
  - SQLite-backed persistence for scene/chapter runtime state
- `lib/app/state/story_generation_storage_stub.dart`
  - Non-IO fallback
- `lib/app/state/story_generation_store.dart`
  - Runtime store for scene/chapter statuses, retries, fingerprints, and invalidation
- `lib/features/story_generation/data/story_generation_models.dart`
  - Shared records/enums for scene briefs, cast members, reviews, runtime output, and fingerprints
- `lib/features/story_generation/data/scene_cast_resolver.dart`
  - Determines which scene characters become dynamic agents
- `lib/features/story_generation/data/scene_director_orchestrator.dart`
  - Runs the director pass for one scene
- `lib/features/story_generation/data/dynamic_role_agent_runner.dart`
  - Runs dynamic role prompts for one scene
- `lib/features/story_generation/data/scene_prose_generator.dart`
  - Generates scene prose from the structured scene discussion
- `lib/features/story_generation/data/scene_review_coordinator.dart`
  - Runs judge + consistency review and classifies failures
- `lib/features/story_generation/data/story_invalidation_engine.dart`
  - Applies world/character/outline/style invalidation rules
- `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
  - End-to-end chapter orchestration, scene by scene
- `lib/features/story_generation/data/artifact_recorder.dart`
  - Writes repo-visible artifacts under `artifacts/real_validation/three_chapter_run/`
- `test/story_outline_storage_io_test.dart`
- `test/story_generation_storage_io_test.dart`
- `test/story_generation_orchestrator_test.dart`
- `test/story_invalidation_engine_test.dart`
- `test/real_three_chapter_generation_test.dart`

### Modified files

- `lib/features/import_export/data/project_transfer_service.dart`
  - Export/import outline + generation state payloads
- `test/project_transfer_service_test.dart`
  - Cover the new payload files
- `README.md`
  - Document the repo-visible real validation entrypoint
- `docs/release-workflow.md`
  - Document the real three-chapter validation gate

## Task 1: Persist chapter outlines and scene cast metadata

**Files:**
- Create: `lib/app/state/story_outline_storage.dart`
- Create: `lib/app/state/story_outline_storage_io.dart`
- Create: `lib/app/state/story_outline_storage_stub.dart`
- Create: `lib/app/state/story_outline_store.dart`
- Test: `test/story_outline_storage_io_test.dart`

- [ ] **Step 1: Write the failing outline persistence tests**

```dart
test('story outline storage persists chapter scenes and scene cast', () async {
  final directory = await Directory.systemTemp.createTemp(
    'novel_writer_story_outline_storage_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  final storage = SqliteStoryOutlineStorage(
    dbPath: '${directory.path}/authoring.db',
  );

  await storage.save({
    'projectId': 'project-test',
    'chapters': [
      {
        'chapterId': 'chapter-01',
        'title': '第一章',
        'targetLength': 2000,
        'scenes': [
          {
            'sceneId': 'chapter-01-scene-01',
            'summary': '码头接头失败',
            'cast': [
              {'characterId': 'liu-xi', 'hasAction': true, 'hasDialogue': true, 'hasInteraction': true},
              {'characterId': 'crowd-extra', 'hasAction': false, 'hasDialogue': false, 'hasInteraction': false},
            ],
          },
        ],
      },
    ],
  }, projectId: 'project-test');

  final restored = await storage.load(projectId: 'project-test');

  expect(restored?['projectId'], 'project-test');
  final chapters = restored?['chapters'] as List<Object?>;
  final firstChapter = chapters.first as Map<Object?, Object?>;
  final scenes = firstChapter['scenes'] as List<Object?>;
  final firstScene = scenes.first as Map<Object?, Object?>;
  final cast = firstScene['cast'] as List<Object?>;
  expect(cast.length, 2);
});
```

- [ ] **Step 2: Run the new storage test and confirm it fails**

Run:

```bash
flutter test test/story_outline_storage_io_test.dart
```

Expected:

- FAIL with missing `SqliteStoryOutlineStorage`

- [ ] **Step 3: Add the outline storage interface and SQLite implementation**

`lib/app/state/story_outline_storage.dart`

```dart
abstract class StoryOutlineStorage {
  Future<Map<String, Object?>?> load({required String projectId});
  Future<void> save(Map<String, Object?> data, {required String projectId});
  Future<void> clear({String? projectId});
}

class InMemoryStoryOutlineStorage implements StoryOutlineStorage {
  final Map<String, Map<String, Object?>> _dataByProjectId = {};

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    return _dataByProjectId[projectId];
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    _dataByProjectId[projectId] = Map<String, Object?>.from(data);
  }

  @override
  Future<void> clear({String? projectId}) async {
    if (projectId == null) {
      _dataByProjectId.clear();
      return;
    }
    _dataByProjectId.remove(projectId);
  }
}
```

`lib/app/state/story_outline_storage_io.dart`

```dart
class SqliteStoryOutlineStorage implements StoryOutlineStorage {
  SqliteStoryOutlineStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final database = openAuthoringDatabase(_dbPath);
    try {
      database.execute(
        '''
        CREATE TABLE IF NOT EXISTS story_outlines (
          project_id TEXT PRIMARY KEY,
          payload_json TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''',
      );
      final rows = database.select(
        'SELECT payload_json FROM story_outlines WHERE project_id = ? LIMIT 1',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return jsonDecode(rows.first['payload_json'] as String)
          as Map<String, Object?>;
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) async {
    final database = openAuthoringDatabase(_dbPath);
    try {
      database.execute(
        '''
        CREATE TABLE IF NOT EXISTS story_outlines (
          project_id TEXT PRIMARY KEY,
          payload_json TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''',
      );
      database.execute(
        '''
        INSERT INTO story_outlines (project_id, payload_json, updated_at_ms)
        VALUES (?, ?, ?)
        ON CONFLICT(project_id) DO UPDATE SET
          payload_json = excluded.payload_json,
          updated_at_ms = excluded.updated_at_ms
        ''',
        [projectId, jsonEncode(data), DateTime.now().millisecondsSinceEpoch],
      );
    } finally {
      database.dispose();
    }
  }
```

- [ ] **Step 4: Add the runtime outline store**

`lib/app/state/story_outline_store.dart`

```dart
class StoryOutlineStore extends ChangeNotifier {
  StoryOutlineStore({
    StoryOutlineStorage? storage,
    AppWorkspaceStore? workspaceStore,
  }) : _storage = storage ?? createDefaultStoryOutlineStorage(),
       _workspaceStore = workspaceStore;

  final StoryOutlineStorage _storage;
  final AppWorkspaceStore? _workspaceStore;

  Map<String, Object?> _snapshot = const {
    'projectId': '',
    'chapters': <Object?>[],
  };

  Map<String, Object?> get snapshot => Map<String, Object?>.from(_snapshot);
  Map<String, Object?> exportJson() => Map<String, Object?>.from(_snapshot);

  Future<void> saveOutline(Map<String, Object?> data) async {
    _snapshot = Map<String, Object?>.from(data);
    await _storage.save(_snapshot, projectId: _resolveProjectId());
    notifyListeners();
  }

  Future<void> restore() async {
    final restored = await _storage.load(projectId: _resolveProjectId());
    if (restored == null) {
      return;
    }
    _snapshot = restored;
    notifyListeners();
  }
}
```

- [ ] **Step 5: Re-run the outline storage test and commit**

Run:

```bash
flutter test test/story_outline_storage_io_test.dart
```

Expected:

- PASS

Commit:

```bash
git add lib/app/state/story_outline_storage.dart \
  lib/app/state/story_outline_storage_io.dart \
  lib/app/state/story_outline_storage_stub.dart \
  lib/app/state/story_outline_store.dart \
  test/story_outline_storage_io_test.dart
git commit -F - <<'EOF'
Persist chapter outlines and scene cast metadata

Add a real outline store so chapter and scene planning can be saved in the
same authoring database as the rest of the writing state.

Constraint: Outline data must be project-scoped and survive store rebuilds
Rejected: Fold outline semantics into AppWorkspaceStore only | scene metadata would stay too shallow for orchestration
Confidence: high
Scope-risk: narrow
Reversibility: clean
Directive: Keep scene cast facts in outline data so orchestration does not have to re-infer them from prose
Tested: flutter test test/story_outline_storage_io_test.dart
Not-tested: Full import/export integration
EOF
```

## Task 2: Add generation state persistence and invalidation rules

**Files:**
- Create: `lib/app/state/story_generation_storage.dart`
- Create: `lib/app/state/story_generation_storage_io.dart`
- Create: `lib/app/state/story_generation_storage_stub.dart`
- Create: `lib/app/state/story_generation_store.dart`
- Create: `lib/features/story_generation/data/story_invalidation_engine.dart`
- Test: `test/story_generation_storage_io_test.dart`
- Test: `test/story_invalidation_engine_test.dart`

- [ ] **Step 1: Write failing tests for generation state and invalidation**

```dart
test('generation state persists scene review statuses and retries', () async {
  final directory = await Directory.systemTemp.createTemp(
    'novel_writer_story_generation_state_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  final storage = SqliteStoryGenerationStorage(
    dbPath: '${directory.path}/authoring.db',
  );

  await storage.save({
    'projectId': 'project-test',
    'chapters': [
      {
        'chapterId': 'chapter-01',
        'status': 'passed',
        'scenes': [
          {
            'sceneId': 'chapter-01-scene-01',
            'status': 'passed',
            'judgeStatus': 'passed',
            'consistencyStatus': 'passed',
            'proseRetryCount': 1,
            'directorRetryCount': 0,
            'upstreamFingerprint': 'world:v1|roles:v1|outline:v1',
          },
        ],
      },
    ],
  }, projectId: 'project-test');

  final restored = await storage.load(projectId: 'project-test');
  final chapters = restored?['chapters'] as List<Object?>;
  final chapter = chapters.first as Map<Object?, Object?>;
  final scenes = chapter['scenes'] as List<Object?>;
  final scene = scenes.first as Map<Object?, Object?>;
  expect(scene['status'], 'passed');
  expect(scene['proseRetryCount'], 1);
});

test('role-setting changes invalidate only impacted scenes', () {
  final engine = StoryInvalidationEngine();
  final result = engine.invalidateForChangedRole(
    roleId: 'liu-xi',
    chapters: [
      StoryChapterGenerationState(
        chapterId: 'chapter-01',
        scenes: [
          StorySceneGenerationState(
            sceneId: 'chapter-01-scene-01',
            castRoleIds: const ['liu-xi', 'yue-ren'],
            status: StorySceneGenerationStatus.passed,
            upstreamFingerprint: 'roles:v1',
          ),
          StorySceneGenerationState(
            sceneId: 'chapter-01-scene-02',
            castRoleIds: const ['fu-xingzhou'],
            status: StorySceneGenerationStatus.passed,
            upstreamFingerprint: 'roles:v1',
          ),
        ],
      ),
    ],
  );

  expect(result.first.scenes.first.status, StorySceneGenerationStatus.invalidated);
  expect(result.first.scenes.last.status, StorySceneGenerationStatus.passed);
});
```

- [ ] **Step 2: Run the new tests and confirm they fail**

Run:

```bash
flutter test test/story_generation_storage_io_test.dart
flutter test test/story_invalidation_engine_test.dart
```

Expected:

- FAIL with missing generation state types and invalidation engine

- [ ] **Step 3: Implement the generation state models and SQLite store**

`lib/app/state/story_generation_store.dart`

```dart
enum StorySceneGenerationStatus {
  pending,
  directing,
  roleRunning,
  drafting,
  reviewing,
  passed,
  invalidated,
  blocked,
}

enum StoryChapterGenerationStatus {
  pending,
  inProgress,
  reviewing,
  passed,
  invalidated,
  blocked,
}

enum StoryReviewStatus { pending, passed, failed, softFailed, hardFailed }

class StorySceneGenerationState {
  const StorySceneGenerationState({
    required this.sceneId,
    required this.castRoleIds,
    required this.status,
    required this.judgeStatus,
    required this.consistencyStatus,
    required this.proseRetryCount,
    required this.directorRetryCount,
    required this.upstreamFingerprint,
  });
  // fields + toJson/fromJson
}

class StoryChapterGenerationState {
  const StoryChapterGenerationState({
    required this.chapterId,
    required this.status,
    required this.scenes,
  });
  // fields + toJson/fromJson
}

class StoryGenerationStore extends ChangeNotifier {
  StoryGenerationStore({
    StoryGenerationStorage? storage,
    AppWorkspaceStore? workspaceStore,
  }) : _storage = storage ?? createDefaultStoryGenerationStorage(),
       _workspaceStore = workspaceStore;

  final StoryGenerationStorage _storage;
  final AppWorkspaceStore? _workspaceStore;

  Map<String, Object?> _snapshot = const {
    'projectId': '',
    'chapters': <Object?>[],
  };

  Map<String, Object?> exportJson() => Map<String, Object?>.from(_snapshot);
}
```

`lib/app/state/story_generation_storage_io.dart`

```dart
class SqliteStoryGenerationStorage implements StoryGenerationStorage {
  SqliteStoryGenerationStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    final database = openAuthoringDatabase(_dbPath);
    try {
      database.execute(
        '''
        CREATE TABLE IF NOT EXISTS story_generation_state (
          project_id TEXT PRIMARY KEY,
          payload_json TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''',
      );
      final rows = database.select(
        'SELECT payload_json FROM story_generation_state WHERE project_id = ? LIMIT 1',
        [projectId],
      );
      if (rows.isEmpty) {
        return null;
      }
      return jsonDecode(rows.first['payload_json'] as String)
          as Map<String, Object?>;
    } finally {
      database.dispose();
    }
  }
}
```

- [ ] **Step 4: Implement the invalidation engine**

`lib/features/story_generation/data/story_invalidation_engine.dart`

```dart
class StoryInvalidationEngine {
  List<StoryChapterGenerationState> invalidateForChangedRole({
    required String roleId,
    required List<StoryChapterGenerationState> chapters,
  }) {
    return [
      for (final chapter in chapters)
        chapter.copyWith(
          status: chapter.scenes.any((scene) => scene.castRoleIds.contains(roleId))
              ? StoryChapterGenerationStatus.invalidated
              : chapter.status,
          scenes: [
            for (final scene in chapter.scenes)
              scene.castRoleIds.contains(roleId)
                  ? scene.copyWith(status: StorySceneGenerationStatus.invalidated)
                  : scene,
          ],
        ),
    ];
  }
}
```

- [ ] **Step 5: Re-run the generation-state tests and commit**

Run:

```bash
flutter test test/story_generation_storage_io_test.dart
flutter test test/story_invalidation_engine_test.dart
```

Expected:

- PASS

Commit:

```bash
git add lib/app/state/story_generation_storage.dart \
  lib/app/state/story_generation_storage_io.dart \
  lib/app/state/story_generation_storage_stub.dart \
  lib/app/state/story_generation_store.dart \
  lib/features/story_generation/data/story_invalidation_engine.dart \
  test/story_generation_storage_io_test.dart \
  test/story_invalidation_engine_test.dart
git commit -F - <<'EOF'
Track scene generation state and invalidation rules

Add persistent generation state and explicit invalidation propagation so
setting changes can mark stale prose as invalid instead of silently keeping it.

Constraint: World or role changes must invalidate only affected scenes unless the rule is global
Rejected: Infer invalidation only from prose text | too fragile and not testable
Confidence: high
Scope-risk: narrow
Reversibility: clean
Directive: Treat invalidated prose as retained history, not as current valid output
Tested: flutter test test/story_generation_storage_io_test.dart
Tested: flutter test test/story_invalidation_engine_test.dart
Not-tested: End-to-end generation orchestration
EOF
```

## Task 3: Implement dynamic cast resolution and real scene orchestration

**Files:**
- Create: `lib/features/story_generation/data/story_generation_models.dart`
- Create: `lib/features/story_generation/data/scene_cast_resolver.dart`
- Create: `lib/features/story_generation/data/scene_director_orchestrator.dart`
- Create: `lib/features/story_generation/data/dynamic_role_agent_runner.dart`
- Create: `lib/features/story_generation/data/scene_prose_generator.dart`
- Create: `lib/features/story_generation/data/scene_review_coordinator.dart`
- Create: `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
- Test: `test/story_generation_orchestrator_test.dart`

- [ ] **Step 1: Write failing orchestration tests**

```dart
test('scene cast resolver excludes background characters', () {
  final resolver = SceneCastResolver();
  final cast = resolver.resolve(
    const StorySceneOutline(
      sceneId: 'scene-01',
      summary: '码头盘问',
      cast: [
        StorySceneCastMember(
          characterId: 'liu-xi',
          hasAction: true,
          hasDialogue: true,
          hasInteraction: true,
        ),
        StorySceneCastMember(
          characterId: 'dock-worker-extra',
          hasAction: false,
          hasDialogue: false,
          hasInteraction: false,
        ),
      ],
    ),
  );

  expect(cast.map((item) => item.characterId), ['liu-xi']);
});

test('chapter orchestrator reruns prose for soft review failures', () async {
  final directory = await Directory.systemTemp.createTemp(
    'novel_writer_story_generation_orchestrator_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  final settingsStore = AppSettingsStore(
    storage: FileAppSettingsStorage(file: File('${directory.path}/settings.json')),
    llmClient: FakeAppLlmClient(
      queuedResponses: const [
        'director brief',
        'liu-xi response',
        'scene prose draft 1',
        'judge failed: 用词重复',
        'consistency soft_failed',
        'scene prose draft 2',
        'judge passed',
        'consistency passed',
      ],
    ),
  );
  final orchestrator = ChapterGenerationOrchestrator(
    settingsStore: settingsStore,
  );

  final result = await orchestrator.runScene(
    chapterId: 'chapter-01',
    scene: _sceneWithCast(),
    previousChapterSummary: '前章摘要',
  );

  expect(result.proseRetryCount, 1);
  expect(result.status, StorySceneGenerationStatus.passed);
});
```

- [ ] **Step 2: Run the orchestration test and confirm it fails**

Run:

```bash
flutter test test/story_generation_orchestrator_test.dart
```

Expected:

- FAIL with missing resolver/orchestrator classes

- [ ] **Step 3: Add shared models and cast resolution**

`lib/features/story_generation/data/story_generation_models.dart`

```dart
class StorySceneCastMember {
  const StorySceneCastMember({
    required this.characterId,
    required this.hasAction,
    required this.hasDialogue,
    required this.hasInteraction,
  });
  // fields + toJson/fromJson
}

class StorySceneOutline {
  const StorySceneOutline({
    required this.sceneId,
    required this.summary,
    required this.cast,
  });
  // fields + toJson/fromJson
}
```

`lib/features/story_generation/data/scene_cast_resolver.dart`

```dart
class SceneCastResolver {
  List<StorySceneCastMember> resolve(StorySceneOutline scene) {
    return [
      for (final member in scene.cast)
        if (member.hasAction || member.hasDialogue || member.hasInteraction)
          member,
    ];
  }
}
```

- [ ] **Step 4: Implement the director, role, prose, and review services**

`lib/features/story_generation/data/scene_director_orchestrator.dart`

```dart
class SceneDirectorOrchestrator {
  SceneDirectorOrchestrator({required this.settingsStore});

  final AppSettingsStore settingsStore;

  Future<String> run({
    required StorySceneOutline scene,
    required String worldSummary,
    required String chapterSummary,
  }) async {
    final result = await settingsStore.requestAiCompletion(
      messages: [
        AppLlmChatMessage(
          role: 'user',
          content: '你是 director。请根据场景摘要输出任务卡：${scene.summary}',
        ),
      ],
    );
    if (!result.succeeded || result.text == null) {
      throw StateError('director run failed: ${result.detail}');
    }
    return result.text!;
  }
}
```

`lib/features/story_generation/data/chapter_generation_orchestrator.dart`

```dart
class ChapterGenerationOrchestrator {
  ChapterGenerationOrchestrator({
    required this.settingsStore,
    SceneCastResolver? castResolver,
    SceneDirectorOrchestrator? director,
    DynamicRoleAgentRunner? roleRunner,
    SceneProseGenerator? proseGenerator,
    SceneReviewCoordinator? reviewCoordinator,
  }) : _castResolver = castResolver ?? SceneCastResolver(),
       _director = director ?? SceneDirectorOrchestrator(settingsStore: settingsStore),
       _roleRunner = roleRunner ?? DynamicRoleAgentRunner(settingsStore: settingsStore),
       _proseGenerator = proseGenerator ?? SceneProseGenerator(settingsStore: settingsStore),
       _reviewCoordinator = reviewCoordinator ?? SceneReviewCoordinator(settingsStore: settingsStore);

  Future<StorySceneGenerationResult> runScene({
    required String chapterId,
    required StorySceneOutline scene,
    required String previousChapterSummary,
  }) async {
    final cast = _castResolver.resolve(scene);
    final directorBrief = await _director.run(
      scene: scene,
      worldSummary: 'world',
      chapterSummary: previousChapterSummary,
    );
    final turns = await _roleRunner.run(
      scene: scene,
      cast: cast,
      directorBrief: directorBrief,
    );
    var proseRetryCount = 0;
    while (true) {
      final prose = await _proseGenerator.run(
        scene: scene,
        directorBrief: directorBrief,
        turns: turns,
      );
      final review = await _reviewCoordinator.run(
        scene: scene,
        prose: prose,
      );
      if (review.shouldReplanScene) {
        return StorySceneGenerationResult.replanNeeded(
          sceneId: scene.sceneId,
          proseRetryCount: proseRetryCount,
        );
      }
      if (!review.shouldRewriteProse) {
        return StorySceneGenerationResult.passed(
          sceneId: scene.sceneId,
          finalSceneText: prose,
          proseRetryCount: proseRetryCount,
        );
      }
      proseRetryCount += 1;
      if (proseRetryCount > 2) {
        return StorySceneGenerationResult.blocked(
          sceneId: scene.sceneId,
          proseRetryCount: proseRetryCount,
        );
      }
    }
  }
}
```

- [ ] **Step 5: Re-run the orchestration tests and commit**

Run:

```bash
flutter test test/story_generation_orchestrator_test.dart
```

Expected:

- PASS

Commit:

```bash
git add lib/features/story_generation/data/story_generation_models.dart \
  lib/features/story_generation/data/scene_cast_resolver.dart \
  lib/features/story_generation/data/scene_director_orchestrator.dart \
  lib/features/story_generation/data/dynamic_role_agent_runner.dart \
  lib/features/story_generation/data/scene_prose_generator.dart \
  lib/features/story_generation/data/scene_review_coordinator.dart \
  lib/features/story_generation/data/chapter_generation_orchestrator.dart \
  test/story_generation_orchestrator_test.dart
git commit -F - <<'EOF'
Add dynamic scene orchestration for real chapter generation

Implement the real scene pipeline: director briefing, dynamic role turns,
independent prose generation, and review-driven retries.

Constraint: Dynamic cast comes from scene-outline action/dialogue/interaction flags, not fixed slots
Rejected: Reuse AppSimulationStore for orchestration | it is template-driven and not a real LLM workflow
Confidence: medium
Scope-risk: moderate
Reversibility: clean
Directive: Keep prose generation separate from the director pass so review failures can target the right stage
Tested: flutter test test/story_generation_orchestrator_test.dart
Not-tested: Real provider run and export/import integration
EOF
```

## Task 4: Integrate visible artifacts, import/export, and runtime reporting

**Files:**
- Create: `lib/features/story_generation/data/artifact_recorder.dart`
- Modify: `lib/features/import_export/data/project_transfer_service.dart`
- Test: `test/project_transfer_service_test.dart`

- [ ] **Step 1: Write failing transfer and artifact tests**

```dart
test('project transfer exports and imports outline and generation payloads', () async {
  final directory = await Directory.systemTemp.createTemp(
    'novel_writer_story_generation_transfer_test',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  final service = ProjectTransferService(
    exportsDirectory: Directory('${directory.path}/exports'),
    importsDirectory: Directory('${directory.path}/imports'),
  );

  final exportResult = await service.exportPackage(
    draftStore: sourceDraftStore,
    versionStore: sourceVersionStore,
    workspaceStore: sourceWorkspaceStore,
    aiHistoryStore: sourceAiHistoryStore,
    sceneContextStore: sourceSceneContextStore,
    simulationStore: sourceSimulationStore,
    storyOutlineStore: sourceOutlineStore,
    storyGenerationStore: sourceGenerationStore,
  );

  expect(exportResult.state, ProjectTransferState.exportSuccess);
  expect(await _packageContains(exportResult.packagePath, 'outline.json'), isTrue);
  expect(await _packageContains(exportResult.packagePath, 'generation_state.json'), isTrue);
});
```

- [ ] **Step 2: Run the transfer test and confirm it fails**

Run:

```bash
flutter test test/project_transfer_service_test.dart --plain-name "project transfer exports and imports outline and generation payloads"
```

Expected:

- FAIL with missing `storyOutlineStore` / `storyGenerationStore` parameters

- [ ] **Step 3: Extend the transfer service and add artifact recording**

`lib/features/import_export/data/project_transfer_service.dart`

```dart
Future<ProjectTransferResult> exportPackage({
  required AppDraftStore draftStore,
  required AppVersionStore versionStore,
  required AppWorkspaceStore workspaceStore,
  AppAiHistoryStore? aiHistoryStore,
  AppSceneContextStore? sceneContextStore,
  AppSimulationStore? simulationStore,
  StoryOutlineStore? storyOutlineStore,
  StoryGenerationStore? storyGenerationStore,
}) async {
  // existing payloads
  if (storyOutlineStore != null) {
    await File('${stagingDirectory.path}/outline.json')
        .writeAsString(jsonEncode(storyOutlineStore.exportJson()));
  }
  if (storyGenerationStore != null) {
    await File('${stagingDirectory.path}/generation_state.json')
        .writeAsString(jsonEncode(storyGenerationStore.exportJson()));
  }
}
```

`lib/features/story_generation/data/artifact_recorder.dart`

```dart
class ArtifactRecorder {
  ArtifactRecorder({required this.rootDirectory});

  final Directory rootDirectory;

  Future<void> recordChapterText({
    required String chapterId,
    required String text,
  }) async {
    final file = File('${rootDirectory.path}/chapters/$chapterId.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<void> recordReport({
    required String relativePath,
    required String content,
  }) async {
    final file = File('${rootDirectory.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}
```

- [ ] **Step 4: Re-run the transfer test and commit**

Run:

```bash
flutter test test/project_transfer_service_test.dart --plain-name "project transfer exports and imports outline and generation payloads"
```

Expected:

- PASS

Commit:

```bash
git add lib/features/story_generation/data/artifact_recorder.dart \
  lib/features/import_export/data/project_transfer_service.dart \
  test/project_transfer_service_test.dart
git commit -F - <<'EOF'
Export story outlines and generation state with visible artifacts

Extend project transfer so the new outline and generation state can move with
the rest of the project, and add an artifact recorder for repo-visible runs.

Constraint: Real validation artifacts must be inspectable from the repository, not hidden in temp directories
Rejected: Keep generation state out of export packages | imported projects would lose review/invalidation context
Confidence: high
Scope-risk: moderate
Reversibility: clean
Directive: New writing-pipeline state must stay aligned with project transfer payloads
Tested: flutter test test/project_transfer_service_test.dart --plain-name "project transfer exports and imports outline and generation payloads"
Not-tested: Full real provider validation
EOF
```

## Task 5: Add the repo-visible real validation run and verify it manually

**Files:**
- Create: `test/real_three_chapter_generation_test.dart`
- Modify: `README.md`
- Modify: `docs/release-workflow.md`

- [ ] **Step 1: Write the real validation test file**

```dart
test('real three chapter generation leaves visible artifacts', () async {
  final settingFile = File('setting.json');
  expect(await settingFile.exists(), isTrue, reason: 'setting.json is required');

  final outputRoot = Directory(
    'artifacts/real_validation/three_chapter_run',
  );
  if (await outputRoot.exists()) {
    await outputRoot.delete(recursive: true);
  }
  await outputRoot.create(recursive: true);

  final realSettingsStore = AppSettingsStore(
    storage: FileAppSettingsStorage(file: settingFile),
  );
  addTearDown(realSettingsStore.dispose);

  final orchestrator = ChapterGenerationOrchestrator(
    settingsStore: realSettingsStore,
    artifactRecorder: ArtifactRecorder(rootDirectory: outputRoot),
  );

  final result = await orchestrator.runThreeChapterValidation();

  expect(result.chapterSummaries.length, 3);
  expect(result.chapterSummaries.every((item) => item.actualLength >= 1800), isTrue);
  expect(File('${outputRoot.path}/reports/run-report.md').existsSync(), isTrue);
  expect(File('${outputRoot.path}/chapters/chapter-01.md').existsSync(), isTrue);
});
```

- [ ] **Step 2: Keep the real validation test out of the default fast suite**

Use a guard in the test body:

```dart
final enabled = Platform.environment['RUN_REAL_STORY_VALIDATION'] == '1';
if (!enabled) {
  return;
}
```

This keeps CI and local fast test runs sane while still allowing a real visible run on demand.

- [ ] **Step 3: Document the real validation run**

`README.md`

~~~md
## Real Three-Chapter Validation

To run the full real validation flow with repo-visible artifacts:

~~~bash
RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
~~~

Artifacts are written under:

- `artifacts/real_validation/three_chapter_run/`
~~~

`docs/release-workflow.md`

~~~md
- If the release depends on story-generation behavior, run:

~~~bash
RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
~~~

- Verify that the run leaves:
  - `chapters/chapter-01.md`
  - `chapters/chapter-02.md`
  - `chapters/chapter-03.md`
  - `reports/run-report.md`
~~~

- [ ] **Step 4: Run focused verification for the new modules**

Run:

```bash
flutter analyze
flutter test test/story_outline_storage_io_test.dart
flutter test test/story_generation_storage_io_test.dart
flutter test test/story_invalidation_engine_test.dart
flutter test test/story_generation_orchestrator_test.dart
flutter test test/project_transfer_service_test.dart
```

Expected:

- All commands PASS

- [ ] **Step 5: Run the real visible validation and commit**

Run:

```bash
RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
```

Expected:

- PASS
- Repo-visible artifacts written under `artifacts/real_validation/three_chapter_run/`

Commit:

```bash
git add test/real_three_chapter_generation_test.dart README.md docs/release-workflow.md
git commit -F - <<'EOF'
Add a repo-visible real three-chapter validation run

Add the final real validation entrypoint so the dynamic-agent pipeline can be
run against the real provider and leave inspectable artifacts in the repo.

Constraint: Real validation must produce user-visible artifacts in the workspace
Rejected: Hide the final validation inside temp-only integration tests | the operator would not be able to inspect outputs directly
Confidence: medium
Scope-risk: moderate
Reversibility: clean
Directive: Keep the real validation gate explicit and opt-in so CI does not accidentally consume external tokens
Tested: flutter analyze
Tested: flutter test test/story_outline_storage_io_test.dart
Tested: flutter test test/story_generation_storage_io_test.dart
Tested: flutter test test/story_invalidation_engine_test.dart
Tested: flutter test test/story_generation_orchestrator_test.dart
Tested: flutter test test/project_transfer_service_test.dart
Tested: RUN_REAL_STORY_VALIDATION=1 flutter test test/real_three_chapter_generation_test.dart
Not-tested: make verify-macos after the full feature lands
EOF
```

## Self-Review

- Spec coverage:
  - Dynamic cast from outline: Task 1 + Task 3
  - Director / dynamic roles / prose / review split: Task 3
  - Setting-change invalidation: Task 2
  - Repo-visible artifacts: Task 4 + Task 5
  - Export/import continuity: Task 4
  - Real three-chapter validation: Task 5
- Placeholder scan:
  - No deferred placeholders remain
- Type consistency:
  - New state types and orchestrator APIs are introduced before downstream tasks reference them
