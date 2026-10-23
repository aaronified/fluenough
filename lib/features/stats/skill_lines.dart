import 'package:flutter/material.dart';

import '../../core/progress/mastery.dart';
import '../../l10n/app_localizations.dart';

/// The six skills in the order the star and the charts draw them, clockwise
/// from the top.
const List<MasterySkill> kStarSkills = MasterySkill.values;

/// [skill]'s name on Progress.
String masterySkillLabel(AppLocalizations l10n, MasterySkill skill) =>
    switch (skill) {
      MasterySkill.grammar => l10n.skillGrammar,
      MasterySkill.script => l10n.progressSkillScript,
      MasterySkill.read => l10n.progressSkillRead,
      MasterySkill.write => l10n.skillProduction,
      MasterySkill.hear => l10n.skillListening,
      MasterySkill.say => l10n.skillSpeaking,
    };

/// How a skill's line is drawn on the charts over time: colour, dash and
/// marker, so that colour is never the only cue.
enum LineMarker { circle, square, diamond, triangle, triangleDown, ring }

class SkillLineStyle {
  const SkillLineStyle(this.light, this.dark, this.dash, this.marker);

  /// The colour on a light theme and on a dark one.
  final Color light;
  final Color dark;

  /// On and off lengths, empty for solid.
  final List<double> dash;
  final LineMarker marker;

  Color colour(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const Map<MasterySkill, SkillLineStyle> all =
      <MasterySkill, SkillLineStyle>{
        MasterySkill.grammar: SkillLineStyle(
          Color(0xFF1F6584),
          Color(0xFF8FC9E6),
          <double>[],
          LineMarker.circle,
        ),
        MasterySkill.script: SkillLineStyle(
          Color(0xFF8A5A00),
          Color(0xFFE8C46A),
          <double>[7, 4],
          LineMarker.square,
        ),
        MasterySkill.read: SkillLineStyle(
          Color(0xFF296A48),
          Color(0xFF92D5AB),
          <double>[1.5, 4],
          LineMarker.diamond,
        ),
        MasterySkill.write: SkillLineStyle(
          Color(0xFFA23A55),
          Color(0xFFF2A9B8),
          <double>[8, 3, 1.5, 3],
          LineMarker.triangle,
        ),
        MasterySkill.hear: SkillLineStyle(
          Color(0xFF6B4C9A),
          Color(0xFFC9B0F0),
          <double>[14, 4],
          LineMarker.triangleDown,
        ),
        MasterySkill.say: SkillLineStyle(
          Color(0xFF596064),
          Color(0xFFB8C0C4),
          <double>[3, 3],
          LineMarker.ring,
        ),
      };
}

/// The star's solid blue outline (owner, 2026-10-23: "Solid, blue").
Color starOutlineColour(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF8FC9E6)
    : const Color(0xFF1F6584);

/// Draws [marker] at [at] in [colour]; [ringFill] fills a ring.
void paintLineMarker(
  Canvas canvas,
  Offset at,
  LineMarker marker,
  Color colour,
  Color ringFill,
) {
  const r = 3.4;
  final fill = Paint()..color = colour;
  switch (marker) {
    case LineMarker.circle:
      canvas.drawCircle(at, r, fill);
    case LineMarker.ring:
      canvas.drawCircle(at, r, Paint()..color = ringFill);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    case LineMarker.square:
      canvas.drawRect(Rect.fromCircle(center: at, radius: r), fill);
    case LineMarker.diamond:
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r - 1)
          ..lineTo(at.dx + r + 1, at.dy)
          ..lineTo(at.dx, at.dy + r + 1)
          ..lineTo(at.dx - r - 1, at.dy)
          ..close(),
        fill,
      );
    case LineMarker.triangle:
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r - 1)
          ..lineTo(at.dx + r + 1, at.dy + r)
          ..lineTo(at.dx - r - 1, at.dy + r)
          ..close(),
        fill,
      );
    case LineMarker.triangleDown:
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - r - 1, at.dy - r)
          ..lineTo(at.dx + r + 1, at.dy - r)
          ..lineTo(at.dx, at.dy + r + 1)
          ..close(),
        fill,
      );
  }
}

/// Strokes [path] with [dash] on and off lengths; solid when it is empty.
void strokeDashed(Canvas canvas, Path path, Paint paint, List<double> dash) {
  if (dash.isEmpty) {
    canvas.drawPath(path, paint);
    return;
  }
  for (final metric in path.computeMetrics()) {
    var at = 0.0;
    var i = 0;
    while (at < metric.length) {
      final length = dash[i % dash.length];
      if (i.isEven) {
        canvas.drawPath(
          metric.extractPath(at, (at + length).clamp(0, metric.length)),
          paint,
        );
      }
      at += length;
      i++;
    }
  }
}
