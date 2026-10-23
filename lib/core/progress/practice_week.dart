import '../models/review_event.dart';
import '../scheduling/study_hours.dart';

/// The minutes a day a learner is asked for until they choose their own
/// (#485: the default for existing learners).
const Duration kDefaultDailyQuota = Duration(minutes: 15);

/// Midnight at the start of [time]'s calendar day, in its own time zone (a
/// UTC time stays UTC), the way the app's `dateOnly` does. Core cannot
/// import the app, so this is its twin.
DateTime calendarDay(DateTime time) => time.isUtc
    ? DateTime.utc(time.year, time.month, time.day)
    : DateTime(time.year, time.month, time.day);

/// [day] moved by whole calendar days, safe across daylight saving changes.
DateTime _addDays(DateTime day, int days) => day.isUtc
    ? DateTime.utc(day.year, day.month, day.day + days)
    : DateTime(day.year, day.month, day.day + days);

/// What one day of practice looks like on the 7-day calendar.
enum DayMark {
  /// No practice at all.
  none,

  /// Some practice, under the quota.
  some,

  /// The quota met.
  met,

  /// Twice the quota or more.
  twice,
}

/// One day of the calendar.
class PracticeDay {
  const PracticeDay({
    required this.day,
    required this.spent,
    required this.mark,
    required this.joinsNext,
  });

  final DateTime day;

  /// The time on cards that day (`StudyHours.spent`).
  final Duration spent;
  final DayMark mark;

  /// Whether this day and the next were both practised, so that a line
  /// joins them: the streak.
  final bool joinsNext;
}

/// [spent] against [quota]. Any answer at all is [DayMark.some], whatever
/// the time, which a day's [practised] says.
DayMark markOf(Duration spent, Duration quota, {required bool practised}) {
  if (!practised) return DayMark.none;
  if (spent >= quota * 2) return DayMark.twice;
  if (spent >= quota) return DayMark.met;
  return DayMark.some;
}

/// The last [days] days ending on [now]'s day, oldest first, from [reviews]
/// (of one language, or of every language for All: any practice counts).
List<PracticeDay> practiceWeek(
  Iterable<ReviewEvent> reviews, {
  required DateTime now,
  Duration quota = kDefaultDailyQuota,
  int days = 7,
}) {
  final today = calendarDay(now);
  final first = _addDays(today, -(days - 1));
  final byDay = <DateTime, List<ReviewEvent>>{};
  for (final e in reviews) {
    // The event's own calendar date, as a day in [now]'s zone, so that the
    // days compare and key together.
    final date = calendarDay(e.at);
    final day = today.isUtc
        ? DateTime.utc(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day);
    if (day.isBefore(first) || day.isAfter(today)) continue;
    (byDay[day] ??= <ReviewEvent>[]).add(e);
  }
  // DateTime's own day arithmetic, so a daylight saving change does not
  // skip or repeat a day.
  final dates = <DateTime>[for (var i = 0; i < days; i++) _addDays(first, i)];
  return <PracticeDay>[
    for (final (i, day) in dates.indexed)
      PracticeDay(
        day: day,
        spent: StudyHours.spent(byDay[day] ?? const <ReviewEvent>[]),
        mark: markOf(
          StudyHours.spent(byDay[day] ?? const <ReviewEvent>[]),
          quota,
          practised: byDay.containsKey(day),
        ),
        joinsNext:
            i < days - 1 &&
            byDay.containsKey(day) &&
            byDay.containsKey(dates[i + 1]),
      ),
  ];
}
