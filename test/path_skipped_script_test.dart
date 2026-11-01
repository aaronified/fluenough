// The Decks path for a learner of one script of a language written in
// several (mockup skill-pills-onboarding screen 4, approved
// 2026-11-01): the decks of the script they skip get a titled section with
// an Add it button instead of sitting under Other decks, and the first unit
// of their script says "Your script". A learner of every script, and a
// language with one script, see none of it.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _dev = 'devanagari';
const String _perso = 'perso_arabic';

String _deck(
  String native,
  String name,
  String id,
  String script,
  int cards, {
  bool isScript = true,
}) {
  final scripts = script == _perso
      ? '[perso_arabic], rtl: true'
      : '[devanagari, perso_arabic]';
  final nativeName = native == 'bn' ? 'Bengali' : 'English';
  final iso = native == 'bn' ? 'ben' : 'eng';
  return '''
schema: 1
id: hi-$native-$id
name: "$name"
language: { code: hi, iso639_3: hin, name: Hindustani, script: $script, scripts: $scripts }
native: { code: $native, iso639_3: $iso, name: $nativeName }
license: CC0-1.0
${isScript ? 'tags: [script]\n' : ''}cards:
${<String>[for (var i = 1; i <= cards; i++) '  - { id: hi-$native-$id-000$i, target: "क", native: "k$i", reading: "ka" }'].join('\n')}
''';
}

/// Hindustani taught from [native]: two Devanagari script decks (3 cards),
/// two Perso-Arabic script decks (3 cards) and a words deck, in that order
/// on its path; and, from [other], a deck of its own that the course leaves
/// to Other decks.
MemoryDeckSource _course({
  String native = 'en',
  String other = 'bn',
}) => MemoryDeckSource(<String, String>{
  'decks/hi/a.yaml': _deck(native, 'Devanagari letters', 'letters', _dev, 1),
  'decks/hi/b.yaml': _deck(native, 'Devanagari vowels', 'vowels', _dev, 2),
  'decks/hi/c.yaml': _deck(
    native,
    'Perso-Arabic letters',
    'urdu-letters',
    _perso,
    1,
  ),
  'decks/hi/d.yaml': _deck(
    native,
    'Perso-Arabic marks',
    'urdu-marks',
    _perso,
    2,
  ),
  'decks/hi/e.yaml': _deck(native, 'Words', 'words', _dev, 2, isScript: false),
  'decks/hi/f.yaml': _deck(
    other,
    'Other course words',
    'words',
    _dev,
    1,
    isScript: false,
  ),
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
alphabet:
  - hi-letters
  - hi-vowels
  - hi-urdu-letters
  - hi-urdu-marks
units:
  - [hi-letters]
  - [hi-vowels]
  - [hi-urdu-letters]
  - [hi-urdu-marks]
  - [hi-words]
''',
});

Future<AppState> _learner({
  Set<String>? scripts,
  String native = 'en',
  String other = 'bn',
}) async {
  final state = AppState.test(
    decks: _course(native: native, other: other),
    settings: SettingsNotifier(
      spokenLanguages: <String>[native],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'hi': ?scripts},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

/// Telugu, written in one script, with an alphabet deck on its path.
MemoryDeckSource _teluguCourse() => MemoryDeckSource(<String, String>{
  for (final (id, name, tag) in <(String, String, String)>[
    ('letters', 'Telugu letters', 'tags: [script]\n'),
    ('words', 'Telugu words', ''),
  ])
    'decks/te/$id.yaml':
        '''
schema: 1
id: te-en-$id
name: "$name"
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
${tag}cards:
  - { id: te-en-$id-0001, target: "క", native: "k", reading: "ka" }
''',
  'decks/te/te-path.yaml': '''
schema: 1
kind: path
id: te-path
language: te
alphabet:
  - te-letters
units:
  - [te-letters]
  - [te-words]
''',
});

Future<AppState> _telugu({bool alphabet = true}) async {
  final state = AppState.test(
    decks: _teluguCourse(),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['te'],
      learningChosen: true,
      noAlphabet: alphabet ? const <String>{} : const <String>{'te'},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

Set<String> _ids(Iterable<DeckEntry> decks) => <String>{
  for (final d in decks) d.id,
};

const List<SpokenLanguage> _spoken = <SpokenLanguage>[
  SpokenLanguage(
    code: 'hi',
    iso639_3: 'hin',
    name: 'Hindustani',
    ownName: 'हिन्दुस्तानी',
    scripts: <String>[_dev, _perso],
  ),
  SpokenLanguage(
    code: 'bn',
    iso639_3: 'ben',
    name: 'Bengali',
    ownName: 'বাংলা',
    scripts: <String>['bengali'],
  ),
];

Finder _pathScroll() => find.descendant(
  of: find.byType(CustomScrollView),
  matching: find.byType(Scrollable),
);

Future<void> _pump(
  WidgetTester tester,
  AppState state, {
  double textScale = 1.4,
  ThemeMode mode = ThemeMode.light,
  TextDirection? direction,
}) async {
  usePhone(tester, textScale: textScale);
  const page = DecksPage(spokenList: _spoken);
  await pumpScreen(
    tester,
    direction == null
        ? page
        : Directionality(textDirection: direction, child: page),
    state: state,
    themeMode: mode,
  );
}

Future<void> _toBottom(WidgetTester tester) async {
  await tester.drag(_pathScroll().first, const Offset(0, -20000));
  await tester.pumpAndSettle();
}

void main() {
  group('the path model', () {
    test('Perso-Arabic only: the Devanagari decks are grouped under a section '
        'for the script, the first Perso-Arabic unit is flagged, and the '
        'Script learned milestone follows the units learned', () async {
      final state = await _learner(scripts: <String>{_perso});
      final view = courseView(state, 'hi')!;

      expect(view.skippedScripts, hasLength(1));
      final skipped = view.skippedScripts.single;
      expect(skipped.script, _dev);
      expect(_ids(skipped.decks), <String>{'hi-en-letters', 'hi-en-vowels'});
      expect(skipped.cards, 3);
      // What is not a skipped script deck stays under Other decks.
      expect(_ids(view.otherDecks), <String>{'hi-bn-words'});

      final flagged = <String>[
        for (final u in view.units)
          if (u.yourScript) u.title,
      ];
      expect(flagged, <String>['Perso-Arabic letters']);

      final script = view.steps.whereType<MilestoneStep>().singleWhere(
        (m) => m.kind == MilestoneKind.script,
      );
      expect(script.earned, isFalse);
      expect(script.toGo, 2);
      final at = view.steps.indexOf(script);
      expect((view.steps[at - 1] as UnitStep).title, 'Perso-Arabic marks');
    });

    test('a Bengali speaker learning Devanagari only: the section names '
        'Perso-Arabic and the pill is on Devanagari letters', () async {
      final state = await _learner(
        scripts: <String>{_dev},
        native: 'bn',
        other: 'en',
      );
      final view = courseView(state, 'hi')!;
      expect(view.skippedScripts.single.script, _perso);
      expect(_ids(view.skippedScripts.single.decks), <String>{
        'hi-bn-urdu-letters',
        'hi-bn-urdu-marks',
      });
      expect(view.skippedScripts.single.cards, 3);
      expect(
        <String>[
          for (final u in view.units)
            if (u.yourScript) u.title,
        ],
        <String>['Devanagari letters'],
      );
    });

    test('the primary script alone, as nothing was chosen, is one script '
        'too', () async {
      final view = courseView(await _learner(), 'hi')!;
      expect(view.skippedScripts.single.script, _perso);
      expect(
        view.units.where((u) => u.yourScript).single.title,
        'Devanagari letters',
      );
    });

    test(
      'both scripts: no section and no flag, Other decks as before',
      () async {
        final state = await _learner(scripts: <String>{_dev, _perso});
        final view = courseView(state, 'hi')!;
        expect(view.skippedScripts, isEmpty);
        expect(view.units.any((u) => u.yourScript), isFalse);
        expect(_ids(view.otherDecks), <String>{'hi-bn-words'});
        expect(view.units, hasLength(5));
      },
    );

    test('a language with one script is unchanged, with its alphabet or '
        'without it', () async {
      final withAlphabet = courseView(await _telugu(), 'te')!;
      expect(withAlphabet.skippedScripts, isEmpty);
      expect(withAlphabet.units.any((u) => u.yourScript), isFalse);
      expect(withAlphabet.otherDecks, isEmpty);

      final without = courseView(await _telugu(alphabet: false), 'te')!;
      expect(without.skippedScripts, isEmpty);
      expect(without.units.any((u) => u.yourScript), isFalse);
      expect(_ids(without.otherDecks), <String>{'te-en-letters'});
    });
  });

  group('the Decks tab', () {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Perso-Arabic only, at 1.4x text in $mode: a titled section '
          'with its decks, one Your script mark, Other decks kept for the '
          'rest', (tester) async {
        final state = await _learner(scripts: <String>{_perso});
        await _pump(tester, state, mode: mode);
        final l10n = l10nOf(tester);
        expect(
          find.byKey(const ValueKey<String>('your-script')),
          findsOneWidget,
        );

        await _toBottom(tester);
        expect(
          find.text(l10n.pathSkippedScriptTitle('Devanagari')),
          findsOneWidget,
        );
        expect(find.text(l10n.pathSkippedScriptCount(2, 3)), findsOneWidget);
        expect(
          find.text(l10n.pathSkippedScriptWhy('Hindustani', 'Perso-Arabic')),
          findsOneWidget,
        );
        expect(find.text(l10n.pathSkippedScriptAdd), findsOneWidget);
        // Listed, not folded.
        expect(find.text('Devanagari letters'), findsOneWidget);
        expect(find.text('Devanagari vowels'), findsOneWidget);
        // The other course's deck still sits under Other decks.
        expect(find.text(l10n.pathOtherDecks), findsOneWidget);
        expect(find.text('Other course words'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the Your script mark is on the first Perso-Arabic unit', (
      tester,
    ) async {
      await _pump(tester, await _learner(scripts: <String>{_perso}));
      final pill = find.byKey(const ValueKey<String>('your-script'));
      final card = find.ancestor(of: pill, matching: find.byType(InkWell));
      expect(
        find.descendant(
          of: card.first,
          matching: find.text('Perso-Arabic letters'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("Add it opens the language's skills sheet", (tester) async {
      await _pump(tester, await _learner(scripts: <String>{_perso}));
      await _toBottom(tester);
      final add = find.byKey(const ValueKey<String>('skipped-script-add'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSkillsSheet), findsNothing);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSkillsSheet), findsOneWidget);
    });

    testWidgets('Add it is named for the script for a screen reader', (
      tester,
    ) async {
      await _pump(tester, await _learner(scripts: <String>{_perso}));
      await _toBottom(tester);
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(
          l10nOf(tester).pathSkippedScriptAddSemantics('Devanagari'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a Bengali speaker learning Devanagari only: the section '
        'names Perso-Arabic', (tester) async {
      final state = await _learner(
        scripts: <String>{_dev},
        native: 'bn',
        other: 'en',
      );
      await _pump(tester, state);
      await _toBottom(tester);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.pathSkippedScriptTitle('Perso-Arabic')),
        findsOneWidget,
      );
      expect(find.text('Perso-Arabic letters'), findsOneWidget);
    });

    testWidgets('right to left, the section lays out without overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        await _learner(scripts: <String>{_perso}),
        direction: TextDirection.rtl,
      );
      await _toBottom(tester);
      expect(find.text(l10nOf(tester).pathSkippedScriptAdd), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both scripts: no section and no mark', (tester) async {
      await _pump(tester, await _learner(scripts: <String>{_dev, _perso}));
      expect(find.byKey(const ValueKey<String>('your-script')), findsNothing);
      await _toBottom(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pathSkippedScriptAdd), findsNothing);
      expect(find.text(l10n.pathOtherDecks), findsOneWidget);
    });
  });
}
