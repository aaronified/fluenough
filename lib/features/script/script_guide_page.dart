import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/deck.dart';
import '../../core/models/script_guide.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';

/// How a script works, opened from a script deck's Tips (#30, ADR-0016).
/// The drill shows the same guide once, before a language's first script
/// card, with Start in place of Done.
class ScriptGuidePage extends StatelessWidget {
  const ScriptGuidePage({super.key, required this.languageCode});

  /// The language whose guide to show, by code.
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    LanguageInfo? language;
    for (final candidate in state.languages) {
      if (candidate.code == languageCode) language = candidate;
    }
    final guide = language == null ? null : state.scriptGuideFor(language);
    void close() => Navigator.of(context).maybePop();
    if (language == null || guide == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: close,
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close),
          ),
          actions: const <Widget>[ReportButton()],
        ),
      );
    }
    return ScriptGuideView(
      guide: guide,
      language: language,
      actionLabel: l10n.commonDone,
      onAction: close,
      onClose: close,
    );
  }
}

/// The guide itself: a paragraph, then each feature with its example drawn
/// large, its name and its term in the language, what to look for, and the
/// letters that share it. Modelled on Duolingo's script tips
/// (docs/market-research.md, "Script lessons").
///
/// Only the term has a reading, under Show romanisation as on a card. The
/// example and the letters are shapes to look at, and the text gives a
/// sound where it matters, as a card's notes do.
class ScriptGuideView extends StatelessWidget {
  const ScriptGuideView({
    super.key,
    required this.guide,
    required this.language,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  final ScriptGuide guide;
  final LanguageInfo language;

  /// The button at the foot: Start before the first letters, Done from Tips.
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onClose,
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
        ),
        title: Text(guide.name),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: <Widget>[
          Text(
            guide.intro,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final feature in guide.features) ...<Widget>[
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) => _FeatureRow(
                feature: feature,
                language: language,
                showReading: settings.showRomanisation,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          ),
          onPressed: onAction,
          child: Text(actionLabel, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.language,
    required this.showReading,
  });

  final ScriptFeature feature;
  final LanguageInfo language;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final term = feature.term;
    final reading = feature.reading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TargetText(
                feature.example,
                language: language,
                fontSize: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(feature.name, style: theme.textTheme.titleMedium),
              ),
              if (term != null)
                TargetText(
                  term,
                  language: language,
                  fontSize: theme.textTheme.bodyLarge!.fontSize!,
                  fontWeight: FontWeight.w500,
                  color: scheme.primary,
                  textAlign: TextAlign.start,
                ),
              if (showReading && reading != null)
                Text(
                  reading,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              Text(feature.text, style: theme.textTheme.bodyLarge),
              if (feature.letters.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final letter in feature.letters)
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TargetText(
                          letter,
                          language: language,
                          fontSize: 22,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
