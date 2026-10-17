import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../profiles/spoken_languages_picker.dart';
import 'onboarding_step.dart';

/// The first launch's question: the languages the learner already speaks
/// (#53). Not the ones they want to learn, which #117 asks next.
final OnboardingStep spokenStep = OnboardingStep(
  id: 'spoken',
  asks: true,
  blocked: (answers, l10n) =>
      answers.spoken.isEmpty ? l10n.onboardingSpokenNeedOne : null,
  content: (context, at) {
    final l10n = AppLocalizations.of(context)!;
    return SpokenLanguagesPicker(
      initial: at.answers.spoken,
      choices: at.choices,
      onChanged: (ranked) => at.answers.spoken = ranked,
      readsScript: at.answers.scripts,
      onScriptChanged: at.answers.setReadsScript,
      header: QuestionHeading(
        title: l10n.onboardingSpokenTitle,
        body: l10n.onboardingSpokenBody,
      ),
      footer: PickerNote(
        icon: Icons.lock_outline,
        text: l10n.onboardingSpokenPrivacy(
          l10n.navSettings,
          l10n.settingsSpoken,
        ),
      ),
    );
  },
);

/// A question's title and what the answer is for, on the 24 px line. It
/// scrolls with the answers. The title grows at most one and a half times,
/// as Android's own scaling does for large type, so the first answers stay
/// in view at the largest text size.
class QuestionHeading extends StatelessWidget {
  const QuestionHeading({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            namesRoute: true,
            child: Text(
              title,
              style: theme.textTheme.headlineMedium,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
