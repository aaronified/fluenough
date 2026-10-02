import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/deck.dart';
import '../../core/models/script_guide.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onClose,
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
        ),
        title: Text(guide.name),
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
            _FeatureRow(feature: feature, language: language),
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
  const _FeatureRow({required this.feature, required this.language});

  final ScriptFeature feature;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Locale(language.code);
    final term = feature.term;
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
                Text(
                  term,
                  locale: locale,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.primary,
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
