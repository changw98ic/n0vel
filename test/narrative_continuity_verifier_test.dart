import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/narrative_continuity_verifier.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';

const _missingLedger = Object();
const _missingEntityDeclarations = Object();

void main() {
  group('NarrativeContinuityVerifier', () {
    test('flags the real three-chapter unexplained U drive possession', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: _heldDriveLedger()),
        prose: '柳溪从衣领内侧摸出一枚贴身藏着的U盘，不由分说塞进沈渡掌心。',
      );

      expect(report.passed, isFalse);
      expect(report.findings, hasLength(1));
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.holderMismatch,
      );
      expect(report.findings.single.entityId, 'evidence-drive');
      expect(report.findings.single.alias, 'U盘');
      expect(report.findings.single.expectedHolder, '沈渡');
      expect(report.findings.single.observedHolder, '柳溪');
      expect(report.findings.single.sourceSceneId, 'chapter-03/scene-03');
      expect(report.findings.single.explanation, contains('未见交接'));
      expect(report.findings.single.excerpt, contains('衣领内侧'));
    });

    test('an alias normalizes identity but does not prove a transfer', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: _heldDriveLedger()),
        prose: '柳溪从自己的衣袋里取出存储卡，确认文件仍然完整。',
      );

      expect(report.passed, isFalse);
      expect(report.findings.single.entityId, 'evidence-drive');
      expect(report.findings.single.alias, '存储卡');
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.holderMismatch,
      );
    });

    test('accepts the ledger holder retrieving the entity', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: _heldDriveLedger()),
        prose: '沈渡从贴身内袋里取出存储卡，检查封口后又收了回去。',
      );

      expect(report.passed, isTrue);
      expect(report.findings, isEmpty);
      expect(report.resultingLedgerEntries.single.holder, 'shendu');
      expect(
        report.resultingLedgerEntries.single.sourceSceneId,
        'chapter-03/scene-03',
      );
    });

    test('accepts an explicit transfer before the new holder retrieves it', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: _heldDriveLedger()),
        prose: '沈渡把U盘交给柳溪。柳溪从衣袋里取出存储卡，确认文件仍然完整。',
      );

      expect(report.passed, isTrue);
      expect(report.findings, isEmpty);
      expect(report.resultingLedgerEntries.single.holder, 'liuxi');
      expect(report.resultingLedgerEntries.single.status, 'held');
      expect(
        report.resultingLedgerEntries.single.sourceSceneId,
        'chapter-03/scene-04',
      );
      expect(report.resultingLedgerJson.single['entityId'], 'evidence-drive');
    });

    test('does not report an entity that the prose never mentions', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: _heldDriveLedger()),
        prose: '两人隔着雨幕对视，谁也没有先开口。',
      );

      expect(report.passed, isTrue);
      expect(report.findings, isEmpty);
    });

    test('flags a lost entity that reappears without a recovery source', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _heldDriveLedger(holder: '', status: 'lost'),
        ),
        prose: '柳溪从衣袋里又摸出U盘，插进终端。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.unexplainedReappearance,
      );
      expect(report.findings.single.explanation, contains('lost'));
    });

    test('accepts an explicit recovery of a lost entity', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _heldDriveLedger(holder: '', status: 'lost'),
        ),
        prose: '柳溪在积水里找回U盘，收进衣袋。片刻后，柳溪从衣袋里取出存储卡。',
      );

      expect(report.passed, isTrue);
      expect(report.findings, isEmpty);
    });

    test('legacy execution ignores malformed optional ledger metadata', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: 'not-a-list'),
        prose: '柳溪从衣袋里取出U盘。',
      );

      expect(report.passed, isTrue);
      expect(report.findings, isEmpty);
      expect(report.ledgerIgnored, isTrue);
    });

    test('formal execution fails closed on malformed ledger metadata', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: 'not-a-list', formalExecution: true),
        prose: '柳溪从衣袋里取出U盘。',
      );

      expect(report.passed, isFalse);
      expect(report.ledgerIgnored, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
      expect(report.findings.single.explanation, contains('continuityLedger'));
    });

    test('formal execution rejects an unknown canonical entity status', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: const <Object?>[
            <String, Object?>{
              'entityId': 'evidence-phone',
              'aliases': <String>['证据手机'],
              'holder': 'liuxi',
              'location': '蓝色柜机',
              'status': 'teleported',
              'sourceSceneId': 'chapter-03/scene-03',
            },
          ],
          formalExecution: true,
        ),
        prose: '柳溪没有碰证据手机。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
      expect(report.findings.single.explanation, contains('teleported'));
    });

    test('formal first scene accepts an explicitly empty ledger', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(ledger: const <Object?>[], formalExecution: true),
        prose: '柳溪推开旧港值班室的门。',
      );

      expect(report.passed, isTrue);
      expect(report.ledgerEntries, isEmpty);
      expect(report.resultingLedgerEntries, isEmpty);
      expect(report.ledgerIgnored, isFalse);
    });

    test(
      'introduces a declared entity only from exact final-prose evidence',
      () {
        final report = const NarrativeContinuityVerifier().verify(
          brief: _brief(
            ledger: const <Object?>[],
            entityDeclarations: _introductionDeclarations(),
            formalExecution: true,
          ),
          prose: '柳溪从蓝色柜机里取出证据手机，屏幕仍亮着。',
        );

        expect(report.passed, isTrue);
        expect(report.resultingLedgerEntries, hasLength(1));
        final entry = report.resultingLedgerEntries.single;
        expect(entry.entityId, 'evidence-phone');
        expect(entry.aliases, ['证据手机', '手机']);
        expect(entry.holder, 'liuxi');
        expect(entry.location, '蓝色柜机');
        expect(entry.status, 'held');
        expect(entry.sourceSceneId, 'chapter-03/scene-04');
        expect(report.resultingLedgerJson.single['location'], '蓝色柜机');
      },
    );

    test('requires every declared entity to bind at least one event', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: const <Object?>[],
          entityDeclarations: <Object?>[
            _entityDeclaration(events: const <Object?>[]),
          ],
          formalExecution: true,
        ),
        prose: '柳溪没有碰任何设备。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
      expect(report.findings.single.explanation, contains('non-empty list'));
    });

    test('observes unchanged state before an evidence-bound relocation', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-observed',
                  'kind': 'observe',
                  'evidence': '柳溪在蓝色柜机检查证据手机',
                  'alias': '证据手机',
                  'holder': 'liuxi',
                  'location': '蓝色柜机',
                  'status': 'held',
                },
                <String, Object?>{
                  'eventId': 'phone-relocated',
                  'kind': 'relocate',
                  'evidence': '柳溪把证据手机移到东堤岗亭',
                  'alias': '证据手机',
                  'fromHolder': 'liuxi',
                  'holder': 'liuxi',
                  'location': '东堤岗亭',
                  'status': 'held',
                },
              ],
            ),
          ],
        ),
        prose: '柳溪在蓝色柜机检查证据手机。随后，柳溪把证据手机移到东堤岗亭。',
      );

      expect(report.passed, isTrue);
      expect(report.resultingLedgerEntries.single.holder, 'liuxi');
      expect(report.resultingLedgerEntries.single.location, '东堤岗亭');
      expect(report.resultingLedgerEntries.single.status, 'held');
    });

    test('relocate cannot masquerade as a holder transfer', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-relocate-holder-swap',
                  'kind': 'relocate',
                  'evidence': '柳溪把证据手机移到沈渡手中',
                  'alias': '证据手机',
                  'fromHolder': 'liuxi',
                  'holder': 'shendu',
                  'location': '沈渡手中',
                  'status': 'held',
                },
              ],
            ),
          ],
        ),
        prose: '柳溪把证据手机移到沈渡手中。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
      expect(report.resultingLedgerEntries.single.holder, 'liuxi');
    });

    test('relocate cannot mutate status while preserving the holder', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-relocate-status-swap',
                  'kind': 'relocate',
                  'evidence': '柳溪把证据手机移到东堤岗亭',
                  'alias': '证据手机',
                  'fromHolder': 'liuxi',
                  'holder': 'liuxi',
                  'location': '东堤岗亭',
                  'status': 'stored',
                },
              ],
            ),
          ],
        ),
        prose: '柳溪把证据手机移到东堤岗亭。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.statusMismatch,
      );
      expect(report.resultingLedgerEntries.single.status, 'held');
    });

    test('one entity finding does not truncate later entity events', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: <Object?>[
            ..._phoneLedger(),
            <String, Object?>{
              'entityId': 'evidence-drive',
              'aliases': <String>['U盘', '存储卡'],
              'holder': 'shendu',
              'location': '内袋',
              'status': 'held',
              'sourceSceneId': 'chapter-03/scene-03',
            },
          ],
          entityDeclarations: <Object?>[
            _entityDeclaration(
              aliases: const <String>['证据手机', '手机', '黑匣子'],
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-invalid-alias',
                  'kind': 'observe',
                  'evidence': '柳溪在蓝色柜机前拿着黑匣子',
                  'alias': '黑匣子',
                  'holder': 'liuxi',
                  'location': '蓝色柜机',
                  'status': 'held',
                },
              ],
            ),
            <String, Object?>{
              'entityId': 'evidence-drive',
              'aliases': <String>['U盘', '存储卡'],
              'events': <Object?>[
                <String, Object?>{
                  'eventId': 'drive-observed',
                  'kind': 'observe',
                  'evidence': '沈渡在内袋检查U盘',
                  'alias': 'U盘',
                  'holder': 'shendu',
                  'location': '内袋',
                  'status': 'held',
                },
                <String, Object?>{
                  'eventId': 'drive-transferred',
                  'kind': 'transfer',
                  'evidence': '沈渡把U盘交到柳溪手中',
                  'alias': 'U盘',
                  'fromHolder': 'shendu',
                  'holder': 'liuxi',
                  'location': '柳溪手中',
                  'status': 'held',
                },
              ],
            },
          ],
        ),
        prose:
            '柳溪在蓝色柜机前拿着黑匣子。沈渡在内袋检查U盘。'
            '随后，沈渡把U盘交到柳溪手中。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.unexplainedRename,
      );
      final drive = report.resultingLedgerEntries.singleWhere(
        (entry) => entry.entityId == 'evidence-drive',
      );
      expect(drive.holder, 'liuxi');
      expect(drive.location, '柳溪手中');
    });

    test('fails closed when declared evidence is absent from final prose', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: const <Object?>[],
          entityDeclarations: _introductionDeclarations(),
          formalExecution: true,
        ),
        prose: '柳溪检查了空柜机，里面什么也没有。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.missingDeclaredEvidence,
      );
      expect(report.resultingLedgerEntries, isEmpty);
    });

    test(
      'persists transfer loss recovery discard and destruction transitions',
      () {
        const verifier = NarrativeContinuityVerifier();
        var ledger = verifier
            .verify(
              brief: _brief(
                ledger: const <Object?>[],
                entityDeclarations: _introductionDeclarations(),
              ),
              prose: '柳溪从蓝色柜机里取出证据手机。',
            )
            .resultingLedgerJson;

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-transfer',
                        'kind': 'transfer',
                        'evidence': '柳溪把证据手机交到沈渡手中',
                        'alias': '证据手机',
                        'fromHolder': 'liuxi',
                        'holder': 'shendu',
                        'location': '沈渡手中',
                        'status': 'held',
                      },
                    ],
                  ),
                ],
              ),
              prose: '柳溪把证据手机交到沈渡手中，叮嘱他不要关机。',
            )
            .resultingLedgerJson;
        expect(ledger.single['holder'], 'shendu');
        expect(ledger.single['location'], '沈渡手中');

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-lost',
                        'kind': 'lose',
                        'evidence': '沈渡在东堤遗失证据手机',
                        'alias': '证据手机',
                        'fromHolder': 'shendu',
                        'holder': '',
                        'location': '东堤',
                        'status': 'lost',
                      },
                    ],
                  ),
                ],
              ),
              prose: '沈渡在东堤遗失证据手机，只找到断裂的挂绳。',
            )
            .resultingLedgerJson;
        expect(ledger.single['holder'], isEmpty);
        expect(ledger.single['location'], '东堤');
        expect(ledger.single['status'], 'lost');

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-recovered',
                        'kind': 'recover',
                        'evidence': '柳溪在东堤找回证据手机',
                        'alias': '证据手机',
                        'holder': 'liuxi',
                        'location': '东堤',
                        'status': 'held',
                      },
                    ],
                  ),
                ],
              ),
              prose: '柳溪在东堤找回证据手机，立刻装进防水袋。',
            )
            .resultingLedgerJson;
        expect(ledger.single['holder'], 'liuxi');
        expect(ledger.single['status'], 'held');

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-discarded',
                        'kind': 'discard',
                        'evidence': '柳溪把证据手机丢进废弃井',
                        'alias': '证据手机',
                        'fromHolder': 'liuxi',
                        'holder': '',
                        'location': '废弃井',
                        'status': 'discarded',
                      },
                    ],
                  ),
                ],
              ),
              prose: '柳溪把证据手机丢进废弃井，随后标记了井口。',
            )
            .resultingLedgerJson;
        expect(ledger.single['status'], 'discarded');
        expect(ledger.single['location'], '废弃井');

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-recovered-again',
                        'kind': 'recover',
                        'evidence': '沈渡从废弃井捞回证据手机',
                        'alias': '证据手机',
                        'holder': 'shendu',
                        'location': '废弃井',
                        'status': 'held',
                      },
                    ],
                  ),
                ],
              ),
              prose: '沈渡从废弃井捞回证据手机，外壳已经进水。',
            )
            .resultingLedgerJson;
        expect(ledger.single['holder'], 'shendu');

        ledger = verifier
            .verify(
              brief: _brief(
                ledger: ledger,
                entityDeclarations: <Object?>[
                  _entityDeclaration(
                    events: const <Object?>[
                      <String, Object?>{
                        'eventId': 'phone-destroyed',
                        'kind': 'destroy',
                        'evidence': '沈渡在焚烧炉销毁证据手机',
                        'alias': '证据手机',
                        'fromHolder': 'shendu',
                        'holder': '',
                        'location': '焚烧炉',
                        'status': 'destroyed',
                      },
                    ],
                  ),
                ],
              ),
              prose: '沈渡在焚烧炉销毁证据手机，确认主板彻底熔化。',
            )
            .resultingLedgerJson;
        expect(ledger.single['holder'], isEmpty);
        expect(ledger.single['location'], '焚烧炉');
        expect(ledger.single['status'], 'destroyed');

        final reappearance = verifier.verify(
          brief: _brief(ledger: ledger),
          prose: '柳溪从衣袋里取出证据手机，屏幕没有裂痕。',
        );
        expect(reappearance.passed, isFalse);
        expect(
          reappearance.findings.single.kind,
          NarrativeContinuityIssueKind.unexplainedReappearance,
        );
      },
    );

    test('rejects an undeclared rename of a tracked entity', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              aliases: const <String>['证据手机', '手机', '黑匣子'],
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-new-name-without-rename',
                  'kind': 'observe',
                  'evidence': '柳溪在蓝色柜机前拿着黑匣子核对录像',
                  'alias': '黑匣子',
                  'holder': 'liuxi',
                  'location': '蓝色柜机',
                  'status': 'held',
                },
              ],
            ),
          ],
        ),
        prose: '柳溪在蓝色柜机前拿着黑匣子核对录像。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.unexplainedRename,
      );
    });

    test('rejects state evidence that omits its declared location', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-observed-with-unbound-location',
                  'kind': 'observe',
                  'evidence': '柳溪拿着证据手机核对录像',
                  'alias': '证据手机',
                  'holder': 'liuxi',
                  'location': '蓝色柜机',
                  'status': 'held',
                },
              ],
            ),
          ],
        ),
        prose: '柳溪拿着证据手机核对录像。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
      expect(report.findings.single.explanation, contains('蓝色柜机'));
    });

    test('accepts an explicit evidence-bound rename', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: _phoneLedger(),
          entityDeclarations: <Object?>[
            _entityDeclaration(
              aliases: const <String>['证据手机', '手机', '黑匣子'],
              events: const <Object?>[
                <String, Object?>{
                  'eventId': 'phone-renamed',
                  'kind': 'rename',
                  'evidence': '证据手机被柳溪改称黑匣子',
                  'alias': '黑匣子',
                  'previousAlias': '证据手机',
                },
              ],
            ),
          ],
        ),
        prose: '为避开监听，证据手机被柳溪改称黑匣子。',
      );

      expect(report.passed, isTrue);
      expect(report.resultingLedgerEntries.single.aliases, contains('黑匣子'));
    });

    test('rejects duplicate entity aliases in the declaration contract', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(
          ledger: const <Object?>[],
          entityDeclarations: <Object?>[
            _entityDeclaration(events: const <Object?>[]),
            <String, Object?>{
              'entityId': 'second-phone',
              'aliases': <String>['手机', '备用手机'],
              'events': <Object?>[],
            },
          ],
          formalExecution: true,
        ),
        prose: '柳溪没有碰任何设备。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.duplicateEntity,
      );
    });

    test('an explicitly required missing ledger fails closed', () {
      final report = const NarrativeContinuityVerifier().verify(
        brief: _brief(requireContinuityLedger: true),
        prose: '柳溪没有提到任何证物。',
      );

      expect(report.passed, isFalse);
      expect(
        report.findings.single.kind,
        NarrativeContinuityIssueKind.malformedLedger,
      );
    });
  });
}

SceneBrief _brief({
  Object? ledger = _missingLedger,
  Object? entityDeclarations = _missingEntityDeclarations,
  bool formalExecution = false,
  bool requireContinuityLedger = false,
}) {
  return SceneBrief(
    chapterId: 'chapter-03',
    chapterTitle: '第三章 天台交锋',
    sceneId: 'scene-04',
    sceneTitle: '转折与余波',
    sceneSummary: '两人必须带着证据撤离。',
    formalExecution: formalExecution,
    cast: [
      SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '记者'),
      SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '线人'),
    ],
    metadata: <String, Object?>{
      if (!identical(ledger, _missingLedger)) 'continuityLedger': ledger,
      if (!identical(entityDeclarations, _missingEntityDeclarations))
        'continuityEntityDeclarations': entityDeclarations,
      if (requireContinuityLedger) 'requireContinuityLedger': true,
    },
  );
}

List<Object?> _introductionDeclarations() => <Object?>[
  _entityDeclaration(
    events: const <Object?>[
      <String, Object?>{
        'eventId': 'phone-introduced',
        'kind': 'introduce',
        'evidence': '柳溪从蓝色柜机里取出证据手机',
        'alias': '证据手机',
        'holder': 'liuxi',
        'location': '蓝色柜机',
        'status': 'held',
      },
    ],
  ),
];

Map<String, Object?> _entityDeclaration({
  List<String> aliases = const <String>['证据手机', '手机'],
  required List<Object?> events,
}) => <String, Object?>{
  'entityId': 'evidence-phone',
  'aliases': aliases,
  'events': events,
};

List<Map<String, Object?>> _phoneLedger() => <Map<String, Object?>>[
  <String, Object?>{
    'entityId': 'evidence-phone',
    'aliases': <String>['证据手机', '手机'],
    'holder': 'liuxi',
    'location': '蓝色柜机',
    'status': 'held',
    'sourceSceneId': 'chapter-03/scene-03',
  },
];

List<Map<String, Object?>> _heldDriveLedger({
  String holder = 'shendu',
  String status = 'held',
}) {
  return [
    <String, Object?>{
      'entityId': 'evidence-drive',
      'aliases': <String>['U盘', '存储卡'],
      'holder': holder,
      'status': status,
      'sourceSceneId': 'chapter-03/scene-03',
    },
  ];
}
