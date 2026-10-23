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
              mainAxisSize: MainAxisSize.min,
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

  static const double _maxRadius = 70;
  static const double _minRadius = 40;

  /// The least width a label beside the star is given, so the star shrinks
  /// to leave it, rather than the label running out of the card.
  static const double _sideWidth = 84;
  static const double _gap = 6;

  /// The lines a label is given room for: the skill's name and its two
  /// shares, each of which may wrap. A name that breaks mid-word in the
  /// narrow side box takes two lines and the shares three.
  static const int _lines = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final style = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurface,
      height: 1.25,
    );
    final labelHeight =
        (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                style.height! *
                _lines)
            .ceilToDouble();

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final cx = width / 2;
        final radius = math
            .min(_maxRadius, (cx - _sideWidth - _gap) / math.cos(math.pi / 6))
            .clamp(_minRadius, _maxRadius);
        final cy = labelHeight + _gap + radius;
        final height = cy + radius + _gap + labelHeight;
        final star = _StarShape(
          center: Offset(cx, cy),
          radius: radius,
          rtl: rtl,
        );

        final line = labelHeight / _lines;

        Widget label(int i) {
          final skill = kStarSkills[i];
          final p = star.at(i);
          final fill = l10n.commonPercent(mastery[skill].fill);
          final outline = mastery[skill].outline;
          // A dash while nothing is taught.
          final shownOutline = outline == null
              ? '–' // ui-literal-ok: a dash for "nothing taught" is not language
              : l10n.commonPercent(outline);
          final double left;
          final double top;
          final double boxWidth;
          final TextAlign align;
          final Alignment alignment;
          if (i == 0 || i == 3) {
            boxWidth = math.min(width, 2 * radius * math.cos(math.pi / 6));
            left = cx - boxWidth / 2;
            top = i == 0 ? p.dy - _gap - labelHeight : p.dy + _gap;
            align = TextAlign.center;
            alignment = i == 0 ? Alignment.bottomCenter : Alignment.topCenter;
          } else {
            final right = p.dx > cx;
            if (right) {
              left = p.dx + _gap;
              boxWidth = width - left;
              align = TextAlign.left;
            } else {
              left = 0;
              boxWidth = p.dx - _gap;
              align = TextAlign.right;
            }
            // The upper labels sit on their vertex and the lower hang from
            // theirs, so that two on one side never overlap.
            final upper = i == 1 || i == 5;
            top = upper ? p.dy - labelHeight + line : p.dy - line;
            alignment = upper
                ? (right ? Alignment.bottomLeft : Alignment.bottomRight)
                : (right ? Alignment.topLeft : Alignment.topRight);
          }
          return Positioned(
            left: left,
            top: top,
            width: boxWidth,
            height: labelHeight,
            child: Align(
              alignment: alignment,
              child: Text(
                '${masterySkillLabel(l10n, skill)}\n'
                '${l10n.progressStarAxis(fill, shownOutline)}',
                key: ValueKey<String>('star-label-$i'),
                textAlign: align,
                style: style,
              ),
            ),
          );
        }

        return SizedBox(
          key: const ValueKey<String>('star'),
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
                      shape: star,
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

/// Where the star's six vertices are: the first at the top, the rest
/// clockwise, or anticlockwise when [rtl], which mirrors the star.
class _StarShape {
  const _StarShape({
    required this.center,
    required this.radius,
    required this.rtl,
  });

  final Offset center;
  final double radius;
  final bool rtl;

  Offset at(int i, [double value = 1]) {
    final a = -math.pi / 2 + i * math.pi / 3;
    final x = radius * value * math.cos(a);
    return Offset(
      center.dx + (rtl ? -x : x),
      center.dy + radius * value * math.sin(a),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _StarShape &&
      other.center == center &&
      other.radius == radius &&
      other.rtl == rtl;

  @override
  int get hashCode => Object.hash(center, radius, rtl);
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.fill,
    required this.outline,
    required this.taught,
    required this.grow,
    required this.shape,
    required this.grid,
    required this.fillColour,
    required this.outlineColour,
    required this.markerFill,
  });

  final List<double> fill;
  final List<double> outline;
  final List<bool> taught;
  final double grow;
  final _StarShape shape;
  final Color grid;
  final Color fillColour;
  final Color outlineColour;
  final Color markerFill;

  Offset _at(int i, double value) => shape.at(i, value);

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
      canvas.drawLine(shape.center, _at(i, 1), line);
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
      old.shape != shape ||
      old.fill != fill ||
      old.outline != outline ||
      old.fillColour != fillColour ||
      old.outlineColour != outlineColour;
}
