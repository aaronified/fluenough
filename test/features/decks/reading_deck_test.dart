import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/placement.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/passage_preview.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/reading_drill.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';

/// A reading deck (#98) outside the drill: an ordinary deck on the Decks tab
/// and its own page, and nothing placement asks about.

AppState readingApp() => AppState.test(
  decks: readingFixtureDecks(),
  tts: FixedTtsEngine(<String>{'bn'}),
);

void main() {
  testWidgets('its page: the kind, its passages with their sources, and a '
      'skill row each for reading and for hearing it', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const DeckDetailPage(deckId: readingFixtureDeckId),
      state: readingApp(),
    );
    final l10n = l10nOf(tester);
    expect(
      find.text(l10n.deckHeaderLine('Bengali', 'ben', l10n.deckKindReading)),
      findsOneWidget,
    );
    expect(find.text(l10n.deckReadingCount(2, 5)), findsOneWidget);
    expect(find.byType(PassagePreview), findsOneWidget);
    expect(find.text(l10n.deckPassages), findsOneWidget);
    for (final title in ['At the shop', 'Going home']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('নমস্কার। কত দাম?'), findsOneWidget);
    expect(find.text(l10n.deckPassageQuestions(3)), findsOneWidget);
    expect(find.text(l10n.deckPassageQuestions(2)), findsOneWidget);
    expect(find.text(l10n.readingSource(readingFixtureSource)), findsOneWidget);
    expect(
      find.text(l10n.readingSource(readingFixtureDeckSource)),
      findsOneWidget,
    );
    // The deck's own source is among its facts too.
    expect(find.textContaining(readingFixtureDeckSource), findsWidgets);

    final reading = find.widgetWithText(GroupedTile, Skill.reading.label(l10n));
    expect(reading, findsOneWidget);
    expect(find.text(l10n.skillReadingDeckDesc), findsOneWidget);
    expect(find.text(l10n.skillListeningReadingDeckDesc), findsOneWidget);
    expect(find.text(l10n.skillListeningDeckDesc), findsNothing);
    expect(state.countsFor(state.deckById(readingFixtureDeckId)!).fresh, 5);

    // Start reads its passages.
    await tester.ensureVisible(find.text(l10n.deckReviewAll(5)));
    await tester.tap(find.text(l10n.deckReviewAll(5)));
    await tester.pumpAndSettle();
    expect(find.byType(DrillPage), findsOneWidget);
    expect(find.byType(ReadingDrill), findsOneWidget);
  });

  testWidgets('the Decks tab lists it, counted in passages', (tester) async {
    usePhone(tester);
    final state = readingApp();
    await pumpApp(tester, state: state);
    state.shellTab.value = ShellTab.decks;
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester, find.byType(AppShell));
    expect(find.text('Bengali reading (fixture)'), findsOneWidget);
    expect(
      find.text(l10n.deckMetaReading('Bengali', 'ben', 2)),
      findsOneWidget,
    );
  });

  test('placement asks nothing from a reading deck', () async {
    final state = readingApp();
    await state.load();
    final units = state.courseUnits('bn');
    expect(units.single.single.id, readingFixtureDeckId);
    final placement = Placement(units);
    // A unit with nothing to ask is known.
    expect(placement.isFinished, isTrue);
    expect(placement.placedDeckIds, {readingFixtureDeckId});
  });
}
