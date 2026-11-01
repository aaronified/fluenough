import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';

/// How each skill looks on the Languages page: its icon, taken from the drill
/// skill it matches (Speak the microphone, Hear the ear, Read the eye, Write
/// the keyboard; a sign language's Gestures a raised hand). A pill's colour is
/// not the skill's but the level's, see [pillColors] (owner, 2026-11-01).
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

/// The colours of a pill in [mark], by level and not by skill (owner,
/// 2026-11-01): Leave red, Learn and Know two yellow tints, Learnt (Know with
/// the level found by placement, the double tick) dark green. The tokens are
/// `ModeColors.pillLeave` and the three after it.
ModeColor pillColors(ModeColors modes, SkillMark mark) => switch (mark) {
  SkillMark.leave => modes.pillLeave,
  SkillMark.learn => modes.pillLearn,
  SkillMark.know || SkillMark.knowBoth => modes.pillKnow,
  SkillMark.knowCovered || SkillMark.knowBothCovered => modes.pillVerified,
};

/// Whether [mark] is the double tick, a level found by placement.
bool markIsVerified(SkillMark mark) =>
    mark == SkillMark.knowCovered || mark == SkillMark.knowBothCovered;

/// Whether [mark] is the higher level of a combined pill (Read and Write,
/// Hear and Speak).
bool markIsBoth(SkillMark mark) =>
    mark == SkillMark.knowBoth || mark == SkillMark.knowBothCovered;

/// The skill whose icon follows [kind]'s on the higher level of a combined
/// pill: Write after Read on a script's pill, Speak after Hear on Spoken.
SkillKind secondKind(SkillKind kind) =>
    kind == SkillKind.hear ? SkillKind.speak : SkillKind.write;

/// What a pill's long press says, in a word or two (#913), and what a screen
/// reader reads after the pill's name: "Listening and speaking, checked".
/// A combined pill ([combined]: a script's Read and Write, Spoken's Hear and
/// Speak) names the levels; a single skill names its own skill.
String pillTip(
  AppLocalizations l10n,
  SkillKind kind,
  SkillMark mark, {
  required bool combined,
}) {
  if (mark == SkillMark.leave) return l10n.languagesPillLeave;
  if (mark == SkillMark.learn) {
    return combined
        ? l10n.languagesPillLearning
        : switch (kind) {
            SkillKind.read => l10n.languagesPillLearnRead,
            SkillKind.write => l10n.languagesPillLearnWrite,
            SkillKind.speak => l10n.languagesPillLearnSpeak,
            SkillKind.hear => l10n.languagesPillLearnHear,
            SkillKind.gesture => l10n.languagesPillLearnGesture,
          };
  }
  final both = markIsBoth(mark);
  final tip = combined
      ? switch ((kind, both)) {
          (SkillKind.hear, true) => l10n.languagesPillHearSpeak,
          (SkillKind.hear, false) => l10n.languagesPillHear,
          (_, true) => l10n.languagesPillReadWrite,
          (_, false) => l10n.languagesPillRead,
        }
      : switch (kind) {
          SkillKind.read => l10n.languagesPillRead,
          SkillKind.write => l10n.languagesPillWrite,
          SkillKind.speak => l10n.languagesPillSpeak,
          SkillKind.hear => l10n.languagesPillHear,
          SkillKind.gesture => l10n.languagesPillGesture,
        };
  return markIsVerified(mark) ? l10n.languagesPillChecked(tip) : tip;
}

/// What the long press shows (the tooltip rule: one word, two at most): the
/// level's own words, or "Checked" for a known skill the placement test
/// found. A screen reader still reads the whole [pillTip].
String pillHint(
  AppLocalizations l10n,
  SkillKind kind,
  SkillMark mark, {
  required bool combined,
}) => markIsVerified(mark)
    ? l10n.languagesPillCheckedHint
    : pillTip(l10n, kind, mark, combined: combined);

/// The name of a script's pill: "Script Devanagari".
String scriptPillName(AppLocalizations l10n, String script, String fallback) =>
    l10n.languagesSkillScript(
      l10n.languagesSkillScriptName,
      l10n.scriptNameOr(script, fallback),
    );

/// The mark on a pill, drawn so that no two are alike without colour: Leave
/// the block icon, Learn the cap, Know one tick small inside an outlined
/// circle, Learnt (the level found by placement) a double tick, bold, on a
/// filled capsule. Single and double tick differ in shape, size and fill,
/// never only in count.
class SkillMarkGlyph extends StatelessWidget {
  const SkillMarkGlyph({
    super.key,
    required this.mark,
    required this.colors,
    this.big = false,
  });

  final SkillMark mark;

  /// The pill's colours ([pillColors]): the glyph is drawn in the text colour.
  final ModeColor colors;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final fg = colors.onContainer;
    final icon = big ? 16.0 : 14.0;
    switch (mark) {
      case SkillMark.leave:
        return Icon(
          Icons.block,
          key: const ValueKey<String>('pill-mark-leave'),
          size: big ? 20 : 16,
          color: fg,
        );
      case SkillMark.learn:
        return Icon(
          Icons.school_outlined,
          key: const ValueKey<String>('pill-mark-learn'),
          size: icon,
          color: fg,
        );
      case SkillMark.know:
      case SkillMark.knowBoth:
        final d = big ? 20.0 : 16.0;
        return Container(
          key: const ValueKey<String>('pill-mark-know'),
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: fg, width: 1.5),
          ),
          child: Icon(Icons.check, size: big ? 12 : 10, color: fg),
        );
      case SkillMark.knowCovered:
      case SkillMark.knowBothCovered:
        return Container(
          key: const ValueKey<String>('pill-mark-verified'),
          width: big ? 32 : 26,
          height: big ? 22 : 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fg,
            borderRadius: BorderRadius.circular(big ? 11 : 9),
          ),
          child: Icon(
            Icons.done_all,
            size: big ? 18 : 14,
            color: colors.container,
          ),
        );
    }
  }
}

/// One skill as a chip or a pill, icons only, no word. The colour is the
/// level's ([pillColors]): red for Leave, two yellows for Learn and Know,
/// dark green for Learnt. A single skill ([combined] false) shows its own
/// icon and the mark; a combined pill (a script's Read and Write, Spoken's
/// Hear and Speak: [combined] true, [kind] the first skill) shows only the
/// icons of the levels reached, and the cap alone for Learn; Leave is the
/// block icon alone. Learn has a ring drawn inside (2 px, 1.5 px on a chip) (so its size does not
/// change), Leave a dashed outline. With [onTap] it is the sheet's pill;
/// without, the list's read-only chip. The long press says the level in a word
/// or two ([pillTip]); a screen reader reads [name] and that.
class SkillBadge extends StatelessWidget {
  const SkillBadge({
    super.key,
    required this.kind,
    required this.mark,
    required this.name,
    this.combined = false,
    this.onTap,
    this.hint,
    this.big = false,
  });

  final SkillKind kind;
  final SkillMark mark;

  /// What the row calls the pill ("Spoken", "Script Devanagari", "Gestures"),
  /// read before the level.
  final String name;

  /// A script's or the Spoken pill, not one skill.
  final bool combined;
  final VoidCallback? onTap;

  /// What the next tap does, for a screen reader.
  final String? hint;

  /// The sheet's pill, 48 px high; else the list's chip.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = pillColors(ModeColors.of(context), mark);
    final leave = mark == SkillMark.leave;
    final fg = colors.onContainer;
    // The mockup's 12 (big) and 8 (chip): AppRadii.chip and AppRadii.control.
    final radius = big ? AppRadii.chip : AppRadii.control;
    final iconSize = big ? 20.0 : 16.0;
    final icons = <SkillKind>[
      if (!leave && (!combined || (mark != SkillMark.learn))) kind,
      if (combined && markIsBoth(mark)) secondKind(kind),
    ];
    final tip = pillTip(l10n, kind, mark, combined: combined);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final k in icons) ...<Widget>[
          Icon(
            k.icon,
            key: ValueKey<String>('pill-icon-${k.name}'),
            size: iconSize,
            color: fg,
          ),
          SizedBox(width: big ? 2 : 1),
        ],
        SkillMarkGlyph(mark: mark, colors: colors, big: big),
      ],
    );
    final box = CustomPaint(
      foregroundPainter: leave ? DashedOutline(fg, radius) : null,
      child: Container(
        constraints: BoxConstraints(
          minHeight: big ? 48 : 28,
          minWidth: big ? 48 : 28,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: big ? (leave ? 12 : 10) : 7,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: BorderRadius.circular(radius),
        ),
        foregroundDecoration: mark == SkillMark.learn
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: fg, width: big ? 2 : 1.5),
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
      label: l10n.languagesSkillState(name, tip),
      hint: hint,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Hint(
        message: pillHint(l10n, kind, mark, combined: combined),
        excludeFromSemantics: true,
        child: tappable,
      ),
    );
  }
}

/// A 1 px dashed rounded outline, for a skill that is Leave (the pill and
/// the key's swatch).
class DashedOutline extends CustomPainter {
  DashedOutline(this.color, this.radius);

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
  bool shouldRepaint(DashedOutline old) =>
      old.color != color || old.radius != radius;
}
