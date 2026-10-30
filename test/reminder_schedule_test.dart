import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/reminder_schedule.dart';

void main() {
  final morning = DateTime(2026, 10, 30, 8, 0);

  test('reminds at the chosen time on each day with cards due', () {
    final fires = ReminderSchedule.plan(
      now: morning,
      hour: 19,
      minute: 30,
      dueByDay: <int>[12, 0, 3],
    );
    expect(fires, <DateTime>[
      DateTime(2026, 10, 30, 19, 30),
      DateTime(2026, 11, 1, 19, 30),
    ]);
  });

  test('says nothing on a day with nothing due', () {
    expect(
      ReminderSchedule.plan(
        now: morning,
        hour: 19,
        minute: 30,
        dueByDay: <int>[0, 0, 0, 0],
      ),
      isEmpty,
    );
  });

  test('skips today once the time has passed, and never fires twice a day', () {
    final evening = DateTime(2026, 10, 30, 20, 0);
    expect(
      ReminderSchedule.plan(
        now: evening,
        hour: 19,
        minute: 30,
        dueByDay: <int>[5, 5],
      ),
      <DateTime>[DateTime(2026, 10, 31, 19, 30)],
    );
    expect(
      ReminderSchedule.plan(
        now: morning,
        hour: 19,
        minute: 30,
        dueByDay: <int>[5, 5],
        lastReminded: DateTime(2026, 10, 30, 7, 0),
      ),
      <DateTime>[DateTime(2026, 10, 31, 19, 30)],
    );
  });

  test('plans across a month end and no further than a week', () {
    final fires = ReminderSchedule.plan(
      now: DateTime(2026, 10, 30, 8),
      hour: 9,
      minute: 0,
      dueByDay: List<int>.filled(20, 1),
    );
    expect(fires.length, ReminderSchedule.horizonDays);
    expect(fires[2], DateTime(2026, 11, 1, 9, 0));
  });
}
