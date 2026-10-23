import 'package:flutter/material.dart';

import '../../core/data/course_path.dart';

/// The Level tile's metal (#678, owner, 2026-10-23): A1 is bronze, A2 silver
/// and B1 gold, each a static diagonal gradient with a lighter band across
/// it, the course's achievement badges.
///
/// The colours are the same in light and dark themes, so the text on them is
/// one dark colour, [text], that passes 4.5:1 against every stop.
class LevelBadge {
  const LevelBadge._(this.shade, this.base, this.highlight);

  /// The darkest and the plain stop, and the band of light.
  final Color shade;
  final Color base;
  final Color highlight;

  /// The text on the badge: near black, for 4.5:1 on every stop.
  static const Color text = Color(0xFF1F1700);

  static const LevelBadge bronze = LevelBadge._(
    Color(0xFFC07C45),
    Color(0xFFD09562),
    Color(0xFFEFC9A3),
  );
  static const LevelBadge silver = LevelBadge._(
    Color(0xFFAEB3B8),
    Color(0xFFC4C8CC),
    Color(0xFFF3F5F7),
  );
  static const LevelBadge gold = LevelBadge._(
    Color(0xFFD1A02A),
    Color(0xFFE0B13A),
    Color(0xFFFFE595),
  );

  /// The badge for [level].
  static LevelBadge of(Milestone level) => switch (level) {
    Milestone.a1 => bronze,
    Milestone.a2 => silver,
    Milestone.b1 => gold,
  };

  /// Every colour in the gradient.
  List<Color> get stops => <Color>[shade, base, highlight, base, shade];

  /// The diagonal gradient with its band of light, which stays still.
  LinearGradient get gradient => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: stops,
    stops: const <double>[0, 0.3, 0.5, 0.7, 1],
  );
}
