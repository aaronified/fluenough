import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/theme.dart';

import 'support/harness.dart';

/// Whether [page] is the tab on screen, rather than kept alive offstage.
bool showing(WidgetTester tester, Type page) =>
    find.byType(page).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets('starts on Today, with the real bundled decks', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);

    expect(state.status, CatalogStatus.ready);
    expect(state.deckById('es-core-100'), isNotNull);
    expect(state.deckById('ja-hiragana'), isNotNull);
    expect(state.brokenDecks, isEmpty);
    expect(state.currentProfile.id, Profile.defaultProfile.id);

    expect(showing(tester, TodayPage), isTrue);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, ShellTab.today.index);
  });

  testWidgets('the navigation bar switches tabs, and back returns to Today', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    final l10n = l10nOf(tester);

    for (final (label, page, tab) in <(String, Type, ShellTab)>[
      (l10n.navDecks, DecksPage, ShellTab.decks),
      (l10n.navProgress, StatsPage, ShellTab.progress),
      (l10n.navSettings, SettingsPage, ShellTab.settings),
      (l10n.navToday, TodayPage, ShellTab.today),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(showing(tester, page), isTrue, reason: label);
      expect(state.shellTab.value, tab);
    }

    await tester.tap(find.text(l10n.navDecks));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(showing(tester, TodayPage), isTrue);
  });

  testWidgets('a page pushed over the shell can switch its tab', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    state.shellTab.value = ShellTab.progress;
    await tester.pumpAndSettle();
    expect(showing(tester, StatsPage), isTrue);
  });

  testWidgets('follows a dark theme mode, with the dark mode colours', (
    tester,
  ) async {
    final state = await pumpApp(
      tester,
      state: AppState.test(
        settings: SettingsNotifier(
          themeMode: ThemeMode.dark,
          spokenLanguages: const <String>['en'],
        ),
      ),
    );
    final context = tester.element(find.byType(TodayPage));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(
      theme.colorScheme.primary,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F6C51),
        brightness: Brightness.dark,
      ).primary,
    );
    expect(ModeColors.of(context).recognition, ModeColors.dark.recognition);

    state.settings.themeMode = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(TodayPage))).brightness,
      Brightness.light,
    );
  });

  testWidgets('the shell does not overflow at twice the text size', (
    tester,
  ) async {
    usePhone(tester, textScale: 2.0);
    final state = await pumpApp(tester);
    final l10n = l10nOf(tester);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(AppShell))).scale(10),
      20,
    );
    for (final tab in ShellTab.values) {
      state.shellTab.value = tab;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab.name);
    }
    expect(find.text(l10n.navProgress), findsOneWidget);
  });
}
