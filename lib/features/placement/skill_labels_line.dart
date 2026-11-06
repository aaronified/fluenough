import 'package:flutter/material.dart';

import '../../app/settings.dart';
import '../../core/placement/assurance_readout.dart';
import '../../core/placement/placement_questions.dart';
import '../../l10n/app_localizations.dart';
import 'find_level_summary.dart';

/// How sure the last Find my level run was of each of [skills] in [language],
/// from the settings: its stored name, or Verified when the skill carries
/// the mark. A skill the learner has never been placed in is left out, so a
/// language with no run shows nothing new (wiki/Plan-Placement-V2.md,
/// section 5.5).
Map<PlacementSkill, AssuranceLabel> placedLabelsOf(
  SettingsNotifier settings,
  String language,
  Iterable<PlacementSkill> skills,
) {
  final verified = settings.verifiedSkillsOf(language);
  final stored = settings.skillLabelsOf(language);
  final out = <PlacementSkill, AssuranceLabel>{};
  for (final skill in skills) {
    if (verified.contains(skill.name)) {
      out[skill] = AssuranceLabel.verified;
      continue;
    }
    for (final label in AssuranceLabel.values) {
      // A stored `verified` is not enough: only the skill's Verified mark
      // (set with the run's write) shows as Verified.
      if (label != AssuranceLabel.notTested &&
          label != AssuranceLabel.verified &&
          stored[skill.name] == label.name) {
        out[skill] = label;
      }
    }
  }
  return out;
}

/// The small line under a skill row of the Languages sheet: "Hear: Sure ·
/// Say: Very sure", with a quiet mark before a Verified skill. Nothing at
/// all when [labels] is empty.
class SkillLabelsLine extends StatelessWidget {
  const SkillLabelsLine({super.key, required this.labels});

  final Map<PlacementSkill, AssuranceLabel> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final MapEntry(:key, :value) in labels.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (value == AssuranceLabel.verified) ...<Widget>[
                Icon(Icons.verified, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  l10n.findLevelSheetLabel(
                    findLevelSkillName(l10n, key),
                    findLevelLabelName(l10n, value),
                  ),
                  style: style,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
