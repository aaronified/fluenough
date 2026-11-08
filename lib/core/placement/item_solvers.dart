import 'dart:math' as math;

import 'cognate_score.dart';
import 'item_generators.dart' show VocabWord, tileUnits;

// The scoring helpers of the admission audit's solvers, shared with the
// generators that choose distractors the solvers cannot use (build step 4b):
// an option the solvers score the same as the right one gives no cue.
//
// Pure Dart.

/// Expected accuracy of a solver that scores each option and picks the
/// highest (`high`) or the lowest (`low`); a tie among n options is worth 1/n.
({double high, double low}) expectedBoth(List<double> scores, int correct) {
  if (scores.isEmpty) return (high: 0, low: 0);
  double pick(bool highest) {
    final best = highest ? scores.reduce(math.max) : scores.reduce(math.min);
    var ties = 0;
    for (final s in scores) {
      if ((s - best).abs() < 1e-9) ties++;
    }
    return (scores[correct] - best).abs() < 1e-9 ? 1 / ties : 0;
  }

  return (high: pick(true), low: pick(false));
}

/// The n-gram keys of [tokens], padded with `^` at the start and `$` at the
/// end.
List<String> ngramKeys(List<String> tokens, int n) {
  final t = <String>[for (var i = 0; i < n - 1; i++) '^', ...tokens, r'$'];
  return <String>[
    for (var i = 0; i + n <= t.length; i++) t.sublist(i, i + n).join('|'),
  ];
}

Map<String, int> countGrams(
  Iterable<List<String>> sentences,
  int n,
  String Function(String) map,
) {
  final counts = <String, int>{};
  for (final s in sentences) {
    for (final k in ngramKeys(<String>[for (final w in s) map(w)], n)) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

/// The log-likelihood of [tokens] under [counts] without the item's own
/// sentence ([own], the grams of the true sentence, counted once there).
double ngramScore(
  List<String> tokens,
  int n,
  Map<String, int> counts,
  Map<String, int> own,
  String Function(String) map,
) {
  var s = 0.0;
  for (final k in ngramKeys(<String>[for (final w in tokens) map(w)], n)) {
    s += math.log(1 + math.max(0, (counts[k] ?? 0) - (own[k] ?? 0)));
  }
  return s;
}

Map<String, int> ownGrams(
  List<String> tokens,
  int n,
  String Function(String) map,
) {
  final own = <String, int>{};
  for (final k in ngramKeys(<String>[for (final w in tokens) map(w)], n)) {
    own[k] = (own[k] ?? 0) + 1;
  }
  return own;
}

String lowerWord(String w) => w.toLowerCase();

String suffixOf(String word) {
  final u = tileUnits(word.toLowerCase());
  return u.length < 2 ? word.toLowerCase() : u.sublist(u.length - 2).join();
}

/// The context cues of a course's sentences: word pairs and ending pairs and
/// triples, each scored without the item's own sentence.
class ContextCues {
  ContextCues(Iterable<List<String>> sentences) {
    final all = <List<String>>[for (final s in sentences) s];
    _word2 = countGrams(all, 2, lowerWord);
    _suffix2 = countGrams(all, 2, suffixOf);
    _suffix3 = countGrams(all, 3, suffixOf);
  }

  late final Map<String, int> _word2;
  late final Map<String, int> _suffix2;
  late final Map<String, int> _suffix3;

  /// The names of the cues, in the order [scores] gives them.
  static const List<String> names = <String>[
    'word-pairs',
    'ending-pairs',
    'ending-triples',
  ];

  /// The three cues' scores of [words], with the grams of [truth] (the true
  /// sentence) counted once less.
  List<double> scores(List<String> words, List<String> truth) {
    final t = <String>[for (final w in truth) w.toLowerCase()];
    final w = <String>[for (final x in words) x.toLowerCase()];
    return <double>[
      ngramScore(w, 2, _word2, ownGrams(t, 2, lowerWord), lowerWord),
      ngramScore(w, 2, _suffix2, ownGrams(t, 2, suffixOf), suffixOf),
      ngramScore(w, 3, _suffix3, ownGrams(t, 3, suffixOf), suffixOf),
    ];
  }
}

/// Whether no solver of [cues] (one score list per option, per cue) can tell
/// option [correct] from the others: the right option is neither the unique
/// highest nor the unique lowest of any cue, and no tie makes it likelier
/// than chance.
bool cuesNeutral(List<List<double>> perOption, int correct) {
  final n = perOption.length;
  if (n < 2) return false;
  for (var c = 0; c < perOption.first.length; c++) {
    final r = expectedBoth(<double>[for (final o in perOption) o[c]], correct);
    if (r.high > 1 / n + 1e-9 || r.low > 1 / n + 1e-9) return false;
  }
  return true;
}

/// What a gamer that knows the first words of the path knows: for each of the
/// word's spellings, its English words.
Map<String, Set<String>> buildKnownText(Iterable<VocabWord> early) {
  final out = <String, Set<String>>{};
  for (final v in early) {
    final eng = <String>{v.glossHead, ...glossWords(v.gloss)}..remove('');
    out[v.roman.toLowerCase()] = eng;
    out[v.word.toLowerCase()] = eng;
  }
  return out;
}

/// The highest cognate-like similarity of a word of [a] to a word of [b].
double maxSimilarity(List<String> a, List<String> b, String language) {
  var best = 0.0;
  for (final x in a) {
    if (latinLetters(x).length < 4) continue;
    for (final y in b) {
      best = math.max(best, wordSimilarity(x, y, language));
    }
  }
  return best;
}

/// How many words of the prompt the gamer knows have their English in
/// [option].
double knownWordScore(
  List<String> promptWords,
  String option,
  Map<String, Set<String>> knownText,
) {
  final eng = glossWords(option).toSet();
  var s = 0.0;
  for (final w in promptWords) {
    final en = knownText[w.toLowerCase()];
    if (en == null) continue;
    if (en.any(eng.contains)) s += 1;
  }
  return s;
}

/// The words of an English option, lowercased, as a set.
Set<String> optionWords(String option) => <String>{
  for (final m in RegExp(r"[A-Za-z']+").allMatches(option.toLowerCase())) m[0]!,
};

/// For each option, minus its summed word-set distance to the others: the
/// "centre of the options" cue (an option that is the one-word contrast of
/// all the others is the right one).
List<double> centrality(List<String> options) {
  final sets = <Set<String>>[for (final o in options) optionWords(o)];
  double dist(Set<String> a, Set<String> b) {
    final union = a.union(b).length;
    return union == 0 ? 0 : 1 - a.intersection(b).length / union;
  }

  return <double>[
    for (var i = 0; i < sets.length; i++)
      -<double>[
        for (var j = 0; j < sets.length; j++)
          if (j != i) dist(sets[i], sets[j]),
      ].fold<double>(0, (a, b) => a + b),
  ];
}

/// Where option 0 (the right one) stands among [scores]: 0 the unique
/// highest, 1 the unique lowest, 2 strictly between, -1 tied with another
/// (which gives a solver a share of the item).
int rankPattern(List<double> scores) {
  final right = scores.first;
  var above = 0;
  var below = 0;
  var equal = 0;
  for (var i = 1; i < scores.length; i++) {
    if ((scores[i] - right).abs() < 1e-9) {
      equal++;
    } else if (scores[i] > right) {
      above++;
    } else {
      below++;
    }
  }
  if (equal > 0) return -1;
  if (above == 0) return 0;
  if (below == 0) return 1;
  return 2;
}

/// Hands out rank patterns in the proportions a class needs so that a solver
/// that picks the highest or the lowest scoring option, or drops the most
/// similar one, gets a quarter of four options: a quarter of the items with
/// the right option on top, a quarter at the bottom, half between. The next
/// pattern is the most behind its share.
class PatternBalance {
  final List<int> _given = <int>[0, 0, 0];
  static const List<double> _share = <double>[0.25, 0.25, 0.5];

  /// The patterns, most behind first.
  List<int> order() {
    final n = _given.fold<int>(0, (a, b) => a + b) + 1;
    final idx = <int>[0, 1, 2]
      ..sort(
        (a, b) =>
            (_given[a] - _share[a] * n).compareTo(_given[b] - _share[b] * n),
      );
    return idx;
  }

  void record(int pattern) => _given[pattern]++;

  /// Whether one more item of [pattern] keeps the proportions (with a slack
  /// of one item, so the first items of a class are not starved).
  bool allows(int pattern) {
    final n = _given.fold<int>(0, (a, b) => a + b) + 1;
    return _given[pattern] + 1 <= _share[pattern] * n + 2;
  }
}

/// Keeps, for each cue of a two-option item, how often the right option
/// scored higher and lower than the wrong one, and accepts an item only if it
/// leaves the cues balanced (within one item): a solver that picks the higher
/// or the lower scoring option then gets half, and no more.
class DirectionBalance {
  DirectionBalance(int cues)
    : _higher = List<int>.filled(cues, 0),
      _lower = List<int>.filled(cues, 0);

  final List<int> _higher;
  final List<int> _lower;

  /// The direction of each cue for scores [right] and [wrong]: 1 the right
  /// one higher, -1 lower, 0 tied.
  static List<int> directions(List<double> right, List<double> wrong) => <int>[
    for (var c = 0; c < right.length; c++)
      (right[c] - wrong[c]).abs() < 1e-9 ? 0 : (right[c] > wrong[c] ? 1 : -1),
  ];

  bool allows(List<int> dirs) {
    for (var c = 0; c < dirs.length; c++) {
      if (dirs[c] == 1 && _higher[c] + 1 - _lower[c] > 1) return false;
      if (dirs[c] == -1 && _lower[c] + 1 - _higher[c] > 1) return false;
    }
    return true;
  }

  void record(List<int> dirs) {
    for (var c = 0; c < dirs.length; c++) {
      if (dirs[c] == 1) _higher[c]++;
      if (dirs[c] == -1) _lower[c]++;
    }
  }
}

/// The pattern of option 0 among [scores] for balancing: [rankPattern], or 3
/// when all options score alike (a solver then has a quarter of four).
int balancePattern(List<double> scores) {
  final first = scores.first;
  if (scores.every((v) => (v - first).abs() < 1e-9)) return 3;
  return rankPattern(scores);
}

/// The items of [patterns] (one list of per-cue patterns each) to keep so
/// that, in every cue, at most a quarter of the items have the right option
/// highest and at most a quarter lowest: the last offenders are dropped.
List<int> balancedKeep(List<List<int>> patterns) {
  final keep = <int>[for (var i = 0; i < patterns.length; i++) i];
  if (patterns.isEmpty) return keep;
  var changed = true;
  while (changed && keep.isNotEmpty) {
    changed = false;
    final n = keep.length;
    for (var c = 0; c < patterns.first.length && !changed; c++) {
      for (var pat = 0; pat < 2 && !changed; pat++) {
        final over = <int>[
          for (final i in keep)
            if (patterns[i][c] == pat) i,
        ];
        if (over.length * 4 > n) {
          keep.remove(over.last);
          changed = true;
        }
      }
    }
  }
  return keep;
}
