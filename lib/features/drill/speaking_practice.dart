import '../../core/models/deck.dart';
import '../../core/network/network_probe.dart';
import '../../core/speech/speech_engine.dart';
import '../../app/browser_words.dart';
import '../../l10n/app_localizations.dart';

/// Why a listen gave nothing to grade, in words: under the microphone
/// before an answer, and under the card after a "Try again".
String unheardMessage(
  AppLocalizations l10n,
  SpeechFailure failure,
  LanguageInfo language, [
  NetworkDiagnosis? why,
]) => switch (failure) {
  SpeechFailure.noMatch => l10n.drillUnheardNoMatch,
  SpeechFailure.permissionDenied => microphoneRefusedText(l10n),
  SpeechFailure.noRecogniser => noRecogniserText(l10n),
  SpeechFailure.unsupported => l10n.drillUnheardUnsupported(language.name),
  SpeechFailure.network => switch (why) {
    null => l10n.drillUnheardNetwork,
    NetworkDiagnosis.offline => l10n.drillNetworkOffline,
    NetworkDiagnosis.githubBlocked => l10n.drillNetworkGithubBlocked,
    NetworkDiagnosis.googleUnreachable => l10n.drillNetworkGoogleUnreachable,
    NetworkDiagnosis.serviceFailed => l10n.drillNetworkServiceFailed,
  },
  SpeechFailure.notOnDevice || SpeechFailure.other => l10n.drillUnheardOther,
};
