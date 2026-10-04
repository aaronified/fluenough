import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
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

  testWidgets('a chip shows the icon, or else its first deck\'s glyph', (
    tester,
  ) async {
    const hindi = LanguageInfo(
      code: 'hi',
      iso639_3: 'hin',
      name: 'Hindi',
      script: 'devanagari',
      icon: 'हि',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LanguageChips(
            languages: const <LanguageInfo>[hindi],
            decks: const [],
            semanticLabel: 'Filter by language',
            selected: null,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('हि'), findsOneWidget);
  });
}
