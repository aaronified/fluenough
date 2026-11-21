import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/review/facets.dart';
import '../../core/review/review_session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'facet_labels.dart';
import 'facet_tags_sheet.dart';

/// The card screen of the review (ADR-0058, decisions 5 and 6; docs/mockups/
/// reviewer-ux.html, frames 1c to 1e): every facet of the card in card order
/// (word, reading, IPA, meaning, example, note, unit, offence rating,
/// audio), and one button at the end.
///
/// The word, meaning and example show what the card says and a flag icon;
/// so do the note, the unit and the offence rating. The reading, the IPA and
/// the audio also have a tick, and a row not answered yet has an outline in
/// the accent colour. The flag opens the tags sheet. An answer is kept the
/// moment it is given.
///
/// The one button reads "All good" while nothing is flagged and "Done" once a
/// facet is, and waits until the reading, the IPA and the audio, where the
/// card has them, are answered. It answers the rest right and calls
/// [onDone].
///
/// The screen shows what this reviewer answered and nothing another
/// reviewer said: a second speaker's verdict is blind (decision 7).
/// [needsAnother] adds the one line that says another speaker has still to
/// check the card.
class ReviewCardView extends StatelessWidget {
  const ReviewCardView({
    super.key,
    required this.deck,
    required this.card,
    required this.placeText,
    required this.onDone,
    this.needsAnother = false,
  });

  final DeckEntry deck;
  final Card card;

  /// Where the card sits, for the Unit row ("Unit 3 · card 5 of 18").
  final String placeText;

  final VoidCallback onDone;
  final bool needsAnother;

  /// The row of [facet].
  static Key rowKey(Facet facet) =>
      ValueKey<String>('review-row-${facet.wire}');

  /// The tick of [facet], on the three that have one.
  static Key tickKey(Facet facet) =>
      ValueKey<String>('review-tick-${facet.wire}');

  /// The flag of [facet].
  static Key flagKey(Facet facet) =>
      ValueKey<String>('review-flag-${facet.wire}');

  static const Key doneKey = ValueKey<String>('review-done');
  static const Key needsKey = ValueKey<String>('review-needs-another');

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reviewing = AppScope.of(context).reviewing;
    final answers =
        reviewing.reviewOf(deck, card)?.facets ?? const <Facet, FacetAnswer>{};
    final applicable = facetsOf(card);
    final flagged = anyFlagged(answers);
    final ready = canFinishCard(applicable, answers);
    void answer(Facet facet, FacetAnswer a) =>
        reviewing.answerFacet(deck, card, facet, a);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: <Widget>[
        if (needsAnother)
          Padding(
            key: ReviewCardView.needsKey,
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              spacing: 6,
              children: <Widget>[
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                Flexible(
                  child: Text(
                    l10n.reviewNeedsAnother,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final facet in Facet.values)
          if (applicable.contains(facet))
            _FacetRow(
              key: ReviewCardView.rowKey(facet),
              facet: facet,
              deck: deck,
              card: card,
              placeText: placeText,
              answer: answers[facet],
              onRight: () => answer(facet, const FacetAnswer.right()),
              onFlag: () async {
                final a = await showFacetTagsSheet(
                  context,
                  card: card,
                  facet: facet,
                  languageName: deck.language.name,
                  current: answers[facet],
                );
                if (a != null) answer(facet, a);
              },
            ),
        const SizedBox(height: 18),
        FilledButton(
          key: ReviewCardView.doneKey,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          ),
          onPressed: ready
              ? () {
                  for (final MapEntry(:key, :value) in shortcutAnswers(
                    applicable,
                    answers,
                  ).entries) {
                    answer(key, value);
                  }
                  onDone();
                }
              : null,
          child: Text(flagged ? l10n.commonDone : l10n.reviewAllGood),
        ),
      ],
    );
  }
}

class _FacetRow extends StatelessWidget {
  const _FacetRow({
    super.key,
    required this.facet,
    required this.deck,
    required this.card,
    required this.placeText,
    required this.answer,
    required this.onRight,
    required this.onFlag,
  });

  final Facet facet;
  final DeckEntry deck;
  final Card card;
  final String placeText;
  final FacetAnswer? answer;
  final VoidCallback onRight;
  final VoidCallback onFlag;

  bool get _hasTick => separatelyConfirmedFacets.contains(facet);

  /// The facets that show their content with no label over it.
  bool get _unlabelled =>
      facet == Facet.word || facet == Facet.meaning || facet == Facet.example;

  String _text(AppLocalizations l10n) => switch (facet) {
    Facet.word => card.target,
    Facet.reading => card.reading ?? '',
    Facet.ipa => card.ipa ?? '',
    Facet.meaning => card.native,
    Facet.example => <String>[
      for (final e in card.examples) e.target,
    ].join('; '),
    Facet.note => <String>[for (final n in card.notes) n.text].join('; '),
    Facet.unitPlacement => placeText,
    Facet.offenceRating => l10n.reviewOffenceMarked,
    Facet.audio => card.target,
  };

  Widget _value(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    switch (facet) {
      case Facet.word:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: TargetText(
            card.target,
            language: deck.language,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            textAlign: TextAlign.start,
            card: card,
          ),
        );
      case Facet.ipa:
        return IpaLine(card.ipa ?? '', textAlign: TextAlign.start);
      case Facet.meaning:
        return Text(card.native, style: theme.textTheme.titleMedium);
      case Facet.example:
        // Every example, so that "right" covers all that is shown.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: <Widget>[
            for (final example in card.examples)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TargetText(
                    example.target,
                    language: deck.language,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    textAlign: TextAlign.start,
                    card: card,
                  ),
                  if (example.reading != null)
                    Text(
                      example.reading!,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(example.native, style: theme.textTheme.bodyMedium),
                ],
              ),
          ],
        );
      case Facet.audio:
        final state = AppScope.of(context);
        return Row(
          spacing: 10,
          children: <Widget>[
            SpeakerIcon(
              onPlay: () => state.speakCard(card, deck.language),
              label: l10n.drillPlay,
            ),
            Flexible(
              child: TargetText(
                card.target,
                language: deck.language,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.start,
                card: card,
              ),
            ),
          ],
        );
      case Facet.note:
        // Every note, so that "right" covers all that is shown.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: <Widget>[
            for (final note in card.notes)
              Text(note.text, style: theme.textTheme.bodyMedium),
          ],
        );
      case Facet.reading:
      case Facet.unitPlacement:
      case Facet.offenceRating:
        return Text(_text(l10n), style: theme.textTheme.bodyMedium);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = facetTitle(l10n, facet);
    final right = answer?.isRight ?? false;
    final flagged = answer?.isFlagged ?? false;
    // A facet that waits for its own tick or flag is outlined.
    final needs = _hasTick && answer == null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!_unlabelled)
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall!.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          _value(context, l10n),
          if (flagged)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final tag in PointerTag.values)
                    if (answer!.tags.contains(tag))
                      _TagChip(label: pointerTagLabel(l10n, tag)),
                ],
              ),
            ),
        ],
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      margin: needs ? const EdgeInsets.symmetric(vertical: 2) : null,
      padding: EdgeInsetsDirectional.only(start: needs ? 10 : 2),
      decoration: needs
          ? BoxDecoration(
              border: Border.all(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            )
          : BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              container: true,
              label: l10n.reviewFacetValue(title, _text(l10n)),
              excludeSemantics: true,
              child: content,
            ),
          ),
          if (_hasTick)
            _FacetButton(
              key: ReviewCardView.tickKey(facet),
              icon: Icons.check,
              hint: l10n.hintRight,
              label: right
                  ? l10n.reviewRightFacetOn(title)
                  : l10n.reviewRightFacet(title),
              on: right,
              fill: scheme.secondaryContainer,
              ink: scheme.onSecondaryContainer,
              onPressed: onRight,
            ),
          _FacetButton(
            key: ReviewCardView.flagKey(facet),
            icon: flagged ? Icons.flag : Icons.flag_outlined,
            hint: l10n.hintFlag,
            label: flagged
                ? l10n.reviewFlagFacetOn(title)
                : l10n.reviewFlagFacet(title),
            on: flagged,
            fill: scheme.tertiaryContainer,
            ink: scheme.onTertiaryContainer,
            onPressed: onFlag,
          ),
        ],
      ),
    );
  }
}

/// A 48 dp icon button: a short hint on a long press, a longer label for the
/// screen reader, and a filled background while [on].
class _FacetButton extends StatelessWidget {
  const _FacetButton({
    super.key,
    required this.icon,
    required this.hint,
    required this.label,
    required this.on,
    required this.fill,
    required this.ink,
    required this.onPressed,
  });

  final IconData icon;
  final String hint;
  final String label;
  final bool on;
  final Color fill;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    excludeSemantics: true,
    onTap: onPressed,
    child: IconButton(
      tooltip: hint,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: on ? fill : null,
        foregroundColor: on ? ink : null,
      ),
      icon: Icon(icon, size: 22),
    ),
  );
}

/// A tag put on a facet, with a flag icon: state is the icon and the name,
/// never colour alone.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            Icon(Icons.flag, size: 14, color: scheme.onTertiaryContainer),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium!.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
