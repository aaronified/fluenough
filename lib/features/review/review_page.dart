import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/checked_by_line.dart';
import '../decks/path_model.dart';
import 'proposal_card.dart';
import 'review_sheets.dart';
import 'review_waiting.dart';
import 'review_words.dart';
import 'send_reviews_sheet.dart';

/// Reviewing a unit (the owner's design, "Review a unit"): the rater code
/// and how far the review has got at the top; each card with "Suggest a
/// change" and Right, or Check while not yet marked, or Suggested; tapping
/// a card opens it whole. Sign off once every card is checked; Send review
/// opens the send sheet, which sends every deck waiting, in one mail.
///
/// Offensive words never show here, adult content on or off: they are
/// reviewed apart, in their language's Offensive words review, and only on
/// purpose (docs/plans/deck-browser.md, owner, 2026-10-10). The screen says
/// how many it leaves out, and they do not count as left to check. A deck
/// of offensive words only is signed off there, not here. Nor is a rude
/// word named here through a word like it: such a word shows the warning
/// a learner sees, and its pair is checked in the Offensive words review.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.deckId, this.plan});

  /// A deck in the unit, by id: the unit is the one holding it.
  final String deckId;

  /// The course's plan, for tests and the gallery, as [UnitPage] takes it.
  final CoursePlan? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final unit = unitOfDeck(state, deckId, plan: plan);
    if (unit == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) =>
          _build(context, state, unitTitle(state, unit.decks), unit.decks),
    );
  }

  Widget _build(
    BuildContext context,
    AppState state,
    String title,
    List<DeckEntry> decks,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewing = state.reviewing;
    final code = reviewing.code;
    var total = 0;
    var done = 0;
    var apart = 0;
    for (final deck in decks) {
      for (final card in deck.cards) {
        if (isRudeIn(deck, card)) {
          apart++;
          continue;
        }
        total++;
        if (cardChecked(state, deck, card)) done++;
      }
    }
    final left = total - done;
    // The decks this review signs off: a deck of offensive words only is
    // signed off in the Offensive words review.
    final ordinary = <DeckEntry>[
      for (final deck in decks)
        if (hasOrdinaryCards(deck)) deck,
    ];
    final signed = ordinary.every(
      (d) => reviewing.reviews.of(d.id)?.signedOff != null,
    );
    final waiting = reviewing.unsent.length;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.reviewPageTitle(title),
              style: theme.textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
            if (code != null)
              Text(
                '$code',
                style: theme.textTheme.bodySmall!.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          Semantics(
            label: l10n.reviewPageProgressLabel(done, total),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
              child: Text(
                l10n.reviewPageProgress(done, total),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          ReportButton(detail: decks.map((e) => e.id).join(', ')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
        children: <Widget>[
          ReviewInfo(text: l10n.reviewPageInfo, icon: Icons.info_outline),
          if (apart > 0) ...<Widget>[
            const SizedBox(height: 8),
            ReviewInfo(
              text: l10n.reviewOffensiveApart(apart),
              icon: Icons.visibility_off_outlined,
            ),
          ],
          for (final deck in decks)
            ..._deck(context, state, deck, single: decks.length == 1),
        ],
      ),
      bottomNavigationBar: ReviewFoot(
        left: left,
        signed: signed,
        waiting: waiting,
        showSignOff: ordinary.isNotEmpty,
        onSignOff: left == 0 && !signed
            ? () {
                for (final deck in ordinary) {
                  reviewing.signOff(deck);
                }
                showAppSnackBar(context, l10n.reviewSignedOffDone);
              }
            : null,
        onSend: () => showSendReviews(context),
      ),
    );
  }

  /// A deck's heading, its tally, and its cards.
  List<Widget> _deck(
    BuildContext context,
    AppState state,
    DeckEntry deck, {
    required bool single,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cards = <Card>[
      for (final card in deck.cards)
        if (!isRudeIn(deck, card)) card,
    ];
    if (cards.isEmpty) return const <Widget>[];
    final reviews = state.reviewing.reviews.of(deck.id);
    final right = reviews?.cards.values.where((c) => c.right).length ?? 0;
    final suggested =
        reviews?.cards.values.where((c) => c.suggestion != null).length ?? 0;
    return <Widget>[
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(deck.deck.name, style: theme.textTheme.titleMedium),
            ),
            Text(
              l10n.reviewSectionCards(cards.length),
              style: theme.textTheme.labelMedium,
            ),
            Text(
              l10n.reviewSectionTally(right, suggested),
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      GroupedList(
        outerRadius: AppRadii.card,
        gap: 4,
        children: <Widget>[
          for (final card in cards)
            _ReviewRow(
              deck: deck,
              card: card,
              review: state.reviewing.reviewOf(deck, card),
              onOpen: () => _open(context, deck, card),
              onSuggest: () => _suggest(context, state, deck, card),
            ),
        ],
      ),
    ];
  }

  /// Opens [card], then whatever its sheet asked for.
  Future<void> _open(BuildContext context, DeckEntry deck, Card card) async {
    final action = await showReviewCard(context, deck: deck, card: card);
    if (!context.mounted || action == null) return;
    switch (action) {
      case ReviewCardAction.suggest:
        await showSuggestSheet(context, deck: deck, card: card);
      case ReviewCardAction.rate:
        final suggest = await showRateSheet(context, deck: deck, card: card);
        if (suggest == true && context.mounted) {
          await showSuggestSheet(context, deck: deck, card: card);
        }
      case ReviewCardAction.checkAlike:
        // Offered only in the Offensive words review, which names the
        // rude word: never from here.
        break;
    }
  }

  Future<void> _suggest(
    BuildContext context,
    AppState state,
    DeckEntry deck,
    Card card,
  ) => showSuggestSheet(context, deck: deck, card: card);
}

/// A tinted line with an icon: what reviewing asks, or what is hidden.
class ReviewInfo extends StatelessWidget {
  const ReviewInfo({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card in review: the word, its reading and meaning, which open it;
/// the pencil, "Suggest a change"; and Right, Check or Suggested.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.deck,
    required this.card,
    required this.review,
    required this.onOpen,
    required this.onSuggest,
  });

  final DeckEntry deck;
  final Card card;
  final CardReview? review;
  final VoidCallback onOpen;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.read(context);
    final reading = card.reading;
    final review = this.review;
    final LanguageInfo language = deck.language;
    // The label inside each button, so that the button keeps its own tap
    // for screen readers. It starts with the button's word, for voice
    // control, and names the card, as a list of rows reads alike.
    Widget said(String text, String label) =>
        Semantics(label: label, excludeSemantics: true, child: Text(text));
    final meaning = card.native;
    final Widget mark = switch (review) {
      CardReview(suggestion: _?) => FilledButton.tonalIcon(
        onPressed: onSuggest,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: said(l10n.reviewSuggested, l10n.reviewSuggestedFor(meaning)),
      ),
      CardReview(right: true) => FilledButton.icon(
        onPressed: () => state.reviewing.markRight(deck, card, right: false),
        icon: const Icon(Icons.check, size: 18),
        label: said(l10n.reviewRight, l10n.reviewRightFor(meaning)),
      ),
      _ => FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
        ),
        onPressed: () => state.reviewing.markRight(deck, card),
        icon: const Icon(Icons.check, size: 18),
        label: said(l10n.reviewCheck, l10n.reviewCheckFor(meaning)),
      ),
    };
    final proposals = waitingProposals(state.decks, deck, card).length;
    final checked = checkedByOf(state.decks, card, deck: deck).length;
    final extra = <String>[
      if (checked > 0) l10n.cardCheckedBy(checked),
      if (proposals > 0) l10n.reviewProposalsWaiting(proposals),
      if (review?.alike case final a?)
        a.real ? l10n.reviewAlikeConfirmed : l10n.reviewAlikeRejected,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              hint: l10n.unitOpenWord,
              child: MergeSemantics(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        6,
                        8,
                        6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          TargetText(
                            card.target,
                            language: language,
                            fontSize: 20,
                            textAlign: TextAlign.start,
                          ),
                          if (reading != null)
                            Text(
                              reading,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          Text(card.native, style: theme.textTheme.bodyMedium),
                          for (final line in extra)
                            Text(
                              line,
                              style: theme.textTheme.labelSmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: l10n.reviewSuggestOn(card.native),
            onPressed: onSuggest,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          const SizedBox(width: 8),
          mark,
        ],
      ),
    );
  }
}

/// The foot: how many decks wait to send, then Sign off and Send review.
/// Without [showSignOff], Send review alone: nothing on the screen is
/// signed off from it.
class ReviewFoot extends StatelessWidget {
  const ReviewFoot({
    super.key,
    required this.left,
    required this.signed,
    required this.waiting,
    required this.onSignOff,
    required this.onSend,
    this.showSignOff = true,
  });

  final int left;
  final bool signed;
  final int waiting;
  final VoidCallback? onSignOff;
  final VoidCallback onSend;
  final bool showSignOff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signOff = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, AppSizes.primaryButton),
      ),
      onPressed: onSignOff,
      child: Text(
        signed
            ? l10n.reviewSignedOff
            : left == 0
            ? l10n.reviewSignOffReady
            : l10n.reviewSignOff(left),
        textAlign: TextAlign.center,
      ),
    );
    final send = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppSizes.primaryButton),
      ),
      onPressed: onSend,
      icon: const Icon(Icons.send_outlined, size: 20),
      label: Text(l10n.reviewSend, textAlign: TextAlign.center),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              if (waiting > 0)
                Text(
                  l10n.reviewDecksWaiting(waiting),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (!showSignOff)
                send
              else if (stacked) ...<Widget>[signOff, send] else
                Row(
                  spacing: 12,
                  children: <Widget>[
                    Expanded(child: signOff),
                    Expanded(child: send),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
