import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'today_numbers.dart';

/// The streak, the words taught today, and the last seven
/// days, each ticked if practised.
///
/// Design screen `today`, the section named "Streak". The week is drawn in
/// colour, so each day also carries a screen-reader label (`todayWeekDay`).
/// It shows the seven days ending today, today last, as the design does; the
/// letters come from the locale, so they follow the real dates.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.numbers});

  final TodayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.todayStreakSection,
      child: Container(
        padding: const EdgeInsetsDirectional.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(
                    Icons.local_fire_department_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.todayStreak(numbers.streak),
                          style: theme.textTheme.sectionTitle,
                        ),
                        Text(
                          l10n.todayNewWords(numbers.newWords),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Week(days: numbers.week),
          ],
        ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.days});

  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final letter = DateFormat.EEEEE(locale);
    final name = DateFormat.EEEE(locale);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: <Widget>[
        for (final day in days)
          Expanded(
            child: Semantics(
              container: true,
              label: l10n.todayWeekDay(name.format(day.date), day.status.name),
              excludeSemantics: true,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.status == WeekDayStatus.done
                          ? scheme.primary
                          : null,
                      border: Border.all(
                        width: 2,
                        color: day.status == WeekDayStatus.other
                            ? scheme.outlineVariant
                            : scheme.primary,
                      ),
                    ),
                    child: day.status == WeekDayStatus.done
                        ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    letter.format(day.date),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
