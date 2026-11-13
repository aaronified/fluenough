import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/culture.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/situations.dart';
import '../../core/decks/weave.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import 'culture_parts.dart';

/// A culture item as a row on a card: the quote mark in the primary colour, the
/// kind and the item's first words, and a line under it. The whole row opens
/// the item.
class _CultureCard extends StatelessWidget {
  const _CultureCard({
    required this.item,
    required this.language,
    required this.line,
    required this.done,
    this.title,
  });

  final CultureItem item;
  final String language;
  final String line;
  final bool done;

  /// The title when it is not the item's own kind and first words.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final info = cultureLanguage(state, language);
    final first = item.target.split('\n').first;
    final short = first.length > 28 ? '${first.substring(0, 28)}…' : first;
    return Semantics(
      button: true,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.group),
        clipBehavior: Clip.antiAlias,
        // hint-ok: shows text
        child: InkWell(
          onTap: () => AppNavigator.openCultureItem(context, language, item.id),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.format_quote,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      title != null
                          ? Text(
                              title!,
                              style: theme.textTheme.titleMedium!.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            )
                          : Row(
                              children: <Widget>[
                                Text(
                                  l10n.cultureCardKind(
                                    cultureKindName(l10n, item.kind),
                                  ),
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TargetText(
                                    short,
                                    language: info,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSecondaryContainer,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ],
                            ),
                      Text(
                        line,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The culture item woven into a path unit (approved mockup, screen 1): one
/// card between the lessons and the words, at the learner's level, "bonus" or
/// "counts toward the unit" as Settings says. With culture items off, one line
/// says so and where to turn them on; a unit with no item shows nothing.
class UnitCultureCard extends StatelessWidget {
  const UnitCultureCard({
    super.key,
    required this.language,
    required this.decks,
  });

  final String language;
  final List<DeckEntry> decks;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    try {
      final index = state.pathIndexOfUnit(language, decks);
      if (index < 0) return const SizedBox.shrink();
      final settings = state.settings;
      final woven = state.wovenCultureOf(language).of(index);
      if (state.cultureItemsIn(language).isEmpty) {
        return const SizedBox.shrink();
      }
      if (!settings.cultureItems) {
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSizes.textInset,
            16,
            AppSizes.textInset,
            0,
          ),
          child: Text(
            l10n.cultureOffHint,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      if (woven.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            for (final item in woven)
              _CultureCard(
                item: item,
                language: language,
                done: state.isCultureItemDone(item),
                line: settings.cultureCounts
                    ? l10n.cultureCardLineCounts(item.level.label)
                    : l10n.cultureCardLineBonus(item.level.label),
              ),
          ],
        ),
      );
    } on Object catch (error, stack) {
      state.log.error('Culture of a unit could not be shown: $error\n$stack');
      return const SizedBox.shrink();
    }
  }
}

/// Today's culture row (approved mockup, screen 5): the next culture item of
/// the language shown, at the learner's level, skippable: it is no part of the
/// day's chain, and it stays until the learner has met it. Nothing when
/// culture items are off or all are met.
class TodayCultureCard extends StatelessWidget {
  const TodayCultureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final language = state.situationsLanguage;
    if (language == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.settings,
        state.progress,
      ]),
      builder: (context, _) {
        try {
          final item = state.nextCultureItem(language);
          if (item == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsetsDirectional.only(top: 16),
            child: _CultureCard(
              item: item,
              language: language,
              done: false,
              title: l10n.cultureTodayTitle(item.level.label),
              line: l10n.cultureTodayLine(cultureKindName(l10n, item.kind)),
            ),
          );
        } on Object catch (error, stack) {
          state.log.error('Today culture could not be shown: $error\n$stack');
          return const SizedBox.shrink();
        }
      },
    );
  }
}
