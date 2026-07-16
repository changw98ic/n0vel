import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/novel_corpus_importer.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late Database db;
  late HybridRetriever retriever;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_corpus_importer_');
    db = sqlite3.openInMemory();
    retriever = HybridRetriever.local(db: db);
  });

  tearDown(() {
    db.dispose();
    tempDir.deleteSync(recursive: true);
  });

  test(
    'imports atoms, folds exact duplicates, and ignores contextual JSONL',
    () async {
      _writeAtoms(tempDir, 'jianlai', [
        _atom(
          id: 'jianlai_a1',
          sceneId: 'jianlai_s1',
          text: '陈平安在泥瓶巷点燃蜡烛，用桃枝轻敲墙壁。',
          hash: 'hash-a',
        ),
        _atom(
          id: 'jianlai_a2',
          sceneId: 'jianlai_s2',
          text: '  陈平安在泥瓶巷点燃蜡烛，用桃枝轻敲墙壁。  ',
          hash: 'hash-b',
          needsLlmReview: true,
        ),
        _atom(
          id: 'jianlai_a3',
          sceneId: 'jianlai_s3',
          text: '宁姚在小镇剑气冲霄，提醒少年不要回头。',
          hash: 'hash-c',
        ),
        {'atom_id': 'missing-content', 'parent_scene_id': 's4'},
      ]);
      File(
        '${tempDir.path}/jianlai/rag_contextual_atoms.jsonl',
      ).writeAsStringSync('{this is deliberately invalid json');

      final report = await NovelCorpusImporter(
        retriever: retriever,
        corpusRootPath: tempDir.path,
        batchSize: 1,
      ).importWorks(works: const ['jianlai'], limitPerWork: 0);

      expect(report.sourceFileName, 'atoms.jsonl');
      expect(report.indexedRecords, 2);
      expect(report.duplicateRecords, 1);
      expect(report.invalidRecords, 1);
      expect(_count(db, 'rag_documents'), 2);
      expect(_count(db, 'vector_embeddings'), 2);

      final row = db.select(
        'SELECT path, project_id, scope_id, category, metadata '
        'FROM rag_documents WHERE content LIKE ?',
        ['%桃枝轻敲墙壁%'],
      ).single;
      expect(row['project_id'], 'writing-reference-jianlai');
      expect(row['scope_id'], 'writing-reference-jianlai');
      expect(row['category'], MemorySourceKind.reviewFinding.name);
      expect(
        row['path'],
        matches(RegExp(r'^writing-reference/v1/jianlai/[0-9a-f]{64}$')),
      );
      final metadata =
          jsonDecode(row['metadata'] as String) as Map<String, dynamic>;
      expect(metadata['producer'], NovelCorpusImporter.producer);
      expect(metadata['rootSourceIds'], ['jianlai_s1', 'jianlai_s2']);
      expect(
        (metadata['sourceRefs'] as List).cast<Map<String, dynamic>>().map(
          (ref) => ref['sourceId'],
        ),
        ['jianlai_a1', 'jianlai_a2'],
      );
      expect(metadata['tags'], contains('style:worldbuilding_place_lore'));
      expect(metadata['tags'], contains('review:needs-llm'));
    },
  );

  test(
    'keeps projects isolated and retrieves through the real hybrid path',
    () async {
      _writeAtoms(tempDir, 'jianlai', [
        _atom(
          id: 'jianlai_a1',
          sceneId: 'jianlai_s1',
          text: '陈平安在泥瓶巷寻找烧瓷留下的线索。',
          hash: 'jianlai-hash',
        ),
        _atom(
          id: 'jianlai_a2',
          sceneId: 'jianlai_s2',
          text: '陈平安走出泥瓶巷，前往铁匠铺询问旧事。',
          hash: 'jianlai-hash-2',
        ),
      ]);
      _writeAtoms(tempDir, 'guimi', [
        _atom(
          id: 'guimi_a1',
          sceneId: 'guimi_s1',
          text: '克莱恩在灰雾之上召集塔罗会。',
          hash: 'guimi-hash',
        ),
      ]);

      final report = await NovelCorpusImporter(
        retriever: retriever,
        corpusRootPath: tempDir.path,
        batchSize: 2,
      ).importWorks(works: const ['jianlai', 'guimi'], limitPerWork: 1);

      expect(report.indexedRecords, 2);
      expect(report.works.first.truncatedByLimit, isTrue);
      expect(_count(db, 'rag_documents'), 2);

      final jianlai = await _retrieve(
        retriever,
        'writing-reference-jianlai',
        '泥瓶巷 烧瓷',
      );
      expect(jianlai.hits, hasLength(1));
      expect(jianlai.hits.single.chunk.content, contains('陈平安'));

      final leaked = await _retrieve(
        retriever,
        'writing-reference-jianlai',
        '灰雾 塔罗会',
      );
      expect(leaked.hits.map((hit) => hit.chunk.projectId).toSet(), {
        'writing-reference-jianlai',
      });
      expect(
        leaked.hits.map((hit) => hit.chunk.content).join(),
        isNot(contains('克莱恩')),
      );

      final guimi = await _retrieve(
        retriever,
        'writing-reference-guimi',
        '灰雾 塔罗会',
      );
      expect(guimi.hits, hasLength(1));
      expect(guimi.hits.single.chunk.content, contains('克莱恩'));
    },
  );

  test('does not trust a colliding source text_hash as identity', () async {
    _writeAtoms(tempDir, 'tigui', [
      _atom(
        id: 'tigui_a1',
        sceneId: 'tigui_s1',
        text: '乔汨答应去接少爷和小姐。',
        hash: 'untrusted-collision',
      ),
      _atom(
        id: 'tigui_a2',
        sceneId: 'tigui_s2',
        text: '马氏集团的车停在公馆门口。',
        hash: 'untrusted-collision',
      ),
    ]);

    final report = await NovelCorpusImporter(
      retriever: retriever,
      corpusRootPath: tempDir.path,
    ).importWorks(works: const ['tigui'], limitPerWork: 0);

    expect(report.indexedRecords, 2);
    expect(_count(db, 'rag_documents'), 2);
    expect(
      db
          .select('SELECT path FROM rag_documents')
          .map((row) => row['path'])
          .toSet(),
      hasLength(2),
    );
  });

  test('resumes from the last committed stable-hash ordinal', () async {
    _writeAtoms(tempDir, 'jianlai', [
      _atom(id: 'a1', sceneId: 's1', text: '第一条素材。', hash: 'h1'),
      _atom(id: 'a2', sceneId: 's2', text: '第二条素材。', hash: 'h2'),
      _atom(id: 'a3', sceneId: 's3', text: '第三条素材。', hash: 'h3'),
    ]);
    final importer = NovelCorpusImporter(
      retriever: retriever,
      corpusRootPath: tempDir.path,
      batchSize: 2,
    );
    var checkpoint = 0;

    await expectLater(
      importer.importWorks(
        works: const ['jianlai'],
        onProgress: (progress) async {
          checkpoint = progress.nextOrdinal;
          if (checkpoint == 2) throw StateError('simulated interruption');
        },
      ),
      throwsStateError,
    );
    expect(checkpoint, 2);
    expect(_count(db, 'vector_embeddings'), 2);

    final report = await importer.importWorks(
      works: const ['jianlai'],
      startOrdinalByWork: {'jianlai': checkpoint},
    );

    expect(report.indexedRecords, 3);
    expect(report.works.single.resumedFromOrdinal, 2);
    expect(report.works.single.writtenRecords, 1);
    expect(_count(db, 'rag_documents'), 3);
    expect(_count(db, 'vector_embeddings'), 3);
  });

  test('rejects an all-invalid corpus instead of reporting success', () async {
    _writeAtoms(tempDir, 'guimi', [
      {'atom_id': 'missing-everything-else'},
    ]);

    await expectLater(
      NovelCorpusImporter(
        retriever: retriever,
        corpusRootPath: tempDir.path,
      ).importWorks(works: const ['guimi'], limitPerWork: 0),
      throwsStateError,
    );
  });
}

int _count(Database db, String table) =>
    db.select('SELECT count(*) AS count FROM $table').single['count'] as int;

Future<StoryRetrievalPack> _retrieve(
  HybridRetriever retriever,
  String projectId,
  String text,
) {
  return retriever.retrieve(
    StoryMemoryQuery(
      projectId: projectId,
      queryType: StoryMemoryQueryType.style,
      text: text,
      maxResults: 5,
      tokenBudget: 1000,
    ),
    const RagRetrievalPolicy(
      roleId: 'novel-corpus-test',
      allowedTiers: [MemoryTier.scene],
      rankingStrategy: RankingStrategy.hybrid,
    ),
  );
}

Map<String, Object?> _atom({
  required String id,
  required String sceneId,
  required String text,
  required String hash,
  bool needsLlmReview = false,
}) => {
  'atom_id': id,
  'chunk_id': id,
  'parent_scene_id': sceneId,
  'text': text,
  'text_hash': hash,
  'needs_llm_review': needsLlmReview,
  'primary_tag': 'worldbuilding_place_lore',
  'tag_axes': ['worldbuilding'],
  'tags': [
    {'id': 'worldbuilding_place_lore'},
  ],
  'quality_flags': ['semantic_atom'],
};

void _writeAtoms(
  Directory root,
  String work,
  List<Map<String, Object?>> records,
) {
  final directory = Directory('${root.path}/$work')
    ..createSync(recursive: true);
  File(
    '${directory.path}/atoms.jsonl',
  ).writeAsStringSync(records.map(jsonEncode).join('\n'));
}
