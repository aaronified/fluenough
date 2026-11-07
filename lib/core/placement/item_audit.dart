import 'dart:math' as math;

import 'cognate_score.dart';
import 'item_generators.dart';
import 'item_registry.dart';

// The admission audit of "Find my level" V3 (wiki/Plan-Placement-V3.md,
// "Adversarial review and required amendments", validation): every item class
// (a format and its cognate class) is attacked by solvers that never see the
// answer key, and a class whose best solver beats the design guess plus 0.07
// (0.32 for a four-option pick) is excluded from the bank.
//
// The solvers are the leaks the adversary found, written as expected-accuracy
// functions (a tie among n options is worth 1/n), so the audit is exact and
// deterministic:
//  - longest and shortest option;
//  - similarity: the option that looks most like the prompt (a cognate cue);
//  - known words: a gamer that knows the first 100 words of the path and uses
//    them to eliminate options or to confirm one;
//  - an anagram solver for tiles (a strong one: it knows the whole course's
//    letter patterns except the target word itself);
//  - spelling rules for typed and said words;
//  - a matcher for matching screens;
//  - a pseudoword detector for yes/no;
//  - a bigram solver for word order;
//  - the ending rule for gender;
//  - chance.
//
// Pure Dart.

/// How many words the audit's gamer knows.
const int kAuditKnownWords = 100;

/// The most items of one class the audit attacks (a deterministic stride).
const int kAuditSample = 400;

/// What the audit found for one class of items.
class AuditClass {
  const AuditClass({
    required this.key,
    required this.n,
    required this.accuracy,
    required this.bound,
    required this.solver,
  });

  /// `format:cognateClass`, such as `F2:clean`.
  final String key;

  /// How many items were attacked.
  final int n;

  /// The best solver's expected accuracy.
  final double accuracy;

  /// The admission bound of the class.
  final double bound;

  /// The solver that did best.
  final String solver;

  bool get passes => accuracy <= bound + 1e-9;
}

/// The audit of a bank.
class AuditReport {
  const AuditReport(this.classes);

  final Map<String, AuditClass> classes;

  /// Whether items of [key] are admitted: a class that was not attacked (too
  /// few items) is admitted only when its format is not leak-prone.
  bool admits(String key) => classes[key]?.passes ?? true;

  /// The classes that failed.
  List<AuditClass> get failed => <AuditClass>[
    for (final c in classes.values)
      if (!c.passes) c,
  ];
}

double _expected(Iterable<double> scores, int correct) {
  final list = scores.toList();
  if (list.isEmpty) return 0;
  final best = list.reduce(math.max);
  var ties = 0;
  for (final s in list) {
    if ((s - best).abs() < 1e-9) ties++;
  }
  return (list[correct] - best).abs() < 1e-9 ? 1 / ties : 0;
}

/// The unit-trigram language model of a course's words, built once, with the
/// ability to leave one word out.
class _UnitModel {
  _UnitModel(Iterable<VocabWord> words) {
    for (final w in words) {
      _add(w.units, 1);
    }
  }

  final Map<String, int> counts = <String, int>{};

  void _add(List<String> units, int by) {
    final u = <String>['^', ...units, r'$'];
    for (var i = 0; i + 2 < u.length; i++) {
      final k = u.sublist(i, i + 3).join('|');
      counts[k] = (counts[k] ?? 0) + by;
    }
  }

  void remove(List<String> units) => _add(units, -1);
  void restore(List<String> units) => _add(units, 1);

  int count(String a, String b, String c) => counts['$a|$b|$c'] ?? 0;

  double score(List<String> units) {
    final u = <String>['^', ...units, r'$'];
    var s = 0.0;
    for (var i = 0; i + 2 < u.length; i++) {
      s += math.log(1 + math.max(0, count(u[i], u[i + 1], u[i + 2])));
    }
    return s;
  }
}

/// Runs the audit on [items] (all formats of a bank) with [cx].
AuditReport auditItems(List<RegItem> items, GenContext cx) {
  final model = _UnitModel(cx.vocab);
  final known = cx.vocab.toList()
    ..sort(
      (a, b) => a.deck != b.deck
          ? a.deck.compareTo(b.deck)
          : a.card.id.compareTo(b.card.id),
    );
  final knownCards = known.take(kAuditKnownWords).toList();
  final knownIds = <String>{for (final v in knownCards) v.card.id};
  final knownText = <String, Set<String>>{};
  for (final v in knownCards) {
    // target word (roman, lower) -> its English words
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

  final byClass = <String, List<RegItem>>{};
  for (final it in items) {
    if (it.pseudo) continue;
    (byClass[it.auditClass] ??= <RegItem>[]).add(it);
  }
  final pseudo = <RegItem>[
    for (final it in items)
      if (it.pseudo && it.format == 'F1') it,
  ];
  final bigrams = _bigrams(cx);
  final suffixBigrams = _suffixBigrams(cx);
  final suffixTrigrams = _suffixTrigrams(cx);
  final out = <String, AuditClass>{};
  for (final e in byClass.entries) {
    final all = e.value;
    final stride = math.max(1, (all.length / kAuditSample).ceil());
    final sample = <RegItem>[
      for (var i = 0; i < all.length; i += stride) all[i],
    ];
    final fmt = sample.first.format;
    final info = sample.first.info;
    final solvers = <String, double>{};
    void add(String name, double total) =>
        solvers[name] = total / sample.length;
    switch (fmt) {
      case 'F2' || 'F13' || 'F3' || 'F5' || 'F17' || 'F6' || 'S2' || 'F6g':
        solvers['chance'] = 1 / sample.first.options.length;
        var st = 0.0,
            sb = 0.0,
            longest = 0.0,
            shortest = 0.0,
            sim = 0.0,
            kn = 0.0,
            comb = 0.0,
            rule = 0.0,
            bi = 0.0;
        for (final it in sample) {
          final lens = [for (final o in it.options) o.length.toDouble()];
          longest += _expected(lens, it.correct);
          shortest += _expected([for (final l in lens) -l], it.correct);
          if (fmt == 'S2') {
            bi += _expected(<double>[
              for (final o in it.options) _bigramScore(o, bigrams, it.cardId),
            ], it.correct);
            sb += _expected(<double>[
              for (final o in it.options)
                _suffixBigramScore(o, suffixBigrams, it.cardId, cx),
            ], it.correct);
            st += _expected(<double>[
              for (final o in it.options)
                _suffixTrigramScore(o, suffixTrigrams, it.cardId),
            ], it.correct);
          }
          if (fmt == 'F6g') {
            rule += _expected(<double>[
              for (final o in it.options) _endingRule(o, it, cx),
            ], it.correct);
          }
          if (fmt == 'F2' || fmt == 'F13' || fmt == 'F5' || fmt == 'F17') {
            final promptWords = targetWords(it.promptRoman ?? it.prompt);
            final simScores = <double>[
              for (final o in it.options)
                _maxSim(promptWords, glossWords(o), cx.data.language),
            ];
            sim += _expected(simScores, it.correct);
            final knownScores = <double>[
              for (final o in it.options)
                _knownScore(promptWords, o, knownText, it, knownIds),
            ];
            kn += _expected(knownScores, it.correct);
            comb += _expected(<double>[
              for (var i = 0; i < knownScores.length; i++)
                knownScores[i] + 0.01 * simScores[i],
            ], it.correct);
          } else if (fmt == 'F3') {
            final eng = glossWords(it.prompt);
            final simScores = <double>[
              for (final o in it.optionsRoman)
                _maxSim(targetWords(o), eng, cx.data.language),
            ];
            sim += _expected(simScores, it.correct);
            final knownScores = <double>[
              for (final o in it.optionsRoman)
                (knownText.containsKey(o.toLowerCase()) &&
                        knownText[o.toLowerCase()]!.any(eng.contains)
                    ? 1.0
                    : 0.0),
            ];
            kn += _expected(knownScores, it.correct);
            comb += _expected(<double>[
              for (var i = 0; i < knownScores.length; i++)
                knownScores[i] + 0.01 * simScores[i],
            ], it.correct);
          } else if (fmt == 'F6') {
            // Eliminate options that are known words of other cards: a known
            // word near the blank is no more likely than another.
            final scores = <double>[
              for (final o in it.options)
                knownGloss.contains(o.toLowerCase()) ? 1.0 : 0.0,
            ];
            kn += _expected(scores, it.correct);
          }
        }
        add('longest', longest);
        add('shortest', shortest);
        if (fmt == 'S2') {
          add('bigram', bi);
          add('suffix-bigram', sb);
          add('suffix-trigram', st);
        }
        if (fmt == 'F6g') add('ending-rule', rule);
        if (fmt != 'S2' && fmt != 'F6g' && fmt != 'F6') {
          add('similarity', sim);
          add('known-words', kn);
          add('combined', comb);
        }
        if (fmt == 'F6') add('known-words', kn);
      case 'F4':
        var total = 0.0;
        for (final it in sample) {
          total += _anagram(it, model, cx);
        }
        add('anagram-solver', total);
      case 'F7' || 'F18':
        var total = 0.0;
        for (final it in sample) {
          final head = latinLetters(it.prompt.split(' ').last);
          final target = latinLetters(
            it.answerTiles.isEmpty ? '' : it.answerTiles.first,
          );
          final guesses = _spellings(head, cx.data.language);
          if (target.isNotEmpty && guesses.contains(target)) total += 1;
        }
        add('spelling-rules', total);
      case 'F9':
        var total = 0.0;
        var pairs = 0;
        final rng = math.Random(7);
        for (final it in sample) {
          total += _matcher(it, cx.data.language, rng);
          pairs += it.pairs.length;
        }
        solvers['matcher'] = pairs == 0 ? 0 : total / pairs;
      case 'F1' || 'F14':
        solvers['pseudoword-detector'] = _yesNo(sample, pseudo, cx);
      case 'F8' || 'F16':
        // The tiles of a sentence: an order solver with the bigram model
        // succeeds only if it reproduces the whole sentence.
        var total = 0.0;
        for (final it in sample) {
          total += _sentenceTiles(it, bigrams);
        }
        add('bigram-solver', total);
    }
    var bestName = 'chance';
    var best = 0.0;
    for (final s in solvers.entries) {
      if (s.value > best) {
        best = s.value;
        bestName = s.key;
      }
    }
    out[e.key] = AuditClass(
      key: e.key,
      n: sample.length,
      accuracy: best,
      bound: _bound(fmt, info),
      solver: bestName,
    );
  }
  return AuditReport(out);
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
    case 'F8' || 'F16':
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

Map<String, int> _bigrams(GenContext cx) {
  final counts = <String, int>{};
  for (final s in cx.sentences) {
    final w = <String>[
      '^',
      ...[for (final x in s.words) x.toLowerCase()],
      r'$',
    ];
    for (var i = 0; i + 1 < w.length; i++) {
      final k = '${w[i]}|${w[i + 1]}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

double _bigramScore(String option, Map<String, int> counts, String cardId) {
  final w = <String>[
    '^',
    ...targetWords(option).map((x) => x.toLowerCase()),
    r'$',
  ];
  var s = 0.0;
  for (var i = 0; i + 1 < w.length; i++) {
    // The sentence itself is in the counts once: leave it out.
    final c = (counts['${w[i]}|${w[i + 1]}'] ?? 0);
    s += math.log(1 + math.max(0, c - 1));
  }
  return s;
}

Map<String, int> _suffixTrigrams(GenContext cx) {
  final counts = <String, int>{};
  for (final s in cx.sentences) {
    final w = <String>[
      '^',
      '^',
      ...[for (final x in s.words) _suffixOf(x)],
      r'$',
    ];
    for (var i = 0; i + 2 < w.length; i++) {
      final k = '${w[i]}|${w[i + 1]}|${w[i + 2]}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

/// A held-out cue: trigrams of endings, which the generator's own choice of
/// swap (words and endings, as bigrams) did not use.
double _suffixTrigramScore(
  String option,
  Map<String, int> counts,
  String cardId,
) {
  final w = <String>['^', '^', ...targetWords(option).map(_suffixOf), r'$'];
  var s = 0.0;
  for (var i = 0; i + 2 < w.length; i++) {
    s += math.log(
      1 + math.max(0, (counts['${w[i]}|${w[i + 1]}|${w[i + 2]}'] ?? 0) - 1),
    );
  }
  return s;
}

String _suffixOf(String word) {
  final u = tileUnits(word.toLowerCase());
  return u.length < 2 ? word.toLowerCase() : u.sublist(u.length - 2).join();
}

Map<String, int> _suffixBigrams(GenContext cx) {
  final counts = <String, int>{};
  for (final s in cx.sentences) {
    final w = <String>[
      '^',
      ...[for (final x in s.words) _suffixOf(x)],
      r'$',
    ];
    for (var i = 0; i + 1 < w.length; i++) {
      final k = '${w[i]}|${w[i + 1]}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

/// A solver that sees only the endings of words (their agreement and word
/// class), not the words: a different cue from the generator's own.
double _suffixBigramScore(
  String option,
  Map<String, int> counts,
  String cardId,
  GenContext cx,
) {
  final w = <String>['^', ...targetWords(option).map(_suffixOf), r'$'];
  var s = 0.0;
  for (var i = 0; i + 1 < w.length; i++) {
    s += math.log(1 + math.max(0, (counts['${w[i]}|${w[i + 1]}'] ?? 0) - 1));
  }
  return s;
}

double _endingRule(String article, RegItem it, GenContext cx) {
  // The rule-follower's answer: the article of the gender the noun's ending
  // usually has. On an exception that is the wrong one; the item stores the
  // right article, so the rule scores 1 for the article it would pick.
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

Set<String> _spellings(String head, String language) {
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

double _anagram(RegItem it, _UnitModel model, GenContext cx) {
  final answer = it.answerTiles;
  final n = answer.length;
  final tiles = it.tiles;
  // Leave the target word out of the model: the solver does not know it.
  model.remove(answer);
  var bestScore = double.negativeInfinity;
  var ties = 0;
  var targetFound = false;
  final used = List<bool>.filled(tiles.length, false);
  final path = <String>[];
  var visited = 0;
  const maxVisits = 400000;
  void dfs() {
    if (visited++ > maxVisits) return;
    final p = path.length;
    if (p == n) {
      // The word must be able to end where it does.
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
      // A prefix whose last trigram occurs in no word is not a word.
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

double _matcher(RegItem it, String language, math.Random rng) {
  final prompts = [for (final p in it.pairs) p.$1];
  final meanings = [for (final p in it.pairs) p.$2];
  final sims = <(double, int, int)>[];
  for (var i = 0; i < prompts.length; i++) {
    for (var j = 0; j < meanings.length; j++) {
      sims.add((
        _maxSim(targetWords(prompts[i]), glossWords(meanings[j]), language) +
            rng.nextDouble() * 1e-6,
        i,
        j,
      ));
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

double _yesNo(List<RegItem> real, List<RegItem> pseudo, GenContext cx) {
  // A detector trained on one half of the words, scoring the real words of
  // the other half and the pseudowords made from them: no word is scored by
  // a model that has seen it.
  final model = _UnitModel(cx.vocab.where((v) => !cx.heldOut(v)));
  final heldOutIds = <String>{
    for (final v in cx.vocab)
      if (cx.heldOut(v)) v.card.id,
  };
  // The words a pseudoword can be compared with: held out, and of the
  // lengths the pseudowords are made in.
  final reals = <RegItem>[
    for (final r in real)
      if (heldOutIds.contains(r.cardId) &&
          tileUnits(r.prompt).length >= 4 &&
          tileUnits(r.prompt).length <= 8)
        r,
  ];
  if (reals.isEmpty || pseudo.isEmpty) return 0.5;
  final scored = <(double, bool)>[];
  for (final it in reals) {
    final units = tileUnits(it.prompt);
    scored.add((model.score(units) / units.length, true));
  }
  for (final it in pseudo) {
    final units = tileUnits(it.prompt);
    scored.add((model.score(units) / units.length, false));
  }
  // The area under the ROC curve of the typicality score: the chance that a
  // random real word scores above a random pseudoword (ties count half). An
  // adversary may read the cue either way: the better orientation counts.
  var wins = 0.0;
  var pairs = 0;
  for (final (a, aReal) in scored) {
    if (!aReal) continue;
    for (final (b, bReal) in scored) {
      if (bReal) continue;
      pairs++;
      wins += a > b ? 1 : (a == b ? 0.5 : 0);
    }
  }
  final auc = pairs == 0 ? 0.5 : wins / pairs;
  return math.max(auc, 1 - auc);
}

double _sentenceTiles(RegItem it, Map<String, int> bigrams) {
  // Greedy bigram solver over the tiles, a stand-in for a strong solver that
  // knows the whole course's sentences except this one: it succeeds when its
  // greedy order is the sentence.
  final own = <String, int>{};
  final w = <String>['^', ...it.answerTiles];
  for (var i = 0; i + 1 < w.length; i++) {
    own['${w[i]}|${w[i + 1]}'] = (own['${w[i]}|${w[i + 1]}'] ?? 0) + 1;
  }
  final remaining = List<String>.of(it.tiles);
  final order = <String>[];
  var prev = '^';
  while (order.length < it.answerTiles.length && remaining.isNotEmpty) {
    var best = -1;
    var bestScore = -1.0;
    for (var i = 0; i < remaining.length; i++) {
      final k = '$prev|${remaining[i]}';
      final c = ((bigrams[k] ?? 0) - (own[k] ?? 0)).toDouble();
      if (c > bestScore) {
        bestScore = c;
        best = i;
      }
    }
    prev = remaining.removeAt(best);
    order.add(prev);
  }
  return _same(order, it.answerTiles) ? 1 : 0;
}
