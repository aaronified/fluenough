import 'dart:math' as math;

import 'package:flutter/material.dart';

/// M3 Expressive's rounded polar shapes, from the design's `shapePath`: a
/// circle whose radius ripples [lobes] times round, by [amplitude].
enum ExpressiveShape {
  /// Nine soft scallops: avatars, the play button.
  cookie(9, 0.07, 0),

  /// Four leaves: an avatar.
  clover(4, 0.16, math.pi / 4),

  /// Six petals: an avatar.
  flower(6, 0.11, 0),

  /// Eight shallow rays: an avatar, and the summary's tick.
  sunny(8, 0.045, 0),

  /// Two lobes, lying on its side.
  pill(2, 0.12, math.pi / 2);

  const ExpressiveShape(this.lobes, this.amplitude, this.rotation);

  final int lobes;
  final double amplitude;

  /// Radians, clockwise from the top.
  final double rotation;

  /// The outline of this shape filling [rect], turned by [turn] radians.
  Path pathIn(Rect rect, {double turn = 0}) {
    final r = math.min(rect.width, rect.height) / 2;
    final c = rect.center;
    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final radius =
          r * (1 + amplitude * math.cos(lobes * t)) / (1 + amplitude);
      final a = t - math.pi / 2 + rotation + turn;
      final p = Offset(
        c.dx + radius * math.cos(a),
        c.dy + radius * math.sin(a),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }
}

/// An [OutlinedBorder] in an [ExpressiveShape], so the shapes work anywhere
/// a shape does: `Material(shape: …)`, `ShapeDecoration`, `InkWell`'s
/// `customBorder`, clipping.
class ExpressiveShapeBorder extends OutlinedBorder {
  const ExpressiveShapeBorder(this.shape, {this.turn = 0, super.side});

  final ExpressiveShape shape;

  /// Extra rotation, in radians.
  final double turn;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shape.pathIn(rect.deflate(side.strokeInset), turn: turn);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shape.pathIn(rect, turn: turn);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      shape.pathIn(rect.deflate(side.strokeInset / 2), turn: turn),
      side.toPaint(),
    );
  }

  @override
  ExpressiveShapeBorder scale(double t) =>
      ExpressiveShapeBorder(shape, turn: turn, side: side.scale(t));

  @override
  ExpressiveShapeBorder copyWith({
    BorderSide? side,
    ExpressiveShape? shape,
    double? turn,
  }) => ExpressiveShapeBorder(
    shape ?? this.shape,
    turn: turn ?? this.turn,
    side: side ?? this.side,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpressiveShapeBorder &&
      other.shape == shape &&
      other.turn == turn &&
      other.side == side;

  @override
  int get hashCode => Object.hash(shape, turn, side);
}
