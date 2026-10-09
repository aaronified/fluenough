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
import '../decks/path_model.dart';
import '../decks/word_sheet.dart' show adultContentOn;
import 'review_sheets.dart';
import 'review_words.dart';
import 'send_reviews_sheet.dart';

/// Reviewing a unit (the owner's design, "Review a unit"): the rater code
/// and how far the review has got at the top; each card with "Suggest a
/// change" and Right, or Check while not yet marked, or Suggested; tapping
/// a card opens it whole. Sign off once every card is checked; Send review
/// opens the send sheet, which sends every deck waiting, in one mail.
///
/// Rude words show only with adult content on (#96); until then the screen
/// says how many are hidden, and they count as left to check.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.deckId, this.plan, this.adult});

  /// A deck in the unit, by id: the unit is the one holding it.
  final String deckId;

  /// The course's plan, for tests and the gallery, as [UnitPage] takes it.
  final CoursePlan? plan;

  /// Whether adult content is on, in place of the setting: for tests and
  /// the gallery.
  final bool? adult;

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
    final adultOn = adult ?? adultContentOn(state);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(
        context,
        state,
        unitTitle(state, unit.decks),
        unit.decks,
        adultOn,
      ),
    );
  }

  Widget _build(
    BuildContext context,
    AppState state,
    String title,
    List<DeckEntry> decks,
    bool adult,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewing = state.reviewing;
    final code = reviewing.code;
    var total = 0;
    var done = 0;
    var hidden = 0;
    for (final deck in decks) {
      for (final card in deck.cards) {
        total++;
        if (isRudeIn(deck, card) && !adult) {
          hidden++;
        } else if (_checked(state, deck, card, adult)) {
          done++;
        }
      }
    }
    final left = total - done;
    final signed = decks.every(
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
          _Info(text: l10n.reviewPageInfo, icon: Icons.info_outline),
          if (hidden > 0) ...<Widget>[
            const SizedBox(height: 8),
            _Info(
              text: l10n.reviewRudeHidden(hidden),
              icon: Icons.visibility_off_outlined,
            ),
          ],
          for (final deck in decks)
            ..._deck(context, state, deck, adult, single: decks.length == 1),
        ],
      ),
      bottomNavigationBar: _Foot(
        left: left,
        signed: signed,
        waiting: waiting,
        onSignOff: left == 0 && !signed
            ? () {
                for (final deck in decks) {
                  reviewing.signOff(deck);
                }
                showAppSnackBar(context, l10n.reviewSignedOffDone);
              }
            : null,
        onSend: () => showSendReviews(context),
      ),
    );
  }

  /// Whether [card] needs nothing more: marked right or suggested, rated if
  /// rude, and its pair checked if it is like a rude word and the reviewer
  /// can see it.
  static bool _checked(AppState state, DeckEntry deck, Card card, bool adult) {
    final review = state.reviewing.reviewOf(deck, card);
    if (review == null) return false;
    // A rude word is rated, not marked right.
    if (isRudeIn(deck, card) ? review.rating == null : !review.marked) {
      return false;
    }
    if (adult && rudeAlikesOf(state, card).isNotEmpty && review.alike == null) {
      return false;
    }
    return true;
  }

  /// A deck's heading, its tally, and its cards.
  List<Widget> _deck(
    BuildContext context,
    AppState state,
    DeckEntry deck,
    bool adult, {
    required bool single,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cards = <Card>[
      for (final card in deck.cards)
        if (adult || !isRudeIn(deck, card)) card,
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
              onOpen: () => _open(context, state, deck, card, adult),
              onSuggest: () => _suggest(context, state, deck, card),
              onRate: isRudeIn(deck, card)
                  ? () => _rate(context, deck, card)
                  : null,
            ),
        ],
      ),
    ];
  }

  /// Opens [card], then whatever its sheet asked for.
  Future<void> _open(
    BuildContext context,
    AppState state,
    DeckEntry deck,
    Card card,
    bool adult,
  ) async {
    final action = await showReviewCard(
      context,
      deck: deck,
      card: card,
      adult: adult,
    );
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
        final pair = rudeAlikesOf(state, card).firstOrNull;
        if (pair != null) {
          await showAlikeSheet(context, deck: deck, card: card, pair: pair);
        }
    }
  }

  /// Rates the rude word [card], and suggests a change if asked from there.
  Future<void> _rate(BuildContext context, DeckEntry deck, Card card) async {
    final suggest = await showRateSheet(context, deck: deck, card: card);
    if (suggest == true && context.mounted) {
      await showSuggestSheet(context, deck: deck, card: card);
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
class _Info extends StatelessWidget {
  const _Info({required this.text, required this.icon});

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
    this.onRate,
  });

  final DeckEntry deck;
  final Card card;
  final CardReview? review;
  final VoidCallback onOpen;
  final VoidCallback onSuggest;

  /// For a rude word, which is rated rather than marked right.
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.read(context);
    final onRate = this.onRate;
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
      _ when onRate != null => FilledButton.tonalIcon(
        onPressed: onRate,
        icon: const Icon(Icons.bar_chart, size: 18),
        label: review?.rating == null
            ? said(l10n.reviewRateShort, l10n.reviewRateFor(meaning))
            : said(l10n.reviewRatedShort, l10n.reviewRatedFor(meaning)),
      ),
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
    final extra = <String>[
      if (review?.rating case final r?) l10n.reviewRated(r.score),
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
class _Foot extends StatelessWidget {
  const _Foot({
    required this.left,
    required this.signed,
    required this.waiting,
    required this.onSignOff,
    required this.onSend,
  });

  final int left;
  final bool signed;
  final int waiting;
  final VoidCallback? onSignOff;
  final VoidCallback onSend;

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
              if (stacked) ...<Widget>[signOff, send] else
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
