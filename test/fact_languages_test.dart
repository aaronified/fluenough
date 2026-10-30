// The languages Today's fact is shown in (#926): the menu lists the known
// languages, one stays checked, the card shows the checked ones, the choice
// is kept per profile, and English stands in when nothing else is left.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/fact.dart';
import 'package:fluenough/core/scheduling/daily_fact.dart';
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

Fact _fact(Map<String, String> text) => Fact(id: 'f', text: text);

Finder _box(String code) => find.byKey(ValueKey<String>('fact-language-$code'));

Future<AppState> _pump(
  WidgetTester tester,
  SettingsNotifier settings, {
  double textScale = 1.4,
  ThemeMode mode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/hi/hi-en-core.yaml': _deck,
      'decks/hi/hi-facts.yaml': _facts,
    }),
    settings: settings,
  );
  addTearDown(settings.dispose);
  await pumpScreen(tester, const TodayPage(), state: state, themeMode: mode);
  return state;
}

Future<void> _openMenu(WidgetTester tester) async {
  final button = find.byKey(const ValueKey<String>('fact-languages-button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('the choice', () {
    const known = <String>['bn', 'hi', 'en'];

    test('nothing chosen checks every known language', () {
      expect(checkedFactLanguages(known, null), known.toSet());
    });

    test('a choice of languages no longer known falls back to all', () {
      expect(checkedFactLanguages(known, <String>{'fr'}), known.toSet());
    });

    test('the last checked language cannot be unchecked', () {
      var chosen = toggledFactLanguages(known, null, 'hi');
      expect(chosen, <String>{'bn', 'en'});
      chosen = toggledFactLanguages(known, chosen, 'bn');
      chosen = toggledFactLanguages(known, chosen, 'en');
      expect(chosen, <String>{'en'});
      expect(toggledFactLanguages(known, chosen, 'en'), <String>{'en'});
    });

    test('checking all again goes back to nothing chosen', () {
      final chosen = toggledFactLanguages(known, <String>{'en'}, 'bn');
      expect(toggledFactLanguages(known, chosen, 'hi'), isNull);
    });

    test('the text is in the checked languages, in the learner order', () {
      final fact = _fact(<String, String>{'en': 'E', 'bn': 'B', 'hi': 'H'});
      expect(
        shownFactTexts(fact, known, <String>{'en', 'bn'}).map((t) => t.code),
        <String>['bn', 'en'],
      );
      expect(shownFactTexts(fact, known, null).map((t) => t.code), known);
    });

    test('a language with no translation is left out', () {
      final fact = _fact(<String, String>{'en': 'E', 'bn': 'B'});
      expect(
        shownFactTexts(fact, known, <String>{'hi', 'bn'}).map((t) => t.code),
        <String>['bn'],
      );
    });

    test('nothing left falls back to English', () {
      final fact = _fact(<String, String>{'en': 'E', 'bn': 'B'});
      expect(
        shownFactTexts(fact, known, <String>{'hi'}).map((t) => t.code),
        <String>['en'],
      );
    });
  });

  testWidgets('the card shows every known language until a choice is made, '
      'and the menu lists exactly those known', (tester) async {
    await _pump(
      tester,
      SettingsNotifier(spokenLanguages: <String>['bn', 'en']),
    );
    expect(find.text(_bengali), findsOneWidget);
    expect(find.text(_english), findsOneWidget);
    await _openMenu(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(_box('bn'), findsOneWidget);
    expect(_box('en'), findsOneWidget);
    expect(_box('hi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchecking a language hides it, the last one stays checked '
      'and says why', (tester) async {
    final settings = SettingsNotifier(spokenLanguages: <String>['bn', 'en']);
    final state = await _pump(tester, settings);
    final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
    await _openMenu(tester);
    await tester.tap(_box('bn'));
    await tester.pumpAndSettle();
    expect(settings.factLanguages, <String>{'en'});
    // The only one checked is disabled, with its reason.
    expect(find.text(l10n.factLanguagesLast), findsOneWidget);
    await tester.tap(_box('en'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(state.factLanguagesChecked, <String>{'en'});
    // Close the menu: the card shows English only.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text(_bengali), findsNothing);
    expect(find.text(_english), findsOneWidget);
  });

  testWidgets('a checked language the fact lacks falls back to English', (
    tester,
  ) async {
    await _pump(
      tester,
      SettingsNotifier(
        spokenLanguages: <String>['bn', 'hi', 'en'],
        factLanguages: <String>{'hi'},
      ),
    );
    expect(find.text(_bengali), findsNothing);
    expect(find.text(_english), findsOneWidget);
  });

  testWidgets('the button has a label and is 48 dp, in light and dark', (
    tester,
  ) async {
    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      await _pump(
        tester,
        SettingsNotifier(spokenLanguages: <String>['bn', 'en']),
        mode: mode,
      );
      final button = find.byKey(
        const ValueKey<String>('fact-languages-button'),
      );
      await tester.ensureVisible(button);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
      expect(find.bySemanticsLabel(l10n.factLanguagesLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('the choice is kept per profile, in what is stored', () {
    final a = SettingsNotifier(
      spokenLanguages: <String>['bn', 'en'],
      factLanguages: <String>{'en'},
    );
    final b = SettingsNotifier(spokenLanguages: <String>['bn', 'en']);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    expect(a.toStored()['fact_languages'], 'en');
    expect(b.toStored()['fact_languages'], 'default');
    final restored = SettingsNotifier()..restore(a.toStored());
    addTearDown(restored.dispose);
    expect(restored.factLanguages, <String>{'en'});
    final other = SettingsNotifier()..restore(b.toStored());
    addTearDown(other.dispose);
    expect(other.factLanguages, isNull);
  });
}
