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
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/fonts/font_check_prompt.dart';
import 'package:fluenough/ui/script_name.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/picker.dart';

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

const Map<String, String> _teCourse = <String, String>{
  'decks/te/te-en-first-words.yaml': '''
schema: 1
id: te-en-first-words
name: "First words"
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: te-en-first-words-0001, target: "నమస్తే", native: "hello", reading: "namastē" }
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
    List<Text> textsOf(String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(Text),
          ),
        )
        .toList();
    Text textOf(String key) => textsOf(key).single;
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
    // The learner learns sitelen pona and reads Latin: the glyphs are the
    // main text, the Latin spelling the smaller line beneath it.
    final withCard = textsOf('with-card');
    expect(withCard.map((t) => t.data), <String?>[_toki, 'toki']);
    expect(withCard.first.style!.fontFamily, 'FluenoughScript-sitelen_pona');
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
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(TargetText),
            matching: find.byType(Text),
          ),
        )
        .toList();
    // The glyph as it is, then the Latin spelling the learner reads.
    expect(texts.map((t) => t.data), <String?>[_toki, 'toki']);
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

  test(
    'a failed or dismissed check never stops the next, and is done',
    () async {
      const sound = SoundCheck();
      const script = ScriptCheck('sitelen_pona');
      final ran = <SkillCheck>[];
      final done = <(SkillCheck, bool)>[];
      await runChecks(<SkillCheck>[sound, script], (check) async {
        ran.add(check);
        return check is! SoundCheck;
      }, (check, passed) => done.add((check, passed)));
      expect(ran, <SkillCheck>[sound, script]);
      expect(done, <(SkillCheck, bool)>[(sound, false), (script, true)]);
    },
  );

  test('runChecks stops when the screen is gone', () async {
    final ran = <SkillCheck>[];
    await runChecks(
      const <SkillCheck>[SoundCheck(), ScriptCheck('thai')],
      (check) async {
        ran.add(check);
        return true;
      },
      (_, _) {},
      stop: () => true,
    );
    expect(ran, hasLength(1));
  });

  group('only scripts shown to the learner are offered', () {
    AppState tok(Set<String>? scripts, {Set<String> noAlphabet = const {}}) {
      final s = AppState.test(
        decks: MemoryDeckSource(_course),
        deckDownloads: downloads,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['tok'],
          learningChosen: true,
          noAlphabet: noAlphabet,
          scriptsLearned: <String, Set<String>>{'tok': ?scripts},
        ),
      );
      addTearDown(s.dispose);
      return s;
    }

    test('a Latin-only Toki Pona learner opening the glyph deck is not asked '
        'about sitelen pona, since its cards show Latin', () async {
      final s = tok(<String>{'latin'});
      await s.load();
      final deck = s.deckById('tok-en-script-sitelen-pona')!;
      s.offerFonts(deck.language);
      expect(s.fontCheck.pending, isNull);
    });

    AppState te({Set<String>? scripts, Set<String> noAlphabet = const {}}) {
      final s = AppState.test(
        decks: MemoryDeckSource(_teCourse),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
          noAlphabet: noAlphabet,
          scriptsLearned: <String, Set<String>>{'te': ?scripts},
        ),
      );
      addTearDown(s.dispose);
      return s;
    }

    test('a learner who reads Telugu in romanisation is asked about no '
        'script, on a deck or a word', () async {
      final s = te(noAlphabet: <String>{'te'});
      await s.load();
      final deck = s.deckById('te-en-first-words')!;
      expect(s.readsFirst(deck.language), isTrue);
      s.offerFonts(deck.language);
      expect(s.fontCheck.pending, isNull);
    });

    test('a learner of the Telugu script is asked about it', () async {
      final s = te(scripts: <String>{'telugu'});
      await s.load();
      s.offerFonts(s.deckById('te-en-first-words')!.language);
      expect(s.fontCheck.pending, 'telugu');
    });

    test('a learner of sitelen pona is asked about it', () async {
      final s = tok(<String>{'latin', 'sitelen_pona'});
      await s.load();
      final deck = s.deckById('tok-en-script-sitelen-pona')!;
      s.offerFonts(deck.language);
      expect(s.fontCheck.pending, 'sitelen_pona');
    });
  });

  group('the Languages sheet', () {
    SpokenLanguage tokLanguage() =>
        pickerSpokenList.firstWhere((l) => l.code == 'tok');

    CatalogLanguage course() => CatalogLanguage(
      code: 'tok',
      name: 'Toki Pona',
      natives: <CatalogNative>[
        (
          code: 'en',
          name: 'English',
          progress: B1Progress.of(<B1Unit>[
            const B1Unit(words: 10, milestone: Milestone.a1, has: 10),
          ]),
        ),
      ],
    );

    Future<AppState> pumpDraft(WidgetTester tester) async {
      final s = AppState.test(
        decks: MemoryDeckSource(_course),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      addTearDown(s.dispose);
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: LanguageSkillsSheet(
            view: LanguageView(tokLanguage(), course()),
            draft: true,
          ),
        ),
        state: s,
      );
      return s;
    }

    Finder add(AppLocalizations l10n) => find.widgetWithText(
      FilledButton,
      l10n.languagesAddLanguage('Toki Pona'),
    );

    Future<void> tap(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('a language with no voice can be added with Hear and Speak '
        'on: no sound test is owed', (tester) async {
      await pumpDraft(tester);
      final l10n = l10nOf(tester);
      // Leave, Learn, Hear: at each, Add is offered and no test is owed.
      for (var i = 0; i < 2; i++) {
        await tap(tester, 'skill-spoken');
        expect(find.text(l10n.languagesCheck), findsNothing);
        expect(add(l10n), findsOneWidget);
        expect(tester.widget<FilledButton>(add(l10n)).onPressed, isNotNull);
      }
    });

    testWidgets(
      'dismissing the font check with Later does not block adding the '
      'language',
      (tester) async {
        await pumpDraft(tester);
        final l10n = l10nOf(tester);
        // Cycle the sitelen pona pill until it is Learn: Check appears.
        for (var i = 0; i < 4; i++) {
          if (find.text(l10n.languagesCheck).evaluate().isNotEmpty) break;
          await tap(tester, 'skill-script:sitelen_pona');
        }
        expect(find.text(l10n.languagesCheck), findsOneWidget);
        await tester.tap(find.text(l10n.languagesCheck));
        await tester.pumpAndSettle();
        expect(find.text(l10n.fontCheckLater), findsOneWidget);
        await tester.tap(find.text(l10n.fontCheckLater));
        await tester.pumpAndSettle();
        // Skipped, not owed: the button is Add again, and enabled.
        expect(find.text(l10n.languagesCheck), findsNothing);
        expect(add(l10n), findsOneWidget);
        expect(tester.widget<FilledButton>(add(l10n)).onPressed, isNotNull);
      },
    );
  });
}
