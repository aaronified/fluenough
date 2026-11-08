import 'dart:math' as math;

/// The unit-pattern model of a course's words, built once, with the ability
/// to leave one word out. Shared by the audit's solvers and by the generators
/// that choose items the solvers cannot beat.
class UnitModel {
  UnitModel(Iterable<List<String>> words) {
    for (final w in words) {
      _add(w, 1);
    }
  }

  final Map<String, int> tri = <String, int>{};
  final Map<String, int> bi = <String, int>{};
  final Map<String, int> edge = <String, int>{};
  final Map<String, int> uni = <String, int>{};

  void _add(List<String> units, int by) {
    final u = <String>['^', ...units, r'$'];
    for (var i = 0; i + 2 < u.length; i++) {
      final k = u.sublist(i, i + 3).join('|');
      tri[k] = (tri[k] ?? 0) + by;
    }
    for (var i = 0; i + 1 < u.length; i++) {
      final k = u.sublist(i, i + 2).join('|');
      bi[k] = (bi[k] ?? 0) + by;
    }
    for (final x in units) {
      uni[x] = (uni[x] ?? 0) + by;
    }
    final e = '${units.first}|${units.last}';
    edge[e] = (edge[e] ?? 0) + by;
  }

  void remove(List<String> units) => _add(units, -1);
  void restore(List<String> units) => _add(units, 1);

  int count(String a, String b, String c) => tri['$a|$b|$c'] ?? 0;

  double _mean(List<String> u, Map<String, int> counts, int n) {
    var total = 0.0;
    var k = 0;
    for (var i = 0; i + n <= u.length; i++) {
      total += math.log(
        1 + math.max(0, counts[u.sublist(i, i + n).join('|')] ?? 0),
      );
      k++;
    }
    return k == 0 ? 0 : total / k;
  }

  double triScore(List<String> units) =>
      _mean(<String>['^', ...units, r'$'], tri, 3);
  double biScore(List<String> units) =>
      _mean(<String>['^', ...units, r'$'], bi, 2);
  double edgeScore(List<String> units) =>
      math.log(1 + math.max(0, edge['${units.first}|${units.last}'] ?? 0));
  double score(List<String> units) {
    final u = <String>['^', ...units, r'$'];
    var s = 0.0;
    for (var i = 0; i + 2 < u.length; i++) {
      s += math.log(1 + math.max(0, count(u[i], u[i + 1], u[i + 2])));
    }
    return s;
  }

  /// The cues a gap-filling solver may use, by name.
  static const List<String> gapCues = <String>[
    'letter-patterns',
    'unit-triples',
    'unit-pairs',
    'edges',
    'unit-frequency',
  ];

  /// How well each gap-filling solver does on the unit at [gap] of [units]
  /// among [alphabet]: for each cue, the solver that takes the highest
  /// scoring fill, the lowest, and the second, third and fourth highest (one
  /// that has learned that the right unit is never the top pick). The value
  /// is the expected accuracy (a tie among n fills is worth 1/n). Also, per
  /// cue, where the right unit stands as a fraction of the alphabet (0 the
  /// highest, 1 the lowest). The word must have been left out of the model
  /// ([remove]) by the caller.
  ({Map<String, double> accuracy, List<double> position}) gapSolvers(
    List<String> units,
    int gap,
    List<String> alphabet,
  ) {
    final accuracy = <String, double>{};
    final position = <double>[];
    double score(int cue, List<String> u) => switch (cue) {
      0 => this.score(u),
      1 => triScore(u),
      2 => biScore(u),
      3 => edgeScore(u),
      _ => math.log(1 + math.max(0, uni[u[gap]] ?? 0)),
    };
    final filled = List<String>.of(units);
    for (var cue = 0; cue < gapCues.length; cue++) {
      final right = score(cue, units);
      var better = 0;
      var ties = 0;
      var worse = 0;
      for (final a in alphabet) {
        if (a == units[gap]) continue;
        filled[gap] = a;
        final v = score(cue, filled);
        if (v > right + 1e-9) {
          better++;
        } else if ((v - right).abs() <= 1e-9) {
          ties++;
        } else {
          worse++;
        }
      }
      filled[gap] = units[gap];
      final name = gapCues[cue];
      final share = 1 / (ties + 1);
      // The right unit holds the places better+1 .. better+ties+1 from the
      // top.
      double at(int k) => (k > better && k <= better + ties + 1) ? share : 0;
      accuracy[name] = at(1);
      accuracy['$name-lowest'] = worse == 0 ? share : 0;
      for (var k = 2; k <= 4; k++) {
        accuracy['$name-rank$k'] = at(k);
      }
      final n = better + ties + worse;
      position.add(n == 0 ? 0.5 : (better + ties / 2) / n);
    }
    return (accuracy: accuracy, position: position);
  }

  /// For each fill of [alphabet] at [gap] of [units], the five cues' scores
  /// (in [gapCues] order). The word must have been left out of the model.
  List<List<double>> gapFeatures(
    List<String> units,
    int gap,
    List<String> alphabet,
  ) {
    final filled = List<String>.of(units);
    final out = <List<double>>[];
    for (final a in alphabet) {
      filled[gap] = a;
      out.add(<double>[
        score(filled),
        triScore(filled),
        biScore(filled),
        edgeScore(filled),
        math.log(1 + math.max(0, uni[a] ?? 0)),
      ]);
    }
    return out;
  }
}
