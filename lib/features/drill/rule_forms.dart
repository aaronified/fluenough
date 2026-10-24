import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/unlocks.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';

/// The word's forms in the rule, under the answer to a question about one of
/// them (#417, owner, 2026-10-23: "show forms"), with the cell asked marked:
/// shown once the question is [answered], never before, which would give the
/// form away. Empty for a card that is not a rules table's cell, or a word
/// with one form. Spread it at the end of a drill's card.
List<Widget> answeredRuleForms(
  BuildContext context,
  DrillSession session, {
  required bool answered,
}) {
  final card = session.item.card;
  if (!answered || card.rule == null) return const <Widget>[];
  final forms = AppScope.of(context).ruleFormsOf(card);
  if (forms.length < 2) return const <Widget>[];
  return <Widget>[
    RuleFormsTable(
      forms: forms,
      asked: card.id,
      language: session.deck.language,
    ),
  ];
}

/// A word's forms in a rule, each with its reading and what it means; the
/// cell [asked] on `primaryContainer`, and marked selected for a screen
/// reader so that the colour never stands alone.
class RuleFormsTable extends StatelessWidget {
  const RuleFormsTable({
    super.key,
    required this.forms,
    required this.asked,
    required this.language,
  });

  final List<Card> forms;
  final String asked;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cell = forms.first.rule!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: <Widget>[
        Text(
          cell.wordReading == null
              ? l10n.ruleFormsTitle(cell.wordTarget)
              : l10n.ruleFormsTitle('${cell.wordTarget} (${cell.wordReading})'),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final form in forms)
              MergeSemantics(
                child: Semantics(
                  selected: form.id == asked ? true : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: form.id == asked
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TargetText(
                            form.target,
                            language: language,
                            fontSize: 18,
                            fontWeight: form.id == asked
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: form.id == asked
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                          if (form.reading case final reading?)
                            Text(
                              reading,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: form.id == asked
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            form.native,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: form.id == asked
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
