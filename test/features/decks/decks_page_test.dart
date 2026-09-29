import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/decks/broken_deck_tile.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';

import '../../support/harness.dart';

Future<AppState> pumpDecks(WidgetTester tester, {AppState? state}) =>
    pumpScreen(tester, const DecksPage(), state: state);

/// The names of the decks the list shows, in order.
List<String> shownDecks(WidgetTester tester) => tester
    .widgetList<DeckTile>(find.byType(DeckTile))
    .map((t) => t.entry.deck.name)
    .toList();

/// A phone tall enough for the lazy list to build every bundled deck.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
}

/// Taps [chip] after scrolling the chip row to it.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

/// A valid deck and a broken one, in memory.
MemoryDeckSource withBrokenDeck() => MemoryDeckSource(const <String, String>{
  'decks/xx/xx-fixture-ok.yaml': '''
schema: 1
id: xx-fixture-ok
name: Fixture deck
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-fixture-ok-0001
    target: "sí"
    native: "yes"
''',
  'decks/xx/xx-fixture-broken.yaml': '''
schema: 1
id: xx-fixture-broken
name: Broken fixture
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-fixture-broken-0001
    target: "no"
    native: no
''',
});

void main() {
  testWidgets('lists every bundled deck with what a session would drill', (
    tester,
  ) async {
    useTallPhone(tester);
    final state = await pumpDecks(tester);
    final l10n = l10nOf(tester);
    expect(state.decks, isNotEmpty);
    expect(state.deckById('es-grammar-present-ar')!.cards, isEmpty);
    expect(shownDecks(tester), state.decks.map((e) => e.deck.name).toList());
    for (final entry in state.decks) {
      final counts = state.countsFor(entry);
      final n = counts.due + counts.fresh;
      final tile = find.widgetWithText(DeckTile, entry.deck.name);
      // A grammar deck has nothing to drill until the expander (#2): it is
      // incoming, never Done.
      final badge = entry.cards.isEmpty
          ? l10n.incomingBadge
          : n > 0
          ? l10n.commonDueBadge(n)
          : l10n.commonDoneBadge;
      expect(
        find.descendant(of: tile, matching: find.text(badge)),
        findsOneWidget,
        reason: entry.id,
      );
      // A theme deck's line is its place on the path and its progress.
      final theme = state.themeOf(entry);
      final meta = theme == null
          ? DeckTile.metaFor(l10n, entry)
          : l10n.deckMetaTheme(
              state.themes.indexOf(theme) + 1,
              state.progress.learnedIn(entry.id),
              entry.itemCount,
            );
      expect(
        find.descendant(of: tile, matching: find.text(meta)),
        findsOneWidget,
        reason: entry.id,
      );
    }
  });

  testWidgets('search matches deck and language names', (tester) async {
    usePhone(tester);
    final state = await pumpDecks(tester);
    final l10n = l10nOf(tester);

    await search(tester, 'hira');
    expect(shownDecks(tester), <String>[
      state.deckById('ja-hiragana')!.deck.name,
    ]);

    await search(tester, 'SPANISH');
    expect(shownDecks(tester), <String>[
      for (final e in state.decks)
        if (e.language.code == 'es') e.deck.name,
    ]);

    await search(tester, 'no deck is called this');
    expect(find.byType(DeckTile), findsNothing);
    expect(find.text(l10n.decksEmptySearch), findsOneWidget);
  });

  testWidgets('the language chips come from the loaded decks and filter', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDecks(tester);
    final l10n = l10nOf(tester);

    expect(find.byType(FilterChip), findsNWidgets(state.languages.length + 1));
    for (final language in state.languages) {
      expect(
        find.widgetWithText(FilterChip, language.name),
        findsOneWidget,
        reason: language.code,
      );
    }

    await tapChip(tester, 'Japanese');
    expect(shownDecks(tester), <String>[
      state.deckById('ja-hiragana')!.deck.name,
    ]);

    // A search narrows within the chosen language.
    await search(tester, 'core');
    expect(find.text(l10n.decksEmptySearch), findsOneWidget);

    await tapChip(tester, l10n.decksFilterAll);
    expect(shownDecks(tester), <String>[
      state.deckById('es-core-100')!.deck.name,
    ]);
  });

  testWidgets('a deck in a language the profile does not learn says Start', (
    tester,
  ) async {
    useTallPhone(tester);
    final state = await pumpDecks(
      tester,
      state: AppState.test(profiles: const [GalleryFixtures.mira]),
    );
    final l10n = l10nOf(tester);
    for (final entry in state.decks) {
      final badge = tester
          .widget<DeckTile>(find.widgetWithText(DeckTile, entry.deck.name))
          .badge;
      expect(
        badge.kind,
        entry.cards.isEmpty
            ? DeckBadgeKind.incoming
            : entry.language.code == 'ja'
            ? DeckBadgeKind.due
            : DeckBadgeKind.start,
        reason: entry.id,
      );
    }
    expect(find.text(l10n.commonStartBadge), findsWidgets);
  });

  testWidgets('a broken file is a row with its file, line and message', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDecks(
      tester,
      state: AppState.test(decks: withBrokenDeck()),
    );
    final l10n = l10nOf(tester);
    final broken = state.brokenDecks.single;
    final line = broken.error.line;
    expect(line, isNotNull);

    expect(shownDecks(tester), <String>['Fixture deck']);
    expect(find.byType(BrokenDeckTile), findsOneWidget);
    expect(find.text(l10n.decksBrokenTitle(broken.fileName)), findsOneWidget);
    expect(
      find.text(l10n.decksBrokenAt(line!, broken.error.message)),
      findsOneWidget,
    );
    expect(find.text(l10n.decksBrokenBadge), findsOneWidget);

    // A broken file has no language, so a language chip hides it.
    await tester.tap(find.widgetWithText(FilterChip, 'Spanish'));
    await tester.pumpAndSettle();
    expect(find.byType(BrokenDeckTile), findsNothing);
  });

  testWidgets('a deck opens its screen, and Add deck opens import', (
    tester,
  ) async {
    useTallPhone(tester);
    final state = await pumpDecks(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.text(state.deckById('ja-hiragana')!.deck.name));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DeckDetailPage>(find.byType(DeckDetailPage)).deckId,
      'ja-hiragana',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.decksAdd));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPage), findsOneWidget);
  });

  testWidgets('a catalog that failed offers Try again, which reloads it', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(decks: FailOnceDeckSource()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonDecksFailed), findsOneWidget);
    expect(find.byType(DeckTile), findsNothing);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(state.status, CatalogStatus.ready);
    expect(find.text(l10n.commonDecksFailed), findsNothing);
    expect(find.byType(DeckTile), findsWidgets);
  });

  testWidgets('a course\'s theme decks sit under it, with their progress', (
    tester,
  ) async {
    usePhone(tester);
    String deck(String id, {String? theme, int cards = 2}) =>
        '''
schema: 1
id: $id
name: "${theme ?? id}"
${theme == null ? '' : 'theme: $theme'}
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 1; i <= cards; i++) '  - { id: $id-000$i, target: "क$i", native: "k$i", reading: "k$i" }'].join('\n')}
''';
    final state = AppState.test(
      decks: MemoryDeckSource(<String, String>{
        'decks/themes.yaml': '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
''',
        'decks/hi/hi-en-core.yaml': deck('hi-en-core'),
        'decks/hi/hi-en-market.yaml': deck('hi-en-market', theme: 'market'),
        'decks/hi/hi-en-first-words.yaml': deck(
          'hi-en-first-words',
          theme: 'first-words',
          cards: 3,
        ),
      }),
    );
    await state.load();
    state.progress.record(
      deckId: 'hi-en-first-words',
      cardId: 'hi-en-first-words-0001',
      mode: DrillMode.recognition,
      grade: 5,
      now: state.now(),
    );
    await pumpDecks(tester, state: state);
    final l10n = l10nOf(tester);

    expect(shownDecks(tester), <String>['hi-en-core', 'first-words', 'market']);
    expect(
      find.text(l10n.decksCourseHeading('Hindi', 'English')),
      findsOneWidget,
    );
    expect(find.text(l10n.deckMetaTheme(1, 1, 3)), findsOneWidget);
    expect(find.text(l10n.deckMetaTheme(2, 0, 2)), findsOneWidget);
    // The deck outside the path keeps its usual line.
    expect(
      find.text(DeckTile.metaFor(l10n, state.deckById('hi-en-core')!)),
      findsOneWidget,
    );
  });
}
