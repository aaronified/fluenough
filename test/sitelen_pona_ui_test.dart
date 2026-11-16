// Sitelen pona's private-use glyphs need their downloaded font (ADR-0055):
// the script's tile and pill draw them in it, and a Latin letter until it is
// loaded; and a learner who reads only sitelen pona is never asked to type it.

import 'dart:typed_data';

import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

const String _toki = '\u{F196C}';

const Map<String, String> _course = <String, String>{
  'decks/tok/tok-en-first-words.yaml': '''
schema: 1
id: tok-en-first-words
name: "First words"
language: { code: tok, iso639_3: tok, name: Toki Pona, script: latin, scripts: [latin, sitelen_pona] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: tok-en-first-words-0001
    target: "toki"
    target_scripts: { sitelen_pona: "\u{F196C}" }
    native: "language"
  - id: tok-en-first-words-0002
    target: "pona"
    target_scripts: { sitelen_pona: "\u{F1954}" }
    native: "good"
''',
  'decks/tok/tok-en-script-sitelen-pona.yaml': '''
schema: 1
id: tok-en-script-sitelen-pona
name: "Sitelen pona: the glyphs"
language: { code: tok, iso639_3: tok, name: Toki Pona, script: sitelen_pona, scripts: [sitelen_pona, latin] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - id: tok-en-script-sitelen-pona-0001
    target: "\u{F196C}"
    target_scripts: { latin: "toki" }
    native: "language"
    reading: "toki"
    pos: letter
''',
  'decks/tok/tok-path.yaml': '''
schema: 1
kind: path
id: tok-path
language: tok
units:
  - [tok-first-words]
''',
};

IndexFont _font(String script) => IndexFont(
  path: 'decks/fonts/$script/Noto.ttf',
  size: 4,
  sha256: script.padRight(64, '0'),
  script: script,
);

void main() {
  testWidgets('a script tile draws its glyph in the downloaded font, and a '
      'Latin letter of the script\'s name until it is loaded', (tester) async {
    final downloads = DeckDownloads(
      fetcher: FakeDeckRemote(const <String, String>{}),
      files: MemoryDownloadedDecks(),
      clock: () => DateTime(2026, 11, 16),
      scriptFonts: ScriptFonts(register: (family, bytes) async {}),
    );
    final state = AppState.test(deckDownloads: downloads);
    addTearDown(state.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    ({String text, String? family}) face(String script, String name) =>
        scriptGlyphFace(context, script, name);

    // Not loaded: the rare scripts draw a letter, others their glyph.
    expect(face('sitelen_pona', 'Sitelen pona'), (text: 'S', family: null));
    expect(face('brahmi', 'Brahmi'), (text: 'B', family: null));
    expect(face('meitei_mayek', 'Meitei Mayek'), (text: 'M', family: null));
    expect(face('devanagari', 'Devanagari').family, isNull);
    expect(face('devanagari', 'Devanagari').text, 'न');

    for (final script in <String>[
      'sitelen_pona',
      'brahmi',
      'meitei_mayek',
      'perso_arabic',
    ]) {
      await downloads.fonts.load(_font(script), Uint8List(4));
    }
    final loaded = face('sitelen_pona', 'Sitelen pona');
    expect(loaded.text, _toki);
    expect(loaded.family, 'FluenoughScript-sitelen_pona');
    expect(face('brahmi', 'Brahmi').family, 'FluenoughScript-brahmi');
    expect(
      face('meitei_mayek', 'Meitei Mayek').family,
      'FluenoughScript-meitei_mayek',
    );
    // Shahmukhi shares the Urdu font.
    expect(
      face('shahmukhi', 'Shahmukhi').family,
      'FluenoughScript-perso_arabic',
    );
  });

  group('typed answers', () {
    Future<AppState> toki(Set<String> scripts) async {
      final state = AppState.test(
        decks: MemoryDeckSource(_course),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['tok'],
          learningChosen: true,
          scriptsLearned: <String, Set<String>>{'tok': scripts},
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      return state;
    }

    DrillSession production(AppState state) {
      final card = state.deckById('tok-en-first-words')!.cards.first;
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(card: card, mode: DrillMode.production, state: null),
        ],
      );
      addTearDown(session.dispose);
      return session;
    }

    test('a learner who reads only sitelen pona is shown it but answers in '
        'Latin letters', () async {
      final state = await toki(<String>{'sitelen_pona'});
      final deck = state.deckById('tok-en-first-words')!;
      expect(
        state.targetShown(deck.cards.first, deck.language).text,
        _toki,
        reason: 'the card is shown in sitelen pona',
      );
      final session = production(state);
      expect(session.writeScripts, <String>['latin']);
      expect(session.inputScript, 'latin');
      expect(session.writtenTarget, 'toki');
      expect(session.acceptedAnswers, contains('toki'));
      expect(session.acceptedAnswers, isNot(contains(_toki)));
    });

    test('a learner of both is offered Latin letters only', () async {
      final state = await toki(<String>{'latin', 'sitelen_pona'});
      final session = production(state);
      expect(session.writeScripts, <String>['latin']);
    });

    test('in the glyph deck, written in sitelen pona, the answer is the '
        'Latin word', () async {
      final state = await toki(<String>{'sitelen_pona'});
      final glyphs = state.deckById('tok-en-script-sitelen-pona')!;
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(
            card: glyphs.cards.first,
            mode: DrillMode.production,
            state: null,
          ),
        ],
      );
      addTearDown(session.dispose);
      expect(session.writeScripts, <String>['latin']);
      expect(session.writtenTarget, 'toki');
      expect(session.acceptedAnswers, contains('toki'));
      expect(session.acceptedAnswers, isNot(contains(_toki)));
    });

    test('the script has no keyboard, and other scripts are unchanged', () {
      expect(LanguageInfo.noKeyboardScripts, contains('sitelen_pona'));
      expect(LanguageInfo.noKeyboardScripts, isNot(contains('kana')));
      expect(LanguageInfo.noKeyboardScripts, isNot(contains('cuneiform')));
    });
  });
}
