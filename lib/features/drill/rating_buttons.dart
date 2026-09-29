import 'package:flutter/material.dart';

import '../../core/grading/self_grade.dart';
import '../../l10n/app_localizations.dart';

/// Recognition's four self-rating buttons: Again, Hard, Good, Easy, each
/// with when the card would next be due.
///
/// One connected row, 68 tall and 4 apart, round (28) at the group's outer
/// ends and 10 inside, as the design draws it. At large text sizes the row
/// becomes two rows of two, so that no label is broken mid-word.
class RatingButtons extends StatelessWidget {
  const RatingButtons({
    super.key,
    required this.intervalFor,
    required this.onRate,
  });

  /// Days until the card is next due if rated so: `ProgressStore.preview`.
  /// Null in number practice, which schedules nothing: no interval is shown.
  final int Function(SelfGrade grade)? intervalFor;

  final ValueChanged<SelfGrade> onRate;

  static const double _outer = 28;
  static const double _inner = 10;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final large = MediaQuery.textScalerOf(context).scale(16) >= 24;

    Widget button(SelfGrade grade, BorderRadiusDirectional radius) => Expanded(
      child: _RatingButton(
        grade: grade,
        label: _label(l10n, grade),
        interval: switch (intervalFor) {
          final interval? => l10n.rateInterval(interval(grade)),
          null => null,
        },
        radius: radius,
        onPressed: () => onRate(grade),
      ),
    );

    Widget row(List<Widget> buttons) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < buttons.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _gap),
            buttons[i],
          ],
        ],
      ),
    );

    const o = Radius.circular(_outer);
    const n = Radius.circular(_inner);
    final Widget content = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              row(<Widget>[
                button(
                  SelfGrade.again,
                  const BorderRadiusDirectional.only(
                    topStart: o,
                    topEnd: n,
                    bottomStart: n,
                    bottomEnd: n,
                  ),
                ),
                button(
                  SelfGrade.hard,
                  const BorderRadiusDirectional.only(
                    topStart: n,
                    topEnd: o,
                    bottomStart: n,
                    bottomEnd: n,
                  ),
                ),
              ]),
              const SizedBox(height: _gap),
              row(<Widget>[
                button(
                  SelfGrade.good,
                  const BorderRadiusDirectional.only(
                    topStart: n,
                    topEnd: n,
                    bottomStart: o,
                    bottomEnd: n,
                  ),
                ),
                button(
                  SelfGrade.easy,
                  const BorderRadiusDirectional.only(
                    topStart: n,
                    topEnd: n,
                    bottomStart: n,
                    bottomEnd: o,
                  ),
                ),
              ]),
            ],
          )
        : row(<Widget>[
            button(
              SelfGrade.again,
              const BorderRadiusDirectional.horizontal(start: o, end: n),
            ),
            button(SelfGrade.hard, const BorderRadiusDirectional.all(n)),
            button(SelfGrade.good, const BorderRadiusDirectional.all(n)),
            button(
              SelfGrade.easy,
              const BorderRadiusDirectional.horizontal(start: n, end: o),
            ),
          ]);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.drillRateGroup,
      child: content,
    );
  }

  static String _label(AppLocalizations l10n, SelfGrade grade) =>
      switch (grade) {
        SelfGrade.again => l10n.rateAgain,
        SelfGrade.hard => l10n.rateHard,
        SelfGrade.good => l10n.rateGood,
        SelfGrade.easy => l10n.rateEasy,
      };
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.grade,
    required this.label,
    required this.interval,
    required this.radius,
    required this.onPressed,
  });

  final SelfGrade grade;
  final String label;

  /// Null when nothing is scheduled: the button is its label alone.
  final String? interval;
  final BorderRadiusDirectional radius;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color bg, Color fg) = switch (grade) {
      SelfGrade.again => (scheme.errorContainer, scheme.onErrorContainer),
      SelfGrade.hard => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      SelfGrade.good => (scheme.primary, scheme.onPrimary),
      SelfGrade.easy => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 68),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: Semantics(
        label: switch (interval) {
          final interval? => l10n.rateButtonSemantics(label, interval),
          null => label,
        },
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (interval case final interval?) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                interval,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium!.copyWith(
                  color: fg.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
