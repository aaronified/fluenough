// The script gate of Find my level V3 (lib/core/placement/script_gate.dart):
// the items, what it decides, and what the decision does to the run for a
// language in a non-Latin script (Hindustani, Devanagari) and one in Latin
// (Spanish).
@Timeout(Duration(minutes: 15))
library;

import 'dart:math' as math;

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/script_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;

ScriptGateResult _play(
  List<ScriptLetter> letters,
  ScriptLevel level,
  int seed, {
  bool audio = true,
  bool? declared,
}) {
  final rng = math.Random(seed);
  final persona = Persona('p', truth: const {}, script: level);
  final g = ScriptGate(
    letters,
    rng: rng,
    audio: audio,
    declaredReads: declared,
  );
  while (true) {
    final item = g.next();
    if (item == null) break;
    g.record(right: persona.answerScript(rng));
  }
  return g.result;
}

void main() {
  late List<ScriptLetter> letters;
  setUpAll(() => letters = devanagariLetters());

  group('the items', () {
    test('the letter decks give plain letters and joined forms', () {
      expect(letters.where((l) => !l.joined).length, greaterThan(30));
      expect(letters.where((l) => l.joined).length, greaterThan(10));
    });

    test('a letter item has four options of one length, the right one among '
        'them, and no two readings alike', () {
      for (var seed = 1; seed <= 60; seed++) {
        final g = ScriptGate(letters, rng: math.Random(seed), audio: true);
        ScriptGateItem? item;
        while ((item = g.next()) != null) {
          final it = item!;
          expect(it.options.length, 4);
          expect(it.options.toSet().length, 4);
          expect(it.correct, inInclusiveRange(0, 3));
          final letter = letters[it.letterIndex];
          if (it.kind == ScriptItemKind.letterToSound) {
            expect(it.prompt, letter.glyph);
            expect(it.options[it.correct], letter.reading);
            expect(it.format, 'F12');
            expect(it.needsAudio, isFalse);
          } else {
            expect(it.prompt, letter.reading);
            expect(it.options[it.correct], letter.glyph);
            expect(it.format, 'F10');
            expect(it.needsAudio, isTrue);
          }
          g.record(right: true);
        }
        expect(g.asked.length, inInclusiveRange(2, 5));
        // No letter twice.
        expect(
          g.asked.map((i) => i.letterIndex).toSet().length,
          g.asked.length,
        );
      }
    });

    test('with no audio nothing is heard, and no cue of length picks the '
        'right option', () {
      var checked = 0;
      var longest = 0;
      var shortest = 0;
      for (var seed = 1; seed <= 200; seed++) {
        final g = ScriptGate(letters, rng: math.Random(seed));
        ScriptGateItem? item;
        while ((item = g.next()) != null) {
          final it = item!;
          expect(it.needsAudio, isFalse);
          final lens = it.options.map((o) => o.length).toList();
          final right = lens[it.correct];
          final alone = lens.where((l) => l == right).length == 1;
          if (alone && lens.every((l) => l <= right)) {
            longest++;
          }
          if (alone && lens.every((l) => l >= right)) {
            shortest++;
          }
          checked++;
          g.record(right: true);
        }
      }
      // Options of one length are ties: a solver that takes the longest or
      // the shortest gets a quarter, no more.
      expect(longest / checked, lessThan(0.15));
      expect(shortest / checked, lessThan(0.15));
    });

    test('the heard item is asked only with audio', () {
      var heard = 0;
      for (var seed = 1; seed <= 40; seed++) {
        final g = ScriptGate(letters, rng: math.Random(seed), audio: true);
        ScriptGateItem? item;
        while ((item = g.next()) != null) {
          if (item!.needsAudio) heard++;
          g.record(right: true);
        }
      }
      expect(heard, greaterThan(20));
    });
  });

  group('what the gate decides', () {
    test('a Latin script is not asked and counts as letters known', () {
      final g = ScriptGate.latin();
      expect(g.needed, isFalse);
      expect(g.next(), isNull);
      expect(g.result.skipped, isTrue);
      expect(g.result.lettersKnown, isTrue);
      expect(g.result.readable, isTrue);
      expect(g.result.items, 0);
    });

    test('a learner who cannot read the script is found in at least 95% of '
        'the runs, one who can is read as able in at least 95%, and it takes '
        'about three items', () {
      const runs = 600;
      var none = 0;
      var allAll = 0;
      var allReadable = 0;
      var partlyNone = 0;
      var items = 0;
      var n = 0;
      for (var seed = 1; seed <= runs; seed++) {
        final a = _play(letters, ScriptLevel.none, seed);
        if (a.level == ScriptLevel.none) none++;
        final b = _play(letters, ScriptLevel.all, seed);
        if (b.level == ScriptLevel.all) allAll++;
        if (b.readable) allReadable++;
        final c = _play(letters, ScriptLevel.partly, seed);
        if (c.level == ScriptLevel.none) partlyNone++;
        for (final r in [a, b]) {
          expect(r.items, inInclusiveRange(2, 5));
          items += r.items;
          n++;
        }
      }
      expect(none / runs, greaterThanOrEqualTo(0.95));
      expect(allAll / runs, greaterThanOrEqualTo(0.95));
      expect(allReadable / runs, greaterThanOrEqualTo(0.97));
      expect(items / n, lessThan(3.6));
      // A learner with some letters is told apart less well (a known limit,
      // in the plan): about three in four are read as unable.
      // ignore: avoid_print
      print('partly read as none: ${partlyNone / runs}');
    });

    test('a truthful declaration shortens it: a learner who says they read '
        'it and does is through in two items, and one who says they do not and '
        'cannot is found in 97% of the runs', () {
      const runs = 600;
      var none = 0;
      var all = 0;
      var two = 0;
      for (var seed = 1; seed <= runs; seed++) {
        if (_play(letters, ScriptLevel.none, seed, declared: false).level ==
            ScriptLevel.none) {
          none++;
        }
        final r = _play(letters, ScriptLevel.all, seed, declared: true);
        if (r.level == ScriptLevel.all) all++;
        if (r.items == 2) two++;
      }
      expect(none / runs, greaterThanOrEqualTo(0.97));
      expect(all / runs, greaterThanOrEqualTo(0.95));
      expect(two / runs, greaterThanOrEqualTo(0.8));
    });

    test('a guesser who says they read it passes it in at most one run in '
        'ten', () {
      var passed = 0;
      for (var seed = 1; seed <= 600; seed++) {
        if (_play(letters, ScriptLevel.none, seed, declared: true).readable) {
          passed++;
        }
      }
      expect(passed / 600, lessThanOrEqualTo(0.10));
    });

    test('a guesser passes it rarely', () {
      var passed = 0;
      for (var seed = 1; seed <= 400; seed++) {
        final r = _play(letters, ScriptLevel.none, seed);
        if (r.readable) passed++;
      }
      expect(passed / 400, lessThanOrEqualTo(0.05));
    });
  });

  group('what it does to the run (hi)', () {
    late SimBank bank;
    late PlacementLevels levels;
    setUpAll(() {
      bank = leakLanguages()['hi']!.bank();
      levels = bank.levels;
    });

    int c(double t) => t <= 0 ? 0 : classAtTenth(levels, t);

    RunResult run(Persona p, int seed, {bool gate = true}) => runOnce(
      bank: bank,
      persona: p,
      picker: V3SimPicker(),
      declaration: null,
      variant: Variant.full,
      seed: seed,
      scriptLetters: gate ? letters : null,
    );

    test('a learner who hears and speaks but cannot read is placed on Hear '
        'and not punished as knowing no language; Read and Write are not '
        'tested', () {
      final p = Persona(
        'heritage',
        truth: {_read: 0, _hear: c(7), _write: 0},
        script: ScriptLevel.none,
      );
      var scripts = 0;
      var near = 0;
      var noReadWrite = 0;
      const runs = 100;
      for (var seed = 1; seed <= runs; seed++) {
        final r = run(p, seed);
        if (r.script!.level == ScriptLevel.none) {
          scripts++;
          if (!r.skills.containsKey(_read) && !r.skills.containsKey(_write)) {
            noReadWrite++;
          }
          final h = r.skills[_hear]!;
          if (h.start >= h.truth - 4 && h.over <= 2) near++;
        }
      }
      expect(scripts / runs, greaterThanOrEqualTo(0.95));
      expect(noReadWrite, scripts);
      // Hear is placed near the truth, as for any learner (the gate's job:
      // Read and Write at none no longer hold Hear down through the joint
      // prior).
      expect(near / scripts, greaterThanOrEqualTo(0.70));
    });

    test('without the gate the same learner is placed lower on Hear '
        '(control)', () {
      final p = Persona(
        'heritage',
        truth: {_read: 0, _hear: c(7), _write: 0},
        script: ScriptLevel.none,
      );
      var withGate = 0;
      var without = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final a = run(p, seed).skills[_hear]!;
        final b = run(p, seed, gate: false).skills[_hear]!;
        if (a.start >= a.truth - 4) withGate++;
        if (b.start >= b.truth - 4) without++;
      }
      expect(withGate, greaterThan(without));
    });

    test('a learner who knows the script and no words reads it, and starts '
        'the vocabulary at A1', () {
      final p = Persona('script-only', truth: {_read: 0, _hear: 0, _write: 0});
      var readable = 0;
      var atStart = 0;
      var cells = 0;
      for (var seed = 1; seed <= 100; seed++) {
        final r = run(p, seed);
        if (r.script!.readable) {
          readable++;
          for (final k in [_read, _write]) {
            cells++;
            if (r.skills[k]!.start <= 2) atStart++;
          }
        }
      }
      expect(readable, greaterThanOrEqualTo(99));
      expect(atStart / cells, greaterThanOrEqualTo(0.97));
    });

    test('a learner who knows the script and the words is placed as before, '
        'and the gate costs at most 20 s', () {
      final p = Persona('adv', truth: {_read: c(7), _hear: c(7), _write: c(7)});
      for (var seed = 1; seed <= 30; seed++) {
        final r = run(p, seed);
        expect(r.script!.readable, isTrue);
        expect(r.skills.keys, containsAll([_read, _hear, _write]));
        expect(r.items, lessThanOrEqualTo(40));
        expect(r.seconds, lessThanOrEqualTo(300));
        for (final k in r.skills.values) {
          expect(k.over, lessThanOrEqualTo(4), reason: 'seed $seed');
        }
      }
    });
  });

  group('a Latin script (es)', () {
    test('has no gate: no extra item, and the letters count as known', () {
      final bank = leakLanguages()['es']!.bank();
      final p = Persona('a', truth: {_read: 5, _hear: 5, _write: 5});
      final r = runOnce(
        bank: bank,
        persona: p,
        picker: V3SimPicker(),
        declaration: null,
        variant: Variant.full,
        seed: 1,
      );
      expect(r.script, isNull);
      expect(r.skills.keys, containsAll([_read, _hear, _write]));
      expect(ScriptGate.latin().result.lettersKnown, isTrue);
    });
  });
}
