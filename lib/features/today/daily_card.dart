import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../app/daily_plan.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/scheduling/daily_budget.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The size of the ring and of the button inside it.
const double _ringSize = 200;
const double _ringStroke = 12;
const double _buttonSize = 152;

/// Today's one button (#521): the day's session, which mixes reviews and
/// new words and follows the daily minutes (#485). A ring around the button
/// fills as the day's minutes are spent, with "12 of 15 min" under it and
/// the split of reviews and new words under that.
///
/// Once the minutes are spent the button reads "Done for today", with a
/// smaller "Keep going". When reviews have piled up beyond three days of
/// minutes, a banner says so, with its estimate and plan and a "+ 5 min"
/// that a long press takes back.
///
/// One for each language learned, the first named.
///
/// Mockup `docs/mockups/today-chain.html`, screen 1; the owner's answers of
/// 2026-10-23 on #521.
class DailyCard extends StatelessWidget {
  const DailyCard({super.key, required this.plans});

  final List<DailyPlan> plans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (i, plan) in plans.indexed) ...<Widget>[
          if (i > 0) const SizedBox(height: 24),
          _Daily(plan: plan, named: plans.length > 1),
        ],
      ],
    );
  }
}

class _Daily extends StatelessWidget {
  const _Daily({required this.plan, required this.named});

  final DailyPlan plan;

  /// Whether the language is named: more than one is learned.
  final bool named;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final code = plan.language.code;
    void start() =>
        AppNavigator.startDrill(context, DrillRequest.daily(language: code));
    void keepGoing() {
      AppScope.read(context).addDailyMinutes(code, DailyBudget.stepMinutes);
      start();
    }

    final label = plan.done
        ? l10n.todayDailyDone
        : plan.inProgress
        ? l10n.todayDailyContinue
        : l10n.todayDailyStart;
    final progress = l10n.todayDailyProgress(plan.minutesDone, plan.minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (named)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                plan.language.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.sectionTitle,
              ),
            ),
          ),
        Center(
          child: _Ring(
            fraction: plan.fraction,
            label: label,
            done: plan.done,
            onPressed: start,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          container: true,
          child: Text(
            progress,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (plan.canKeepGoing)
          Center(
            child: TextButton(
              onPressed: keepGoing,
              child: Text(l10n.todayDailyKeepGoing),
            ),
          ),
        if (plan.showsSplit) ...<Widget>[
          const SizedBox(height: 6),
          _Split(plan: plan),
        ],
        if (plan.split.catchingUp) ...<Widget>[
          const SizedBox(height: 16),
          _CatchingUp(plan: plan),
        ],
      ],
    );
  }
}

/// The ring that fills toward the day's minutes, with the button inside, or
/// with the day done, a tick in its place that starts nothing.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.fraction,
    required this.label,
    required this.done,
    required this.onPressed,
  });

  final double fraction;
  final String label;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = done ? scheme.onSecondaryContainer : scheme.onPrimary;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          done ? Icons.check_rounded : Icons.play_arrow_rounded,
          size: 32,
          color: foreground,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: foreground,
          ),
        ),
      ],
    );
    return SizedBox.square(
      dimension: _ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size.square(_ringSize),
              painter: _RingPainter(
                fraction: fraction,
                track: scheme.secondaryContainer,
                fill: scheme.primary,
              ),
            ),
          ),
          if (done)
            Semantics(
              container: true,
              label: label,
              excludeSemantics: true,
              child: Container(
                width: _buttonSize,
                height: _buttonSize,
                padding: const EdgeInsetsDirectional.all(8),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: scheme.secondaryContainer,
                  shape: const CircleBorder(),
                ),
                child: content,
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                fixedSize: const Size.square(_buttonSize),
                minimumSize: Size.zero,
                padding: const EdgeInsetsDirectional.all(8),
                shape: const CircleBorder(),
              ),
              onPressed: onPressed,
              child: content,
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - _ringStroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction.clamp(0.0, 1.0),
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

/// "8 reviews" and "6 new", side by side, as two small badges.
class _Split extends StatelessWidget {
  const _Split({required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final reviews = l10n.todayDailyReviews(plan.split.reviews);
    final fresh = l10n.todayDailyNew(plan.split.newWords);
    return Semantics(
      container: true,
      label: '$reviews, $fresh',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _Badge(
            text: reviews,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
          ),
          _Badge(
            text: fresh,
            background: plan.split.newWords == 0 ? null : scheme.primary,
            foreground: plan.split.newWords == 0
                ? scheme.onSurfaceVariant
                : scheme.onPrimary,
            outline: plan.split.newWords == 0 ? scheme.outline : null,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.foreground,
    this.background,
    this.outline,
  });

  final String text;
  final Color foreground;
  final Color? background;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: outline == null ? null : Border.all(color: outline!),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.badge.copyWith(color: foreground),
      ),
    );
  }
}

/// "Catching up: no new words today", its estimate and plan, and "+ 5 min":
/// each tap adds five minutes to today's session, a long press takes five
/// away (owner, 2026-10-23).
class _CatchingUp extends StatelessWidget {
  const _CatchingUp({required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onTertiaryContainer;
    final state = AppScope.read(context);
    final code = plan.language.code;
    const step = DailyBudget.stepMinutes;
    void add(int minutes) => state.addDailyMinutes(code, minutes);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.todayDailyCatchingUp,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.todayDailyCatchingUpPlan(
                    plan.due,
                    plan.dueMinutes,
                    plan.goalMinutes,
                    plan.daysToCatchUp,
                  ),
                  style: theme.textTheme.bodySmall!.copyWith(color: fg),
                ),
                const SizedBox(height: 10),
                Semantics(
                  container: true,
                  button: true,
                  label: l10n.todayDailyAddMinutes(step),
                  hint: l10n.todayDailyAddHint(step),
                  onTap: () => add(step),
                  excludeSemantics: true,
                  customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                    CustomSemanticsAction(
                      label: l10n.todayDailyTakeAway(step),
                    ): () =>
                        add(-step),
                  },
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(color: fg),
                    ),
                    onPressed: () => add(step),
                    onLongPress: () => add(-step),
                    child: Text(l10n.todayDailyAddMinutes(step)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
