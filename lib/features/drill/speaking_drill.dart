import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/target_text.dart';
import 'answer_feedback.dart';
import 'cant_now.dart';
import 'drill_session.dart';
import 'going_on.dart';
import 'say_result.dart';
import 'set_drill.dart';
import 'speaking_practice.dart' show unheardMessage;
import 'taught_details.dart';

/// Speaking (#89, ADR-0014): the meaning ("Say it in Hindi"), a microphone
/// button, and what the phone's speech recogniser heard, graded like a
/// typed answer.
///
/// Nothing heard, or a recogniser that failed, records nothing and asks
/// again, or offers to skip the card when saying it again cannot help. A
/// language the phone cannot recognise by itself asks before going online,
/// for that language from then on, or not now, which skips its speaking
/// cards for the rest of the session unrecorded.
///
/// Once answered, the card shows the word and its reading, and under it what
/// the phone heard and the learner's own recording ([SayResult], #509). A
/// wrong or almost-right answer, or "Don't know", offers "Try again" as often
/// as the learner likes, each try graded in the banner but never recorded.
/// Going on is the swipe and the chevron. Build one per card (key it by the
/// card's position).
class SpeakingDrill extends StatelessWidget {
  const SpeakingDrill({
    super.key,
    required this.session,
    required this.onClose,
  });

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = session.item.card;
    final language = session.deck.language;
    final answer = session.answer;
    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${session.item.card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      going: goingOn(session, answered: answer != null),
      // The card over a result: less padding, for the rows under it.
      snugCard: answer != null,
      card: <Widget>[
        ..._card(context, card, language),
        ...answeredSetList(context, session, answered: answer != null),
      ],
      belowCard: answer != null
          ? SayResult.parts(context, session)
          : _microphone(context, language),
      feedback: answer == null
          ? null
          : alreadyAnswered(context, session) ??
                AnswerFeedback(
                  // A new banner for each try again, so that it is announced.
                  key: ValueKey<int>(session.retries),
                  answer: session.retried ?? answer,
                  card: card,
                  expected: session.acceptedAnswers.first,
                  transliterating: false,
                  language: language,
                  spoken: true,
                ),
      actions: _actions(context, l10n),
    );
  }

  List<Widget> _card(BuildContext context, Card card, LanguageInfo language) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = session.answer != null;
    return <Widget>[
      Text(
        l10n.drillSayIn(language.name),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      Text(
        card.native,
        textAlign: TextAlign.center,
        style:
            (answered
                    ? theme.textTheme.headlineSmall!
                    : theme.textTheme.displaySmall!)
                .copyWith(fontWeight: FontWeight.w600),
      ),
      // The word, once answered: only now, hearing it first would be saying
      // it after the phone. Its sound is the Word button under the card.
      if (answered) ..._answerWord(context, card, language),
    ];
  }

  /// The answered card's word and its reading, under a rule.
  List<Widget> _answerWord(
    BuildContext context,
    Card card,
    LanguageInfo language,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = readingLines(
      context,
      reading: card.reading,
      ipa: card.ipa,
      target: card.target,
    );
    return <Widget>[
      Container(
        width: 64,
        height: 4,
        margin: const EdgeInsetsDirectional.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(AppRadii.mark),
        ),
      ),
      TargetText.card(
        card.target,
        language: language,
        fontSize: 22,
        color: scheme.primary,
        fontWeight: FontWeight.w500,
        card: card,
      ),
      if (lines.reading case final reading?)
        ReadingText(
          reading,
          swapped: lines.swapped,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge!.copyWith(
            fontSize: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
      // What the word's lesson showed under it: its note, its bases, its
      // example and its warnings (the shell's mockup draws the word and its
      // reading and is silent on these, which the answered card always had).
      TaughtDetails(
        card: card,
        language: language,
        reading: TaughtReading.inReview(session),
        word: false,
        meaning: false,
      ),
    ];
  }

  List<Widget> _microphone(BuildContext context, LanguageInfo language) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hearing = session.hearing;
    final unheard = session.unheard;
    if (unheard == SpeechFailure.notOnDevice) {
      return <Widget>[_askOnline(context, language)];
    }
    return <Widget>[
      Center(
        child: _MicrophoneButton(
          hearing: hearing,
          onPressed: hearing ? session.stopListening : session.listen,
        ),
      ),
      const SizedBox(height: 12),
      // Why nothing was graded takes the hint's place, so it adds no height
      // and stays in view above the fixed buttons.
      if (unheard == null || hearing)
        Text(
          hearing ? l10n.drillHearingHint : l10n.drillSpeakHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        )
      else ...<Widget>[
        Semantics(
          liveRegion: true,
          child: Text(
            unheardMessage(l10n, unheard, language, session.networkWhy),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(color: scheme.error),
          ),
        ),
        // Saying it again will not help these.
        if (unheard == SpeechFailure.permissionDenied ||
            unheard == SpeechFailure.noRecogniser ||
            unheard == SpeechFailure.unsupported) ...<Widget>[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: session.skipUnheard,
              child: Text(l10n.drillSkipCard, textAlign: TextAlign.center),
            ),
          ),
        ],
      ],
    ];
  }

  /// The phone cannot recognise [language] by itself: going online is the
  /// learner's choice, per language.
  Widget _askOnline(BuildContext context, LanguageInfo language) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = AppScope.read(context).settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.drillOnlineAsk(language.name),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            settings.allowOnlineSpeech(language.code, true);
            session.listen();
          },
          child: Text(
            l10n.drillOnlineAllow(language.name),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: session.skipUnheard,
          child: Text(l10n.drillOnlineNotNow, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final answer = session.answer;
    if (answer == null) {
      return <Widget>[
        CantNowButton(session: session),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: session.hearing ? null : session.dontKnow,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, AppSizes.primaryButton),
            textStyle: theme.textTheme.titleMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(l10n.drillDontKnow, textAlign: TextAlign.center),
        ),
      ];
    }
    // Answered: Try again where it is offered; going on is the swipe and the
    // chevron, and a card gone back to has nothing to do.
    if (session.readOnly || !session.canRetry) return const <Widget>[];
    return <Widget>[
      if (session.canRetry) ...<Widget>[
        OutlinedButton.icon(
          onPressed: session.hearing
              ? session.stopListening
              : session.hearingSelf == SelfTake.idle
              ? session.retry
              : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, AppSizes.primaryButton),
            textStyle: theme.textTheme.titleMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: Icon(session.hearing ? Icons.stop_rounded : Icons.mic),
          label: Text(
            session.hearing ? l10n.drillStopHearing : l10n.drillTryAgain,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ];
  }
}

/// A large round `primary` button with a microphone, which becomes a stop
/// button while the phone listens.
class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton({required this.hearing, required this.onPressed});

  final bool hearing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: hearing ? l10n.drillStopHearing : l10n.drillSpeak,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 112,
        child: Material(
          color: hearing ? scheme.tertiary : scheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Hint(
            message: hearing ? l10n.hintStop : l10n.hintSpeak,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                hearing ? Icons.stop_rounded : Icons.mic,
                size: 48,
                color: hearing ? scheme.onTertiary : scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
