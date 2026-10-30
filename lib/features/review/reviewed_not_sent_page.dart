import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/models/card.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import 'review_sheets.dart' show partName, suggestionPartName;
import 'send_reviews_sheet.dart';
import 'suggestion_lines.dart';

/// "Reviewed, not sent" (#471, the reviewer mode mockup, section 1c): the
/// reviews kept on this phone until they are sent, by deck. A card with
/// suggestions lists each under it as Now, Yours and Why; the cards marked
/// Looks right are one folded row, "N cards look right". Send review is the
/// button in the bar at the bottom. Opened from Waiting for review.
class ReviewedNotSentPage extends StatelessWidget {
  const ReviewedNotSentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final decks = state.reviewing.unsent;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.reviewUnsentTitle),
            actions: const <Widget>[ReportButton()],
          ),
          body: decks.isEmpty
              ? EmptyState(
                  icon: Icons.outbox_outlined,
                  title: l10n.reviewUnsentNone,
                )
              : ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    16,
                    4,
                    16,
                    24,
                  ).clearingSystemBar(context),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
                      child: Text(
                        l10n.reviewUnsentIntro,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final deck in decks)
                      _DeckGroup(
                        key: ValueKey<String>(deck.deckId),
                        deck: deck,
                      ),
                  ],
                ),
          bottomNavigationBar: decks.isEmpty
              ? null
              : BottomActions(
                  child: FilledButton.icon(
                    onPressed: () => showSendReviews(context),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.reviewSend),
                  ),
                ),
        );
      },
    );
  }
}

/// One deck's unsent reviews.
class _DeckGroup extends StatefulWidget {
  const _DeckGroup({super.key, required this.deck});

  final DeckReview deck;

  @override
  State<_DeckGroup> createState() => _DeckGroupState();
}

class _DeckGroupState extends State<_DeckGroup> {
  bool _rightOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final review = widget.deck;
    final entry = state.reviewDeckById(review.deckId);
    final cards = <({String id, Card? card, CardReview review})>[
      for (final MapEntry(:key, :value) in review.unsentCards.entries)
        (
          id: key,
          card: entry?.cards.where((c) => c.id == key).firstOrNull,
          review: value,
        ),
    ];
    final suggested = [
      for (final c in cards)
        if (c.review.suggestions.isNotEmpty) c,
    ];
    final right = [
      for (final c in cards)
        if (c.review.right && c.review.suggestions.isEmpty) c,
    ];
    final others = cards.length - suggested.length - right.length;
    final header = l10n.reviewDeckHeader(
      entry?.language.name ?? review.language,
      entry?.deck.name ?? review.deckId,
    );
    void open() => AppNavigator.openReview(context, review.deckId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GroupedList.settings(
        header: header,
        children: <Widget>[
          for (final c in suggested) ...<Widget>[
            GroupedTile(
              leading: const Icon(Icons.edit_note),
              title: c.card?.target ?? c.id,
              subtitle: c.card == null ? null : '${c.card!.native} · ${c.id}',
              trailing: entry == null ? null : const Icon(Icons.chevron_right),
              onTap: entry == null ? null : open,
            ),
            for (final s in c.review.suggestions)
              SuggestionLines(
                title: c.card == null
                    ? partName(l10n, s.part)
                    : suggestionPartName(l10n, c.card!, s.part, word: s.word),
                now: s.now.isEmpty ? l10n.reviewSuggestNothing : s.now,
                yours: yoursOf(l10n, s),
                why: s.why,
              ),
          ],
          if (right.isNotEmpty)
            GroupedTile(
              expanded: _rightOpen,
              leading: const Icon(Icons.check_circle_outline),
              title: l10n.reviewUnsentLooksRight(right.length),
              trailing: Icon(
                _rightOpen ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _rightOpen = !_rightOpen),
            ),
          if (_rightOpen)
            for (final c in right)
              GroupedTile(
                leading: const Icon(Icons.check_circle_outline),
                title: c.card?.target ?? c.id,
                subtitle: c.card == null ? null : '${c.card!.native} · ${c.id}',
              ),
          if (others > 0)
            GroupedTile(
              leading: const Icon(Icons.bar_chart),
              title: l10n.reviewUnsentOther(others),
            ),
          if (review.unsentSignOff)
            GroupedTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: l10n.reviewUnsentSignedOff,
            ),
        ],
      ),
    );
  }
}
