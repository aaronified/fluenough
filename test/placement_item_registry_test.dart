// The item registry and generators of Find my level V3 (wiki/Plan-Placement-V3.md,
// the amendments of its adversarial review): the format inventory, the cognate
// score, the generators and their fixes, the admission audit, and the gates
// the registry's arrival enables (anagram solver, matcher, family replay,
// admission audit). Built from the real decks of Spanish and Hindi; nothing
// here is per-language content.
@Timeout(Duration(minutes: 15))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/placement/cognate_score.dart';
import 'package:fluenough/core/placement/item_audit.dart';
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/item_generators.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/item_solvers.dart';
import 'package:fluenough/core/placement/placement_questions.dart'
    show PlacementSkill;
import 'package:fluenough/core/placement/unit_model.dart';
import 'package:fluenough/core/placement/v3_grading.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/scheduling/look_alike.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

PlacementCourse _course(String language) {
  final files = <String, String>{};
  for (final e in Directory('decks/$language').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.yaml')) {
      files[e.path.substring('decks/'.length)] = e.readAsStringSync();
    }
  }
  return loadPlacementCourse(files, language: language);
}

void main() {
  test('a course with no part of speech makes no sentence fill-in', () {
    final files = <String, String>{};
    for (final e in Directory('decks/es').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.yaml')) {
        files[e.path.substring('decks/'.length)] = e
            .readAsStringSync()
            .replaceAll(
              RegExp(r'pos: "(noun|verb|adj|adv|pronoun)"'),
              'pos: "other"',
            );
      }
    }
    final cx = ItemBank.build(loadPlacementCourse(files, language: 'es').data)
        .context;
    expect(ItemGenerators(cx).sentenceFill(), isEmpty);
  });

  group('the inventory', () {
    test('lists F1 to F20 with what each needs and leaks', () {
      for (var n = 1; n <= 20; n++) {
        if (n == 16) continue; // F16 (dictation) was removed (#1105)
        final f = formatInfo('F$n');
        expect(f.skills, isNotEmpty, reason: f.code);
        expect(f.slip, inInclusiveRange(0, 0.2), reason: f.code);
        expect(f.guess, inInclusiveRange(0, 1), reason: f.code);
        expect(f.seconds, greaterThan(0), reason: f.code);
        if (!f.generated) {
          expect(f.notGeneratedBecause, isNotEmpty, reason: f.code);
        }
      }
      // Audio and a microphone are what the plan says.
      for (final code in <String>['F13', 'F14', 'F15', 'F17']) {
        expect(formatInfo(code).needsAudio, isTrue, reason: code);
        expect(formatInfo(code).needsMic, isFalse, reason: code);
      }
      for (final code in <String>['F18', 'F19', 'F20']) {
        expect(formatInfo(code).needsMic, isTrue, reason: code);
      }
      for (final code in <String>['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7']) {
        expect(formatInfo(code).needsAudio, isFalse, reason: code);
      }
    });

    test('says which formats the registry does not generate, and why', () {
      final missing = <String>[
        for (final f in kFormatInventory)
          if (!f.generated) f.code,
      ];
      expect(
        missing,
        containsAll(<String>['F10', 'F11', 'F12', 'F15', 'F19', 'F20']),
      );
    });

    test(
      'the admission bound is the guess plus 0.07, 0.32 for four options',
      () {
        expect(formatInfo('F2').admissionBound, 0.32);
        expect(formatInfo('F4').admissionBound, closeTo(0.17, 1e-9));
        expect(formatInfo('F7').admissionBound, closeTo(0.10, 1e-9));
        expect(formatInfo('S2').admissionBound, closeTo(0.57, 1e-9));
      },
    );
  });

  group('the cognate score', () {
    const es = CognateScorer('es');
    const hi = CognateScorer('hi');

    test('a Spanish near-cognate scores high, a plain word low', () {
      expect(
        es.score('hotel', 'hotel'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(
        es.score('la educación', 'education'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(
        es.score('la bicicleta', 'bicycle'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(es.score('el agua', 'the water'), lessThan(kCognateThreshold));
      expect(es.score('la casa', 'the house'), lessThan(kCognateThreshold));
      expect(es.score('el perro', 'dog'), lessThan(kCognateThreshold));
    });

    test('a Hindi loanword is found by its transliteration', () {
      expect(
        hi.score('skūl', 'school'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(
        hi.score('gilās', 'glass'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(
        hi.score('kampyūṭar', 'computer'),
        greaterThanOrEqualTo(kCognateThreshold),
      );
      expect(hi.score('kitāb', 'book'), lessThan(kCognateThreshold));
      expect(hi.score('pānī', 'water'), lessThan(kCognateThreshold));
    });

    test('accents and marks fold, and words split into units', () {
      expect(foldAccents('Śāla ñandú m̐'), 'sala nandu m');
      expect(editDistance('kitten', 'sitting'), 3);
      expect(shortGloss('to eat; to have lunch (formal)'), 'to eat');
      expect(shortGloss('a heap, a pile, a great deal'), 'a heap');
      expect(shortGloss('33, thirty-three'), 'thirty-three');
      expect(tileUnits('casa'), <String>['c', 'a', 's', 'a']);
      // A consonant with its vowel sign, and a conjunct, are one unit.
      expect(tileUnits('स्कूल'), <String>['स्कू', 'ल']);
      expect(tileUnits('किताब').length, 3);
    });
  });

  for (final language in <String>['es', 'hi']) {
    group('the $language bank', () {
      late PlacementCourse course;
      late ItemBank bank;
      late GenContext cx;

      setUpAll(() {
        course = _course(language);
        bank = ItemBank.build(course.data);
        cx = bank.context;
      });

      Iterable<RegItem> of(String format) => bank.ofFormat(format);

      test('is built from the decks and has every generated format', () {
        expect(course.data.deckCount, greaterThan(50));
        expect(cx.vocab.length, greaterThan(500));
        expect(cx.sentences.length, greaterThan(100));
        final counts = bank.countsByFormat;
        // The formats that pass the audit in both courses. The sentence picks
        // (F5, F17) are not here: with only whole sentences and look-alike
        // options of one kind (sentence_gate.dart) the audit does not pass
        // them in either course at this few (its upper bound is above the
        // pick's 0.32; never loosened), so they are admitted when it does.
        for (final code in <String>[
          'F2',
          'F3',
          'F4',
          'F7',
          'F8',
          'F9',
          'F13',
          'F18',
          'F22',
          'F23',
          'F24',
          'F25',
          'F26',
          'F27',
          'F21',
        ]) {
          expect(counts[code] ?? 0, greaterThan(20), reason: '$language $code');
        }
        // Yes/no needs words of four units or more to build pseudowords from
        // (a Devanagari word is few units), and the audit shows whether they
        // pass; Spanish does.
        if (language == 'es') {
          for (final code in <String>['F1', 'F14']) {
            expect(counts[code] ?? 0, greaterThan(20), reason: code);
          }
        }
        // Every skill has at least two admitted formats that need no audio
        // for Read and Write (and Hear has two that need it).
        bool has(String code) => (counts[code] ?? 0) > 0;
        expect(
          <String>['F2', 'F3', 'F9', 'F8'].where(has).length,
          greaterThanOrEqualTo(3),
        );
        expect(
          <String>['F4', 'F7', 'F8'].where(has).length,
          greaterThanOrEqualTo(3),
        );
        // Hear alone has the look-alike word pick (F26) in both courses; the
        // sentence pick (F17) is asked when the audit passes it.
        expect(has('F26'), isTrue);
        expect(
          <String>['F13', 'F17', 'F26'].where(has).length,
          2 + (has('F17') ? 1 : 0),
        );
        expect(has('F18'), isTrue);
        // Word order passes the held-out solvers in Spanish only (Hindi has
        // 139 usable sentences, too few once they are balanced).
        expect(has('S2'), language == 'es');
      });

      test('has no heard transcription, and reverse formats', () {
        expect(kFormatInventory.any((f) => f.code == 'F16'), isFalse);
        expect(of('F16'), isEmpty);
        // Tiles: the English is spoken (and shown), the answer is the sentence.
        final tiles = of('F24').first;
        final q = V3Run.questionOf(tiles);
        expect(q.mode, V3Mode.tiles);
        expect(q.audio, isNull);
        expect(q.shown, tiles.prompt);
        expect(isSpokenEnglish(q.format), isTrue);
        final placed = <int>[];
        for (final a in tiles.answerTiles) {
          placed.add(
            List<int>.generate(
              tiles.tiles.length,
              (i) => i,
            ).firstWhere((i) => tiles.tiles[i] == a && !placed.contains(i)),
          );
        }
        expect(gradeTiles(tiles, placed), AnswerOutcome.right);
        expect(gradeTiles(tiles, placed.sublist(1)), AnswerOutcome.wrong);
        // Typed word and a pick grade as the formats they reverse.
        final typed = of('F23').first;
        expect(gradeTyped(typed, typed.accepted.first), AnswerOutcome.right);
        expect(gradeTyped(typed, 'qqqq'), AnswerOutcome.wrong);
        final pick = of('F22').first;
        expect(V3Run.questionOf(pick).optionsAreTarget, isTrue);
        expect(pick.options, hasLength(4));
        expect(pick.info.skills, <PlacementSkill>{PlacementSkill.read});
      });

      test('keeps near-cognates out of every word-level format', () {
        final cognateCards = <String>{
          for (final v in cx.vocab)
            if (v.leaky) v.card.id,
        };
        expect(cognateCards, isNotEmpty);
        var checked = 0;
        for (final it in bank.items) {
          if (it.pseudo || !it.info.wordLevel) continue;
          checked++;
          expect(cognateCards.contains(it.cardId), isFalse, reason: it.id);
          expect(
            it.cognateScore,
            lessThan(kWordLevelCognateMax),
            reason: it.id,
          );
          // The other words of a matching screen are eligible too (the
          // options of a pick may be any word).
          if (it.format == 'F9') {
            for (final c in it.coCards) {
              expect(cognateCards.contains(c), isFalse, reason: it.id);
            }
          }
        }
        expect(checked, greaterThan(1000));
        // Matching is stricter still.
        for (final it in of('F9')) {
          expect(it.cognateScore, lessThan(0.45), reason: it.id);
        }
      });

      test('weights a sentence by its non-cognate content words', () {
        var light = 0;
        var full = 0;
        for (final it in bank.items) {
          if (it.pseudo || it.info.wordLevel) continue;
          if (it.nonCognateContent >= 2) {
            expect(it.weight, 1, reason: it.id);
            expect(it.cognateClass, 'clean', reason: it.id);
            full++;
          } else {
            expect(it.weight, 0.5, reason: it.id);
            expect(it.cognateClass, 'cognate', reason: it.id);
            expect(it.toJointItem().clean, isFalse, reason: it.id);
            light++;
          }
        }
        expect(full, greaterThan(0));
        // Both kinds exist in a real course (a short sentence of cognates).
        expect(light + full, greaterThan(100));
      });

      test('word tiles carry decoys, chosen so the strong solver stays under '
          'guess plus 0.07 (ANAGRAM-SOLVER gate)', () {
        final tiles = of('F4').toList();
        expect(tiles, isNotEmpty);
        expect(bank.decoys, greaterThanOrEqualTo(2));
        for (final it in tiles) {
          expect(it.decoyCount, bank.decoys);
          expect(it.tiles.length, it.answerTiles.length + it.decoyCount);
          final left = List<String>.of(it.tiles);
          for (final a in it.answerTiles) {
            expect(left.remove(a), isTrue, reason: '${it.id} has tile $a');
          }
          // What is left over are decoys, not the answer's own units.
          expect(left.length, it.decoyCount, reason: it.id);
          for (final d in left) {
            expect(it.answerTiles.contains(d), isFalse, reason: it.id);
          }
        }
        final audit = bank.audit.classes['F4:clean']!;
        expect(audit.solver, 'anagram-solver');
        expect(audit.accuracy, lessThanOrEqualTo(0.10 + 0.07));
        expect(audit.passes, isTrue);
      });

      test('keeps the end marks of a word-order pair fixed and swaps two '
          'words', () {
        final items = ItemGenerators(cx).wordOrder();
        expect(items, isNotEmpty);
        for (final it in items) {
          final s = cx.sentences.firstWhere((x) => x.card.id == it.cardId);
          expect(it.options.length, 2);
          final good = it.options[it.correct];
          final bad = it.options[1 - it.correct];
          expect(good, s.text);
          for (final o in it.options) {
            expect(o.startsWith(s.leadingMark), isTrue, reason: o);
            expect(o.endsWith(s.trailingMark), isTrue, reason: o);
          }
          final g = targetWords(good);
          final b = targetWords(bad);
          expect(b.length, g.length);
          final differing = <int>[
            for (var i = 0; i < g.length; i++)
              if (g[i].toLowerCase() != b[i].toLowerCase()) i,
          ];
          // Two words (up to three places apart) trade places.
          expect(differing.length, 2, reason: it.id);
          expect(differing[1] - differing[0], lessThanOrEqualTo(3));
          expect(b[differing[0]].toLowerCase(), g[differing[1]].toLowerCase());
          expect(b[differing[1]].toLowerCase(), g[differing[0]].toLowerCase());
        }
      });

      test('admits a word-order class only if the audit passes it', () {
        for (final key in <String>['S2:clean', 'S2:cognate']) {
          final c = bank.audit.classes[key];
          if (c == null) continue;
          final admitted = bank.items.any((i) => i.auditClass == key);
          expect(admitted, c.passes, reason: '$key ${c.accuracy} ${c.solver}');
        }
      });

      test('picks words with distractors of the same part of speech and '
          'shape, with a look-alike lure', () {
        final byGloss = <String, List<VocabWord>>{};
        for (final v in cx.vocab) {
          (byGloss[v.gloss] ??= <VocabWord>[]).add(v);
        }
        final byDisplay = <String, List<VocabWord>>{};
        for (final v in cx.vocab) {
          (byDisplay[v.display] ??= <VocabWord>[]).add(v);
        }
        var withLure = 0;
        var oddWords = 0;
        final f2 = of('F2').toList();
        for (final it in f2) {
          final card = cx.vocab.firstWhere((v) => v.card.id == it.cardId);
          expect(it.options.length, 4);
          expect(it.options.toSet().length, 4, reason: it.id);
          expect(it.options[it.correct], card.gloss);
          for (final o in it.options) {
            expect(
              (byGloss[o] ?? const <VocabWord>[]).any((v) => v.pos == card.pos),
              isTrue,
              reason: '${it.id}: "$o" is not a ${card.pos}',
            );
          }
          // A look-alike of the prompt among the wrong options.
          final lure = it.options.any(
            (o) =>
                o != card.gloss &&
                wordSimilarity(card.roman, o, language) >= 0.3,
          );
          if (lure) withLure++;
          // No option is the odd one out by its number of words (a few items
          // have no better distractor).
          if (it.options.map((o) => o.split(' ').length).toSet().length > 2) {
            oddWords++;
          }
        }
        expect(withLure / f2.length, greaterThan(0.05));
        expect(oddWords / f2.length, lessThanOrEqualTo(0.02));
        var loose = 0;
        for (final it in of('F3')) {
          // Two cards may share a spelling (homographs): the right option is
          // the one whose meaning is the prompt.
          final card = byDisplay[it.options[it.correct]]!.firstWhere(
            (v) => v.gloss == it.prompt,
          );
          expect(it.options.toSet().length, 4, reason: it.id);
          final shaped = <String>[
            for (final o in it.options)
              if (o != it.options[it.correct])
                if ((byDisplay[o] ?? const <VocabWord>[]).any(
                  (v) =>
                      v.pos == card.pos &&
                      (v.units.length - card.units.length).abs() <= 2,
                ))
                  o,
          ];
          // Two of the three wrong options match the shape; one may be the
          // look-alike lure.
          if (shaped.length < 2) loose++;
        }
        expect(loose / of('F3').length, lessThanOrEqualTo(0.01));
      });

      test('makes look-alike word picks (F26 heard, F27 written) of six '
          'options in one length band, each a cheap single-skill item', () {
        final hear = formatInfo('F26');
        final read = formatInfo('F27');
        expect(hear.skills, <PlacementSkill>{PlacementSkill.hear});
        expect(read.skills, <PlacementSkill>{PlacementSkill.read});
        expect(hear.needsAudio, isTrue);
        expect(read.needsAudio, isFalse);
        for (final f in <FormatInfo>[hear, read]) {
          expect(f.options, 6, reason: f.code);
          expect(f.guess, inInclusiveRange(0.17, 0.20), reason: f.code);
          expect(f.slip, lessThanOrEqualTo(0.05), reason: f.code);
          expect(f.seconds, lessThanOrEqualTo(8), reason: f.code);
          expect(f.admissionBound, closeTo(f.guess + 0.07, 1e-9));
        }
        final picks = ItemGenerators(cx).lookAlikePicks('F27');
        expect(picks.length, greaterThan(300), reason: language);
        for (final it in picks) {
          expect(it.options, hasLength(6), reason: it.id);
          expect(it.options.toSet().length, 6, reason: it.id);
          final right = it.options[it.correct];
          for (final o in it.options) {
            expect(inOneBand(right, o), isTrue, reason: '${it.id} $o');
          }
          expect(it.cognateScore, lessThan(kWordLevelCognateMax));
        }
        // Heard and written are the same items; both are admitted, so a bank
        // asks them (a card is never asked in both: shared conflict keys).
        for (final code in <String>['F26', 'F27']) {
          final cls = bank.audit.classes['$code:clean']!;
          expect(cls.passes, isTrue, reason: '$language $code');
          expect(cls.accuracy, lessThan(0.22), reason: '$language $code');
          expect(of(code).length, picks.length, reason: code);
        }
        final heard = of('F26').first;
        final written = of('F27').firstWhere((i) => i.cardId == heard.cardId);
        expect(heard.conflictKeys, written.conflictKeys);
        final q = V3Run.questionOf(heard);
        expect(q.audio, heard.prompt);
        expect(q.options, hasLength(6));
        expect(V3Run.questionOf(written).shown, written.prompt);
      });

      test('makes sentence picks whose wrong options are other sentences, '
          'with no cue for the solvers', () {
        final g = ItemGenerators(cx);
        for (final format in <String>['F5', 'F17']) {
          final picks = g.sentencePicks(format);
          expect(picks.length, greaterThan(100), reason: '$language $format');
          var simTop = 0;
          var lenTop = 0;
          var lenBottom = 0;
          final known = buildKnownText(cx.early);
          for (final it in picks) {
            final right = it.options[it.correct];
            final card = cx.sentences.firstWhere((s) => s.card.id == it.cardId);
            expect(right, card.english);
            expect(it.options.toSet().length, 4);
            // The options look alike: one length band, about as many words.
            for (final o in it.options) {
              expect(inOneBand(right, o), isTrue, reason: '${it.id}: $o');
            }
            // No wrong option is the right translation with one word changed
            // (that would make the right one the centre of the four).
            final centre = centrality(it.options);
            final c = expectedBoth(centre, it.correct);
            expect(c.high, lessThanOrEqualTo(0.25 + 1e-9), reason: it.id);
            expect(c.low, lessThanOrEqualTo(0.25 + 1e-9), reason: it.id);
            // The gamer's first words are in no option more than in another.
            final prompt = targetWords(it.promptRoman ?? it.prompt);
            final scores = <double>[
              for (final o in it.options) knownWordScore(prompt, o, known),
            ];
            expect(scores.toSet().length, 1, reason: it.id);
            if (it.options.where((o) => o.length > right.length).isEmpty) {
              lenTop++;
            }
            if (it.options.where((o) => o.length < right.length).isEmpty) {
              lenBottom++;
            }
            final sims = <double>[
              for (final o in it.options)
                maxSimilarity(prompt, glossWords(o), language),
            ];
            if (rankPattern(<double>[
                  sims[it.correct],
                  for (var i = 0; i < 4; i++)
                    if (i != it.correct) sims[i],
                ]) ==
                0) {
              simTop++;
            }
          }
          // A solver that takes the longest, the shortest or the most similar
          // option gets no more than a quarter (cognate-class sentences are
          // audited apart and kept in proportion too).
          expect(lenTop / picks.length, lessThanOrEqualTo(0.27));
          expect(lenBottom / picks.length, lessThanOrEqualTo(0.27));
          expect(simTop / picks.length, lessThanOrEqualTo(0.27));
          // The audit decides: a class is asked only when it passes.
          final audited = bank.audit.classes['$format:clean']!;
          expect(of(format).isNotEmpty, audited.passes, reason: format);
        }
      });

      test('gap spelling (F21) is a cheap Write item the language patterns '
          'cannot fill', () {
        final info = formatInfo('F21');
        expect(info.seconds, lessThanOrEqualTo(6));
        expect(info.slip, lessThanOrEqualTo(0.10));
        expect(info.guess, lessThanOrEqualTo(0.10));
        expect(info.skills, {PlacementSkill.write});
        final items = of('F21').toList();
        expect(items.length, greaterThan(200), reason: language);
        final model = UnitModel(<List<String>>[
          for (final v in cx.vocab) v.units,
        ]);
        final alphabet = <String>[
          for (final e in model.uni.entries)
            if (e.value >= 2) e.key,
        ]..sort();
        var checked = 0;
        for (final it in items.take(150)) {
          final units = it.answerTiles;
          expect(it.gapIndex, inInclusiveRange(0, units.length - 1));
          expect(it.gapLength, inInclusiveRange(1, 3), reason: it.id);
          expect(it.gapIndex + it.gapLength, lessThanOrEqualTo(units.length));
          expect(it.accepted, <String>[
            units.sublist(it.gapIndex, it.gapIndex + it.gapLength).join(),
          ], reason: it.id);
          final card = cx.vocab.firstWhere((v) => v.card.id == it.cardId);
          expect(units, card.units, reason: it.id);
          expect(it.prompt, card.gloss);
          // No gap-filling cue of the language's own spelling patterns picks
          // the unit.
          model.remove(units);
          final abc = alphabet.contains(units[it.gapIndex])
              ? alphabet
              : <String>[...alphabet, units[it.gapIndex]];
          final r = model.gapSolvers(units, it.gapIndex, abc);
          model.restore(units);
          for (final e in r.accuracy.entries) {
            expect(
              e.value,
              lessThanOrEqualTo(0.04),
              reason: '${it.id} ${e.key}',
            );
          }
          checked++;
        }
        expect(checked, greaterThan(100));
        expect(bank.audit.classes['F21:clean']!.passes, isTrue);
        // Every tenth of the path has gap items, so a proof can be asked at
        // any band.
        final decks = course.data.deckCount;
        for (var t = 0; t < 10; t++) {
          final from = decks * t ~/ 10;
          final to = decks * (t + 1) ~/ 10;
          final n = items.where((i) => i.deck >= from && i.deck < to).length;
          expect(n, greaterThanOrEqualTo(10), reason: '$language tenth $t');
        }
      });

      test('gap spelling leaves out one, two or three units, mostly more '
          'than one', () {
        final items = of('F21').toList();
        final counts = <int, int>{};
        for (final it in items) {
          counts[it.gapLength] = (counts[it.gapLength] ?? 0) + 1;
        }
        expect(
          counts.keys.toSet(),
          containsAll(<int>[1, 2]),
          reason: '$counts',
        );
        final multi = items.where((i) => i.gapLength > 1).length;
        expect(multi / items.length, greaterThan(0.1), reason: '$counts');
        // Typing the units or the whole word is right.
        final it = items.firstWhere((i) => i.gapLength > 1);
        expect(gradeTyped(it, it.accepted.first), AnswerOutcome.right);
        expect(gradeTyped(it, it.answerTiles.join()), AnswerOutcome.right);
        expect(gradeTyped(it, 'zzz'), AnswerOutcome.wrong);
      });

      test('sentence fill-in (F28) has options of one word class and one '
          'that fits the English', () {
        final items = ItemGenerators(cx).sentenceFill();
        if (language == 'es') expect(items.length, greaterThan(10));
        final classes = <String, Set<String>>{};
        for (final v in cx.vocab) {
          (classes[v.word.toLowerCase()] ??= <String>{}).add(v.pos);
        }
        for (final it in items) {
          expect(it.options.length, 4);
          expect(it.options.toSet().length, 4);
          expect(it.prompt.split('___').length, 2, reason: it.id);
          final cls = <Set<String>>[
            for (final o in it.options) classes[o.toLowerCase()] ?? <String>{},
          ];
          for (final c in cls) {
            expect(c.length, 1, reason: '${it.id}: a class is known');
            expect(c.first, isNot('other'), reason: it.id);
            expect(c.first, cls.first.first, reason: '${it.id}: one class');
          }
          // The English holds the right word's meaning and none of the
          // others'.
          final eng = glossWords(it.promptRoman!).toSet();
          for (var i = 0; i < 4; i++) {
            final fits = cx.vocab
                .where((v) => v.word.toLowerCase() == it.options[i])
                .any((v) => glossWords(v.gloss).any(eng.contains));
            expect(fits, i == it.correct, reason: '${it.id} option $i');
          }
        }
        final audited = bank.audit.classes['F28:clean']!;
        if (language == 'es') {
          // No solver of the audit gains on the options: the best is within
          // sampling noise of chance, and the class is asked.
          expect(audited.passes, isTrue, reason: '${audited.solvers}');
          expect(bank.excluded, isNot(contains('F28:clean')));
          for (final e in audited.solvers.entries) {
            expect(e.value, lessThan(0.29), reason: e.key);
          }
        } else {
          // Hindi has too few sentences: even a solver at exact chance has an
          // upper bound above the admission bound, so the class stays out.
          expect(audited.n, lessThan(100));
          expect(bank.excluded, contains('F28:clean'));
        }
      });

      test('word order is admitted and balanced: the right order scores '
          'higher as often as lower on every cue', () {
        final items = of('S2').toList();
        if (language == 'hi') {
          expect(items, isEmpty);
          expect(bank.excluded, contains('S2:clean'));
          return;
        }
        expect(items.length, greaterThan(100), reason: language);
        final cues = ContextCues(
          <List<String>>[for (final s in cx.sentences) s.words],
          texts: <String>[for (final s in cx.sentences) s.text],
        );
        for (final clean in <bool>[true, false]) {
          final group = [
            for (final it in items)
              if ((cx.sentences
                          .firstWhere((s) => s.card.id == it.cardId)
                          .nonCognateContent >=
                      2) ==
                  clean)
                it,
          ];
          for (var c = 0; c < ContextCues.names.length; c++) {
            var higher = 0;
            var lower = 0;
            for (final it in group) {
              final good = targetWords(it.options[it.correct]);
              final bad = targetWords(it.options[1 - it.correct]);
              final gt = it.options[it.correct];
              final bt = it.options[1 - it.correct];
              final g = cues.scores(good, good, text: gt, truthText: gt)[c];
              final b = cues.scores(bad, good, text: bt, truthText: gt)[c];
              if ((g - b).abs() < 1e-9) continue;
              g > b ? higher++ : lower++;
            }
            expect(higher, lower, reason: '$language clean=$clean cue $c');
          }
        }
        expect(bank.audit.classes['S2:clean']!.passes, isTrue);
      });

      test(
        'the held-out solvers are in the audit of F21, S2 and the picks',
        () {
          List<String> names(String key) =>
              bank.audit.classes[key]?.solvers.keys.toList() ?? <String>[];
          expect(
            names('F21:clean'),
            containsAll(<String>[
              'char-lm',
              'char-lm-lowest',
              'char-lm-rank2',
              'edges-lowest',
              'unit-frequency-lowest',
              'letter-patterns-rank3',
              'feature-classifier',
            ]),
          );
          expect(
            names('F5:clean'),
            containsAll(<String>[
              'english-char-lm',
              'english-char-lm-inverted',
              'feature-classifier',
            ]),
          );
          if (language == 'es') {
            expect(
              names('S2:clean'),
              containsAll(<String>['sentence-char-lm', 'feature-classifier']),
            );
          }
          // Every solver of an admitted class is within the bound.
          for (final key in <String>['F21:clean']) {
            final c = bank.audit.classes[key]!;
            expect(c.passes, isTrue, reason: key);
            expect(
              c.solvers['feature-classifier']!,
              lessThanOrEqualTo(c.bound),
            );
          }
        },
      );

      test('matching screens are drawn so the matcher does worse than '
          'chance', () {
        final c = bank.audit.classes['F9:clean']!;
        expect(c.passes, isTrue);
        expect(c.accuracy, lessThan(0.30));
      });

      test('makes clozes with no English hint and options that share the '
          'ending but not the stem', () {
        final cloze = ItemGenerators(cx).cloze();
        // Few sentences have three same-ending words the context cues rate
        // exactly alike (none in Hindi); the class is not admitted.
        if (cloze.isEmpty) return;
        for (final it in cloze) {
          final card = cx.sentences.firstWhere((s) => s.card.id == it.cardId);
          expect(it.prompt.split('___').length, 2, reason: it.id);
          // No translation of the sentence is shown or hinted.
          expect(it.prompt.contains(card.english), isFalse, reason: it.id);
          expect(it.options.length, 4);
          expect(it.options.toSet().length, 4);
          final right = tileUnits(it.options[it.correct]);
          for (final o in it.options) {
            final u = tileUnits(o);
            expect(u.last, right.last, reason: '${it.id}: ending of $o');
            if (o != it.options[it.correct]) {
              expect(
                u.take(3).join() == right.take(3).join(),
                isFalse,
                reason: it.id,
              );
              expect((u.length - right.length).abs(), lessThanOrEqualTo(1));
            }
          }
          // Putting the right word back gives the sentence.
          final back = it.prompt.replaceFirst('___', it.options[it.correct]);
          expect(back.toLowerCase(), card.text.toLowerCase(), reason: it.id);
        }
      });

      test('asks the article of nouns, half of them exceptions to their '
          'ending, where the course has articles for both genders', () {
        final items = ItemGenerators(cx).genderExceptions();
        if (cx.genderArticle.isEmpty) {
          expect(items, isEmpty);
          return;
        }
        expect(items, isNotEmpty);
        final votes = <String, Map<String, int>>{};
        for (final v in cx.vocab) {
          final g = v.card.gender;
          if (v.pos != 'noun' || (g != 'm' && g != 'f')) continue;
          (votes[v.units.last] ??= <String, int>{})[g!] =
              ((votes[v.units.last] ?? const <String, int>{})[g] ?? 0) + 1;
        }
        var exceptions = 0;
        for (final it in items) {
          final v = cx.vocab.firstWhere((x) => x.card.id == it.cardId);
          final g = v.card.gender!;
          final v2 = votes[v.units.last]!;
          final other = g == 'm' ? 'f' : 'm';
          if (it.genderException) {
            exceptions++;
            expect(v2[other] ?? 0, greaterThan(v2[g] ?? 0), reason: it.id);
          } else {
            expect(v2[g] ?? 0, greaterThan(v2[other] ?? 0), reason: it.id);
          }
          expect(it.options[it.correct], cx.genderArticle[g]);
          expect(it.options.length, 2);
        }
        // Half exceptions, half rule-followers: always agreeing with the
        // ending, or always contradicting it, gets half.
        expect(exceptions * 2, items.length);
      });

      test('builds at least eight pseudowords that are not words', () {
        final pseudo = ItemGenerators(cx).pseudowords('F1');
        // Enough of them for the audit's confidence bound to mean something.
        expect(pseudo.length, greaterThanOrEqualTo(200));
        final words = <String>{for (final v in cx.vocab) v.word.toLowerCase()};
        for (final p in pseudo) {
          expect(
            words.contains(p.prompt.toLowerCase()),
            isFalse,
            reason: p.prompt,
          );
          expect(p.isReal, isFalse);
          expect(p.toJointItem().yesNo, YesNoRole.pseudoword);
        }
      });

      test('audits every class, and admits only classes that pass '
          '(admission audit gate)', () {
        expect(bank.audit.classes, isNotEmpty);
        for (final c in bank.audit.classes.values) {
          expect(c.accuracy, lessThanOrEqualTo(1));
          // The bound is the guess plus 0.07: 0.32 for a four-option pick.
          if (c.key.startsWith('F2:') || c.key.startsWith('F13:')) {
            expect(c.bound, 0.32);
          }
        }
        for (final it in bank.items) {
          expect(
            bank.audit.classes[it.auditClass]!.passes,
            isTrue,
            reason: it.id,
          );
        }
        for (final c in bank.audit.failed) {
          expect(bank.excluded, contains(c.key));
          expect(bank.items.any((i) => i.auditClass == c.key), isFalse);
        }
        // The core classes pass in a real course.
        for (final key in <String>[
          'F2:clean',
          'F3:clean',
          'F13:clean',
          'F7:clean',
        ]) {
          expect(bank.audit.classes[key]!.passes, isTrue, reason: key);
        }
      });

      test('the audit can fail a class (control): a pick whose right answer '
          'is the longest option', () {
        final leaky = <RegItem>[];
        for (final it in of('F2').take(120)) {
          final right = it.options[it.correct];
          final opts = <String>[right, 'x', 'yy', 'zzz'];
          leaky.add(
            RegItem(
              id: '${it.id}-leaky',
              format: 'F2',
              cardId: it.cardId,
              deck: it.deck,
              prompt: it.prompt,
              promptRoman: it.promptRoman,
              options: opts,
              optionsRoman: opts,
              correct: 0,
              cognateScore: 0,
            ),
          );
        }
        final report = auditItems(leaky, cx);
        final c = report.classes['F2:clean']!;
        expect(c.passes, isFalse);
        expect(c.solver, 'length');
        expect(report.admits('F2:clean'), isFalse);
      });

      test('the audit is confidence-aware: a small class is not admitted even '
          'at chance, and an unattacked class is not admitted', () {
        final few = <RegItem>[
          for (final it in of('F2').skip(150).take(20))
            RegItem(
              id: '${it.id}-few',
              format: 'F2',
              cardId: it.cardId,
              deck: it.deck,
              prompt: it.prompt,
              promptRoman: it.promptRoman,
              options: it.options,
              optionsRoman: it.optionsRoman,
              correct: it.correct,
            ),
        ];
        final report = auditItems(few, cx);
        final c = report.classes['F2:clean']!;
        expect(c.upper, greaterThan(c.bound));
        expect(c.passes, isFalse);
        expect(report.admits('F3:clean'), isFalse);
        for (final k in bank.audit.classes.values) {
          if (k.passes) expect(k.upper, lessThanOrEqualTo(k.bound + 1e-9));
        }
        expect(wilsonUpper(0.25, 320), lessThan(0.32));
        expect(wilsonUpper(0.25, 26), greaterThan(0.32));
        expect(aucUpper(0.5, 850, 400), lessThan(0.55));
        expect(aucUpper(0.5, 20, 20), greaterThan(0.6));
      });

      test('the audit reads a cue either way: an answer that is always the '
          'shortest option fails (inverted orientation)', () {
        final leaky = <RegItem>[
          for (final it in of('F2').take(160))
            RegItem(
              id: '${it.id}-short',
              format: 'F2',
              cardId: it.cardId,
              deck: it.deck,
              prompt: it.prompt,
              promptRoman: it.promptRoman,
              options: <String>['a', 'bbbb', 'cccccc', 'dddddddd'],
              optionsRoman: <String>['a', 'bbbb', 'cccccc', 'dddddddd'],
              correct: 0,
            ),
        ];
        final c = auditItems(leaky, cx).classes['F2:clean']!;
        expect(c.passes, isFalse);
        expect(c.solver, 'length-inverted');
      });

      test('a look-alike lure that is always wrong is audited: dropping the '
          'most similar option beats chance', () {
        final items = <RegItem>[];
        for (final v in cx.vocab.where((v) => !v.leaky && !v.early).take(300)) {
          final lure = cx.vocab.firstWhere(
            (o) =>
                o.card.id != v.card.id &&
                wordSimilarity(v.roman, o.gloss, language) >= 0.35 &&
                wordSimilarity(v.roman, o.gloss, language) >
                    wordSimilarity(v.roman, v.gloss, language) + 0.05,
            orElse: () => v,
          );
          if (lure.card.id == v.card.id) continue;
          final others = cx.vocab
              .where(
                (o) =>
                    o.card.id != v.card.id &&
                    o.card.id != lure.card.id &&
                    !o.early &&
                    wordSimilarity(v.roman, o.gloss, language) < 0.2,
              )
              .take(2)
              .map((o) => o.gloss)
              .toList();
          if (others.length < 2) continue;
          final opts = <String>[v.gloss, lure.gloss, ...others];
          items.add(
            RegItem(
              id: '${v.card.id}-lure',
              format: 'F2',
              cardId: v.card.id,
              deck: v.deck,
              prompt: v.display,
              promptRoman: v.roman,
              options: opts,
              optionsRoman: opts,
              correct: 0,
            ),
          );
        }
        if (items.length < 40) return;
        final c = auditItems(items, cx).classes['F2:clean']!;
        expect(c.accuracy, greaterThan(0.3));
      });

      test(
        'matching: a matcher gets at most 0.35 of the pairs (MATCHER gate)',
        () {
          final c = bank.audit.classes['F9:clean']!;
          expect(c.solver, startsWith('matcher'));
          expect(c.accuracy, lessThanOrEqualTo(0.35));
          expect(c.passes, isTrue);
          for (final it in of('F9')) {
            expect(it.pairs.length, 4);
            expect(it.pairs.map((p) => p.$2).toSet().length, 4, reason: it.id);
            expect(it.options.toSet(), it.pairs.map((p) => p.$2).toSet());
          }
          // Control: pairs that look like each other are matched.
          final leaky = RegItem(
            id: 'leaky:F9',
            format: 'F9',
            cardId: 'x',
            deck: 1,
            prompt: '',
            pairs: const <(String, String)>[
              ('hotel', 'hotel'),
              ('piano', 'piano'),
              ('radio', 'radio'),
              ('tigre', 'tiger'),
            ],
          );
          final report = auditItems(<RegItem>[leaky], cx);
          expect(report.classes['F9:clean']!.accuracy, greaterThan(0.9));
          expect(report.classes['F9:clean']!.passes, isFalse);
        },
      );

      test('a card is never asked twice in a run, drill-down included, and a '
          'replay gamer gains nothing (FAMILY-REPLAY gate)', () {
        List<RegItem> run(math.Random rng, {required bool exclude}) {
          final asked = <RegItem>[];
          for (var i = 0; i < 30; i++) {
            final pool = exclude
                ? bank.available(asked).toList()
                : bank.items.toList();
            if (pool.isEmpty) break;
            asked.add(pool[rng.nextInt(pool.length)]);
          }
          return asked;
        }

        // A gamer that solved an earlier item answers right any later item
        // that shares a card or a lemma with one; otherwise it answers at the
        // audit's accuracy for the class. The lift is the gap.
        double lift(bool exclude, int runs) {
          final rng = math.Random(3);
          var sharedN = 0;
          var sharedRight = 0.0;
          var otherN = 0;
          var otherRight = 0.0;
          for (var r = 0; r < runs; r++) {
            final asked = run(rng, exclude: exclude);
            final seen = <String>{};
            for (final it in asked) {
              final keys = it.conflictKeys;
              final base = bank.audit.classes[it.auditClass]?.accuracy ?? 0.3;
              if (keys.any(seen.contains)) {
                sharedN++;
                sharedRight += 1;
              } else {
                otherN++;
                otherRight += base;
              }
              seen.addAll(keys);
            }
          }
          if (sharedN == 0) return 0;
          return sharedRight / sharedN - otherRight / otherN;
        }

        expect(lift(true, 60), lessThanOrEqualTo(0.05));
        // The control: without the rule the leak is large.
        expect(lift(false, 400), greaterThan(0.4));

        final rng = math.Random(9);
        for (var r = 0; r < 60; r++) {
          final asked = run(rng, exclude: true);
          final keys = <String>{};
          for (final it in asked) {
            for (final k in it.conflictKeys) {
              expect(keys.add(k), isTrue, reason: '${it.id} repeats $k');
            }
          }
        }
      });

      test('items become the model\'s items with their cognate class', () {
        final f2 = of('F2').first;
        final j = f2.toJointItem();
        expect(j.skills, f2.info.skills);
        expect(j.deck, f2.deck);
        expect(j.clean, isTrue);
        expect(j.cardId, f2.cardId);
        if (of('F1').isNotEmpty) {
          final yes = of('F1').firstWhere((i) => !i.pseudo);
          expect(yes.toJointItem().yesNo, YesNoRole.realWord);
        }
      });
    });
  }

  group('the gap solvers', () {
    test('catch a gap that is always the rarest unit (control)', () {
      // A tiny course in which every word has a common letter pair, and the
      // gap is always the only rare letter: the solver that types the rarest
      // unit, or the lowest scoring one, wins.
      final words = <List<String>>[
        for (var i = 0; i < 30; i++) <String>['c', 'a', 's', 'a'],
        for (var i = 0; i < 30; i++) <String>['m', 'e', 's', 'a'],
        for (var i = 0; i < 30; i++) <String>['o', 's', 'o'],
        <String>['a', 'ñ', 'o'],
      ];
      final model = UnitModel(words);
      final alphabet = <String>['a', 'c', 'e', 'm', 'o', 's', 'ñ'];
      model.remove(<String>['a', 'ñ', 'o']);
      final r = model.gapSolvers(<String>['a', 'ñ', 'o'], 1, alphabet);
      model.restore(<String>['a', 'ñ', 'o']);
      expect(r.accuracy['unit-frequency-lowest'], greaterThan(0.9));
      expect(r.accuracy['unit-frequency'], lessThan(0.1));
      // The old audit, which looked only at the highest, would have passed it.
      expect(r.position[4], greaterThan(0.9));
    });
  });

  group('the audit profile of the harness', () {
    test('the fixture matches what the audit measures now', () {
      final fixture =
          jsonDecode(File(kAuditProfilePath).readAsStringSync())!
              as Map<String, Object?>;
      final languages = fixture['languages']! as Map<String, Object?>;
      expect(languages.keys, containsAll(<String>['es', 'hi']));
      for (final language in <String>['es', 'hi']) {
        final bank = ItemBank.build(_course(language).data);
        final entry = languages[language]! as Map<String, Object?>;
        final classes = entry['classes']! as Map<String, Object?>;
        expect(entry['wordTileDecoys'], bank.decoys, reason: language);
        // The same classes pass and the same are excluded.
        expect(
          (entry['excluded']! as List).cast<String>(),
          bank.excluded,
          reason: '$language excluded classes',
        );
        for (final c in classes.entries) {
          final now = bank.audit.classes[c.key];
          expect(now, isNotNull, reason: '$language ${c.key}');
          final e = c.value! as Map<String, Object?>;
          expect(now!.passes, e['passes'], reason: '$language ${c.key}');
          // The decks grow; a drift above 0.02 means the fixture is stale:
          // regenerate it with tool/placement_audit.dart.
          expect(
            now.accuracy,
            closeTo((e['accuracy']! as num).toDouble(), 0.02),
            reason: '$language ${c.key}',
          );
        }
      }
    });

    test('the harness takes the measured leak of a clean item', () {
      final fixture =
          jsonDecode(File(kAuditProfilePath).readAsStringSync())!
              as Map<String, Object?>;
      final es = leakLanguages()['es']!;
      final classes =
          ((fixture['languages']! as Map<String, Object?>)['es']!
                  as Map<String, Object?>)['classes']!
              as Map<String, Object?>;
      for (final code in <String>['F2', 'F3', 'F13']) {
        final acc =
            ((classes['$code:clean']! as Map<String, Object?>)['accuracy']!
                    as num)
                .toDouble();
        expect(
          es.rate(code, false, BankProfile.fixed, true),
          closeTo(math.max(acc, kFormats[code]!.guess), 1e-9),
          reason: code,
        );
        // A cognate is not generated: the old figure stands.
        expect(es.rate(code, true, BankProfile.fixed, true), greaterThan(0.5));
      }
      // Gap spelling is the cheap Write item. (Sentence picks that the audit
      // does not pass are not in the profile, so the harness takes no leak
      // for them.)
      expect(es.rate('F21', false, BankProfile.fixed, true), 0.10);
      // The legacy bank is the adversary's own measurement, untouched.
      expect(es.rate('F5', false, BankProfile.legacy, true), 0.75);
    });
  });
}
