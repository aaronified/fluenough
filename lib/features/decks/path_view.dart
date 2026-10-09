import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import 'deck_content.dart';
import 'path_model.dart';
import 'path_parts.dart';

/// A course's path, winding down the screen (docs/plans/path-redesign.md):
/// each unit a slightly rounded rectangle, playfully off-centre, joined by a
/// line that is solid up to the unit the learner is on and dotted after it;
/// milestones and level achievements between them.
///
/// [upNextKey] marks the unit up next, so that the page can scroll to it.
class CoursePathView extends StatelessWidget {
  const CoursePathView({
    super.key,
    required this.view,
    required this.state,
    required this.onOpen,
    this.upNextKey,
  });

  final CourseView view;
  final AppState state;
  final ValueChanged<UnitStep> onOpen;
  final Key? upNextKey;

  /// Where each node sits across the path, from its start (0) to its end
  /// (1), in turn: a gentle zigzag.
  static const List<double> _sway = <double>[0.1, 0.35, 0.65, 0.9, 0.65, 0.35];

  @override
  Widget build(BuildContext context) {
    final steps = view.steps;
    final upNext = steps.indexWhere(
      (s) => s is UnitStep && s.status == UnitStatus.upNext,
    );
    // Everything is behind the learner once every unit is done.
    final reached = upNext < 0 ? steps.length : upNext;
    final now = state.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final nodeWidth = math.min(width * (scale > 1.3 ? 0.86 : 0.64), 300.0);

        // Each step's centre across the path, as a share of [width].
        var node = 0;
        final centres = <double>[
          for (final step in steps)
            switch (step) {
              UnitStep() || ComingStep() => () {
                final sway = _sway[node++ % _sway.length];
                return (nodeWidth / 2 + sway * (width - nodeWidth)) / width;
              }(),
              _ => 0.5,
            },
        ];

        final children = <Widget>[];
        for (final (i, step) in steps.indexed) {
          if (i > 0) {
            children.add(
              _Connector(
                from: centres[i - 1],
                to: centres[i],
                behind: i <= reached,
              ),
            );
          }
          final Widget child = switch (step) {
            UnitStep() => _UnitNode(
              key: i == upNext ? upNextKey : null,
              step: step,
              state: state,
              width: nodeWidth,
              onTap: () => onOpen(step),
            ),
            ComingStep() => _ComingNode(step: step, width: nodeWidth),
            MilestoneStep() => MilestoneMark(step: step, now: now),
            AchievementStep() => AchievementMark(step: step, now: now),
            LevelStep() => LevelHeader(step: step),
          };
          if (step is LevelStep) {
            children.add(child);
            continue;
          }
          final centre = centres[i] * width;
          final isNode = step is UnitStep || step is ComingStep;
          children.add(
            isNode
                ? Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: math.max(0, centre - nodeWidth / 2),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: child,
                    ),
                  )
                : Center(child: child),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// The line between two steps, [from] one centre to the [to] next, as
/// shares of the width: solid in `primary` where the learner has been,
/// dotted ahead.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.from,
    required this.to,
    required this.behind,
  });

  final double from;
  final double to;
  final bool behind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size.fromHeight(28),
        painter: _ConnectorPainter(
          from: from,
          to: to,
          behind: behind,
          color: behind ? scheme.primary : scheme.outline,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.from,
    required this.to,
    required this.behind,
    required this.color,
    required this.rtl,
  });

  final double from;
  final double to;
  final bool behind;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double share) => (rtl ? 1 - share : share) * size.width;
    final start = Offset(x(from), 0);
    final end = Offset(x(to), size.height);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx,
        size.height / 2,
        end.dx,
        size.height / 2,
        end.dx,
        end.dy,
      );
    if (behind) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final dot = Paint()..color = color.withValues(alpha: 0.6);
    for (final metric in path.computeMetrics()) {
      for (var d = 2.0; d < metric.length; d += 9) {
        final at = metric.getTangentForOffset(d)?.position;
        if (at != null) canvas.drawCircle(at, 2.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.from != from ||
      old.to != to ||
      old.behind != behind ||
      old.color != color ||
      old.rtl != rtl;
}

/// A unit on the path: done (a tick), up next (a play button, highlighted,
/// under "Up next"), or ahead (its number, or a script unit's letter), with
/// its name, its line and the reviews due in it.
class _UnitNode extends StatelessWidget {
  const _UnitNode({
    super.key,
    required this.step,
    required this.state,
    required this.width,
    required this.onTap,
  });

  final UnitStep step;
  final AppState state;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = unitMeta(l10n, state, step.content);
    final status = step.status;
    final (bg, fg, sub) = switch (status) {
      UnitStatus.done => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.onSecondaryContainer,
      ),
      UnitStatus.upNext => (scheme.primary, scheme.onPrimary, scheme.onPrimary),
      UnitStatus.ahead => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
    };
    final statusWord = switch (status) {
      UnitStatus.done => l10n.pathUnitDone,
      UnitStatus.upNext => l10n.pathUpNext,
      UnitStatus.ahead => l10n.pathUnitAhead,
    };
    final semantics = joinParts(l10n, <String>[
      l10n.pathUnitSemantics(step.title, step.number, statusWord, meta),
      if (step.due > 0) l10n.commonDueBadge(step.due),
    ]);
    final leading = switch (status) {
      UnitStatus.done => Icon(Icons.check_rounded, color: fg, size: 22),
      UnitStatus.upNext => Icon(Icons.play_arrow_rounded, color: fg, size: 26),
      UnitStatus.ahead =>
        step.content.isScript || !step.onPath
            ? DeckGlyph(
                glyph: step.decks.first.glyph,
                language: step.decks.first.language,
                size: 40,
              )
            : Text(
                formatCount(context, step.number),
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.titleMedium!.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
    };

    final card = Material(
      color: bg,
      elevation: status == UnitStatus.upNext ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: status == UnitStatus.ahead
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.14),
                    shape: status == UnitStatus.upNext
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: status == UnitStatus.upNext
                        ? null
                        : BorderRadius.circular(12),
                  ),
                  child: leading,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.title,
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: sub,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (status == UnitStatus.upNext) ...<Widget>[
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.pathUpNext,
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                card,
                if (step.due > 0)
                  PositionedDirectional(
                    top: -8,
                    end: -6,
                    child: _DueDot(count: step.due),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The reviews due in a unit, on its corner.
class _DueDot extends StatelessWidget {
  const _DueDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.surface, width: 2),
      ),
      child: Text(
        formatCount(context, count),
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.labelSmall!
            .copyWith(color: scheme.onError, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// A unit still being written: outlined, its name and size, not opened.
class _ComingNode extends StatelessWidget {
  const _ComingNode({required this.step, required this.width});

  final ComingStep step;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final words = step.unit.words;
    return MergeSemantics(
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: scheme.outline, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.more_horiz,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.unit.title,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    words == null
                        ? l10n.pathComing
                        : l10n.pathComingWords(words),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
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
