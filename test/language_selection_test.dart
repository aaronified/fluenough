// Add a language with Popular, one flat list, search and the two markers
// (the approved mockup `docs/mockups/language-level-verification.html`),
// the verification row of the details dialog, and the Languages page's one
// pill arrangement. What a learner sees, at 1.4x text in light and dark.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/languages/add_language_page.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/features/languages/verification_mark.dart';
import 'package:fluenough/features/placement/course_line.dart';
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

/// Alphabetical: Alpha, Bravo, Charlie, Delta, IPA, Zulu. Popular: Bravo,
/// Delta, Zulu, so that the order of the two sections differs.
final List<SpokenLanguage> sample = <SpokenLanguage>[
  lang('zz', 'Zulu', popular: true, verification: NativeVerification.full),
  lang('aa', 'Alpha'),
  lang('dd', 'Delta', popular: true, aliases: <String>['Dalmatian']),
  lang('bb', 'Bravo', popular: true, verification: NativeVerification.some),
  lang('cc', 'Charlie', verification: NativeVerification.full),
  lang('ipa', 'IPA'),
];

AppLocalizations l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

Future<void> pumpAdd(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  List<SpokenLanguage>? list,
}) async {
  usePhone(tester, textScale: 1.4);
  // Tall, so that the whole lazy list is built.
  tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
  await pumpScreen(
    tester,
    AddLanguagePage(spokenList: list ?? sample),
    themeMode: mode,
  );
}

Finder key(String k) => find.byKey(ValueKey<String>(k));

double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(key('languages-add-search'), text);
  await tester.pumpAndSettle();
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

    test('Popular is the owner\'s eight, and no language is verified yet', () {
      final all = parseSpokenLanguages(
        File('assets/languages.yaml').readAsStringSync(),
      );
      final popular = all.where((l) => l.popular).map((l) => l.name).toList()
        ..sort();
      expect(popular, <String>[
        'Bengali',
        'French',
        'Hindustani',
        'Japanese',
        'Kannada',
        'Mandarin Chinese',
        'Marathi',
        'Spanish',
      ]);
      expect(
        all.every((l) => l.verification == NativeVerification.none),
        isTrue,
      );
    });
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('Add a language in ${mode.name}', () {
      testWidgets('Popular comes first, then All languages as one flat '
          'alphabetical list that holds the popular ones again', (
        tester,
      ) async {
        await pumpAdd(tester, mode: mode);
        final text = l10n(tester);
        final popular = top(tester, find.text(text.languagesPopular));
        final all = top(tester, find.text(text.languagesAllLanguages));
        expect(top(tester, key('languages-add-search')), lessThan(popular));
        // Popular, alphabetical, under its heading and above All languages.
        final popularRows = <double>[
          for (final c in <String>['bb', 'dd', 'zz'])
            top(tester, key('add-popular-$c')),
        ];
        expect(popularRows, orderedEquals(<double>[...popularRows]..sort()));
        expect(popularRows.first, greaterThan(popular));
        expect(popularRows.last, lessThan(all));
        expect(key('add-popular-aa'), findsNothing);
        // The full list: every language once, by name, no family headings.
        final order = <double>[
          for (final c in <String>['aa', 'bb', 'cc', 'dd', 'ipa', 'zz'])
            top(tester, key('add-$c')),
        ];
        expect(order.first, greaterThan(all));
        expect(order, orderedEquals(<double>[...order]..sort()));
        expect(find.text(text.knownFamily('germanic')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('each row carries the A1 A2 B1 line and the verification '
          'flag as icon and word; a notation has no flag', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpAdd(tester, mode: mode);
        final text = l10n(tester);
        for (final (code, word) in <(String, String)>[
          ('add-popular-bb', text.languagesVerifiedSome),
          ('add-popular-zz', text.languagesVerifiedFull),
          ('add-aa', text.languagesVerifiedNone),
        ]) {
          final row = key(code);
          expect(
            find.descendant(of: row, matching: find.byType(CourseLine)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.textContaining(word)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.byType(VerificationFlag)),
            findsOneWidget,
          );
        }
        expect(
          find.bySemanticsLabel(
            text.languagesVerifiedLabel(
              text.languagesVerifiedSome.toLowerCase(),
            ),
          ),
          findsWidgets,
        );
        // No decks: the line is empty and says so.
        expect(find.bySemanticsLabel(text.languagesNoDecksLabel), findsWidgets);
        expect(
          find.descendant(
            of: key('add-ipa'),
            matching: find.byType(VerificationMark),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: key('add-ipa'),
            matching: find.byType(CourseLine),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('the key is one scrolling row, edge masked, starting at '
          '16', (tester) async {
        await pumpAdd(tester, mode: mode);
        final text = l10n(tester);
        final keyRow = find.byType(VerificationKey);
        expect(
          find.descendant(of: keyRow, matching: find.byType(ShaderMask)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: keyRow,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
          ),
          findsOneWidget,
        );
        expect(tester.getTopLeft(find.text(text.languagesVerifiedKey)).dx, 16);
        // The three states, each with its word.
        for (final w in <String>[
          text.languagesVerifiedNone,
          text.languagesVerifiedSome,
          text.languagesVerifiedFull,
        ]) {
          expect(
            find.descendant(of: keyRow, matching: find.text(w)),
            findsOneWidget,
          );
        }
      });

      testWidgets('a search collapses the sections: Popular matches first, '
          'no headings; names, own names and aliases match', (tester) async {
        await pumpAdd(tester, mode: mode);
        final text = l10n(tester);
        await search(tester, 'l');
        expect(find.text(text.languagesPopular), findsNothing);
        expect(find.text(text.languagesAllLanguages), findsNothing);
        // Delta and Zulu are popular, Alpha and Charlie are not.
        final order = <double>[
          for (final c in <String>['dd', 'zz', 'aa', 'cc'])
            top(tester, key('add-$c')),
        ];
        expect(order, orderedEquals(<double>[...order]..sort()));
        expect(key('add-bb'), findsNothing);
        expect(key('add-popular-dd'), findsNothing);
        await search(tester, 'dalm');
        expect(key('add-dd'), findsOneWidget);
        expect(key('add-zz'), findsNothing);
        await search(tester, 'qqq');
        expect(find.text(text.languagesAddNoMatch('qqq')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

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
      expect(find.byType(VerificationMark), findsNothing);
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
