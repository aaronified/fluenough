// One script gate for each script of a course written in several (wiki/
// Plan-Placement-V3.md, "One gate for each script"): each script is asked on
// its own letters and is placed on its own result, a pass in one never
// credits another, the questions stay bounded, a course written in one
// script is asked exactly what it was, and a run replays from its events.
@Timeout(Duration(minutes: 10))
library;

import 'dart:math' as math;

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/assurance_model.dart'
    show PlacementLevels;
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/script_gate.dart';
import 'package:fluenough/core/placement/v3_picker.dart'
    show kRunMaxItems, kRunMaxSeconds;
import 'package:fluenough/core/placement/v3_result.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/v3_oracle.dart';

const String _deva = 'devanagari';
const String _perso = 'perso_arabic';

const Set<PlacementSkill> _bothScripts = <PlacementSkill>{
  PlacementSkill.read,
  PlacementSkill.hear,
  PlacementSkill.write,
  PlacementSkill.script,
  PlacementSkill.secondScript,
};

void main() {
  late PlacementLanguageData oneScript;
  late PlacementLanguageData twoScripts;
  late ItemBank bank;
  setUpAll(() {
    oneScript = hindustaniWithScript();
    twoScripts = hindustaniWithTwoScripts();
    // The decks are the same in both, so one bank serves both.
    bank = ItemBank.build(oneScript);
  });

  V3Run begin(
    PlacementLanguageData data, {
    Set<PlacementSkill> skills = _bothScripts,
    int seed = 4,
    V3ScriptStart start = V3ScriptStart.ask,
  }) => V3Run(
    data: data,
    skills: skills,
    audio: true,
    recogniser: false,
    seed: seed,
    scriptStart: start,
    items: bank.items,
  );

  /// Answers the gate's questions: right for the scripts in [reads], wrong
  /// for the others. Returns the scripts asked, in order, one per question.
  List<String?> answerGates(V3Run run, Set<String> reads) {
    final asked = <String?>[];
    var guard = 0;
    while (run.inGate && guard++ < 40) {
      final g = run.question!.gateItem!;
      asked.add(run.gateScript);
      run.answerPick(
        reads.contains(run.gateScript) ? g.correct : (g.correct + 1) % 4,
      );
    }
    return asked;
  }

  /// The result of [run] at the end of its gates, with no word answers (the
  /// credit of the scripts reads the gates alone).
  V3Result gatesResult(V3Run run) => V3Result(
    skills: const <V3SkillResult>[],
    levels: run.levels,
    readout: null,
    script: run.scriptResult,
    scriptChecks: run.scriptChecks,
    items: run.answered,
    seconds: run.seconds,
    endReason: null,
  );

  int topOf(V3Run run) => run.levels.topClass;

  group('a course written in two scripts', () {
    test('a pass in the first script and a fail in the second credit only '
        'the first', () {
      final run = begin(twoScripts);
      final asked = answerGates(run, <String>{_deva});
      expect(asked, <String?>[_deva, _deva, _deva, _perso, _perso]);
      final checks = run.scriptChecks;
      final names = <String?>[for (final c in checks) c.script];
      expect(names, <String?>[_deva, _perso]);
      expect(checks[0].result.level, ScriptLevel.all);
      expect(checks[1].result.level, ScriptLevel.none);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a[PlacementSkill.script]!.placedClass, topOf(run));
      expect(a[PlacementSkill.secondScript]!.placedClass, 0);
      expect(a[PlacementSkill.secondScript]!.placedLevel, -1);
      // One script can be read: Read and Write are tested.
      expect(run.scriptResult!.readable, isTrue);
      expect(run.inGate, isFalse);
    });

    test('a fail in the first script and a pass in the second credit only '
        'the second', () {
      final run = begin(twoScripts);
      final asked = answerGates(run, <String>{_perso});
      expect(asked, <String?>[_deva, _deva, _perso, _perso, _perso]);
      final checks = run.scriptChecks;
      expect(checks[0].result.level, ScriptLevel.none);
      expect(checks[1].result.level, ScriptLevel.all);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a[PlacementSkill.script]!.placedClass, 0);
      expect(a[PlacementSkill.script]!.placedLevel, -1);
      expect(a[PlacementSkill.secondScript]!.placedClass, topOf(run));
      // The word items are written in Devanagari (the first script), which
      // this learner cannot read: Read and Write wait, as for a learner who
      // fails both.
      expect(run.scriptResult!.readable, isFalse);
    });

    test('a pass in both credits both, within the shared budget', () {
      final run = begin(twoScripts);
      final asked = answerGates(run, <String>{_deva, _perso});
      expect(asked.length, 6);
      expect(
        asked.length,
        lessThanOrEqualTo(2 * kScriptSharedMaxItems),
        reason: 'two gates share the budget of one',
      );
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a[PlacementSkill.script]!.placedClass, topOf(run));
      expect(a[PlacementSkill.secondScript]!.placedClass, topOf(run));
    });

    test('a fail in both records both as new and waits for the script', () {
      final run = begin(twoScripts);
      final asked = answerGates(run, const <String>{});
      expect(asked, <String?>[_deva, _deva, _perso, _perso]);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a[PlacementSkill.script]!.placedClass, 0);
      expect(a[PlacementSkill.secondScript]!.placedClass, 0);
      expect(run.scriptResult!.readable, isFalse);
      // The rest of the run, to its end: Read and Write wait for a script.
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        answerV3(run, 40, readsScript: false);
      }
      final result = V3Result.of(run);
      expect(result.of(PlacementSkill.read)!.status, V3Status.needsScript);
      expect(result.of(PlacementSkill.write)!.status, V3Status.needsScript);
      expect(result.scriptChecks.length, 2);
      final credit = result.assurances(scripts: 2);
      expect(credit[PlacementSkill.script]!.placedClass, 0);
      expect(credit[PlacementSkill.secondScript]!.placedClass, 0);
    });

    test('the gates of the two scripts ask each its own letters', () {
      Set<String> glyphsOf(PlacementScriptData s) => <String>{
        for (final c in s.letters) c.target,
        for (final c in s.joined) c.target,
      };
      final own = <String?, Set<String>>{
        _deva: glyphsOf(twoScripts.scripts[0]),
        _perso: glyphsOf(twoScripts.scripts[1]),
      };
      final run = begin(twoScripts, seed: 6);
      final seen = <String?>{};
      while (run.inGate) {
        final g = run.question!.gateItem!;
        final script = run.gateScript;
        expect(g.id, startsWith('script:$script:'));
        // The letter shown (or heard) is one of the script's own.
        final heard = g.kind == ScriptItemKind.soundToLetter;
        final glyph = heard ? g.options[g.correct] : g.prompt;
        expect(own[script], contains(glyph), reason: '$script: $glyph');
        seen.add(script);
        run.answerPick(g.correct);
      }
      expect(seen, <String?>{_deva, _perso});
    });

    test('the number of gate questions is bounded for every seed and every '
        'learner', () {
      for (var seed = 1; seed <= 12; seed++) {
        for (final pattern in <int>[0, 1, 2, 3, 4, 5]) {
          final run = begin(twoScripts, seed: seed);
          final rng = math.Random(seed * 31 + pattern);
          var n = 0;
          while (run.inGate) {
            final g = run.question!.gateItem!;
            // 0 wrong, 1 right, 2 alternate, 3 first script only, 4 second
            // script only, 5 at random.
            final right = switch (pattern) {
              0 => false,
              1 => true,
              2 => n.isEven,
              3 => run.gateScript == _deva,
              4 => run.gateScript == _perso,
              _ => rng.nextBool(),
            };
            run.answerPick(right ? g.correct : (g.correct + 1) % 4);
            n++;
          }
          expect(n, lessThanOrEqualTo(2 * kScriptSharedMaxItems));
          expect(n, greaterThanOrEqualTo(4));
          // A single script's gate asks five at the most: two scripts ask
          // eight at the most (four each).
          expect(n, lessThanOrEqualTo(8));
          expect(run.answered, n);
        }
      }
    });

    /// The result of the first script's gate for a learner whose answers
    /// there are [answers] (then right), while the second script's gate is
    /// answered right.
    ScriptLevel firstGateWith(List<bool> answers) {
      final run = begin(twoScripts);
      var n = 0;
      while (run.inGate) {
        final g = run.question!.gateItem!;
        final right = run.gateScript == _deva
            ? (n < answers.length ? answers[n++] : true)
            : true;
        run.answerPick(right ? g.correct : (g.correct + 1) % 4);
      }
      return run.scriptChecks[0].result.level;
    }

    test('a reader who slips once is never read as unable, in any order', () {
      for (final answers in <List<bool>>[
        <bool>[false, true, true, true],
        <bool>[true, false, true, true],
        <bool>[true, true, false, true],
      ]) {
        final level = firstGateWith(answers);
        expect(level, isNot(ScriptLevel.none), reason: '$answers');
        expect(level, ScriptLevel.partly, reason: '$answers');
      }
      // Two right and one wrong, whatever came fourth, is not "none" either.
      for (final answers in <List<bool>>[
        <bool>[false, true, true, false],
        <bool>[true, false, true, false],
        <bool>[true, true, false, false],
      ]) {
        expect(firstGateWith(answers), isNot(ScriptLevel.none));
      }
    });

    test('one right and two wrong is unable, all wrong is unable, all right '
        'is able', () {
      for (final answers in <List<bool>>[
        <bool>[true, false, false],
        <bool>[false, true, false],
        <bool>[false, false],
        <bool>[false, false, false, false],
      ]) {
        expect(firstGateWith(answers), ScriptLevel.none, reason: '$answers');
      }
      expect(firstGateWith(<bool>[true, true, true]), ScriptLevel.all);
    });

    test('a gate that ends undecided writes nothing about its script', () {
      final run = begin(twoScripts);
      const first = <bool>[true, false, true, true];
      var n = 0;
      while (run.inGate) {
        final g = run.question!.gateItem!;
        final right = run.gateScript == _deva ? first[n++] : true;
        run.answerPick(right ? g.correct : (g.correct + 1) % 4);
      }
      expect(run.scriptChecks[0].result.level, ScriptLevel.partly);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a.containsKey(PlacementSkill.script), isFalse);
      expect(run.scriptResult!.readable, isTrue);
    });

    test('a learner who reads Devanagari and learns Perso-Arabic is still '
        'tested on Read and Write when the Perso-Arabic check fails', () {
      // Devanagari is verified (not in the run); the words are written in it.
      final run = begin(
        twoScripts,
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
          PlacementSkill.hear,
          PlacementSkill.secondScript,
        },
      );
      final asked = answerGates(run, const <String>{});
      expect(asked.toSet(), <String?>{_perso});
      expect(run.scriptChecks[1].result.level, ScriptLevel.none);
      expect(run.scriptResult!.readable, isTrue);
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        answerV3(run, 40);
      }
      final result = V3Result.of(run);
      expect(result.needsScript, isFalse);
      expect(result.of(PlacementSkill.read)!.placed, isTrue);
      expect(
        result.of(PlacementSkill.write)!.status,
        isNot(V3Status.needsScript),
      );
      // The failed script is recorded as new to it.
      final a = result.assurances(scripts: 2);
      expect(a[PlacementSkill.secondScript]!.placedClass, 0);
      expect(a.containsKey(PlacementSkill.script), isFalse);
    });

    test('a learner who passes Perso-Arabic but fails Devanagari, in which '
        'the words are written, waits for the script; one who has Devanagari '
        'out of the run is trusted', () {
      final fails = begin(twoScripts);
      answerGates(fails, <String>{_perso});
      expect(fails.scriptResult!.readable, isFalse);
      final out = begin(
        twoScripts,
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
          PlacementSkill.secondScript,
        },
      );
      answerGates(out, <String>{_perso});
      expect(out.scriptResult!.readable, isTrue);
    });

    test('the run still ends within 40 items and 5 minutes with two gates', () {
      for (final reads in <Set<String>>[
        <String>{_deva, _perso},
        const <String>{},
      ]) {
        final run = begin(twoScripts, seed: 5);
        var guard = 0;
        while (!run.finished && guard++ < 200) {
          if (run.inGate) {
            final g = run.question!.gateItem!;
            final right = reads.contains(run.gateScript);
            run.answerPick(right ? g.correct : (g.correct + 1) % 4);
          } else if (run.atCheckpoint) {
            run.keepGoing();
          } else {
            answerV3(run, 20);
          }
        }
        expect(run.finished, isTrue);
        expect(run.answered, lessThanOrEqualTo(kRunMaxItems));
        // An item that starts under the limit may end a few seconds over it.
        expect(run.seconds, lessThanOrEqualTo(kRunMaxSeconds + 15));
      }
    });

    test('a script the learner has not put in play is not asked and writes '
        'nothing', () {
      // Devanagari known and verified: only Second script is in play.
      final run = begin(
        twoScripts,
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
          PlacementSkill.secondScript,
        },
      );
      final asked = answerGates(run, <String>{_perso});
      expect(asked, <String?>[_perso, _perso, _perso]);
      expect(run.scriptChecks[0].result.skipped, isTrue);
      expect(run.scriptChecks[1].result.level, ScriptLevel.all);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a.containsKey(PlacementSkill.script), isFalse);
      expect(a[PlacementSkill.secondScript]!.placedClass, topOf(run));

      // Perso-Arabic known and verified: only Script is in play, and one
      // gate has the budget of one.
      final other = begin(
        twoScripts,
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.script,
        },
      );
      final askedOther = answerGates(other, const <String>{});
      expect(askedOther, <String?>[_deva, _deva]);
      expect(other.scriptChecks[1].result.skipped, isTrue);
      final b = gatesResult(other).assurances(scripts: 2);
      expect(b[PlacementSkill.script]!.placedClass, 0);
      expect(b.containsKey(PlacementSkill.secondScript), isFalse);
    });

    test('a gate that is asked alone keeps the whole budget of one', () {
      var most = 0;
      for (var seed = 1; seed <= 12; seed++) {
        final run = begin(
          twoScripts,
          skills: const <PlacementSkill>{
            PlacementSkill.read,
            PlacementSkill.script,
          },
          seed: seed,
        );
        var n = 0;
        while (run.inGate) {
          final g = run.question!.gateItem!;
          // Right, wrong, right, wrong...: the slowest to decide.
          run.answerPick(n.isEven ? g.correct : (g.correct + 1) % 4);
          n++;
        }
        most = math.max(most, n);
      }
      expect(most, greaterThan(kScriptSharedMaxItems));
      expect(most, lessThanOrEqualTo(5));
    });

    test('"I do read it" asks no script', () {
      final run = begin(twoScripts, start: V3ScriptStart.skip);
      expect(run.inGate, isFalse);
      expect(run.question!.script, isFalse);
      expect(run.scriptResult!.skipped, isTrue);
      expect(gatesResult(run).assurances(scripts: 2), isEmpty);
    });

    test('a run is rebuilt from its events, gates and all', () {
      for (final reads in <Set<String>>[
        <String>{_deva},
        <String>{_perso},
        <String>{_deva, _perso},
        const <String>{},
      ]) {
        final run = begin(twoScripts, seed: 9);
        final ids = <String>[];
        var guard = 0;
        while (run.inGate && guard++ < 40) {
          final g = run.question!.gateItem!;
          ids.add(g.id);
          run.answerPick(
            reads.contains(run.gateScript) ? g.correct : (g.correct + 1) % 4,
          );
        }
        final again = V3Run.replay(
          data: twoScripts,
          skills: _bothScripts,
          audio: true,
          recogniser: false,
          seed: 9,
          items: bank.items,
          events: run.events,
        );
        expect(again.inGate, isFalse);
        expect(again.events, run.events);
        expect(again.answered, run.answered);
        expect(
          <ScriptLevel>[for (final c in again.scriptChecks) c.result.level],
          <ScriptLevel>[for (final c in run.scriptChecks) c.result.level],
        );
        expect(again.scriptResult!.level, run.scriptResult!.level);
        // And a replay stopped in the middle of the second gate is there.
        final partial = V3Run.replay(
          data: twoScripts,
          skills: _bothScripts,
          audio: true,
          recogniser: false,
          seed: 9,
          items: bank.items,
          events: run.events.take(4),
        );
        if (ids.length > 4) {
          expect(partial.inGate, isTrue);
          expect(partial.question!.gateItem!.id, ids[4]);
        }
      }
    });
  });

  group('a course written in one script is asked what it always was', () {
    test('the same questions and the same result as the one gate', () {
      for (var seed = 1; seed <= 8; seed++) {
        for (final reads in <bool>[true, false]) {
          final run = begin(oneScript, seed: seed);
          // The gate as it was: one gate over the letters, on the run's own
          // generator.
          final old = ScriptGate(
            V3Run.scriptLettersOf(oneScript),
            rng: math.Random(seed * 100003 + 17),
            audio: true,
          );
          var n = 0;
          while (true) {
            final want = old.next();
            if (want == null) {
              expect(run.inGate, isFalse, reason: 'seed $seed');
              break;
            }
            expect(run.inGate, isTrue, reason: 'seed $seed item $n');
            final got = run.question!.gateItem!;
            expect(got.id, want.id);
            expect(got.options, want.options);
            expect(got.correct, want.correct);
            expect(got.prompt, want.prompt);
            expect(got.kind, want.kind);
            expect(run.gateScript, _deva);
            // Right or wrong all the way, as a learner who reads or not.
            old.record(right: reads);
            run.answerPick(reads ? got.correct : (got.correct + 1) % 4);
            n++;
          }
          expect(run.scriptChecks.length, 1);
          expect(run.scriptResult!.level, old.result.level);
          expect(run.scriptResult!.items, old.result.items);
          expect(run.scriptChecks.single.result.level, old.result.level);
        }
      }
    });

    test('the credit is the one the single gate gave', () {
      for (final level in ScriptLevel.values) {
        final gate = ScriptGateResult(
          level: level,
          items: 3,
          skipped: false,
          posterior: const <ScriptLevel, double>{},
        );
        V3Result make({required bool checks}) => V3Result(
          skills: const <V3SkillResult>[],
          levels: PlacementLevels(30, maxParts: 20),
          readout: null,
          script: gate,
          scriptChecks: checks
              ? <V3ScriptCheck>[
                  V3ScriptCheck(script: _deva, index: 0, result: gate),
                ]
              : const <V3ScriptCheck>[],
          items: 3,
          seconds: 10,
          endReason: null,
        );
        final old = make(checks: false).assurances(scripts: 1);
        final now = make(checks: true).assurances(scripts: 1);
        expect(now.keys, old.keys, reason: level.name);
        for (final key in old.keys) {
          expect(now[key]!.placedClass, old[key]!.placedClass);
          expect(now[key]!.placedLevel, old[key]!.placedLevel);
          expect(now[key]!.questions, old[key]!.questions);
        }
      }
    });

    test('a result made without checks still credits every script alike', () {
      const gate = ScriptGateResult(
        level: ScriptLevel.all,
        items: 3,
        skipped: false,
        posterior: const <ScriptLevel, double>{},
      );
      final a = V3Result(
        skills: const <V3SkillResult>[],
        levels: PlacementLevels(30, maxParts: 20),
        readout: null,
        script: gate,
        items: 3,
        seconds: 10,
        endReason: null,
      ).assurances(scripts: 2);
      expect(a.keys, <PlacementSkill>{
        PlacementSkill.script,
        PlacementSkill.secondScript,
      });
    });
  });

  group('the other courses with more than one script', () {
    PlacementLanguageData withScripts(List<PlacementScriptData> scripts) =>
        PlacementLanguageData(
          language: 'hi',
          decks: oneScript.decks,
          sounds: oneScript.sounds,
          levelMarkDecks: oneScript.levelMarkDecks,
          scripts: scripts,
        );

    PlacementScriptData few(String script) => PlacementScriptData(
      script: script,
      letters: <Card>[
        for (final (i, c) in oneScript.scripts.first.letters.take(3).indexed)
          Card(
            id: '$script-$i',
            deckId: script,
            target: c.target,
            native: '',
            reading: c.reading,
          ),
      ],
    );

    test('Japanese: kana is asked, and kanji with too few letters is not', () {
      final data = withScripts(<PlacementScriptData>[
        oneScript.scripts.first,
        few('han'),
      ]);
      final run = begin(data);
      final asked = answerGates(run, <String>{_deva});
      expect(asked.toSet(), <String?>{_deva});
      expect(run.scriptChecks[1].result.skipped, isTrue);
      final a = gatesResult(run).assurances(scripts: 2);
      expect(a.containsKey(PlacementSkill.secondScript), isFalse);
      // The one gate asked has the budget of one.
      expect(run.scriptChecks[0].result.items, lessThanOrEqualTo(5));
    });

    test('Chinese: two scripts with no letters to ask are not gated', () {
      final data = withScripts(<PlacementScriptData>[
        few('han_simplified'),
        few('han_traditional'),
      ]);
      final run = begin(data);
      expect(run.inGate, isFalse);
      expect(run.scriptResult!.skipped, isTrue);
      expect(gatesResult(run).assurances(scripts: 2), isEmpty);
    });

    test('Toki Pona: sitelen pona is the one gate it was', () {
      final data = withScripts(<PlacementScriptData>[
        PlacementScriptData(
          script: 'sitelen_pona',
          letters: oneScript.scripts.first.letters,
          joined: oneScript.scripts.first.joined,
        ),
      ]);
      const only = <PlacementSkill>{PlacementSkill.read};
      final run = begin(data, skills: only);
      expect(run.inGate, isTrue);
      final asked = answerGates(run, <String>{'sitelen_pona'});
      expect(asked.toSet(), <String?>{'sitelen_pona'});
      expect(run.scriptChecks.length, 1);
      final a = gatesResult(run).assurances(scripts: 1);
      expect(a[PlacementSkill.script]!.placedClass, topOf(run));
      expect(a.containsKey(PlacementSkill.secondScript), isFalse);
    });
  });
}
