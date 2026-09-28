import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/import_fixture.dart';
import 'package:fluenough/features/decks/import_page.dart';

import '../../support/harness.dart';
import 'decks_page_test.dart' show withBrokenDeck;

/// Every screen and state this feature draws, on the state it needs.
final Map<String, (Widget Function(), AppState Function())> screens =
    <String, (Widget Function(), AppState Function())>{
      'decks': (() => const DecksPage(), AppState.test),
      'decks, broken file': (
        () => const DecksPage(),
        () => AppState.test(decks: withBrokenDeck()),
      ),
      'deck, with a voice': (
        () => const DeckDetailPage(deckId: 'es-en-core-100'),
        () => AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
      ),
      'deck, no voice': (
        () => const DeckDetailPage(deckId: 'ja-en-hiragana'),
        AppState.test,
      ),
      'deck, grammar': (
        () => const DeckDetailPage(deckId: 'es-en-grammar-present-ar'),
        AppState.test,
      ),
      'deck, tags chosen': (
        () => const DeckDetailPage(
          deckId: 'es-en-core-100',
          initialTags: <String>{'food', 'home'},
        ),
        AppState.test,
      ),
      'import': (() => const ImportPage(), AppState.test),
      'import, spreadsheet': (
        () => const ImportPage(initialSource: ImportSource.csv),
        AppState.test,
      ),
      'import-error': (
        () => ImportPage(error: importErrorFixture()),
        AppState.test,
      ),
    };

/// Scrolls the page's main list from top to bottom a step at a time, so that
/// every row is laid out and any overflow is reported.
Future<void> scrollThrough(WidgetTester tester, String reason) async {
  final list = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  if (list.evaluate().isEmpty) return;
  for (var i = 0; i < 30; i++) {
    await tester.drag(list.first, const Offset(0, -250));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '$reason, step $i');
  }
}

void main() {
  for (final MapEntry(key: name, value: (page, state)) in screens.entries) {
    testWidgets('$name: no overflow at a 2.0 text scale', (tester) async {
      usePhone(tester, textScale: 2.0);
      await pumpScreen(tester, page(), state: state());
      expect(tester.takeException(), isNull, reason: name);
      await scrollThrough(tester, name);
    });

    testWidgets('$name: builds in the dark theme', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        page(),
        state: state(),
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull, reason: name);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      await scrollThrough(tester, name);
    });
  }
}
