import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../core/review/flagged_queue.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/system_bar.dart';
import 'facet_labels.dart';
import 'review_waiting.dart';

/// The flagged queue of [state]'s reviewer: the cards of the courses they
/// review with a facet flagged or contested ([FlaggedQueue]). Empty while
/// reviewing is off.
FlaggedQueue flaggedQueueOf(AppState state) {
  final reviewing = state.reviewing;
  final code = reviewing.code;
  if (!reviewing.on || code == null) return FlaggedQueue.empty;
  return FlaggedQueue.build(
    decks: <FlaggedSourceDeck>[
      for (final deck in state.reviewDecks)
        FlaggedSourceDeck(
          deckId: deck.id,
          pair: pairOf(deck),
          cards: deck.cards,
        ),
    ],
    allowed: reviewPairsOf(state),
    reviews: reviewing.reviews,
    ownCode: '$code',
  );
}

/// The reason line of a row, in lower case: the tags of what is flagged, then
/// the names of what is contested ("reading wrong", "meaning wrong, unit
/// wrong", "spelling").
String flaggedReason(AppLocalizations l10n, FlaggedCard card) => <String>[
  for (final tag in card.flaggedTags) pointerTagLabel(l10n, tag),
  for (final facet in card.contestedFacets) facetTitle(l10n, facet),
].map((s) => s.toLowerCase()).join(', ');

/// Opens the flagged and contested list.
Future<void> showFlagged(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/review-flagged'),
    builder: (_) => const FlaggedPage(),
  ),
);

/// Flagged and contested (ADR-0058, decisions 5 and 10; docs/mockups/
/// reviewer-ux.html, frame 1b): a row for each card, its word, a pill and the
/// reason, and one button, "Review all N".
///
/// TODO(W3): a row and the button open the existing unit review of the
/// card's deck ([AppRoutes.review]). The queue screens that show one card at
/// a time, with its facets, and the flagged-only mode are W3: wire both to
/// them with [FlaggedQueue.cards].
class FlaggedPage extends StatelessWidget {
  const FlaggedPage({super.key});

  static const Key reviewAllKey = ValueKey<String>('flagged-review-all');

  /// The row of the card [cardId] in [deckId].
  static Key rowKey(String deckId, String cardId) =>
      ValueKey<String>('flagged-$deckId-$cardId');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewFlaggedTitle)),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final queue = flaggedQueueOf(state);
    if (queue.isEmpty) {
      return EmptyState(
        icon: Icons.flag_outlined,
        title: l10n.reviewFlaggedEmpty,
      );
    }
    final decks = <String, DeckEntry>{
      for (final deck in state.reviewDecks) deck.id: deck,
    };
    String wordOf(FlaggedCard card) =>
        decks[card.deckId]?.cards
            .where((c) => c.id == card.cardId)
            .firstOrNull
            ?.target ??
        card.cardId;
    void open(FlaggedCard card) =>
        Navigator.of(context)
            .pushNamed(AppRoutes.review, arguments: card.deckId);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        16,
        4,
        16,
        24,
      ).clearingSystemBar(context),
      children: <Widget>[
        for (final card in queue.cards)
          _Row(
            key: FlaggedPage.rowKey(card.deckId, card.cardId),
            word: wordOf(card),
            card: card,
            onTap: () => open(card),
          ),
        const SizedBox(height: 14),
        FilledButton(
          key: FlaggedPage.reviewAllKey,
          onPressed: () => open(queue.cards.first),
          child: Text(l10n.reviewFlaggedAll(queue.count)),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.word,
    required this.card,
    required this.onTap,
  });

  final String word;
  final FlaggedCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pill = card.isContested
        ? l10n.reviewFlaggedPillContested
        : l10n.reviewFlaggedPillFlagged;
    final reason = flaggedReason(l10n, card);
    return Semantics(
      button: true,
      label: '$word, ${l10n.reviewFlaggedRow(pill, reason)}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      Text(word, style: theme.textTheme.titleLarge),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: Text(
                                pill,
                                style: theme.textTheme.labelMedium!.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            reason,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
