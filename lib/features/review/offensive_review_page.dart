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
import 'review_page.dart' show ReviewFoot, ReviewInfo;
import 'review_sheets.dart';
import 'review_words.dart';
import 'send_reviews_sheet.dart';

/// A language's "Offensive words" review (docs/plans/deck-browser.md,
/// "Offensive words are reviewed apart, and only on purpose"; #428).
///
/// The owner, 2026-10-10: "group offensive words separately for review and
/// only review them when the reviewer intentionally wants to check them."
/// Offensive words never show in the ordinary review of a deck or unit;
/// they wait here, one review per language, which the reviewer opens on
/// purpose from Waiting for review.
///
/// Before any word, the screen says why they are in the app: from deeply
/// offensive and unprintable, through mild, to fine between friends;
/// learners should understand abuse rather than use it unknowingly; and a
/// word's strength differs across languages and cultures. Then it asks
/// whether the reviewer is 18 or over, every time it is opened. Only then
/// does it list the words, each rated 1 to 9 with the region the rater
/// speaks in, on the rating sheet the unit review used. Ratings are kept
/// and sent as every review is: in the deck's review file, by mail.
///
/// After the words, the language's words like an offensive one: each
/// names the offensive word it sounds or looks like, so its pair is
/// confirmed or rejected here, never in the ordinary review.
///
/// A deck of offensive words only is signed off here once every word in
/// it is rated.
class OffensiveReviewPage extends StatefulWidget {
  const OffensiveReviewPage({super.key, required this.language});

  /// The language's code.
  final String language;

  @override
  State<OffensiveReviewPage> createState() => _OffensiveReviewPageState();
}

/// Where the screen stands: why the words are here, the age question, then
/// the words.
enum _Step { why, age, words }

class _OffensiveReviewPageState extends State<OffensiveReviewPage> {
  _Step _step = _Step.why;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final language = state.languages
        .where((l) => l.code == widget.language)
        .firstOrNull;
    if (language == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: EmptyState(
          icon: Icons.translate_outlined,
          title: l10n.deckNotFound,
        ),
      );
    }
    final title = Text(
      l10n.reviewOffensivePageTitle(language.name),
      overflow: TextOverflow.ellipsis,
    );
    final report = ReportButton(detail: 'offensive ${language.code}');
    return switch (_step) {
      _Step.why => Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: title,
          actions: <Widget>[report],
        ),
        body: _Why(onContinue: () => setState(() => _step = _Step.age)),
      ),
      _Step.age => Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: title,
          actions: <Widget>[report],
        ),
        body: _Age(
          language: language,
          onConfirmed: () => setState(() => _step = _Step.words),
        ),
      ),
      _Step.words => ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) =>
            _words(context, state, language, title, report),
      ),
    };
  }

  /// The words, by deck, each with its rating; the foot signs off a deck
  /// of offensive words only and sends.
  Widget _words(
    BuildContext context,
    AppState state,
    LanguageInfo language,
    Widget title,
    Widget report,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final reviewing = state.reviewing;
    final decks = offensiveDecksIn(state, language.code);
    final pairs = offensivePairsIn(state, language.code);
    var total = 0;
    var rated = 0;
    for (final d in decks) {
      for (final card in d.words) {
        total++;
        if (reviewing.reviewOf(d.deck, card)?.rating != null) rated++;
      }
    }
    // The decks this review signs off: those of offensive words only. A
    // deck with other words too is signed off in its unit's review.
    final apart = <OffensiveDeck>[
      for (final d in decks)
        if (!hasOrdinaryCards(d.deck)) d,
    ];
    final left = <Card>[
      for (final d in apart)
        for (final card in d.words)
          if (reviewing.reviewOf(d.deck, card)?.rating == null) card,
    ].length;
    final signed = apart.every(
      (d) => reviewing.reviews.of(d.deck.id)?.signedOff != null,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: title,
        actions: <Widget>[report],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : rated / total,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
      body: decks.isEmpty && pairs.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline,
              title: l10n.reviewOffensiveNone(language.name),
            )
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
              children: <Widget>[
                // How far the rating has got, in the body rather than the
                // bar, where at twice the text size it has no room.
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
                  child: Text(
                    l10n.reviewOffensiveProgress(rated, total),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ReviewInfo(
                  text: l10n.reviewOffensiveWordsInfo,
                  icon: Icons.info_outline,
                ),
                for (final d in decks) ..._deck(context, state, d),
                if (pairs.isNotEmpty) ..._pairs(context, state, pairs),
              ],
            ),
      bottomNavigationBar: ReviewFoot(
        left: left,
        signed: signed,
        waiting: reviewing.unsent.length,
        showSignOff: apart.isNotEmpty,
        onSignOff: left == 0 && !signed
            ? () {
                for (final d in apart) {
                  reviewing.signOff(d.deck);
                }
                showAppSnackBar(context, l10n.reviewSignedOffDone);
              }
            : null,
        onSend: () => showSendReviews(context),
      ),
    );
  }

  /// A deck's heading, how many of its words are rated, and its words.
  List<Widget> _deck(BuildContext context, AppState state, OffensiveDeck d) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deck = d.deck;
    final rated = d.words
        .where((c) => state.reviewing.reviewOf(deck, c)?.rating != null)
        .length;
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
              l10n.reviewOffensiveProgress(rated, d.words.length),
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
          for (final card in d.words)
            _WordRow(
              deck: deck,
              card: card,
              rating: state.reviewing.reviewOf(deck, card)?.rating,
              onOpen: () => _open(context, state, deck, card),
              onRate: () => _rate(context, deck, card),
            ),
        ],
      ),
    ];
  }

  /// The words like an offensive one: a heading, how many pairs are
  /// checked, what checking one means, and the words, each naming the
  /// offensive word it is like.
  List<Widget> _pairs(
    BuildContext context,
    AppState state,
    List<OffensivePair> pairs,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final checked = pairs
        .where((p) => state.reviewing.reviewOf(p.deck, p.card)?.alike != null)
        .length;
    return <Widget>[
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.reviewOffensivePairsTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              l10n.reviewOffensivePairsProgress(checked, pairs.length),
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ReviewInfo(
        text: l10n.reviewOffensivePairsInfo,
        icon: Icons.hearing_outlined,
      ),
      const SizedBox(height: 10),
      GroupedList(
        outerRadius: AppRadii.card,
        gap: 4,
        children: <Widget>[
          for (final p in pairs)
            _PairRow(
              pair: p,
              check: state.reviewing.reviewOf(p.deck, p.card)?.alike,
              onOpen: () => _open(context, state, p.deck, p.card),
              onCheck: () => showAlikeSheet(
                context,
                deck: p.deck,
                card: p.card,
                pair: p.pair,
              ),
            ),
        ],
      ),
    ];
  }

  /// Opens [card] whole, then whatever its sheet asked for.
  Future<void> _open(
    BuildContext context,
    AppState state,
    DeckEntry deck,
    Card card,
  ) async {
    final action = await showReviewCard(
      context,
      deck: deck,
      card: card,
      offensive: true,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case ReviewCardAction.suggest:
        await showSuggestSheet(context, deck: deck, card: card);
      case ReviewCardAction.rate:
        await _rate(context, deck, card);
      case ReviewCardAction.checkAlike:
        final pair = rudeAlikesOf(state, card).firstOrNull;
        if (pair != null) {
          await showAlikeSheet(context, deck: deck, card: card, pair: pair);
        }
    }
  }

  /// Rates [card], and suggests a change if asked from there.
  Future<void> _rate(BuildContext context, DeckEntry deck, Card card) async {
    final suggest = await showRateSheet(context, deck: deck, card: card);
    if (suggest == true && context.mounted) {
      await showSuggestSheet(context, deck: deck, card: card);
    }
  }
}

/// Why offensive words are in the app, before any is shown, and Continue.
class _Why extends StatelessWidget {
  const _Why({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge!;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.reviewOffensiveWhyTitle,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.reviewOffensiveWhyRange, style: body),
            const SizedBox(height: 12),
            Text(l10n.reviewOffensiveWhyUnderstand, style: body),
            const SizedBox(height: 12),
            Text(l10n.reviewOffensiveWhyCulture, style: body),
            const SizedBox(height: 12),
            Text(l10n.reviewOffensiveWhyRate, style: body),
            const SizedBox(height: 12),
            Text(l10n.reviewOffensiveWhyApart, style: muted),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, AppSizes.primaryButton),
              ),
              onPressed: onContinue,
              child: Text(l10n.commonContinue, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                l10n.reviewOffensiveNotNow,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Are you 18 or over?", asked each time the words are about to show.
class _Age extends StatelessWidget {
  const _Age({required this.language, required this.onConfirmed});

  final LanguageInfo language;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.eighteen_up_rating_outlined,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.settingsAdultConfirmTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.reviewOffensiveAgeBody(language.name),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, AppSizes.primaryButton),
              ),
              onPressed: onConfirmed,
              child: Text(
                l10n.settingsAdultConfirm,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                l10n.reviewOffensiveNotNow,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An offensive word: the word, its reading and meaning, which open it
/// whole; its rating and region once rated; and Rate or Rated.
class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.deck,
    required this.card,
    required this.rating,
    required this.onOpen,
    required this.onRate,
  });

  final DeckEntry deck;
  final Card card;
  final WordRating? rating;
  final VoidCallback onOpen;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = card.reading;
    final rating = this.rating;
    final meaning = card.native;
    final region = rating?.region;
    final regionName = region == null
        ? null
        : region == WordRating.elsewhere
        ? l10n.reviewRateElsewhere
        : raterRegions(
                AppScope.read(context),
                deck.language.code,
                code: Localizations.localeOf(context).languageCode,
              ).where((r) => r.id == region).firstOrNull?.name ??
              region;
    final extra = <String>[
      if (rating != null) l10n.reviewRated(rating.score),
      if (regionName != null) l10n.reviewOffensiveRegion(regionName),
    ];
    // The label inside the button, so that it keeps its own tap for screen
    // readers, starting with the button's word and naming the word.
    Widget said(String text, String label) =>
        Semantics(label: label, excludeSemantics: true, child: Text(text));
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
                            language: deck.language,
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
                          Text(meaning, style: theme.textTheme.bodyMedium),
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
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onRate,
            icon: const Icon(Icons.bar_chart, size: 18),
            label: rating == null
                ? said(l10n.reviewRateShort, l10n.reviewRateFor(meaning))
                : said(l10n.reviewRatedShort, l10n.reviewRatedFor(meaning)),
          ),
        ],
      ),
    );
  }
}

/// A word like an offensive one: the word, its reading and meaning, which
/// open it whole; the offensive word it is like, named; where the pair
/// stands; and Check or Checked.
class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.pair,
    required this.check,
    required this.onOpen,
    required this.onCheck,
  });

  final OffensivePair pair;
  final AlikeCheck? check;
  final VoidCallback onOpen;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = pair.card;
    final language = pair.deck.language;
    final reading = card.reading;
    final meaning = card.native;
    final check = this.check;
    final small = theme.textTheme.labelSmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // The label inside the button, so that it keeps its own tap for screen
    // readers, starting with the button's word and naming the word.
    Widget said(String text, String label) =>
        Semantics(label: label, excludeSemantics: true, child: Text(text));
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
                          Text(meaning, style: theme.textTheme.bodyMedium),
                          Text.rich(
                            quotingTarget(alikeTitle(l10n, pair.pair), <String>[
                              pair.pair.partner.target,
                            ], language),
                            style: small,
                          ),
                          if (check != null)
                            Text(
                              check.real
                                  ? l10n.reviewAlikeConfirmed
                                  : l10n.reviewAlikeRejected,
                              style: small,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onCheck,
            icon: const Icon(Icons.hearing_outlined, size: 18),
            label: check == null
                ? said(
                    l10n.reviewAlikeCheckShort,
                    l10n.reviewAlikeCheckFor(meaning),
                  )
                : said(
                    l10n.reviewAlikeCheckedShort,
                    l10n.reviewAlikeCheckedFor(meaning),
                  ),
          ),
        ],
      ),
    );
  }
}
