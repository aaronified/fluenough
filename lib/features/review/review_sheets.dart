import 'dart:convert';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/proposal.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_bases.dart';
import '../decks/card_notes.dart';
import '../decks/card_top_line.dart';
import '../decks/checked_by_line.dart';
import '../decks/path_parts.dart' show joinParts;
import 'alike_warning.dart';
import 'proposal_card.dart';
import 'review_words.dart';
import 'suggest_bases.dart';

/// What a reviewer can do from a card's sheet: the sheet closes, then the
/// review screen opens the next one.
enum ReviewCardAction { suggest, rate, checkAlike }

/// Opens [card] of [deck] as a lesson shows it, with "Looks right" and
/// "Suggest a change" (the approved card in reviewer mode); a rude word
/// with its level, type, friendliness and region note, and "Rate this
/// word"; a word like a rude one with the warning a learner sees, or, in
/// the [offensive] words review, with the rude word named and the pair to
/// check.
Future<ReviewCardAction?> showReviewCard(
  BuildContext context, {
  required DeckEntry deck,
  required Card card,
  bool offensive = false,
}) => showModalBottomSheet<ReviewCardAction>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ReviewCardSheet(deck: deck, card: card, offensive: offensive),
);

/// The text of [part] of [card], as "Suggest a change" shows it under Now,
/// or null when the card has none. For [CardPart.base], the meaning of the
/// base written in full for [word], as it stands in the target.
String? partText(Card card, CardPart part, {String? word}) => switch (part) {
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
  CardPart.base => inlineBaseOf(card, word)?.meaning,
  CardPart.alt => card.altTarget.isEmpty ? null : card.altTarget.join('\n'),
};

/// [card]'s base written in full for [word], the word as it stands in its
/// target, or null. A base given by ref is not one: its meaning is the
/// card's it names, and a change to it is suggested there.
CardBase? inlineBaseOf(Card card, String? word) {
  if (word == null) return null;
  for (final base in card.bases) {
    if (base.word == word && base.base != null) return base;
  }
  return null;
}

/// The bases of [card] a reviewer can suggest a meaning for: those written
/// in full, in order, every one of them, though the card's base line shows
/// a base and meaning only once ([shownBases]).
List<CardBase> inlineBasesOf(Card card) => <CardBase>[
  for (final base in card.bases)
    if (base.base != null && base.base!.trim().isNotEmpty) base,
];

/// Whether another base [card] writes in full has the same base as the one
/// for [word], so that the base alone does not say which it is.
bool baseIsShared(Card card, String? word) {
  final base = inlineBaseOf(card, word)?.base;
  if (base == null) return false;
  return inlineBasesOf(card)
      .any((b) => b.word != word && b.base!.trim() == base.trim());
}

/// The name of the base [card] writes in full for [word]: "Base: जाना", or
/// "Base of गया: जाना" when another of its bases is also जाना.
String baseName(AppLocalizations l10n, Card card, String? word) {
  final base = inlineBaseOf(card, word)?.base ?? word ?? '';
  return word != null && baseIsShared(card, word)
      ? l10n.reviewPartBaseOfWord(word, base)
      : l10n.reviewPartBaseOf(base);
}

/// [part]'s name on its chip.
String partName(AppLocalizations l10n, CardPart part) => switch (part) {
  CardPart.word => l10n.reviewPartWord,
  CardPart.reading => l10n.reviewPartReading,
  CardPart.ipa => l10n.reviewPartIpa,
  CardPart.meaning => l10n.reviewPartMeaning,
  CardPart.notes => l10n.reviewPartNotes,
  CardPart.example => l10n.reviewPartExample,
  CardPart.picture => l10n.reviewPartPicture,
  CardPart.base => l10n.reviewPartBase,
  CardPart.alt => l10n.reviewPartAlt,
};

/// What a suggestion on [part] is about, by name: [partName], or for a base
/// word's meaning, "Base: जाना" with the base [card] writes for [word].
String suggestionPartName(
  AppLocalizations l10n,
  Card card,
  CardPart part, {
  String? word,
}) => part == CardPart.base ? baseName(l10n, card, word) : partName(l10n, part);

/// Where [review] stands, as a card's top line says it.
String reviewStateName(AppLocalizations l10n, CardReview? review) =>
    switch (review) {
      CardReview(suggestions: [_, ...]) => l10n.reviewStateSuggested,
      CardReview(right: true) => l10n.reviewStateRight,
      _ => l10n.reviewStateNot,
    };

/// A card in review, in a sheet.
class ReviewCardSheet extends StatelessWidget {
  const ReviewCardSheet({
    super.key,
    required this.deck,
    required this.card,
    this.offensive = false,
  });

  final DeckEntry deck;
  final Card card;

  /// Whether the sheet is opened from a language's Offensive words review,
  /// past its 18+ question: only there does it name the rude word a card
  /// is like, and offer to check the pair. Elsewhere, the ordinary review
  /// of a deck or unit, it shows the warning a learner sees, the rude word
  /// hidden, adult content on or off (owner, 2026-10-10: offensive words
  /// are reviewed "only when the reviewer intentionally wants to check
  /// them").
  final bool offensive;

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
              if (offensive)
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
            if (offensive && alikes.isNotEmpty) ...<Widget>[
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
/// its meaning, its note, its base words ([BaseLine]) and its first example.
/// The base words are here so that a reviewer can check their meanings,
/// which agents wrote (#410), and suggest a change to one.
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
    final bases = basesOf(AppScope.read(context), card, language);
    final muted = theme.textTheme.bodyLarge!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: <Widget>[
        if (card.hasPicture) Center(child: CardPicture(card, size: 72)),
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
        if (bases.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          BaseLine(bases: bases, language: language),
        ],
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

/// In the Offensive words review: the rude word the check found,
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

/// "Suggest a change" (#468): one card a part of the card under review,
/// each with its name, what it says now, and a pencil. The pencil turns
/// that part into a field of its own, with its own why, started from the
/// reviewer's suggestion on it or from what it says now; nothing is shared
/// between parts, so no text carries over from one to another. A part
/// with a suggestion shows it under what it says now, marked, with a way
/// to remove it. The tick saves every part edited at once; the cross
/// discards them. Kept on the phone until the review is sent.
///
/// Base words (#476, docs/mockups/reviewer-mode.html, section 2): each of
/// the card's bases has a box whose pencil changes its form, reading and
/// meaning, and whose delete marks it to be removed, with Undo until the
/// tick. "Add a base" opens a box for a new one, for a word of the card
/// that has none. Each is a suggestion of its own, with its own why.
///
/// A new word for the card makes it a new identity: under the Word box a
/// panel says the card keeps its id and meaning, offers to replace the
/// bases and to keep the old word as an accepted answer (ticked at first),
/// and the parts that hung on the old word are tagged "Check". All of it
/// is sent as one review, which the review bot applies at once.
///
/// Opened [from] another reviewer's proposal (ADR-0038), the proposal's
/// part starts edited, with the proposal's text; saved, it is this
/// reviewer's own suggestion, which becomes a new proposal, and the answer
/// to [from] is "edit". The proposal edited keeps waiting.
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

  /// The key of the suggestion field of [part], and for a base, of the
  /// base for [word].
  static Key textKey(CardPart part, {String? word}) =>
      ValueKey<String>('suggest-text-${part.name}-${word ?? ''}');

  /// The key of the why field of [part].
  static Key whyKey(CardPart part, {String? word}) =>
      ValueKey<String>('suggest-why-${part.name}-${word ?? ''}');

  /// The key of [field] (form, reading, meaning, why or link) of the base
  /// for [word] while it is changed, or its why while it is removed.
  static Key baseKey(String word, String field) =>
      ValueKey<String>('suggest-base-$field-$word');

  /// The key of [field] of the [index]th new base, from 0.
  static Key newBaseKey(int index, String field) =>
      ValueKey<String>('suggest-newbase-$field-$index');

  /// The key of the [index]th new base's chip for [word].
  static Key chipKey(int index, String word) =>
      ValueKey<String>('suggest-newbase-chip-$index-$word');

  /// "Add a base".
  static const Key addBaseKey = ValueKey<String>('suggest-add-base');

  /// The checkbox of the Also heard box, once a new word is suggested.
  static const Key keepAltKey = ValueKey<String>('suggest-keep-alt');

  @override
  State<SuggestSheet> createState() => _SuggestSheetState();
}

/// A part of a card a suggestion can be about: for a base word, the base's
/// [word] as it stands in the target; null for any other part.
typedef _Part = ({CardPart part, String? word});

const _Part _wordPart = (part: CardPart.word, word: null);

/// The fields of a part being edited.
class _Edit {
  _Edit(String text, String why)
    : text = TextEditingController(text: text),
      why = TextEditingController(text: why);

  final TextEditingController text;
  final TextEditingController why;

  void dispose() {
    text.dispose();
    why.dispose();
  }
}

/// The fields of a base being changed or added: for a new base, the word
/// of the card it explains, chosen by its chip.
class _BaseEdit {
  _BaseEdit({
    this.word,
    String form = '',
    String reading = '',
    String meaning = '',
    String why = '',
    this.link = true,
  }) : form = TextEditingController(text: form),
       reading = TextEditingController(text: reading),
       meaning = TextEditingController(text: meaning),
       why = TextEditingController(text: why);

  String? word;
  final TextEditingController form;
  final TextEditingController reading;
  final TextEditingController meaning;
  final TextEditingController why;

  /// Whether a form that is another card's word is given by ref to it.
  bool link;

  List<TextEditingController> get all => <TextEditingController>[
    form,
    reading,
    meaning,
    why,
  ];
}

class _SuggestSheetState extends State<SuggestSheet> {
  /// The suggestions already kept on the card, a base's meaning from
  /// before #476 read as a change to that base.
  List<Suggestion> _saved = const <Suggestion>[];

  /// The parts being edited, each with its own fields.
  final Map<_Part, _Edit> _edits = <_Part, _Edit>{};

  /// The parts whose kept suggestion is removed when the sheet is saved.
  final Set<_Part> _removed = <_Part>{};
  bool _seeded = false;

  late final AppState _state;
  late final Card? Function(String id) _find;

  /// The card's bases, every one, in order.
  List<CardBaseShown> _bases = const <CardBaseShown>[];

  /// The bases being changed, by word.
  final Map<String, _BaseEdit> _baseEdits = <String, _BaseEdit>{};

  /// The bases marked to be removed, by word, each with its why.
  final Map<String, TextEditingController> _baseRemoved =
      <String, TextEditingController>{};

  /// The bases being added, in the order they were opened.
  final List<_BaseEdit> _added = <_BaseEdit>[];

  /// Whether the old word stays an accepted answer, once a new word is
  /// suggested: ticked at first, and the reviewer may untick it.
  bool _keepAlt = true;

  /// Fields no longer shown, disposed with the sheet: a field may still be
  /// in the tree in the frame that drops it.
  final List<TextEditingController> _retired = <TextEditingController>[];

  late final List<_Part> _parts = <_Part>[
    for (final part in CardPart.values)
      if (part != CardPart.base && part != CardPart.alt)
        (part: part, word: null),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _state = AppScope.read(context);
    final language = widget.deck.language.code;
    final native = widget.deck.deck.native.code;
    _find = baseFinder(_state, language: language, native: native);
    _bases = basesShown(widget.card, _find);
    final l10n = AppLocalizations.of(context)!;
    _saved = <Suggestion>[
      for (final s
          in _state.reviewing.reviewOf(widget.deck, widget.card)?.suggestions ??
              const <Suggestion>[])
        _readBase(l10n, s),
    ];
    for (final s in _saved) {
      final word = s.word;
      if (s.part != CardPart.base || word == null) continue;
      if (s.action == BaseAction.remove && _baseOf(word) != null) {
        _baseRemoved[word] = TextEditingController(text: s.why);
      } else if (s.action == BaseAction.add) {
        _added.add(_fieldsFor(word, s.base!, s.why, link: true));
      }
    }
    _keepAlt =
        !_saved.any((s) => s.part == CardPart.word) ||
        _saved.any((s) => s.part == CardPart.alt);
    if (widget.from case final from?) {
      final _Part part = (part: partOf(from.field), word: null);
      _edits[part] = _Edit(from.text, _savedOn(part)?.why ?? '');
    }
  }

  @override
  void dispose() {
    for (final edit in _edits.values) {
      edit.dispose();
    }
    for (final c in <TextEditingController>[
      for (final e in _baseEdits.values) ...e.all,
      for (final e in _added) ...e.all,
      ..._baseRemoved.values,
      ..._retired,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  CardBaseShown? _baseOf(String word) =>
      _bases.where((b) => b.word == word).firstOrNull;

  /// [s], a change to a base's meaning as kept before #476, as a change to
  /// that base; any other as it is.
  Suggestion _readBase(AppLocalizations l10n, Suggestion s) {
    if (s.part != CardPart.base || s.action != null) return s;
    final b = _baseOf(s.word!);
    if (b == null || b.form.byRef) return s;
    final base = BaseForm(
      base: b.form.base,
      reading: b.form.reading,
      meaning: s.text,
    );
    return Suggestion(
      part: CardPart.base,
      word: s.word,
      action: BaseAction.edit,
      was: b.form,
      base: base,
      now: _line(l10n, s.word!, b.form),
      text: _line(l10n, s.word!, base),
      why: s.why,
    );
  }

  /// [form] of the base for [word] as its line says it: "आना (ānā) · to
  /// come", a base by ref as the card it names.
  ShownBase _shown(String word, BaseForm form) {
    if (form.ref case final ref?) {
      final taught = _find(ref);
      return (
        word: word,
        base: taught?.target ?? ref,
        reading: taught?.reading,
        meaning: taught?.native,
        inline: false,
        ref: ref,
      );
    }
    return (
      word: word,
      base: form.base ?? '',
      reading: form.reading,
      meaning: form.meaning,
      inline: true,
      ref: null,
    );
  }

  String _line(AppLocalizations l10n, String word, BaseForm form) =>
      baseText(l10n, _shown(word, form));

  /// The fields of the base for [word] started from [form]: a base by ref
  /// from the card it names, linked. [link] is whether a base written in
  /// full whose form is a card's word starts linked.
  _BaseEdit _fieldsFor(
    String word,
    BaseForm form,
    String why, {
    required bool link,
  }) {
    final shown = _shown(word, form);
    return _BaseEdit(
      word: word,
      form: form.byRef ? (_find(form.ref!)?.target ?? '') : shown.base,
      reading: shown.reading ?? '',
      meaning: shown.meaning ?? '',
      why: why,
      link: form.byRef || (link && form.link != false),
    );
  }

  /// The card whose word [form] is, which a base of that form can link.
  Card? _match(String form) => cardForForm(
    _state,
    form,
    language: widget.deck.language.code,
    except: widget.card.id,
    native: widget.deck.deck.native.code,
  );

  /// The base [edit]'s fields give, or null while it has no form.
  BaseForm? _formOf(_BaseEdit edit) {
    final form = edit.form.text.trim();
    if (form.isEmpty) return null;
    final match = _match(form);
    if (match != null && edit.link) return BaseForm(ref: match.id);
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return BaseForm(
      base: form,
      reading: text(edit.reading),
      meaning: text(edit.meaning),
      link: match != null ? false : null,
    );
  }

  static bool _same(BaseForm a, BaseForm b) =>
      a.ref == b.ref &&
      (a.ref != null ||
          (a.base == b.base &&
              a.reading == b.reading &&
              a.meaning == b.meaning));

  String? _now(_Part p) => partText(widget.card, p.part, word: p.word);

  Suggestion? _savedOn(_Part p) =>
      _saved.where((s) => s.part == p.part && s.word == p.word).firstOrNull;

  void _retire(Iterable<TextEditingController> fields) =>
      _retired.addAll(fields);

  void _edit(_Part p) => setState(() {
    final saved = _removed.remove(p) ? null : _savedOn(p);
    _edits[p] = _Edit(saved?.text ?? _now(p) ?? '', saved?.why ?? '');
  });

  /// The suggestion [p] has once saved: its edit, when the text differs
  /// from what the part says now, or the one kept, unless removed.
  Suggestion? _resultOn(_Part p) {
    final edit = _edits[p];
    if (edit == null) return _removed.contains(p) ? null : _savedOn(p);
    final now = _now(p) ?? '';
    final text = edit.text.text.trim();
    if (text.isEmpty || text == now) return null;
    return Suggestion(
      part: p.part,
      now: now,
      text: text,
      why: edit.why.text.trim(),
      word: p.word,
    );
  }

  /// The new word suggested for the card, once saved, or null.
  String? get _newWord => _resultOn(_wordPart)?.text;

  /// Keeping the old word as an accepted answer, with a new word.
  Suggestion? _altResult() {
    final alts = widget.card.altTarget;
    if (_newWord == null || !_keepAlt || alts.contains(widget.card.target)) {
      return null;
    }
    return Suggestion(
      part: CardPart.alt,
      now: alts.join('\n'),
      text: <String>[...alts, widget.card.target].join('\n'),
    );
  }

  /// The suggestion on the base [b] once saved: removed, changed, or the
  /// change kept on it.
  Suggestion? _baseResult(AppLocalizations l10n, CardBaseShown b) {
    final word = b.word;
    if (_baseRemoved[word] case final why?) {
      return Suggestion(
        part: CardPart.base,
        word: word,
        action: BaseAction.remove,
        was: b.form,
        now: _line(l10n, word, b.form),
        text: '',
        why: why.text.trim(),
      );
    }
    if (_baseEdits[word] case final edit?) {
      final form = _formOf(edit);
      if (form == null || _same(form, b.form)) return null;
      return Suggestion(
        part: CardPart.base,
        word: word,
        action: BaseAction.edit,
        was: b.form,
        base: form,
        now: _line(l10n, word, b.form),
        text: _line(l10n, word, form),
        why: edit.why.text.trim(),
      );
    }
    if (_removed.contains((part: CardPart.base, word: word))) return null;
    return _saved
        .where(
          (s) =>
              s.part == CardPart.base &&
              s.word == word &&
              s.action == BaseAction.edit,
        )
        .firstOrNull;
  }

  Suggestion? _addResult(AppLocalizations l10n, _BaseEdit edit) {
    final word = edit.word;
    final form = _formOf(edit);
    if (word == null || form == null) return null;
    return Suggestion(
      part: CardPart.base,
      word: word,
      action: BaseAction.add,
      base: form,
      now: '',
      text: _line(l10n, word, form),
      why: edit.why.text.trim(),
    );
  }

  /// Whether the sheet shows [s], and so writes it again on saving.
  bool _shows(Suggestion s) => switch (s.part) {
    CardPart.alt => true,
    CardPart.base => switch (s.action) {
      null => false,
      BaseAction.add => true,
      _ => _baseOf(s.word!) != null,
    },
    _ => true,
  };

  /// Every suggestion the card keeps once saved, those on parts this sheet
  /// does not show (a base no longer on the card) left as they are.
  List<Suggestion> _result(AppLocalizations l10n) => <Suggestion>[
    for (final p in _parts) ?_resultOn(p),
    ?_altResult(),
    for (final b in _bases) ?_baseResult(l10n, b),
    for (final edit in _added) ?_addResult(l10n, edit),
    for (final s in _saved)
      if (!_shows(s)) s,
  ];

  bool _changed(AppLocalizations l10n) {
    String key(List<Suggestion> list) =>
        jsonEncode(<Object?>[for (final s in list) s.toJson()]);
    return key(_result(l10n)) != key(_saved);
  }

  void _save(AppLocalizations l10n) {
    final reviewing = AppScope.read(context).reviewing;
    final result = _result(l10n);
    reviewing.suggest(widget.deck, widget.card, result);
    if (widget.from case final from?) {
      final part = partOf(from.field);
      if (result.any((s) => s.part == part && s.word == null)) {
        reviewing.answer(widget.deck, widget.card, from, ProposalVerdict.edit);
      }
    }
    Navigator.of(context).pop();
  }

  /// The words of the card's target, or of the new word suggested, that
  /// have no base and no new base other than [own].
  List<String> _freeWords([_BaseEdit? own]) {
    final taken = <String>{
      for (final b in _bases)
        if (!_baseRemoved.containsKey(b.word)) b.word,
      for (final e in _added)
        if (!identical(e, own) && e.word != null) e.word!,
    };
    final words = switch (_newWord) {
      final word? => wordsForBases(word),
      null => widget.card.words ?? wordsForBases(widget.card.target),
    };
    return <String>{...words}.where((w) => !taken.contains(w)).toList();
  }

  void _addBase() => setState(() {
    final free = _freeWords();
    final word = free.length == 1 ? free.single : null;
    _added.add(_BaseEdit(word: word, form: word ?? ''));
  });

  /// Marks every base removed, and opens a new base for the new word.
  void _replaceBases() => setState(() {
    for (final b in _bases) {
      _baseRemoved.putIfAbsent(b.word, TextEditingController.new);
      if (_baseEdits.remove(b.word) case final edit?) _retire(edit.all);
    }
    final free = _freeWords();
    if (free.isNotEmpty) {
      _added.add(_BaseEdit(word: free.first, form: free.first));
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final changed = _changed(l10n);
    final newWord = _newWord;
    final editingWord = _edits.containsKey(_wordPart);
    final free = _freeWords();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l10n.reviewSuggestDiscard,
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.reviewSuggest,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: changed ? () => _save(l10n) : null,
                    tooltip: l10n.reviewSuggestSaveAll,
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                child: _about(context, widget.card, widget.deck.language),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    Expanded(child: Text(l10n.reviewSuggestRule, style: muted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final p in _parts) ...<Widget>[
                _partCard(context, p, check: newWord != null),
                const SizedBox(height: 8),
                if (p.part == CardPart.word &&
                    editingWord &&
                    newWord != null) ...<Widget>[
                  IdentityPanel(
                    card: widget.card,
                    language: widget.deck.language,
                    bases: <ShownBase>[
                      for (final b in _bases)
                        if (!_baseRemoved.containsKey(b.word)) b.shown,
                    ],
                    onReplace:
                        _bases.every((b) => _baseRemoved.containsKey(b.word))
                        ? null
                        : _replaceBases,
                    keepAlt: _keepAlt,
                    onKeepAlt: (v) => setState(() => _keepAlt = v),
                  ),
                  const SizedBox(height: 8),
                ],
                if (p.part == CardPart.ipa &&
                    !editingWord &&
                    newWord != null) ...<Widget>[
                  _altBox(context),
                  const SizedBox(height: 8),
                ],
              ],
              for (final b in _bases) ...<Widget>[
                _baseBox(context, b, check: newWord != null),
                const SizedBox(height: 8),
              ],
              for (final (i, edit) in _added.indexed) ...<Widget>[
                _newBaseBox(context, i, edit),
                const SizedBox(height: 8),
              ],
              if (free.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: SuggestSheet.addBaseKey,
                    onPressed: _addBase,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.reviewBaseAdd),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                child: Text(l10n.reviewSuggestKept, style: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A part's name in small capitals, the deck content it quotes in its
  /// language's own case and font.
  Widget _label(String name, List<String> quotes) {
    final theme = Theme.of(context);
    return Text.rich(
      _smallCaps(quotingTarget(name, quotes, widget.deck.language)),
      semanticsLabel: name,
      style: theme.textTheme.labelMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }

  /// A part's box: on surfaceContainerHigh, or outlined while edited; its
  /// name and buttons in a 48 dp row, then [body].
  Widget _box({
    required Widget label,
    required List<Widget> body,
    List<Widget> actions = const <Widget>[],
    bool outlined = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 12),
      decoration: BoxDecoration(
        color: outlined ? null : scheme.surfaceContainerHigh,
        border: outlined ? Border.all(color: scheme.outline) : null,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Expanded(child: label),
                ...actions,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ],
      ),
    );
  }

  /// One part: its name in small capitals, what it says now, and the
  /// reviewer's suggestion on it, or its own fields while edited. [check]
  /// tags the notes and example, when the card has them: they may name the
  /// old word.
  Widget _partCard(BuildContext context, _Part p, {bool check = false}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.deck.language;
    final name = suggestionPartName(l10n, widget.card, p.part, word: p.word);
    final now = _now(p);
    final edit = _edits[p];
    final saved = _removed.contains(p) ? null : _savedOn(p);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final Widget value = now == null
        ? Text(
            l10n.reviewSuggestNotSet,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        : Text.rich(
            quotingTarget(now, <String>[
              if (p.part == CardPart.word) now,
            ], language),
            style: theme.textTheme.bodyLarge,
          );
    return _box(
      outlined: edit != null,
      label: _label(name, const <String>[]),
      actions: <Widget>[
        if (edit == null &&
            check &&
            now != null &&
            (p.part == CardPart.notes || p.part == CardPart.example))
          const CheckTag(),
        if (edit == null)
          IconButton(
            onPressed: () => _edit(p),
            tooltip: l10n.reviewSuggestEditPart(name),
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      body: edit == null
          ? <Widget>[
              value,
              if (saved != null) ...<Widget>[
                const SizedBox(height: 8),
                _yours(
                  context,
                  p,
                  saved,
                  name,
                  quotes: <String>[if (p.part == CardPart.word) saved.text],
                ),
              ],
              if (_removed.contains(p))
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(l10n.reviewSuggestRemoved, style: muted),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _removed.remove(p)),
                      child: Text(l10n.commonUndo),
                    ),
                  ],
                ),
            ]
          : <Widget>[
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.reviewSuggestNow, style: muted),
                    value,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: SuggestSheet.textKey(p.part, word: p.word),
                controller: edit.text,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.reviewSuggestYours,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: SuggestSheet.whyKey(p.part, word: p.word),
                controller: edit.why,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.reviewSuggestWhy,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
    );
  }

  /// "Base: शुभ", or "Base of गया: जाना" when another base of the card
  /// has the same form.
  String _baseName(AppLocalizations l10n, CardBaseShown b) => _shared(b)
      ? l10n.reviewPartBaseOfWord(b.word, b.shown.base)
      : l10n.reviewPartBaseOf(b.shown.base);

  bool _shared(CardBaseShown b) =>
      _bases.any((o) => o.word != b.word && o.shown.base == b.shown.base);

  /// A base's two lines: its form and reading, then its meaning and, when
  /// it is not the word itself, the word it explains, or for a base by
  /// ref, the card that teaches it. [strike] draws them struck through.
  List<Widget> _baseLines(ShownBase base, {bool strike = false}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.deck.language;
    final through = strike ? TextDecoration.lineThrough : null;
    final meaning = base.meaning ?? '';
    final second = switch (base.ref) {
      final ref? => l10n.reviewBaseByCard(meaning, ref),
      null when base.word != base.base => l10n.reviewBaseFor(
        meaning,
        base.word,
      ),
      null => meaning,
    };
    return <Widget>[
      Text.rich(
        quotingTarget(
          switch (base.reading) {
            final r? => l10n.cardBaseReading(base.base, r),
            null => base.base,
          },
          <String>[base.base],
          language,
        ),
        style: theme.textTheme.bodyLarge!.copyWith(decoration: through),
      ),
      if (second.isNotEmpty)
        Text.rich(
          quotingTarget(second, <String>[
            if (base.ref == null && base.word != base.base) base.word,
          ], language),
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
            decoration: through,
          ),
        ),
    ];
  }

  /// One of the card's bases: as it is, with a pencil and a delete button;
  /// its fields while changed; struck through, with Undo and why, while
  /// marked removed. [check] tags it, once the card has a new word.
  Widget _baseBox(BuildContext context, CardBaseShown b, {bool check = false}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name = _baseName(l10n, b);
    final label = _label(name, <String>[if (_shared(b)) b.word, b.shown.base]);
    final word = b.word;
    if (_baseRemoved[word] case final why?) {
      return _box(
        outlined: true,
        label: label,
        body: <Widget>[
          ..._baseLines(b.shown, strike: true),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(child: Text(l10n.reviewBaseRemoved, style: muted)),
              TextButton(
                onPressed: () => setState(() {
                  if (_baseRemoved.remove(word) case final c?) _retire([c]);
                }),
                child: Text(l10n.commonUndo),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            key: SuggestSheet.baseKey(word, 'why'),
            controller: why,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.reviewSuggestWhy,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
    if (_baseEdits[word] case final edit?) {
      return _box(
        outlined: true,
        label: label,
        body: <Widget>[
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.reviewSuggestNow, style: muted),
                ..._baseLines(b.shown),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _fields(edit, (f) => SuggestSheet.baseKey(word, f)),
        ],
      );
    }
    final p = (part: CardPart.base, word: word);
    final saved = _removed.contains(p) ? null : _baseResult(l10n, b);
    return _box(
      label: label,
      actions: <Widget>[
        if (check) const CheckTag(),
        IconButton(
          onPressed: () => setState(() {
            _removed.remove(p);
            _baseEdits[word] = _fieldsFor(
              word,
              saved?.base ?? b.form,
              saved?.why ?? '',
              link: false,
            );
          }),
          tooltip: l10n.reviewSuggestEditPart(name),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          onPressed: () =>
              setState(() => _baseRemoved[word] = TextEditingController()),
          tooltip: l10n.reviewBaseRemove(b.shown.base),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: <Widget>[
        ..._baseLines(b.shown),
        if (saved != null) ...<Widget>[
          const SizedBox(height: 8),
          _yours(
            context,
            p,
            saved,
            name,
            quotes: <String>[_shown(word, saved.base!).base],
          ),
        ],
        if (_removed.contains(p))
          Row(
            children: <Widget>[
              Expanded(child: Text(l10n.reviewSuggestRemoved, style: muted)),
              TextButton(
                onPressed: () => setState(() => _removed.remove(p)),
                child: Text(l10n.commonUndo),
              ),
            ],
          ),
      ],
    );
  }

  /// [edit]'s fields, with the link row when its form is a card's word.
  Widget _fields(_BaseEdit edit, Key Function(String field) keyOf) =>
      BaseFields(
        keyOf: keyOf,
        form: edit.form,
        reading: edit.reading,
        meaning: edit.meaning,
        why: edit.why,
        language: widget.deck.language,
        match: _match(edit.form.text),
        link: edit.link,
        onLink: (v) => setState(() => edit.link = v),
        onChanged: () => setState(() {}),
      );

  /// A new base: which word of the card it explains, as chips, then its
  /// fields.
  Widget _newBaseBox(BuildContext context, int index, _BaseEdit edit) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.deck.language;
    final words = <String>{?edit.word, ..._freeWords(edit)}.toList();
    return _box(
      outlined: true,
      label: _label(l10n.reviewBaseNew, const <String>[]),
      actions: <Widget>[
        IconButton(
          onPressed: () => setState(() {
            _added.remove(edit);
            _retire(edit.all);
          }),
          tooltip: l10n.reviewBaseNewRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: <Widget>[
        Text(
          l10n.reviewBaseWhich,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final w in words)
              FilterChip(
                key: SuggestSheet.chipKey(index, w),
                label: Text.rich(quotingTarget(w, <String>[w], language)),
                selected: edit.word == w,
                onSelected: (_) => setState(() {
                  edit.word = w;
                  if (edit.form.text.trim().isEmpty) edit.form.text = w;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _fields(edit, (f) => SuggestSheet.newBaseKey(index, f)),
      ],
    );
  }

  /// Also heard, once a new word is suggested: the card's accepted
  /// answers, and the old word, ticked to stay one.
  Widget _altBox(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.deck.language;
    final target = widget.card.target;
    return _box(
      label: _label(l10n.reviewPartAlt, const <String>[]),
      actions: const <Widget>[CheckTag(), SizedBox(width: 12)],
      body: <Widget>[
        for (final alt in widget.card.altTarget)
          Text.rich(
            quotingTarget(alt, <String>[alt], language),
            style: theme.textTheme.bodyLarge,
          ),
        if (!widget.card.altTarget.contains(target))
          CheckRow(
            key: SuggestSheet.keepAltKey,
            value: _keepAlt,
            onChanged: (v) => setState(() => _keepAlt = v),
            label: quotingTarget(l10n.reviewAltOld(target), <String>[
              target,
            ], language),
          ),
      ],
    );
  }

  /// The reviewer's suggestion kept on [p], marked as theirs, with a
  /// button that removes it. [quotes] are the deck content its text has.
  Widget _yours(
    BuildContext context,
    _Part p,
    Suggestion saved,
    String name, {
    List<String> quotes = const <String>[],
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 0, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.innerRow),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.reviewSuggestYours,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text.rich(
                    quotingTarget(saved.text, quotes, widget.deck.language),
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  if (saved.why.isNotEmpty)
                    Text(
                      saved.why,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _removed.add(p)),
            tooltip: l10n.reviewSuggestRemove(name),
            color: scheme.onPrimaryContainer,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

/// [span], an interface string quoting deck content as [quotingTarget]
/// marks it, in capitals but for the content quoted, whose case is its
/// language's own.
TextSpan _smallCaps(TextSpan span) => TextSpan(
  children: <TextSpan>[
    for (final child in span.children!.cast<TextSpan>())
      TextSpan(
        text: child.locale == null ? child.text!.toUpperCase() : child.text,
        locale: child.locale,
      ),
  ],
);

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
