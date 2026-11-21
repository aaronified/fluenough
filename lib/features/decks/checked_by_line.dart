import 'package:flutter/material.dart' hide Card;

import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../l10n/app_localizations.dart';

/// The rater codes of the reviewers who signed [card] off (#449), each
/// once: as [deck] lists them in its `checked_by`, written by the review
/// bot, or without a deck as every deck among [decks] that holds the card
/// does.
Set<String> checkedByOf(
  Iterable<DeckEntry> decks,
  Card card, {
  DeckEntry? deck,
}) => <String>{
  if (deck != null)
    ...?deck.deck.checkedBy[card.id]
  else
    for (final d in decks)
      if (d.cards.any((c) => c.id == card.id)) ...?d.deck.checkedBy[card.id],
};

/// "Checked by 3 speakers" (ADR-0058, decision 4; docs/mockups/reviewer-ux.html,
/// frame 6): how many distinct reviewers checked a card, in small muted text
/// under its example on a word's card, and in review. Nothing when no one
/// has. Never the quorum, never "N of N" and never "needs N": only how many
/// speakers did.
class CheckedByLine extends StatelessWidget {
  const CheckedByLine({
    super.key,
    required this.count,
    this.alignment = MainAxisAlignment.center,
  });

  final int count;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: alignment,
        children: <Widget>[
          Flexible(
            child: Text(
              l10n.cardCheckedBy(count),
              style: theme.textTheme.bodySmall!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
