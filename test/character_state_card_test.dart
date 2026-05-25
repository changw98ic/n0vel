import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/characters/presentation/character_state_card.dart';

void main() {
  testWidgets('shows current state, recent change, and editable history', (
    tester,
  ) async {
    CharacterStateUpdate? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CharacterStateCard(
              characterName: '柳溪',
              role: '调查记者',
              currentState: '保持冷静但开始怀疑证词。',
              recentChange: '证人改变了供述顺序。',
              history: const [
                CharacterStateHistoryEntry(
                  state: '进入证人房间',
                  change: '开始追问交通调度记录',
                  recordedAtLabel: '上一场',
                ),
              ],
              historyInitiallyExpanded: true,
              onStateSubmitted: (update) => submitted = update,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(CharacterStateCard.cardKey), findsOneWidget);
    expect(find.text('柳溪'), findsOneWidget);
    expect(find.text('调查记者'), findsOneWidget);
    expect(find.text('保持冷静但开始怀疑证词。'), findsWidgets);
    expect(find.text('证人改变了供述顺序。'), findsOneWidget);
    expect(find.text('进入证人房间'), findsOneWidget);

    await tester.enterText(
      find.byKey(CharacterStateCard.stateFieldKey),
      '确认证词有裂缝，准备逼近线人。',
    );
    await tester.enterText(
      find.byKey(CharacterStateCard.changeFieldKey),
      '手动记录：证词顺序被改写',
    );
    await tester.tap(find.byKey(CharacterStateCard.saveButtonKey));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.currentState, '确认证词有裂缝，准备逼近线人。');
    expect(submitted!.recentChange, '手动记录：证词顺序被改写');
    expect(submitted!.history.first.recordedAtLabel, '刚刚');
    expect(find.text('确认证词有裂缝，准备逼近线人。'), findsWidgets);
    expect(find.text('手动记录：证词顺序被改写'), findsWidgets);
  });

  test('derives state history from character reference summary', () {
    const character = CharacterRecord(
      id: 'character-liuxi',
      name: '柳溪',
      role: '调查记者',
      note: '追问变得更直接',
      summary: '证人房间后保持警觉。',
      referenceSummary: '状态历史\n- 证人房间后保持警觉。 | 发现证词顺序被改写',
    );

    final history = characterStateHistoryForRecord(character);

    expect(characterCurrentStateForRecord(character), '证人房间后保持警觉。');
    expect(characterRecentChangeForRecord(character), '发现证词顺序被改写');
    expect(history, hasLength(1));
    expect(history.first.state, '证人房间后保持警觉。');
    expect(
      characterStateHistoryToReferenceSummary(history),
      '状态历史\n- 证人房间后保持警觉。 | 发现证词顺序被改写',
    );
  });
}
