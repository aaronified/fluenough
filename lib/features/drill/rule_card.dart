import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/unlocks.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/path_parts.dart' show Pill;

/// The rule card (#417, owner, 2026-10-18: "Name, explanation, worked
/// forms"): shown once, before the first question about a cell of a rule.
/// The rule's name, its explanation with readings, and the rule's forms on
/// two or three words the learner already knows. [card] is the first cell
/// asked.
///
/// Where a word changes its stem, the rule's explanation says so, as the
/// deck's notes do (DECK-FORMAT.md).
class RuleCard extends StatelessWidget {
  const RuleCard({super.key, required this.card, required this.language});

  final Card card;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cell = card.rule;
    final rule = cell == null ? null : state.ruleOf(cell.ruleId)?.rule;
    final forms = state.ruleExamples(card);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          Pill(
            text: l10n.ruleCardKind,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
          ),
          if (rule != null) ...<Widget>[
            Semantics(
              header: true,
              child: Text(rule.name, style: theme.textTheme.headlineMedium),
            ),
            Text(rule.explanation, style: theme.textTheme.bodyLarge),
          ],
          Text(
            l10n.ruleCardWords,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final form in forms) _FormRow(card: form, language: language),
        ],
      ),
    );
  }
}

/// One word in the rule: the word, its form, and what the form means.
class _FormRow extends StatelessWidget {
  const _FormRow({required this.card, required this.language});

  final Card card;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cell = card.rule!;
    Widget word(String text, String? reading, double size, Color? color) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TargetText(
              text,
              language: language,
              fontSize: size,
              textAlign: TextAlign.start,
              color: color,
            ),
            if (reading != null)
              Text(
                reading,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        );
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: word(
                      cell.wordTarget,
                      cell.wordReading,
                      18,
                      scheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: word(card.target, card.reading, 22, scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(card.native, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
