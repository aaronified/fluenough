// Sitelen pona's glyphs are private-use code points no phone has a font for
// (ADR-0055). Opening a deck written in it offers the font check, the glyphs
// are boxes' stand-in until the font is downloaded and the script's family
// after, and a failed sound test never stops the font check.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/font_check.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/fonts/font_check_prompt.dart';
import 'package:fluenough/ui/script_name.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';

const String _toki = '\u{F196C}';
const String _fontPath = 'decks/fonts/sitelen_pona/SitelenSeliKiwen.ttf';

const Map<String, String> _course = <String, String>{
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
};

/// The remote's index with Toki Pona's sitelen pona font, as decks-live has it.
void _serveFont(FakeDeckRemote remote) {
  final json = jsonDecode(indexFor(remote.files)) as Map<String, Object?>;
  for (final language in json['languages']! as List<Object?>) {
    final map = language! as Map<String, Object?>;
    if (map['code'] != 'tok') continue;
    map['fonts'] = <Object?>[
      <String, Object?>{
        'path': _fontPath,
        'size': utf8.encode(_fontPath).length,
        'sha256': sha256Hex(utf8.encode(_fontPath)),
        'script': 'sitelen_pona',
        'family': 'sitelen seli kiwen asuki',
      },
    ];
  }
  remote.index = jsonEncode(json);
  remote.served[_fontPath] = _fontPath;
}

void main() {
  late AppState state;
  late DeckDownloads downloads;

  setUp(() async {
    final remote = FakeDeckRemote(_course);
    _serveFont(remote);
    downloads = DeckDownloads(
      fetcher: remote,
      files: MemoryDownloadedDecks(),
      clock: () => DateTime(2026, 11, 17),
      scriptFonts: ScriptFonts(register: (family, bytes) async {}),
    );
    await downloads.open();
    await downloads.ensureIndex();
    state = AppState.test(
      decks: MemoryDeckSource(_course),
      deckDownloads: downloads,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['tok'],
        learningChosen: true,
        scriptsLearned: <String, Set<String>>{
          'tok': <String>{'sitelen_pona'},
        },
      ),
    );
    await state.load();
  });

  tearDown(() => state.dispose());

  testWidgets('opening a deck written in sitelen pona offers the font check '
      'when its font is not on the phone', (tester) async {
    expect(state.fontCheck.pending, isNull);
    await pumpScreen(
      tester,
      const FontCheckPrompt(
        child: DeckDetailPage(deckId: 'tok-en-script-sitelen-pona'),
      ),
      state: state,
      settle: false,
    );
    await tester.pump();
    await tester.pump();
    expect(state.fontCheck.pending, 'sitelen_pona');
    final l10n = l10nOf(tester);
    expect(
      find.text(l10n.fontCheckTitle(l10n.scriptNameOr('sitelen_pona', ''))),
      findsOneWidget,
    );
    expect(find.text(l10n.fontCheckNo), findsOneWidget);
  });

  testWidgets('the glyphs are a stand-in, not boxes, before the font and the '
      'script\'s family after', (tester) async {
    final deck = state.deckById('tok-en-script-sitelen-pona')!;
    final card = deck.cards.first;
    await pumpScreen(
      tester,
      Scaffold(
        body: Column(
          children: <Widget>[
            TargetText(
              card.target,
              language: deck.language,
              fontSize: 40,
              card: card,
              key: const ValueKey<String>('with-card'),
            ),
            TargetText(
              card.target,
              language: deck.language,
              fontSize: 40,
              key: const ValueKey<String>('raw'),
            ),
          ],
        ),
      ),
      state: state,
    );
    Text textOf(String key) => tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byType(Text),
      ),
    );
    // Not loaded: the card shows its Latin spelling, a bare text a mark; never
    // the private-use glyph.
    expect(textOf('with-card').data, 'toki');
    expect(textOf('raw').data, isNot(_toki));
    expect(textOf('raw').data, '…');

    await downloads.fonts.load(
      IndexFont(
        path: _fontPath,
        size: 4,
        sha256: 'a' * 64,
        script: 'sitelen_pona',
      ),
      Uint8List(4),
    );
    await tester.pump();
    expect(textOf('with-card').data, _toki);
    expect(
      textOf('with-card').style!.fontFamily,
      'FluenoughScript-sitelen_pona',
    );
    expect(textOf('raw').data, _toki);
    expect(textOf('raw').style!.fontFamily, 'FluenoughScript-sitelen_pona');
  });

  testWidgets('a learner who said the phone draws it sees the glyph as it '
      'is', (tester) async {
    state.settings.setFontChoice('sitelen_pona', FontChoice.phone);
    final deck = state.deckById('tok-en-script-sitelen-pona')!;
    await pumpScreen(
      tester,
      Scaffold(
        body: TargetText(
          deck.cards.first.target,
          language: deck.language,
          fontSize: 40,
          card: deck.cards.first,
        ),
      ),
      state: state,
    );
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(TargetText), matching: find.byType(Text)),
    );
    expect(text.data, _toki);
  });

  test('the other font-only scripts have a sample, so the check can ask', () {
    for (final script in <String>[
      'brahmi',
      'meitei_mayek',
      'sitelen_pona',
      'cuneiform',
      'egyptian_hieroglyphs',
      'linear_b',
      'ol_chiki',
    ]) {
      expect(scriptSamples, contains(script), reason: script);
    }
  });

  test('a failed sound test does not stop the script\'s font check', () async {
    const sound = SoundCheck();
    const script = ScriptCheck('sitelen_pona');
    final ran = <SkillCheck>[];
    final passed = <SkillCheck>[];
    await runChecks(<SkillCheck>[sound, script], (check) async {
      ran.add(check);
      return check is! SoundCheck;
    }, passed.add);
    expect(ran, <SkillCheck>[sound, script]);
    expect(passed, <SkillCheck>[script]);
  });

  test('runChecks stops when the screen is gone', () async {
    final ran = <SkillCheck>[];
    await runChecks(
      const <SkillCheck>[SoundCheck(), ScriptCheck('thai')],
      (check) async {
        ran.add(check);
        return true;
      },
      (_) {},
      stop: () => true,
    );
    expect(ran, hasLength(1));
  });
}
