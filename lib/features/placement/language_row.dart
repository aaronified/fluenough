import 'package:flutter/material.dart';

import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// A course's stage as the Alpha, Beta or Complete tag says it, with what a
/// screen reader reads for it; null for no course. A course whose path has no
/// B1 plan is Alpha without claiming that A1 is unfinished ([planned]).
({String text, String label})? stageTag(
  AppLocalizations l10n,
  CourseStage? stage, {
  required bool planned,
}) => switch (stage) {
  CourseStage.alpha => (
    text: l10n.pickerAlpha,
    label: planned ? l10n.pickerAlphaLabel : l10n.pickerAlphaUnplannedLabel,
  ),
  CourseStage.beta => (text: l10n.pickerBeta, label: l10n.pickerBetaLabel),
  CourseStage.complete => (
    text: l10n.pickerComplete,
    label: l10n.pickerCompleteLabel,
  ),
  null => null,
};

/// The Alpha, Beta or Complete tag.
class StageTag extends StatelessWidget {
  const StageTag({super.key, required this.tag});

  final ({String text, String label}) tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: tag.label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Text(
            tag.text,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Telugu · తెలుగు", the own name in its language, and the search marked in
/// both.
TextSpan languageNames(
  BuildContext context,
  CatalogLanguage language, {
  String query = '',
}) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  List<TextSpan> marked(String text, {Locale? locale}) {
    final match = LanguageSearch.find(text, query);
    if (match == null) return <TextSpan>[TextSpan(text: text, locale: locale)];
    return <TextSpan>[
      TextSpan(text: text.substring(0, match.start), locale: locale),
      TextSpan(
        text: text.substring(match.start, match.end),
        locale: locale,
        style: TextStyle(
          backgroundColor: scheme.primaryContainer,
          color: scheme.onPrimaryContainer,
        ),
      ),
      TextSpan(text: text.substring(match.end), locale: locale),
    ];
  }

  final own = language.ownName;
  return TextSpan(
    children: <TextSpan>[
      ...marked(language.name),
      if (own != null && own != language.name) ...<TextSpan>[
        TextSpan(text: l10n.pickerNameSeparator),
        ...marked(own, locale: Locale(language.code)),
      ],
    ],
  );
}

/// One language in Languages I'm learning (#626, the approved mockup
/// `docs/mockups/languages-learning.html`): a plain row with its names, its
/// Alpha, Beta or Complete tag and the learner's own progress, which opens
/// the language's sheet. A language the learner learns, or has chosen, shows
/// a tick and, when it is on the phone, its row of buttons ([actions]);
/// [below] holds what comes under it, such as a download's bar.
class LanguageRow extends StatelessWidget {
  const LanguageRow({
    super.key,
    required this.language,
    required this.chosen,
    required this.onTap,
    this.progress,
    this.you,
    this.youWords,
    this.query = '',
    this.actions,
    this.below = const <Widget>[],
    this.needsApp,
  });

  final CatalogLanguage language;

  /// Whether it is learned or newly chosen.
  final bool chosen;
  final VoidCallback onTap;

  /// The course as the learner would take it, from its native language.
  final B1Progress? progress;

  /// The learner's own progress toward B1, 0–1, where its course has a B1
  /// plan; else [youWords], the words learned. Both null where they do not
  /// learn it.
  final double? you;
  final int? youWords;

  /// The search, to mark in the names.
  final String query;

  /// The row of buttons under it, for a language on the phone.
  final Widget? actions;

  /// More under the row: a download, a notice.
  final List<Widget> below;

  /// The app version this app must be updated to before the language can be
  /// downloaded (ADR-0052). Then the row is greyed, says so, and [onTap]
  /// opens where the app is downloaded.
  final String? needsApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final planned = progress?.hasPlan ?? false;
    final tag = stageTag(l10n, progress?.stage, planned: planned);
    final youText = switch ((you, youWords)) {
      (final share?, _) => l10n.pickerYouShort(B1Progress.percentOf(share)),
      (_, final words?) => l10n.pickerYouWords(words),
      _ => null,
    };
    final names = <String>[
      language.name,
      if (language.ownName case final own?
          when own.isNotEmpty && own != language.name)
        own,
    ];
    final label = <String>[
      names.join(l10n.commonListSeparator),
      ?tag?.label,
      if (progress != null && planned) l10n.pickerWritten(progress.percent),
      ?youText,
      if (needsApp case final version?) l10n.appUpdateNeeded(version),
    ].join(l10n.commonListSeparator);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          excludeSemantics: true,
          label: label,
          onTap: onTap,
          // hint-ok: shows text
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 10, 16, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(
                          languageNames(context, language, query: query),
                          style: needsApp == null
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleMedium!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                        ),
                        if (needsApp case final version?) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            l10n.appUpdateNeeded(version),
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (tag != null || youText != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if (tag != null) StageTag(tag: tag),
                              if (youText != null)
                                Text(
                                  youText,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (needsApp != null)
                    Text(
                      l10n.appUpdateAction,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Icon(
                      chosen ? Icons.check_circle : Icons.chevron_right,
                      color: chosen ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (actions != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 8, 0),
            child: actions,
          ),
        for (final part in below)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 16, 4),
            child: part,
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
