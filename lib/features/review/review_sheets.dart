import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/proposal.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_notes.dart';
import '../decks/card_top_line.dart';
import '../decks/checked_by_line.dart';
import '../decks/path_parts.dart' show joinParts;
import 'alike_warning.dart';
import 'proposal_card.dart';
import 'review_words.dart';

/// What a reviewer can do from a card's sheet: the sheet closes, then the
/// review screen opens the next one.
enum ReviewCardAction { suggest, rate, checkAlike }

/// Opens [card] of [deck] as a lesson shows it, with "Looks right" and
/// "Suggest a change" (the approved card in reviewer mode); a rude word
/// with its level, type, friendliness and region note, and "Rate this
/// word"; a word like a rude one with the pair to check. [adult] says
/// whether adult content is on, which names a rude word.
Future<ReviewCardAction?> showReviewCard(
  BuildContext context, {
  required DeckEntry deck,
  required Card card,
  required bool adult,
}) => showModalBottomSheet<ReviewCardAction>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ReviewCardSheet(deck: deck, card: card, adult: adult),
);

/// The text of [part] of [card], as "Suggest a change" shows it under Now,
/// or null when the card has none.
String? partText(Card card, CardPart part) => switch (part) {
  CardPart.word => card.target,
  CardPart.reading => card.reading,
  CardPart.ipa => card.ipa,
  CardPart.meaning => card.native,
  CardPart.notes => notesText(card),
  CardPart.example => switch (card.examples.firstOrNull) {
    null => null,
    final e => '${e.target}\n${e.reading ?? ''}\n${e.native}'.replaceAll(
      '\n\n',
      '\n',
    ),
  },
  CardPart.picture => card.picture,
};

/// [part]'s name on its chip.
String partName(AppLocalizations l10n, CardPart part) => switch (part) {
  CardPart.word => l10n.reviewPartWord,
  CardPart.reading => l10n.reviewPartReading,
  CardPart.ipa => l10n.reviewPartIpa,
  CardPart.meaning => l10n.reviewPartMeaning,
  CardPart.notes => l10n.reviewPartNotes,
  CardPart.example => l10n.reviewPartExample,
  CardPart.picture => l10n.reviewPartPicture,
};

/// Where [review] stands, as a card's top line says it.
String reviewStateName(AppLocalizations l10n, CardReview? review) =>
    switch (review) {
      CardReview(suggestion: _?) => l10n.reviewStateSuggested,
      CardReview(right: true) => l10n.reviewStateRight,
      _ => l10n.reviewStateNot,
    };

/// A card in review, in a sheet.
class ReviewCardSheet extends StatelessWidget {
  const ReviewCardSheet({
    super.key,
    required this.deck,
    required this.card,
    required this.adult,
  });

  final DeckEntry deck;
  final Card card;
  final bool adult;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final language = deck.language;
    final review = state.reviewing.reviewOf(deck, card);
    final rude = isRudeIn(deck, card);
    final alikes = rudeAlikesOf(state, card);
    final status = reviewStateName(l10n, review);
    final pos = card.pos;
    final rating = review?.rating;
    final alike = review?.alike;
    final proposals = waitingProposals(state.decks, deck, card);
    final checked = checkedByOf(state.decks, card, deck: deck).length;
    void close(ReviewCardAction? action) => Navigator.of(context).pop(action);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CardTopLine(
              text: pos == null
                  ? l10n.reviewCardLine(card.id, status)
                  : l10n.reviewCardLinePos(card.id, pos, status),
              card: card,
              language: language,
              report: '${card.id} in ${deck.id}',
            ),
            CardFace(card: card, language: language),
            if (checked > 0) ...<Widget>[
              const SizedBox(height: 8),
              CheckedByLine(count: checked),
            ],
            for (final proposal in proposals) ...<Widget>[
              const SizedBox(height: 16),
              ProposalCard(deck: deck, card: card, proposal: proposal),
            ],
            if (rude) ...<Widget>[
              const SizedBox(height: 16),
              _RudeFacts(
                rating: rating,
                region: regionNote(
                  state,
                  language.code,
                  card,
                  code: Localizations.localeOf(context).languageCode,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.reviewRudeOnly,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final pair in alikes) ...<Widget>[
              const SizedBox(height: 16),
              if (adult)
                _AlikeFound(pair: pair, language: language, check: alike)
              else
                AlikeWarning(kind: pair.kind, care: pair.care),
            ],
            const SizedBox(height: 20),
            if (rude)
              FilledButton.icon(
                style: _tall,
                onPressed: () => close(ReviewCardAction.rate),
                icon: const Icon(Icons.bar_chart),
                label: Text(l10n.reviewRate),
              )
            else
              FilledButton.icon(
                style: _tall,
                onPressed: () {
                  state.reviewing.markRight(deck, card);
                  close(null);
                },
                icon: const Icon(Icons.check),
                label: Text(l10n.reviewLooksRight),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: () => close(ReviewCardAction.suggest),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.reviewSuggest),
            ),
            if (adult && alikes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                ),
                onPressed: () => close(ReviewCardAction.checkAlike),
                icon: const Icon(Icons.hearing_outlined),
                label: Text(l10n.reviewAlikeCheck),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _tall = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(AppSizes.primaryButton),
  );
}

/// A card as a lesson shows it: its picture, the word, its reading and IPA,
/// its meaning, its note and its first example.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, required this.language});

  final Card card;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = card.reading;
    final ipa = card.ipa;
    final notes = shownNotes(card);
    final example = card.examples.firstOrNull;
    final muted = theme.textTheme.bodyLarge!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: <Widget>[
        if (card.picture != null) Center(child: CardPicture(card, size: 72)),
        TargetText(card.target, language: language, fontSize: 40),
        if (reading != null)
          Text(
            reading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (ipa != null)
          Text(
            l10n.wordSheetIpa(ipa),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          card.native,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        if (notes.isNotEmpty) const SizedBox(height: 4),
        for (final note in notes)
          Text(note, textAlign: TextAlign.center, style: muted),
        if (example != null) ...<Widget>[
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: l10n.drillExample,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Column(
                children: <Widget>[
                  TargetText(
                    example.target,
                    language: language,
                    fontSize: 17,
                    color: scheme.onSurface,
                  ),
                  if (example.reading case final r?)
                    Text(
                      r,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    example.native,
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A rude word's level, type, whether it can be friendly among peers and
/// its region note (docs/plans/offensive-words.md), and this rater's
/// rating once made.
///
/// The region note is the card's own, a note naming regions of its
/// language's path (ADR-0036). The deck format has no fields for the
/// other three yet: they come with the offensive words, set from several
/// native raters' medians. Until then each, and a card with no region
/// note, reads "Not set yet".
class _RudeFacts extends StatelessWidget {
  const _RudeFacts({required this.rating, this.region});

  final WordRating? rating;

  /// The card's region note, its regions named ([regionNote]), or null.
  final ({String text, List<String> regions})? region;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rating = this.rating;
    final rows = <(String, String)>[
      (l10n.reviewRudeLevel, l10n.reviewRudeNotSet),
      (l10n.reviewRudeType, l10n.reviewRudeNotSet),
      (l10n.reviewRudeFriends, l10n.reviewRudeNotSet),
      (
        l10n.reviewRudeRegion,
        switch (region) {
          null => l10n.reviewRudeNotSet,
          final r => l10n.reviewRudeRegionNote(
            joinParts(l10n, r.regions),
            r.text,
          ),
        },
      ),
    ];
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
          for (final (key, value) in rows)
            MergeSemantics(
              child: Wrap(
                spacing: 12,
                children: <Widget>[
                  Text(
                    key,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(value, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          if (rating != null)
            Text(
              l10n.reviewRated(rating.score),
              style: theme.textTheme.titleSmall,
            ),
        ],
      ),
    );
  }
}

/// For a reviewer with adult content on: the rude word the check found,
/// and where the reviewer's answer on the pair stands.
class _AlikeFound extends StatelessWidget {
  const _AlikeFound({
    required this.pair,
    required this.language,
    required this.check,
  });

  final RudeAlike pair;
  final LanguageInfo language;
  final AlikeCheck? check;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final check = this.check;
    final title = alikeTitle(l10n, pair);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onTertiaryContainer,
    );
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: <Widget>[
                  Text.rich(
                    quotingTarget(title, <String>[
                      pair.partner.target,
                    ], language),
                    style: style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    pair.kind == AlikeKind.sound
                        ? l10n.reviewAlikeSoundsAbout
                        : l10n.reviewAlikeLooksAbout,
                    style: style,
                  ),
                  if (check != null)
                    Text(
                      check.real
                          ? l10n.reviewAlikeConfirmed
                          : l10n.reviewAlikeRejected,
                      style: style.copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (check != null && check.care.isNotEmpty)
                    Text(check.care, style: style),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sounds like వెధవ (vedhava)": the rude word, with its reading where it
/// has one.
String alikeTitle(AppLocalizations l10n, RudeAlike pair) {
  final reading = pair.partner.reading;
  final word = pair.partner.target;
  return switch ((pair.kind, reading)) {
    (AlikeKind.sound, null) => l10n.reviewAlikeSoundsNoReading(word),
    (AlikeKind.sound, final r?) => l10n.reviewAlikeSounds(word, r),
    (AlikeKind.look, null) => l10n.reviewAlikeLooksNoReading(word),
    (AlikeKind.look, final r?) => l10n.reviewAlikeLooks(word, r),
  };
}

/// The bottom sheet's frame for the three forms: a title, what the card
/// is, the form, and Cancel and Save.
class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.title,
    required this.about,
    required this.children,
    required this.onSave,
    this.extra,
  });

  final String title;
  final Widget about;
  final List<Widget> children;
  final VoidCallback? onSave;

  /// A button before Cancel, such as "Suggest a change" on the rating.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 4),
              about,
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ?extra,
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(onPressed: onSave, child: Text(l10n.reviewSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "వెధవ · vedhava · idiot · te-0900": the card under a form's title, the
/// word read out in its language.
Widget _about(BuildContext context, Card card, LanguageInfo language) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final reading = card.reading;
  final text = reading == null
      ? l10n.reviewCardAboutNoReading(card.target, card.native, card.id)
      : l10n.reviewCardAbout(card.target, reading, card.native, card.id);
  return Text.rich(
    quotingTarget(text, <String>[card.target], language),
    style: theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

/// Opens "Suggest a change" on [card] of [deck], or, [from] another
/// reviewer's proposal, to edit it into one of this reviewer's own.
Future<void> showSuggestSheet(
  BuildContext context, {
  required DeckEntry deck,
  required Card card,
  Proposal? from,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SuggestSheet(deck: deck, card: card, from: from),
);

/// "Suggest a change": which part, what it says now, the suggestion and
/// why. Kept on the phone until the review is sent.
///
/// Opened [from] another reviewer's proposal (ADR-0038), it starts with
/// the proposal's part and text; saved, it is this reviewer's own
/// suggestion, which becomes a new proposal, and the answer to [from] is
/// "edit". The proposal edited keeps waiting.
///
/// A card keeps one suggestion: where saving would replace one already
/// made on another part, or one made before an Edit, the sheet says so and
/// shows it.
class SuggestSheet extends StatefulWidget {
  const SuggestSheet({
    super.key,
    required this.deck,
    required this.card,
    this.from,
  });

  final DeckEntry deck;
  final Card card;
  final Proposal? from;

  @override
  State<SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends State<SuggestSheet> {
  late CardPart _part;
  final TextEditingController _text = TextEditingController();
  final TextEditingController _why = TextEditingController();
  bool _seeded = false;

  /// The suggestion already kept on the card, which saving replaces.
  Suggestion? _old;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final old = AppScope.read(context).reviewing
        .reviewOf(widget.deck, widget.card)
        ?.suggestion;
    _old = old;
    final from = widget.from;
    if (from != null) {
      _part = partOf(from.field);
      _text.text = from.text;
      _why.text = old?.part == _part ? old!.why : '';
      return;
    }
    _part = old?.part ?? CardPart.word;
    _text.text = old?.text ?? partText(widget.card, _part) ?? '';
    _why.text = old?.why ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    _why.dispose();
    super.dispose();
  }

  void _choose(CardPart part) {
    final before = partText(widget.card, _part) ?? '';
    setState(() {
      // A suggestion not yet changed follows the part chosen.
      if (_text.text == before) _text.text = partText(widget.card, part) ?? '';
      _part = part;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.deck.language;
    final now = partText(widget.card, _part);
    final changed =
        _text.text.trim().isNotEmpty && _text.text.trim() != (now ?? '');
    final old = _old;
    final replaces = old != null && (widget.from != null || old.part != _part);
    return _FormSheet(
      title: l10n.reviewSuggest,
      about: _about(context, widget.card, language),
      onSave: changed
          ? () {
              final reviewing = AppScope.read(context).reviewing;
              reviewing.suggest(
                widget.deck,
                widget.card,
                Suggestion(
                  part: _part,
                  now: now ?? '',
                  text: _text.text.trim(),
                  why: _why.text.trim(),
                ),
              );
              if (widget.from case final from?) {
                reviewing.answer(
                  widget.deck,
                  widget.card,
                  from,
                  ProposalVerdict.edit,
                );
              }
              Navigator.of(context).pop();
            }
          : null,
      children: <Widget>[
        if (replaces) ...<Widget>[
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Text.rich(
              quotingTarget(
                l10n.reviewSuggestReplaces(partName(l10n, old.part), old.text),
                <String>[if (old.part == CardPart.word) old.text],
                language,
              ),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(l10n.reviewSuggestWhich, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            for (final part in CardPart.values)
              ChoiceChip(
                label: Text(partName(l10n, part)),
                selected: part == _part,
                onSelected: (_) => _choose(part),
              ),
          ],
        ),
        const SizedBox(height: 16),
        MergeSemantics(
          child: Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.reviewSuggestNow,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (now == null)
                  Text(l10n.reviewSuggestNothing)
                else
                  Text.rich(
                    quotingTarget(now, <String>[
                      if (_part == CardPart.word) now,
                    ], language),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.reviewSuggestYours,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _why,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.reviewSuggestWhy,
            border: const OutlineInputBorder(),
            helperText: l10n.reviewSuggestKept,
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Opens "Rate this word" on the rude word [card] of [deck]. True if the
/// rater chose "Suggest a change" from it.
Future<bool?> showRateSheet(
  BuildContext context, {
  required DeckEntry deck,
  required Card card,
}) => showModalBottomSheet<bool>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RateSheet(deck: deck, card: card),
);

/// "Rate this word": how offensive it is to native speakers in general, 1
/// to 9; where the rater speaks the language, from its regions and then
/// Elsewhere; and whether it can be friendly among friends.
class RateSheet extends StatefulWidget {
  const RateSheet({super.key, required this.deck, required this.card});

  final DeckEntry deck;
  final Card card;

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  int? _score;
  String? _region;
  Friendly? _friendly;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final old = AppScope.read(context).reviewing
        .reviewOf(widget.deck, widget.card)
        ?.rating;
    _score = old?.score;
    _region = old?.region;
    _friendly = old?.friendly;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.deck.language;
    final regions = raterRegions(
      AppScope.read(context),
      language.code,
      code: Localizations.localeOf(context).languageCode,
    );
    final score = _score;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return _FormSheet(
      title: l10n.reviewRate,
      about: _about(context, widget.card, language),
      extra: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(l10n.reviewSuggest),
      ),
      onSave: score == null
          ? null
          : () {
              AppScope.read(context).reviewing.rate(
                widget.deck,
                widget.card,
                WordRating(score: score, region: _region, friendly: _friendly),
              );
              Navigator.of(context).pop();
            },
      children: <Widget>[
        Text(l10n.reviewRateQuestion, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _Scale(score: score, onChosen: (n) => setState(() => _score = n)),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(child: Text(l10n.reviewRateLow, style: muted)),
            Expanded(
              child: Text(
                l10n.reviewRateHigh,
                textAlign: TextAlign.end,
                style: muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.reviewRateNote, style: muted),
        if (regions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            l10n.reviewRateWhere(language.name),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final (id, name) in <(String, String)>[
            for (final r in regions) (r.id, r.name),
            (WordRating.elsewhere, l10n.reviewRateElsewhere),
          ])
            _Choice(
              label: name,
              selected: _region == id,
              onTap: () => setState(() => _region = id),
            ),
        ],
        const SizedBox(height: 16),
        Text(l10n.reviewRateFriendly, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final (value, label) in <(Friendly, String)>[
              (Friendly.yes, l10n.reviewFriendlyYes),
              (Friendly.no, l10n.reviewFriendlyNo),
              (Friendly.sometimes, l10n.reviewFriendlySometimes),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _friendly == value,
                onSelected: (_) => setState(() => _friendly = value),
              ),
          ],
        ),
      ],
    );
  }
}

/// The 1 to 9 of "Rate this word", as the design draws it: nine numbers,
/// one of them chosen, none at first, so that no score is given before the
/// rater picks one. Each is a 48 by 48 target, so on a phone the nine wrap
/// onto a second line.
class _Scale extends StatelessWidget {
  const _Scale({required this.score, required this.onChosen});

  final int? score;
  final ValueChanged<int> onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        for (var n = WordRating.minScore; n <= WordRating.maxScore; n++)
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: score == n,
            button: true,
            label: l10n.reviewRateScore(n),
            child: Material(
              color: score == n
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: InkWell(
                onTap: () => onChosen(n),
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: SizedBox.square(
                  dimension: 48,
                  // The label above says "4 of 9"; the bare number is not
                  // read as well. The tap stays the InkWell's own.
                  child: ExcludeSemantics(
                    child: Center(
                      child: Text(
                        '$n',
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: score == n
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One answer of a list where one is chosen: a row with a radio mark, for
/// answers too long for a chip, such as Bengali's regions.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the pair check on [card] of [deck] and its rude partner.
Future<void> showAlikeSheet(
  BuildContext context, {
  required DeckEntry deck,
  required Card card,
  required RudeAlike pair,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AlikeSheet(deck: deck, card: card, pair: pair),
);

/// A sound-alike or look-alike pair the check found: is it a real risk,
/// and if so the care note learners read, at most 40 letters, counted as
/// the reviewer types.
class AlikeSheet extends StatefulWidget {
  const AlikeSheet({
    super.key,
    required this.deck,
    required this.card,
    required this.pair,
  });

  final DeckEntry deck;
  final Card card;
  final RudeAlike pair;

  @override
  State<AlikeSheet> createState() => _AlikeSheetState();
}

class _AlikeSheetState extends State<AlikeSheet> {
  bool? _real;
  final TextEditingController _care = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final old = AppScope.read(context).reviewing
        .reviewOf(widget.deck, widget.card)
        ?.alike;
    _real = old?.real;
    _care.text = old?.care ?? '';
  }

  @override
  void dispose() {
    _care.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.deck.language;
    final real = _real;
    final care = _care.text.trim();
    final ready = real == false || (real == true && care.isNotEmpty);
    return _FormSheet(
      title: l10n.reviewAlikeCheck,
      about: _about(context, widget.card, language),
      onSave: ready
          ? () {
              AppScope.read(context).reviewing.checkAlike(
                widget.deck,
                widget.card,
                AlikeCheck(
                  partner: widget.pair.partner.id,
                  kind: widget.pair.kind,
                  real: real!,
                  care: real ? care : '',
                ),
              );
              Navigator.of(context).pop();
            }
          : null,
      children: <Widget>[
        _AlikeFound(pair: widget.pair, language: language, check: null),
        const SizedBox(height: 16),
        Text(l10n.reviewAlikeReal, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          emptySelectionAllowed: true,
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: true,
              label: Text(l10n.reviewAlikeConfirm),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text(l10n.reviewAlikeReject),
            ),
          ],
          selected: <bool>{?real},
          onSelectionChanged: (chosen) =>
              setState(() => _real = chosen.firstOrNull),
        ),
        if (real == true) ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            controller: _care,
            maxLength: AlikeCheck.careLimit,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.reviewAlikeCare,
              hintText: l10n.reviewAlikeCareHint,
              helperText: l10n.reviewAlikeCareHelp,
              border: const OutlineInputBorder(),
            ),
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => Text(
                  l10n.reviewAlikeCareCount(
                    currentLength,
                    maxLength ?? AlikeCheck.careLimit,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
          ),
        ],
      ],
    );
  }
}
