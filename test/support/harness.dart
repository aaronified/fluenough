import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
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

/// How far [text]'s first line of glyphs starts from the start edge of the
/// [width]-wide screen: from the left in left-to-right text, from the right
/// in right-to-left. Measures the glyphs, not the text's box, which a
/// stretched column makes as wide as the column whatever the alignment.
/// Spaces are left out: a line's trailing space hangs past its edge.
double textStart(WidgetTester tester, Finder text, {double width = 390}) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final plain = paragraph.text.toPlainText();
  // The first line's band, from the runs; then its words, which leave the
  // spaces out and keep a script's clusters whole.
  final runs = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: plain.length),
  );
  final band = runs.reduce((a, b) => a.top <= b.top ? a : b);
  final line = <TextBox>[
    for (final word in RegExp(r'\S+').allMatches(plain))
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      ))
        if ((box.top + box.bottom) / 2 < band.bottom) box,
  ];
  final origin = paragraph.localToGlobal(Offset.zero).dx;
  final edge = paragraph.textDirection == TextDirection.rtl
      ? width -
            origin -
            line.map((b) => b.right).reduce((a, b) => a > b ? a : b)
      : origin + line.map((b) => b.left).reduce((a, b) => a < b ? a : b);
  // Glyph boxes land on fractions of a pixel.
  return edge.roundToDouble();
}

/// The interface strings, for asserting on tokens rather than English.
AppLocalizations l10nOf(WidgetTester tester, [Finder? under]) =>
    AppLocalizations.of(tester.element(under ?? find.byType(Scaffold).first))!;

/// The bundled decks, except that the first listing fails: a catalog that
/// fails to load, then loads on "Try again" (`AppState.reload`).
class FailOnceDeckSource implements DeckSource {
  final DeckSource _decks = AssetDeckSource();
  bool _failed = false;

  @override
  Future<List<String>> list() async {
    if (!_failed) {
      _failed = true;
      throw StateError('no manifest');
    }
    return _decks.list();
  }

  @override
  Future<String> read(String path) => _decks.read(path);
}
