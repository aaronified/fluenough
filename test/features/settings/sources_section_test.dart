import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/sources_section.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';

/// Settings, Sources (#98): the sources the decks name, from their `source`
/// fields, a row per language.

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

  testWidgets('Settings lists them, worded by what each gives', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(decks: readingFixtureDecks()),
    );
    final l10n = l10nOf(tester);
    await tester.scrollUntilVisible(
      find.text(l10n.settingsSectionSources),
      200,
    );
    expect(find.text(l10n.settingsSectionSources), findsOneWidget);
    final row = find.widgetWithText(
      GroupedTile,
      '${l10n.settingsSourceLine(readingFixtureDeckSource, 'reading')}\n'
      '${l10n.settingsSourceLine(readingFixtureSource, 'reading')}',
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Bengali')),
      findsOneWidget,
    );
    expect(
      l10n.settingsSourceLine('Sahaj Path', 'reading'),
      'Sahaj Path: passages for reading',
    );
  });

  testWidgets('and has no section when no deck names a source', (tester) async {
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
    expect(find.text(l10nOf(tester).settingsSectionSources), findsNothing);
  });
}
