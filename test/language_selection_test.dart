// Add a language (the approved mockup `docs/mockups/language-picker.html`):
// the eight tiles of its first screen, the full list with its one key, a bar
// of four parts and a verification flag a row, Scripts and sounds and the
// folded Coming soon, the verification row of the details dialog, and the
// Languages page's one pill arrangement. What a learner sees, at 1.4x text
// in light and dark.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/features/languages/language_pick_list.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/features/languages/verification_mark.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/faded_row.dart';

import 'support/harness.dart';
import 'support/picker.dart';

SpokenLanguage lang(
  String code,
  String name, {
  String own = '',
  bool popular = false,
  NativeVerification verification = NativeVerification.none,
  List<String> aliases = const <String>[],
}) => SpokenLanguage(
  code: code,
  iso639_3: 'xxx',
  name: name,
  ownName: own.isEmpty ? name : own,
  scripts: const <String>['latin'],
  popular: popular,
  verification: verification,
  aliases: aliases,
);

B1Unit written(Milestone m) => B1Unit(words: 10, milestone: m, has: 10);

B1Unit planned(Milestone m) => B1Unit(planned: true, words: 10, milestone: m);

/// A course whose path is [units], taught from English.
CatalogLanguage course(String code, String name, List<B1Unit> units) =>
    CatalogLanguage(
      code: code,
      name: name,
      natives: <CatalogNative>[
        (code: 'en', name: 'English', progress: B1Progress.of(units)),
      ],
    );

/// File order, as `assets/languages.yaml` has it: the tiles are the first
/// eight popular ones in this order, five here. Zulu has A1 to B1 written,
/// Alpha A1 and A2, Delta A1, Bravo a part of A1, Foxtrot nothing but first
/// words; Charlie has a course too. Echo and Golf have none (Coming soon),
/// IPA is a notation.
final List<SpokenLanguage> sample = <SpokenLanguage>[
  lang('zz', 'Zulu', popular: true, verification: NativeVerification.full),
  lang('aa', 'Alpha', popular: true),
  lang('dd', 'Delta', popular: true, aliases: <String>['Dalmatian']),
  lang('bb', 'Bravo', popular: true, verification: NativeVerification.some),
  lang('ff', 'Foxtrot', popular: true),
  lang('cc', 'Charlie', verification: NativeVerification.full),
  lang('ee', 'Echo'),
  lang('gg', 'Golf', own: 'Gölf'),
  lang('ipa', 'IPA'),
];

final Map<String, CatalogLanguage> sampleCourses = <String, CatalogLanguage>{
  'zz': course('zz', 'Zulu', <B1Unit>[
    written(Milestone.a1),
    written(Milestone.a2),
    written(Milestone.b1),
  ]),
  'aa': course('aa', 'Alpha', <B1Unit>[
    written(Milestone.a1),
    written(Milestone.a2),
    planned(Milestone.b1),
  ]),
  'dd': course('dd', 'Delta', <B1Unit>[
    written(Milestone.a1),
    planned(Milestone.a2),
    planned(Milestone.b1),
  ]),
  'bb': course('bb', 'Bravo', <B1Unit>[
    // Some words written, A1 itself not yet: a beginner course.
    const B1Unit(words: 10, has: 10),
    planned(Milestone.a1),
    planned(Milestone.a2),
  ]),
  'ff': course('ff', 'Foxtrot', const <B1Unit>[]),
  'cc': course('cc', 'Charlie', const <B1Unit>[]),
};

List<LanguageView> sampleViews([List<SpokenLanguage>? list]) => <LanguageView>[
  for (final l in list ?? sample) LanguageView(l, sampleCourses[l.code]),
];

AppLocalizations l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

/// The picker list on a 360 dp phone at 1.4x text, tall enough to build the
/// whole lazy list, with [added] on the learner's list; [picked] gets the
/// codes of what a tap picked.
Future<void> pumpList(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  List<LanguageView>? views,
  Set<String> added = const <String>{},
  List<String>? picked,
  double height = 3000,
  String? initialQuery,
}) async {
  usePhone(tester, textScale: 1.4);
  tester.view.physicalSize = Size(360 * 3, height * 3);
  await pumpScreen(
    tester,
    Scaffold(
      body: LanguagePickList(
        views: views ?? sampleViews(),
        initialQuery: initialQuery,
        isAdded: (v) => added.contains(v.code),
        onPick: (v) => picked?.add(v.code),
      ),
    ),
    themeMode: mode,
  );
}

Finder key(String k) => find.byKey(ValueKey<String>(k));

double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(key('languages-add-search'), text);
  await tester.pumpAndSettle();
}

Future<void> seeAll(WidgetTester tester) async {
  await tester.tap(key('languages-see-all'));
  await tester.pumpAndSettle();
}

/// The tiles in the owner's order: the first eight popular languages of
/// `assets/languages.yaml`, in file order.
const List<String> tileOrder = <String>[
  'es',
  'fr',
  'te',
  'hi',
  'bn',
  'mr',
  'kn',
  'ja',
];

/// Every language of the real list, the tiles' ones with a course written to
/// B1 and the rest with none.
List<LanguageView> realViews() => <LanguageView>[
  for (final l in pickerSpokenList)
    LanguageView(
      l,
      tileOrder.contains(l.code)
          ? course(l.code, l.name, <B1Unit>[
              written(Milestone.a1),
              written(Milestone.a2),
              written(Milestone.b1),
            ])
          : null,
    ),
];

/// [codes] in the order their tiles are drawn: by row, then by column.
List<String> byPosition(WidgetTester tester, List<String> codes) {
  final sorted = <String>[...codes];
  sorted.sort((a, b) {
    final pa = tester.getTopLeft(key('tile-$a'));
    final pb = tester.getTopLeft(key('tile-$b'));
    final byRow = pa.dy.compareTo(pb.dy);
    return byRow != 0 ? byRow : pa.dx.compareTo(pb.dx);
  });
  return sorted;
}

void main() {
  group('the language list file', () {
    test('verification is none, some or full and is none when absent', () {
      final list = parseSpokenLanguages('''
kind: languages
languages:
  - { code: "aa", iso639_3: "aaa", name: "A", own_name: "A" }
  - { code: "bb", iso639_3: "bbb", name: "B", own_name: "B", verification: "some" }
  - { code: "cc", iso639_3: "ccc", name: "C", own_name: "C", verification: "full" }
''');
      expect(list.map((l) => l.verification), <NativeVerification>[
        NativeVerification.none,
        NativeVerification.some,
        NativeVerification.full,
      ]);
    });

    test('an unknown verification or a popular that is not a boolean is '
        'refused, naming the entry', () {
      String entry(String extra) =>
          '''
kind: languages
languages:
  - { code: "aa", iso639_3: "aaa", name: "A", own_name: "A", $extra }
''';
      expect(
        () => parseSpokenLanguages(entry('verification: "most"')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('languages[0]: verification'),
          ),
        ),
      );
      expect(
        () => parseSpokenLanguages(entry('popular: "yes"')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('languages[0]: popular'),
          ),
        ),
      );
    });

    test('the tiles are the first eight popular languages in file order, '
        'the owner\'s eight, and no language is verified yet', () {
      final all = parseSpokenLanguages(
        File('assets/languages.yaml').readAsStringSync(),
      );
      final popular = all.where((l) => l.popular).map((l) => l.name).toList();
      expect(popular, <String>[
        'Spanish',
        'French',
        'Telugu',
        'Hindustani',
        'Bengali',
        'Marathi',
        'Kannada',
        'Japanese',
      ]);
      expect(
        all.every((l) => l.verification == NativeVerification.none),
        isTrue,
      );
    });
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('Add a language in ${mode.name}', () {
      testWidgets('opens on the question, the search, the tiles from the '
          'data in file order, and See all languages; no key yet', (
        tester,
      ) async {
        await pumpList(tester, mode: mode, views: realViews());
        final text = l10n(tester);
        expect(find.text(text.languagesAddQuestion), findsOneWidget);
        expect(key('languages-add-search'), findsOneWidget);
        // Eight tiles, in two even columns, in the order of the file: the
        // order the owner chose, not A to Z; Mandarin Chinese is no tile.
        final tiles = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('tile-'),
        );
        expect(tiles, findsNWidgets(8));
        expect(byPosition(tester, <String>[...tileOrder.reversed]), tileOrder);
        // Two even columns: the same two left edges all the way down.
        final lefts = <double>{
          for (final c in tileOrder) tester.getTopLeft(key('tile-$c')).dx,
        };
        expect(lefts.length, 2);
        expect(
          tester.getSize(key('tile-es')).width,
          tester.getSize(key('tile-fr')).width,
        );
        expect(key('tile-zh'), findsNothing);
        expect(find.text(text.languagesSeeAll), findsOneWidget);
        // The key and the groups wait for the full list.
        expect(find.text(text.languagesCourseMadeKey), findsNothing);
        expect(find.text(text.languagesComingSoon), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tile has the name in its own script, the English name '
          'and one line from the levels the course has written', (
        tester,
      ) async {
        await pumpList(tester, mode: mode);
        final text = l10n(tester);
        for (final (code, status) in <(String, String)>[
          ('zz', text.languagesTileStatusA1B1),
          ('aa', text.languagesTileStatusA1A2),
          ('dd', text.languagesTileStatusA1),
          ('bb', text.languagesTileStatusBeginner),
          ('ff', text.languagesFirstWordsLabel),
        ]) {
          expect(
            find.descendant(of: key('tile-$code'), matching: find.text(status)),
            findsOneWidget,
            reason: code,
          );
        }
        // Zulu has its own name as its name; Gölf is no tile.
        expect(
          find.descendant(of: key('tile-zz'), matching: find.text('Zulu')),
          findsOneWidget,
        );
        expect(key('tile-gg'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tile of a language added already says so; a tap picks '
          'the language', (tester) async {
        final picked = <String>[];
        await pumpList(
          tester,
          mode: mode,
          added: <String>{'bb'},
          picked: picked,
        );
        final text = l10n(tester);
        Finder addedText(String code) => find.descendant(
          of: key('tile-$code'),
          matching: find.textContaining(
            text.languagesAdded,
            findRichText: true,
          ),
        );
        expect(addedText('bb'), findsOneWidget);
        expect(addedText('dd'), findsNothing);
        await tester.tap(key('tile-dd'));
        await tester.pumpAndSettle();
        expect(picked, <String>['dd']);
      });

      testWidgets('See all languages shows one key, then Languages A to Z '
          'with only the courses, Scripts and sounds, and Coming soon '
          'folded', (tester) async {
        await pumpList(tester, mode: mode);
        final text = l10n(tester);
        await seeAll(tester);
        // The key, once: how much of the course is made, its four parts and
        // the three flags.
        expect(find.text(text.languagesCourseMadeKey), findsOneWidget);
        for (final part in <String>[
          'A1',
          'A2',
          'B1',
          text.pickerLevelCulture,
        ]) {
          expect(find.text(part), findsOneWidget, reason: part);
        }
        for (final w in <String>[
          text.languagesVerifiedNone,
          text.languagesVerifiedSome,
          text.languagesVerifiedFull,
        ]) {
          expect(
            find.descendant(of: key('languages-key'), matching: find.text(w)),
            findsOneWidget,
          );
        }
        expect(find.text(text.languagesVerifiedKey), findsOneWidget);
        // Languages with a course, A to Z, under their heading.
        final heading = top(tester, find.text(text.languagesAllLanguages));
        final rows = <double>[
          for (final c in <String>['aa', 'bb', 'cc', 'dd', 'ff', 'zz'])
            top(tester, key('add-$c')),
        ];
        expect(rows, orderedEquals(<double>[...rows]..sort()));
        expect(rows.first, greaterThan(heading));
        expect(key('add-ee'), findsNothing);
        // Scripts and sounds after them, Coming soon last and folded.
        final scripts = top(tester, find.text(text.languagesScriptsAndSounds));
        final soon = top(tester, find.text(text.languagesComingSoon));
        expect(scripts, greaterThan(rows.last));
        expect(top(tester, key('add-ipa')), greaterThan(scripts));
        expect(soon, greaterThan(top(tester, key('add-ipa'))));
        expect(key('soon-ee'), findsNothing);
        expect(key('soon-gg'), findsNothing);
        // No count, no "No course yet" chip, no Popular group.
        expect(find.text(text.languagesNoCourse), findsNothing);
        expect(
          find.descendant(
            of: key('languages-coming-soon'),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a row has a name, own name and chevron, one slim bar of '
          'four outlined parts, and a flag; no labels and no text row', (
        tester,
      ) async {
        await pumpList(
          tester,
          mode: mode,
          views: sampleViews(),
          added: <String>{'aa'},
        );
        final text = l10n(tester);
        await seeAll(tester);
        final scheme = Theme.of(tester.element(key('add-aa'))).colorScheme;
        // Alpha has A1 and A2 written and B1 planned: two parts filled, two
        // empty, and every part an outlined capsule in the outline colour.
        final fills = tester
            .widgetList<FractionallySizedBox>(
              find.descendant(
                of: key('course-line-aa'),
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .map((w) => w.widthFactor)
            .toList();
        expect(fills, <double?>[1, 1, 0, 0]);
        for (var i = 0; i < 4; i++) {
          final capsule = tester.widget<Container>(
            find
                .descendant(
                  of: find.descendant(
                    of: key('course-line-aa'),
                    matching: key('course-segment-$i'),
                  ),
                  matching: find.byType(Container),
                )
                .first,
          );
          final border = (capsule.decoration! as BoxDecoration).border!;
          expect(border.top.color, scheme.outline);
        }
        // No label under the bar, and no "Verified:" text row.
        expect(
          find.descendant(
            of: key('course-line-aa'),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
        expect(find.textContaining(text.languagesVerifiedShort), findsNothing);
        // Added chip on the added row only.
        expect(
          find.descendant(
            of: key('add-aa'),
            matching: find.text(text.languagesAdded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: key('add-bb'),
            matching: find.text(text.languagesAdded),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('the flag says none, some and full by its shape; a tap '
          'shows the tooltip', (tester) async {
        await pumpList(tester, mode: mode);
        final text = l10n(tester);
        await seeAll(tester);
        Finder glyph(String code, IconData icon) =>
            find.descendant(of: key('flag-$code'), matching: find.byIcon(icon));
        // None: outlined only. Full: solid only. Some: both, the solid one
        // clipped to its start half.
        expect(glyph('aa', Icons.flag_outlined), findsOneWidget);
        expect(glyph('aa', Icons.flag), findsNothing);
        expect(glyph('zz', Icons.flag), findsOneWidget);
        expect(glyph('zz', Icons.flag_outlined), findsNothing);
        expect(glyph('bb', Icons.flag_outlined), findsOneWidget);
        expect(glyph('bb', Icons.flag), findsOneWidget);
        expect(tester.getSize(key('flag-bb')), const Size.square(40));
        // A tap shows a bubble, nothing else.
        final bubble =
            '${text.languagesVerifiedShort} '
            '${text.languagesVerifiedSome}';
        expect(find.text(bubble), findsNothing);
        await tester.tap(key('flag-bb'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(bubble), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        // The bubble goes by itself.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text(bubble), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a screen reader reads each bar as how much of the course '
          'is made, never as progress, and the flag with the longer text', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpList(tester, mode: mode);
        final text = l10n(tester);
        await seeAll(tester);
        final shares = <double>[1, 1, 0, 0];
        final label = text.languagesCourseMadeLabel(
          <String>[
            for (final (i, name) in <String>[
              'A1',
              'A2',
              'B1',
              text.pickerLevelCulture,
            ].indexed)
              '$name ${text.commonPercent(shares[i])}',
          ].join(text.commonListSeparator),
        );
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(label.toLowerCase(), isNot(contains('progress')));
        expect(
          find.bySemanticsLabel(
            text.languagesVerifiedLabel(
              text.languagesVerifiedSome.toLowerCase(),
            ),
          ),
          findsOneWidget,
        );
        // A course with first words only says so.
        expect(
          find.bySemanticsLabel(text.languagesFirstWordsLabel),
          findsWidgets,
        );
        handle.dispose();
      });

      testWidgets('Scripts and sounds rows have neither bar nor flag, and a '
          'tap picks them', (tester) async {
        final picked = <String>[];
        await pumpList(tester, mode: mode, picked: picked);
        await seeAll(tester);
        expect(key('add-ipa'), findsOneWidget);
        expect(key('course-line-ipa'), findsNothing);
        expect(key('flag-ipa'), findsNothing);
        await tester.tap(key('add-ipa'));
        await tester.pumpAndSettle();
        expect(picked, <String>['ipa']);
      });

      testWidgets('Coming soon opens on a tap, shows names only, and its rows '
          'are not tappable', (tester) async {
        final handle = tester.ensureSemantics();
        final picked = <String>[];
        await pumpList(tester, mode: mode, picked: picked);
        final text = l10n(tester);
        await seeAll(tester);
        await tester.tap(key('languages-coming-soon'));
        await tester.pumpAndSettle();
        expect(key('soon-ee'), findsOneWidget);
        expect(key('soon-gg'), findsOneWidget);
        expect(
          find.descendant(of: key('soon-gg'), matching: find.text('Gölf')),
          findsOneWidget,
        );
        // Not a button: no chevron, no ink, no bar, no flag, no pick.
        expect(
          find.descendant(
            of: key('soon-ee'),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: key('soon-ee'), matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(key('flag-ee'), findsNothing);
        expect(key('course-line-ee'), findsNothing);
        await tester.tap(key('soon-ee'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(picked, isEmpty);
        expect(
          find.bySemanticsLabel(text.languagesNoCourseLabel('Echo')),
          findsOneWidget,
        );
        // Folds again.
        await tester.tap(key('languages-coming-soon'));
        await tester.pumpAndSettle();
        expect(key('soon-ee'), findsNothing);
        handle.dispose();
      });

      testWidgets('a search shows the list, Popular matches first; names, '
          'own names and aliases match; a match in Coming soon opens it', (
        tester,
      ) async {
        await pumpList(tester, mode: mode);
        final text = l10n(tester);
        await search(tester, 'l');
        // Off the tiles, onto the list, without tapping See all.
        expect(find.text(text.languagesAddQuestion), findsNothing);
        // Alpha, Delta and Zulu are popular, Charlie is not.
        final order = <double>[
          for (final c in <String>['aa', 'dd', 'zz', 'cc'])
            top(tester, key('add-$c')),
        ];
        expect(order, orderedEquals(<double>[...order]..sort()));
        expect(key('add-bb'), findsNothing);
        await search(tester, 'dalm');
        expect(key('add-dd'), findsOneWidget);
        expect(key('add-zz'), findsNothing);
        // Golf is in Coming soon, open without a tap, found by its own name
        // without the accent.
        await search(tester, 'golf');
        expect(key('soon-gg'), findsOneWidget);
        expect(key('add-aa'), findsNothing);
        await search(tester, 'qqq');
        expect(find.text(text.languagesAddNoMatch('qqq')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the search keeps focus while typing on the first screen', (
        tester,
      ) async {
        await pumpList(tester, mode: mode);
        await tester.tap(key('languages-add-search'));
        await tester.pump();
        await tester.enterText(key('languages-add-search'), 'a');
        await tester.pump();
        await tester.enterText(key('languages-add-search'), 'al');
        await tester.pump();
        final field = tester.widget<EditableText>(find.byType(EditableText));
        expect(field.focusNode.hasFocus, isTrue);
        expect(find.text('al'), findsOneWidget);
      });

      testWidgets('a popular language with no course is no tile', (
        tester,
      ) async {
        final views = <LanguageView>[
          ...sampleViews(),
          LanguageView(lang('hh', 'Hotel', popular: true), null),
        ];
        await pumpList(tester, mode: mode, views: views);
        expect(key('tile-hh'), findsNothing);
        expect(key('tile-zz'), findsOneWidget);
      });

      testWidgets('Coming soon can be closed during a search', (tester) async {
        await pumpList(tester, mode: mode);
        await search(tester, 'golf');
        expect(key('soon-gg'), findsOneWidget);
        await tester.tap(key('languages-coming-soon'));
        await tester.pumpAndSettle();
        expect(key('soon-gg'), findsNothing);
      });

      testWidgets('tapping a row picks that language; Back from the list goes '
          'back to the tiles', (tester) async {
        final picked = <String>[];
        await pumpList(tester, mode: mode, picked: picked);
        await seeAll(tester);
        await tester.tap(key('add-cc'));
        await tester.pumpAndSettle();
        expect(picked, <String>['cc']);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(l10n(tester).languagesAddQuestion), findsOneWidget);
      });
    });
  }

  group('at 1.4x text on a 360 dp phone', () {
    testWidgets('the tiles and the list hold Telugu, Hindustani and Bengali '
        'names without overflow', (tester) async {
      await pumpList(tester, views: realViews(), height: 800);
      for (final c in <String>['te', 'hi', 'bn']) {
        expect(key('tile-$c'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      // The link is below the fold of a 800 dp phone.
      await tester.scrollUntilVisible(key('languages-see-all'), 300);
      await seeAll(tester);
      await tester.scrollUntilVisible(key('languages-coming-soon'), 500);
      await tester.tap(key('languages-coming-soon'));
      await tester.pumpAndSettle();
      // The whole list, scrolled through, Coming soon open.
      for (var i = 0; i < 30; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the details dialog and the Languages page', () {
    AppState learner() => AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      )..scriptsRead = <String, bool>{'en': true},
    );

    List<SpokenLanguage> listWith(NativeVerification v) => <SpokenLanguage>[
      for (final l in pickerSpokenList)
        if (l.code == 'es')
          SpokenLanguage(
            code: l.code,
            iso639_3: l.iso639_3,
            name: l.name,
            ownName: l.ownName,
            scripts: l.scripts,
            family: l.family,
            verification: v,
          )
        else
          l,
    ];

    Future<void> pumpLanguages(
      WidgetTester tester,
      List<SpokenLanguage> list,
    ) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        LanguagesPage(spokenList: list),
        state: learner(),
      );
    }

    for (final v in NativeVerification.values) {
      testWidgets('the i dialog says "Verified by native speakers" with the '
          'state ${v.name} and its sentence', (tester) async {
        await pumpLanguages(tester, listWith(v));
        await tester.tap(key('language-es'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('i'));
        await tester.pumpAndSettle();
        final text = l10n(tester);
        final dialog = find.byType(AlertDialog);
        final row = find.descendant(
          of: dialog,
          matching: find.byType(VerificationRow),
        );
        expect(row, findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.text(text.languagesVerifiedHeading),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(verificationWord(text, v)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(verificationDetail(text, v)),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the Languages rows carry no flag, both pill rows scroll '
        'edge masked and start at 16, where the rows do', (tester) async {
      await pumpLanguages(tester, listWith(NativeVerification.full));
      expect(find.byType(VerificationFlagButton), findsNothing);
      expect(find.byType(VerificationFlag), findsNothing);
      // The skill key and the Learning, Know, Speak chips.
      expect(find.byType(FadedScrollRow), findsNWidgets(2));
      final chip = tester.getTopLeft(key('filter-learning')).dx;
      final row = tester.getTopLeft(key('language-es')).dx;
      expect(chip, 16);
      expect(chip, row);
      expect(tester.takeException(), isNull);
    });
  });
}
