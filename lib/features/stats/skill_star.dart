import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/progress/mastery.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'skill_lines.dart';

/// How long the star takes to grow from the centre, once, on open.
const Duration kStarGrowTime = Duration(milliseconds: 400);

/// "Mastery by skill": the six-axis star of grammar, script, read, write,
/// hear and say (#678), and a button that opens the charts over time.
///
/// The filled shape is known ÷ the B1 total, with no edge; the solid blue
/// outline is known ÷ taught, which sits at the centre for a skill with
/// nothing taught. It grows once, in [kStarGrowTime], and not at all under
/// reduced motion. Nothing is written under it.
class SkillStarCard extends StatelessWidget {
  const SkillStarCard({super.key, required this.mastery, required this.onTap});

  final Mastery mastery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = <String>[
      for (final skill in kStarSkills)
        l10n.progressStarSkill(
          masterySkillLabel(l10n, skill),
          mastery[skill].fill,
          mastery[skill].outline == null
              ? l10n.progressNothingTaught
              : l10n.commonPercent(mastery[skill].outline!),
        ),
    ].join(l10n.commonListSeparator);
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: l10n.progressStarSemantics(
        l10n.progressStarTitle,
        mastery.overall,
        details,
      ),
      onTap: onTap,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.progressStarTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      l10n.progressOverTime,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.primary),
                  ],
                ),
                Text(
                  l10n.progressStarOverall(mastery.overall),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _Star(mastery: mastery),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.mastery});

  final Mastery mastery;

  static const double _radius = 70;
  static const double _labelWidth = 92;
  static const double _labelHeight = 56;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final height = _labelHeight + _gap + _radius * 2 + _gap + _labelHeight;
    final cy = _labelHeight + _gap + _radius;

    return LayoutBuilder(
      builder: (context, box) {
        final cx = box.maxWidth / 2;
        Offset vertex(int i, [double scale = 1]) {
          final a = -math.pi / 2 + i * math.pi / 3;
          return Offset(
            cx + _radius * scale * math.cos(a),
            cy + _radius * scale * math.sin(a),
          );
        }

        Widget label(int i) {
          final skill = kStarSkills[i];
          final p = vertex(i);
          final fill = l10n.commonPercent(mastery[skill].fill);
          final outline = mastery[skill].outline;
          // A dash while nothing is taught.
          final shownOutline = outline == null
              ? '–' // ui-literal-ok: a dash for "nothing taught" is not language
              : l10n.commonPercent(outline);
          final TextAlign align;
          final double left;
          final double top;
          if (i == 0) {
            align = TextAlign.center;
            left = p.dx - _labelWidth / 2;
            top = p.dy - _gap - _labelHeight;
          } else if (i == 3) {
            align = TextAlign.center;
            left = p.dx - _labelWidth / 2;
            top = p.dy + _gap;
          } else if (i < 3) {
            align = TextAlign.start;
            left = p.dx + _gap;
            top = p.dy - _labelHeight / 2;
          } else {
            align = TextAlign.end;
            left = p.dx - _gap - _labelWidth;
            top = p.dy - _labelHeight / 2;
          }
          return Positioned(
            left: left,
            top: top,
            width: _labelWidth,
            height: _labelHeight,
            child: Align(
              alignment: i == 0
                  ? Alignment.bottomCenter
                  : i == 3
                  ? Alignment.topCenter
                  : Alignment.center,
              child: Text(
                '${masterySkillLabel(l10n, skill)}\n'
                '${l10n.progressStarAxis(fill, shownOutline)}',
                textAlign: align,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurface,
                  height: 1.25,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduced ? 1.0 : 0.0, end: 1.0),
                  duration: reduced ? Duration.zero : kStarGrowTime,
                  curve: Curves.easeOutCubic,
                  builder: (context, grow, _) => CustomPaint(
                    painter: _StarPainter(
                      fill: <double>[
                        for (final s in kStarSkills) mastery[s].fill,
                      ],
                      outline: <double>[
                        for (final s in kStarSkills) mastery[s].outline ?? 0,
                      ],
                      taught: <bool>[
                        for (final s in kStarSkills) mastery[s].taught > 0,
                      ],
                      grow: grow,
                      center: Offset(cx, cy),
                      radius: _radius,
                      grid: scheme.outlineVariant,
                      fillColour: scheme.primary.withValues(alpha: 0.38),
                      outlineColour: starOutlineColour(theme.brightness),
                      markerFill: scheme.surface,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < kStarSkills.length; i++) label(i),
            ],
          ),
        );
      },
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.fill,
    required this.outline,
    required this.taught,
    required this.grow,
    required this.center,
    required this.radius,
    required this.grid,
    required this.fillColour,
    required this.outlineColour,
    required this.markerFill,
  });

  final List<double> fill;
  final List<double> outline;
  final List<bool> taught;
  final double grow;
  final Offset center;
  final double radius;
  final Color grid;
  final Color fillColour;
  final Color outlineColour;
  final Color markerFill;

  Offset _at(int i, double value) {
    final a = -math.pi / 2 + i * math.pi / 3;
    return Offset(
      center.dx + radius * value * math.cos(a),
      center.dy + radius * value * math.sin(a),
    );
  }

  Path _shape(List<double> values, double scale) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = _at(i, values[i].clamp(0.0, 1.0) * scale);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ring in const <double>[0.25, 0.5, 0.75, 1]) {
      canvas.drawPath(_shape(List<double>.filled(6, ring), 1), line);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(center, _at(i, 1), line);
    }
    // The fill has no edge: a fill only.
    canvas.drawPath(_shape(fill, grow), Paint()..color = fillColour);
    canvas.drawPath(
      _shape(outline, grow),
      Paint()
        ..color = outlineColour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < 6; i++) {
      if (!taught[i]) continue;
      final p = _at(i, outline[i].clamp(0.0, 1.0) * grow);
      canvas.drawCircle(p, 3, Paint()..color = markerFill);
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = outlineColour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.grow != grow ||
      old.fill != fill ||
      old.outline != outline ||
      old.fillColour != fillColour ||
      old.outlineColour != outlineColour;
}
