import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_supervisor.dart';

void main() {
  test('public provider budget aggregates every typed model partition', () {
    expect(
      agentEvaluationAggregatePublicProviderCallCount(<String, Object?>{
        'partitions': <Object?>[
          <String, Object?>{
            'modelRouteHash': '1' * 64,
            'providerCallCount': 61,
          },
          <String, Object?>{
            'modelRouteHash': '2' * 64,
            'providerCallCount': 73,
          },
        ],
      }),
      134,
    );
  });

  test(
    'public provider budget rejects missing duplicate and malformed parts',
    () {
      for (final partitions in <Object?>[
        const <Object?>[],
        <Object?>[
          <String, Object?>{'modelRouteHash': '1' * 64, 'providerCallCount': 1},
          <String, Object?>{'modelRouteHash': '1' * 64, 'providerCallCount': 2},
        ],
        <Object?>[
          <String, Object?>{
            'modelRouteHash': '2' * 64,
            'providerCallCount': '3',
          },
        ],
        <Object?>[
          <String, Object?>{
            'modelRouteHash': 'not-a-digest',
            'providerCallCount': 3,
          },
        ],
      ]) {
        expect(
          () => agentEvaluationAggregatePublicProviderCallCount(
            <String, Object?>{'partitions': partitions},
          ),
          throwsFormatException,
        );
      }
    },
  );
}
