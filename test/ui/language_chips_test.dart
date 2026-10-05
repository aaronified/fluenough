import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/widgets/language_chips.dart';

/// Each language's chip shows the first letter of its own name (ADR-0027),
/// not the first letter of its first card, which was न, ন or న for most.
void main() {
  testWidgets('every bundled language has its own icon, and no two share '
      'one', (tester) async {
    final state = AppState.test(
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    );
    await state.load();
    final languages = state.languages;
    final icons = <String, String?>{
      for (final language in languages) language.code: language.icon,
    };
    expect(icons, containsPair('hi', 'हि'));
    expect(icons, containsPair('mr', 'म'));
    expect(icons, containsPair('bn', 'বা'));
    expect(icons, containsPair('as', 'অ'));
    expect(icons, containsPair('te', 'తె'));
    expect(icons, containsPair('kn', 'ಕ'));
    expect(icons, containsPair('gu', 'ગુ'));
    expect(icons, containsPair('es', 'Es'));
    expect(icons.values.toSet(), hasLength(icons.length));
  });

  Future<void> pumpChips(
    WidgetTester tester,
    LanguageInfo language,
    List<DeckEntry> decks,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LanguageChips(
          languages: <LanguageInfo>[language],
          decks: decks,
          semanticLabel: 'Filter by language',
          selected: null,
          onSelected: (_) {},
        ),
      ),
    ),
  );

  testWidgets('a chip shows the icon, or else its first deck\'s glyph', (
    tester,
  ) async {
    final deck = DeckParser.parse('''
schema: 1
id: hi-en-probe
name: Probe
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: hi-0001
    target: नमस्ते
    native: hello
    reading: namaste
''', source: 'hi-en-probe.yaml');
    final decks = <DeckEntry>[DeckEntry(path: 'hi-en-probe.yaml', deck: deck)];
    const named = LanguageInfo(
      code: 'hi',
      iso639_3: 'hin',
      name: 'Hindi',
      script: 'devanagari',
      icon: 'हि',
    );
    await pumpChips(tester, named, decks);
    expect(find.text('हि'), findsOneWidget);
    expect(find.text('न'), findsNothing);

    // A language that names no icon: the first letter of its first card.
    await pumpChips(tester, deck.language, decks);
    expect(find.text('न'), findsOneWidget);
    expect(find.text('हि'), findsNothing);
  });
}
