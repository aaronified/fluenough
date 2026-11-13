import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';

/// The most cards a drill on a topic may be limited to, by the first two
/// choices (the third is every card).
const List<int> topicDrillSizes = <int>[10, 20];

/// The skills a topic drill may ask, as the sheet names them (the approved
/// topic-page mockup): Read, Hear, Say and Write.
const List<Skill> topicDrillSkills = <Skill>[
  Skill.recognition,
  Skill.listening,
  Skill.speaking,
  Skill.production,
];

/// The skills the sheet starts with: Read and Hear.
const Set<Skill> topicDrillDefaultSkills = <Skill>{
  Skill.recognition,
  Skill.listening,
};

String _skillName(AppLocalizations l10n, Skill skill) => switch (skill) {
  Skill.recognition => l10n.topicSkillRead,
  Skill.listening => l10n.topicSkillHear,
  Skill.speaking => l10n.topicSkillSay,
  _ => l10n.topicSkillWrite,
};

/// The sheet that chooses a topic drill (mockup `topic-page.html`, screen 2):
/// how many cards, which skills, and Start. Pops the [DrillRequest] to start,
/// or null when dismissed.
Future<DrillRequest?> showTopicDrillSheet(
  BuildContext context, {
  required String topicName,
  required String language,
  required Set<String> cardIds,
  required bool revise,
}) => showModalBottomSheet<DrillRequest>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => TopicDrillSheet(
    topicName: topicName,
    language: language,
    cardIds: cardIds,
    revise: revise,
  ),
);

class TopicDrillSheet extends StatefulWidget {
  const TopicDrillSheet({
    super.key,
    required this.topicName,
    required this.language,
    required this.cardIds,
    required this.revise,
  });

  final String topicName;
  final String language;

  /// The cards the topic's drill may use, at the learner's level.
  final Set<String> cardIds;

  /// Whether the topic has nothing new: the drill only revises.
  final bool revise;

  @override
  State<TopicDrillSheet> createState() => _TopicDrillSheetState();
}

class _TopicDrillSheetState extends State<TopicDrillSheet> {
  /// How many cards; 0 for all.
  int _count = topicDrillSizes.first;
  final Set<Skill> _skills = <Skill>{...topicDrillDefaultSkills};

  DrillRequest _request() => DrillRequest.sheet(
    widget.cardIds,
    language: widget.language,
    revise: widget.revise,
    skills: <Skill>{..._skills},
    limit: _count == 0 ? null : _count,
  );

  /// How many cards the chosen skills and size would ask right now.
  int _drillable(AppState state) {
    try {
      return state.sheetSession(_request()).length;
    } on Object catch (error) {
      state.log.warning('A topic drill could not be counted: $error');
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = widget.cardIds.length;
    final sizes = <int>[
      for (final n in topicDrillSizes)
        if (n < total) n,
    ];
    if (!sizes.contains(_count) && _count != 0) _count = 0;
    // An empty skill set would mean every skill, so Start waits for a choice,
    // and for a session that has something to ask.
    final noSkill = _skills.isEmpty;
    final nothing = !noSkill && _drillable(AppScope.of(context)) == 0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.topicSheetTitle(widget.topicName),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.topicSheetBody,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.topicHowMany, style: theme.textTheme.titleSmall),
            RadioGroup<int>(
              groupValue: _count,
              onChanged: (value) => setState(() => _count = value ?? 0),
              child: Column(
                children: <Widget>[
                  for (final n in sizes)
                    RadioListTile<int>(
                      value: n,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.topicHowManyN(n)),
                    ),
                  RadioListTile<int>(
                    value: 0,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.topicHowManyAll(total)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.topicSkills, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final skill in topicDrillSkills)
                  FilterChip(
                    label: Text(_skillName(l10n, skill)),
                    selected: _skills.contains(skill),
                    onSelected: (on) => setState(() {
                      on ? _skills.add(skill) : _skills.remove(skill);
                    }),
                  ),
              ],
            ),
            if (noSkill || nothing)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  noSkill ? l10n.topicChooseASkill : l10n.topicNothingToDrill,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: noSkill || nothing
                    ? null
                    : () => Navigator.of(context).pop(_request()),
                child: Text(l10n.topicStartDrill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
