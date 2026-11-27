import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../stats/level_badge.dart';
import 'achievement_texts.dart';
import 'badge_view.dart';

/// How big a badge is drawn: in a row on the summary, in the grid, on its
/// sheet.
enum BadgeSize {
  small(40, 13, 20, 2),
  regular(56, 18, 26, 3),
  big(96, 30, 44, 4);

  const BadgeSize(this.side, this.radius, this.icon, this.ringGap);

  /// The badge's side and corner radius, its icon and the gap of its ring.
  final double side;
  final double radius;
  final double icon;
  final double ringGap;

  double get levelText => switch (this) {
    BadgeSize.small => 11,
    BadgeSize.regular => 14,
    BadgeSize.big => 22,
  };
}

/// One badge's picture (the approved mockup `achievements`): earned is
/// filled, in progress has a ring of how far it has got, locked is dashed
/// with a lock, and a skill marked Leave is dimmed. A level is drawn in its
/// metal by [LevelBadge], bronze, silver or gold, the same in light and dark.
/// State is never colour alone: the tile under it says the date, the count
/// or Locked. Decorative: the tile's label says the same.
class BadgeGlyph extends StatelessWidget {
  const BadgeGlyph({
    super.key,
    required this.view,
    this.size = BadgeSize.regular,
  });

  final BadgeView view;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final def = view.def;
    final level = def.level;
    final radius = BorderRadius.circular(size.radius);
    final shown = view.shown;
    final earned = shown == BadgeShown.earned;
    final progress = shown == BadgeShown.progress;

    final Color ink;
    BoxDecoration? decoration;
    if (earned && level != null) {
      ink = LevelBadge.text;
      decoration = BoxDecoration(
        gradient: LevelBadge.of(level).gradient,
        borderRadius: radius,
      );
    } else if (earned) {
      ink = scheme.onPrimary;
      decoration = BoxDecoration(color: scheme.primary, borderRadius: radius);
    } else if (progress) {
      ink = scheme.onSecondaryContainer;
      decoration = BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: radius,
      );
    } else {
      ink = scheme.onSurfaceVariant;
    }

    final Widget face;
    if (level != null) {
      face = FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          def.name(l10n),
          maxLines: 1,
          style: TextStyle(
            fontSize: size.levelText,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: ink,
          ),
        ),
      );
    } else {
      final locked = !earned && !progress;
      face = Icon(locked ? Icons.lock : def.icon, size: size.icon, color: ink);
    }

    final side = size.side;
    final ring = side + 2 * size.ringGap;
    Widget glyph = Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.all(4),
      decoration: decoration,
      child: face,
    );
    if (!earned && !progress) {
      glyph = CustomPaint(
        foregroundPainter: _DashedBorder(
          color: scheme.outline,
          radius: size.radius,
        ),
        child: glyph,
      );
    }
    if (progress) {
      glyph = SizedBox(
        width: ring,
        height: ring,
        child: CustomPaint(
          painter: _Ring(
            track: scheme.outlineVariant,
            fill: scheme.primary,
            share: view.fraction,
            radius: size.radius + size.ringGap - _ringInset,
          ),
          child: Center(child: glyph),
        ),
      );
    } else {
      glyph = SizedBox(
        width: ring,
        height: ring,
        child: Center(child: glyph),
      );
    }
    final dimmed = shown == BadgeShown.left;
    return ExcludeSemantics(
      child: dimmed ? Opacity(opacity: 0.55, child: glyph) : glyph,
    );
  }
}

/// How far the ring's stroke sits inside the edge of its box.
const double _ringInset = 2;

/// The outline of the ring round a badge in progress: the badge's rounded
/// shape (the same corner curve as the glyph's [BorderRadius]) grown by the
/// ring's gap, so the ring and the glyph always agree. It starts at the top
/// centre and runs clockwise.
Path badgeRingPath(Size size, double radius) {
  final rect = (Offset.zero & size).deflate(_ringInset);
  final corner = Radius.circular(radius);
  return Path()
    ..moveTo(rect.center.dx, rect.top)
    ..lineTo(rect.right - radius, rect.top)
    ..arcToPoint(Offset(rect.right, rect.top + radius), radius: corner)
    ..lineTo(rect.right, rect.bottom - radius)
    ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: corner)
    ..lineTo(rect.left + radius, rect.bottom)
    ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: corner)
    ..lineTo(rect.left, rect.top + radius)
    ..arcToPoint(Offset(rect.left + radius, rect.top), radius: corner)
    ..close();
}

/// The ring round a badge in progress: a track, and over it the share done,
/// both along the badge's own rounded outline.
class _Ring extends CustomPainter {
  const _Ring({
    required this.track,
    required this.fill,
    required this.share,
    required this.radius,
  });

  final Color track;
  final Color fill;
  final double share;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = badgeRingPath(size, radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawPath(outline, base);
    final done = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..color = fill;
    for (final metric in outline.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * share.clamp(0.0, 1.0)),
        done,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.track != track ||
      old.fill != fill ||
      old.share != share ||
      old.radius != radius;
}

/// The dashed border of a locked badge.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 5), paint);
        at += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
