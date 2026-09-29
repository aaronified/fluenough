import 'package:flutter/material.dart';

/// The Fluenough mark: a lowercase f whose crossbar is a tick
/// (`fluenough-brand/`).
///
/// Painted from the brand SVG's two strokes rather than loaded from it, so
/// no SVG package is needed (AGENTS.md rule 6). The colours are the brand's,
/// light or dark with the theme, not the theme's own: the mark looks the same
/// whichever seed the learner picks. Decorative: whatever shows it also says
/// the app's name in words.
class FluenoughMark extends StatelessWidget {
  const FluenoughMark({super.key, this.size = 32})
    : assert(size >= minSize, 'the brand sets a minimum size');

  /// Width and height.
  final double size;

  /// The brand's minimum size.
  static const double minSize = 16;

  /// Stem, then tick: `#085231` and `#C2621D` light, `#AEF2C6` and `#FFB68A`
  /// dark.
  static (Color, Color) colorsFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? (const Color(0xFFAEF2C6), const Color(0xFFFFB68A))
      : (const Color(0xFF085231), const Color(0xFFC2621D));

  @override
  Widget build(BuildContext context) {
    final (stem, tick) = colorsFor(Theme.of(context).brightness);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(stem: stem, tick: tick),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.stem, required this.tick});

  final Color stem;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    // The SVG's viewBox is 14 14 76 76.
    canvas
      ..scale(size.width / 76, size.height / 76)
      ..translate(-14, -14);
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // M46 84V42c0-14 8-22 21-22
    canvas.drawPath(
      Path()
        ..moveTo(46, 84)
        ..lineTo(46, 42)
        ..cubicTo(46, 28, 54, 20, 67, 20),
      stroke(stem),
    );
    // M27 48l19 13 30-27
    canvas.drawPath(
      Path()
        ..moveTo(27, 48)
        ..lineTo(46, 61)
        ..lineTo(76, 34),
      stroke(tick),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.stem != stem || old.tick != tick;
}
