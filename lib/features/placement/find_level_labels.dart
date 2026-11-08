import 'dart:ui' show VoidCallback;

import '../../core/placement/assurance_readout.dart';
import '../../core/placement/placement_questions.dart';
import '../../l10n/app_localizations.dart';

/// The skill's name as a learner reads it: Read, Hear, Say, Write, Script.
String findLevelSkillName(AppLocalizations l10n, PlacementSkill skill) =>
    switch (skill) {
      PlacementSkill.read => l10n.findLevelSkillRead,
      PlacementSkill.hear => l10n.findLevelSkillHear,
      PlacementSkill.say => l10n.findLevelSkillSay,
      PlacementSkill.write => l10n.findLevelSkillWrite,
      PlacementSkill.script => l10n.findLevelSkillScript,
      PlacementSkill.secondScript => l10n.findLevelSkillSecondScript,
    };

/// The word for a stored confidence label, with no number. `verified` is an
/// earlier version's mark, shown as "Earlier check (not verified)".
String findLevelLabelName(AppLocalizations l10n, AssuranceLabel label) =>
    switch (label) {
      AssuranceLabel.notTested => '',
      AssuranceLabel.notSureYet => l10n.findLevelLabelNotSureYet,
      AssuranceLabel.fairlySure => l10n.findLevelLabelFairlySure,
      AssuranceLabel.sure => l10n.findLevelLabelSure,
      AssuranceLabel.verySure => l10n.findLevelLabelVerySure,
      AssuranceLabel.verified => l10n.findLevelLabelVerified,
    };

/// What a Check again does at its end, in place of writing the run
/// (wiki/Plan-Placement-V2.md, point 17.5): [before] is the level each word
/// skill held as unconfirmed credit (a path index), [onUse] writes the new
/// level (withdrawing the credit above it) and [onKeep] keeps the old one.
class FindLevelRecheck {
  const FindLevelRecheck({
    required this.before,
    required this.onUse,
    required this.onKeep,
  });

  /// The credited level of each word skill that held unconfirmed credit,
  /// as a path index.
  final Map<PlacementSkill, int> before;

  /// Use the new level: writes the run.
  final VoidCallback onUse;

  /// Keep the old level: writes nothing but the choice.
  final VoidCallback onKeep;
}
