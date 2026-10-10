import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/skill_difficulty.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';

import '../../support/harness.dart';

Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('a deck page opens Inspect for that deck', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const DeckDetailPage(deckId: 'hi-en-market'));
    final l10n = l10nOf(tester);
    final button = find.text(l10n.deckInspect);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      tester.widget<InspectPage>(find.byType(InspectPage)).deckId,
      'hi-en-market',
    );
  });

  testWidgets('every card is shown in full, with its id', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-market'),
    );
    final l10n = l10nOf(tester);
    final cards = state.deckById('hi-en-market')!.cards;
    final first = cards.first;
    expect(find.text(l10n.inspectTitle('Market')), findsOneWidget);
    expect(find.text(l10n.inspectId(first.id)), findsOneWidget);
    expect(find.text(first.native), findsWidgets);
    expect(find.text(first.reading!), findsWidgets);

    // Two or three lines a card; the rest opens in place.
    final noted = cards.firstWhere((c) => c.notes.isNotEmpty);
    expect(find.textContaining(noted.notes.first.text), findsNothing);
    await scrollTo(tester, find.text(l10n.inspectId(noted.id)));
    await tester.tap(find.text(l10n.inspectId(noted.id)));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining(noted.notes.first.text));

    await scrollTo(tester, find.text(l10n.inspectId(cards.last.id)));
  });

  testWidgets('a grammar deck shows each table, a cell id per form', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-grammar-present'),
    );
    final l10n = l10nOf(tester);
    final entry = state.deckById('hi-en-grammar-present')!;
    final card = entry.cards.first;
    final cell = grammarCellOf(card, entry.deck)!;
    expect(find.text(cell.entry.gloss), findsWidgets);
    expect(find.text('${cell.pattern.slotName}: ${cell.slot}'), findsWidgets);
    expect(find.text(l10n.inspectId(card.id)), findsOneWidget);
    await scrollTo(tester, find.text(l10n.inspectId(entry.cards.last.id)));
  });

  testWidgets('a reading deck shows passages, questions with the right '
      'answer marked, and the glossary', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'bn-en-reading-sahaj-path-1'),
    );
    final l10n = l10nOf(tester);
    final passage = state
        .deckById('bn-en-reading-sahaj-path-1')!
        .deck
        .passages
        .first;
    expect(find.text(l10n.inspectId(passage.id)), findsOneWidget);
    expect(find.text(passage.title), findsOneWidget);
    final question = passage.questions.first;
    await scrollTo(tester, find.text(l10n.inspectId(question.id)));
    await tester.ensureVisible(find.text(l10n.inspectId(question.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.inspectId(question.id)));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(l10n.readingChoiceRight))),
      findsWidgets,
    );
  });

  group('how hard, by skill', () {
    final monday = DateTime(2026, 10, 5, 19);

    /// Progress where [card] was answered in each of [answers], in order.
    MemoryProgress answered(
      String deck,
      String card,
      List<(DrillMode, int)> answers,
    ) {
      final progress = MemoryProgress();
      for (final (i, (mode, grade)) in answers.indexed) {
        progress.record(
          deckId: deck,
          cardId: card,
          mode: mode,
          grade: grade,
          now: monday.add(Duration(days: i)),
          answerGiven: 'typed',
        );
      }
      return progress;
    }

    Future<void> open(WidgetTester tester, String id) async {
      final l10n = l10nOf(tester);
      await scrollTo(tester, find.text(l10n.inspectId(id)));
      await tester.ensureVisible(find.text(l10n.inspectId(id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.inspectId(id)));
      await tester.pumpAndSettle();
    }

    testWidgets('a card shows its D in each skill answered, and nothing for '
        'the others', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      final state = AppState.test(progress: progress);
      await state.load();
      final card = state.deckById('hi-en-market')!.cards.first;
      for (final (i, (mode, grade)) in const <(DrillMode, int)>[
        (DrillMode.listening, 1),
        (DrillMode.listening, 0),
        (DrillMode.listening, 1),
        (DrillMode.production, 4),
      ].indexed) {
        progress.record(
          deckId: 'hi-en-market',
          cardId: card.id,
          mode: mode,
          grade: grade,
          now: monday.add(Duration(days: i)),
          answerGiven: 'typed',
        );
      }
      await pumpScreen(
        tester,
        const InspectPage(deckId: 'hi-en-market'),
        state: state,
      );
      final l10n = l10nOf(tester);
      final hear = SkillDifficulty(
        DrillMode.listening,
        progress.stateOf(card.id, DrillMode.listening)!.difficulty,
      );
      final write = SkillDifficulty(
        DrillMode.production,
        progress.stateOf(card.id, DrillMode.production)!.difficulty,
      );
      expect(hear.lean, DifficultyLean.harder);
      expect(write.lean, DifficultyLean.easier);
      String line(SkillDifficulty d) =>
          l10n.inspectDifficultyIn(d.mode.name, d.shown, d.lean.name);

      // Closed, the row shows none of it.
      expect(find.text(l10n.inspectDifficulty), findsNothing);
      await open(tester, card.id);
      await scrollTo(tester, find.text(line(hear)));
      expect(find.text(l10n.inspectDifficulty), findsOneWidget);
      expect(find.text(line(hear)), findsOneWidget);
      expect(find.text(line(write)), findsOneWidget);
      expect(line(hear), contains('Hear: ${hear.shown} of 10, harder'));
      expect(line(write), contains('Write: ${write.shown} of 10, easier'));
      // Write is listed before Hear, as the skills are ordered.
      expect(
        tester.getTopLeft(find.text(line(write))).dy,
        lessThan(tester.getTopLeft(find.text(line(hear))).dy),
      );
      for (final mode in <DrillMode>[
        DrillMode.recognition,
        DrillMode.speaking,
        DrillMode.grammarUnderstood,
        DrillMode.grammar,
      ]) {
        final skill = l10n.inspectDifficultyIn(mode.name, 1, 'easier');
        expect(
          find.text(skill),
          findsNothing,
          reason: '${mode.name} was never answered',
        );
        expect(
          find.textContaining(skill.substring(0, skill.indexOf(':') + 1)),
          findsNothing,
          reason: '${mode.name} was never answered',
        );
      }

      // Another card, never answered, shows no difficulty in its row.
      final other = state.deckById('hi-en-market')!.cards[1];
      await scrollTo(tester, find.text(l10n.inspectId(other.id)));
      final row = find.ancestor(
        of: find.text(l10n.inspectId(other.id)),
        matching: find.byWidgetPredicate(
          (w) => w is ListTile || w is ExpansionTile,
        ),
      );
      if (tester.any(
        find.ancestor(
          of: find.text(l10n.inspectId(other.id)),
          matching: find.byType(ExpansionTile),
        ),
      )) {
        await open(tester, other.id);
      }
      expect(
        find.descendant(
          of: row.first,
          matching: find.text(l10n.inspectDifficulty),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: row.first,
          matching: find.textContaining(' of 10, '),
        ),
        findsNothing,
      );
    });

    testWidgets('a grammar cell shows understood and produced apart', (
      tester,
    ) async {
      usePhone(tester);
      final probe = AppState.test();
      await probe.load();
      final card = probe.deckById('hi-en-grammar-present')!.cards.first;
      final progress = answered('hi-en-grammar-present', card.id, const [
        (DrillMode.grammarUnderstood, 4),
        (DrillMode.grammar, 1),
        (DrillMode.grammar, 1),
        (DrillMode.grammar, 0),
      ]);
      await pumpScreen(
        tester,
        const InspectPage(deckId: 'hi-en-grammar-present'),
        state: AppState.test(progress: progress),
      );
      final l10n = l10nOf(tester);
      await open(tester, card.id);
      for (final mode in <DrillMode>[
        DrillMode.grammarUnderstood,
        DrillMode.grammar,
      ]) {
        final d = SkillDifficulty(
          mode,
          progress.stateOf(card.id, mode)!.difficulty,
        );
        final text = l10n.inspectDifficultyIn(mode.name, d.shown, d.lean.name);
        await scrollTo(tester, find.text(text));
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('Grammar understood: '), findsOneWidget);
      expect(find.textContaining('Grammar produced: '), findsOneWidget);
    });

    testWidgets('a card never answered shows no difficulty, and opens only '
        'for what it has', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const InspectPage(deckId: 'hi-en-market'));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.inspectDifficulty), findsNothing);
      expect(find.textContaining(' of 10, '), findsNothing);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('is read as a heading and plain lines, with good contrast '
          '(${mode.name})', (tester) async {
        usePhone(tester);
        final handle = tester.ensureSemantics();
        final probe = AppState.test();
        await probe.load();
        final card = probe.deckById('hi-en-market')!.cards.first;
        final progress = answered('hi-en-market', card.id, const [
          (DrillMode.speaking, 1),
        ]);
        await pumpScreen(
          tester,
          const InspectPage(deckId: 'hi-en-market'),
          state: AppState.test(progress: progress),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        await open(tester, card.id);
        final d = SkillDifficulty(
          DrillMode.speaking,
          progress.stateOf(card.id, DrillMode.speaking)!.difficulty,
        );
        final text = l10n.inspectDifficultyIn('speaking', d.shown, d.lean.name);
        await scrollTo(tester, find.text(text));
        expect(text, startsWith('Say: '));
        expect(find.bySemanticsLabel(text), findsOneWidget);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(
              RegExp('^${RegExp.escape(l10n.inspectDifficulty)}'),
            ),
          ),
          isSemantics(isHeader: true),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  testWidgets('a deck that is not loaded says so', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const InspectPage(deckId: 'xx-en-nothing'),
      state: AppState.test(),
    );
    expect(find.text(l10nOf(tester).deckNotFound), findsOneWidget);
  });
}
