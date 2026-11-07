import 'package:flutter/material.dart';

import '../../core/placement/assurance_readout.dart';
import '../../core/placement/placement_questions.dart';
import '../../core/placement/placement_run.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'find_level_summary.dart';

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

/// The level of [found] as the comparison says it: "from the start", "unit
/// 40", or "at least unit 40" while a higher class is more probable.
String findLevelNowText(AppLocalizations l10n, SkillAssurance found) =>
    found.placedLevel < 0
    ? l10n.findLevelCompareStart
    : found.lowerBound
    ? l10n.findLevelCompareAtLeast(found.placedUnit)
    : l10n.findLevelCompareUnit(found.placedUnit);

/// Whether the new level of every word skill in [before] is at least the old
/// one: "The check found at least what you had".
bool findLevelAtLeastBefore(PlacementRun run, Map<PlacementSkill, int> before) {
  for (final MapEntry(key: skill, value: level) in before.entries) {
    final found = run.readout[skill];
    if (found == null || found.label == AssuranceLabel.notTested) continue;
    if (found.placedLevel < level) return false;
  }
  return true;
}

/// "Your level, before and now": one line for each skill the run tested,
/// both levels, and the two choices. Nothing is written until one is
/// pressed.
class FindLevelComparison extends StatelessWidget {
  const FindLevelComparison({
    super.key,
    required this.run,
    required this.recheck,
  });

  final PlacementRun run;
  final FindLevelRecheck recheck;

  String _line(AppLocalizations l10n, SkillAssurance found) {
    final label = findLevelLabelName(l10n, found.label);
    final isScript =
        found.skill == PlacementSkill.script ||
        found.skill == PlacementSkill.secondScript;
    if (isScript) return findLevelStanding(l10n, run, found);
    final before = recheck.before[found.skill];
    return l10n.findLevelCompareLine(
      findLevelSkillName(l10n, found.skill),
      before == null
          ? l10n.findLevelCompareNothingBefore
          : l10n.findLevelCompareUnit(before + 1),
      findLevelNowText(l10n, found),
      label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <String>[
      for (final found in findLevelSkillsListed(run))
        if (found.label != AssuranceLabel.notTested) _line(l10n, found),
    ];
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.gutter),
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.findLevelCompareTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(line, style: theme.textTheme.titleMedium),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.findLevelCompareNothingChanges,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (findLevelAtLeastBefore(run, recheck.before)) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n.findLevelCompareAtLeastWhatYouHad,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    key: const ValueKey<String>('find-level-use-new'),
                    style: AppButtonStyles.tall(context),
                    onPressed: recheck.onUse,
                    child: Text(l10n.findLevelUseNew),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey<String>('find-level-keep-old'),
                    style: AppButtonStyles.tall(context),
                    onPressed: recheck.onKeep,
                    child: Text(l10n.findLevelKeepOld),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
