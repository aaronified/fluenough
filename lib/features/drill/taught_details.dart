import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/settings.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_notes.dart';
import '../review/alike_warning.dart';
import 'drill_session.dart';

/// How [TaughtDetails] shows a word's reading.
enum TaughtReading {
  /// The reading first, as large as the word would be, with the word in its
  /// script smaller under it: a language learned without its alphabet, or
  /// one whose script is not yet expected. Both always show, whatever Show
  /// romanisation says.
  first,

  /// The word in its script, its reading under it, always: the lesson's
  /// teach card.
  always,

  /// The word in its script, its reading under it while Latin-letter readings
  /// is on: a review of a language learned with its alphabet.
  bySetting;

  /// How a review shows the reading of the word [session] asks: reading
  /// first for a language learned without its alphabet (as recognition
  /// does), else under the word as Latin-letter readings says.
  static TaughtReading inReview(DrillSession session) =>
      session.learnsAlphabet ? bySetting : first;
}

/// What a word's lesson showed of it (ADR-0024), laid out as the teach card
/// does: the word and its reading, its meaning, its notes and its first
/// example, 12 apart and centred. Its notes are every one but a pair note
/// ([shownNotes]), whose text is the care note of the warning below.
///
/// The teach card shows all of it. A review shows it again once the
/// question is answered, never before, so that it gives nothing away:
/// leave out the [word] where the question showed it all along, and the
/// [meaning] where it asked for it. A card with no note and no example has
/// neither. With nothing at all to show, this is empty, so keep it off the
/// drill's card then, or the card's spacing leaves a gap.
///
/// A word that sounds or looks like a rude word ends with the warning
/// ([AlikeWarning]), which is why this shows only once the word is shown
/// or answered: seen, heard, spoken and written words alike.
///
/// Put it on the drill's card, which scrolls, not in the frame's fixed
/// foot. It measures like any other child of the card (see `DrillFrame`):
/// the note is padded, not boxed, so that the frame measures it at the
/// width it is laid out at.
class TaughtDetails extends StatelessWidget {
  const TaughtDetails({
    super.key,
    required this.card,
    required this.language,
    required this.reading,
    this.word = true,
    this.wordSize,
    this.wordColor,
    this.meaning = true,
    this.between,
  });

  final Card card;
  final LanguageInfo language;

  /// How the card's reading shows, if it has one.
  final TaughtReading reading;

  /// Whether to show the word and its reading.
  final bool word;

  /// The word's size at a card text scale of 1, or null for the big text
  /// of the teach card, sized by its length.
  final double? wordSize;

  /// The word's colour, or null for the card's own.
  final Color? wordColor;

  /// Whether to show the meaning.
  final bool meaning;

  /// Between the word and its meaning, and the note: the speaker, which the
  /// teach card has there. Keep its key stable, so that it does not play
  /// again.
  final Widget? between;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final settings = state.settings;
    final warnings = AlikeWarning.forCard(state, card, language);
    // Live, as the reading's line follows Latin-letter readings.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final notes = shownNotes(card);
        final children = <Widget>[
          if (word) ..._word(theme, showReading: _showsReading(settings)),
          if (meaning)
            Text(
              card.native,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
          ?between,
          // Padding, not a max-width box: DrillFrame measures the card's
          // intrinsic height, and a ConstrainedBox reports its child's
          // height at the full width, so wrapped notes would overflow.
          // 19 each side is the design's 280 on a phone's 318 card.
          for (final note in notes)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 19),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontSize: 15,
                  height: 22 / 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (card.examples.isNotEmpty)
            _Example(example: card.examples.first, language: language),
          ...warnings,
        ];
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: children,
        );
      },
    );
  }

  bool _showsReading(SettingsNotifier settings) => switch (reading) {
    TaughtReading.first || TaughtReading.always => true,
    TaughtReading.bySetting => settings.showRomanisation,
  };

  /// The word, or its reading first, and its reading under it when it shows.
  List<Widget> _word(ThemeData theme, {required bool showReading}) {
    final reading = card.reading;
    final size = wordSize;
    if (reading != null && this.reading == TaughtReading.first) {
      return <Widget>[
        ReadingFirst(
          reading: reading,
          target: card.target,
          language: language,
          fontSize: size ?? 48,
          color: wordColor,
        ),
      ];
    }
    return <Widget>[
      if (size == null)
        TargetText.hero(card.target, language: language, color: wordColor)
      else
        TargetText.card(
          card.target,
          language: language,
          fontSize: size,
          color: wordColor,
        ),
      if (reading != null && showReading)
        Text(
          reading,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge!.copyWith(
            fontSize: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ];
  }
}

/// An example sentence under the meaning: the target sentence, bold, over
/// its translation.
class _Example extends StatelessWidget {
  const _Example({required this.example, required this.language});

  final CardExample example;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context)!.drillExample,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TargetText.card(
              example.target,
              language: language,
              fontSize: 16,
              color: scheme.onSurface,
            ),
            const SizedBox(height: 2),
            Text(
              example.native,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
