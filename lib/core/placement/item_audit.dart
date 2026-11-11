import 'dart:math' as math;

import 'cognate_score.dart';
import 'item_generators.dart';
import 'item_registry.dart';
import 'item_solvers.dart';
import 'unit_model.dart';

// The admission audit of "Find my level" V3 (wiki/Plan-Placement-V3.md,
// "Adversarial review and required amendments", validation): every item class
// (a format and its cognate class) is attacked by solvers that never see the
// answer key, and a class is admitted only if the UPPER confidence bound of
// its best solver's accuracy is within the design guess plus 0.07 (0.32 for a
// four-option pick). A class with too few items to show that is not admitted:
// never loosen a bound, exclude the class.
//
// Every solver is tried in both orientations (it picks the option it scores
// highest, or lowest), because a cue that is always wrong is as good as one
// that is always right. The solvers are the leaks the adversary found, as
// expected-accuracy functions (a tie among n options is worth 1/n), so the
// audit is deterministic:
//  - option length;
//  - similarity of an option to the prompt (a cognate cue), and eliminating
//    the most similar option (a look-alike lure is always wrong);
//  - known words: a gamer that knows the first 100 words of the path;
//  - context: a word-pair model of the course's sentences (without the item's
//    own sentence) for a cloze, and the same on word endings;
//  - an anagram solver for tiles that knows the course's letter patterns
//    except the target word itself (a truncated search counts as solved);
//  - a beam-search order solver for sentence tiles (word and ending pairs);
//  - spelling rules for typed and said words;
//  - a matcher (and an anti-matcher) for matching screens;
//  - pseudoword detectors for yes/no (letter-pattern typicality, nearest-word
//    distance, length, edges, unit pairs), each leaving the word out;
//  - the ending rule for gender (and its opposite);
//  - chance.
//
// Pure Dart.

/// How many words the audit's gamer knows.
const int kAuditKnownWords = 100;

/// The most items of one class the audit attacks (a deterministic stride).
const int kAuditSample = 400;

/// The one-sided confidence the upper bound is taken at (z for 95%).
const double kAuditZ = 1.645;

/// The upper confidence bound of a rate seen as [p] in [n] trials (Wilson).
double wilsonUpper(double p, int n, {double z = kAuditZ}) {
  if (n <= 0) return 1;
  final z2 = z * z;
  final centre = p + z2 / (2 * n);
  final spread = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n));
  return math.min(1.0, (centre + spread) / (1 + z2 / n));
}

/// The upper confidence bound of an AUC of [a] with [n1] positives and [n2]
/// negatives (Hanley and McNeil's standard error).
double aucUpper(double a, int n1, int n2, {double z = kAuditZ}) {
  if (n1 < 2 || n2 < 2) return 1;
  final q1 = a / (2 - a);
  final q2 = 2 * a * a / (1 + a);
  final variance =
      (a * (1 - a) + (n1 - 1) * (q1 - a * a) + (n2 - 1) * (q2 - a * a)) /
      (n1 * n2);
  return math.min(1.0, a + z * math.sqrt(math.max(0, variance)));
}

/// What the audit found for one class of items.
class AuditClass {
  const AuditClass({
    required this.key,
    required this.n,
    required this.accuracy,
    required this.upper,
    required this.bound,
    required this.solver,
    this.solvers = const <String, double>{},
  });

  /// `format:cognateClass`, such as `F2:clean`.
  final String key;

  /// How many items were attacked.
  final int n;

  /// The best solver's expected accuracy.
  final double accuracy;

  /// The upper confidence bound of that accuracy.
  final double upper;

  /// The admission bound of the class.
  final double bound;

  /// The solver that did best.
  final String solver;

  /// The expected accuracy of every solver tried (an AUC for yes/no).
  final Map<String, double> solvers;

  /// Whether the class is admitted: the UPPER bound is within the bound.
  bool get passes => upper <= bound + 1e-9;
}

/// The audit of a bank.
class AuditReport {
  const AuditReport(this.classes);

  final Map<String, AuditClass> classes;

  /// Whether items of [key] are admitted. A class that was not attacked is
  /// not admitted.
  bool admits(String key) => classes[key]?.passes ?? false;

  /// The classes that failed.
  List<AuditClass> get failed => <AuditClass>[
    for (final c in classes.values)
      if (!c.passes) c,
  ];
}

/// Runs the audit on [items] (all formats of a bank) with [cx].
AuditReport auditItems(List<RegItem> items, GenContext cx) {
  final model = UnitModel(<List<String>>[for (final v in cx.vocab) v.units]);
  final knownCards = cx.early;
  final knownIds = cx.earlyIds;
  final knownText = <String, Set<String>>{};
  for (final v in knownCards) {
    knownText[v.roman.toLowerCase()] = <String>{
      v.glossHead,
      ...glossWords(v.gloss),
    }..remove('');
    knownText[v.word.toLowerCase()] = knownText[v.roman.toLowerCase()]!;
  }
  final knownGloss = <String>{
    for (final v in knownCards) ...<String>{
      v.gloss.toLowerCase(),
      v.glossHead,
      v.word.toLowerCase(),
      v.roman.toLowerCase(),
    },
  }..remove('');

  final sentenceWords = <List<String>>[
    for (final s in cx.sentences) <String>[for (final w in s.words) w],
  ];
  final wordGrams2 = countGrams(sentenceWords, 2, lowerWord);
  final suffixGrams2 = countGrams(sentenceWords, 2, suffixOf);
  final suffixGrams3 = countGrams(sentenceWords, 3, suffixOf);

  // Held-out solver families: character n-gram models of the course's text
  // (each item's own text left out), and a classifier fitted on one half of a
  // class and tested on the other.
  final englishLm = CharLm(<String>[for (final s in cx.sentences) s.english]);
  final sentenceLm = CharLm(<String>[for (final s in cx.sentences) s.text]);
  final wordLm = CharLm(<String>[
    for (final v in cx.vocab) v.units.join(),
    for (final s in cx.sentences)
      for (final w in s.words) w,
  ]);
  final tokenCount = <String, int>{};
  for (final s in cx.sentences) {
    for (final w in s.words) {
      final k = w.toLowerCase();
      tokenCount[k] = (tokenCount[k] ?? 0) + 1;
    }
  }

  final byClass = <String, List<RegItem>>{};
  for (final it in items) {
    if (it.pseudo) continue;
    // Items on the gamer's own first 100 words test what it knows: leaks are
    // measured beyond them.
    if (knownIds.contains(it.cardId)) {
      continue;
    }
    (byClass[it.auditClass] ??= <RegItem>[]).add(it);
  }
  final pseudo = <RegItem>[
    for (final it in items)
      if (it.pseudo && it.format == 'F1') it,
  ];
  final out = <String, AuditClass>{};
  for (final e in byClass.entries) {
    final all = e.value;
    // Yes/no is audited on every real word: the AUC's confidence bound
    // needs as many as there are.
    final yesNo = all.first.format == 'F1' || all.first.format == 'F14';
    final stride = yesNo ? 1 : math.max(1, (all.length / kAuditSample).ceil());
    final sample = <RegItem>[
      for (var i = 0; i < all.length; i += stride) all[i],
    ];
    final fmt = baseFormat(sample.first.format);
    final info = sample.first.info;
    final solvers = <String, double>{};
    var trials = sample.length;
    double? auc;
    var aucN1 = 0;
    var aucN2 = 0;

    void both(String name, double high, double low) {
      solvers[name] = (solvers[name] ?? 0) + high;
      solvers['$name-inverted'] = (solvers['$name-inverted'] ?? 0) + low;
    }

    final rows = <List<List<double>>>[];
    final rowCorrect = <int>[];
    switch (fmt) {
      case 'F2' || 'F13' || 'F3' || 'F5' || 'F17' || 'F6' || 'S2' || 'F6g':
        final nOptions = sample.first.options.length;
        solvers['chance'] = sample.length / nOptions;
        for (final it in sample) {
          final lens = <double>[
            for (final o in it.options) o.length.toDouble(),
          ];
          final l = expectedBoth(lens, it.correct);
          both('length', l.high, l.low);
          if (fmt == 'F2' || fmt == 'F13' || fmt == 'F5' || fmt == 'F17') {
            final promptWords = targetWords(it.promptRoman ?? it.prompt);
            final sim = <double>[
              for (final o in it.options)
                _maxSim(promptWords, glossWords(o), cx.data.language),
            ];
            final s = expectedBoth(sim, it.correct);
            both('similarity', s.high, s.low);
            both('eliminate-similar', _eliminate(sim, it.correct), 0);
            final known = <double>[
              for (final o in it.options)
                _knownScore(promptWords, o, knownText, it, knownIds),
            ];
            final k = expectedBoth(known, it.correct);
            both('known-words', k.high, k.low);
            final comb = expectedBoth(<double>[
              for (var i = 0; i < known.length; i++) known[i] + 0.01 * sim[i],
            ], it.correct);
            both('known+similarity', comb.high, comb.low);
            if (fmt == 'F5' || fmt == 'F17') {
              final centre = centrality(it.options);
              final c = expectedBoth(centre, it.correct);
              both('centre-of-options', c.high, c.low);
              // Held out: how typical of the course's English each option
              // is, each leaving itself out.
              final lm = <double>[
                for (final o in it.options) _heldOut(englishLm, o),
              ];
              final l = expectedBoth(lm, it.correct);
              both('english-char-lm', l.high, l.low);
              final zl = zWithin(lens);
              final zs = zWithin(sim);
              final zc = zWithin(centre);
              final zm = zWithin(lm);
              final zk = zWithin(known);
              rows.add(<List<double>>[
                for (var i = 0; i < it.options.length; i++)
                  <double>[zl[i], zs[i], zc[i], zm[i], zk[i]],
              ]);
              rowCorrect.add(it.correct);
            }
          } else if (fmt == 'F3') {
            final eng = glossWords(it.prompt);
            final sim = <double>[
              for (final o in it.optionsRoman)
                _maxSim(targetWords(o), eng, cx.data.language),
            ];
            final s = expectedBoth(sim, it.correct);
            both('similarity', s.high, s.low);
            both('eliminate-similar', _eliminate(sim, it.correct), 0);
            final known = <double>[
              for (final o in it.optionsRoman)
                knownText[o.toLowerCase()]?.any(eng.contains) == true
                    ? 1.0
                    : 0.0,
            ];
            final k = expectedBoth(known, it.correct);
            both('known-words', k.high, k.low);
            final comb = expectedBoth(<double>[
              for (var i = 0; i < known.length; i++) known[i] + 0.01 * sim[i],
            ], it.correct);
            both('known+similarity', comb.high, comb.low);
          } else if (fmt == 'F6') {
            final scores = <double>[
              for (final o in it.options)
                knownGloss.contains(o.toLowerCase()) ? 1.0 : 0.0,
            ];
            final k = expectedBoth(scores, it.correct);
            both('known-words', k.high, k.low);
            // The context solvers: the sentence with each option filled in,
            // scored by the course's word pairs and ending pairs without
            // this sentence.
            final parts = it.prompt.split('___');
            List<String> fill(String o) => <String>[
              ...targetWords(parts.first),
              o,
              ...targetWords(parts.last),
            ].map((w) => w.toLowerCase()).toList();
            final truth = fill(it.options[it.correct]);
            final own2 = ownGrams(truth, 2, lowerWord);
            final ownS2 = ownGrams(truth, 2, suffixOf);
            final ownS3 = ownGrams(truth, 3, suffixOf);
            final c2 = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(fill(o), 2, wordGrams2, own2, lowerWord),
            ], it.correct);
            both('context-word-pairs', c2.high, c2.low);
            final cs2 = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(fill(o), 2, suffixGrams2, ownS2, suffixOf),
            ], it.correct);
            both('context-ending-pairs', cs2.high, cs2.low);
            final cs3 = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(fill(o), 3, suffixGrams3, ownS3, suffixOf),
            ], it.correct);
            both('context-ending-triples', cs3.high, cs3.low);
          } else if (fmt == 'S2') {
            final truth = targetWords(it.options[it.correct]);
            List<String> words(String o) =>
                targetWords(o).map((w) => w.toLowerCase()).toList();
            final own2 = ownGrams(truth.map(lowerWord).toList(), 2, lowerWord);
            final ownS2 = ownGrams(truth.map(lowerWord).toList(), 2, suffixOf);
            final ownS3 = ownGrams(truth.map(lowerWord).toList(), 3, suffixOf);
            final b = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(words(o), 2, wordGrams2, own2, lowerWord),
            ], it.correct);
            both('word-pairs', b.high, b.low);
            final s2 = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(words(o), 2, suffixGrams2, ownS2, suffixOf),
            ], it.correct);
            both('ending-pairs', s2.high, s2.low);
            final s3 = expectedBoth(<double>[
              for (final o in it.options)
                ngramScore(words(o), 3, suffixGrams3, ownS3, suffixOf),
            ], it.correct);
            both('ending-triples', s3.high, s3.low);
            sentenceLm.add(it.options[it.correct], -1);
            final lm = <double>[
              for (final o in it.options) sentenceLm.score(o),
            ];
            sentenceLm.add(it.options[it.correct], 1);
            final l = expectedBoth(lm, it.correct);
            both('sentence-char-lm', l.high, l.low);
            final cuesOf = <List<double>>[
              for (final o in it.options)
                <double>[
                  ngramScore(words(o), 2, wordGrams2, own2, lowerWord),
                  ngramScore(words(o), 2, suffixGrams2, ownS2, suffixOf),
                  ngramScore(words(o), 3, suffixGrams3, ownS3, suffixOf),
                  lm[it.options.indexOf(o)],
                ],
            ];
            final z = <List<double>>[
              for (var i = 0; i < it.options.length; i++) <double>[],
            ];
            for (var c = 0; c < 4; c++) {
              final zc = zWithin(<double>[for (final o in cuesOf) o[c]]);
              for (var i = 0; i < z.length; i++) {
                z[i].add(zc[i]);
              }
            }
            rows.add(z);
            rowCorrect.add(it.correct);
          } else if (fmt == 'F6g') {
            final r = expectedBoth(<double>[
              for (final o in it.options) _endingRule(o, it, cx),
            ], it.correct);
            both('ending-rule', r.high, r.low);
          }
        }
        if (rows.isNotEmpty) {
          solvers['feature-classifier'] =
              crossFitAccuracy(rows, rowCorrect) * sample.length;
        }
      case 'F4':
        var total = 0.0;
        for (final it in sample) {
          total += _anagram(it, model);
        }
        solvers['anagram-solver'] = total;
      case 'F7' || 'F18':
        var total = 0.0;
        for (final it in sample) {
          final head = latinLetters(it.prompt.split(' ').last);
          final target = latinLetters(
            it.answerTiles.isEmpty ? '' : it.answerTiles.first,
          );
          final guesses = _spellings(head);
          if (target.isNotEmpty && guesses.contains(target)) total += 1;
        }
        solvers['spelling-rules'] = total;
      case 'F21':
        // Gap spelling: the best gap-filling cue, and the spelling rules
        // applied to the whole word.
        final alphabet = <String>[
          for (final e in model.uni.entries)
            if (e.value >= 2) e.key,
        ]..sort();
        final totals = <String, double>{};
        var rules = 0.0;
        for (final it in sample) {
          final units = it.answerTiles;
          model.remove(units);
          final abc = alphabet.contains(units[it.gapIndex])
              ? alphabet
              : <String>[...alphabet, units[it.gapIndex]];
          final r = model.gapSolvers(units, it.gapIndex, abc);
          model.restore(units);
          for (final e in r.accuracy.entries) {
            totals[e.key] = (totals[e.key] ?? 0) + e.value;
          }
          final head = latinLetters(it.prompt.split(' ').last);
          final target = latinLetters(units.join());
          if (target.isNotEmpty && _spellings(head).contains(target)) {
            rules += 1;
          }
        }
        // Held out: a character n-gram model of the course's words and
        // sentence words without the target word, and a classifier fitted on
        // one half of the items and tested on the other.
        final lmTotals = <String, double>{};
        final frows = <List<List<double>>>[];
        final fcorrect = <int>[];
        for (final it in sample) {
          final units = it.answerTiles;
          final word = units.join();
          final copies = 1 + (tokenCount[word.toLowerCase()] ?? 0);
          final abc = alphabet.contains(units[it.gapIndex])
              ? alphabet
              : <String>[...alphabet, units[it.gapIndex]];
          model.remove(units);
          wordLm.add(word, -copies);
          final lmScores = <double>[];
          final filled = List<String>.of(units);
          for (final a in abc) {
            filled[it.gapIndex] = a;
            lmScores.add(wordLm.score(filled.join()));
          }
          wordLm.add(word, copies);
          final feats = model.gapFeatures(units, it.gapIndex, abc);
          model.restore(units);
          final right = abc.indexOf(units[it.gapIndex]);
          var better = 0;
          var ties = 0;
          var worse = 0;
          for (var k = 0; k < lmScores.length; k++) {
            if (k == right) continue;
            if (lmScores[k] > lmScores[right] + 1e-9) {
              better++;
            } else if ((lmScores[k] - lmScores[right]).abs() <= 1e-9) {
              ties++;
            } else {
              worse++;
            }
          }
          final share = 1 / (ties + 1);
          double at(int k) =>
              (k > better && k <= better + ties + 1) ? share : 0;
          lmTotals['char-lm'] = (lmTotals['char-lm'] ?? 0) + at(1);
          lmTotals['char-lm-lowest'] =
              (lmTotals['char-lm-lowest'] ?? 0) + (worse == 0 ? share : 0);
          for (var k = 2; k <= 4; k++) {
            lmTotals['char-lm-rank$k'] =
                (lmTotals['char-lm-rank$k'] ?? 0) + at(k);
          }
          final cols = <List<double>>[
            for (var c = 0; c < 5; c++)
              zWithin(<double>[for (final f in feats) f[c]]),
            zWithin(lmScores),
          ];
          frows.add(<List<double>>[
            for (var k = 0; k < abc.length; k++)
              <double>[for (final c in cols) c[k]],
          ]);
          fcorrect.add(right);
        }
        solvers.addAll(totals);
        solvers.addAll(lmTotals);
        solvers['feature-classifier'] =
            crossFitAccuracy(frows, fcorrect) * sample.length;
        solvers['spelling-rules'] = rules;
      case 'F9':
        var good = 0.0;
        var anti = 0.0;
        var pairs = 0;
        final rng = math.Random(7);
        for (final it in sample) {
          good += matcherRight(it, cx.data.language, rng, anti: false);
          anti += matcherRight(it, cx.data.language, rng, anti: true);
          pairs += it.pairs.length;
        }
        trials = pairs;
        solvers['matcher'] = good;
        solvers['matcher-inverted'] = anti;
      case 'F1' || 'F14':
        final r = _yesNo(sample, pseudo, cx, model);
        auc = r.$1;
        solvers[r.$2] = r.$1;
        aucN1 = r.$3;
        aucN2 = r.$4;
      case 'F8' || 'F27':
        var total = 0.0;
        for (final it in sample) {
          total += _sentenceTiles(it, wordGrams2, suffixGrams2);
        }
        solvers['order-beam-solver'] = total;
    }
    var bestName = 'chance';
    var best = 0.0;
    for (final s in solvers.entries) {
      // Totals are summed over items (or pairs); an AUC is already a rate.
      final rate = auc != null ? s.value : s.value / trials;
      if (rate > best) {
        best = rate;
        bestName = s.key;
      }
    }
    out[e.key] = AuditClass(
      key: e.key,
      n: auc != null ? aucN1 : sample.length,
      accuracy: best,
      upper: auc != null
          ? aucUpper(best, aucN1, aucN2)
          : wilsonUpper(best, trials),
      bound: _bound(fmt, info),
      solver: bestName,
      solvers: <String, double>{
        for (final e in solvers.entries)
          e.key: auc != null ? e.value : e.value / trials,
      },
    );
  }
  return AuditReport(out);
}

/// The held-out score of [option]: [lm] without [option] itself.
double _heldOut(CharLm lm, String option) {
  lm.add(option, -1);
  final s = lm.score(option);
  lm.add(option, 1);
  return s;
}

/// Expected accuracy of a solver that drops the most similar option when it
/// looks like the prompt (similarity 0.3 or more) and picks among the rest.
double _eliminate(List<double> sim, int correct) {
  final best = sim.reduce(math.max);
  if (best < 0.3) return 1 / sim.length;
  final top = <int>[
    for (var i = 0; i < sim.length; i++)
      if ((sim[i] - best).abs() < 1e-9) i,
  ];
  if (top.length != 1) return 1 / sim.length;
  if (top.first == correct) return 0;
  return 1 / (sim.length - 1);
}

double _bound(String fmt, FormatInfo info) {
  switch (fmt) {
    case 'F9':
      return 0.35;
    case 'F1' || 'F14':
      return 0.60;
    case 'F6g':
      return 0.57;
    case 'F4':
      return 0.10 + 0.07;
    case 'F8' || 'F27':
      return 0.05 + 0.07;
    default:
      return info.admissionBound;
  }
}

double _maxSim(List<String> a, List<String> b, String language) {
  var best = 0.0;
  for (final x in a) {
    if (latinLetters(x).length < 4) continue;
    for (final y in b) {
      best = math.max(best, wordSimilarity(x, y, language));
    }
  }
  return best;
}

double _knownScore(
  List<String> promptWords,
  String option,
  Map<String, Set<String>> knownText,
  RegItem it,
  Set<String> knownIds,
) {
  // Words of the prompt the gamer knows must have their English in the
  // right option.
  final eng = glossWords(option).toSet();
  var s = 0.0;
  for (final w in promptWords) {
    final en = knownText[w.toLowerCase()];
    if (en == null) continue;
    if (knownIds.contains(it.cardId) && promptWords.length == 1) continue;
    if (en.any(eng.contains)) s += 1;
  }
  return s;
}

double _endingRule(String article, RegItem it, GenContext cx) {
  // The rule-follower's answer: the article of the gender the noun's ending
  // usually has. The item stores the right article; the rule scores 1 for the
  // article it would pick.
  final m = cx.genderArticle['m'];
  final word = it.prompt.replaceFirst('___ ', '');
  final units = tileUnits(word);
  if (units.isEmpty) return 0;
  final end = units.last;
  var mVotes = 0, fVotes = 0;
  for (final v in cx.vocab) {
    if (v.pos != 'noun' || v.units.last != end) continue;
    if (v.card.gender == 'm') mVotes++;
    if (v.card.gender == 'f') fVotes++;
  }
  final guessMasculine = mVotes >= fVotes;
  return (article == m) == guessMasculine ? 1.0 : 0.0;
}

Set<String> _spellings(String head) {
  final out = <String>{head};
  for (final base in <String>{
    head,
    head.replaceAll('tion', 'cion'),
    head.replaceAll('ph', 'f'),
    head.replaceAll('y', 'i'),
  }) {
    out.add(base);
    for (final end in const <String>[
      'o',
      'a',
      'e',
      'ar',
      'er',
      'ir',
      'ia',
      'io',
    ]) {
      out.add('$base$end');
    }
    if (base.length > 3) {
      out.add(base.substring(0, base.length - 1));
    }
  }
  return out;
}

/// The anagram solver: the most plausible word that can be built from the
/// tiles under the course's letter patterns without the target word. A search
/// cut short counts as solved (the conservative reading).
double _anagram(RegItem it, UnitModel model) {
  final answer = it.answerTiles;
  final n = answer.length;
  final tiles = it.tiles;
  model.remove(answer);
  var bestScore = double.negativeInfinity;
  var ties = 0;
  var targetFound = false;
  final used = List<bool>.filled(tiles.length, false);
  final path = <String>[];
  var visited = 0;
  var truncated = false;
  const maxVisits = 400000;
  void dfs() {
    if (truncated) return;
    if (visited++ > maxVisits) {
      truncated = true;
      return;
    }
    final p = path.length;
    if (p == n) {
      if (n >= 2 && model.count(path[n - 2], path[n - 1], r'$') <= 0) return;
      final s = model.score(path);
      final isTarget = _same(path, answer);
      if (s > bestScore + 1e-9) {
        bestScore = s;
        ties = 1;
        targetFound = isTarget;
      } else if ((s - bestScore).abs() <= 1e-9) {
        ties++;
        targetFound = targetFound || isTarget;
      }
      return;
    }
    final tried = <String>{};
    for (var i = 0; i < tiles.length; i++) {
      if (used[i] || !tried.add(tiles[i])) continue;
      if (p >= 1) {
        final a = p >= 2 ? path[p - 2] : '^';
        if (model.count(a, path[p - 1], tiles[i]) <= 0) continue;
      }
      used[i] = true;
      path.add(tiles[i]);
      dfs();
      path.removeLast();
      used[i] = false;
    }
  }

  dfs();
  model.restore(answer);
  if (truncated) return 1;
  if (!targetFound || ties == 0) return 0;
  return 1 / ties;
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// How many of the four pairs of a matching screen the matcher gets right
/// (best similarity first, or the least similar first when [anti]).
double matcherRight(
  RegItem it,
  String language,
  math.Random rng, {
  required bool anti,
}) {
  final prompts = [for (final p in it.pairs) p.$1];
  final meanings = [for (final p in it.pairs) p.$2];
  final sims = <(double, int, int)>[];
  for (var i = 0; i < prompts.length; i++) {
    for (var j = 0; j < meanings.length; j++) {
      final s = _maxSim(
        targetWords(prompts[i]),
        glossWords(meanings[j]),
        language,
      );
      sims.add(((anti ? -s : s) + rng.nextDouble() * 1e-6, i, j));
    }
  }
  sims.sort((a, b) => b.$1.compareTo(a.$1));
  final pi = <int>{};
  final pj = <int>{};
  var right = 0;
  for (final (_, i, j) in sims) {
    if (pi.contains(i) || pj.contains(j)) continue;
    pi.add(i);
    pj.add(j);
    if (i == j) right++;
  }
  return right.toDouble();
}

/// The best pseudoword detector: (oriented AUC, its name, real count,
/// pseudo count). Real words are scored without themselves, pseudowords
/// without the word they were made from.
(double, String, int, int) _yesNo(
  List<RegItem> real,
  List<RegItem> pseudo,
  GenContext cx,
  UnitModel model,
) {
  final byId = <String, VocabWord>{for (final v in cx.vocab) v.card.id: v};
  final reals = <RegItem>[
    for (final r in real)
      if (byId.containsKey(r.cardId)) r,
  ];
  if (reals.length < 2 || pseudo.length < 2) return (1, 'too-few', 0, 0);
  // (cue name -> scores of real, scores of pseudo)
  final cues = <String, (List<double>, List<double>)>{
    for (final n in <String>[
      'letter-patterns',
      'unit-pairs',
      'edges',
      'nearest-word',
      'length',
    ])
      n: (<double>[], <double>[]),
  };
  void score(List<String> units, String? leaveOutId, bool isReal) {
    final left = leaveOutId == null ? null : byId[leaveOutId]!.units;
    if (left != null) model.remove(left);
    final vals = <String, double>{
      'letter-patterns': model.triScore(units),
      'unit-pairs': model.biScore(units),
      'edges': model.edgeScore(units),
      'length': units.length.toDouble(),
    };
    if (left != null) model.restore(left);
    for (final e in vals.entries) {
      (isReal ? cues[e.key]!.$1 : cues[e.key]!.$2).add(e.value);
    }
    // The nearest other word: for a real word the nearest word that is not
    // itself, for a pseudoword the nearest word of the course.
    final d = isReal
        ? cx.nearestOther(byId[leaveOutId!]!)
        : cx.nearestToPseudo(units);
    (isReal ? cues['nearest-word']!.$1 : cues['nearest-word']!.$2).add(
      -d.toDouble(),
    );
  }

  for (final r in reals) {
    score(tileUnits(r.prompt), r.cardId, true);
  }
  for (final p in pseudo) {
    score(
      tileUnits(p.prompt),
      p.coCards.isEmpty ? null : p.coCards.first,
      false,
    );
  }
  var best = 0.5;
  var bestName = 'chance';
  for (final e in cues.entries) {
    var wins = 0.0;
    for (final a in e.value.$1) {
      for (final b in e.value.$2) {
        wins += a > b ? 1 : (a == b ? 0.5 : 0);
      }
    }
    final auc = wins / (e.value.$1.length * e.value.$2.length);
    final oriented = math.max(auc, 1 - auc);
    if (oriented > best) {
      best = oriented;
      bestName = auc >= 0.5 ? e.key : '${e.key}-inverted';
    }
  }
  return (best, bestName, reals.length, pseudo.length);
}

/// A beam-search order solver over sentence tiles, scoring word pairs and
/// ending pairs of the course without this sentence; it succeeds when its best
/// order is the sentence.
double _sentenceTiles(
  RegItem it,
  Map<String, int> wordPairs,
  Map<String, int> endingPairs,
) {
  final own = ownGrams(it.answerTiles, 2, lowerWord);
  final ownE = ownGrams(it.answerTiles, 2, suffixOf);
  double step(String prev, String next) {
    final w = '$prev|$next';
    final e = '${prev == '^' ? '^' : suffixOf(prev)}|${suffixOf(next)}';
    return math.log(1 + math.max(0, (wordPairs[w] ?? 0) - (own[w] ?? 0))) +
        0.5 * math.log(1 + math.max(0, (endingPairs[e] ?? 0) - (ownE[e] ?? 0)));
  }

  const width = 12;
  var beam = <(List<String>, List<String>, double)>[
    (<String>[], List<String>.of(it.tiles), 0),
  ];
  for (var k = 0; k < it.answerTiles.length; k++) {
    final next = <(List<String>, List<String>, double)>[];
    for (final (order, rest, score) in beam) {
      final prev = order.isEmpty ? '^' : order.last;
      final tried = <String>{};
      for (var i = 0; i < rest.length; i++) {
        if (!tried.add(rest[i])) continue;
        final r = List<String>.of(rest)..removeAt(i);
        next.add((<String>[...order, rest[i]], r, score + step(prev, rest[i])));
      }
    }
    next.sort((a, b) => b.$3.compareTo(a.$3));
    beam = next.take(width).toList();
  }
  if (beam.isEmpty) return 0;
  final bestScore = beam.first.$3;
  final top = beam.where((b) => (b.$3 - bestScore).abs() < 1e-9).toList();
  final hit = top.any((b) => _same(b.$1, it.answerTiles));
  return hit ? 1 / top.length : 0;
}
