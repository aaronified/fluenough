import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_state.dart';
import '../../core/models/deck.dart';
import '../../core/scheduling/study_hours.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/language_glyph.dart';
import '../decks/course_hours.dart';
import 'progress_tiles.dart';

/// One language's hours: spent, and about how many are left to the end of
/// B1 (null where the language has no decks to count).
typedef LanguageHours = ({
  LanguageInfo language,
  String glyph,
  double spent,
  double? left,
});

/// The hours Progress shows (#227): for [language], or with null, for every
/// language together; and each language's own, for the popup.
class ProgressHours {
  const ProgressHours({
    required this.spent,
    required this.left,
    required this.rows,
  });

  final double spent;
  final double? left;
  final List<LanguageHours> rows;

  factory ProgressHours.of(AppState state, String? language) {
    final rows = <LanguageHours>[
      for (final choice in state.languageChoices)
        (
          language: choice,
          glyph: languageGlyph(choice, state.decks),
          spent: courseHours(state, choice.code).spent,
          left: hoursLeftToB1(state, choice.code),
        ),
    ];
    if (language != null) {
      for (final row in rows) {
        if (row.language.code == language) {
          return ProgressHours(spent: row.spent, left: row.left, rows: rows);
        }
      }
    }
    final counted = <double>[for (final row in rows) ?row.left];
    return ProgressHours(
      // Every review, those whose language cannot be told too.
      spent: StudyHours.hours(
        StudyHours.spent(state.progress.log) +
            state.settings.teachTimeTotal().time,
      ),
      left: counted.isEmpty ? null : counted.fold<double>(0, (a, b) => a + b),
      rows: rows,
    );
  }
}

/// The row of two tiles under the mastery star: "Hours spent" and "Hours
/// left", to the end of B1. A tap opens the hours of each language.
class HoursTiles extends StatelessWidget {
  const HoursTiles({super.key, required this.hours});

  final ProgressHours hours;

  static String _spent(AppLocalizations l10n, double hours) =>
      NumberFormat.decimalPatternDigits(
        locale: l10n.localeName,
        decimalDigits: 1,
      ).format(hours);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = hours.left;
    final leftText = left == null
        ? l10n.progressHoursNone
        : NumberFormat.decimalPattern(l10n.localeName).format(left.ceil());
    Widget fit(Widget child) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
    final figure = theme.textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );
    final label = left == null
        ? l10n.progressHoursNoneSemantics
        : l10n.progressHoursLeftSemantics(left.ceil());
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '${l10n.progressHoursSpentSemantics(hours.spent)}. $label',
      onTap: () => showHoursPopup(context, hours),
      // hint-ok: shows text
      child: InkWell(
        key: const ValueKey<String>('hours-tiles'),
        borderRadius: BorderRadius.circular(AppRadii.group),
        onTap: () => showHoursPopup(context, hours),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 1,
                child: ProgressTile(
                  icon: Icons.schedule,
                  color: scheme.surfaceContainerHigh,
                  title: l10n.progressHoursSpentTitle,
                  titleColor: scheme.onSurfaceVariant,
                  child: fit(
                    Text(_spent(l10n, hours.spent), maxLines: 1, style: figure),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: ProgressTile(
                  icon: Icons.hourglass_empty,
                  color: scheme.surfaceContainerHigh,
                  title: l10n.progressHoursLeftTitle,
                  titleColor: scheme.onSurfaceVariant,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      fit(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            if (left != null) ...<Widget>[
                              Text(
                                l10n.progressHoursAbout,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(leftText, maxLines: 1, style: figure),
                          ],
                        ),
                      ),
                      Text(
                        l10n.progressHoursToB1,
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
        ),
      ),
    );
  }
}

/// The popup the hours tiles open: hours spent and left, a row a language.
Future<void> showHoursPopup(BuildContext context, ProgressHours hours) =>
    showDialog<void>(
      context: context,
      builder: (context) => _HoursPopup(hours: hours),
    );

class _HoursPopup extends StatelessWidget {
  const _HoursPopup({required this.hours});

  final ProgressHours hours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = NumberFormat.decimalPattern(l10n.localeName);
    Widget figure(String value, String caption) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          caption,
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    Widget row(Widget name, double spent, double? left) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: name),
          const SizedBox(width: 12),
          figure(
            HoursTiles._spent(l10n, spent),
            l10n.progressHoursSpentCaption,
          ),
          const SizedBox(width: 16),
          figure(
            left == null ? l10n.progressHoursNone : count.format(left.ceil()),
            l10n.progressHoursLeftCaption,
          ),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l10n.progressHoursPopupTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final entry in hours.rows)
                row(
                  Row(
                    children: <Widget>[
                      LanguageGlyphTile(
                        glyph: entry.glyph,
                        language: entry.language,
                        background: scheme.secondaryContainer,
                        foreground: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.language.name)),
                    ],
                  ),
                  entry.spent,
                  entry.left,
                ),
              const Divider(),
              row(
                Text(
                  l10n.progressHoursTotal,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                hours.rows.fold<double>(0, (a, r) => a + r.spent),
                hours.rows.any((r) => r.left != null)
                    ? hours.rows.fold<double>(0, (a, r) => a + (r.left ?? 0))
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.progressHoursPopupNote,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
