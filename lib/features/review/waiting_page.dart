import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/review/sent_state.dart';
import '../../ui/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../decks/path_parts.dart' show joinParts;
import 'review_languages_page.dart';
import 'review_waiting.dart';

/// "Waiting for review" (docs/plans/deck-browser.md, #471): at the top, "Your
/// reviews", Reviewed, not sent and Reviewed and sent, each with its count
/// and opening its page; then "Languages you review", each a group folded
/// until tapped. Per language the
/// reviewer reviews, the units and decks no native speaker has signed off,
/// with the cards each has left; the offensive words not yet rated and
/// the pairs not yet confirmed; and what the reviewer has reviewed and not
/// sent. Opened from Settings, under Review decks.
///
/// A unit opens its review; the words waiting are counted, never named.
/// Offensive words, and the pairs that name one, are never in a unit's
/// review: each language with any has its own "Offensive words" row,
/// which the reviewer opens on purpose (owner, 2026-10-10).
class WaitingForReviewPage extends StatelessWidget {
  const WaitingForReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSettingsWaiting),
        actions: const <Widget>[ReportButton()],
      ),
      // The reviews and the languages chosen are in the settings.
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languages = reviewLanguagesOf(state);
    if (languages.isEmpty) {
      return EmptyState(
        icon: Icons.translate_outlined,
        title: l10n.reviewWaitingNoLanguages,
        action: FilledButton(
          onPressed: () => showReviewLanguages(context),
          child: Text(l10n.reviewWaitingChoose),
        ),
      );
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
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
          child: Text(
            l10n.reviewWaitingIntro,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const _YourReviews(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
          child: Semantics(
            header: true,
            child: Text(
              l10n.reviewLanguagesHeading,
              style: theme.textTheme.groupLabel.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        for (final language in languages)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Language(
              key: ValueKey<String>(language.code),
              waiting: waitingIn(state, language),
            ),
          ),
      ],
    );
  }
}

/// "Your reviews" (#471): what the reviewer has reviewed, not sent and
/// sent, each a row with its count that opens its page.
class _YourReviews extends StatelessWidget {
  const _YourReviews();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final unsent = state.reviewing.unsent;
    final sentDecks = state.reviewing.reviews.decks.values
        .where((d) => d.sent != null)
        .length;
    final waiting = sentSuggestionsOf(state)
        .where((s) => s.state.outcome == SentOutcome.waiting)
        .length;
    return GroupedList.settings(
      header: l10n.reviewYoursHeading,
      children: <Widget>[
        GroupedTile(
          leading: const Icon(Icons.outbox_outlined),
          title: l10n.reviewUnsentTitle,
          subtitle: unsent.isEmpty
              ? l10n.reviewUnsentNone
              : l10n.reviewUnsentCount(
                  unsent.length,
                  unsent.fold<int>(0, (n, d) => n + d.unsentCards.length),
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openReviewedNotSent(context),
        ),
        GroupedTile(
          leading: const Icon(Icons.mark_email_read_outlined),
          title: l10n.reviewSentTitle,
          subtitle: sentDecks == 0
              ? l10n.reviewSentNone
              : joinParts(l10n, <String>[
                  l10n.reviewSentCount(sentDecks),
                  if (waiting > 0) l10n.reviewSentWaitingCount(waiting),
                ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openReviewedSent(context),
        ),
      ],
    );
  }
}

/// One language's group, folded until its header is tapped: the header
/// names the language and counts the decks and cards to check, with an arrow
/// and, for a screen reader, whether it is expanded (#471). Unfolded, it
/// holds what waits in it, or that nothing does.
class _Language extends StatelessWidget {
  const _Language({super.key, required this.waiting});

  final WaitingLanguage waiting;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final unfolded = settings.isWaitingLanguageOpen(waiting.language.code);
    final l10n = AppLocalizations.of(context)!;
    final language = waiting.language;
    // What waits in the Offensive words review, counted, never named.
    final offensive = <String>[
      if (waiting.unrated.isNotEmpty)
        l10n.reviewWaitingUnrated(waiting.unrated.length),
      if (waiting.unconfirmed.isNotEmpty)
        l10n.reviewWaitingUnconfirmed(waiting.unconfirmed.length),
    ];
    // A unit opens its review; a deck outside the path, which has no unit
    // to review, opens its deck.
    void open(String deckId) => AppNavigator.openReview(context, deckId);

    final decks = waiting.allDecks.toList();
    final fold = GroupedTile(
      expanded: unfolded,
      leading: const Icon(Icons.translate_outlined),
      title: language.name,
      subtitle: decks.isEmpty
          ? l10n.reviewLanguageNothing
          : l10n.reviewLanguageCounts(
              decks.length,
              decks.fold<int>(0, (n, d) => n + d.left),
            ),
      trailing: Icon(unfolded ? Icons.expand_less : Icons.expand_more),
      onTap: () =>
          settings.setWaitingLanguageOpen(waiting.language.code, !unfolded),
    );
    return GroupedList.settings(
      children: <Widget>[
        fold,
        if (unfolded) ..._rows(context, l10n, waiting, offensive, open),
      ],
    );
  }

  List<Widget> _rows(
    BuildContext context,
    AppLocalizations l10n,
    WaitingLanguage waiting,
    List<String> offensive,
    void Function(String) open,
  ) {
    final language = waiting.language;
    return <Widget>[
      if (waiting.isEmpty)
        GroupedTile(
          leading: const Icon(Icons.check_circle_outline),
          title: l10n.reviewWaitingNothing(language.name),
        ),
      for (final unit in waiting.units)
        GroupedTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: l10n.reviewWaitingUnit(unit.number, unit.title),
          subtitle: unit.decks.length == 1
              ? l10n.reviewWaitingCardsLeft(unit.decks.single.left)
              : <String>[
                  for (final d in unit.decks)
                    l10n.reviewWaitingDeckCards(d.deck.deck.name, d.left),
                ].join('\n'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(unit.decks.first.deck.id),
        ),
      for (final d in waiting.decks)
        GroupedTile(
          leading: const Icon(Icons.style_outlined),
          title: d.deck.deck.name,
          subtitle: joinParts(l10n, <String>[
            l10n.reviewWaitingFrom(d.deck.deck.native.name),
            l10n.reviewWaitingCardsLeft(d.left),
          ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openDeck(context, d.deck.id),
        ),
      if (waiting.hasOffensiveReview)
        GroupedTile(
          leading: const Icon(Icons.bar_chart),
          title: l10n.reviewOffensiveTitle,
          subtitle: offensive.isEmpty
              ? l10n.reviewOffensiveNoneWaiting
              : offensive.join('\n'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openOffensiveReview(context, language.code),
        ),
    ];
  }
}
