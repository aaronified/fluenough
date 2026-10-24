import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/unlocks.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/progress/recent_answers.dart';
import '../../core/progress/unlocks.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import 'path_parts.dart' show Pill;

/// Opens the "Why it is closed" sheet for [card], a sentence that waits for
/// words and rules (#416, owner, 2026-10-23: "Greyed + why sheet; no plan"):
/// each word and rule in it with where the learner stands against the bar,
/// and a way to practise the rule.
Future<void> showWhyClosedSheet(
  BuildContext context, {
  required Card card,
  required LanguageInfo language,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => WhyClosedSheet(card: card, language: language),
);

/// The sheet itself: a sentence, what it waits for and how far each is.
class WhyClosedSheet extends StatelessWidget {
  const WhyClosedSheet({super.key, required this.card, required this.language});

  final Card card;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needs = state.unlocks.needsOf(card);
    final practise = <DrillRequest?>[
      for (final need in needs)
        if (need.kind == NeedKind.rule && need.level != MasteryLevel.known)
          state.practiseRule(need.id),
    ].nonNulls.firstOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.whyClosedTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            TargetText(
              card.target,
              language: language,
              fontSize: 22,
              textAlign: TextAlign.start,
              card: card,
            ),
            if (card.reading case final reading?)
              Text(
                reading,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            Text(card.native, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(
              l10n.whyClosedIntro(knownRight, recentAnswerCount),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final need in needs) _NeedRow(need: need),
            if (practise != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(
                style: AppButtonStyles.secondary(context),
                onPressed: () {
                  Navigator.of(context).pop();
                  AppNavigator.startDrill(context, practise);
                },
                child: Text(l10n.whyClosedPractise),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.whyClosedReviewsNeverWait,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One word or rule the sentence uses: its name, its kind and where it
/// stands: Known, or how many of the last answers were right, with a bar.
class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.need});

  final Need need;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final known = need.level == MasteryLevel.known;
    final status = switch (need.level) {
      MasteryLevel.known => l10n.unitKnown,
      MasteryLevel.learning => l10n.whyClosedRight(
        need.right,
        recentAnswerCount,
      ),
      MasteryLevel.fresh => l10n.unitNew,
    };
    final name = state.needName(need);
    final kind = need.kind == NeedKind.word
        ? l10n.whyClosedWord
        : l10n.whyClosedRule;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
                const SizedBox(width: 8),
                Text(
                  kind,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Pill(
                  text: status,
                  background: known
                      ? scheme.primaryContainer
                      : need.level == MasteryLevel.learning
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  foreground: known
                      ? scheme.onPrimaryContainer
                      : need.level == MasteryLevel.learning
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
            if (need.level == MasteryLevel.learning) ...<Widget>[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: need.right / recentAnswerCount,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
