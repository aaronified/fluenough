import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/grading/self_grade.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'going_on.dart';
import 'set_drill.dart';
import 'rating_buttons.dart';
import 'taught_details.dart';
import '../decks/ipa_info_dot.dart';

/// Recognition: the target, big, with its reading and, where the phone has
/// a voice, its speaker; "Show answer"; then the meaning, the note and an
/// example, and the four self-ratings in one row, or a swipe, which is Okay.
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
    final lines = readingLines(
      context,
      reading: card.reading,
      ipa: card.ipa,
      target: card.target,
      showReading: session.readsFirst || settings.showRomanisation,
    );
    final reading = lines.reading;

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
      // A swipe on the answer page, or the end-edge chevron, is Okay, as
      // tapping Okay is (owner, 2026-10-29). Gone back to, it only shows the
      // card again.
      going: goingOn(
        session,
        answered: revealed,
        onNext: () => session.rate(SelfGrade.good),
        // The ratings are the way on while the card is live.
        pinned: session.readOnly,
      ),
      card: <Widget>[
        if (reading != null && session.readsFirst)
          ReadingFirst(
            reading: reading,
            target: card.target,
            language: language,
            fontSize: 48,
            ipaFont: lines.swapped,
            readingWrapper: (r) =>
                ReadingWithInfo(reading: r, card: card, swapped: lines.swapped),
          )
        else
          TargetText.hero(card.target, language: language, card: card),
        if (reading != null && !session.readsFirst)
          ReadingWithInfo(
            swapped: lines.swapped,
            card: card,
            reading: ReadingText(
              reading,
              swapped: lines.swapped,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                fontSize: 18,
                height: 24 / 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        // How it is said: the word is shown, so this gives nothing away.
        if (lines.ipa case final ipa?)
          IpaWithInfo(ipa, card: card, fontSize: 16),
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
              borderRadius: BorderRadius.circular(AppRadii.mark),
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
        ...answeredSetList(context, session, answered: revealed),
      ],
      feedback: alreadyAnswered(context, session),
      actions: session.readOnly
          ? const <Widget>[]
          : revealed
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
