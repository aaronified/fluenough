import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';

/// How each of the four skills looks on the Languages page: Speak is the
/// speaking skill's microphone and green, Hear listening's ear and purple,
/// Read recognition's eye and blue, Write production's keyboard and orange
/// (`lib/ui/skill_visuals.dart`, `ModeColors`), fixed whatever the seed.
extension SkillKindVisuals on SkillKind {
  Skill get skill => switch (this) {
    SkillKind.speak => Skill.speaking,
    SkillKind.hear => Skill.listening,
    SkillKind.read => Skill.recognition,
    SkillKind.write => Skill.production,
  };

  IconData get icon => skill.icon;

  String label(AppLocalizations l10n) => switch (this) {
    SkillKind.speak => l10n.languagesSkillSpeak,
    SkillKind.hear => l10n.languagesSkillHear,
    SkillKind.read => l10n.languagesSkillRead,
    SkillKind.write => l10n.languagesSkillWrite,
  };
}

extension SkillStateText on SkillState {
  String label(AppLocalizations l10n) => switch (this) {
    SkillState.leave => l10n.languagesStateLeave,
    SkillState.know => l10n.languagesStateKnow,
    SkillState.learn => l10n.languagesStateLearn,
  };
}

/// The mark in a chip's corner: a tick for Know, a double tick once the
/// level covers it, a cap for Learn, a minus for Leave. Never colour alone.
IconData markIcon(SkillMark mark) => switch (mark) {
  SkillMark.leave => Icons.remove,
  SkillMark.know => Icons.check,
  SkillMark.knowCovered => Icons.done_all,
  SkillMark.learn => Icons.school_outlined,
};

/// A skill's name: "Read", or "Read Devanagari" where the language has
/// [severalScripts].
String skillName(
  AppLocalizations l10n,
  SkillKey key, {
  required bool severalScripts,
  required String fallbackScript,
}) {
  final base = key.kind.label(l10n);
  final script = key.script;
  if (script == null || !severalScripts) return base;
  return l10n.languagesSkillScript(
    base,
    l10n.scriptNameOr(script, fallbackScript),
  );
}

/// A skill's state and level as a screen reader reads it.
String skillSemantics(
  AppLocalizations l10n,
  String name,
  SkillState state, {
  required bool covered,
}) => state == SkillState.know && covered
    ? l10n.languagesSkillStateCovered(name, state.label(l10n))
    : l10n.languagesSkillState(name, state.label(l10n));

/// One skill as a chip or a pill: its icon in its colour and the mark of its
/// state; Know is the skill's container, Learn the container with a 2 px
/// primary border drawn inside (so its size does not change), Leave dashed.
/// With [onTap] it is the sheet's pill; without, the list's read-only chip.
class SkillBadge extends StatelessWidget {
  const SkillBadge({
    super.key,
    required this.kind,
    required this.mark,
    required this.label,
    this.glyph,
    this.onTap,
    this.hint,
    this.big = false,
  });

  final SkillKind kind;
  final SkillMark mark;

  /// What a screen reader and the tooltip say.
  final String label;

  /// A script's glyph, on a chip of a language with several scripts.
  final String? glyph;
  final VoidCallback? onTap;

  /// What the next tap does, for a screen reader.
  final String? hint;

  /// The sheet's pill, 48 px high; else the list's chip.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ModeColors.of(context).forSkill(kind.skill);
    final leave = mark == SkillMark.leave;
    final fg = leave ? scheme.onSurfaceVariant : colors.onContainer;
    final radius = big ? AppRadii.card : AppRadii.control;
    final iconSize = big ? 24.0 : 16.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(kind.icon, size: iconSize, color: fg),
        if (glyph != null) ...<Widget>[
          const SizedBox(width: 3),
          Text(
            glyph!,
            style: theme.textTheme.labelSmall!.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(width: big ? 4 : 2),
        Icon(markIcon(mark), size: big ? 16 : 14, color: fg),
      ],
    );
    final box = CustomPaint(
      foregroundPainter: leave ? _DashedOutline(scheme.outline, radius) : null,
      child: Container(
        constraints: BoxConstraints(
          minHeight: big ? 48 : 28,
          minWidth: big ? 64 : 0,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: big ? 12 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: leave ? null : colors.container,
          borderRadius: BorderRadius.circular(radius),
        ),
        foregroundDecoration: mark == SkillMark.learn
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        alignment: Alignment.center,
        child: content,
      ),
    );
    final tappable = onTap == null
        ? box
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: box,
            ),
          );
    return Semantics(
      label: label,
      hint: hint,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: tappable,
      ),
    );
  }
}

/// A 1 px dashed rounded outline, for a skill that is Leave.
class _DashedOutline extends CustomPainter {
  _DashedOutline(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 4), paint);
        at += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.radius != radius;
}
