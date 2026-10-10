import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/language_catalog.dart';

/// The language picker's catalog (#211, `docs/plans/language-picker.md`):
/// completeness toward B1 from a path's plan, the Alpha and Beta stages,
/// search, and the picker's order. No Flutter: these run in milliseconds.

B1Unit written(int has, {int? words, Milestone? milestone, List<String>? g}) =>
    B1Unit(
      has: has,
      words: words,
      milestone: milestone,
      grammar: g ?? const <String>[],
    );

B1Unit planned(int words, {Milestone? milestone, List<String>? g}) => B1Unit(
  planned: true,
  words: words,
  milestone: milestone,
  grammar: g ?? const <String>[],
);

CatalogLanguage language(
  String code,
  String name, {
  String? own,
  List<String> natives = const <String>['en'],
}) => CatalogLanguage(
  code: code,
  name: name,
  ownName: own,
  natives: <CatalogNative>[
    for (final n in natives)
      (code: n, name: n, progress: B1Progress.of(const <B1Unit>[])),
  ],
);

void main() {
  group('completeness toward B1', () {
    test('is the words written over the words planned, up to B1', () {
      final p = B1Progress.of(<B1Unit>[
        written(30, words: 40, milestone: Milestone.a1),
        written(20, words: 20, milestone: Milestone.a2),
        planned(40, milestone: Milestone.b1),
        // After B1: not counted.
        written(500, words: 500),
      ]);
      expect(p.hasPlan, isTrue);
      expect(p.plannedWords, 100);
      expect(p.writtenWords, 50);
      expect(p.percent, 50);
    });

    test('caps a unit over its plan at its plan', () {
      final p = B1Progress.of(<B1Unit>[
        written(90, words: 40, milestone: Milestone.a1),
        planned(60, milestone: Milestone.b1),
      ]);
      expect(p.writtenWords, 40);
      expect(p.percent, 40);
    });

    test('counts a unit not written as 0, and one with no deck in the '
        "course's native language as not written", () {
      final p = B1Progress.of(<B1Unit>[
        written(10, words: 10, milestone: Milestone.a1),
        const B1Unit(words: 30),
        planned(60, milestone: Milestone.b1),
      ]);
      expect(p.writtenWords, 10);
      expect(p.percent, 10);
    });

    test('rounds down, so 100% means all of it', () {
      final p = B1Progress.of(<B1Unit>[
        written(199, words: 200, milestone: Milestone.b1),
      ]);
      expect(p.percent, 99);
    });

    test('without a B1 mark, has no plan and gives the course size', () {
      final p = B1Progress.of(<B1Unit>[written(400), written(240)]);
      expect(p.hasPlan, isFalse);
      expect(p.courseWords, 640);
      expect(p.percent, 0);
    });

    test('counts grammar topics planned up to B1, and those taught', () {
      final p = B1Progress.of(<B1Unit>[
        written(5, words: 5, g: <String>['be', 'past']),
        planned(5, g: <String>['future']),
        written(0, words: 0, milestone: Milestone.b1, g: <String>['be']),
        written(0, g: <String>['later']),
      ]);
      expect(p.grammarTopics, 3);
      expect(p.grammarWritten, 2);
    });

    test("a learner's share never passes the course's", () {
      final p = B1Progress.of(<B1Unit>[
        written(30, words: 40, milestone: Milestone.a1),
        planned(60, milestone: Milestone.b1),
      ]);
      // Learned more than the unit plans, or has: capped at what it has.
      expect(p.learnedShare(<int>[50, 0]), closeTo(0.3, 1e-9));
      expect(p.learnedShare(<int>[10, 0]), closeTo(0.1, 1e-9));
      expect(p.learnedShare(const <int>[]), 0);
    });
  });

  group('stage', () {
    test('Alpha until every A1 unit is written', () {
      final p = B1Progress.of(<B1Unit>[
        written(10, words: 10),
        planned(10, milestone: Milestone.a1),
        planned(10, milestone: Milestone.b1),
      ]);
      expect(p.stage, CourseStage.alpha);
    });

    test('Beta from then until every B1 unit is written', () {
      final p = B1Progress.of(<B1Unit>[
        written(10, words: 10, milestone: Milestone.a1),
        planned(10, milestone: Milestone.a2),
        planned(10, milestone: Milestone.b1),
      ]);
      expect(p.stage, CourseStage.beta);
    });

    test('no tag once every B1 unit is written, however small', () {
      final p = B1Progress.of(<B1Unit>[
        written(1, words: 10, milestone: Milestone.a1),
        written(1, words: 10, milestone: Milestone.a2),
        written(1, words: 10, milestone: Milestone.b1),
        planned(10),
      ]);
      expect(p.stage, CourseStage.complete);
    });

    test('a course with no B1 plan is Alpha', () {
      expect(B1Progress.of(<B1Unit>[written(600)]).stage, CourseStage.alpha);
    });
  });

  group('search', () {
    final hindi = language('hi', 'Hindi', own: 'हिन्दी');
    final marathi = language('mr', 'Marathi', own: 'मराठी');
    final spanish = language('es', 'Spanish', own: 'Español');
    final telugu = language('te', 'Telugu', own: 'తెలుగు');
    final all = <CatalogLanguage>[hindi, marathi, spanish, telugu];
    List<String> codes(String q) => <String>[
      for (final l in all)
        if (LanguageSearch.matches(l, q)) l.code,
    ];

    test('matches English names, in any case', () {
      expect(codes('hi'), <String>['hi', 'mr']);
      expect(codes('TELU'), <String>['te']);
    });

    test('matches own names, accents ignored', () {
      expect(codes('espanol'), <String>['es']);
      expect(codes('Español'), <String>['es']);
      expect(codes('తెలు'), <String>['te']);
    });

    test('matches codes', () => expect(codes('es'), <String>['es']));

    test('finds nothing for a language with no decks', () {
      expect(codes('tamil'), isEmpty);
    });

    test('an empty search matches all', () {
      expect(codes('  '), hasLength(4));
    });

    test('marks the match in the name as written', () {
      expect(LanguageSearch.find('Marathi', 'hi'), (start: 5, end: 7));
      expect(LanguageSearch.find('Español', 'espanol'), (start: 0, end: 7));
      expect(LanguageSearch.find('Español', 'NOL'), (start: 4, end: 7));
      expect(LanguageSearch.find('Hindi', 'x'), isNull);
    });
  });

  group('order', () {
    test('taught from a language the learner speaks first, then A to Z', () {
      final ordered = pickerOrder(
        <CatalogLanguage>[
          language('kn', 'Kannada'),
          language('te', 'Telugu', natives: const <String>['bn', 'hi', 'en']),
          language('as', 'Assamese'),
        ],
        const <String>['bn', 'hi'],
      );
      expect(ordered.map((l) => l.code), <String>['te', 'as', 'kn']);
    });

    test("natives: the learner's own first, in their order", () {
      final te = language(
        'te',
        'Telugu',
        natives: const <String>['en', 'hi', 'bn'],
      );
      expect(
        te.nativesInOrder(const <String>['bn', 'hi']).map((n) => n.code),
        <String>['bn', 'hi', 'en'],
      );
      expect(te.nativeFor(const <String>['hi', 'bn'])!.code, 'hi');
      expect(te.nativeFor(const <String>['ta'])!.code, 'en');
      expect(te.taughtFromSpoken(const <String>['ta']), isFalse);
    });
  });

  group('from the index', () {
    test('reads each native language\'s units', () {
      final index = DeckIndex.parse('''
{"version": 1, "languages": [{
  "code": "te", "name": "Telugu", "icon": "తె", "script": "telugu",
  "script_decks": true,
  "natives": [{"code": "en", "name": "English"}, {"code": "bn", "name": "Bengali"}],
  "units": [
    {"decks": ["te-a"], "has": {"en": 30, "bn": 10}, "words": 40, "grammar": ["be"], "milestone": "A1"},
    {"decks": [], "planned": true, "words": 60, "grammar": ["past"], "milestone": "B1"}
  ],
  "files": []
}]}''');
      final te = CatalogLanguage.fromIndex(
        index.language('te')!,
        ownNames: const <String, String>{'te': 'తెలుగు'},
      );
      expect(te.ownName, 'తెలుగు');
      expect(te.scriptDecks, isTrue);
      final en = te.progressFor(const <String>['en'])!;
      expect(en.percent, 30);
      expect(en.grammarTopics, 2);
      expect(en.grammarWritten, 1);
      expect(en.stage, CourseStage.beta);
      expect(te.progressFor(const <String>['bn'])!.percent, 10);
    });

    test('the committed index gives every language a figure', () {
      final index = DeckIndex.parse(
        File('decks/index.json').readAsStringSync(),
      );
      for (final entry in index.languages) {
        final language = CatalogLanguage.fromIndex(entry);
        final progress = language.progressFor(const <String>['en'])!;
        expect(
          progress.hasPlan ? progress.plannedWords : progress.courseWords,
          greaterThan(0),
          reason: entry.code,
        );
      }
    });
  });
}
