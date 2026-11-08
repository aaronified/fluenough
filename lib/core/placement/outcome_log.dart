import 'dart:convert';

import 'placement_profile.dart';

// The local outcome log of Find my level V3 (wiki/Plan-Placement-V3.md,
// "Adapting placement to a language"): for every placement a small record of
// what it said and under which profile, later joined with the learner's own
// real reviews of the pairs it placed, to tell whether the placement was too
// high, too low, or its range too narrow or too wide. The signals feed bounded,
// reversible corrections of the profile and, if the learner opts in, an export
// for the maintainers' re-fit. Nothing here leaves the phone by itself and
// nothing is shown to the learner.
//
// No personal content: a record holds a language code, skill names, units,
// confidence words, counts and a profile version; never a card, a word, an
// answer text, audio or a date more precise than a day.
//
// Pure Dart.

/// What a placement said of one skill.
class SkillOutcome {
  const SkillOutcome({
    required this.start,
    required this.low,
    required this.high,
    required this.label,
  });

  /// The unit the learner starts at, and the unit range the run was 80% sure
  /// of (0 is the very beginning).
  final int start;
  final int low;
  final int high;

  /// The confidence word (`sure`, `fairlySure`, `notSureYet`).
  final String label;

  Map<String, Object?> toJson() => <String, Object?>{
    'start': start,
    'low': low,
    'high': high,
    'label': label,
  };

  static SkillOutcome? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['start'];
    final l = j['low'];
    final h = j['high'];
    final w = j['label'];
    if (s is! int || l is! int || h is! int || w is! String) return null;
    if (s < 0 || l < 0 || h < l || !RegExp(r'^[a-zA-Z]{1,16}$').hasMatch(w)) {
      return null;
    }
    return SkillOutcome(start: s, low: l, high: h, label: w);
  }
}

/// One placement.
class PlacementOutcome {
  const PlacementOutcome({
    required this.language,
    required this.day,
    required this.profileVersion,
    required this.band,
    required this.skills,
    this.itemsByFormat = const <String, int>{},
    this.right = 0,
    this.wrong = 0,
    this.dontKnow = 0,
    this.drillCases = 0,
    this.carefulness = 0,
    this.signals = const <String, String>{},
  });

  final String language;

  /// The day it was made, as days since 1970 (no time of day).
  final int day;

  /// The calibration profile version it was made under, and how far that
  /// profile is toward the language's gated edge (0 the default, 1 the edge):
  /// what the re-fit regresses the signals on.
  final int profileVersion;
  final double carefulness;
  final String band;
  final Map<String, SkillOutcome> skills;

  /// The run: items asked by format, answers, drill-down cases.
  final Map<String, int> itemsByFormat;
  final int right;
  final int wrong;
  final int dontKnow;
  final int drillCases;

  /// What the learner's own reviews later said of each skill
  /// ([PlacementSignal] names), once there were enough of them; empty until
  /// then.
  final Map<String, String> signals;

  PlacementOutcome withSignals(Map<String, String> next) => PlacementOutcome(
    language: language,
    day: day,
    profileVersion: profileVersion,
    band: band,
    skills: skills,
    itemsByFormat: itemsByFormat,
    right: right,
    wrong: wrong,
    dontKnow: dontKnow,
    drillCases: drillCases,
    carefulness: carefulness,
    signals: next,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'language': language,
    'day': day,
    'profile': profileVersion,
    'carefulness': carefulness,
    'band': band,
    'skills': <String, Object?>{
      for (final e in skills.entries) e.key: e.value.toJson(),
    },
    'items': itemsByFormat,
    'right': right,
    'wrong': wrong,
    'dontKnow': dontKnow,
    'drill': drillCases,
    'signals': signals,
  };

  static PlacementOutcome? fromJson(Object? j) {
    if (j is! Map) return null;
    final language = j['language'];
    final day = j['day'];
    final profile = j['profile'];
    final band = j['band'];
    final skills = j['skills'];
    if (language is! String ||
        !RegExp(r'^[a-z]{2,3}$').hasMatch(language) ||
        day is! int ||
        profile is! int ||
        band is! String ||
        skills is! Map) {
      return null;
    }
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    final items = <String, int>{};
    if (j['items'] is Map) {
      for (final e in (j['items'] as Map).entries) {
        if (e.key is String &&
            RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(e.key as String) &&
            e.value is int) {
          items[e.key as String] = count(e.value);
        }
      }
    }
    final out = <String, SkillOutcome>{};
    for (final e in skills.entries) {
      final o = SkillOutcome.fromJson(e.value);
      if (e.key is String &&
          RegExp(r'^[a-zA-Z]{2,12}$').hasMatch(e.key as String) &&
          o != null) {
        out[e.key as String] = o;
      }
    }
    final c = j['carefulness'];
    return PlacementOutcome(
      language: language,
      day: day,
      profileVersion: profile,
      band: band,
      skills: out,
      itemsByFormat: items,
      right: count(j['right']),
      wrong: count(j['wrong']),
      dontKnow: count(j['dontKnow']),
      drillCases: count(j['drill']),
      carefulness: c is num ? c.toDouble().clamp(0.0, 1.0) : 0,
      signals: <String, String>{
        if (j['signals'] is Map)
          for (final e in (j['signals'] as Map).entries)
            if (e.key is String &&
                e.value is String &&
                PlacementSignal.values.any((v) => v.name == e.value))
              e.key as String: e.value as String,
      },
    );
  }
}

/// How far [profile] is from the default toward [edge], 0 to 1: the mean over
/// the values the edge moves.
double carefulnessOf(PlacementProfile profile, PlacementProfile edge) {
  final parts = <double>[];
  void part(double v, double def, double e) {
    if (e != def) parts.add(((v - def) / (e - def)).clamp(0.0, 1.0));
  }

  const d = PlacementProfile.defaults;
  part(profile.declarationWeight, d.declarationWeight, edge.declarationWeight);
  part(profile.togetherShare, d.togetherShare, edge.togetherShare);
  part(profile.temper, d.temper, edge.temper);
  part(
    profile.standApartItems.toDouble(),
    d.standApartItems.toDouble(),
    edge.standApartItems.toDouble(),
  );
  part(profile.mixedBonus, d.mixedBonus, edge.mixedBonus);
  return parts.isEmpty ? 0 : parts.reduce((a, b) => a + b) / parts.length;
}

/// One real review of a pair a placement credited (or of the first pairs
/// above it), reduced to what the join needs: the skill, where the pair sits
/// against the placed unit, and whether it was answered right.
class ReviewSample {
  const ReviewSample({
    required this.skill,
    required this.unitsFromStart,
    required this.correct,
  });

  final String skill;

  /// The pair's unit minus the placed start unit: 0 or below is a pair the
  /// placement credited, above it a pair it did not.
  final int unitsFromStart;
  final bool correct;
}

/// What the learner's own reviews say of a placement of one skill.
enum PlacementSignal {
  /// Not enough reviews yet.
  insufficient,

  /// Consistent with the placement.
  ok,

  /// The credited pairs are answered worse than a known pair should be:
  /// placed too high.
  tooHigh,

  /// The pairs just above the start are answered right nearly always: placed
  /// too low.
  tooLow,

  /// The pairs above the range's upper edge are answered right: the range
  /// was too narrow (it missed what the learner knew).
  rangeTooNarrow,

  /// The pairs at the range's lower edge are answered no better than those
  /// outside it: the range was wider than the evidence.
  rangeTooWide,
}

/// The thresholds of the join, and how many reviews are enough.
class SignalRules {
  const SignalRules({
    this.minReviews = 30,
    this.tooHighBelow = 0.7,
    this.tooLowAbove = 0.95,
    this.aboveWindow = 3,
  });

  /// Reviews needed in a group before it says anything.
  final int minReviews;
  final double tooHighBelow;
  final double tooLowAbove;

  /// How many units above the start count as "just above".
  final int aboveWindow;
}

/// The signal of [outcome]'s [skill] given the learner's first real [reviews]
/// of that skill's pairs.
PlacementSignal signalOf(
  SkillOutcome outcome,
  Iterable<ReviewSample> reviews, {
  SignalRules rules = const SignalRules(),
}) {
  var credited = 0;
  var creditedRight = 0;
  var above = 0;
  var aboveRight = 0;
  var beyond = 0;
  var beyondRight = 0;
  for (final r in reviews) {
    final unit = outcome.start + r.unitsFromStart;
    if (r.unitsFromStart <= 0) {
      credited++;
      if (r.correct) creditedRight++;
    } else if (r.unitsFromStart <= rules.aboveWindow) {
      above++;
      if (r.correct) aboveRight++;
    }
    if (unit > outcome.high && r.unitsFromStart > 0) {
      beyond++;
      if (r.correct) beyondRight++;
    }
  }
  if (credited < rules.minReviews && above < rules.minReviews) {
    return PlacementSignal.insufficient;
  }
  if (credited >= rules.minReviews &&
      creditedRight / credited < rules.tooHighBelow) {
    return PlacementSignal.tooHigh;
  }
  if (above >= rules.minReviews && aboveRight / above >= rules.tooLowAbove) {
    // A range that already reached these pairs was too narrow only if they lie
    // beyond its upper edge; otherwise the start was too low.
    return beyond >= rules.minReviews &&
            beyondRight / beyond >= rules.tooLowAbove
        ? PlacementSignal.rangeTooNarrow
        : PlacementSignal.tooLow;
  }
  if (outcome.high - outcome.low >= 6 &&
      credited >= rules.minReviews &&
      creditedRight / credited >= 0.99 &&
      above >= rules.minReviews &&
      aboveRight / above >= 0.9) {
    return PlacementSignal.rangeTooWide;
  }
  return PlacementSignal.ok;
}

/// The tally of signals for a language: what the corrections and the re-fit
/// read.
class SignalTally {
  const SignalTally({
    this.tooHigh = 0,
    this.tooLow = 0,
    this.ok = 0,
    this.narrow = 0,
    this.wide = 0,
  });

  final int tooHigh;
  final int tooLow;
  final int ok;
  final int narrow;
  final int wide;

  int get decided => tooHigh + tooLow + ok + narrow + wide;

  SignalTally plus(PlacementSignal s) => SignalTally(
    tooHigh: tooHigh + (s == PlacementSignal.tooHigh ? 1 : 0),
    tooLow: tooLow + (s == PlacementSignal.tooLow ? 1 : 0),
    ok: ok + (s == PlacementSignal.ok ? 1 : 0),
    narrow: narrow + (s == PlacementSignal.rangeTooNarrow ? 1 : 0),
    wide: wide + (s == PlacementSignal.rangeTooWide ? 1 : 0),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'tooHigh': tooHigh,
    'tooLow': tooLow,
    'ok': ok,
    'narrow': narrow,
    'wide': wide,
  };

  static SignalTally fromJson(Object? j) {
    if (j is! Map) return const SignalTally();
    int n(String k) => j[k] is int && (j[k] as int) >= 0 ? j[k] as int : 0;
    return SignalTally(
      tooHigh: n('tooHigh'),
      tooLow: n('tooLow'),
      ok: n('ok'),
      narrow: n('narrow'),
      wide: n('wide'),
    );
  }
}

/// A bounded, reversible correction of one language's profile: how far, from
/// the default toward the language's gated edge, the profile is moved (0 to 1),
/// proposed from the signals and applied only after enough evidence.
class CorrectionRules {
  const CorrectionRules({
    this.minDecided = 40,
    this.tooHighShare = 0.15,
    this.tooLowShare = 0.4,
    this.step = 0.25,
  });

  /// Decided placements needed before any correction.
  final int minDecided;

  /// Placed-too-high share above which the profile is made more careful, and
  /// placed-too-low share above which a correction is taken back.
  final double tooHighShare;
  final double tooLowShare;

  /// How far one correction moves, as a share of the way to the edge.
  final double step;
}

/// The next [carefulness] (0 to 1) for a language with [tally] and [current]
/// carefulness, or [current] when there is not enough evidence. Never moves
/// past 0 or 1 (the default and the edge), so the profile built from it stays
/// inside the language's clamps. A language without an edge is never moved.
double correctedCarefulness({
  required SignalTally tally,
  required double current,
  required bool hasEdge,
  CorrectionRules rules = const CorrectionRules(),
}) {
  if (!hasEdge || tally.decided < rules.minDecided) return current;
  final high = tally.tooHigh / tally.decided;
  final low = tally.tooLow / tally.decided;
  if (high > rules.tooHighShare) {
    return (current + rules.step).clamp(0.0, 1.0);
  }
  if (low > rules.tooLowShare) {
    return (current - rules.step).clamp(0.0, 1.0);
  }
  return current;
}

/// The profile [carefulness] of the way from the default to [edge].
PlacementProfile profileAt(double carefulness, PlacementProfile edge) {
  final c = carefulness.clamp(0.0, 1.0);
  double mix(double def, double e) => def + (e - def) * c;
  const d = PlacementProfile.defaults;
  return PlacementProfile(
    version: d.version,
    declarationWeight: mix(d.declarationWeight, edge.declarationWeight),
    togetherShare: mix(d.togetherShare, edge.togetherShare),
    temper: mix(d.temper, edge.temper),
    standApartItems: mix(
      d.standApartItems.toDouble(),
      edge.standApartItems.toDouble(),
    ).round(),
    mixedBonus: mix(d.mixedBonus, edge.mixedBonus),
    guessScale: <String, double>{
      for (final e in edge.guessScale.entries) e.key: mix(1, e.value),
    },
    slipScale: <String, double>{
      for (final e in edge.slipScale.entries) e.key: mix(1, e.value),
    },
  ).within(edge);
}

/// The export of a learner's outcome records, for the maintainers' re-fit
/// (opt-in). The text holds the schema, the app version and the records and
/// nothing else.
String exportOutcomes(Iterable<PlacementOutcome> outcomes, String appVersion) =>
    jsonEncode(<String, Object?>{
      'schema': 1,
      'kind': 'fluenough-placement-outcomes',
      'app': appVersion,
      'outcomes': <Object?>[for (final o in outcomes) o.toJson()],
    });

/// The records of an export (or of several, concatenated by the caller),
/// skipping anything malformed.
List<PlacementOutcome> importOutcomes(String text) {
  try {
    final j = jsonDecode(text);
    if (j is! Map || j['schema'] != 1 || j['outcomes'] is! List) {
      return const <PlacementOutcome>[];
    }
    return <PlacementOutcome>[
      for (final o in j['outcomes'] as List) ?PlacementOutcome.fromJson(o),
    ];
  } on Object {
    return const <PlacementOutcome>[];
  }
}
