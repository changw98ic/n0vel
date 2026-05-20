import 'package:novel_writer/features/story_generation/domain/contracts/pipeline_role_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PipelineRoleContract', () {
    test('concrete implementation satisfies interface', () {
      final role = _TestRole();
      expect(role.roleId, 'test_role');
      expect(role.outputType, ArtifactType.proseDraft);
    });
  });

  group('PipelineStage', () {
    test('generic constraints compile correctly', () async {
      final stage = _TestStage();
      expect(stage.roleId, 'test_stage');
      expect(stage.outputType, ArtifactType.reviewResult);
      expect(stage.maxRetries, 2);

      const input = _TestArtifact(type: ArtifactType.proseDraft);
      final output = await stage.execute(input, Object());
      expect(output.type, ArtifactType.reviewResult);
    });

    test('maxRetries can be overridden', () {
      final stage = _LowRetryStage();
      expect(stage.maxRetries, 0);
    });
  });
}

class _TestRole extends PipelineRoleContract {
  @override
  String get roleId => 'test_role';

  @override
  ArtifactType get outputType => ArtifactType.proseDraft;
}

class _TestStage extends PipelineStage<_TestArtifact, _TestArtifact> {
  @override
  String get roleId => 'test_stage';

  @override
  ArtifactType get outputType => ArtifactType.reviewResult;

  @override
  Future<_TestArtifact> execute(_TestArtifact input, Object context) async {
    return const _TestArtifact(type: ArtifactType.reviewResult);
  }
}

class _LowRetryStage extends PipelineStage<_TestArtifact, _TestArtifact> {
  @override
  int get maxRetries => 0;

  @override
  String get roleId => 'low_retry';

  @override
  ArtifactType get outputType => ArtifactType.proseDraft;

  @override
  Future<_TestArtifact> execute(_TestArtifact input, Object context) async {
    return input;
  }
}

class _TestArtifact extends TypedArtifact {
  const _TestArtifact({required this.type});

  @override
  final ArtifactType type;

  @override
  int get tokenEstimate => 10;

  @override
  Map<String, Object?> toJson() => {'type': type.name};
}
