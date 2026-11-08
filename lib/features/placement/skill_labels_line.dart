import 'package:flutter/material.dart';

import '../../app/settings.dart';
import '../../core/placement/assurance_readout.dart';
import '../../core/placement/placement_questions.dart';
import '../../l10n/app_localizations.dart';
import 'find_level_labels.dart';

/// "likely 11 to 17" for a stored range.
String findLevelResultRangeShort(AppLocalizations l10n, PlacementRange r) =>
    r.high <= r.low
    ? l10n.findLevelSheetRangeOne(r.low)
    : l10n.findLevelSheetRangeBetween(r.low, r.high);

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
/// Say: Fairly sure", or with the V3 range "Read: unit 14, likely 11 to 17 ·
/// Fairly sure"; an earlier version's Verified mark reads "Earlier check (not
/// verified)". Nothing at
/// all when [labels] is empty.
class SkillLabelsLine extends StatelessWidget {
  const SkillLabelsLine({
    super.key,
    required this.labels,
    this.ranges = const <String, PlacementRange>{},
  });

  final Map<PlacementSkill, AssuranceLabel> labels;

  /// Where the last V3 run started each skill, by the skill's name: shown
  /// as "Read: unit 14, likely 11 to 17 · Fairly sure" in place of the bare
  /// name.
  final Map<String, PlacementRange> ranges;

  String _line(
    AppLocalizations l10n,
    PlacementSkill skill,
    AssuranceLabel label,
  ) {
    final range = ranges[skill.name];
    final name = findLevelSkillName(l10n, skill);
    // An earlier version's Verified mark is never shown with a range: it
    // says only that there was an earlier check.
    if (range == null || label == AssuranceLabel.verified) {
      return l10n.findLevelSheetLabel(name, findLevelLabelName(l10n, label));
    }
    return l10n.findLevelSheetRange(
      name,
      range.start,
      findLevelResultRangeShort(l10n, range),
      findLevelLabelName(l10n, label),
    );
  }

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
              Flexible(child: Text(_line(l10n, key, value), style: style)),
            ],
          ),
      ],
    );
  }
}
