import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/item_search.dart';
import '../../app/topics.dart';
import '../../core/data/sections.dart' show DeckSections, nameIn;
import '../../core/search/fuzzy.dart';
import '../../core/search/search_items.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import 'broken_deck_tile.dart';
import 'search_item_rows.dart';
import 'unit_search.dart';

/// What the search remembers while the app runs: the tab last used and the
/// searches made (the approved mockup: "the last tab you used is remembered
/// for this session"). Never saved to disk.
class SearchSession {
  SearchSession._();

  static final Expando<SearchSession> _sessions = Expando<SearchSession>(
    'searchSession',
  );

  /// The session of [state].
  static SearchSession of(AppState state) =>
      _sessions[state] ??= SearchSession._();

  /// The search kind of the tab last chosen.
  String? lastKind;

  /// The searches made, newest first, at most [maxRecent].
  final List<String> recent = <String>[];

  static const int maxRecent = 5;

  /// Remembers [text] as a search made; a repeat moves it to the front.
  void remember(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 2) return;
    recent
      ..remove(trimmed)
      ..insert(0, trimmed);
    if (recent.length > maxRecent) recent.removeRange(maxRecent, recent.length);
  }
}

/// A search kind's name for a tab or a hint: the sections file's, in the first
/// language the learner reads that it is written in, else the app's own name
/// for the kinds the code knows, else the id.
String searchKindName(
  AppLocalizations l10n,
  DeckSections sections,
  List<String> spoken,
  String kind,
) {
  final named = sections.searchKind(kind);
  if (named != null && named.names.isNotEmpty) {
    return nameIn(named.names, spoken);
  }
  return switch (kind) {
    ResultKind.situations => l10n.searchKindSituations,
    ResultKind.topics => l10n.searchKindTopics,
    ResultKind.decks => l10n.searchKindDecks,
    ResultKind.concepts => l10n.searchKindConcepts,
    ResultKind.cards => l10n.searchKindWords,
    ResultKind.units => l10n.searchKindUnits,
    'culture' => l10n.searchKindCulture,
    'proverbs' => l10n.searchKindProverbs,
    'multiword' => l10n.searchKindMultiword,
    _ => kind,
  };
}

/// One tab: a search kind, what it is called and how many results it has.
class ResultTab {
  const ResultTab({
    required this.kind,
    required this.label,
    required this.count,
  });

  final String kind;
  final String label;
  final int count;
}

/// The tabs of a search (#1140): only the kinds that have results, the best
/// match's first, the rest in the sections file's order. [items] are the
/// results of every kind but plain words; [words] is how many plain words were
/// found, with [wordsRank] their best rank.
List<ResultTab> resultTabs({
  required AppLocalizations l10n,
  required DeckSections sections,
  required List<String> spoken,
  required List<ItemResult> items,
  required int words,
  int wordsRank = 0,
}) {
  final counts = <String, int>{};
  final best = <String, int>{};
  for (final r in items) {
    counts[r.row.kind] = (counts[r.row.kind] ?? 0) + 1;
    final earlier = best[r.row.kind];
    if (earlier == null || r.rank < earlier) best[r.row.kind] = r.rank;
  }
  if (words > 0) {
    counts[ResultKind.cards] = words;
    best[ResultKind.cards] = wordsRank;
  }
  if (counts.isEmpty) return const <ResultTab>[];
  final order = <String, int>{
    for (final k in sections.searchKinds) k.id: k.order,
  };
  int orderOf(String kind) => order[kind] ?? 100000;
  final kinds = counts.keys.toList()
    ..sort((a, b) {
      final byOrder = orderOf(a).compareTo(orderOf(b));
      return byOrder != 0 ? byOrder : a.compareTo(b);
    });
  var first = kinds.first;
  for (final k in kinds) {
    if (best[k]! < best[first]!) first = k;
  }
  return <ResultTab>[
    for (final k in <String>[first, ...kinds.where((k) => k != first)])
      ResultTab(
        kind: k,
        label: searchKindName(l10n, sections, spoken, k),
        count: counts[k]!,
      ),
  ];
}

/// The search as the learner meant it: each word of [typed] found only despite
/// a typo, replaced by the word the results have ("teform" by "te-form"), or
/// null when no word could be put right.
String? correctedQuery(String typed, List<ItemResult> results) {
  final words = searchWords(typed);
  if (words.isEmpty) return null;
  final tokens = <String>[
    for (final r in results.take(5))
      for (final field in r.row.fields) ...field.split(RegExp(r'\s+')),
  ];
  var changed = false;
  final corrected = <String>[];
  for (final word in words) {
    if (matchWord(word, tokens, typos: false) != null) {
      corrected.add(word);
      continue;
    }
    String? found;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (matchWord(word, <String>[token]) != null) {
        found = token;
        break;
      }
    }
    if (found == null) return null;
    corrected.add(found);
    changed = true;
  }
  return changed ? corrected.join(' ') : null;
}

/// The typed results of the Decks tab's search (#1140, the approved mockup
/// `search-results-tabs.html`): a native [TabBar] of the kinds that have
/// results, with their counts and the best match's first, and under it the
/// rows of the tab chosen, one row template per kind. Plain words are the
/// Decks tab's own word rows (`SearchResultsSliver`); situations, topics,
/// decks, grammar concepts, units, culture and proverbs come from the typed
/// items ([ItemSearchState.searchItems]).
///
/// A sliver, so that it sits in the Decks tab's own scrolling.
class TypedSearchResults extends StatefulWidget {
  const TypedSearchResults({
    super.key,
    required this.outcome,
    required this.query,
    required this.language,
    required this.onSearch,
  });

  /// The Decks tab's word search of the same text: the words found, and the
  /// deck files that could not be read.
  final SearchOutcome outcome;

  /// The text the learner typed.
  final String query;

  /// The code of the language searched.
  final String language;

  /// A suggestion or a recent search was tapped: put it in the bar.
  final ValueChanged<String> onSearch;

  @override
  State<TypedSearchResults> createState() => _TypedSearchResultsState();
}

class _TypedSearchResultsState extends State<TypedSearchResults> {
  String? _kind;
  bool _exact = false;
  String? _profession;
  String _text = '';

  String get _typed => widget.outcome.parsed.text.isEmpty
      ? widget.query.trim()
      : widget.outcome.parsed.text.trim();

  @override
  void didUpdateWidget(TypedSearchResults old) {
    super.didUpdateWidget(old);
    if (_typed != _text) {
      _text = _typed;
      _exact = false;
      _profession = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _text = _typed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    final spoken = spokenFor(context, state);
    final sections = state.catalogWithAboveLevel.sections;
    final text = _typed;
    final found = state.searchItems(language, text, exact: _exact);
    final index = state.itemSearchFor(language);
    final items = found.outcome.results;
    final wordHits = <SearchHit>[
      for (final hit in widget.outcome.hits)
        if ((hit is CardHit || hit is EntryHit) && !(_exact && hit.isClose))
          hit,
    ];
    final wordsClose = wordHits.isNotEmpty && wordHits.every((h) => h.isClose);
    final tabs = resultTabs(
      l10n: l10n,
      sections: sections,
      spoken: spoken,
      items: items,
      words: wordHits.length,
      wordsRank: wordHits.isEmpty ? 0 : wordHits.first.rank,
    );
    final session = SearchSession.of(state);
    final selected = tabs.any((t) => t.kind == _kind)
        ? _kind!
        : tabs.any((t) => t.kind == session.lastKind)
        ? session.lastKind!
        : tabs.isEmpty
        ? null
        : tabs.first.kind;
    final close =
        (found.close && items.isNotEmpty) || (wordsClose && items.isEmpty);
    final corrected = close ? correctedQuery(text, items) : null;
    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (tabs.isEmpty)
          SliverToBoxAdapter(
            child: _NoResults(
              query: text,
              language: language,
              hiddenAbove: found.hiddenAbove,
              onSearch: widget.onSearch,
            ),
          )
        else ...<Widget>[
          if (close && !_exact)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      corrected == null
                          ? l10n.searchCloseMatches(text)
                          : l10n.searchShowingResultsFor(corrected),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _exact = true),
                      child: Text(l10n.searchOnlyFor(text)),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _TabStrip(
              key: ValueKey<String>(
                '${tabs.map((t) => t.kind).join(',')}|$selected',
              ),
              tabs: tabs,
              selected: selected!,
              onSelect: (kind) {
                session.lastKind = kind;
                setState(() {
                  _kind = kind;
                  _profession = null;
                });
              },
            ),
          ),
          ..._content(context, state, index, selected, items, wordHits),
          if (found.hiddenAbove > 0)
            SliverToBoxAdapter(child: _HiddenAbove(count: found.hiddenAbove)),
        ],
        if (widget.outcome.broken.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                top: tabs.isNotEmpty ? 16 : 0,
              ),
              child: GroupedList(
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final file in widget.outcome.broken)
                    BrokenDeckTile(broken: file),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _content(
    BuildContext context,
    AppState state,
    ItemSearchIndex index,
    String kind,
    List<ItemResult> items,
    List<SearchHit> wordHits,
  ) {
    if (kind == ResultKind.cards) {
      return <Widget>[
        SearchResultsSliver(
          outcome: SearchOutcome(
            hits: wordHits,
            parsed: widget.outcome.parsed,
            chips: widget.outcome.chips,
          ),
          query: widget.query,
          onKind: (_) {},
          onRemoveKind: () {},
          kindChips: false,
        ),
      ];
    }
    final l10n = AppLocalizations.of(context)!;
    final sections = state.catalogWithAboveLevel.sections;
    final spoken = spokenFor(context, state);
    var rows = <ItemResult>[
      for (final r in items)
        if (r.row.kind == kind) r,
    ];
    // A professional situation's profession, for the chips above Situations.
    final professions = <String, String>{};
    String? professionOf(ItemResult r) {
      if (r.row.type != SearchItemType.deck) return null;
      return index.deckEntry(r.row.id)?.deck.professional ??
          index.shelfOf(r.row.id)?.professional;
    }

    for (final r in rows) {
      final id = professionOf(r);
      if (id == null) continue;
      final named = sections.profession(id);
      professions[id] = named == null ? id : nameIn(named.names, spoken);
    }
    final profession = _profession;
    if (profession != null) {
      rows = <ItemResult>[
        for (final r in rows)
          if (professionOf(r) == profession) r,
      ];
    }
    const outer = Radius.circular(AppRadii.card);
    const inner = Radius.circular(AppRadii.control);
    BorderRadius radius(int i) => BorderRadius.vertical(
      top: i == 0 ? outer : inner,
      bottom: i == rows.length - 1 ? outer : inner,
    );
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      if (professions.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.searchProfessionFilterAll),
                  selected: profession == null,
                  onSelected: (_) => setState(() => _profession = null),
                ),
                for (final entry in professions.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: profession == entry.key,
                    onSelected: (_) => setState(() => _profession = entry.key),
                  ),
              ],
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = itemResultRow(context, index, rows[i]);
            return Padding(
              padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 4),
              child: Material(
                color: scheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: radius(i)),
                child: row ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// The tab bar: a scrollable native [TabBar], each tab its kind's name and a
/// count, the first with a dot for the best match.
class _TabStrip extends StatefulWidget {
  const _TabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<ResultTab> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.tabs.length,
    vsync: this,
    initialIndex: widget.tabs
        .indexWhere((t) => t.kind == widget.selected)
        .clamp(0, widget.tabs.length - 1),
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() {
    if (_controller.indexIsChanging) return;
    final kind = widget.tabs[_controller.index].kind;
    if (kind != widget.selected) widget.onSelect(kind);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: l10n.searchTabsLabel,
      child: TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        tabs: <Widget>[
          for (final (i, tab) in widget.tabs.indexed)
            Tab(
              child: Semantics(
                label:
                    '${l10n.searchTabSemantics(tab.label, tab.count)}'
                    '${i == 0 ? ', ${l10n.searchTabBestMatch}' : ''}',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (i == 0) ...<Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 6, height: 6),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(tab.label),
                    const SizedBox(width: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        child: Text(
                          '${tab.count}',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The line under the results while "Hide what is above my level" is on: how
/// many it left out, and a way to show them.
class _HiddenAbove extends StatelessWidget {
  const _HiddenAbove({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = AppScope.read(context).settings;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.visibility_off_outlined,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.searchAboveHidden(count),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => settings.hideAboveLevel = false,
              child: Text(l10n.searchShowAbove),
            ),
          ),
          Text(
            l10n.searchHideAboveHint,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing found (the mockup's screen 5): what the search looks in, and a few
/// searches to try, from the language's own topics.
class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.language,
    required this.hiddenAbove,
    required this.onSearch,
  });

  final String query;
  final String language;
  final int hiddenAbove;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spoken = spokenFor(context, state);
    final suggestions = <String>[
      for (final r
          in state.topicsOf(language).startable(state.levelIn(language)))
        r.topic.nameFor(spoken),
    ].take(3).toList();
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSizes.gutter,
        vertical: 32,
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            l10n.searchNothing(query),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.searchNothingTypedBody(
              state.languageByCode(language)?.name ?? language,
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (hiddenAbove > 0) _HiddenAbove(count: hiddenAbove),
          if (suggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            Text(l10n.searchTry, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final s in suggestions)
                  ActionChip(label: Text(s), onPressed: () => onSearch(s)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What the open search shows before anything is typed (the mockup's screen
/// 6): the searches made recently, the types of result, and that tabs appear
/// after typing. No tabs yet.
class SearchStartHints extends StatelessWidget {
  const SearchStartHints({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sections = state.catalogWithAboveLevel.sections;
    final spoken = spokenFor(context, state);
    final recent = SearchSession.of(state).recent;
    final kinds = sections.searchKinds.isEmpty
        ? const <String>[
            ResultKind.situations,
            ResultKind.topics,
            ResultKind.concepts,
            ResultKind.cards,
            ResultKind.units,
            'proverbs',
          ]
        : <String>[for (final k in sections.searchKinds) k.id];
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (recent.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 4),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.searchRecent,
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            for (final text in recent)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(text),
                onTap: () => onSearch(text),
              ),
          ],
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 6),
            child: Semantics(
              header: true,
              child: Text(
                l10n.searchFindByType,
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final kind in kinds)
                  Chip(
                    label: Text(searchKindName(l10n, sections, spoken, kind)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
            child: Text(
              l10n.searchTabsHint,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
