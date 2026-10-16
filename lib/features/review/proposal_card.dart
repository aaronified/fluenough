import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/proposal.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import 'review_sheets.dart';

/// The part of a card "Suggest a change" names for a proposal's [field].
CardPart partOf(ProposalField field) => switch (field) {
  ProposalField.target => CardPart.word,
  ProposalField.reading => CardPart.reading,
  ProposalField.ipa => CardPart.ipa,
  ProposalField.native => CardPart.meaning,
  ProposalField.notes => CardPart.notes,
};

/// The proposals waiting on [card] of [deck] (ADR-0038), from every deck
/// of its language in [decks], each once: a proposal is kept in the file
/// that holds the field, which may be another deck's when [deck] lists the
/// card by ref. Only those whose field still says, in [deck], what the
/// proposer saw: one whose field has changed since is outdated, and the
/// review bot removes it.
List<Proposal> waitingProposals(
  Iterable<DeckEntry> decks,
  DeckEntry deck,
  Card card,
) {
  final seen = <String>{};
  return <Proposal>[
    for (final d in <DeckEntry>[deck, ...decks])
      if (d.language.code == deck.language.code)
        for (final p in d.deck.proposals[card.id] ?? const <Proposal>[])
          if ((partText(card, partOf(p.field)) ?? '') == p.now &&
              seen.add(p.id))
            p,
  ];
}

/// Another reviewer's proposed change to [card], with Accept, Edit and
/// Reject; the reviewer's own, without them. The answer is kept with the
/// card's review and sent with it.
class ProposalCard extends StatelessWidget {
  const ProposalCard({
    super.key,
    required this.deck,
    required this.card,
    required this.proposal,
  });

  final DeckEntry deck;
  final Card card;
  final Proposal proposal;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The answer is kept in the settings, which the sheet does not watch.
    listenable: AppScope.of(context).reviewing.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final reviewing = state.reviewing;
    final p = proposal;
    final own = '${reviewing.code}' == p.by;
    final answer = reviewing.answerTo(deck, card, p);
    final language = deck.language;
    final small = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final words = p.field == ProposalField.target;

    void choose(ProposalVerdict verdict) =>
        reviewing.answer(deck, card, p, answer == verdict ? null : verdict);

    Widget choice(ProposalVerdict verdict, IconData icon, String label) {
      final chosen = answer == verdict;
      final onPressed = verdict == ProposalVerdict.edit
          ? () => showSuggestSheet(context, deck: deck, card: card, from: p)
          : () => choose(verdict);
      return Semantics(
        selected: chosen,
        child: chosen
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
              ),
      );
    }

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: <Widget>[
          Text(
            l10n.reviewProposalTitle(partName(l10n, partOf(p.field))),
            style: theme.textTheme.titleSmall,
          ),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.reviewSuggestNow, style: small),
                if (p.now.isEmpty)
                  Text(l10n.reviewSuggestNothing)
                else
                  Text.rich(
                    quotingTarget(p.now, <String>[if (words) p.now], language),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.reviewProposalNew, style: small),
                Text.rich(
                  quotingTarget(p.text, <String>[if (words) p.text], language),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          if (p.why.isNotEmpty)
            Text(l10n.reviewProposalWhy(p.why), style: small),
          Text(
            own
                ? l10n.reviewProposalYours(p.accepted.length)
                : l10n.reviewProposalBy(p.by, p.accepted.length),
            style: small,
          ),
          if (!own) ...<Widget>[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                choice(
                  ProposalVerdict.accept,
                  Icons.check,
                  l10n.reviewProposalAccept,
                ),
                choice(
                  ProposalVerdict.edit,
                  Icons.edit_outlined,
                  l10n.reviewProposalEdit,
                ),
                choice(
                  ProposalVerdict.reject,
                  Icons.close,
                  l10n.reviewProposalReject,
                ),
              ],
            ),
            if (answer != null)
              Text(switch (answer) {
                ProposalVerdict.accept => l10n.reviewProposalAccepted,
                ProposalVerdict.edit => l10n.reviewProposalEdited,
                ProposalVerdict.reject => l10n.reviewProposalRejected,
              }, style: small),
          ],
        ],
      ),
    );
  }
}
