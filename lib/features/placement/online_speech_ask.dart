import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/browser_words.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';

/// Asks whether to recognise [language] online before any audio leaves the
/// device, as the speaking drill does, for Find my level and placement's Say
/// questions (a browser listens online only). [onAllowed] runs once the
/// learner has allowed it, from now on for the language. Declining calls
/// [onDeclined], which leaves Say not tested, never a miss; null hides it.
class OnlineSpeechAsk extends StatelessWidget {
  const OnlineSpeechAsk({
    super.key,
    required this.language,
    required this.onAllowed,
    this.onDeclined,
  });

  final LanguageInfo language;
  final VoidCallback onAllowed;
  final VoidCallback? onDeclined;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        Text(
          onlineAskText(l10n, language.name),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        FilledButton(
          key: const ValueKey<String>('online-speech-allow'),
          onPressed: () {
            AppScope.read(context).settings
                .allowOnlineSpeech(language.code, true);
            onAllowed();
          },
          child: Text(
            l10n.drillOnlineAllow(language.name),
            textAlign: TextAlign.center,
          ),
        ),
        if (onDeclined case final declined?)
          OutlinedButton(
            key: const ValueKey<String>('online-speech-not-now'),
            onPressed: declined,
            child: Text(l10n.drillOnlineNotNow, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
