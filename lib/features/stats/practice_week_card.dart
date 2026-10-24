import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/progress/practice_week.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The last seven days, oldest first, today last: one mark a day and no
/// legend (#678).
///
/// - a filled flame: the day's quota met;
/// - two overlapping flames, only the front one filled: twice the quota or
///   more;
/// - a filled dot: some practice;
/// - an empty dot: none.
///
/// A line joins the marks of two days both practised, so a run reads as the
/// streak. Each day is one labelled image for screen readers, and its
/// initial is hidden from them.
///
/// The marks are Material's equivalents of Tabler's `flame`,
/// `circle-filled` and `circle`.
class PracticeWeekCard extends StatelessWidget {
  const PracticeWeekCard({super.key, required this.week, required this.quota});

  final List<PracticeDay> week;
  final Duration quota;

  /// The flame's colour, as the mockup's: a dark orange on light, a pale
  /// one on dark.
  static Color fireOf(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFFFB77C)
      : const Color(0xFFA84300);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fire = fireOf(theme.brightness);
    final locale = l10n.localeName;
    final minutes = quota.inMinutes;

    String state(DayMark mark) => switch (mark) {
      DayMark.none => l10n.progressDayNone,
      DayMark.some => l10n.progressDaySome,
      DayMark.met => l10n.progressDayMet,
      DayMark.twice => l10n.progressDayTwice,
    };

    Widget mark(PracticeDay day) {
      const size = 26.0;
      return switch (day.mark) {
        DayMark.met => Icon(
          Icons.local_fire_department,
          size: size,
          color: fire,
        ),
        DayMark.twice => SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: <Widget>[
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Icon(
                  Icons.local_fire_department_outlined,
                  size: size * 0.8,
                  color: fire,
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                child: Icon(
                  Icons.local_fire_department,
                  size: size * 0.8,
                  color: fire,
                ),
              ),
            ],
          ),
        ),
        DayMark.some => Icon(
          Icons.circle,
          size: size - 8,
          color: scheme.primary,
        ),
        DayMark.none => Icon(
          Icons.circle_outlined,
          size: size - 8,
          color: scheme.onSurfaceVariant,
        ),
      };
    }

    final today = week.last.day;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Semantics(
        container: true,
        label: l10n.progressWeekLabel(minutes),
        child: Row(
          children: <Widget>[
            for (final day in week)
              Expanded(
                child: Column(
                  children: <Widget>[
                    Semantics(
                      image: true,
                      label: () {
                        final name = DateFormat.EEEE(locale).format(day.day);
                        final mins = day.spent.inMinutes;
                        return day.day == today
                            ? l10n.progressDayLabelToday(
                                name,
                                state(day.mark),
                                mins,
                                minutes,
                              )
                            : l10n.progressDayLabel(
                                name,
                                state(day.mark),
                                mins,
                                minutes,
                              );
                      }(),
                      excludeSemantics: true,
                      child: SizedBox(
                        height: 32,
                        child: LayoutBuilder(
                          builder: (context, box) => Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: <Widget>[
                              mark(day),
                              // Out of the mark's half-width, over to the
                              // next day's: the streak's line.
                              if (day.joinsNext)
                                PositionedDirectional(
                                  start: box.maxWidth / 2 + 16,
                                  width: box.maxWidth - 32,
                                  top: 15,
                                  height: 3,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: fire,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ExcludeSemantics(
                      child: Text(
                        DateFormat.EEEEE(locale).format(day.day),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: day.day == today
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: day.day == today
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
