import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';

/// How each of the four skills looks on the Languages page: Speak is the
/// speaking skill's microphone and green, Hear listening's ear and purple,
/// Read recognition's eye and blue, Write production's keyboard and orange
/// (`lib/ui/skill_visuals.dart`, `ModeColors`), fixed whatever the seed. A
/// sign language's one skill, Gestures, has its own: a raised hand, in red.
extension SkillKindVisuals on SkillKind {
  /// The drill skill whose look it borrows, or null for a gesture skill,
  /// which has its own.
  Skill? get skill => switch (this) {
    SkillKind.speak => Skill.speaking,
    SkillKind.hear => Skill.listening,
    SkillKind.read => Skill.recognition,
    SkillKind.write => Skill.production,
    SkillKind.gesture => null,
  };

  IconData get icon => switch (this) {
    SkillKind.gesture => Icons.front_hand_outlined,
    _ => skill!.icon,
  };

  ModeColor colors(ModeColors modes) => switch (this) {
    SkillKind.gesture => modes.gesture,
    _ => modes.forSkill(skill!),
  };

  String label(AppLocalizations l10n) => switch (this) {
    SkillKind.speak => l10n.languagesSkillSpeak,
    SkillKind.hear => l10n.languagesSkillHear,
    SkillKind.read => l10n.languagesSkillRead,
    SkillKind.write => l10n.languagesSkillWrite,
    SkillKind.gesture => l10n.languagesSkillGestures,
  };
}

extension SkillStateText on SkillState {
  String label(AppLocalizations l10n) => switch (this) {
    SkillState.leave => l10n.languagesStateLeave,
    SkillState.know => l10n.languagesStateKnow,
    SkillState.learn => l10n.languagesStateLearn,
  };
}

extension ScriptLevelText on ScriptLevel {
  String label(AppLocalizations l10n) => switch (this) {
    ScriptLevel.leave => l10n.languagesStateLeave,
    ScriptLevel.learn => l10n.languagesStateLearn,
    ScriptLevel.read => l10n.languagesSkillRead,
    ScriptLevel.readWrite => l10n.languagesSkillReadWrite,
  };
}

extension SpokenLevelText on SpokenLevel {
  String label(AppLocalizations l10n) => switch (this) {
    SpokenLevel.leave => l10n.languagesStateLeave,
    SpokenLevel.learn => l10n.languagesStateLearn,
    SpokenLevel.hear => l10n.languagesSkillHear,
    SpokenLevel.hearSpeak => l10n.languagesSkillHearSpeak,
  };
}

/// The mark in a chip's corner: a tick for Know, a double tick once the
/// level covers it, a cap for Learn, a minus for Leave. Never colour alone.
/// The higher Know level of a pill ([SkillMark.knowBoth]) is the tick and
/// the icon of the extra skill: the keyboard of Write on a script's pill, the
/// microphone of Speak on the Spoken pill.
IconData markIcon(SkillMark mark) => switch (mark) {
  SkillMark.leave => Icons.remove,
  SkillMark.know || SkillMark.knowBoth => Icons.check,
  SkillMark.knowCovered || SkillMark.knowBothCovered => Icons.done_all,
  SkillMark.learn => Icons.school_outlined,
};

/// The icon after the tick on the higher Know level of the pill of [kind]
/// (Read for a script's pill, Hear for the Spoken pill), else null.
IconData? markExtraIcon(SkillMark mark, SkillKind kind) =>
    mark == SkillMark.knowBoth || mark == SkillMark.knowBothCovered
    ? (kind == SkillKind.hear ? SkillKind.speak.icon : SkillKind.write.icon)
    : null;

/// Know's fill: the skill's container, darkened a little so that Know stands
/// apart from Learn, which keeps the container and adds the border. The text
/// stays 4.5:1 or better on it in every theme.
Color knowFill(Color container, Brightness brightness) => Color.lerp(
  container,
  Colors.black,
  brightness == Brightness.dark ? 0.35 : 0.18,
)!;

/// The name of a script's pill: "Script Devanagari".
String scriptPillName(AppLocalizations l10n, String script, String fallback) =>
    l10n.languagesSkillScript(
      l10n.languagesSkillScriptName,
      l10n.scriptNameOr(script, fallback),
    );

/// A pill's level as a screen reader reads it: "Spoken: Hear and Speak",
/// with ", level found" where the found level covers a Know level.
String pillSemantics(
  AppLocalizations l10n,
  String name,
  String levelLabel, {
  required bool covered,
}) => covered
    ? l10n.languagesSkillStateCovered(name, levelLabel)
    : l10n.languagesSkillState(name, levelLabel);

/// One skill as a chip or a pill: its icon in its colour and the mark of its
/// state; Know is the skill's container darkened ([knowFill]), Learn the container with a 2 px
/// primary border drawn inside (so its size does not change), Leave dashed.
/// With [onTap] it is the sheet's pill; without, the list's read-only chip.
class SkillBadge extends StatelessWidget {
  const SkillBadge({
    super.key,
    required this.kind,
    required this.mark,
    required this.label,
    this.scriptGlyph,
    this.onTap,
    this.hint,
    this.tip,
    this.big = false,
  });

  final SkillKind kind;
  final SkillMark mark;

  /// What a screen reader and the tooltip say.
  final String label;

  /// A script's glyph, drawn in place of the skill's icon on a script's pill
  /// ([kind] is Read, for its colour).
  final String? scriptGlyph;
  final VoidCallback? onTap;

  /// What the next tap does, for a screen reader.
  final String? hint;

  /// What a long press shows: short, the skill and its state. Defaults to
  /// [label].
  final String? tip;

  /// The sheet's pill, 48 px high; else the list's chip.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = kind.colors(ModeColors.of(context));
    final leave = mark == SkillMark.leave;
    final fg = leave ? scheme.onSurfaceVariant : colors.onContainer;
    final radius = big ? AppRadii.card : AppRadii.control;
    final iconSize = big ? 24.0 : 16.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (scriptGlyph != null)
          Text(
            scriptGlyph!,
            style:
                (big
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.labelLarge)!
                    .copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
          )
        else
          Icon(kind.icon, size: iconSize, color: fg),
        SizedBox(width: big ? 4 : 2),
        Icon(markIcon(mark), size: big ? 16 : 14, color: fg),
        if (markExtraIcon(mark, kind) case final extra?)
          Icon(extra, size: big ? 16 : 14, color: fg),
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
          color: leave
              ? null
              : mark != SkillMark.learn
              ? knowFill(colors.container, theme.brightness)
              : colors.container,
          borderRadius: BorderRadius.circular(radius),
        ),
        foregroundDecoration: mark == SkillMark.learn
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        // No `alignment` here: it wraps the child in an Align, which fills
        // all the width a Wrap offers and drew every chip full width. The
        // Row centres its own icons within a minimum width.
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
      child: Hint(
        message: tip ?? label,
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
