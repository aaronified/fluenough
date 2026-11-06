import 'package:flutter/material.dart';

import '../../core/placement/assurance_readout.dart';
import '../../core/placement/placement_questions.dart';
import '../../core/placement/placement_run.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The words for one skill of a run, as the checkpoint and the result both
/// list them (wiki/Plan-Placement-V2.md, sections 5.4 and 5.5): "Hear: unit
/// 40 · Very sure", "Script: known · Sure", "Say: not tested". The skills in
/// play only; a skill the learner did not mark is not listed.
List<String> findLevelStandings(AppLocalizations l10n, PlacementRun run) {
  final readout = run.readout;
  return <String>[
    for (final skill in PlacementSkill.values)
      if (run.config.skills.contains(skill) && readout[skill] != null)
        _standing(l10n, run, readout[skill]!),
  ];
}

String _standing(
  AppLocalizations l10n,
  PlacementRun run,
  SkillAssurance found,
) {
  final name = _skillName(l10n, found.skill);
  if (found.label == AssuranceLabel.notTested) {
    return l10n.findLevelStandNotTested(name);
  }
  final label = _labelName(l10n, found.label);
  final isScript =
      found.skill == PlacementSkill.script ||
      found.skill == PlacementSkill.secondScript;
  if (isScript) {
    return found.leadingClass == run.levels.topClass
        ? l10n.findLevelStandScriptKnown(name, label)
        : l10n.findLevelStandScriptNot(name, label);
  }
  return found.placedLevel < 0
      ? l10n.findLevelStandStart(name, label)
      : l10n.findLevelStandUnit(name, found.placedUnit, label);
}

String _skillName(AppLocalizations l10n, PlacementSkill skill) =>
    switch (skill) {
      PlacementSkill.read => l10n.findLevelSkillRead,
      PlacementSkill.hear => l10n.findLevelSkillHear,
      PlacementSkill.say => l10n.findLevelSkillSay,
      PlacementSkill.write => l10n.findLevelSkillWrite,
      PlacementSkill.script => l10n.findLevelSkillScript,
      PlacementSkill.secondScript => l10n.findLevelSkillSecondScript,
    };

String _labelName(AppLocalizations l10n, AssuranceLabel label) =>
    switch (label) {
      AssuranceLabel.notTested => '',
      AssuranceLabel.notSureYet => l10n.findLevelLabelNotSureYet,
      AssuranceLabel.fairlySure => l10n.findLevelLabelFairlySure,
      AssuranceLabel.sure => l10n.findLevelLabelSure,
      AssuranceLabel.verySure => l10n.findLevelLabelVerySure,
      AssuranceLabel.verified => l10n.findLevelLabelVerified,
    };

/// The end of a run, as a minimal list: each skill's placed level and its
/// name from the readout. Step 5 of the plan (the confidence display, 4.3
/// and 5.5) replaces this widget; the run page shows it once the outcome is
/// written, and leaves with `Navigator.pop` when [onDone] is called.
class FindLevelSummary extends StatelessWidget {
  const FindLevelSummary({super.key, required this.run, required this.onDone});

  /// The finished run.
  final PlacementRun run;

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.gutter),
                children: <Widget>[
                  Text(
                    l10n.findLevelSummaryTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  for (final line in findLevelStandings(l10n, run))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(line, style: theme.textTheme.titleMedium),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.gutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('find-level-done'),
                  onPressed: onDone,
                  child: Text(l10n.languagesDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
