import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/theme.dart';

/// Shared helpers for widget tests. Import from any test directory:
/// `import '../support/harness.dart';` (adjust the depth).

/// The design's phone: 390 × 844 logical pixels at 3×. Resets after the test.
void usePhone(WidgetTester tester, {double textScale = 1.0}) {
  tester.view
    ..physicalSize = const Size(390 * 3, 844 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps the whole app on [state] (default: `AppState.test()`, the real
/// bundled decks, no voices, a fixed clock) and waits for the catalog.
Future<AppState> pumpApp(WidgetTester tester, {AppState? state}) async {
  final s = state ?? AppState.test();
  await tester.pumpWidget(FluenoughApp(state: s));
  await tester.pumpAndSettle();
  return s;
}

/// Pumps [child] as a screen of its own, with the app's theme, strings and
/// routes, on [state] (loaded first). For testing one page or widget.
Future<AppState> pumpScreen(
  WidgetTester tester,
  Widget child, {
  AppState? state,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final s = state ?? AppState.test();
  await s.load();
  await tester.pumpWidget(
    AppScope(
      state: s,
      child: MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

/// The interface strings, for asserting on tokens rather than English.
AppLocalizations l10nOf(WidgetTester tester, [Finder? under]) =>
    AppLocalizations.of(tester.element(under ?? find.byType(Scaffold).first))!;
