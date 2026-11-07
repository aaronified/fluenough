import 'dart:math' as math;

// The assurance model of "Find my level" (wiki/Plan-Placement-V2.md,
// section 4, agreed by the owner 2026-11-05): a Bayesian update over twelve
// classes of "how much of the path the learner knows", for one skill.
//
// Pure Dart, no Flutter, no clock, no randomness: the same answers always
// give the same numbers. Nothing here is wired into a screen or into the
// placement that exists today (lib/app/placement*.dart).

/// The kinds of question the model knows, with their slip rate (a learner who
/// knows the deck still misses) and guess rate (a learner who does not know it
/// still answers right), from the table of section 4.2 of the plan. These are
/// defaults chosen by feel (the plan's open question 1), kept in one place.
enum PlacementQuestionKind {
  /// A four-option pick that tests one skill.
  pickOne(0.05, 0.25),

  /// A four-option pick that needs several skills at once.
  pickMany(0.10, 0.25),

  /// A two-option pick (a minimal pair).
  pair(0.05, 0.50),

  /// Say the meaning in English (the English recogniser is reliable).
  english(0.10, 0.03),

  /// Build a sentence with tiles.
  tilesSentence(0.10, 0.05),

  /// Build a short word with tiles.
  tilesWord(0.05, 0.10),

  /// Say the taught word.
  say(0.15, 0.03);

  const PlacementQuestionKind(this.slip, this.guess);

  /// P(wrong) for a learner who knows the deck.
  final double slip;

  /// P(right) for a learner who does not know the deck.
  final double guess;

  /// What a right answer multiplies the odds by, `(1 - s) / g`.
  double get oddsPerRight => (1 - slip) / guess;

  /// The slip of the credit posterior (plan section 13, "Make or break",
  /// point 4): how fast a true knower is credited; it plays no part in the
  /// guarantee.
  double get creditSlip => switch (this) {
    pickOne || pickMany => 0.15,
    pair => 0.10,
    english => 0.15,
    tilesSentence => 0.15,
    tilesWord => 0.10,
    say => 0.20,
  };

  /// The base guess of a question of this kind with no cue: `1/k` for a pick
  /// of [options] (four when not given), and the kind's own for the rest.
  double creditBase([int? options]) => switch (this) {
    pickOne || pickMany => 1 / (options == null || options < 2 ? 4 : options),
    pair => 0.50,
    english => 0.03,
    say => 0.03,
    tilesWord => 0.10,
    tilesSentence => 0.05,
  };
}

/// The margin added to a question's base guess: knowledge that is not exactly
/// a prefix of the path, and a distractor ruled out from what is known.
const double creditKappa = 0.10;

/// The chance the credited level may be above what the learner knows.
const double creditAlpha = 0.01;

/// The hypothesis space of one skill: `none`, then the levels
/// `l_k = round(k x (N - 1) / parts)` for k = 0 to `parts`, where
/// `parts = min(10, N)` (plan, section 4.1, point 1). A class says "the
/// learner knows every deck up to its level and none above".
///
/// Class 0 is `none`; class `i` (1 and up) has level `levels[i - 1]`; the
/// last class is the whole path, the last deck included.
class PlacementLevels {
  PlacementLevels._(this.deckCount, this.levels);

  /// The levels of a path of [deckCount] decks (one at least).
  ///
  /// A short path would round to the same deck twice (two classes with one
  /// level cannot be told apart, and the run would never reach 95%), so equal
  /// levels are merged: the classes are `none` and the distinct levels. A
  /// path of 11 decks or more has ten distinct tenths, as the plan says; one
  /// deck has `none` and one level; two have `none`, 0 and 1.
  ///
  /// [maxParts] is how many parts the path is cut into at most: 10 for the
  /// V2 model (the default), 20 for the joint model of V3.
  factory PlacementLevels(int deckCount, {int maxParts = 10}) {
    final decks = deckCount < 1 ? 1 : deckCount;
    final parts = math.min(maxParts < 1 ? 1 : maxParts, decks);
    final span = decks - 1;
    final levels = <int>[];
    for (var k = 0; k <= parts; k++) {
      // Rounded half up, in integers, so every platform agrees.
      final level = (2 * k * span + parts) ~/ (2 * parts);
      if (levels.isEmpty || level > levels.last) levels.add(level);
    }
    return PlacementLevels._(decks, List<int>.unmodifiable(levels));
  }

  /// How many decks the path has up to B1.
  final int deckCount;

  /// How many parts the path is cut into: one fewer than the levels (10 for
  /// a path of 11 decks or more).
  int get parts => levels.length - 1;

  /// The deck index of each level, ascending (`l_0` to `l_parts`).
  final List<int> levels;

  /// `none` plus one class per level.
  int get classCount => levels.length + 1;

  /// The class of the whole path.
  int get topClass => levels.length;

  /// The last deck's index.
  int get lastDeck => deckCount - 1;

  /// The deck index class [c] knows up to, or -1 for `none`.
  int levelOf(int c) => c == 0 ? -1 : levels[c - 1];

  /// The decks a probe at [deck] draws from (plan section 13, point 13): the
  /// band of the class whose level is the first at or above [deck],
  /// `(l_(k-1), l_k]`; the first band starts at deck 0. Any deck of the band
  /// is full evidence for that class.
  ({int from, int to}) bandOf(int deck) {
    var k = 0;
    while (k < levels.length - 1 && levels[k] < deck) {
      k++;
    }
    return (from: k == 0 ? 0 : levels[k - 1] + 1, to: levels[k]);
  }

  /// Whether a learner of class [c] knows the deck at index [deck].
  bool knows(int c, int deck) => c > 0 && levels[c - 1] >= deck;

  /// The position of class [c] on the scale of ten tenths of the path.
  double tenthOf(int c) => parts == 0 ? 10 : (c - 1) * 10 / parts;
}

/// The probabilities of the classes of one skill, given the answers so far.
/// Immutable: [update] returns a new one.
class PlacementPosterior {
  /// A posterior over [levels] from unnormalised [weights].
  PlacementPosterior(this.levels, List<double> weights)
    : probabilities = _normalised(weights);

  /// "No opinion": every class equally likely (the reporting prior).
  factory PlacementPosterior.flat(PlacementLevels levels) =>
      PlacementPosterior(levels, List<double>.filled(levels.classCount, 1));

  final PlacementLevels levels;

  /// One probability per class, summing to 1.
  final List<double> probabilities;

  static List<double> _normalised(List<double> weights) {
    final total = weights.fold<double>(0, (sum, w) => sum + w);
    return List<double>.unmodifiable(<double>[
      for (final w in weights) w / total,
    ]);
  }

  /// The posterior after one answer to a question of [kind] asked at [deck].
  ///
  /// A class that knows the deck answers right with `1 - slip`, any other
  /// with `guess`; the likelihood of the answer is that, or its complement
  /// for a miss. [missWeight] below 1 raises the likelihood of a miss to that
  /// power: 0.5 is the half strength of a composite miss (section 4.1,
  /// point 4).
  PlacementPosterior update({
    required int deck,
    required PlacementQuestionKind kind,
    required bool correct,
    double missWeight = 1,
    double? guess,
  }) {
    // A question whose options give the answer away (see guessability.dart)
    // is not as hard to guess as its kind says: [guess] raises the guess
    // rate, never lowers it.
    final guessRate = guess == null ? kind.guess : math.max(kind.guess, guess);
    final next = <double>[];
    for (var c = 0; c < probabilities.length; c++) {
      final right = levels.knows(c, deck) ? 1 - kind.slip : guessRate;
      final likelihood = correct
          ? right
          : math.pow(1 - right, missWeight).toDouble();
      next.add(probabilities[c] * likelihood);
    }
    return PlacementPosterior(levels, next);
  }

  /// The posterior after one answer in the credit posterior (plan section 13,
  /// "Make or break"): a class that knows [deck] answers right with `1 - slip`,
  /// any other with the guess floor `min(1, base + creditKappa)`; a miss counts
  /// in full. A [base] of 1 or more is a question with a cue (it may be
  /// guessed by what it shows): left out, no evidence.
  PlacementPosterior updateCredit({
    required int deck,
    required PlacementQuestionKind kind,
    required bool correct,
    double? base,
  }) {
    final b = base ?? kind.creditBase();
    if (b >= 1) return this;
    final floor = math.min(1.0, b + creditKappa);
    final slip = kind.creditSlip;
    final next = <double>[];
    for (var c = 0; c < probabilities.length; c++) {
      final right = levels.knows(c, deck) ? 1 - slip : floor;
      next.add(probabilities[c] * (correct ? right : 1 - right));
    }
    return PlacementPosterior(levels, next);
  }

  /// The highest class whose level the learner is at or above with a
  /// probability of at least `1 - alpha / C` (C the number of classes), or 0
  /// (`none`). An anytime lower bound that holds against any guessing
  /// strategy whose success on a counted question is at most its floor (plan
  /// section 13, point 5); never the most probable class.
  int placedClass({double alpha = creditAlpha}) {
    final need = 1 - alpha / levels.classCount - 1e-12;
    var best = 0;
    for (var c = 1; c < probabilities.length; c++) {
      if (massAtOrAbove(levels.levelOf(c)) >= need) best = c;
    }
    return best;
  }

  /// P(the learner knows at least the deck at index [deck]).
  double massAtOrAbove(int deck) {
    var mass = 0.0;
    for (var c = 0; c < probabilities.length; c++) {
      if (levels.knows(c, deck)) mass += probabilities[c];
    }
    return mass;
  }

  /// The most probable class (the lowest of equals).
  int get leadingClass {
    var best = 0;
    for (var c = 1; c < probabilities.length; c++) {
      if (probabilities[c] > probabilities[best]) best = c;
    }
    return best;
  }

  /// The probability of the leading class: the assurance of the placement.
  double get leadingMass => probabilities[leadingClass];

  /// The probability of the whole-path class.
  double get topMass => probabilities[levels.topClass];

  /// The deck index the leading class knows up to, or -1 for `none`.
  int get placedLevel => levels.levelOf(leadingClass);
}

/// The learner's first answer in a run (section 4.5). It chooses where the
/// questions start and nothing else: it is never evidence.
enum PlacementDeclaration {
  /// "I use it easily": the expert track at the last deck.
  expert,

  /// "I follow most of it and can say what I need": positioning starts high.
  advanced,

  /// "I know some words and phrases": positioning starts in the lower middle.
  amateur,

  /// "I am starting from nothing": the run is skipped.
  beginner,
}

/// The asking prior of a declaration over the classes of [levels] (section
/// 4.5, the starting priors the owner approved). `null`, and Beginner (which
/// asks nothing), give the flat prior of the comparison baseline.
///
/// For ten parts these are the published figures: Expert puts 0.55, 0.15,
/// 0.08 and 0.05 on the top four classes and 0.02125 on each of the eight
/// below; Advanced and Amateur a triangle of height `max(0, 6 - 2 d)` (d the
/// distance in tenths from 7.5 or 3.5) times 0.16 on a floor of 0.02,
/// normalised.
List<double> askingPriorWeights(
  PlacementLevels levels,
  PlacementDeclaration? declaration,
) {
  final count = levels.classCount;
  switch (declaration) {
    case PlacementDeclaration.expert:
      const top = <double>[0.55, 0.15, 0.08, 0.05];
      final rest = count > top.length ? 0.17 / (count - top.length) : 0.0;
      return <double>[
        for (var c = 0; c < count; c++)
          count - 1 - c < top.length ? top[count - 1 - c] : rest,
      ];
    case PlacementDeclaration.advanced:
      return _triangle(levels, 7.5);
    case PlacementDeclaration.amateur:
      return _triangle(levels, 3.5);
    case PlacementDeclaration.beginner:
    case null:
      return List<double>.filled(count, 1);
  }
}

List<double> _triangle(PlacementLevels levels, double centre) {
  return <double>[
    for (var c = 0; c < levels.classCount; c++)
      0.02 +
          (c == 0
              ? 0
              : 0.16 *
                    math.max(0.0, 6 - 2 * (levels.tenthOf(c) - centre).abs())),
  ];
}

/// The deck to ask next for a skill: the level where P(level at or above it)
/// is closest to one half in the [asking] posterior (section 5.3, point 2;
/// the lowest deck of equals). Deck 79 for Advanced and deck 40 for Amateur
/// at 100 decks; the 50th percentile deck for a flat start.
int askingDeck(PlacementPosterior asking) {
  var best = asking.levels.levels.first;
  var bestGap = double.infinity;
  for (final level in asking.levels.levels) {
    final gap = (asking.massAtOrAbove(level) - 0.5).abs();
    if (gap < bestGap - 1e-12) {
      best = level;
      bestGap = gap;
    }
  }
  return best;
}
