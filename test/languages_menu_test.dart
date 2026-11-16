// The Languages screen after the menu rework (docs/mockups/menu-and-report,
// approved 2026-11-16): Settings' Your languages opens the list at once, the
// switches and the open items are in its three-dot menu, Your decks is a row
// below the list, and Learn from is in a language's own sheet.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/features/placement/native_choice.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/hindi_courses.dart';
import 'support/picker.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

AppState _learner([SettingsNotifier? settings]) => AppState.test(
  settings:
      settings ??
      SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
);

Future<AppState> _pump(
  WidgetTester tester, {
  AppState? state,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) {
  usePhone(tester, textScale: textScale);
  return pumpScreen(
    tester,
    LanguagesPage(spokenList: pickerSpokenList),
    state: state ?? _learner(),
    themeMode: mode,
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

// The framework gives the menu button's key to the item inside it too, so
// the outer widget is the first match.
Finder _item(String key) =>
    find.byKey(ValueKey<String>('languages-menu-$key')).first;

CheckboxMenuButton _toggle(WidgetTester tester, String key) =>
    tester.widget<CheckboxMenuButton>(_item(key));

Future<void> _tapItem(WidgetTester tester, String key) async {
  await tester.ensureVisible(_item(key));
  await tester.pumpAndSettle();
  await tester.tap(_item(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings: Your languages opens the Languages list, with no '
      'page of rows between', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final l10n = _l10n(tester);
    await tester.ensureVisible(find.text(l10n.settingsRowLanguages));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsRowLanguages));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LanguagesPage), findsOneWidget);
    expect(find.text(l10n.languagesTitle), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('the bar has the add button and the three dots, and no bug '
      'icon', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
    await tester.longPress(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).languagesMenuMoreHint), findsWidgets);
  });

  testWidgets('the menu lists the switches, then a divider, then Fact '
      'languages and Sources, and no Your decks or Learn from', (tester) async {
    await _pump(tester, state: _learner());
    await _openMenu(tester);
    final l10n = _l10n(tester);
    final order = <String>['romanisation', 'ipa', 'ipa-replaces', 'adult'];
    var last = -1.0;
    for (final key in order) {
      final top = tester.getTopLeft(_item(key)).dy;
      expect(top, greaterThan(last), reason: key);
      last = top;
    }
    final divider = tester.getTopLeft(find.byType(Divider).last).dy;
    expect(divider, greaterThan(last));
    expect(tester.getTopLeft(_item('fact')).dy, greaterThan(divider));
    expect(
      tester.getTopLeft(_item('sources')).dy,
      greaterThan(tester.getTopLeft(_item('fact')).dy),
    );
    // Your decks is the row under the list, outside the menu.
    expect(find.text(l10n.settingsRowDecks), findsOneWidget);
    for (final key in <String>['fact', 'sources', 'adult']) {
      expect(
        find.descendant(
          of: _item(key),
          matching: find.text(l10n.settingsRowDecks),
        ),
        findsNothing,
      );
    }
    expect(find.text(l10n.nativeChoiceTitle('Spanish')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each switch has its box in both states and its line under '
      'the label; flipping it changes the setting and the line', (
    tester,
  ) async {
    final state = await _pump(tester);
    await _openMenu(tester);
    final l10n = _l10n(tester);
    final settings = state.settings;
    Future<void> check(
      String key,
      bool Function() value,
      String off,
      String on,
      void Function() reset,
    ) async {
      reset();
      await tester.pumpAndSettle();
      await tester.ensureVisible(_item(key));
      // The box is there while off, and the line says what happens now.
      final box = find.descendant(
        of: _item(key),
        matching: find.byType(Checkbox),
      );
      expect(box, findsOneWidget, reason: key);
      expect(_toggle(tester, key).value, isFalse, reason: key);
      expect(
        find.descendant(of: _item(key), matching: find.text(off)),
        findsOneWidget,
        reason: key,
      );
      await _tapItem(tester, key);
      expect(value(), isTrue, reason: key);
      expect(_toggle(tester, key).value, isTrue, reason: key);
      expect(
        find.descendant(of: _item(key), matching: find.text(on)),
        findsOneWidget,
        reason: key,
      );
      expect(box, findsOneWidget, reason: key);
      // The menu stays open while a switch flips.
      expect(_item('sources'), findsOneWidget);
      // And it persists as the old rows did.
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.showRomanisation, settings.showRomanisation);
      expect(restored.showIpa, settings.showIpa);
    }

    await check(
      'romanisation',
      () => settings.showRomanisation,
      l10n.settingsRomanisationOff,
      l10n.settingsRomanisationOn,
      () => settings.showRomanisation = false,
    );
    await check(
      'ipa',
      () => settings.showIpa,
      l10n.settingsIpaOff,
      l10n.settingsIpaOn,
      () => settings.showIpa = false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('IPA replaces transliteration is greyed out and explained '
      'while IPA is off, and switchable once it is on', (tester) async {
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['es'],
      learningChosen: true,
    )..showIpa = false;
    final state = await _pump(tester, state: _learner(settings));
    await _openMenu(tester);
    final l10n = _l10n(tester);
    expect(_toggle(tester, 'ipa-replaces').onChanged, isNull);
    expect(_toggle(tester, 'ipa-replaces').value, isFalse);
    expect(find.text(l10n.settingsIpaReplacesNeedsIpa), findsOneWidget);
    expect(
      find.descendant(
        of: _item('ipa-replaces'),
        matching: find.byType(Checkbox),
      ),
      findsOneWidget,
    );

    await _tapItem(tester, 'ipa');
    expect(state.settings.showIpa, isTrue);
    expect(_toggle(tester, 'ipa-replaces').onChanged, isNotNull);
    expect(find.text(l10n.settingsIpaReplacesOff), findsOneWidget);
    await _tapItem(tester, 'ipa-replaces');
    expect(state.settings.ipaReplacesReading, isTrue);
    expect(_toggle(tester, 'ipa-replaces').value, isTrue);
    expect(find.text(l10n.settingsIpaReplacesOn), findsOneWidget);
  });

  testWidgets('Sources has the link icon and opens its screen; Fact '
      'languages has the arrow of a submenu', (tester) async {
    await _pump(tester);
    await _openMenu(tester);
    expect(
      find.descendant(
        of: _item('sources'),
        matching: find.byIcon(Icons.open_in_new),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _item('fact'),
        matching: find.byIcon(Icons.open_in_new),
      ),
      findsNothing,
    );
    expect(find.byType(SubmenuButton), findsOneWidget);
    await _tapItem(tester, 'sources');
    expect(find.byType(SourcesPage), findsOneWidget);
  });

  testWidgets('Your decks is a full-width row below the languages, with a '
      'link icon, and opens the decks page', (tester) async {
    await _pump(tester);
    final l10n = _l10n(tester);
    final row = find.byKey(const ValueKey<String>('languages-your-decks'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsSumDecks(0)), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey<String>('language-es'))).dy,
      ),
    );
    expect(tester.getSize(row).width, greaterThan(300));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(YourDecksPage), findsOneWidget);
  });

  testWidgets('Learn from is in the language sheet, for a course more than '
      'one spoken language teaches, with the link icon', (tester) async {
    usePhone(tester);
    final state = AppState.test(
      decks: MemoryDeckSource(hindi(bengali: const <String>{'a'})),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['bn', 'en'],
        learningLanguages: const <String>['hi'],
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    await pumpScreen(
      tester,
      LanguagesPage(spokenList: pickerSpokenList),
      state: state,
    );
    final l10n = _l10n(tester);
    // Not in the menu.
    await _openMenu(tester);
    expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    final language = find.byKey(const ValueKey<String>('language-hi'));
    await tester.ensureVisible(language);
    await tester.pumpAndSettle();
    await tester.tap(language);
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey<String>('languages-native'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(NativeChoicePage), findsOneWidget);
  });

  testWidgets('a course taught from one language has no Learn from row', (
    tester,
  ) async {
    await _pump(tester);
    final language = find.byKey(const ValueKey<String>('language-es'));
    await tester.tap(language);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('languages-native')),
      findsNothing,
    );
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the menu, its Fact languages choices and the page fit at '
        '1.4x text on 360 dp in ${mode.name}', (tester) async {
      await _pump(tester, textScale: 1.4, mode: mode);
      tester.view
        ..physicalSize = const Size(360 * 3, 740 * 3)
        ..devicePixelRatio = 3;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _openMenu(tester);
      expect(tester.takeException(), isNull);
      await _tapItem(tester, 'fact');
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('fact-language-en')).first,
        findsOneWidget,
      );
    });
  }
}
