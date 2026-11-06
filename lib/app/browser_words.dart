import 'package:flutter/foundation.dart' show kIsWeb;

import '../l10n/app_localizations.dart';

/// Whether the words about the microphone and the speech recogniser say
/// "browser" and name a browser's way to allow the microphone, rather than
/// "phone" and Android's Settings. True in the web build. A test sets it to
/// check both.
bool browserWords = kIsWeb;

/// Speaking: the microphone permission was refused.
String microphoneRefusedText(AppLocalizations l10n) =>
    browserWords ? l10n.drillUnheardPermissionWeb : l10n.drillUnheardPermission;

/// Speaking: there is no speech recogniser to hear the learner.
String noRecogniserText(AppLocalizations l10n) => browserWords
    ? l10n.drillUnheardNoRecogniserWeb
    : l10n.drillUnheardNoRecogniser;

/// The SnackBar when Speaking is switched on and there is no recogniser.
String speakingNoRecogniserText(AppLocalizations l10n) => browserWords
    ? l10n.settingsSpeakingNoRecogniserWeb
    : l10n.settingsSpeakingNoRecogniser;

/// The sound check's introduction.
String soundCheckBodyText(AppLocalizations l10n) =>
    browserWords ? l10n.onboardingSoundBodyWeb : l10n.onboardingSoundBody;

/// The sound check: recorded fine but no recogniser.
String soundCheckNoRecogniserText(AppLocalizations l10n) => browserWords
    ? l10n.onboardingSoundNoRecogniserWeb
    : l10n.onboardingSoundNoRecogniser;

/// The sound check: the microphone was refused twice and is not asked again.
String soundCheckRefusedForGoodText(AppLocalizations l10n) => browserWords
    ? l10n.onboardingSoundRefusedForGoodWeb
    : l10n.onboardingSoundRefusedForGood;

/// Speaking: asks before audio goes online to recognise [language].
String onlineAskText(AppLocalizations l10n, String language) => browserWords
    ? l10n.drillOnlineAskWeb(language)
    : l10n.drillOnlineAsk(language);
