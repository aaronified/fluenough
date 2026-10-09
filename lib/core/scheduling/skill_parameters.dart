import '../models/drill_mode.dart';
import '../models/review_event.dart';
import 'ability.dart';
import 'fsrs.dart';

/// One skill in one language: what FSRS's parameters are fitted and kept
/// for (ADR-0035).
typedef SkillKey = ({String language, DrillMode mode});

/// The skill a pair is scheduled in: its card's language, and its mode.
SkillKey skillOf(ProgressKey key) =>
    (language: Abilities.languageOf(key.cardId), mode: key.mode);

/// FSRS's 21 parameters as fitted to the learner for one skill in one
/// language, and what the fit was made from.
///
/// Not derived: a fit starts from the one before it, so the set cannot be
/// worked out again from the review log. It is kept in the profile's
/// database and in the backup, so that a restored phone schedules exactly
/// as before.
class FittedParameters {
  FittedParameters({
    required List<double> values,
    required this.fittedAt,
    required this.reviewCount,
    this.lossBefore,
    this.lossAfter,
  }) : values = List<double>.unmodifiable(values) {
    if (values.length != Fsrs.w.length) {
      throw ArgumentError.value(
        values.length,
        'values',
        'must hold ${Fsrs.w.length} values, w0 to w20',
      );
    }
  }

  /// The set in use from this fit on, w0 to w20: the one fitted when it
  /// predicted the window better than the set in use before, else that set.
  final List<double> values;

  /// When the fit ran.
  final DateTime fittedAt;

  /// How many reviews the skill had in the language when it was fitted:
  /// the automatic refit waits for 10% more.
  final int reviewCount;

  /// The log loss, on the fit's window, of the set in use before the fit,
  /// and of the set the fit gave. Lower is better; the fitted set was kept
  /// when [lossAfter] is below [lossBefore]. Null when there was nothing
  /// to predict.
  final double? lossBefore;
  final double? lossAfter;

  /// Whether the fit's own set was kept.
  bool get kept =>
      lossAfter != null && (lossBefore == null || lossAfter! < lossBefore!);

  @override
  bool operator ==(Object other) =>
      other is FittedParameters &&
      other.fittedAt == fittedAt &&
      other.reviewCount == reviewCount &&
      other.lossBefore == lossBefore &&
      other.lossAfter == lossAfter &&
      _sameValues(other.values, values);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(values), fittedAt, reviewCount);

  @override
  String toString() =>
      'FittedParameters($values, at $fittedAt, from $reviewCount reviews, '
      'loss $lossBefore -> $lossAfter)';

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Which parameters schedule each pair (owner, 2026-10-09):
///
/// 1. the skill's own fit in the pair's language;
/// 2. else that skill's fit in the language most recently studied, by its
///    last review, of those that have one: "the fit on one language should
///    be used as the baseline on the next language". A set that is
///    FSRS-6's defaults is not one: a first fit that lost before any
///    language had a fit stores them, and a baseline of them would hide a
///    real fit in a language studied less recently;
/// 3. else FSRS-6's defaults.
///
/// Immutable. The baseline moves when another language becomes the one
/// most recently studied, so whoever holds the states rebuilds them when
/// [sameAs] says the choice changed: replaying the log with one choice
/// always gives the states recording with it gives.
class SkillParameters {
  SkillParameters({
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
    Map<String, DateTime> lastStudied = const <String, DateTime>{},
  }) : fitted = Map<SkillKey, FittedParameters>.unmodifiable(fitted),
       lastStudied = Map<String, DateTime>.unmodifiable(lastStudied) {
    for (final MapEntry(:key, :value) in this.fitted.entries) {
      if (_isDefaults(value.values)) continue;
      final current = _baseline[key.mode];
      if (current == null || _isLater(key.language, current)) {
        _baseline[key.mode] = key.language;
      }
    }
  }

  /// No fit anywhere: every pair on FSRS-6's defaults.
  static final SkillParameters none = SkillParameters();

  /// The skills fitted, by language and mode.
  final Map<SkillKey, FittedParameters> fitted;

  /// When each language was last studied: its latest review.
  final Map<String, DateTime> lastStudied;

  /// For each mode, the language whose fit a language without one uses.
  final Map<DrillMode, String> _baseline = <DrillMode, String>{};

  static bool _isDefaults(List<double> values) {
    for (var i = 0; i < Fsrs.w.length; i++) {
      if (values[i] != Fsrs.w[i]) return false;
    }
    return true;
  }

  /// Whether [a] was studied after [b], ties by code, so that the choice
  /// never depends on the order of a map.
  bool _isLater(String a, String b) {
    final at = lastStudied[a];
    final bt = lastStudied[b];
    if (at == null || bt == null) {
      if (at != bt) return at != null;
      return a.compareTo(b) < 0;
    }
    final byTime = at.compareTo(bt);
    return byTime != 0 ? byTime > 0 : a.compareTo(b) < 0;
  }

  /// The language whose fit schedules [mode] in [language], or null for
  /// FSRS-6's defaults.
  String? sourceOf(String language, DrillMode mode) =>
      fitted.containsKey((language: language, mode: mode))
      ? language
      : _baseline[mode];

  /// The parameters that schedule [mode] in [language].
  List<double> of(String language, DrillMode mode) {
    final source = sourceOf(language, mode);
    return source == null
        ? Fsrs.w
        : fitted[(language: source, mode: mode)]!.values;
  }

  /// The parameters that schedule the pair [key].
  List<double> forPair(ProgressKey key) {
    final skill = skillOf(key);
    return of(skill.language, skill.mode);
  }

  /// These, with [language] studied at [at].
  SkillParameters studied(String language, DateTime at) {
    final last = lastStudied[language];
    if (last != null && !at.isAfter(last)) return this;
    return SkillParameters(
      fitted: fitted,
      lastStudied: <String, DateTime>{...lastStudied, language: at},
    );
  }

  /// These, with [key] fitted to [value].
  SkillParameters withFit(SkillKey key, FittedParameters value) =>
      SkillParameters(
        fitted: <SkillKey, FittedParameters>{...fitted, key: value},
        lastStudied: lastStudied,
      );

  /// These, with the fits in [others] added: of two for one skill, the
  /// later fit.
  SkillParameters merged(Map<SkillKey, FittedParameters> others) {
    final all = <SkillKey, FittedParameters>{...fitted};
    for (final MapEntry(:key, :value) in others.entries) {
      final mine = all[key];
      if (mine == null || value.fittedAt.isAfter(mine.fittedAt)) {
        all[key] = value;
      }
    }
    return SkillParameters(fitted: all, lastStudied: lastStudied);
  }

  /// Whether every pair is scheduled by the same parameters under [other]
  /// as under these.
  bool sameAs(SkillParameters other) {
    if (!identical(other.fitted, fitted)) {
      if (other.fitted.length != fitted.length) return false;
      for (final MapEntry(:key, :value) in fitted.entries) {
        if (other.fitted[key] != value) return false;
      }
    }
    if (other._baseline.length != _baseline.length) return false;
    for (final MapEntry(:key, :value) in _baseline.entries) {
      if (other._baseline[key] != value) return false;
    }
    return true;
  }

  /// When each language in [reviews] was last studied.
  static Map<String, DateTime> lastStudiedIn(
    Iterable<({String cardId, DateTime at})> reviews,
  ) {
    final last = <String, DateTime>{};
    for (final r in reviews) {
      final language = Abilities.languageOf(r.cardId);
      final seen = last[language];
      if (seen == null || r.at.isAfter(seen)) last[language] = r.at;
    }
    return last;
  }
}
