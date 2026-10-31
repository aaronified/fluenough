// The Fact languages row in Settings (#926): it says the choice, opens the
// same sheet as Today's fact button, and both write one setting.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/settings/fact_languages_tile.dart';
import 'package:fluenough/features/settings/languages_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _deck = '''
schema: 1
id: hi-en-core
name: Hindi core
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-core-0001, target: "घर", native: "house", reading: "ghar" }
''';

const _facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: CC0-1.0
facts:
  - id: hi-fact-001
    text:
      en: "No Hindi word begins with ड़."
      bn: "কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।"
''';

const _english = 'No Hindi word begins with ड़.';
const _bengali = 'কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।';

const _names = <SpokenLanguage>[
  SpokenLanguage(
    code: 'bn',
    iso639_3: 'ben',
    name: 'Bengali',
    ownName: 'বাংলা',
  ),
  SpokenLanguage(
    code: 'en',
    iso639_3: 'eng',
    name: 'English',
    ownName: 'English',
  ),
  SpokenLanguage(code: 'hi', iso639_3: 'hin', name: 'Hindi', ownName: 'हिन्दी'),
];

const _tile = FactLanguagesTile(spokenList: _names);

Finder _box(String code) => find.byKey(ValueKey<String>('fact-language-$code'));

AppState _state(SettingsNotifier settings) {
  addTearDown(settings.dispose);
  return AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/hi/hi-en-core.yaml': _deck,
      'decks/hi/hi-facts.yaml': _facts,
    }),
    settings: settings,
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

void main() {
  testWidgets('the row says all known languages while nothing is chosen', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      const Scaffold(body: _tile),
      state: _state(SettingsNotifier(spokenLanguages: <String>['bn', 'en'])),
    );
    final l10n = _l10n(tester);
    expect(find.text(l10n.settingsFactLanguages), findsOneWidget);
    expect(find.text(l10n.settingsFactLanguagesAll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the row names the chosen languages, in the learner order', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      const Scaffold(body: _tile),
      state: _state(
        SettingsNotifier(
          spokenLanguages: <String>['bn', 'hi', 'en'],
          factLanguages: <String>{'en', 'bn'},
        ),
      ),
    );
    expect(find.text('Bengali, English'), findsOneWidget);
    expect(find.text(_l10n(tester).settingsFactLanguagesAll), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the row opens the sheet; a change shows in the row '
      'and on Today, and a change on Today shows in the row', (tester) async {
    usePhone(tester, textScale: 1.4);
    final settings = SettingsNotifier(spokenLanguages: <String>['bn', 'en']);
    final state = _state(settings);
    await pumpScreen(tester, const Scaffold(body: _tile), state: state);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.settingsFactLanguages));
    await tester.pumpAndSettle();
    expect(find.text(l10n.factLanguagesTitle), findsOneWidget);
    expect(_box('bn'), findsOneWidget);
    await tester.tap(_box('bn'));
    await tester.pumpAndSettle();
    expect(settings.factLanguages, <String>{'en'});
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);

    // Today shows what Settings chose.
    await pumpScreen(tester, const TodayPage(), state: state);
    expect(find.text(_bengali), findsNothing);
    expect(find.text(_english), findsOneWidget);

    // And what Today's button chooses shows in Settings.
    final button = find.byKey(const ValueKey<String>('fact-languages-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(_box('bn'));
    await tester.pumpAndSettle();
    expect(settings.factLanguages, isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await pumpScreen(tester, const Scaffold(body: _tile), state: state);
    expect(find.text(_l10n(tester).settingsFactLanguagesAll), findsOneWidget);
  });

  testWidgets('with one language known the row is there and the sheet lists '
      'it, checked and explained', (tester) async {
    usePhone(tester, textScale: 1.4);
    final state = _state(SettingsNotifier(spokenLanguages: <String>['en']));
    await pumpScreen(tester, const Scaffold(body: _tile), state: state);
    final l10n = _l10n(tester);
    expect(find.text(l10n.settingsFactLanguagesAll), findsOneWidget);
    await tester.tap(find.text(l10n.settingsFactLanguages));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(find.text(l10n.factLanguagesLast), findsOneWidget);
    await tester.tap(_box('en'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(state.factLanguagesChecked, <String>{'en'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('the row is on the Your languages page, at 1.4x text, in '
      'light and dark', (tester) async {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        const LanguagesSettingsPage(),
        state: _state(SettingsNotifier(spokenLanguages: <String>['bn', 'en'])),
        themeMode: mode,
      );
      final l10n = _l10n(tester);
      expect(find.text(l10n.settingsFactLanguages), findsOneWidget);
      expect(find.text(l10n.settingsFactLanguagesAll), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
