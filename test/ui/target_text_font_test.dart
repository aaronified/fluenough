import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../support/harness.dart';

const LanguageInfo telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

const LanguageInfo spanish = LanguageInfo(
  code: 'es',
  iso639_3: 'spa',
  name: 'Spanish',
);

const IndexFont _font = IndexFont(
  path: 'decks/fonts/telugu/NotoSansTelugu.ttf',
  size: 1,
  sha256: 'a',
  script: 'telugu',
);

/// An app whose downloads have [fonts] to load from.
AppState _app(ScriptFonts fonts) => AppState.test(
  deckDownloads: DeckDownloads(
    fetcher: const NullDeckFetcher(),
    files: MemoryDownloadedDecks(),
    clock: () => DateTime(2026, 10, 19),
    scriptFonts: fonts,
  ),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('TargetText draws a script in its font once it is loaded', (
    tester,
  ) async {
    final fonts = ScriptFonts(register: (family, bytes) async {});
    await pumpScreen(
      tester,
      const Scaffold(body: TargetText.hero('తెలుగు', language: telugu)),
      state: _app(fonts),
    );
    // No font yet: the phone's own.
    expect(_styleOf(tester, 'తెలుగు').fontFamily, isNull);
    expect(_styleOf(tester, 'తెలుగు').fontVariations, isNull);

    await fonts.load(_font, Uint8List(1));
    await tester.pump();
    final style = _styleOf(tester, 'తెలుగు');
    expect(style.fontFamily, 'FluenoughScript-telugu');
    expect(style.fontVariations, <FontVariation>[
      const FontVariation.weight(600),
    ]);
    // The weight is the font's axis alone, with no synthetic bold on top.
    expect(style.fontWeight, FontWeight.normal);
  });

  testWidgets('the other sizes of TargetText take the font too', (
    tester,
  ) async {
    final fonts = ScriptFonts(register: (family, bytes) async {});
    await fonts.load(_font, Uint8List(1));
    await pumpScreen(
      tester,
      const Scaffold(
        body: Column(
          children: <Widget>[
            TargetText('తెలుగు', language: telugu, fontSize: 20),
            TargetText.card('తెలుగు', language: telugu, fontSize: 20),
          ],
        ),
      ),
      state: _app(fonts),
    );
    for (final text in tester.widgetList<Text>(find.text('తెలుగు'))) {
      expect(text.style!.fontFamily, 'FluenoughScript-telugu');
    }
  });

  testWidgets('a script with no font loaded stays in the phone\'s font', (
    tester,
  ) async {
    final fonts = ScriptFonts(register: (family, bytes) async {});
    await fonts.load(_font, Uint8List(1));
    await pumpScreen(
      tester,
      const Scaffold(body: TargetText.hero('niño', language: spanish)),
      state: _app(fonts),
    );
    expect(_styleOf(tester, 'niño').fontFamily, isNull);
  });

  testWidgets('without downloads, it is the phone\'s font', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: TargetText.hero('తెలుగు', language: telugu)),
    );
    expect(_styleOf(tester, 'తెలుగు').fontFamily, isNull);
  });
}
