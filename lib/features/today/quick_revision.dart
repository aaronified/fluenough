import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import 'today_numbers.dart';

/// Listening and speaking: the skills by ear and mouth, revised together as
/// "Spoken" (ADR-0030).
const Set<Skill> spokenSkills = <Skill>{Skill.listening, Skill.speaking};

/// Quick revision on Today (ADR-0029): 5, 10, 15 or 20 words the learner
/// has been taught, picked at random, due or not. A miss is recorded; a
/// right answer is not.
///
/// A row of choices above the sizes narrows it to some skills (ADR-0030):
/// all of them, the spoken ones, or one skill switched on.
class QuickRevision extends StatefulWidget {
  const QuickRevision({super.key});

  /// The sizes offered, in words.
  static const List<int> sizes = <int>[5, 10, 15, 20];

  @override
  State<QuickRevision> createState() => _QuickRevisionState();
}

/// One choice of skills: null [skills] for all of them.
typedef _Choice = ({String key, String label, Set<Skill>? skills});

class _QuickRevisionState extends State<QuickRevision> {
  String _chosen = 'all';

  /// All, Spoken while listening and speaking are both on, then each skill
  /// with a tile on Today that is switched on.
  List<_Choice> _choices(AppState state, AppLocalizations l10n) {
    bool on(Skill skill) =>
        state.settings.isEnabled(skill) &&
        state.features.isAvailable(skill.feature);
    return <_Choice>[
      (key: 'all', label: l10n.todayRevisionAll, skills: null),
      if (spokenSkills.every(on))
        (key: 'spoken', label: l10n.todayRevisionSpoken, skills: spokenSkills),
      for (final skill in todaySkills)
        if (on(skill))
          (key: skill.name, label: skill.label(l10n), skills: <Skill>{skill}),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final choices = _choices(state, l10n);
    // A skill switched off since it was chosen falls back to all.
    final choice = choices.firstWhere(
      (c) => c.key == _chosen,
      orElse: () => choices.first,
    );
    final knownAtAll = state.revisableCount;
    final known = choice.skills == null
        ? knownAtAll
        : state.revisableIn(choice.skills);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Semantics(
            header: true,
            child: Text(
              l10n.todayRevisionTitle,
              style: theme.textTheme.sectionTitle,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            knownAtAll == 0
                ? l10n.todayRevisionNone
                : known == 0
                ? l10n.todayRevisionNoneIn(choice.label)
                : l10n.todayRevisionBody,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (knownAtAll > 0 && choices.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: l10n.todayRevisionSkillsLabel,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final c in choices)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c.key == choice.key,
                    onSelected: (_) => setState(() => _chosen = c.key),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (final (i, size) in QuickRevision.sizes.indexed) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  style: AppButtonStyles.tall(context),
                  onPressed: known == 0
                      ? null
                      : () => AppNavigator.startDrill(
                          context,
                          DrillRequest.revision(size, skills: choice.skills),
                        ),
                  child: Semantics(
                    label: l10n.todayRevisionCards(size),
                    excludeSemantics: true,
                    child: Text('$size'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
