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
import 'package:fluenough/core/placement/joint_model.dart';
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

final RegExp _english = RegExp(r"[A-Za-z']+");

void main() {
  group('the inventory', () {
    test('lists F1 to F20 with what each needs and leaks', () {
      for (var n = 1; n <= 20; n++) {
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
      for (final code in <String>['F13', 'F14', 'F15', 'F16', 'F17']) {
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
        for (final code in <String>[
          'F1',
          'F2',
          'F3',
          'F4',
          'F7',
          'F8',
          'F9',
          'F13',
          'F14',
          'F16',
          'F18',
        ]) {
          expect(counts[code] ?? 0, greaterThan(20), reason: '$language $code');
        }
        // Sentence formats need a course with enough sentences.
        // (A small class may fail the audit by chance, so only the larger
        // Spanish course is asserted.)
        if (language == 'es') {
          for (final code in <String>['F5', 'F17', 'F6']) {
            expect(counts[code] ?? 0, greaterThan(0), reason: code);
          }
        }
      });

      test('keeps near-cognates out of every word-level format', () {
        final cognateCards = <String>{
          for (final v in cx.vocab)
            if (v.cognate) v.card.id,
        };
        expect(cognateCards, isNotEmpty);
        var checked = 0;
        for (final it in bank.items) {
          if (it.pseudo || !it.info.wordLevel) continue;
          checked++;
          expect(cognateCards.contains(it.cardId), isFalse, reason: it.id);
          expect(it.cognateScore, lessThan(kCognateThreshold), reason: it.id);
          for (final c in it.coCards) {
            expect(cognateCards.contains(c), isFalse, reason: it.id);
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

      test('keeps the end marks of a word-order pair fixed and swaps one '
          'constituent', () {
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
          // One constituent: two adjacent words trade places.
          expect(differing.length, 2, reason: it.id);
          expect(differing[1] - differing[0], 1, reason: it.id);
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
        final byDisplay = <String, VocabWord>{
          for (final v in cx.vocab) v.display: v,
        };
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
        expect(withLure / f2.length, greaterThan(0.2));
        expect(oddWords / f2.length, lessThanOrEqualTo(0.02));
        var loose = 0;
        for (final it in of('F3')) {
          final card = byDisplay[it.options[it.correct]]!;
          expect(card.gloss, it.prompt);
          final shaped = <String>[
            for (final o in it.options)
              if (o != it.options[it.correct])
                if (byDisplay[o] case final v?)
                  if (v.pos == card.pos &&
                      (v.units.length - card.units.length).abs() <= 2)
                    o,
          ];
          // Two of the three wrong options match the shape; one may be the
          // look-alike lure.
          if (shaped.length < 2) loose++;
        }
        expect(loose / of('F3').length, lessThanOrEqualTo(0.01));
      });

      test('makes sentence picks of one-word contrasts of the translation', () {
        final g = ItemGenerators(cx);
        final picks = <RegItem>[
          ...g.sentencePicks('F5'),
          ...g.sentencePicks('F17'),
        ];
        expect(picks, isNotEmpty);
        for (final it in picks) {
          final right = it.options[it.correct];
          final rt = _english.allMatches(right).map((m) => m[0]!).toList();
          final card = cx.sentences.firstWhere((s) => s.card.id == it.cardId);
          expect(right, card.english);
          expect(it.options.toSet().length, 4);
          for (var i = 0; i < 4; i++) {
            if (i == it.correct) continue;
            final ot = _english
                .allMatches(it.options[i])
                .map((m) => m[0]!)
                .toList();
            expect(ot.length, rt.length, reason: it.id);
            final diff = <int>[
              for (var k = 0; k < rt.length; k++)
                if (rt[k] != ot[k]) k,
            ];
            expect(diff.length, 1, reason: '${it.id}: ${it.options[i]}');
            // The contrast has about the length of the word it replaced.
            expect(
              (ot[diff.first].length - rt[diff.first].length).abs(),
              lessThanOrEqualTo(2),
            );
            expect(
              (it.options[i].length - right.length).abs(),
              lessThanOrEqualTo(2),
            );
          }
        }
      });

      test('makes clozes with no English hint and options that share the '
          'ending but not the stem', () {
        final cloze = ItemGenerators(cx).cloze();
        expect(cloze, isNotEmpty);
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

      test('asks the article of exception nouns, where the course has '
          'articles for both genders', () {
        final items = of('F6g').toList();
        if (cx.genderArticle.isEmpty) {
          expect(items, isEmpty);
          return;
        }
        expect(items, isNotEmpty);
        // The ending of each noun does not predict its gender.
        final votes = <String, Map<String, int>>{};
        for (final v in cx.vocab) {
          final g = v.card.gender;
          if (v.pos != 'noun' || (g != 'm' && g != 'f')) continue;
          (votes[v.units.last] ??= <String, int>{})[g!] =
              ((votes[v.units.last] ?? const <String, int>{})[g] ?? 0) + 1;
        }
        for (final it in items) {
          final v = cx.vocab.firstWhere((x) => x.card.id == it.cardId);
          final g = v.card.gender!;
          final v2 = votes[v.units.last]!;
          final other = g == 'm' ? 'f' : 'm';
          expect(v2[other] ?? 0, greaterThan(v2[g] ?? 0), reason: it.id);
          expect(it.options[it.correct], cx.genderArticle[g]);
          expect(it.options.length, 2);
        }
      });

      test('builds at least eight pseudowords that are not words', () {
        final pseudo = bank.items
            .where((i) => i.pseudo && i.format == 'F1')
            .toList();
        expect(pseudo.length, greaterThanOrEqualTo(kMinPseudowords));
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
        expect(c.solver, anyOf('longest', 'shortest'));
        expect(report.admits('F2:clean'), isFalse);
      });

      test(
        'matching: a matcher gets at most 0.35 of the pairs (MATCHER gate)',
        () {
          final c = bank.audit.classes['F9:clean']!;
          expect(c.solver, 'matcher');
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
        final yes = of('F1').firstWhere((i) => !i.pseudo);
        expect(yes.toJointItem().yesNo, YesNoRole.realWord);
      });
    });
  }

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
        for (final c in classes.entries) {
          final now = bank.audit.classes[c.key];
          if (now == null) continue;
          final then = (c.value! as Map<String, Object?>)['accuracy']! as num;
          // The decks grow; a large drift means the fixture is stale:
          // regenerate it with tool/placement_audit.dart.
          expect(
            now.accuracy,
            closeTo(then.toDouble(), 0.08),
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
      for (final code in <String>['F2', 'F3', 'F5', 'F13', 'F17']) {
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
      // The legacy bank is the adversary's own measurement, untouched.
      expect(es.rate('F5', false, BankProfile.legacy, true), 0.75);
    });
  });
}
