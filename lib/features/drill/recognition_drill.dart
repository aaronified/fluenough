import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'rating_buttons.dart';
import 'taught_details.dart';

/// Recognition: the target, big, with its reading and, where the phone has
/// a voice, its speaker; "Show answer"; then the meaning, the note and an
/// example, and the four self-ratings.
///
/// What it shows once revealed is [TaughtDetails], as the other questions
/// show it once answered.
///
/// Design screens `drill-recognition` and `drill-recognition-revealed`.
class RecognitionDrill extends StatelessWidget {
  const RecognitionDrill({
    super.key,
    required this.session,
    required this.onClose,
  });

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = AppScope.read(context).settings;
    final card = session.item.card;
    final language = session.deck.language;
    final revealed = session.phase == DrillPhase.revealed;
    final reading = card.reading;

    return DrillFrame(
      skill: session.skill,
      deckName: session.recorded || session.revising
          ? session.deck.deck.name
          : l10n.numbersPracticeTitle,
      position: session.position,
      total: session.total,
      reportDetail: '${session.item.card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      card: <Widget>[
        if (reading != null && !session.learnsAlphabet)
          ReadingFirst(
            reading: reading,
            target: card.target,
            language: language,
            fontSize: 48,
          )
        else
          TargetText.hero(card.target, language: language),
        if (reading != null &&
            settings.showRomanisation &&
            session.learnsAlphabet)
          Text(
            reading,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 18,
              height: 24 / 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        // From the start: hearing the word gives nothing away. Keyed, so
        // that showing the answer does not play it again.
        if (session.canPlay)
          Speaker(
            key: const ValueKey<String>('speaker'),
            onPlay: session.play,
            playing: session.playing,
          ),
        if (revealed) ...<Widget>[
          Container(
            width: 64,
            height: 4,
            margin: const EdgeInsetsDirectional.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // The word is on the card already: the rest of what its lesson
          // showed, from the meaning down.
          TaughtDetails(
            card: card,
            language: language,
            reading: TaughtReading.inReview(session),
            word: false,
          ),
        ],
      ],
      actions: revealed
          ? <Widget>[
              Text(
                l10n.drillRatePrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              RatingButtons(
                intervalFor: session.recorded || session.recordsRevision
                    ? session.intervalFor
                    : null,
                onRate: session.rate,
              ),
            ]
          : <Widget>[
              FilledButton(
                onPressed: session.reveal,
                style: AppButtonStyles.tall(context),
                child: Text(l10n.drillShowAnswer),
              ),
            ],
    );
  }
}
