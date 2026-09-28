import 'package:flutter/material.dart';

import '../../app/profile.dart';
import 'expressive_shape.dart';

/// A profile's avatar: its shape in its tone, with the first letter of its
/// name, or a person icon for the unnamed default profile.
///
/// Decorative: the name beside it, or the button around it, carries the
/// meaning, so it is excluded from semantics.
///
/// Sizes in the design: 112 on the profile picker, 80 on the PIN screen, 56
/// in Settings, 48 in Today's header, 72 for a shape choice.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required Profile this.profile,
    this.size = 48,
  }) : _shape = null,
       _tone = null;

  /// A bare shape, with no letter: the new-profile shape picker.
  const ProfileAvatar.shapeOnly({
    super.key,
    required AvatarShape this._shape,
    required AvatarTone this._tone,
    this.size = 72,
  }) : profile = null;

  /// Null for [ProfileAvatar.shapeOnly].
  final Profile? profile;
  final double size;
  final AvatarShape? _shape;
  final AvatarTone? _tone;

  static ExpressiveShape shapeFor(AvatarShape shape) => switch (shape) {
    AvatarShape.cookie => ExpressiveShape.cookie,
    AvatarShape.clover => ExpressiveShape.clover,
    AvatarShape.flower => ExpressiveShape.flower,
    AvatarShape.sunny => ExpressiveShape.sunny,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile;
    final tone = p?.tone ?? _tone ?? AvatarTone.primary;
    final (Color bg, Color fg) = switch (tone) {
      AvatarTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AvatarTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      AvatarTone.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    final shape = shapeFor(p?.shape ?? _shape ?? AvatarShape.cookie);
    final name = p?.name?.trim();

    final Widget? mark = p == null
        ? null
        : name == null || name.isEmpty
        ? Icon(Icons.person, color: fg, size: size * 0.5)
        : Text(
            name.characters.first.toUpperCase(),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: fg,
              fontSize: size * 0.39,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: bg,
            shape: ExpressiveShapeBorder(shape),
          ),
          child: mark == null ? null : Center(child: mark),
        ),
      ),
    );
  }
}
