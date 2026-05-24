# Pipeline Golden Tests

Deterministic golden test harness for pipeline execution. These tests verify that pipeline topology, stage ordering, and event sequencing remain stable across code changes.

## Overview

Golden tests compare actual pipeline execution against versioned fixture files. Fixtures define stable input metadata and expected structured output summaries. Tests fail when actual behavior diverges from the golden snapshot.

This approach:

- **Catches regressions** in pipeline topology without real LLM calls
- **Documents expected behavior** via versioned JSON fixtures
- **Enables safe refactoring** by verifying stage order and event sequences
- **Supports CI/CD** with deterministic, fast-running tests

## Running Tests

### Normal mode (verify against fixtures)

```bash
flutter test test/golden/pipeline_golden_harness_test.dart
```

### Update mode (regenerate fixtures)

To update golden fixtures after intentional changes:

```bash
UPDATE_GOLDENS=1 flutter test test/golden/pipeline_golden_harness_test.dart
```

**Caution**: Review fixture changes carefully before committing. The update mode overwrites versioned fixtures with new output.

## Fixture Files

Fixtures are stored in `test/fixtures/pipeline_goldens/`:

| Fixture | Description | Coverage |
|---------|-------------|----------|
| `success_nine_stage.json` | Successful default-nine-stage pipeline run | All 9 stages complete |
| `recoverable_failure.json` | Recoverable stage failure at roleplay with retry | Failure handling |
| `disabled_review_stage.json` | Custom topology with review stage disabled | Stage filtering |

## Fixture Schema

Each fixture file contains:

```json
{
  "caseId": "unique-identifier",
  "description": "Human-readable description",
  "input": {
    "projectId": "project-id",
    "sceneId": "scene-id",
    "sceneIndex": 0,
    "totalScenesInChapter": 5,
    "sceneTitle": "Scene Title",
    "sceneSummary": "Scene summary text"
  },
  "presetId": "default-nine-stage",
  "expectedOutput": {
    "success": true,
    "stageCount": 9,
    "stageOrder": ["contextEnrichment", "scenePlanning", ...],
    "eventSequence": [
      {"stageId": "contextEnrichment", "eventType": "started", "artifactType": "contextAssembly"},
      {"stageId": "contextEnrichment", "eventType": "completed", "artifactType": "contextAssembly"},
      ...
    ],
    "failureCode": null,
    "failedStageId": null,
    "finalArtifactType": "sceneOutput",
    "metadata": {"totalDurationMs": 450, "tokenEstimate": 3500}
  }
}
```

## Adding New Fixtures

1. Create a new JSON file in `test/fixtures/pipeline_goldens/`
2. Run tests with `UPDATE_GOLDENS=1` to generate the initial snapshot
3. Review and commit the fixture file

## Verification After Changes

After modifying pipeline topology or stage logic:

1. Run golden tests to verify against existing fixtures
2. If changes are intentional, update fixtures with `UPDATE_GOLDENS=1`
3. Review the diff of changed fixture files
4. Commit with clear message describing the behavioral change

## Determinism Guarantees

The golden harness ensures determinism by:

- **No wall-clock timestamps**: Uses incrementing integers
- **No network calls**: Mock runner with deterministic output
- **No real LLM calls**: Uses staged artifact simulation
- **No local settings**: Independent of user configuration
- **Stable JSON ordering**: Consistent key serialization

## Related Documentation

- `test/golden/pipeline_golden_harness.dart` — Helper code and mock runner
- `test/pipeline/pipeline_replay_test.dart` — Replay-style runner pattern
- `lib/features/story_generation/data/pipeline_definition.dart` — Pipeline topology
