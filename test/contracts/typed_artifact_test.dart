import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';

void main() {
  group('ArtifactType', () {
    test('has all expected values', () {
      expect(ArtifactType.values, hasLength(11));
      expect(ArtifactType.values, containsAll([
        ArtifactType.contextAssembly,
        ArtifactType.directorPlan,
        ArtifactType.roleplaySession,
        ArtifactType.stageNarration,
        ArtifactType.beatResolution,
        ArtifactType.proseDraft,
        ArtifactType.reviewResult,
        ArtifactType.polishedProse,
        ArtifactType.sceneOutput,
        ArtifactType.thoughtAtomBatch,
        ArtifactType.retrievalPack,
      ]));
    });

    test('name property is stable for serialization', () {
      for (final t in ArtifactType.values) {
        expect(ArtifactType.values.byName(t.name), equals(t));
      }
    });
  });

  group('TypedArtifact', () {
    test('concrete subclass satisfies contract', () {
      const artifact = _TestArtifact(
        type: ArtifactType.proseDraft,
        data: {'text': 'hello'},
        tokens: 42,
      );
      expect(artifact.type, ArtifactType.proseDraft);
      expect(artifact.toJson(), {'text': 'hello'});
      expect(artifact.tokenEstimate, 42);
    });
  });
}

class _TestArtifact extends TypedArtifact {
  const _TestArtifact({
    required this.type,
    required this.data,
    required this.tokens,
  });

  @override
  final ArtifactType type;

  final Map<String, Object?> data;

  final int tokens;

  @override
  int get tokenEstimate => tokens;

  @override
  Map<String, Object?> toJson() => data;
}
