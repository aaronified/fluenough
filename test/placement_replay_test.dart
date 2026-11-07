// The replay of role-played personas through the real placement engine in
// bank mode (wiki/Plan-Placement-V2.md, section 13, points 12 and 13): each
// question is answered from a persona's answer table (test/fixtures/
// placement/answers), a draw chosen per question by the run's seed. The
// beginner and the amateurs must never be credited above their true position
// in more than 1% of runs, at the 25-question checkpoint and at the end;
// natives and experts are reported. lib/core only.
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/question_bank.dart';
import 'package:fluenough/core/placement/replay.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fixtures = 'test/fixtures/placement';

/// The runs per persona: 100 seeds, each with its draw chosen per question.
const int _runs = 100;

/// The true last known deck of each persona (-1: knows nothing in the path),
/// from the plan's definition: the deck of the last path unit in which the
/// persona's known words are a prefix of what it knows.
const Map<String, Map<String, int>> _truth = <String, Map<String, int>>{
  'es': <String, int>{
    'beginner': -1,
    'amateur-lexodle': 0,
    'amateur-lexodle-nocognate': 0,
    'amateur-wiktionary': 17,
  },
  'hi': <String, int>{
    'beginner': -1,
    'amateur-wordfreq': 29,
    'amateur-wordfreq-nocognate': 29,
    'amateur-wiktionary': 0,
  },
};

Object? _json(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  for (final language in <String>['es', 'hi']) {
    group('$language personas', () {
      late QuestionBank bank;
      late int deckCount;
      late List<int> marks;
      late List<int> grammar;
      final personas = <String, List<Map<String, Object?>>>{};

      setUpAll(() {
        final pub =
            _json('$_fixtures/banks/$language-bank.json')!
                as Map<String, Object?>;
        final key =
            _json('$_fixtures/banks/$language-bank-key.json')!
                as Map<String, Object?>;
        bank = bankFromJson(
          pub['questions']! as List<Object?>,
          key['questions']! as Map<String, Object?>,
          language: language,
        );
        deckCount = key['deckCount']! as int;
        marks = <int>[for (final m in key['levelMarkDecks']! as List) m as int];
        grammar = <int>[for (final m in key['grammarDecks']! as List) m as int];
        final pattern = RegExp('^$language-(.+)-draw[0-9]+\\.json\$');
        for (final f in Directory(
          '$_fixtures/answers/v3',
        ).listSync().whereType<File>()) {
          final m = pattern.firstMatch(f.uri.pathSegments.last);
          if (m == null) continue;
          (personas[m[1]!] ??= <Map<String, Object?>>[]).add(
            _json(f.path)! as Map<String, Object?>,
          );
        }
      });

      List<ReplayOutcome> runAll(String persona, PlacementDeclaration d) => [
        for (var seed = 1; seed <= _runs; seed++)
          replayRun(
            persona: persona,
            bank: bank,
            deckCount: deckCount,
            levelMarkDecks: marks,
            grammarDecks: grammar,
            draws: personas[persona]!,
            declaration: d,
            seed: seed,
          ),
      ];

      for (final MapEntry(key: persona, value: truth)
          in _truth[language]!.entries) {
        test('$persona is never credited above deck $truth', () {
          expect(personas[persona], isNotEmpty, reason: 'answer files');
          final outcomes = runAll(persona, PlacementDeclaration.amateur);
          int over(
            Map<PlacementSkill, SkillOutcome> Function(ReplayOutcome) at,
          ) {
            var n = 0;
            for (final o in outcomes) {
              for (final found in at(o).values) {
                // The unit shown is the deck index + 1; "from the start" is 0.
                if (found.unit - 1 > truth) n++;
              }
            }
            return n;
          }

          final total = outcomes.length * 3;
          final at25 = over((o) => o.atCheckpoint);
          final atEnd = over((o) => o.atEnd);
          // 99%: at most 1% of the skill results over.
          expect(at25, lessThanOrEqualTo(total ~/ 100), reason: 'at 25');
          expect(atEnd, lessThanOrEqualTo(total ~/ 100), reason: 'at the end');
        });
      }

      for (final (persona, need) in <(String, double)>[
        ('expert', 0.95),
        ('native', 0.99),
      ]) {
        test('$persona reaches the top class in $need of runs per skill', () {
          expect(personas[persona], isNotEmpty, reason: 'answer files');
          final outcomes = runAll(persona, PlacementDeclaration.expert);
          final top = <PlacementSkill, int>{};
          for (final o in outcomes) {
            for (final e in o.atEnd.entries) {
              // The unit shown is the deck index + 1: the top class is the
              // last deck.
              if (e.value.unit == deckCount) {
                top[e.key] = (top[e.key] ?? 0) + 1;
              }
            }
          }
          // ignore: avoid_print
          print('$language $persona reached the top: $top of $_runs');
          for (final skill in <PlacementSkill>[
            PlacementSkill.read,
            PlacementSkill.hear,
            PlacementSkill.write,
          ]) {
            expect(
              (top[skill] ?? 0) / outcomes.length,
              greaterThanOrEqualTo(need),
              reason: skill.name,
            );
          }
        });
      }
    });
  }
}
