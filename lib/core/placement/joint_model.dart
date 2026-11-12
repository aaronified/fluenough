import 'dart:math' as math;
import 'dart:typed_data';

import 'assurance_model.dart';
import 'item_registry.dart';
import 'placement_questions.dart';

// The joint measurement model of "Find my level" V3
// (wiki/Plan-Placement-V3.md, section (a), with the amendments of its
// "Adversarial review and required amendments" section).
//
// One position per skill, held as a joint over the skills in play (at most
// four, so at most 22^4 cells with twenty parts), a prior that mixes "the
// skills move together" with "they are independent", a noisy-AND likelihood
// for every item, and a latent yes-bias for the yes/no items. It reports a
// credible range and the "proven level" ceiling, never P(none).
//
// Pure Dart, no Flutter, no clock, no randomness: the same answers always
// give the same numbers.

/// The most the declaration may weigh in the prior; the rest is flat
/// (amendment: the declaration prior carries at most 70%).
const double kMaxDeclarationWeight = 0.7;

/// The share of the prior that says "the skills move together"; the rest is
/// independent skills (plan, section (a)).
const double kTogetherShare = 0.7;

/// How far apart two skills of one learner usually are, in classes: the
/// scale of the decay in the "together" component.
const double kTogetherSpread = 1.5;

/// The mass of the shown range (the central credible interval).
const double kRangeMass = 0.8;

/// The clean items a skill needs before its range is shown, and the clean
/// items of one band that can prove it (amendment: four, not three).
const int kMinCleanItems = 4;

/// The tail probability a band's record must stay under, with the guess at
/// [kProvenGuess], to prove the band: exactly 4 of 4 or 5 of 6 correct.
const double kProvenTail = 0.0125;

/// The guess rate the proof of a band is judged at.
const double kProvenGuess = 0.30;

/// The highest guess rate a clean item may have. An item guessed more often
/// than this may still move the posterior, but it never counts toward the
/// coverage gate or the proof of a band. Above the 0.38 hedge of the word
/// picks (F2, F13), below the 0.45 of F3 and F4 (never clean).
const double kCleanGuessMax = 0.40;

/// An item whose guess rate is this or more gives no evidence and is
/// dropped (amendment: "drop items with guess >= 0.9").
const double kUnusableGuess = 0.9;

/// The pseudowords a yes/no format needs before its real-word answers count
/// as clean items (amendment: at least eight).
const int kMinPseudowords = 8;

/// The values the learner's chance of saying "yes" to a word they do not
/// know (the yes-bias, the false-alarm rate) can take.
const List<double> kBiasGrid = <double>[0.05, 0.2, 0.4, 0.6, 0.85];

/// The exponent every likelihood is raised to, because items share cards,
/// distractors and cues and so are not fully independent (amendment:
/// temper the likelihood).
const double kTemper = 0.85;

/// How an item was answered. For a yes/no item [right] means "yes, I know
/// it" and [wrong] "no"; [dontKnow] counts as "no".
enum AnswerOutcome {
  /// The right answer, or "yes" on a yes/no item.
  right,

  /// A wrong answer, or "no" on a yes/no item.
  wrong,

  /// The learner chose "I don't know": a miss that hides no guess.
  dontKnow,
}

/// The part a yes/no item plays.
enum YesNoRole {
  /// Not a yes/no item.
  notYesNo,

  /// A real word: "yes" is right.
  realWord,

  /// A pseudowords: "yes" is a false alarm.
  pseudoword,
}

/// Why an observed item gave no evidence to the posterior.
enum IgnoredReason {
  /// Its guess rate was [kUnusableGuess] or more.
  unusableGuess,

  /// A self-rated item (Say without a recogniser): never evidence.
  selfRated,

  /// The same card was already asked in this run.
  repeatedCard,

  /// Its weight was zero.
  zeroWeight,

  /// The answer contradicted every hypothesis (a likelihood sum of zero).
  degenerate,
}

/// How a skill's evidence reads on the result screen.
enum EvidenceState {
  /// Nothing scored the skill (not asked, or Say without a recogniser and
  /// without a self-rating).
  notTested,

  /// Only the learner's own rating exists (Say without a recogniser).
  selfRated,

  /// Items scored the skill.
  tested,
}

/// The word shown beside a range.
enum PlacementConfidence {
  /// Under 60% that the true level is within one tenth of the middle.
  low,

  /// 60% to 79%.
  medium,

  /// 80% or more.
  high,
}

/// One item of a run, as the model sees it: which skills it needs at which
/// path difficulty, how it can be slipped and guessed, and how much it may
/// count.
class JointItem {
  const JointItem({
    required this.skills,
    required this.deck,
    required this.slip,
    required this.guess,
    this.weight = 1,
    this.clean = true,
    this.selfRated = false,
    this.yesNo = YesNoRole.notYesNo,
    this.cardId,
  });

  /// A yes/no pseudoword: it measures the learner's yes-bias and needs no
  /// difficulty.
  const JointItem.pseudoword({required this.skills, this.cardId})
    : deck = 0,
      slip = 0,
      guess = 0,
      weight = 1,
      clean = false,
      selfRated = false,
      yesNo = YesNoRole.pseudoword;

  /// The skills the item needs: it is passed only if all of them know the
  /// item's level (noisy AND).
  final Set<PlacementSkill> skills;

  /// The deck index the item is asked at (its difficulty).
  final int deck;

  /// P(wrong) for a learner who knows the item's level.
  final double slip;

  /// P(right) for a learner who does not (after calibration).
  final double guess;

  /// How much the item counts, 0 to 1: lower for an item that shares a card,
  /// a distractor or a cue with others, or that carries a cognate.
  final double weight;

  /// True when the item is non-cognate and non-leaky: only clean items count
  /// toward the coverage gate and the proof of a band.
  final bool clean;

  /// True when the learner marked their own answer (Say without a
  /// recogniser): the item never enters the joint.
  final bool selfRated;

  /// The part the item plays in a yes/no format.
  final YesNoRole yesNo;

  /// The card the item asks, so a card is never asked twice in a run.
  final String? cardId;

  /// Whether the item can give evidence at all.
  bool get usable => yesNo != YesNoRole.notYesNo || guess < kUnusableGuess;
}

/// The skill-level facts a [JointPlacement] reports for one skill.
class SkillReadout {
  const SkillReadout({
    required this.skill,
    required this.state,
    required this.lowClass,
    required this.medianClass,
    required this.highClass,
    required this.startClass,
    required this.startDeck,
    required this.rangeMass,
    required this.nearMass,
    required this.confidence,
    required this.cleanItems,
    required this.touches,
    required this.coveragePassed,
    required this.provenClass,
    required this.cappedByProof,
  });

  final PlacementSkill skill;
  final EvidenceState state;

  /// The classes of the lower edge, the middle and the upper edge of the
  /// 80% range of the posterior (not lowered by the proof ceiling).
  final int lowClass;
  final int medianClass;
  final int highClass;

  /// The class the learner starts at: the lower edge of the range, never
  /// above the proven ceiling, and for Say `none` unless a
  /// recogniser scored it. 0 is `none`.
  final int startClass;

  /// The deck index the learner starts learning at: the deck after the
  /// start class's level (0 for `none`), at most the last deck.
  final int startDeck;

  /// The probability the true class is inside [lowClass] to [highClass] (at
  /// least [kRangeMass], from the posterior before the caps).
  final double rangeMass;

  /// The probability the true class is within one tenth of the middle: what
  /// the confidence word is derived from.
  final double nearMass;

  final PlacementConfidence confidence;

  /// The clean, scored items that touch the skill.
  final int cleanItems;

  /// Every item asked that touches the skill, used or not (the cap counts
  /// these).
  final int touches;

  /// Whether the skill has the clean items to show a range.
  final bool coveragePassed;

  /// The highest class a band of this skill has proven, or null when no band
  /// has been proven.
  final int? provenClass;

  /// Whether the proof ceiling lowered the placement.
  final bool cappedByProof;

  /// Whether the range may be shown: the coverage gate passed and the skill
  /// was scored.
  bool get rangeShown => coveragePassed && state == EvidenceState.tested;
}

/// The readout of every skill in play.
class JointReadout {
  const JointReadout(this.skills);

  final Map<PlacementSkill, SkillReadout> skills;

  /// Whether every scored skill passed the coverage gate (a skill that is
  /// not scored is "Not tested" or "Self-rated" and does not hold it up).
  bool get coveragePassed => skills.values.every(
    (s) => s.state != EvidenceState.tested || s.coveragePassed,
  );
}

/// The guess rate of an item format, per cognate class, as measured by
/// replaying an adversary (amendment: calibrate per format and cognate
/// class, with a 90% upper bound, and drop items with a guess of 0.9 or
/// more).
class GuessCalibration {
  const GuessCalibration(
    this.upperBounds, {
    this.scale = const <String, double>{},
  });

  /// This calibration with a format's guess multiplied (a calibration
  /// profile's `guessScale`); an empty map is this one.
  GuessCalibration scaled(Map<String, double> scale) =>
      scale.isEmpty ? this : GuessCalibration(upperBounds, scale: scale);

  /// Multipliers of the guess by format code, applied after the bound.
  final Map<String, double> scale;

  /// The seed table, from the adversary's replay of the V2 bank (the report
  /// in the plan's amendments). Provisional: the item registry and the real
  /// learner re-fit replace it. Keys are `format:class`, where class is
  /// `clean` or `cognate`.
  static const GuessCalibration seed = GuessCalibration(<String, double>{
    // The word picks: a gamer 0.07 better than the legacy bank's 0.30/0.31
    // (the margin gate) answers them at 0.37 to 0.38, so the model hedges at
    // 0.38 (the real bank audits about 0.26). Still clean (under 0.40); the
    // proof is judged at the item's guess as before (5 of 5 either way).
    'F2:clean': 0.38,
    'F2:cognate': 0.97,
    'F3:clean': 0.45,
    'F3:cognate': 0.99,
    'F4:clean': 0.45,
    'F4:cognate': 0.80,
    'F4decoys:clean': 0.30,
    'F4decoys:cognate': 0.80,
    'F5legacy:clean': 0.95,
    'F5legacy:cognate': 0.95,
    'F5:clean': 0.35,
    'F5:cognate': 0.90,
    'F6hint:clean': 0.60,
    'F6hint:cognate': 0.75,
    'F6endings:clean': 0.99,
    'F6:clean': 0.35,
    // The typed and tiled formats: a gamer 0.07 better than measured (the
    // margin gate) answers them at the design guess plus 0.07, so the model
    // hedges at that (F7 0.03, F8 0.05, F21 0.10, F18 0.03 by design).
    'F7:clean': 0.10,
    'F7:cognate': 0.55,
    'F8:clean': 0.12,
    // The cognate sentence tiles (asked at half weight, Write and Read): the
    // gamer 0.07 better than measured answers them at 0.05 + 0.07.
    'F8:cognate': 0.12,
    'F9:clean': 0.55,
    'F9:cognate': 0.85,
    'F13:clean': 0.38,
    'F13:cognate': 0.85,
    'F15:clean': 0.70,
    'F17:clean': 0.35,
    'F18:clean': 0.10,
    'F21:clean': 0.17,
    'F17:cognate': 0.90,
    // The six-option look-alike word picks: the best solver's upper bound of
    // the audit stays under 0.20 (a sixth by chance), and the admission bound
    // is 0.25; a gamer 0.07 better than measured (the margin gate) answers
    // them at 0.25, so the model hedges at 0.27.
    'F26:clean': 0.27,
    'F26:cognate': 0.85,
    'F27:clean': 0.27,
    'F27:cognate': 0.97,
    // The heard-sentence pick as the adversary found it, before its options
    // were made to look alike (length band, shared structure): the right
    // option was found 75% of the time by shape. Never asked.
    'F17legacy:clean': 0.95,
    'F17legacy:cognate': 0.95,
    'F6:cognate': 0.90,
    'S2legacy:clean': 0.98,
    'S2legacy:cognate': 0.98,
  });

  /// The 90% upper bound of the guess rate by `format:class`.
  final Map<String, double> upperBounds;

  /// The guess to use for [format] and [cognate] when the design's base is
  /// [base]: the base, raised to the measured bound, never lowered.
  double guessFor(String format, bool cognate, double base, {String? key}) {
    final bound =
        upperBounds['${key ?? baseFormat(format)}:${cognate ? 'cognate' : 'clean'}'];
    final g = bound == null ? base : math.max(base, bound);
    final m = scale[baseFormat(format)];
    return m == null ? g : math.min(0.99, g * m);
  }

  /// Whether an item of [format] and [cognate] is worth asking at all.
  bool usable(String format, bool cognate, double base) =>
      guessFor(format, cognate, base) < kUnusableGuess;

  /// The one-sided 90% upper confidence bound (Wilson) of a rate seen as
  /// [hits] of [n]: what a replay turns an adversary's accuracy into.
  static double upperBound90(int hits, int n) {
    if (n <= 0) return 1;
    const z = 1.2816;
    final p = hits / n;
    final z2 = z * z;
    final centre = p + z2 / (2 * n);
    final spread = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n));
    return math.min(1.0, (centre + spread) / (1 + z2 / n));
  }
}

/// The weight of an item that shares [shares] cards, distractors or cues
/// with items already asked: each share takes a fifth off.
double sharedWeight(int shares) =>
    math.pow(0.8, shares < 0 ? 0 : shares).toDouble();

/// P(X >= [k]) for X binomial with [n] trials at rate [p].
double binomialTail(int k, int n, double p) {
  if (k <= 0) return 1;
  if (k > n) return 0;
  var total = 0.0;
  for (var i = k; i <= n; i++) {
    total += _choose(n, i) * math.pow(p, i) * math.pow(1 - p, n - i);
  }
  return total;
}

double _choose(int n, int k) {
  var out = 1.0;
  for (var i = 1; i <= k; i++) {
    out = out * (n - k + i) / i;
  }
  return out;
}

class _Record {
  const _Record(
    this.skill,
    this.band,
    this.correct,
    this.yesNoReal,
    this.guess,
  );
  final PlacementSkill skill;
  final int band;
  final bool correct;
  final bool yesNoReal;
  final double guess;
}

/// The joint posterior of one learner's skills, updated item by item.
///
/// Mutable on purpose (it holds up to a million numbers); a run holds one.
class JointPlacement {
  JointPlacement({
    required this.levels,
    required Iterable<PlacementSkill> skills,
    PlacementDeclaration? declaration,
    double declarationWeight = kMaxDeclarationWeight,
    this.temper = kTemper,
    this.togetherShare = kTogetherShare,
  }) : skills = List<PlacementSkill>.unmodifiable(
         (skills.toSet().toList()..sort((a, b) => a.index - b.index)),
       ),
       declarationWeight = math.min(
         kMaxDeclarationWeight,
         math.max(0.0, declarationWeight),
       ) {
    if (this.skills.isEmpty || this.skills.length > 4) {
      throw ArgumentError('One to four skills in play, got ${this.skills}');
    }
    _n = levels.classCount;
    var cells = 1;
    for (var i = 0; i < this.skills.length; i++) {
      cells *= _n;
    }
    _cells = cells;
    _weights = Float64List(_cells);
    _buildPrior(declaration);
    for (final s in this.skills) {
      _touches[s] = 0;
      _used[s] = 0;
      _selfRated[s] = 0;
      _recognised[s] = 0;
    }
  }

  final PlacementLevels levels;

  /// The skills in play, in enum order.
  final List<PlacementSkill> skills;

  /// How much of the prior is the declaration (at most
  /// [kMaxDeclarationWeight]).
  final double declarationWeight;

  /// The exponent every item's likelihood is raised to.
  final double temper;

  /// The share of the prior in which the skills move together.
  final double togetherShare;

  late final int _n;
  late final int _cells;

  // The joint, cell-major with the bias as the last index; the bias
  // dimension has length 1 until a yes/no item is observed.
  late Float64List _weights;
  int _k = 1;

  final Set<String> _cards = <String>{};
  final List<_Record> _records = <_Record>[];
  final Map<PlacementSkill, int> _touches = <PlacementSkill, int>{};
  final Map<PlacementSkill, int> _used = <PlacementSkill, int>{};
  final Map<PlacementSkill, int> _selfRated = <PlacementSkill, int>{};
  final Map<PlacementSkill, int> _recognised = <PlacementSkill, int>{};
  int _pseudowords = 0;
  int _pseudoYes = 0;
  int _ignored = 0;

  /// How many items gave no evidence (unusable, self-rated, repeated).
  int get ignoredItems => _ignored;

  /// How many pseudowords were answered.
  int get pseudowordCount => _pseudowords;

  /// How many of them were answered "yes" (false alarms).
  int get falseAlarms => _pseudoYes;

  /// Whether the card was already asked.
  bool hasAsked(String cardId) => _cards.contains(cardId);

  /// The items asked that touch [skill], used or not.
  int touchesOf(PlacementSkill skill) => _touches[skill] ?? 0;

  /// The clean, scored items that touch [skill]: what the coverage gate and
  /// the proof of a band count. Self-rated, cognate, repeated and
  /// unusable items are not here, and a yes/no real word is here only when
  /// [kMinPseudowords] pseudowords were answered.
  int cleanItemsOf(PlacementSkill skill) => _cleanRecords(skill).length;

  void _buildPrior(PlacementDeclaration? declaration) {
    final n = _n;
    final decl = askingPriorWeights(levels, declaration);
    final declTotal = decl.fold<double>(0, (a, b) => a + b);
    final w = declaration == null ? 0.0 : declarationWeight;
    final marginal = <double>[
      for (var c = 0; c < n; c++) w * decl[c] / declTotal + (1 - w) / n,
    ];
    // spread[z][c]: where a skill sits given the common level z.
    final spread = <List<double>>[];
    for (var z = 0; z < n; z++) {
      final row = <double>[
        for (var c = 0; c < n; c++) math.exp(-(c - z).abs() / kTogetherSpread),
      ];
      final total = row.fold<double>(0, (a, b) => a + b);
      spread.add(<double>[for (final v in row) v / total]);
    }
    final count = skills.length;
    final digits = List<int>.filled(count, 0);
    var sum = 0.0;
    for (var cell = 0; cell < _cells; cell++) {
      _digits(cell, digits);
      var together = 0.0;
      for (var z = 0; z < n; z++) {
        var p = marginal[z];
        for (var i = 0; i < count; i++) {
          p *= spread[z][digits[i]];
        }
        together += p;
      }
      var independent = 1.0;
      for (var i = 0; i < count; i++) {
        independent *= marginal[digits[i]];
      }
      final value =
          togetherShare * together + (1 - togetherShare) * independent;
      _weights[cell] = value;
      sum += value;
    }
    for (var cell = 0; cell < _cells; cell++) {
      _weights[cell] /= sum;
    }
  }

  void _digits(int cell, List<int> out) {
    var rem = cell;
    for (var i = out.length - 1; i >= 0; i--) {
      out[i] = rem % _n;
      rem ~/= _n;
    }
  }

  void _expandBias() {
    if (_k > 1) return;
    final k = kBiasGrid.length;
    final next = Float64List(_cells * k);
    for (var cell = 0; cell < _cells; cell++) {
      for (var b = 0; b < k; b++) {
        next[cell * k + b] = _weights[cell] / k;
      }
    }
    _weights = next;
    _k = k;
  }

  /// The band (a tenth of the path, 0 to 10) a deck belongs to.
  int bandOfDeck(int deck) {
    var c = 1;
    while (c < levels.topClass && levels.levelOf(c) < deck) {
      c++;
    }
    return levels.parts == 0 ? 10 : ((c - 1) * 10 / levels.parts).ceil();
  }

  /// The highest class whose position is at or below the top of [band].
  int classOfBand(int band) {
    var best = 1;
    for (var c = 1; c < levels.classCount; c++) {
      if (levels.tenthOf(c) <= band + 1e-9) best = c;
    }
    return best;
  }

  /// Takes one answer into the joint. Returns why it gave no evidence, or
  /// null when it did.
  IgnoredReason? observe(JointItem item, AnswerOutcome outcome) {
    // Every cached read of the posterior is stale after an answer.
    _knownCache.clear();
    _marginalCache.clear();
    for (final s in item.skills) {
      if (!skills.contains(s)) {
        throw ArgumentError('$s is not in play ($skills)');
      }
    }
    for (final s in item.skills) {
      _touches[s] = _touches[s]! + 1;
    }
    // A card is remembered only once an item on it gave evidence: a
    // self-rated, unusable or otherwise ignored item must not block a later
    // real item on the same card.
    final card = item.cardId;
    IgnoredReason? reason;
    if (item.selfRated) {
      reason = IgnoredReason.selfRated;
      for (final s in item.skills) {
        _selfRated[s] = _selfRated[s]! + 1;
      }
    } else if (card != null && _cards.contains(card)) {
      reason = IgnoredReason.repeatedCard;
    } else if (!item.usable) {
      reason = IgnoredReason.unusableGuess;
    } else if (item.weight <= 0) {
      reason = IgnoredReason.zeroWeight;
    }
    if (reason != null) {
      _ignored++;
      return reason;
    }
    // The posterior is updated first, so an answer that contradicts every
    // hypothesis changes nothing.
    final bias = item.yesNo != YesNoRole.notYesNo;
    if (bias) _expandBias();
    if (!_apply(item, outcome)) {
      _ignored++;
      return IgnoredReason.degenerate;
    }
    if (card != null) _cards.add(card);
    for (final s in item.skills) {
      _used[s] = _used[s]! + 1;
      _recognised[s] = _recognised[s]! + 1;
    }
    final said = outcome == AnswerOutcome.right;
    if (item.yesNo == YesNoRole.pseudoword) {
      _pseudowords++;
      if (said) _pseudoYes++;
    }
    // Real-word yes/no answers update the posterior at once, but they count
    // toward coverage and proof only once [kMinPseudowords] pseudowords have
    // been answered (see [_cleanRecords]). Items guessed more often than
    // [kCleanGuessMax] may update the posterior but are never clean.
    final cleanGuess = bias || item.guess <= kCleanGuessMax;
    if (item.clean && cleanGuess && item.yesNo != YesNoRole.pseudoword) {
      final band = bandOfDeck(item.deck);
      for (final s in item.skills) {
        _records.add(
          _Record(s, band, said, item.yesNo == YesNoRole.realWord, item.guess),
        );
      }
    }
    return null;
  }

  /// Multiplies the joint by the item's likelihood; false, with the joint
  /// untouched, when the product would sum to zero.
  bool _apply(JointItem item, AnswerOutcome outcome) {
    final exponent = math.min(1.0, item.weight) * temper;
    final count = skills.length;
    final index = <int>[for (final s in item.skills) skills.indexOf(s)];
    final knowsClass = List<bool>.generate(
      _n,
      (c) => levels.knows(c, item.deck),
    );
    final digits = List<int>.filled(count, 0);
    final right = outcome == AnswerOutcome.right;
    final k = _k;
    // The likelihood of the answer for (known, bias index).
    double lik(bool known, int b) {
      switch (item.yesNo) {
        case YesNoRole.notYesNo:
          switch (outcome) {
            case AnswerOutcome.right:
              return known ? 1 - item.slip : item.guess;
            case AnswerOutcome.wrong:
              return known ? item.slip : 1 - item.guess;
            case AnswerOutcome.dontKnow:
              // A miss with no guess behind it.
              return known ? math.max(item.slip, 0.02) : 1.0;
          }
        case YesNoRole.realWord:
          {
            final f = kBiasGrid[b];
            if (known) return right ? 1 - item.slip : item.slip;
            return right ? f : 1 - f;
          }
        case YesNoRole.pseudoword:
          {
            final f = kBiasGrid[b];
            return right ? f : 1 - f;
          }
      }
    }

    final known = List<double>.generate(
      k,
      (b) => math.pow(lik(true, b), exponent).toDouble(),
    );
    final unknown = List<double>.generate(
      k,
      (b) => math.pow(lik(false, b), exponent).toDouble(),
    );
    bool allKnow(int cell) {
      _digits(cell, digits);
      for (final i in index) {
        if (!knowsClass[digits[i]]) return false;
      }
      return true;
    }

    var sum = 0.0;
    for (var cell = 0; cell < _cells; cell++) {
      final table = allKnow(cell) ? known : unknown;
      for (var b = 0; b < k; b++) {
        sum += _weights[cell * k + b] * table[b];
      }
    }
    if (!(sum > 0) || sum.isInfinite) return false;
    for (var cell = 0; cell < _cells; cell++) {
      final table = allKnow(cell) ? known : unknown;
      for (var b = 0; b < k; b++) {
        _weights[cell * k + b] = _weights[cell * k + b] * table[b] / sum;
      }
    }
    return true;
  }

  /// P(class) for one skill, summed over every other skill and the bias.
  List<double> marginal(PlacementSkill skill) {
    final at = skills.indexOf(skill);
    if (at < 0) throw ArgumentError('$skill is not in play ($skills)');
    final cached = _marginalCache[at];
    if (cached != null) return List<double>.of(cached);
    final computed = _marginal(at);
    _marginalCache[at] = computed;
    return List<double>.of(computed);
  }

  // Reads of the posterior that a picker repeats between two answers.
  final Map<int, List<double>> _marginalCache = <int, List<double>>{};
  final Map<int, double> _knownCache = <int, double>{};

  List<double> _marginal(int at) {
    final out = List<double>.filled(_n, 0);
    final digits = List<int>.filled(skills.length, 0);
    for (var cell = 0; cell < _cells; cell++) {
      _digits(cell, digits);
      var v = 0.0;
      for (var b = 0; b < _k; b++) {
        v += _weights[cell * _k + b];
      }
      out[digits[at]] += v;
    }
    return out;
  }

  /// P(the learner's yes-bias is each value of [kBiasGrid]); the prior
  /// (flat) until a yes/no item has been observed.
  List<double> biasPosterior() {
    final out = List<double>.filled(kBiasGrid.length, 0);
    if (_k == 1) {
      return List<double>.filled(kBiasGrid.length, 1 / kBiasGrid.length);
    }
    for (var cell = 0; cell < _cells; cell++) {
      for (var b = 0; b < _k; b++) {
        out[b] += _weights[cell * _k + b];
      }
    }
    return out;
  }

  /// P(every skill of [skills] knows [deck]'s level): what an item that
  /// needs all of them is answered right by knowing. For one skill the same
  /// as [massKnowing].
  double probabilityKnown(Iterable<PlacementSkill> skills, int deck) {
    final index = <int>[for (final s in skills) this.skills.indexOf(s)];
    if (index.any((i) => i < 0)) {
      throw ArgumentError('A skill is not in play ($skills)');
    }
    var mask = 0;
    for (final i in index) {
      mask |= 1 << i;
    }
    final key = deck * 64 + mask;
    final hit = _knownCache[key];
    if (hit != null) return hit;
    return _knownCache[key] = _probabilityKnown(index, deck);
  }

  double _probabilityKnown(List<int> index, int deck) {
    final knows = List<bool>.generate(_n, (c) => levels.knows(c, deck));
    final digits = List<int>.filled(skills.length, 0);
    var total = 0.0;
    for (var cell = 0; cell < _cells; cell++) {
      _digits(cell, digits);
      var all = true;
      for (final i in index) {
        if (!knows[digits[i]]) {
          all = false;
          break;
        }
      }
      if (!all) continue;
      for (var b = 0; b < _k; b++) {
        total += _weights[cell * _k + b];
      }
    }
    return total;
  }

  /// P(exactly [failing] of [skills] does not know [deck]'s level while every
  /// other one of [skills] does): the chance that one skill is the one that
  /// failed an item which needs all of them.
  double probabilityFailingOnly(
    Iterable<PlacementSkill> skills,
    PlacementSkill failing,
    int deck,
  ) {
    final index = <int>[for (final s in skills) this.skills.indexOf(s)];
    final f = this.skills.indexOf(failing);
    if (index.any((i) => i < 0) || f < 0 || !index.contains(f)) {
      throw ArgumentError('A skill is not in play ($skills, $failing)');
    }
    var mask = 0;
    for (final i in index) {
      mask |= 1 << i;
    }
    final key = 1000000 + (deck * 64 + mask) * 8 + f;
    final hit = _knownCache[key];
    if (hit != null) return hit;
    final knows = List<bool>.generate(_n, (c) => levels.knows(c, deck));
    final digits = List<int>.filled(this.skills.length, 0);
    var total = 0.0;
    for (var cell = 0; cell < _cells; cell++) {
      _digits(cell, digits);
      var ok = true;
      for (final i in index) {
        if (knows[digits[i]] == (i == f)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (var b = 0; b < _k; b++) {
        total += _weights[cell * _k + b];
      }
    }
    return _knownCache[key] = total;
  }

  /// P(the skill's class is at or above [deck]'s level).
  double massKnowing(PlacementSkill skill, int deck) {
    final m = marginal(skill);
    var total = 0.0;
    for (var c = 0; c < _n; c++) {
      if (levels.knows(c, deck)) total += m[c];
    }
    return total;
  }

  List<_Record> _cleanRecords(PlacementSkill skill) => <_Record>[
    for (final r in _records)
      if (r.skill == skill && (!r.yesNoReal || _pseudowords >= kMinPseudowords))
        r,
  ];

  /// The clean scored items of [skill] in [band] (a tenth of the path), and
  /// how many of them were answered right: what a picker needs to decide
  /// whether the band is proven, failed or still open.
  ({int clean, int right}) bandRecord(PlacementSkill skill, int band) {
    var clean = 0;
    var right = 0;
    for (final r in _cleanRecords(skill)) {
      if (r.band != band) continue;
      clean++;
      if (r.correct) right++;
    }
    return (clean: clean, right: right);
  }

  /// The highest class a band of [skill] has proven, or null: a band is
  /// proven by at least [kMinCleanItems] clean items of it of which so many
  /// are right that a guesser at [kProvenGuess] would do as well at most
  /// [kProvenTail] of the time (4 of 4, 5 of 6).
  int? provenClass(PlacementSkill skill) {
    final byBand = <int, List<_Record>>{};
    for (final r in _cleanRecords(skill)) {
      byBand.putIfAbsent(r.band, () => <_Record>[]).add(r);
    }
    // A yes/no answer is only as good as the learner's own false-alarm
    // rate: a yes-sayer's "yes" proves nothing.
    final biasGuess = math.max(
      kProvenGuess,
      GuessCalibration.upperBound90(_pseudoYes, _pseudowords),
    );
    int? best;
    byBand.forEach((band, records) {
      if (records.length < kMinCleanItems) return;
      final right = records.where((r) => r.correct).length;
      // Judged at the real guess of the band's items, never below 0.30.
      var guess = records.any((r) => r.yesNoReal) ? biasGuess : kProvenGuess;
      for (final r in records) {
        if (r.guess > guess) guess = r.guess;
      }
      if (guess >= kUnusableGuess) return;
      if (binomialTail(right, records.length, guess) <= kProvenTail) {
        final c = classOfBand(band);
        if (best == null || c > best!) best = c;
      }
    });
    return best;
  }

  /// The readout of every skill in play.
  JointReadout readout() {
    final out = <PlacementSkill, SkillReadout>{};
    for (final skill in skills) {
      out[skill] = _skillReadout(skill);
    }
    // Say is never placed from self-rating alone: without a recogniser-scored
    // item it is unplaced (start `none`), whatever Hear shows.
    final say = out[PlacementSkill.say];
    if (say != null && (_recognised[PlacementSkill.say] ?? 0) == 0) {
      out[PlacementSkill.say] = _unplaced(say);
    }
    return JointReadout(Map<PlacementSkill, SkillReadout>.unmodifiable(out));
  }

  SkillReadout _unplaced(SkillReadout r) {
    return SkillReadout(
      skill: r.skill,
      state: r.state,
      lowClass: 0,
      medianClass: 0,
      highClass: 0,
      startClass: 0,
      startDeck: 0,
      rangeMass: r.rangeMass,
      nearMass: r.nearMass,
      confidence: PlacementConfidence.low,
      cleanItems: r.cleanItems,
      touches: r.touches,
      coveragePassed: false,
      provenClass: r.provenClass,
      cappedByProof: r.cappedByProof,
    );
  }

  int _startDeck(int startClass) {
    if (startClass <= 0) return 0;
    return math.min(levels.lastDeck, levels.levelOf(startClass) + 1);
  }

  SkillReadout _skillReadout(PlacementSkill skill) {
    final m = marginal(skill);
    final cdf = <double>[];
    var run = 0.0;
    for (final p in m) {
      run += p;
      cdf.add(run);
    }
    const tail = (1 - kRangeMass) / 2;
    var lo = 0;
    while (lo < _n - 1 && cdf[lo] < tail - 1e-12) {
      lo++;
    }
    var hi = lo;
    while (hi < _n - 1 && cdf[hi] < 1 - tail - 1e-12) {
      hi++;
    }
    var med = 0;
    while (med < _n - 1 && cdf[med] < 0.5 - 1e-12) {
      med++;
    }
    var rangeMass = 0.0;
    for (var c = lo; c <= hi; c++) {
      rangeMass += m[c];
    }
    final tenth = math.max(1, levels.parts ~/ 10);
    var near = 0.0;
    for (
      var c = math.max(0, med - tenth);
      c <= math.min(_n - 1, med + tenth);
      c++
    ) {
      near += m[c];
    }
    final proven = provenClass(skill);
    final ceiling = proven ?? 0;
    // The range is the posterior's own; only the START is held at the
    // ceiling, so the range stays an honest statement of what is likely.
    final capped = lo > ceiling;
    final start = math.min(lo, ceiling);
    final clean = cleanItemsOf(skill);
    final recognised = (_recognised[skill] ?? 0) > 0;
    final state = recognised
        ? EvidenceState.tested
        : (_selfRated[skill] ?? 0) > 0
        ? EvidenceState.selfRated
        : EvidenceState.notTested;
    return SkillReadout(
      skill: skill,
      state: state,
      lowClass: lo,
      medianClass: med,
      highClass: hi,
      startClass: start,
      startDeck: _startDeck(start),
      rangeMass: rangeMass,
      nearMass: near,
      confidence: near >= 0.8
          ? PlacementConfidence.high
          : near >= 0.6
          ? PlacementConfidence.medium
          : PlacementConfidence.low,
      cleanItems: clean,
      touches: _touches[skill] ?? 0,
      coveragePassed: clean >= kMinCleanItems,
      provenClass: proven,
      cappedByProof: capped,
    );
  }
}
