import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_paragraph_adoption.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_revision_helpers.dart';

void main() {
  group('AiParagraphAdoptionHelpers', () {
    group('splitIntoParagraphs', () {
      test('splits text by double newlines', () {
        const text = 'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.';
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs(text);
        expect(result, ['First paragraph.', 'Second paragraph.', 'Third paragraph.']);
      });

      test('handles single paragraph', () {
        const text = 'Single paragraph.';
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs(text);
        expect(result, ['Single paragraph.']);
      });

      test('handles empty text', () {
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs('');
        expect(result, isEmpty);
      });

      test('handles whitespace-only text', () {
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs('   \n\n  ');
        expect(result, isEmpty);
      });

      test('trims whitespace from paragraphs', () {
        const text = '  First paragraph.  \n\n  Second paragraph.  ';
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs(text);
        expect(result, ['First paragraph.', 'Second paragraph.']);
      });

      test('splits by single newline followed by non-whitespace', () {
        const text = 'First paragraph.\nSecond paragraph.\nThird paragraph.';
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs(text);
        expect(result, ['First paragraph.', 'Second paragraph.', 'Third paragraph.']);
      });

      test('filters out empty paragraphs', () {
        const text = 'First paragraph.\n\n\n\nSecond paragraph.';
        final result = AiParagraphAdoptionHelpers.splitIntoParagraphs(text);
        expect(result, ['First paragraph.', 'Second paragraph.']);
      });
    });

    group('buildAdoptableUnits', () {
      test('returns empty list for empty blocks', () {
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: [],
          continueMode: false,
        );
        expect(result, isEmpty);
      });

      test('preserves selection-based blocks as units', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: '修改块 1',
            previousText: 'Previous text.',
            originalText: 'Original text.',
            nextText: 'Next text.',
            authorPrompt: 'Make it better',
            suggestionText: 'Suggested text.',
            selection: WorkbenchAiSelectionDraft(
              start: 0,
              end: 13,
              prompt: 'Make it better',
            ),
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        expect(result, hasLength(1));
        expect(result.first.originalText, 'Original text.');
        expect(result.first.candidateText, 'Suggested text.');
        expect(result.first.blockLabel, '修改块 1');
      });

      test('splits single rewrite block into paragraphs when counts match', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: '修改块 1',
            previousText: '',
            originalText: 'First paragraph.\n\nSecond paragraph.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Rewritten first.\n\nRewritten second.',
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        expect(result, hasLength(2));
        expect(result[0].originalText, 'First paragraph.');
        expect(result[0].candidateText, 'Rewritten first.');
        expect(result[1].originalText, 'Second paragraph.');
        expect(result[1].candidateText, 'Rewritten second.');
      });

      test('falls back to single block when paragraph counts differ significantly', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: '修改块 1',
            previousText: '',
            originalText: 'Single paragraph.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'First.\n\nSecond.\n\nThird.\n\nFourth.',
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        // Should fall back to single block since 1 vs 4 is > 50% difference
        expect(result, hasLength(1));
        expect(result.first.originalText, 'Single paragraph.');
        expect(result.first.candidateText, 'First.\n\nSecond.\n\nThird.\n\nFourth.');
      });

      test('handles continue mode with paragraph splitting', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: '续写块 1',
            previousText: '',
            originalText: 'Original paragraph.',
            nextText: '',
            authorPrompt: 'Continue',
            suggestionText: 'New first.\n\nNew second.',
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: true,
        );
        // Should have original paragraph + new candidate paragraphs
        expect(result.length, greaterThan(1));
        // First unit should be the original (keep as-is)
        expect(result.first.originalText, 'Original paragraph.');
        expect(result.first.candidateText, 'Original paragraph.');
      });

      test('handles empty original text in continue mode', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: '续写块 1',
            previousText: '',
            originalText: '',
            nextText: '',
            authorPrompt: 'Continue',
            suggestionText: 'New first.\n\nNew second.',
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: true,
        );
        // Should fall back to single block when original is empty
        expect(result, hasLength(1));
        expect(result.first.originalText, '');
        expect(result.first.candidateText, 'New first.\n\nNew second.');
      });
    });

    group('acceptedTextForUnits', () {
      test('returns original when no units', () {
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: 'Original text.',
          units: [],
          continueMode: false,
        );
        expect(result, 'Original text.');
      });

      test('joins accepted paragraphs in rewrite mode', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: 'Rewritten first.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: '1',
            originalText: 'Second.',
            candidateText: 'Rewritten second.',
            isAccepted: false,
          ),
          const AiAdoptableUnit(
            id: '2',
            originalText: 'Third.',
            candidateText: 'Rewritten third.',
            isAccepted: true,
          ),
        ];
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: '',
          units: units,
          continueMode: false,
        );
        expect(result, 'Rewritten first.\n\nSecond.\n\nRewritten third.');
      });

      test('appends accepted units in continue mode', () {
        final units = [
          const AiAdoptableUnit(
            id: 'original-0',
            originalText: 'Original paragraph.',
            candidateText: 'Original paragraph.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: 'candidate-0',
            originalText: '',
            candidateText: 'New first.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: 'candidate-1',
            originalText: '',
            candidateText: 'New second.',
            isAccepted: false,
          ),
        ];
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: 'Original paragraph.',
          units: units,
          continueMode: true,
        );
        expect(result, 'Original paragraph.\n\nNew first.');
      });

      test('keeps original when all units rejected', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: 'Rewritten first.',
            isAccepted: false,
          ),
          const AiAdoptableUnit(
            id: '1',
            originalText: 'Second.',
            candidateText: 'Rewritten second.',
            isAccepted: false,
          ),
        ];
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: 'First.\n\nSecond.',
          units: units,
          continueMode: false,
        );
        expect(result, 'First.\n\nSecond.');
      });

      test('filters out empty texts', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: '',
            isAccepted: false,
          ),
          const AiAdoptableUnit(
            id: '1',
            originalText: 'Second.',
            candidateText: 'Rewritten second.',
            isAccepted: true,
          ),
        ];
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: '',
          units: units,
          continueMode: false,
        );
        expect(result, 'Rewritten second.');
      });

      test('selection-based adoption preserves surrounding text when only one of two selections is accepted', () {
        // When accepting one selection in a draft with multiple selections,
        // the surrounding text must remain intact. Selections replace exactly
        // their [start, end) range without consuming adjacent spaces.
        const original = 'Prefix one. Middle one. Middle two. Suffix one.';
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection 1',
            previousText: '',
            originalText: 'Middle one.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Improved one.',
            selection: WorkbenchAiSelectionDraft(
              start: 12, // "Middle one." position (indices 12-22)
              end: 23,
              prompt: 'Rewrite',
            ),
          ),
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection 2',
            previousText: '',
            originalText: 'Middle two.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Improved two.',
            selection: WorkbenchAiSelectionDraft(
              start: 24, // "Middle two." position (indices 24-34)
              end: 35,
              prompt: 'Rewrite',
            ),
          ),
        ];
        final units = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        // Only accept the first selection, reject the second
        final updatedUnits = [
          units[0].copyWith(isAccepted: true),
          units[1].copyWith(isAccepted: false),
        ];
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: original,
          units: updatedUnits,
          continueMode: false,
        );
        // Exact expectation: prefix, replacement, space, rejected selection, suffix
        // Original: "Prefix one. Middle one. Middle two. Suffix one."
        // After:    "Prefix one. Improved one. Middle two. Suffix one."
        expect(result, 'Prefix one. Improved one. Middle two. Suffix one.');
      });

      test('selection-based adoption with all accepted replaces all selections', () {
        // Verify that all selections are replaced exactly at their ranges
        // with surrounding text preserved.
        const original = 'Start. First selection. Second selection. End.';
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection 1',
            previousText: '',
            originalText: 'First selection.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Improved first.',
            selection: WorkbenchAiSelectionDraft(
              start: 7,  // "First selection." at indices 7-22
              end: 23,
              prompt: 'Rewrite',
            ),
          ),
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection 2',
            previousText: '',
            originalText: 'Second selection.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Improved second.',
            selection: WorkbenchAiSelectionDraft(
              start: 24, // "Second selection." at indices 24-39
              end: 40,
              prompt: 'Rewrite',
            ),
          ),
        ];
        final units = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        // Accept both selections
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: original,
          units: units,
          continueMode: false,
        );
        // Exact expectation: prefix, replacement 1, space, replacement 2, suffix
        // Original: "Start. First selection. Second selection. End."
        // After:    "Start. Improved first. Improved second.. End."
        // Note: The selections include trailing periods, so there are consecutive
        // periods after "second" (one from replacement, one from original text)
        expect(result, 'Start. Improved first. Improved second.. End.');
      });

      test('selection-based adoption preserves selection offsets in units', () {
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection 1',
            previousText: '',
            originalText: 'Selected text.',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'Rewritten.',
            selection: WorkbenchAiSelectionDraft(
              start: 10,
              end: 25,
              prompt: 'Rewrite',
            ),
          ),
        ];
        final result = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        expect(result, hasLength(1));
        expect(result.first.selection, isNotNull);
        expect(result.first.selection!.start, 10);
        expect(result.first.selection!.end, 25);
      });

      test('selection replacement does not consume adjacent spaces', () {
        // Verify that replacements are exact to [start, end) range
        // and do NOT expand to include adjacent spaces.
        const original = 'AAA  BBB  CCC';  // Double spaces between words
        final blocks = [
          const WorkbenchAiReviewBlock(
            blockLabel: 'Selection',
            previousText: '',
            originalText: 'BBB',
            nextText: '',
            authorPrompt: 'Rewrite',
            suggestionText: 'XXX',
            selection: WorkbenchAiSelectionDraft(
              start: 5,  // "BBB" at indices 5-7
              end: 8,
              prompt: 'Rewrite',
            ),
          ),
        ];
        final units = AiParagraphAdoptionHelpers.buildAdoptableUnits(
          blocks: blocks,
          continueMode: false,
        );
        final result = AiParagraphAdoptionHelpers.acceptedTextForUnits(
          original: original,
          units: units,
          continueMode: false,
        );
        // Only "BBB" (indices 5-7) should be replaced with "XXX"
        // The two double spaces should be preserved exactly
        expect(result, 'AAA  XXX  CCC');
        expect(result, isNot(contains('AAA XXX  CCC'))); // Leading space not consumed
        expect(result, isNot(contains('AAA  XXX CCC'))); // Trailing space not consumed
      });
    });

    group('countAcceptedCandidates', () {
      test('counts units with accepted candidate text different from original', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: 'Rewritten first.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: '1',
            originalText: 'Second.',
            candidateText: 'Second.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: '2',
            originalText: 'Third.',
            candidateText: 'Rewritten third.',
            isAccepted: false,
          ),
        ];
        final count = AiParagraphAdoptionHelpers.countAcceptedCandidates(units);
        expect(count, 1); // Only first unit has accepted different candidate
      });

      test('returns zero when no candidates accepted', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: 'Rewritten first.',
            isAccepted: false,
          ),
        ];
        final count = AiParagraphAdoptionHelpers.countAcceptedCandidates(units);
        expect(count, 0);
      });
    });

    group('countKeptOriginals', () {
      test('counts units keeping original text', () {
        final units = [
          const AiAdoptableUnit(
            id: '0',
            originalText: 'First.',
            candidateText: 'Rewritten first.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: '1',
            originalText: 'Second.',
            candidateText: 'Second.',
            isAccepted: true,
          ),
          const AiAdoptableUnit(
            id: '2',
            originalText: 'Third.',
            candidateText: 'Rewritten third.',
            isAccepted: false,
          ),
        ];
        final count = AiParagraphAdoptionHelpers.countKeptOriginals(units);
        expect(count, 2); // Second and Third are keeping original
      });
    });

    group('AiAdoptableUnit', () {
      test('copyWith creates new instance with updated values', () {
        const unit = AiAdoptableUnit(
          id: '0',
          originalText: 'Original.',
          candidateText: 'Candidate.',
          isAccepted: false,
        );
        final updated = unit.copyWith(isAccepted: true);
        expect(updated.id, '0');
        expect(updated.originalText, 'Original.');
        expect(updated.candidateText, 'Candidate.');
        expect(updated.isAccepted, true);
      });

      test('effectiveText returns candidate when accepted', () {
        const unit = AiAdoptableUnit(
          id: '0',
          originalText: 'Original.',
          candidateText: 'Candidate.',
          isAccepted: true,
        );
        expect(unit.effectiveText, 'Candidate.');
      });

      test('effectiveText returns original when not accepted', () {
        const unit = AiAdoptableUnit(
          id: '0',
          originalText: 'Original.',
          candidateText: 'Candidate.',
          isAccepted: false,
        );
        expect(unit.effectiveText, 'Original.');
      });
    });
  });
}
