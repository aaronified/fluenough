import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Settings, Sources (#98): the sources the decks name, from their `source`
/// fields, a row per language, on a page of their own that one row in
/// Settings opens.

/// A vocab deck in [code] that names [source], or none.
String vocab(String id, String code, String name, {String? source}) =>
    '''
schema: 1
id: $id
name: "$id"
language: { code: $code, iso639_3: xxx, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
${source == null ? '' : 'source: "$source"\n'}cards:
  - { id: $id-1, target: "a", native: "b" }
''';

void main() {
  test('each language\'s sources, each once: a deck\'s own, then its '
      'passages\'', () {
    final catalog = DeckCatalog.parseAll(<String, String>{
      'fixtures/bn/bn-en-fixture-reading.yaml': readingFixtureYaml,
      'decks/bn/bn-en-words.yaml': vocab(
        'bn-en-words',
        'bn',
        'Bengali',
        source: readingFixtureSource,
      ),
      'decks/es/es-en-words.yaml': vocab(
        'es-en-words',
        'es',
        'Spanish',
        source: 'A word list',
      ),
      'decks/es/es-en-more.yaml': vocab('es-en-more', 'es', 'Spanish'),
    });
    final sources = sourcesOf(catalog.decks);
    expect(
      <String>[
        for (final (:language, :lines) in sources)
          for (final line in lines)
            '${language.name}: ${line.source} (${line.kind.name})',
      ],
      <String>[
        // The word deck comes first, by path, and names the first passage's
        // source too, which is not named twice.
        'Bengali: $readingFixtureSource (vocab)',
        'Bengali: $readingFixtureDeckSource (reading)',
        'Spanish: A word list (vocab)',
      ],
    );
    expect(sources.map((s) => s.language.code), ['bn', 'es']);
  });

  testWidgets('Settings has one Sources row, not the list', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(decks: readingFixtureDecks()),
    );
    final l10n = l10nOf(tester);
    final title = find.text(l10n.settingsSources);
    await scrollTo(tester, title);
    expect(title, findsOneWidget);
    final row = find.widgetWithText(GroupedTile, l10n.settingsSources);
    expect(row, findsOneWidget);
    // A book and its language: one source, so the row says so.
    expect(
      find.descendant(
        of: row,
        matching: find.text(l10n.settingsSourcesSummary(1)),
      ),
      findsOneWidget,
    );
    expect(l10n.settingsSourcesSummary(1), '1 source');
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.menu_book_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    // None of what the page lists is in Settings.
    expect(
      find.text(l10n.settingsSourceLine(readingFixtureDeckSource, 'reading')),
      findsNothing,
    );
    expect(find.textContaining(readingFixtureDeckSource), findsNothing);
    expect(find.byType(SourcesPage), findsNothing);
  });

  testWidgets('the row counts the sources, in every language', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/bn/bn-en-words.yaml': vocab(
            'bn-en-words',
            'bn',
            'Bengali',
            source: 'A book',
          ),
          'decks/es/es-en-words.yaml': vocab(
            'es-en-words',
            'es',
            'Spanish',
            source: 'A word list',
          ),
        }),
      ),
    );
    final l10n = l10nOf(tester);
    final summary = find.text(l10n.settingsSourcesSummary(2));
    await scrollTo(tester, summary);
    expect(summary, findsOneWidget);
    expect(l10n.settingsSourcesSummary(2), '2 sources');
  });

  testWidgets('tapping the row opens the page, which lists them, worded by '
      'what each gives', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(decks: readingFixtureDecks()),
    );
    final l10n = l10nOf(tester);
    final title = find.text(l10n.settingsSources);
    await scrollTo(tester, title);
    await tester.tap(title);
    await tester.pumpAndSettle();

    expect(find.byType(SourcesPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10n.settingsSources),
      ),
      findsOneWidget,
    );
    // The deck's own source names the book; a passage's page shows with
    // the passage, not here.
    final row = find.widgetWithText(
      GroupedTile,
      l10n.settingsSourceLine(readingFixtureDeckSource, 'reading'),
    );
    expect(row, findsOneWidget);
    expect(
      find.textContaining(readingFixtureSource),
      findsNothing,
      reason: 'a passage source is not a line of its own',
    );
    expect(
      find.descendant(of: row, matching: find.text('Bengali')),
      findsOneWidget,
    );
    expect(
      l10n.settingsSourceLine('Sahaj Path', 'reading'),
      'Sahaj Path: passages for reading',
    );

    // Back is Settings again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SourcesPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('the page has a row per language, each source a line', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SourcesPage(),
      state: AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/bn/bn-en-words.yaml': vocab(
            'bn-en-words',
            'bn',
            'Bengali',
            source: 'A book',
          ),
          'decks/es/es-en-words.yaml': vocab(
            'es-en-words',
            'es',
            'Spanish',
            source: 'A word list',
          ),
          'decks/es/es-en-more.yaml': vocab(
            'es-en-more',
            'es',
            'Spanish',
            source: 'A phrase book',
          ),
          'decks/fr/fr-en-words.yaml': vocab('fr-en-words', 'fr', 'French'),
        }),
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(GroupedTile), findsNWidgets(2));
    final spanish = find.widgetWithText(GroupedTile, 'Spanish');
    expect(
      find.descendant(
        of: spanish,
        matching: find.text(
          <String>[
            l10n.settingsSourceLine('A phrase book', 'vocab'),
            l10n.settingsSourceLine('A word list', 'vocab'),
          ].join('\n'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(GroupedTile, 'Bengali'), findsOneWidget);
    expect(find.text('French'), findsNothing, reason: 'it names no source');
  });

  testWidgets('and has no row when no deck names a source', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/es/es-en-more.yaml': vocab('es-en-more', 'es', 'Spanish'),
        }),
      ),
    );
    final l10n = l10nOf(tester);
    await scrollThrough(tester);
    expect(find.text(l10n.settingsSources), findsNothing);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });
}
