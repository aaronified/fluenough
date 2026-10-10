import 'package:flutter/material.dart';

import '../../core/models/deck.dart';
import '../../core/sound/sound_check.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'drill_session.dart';

/// Why a listen gave nothing to grade, in words: under the microphone
/// before an answer, and under the card after a "Try again".
String unheardMessage(
  AppLocalizations l10n,
  SpeechFailure failure,
  LanguageInfo language,
) => switch (failure) {
  SpeechFailure.noMatch => l10n.drillUnheardNoMatch,
  SpeechFailure.permissionDenied => l10n.drillUnheardPermission,
  SpeechFailure.noRecogniser => l10n.drillUnheardNoRecogniser,
  SpeechFailure.unsupported => l10n.drillUnheardUnsupported(language.name),
  SpeechFailure.network => l10n.drillUnheardNetwork,
  SpeechFailure.notOnDevice || SpeechFailure.other => l10n.drillUnheardOther,
};

/// Under an answered speaking card (#231): what the last "Try again" came
/// to, or why it heard nothing, and "Hear yourself", which records the
/// learner and plays it back, then the voice.
///
/// The result of a try again shows in the feedback banner; this says that
/// it was practice, and that the first answer is the one that counts.
class SpeakingPractice extends StatelessWidget {
  const SpeakingPractice({super.key, required this.session});

  final DrillSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = session.deck.language;
    final retried = session.retried;
    final unheard = session.unheard;
    final self = session.hearingSelf;
    final selfFailure = session.selfFailure;
    final hint = theme.textTheme.bodyLarge!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final error = theme.textTheme.bodyLarge!.copyWith(color: scheme.error);

    final String? status;
    final TextStyle statusStyle;
    if (session.hearing) {
      status = l10n.drillHearingHint;
      statusStyle = hint;
    } else if (unheard != null) {
      status = unheardMessage(l10n, unheard, language);
      statusStyle = error;
    } else if (retried != null) {
      status = retried.graded?.outcome.isCorrect ?? false
          ? l10n.drillRetryPassed
          : l10n.drillRetryPractice;
      statusStyle = hint;
    } else {
      status = null;
      statusStyle = hint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (status != null) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: statusStyle,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Center(
          child: TextButton.icon(
            onPressed: session.hearing || self != SelfTake.idle
                ? null
                : () {
                    if (!session.soundOn) {
                      showAppSnackBar(context, l10n.speakerSoundOff);
                      return;
                    }
                    session.hearSelf();
                  },
            icon: Icon(switch (self) {
              SelfTake.idle => Icons.record_voice_over_outlined,
              SelfTake.recording => Icons.mic,
              SelfTake.playing => Icons.volume_up_outlined,
            }),
            label: Text(switch (self) {
              SelfTake.idle => l10n.drillHearYourself,
              SelfTake.recording => l10n.drillHearYourselfRecording,
              SelfTake.playing => l10n.drillHearYourselfPlaying,
            }, textAlign: TextAlign.center),
          ),
        ),
        if (selfFailure != null)
          Semantics(
            liveRegion: true,
            child: Text(
              switch (selfFailure) {
                RecordFailure.refused => l10n.drillHearYourselfRefused,
                RecordFailure.silent => l10n.drillHearYourselfSilent,
                RecordFailure.failed => l10n.drillHearYourselfFailed,
              },
              textAlign: TextAlign.center,
              style: error,
            ),
          ),
      ],
    );
  }
}
