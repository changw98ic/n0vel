import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  Database database() {
    final db = sqlite3.openInMemory();
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    return db;
  }

  AgentEvaluationPublicCustodyCapability capability(String marker) =>
      AgentEvaluationPublicCustodyCapability.auditOnlyForTest(
        capabilityHash: marker * 64,
        attestationHash: marker.toUpperCase() * 64,
        verifiedAtMs: 10,
        nonce: 'nonce-$marker-${'n' * 40}',
      );

  void insertReceipt(Database db, String marker, int attempt) {
    db.execute(
      '''INSERT INTO eval_production_authority_receipts (
           authority_receipt_hash, authority_release_hash, execution_id,
           trial_slot_id, attempt_no, attempt_run_id,
           sandbox_database_path, candidate_hash, commit_receipt_id,
           transaction_evidence_hash, prose_hash, generation_bundle_hash,
           executor_release_hash, lease_epoch, lease_owner, created_at_ms
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        marker * 64,
        'a' * 64,
        'execution',
        'slot-$attempt',
        attempt,
        'run-$attempt',
        '/private/sandbox-$attempt.sqlite',
        'b' * 64,
        'commit-$attempt',
        'c' * 64,
        'd' * 64,
        'e' * 64,
        'f' * 64,
        1,
        'owner',
        attempt,
      ],
    );
  }

  test(
    'custody capability cannot be retroactively attached to old receipt',
    () {
      final db = database();
      addTearDown(db.dispose);
      insertReceipt(db, '1', 1);

      expect(
        () =>
            installAgentEvaluationPublicCustodyCapability(db, capability('2')),
        throwsStateError,
      );
      expect(
        db.select('SELECT * FROM eval_external_custody_capabilities'),
        isEmpty,
      );
      expect(
        db.select('SELECT * FROM eval_external_custody_receipt_bindings'),
        isEmpty,
      );
    },
  );

  test(
    'active capability atomically binds first receipt and exact recovery',
    () {
      final db = database();
      addTearDown(db.dispose);
      final active = capability('2');
      installAgentEvaluationPublicCustodyCapability(db, active);

      insertReceipt(db, '3', 1);
      insertReceipt(db, '4', 2);
      final bindings = db.select(
        'SELECT * FROM eval_external_custody_receipt_bindings',
      );
      expect(bindings, hasLength(1));
      expect(bindings.single['capability_hash'], active.capabilityHash);
      expect(bindings.single['authority_receipt_hash'], '3' * 64);

      expect(
        () => installAgentEvaluationPublicCustodyCapability(db, active),
        returnsNormally,
      );
      expect(
        () =>
            installAgentEvaluationPublicCustodyCapability(db, capability('5')),
        throwsStateError,
      );
    },
  );
}
