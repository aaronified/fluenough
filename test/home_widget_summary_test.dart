// The home-screen widget's numbers and text (#108): what is stored for today
// and for the next day, when nothing is due, when a streak lapses, and when
// the phone is asked to draw the widget again.

import 'package:fluenough/core/widget/home_widget_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const HomeWidgetTexts _texts = HomeWidgetTexts(
  due: _due,
  allDone: 'All done for today',
  streak: _streak,
  open: 'Open the app to update',
);

String _due(int count) => '$count due';
String _streak(int days) => '$days day streak';

HomeWidgetSummary _summary({
  int dueToday = 12,
  int dueNext = 15,
  int streak = 9,
  bool practisedToday = true,
}) => HomeWidgetSummary(
  language: 'Telugu',
  day: DateTime(2026, 11, 5, 19, 30),
  dueToday: dueToday,
  dueNext: dueNext,
  streak: streak,
  practisedToday: practisedToday,
);

void main() {
  group('the text stored for the widget', () {
    test('holds today and the next day, with the day they are for', () {
      final data = _summary().toData(_texts);
      expect(data, <String, String>{
        HomeWidgetKeys.language: 'Telugu',
        HomeWidgetKeys.day: '2026-11-05',
        HomeWidgetKeys.dueToday: '12 due',
        HomeWidgetKeys.dueNext: '15 due',
        HomeWidgetKeys.streakToday: '9 day streak',
        HomeWidgetKeys.streakNext: '9 day streak',
        HomeWidgetKeys.open: 'Open the app to update',
      });
    });

    test('says all done when nothing is due, today or the next day', () {
      final data = _summary(dueToday: 0, dueNext: 0).toData(_texts);
      expect(data[HomeWidgetKeys.dueToday], 'All done for today');
      expect(data[HomeWidgetKeys.dueNext], 'All done for today');
      final later = _summary(dueToday: 0, dueNext: 4).toData(_texts);
      expect(later[HomeWidgetKeys.dueNext], '4 due');
    });

    test('keeps a streak into the next day only if today had a review', () {
      final unpractised = _summary(practisedToday: false).toData(_texts);
      expect(unpractised[HomeWidgetKeys.streakToday], '9 day streak');
      expect(
        unpractised[HomeWidgetKeys.streakNext],
        '',
        reason: 'a day with no review ends the streak at the next midnight',
      );
      expect(_summary(practisedToday: false).streakNext, 0);
      expect(_summary().streakNext, 9);
    });

    test('has no streak line without a streak', () {
      final data = _summary(streak: 0).toData(_texts);
      expect(data[HomeWidgetKeys.streakToday], '');
      expect(data[HomeWidgetKeys.streakNext], '');
    });

    test('names the day with two digits for the month and the day', () {
      expect(
        HomeWidgetSummary.dayKey(DateTime(2027, 1, 3, 23, 59)),
        '2027-01-03',
      );
    });
  });

  group('when the phone draws the widget again by itself', () {
    test('is a minute into each of the next two days', () {
      expect(
        HomeWidgetSummary.refreshTimes(DateTime(2026, 11, 5, 19, 30)),
        <DateTime>[DateTime(2026, 11, 6, 0, 1), DateTime(2026, 11, 7, 0, 1)],
      );
    });

    test('rolls over the end of a month and a year', () {
      expect(
        HomeWidgetSummary.refreshTimes(DateTime(2026, 12, 31, 23, 59)),
        <DateTime>[DateTime(2027, 1, 1, 0, 1), DateTime(2027, 1, 2, 0, 1)],
      );
    });
  });
}
