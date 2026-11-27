/// What the Android home-screen widget shows (#108): the shown language,
/// the cards due and the streak. Pure Dart, so it tests with no device; the
/// platform side only stores the text this makes and draws it.
///
/// The widget draws from stored text and never runs the app, so it cannot
/// work out a new day for itself. The text for today and for the next day
/// are both stored, with the day they were worked out for, and the widget
/// picks the right one when it draws ([HomeWidgetKeys.day]).
library;

/// The names the text is stored under, shared with
/// `tools/android_templates/widget/DueWidgetProvider.kt`, which reads them.
abstract final class HomeWidgetKeys {
  /// The shown language's name, or empty when there is none.
  static const String language = 'hw_language';

  /// The day the other keys were worked out for, as `yyyy-mm-dd`, local time.
  static const String day = 'hw_day';

  /// The line about cards due, for [day] itself.
  static const String dueToday = 'hw_due_today';

  /// The line about cards due, for the day after [day].
  static const String dueNext = 'hw_due_next';

  /// The streak line for [day], empty with no streak.
  static const String streakToday = 'hw_streak_today';

  /// The streak line for the day after [day], empty when it will have ended.
  static const String streakNext = 'hw_streak_next';

  /// What the widget says when what it holds is older than that.
  static const String open = 'hw_open';

  /// The class of the widget's provider, as `home_widget` names it.
  static const String androidName = 'DueWidgetProvider';
}

/// The widget's words, chosen where the locale is known.
class HomeWidgetTexts {
  const HomeWidgetTexts({
    required this.due,
    required this.allDone,
    required this.streak,
    required this.open,
  });

  /// The line for [count] cards due, [count] above zero.
  final String Function(int count) due;

  /// The line for nothing due.
  final String allDone;

  /// The line for a streak of [days] days, [days] above zero.
  final String Function(int days) streak;

  /// The line when the widget has not been refreshed for days.
  final String open;
}

/// The numbers behind the widget, worked out for [day].
class HomeWidgetSummary {
  const HomeWidgetSummary({
    required this.language,
    required this.day,
    required this.dueToday,
    required this.dueNext,
    required this.streak,
    required this.practisedToday,
  });

  /// The shown language's name, or empty when no language is shown.
  final String language;

  /// The calendar day the numbers are for (only the date part matters).
  final DateTime day;

  /// Cards due by the end of [day], those already due included.
  final int dueToday;

  /// Cards due by the end of the day after [day]: what is left to do then if
  /// nothing more is answered.
  final int dueNext;

  /// Days in a row with a review, as the Today page counts them: a day with
  /// none yet does not end it.
  final int streak;

  /// Whether a review was answered on [day].
  final bool practisedToday;

  /// The streak on the day after [day]: it holds only if [day] had a review.
  int get streakNext => practisedToday ? streak : 0;

  /// [day] as `yyyy-mm-dd`.
  static String dayKey(DateTime day) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  /// The text to store, by [HomeWidgetKeys].
  Map<String, String> toData(HomeWidgetTexts texts) {
    String due(int count) => count <= 0 ? texts.allDone : texts.due(count);
    String streakLine(int days) => days <= 0 ? '' : texts.streak(days);
    return <String, String>{
      HomeWidgetKeys.language: language,
      HomeWidgetKeys.day: dayKey(day),
      HomeWidgetKeys.dueToday: due(dueToday),
      HomeWidgetKeys.dueNext: due(dueNext),
      HomeWidgetKeys.streakToday: streakLine(streak),
      HomeWidgetKeys.streakNext: streakLine(streakNext),
      HomeWidgetKeys.open: texts.open,
    };
  }

  /// When to have the widget drawn again with no help from the app: a minute
  /// into each of the next two days. The first turns it to the next day's
  /// line, the second to [HomeWidgetKeys.open] if the app has not been
  /// opened since.
  static List<DateTime> refreshTimes(DateTime now) => <DateTime>[
    for (var i = 1; i <= 2; i++)
      DateTime(now.year, now.month, now.day + i, 0, 1),
  ];
}
