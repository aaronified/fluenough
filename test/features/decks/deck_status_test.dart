import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';

import '../../support/harness.dart';

const String tiny = 'es-en-tiny';

/// Two cards, drilled by sight and typed: no voice in tests.
AppState tinyState({
  SettingsNotifier? settings,
  ProgressStore? progress,
  DateTime? now,
}) => AppState.test(
  decks: MemoryDeckSource(<String, String>{
    'decks/es/$tiny.yaml':
        '''
schema: 1
id: $tiny
name: "Tiny"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $tiny-0001, target: "hola", native: "hello" }
  - { id: $tiny-0002, target: "adiós", native: "goodbye" }
''',
  }),
  settings: settings,
  progress: progress,
  now: now,
);

/// Learns every pair left in [deckId], past the daily cap.
void learnAll(AppState state, String deckId) {
  while (state.notStudiedIn(state.deckById(deckId)!) > 0) {
    for (final item
        in state.buildSession(DrillRequest.learnAnyway(deckId)).items) {
      state.record(item, 5);
    }
  }
}

DeckBadgeKind badgeOf(AppState state, String deckId) =>
    DeckBadge.forEntry(state, state.deckById(deckId)!).kind;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every deck starts Not done, and spending the day\'s new cards '
      'leaves it Not done', () async {
    final state = AppState.test();
    addTearDown(state.dispose);
    await state.load();
    final decks = state.decks.where(state.canDrill).toList();
    expect(decks, isNotEmpty);
    for (final entry in decks) {
      expect(badgeOf(state, entry.id), DeckBadgeKind.notDone, reason: entry.id);
    }

    // The first session takes the whole day's allowance of new cards.
    for (final item in state.buildSession(const DrillRequest.today()).items) {
      state.record(item, 5);
    }
    expect(state.newCardsLeftToday, 0);
    for (final entry in decks) {
      expect(badgeOf(state, entry.id), DeckBadgeKind.notDone, reason: entry.id);
    }
  });

  test('a deck is Done once every card is learned in every skill on, and '
      'says how many are due again when they are', () async {
    final state = tinyState();
    addTearDown(state.dispose);
    await state.load();
    final entry = state.deckById(tiny)!;
    expect(state.notStudiedIn(entry), 2);

    // Learned by sight only: production is still to learn.
    for (final item in state.buildSession(DrillRequest.deck(tiny)).items) {
      state.record(item, 5);
    }
    expect(badgeOf(state, tiny), DeckBadgeKind.notDone);

    learnAll(state, tiny);
    expect(state.notStudiedIn(entry), 0);
    expect(badgeOf(state, tiny), DeckBadgeKind.done);

    final later = tinyState(
      progress: state.progress,
      now: state.now().add(const Duration(days: 2)),
    );
    addTearDown(later.dispose);
    await later.load();
    final badge = DeckBadge.forEntry(later, later.deckById(tiny)!);
    expect(badge.kind, DeckBadgeKind.due);
    expect(badge.count, 2);
  });

  testWidgets('once the day\'s new cards are spent, a deck offers Learn '
      'anyway, and it starts', (tester) async {
    usePhone(tester);
    final settings = SettingsNotifier(spokenLanguages: const <String>['en'])
      ..newCardsPerDay = 0;
    addTearDown(settings.dispose);
    final state = tinyState(settings: settings);
    await pumpScreen(tester, const DeckDetailPage(deckId: tiny), state: state);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.deckReviewAll(0)), findsNothing);
    expect(find.text(l10n.deckLearnAnywayNote), findsOneWidget);
    await tester.tap(find.text(l10n.deckLearnAnyway(2)));
    await tester.pumpAndSettle();
    expect(find.byType(DrillPage), findsOneWidget);
    expect(find.text('hola'), findsOneWidget);
  });

  testWidgets('a finished deck offers Revise, and revising records nothing', (
    tester,
  ) async {
    usePhone(tester);
    final state = tinyState();
    await state.load();
    learnAll(state, tiny);
    await pumpScreen(tester, const DeckDetailPage(deckId: tiny), state: state);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.deckReviewAll(0)), findsNothing);
    expect(find.text(l10n.deckReviseNote), findsOneWidget);
    await tester.tap(find.text(l10n.deckRevise(2)));
    await tester.pumpAndSettle();
    expect(find.byType(DrillPage), findsOneWidget);
    // Titled with the deck, not as number practice.
    expect(find.text('Tiny'), findsOneWidget);

    final logged = state.progress.log.length;
    final states = Map.of(state.progress.states);
    await tester.tap(find.text(l10n.drillShowAnswer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.rateGood));
    await tester.pumpAndSettle();
    expect(state.progress.log, hasLength(logged));
    expect(state.progress.states, states);
  });
}
