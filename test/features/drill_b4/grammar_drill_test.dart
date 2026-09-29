import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/grammar_pattern.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/incoming.dart';

import '../../support/harness.dart';

/// The real bundled pattern, as the drill reads it.
Future<GrammarPattern> realPattern() async {
  final state = AppState.test();
  await state.load();
  return state.deckById(grammarFixtureDeckId)!.deck.pattern!;
}

AppState grammarOn() => AppState.test(features: FeatureRegistry.all());

Future<void> typeAndCheck(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tester.tap(find.text(l10nOf(tester).drillCheck));
  await tester.pumpAndSettle();
}

FeedbackBanner banner(WidgetTester tester) =>
    tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('grammar cells', () {
    test('fill the prompt from the entry and slot, and skip missing forms', () {
      const pattern = GrammarPattern(
        name: 'fixture',
        slotName: 'person',
        slots: <String>['one', 'two'],
        prompt: '{slot}: {lemma} ({gloss}), {slot}',
        entries: <PatternEntry>[
          PatternEntry(
            lemma: 'be',
            gloss: 'exist',
            forms: <String, String?>{'one': 'am', 'two': null},
          ),
        ],
      );
      final cells = grammarCells(pattern);
      expect(cells, hasLength(1));
      expect(cells.single.prompt, 'one: be (exist), one');
      expect(cells.single.answer, 'am');
      expect(cells.single.table, <({String slot, String? form})>[
        (slot: 'one', form: 'am'),
        (slot: 'two', form: null),
      ]);
    });

    test('are found in the real pattern by lemma and slot', () async {
      final pattern = await realPattern();
      expect(
        grammarCells(pattern),
        hasLength(pattern.entries.length * pattern.slots.length),
      );
      final cell = findGrammarCell(pattern, lemma: 'hablar', slot: 'vosotros')!;
      expect(cell.slotIndex, pattern.slots.indexOf('vosotros'));
      expect(cell.answer, 'habláis');
      expect(cell.prompt, 'hablar (to speak) — vosotros');
    });
  });

  group('grammar drill', () {
    testWidgets('asks with the pattern prompt and the slot', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
      final l10n = l10nOf(tester);
      expect(find.text('hablar (to speak) — vosotros'), findsOneWidget);
      expect(find.text(l10n.drillTypeSlot('vosotros')), findsOneWidget);
      expect(find.text(l10n.drillPositionShort(1, 3)), findsOneWidget);
      expect(find.text('hablo'), findsNothing, reason: 'no table yet');
      expect(find.byType(IncomingFeature), findsNothing);
    });

    testWidgets('a wrong answer shows the whole table, the asked cell marked', (
      tester,
    ) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final pattern = await realPattern();
      await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
      await typeAndCheck(tester, 'hablamos');
      final l10n = l10nOf(tester);

      expect(banner(tester).kind, FeedbackKind.wrong);
      expect(banner(tester).title, l10n.feedbackWrong);
      expect(banner(tester).detail, l10n.feedbackAnswer('habláis'));

      final row = findGrammarCell(pattern, lemma: 'hablar', slot: 'yo')!.table;
      for (final cell in row) {
        // The asked slot is in the chip too.
        expect(find.text(cell.slot), findsWidgets);
        expect(find.text(cell.form!), findsOneWidget);
        final node = tester.getSemantics(find.text(cell.form!));
        if (cell.slot == 'vosotros') {
          expect(node, isSemantics(isSelected: true));
        } else {
          expect(node, isNot(isSemantics(isSelected: true)));
        }
      }
      expect(find.text(pattern.notes!), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a right answer says so, then Continue asks the next cell', (
      tester,
    ) async {
      usePhone(tester);
      final pattern = await realPattern();
      await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
      await typeAndCheck(tester, 'habláis');
      final l10n = l10nOf(tester);

      expect(banner(tester).kind, FeedbackKind.correct);
      expect(banner(tester).title, l10n.feedbackCorrect);
      expect(find.text('hablamos'), findsOneWidget, reason: 'the table');
      expect(find.text(pattern.notes!), findsOneWidget);

      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(find.text('trabajar (to work) — nosotros'), findsOneWidget);
      expect(find.text(l10n.drillPositionShort(2, 3)), findsOneWidget);
      expect(find.byType(FeedbackBanner), findsNothing);
      expect(find.text(pattern.notes!), findsNothing);
    });

    testWidgets('is disabled while its feature is incoming', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const GrammarDrill(),
        state: AppState.test(
          features: FeatureRegistry.only(
            Feature.available.difference(const <Feature>{Feature.drillGrammar}),
          ),
        ),
      );
      final l10n = l10nOf(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text(l10n.incomingBadge), findsOneWidget);

      await tester.tap(find.byType(IncomingFeature));
      await tester.pump();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget);
      expect(find.byType(FeedbackBanner), findsNothing);
    });

    testWidgets('with its drill on, a session reaches the expanded cards', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck(
            grammarFixtureDeckId,
            skill: Skill.grammar,
          ),
        ),
        state: grammarOn(),
      );
      // The cards exist now (#2); #14 gives them the grammar screen.
      expect(find.text(l10nOf(tester).drillEmptyTitle), findsNothing);
    });

    testWidgets('every state fits at 1.0 and 2.0, light and dark', (
      tester,
    ) async {
      usePhone(tester);
      final app = AppState.test();
      await app.load();
      for (final scale in <double>[1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final GalleryEntry entry in <GalleryEntry>[
          ...grammarGalleryEntries,
          ...grammarGalleryStates,
        ]) {
          for (final dark in <bool>[false, true]) {
            await pumpScreen(
              tester,
              GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
              state: app,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.id} $scale $dark',
            );
            expect(find.byType(GrammarDrill), findsOneWidget);
          }
        }
      }
    });

    testWidgets('marks the asked cell in the dark theme too', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const GrammarDrill(typed: 'hablamos', check: true),
        state: grammarOn(),
        themeMode: ThemeMode.dark,
      );
      final scheme = Theme.of(tester.element(find.text('habláis'))).colorScheme;
      expect(scheme.brightness, Brightness.dark);
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('habláis'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, scheme.primaryContainer);
    });
  });

  testWidgets('live: a session card is graded, recorded, and shows its table '
      'and notes', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck(grammarFixtureDeckId, skill: Skill.grammar),
      ),
      state: AppState.test(),
    );
    final l10n = l10nOf(tester);
    final pattern = state.deckById(grammarFixtureDeckId)!.deck.pattern!;
    expect(find.byType(GrammarDrill), findsOneWidget);
    // The first new cell in deck order: hablar, yo.
    expect(find.text('hablar (to speak) — yo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hablo');
    await tester.pump();
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();

    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(find.text('hablas'), findsOneWidget, reason: 'the whole table');
    expect(find.text(pattern.notes!), findsOneWidget);
    final review = state.progress.log.single;
    expect(review.mode, DrillMode.grammar);
    expect(review.cardId, 'es-en-grammar-present-ar-hablar-0');
    expect(review.answerGiven, 'hablo');
    expect(review.grade, greaterThanOrEqualTo(4));
  });
}
