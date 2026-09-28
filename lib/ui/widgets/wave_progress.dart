import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The drill's progress bar: a sine wave in `primary` up to [value], then a
/// flat track in `secondaryContainer`, ending in a dot (M3 Expressive's wavy
/// indicator, as the design draws it).
///
/// [value] is 0–1 and animates when it changes. The wave runs from the start
/// edge, so it flows right to left in a right-to-left locale.
///
/// Screen readers get a progress node named [semanticsLabel] with
/// [semanticsValue], such as "Session progress, 3 of 8".
class WaveProgress extends StatelessWidget {
  const WaveProgress({
    super.key,
    required this.value,
    required this.semanticsLabel,
    this.semanticsValue,
    this.height = 16,
  });

  final double value;
  final String semanticsLabel;
  final String? semanticsValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: semanticsValue,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: WavePainter(
            value: v,
            wave: scheme.primary,
            track: scheme.secondaryContainer,
            mirrored: rtl,
          ),
        ),
      ),
    );
  }
}

/// Paints [WaveProgress]. Public so that a test or a preview can paint one
/// without the animation.
class WavePainter extends CustomPainter {
  const WavePainter({
    required this.value,
    required this.wave,
    required this.track,
    this.mirrored = false,
  });

  final double value;
  final Color wave;
  final Color track;
  final bool mirrored;

  /// Wavelength and amplitude from the design: a period of 20, 3 either side.
  static const double wavelength = 20;
  static const double amplitude = 3;
  static const double stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final mid = size.height / 2;
    final usable = math.max(0.0, size.width - 8);
    final end = (value * usable).clamp(0.0, usable);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (end > 2) {
      final path = Path()..moveTo(2, mid);
      for (var x = 2.0; x <= end; x += 2) {
        path.lineTo(
          x,
          mid + amplitude * math.sin(x / wavelength * 2 * math.pi),
        );
      }
      canvas.drawPath(path, pen..color = wave);
    }

    final trackStart = math.min(usable, end + 8);
    if (trackStart < usable) {
      canvas.drawLine(
        Offset(trackStart, mid),
        Offset(usable, mid),
        pen..color = track,
      );
    }
    canvas.drawCircle(Offset(size.width - 3, mid), 2, Paint()..color = wave);
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.value != value ||
      old.wave != wave ||
      old.track != track ||
      old.mirrored != mirrored;
}
