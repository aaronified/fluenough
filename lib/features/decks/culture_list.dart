import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart' show AppState;
import '../../app/culture.dart';
import '../../app/culture_list.dart';
import '../../app/deck_catalog.dart' show DeckEntry;
import '../../app/routes.dart';
import '../../core/models/recommendation.dart';
import '../../core/search/query.dart' show CultureFilter;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../culture/culture_parts.dart' show cultureLanguage;
import '../culture/culture_works.dart';
import 'result_marks.dart';
import 'search_tabs.dart' show ResultTab, ResultTabStrip, cultureTabPrefix;

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

/// The sections of [language]'s culture list that match [query] and [filter],
/// named as the learner reads them (the kind as a row says it and as a header
/// does).
List<CultureListSection> cultureSections(
  AppState state,
  AppLocalizations l10n,
  String language,
  String query, {
  CultureFilter filter = const CultureFilter(),
}) => state.cultureListOf(
  language,
  query: query,
  filter: filter,
  mediumName: (medium) =>
      '${recommendationMediumName(l10n, medium)} '
      '${cultureSectionName(l10n, medium)}',
  decksName: l10n.decksCultureDecksHeader,
);

/// The tab key of [section]: `culture:decks`, `culture:film`.
String cultureTabKey(CultureListSection section) =>
    '$cultureTabPrefix${section.medium?.name ?? 'decks'}';

/// The tabs of [sections], one for each with its count, for the same strip
/// the deck results use; [all] puts a first tab for every section together.
List<ResultTab> cultureTabs(
  AppLocalizations l10n,
  List<CultureListSection> sections, {
  bool all = false,
}) => <ResultTab>[
  if (all)
    ResultTab(
      kind: '${cultureTabPrefix}all',
      label: l10n.decksCultureAll,
      count: sections.fold(0, (sum, s) => sum + s.count),
    ),
  for (final section in sections)
    ResultTab(
      kind: cultureTabKey(section),
      label: cultureSectionName(l10n, section.medium),
      count: section.count,
    ),
];

/// The rows of the tab [kind] of [sections]: one section's rows, or with
/// `culture:all` every section under its header with its count.
class CultureRows extends StatelessWidget {
  const CultureRows({
    super.key,
    required this.language,
    required this.sections,
    required this.kind,
    required this.openWork,
    required this.onToggleWork,
  });

  final String language;
  final List<CultureListSection> sections;
  final String kind;
  final String? openWork;
  final ValueChanged<String> onToggleWork;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final all = kind == '${cultureTabPrefix}all';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final section in sections)
          if (all || cultureTabKey(section) == kind) ...<Widget>[
            GroupedList(
              header: all
                  ? l10n.decksCultureHeader(
                      cultureSectionName(l10n, section.medium),
                      section.count,
                    )
                  : null,
              outerRadius: AppRadii.card,
              gap: 4,
              children: <Widget>[
                for (final entry in section.decks) _DeckRow(entry: entry),
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
  }
}

/// The culture list the Decks screen shows in place of the deck path (approved
/// mockup `culture-in-decks`): a strip of tabs of the same widget the deck
/// results use, All first and then one for each kind present (the culture and
/// proverbs decks, books, films ...) with its count, and under it the rows.
/// Nothing is hidden or locked by level: every row opens. [query] and
/// [filter] are the Decks screen's one search, applied here; a kind with no
/// match has no tab. [openWork] is the work whose row shows its whole
/// briefing.
class CultureList extends StatefulWidget {
  const CultureList({
    super.key,
    required this.language,
    required this.query,
    required this.openWork,
    required this.onToggleWork,
    this.filter = const CultureFilter(),
  });

  final String language;
  final String query;
  final CultureFilter filter;

  /// The work shown open, `''` for none.
  final String? openWork;

  final ValueChanged<String> onToggleWork;

  @override
  State<CultureList> createState() => _CultureListState();
}

class _CultureListState extends State<CultureList> {
  String _kind = '${cultureTabPrefix}all';

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
        final sections = cultureSections(
          state,
          l10n,
          widget.language,
          widget.query,
          filter: widget.filter,
        );
        if (sections.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 32),
            child: Text(
              widget.query.trim().isEmpty && widget.filter.isEmpty
                  ? l10n.decksCultureNone(
                      cultureLanguage(state, widget.language).name,
                    )
                  : l10n.decksEmptySearch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final tabs = cultureTabs(l10n, sections, all: true);
        final kind = tabs.any((t) => t.kind == _kind)
            ? _kind
            : '${cultureTabPrefix}all';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ResultTabStrip(
              key: ValueKey<String>(tabs.map((t) => t.kind).join(',')),
              tabs: tabs,
              selected: kind,
              bestMatchDot: false,
              onSelect: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 8),
            CultureRows(
              language: widget.language,
              sections: sections,
              kind: kind,
              openWork: widget.openWork,
              onToggleWork: widget.onToggleWork,
            ),
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
