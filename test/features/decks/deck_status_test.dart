import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
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

  test('every deck starts Pending or Not done, and spending the day\'s new '
      'cards leaves it so', () async {
    final state = AppState.test();
    addTearDown(state.dispose);
    await state.load();
    final decks = state.decks.where(state.canDrill).toList();
    expect(decks, isNotEmpty);
    // Pending: in the first two units of its course's path (ADR-0013).
    DeckBadgeKind expected(DeckEntry entry) =>
        state.pathOf(entry)!.units.take(2).expand((u) => u).contains(entry.id)
        ? DeckBadgeKind.pending
        : DeckBadgeKind.notDone;
    expect(badgeOf(state, 'hi-en-first-words'), DeckBadgeKind.pending);
    expect(badgeOf(state, 'hi-en-market'), DeckBadgeKind.notDone);
    for (final entry in decks) {
      expect(badgeOf(state, entry.id), expected(entry), reason: entry.id);
    }

    // The first session takes the whole day's allowance of new cards.
    for (final item in state.buildSession(const DrillRequest.today()).items) {
      state.record(item, 5);
    }
    expect(state.newCardsLeftToday, 0);
    for (final entry in decks) {
      expect(badgeOf(state, entry.id), expected(entry), reason: entry.id);
    }
  });

  test('a deck is Done once every card is learned in every skill on, and '
      'says how many are due again when they are', () async {
    final state = tinyState();
    addTearDown(state.dispose);
    await state.load();
    final entry = state.deckById(tiny)!;
    expect(state.notStudiedIn(entry), 2);

    // Learned by sight only: production is still to learn. Its course's only
    // deck, so it is the unit Today teaches.
    for (final item in state.buildSession(DrillRequest.deck(tiny)).items) {
      state.record(item, 5);
    }
    expect(badgeOf(state, tiny), DeckBadgeKind.pending);

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

  test('a deck with reviews due and cards still to learn counts only the '
      'due ones', () async {
    final state = tinyState();
    addTearDown(state.dispose);
    await state.load();
    final hola = state.deckById(tiny)!.cards.first;
    for (final mode in <DrillMode>[
      DrillMode.recognition,
      DrillMode.production,
    ]) {
      state.record(SessionItem(card: hola, mode: mode, state: null), 5);
    }
    final later = tinyState(
      progress: state.progress,
      now: state.now().add(const Duration(days: 2)),
    );
    addTearDown(later.dispose);
    await later.load();
    final entry = later.deckById(tiny)!;
    expect(later.countsFor(entry).fresh, 1, reason: 'adiós is still new');
    final badge = DeckBadge.forEntry(later, entry);
    expect(badge.kind, DeckBadgeKind.due);
    expect(badge.count, 1);
  });

  test('a deck with nothing learned is Not done even when the skills on '
      'leave nothing in it to drill', () async {
    final settings = SettingsNotifier(spokenLanguages: const <String>['en'])
      ..setSkillEnabled(Skill.recognition, false)
      ..setSkillEnabled(Skill.production, false);
    addTearDown(settings.dispose);
    final state = tinyState(settings: settings);
    addTearDown(state.dispose);
    await state.load();
    expect(state.notStudiedIn(state.deckById(tiny)!), 0);
    expect(badgeOf(state, tiny), DeckBadgeKind.notDone);
  });

  testWidgets('a short badge is as wide as its text, not the row\'s cap', (
    tester,
  ) async {
    usePhone(tester);
    final state = tinyState();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: ListView(
            children: <Widget>[
              DeckTile(
                entry: state.deckById(tiny)!,
                badge: const DeckBadge(kind: DeckBadgeKind.done),
              ),
              DeckTile(
                entry: state.deckById(tiny)!,
                badge: const DeckBadge(kind: DeckBadgeKind.due, count: 3),
              ),
            ],
          ),
        ),
      ),
      state: state,
    );
    final badges = find.byType(DeckBadge);
    expect(badges, findsNWidgets(2));
    for (final badge in badges.evaluate()) {
      expect(tester.getSize(find.byWidget(badge.widget)).width, lessThan(100));
    }
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

    // Learning past the cap is recorded like any new card.
    await tester.tap(find.text(l10n.drillShowAnswer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.rateGood));
    await tester.pumpAndSettle();
    expect(state.progress.log, hasLength(1));
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

    // Ending part-way says so, rather than that answers were recorded.
    await tester.tap(find.byTooltip(l10n.drillEndSession));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillEndBodyNotRecorded), findsOneWidget);
    expect(find.text(l10n.drillEndBody), findsNothing);
  });

  testWidgets('a typed revision is titled with the deck too', (tester) async {
    usePhone(tester);
    final settings = SettingsNotifier(spokenLanguages: const <String>['en'])
      ..setSkillEnabled(Skill.recognition, false);
    addTearDown(settings.dispose);
    final state = tinyState(settings: settings);
    await state.load();
    learnAll(state, tiny);
    await pumpScreen(tester, const DeckDetailPage(deckId: tiny), state: state);
    final l10n = l10nOf(tester);

    await tester.tap(find.text(l10n.deckRevise(2)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillShowAnswer), findsNothing, reason: 'typed');
    expect(find.text('Tiny'), findsOneWidget);
  });
}
