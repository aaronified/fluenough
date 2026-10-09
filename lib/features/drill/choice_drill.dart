import 'package:flutter/material.dart' hide Card;

import '../../app/settings.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/scheduling/ask.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'cant_now.dart';
import 'choice_tile.dart';
import 'drill_session.dart';
import 'taught_details.dart';

/// Multiple choice (ADR-0024), recorded as soon as an option is picked:
///
/// - [Ask.chooseMeaning]: the word, and its meaning to choose. Recognition.
/// - [Ask.chooseWord]: the meaning, and its word to choose. Production.
/// - [Ask.hearAndChoose]: the word played, and the word to choose.
///   Listening, in script practice.
/// - [Ask.hearMeaning]: the word played, and its meaning to choose. Hear
///   (ADR-0034).
///
/// Words to choose show their reading first until the script is expected
/// of the learner, as typed answers start in Latin letters then. The word
/// has its speaker from the start when it is shown, and once answered when
/// it is chosen. Once answered, the card shows what the word's lesson showed
/// ([TaughtDetails]). Build one per card (key it by the card's position).
class ChoiceDrill extends StatelessWidget {
  const ChoiceDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  bool get _hears =>
      session.ask == Ask.hearAndChoose || session.ask == Ask.hearMeaning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = session.item.card;
    final language = session.deck.language;
    final ask = session.ask;
    final picked = session.picked;
    final answered = picked != null;
    final right = picked != null && session.isRight(picked);

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      needsSound: _hears && !answered,
      card: switch (ask) {
        Ask.chooseMeaning => _meaningCard(context, card, language, answered),
        Ask.hearAndChoose ||
        Ask.hearMeaning => _heardCard(context, card, language, answered),
        _ => _wordCard(context, card, language, answered),
      },
      belowCard: <Widget>[
        Semantics(
          container: true,
          label: l10n.drillOptionsGroup,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (place, option) in session.options.indexed) ...[
                if (place > 0) const SizedBox(height: 10),
                ChoiceTile(
                  right: answered && session.isRight(option),
                  chosen: picked?.id == option.id,
                  answered: answered,
                  onTap: () => session.pick(option),
                  label: (style) => ask == Ask.hearMeaning
                      ? _OptionMeaning(card: option, style: style)
                      : ask.choosesMeaning
                      ? Text(option.native, style: style)
                      : _OptionWord(
                          card: option,
                          language: language,
                          readingFirst: !session.expectsScript,
                          style: style,
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
      feedback: !answered
          ? null
          : right
          ? FeedbackBanner(
              kind: FeedbackKind.correct,
              title: l10n.feedbackCorrect,
            )
          : FeedbackBanner(
              kind: FeedbackKind.wrong,
              title: l10n.feedbackWrong,
              detail: l10n.feedbackAnswer(ask.optionOf(card)),
              quotes: <String>[if (!ask.choosesMeaning) card.target],
              language: ask.choosesMeaning ? null : language,
            ),
      actions: answered
          ? <Widget>[
              FilledButton(
                onPressed: session.next,
                style: AppButtonStyles.tall(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text(l10n.commonContinue)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 22),
                  ],
                ),
              ),
            ]
          : <Widget>[if (_hears) CantNowButton(session: session)],
    );
  }

  /// The word, as recognition shows it; once answered, its meaning.
  List<Widget> _meaningCard(
    BuildContext context,
    Card card,
    LanguageInfo language,
    bool answered,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = card.reading;
    return <Widget>[
      Text(
        l10n.drillChooseMeaning,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      if (reading != null && !session.learnsAlphabet)
        ReadingFirst(
          reading: reading,
          target: card.target,
          language: language,
          fontSize: 48,
        )
      else ...<Widget>[
        TargetText.hero(card.target, language: language),
        if (reading != null)
          Text(
            reading,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
      // From the start: the word is shown anyway.
      ?_speaker(),
      // The word is on the card already: what its lesson showed under it.
      if (answered)
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          word: false,
        ),
    ];
  }

  /// The word's speaker, where the phone has a voice. Keyed, so that what
  /// comes after it does not make it play again.
  Widget? _speaker() => session.canPlay
      ? Speaker(
          key: const ValueKey<String>('speaker'),
          onPlay: session.play,
          playing: session.playing,
        )
      : null;

  /// The meaning; once answered, the word.
  List<Widget> _wordCard(
    BuildContext context,
    Card card,
    LanguageInfo language,
    bool answered,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return <Widget>[
      Text(
        l10n.drillChooseWord(language.name),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      if (card.picture != null) CardPicture(card, size: 88),
      Text(
        card.native,
        textAlign: TextAlign.center,
        style: theme.textTheme.displaySmall!.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      // Only once answered: hearing the word would give the answer away.
      // The meaning is the prompt above.
      if (answered)
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          wordSize: 28,
          wordColor: scheme.primary,
          meaning: false,
          between: _speaker(),
        ),
    ];
  }

  /// The play button and Slower; once answered, the meaning.
  List<Widget> _heardCard(
    BuildContext context,
    Card card,
    LanguageInfo language,
    bool answered,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slower = session.slower;
    return <Widget>[
      Speaker(onPlay: session.play, playing: session.playing, size: 136),
      Text(
        session.ask == Ask.hearMeaning
            ? l10n.drillChooseHeardMeaning
            : l10n.drillChooseHeard,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      FilterChip(
        label: Text(l10n.drillSlower(SettingsNotifier.slowerFactor)),
        selected: slower,
        onSelected: (_) => session.toggleSlower(),
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: slower
            ? BorderSide(color: scheme.secondaryContainer)
            : BorderSide(color: scheme.outline),
        labelStyle: theme.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
          color: slower ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      if (answered)
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          wordSize: 28,
          wordColor: scheme.primary,
        ),
    ];
  }
}

/// A word to choose: in its script, or its reading over it.
class _OptionWord extends StatelessWidget {
  const _OptionWord({
    required this.card,
    required this.language,
    required this.readingFirst,
    required this.style,
  });

  final Card card;
  final LanguageInfo language;
  final bool readingFirst;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final reading = card.reading;
    final word = TargetText(
      card.target,
      language: language,
      fontSize: readingFirst && reading != null ? 14 : style.fontSize! + 4,
      color: readingFirst && reading != null
          ? style.color!.withValues(alpha: 0.75)
          : style.color,
      textAlign: TextAlign.start,
    );
    if (!readingFirst || reading == null) return word;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(reading, style: style),
        word,
      ],
    );
  }
}

/// A meaning Hear offers, with its picture where the word has one
/// (ADR-0034).
class _OptionMeaning extends StatelessWidget {
  const _OptionMeaning({required this.card, required this.style});

  final Card card;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final meaning = Text(card.native, style: style);
    if (card.picture == null) return meaning;
    return Row(
      children: <Widget>[
        CardPicture(card, size: 32),
        const SizedBox(width: 12),
        Expanded(child: meaning),
      ],
    );
  }
}
