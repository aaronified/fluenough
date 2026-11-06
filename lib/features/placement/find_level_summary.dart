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
List<String> findLevelStandings(
  AppLocalizations l10n,
  PlacementRun run,
) => <String>[
  for (final found in findLevelSkillsListed(run)) _standing(l10n, run, found),
];

/// The skills in play of [run], in the order they are listed, with what the
/// run found for each.
List<SkillAssurance> findLevelSkillsListed(PlacementRun run) {
  final readout = run.readout;
  return <SkillAssurance>[
    for (final skill in PlacementSkill.values)
      if (run.config.skills.contains(skill) && readout[skill] != null)
        readout[skill]!,
  ];
}

/// One skill's line, as the checkpoint lists it.
String findLevelStanding(
  AppLocalizations l10n,
  PlacementRun run,
  SkillAssurance found,
) => _standing(l10n, run, found);

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

/// The skill's name as a learner reads it: Read, Hear, Say, Write, Script.
String findLevelSkillName(AppLocalizations l10n, PlacementSkill skill) =>
    _skillName(l10n, skill);

/// The word for a name of section 4.3, with no number.
String findLevelLabelName(AppLocalizations l10n, AssuranceLabel label) =>
    _labelName(l10n, label);

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

/// The end of a run (wiki/Plan-Placement-V2.md, sections 4.3 and 5.5): each
/// skill in play with where it is placed in plain words (a unit, never a
/// score), how sure the check is as a name, and a Verified mark. The
/// percentage is in the detail a tap opens, and a low name is explained
/// calmly, never as a fail. A skill that could not be tested says so and why.
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
                  const SizedBox(height: 8),
                  Text(
                    l10n.findLevelSummaryIntro,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final found in findLevelSkillsListed(run))
                    _SkillResult(
                      key: ValueKey<String>(
                        'find-level-result-${found.skill.name}',
                      ),
                      line: findLevelStanding(l10n, run, found),
                      found: found,
                      microphone: run.config.microphone,
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
                  style: AppButtonStyles.tall(context),
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

/// The percentage for the detail line, kept inside the range of its name so
/// that rounding never shows "95%" under "Sure".
int _percentOf(SkillAssurance found) {
  final rounded = (found.mass * 100).round();
  return switch (found.label) {
    AssuranceLabel.notTested ||
    AssuranceLabel.notSureYet => rounded.clamp(0, 49),
    AssuranceLabel.fairlySure => rounded.clamp(50, 79),
    AssuranceLabel.sure => rounded.clamp(80, 94),
    AssuranceLabel.verySure ||
    AssuranceLabel.verified => rounded.clamp(95, 100),
  };
}

/// One skill: its line and, when there is something to say, a calm note;
/// a tap opens how sure it is as a number.
class _SkillResult extends StatelessWidget {
  const _SkillResult({
    super.key,
    required this.line,
    required this.found,
    required this.microphone,
  });

  final String line;
  final SkillAssurance found;
  final bool microphone;

  String? _note(AppLocalizations l10n) => switch (found.label) {
    AssuranceLabel.notTested =>
      found.skill == PlacementSkill.say && !microphone
          ? l10n.findLevelNotTestedNoMic
          : l10n.findLevelNotTestedNotAsked,
    AssuranceLabel.notSureYet => l10n.findLevelNoteNotSureYet,
    AssuranceLabel.fairlySure => l10n.findLevelNoteFairlySure,
    AssuranceLabel.verified => l10n.findLevelNoteVerified,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = _note(l10n);
    final verified = found.label == AssuranceLabel.verified;
    final title = Row(
      children: <Widget>[
        Flexible(child: Text(line, style: theme.textTheme.titleMedium)),
        if (verified) ...<Widget>[
          const SizedBox(width: 8),
          Icon(
            Icons.verified,
            size: 20,
            color: scheme.primary,
            semanticLabel: l10n.findLevelLabelVerified,
          ),
        ],
      ],
    );
    final subtitle = note == null
        ? null
        : Text(
            note,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
    if (found.label == AssuranceLabel.notTested) {
      // Nothing to open: there is no number.
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: title,
        subtitle: subtitle,
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsetsDirectional.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: title,
      subtitle: subtitle,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.findLevelDetailPercent(_percentOf(found), found.questions),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
