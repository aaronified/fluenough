import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/review/sent_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../decks/path_parts.dart' show joinParts;
import 'review_sheets.dart' show partName, suggestionPartName;
import 'review_waiting.dart';
import 'suggestion_lines.dart';

/// "Reviewed and sent" (#471, the reviewer mode mockup, section 1d): each
/// suggestion the reviewer sent, by deck, with where it stands, and a tally
/// line at the top. The state is read from the decks on the phone
/// ([sentSuggestionsOf]); where the phone cannot tell, the row says so.
///
/// Shows no rater code, the reviewer's own or anyone's: only counts, such as
/// "1 more acceptance needed". Rejected is drawn neutral, not in the error
/// colour: another reviewer's choice is not the reviewer's mistake.
class ReviewedSentPage extends StatelessWidget {
  const ReviewedSentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSentTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final sent = sentSuggestionsOf(state);
          if (sent.isEmpty) {
            return EmptyState(
              icon: Icons.mark_email_read_outlined,
              title:
                  state.reviewing.reviews.decks.values.any(
                    (d) => d.sent != null,
                  )
                  ? l10n.reviewSentNoSuggestions
                  : l10n.reviewSentNone,
            );
          }
          int count(SentOutcome o) =>
              sent.where((s) => s.state.outcome == o).length;
          final tally = joinParts(l10n, <String>[
            if (count(SentOutcome.accepted) > 0)
              l10n.reviewSentTallyAccepted(count(SentOutcome.accepted)),
            if (count(SentOutcome.rejected) > 0)
              l10n.reviewSentTallyRejected(count(SentOutcome.rejected)),
            if (count(SentOutcome.waiting) > 0)
              l10n.reviewSentTallyWaiting(count(SentOutcome.waiting)),
            if (count(SentOutcome.unknown) > 0)
              l10n.reviewSentTallyUnknown(count(SentOutcome.unknown)),
          ]);
          final byDeck = <String, List<SentSuggestion>>{};
          for (final s in sent) {
            byDeck
                .putIfAbsent(s.review.deckId, () => <SentSuggestion>[])
                .add(s);
          }
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              16,
              4,
              16,
              24,
            ).clearingSystemBar(context),
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 4),
                child: Text(
                  l10n.reviewSentIntro,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 12),
                child: Text(tally, style: theme.textTheme.bodyMedium),
              ),
              for (final group in byDeck.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GroupedList.settings(
                    header: l10n.reviewDeckHeader(
                      group.first.deck?.language.name ??
                          group.first.review.language,
                      group.first.deck?.deck.name ?? group.first.review.deckId,
                    ),
                    children: <Widget>[
                      for (final s in group)
                        SuggestionLines(
                          title: _title(l10n, s),
                          yours: yoursOf(s.suggestion),
                          footer: _StateLine(state: s.state),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// "Meaning · নমস্কার": the part and the card's word.
  static String _title(AppLocalizations l10n, SentSuggestion s) {
    final card = s.card;
    final part = card == null
        ? partName(l10n, s.suggestion.part)
        : suggestionPartName(
            l10n,
            card,
            s.suggestion.part,
            word: s.suggestion.word,
          );
    return l10n.reviewSentSuggestionTitle(part, card?.target ?? s.cardId);
  }
}

/// A sent suggestion's state: an icon, its name and one line.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.state});

  final SentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, name, line, color) = switch (state.outcome) {
      SentOutcome.accepted => (
        Icons.check_circle,
        l10n.reviewSentAccepted,
        l10n.reviewSentAcceptedLine,
        scheme.primary,
      ),
      SentOutcome.rejected => (
        Icons.cancel_outlined,
        l10n.reviewSentRejected,
        l10n.reviewSentRejectedLine,
        scheme.onSurfaceVariant,
      ),
      SentOutcome.waiting => (
        Icons.hourglass_empty,
        l10n.reviewSentWaiting,
        l10n.reviewSentWaitingLine(state.moreNeeded),
        scheme.onSurfaceVariant,
      ),
      SentOutcome.unknown => (
        Icons.help_outline,
        l10n.reviewSentUnknown,
        state.unknown == SentUnknown.notTracked
            ? l10n.reviewSentUnknownOwner
            : l10n.reviewSentUnknownDeck,
        scheme.onSurfaceVariant,
      ),
    };
    return Semantics(
      container: true,
      label: '$name. $line',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: theme.textTheme.titleSmall!.copyWith(color: color),
                ),
                Text(
                  line,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
