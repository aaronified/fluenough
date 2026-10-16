import '../models/leech_action.dart';
import 'fsrs.dart';
import 'fsrs_fit.dart';
import 'replay.dart';
import 'skill_parameters.dart';

/// One skill's reviews in one language, ready to fit: each pair's history,
/// oldest first, as the scheduler replays it.
class SkillHistory {
  SkillHistory(this.key, this.pairs);

  final SkillKey key;

  /// One history per pair, oldest first. A pair reset since (a leech's
  /// fresh start) holds only its reviews since the reset.
  final List<List<FitReview>> pairs;

  /// Every review of the skill, a reset's earlier ones included: what the
  /// automatic refit counts.
  int reviewCount = 0;

  /// Every review in [pairs].
  Iterable<FitReview> get reviews sync* {
    for (final pair in pairs) {
      yield* pair;
    }
  }
}

/// What fitting one skill in one language takes: plain data, so that it
/// can be sent to another isolate.
typedef SkillFitJob = ({
  SkillKey key,
  List<List<FitReview>> pairs,
  int reviewCount,
  List<double> inUse,
  DateTime now,
});

/// What fitting one skill gave.
typedef SkillFitResult = ({
  SkillKey key,

  /// What to keep from now on, or null when there was too little to fit
  /// (`FsrsFitOutcome.defaults`), and nothing changes.
  FittedParameters? fitted,

  /// What the skill's words would do under the set in use before, and
  /// under the set kept: for the result sheet.
  SkillOutlook before,
  SkillOutlook after,
});

/// What a set of parameters means for one skill's words: the days until a
/// word answered right now comes back, the median over the skill's words,
/// and about how many reviews the next 30 days hold if every one is
/// answered right.
typedef SkillOutlook = ({int days, int reviews});

/// How one skill in one language is paced for the learner, beside how it
/// was paced at the start: How you learn's figures, and the marks on
/// Today's skill tiles.
typedef SkillPace = ({
  SkillKey key,

  /// Every review of the skill, a reset's earlier ones included.
  int answers,

  /// Whether a set other than FSRS-6's defaults schedules the skill: its
  /// own fit, or the baseline of another language.
  bool adjusted,

  /// The outlook on FSRS-6's defaults, as every skill starts.
  SkillOutlook start,

  /// The outlook on the set that schedules the skill now: [start] when it
  /// is not [adjusted].
  SkillOutlook now,
});

/// Fitting FSRS to the learner, one skill in one language at a time
/// (ADR-0035; [FsrsFit] does the fitting). Pure, so
/// that it runs off the main thread.
abstract final class SkillFit {
  /// The days the outlook looks ahead.
  static const int outlookDays = 30;

  /// The fewest reviews a fit's window holds, and the months it reaches
  /// back: whichever holds more.
  static const int windowReviews = 1000;
  static const int windowMonths = 3;

  /// [reviews], oldest first, by skill: each pair's history as the
  /// scheduler replays it, a reset pair's from its reset on.
  static Map<SkillKey, SkillHistory> histories(
    Iterable<LoggedReview> reviews, {
    LeechEffects effects = LeechEffects.none,
  }) {
    final bySkill = <SkillKey, Map<Object, List<FitReview>>>{};
    final counts = <SkillKey, int>{};
    for (final review in reviews) {
      final skill = skillOf(review.key);
      counts[skill] = (counts[skill] ?? 0) + 1;
      final resetAt = effects.resetAt(review.key);
      if (resetAt != null && !review.at.isAfter(resetAt)) continue;
      bySkill
          .putIfAbsent(skill, () => <Object, List<FitReview>>{})
          .putIfAbsent(review.key, () => <FitReview>[])
          .add((
            grade: review.grade,
            at: review.at,
            rated: review.answerGiven == null,
          ));
    }
    return <SkillKey, SkillHistory>{
      for (final MapEntry(:key, :value) in counts.entries)
        key: SkillHistory(key, <List<FitReview>>[...?bySkill[key]?.values])
          ..reviewCount = value,
    };
  }

  /// The start of the window a fit at [now] learns from: the reviews of
  /// the last [windowMonths] months or the last [windowReviews], whichever
  /// is more. Null when every review is in it.
  static DateTime? windowStart(Iterable<FitReview> reviews, DateTime now) {
    final times = <DateTime>[for (final r in reviews) r.at]..sort();
    if (times.length <= windowReviews) return null;
    final months = DateTime(
      now.year,
      now.month - windowMonths,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );
    final lastThousand = times[times.length - windowReviews];
    return lastThousand.isBefore(months) ? lastThousand : months;
  }

  /// Whether [history] holds enough in its window to fit at [now].
  static bool canFit(SkillHistory history, DateTime now) =>
      FsrsFit.gate(
        history.pairs,
        from: windowStart(history.reviews, now),
      ).outcome !=
      FsrsFitOutcome.defaults;

  /// The job of fitting [history] at [now], starting from [inUse], the set
  /// that schedules it now.
  static SkillFitJob job(
    SkillHistory history,
    List<double> inUse,
    DateTime now,
  ) => (
    key: history.key,
    pairs: history.pairs,
    reviewCount: history.reviewCount,
    inUse: inUse,
    now: now,
  );

  /// Fits [job]: from the set in use, on its window, keeping the fitted
  /// set only if it predicts the window better (owner: as `fsrs-rs` and
  /// Anki do). Deterministic.
  static SkillFitResult run(SkillFitJob job) {
    final from = windowStart(<FitReview>[
      for (final pair in job.pairs) ...pair,
    ], job.now);
    final before = outlook(job.pairs, job.inUse, job.now);
    final fitted = FsrsFit.fit(job.pairs, start: job.inUse, from: from);
    if (fitted == null) {
      return (key: job.key, fitted: null, before: before, after: before);
    }
    final lossBefore = FsrsFit.logLoss(
      job.pairs,
      parameters: job.inUse,
      from: from,
    );
    final lossAfter = FsrsFit.logLoss(
      job.pairs,
      parameters: fitted,
      from: from,
    );
    final kept = keepBetter(
      fitted: fitted,
      inUse: job.inUse,
      lossBefore: lossBefore,
      lossAfter: lossAfter,
      at: job.now,
      reviewCount: job.reviewCount,
    );
    return (
      key: job.key,
      fitted: kept,
      before: before,
      after: kept.kept ? outlook(job.pairs, kept.values, job.now) : before,
    );
  }

  /// What a fit at [at], from [reviewCount] reviews, leaves in use: the
  /// [fitted] set if its log loss on the window, [lossAfter], is lower than
  /// [lossBefore], that of the set [inUse]; else [inUse] again, so that the
  /// next refit still waits for 10% more answers. Both losses are kept.
  static FittedParameters keepBetter({
    required List<double> fitted,
    required List<double> inUse,
    required double? lossBefore,
    required double? lossAfter,
    required DateTime at,
    required int reviewCount,
  }) {
    final better =
        lossAfter != null && (lossBefore == null || lossAfter < lossBefore);
    return FittedParameters(
      values: better ? fitted : inUse,
      fittedAt: at,
      reviewCount: reviewCount,
      lossBefore: lossBefore,
      lossAfter: lossAfter,
    );
  }

  /// How [history] is paced at [now] by [inUse], the set that schedules
  /// it, beside FSRS-6's defaults: two [outlook]s, the second only when
  /// the two sets differ.
  static SkillPace pace(
    SkillHistory history,
    List<double> inUse,
    DateTime now,
  ) {
    final adjusted = !isDefaults(inUse);
    final start = outlook(history.pairs, Fsrs.w, now);
    return (
      key: history.key,
      answers: history.reviewCount,
      adjusted: adjusted,
      start: start,
      now: adjusted ? outlook(history.pairs, inUse, now) : start,
    );
  }

  /// The [pace] of every skill [reviews] hold, oldest first, as
  /// [parameters] schedule them at [now]: what How you learn shows. Pure,
  /// so that it runs off the main thread.
  static List<SkillPace> paces(
    Iterable<LoggedReview> reviews, {
    required SkillParameters parameters,
    required DateTime now,
    LeechEffects effects = LeechEffects.none,
  }) => <SkillPace>[
    for (final MapEntry(:key, :value) in histories(
      reviews,
      effects: effects,
    ).entries)
      pace(value, parameters.of(key.language, key.mode), now),
  ];

  /// [paces], of one skill in several languages or of several skills, as
  /// one outlook at the start and one now: their reviews added, and the
  /// days of the one with the most answers. Null for none.
  static ({SkillOutlook start, SkillOutlook now})? together(
    Iterable<SkillPace> paces,
  ) {
    SkillPace? most;
    var start = 0;
    var now = 0;
    for (final pace in paces) {
      start += pace.start.reviews;
      now += pace.now.reviews;
      if (most == null || pace.answers > most.answers) most = pace;
    }
    if (most == null) return null;
    return (
      start: (days: most.start.days, reviews: start),
      now: (days: most.now.days, reviews: now),
    );
  }

  /// Whether [values] are FSRS-6's defaults exactly.
  static bool isDefaults(List<double> values) {
    if (values.length != Fsrs.w.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != Fsrs.w[i]) return false;
    }
    return true;
  }

  /// Which way a fit moved a skill, from the outlook [before] it to the
  /// one [after]: -1 for fewer reviews, 1 for more, 0 for about the same.
  /// About the same is the same days, and reviews within 5% of before.
  static int direction(SkillOutlook before, SkillOutlook after) {
    final change = after.reviews - before.reviews;
    if (change.abs() * 20 > before.reviews && change != 0) return change.sign;
    return before.days.compareTo(after.days);
  }

  /// What [parameters] mean for the words of [pairs] at [now]: each pair's
  /// state replayed with them, then the median days a right answer now
  /// would give, and the reviews of the next [outlookDays] days if each
  /// is answered right on its day. A skill with no words yet: a new word's
  /// first right answer, and none.
  static SkillOutlook outlook(
    List<List<FitReview>> pairs,
    List<double> parameters,
    DateTime now,
  ) {
    final end = now.add(const Duration(days: outlookDays));
    final days = <int>[];
    var reviews = 0;
    for (final pair in pairs) {
      var state = Fsrs.replay(pair, parameters: parameters);
      if (state == null) continue;
      days.add(
        Fsrs.review(
          state,
          Rating.good,
          now: now,
          parameters: parameters,
        ).intervalDays,
      );
      var due = state.dueAt.isBefore(now) ? now : state.dueAt;
      while (due.isBefore(end)) {
        reviews++;
        state = Fsrs.review(
          state,
          Rating.good,
          now: due,
          parameters: parameters,
        );
        due = state.dueAt;
      }
    }
    if (days.isEmpty) {
      return (
        days: Fsrs.intervalFor(parameters[2], parameters: parameters),
        reviews: 0,
      );
    }
    days.sort();
    return (days: days[days.length ~/ 2], reviews: reviews);
  }
}
