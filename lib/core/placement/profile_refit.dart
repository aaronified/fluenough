import 'dart:convert';

import 'outcome_log.dart';
import 'placement_profile.dart';

// The re-fit of the calibration profile from collected outcome exports (the
// maintainers' tool `tool/placement_refit.dart` is a thin shell over this).
// It moves a language's profile along the one line the gates allow, from the
// default toward the language's gated edge ([kGatedEdges]), and only when
// there is enough evidence; it never writes a value outside the clamps, never
// moves a language that has no edge, and says why when it does not move.
//
// Pure Dart.

/// What a language's fit came to.
class RefitResult {
  const RefitResult({
    required this.language,
    required this.moved,
    required this.reason,
    required this.carefulness,
    required this.outcomes,
  });

  final String language;
  final bool moved;
  final String reason;

  /// The carefulness the profile is left at (0 the default, 1 the edge).
  final double carefulness;

  /// The decided placements the fit read.
  final int outcomes;
}

/// The rules of a fit.
class RefitRules {
  const RefitRules({
    this.minOutcomes = 200,
    this.minPerLevel = 30,
    this.targetTooHigh = 0.05,
  });

  /// Decided placements needed, and the least a carefulness value must have
  /// behind it for the line to be fitted at all.
  final int minOutcomes;
  final int minPerLevel;

  /// The share of placements that may be too high.
  final double targetTooHigh;
}

/// Fits one language from its [outcomes]: the share placed too high is
/// regressed on the carefulness it was made under, and the carefulness at
/// which the line reaches the target is the new one. Holds at [current] when
/// there is no edge, too little evidence, no variation in carefulness to fit a
/// line from, or a line that does not fall with carefulness.
RefitResult refitLanguage(
  String language,
  Iterable<PlacementOutcome> outcomes, {
  required double current,
  RefitRules rules = const RefitRules(),
}) {
  RefitResult held(String why, int n) => RefitResult(
    language: language,
    moved: false,
    reason: why,
    carefulness: current,
    outcomes: n,
  );

  if (!kGatedEdges.containsKey(language)) {
    return held('no gated edge for $language: no value may move', 0);
  }
  // One point per decided skill: (carefulness, placed too high).
  final points = <(double, bool)>[];
  for (final o in outcomes) {
    if (o.language != language) continue;
    for (final s in o.signals.values) {
      if (s == PlacementSignal.insufficient.name) continue;
      points.add((o.carefulness, s == PlacementSignal.tooHigh.name));
    }
  }
  if (points.length < rules.minOutcomes) {
    return held(
      'only ${points.length} decided placements, ${rules.minOutcomes} needed',
      points.length,
    );
  }
  // The levels (rounded to a tenth) with enough behind them.
  final byLevel = <int, List<bool>>{};
  for (final (c, high) in points) {
    (byLevel[(c * 10).round()] ??= <bool>[]).add(high);
  }
  final usable = <int, List<bool>>{
    for (final e in byLevel.entries)
      if (e.value.length >= rules.minPerLevel) e.key: e.value,
  };
  if (usable.length < 2) {
    return held(
      'the placements were made under one carefulness only: no line to fit',
      points.length,
    );
  }
  // Least squares of the too-high rate on the carefulness.
  var n = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
  for (final e in usable.entries) {
    final x = e.key / 10;
    for (final high in e.value) {
      final y = high ? 1.0 : 0.0;
      n++;
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
    }
  }
  final denom = n * sxx - sx * sx;
  if (denom.abs() < 1e-9) return held('no variation to fit', points.length);
  final slope = (n * sxy - sx * sy) / denom;
  final intercept = (sy - slope * sx) / n;
  if (slope > -0.05) {
    return held(
      'the too-high rate does not fall with carefulness (slope '
      '${slope.toStringAsFixed(3)}): the line cannot be used',
      points.length,
    );
  }
  final target = ((rules.targetTooHigh - intercept) / slope).clamp(0.0, 1.0);
  final rounded = (target * 20).round() / 20;
  return RefitResult(
    language: language,
    moved: rounded != current,
    reason: rounded == current
        ? 'the fit agrees with the current profile'
        : 'fitted from ${points.length} decided placements',
    carefulness: rounded,
    outcomes: points.length,
  );
}

/// [assetText] (the profile asset) with each language of [results] that moved
/// set to its fitted profile, the version raised, and `fitted` recorded. The
/// values are those of [profileAt] and clamped by the language's edge, so the
/// file can never leave the clamps. Returns the new text.
String applyRefit(String assetText, Iterable<RefitResult> results) {
  final json = jsonDecode(assetText) as Map<String, dynamic>;
  final languages = Map<String, dynamic>.of(
    (json['languages'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{},
  );
  for (final r in results) {
    final edge = kGatedEdges[r.language];
    if (!r.moved || edge == null) continue;
    final profile = profileAt(r.carefulness, edge);
    final old = languages[r.language] is Map
        ? Map<String, dynamic>.of(
            (languages[r.language] as Map).cast<String, dynamic>(),
          )
        : <String, dynamic>{};
    final was = old['version'] is int ? old['version'] as int : 1;
    final values = profile.toJson()
      ..remove('version')
      ..remove('secondsScale')
      ..remove('cognateThreshold')
      ..remove('f4DecoyKey')
      ..remove('climbQuantile');
    languages[r.language] = <String, dynamic>{
      ...old,
      ...values,
      'version': was + 1,
      'fitted': <String, Object?>{
        'outcomes': r.outcomes,
        'carefulness': r.carefulness,
      },
    };
  }
  json['languages'] = languages;
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
