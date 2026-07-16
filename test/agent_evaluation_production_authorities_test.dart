import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
  });

  tearDown(() => db.dispose());

  test('price release is content-addressed and reprices exact calls', () {
    final route = _digest('1');
    final table = AgentEvaluationFrozenProviderPriceTable(
      tableId: 'glm-release-price-v1',
      entries: <AgentEvaluationPriceEntry>[
        AgentEvaluationPriceEntry(
          modelRouteHash: route,
          model: 'glm-release',
          promptMicrousdPerMillionTokens: 3,
          completionMicrousdPerMillionTokens: 7,
        ),
      ],
    )..publish(db, createdAtMs: 1);

    final call = AgentEvaluationProviderCallEvidence(
      sequenceNo: 1,
      modelRouteHash: route,
      model: 'glm-release',
      promptTokens: 1,
      completionTokens: 1000001,
      succeeded: true,
    );
    expect(table.costMicrousd(call), 9);

    final loaded = AgentEvaluationFrozenProviderPriceTable.load(
      db,
      releaseHash: table.releaseHash,
    );
    expect(loaded.releaseHash, table.releaseHash);
    expect(loaded.costMicrousd(call), 9);

    final changed = AgentEvaluationFrozenProviderPriceTable(
      tableId: 'glm-release-price-v2',
      entries: <AgentEvaluationPriceEntry>[
        AgentEvaluationPriceEntry(
          modelRouteHash: route,
          model: 'glm-release',
          promptMicrousdPerMillionTokens: 4,
          completionMicrousdPerMillionTokens: 7,
        ),
      ],
    );
    expect(changed.releaseHash, isNot(table.releaseHash));
    expect(
      () => table.costMicrousd(
        AgentEvaluationProviderCallEvidence(
          sequenceNo: 1,
          modelRouteHash: _digest('2'),
          model: 'glm-release',
          promptTokens: 1,
          completionTokens: 1,
          succeeded: true,
        ),
      ),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('stored price release is rehashed instead of trusted by row id', () {
    final table = AgentEvaluationFrozenProviderPriceTable(
      tableId: 'tamper-probe',
      entries: <AgentEvaluationPriceEntry>[
        AgentEvaluationPriceEntry(
          modelRouteHash: _digest('3'),
          model: 'glm-tamper',
          promptMicrousdPerMillionTokens: 1,
          completionMicrousdPerMillionTokens: 1,
        ),
      ],
    )..publish(db, createdAtMs: 1);
    db.execute('DROP TRIGGER prevent_eval_price_table_releases_update');
    db.execute(
      '''UPDATE eval_price_table_releases
         SET entries_json = replace(entries_json, '"model":"glm-tamper"',
           '"model":"forged-model"')
         WHERE price_table_hash = ?''',
      <Object?>[table.releaseHash],
    );

    expect(
      () => AgentEvaluationFrozenProviderPriceTable.load(
        db,
        releaseHash: table.releaseHash,
      ),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test(
    'safety ignores claimed safe flag and binds prose, facts, and proof',
    () {
      final verifier = AgentEvaluationFrozenSafetyVerifier.standard();
      final proof = <String, Object?>{
        'candidateHash': _digest('4'),
        'finalProseHash': _digest('5'),
        'receiptId': 'receipt-1',
        'pendingWriteSetHash': _digest('6'),
        'outboxSetHash': _digest('7'),
      };
      final passed = verifier.verify(
        prose: '林舟抵达旧港，确认七号仓仍被封锁。',
        referenceFacts: const <String, Object?>{
          'safe': false,
          'requiredLiterals': <String>['七号仓'],
          'forbiddenLiterals': <String>['泄露词'],
        },
        productionProof: proof,
      );
      expect(passed.passed, isTrue);

      final claimedSafe = verifier.verify(
        prose: '正文包含泄露词，却自称安全。',
        referenceFacts: const <String, Object?>{
          'safe': true,
          'requiredLiterals': <String>['七号仓'],
          'forbiddenLiterals': <String>['泄露词'],
        },
        productionProof: proof,
      );
      expect(claimedSafe.passed, isFalse);
      expect(claimedSafe.evidenceHash, isNot(passed.evidenceHash));

      final missingProof = verifier.verify(
        prose: '林舟抵达旧港，确认七号仓仍被封锁。',
        referenceFacts: const <String, Object?>{
          'requiredLiterals': <String>['七号仓'],
        },
        productionProof: <String, Object?>{...proof}..remove('receiptId'),
      );
      expect(missingProof.passed, isFalse);
      expect(missingProof.evidenceHash, isNot(passed.evidenceHash));
    },
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
