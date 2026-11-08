import 'dart:math' as math;

import 'joint_model.dart';
import 'placement_questions.dart';

// The isolating drill-down of "Find my level" V3 (wiki/Plan-Placement-V3.md,
// "Phase 2"): when the mixed items of the first phase leave it unclear which
// skill failed, a few single-skill (isolating) items at the same level tell
// them apart. The state machine here decides WHEN a drill-down starts, WHICH
// skill is asked next and WHEN it stops; the picker (v3_picker.dart) chooses
// the item, from the admitted single-skill formats, never a card twice.
//
// Triggers, each at most once per skill and band:
//  - a wrong answer on an item that needs two skills or more, which the
//    posterior expected to be right (all of its skills at least `surprise`
//    likely to know it): the skills that now probably failed it are
//    implicated;
//  - a right answer that conflicts hard with the posterior (a skill under 0.2
//    likely to know the level): a likely lucky guess, the skill is implicated;
//  - a skill about to be finished whose 80% interval is wider than 6 classes
//    or whose evidence is contradictory (a band with a right and a wrong
//    answer): the skill alone is drilled.
// A drill-down asks 2 isolating items for each implicated skill, the one most
// likely to have failed first, and stops when the failing skill is identified
// (posterior mass 0.8) or after 4 isolating items.
//
// Pure Dart.

/// Why a drill-down started.
enum DrillTrigger { mixedWrong, luckyRight, uncertain }

/// How a drill-down ended.
enum DrillEnd {
  /// One implicated skill is the failing one with posterior mass of 0.8 or
  /// more (for a single skill: it is known or failed at that level, 0.8).
  identified,

  /// Every implicated skill failed the level (each with a chance of 0.9
  /// after at least three isolating items): nothing is left to tell apart.
  allFailed,

  /// Four isolating items were asked.
  budget,

  /// No isolating item was left for the skills implicated.
  exhausted,
}

/// What the picker's configuration says of the drill-down.
class DrillConfig {
  const DrillConfig({
    this.enabled = true,
    this.maxCases = 2,
    this.maxIsolating = 4,
    this.perSkill = 2,
    this.surprise = 0.0,
    this.implicate = 0.25,
    this.lucky = 0.2,
    this.identify = 0.8,
    this.wideClasses = 8,
    this.stopAfterSeconds = 150,
  });

  final bool enabled;

  /// The most drill-downs of one run.
  final int maxCases;

  /// The most isolating items of one drill-down.
  final int maxIsolating;

  /// Isolating items for each implicated skill.
  final int perSkill;

  /// A wrong mixed item starts a drill-down only if the posterior gave all
  /// its skills together at least this chance of knowing it.
  final double surprise;

  /// A skill is implicated when its chance of having failed is this or more.
  final double implicate;

  /// A right answer is a likely lucky guess when a skill of it had less than
  /// this chance of knowing the level.
  final double lucky;

  /// The posterior mass at which the failing skill counts as identified.
  final double identify;

  /// An interval wider than this many classes starts a drill-down (the plan
  /// says 6; 8 keeps the amateur-declared cells inside the time gate).
  final int wideClasses;

  /// No drill-down starts after this many seconds of the run.
  final double stopAfterSeconds;
}

/// One drill-down.
class DrillCase {
  DrillCase(this.trigger, this.skills, this.deck);

  final DrillTrigger trigger;

  /// The implicated skills, the most likely failure first at the start.
  final List<PlacementSkill> skills;

  /// The deck level the isolating items are asked at.
  final int deck;

  /// For several implicated skills, what the isolating answers alone say: the
  /// log-odds that each failed the level (0 is even odds), updated by the
  /// items of that skill only. The joint posterior ties the skills together
  /// (a learner is usually at one level in every skill), which is the very
  /// thing the isolating items are asked to see past.
  final Map<PlacementSkill, double> logOdds = <PlacementSkill, double>{};

  /// The isolating items asked, per skill.
  final Map<PlacementSkill, int> asked = <PlacementSkill, int>{};

  /// The skills with no isolating item left.
  final Set<PlacementSkill> spent = <PlacementSkill>{};

  /// How it ended (null while it goes on).
  DrillEnd? end;

  /// The skill found to be failing (null when it ended without one).
  PlacementSkill? failing;

  /// How likely each implicated skill had failed the level when it ended.
  final Map<PlacementSkill, double> failAtEnd = <PlacementSkill, double>{};

  /// The skill the drill-down names as the failing one when it ended: the
  /// identified one, or else the most likely to have failed when that is at
  /// least 0.5 and clearly ahead (0.15) of the next. Null when the case
  /// settled that no implicated skill failed, or could not tell.
  PlacementSkill? get verdict {
    if (failing != null) return failing;
    if (end == DrillEnd.identified || end == DrillEnd.allFailed) return null;
    PlacementSkill? best;
    var top = 0.0;
    var next = 0.0;
    for (final e in failAtEnd.entries) {
      if (e.value > top) {
        next = top;
        top = e.value;
        best = e.key;
      } else if (e.value > next) {
        next = e.value;
      }
    }
    return top >= 0.4 && top - next >= 0.1 ? best : null;
  }

  /// The isolating items asked.
  int get isolating => asked.values.fold<int>(0, (a, b) => a + b);

  bool get closed => end != null;
}

/// The drill-down of a run, over [model].
class DrillDown {
  DrillDown(this.model, {this.config = const DrillConfig()});

  final JointPlacement model;
  final DrillConfig config;

  /// Every drill-down of the run, in order.
  final List<DrillCase> cases = <DrillCase>[];

  /// The drill-down going on, or null.
  DrillCase? active;

  final Set<String> _done = <String>{};

  /// The most isolating items of a run.
  int get isolatingTotal => cases.fold<int>(0, (a, c) => a + c.isolating);

  String _key(PlacementSkill s, int band) => '${s.name}@$band';

  bool _canStart(double seconds) =>
      config.enabled &&
      active == null &&
      cases.length < config.maxCases &&
      seconds < config.stopAfterSeconds;

  double _fail(PlacementSkill s, int deck) =>
      1 - model.probabilityKnown(<PlacementSkill>[s], deck);

  /// How likely [s] failed the level of [c], by the isolating answers alone
  /// when several skills are implicated, else by the joint posterior.
  double _failOf(DrillCase c, PlacementSkill s) {
    if (c.skills.length == 1) return _fail(s, c.deck);
    final x = c.logOdds[s] ?? 0;
    return 1 / (1 + math.exp(-x));
  }

  DrillCase? _start(
    DrillTrigger t,
    List<PlacementSkill> skills,
    int deck,
    int band,
  ) {
    final fresh = <PlacementSkill>[
      for (final s in skills)
        if (!_done.contains(_key(s, band))) s,
    ];
    if (fresh.isEmpty) return null;
    for (final s in fresh) {
      _done.add(_key(s, band));
    }
    fresh.sort((a, b) => _fail(b, deck).compareTo(_fail(a, deck)));
    final c = DrillCase(t, fresh, deck);
    for (final k in fresh) {
      c.logOdds[k] = 0;
    }
    cases.add(c);
    active = c;
    return c;
  }

  /// An item of [skills] at [deck] (in [band]) was answered. [preKnown] is,
  /// per skill, what the posterior thought before the answer of the chance
  /// that the skill knows the level, and [preAll] the same for all skills
  /// together. The model has already taken the answer in. Returns the
  /// drill-down this started, if any.
  DrillCase? onAnswer({
    required List<PlacementSkill> itemSkills,
    required int deck,
    required int band,
    required bool right,
    required Map<PlacementSkill, double> preKnown,
    required double preAll,
    required double seconds,
    required List<PlacementSkill> testable,
  }) {
    if (!_canStart(seconds)) return null;
    final inPlay = <PlacementSkill>[
      for (final s in itemSkills)
        if (testable.contains(s)) s,
    ];
    if (!right && inPlay.length >= 2 && preAll >= config.surprise) {
      final implicated = <PlacementSkill>[
        for (final s in inPlay)
          if (_fail(s, deck) >= config.implicate) s,
      ];
      if (implicated.isNotEmpty) {
        return _start(DrillTrigger.mixedWrong, implicated, deck, band);
      }
    }
    if (right) {
      final lucky = <PlacementSkill>[
        for (final s in inPlay)
          if ((preKnown[s] ?? 1) < config.lucky) s,
      ];
      if (lucky.isNotEmpty) {
        return _start(DrillTrigger.luckyRight, lucky, deck, band);
      }
    }
    return null;
  }

  /// The 80% interval of [skill] in classes: (low, high).
  (int, int) interval(PlacementSkill skill) {
    final marginal = model.marginal(skill);
    var run = 0.0;
    var low = 0;
    var high = marginal.length - 1;
    var gotLow = false;
    for (var c = 0; c < marginal.length; c++) {
      run += marginal[c];
      if (!gotLow && run >= 0.1) {
        low = c;
        gotLow = true;
      }
      if (run >= 0.9) {
        high = c;
        break;
      }
    }
    return (low, high);
  }

  /// [skill] is about to be finished: a drill-down starts when its interval
  /// is wide or its evidence contradicts itself. Returns whether it did.
  bool checkInterval(PlacementSkill skill, {required double seconds}) {
    if (!_canStart(seconds)) return false;
    final (low, high) = interval(skill);
    var contradictory = -1;
    for (var b = 0; b <= 10; b++) {
      final r = model.bandRecord(skill, b);
      if (r.clean >= 2 && r.right > 0 && r.right < r.clean) {
        contradictory = b;
        break;
      }
    }
    final wide = high - low > config.wideClasses;
    if (!wide && contradictory < 0) return false;
    final marginal = model.marginal(skill);
    var run = 0.0;
    var median = 0;
    for (var c = 0; c < marginal.length; c++) {
      run += marginal[c];
      if (run >= 0.5) {
        median = c;
        break;
      }
    }
    final band = contradictory >= 0
        ? contradictory
        : median <= 1
        ? 0
        : model.levels.tenthOf(median).ceil();
    final deck = model.levels.levelOf(model.classOfBand(band));
    return _start(
          DrillTrigger.uncertain,
          <PlacementSkill>[skill],
          deck,
          band,
        ) !=
        null;
  }

  /// The skill to give the next isolating item, or null when no drill-down
  /// is going on (a drill-down that has used its items ends here).
  PlacementSkill? next() {
    final c = active;
    if (c == null) return null;
    if (c.isolating >= config.maxIsolating) {
      _close(c, DrillEnd.budget);
      return null;
    }
    final open = <PlacementSkill>[
      for (final s in c.skills)
        if ((c.asked[s] ?? 0) <
                (c.skills.length == 1
                    ? config.maxIsolating
                    : config.perSkill) &&
            !c.spent.contains(s))
          s,
    ];
    if (open.isEmpty) {
      // Every implicated skill had its two items and the case is still open:
      // the items left of the four go to the skill whose answer is the least
      // settled (a lucky guess or a slip among its two).
      final spare =
          <PlacementSkill>[
            for (final s in c.skills)
              if (!c.spent.contains(s)) s,
          ]..sort(
            (a, b) => (_fail(a, c.deck) - 0.5).abs().compareTo(
              (_fail(b, c.deck) - 0.5).abs(),
            ),
          );
      if (spare.isEmpty) {
        _close(c, DrillEnd.exhausted);
        return null;
      }
      return spare.first;
    }
    // The skill least asked first (so every implicated skill is heard before
    // any gets its second item and the posterior can tell them apart), the
    // one most likely to have failed among those.
    open.sort((a, b) {
      final ka = c.asked[a] ?? 0;
      final kb = c.asked[b] ?? 0;
      if (ka == 0 || kb == 0) {
        if (ka != kb) return ka.compareTo(kb);
        return _failOf(c, b).compareTo(_failOf(c, a));
      }
      // Every skill has been asked once: the next goes to the one the
      // answers have settled the least.
      return (_failOf(c, a) - 0.5).abs().compareTo((_failOf(c, b) - 0.5).abs());
    });
    return open.first;
  }

  /// The picker found no isolating item for [skill].
  void noCandidate(PlacementSkill skill) => active?.spent.add(skill);

  /// An isolating item of [skill] was answered (the model has taken it in).
  void onIsolating(
    PlacementSkill skill, {
    required bool right,
    required double slip,
    required double guess,
  }) {
    final c = active;
    if (c == null) return;
    c.asked[skill] = (c.asked[skill] ?? 0) + 1;
    // Likelihood ratio of "failed" against "knows".
    final g = guess.clamp(0.01, 0.99);
    final sl = slip.clamp(0.01, 0.99);
    c.logOdds[skill] =
        (c.logOdds[skill] ?? 0) +
        (right ? math.log(g / (1 - sl)) : math.log((1 - g) / sl));
    final id = identified(c);
    if (id != null) {
      c.failing = id.failing;
      _close(c, DrillEnd.identified);
    } else if (c.skills.length > 1 &&
        c.isolating >= 3 &&
        c.skills.every((s) => (c.asked[s] ?? 0) >= 1 && _failOf(c, s) >= 0.9)) {
      _close(c, DrillEnd.allFailed);
    } else if (c.isolating >= config.maxIsolating) {
      _close(c, DrillEnd.budget);
    }
  }

  /// Whether the failing skill of [c] is identified: for several implicated
  /// skills, one of them failed and the others know the level, with
  /// posterior mass [DrillConfig.identify] among the cases in which something
  /// failed; for one skill, it failed (or knows the level) with that mass.
  ({PlacementSkill? failing})? identified(DrillCase c) {
    final deck = c.deck;
    if (c.skills.length == 1) {
      final s = c.skills.first;
      final fail = _fail(s, deck);
      if (fail >= config.identify) return (failing: s);
      // One skill drilled for an uncertain interval: resolved when the
      // interval is no longer wide (and it knows the level).
      final (low, high) = interval(s);
      if (1 - fail >= config.identify && high - low <= config.wideClasses) {
        return (failing: null);
      }
      return null;
    }
    // Several skills implicated: one is the failing skill when it failed with
    // posterior mass [DrillConfig.identify] and no other implicated skill
    // probably did; none is when all of them know the level.
    PlacementSkill? best;
    var bestFail = 0.0;
    var othersMax = 0.0;
    for (final s in c.skills) {
      final f = _failOf(c, s);
      if (f > bestFail) {
        othersMax = math.max(othersMax, bestFail);
        bestFail = f;
        best = s;
      } else {
        othersMax = math.max(othersMax, f);
      }
    }
    // A miss gets two checks (a slip is forgiven): the failing skill is named
    // only after two isolating items of it, unless it is the only one left.
    if (bestFail >= config.identify &&
        othersMax < 0.5 &&
        (c.asked[best] ?? 0) >= config.perSkill) {
      return (failing: best);
    }
    var allKnown = true;
    for (final s in c.skills) {
      if (_failOf(c, s) > 1 - config.identify) allKnown = false;
    }
    if (allKnown &&
        c.skills.every((s) => (c.asked[s] ?? 0) >= config.perSkill)) {
      return (failing: null);
    }
    return null;
  }

  void _close(DrillCase c, DrillEnd end) {
    c.end = end;
    for (final s in c.skills) {
      c.failAtEnd[s] = _failOf(c, s);
    }
    if (identical(active, c)) active = null;
  }
}
