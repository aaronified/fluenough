import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// On Today, when the phone recognises the shown language only online and
/// the learner has not allowed it (#233, plan "Plan-Speech-Offline-Alert"):
/// speaking questions in it are left out, and this says so.
///
/// - **A line** under the day's cards, for as long as it lasts, with "Open
///   settings", which goes to the Voices page at that language's card.
/// - **An alert**, once per language (`Settings.hasSpeechAlert`, kept across
///   launches): the first time Today is on screen with the language in that
///   state. "Open settings" does the same; "Not now" closes it. It is
///   recorded when it is shown, so it never comes twice.
///
/// It takes no room when speaking works, is off, or the language is not the
/// shown one.
class SpeechOnlineCard extends StatefulWidget {
  const SpeechOnlineCard({super.key});

  @override
  State<SpeechOnlineCard> createState() => _SpeechOnlineCardState();
}

class _SpeechOnlineCardState extends State<SpeechOnlineCard> {
  /// Whether an alert is up, or about to be, so a rebuild does not queue a
  /// second one.
  bool _alerting = false;

  void _maybeAlert(LanguageInfo language) {
    final state = AppScope.read(context);
    if (_alerting || state.settings.hasSpeechAlert(language.code)) return;
    // Today stays built behind the other tabs and under a drill: the alert
    // waits until it is the page the learner is looking at.
    final onScreen =
        Visibility.of(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!onScreen) return;
    _alerting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppScope.read(context);
      if (state.settings.hasSpeechAlert(language.code)) {
        _alerting = false;
        return;
      }
      state.settings.markSpeechAlerted(language.code);
      final open = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Text(l10n.speechOnlineAlertTitle(language.name)),
            content: Text(l10n.speechOnlineAlertBody(language.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.speechOnlineNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.speechOnlineOpenSettings),
              ),
            ],
          );
        },
      );
      _alerting = false;
      if (open == true && mounted) {
        await AppNavigator.openVoices(context, language: language.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Allowing it online, or the alert's record, is a setting.
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _content(context, state),
    );
  }

  Widget _content(BuildContext context, AppState state) {
    final language = state.speechOnlineOnlyShown;
    if (language == null) return const SizedBox.shrink();
    _maybeAlert(language);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Semantics(
        container: true,
        child: Container(
          key: const ValueKey<String>('speech-online-line'),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.mic_off_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.speechOnlineLine(language.name),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      children: <Widget>[
                        FilledButton.tonal(
                          onPressed: () => AppNavigator.openVoices(
                            context,
                            language: language.code,
                          ),
                          child: Text(l10n.speechOnlineOpenSettings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
