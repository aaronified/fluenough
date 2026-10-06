import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import 'answer_feedback.dart';
import 'cant_now.dart';
import 'drill_session.dart';
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
/// Once answered, the card shows what the word's lesson showed
/// ([TaughtDetails]). Build one per card (key it by the card's position).
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
      card: _card(context, card, language),
      belowCard: answer != null ? null : _microphone(context, language),
      feedback: answer == null
          ? null
          : AnswerFeedback(
              answer: answer,
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
        style: theme.textTheme.displaySmall!.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      if (answered)
        // The meaning is the prompt above. Only now: hearing it first would
        // be saying it after the phone.
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          wordSize: 28,
          wordColor: scheme.primary,
          meaning: false,
          between: session.canPlay
              ? Speaker(onPlay: session.play, playing: session.playing)
              : null,
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
            switch (unheard) {
              SpeechFailure.noMatch => l10n.drillUnheardNoMatch,
              SpeechFailure.permissionDenied => l10n.drillUnheardPermission,
              SpeechFailure.noRecogniser => l10n.drillUnheardNoRecogniser,
              SpeechFailure.unsupported => l10n.drillUnheardUnsupported(
                language.name,
              ),
              SpeechFailure.network => l10n.drillUnheardNetwork,
              SpeechFailure.notOnDevice ||
              SpeechFailure.other => l10n.drillUnheardOther,
            },
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
    return <Widget>[
      FilledButton(
        onPressed: session.next,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.primaryButton),
          textStyle: theme.textTheme.titleMedium!.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(l10n.commonContinue),
      ),
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
    );
  }
}
