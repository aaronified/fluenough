// Fact languages in the Languages screen's three-dot menu (#926): it says the
// choice, its choices open in the menu, and the menu and Today's fact button
// write one setting.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/languages/languages_page.dart';
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

Future<void> _pumpMenu(
  WidgetTester tester,
  AppState state, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await pumpScreen(
    tester,
    const LanguagesPage(spokenList: _names),
    state: state,
    themeMode: themeMode,
  );
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

Future<void> _openChoices(WidgetTester tester) async {
  final row = find.byKey(const ValueKey<String>('languages-menu-fact'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the row says all known languages while nothing is chosen', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.4);
    await _pumpMenu(
      tester,
      _state(SettingsNotifier(spokenLanguages: <String>['bn', 'en'])),
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
    await _pumpMenu(
      tester,
      _state(
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

  testWidgets('the choices open in the menu, no sheet; a change shows in the '
      'row and on Today, and a change on Today shows in the row', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.4);
    final settings = SettingsNotifier(spokenLanguages: <String>['bn', 'en']);
    final state = _state(settings);
    await _pumpMenu(tester, state);
    final l10n = _l10n(tester);

    await _openChoices(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text(l10n.factLanguagesTitle), findsNothing);
    expect(_box('bn'), findsOneWidget);
    expect(tester.widget<CheckboxMenuButton>(_box('bn')).value, isTrue);
    await tester.tap(_box('bn'));
    await tester.pumpAndSettle();
    expect(settings.factLanguages, <String>{'en'});
    expect(tester.widget<CheckboxMenuButton>(_box('bn')).value, isFalse);

    // Today shows what the menu chose.
    await pumpScreen(tester, const TodayPage(), state: state);
    expect(find.text(_bengali), findsNothing);
    expect(find.text(_english), findsOneWidget);

    // And what Today's button chooses shows in the menu.
    final button = find.byKey(const ValueKey<String>('fact-languages-button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('fact-language-bn')));
    await tester.pumpAndSettle();
    expect(settings.factLanguages, isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await _pumpMenu(tester, state);
    expect(find.text(_l10n(tester).settingsFactLanguagesAll), findsOneWidget);
  });

  testWidgets('with one language known the row is there and lists it, '
      'checked, greyed out and explained', (tester) async {
    usePhone(tester, textScale: 1.4);
    final state = _state(SettingsNotifier(spokenLanguages: <String>['en']));
    await _pumpMenu(tester, state);
    final l10n = _l10n(tester);
    expect(find.text(l10n.settingsFactLanguagesAll), findsOneWidget);
    await _openChoices(tester);
    final box = tester.widget<CheckboxMenuButton>(_box('en'));
    expect(box.value, isTrue);
    expect(box.onChanged, isNull);
    expect(find.text(l10n.factLanguagesLast), findsOneWidget);
    expect(state.factLanguagesChecked, <String>{'en'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu fits at 1.4x text, in light and dark', (tester) async {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      usePhone(tester, textScale: 1.4);
      await _pumpMenu(
        tester,
        _state(SettingsNotifier(spokenLanguages: <String>['bn', 'en'])),
        themeMode: mode,
      );
      expect(find.text(_l10n(tester).settingsFactLanguages), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
