import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/culture.dart';
import '../../app/culture_list.dart';
import '../../app/deck_catalog.dart' show DeckEntry;
import '../../app/routes.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../culture/culture_parts.dart' show cultureLanguage;
import '../culture/culture_works.dart';
import 'result_marks.dart';

/// What a section of the culture list is called.
String cultureSectionName(
  AppLocalizations l10n,
  RecommendationMedium? medium,
) => switch (medium) {
  null => l10n.decksCultureDecksHeader,
  RecommendationMedium.book => l10n.recKindBooks,
  RecommendationMedium.film => l10n.recKindFilms,
  RecommendationMedium.series => l10n.recKindSeries,
  RecommendationMedium.song => l10n.recKindSongs,
  RecommendationMedium.play => l10n.recKindPlays,
  RecommendationMedium.podcast => l10n.recKindPodcasts,
  RecommendationMedium.comic => l10n.recKindComics,
};

/// The culture list the Decks screen shows in place of the deck path (approved
/// mockup `culture-in-decks`): the culture and proverbs decks, then the
/// recommended works by kind, each section with its count. Nothing is hidden or
/// locked by level: every row opens. [query] is the Decks screen's one search,
/// applied here; a section with no match is left out. [openWork] is the work
/// whose row shows its whole briefing.
class CultureList extends StatelessWidget {
  const CultureList({
    super.key,
    required this.language,
    required this.query,
    required this.openWork,
    required this.onToggleWork,
    this.showEmpty = true,
  });

  final String language;
  final String query;

  /// The work shown open, `''` for none.
  final String? openWork;

  final ValueChanged<String> onToggleWork;

  /// Whether to say so when nothing is listed; a search that also looks
  /// elsewhere leaves the saying to the other results.
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
        state.recommendationProgress,
      ]),
      builder: (context, _) {
        final sections = state.cultureListOf(
          language,
          query: query,
          // The kind as a row says it and as the header does ("Film", "Films").
          mediumName: (medium) =>
              '${recommendationMediumName(l10n, medium)} '
              '${cultureSectionName(l10n, medium)}',
          decksName: l10n.decksCultureDecksHeader,
        );
        if (sections.isEmpty) {
          if (!showEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 32),
            child: Text(
              query.trim().isEmpty
                  ? l10n.decksCultureNone(cultureLanguage(state, language).name)
                  : l10n.decksEmptySearch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final section in sections) ...<Widget>[
              GroupedList(
                header: l10n.decksCultureHeader(
                  cultureSectionName(l10n, section.medium),
                  section.count,
                ),
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final entry in section.decks)
                    _DeckRow(entry: entry),
                  for (final work in section.works)
                    CultureWorkRow(
                      key: ValueKey<String>('culture-work-${work.id}'),
                      work: work,
                      language: language,
                      file: state.creatorsOf(language),
                      open: work.id == openWork,
                      onTap: () => onToggleWork(work.id),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }
}

/// A culture or proverbs deck: its name, how many cards, its level.
class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.entry});

  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ResultRow(
      key: ValueKey<String>('culture-deck-${entry.id}'),
      icon: Icons.format_quote,
      title: entry.deck.name,
      lines: <Widget>[RowLine(l10n.cultureDeckCount(entry.itemCount))],
      tags: <Widget>[LevelTag(level: entry.deck.level)],
      onTap: () => AppNavigator.openDeck(context, entry.id),
    );
  }
}
