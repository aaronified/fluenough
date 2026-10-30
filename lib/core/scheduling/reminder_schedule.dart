/// When the daily reminder (#90) fires. Pure Dart, so it tests with no
/// device; the platform side only asks for the times this returns.
abstract final class ReminderSchedule {
  /// Days ahead a plan covers. A reminder is re-planned whenever the app
  /// opens, after a reboot and after a time-zone change, so a short horizon
  /// is enough and keeps the notification list small.
  static const int horizonDays = 7;

  /// The moments to remind, soonest first: at [hour]:[minute] local time on
  /// each of the next [horizonDays] days (today included) that has cards
  /// due and has not been reminded already.
  ///
  /// [dueByDay] holds the cards due by the end of each day: index 0 is
  /// today, 1 tomorrow, and so on. A day past its end holds what is due by
  /// then, backlog included, because a card stays due until it is answered.
  /// A day beyond the list counts as nothing due, so the plan never promises
  /// a reminder it cannot justify.
  ///
  /// A time already past today is skipped. [lastReminded] is the day a
  /// reminder last fired, so a re-plan on that day never fires it again
  /// ("a reminder never fires twice on one day").
  static List<DateTime> plan({
    required DateTime now,
    required int hour,
    required int minute,
    required List<int> dueByDay,
    DateTime? lastReminded,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final fires = <DateTime>[];
    final days = dueByDay.length < horizonDays ? dueByDay.length : horizonDays;
    for (var i = 0; i < days; i++) {
      if (dueByDay[i] <= 0) continue;
      final day = DateTime(today.year, today.month, today.day + i);
      if (lastReminded != null && _sameDay(lastReminded, day)) continue;
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (!at.isAfter(now)) continue;
      fires.add(at);
    }
    return fires;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
