// The content fonts (owner, 2026-11-16: "I don't want to depend on system
// fonts for content"): deck text in Latin, Cyrillic and Greek is drawn in the
// downloaded font of its script, with the other content fonts behind it,
// and the interface's text falls back to them rather than to the phone's.

import 'dart:typed_data';

import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/font_check.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/font_check.dart';
import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

LanguageInfo _language(String code, String script) => LanguageInfo(
  code: code,
  iso639_3: code,
  name: code,
  script: script,
);

IndexFont _font(String script) => IndexFont(
  path: 'decks/fonts/$script/Noto.ttf',
  size: 4,
  sha256: script.padRight(64, '0'),
  script: script,
);

Future<void> _loadAll(ScriptFonts fonts, Iterable<String> scripts) async {
  for (final script in scripts) {
    await fonts.load(_font(script), Uint8List(4));
  }
}

void main() {
  test('the content fonts are Latin, Cyrillic and Greek', () {
    expect(contentFontScripts, <String>['latin', 'cyrillic', 'greek']);
  });

  test('Arabic, Shahmukhi and the IPA share another script\'s font', () {
    expect(fontScriptFor('ar', 'arabic'), 'perso_arabic_naskh');
    expect(fontScriptFor('pa', 'shahmukhi'), 'perso_arabic');
    expect(fontScriptFor('ipa', 'ipa'), 'latin');
    // A script with its own font is unchanged.
    expect(fontScriptFor('th', 'thai'), 'thai');
    expect(fontScriptFor('es', 'latin'), 'latin');
    expect(fontScriptFor('ru', 'cyrillic'), 'cyrillic');
    expect(fontScriptFor('el', 'greek'), 'greek');
    expect(readingScriptOf('latin'), 'latin');
  });

  test('the content fonts always come and are always drawn with', () {
    final settings = SettingsNotifier(spokenLanguages: const <String>['en']);
    final check = FontCheck(settings: settings);
    for (final script in contentFontScripts) {
      expect(check.wants(script), isTrue, reason: script);
      expect(check.uses(script), isTrue, reason: script);
      expect(scriptSamples, isNot(contains(script)));
    }
    // Others still wait for the learner's answer.
    expect(check.wants('thai'), isFalse);
    expect(scriptSamples, contains('thai'));
    check.dispose();
  });

  test('a script falls back to the other loaded content fonts, never the '
      'phone\'s', () async {
    final fonts = ScriptFonts(register: (family, bytes) async {});
    expect(fonts.fallbackFor('FluenoughScript-telugu'), isNull);
    await _loadAll(fonts, <String>['latin', 'greek', 'telugu']);
    expect(fonts.contentFamilies, <String>[
      'FluenoughScript-latin',
      'FluenoughScript-greek',
    ]);
    expect(fonts.fallbackFor('FluenoughScript-telugu'), <String>[
      'FluenoughScript-latin',
      'FluenoughScript-greek',
    ]);
    expect(fonts.fallbackFor('FluenoughScript-greek'), <String>[
      'FluenoughScript-latin',
    ]);
    expect(fonts.fallbackFor(null), isNull);
  });

  testWidgets('content text in each script resolves to its own '
      'FluenoughScript family, with the other content fonts behind it', (
    tester,
  ) async {
    final downloads = DeckDownloads(
      fetcher: FakeDeckRemote(const <String, String>{}),
      files: MemoryDownloadedDecks(),
      scriptFonts: ScriptFonts(register: (family, bytes) async {}),
    );
    await _loadAll(downloads.fonts, contentFontScripts);
    final state = AppState.test(deckDownloads: downloads);
    addTearDown(state.dispose);

    final cases = <(LanguageInfo, String, String)>[
      (_language('es', 'latin'), 'niño', 'latin'),
      (_language('ipa', 'ipa'), 'ʃ', 'latin'),
      (_language('ru', 'cyrillic'), 'привет', 'cyrillic'),
      (_language('el', 'greek'), 'ἀγαθός', 'greek'),
      (_language('grc', 'greek'), 'λόγος', 'greek'),
    ];
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                for (final (language, text, _) in cases)
                  TargetText(text, language: language, fontSize: 24),
              ],
            ),
          ),
        ),
      ),
    );
    for (final (language, text, script) in cases) {
      final style = tester
          .widget<Text>(
            find.descendant(
              of: find.widgetWithText(TargetText, text),
              matching: find.byType(Text),
            ),
          )
          .style!;
      expect(
        style.fontFamily,
        'FluenoughScript-$script',
        reason: language.code,
      );
      expect(
        style.fontFamilyFallback,
        isNot(contains('FluenoughScript-$script')),
      );
      expect(
        style.fontFamilyFallback,
        containsAll(<String>[
          for (final other in contentFontScripts)
            if (other != script) 'FluenoughScript-$other',
        ]),
      );
    }
  });

  testWidgets('a script with no font loaded yet is drawn in the phone\'s '
      'font until it comes', (tester) async {
    final downloads = DeckDownloads(
      fetcher: FakeDeckRemote(const <String, String>{}),
      files: MemoryDownloadedDecks(),
      scriptFonts: ScriptFonts(register: (family, bytes) async {}),
    );
    final state = AppState.test(deckDownloads: downloads);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: TargetText(
              'hola',
              language: _language('es', 'latin'),
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
    Text shown() => tester.widget<Text>(
      find.descendant(
        of: find.byType(TargetText),
        matching: find.byType(Text),
      ),
    );
    expect(shown().style!.fontFamily, isNull);

    await _loadAll(downloads.fonts, <String>['latin']);
    await tester.pump();
    expect(shown().style!.fontFamily, 'FluenoughScript-latin');
  });
}
