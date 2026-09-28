import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../skill_visuals.dart';
import '../theme.dart';

/// The three sizes the design draws a skill's pill in.
enum ModePillSize {
  /// 32 px, icon and label: the drill header.
  label,

  /// 36 × 28, icon only: Today's skill tiles.
  small,

  /// 52 × 36, icon only: a deck's skill rows.
  large,
}

/// A skill's pill, in its fixed [ModeColors] colour.
///
/// Always carries the skill's icon, and in [ModePillSize.label] its name, so
/// the mode never depends on colour alone. The icon-only sizes are
/// decorative: they sit beside the skill's name, which screen readers read.
///
/// [muted] draws it greyed, for a skill the phone cannot do (no voice).
class ModePill extends StatelessWidget {
  const ModePill({
    super.key,
    required this.skill,
    this.size = ModePillSize.label,
    this.muted = false,
  });

  final Skill skill;
  final ModePillSize size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = ModeColors.of(context).forSkill(skill);
    final bg = muted
        ? theme.colorScheme.surfaceContainerHighest
        : colours.container;
    final fg = muted ? theme.colorScheme.onSurfaceVariant : colours.onContainer;

    if (size == ModePillSize.label) {
      return Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(skill.icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                skill.label(AppLocalizations.of(context)!),
                style: theme.textTheme.labelLarge!.copyWith(
                  color: fg,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final (double w, double h, double icon) = size == ModePillSize.small
        ? (36, 28, 20)
        : (52, 36, 22);
    return ExcludeSemantics(
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(h / 2),
        ),
        child: Icon(skill.icon, size: icon, color: fg),
      ),
    );
  }
}
