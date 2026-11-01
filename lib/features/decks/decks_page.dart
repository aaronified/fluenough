import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/unlocks.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../core/data/spoken_languages.dart' show SpokenLanguage;
import '../../core/models/deck.dart';
import '../../core/search/query.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/language_bar.dart';
import '../../ui/widgets/language_glyph.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/visible_listenable_builder.dart';
import 'broken_deck_tile.dart';
import 'course_card.dart';
import 'course_hours.dart';
import 'deck_search_bar.dart';
import 'number_practice_tile.dart';
import 'path_model.dart';
import 'path_view.dart';
import 'script_offers.dart';
import 'unit_search.dart';

/// The Decks tab: under the language bar (#528), the course of the
/// language it shows, its path (the owner's design) opening where the
/// learner is; the search above the path; and "Where I am".
///
/// Only the languages the learner learns show (owner, 2026-10-16: "No,
/// only my languages"). A unit on the path opens its screen; a deck the
/// path leaves out opens its own, from the path or from "Other decks"
/// under it.
class DecksPage extends StatefulWidget {
  const DecksPage({super.key, this.planOf, this.initialQuery, this.spokenList});

  /// Each course's plan, in place of [coursePlanOf]: the levels and units
  /// coming, which no path marks yet. For tests and the debug gallery.
  final CoursePlan Function(String language)? planOf;

  /// A search to open with, for the debug gallery and tests.
  final String? initialQuery;

  /// The catalog of languages the script offers read, in place of the
  /// asset: for tests.
  final List<SpokenLanguage>? spokenList;

  @override
  State<DecksPage> createState() => _DecksPageState();
}

/// The room the path leaves at its end, so that the floating button hides
/// no card when it is scrolled to the bottom: its margin, its height
/// and a gap (#466, #475).
const double fabClearance = kFloatingActionButtonMargin + 40 + 40;

class _DecksPageState extends State<DecksPage> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  final ScrollController _scroll = ScrollController();
  final GlobalKey _upNext = GlobalKey();

  /// The bar with its menu and offers above the results: the scrim covers
  /// what is under it, and a tap there closes the search.
  final GlobalKey _header = GlobalKey();
  final FocusNode _focus = FocusNode();

  /// The token chips the bar holds (#527): typed as `kind:grammar ` or
  /// picked from the menu, each with its value.
  final Map<SearchToken, String> _chips = <SearchToken, String>{};

  /// The chip whose value is being changed, its menu open.
  SearchToken? _editing;

  /// The text the results are computed for: the bar's text, caught up
  /// about 150 ms after typing stops, so that a keystroke does not rescan
  /// every card (#527).
  late String _applied = _search.text;
  Timer? _debounce;

  void _sync() {
    _debounce?.cancel();
    _applied = _search.text;
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  /// The course the path last opened at its unit up next, so that it opens
  /// there once, not on every rebuild.
  String? _openedAt;

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The languages whose courses the search looks in: the one the bar
  /// shows. Until deck search (#527) it covers this course alone, as #527
  /// decided ("Yes, this course").
  List<LanguageInfo> _languages(AppState state) => <LanguageInfo>[
    for (final language in state.languages)
      if (language.code == state.shownLanguage) language,
  ];

  /// The level holding the unit up next on the path shown, as (language,
  /// level), or null where there is none.
  (String, String)? _currentLevel;

  /// Scrolls the path to the unit up next, unfolding its level first if the
  /// learner folded it (#465).
  void _toUpNext({bool animate = true}) {
    if (_currentLevel case (final language, final level)) {
      final settings = AppScope.read(context).settings;
      if (settings.isLevelCollapsed(language, level)) {
        settings.setLevelCollapsed(language, level, false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToUpNext(animate: animate);
        });
        return;
      }
    }
    _scrollToUpNext(animate: animate);
  }

  /// The path's row of the unit up next, or -1.
  int _upNextRow = -1;

  void _scrollToUpNext({required bool animate}) {
    final target = _upNext.currentContext;
    if (target == null) {
      // The unit is not built, as the path builds only the rows on screen
      // (#853): go to where it should be, and then to it.
      final row = _upNextRow;
      if (row < 0 || !_scroll.hasClients) return;
      // The same place the unit is put at once built (alignment 0.3), so a
      // course that starts at its first unit stays at the top, its card in
      // view.
      final position = _scroll.position;
      _scroll.jumpTo(
        (row * CoursePathSliver.estimatedRowHeight +
                220 -
                0.3 * position.viewportDimension)
            .clamp(0.0, position.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _upNext.currentContext != null) {
          Scrollable.ensureVisible(
            _upNext.currentContext!,
            alignment: 0.3,
            duration: Duration.zero,
          );
        }
      });
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeInOut,
    );
  }

  /// The bar's text and chips read, with the theme ids the course offers.
  ParsedSearch _parse(AppState state) => parseSearch(
    _search.text,
    themes: <String>[for (final theme in state.themes) theme.id],
  );

  /// Whether there is anything to search for: text, or a chip.
  bool _isSearching(AppState state) =>
      _parse(state).text.isNotEmpty || _chips.isNotEmpty;

  /// Whether the search is open: focused, or holding a search.
  bool _isOpen(AppState state) => _focus.hasFocus || _isSearching(state);

  /// The bar's text changed: a token typed whole, with a space after it,
  /// becomes a chip.
  void _onChanged(String value) {
    final state = AppScope.read(context);
    final parsed = parseSearch(
      value,
      themes: <String>[for (final theme in state.themes) theme.id],
    );
    if (parsed.chips.isNotEmpty) {
      _chips.addAll(parsed.chips);
      final pending = parsed.pending == null
          ? ''
          : '${parsed.pending!.key}:${parsed.pendingPrefix}';
      var rest = <String>[
        if (parsed.text.isNotEmpty) parsed.text,
        if (pending.isNotEmpty) pending,
      ].join(' ');
      if (pending.isEmpty && rest.isNotEmpty && value.endsWith(' ')) {
        rest = '$rest ';
      }
      _search.value = TextEditingValue(
        text: rest,
        selection: TextSelection.collapsed(offset: rest.length),
      );
    }
    _debounce?.cancel();
    if (_search.text.isEmpty) {
      _applied = '';
    } else {
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _applied = _search.text);
      });
    }
    setState(() {});
  }

  void _setText(String text) {
    _search.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
    _sync();
    setState(() {});
  }

  /// A value picked for [token]: its chip, in place of what was typed.
  void _pick(SearchToken token, String value, ParsedSearch parsed) {
    _chips[token] = value;
    _editing = null;
    _setText(parsed.text);
  }

  /// The end button: the first tap clears the text and the chips, and a tap
  /// on the empty bar closes the search (owner, 2026-10-16: "Clear, then
  /// close").
  void _clearOrClose(AppState state) {
    if (_search.text.isNotEmpty || _chips.isNotEmpty) {
      _chips.clear();
      _editing = null;
      _search.clear();
      _sync();
      setState(() {});
    } else {
      _close();
    }
  }

  void _close() {
    _chips.clear();
    _editing = null;
    _search.clear();
    _focus.unfocus();
    _sync();
    setState(() {});
  }

  /// A tap at [position] on the path darkened under the open search closes
  /// it, as the ✕ does; a tap on the bar, its menu or its offers does not
  /// (mockup section 1).
  void _tapScrim(Offset position) {
    final box = _header.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (position.dy >= bottom) _close();
  }

  /// A swipe on the bar while searching runs the same search, chips and
  /// all, in the next course (to the left) or the one before (to the
  /// right; the other way round where text runs right to left).
  void _swipeCourse(AppState state, double velocity) {
    final choices = state.languageChoices;
    final shown = state.shownLanguage;
    if (choices.length < 2 || shown == null || velocity.abs() < 300) return;
    final at = choices.indexWhere((l) => l.code == shown);
    if (at < 0) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (velocity < 0) != rtl;
    final next = choices[(at + (forward ? 1 : -1)) % choices.length];
    _sync();
    state.showLanguage(next.code);
  }

  /// A kind chip on a result was tapped: the search narrows to that kind.
  void _narrowTo(SearchKind kind) => setState(() {
    _chips[SearchToken.kind] = kind.slug;
    _editing = null;
  });

  /// The search bar above the path (#528, #527): always there; it finds
  /// units, decks and words in the bar's course while it holds a search.
  Widget _searchBar(AppLocalizations l10n, AppState state, String? language) {
    final names = <String, String>{
      for (final theme in state.themes) theme.id: theme.name,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (_isSearching(state)) {
            _swipeCourse(state, details.primaryVelocity ?? 0);
          }
        },
        child: DeckSearchBar(
          controller: _search,
          focusNode: _focus,
          hint: language == null
              ? l10n.decksUnitSearchHint
              : l10n.decksSearchHintIn(language),
          chips: Map<SearchToken, String>.of(_chips),
          chipLabel: (token, value) => l10n.searchChip(
            token.key,
            tokenValueLabel(l10n, token, value, themeNames: names),
          ),
          editing: _editing,
          onChanged: _onChanged,
          onChipTap: (token) =>
              setState(() => _editing = _editing == token ? null : token),
          onChipRemove: (token) => setState(() {
            _chips.remove(token);
            if (_editing == token) _editing = null;
          }),
          onBackspaceEmpty: () => setState(() {
            final last = _chips.keys.toList()
              ..sort((a, b) => b.index.compareTo(a.index));
            if (last.isNotEmpty) _chips.remove(last.first);
          }),
          showEnd: _isOpen(state),
          endTooltip: _search.text.isNotEmpty || _chips.isNotEmpty
              ? l10n.decksSearchClear
              : l10n.decksSearchClose,
          onEnd: () => _clearOrClose(state),
        ),
      ),
    );
  }

  /// The menu under the bar: the tokens on an empty, focused bar, or a
  /// token's values while it is typed or its chip is tapped (#527).
  Widget? _menu(
    AppLocalizations l10n,
    AppState state,
    ParsedSearch parsed,
    String? code,
  ) {
    final token = parsed.pending ?? _editing;
    if (token != null) {
      final prefix = parsed.pending == null
          ? ''
          : parsed.pendingPrefix.toLowerCase();
      final items = <(String, String, String?)>[
        // (value, label, line)
        ...switch (token) {
          SearchToken.kind => <(String, String, String?)>[
            for (final k in SearchKind.values)
              (k.slug, searchKindLabel(l10n, k), kindLine(l10n, k)),
          ],
          SearchToken.status => <(String, String, String?)>[
            for (final s in const <CardStatus>[
              CardStatus.notLearnt,
              CardStatus.learning,
              CardStatus.learnt,
              CardStatus.forgetting,
              CardStatus.struggling,
              CardStatus.setAside,
            ])
              (s.slug, statusLabel(l10n, s), statusLine(l10n, s)),
          ],
          SearchToken.theme => <(String, String, String?)>[
            if (code != null)
              for (final theme in courseThemes(state, code))
                (theme.id, theme.name, null),
          ],
        },
      ];
      return SearchMenu(
        items: <SearchMenuItem>[
          for (final (value, label, line) in items)
            if (prefix.isEmpty ||
                value.startsWith(prefix) ||
                label.toLowerCase().startsWith(prefix))
              SearchMenuItem(
                title: label,
                line: line,
                onTap: () => _pick(token, value, parsed),
              ),
        ],
      );
    }
    if (_focus.hasFocus && _chips.isEmpty && _search.text.trim().isEmpty) {
      return SearchMenu(
        header: l10n.searchTokensHeader,
        items: <SearchMenuItem>[
          for (final (token, line) in <(SearchToken, String)>[
            (SearchToken.kind, l10n.searchTokenKindLine),
            (SearchToken.status, l10n.searchTokenStatusLine),
            (SearchToken.theme, l10n.searchTokenThemeLine),
          ])
            SearchMenuItem(
              title: '${token.key}:',
              line: line,
              onTap: () => _setText('${token.key}:'),
            ),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final languages = _languages(state);
    final code = state.shownLanguage;
    final ready = state.status == CatalogStatus.ready && code != null;
    // The buttons give way while the search is open (#527).
    final open = _isOpen(state);

    return PopScope(
      // Back closes an open search at once, typed or not.
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: open || !ready
            ? null
            : _WhereIAmButton(label: l10n.decksWhereIAm, onPressed: _toUpNext),
        body: SafeArea(
          bottom: false,
          child: LanguageBarFrame(
            screen: LanguageBarScreen.decks,
            reportDetail: 'Decks',
            child: _body(context, state, languages, code),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppState state,
    List<LanguageInfo> languages,
    String? code,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.status) {
      case CatalogStatus.loading:
        return Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.commonLoadingDecks,
          ),
        );
      case CatalogStatus.failed:
        return EmptyState(
          icon: Icons.error_outline,
          title: l10n.commonDecksFailed,
          body: l10n.commonDecksFailedBody,
          action: FilledButton(
            onPressed: state.reload,
            child: Text(l10n.commonRetry),
          ),
        );
      case CatalogStatus.ready:
        break;
    }
    final searchingNow = _isSearching(state);
    if (code == null && !searchingNow) {
      // No deck parsed: only broken files, if any.
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 96),
        children: <Widget>[
          _searchBar(l10n, state, null),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 32),
            child: Text(
              l10n.decksEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _BrokenFiles(files: state.brokenDecks),
        ],
      );
    }
    return VisibleListenableBuilder(
      warmUp: true,
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final parsed = _parse(state);
        final applied = parseSearch(
          _applied,
          themes: <String>[for (final theme in state.themes) theme.id],
        );
        final searching = parsed.text.isNotEmpty || _chips.isNotEmpty;
        final open = _focus.hasFocus || searching;
        final language = languages.firstOrNull;
        final outcome = searching
            ? runSearch(
                state,
                l10n,
                text: _applied,
                chips: _chips,
                languages: languages,
                planOf: widget.planOf,
              )
            : null;
        final menu = _menu(l10n, state, parsed, code);
        // The path stays under the search while nothing is typed, darkened.
        final dim = open && !searching ? 0.5 : 1.0;
        final view = searching || code == null
            ? null
            : courseView(
                state,
                code,
                plan: widget.planOf?.call(code),
                answers: state.recentAnswers,
              );
        _currentLevel = switch (view?.steps
            .whereType<LevelStep>()
            .where((l) => l.current)
            .firstOrNull) {
          final level? => (code!, level.level.label),
          null => null,
        };
        // The level up next starts unfolded: _toUpNext unfolds it.
        if (view != null && _openedAt != code) {
          _openedAt = code;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _toUpNext(animate: false);
          });
        }
        final scrim = open && !searching;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: scrim
              ? (details) => _tapScrim(details.globalPosition)
              : null,
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              // Clear of the buttons that float over the path's end (#466):
              // their margin, their height and a gap, above any system inset.
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  16,
                  4,
                  16,
                  fabClearance + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Column(
                        key: _header,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _searchBar(l10n, state, language?.name),
                          ?menu,
                          if (outcome != null) ...<Widget>[
                            if (outcome.foreign case final script?)
                              ScriptOffers(
                                script: script,
                                shown: language!,
                                spokenList: widget.spokenList,
                              ),
                            if (parsed.pending == null &&
                                _editing == null &&
                                applied.text.isNotEmpty &&
                                outcome.foreign == null)
                              SuggestionRows(
                                typed: applied.text,
                                suggestions: language == null
                                    ? const <SearchSuggestion>[]
                                    : searchSuggestions(
                                        state,
                                        l10n,
                                        applied.text,
                                        language,
                                      ),
                                onUse: (s) => _setText(
                                  s.token == null ? s.text : '${s.token!.key}:',
                                ),
                                onEdit: (s) => _setText(
                                  s.token == null ? '${s.text} ' : s.text,
                                ),
                              ),
                          ] else if (view != null) ...<Widget>[
                            IgnorePointer(
                              ignoring: scrim,
                              child: Opacity(
                                opacity: dim,
                                child: CourseCard(
                                  view: view,
                                  glyph: languageGlyph(
                                    view.language,
                                    state.decks,
                                  ),
                                  hours: courseHours(state, code!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    if (outcome != null)
                      SearchResultsSliver(
                        outcome: outcome,
                        query: _search.text,
                        onKind: _narrowTo,
                        onRemoveKind: () =>
                            setState(() => _chips.remove(SearchToken.kind)),
                      ),
                    if (!searching && view != null) ...<Widget>[
                      SliverIgnorePointer(
                        ignoring: scrim,
                        sliver: SliverOpacity(
                          opacity: dim,
                          sliver: CoursePathSliver(
                            view: view,
                            state: state,
                            upNextKey: _upNext,
                            onUpNextRow: (row) => _upNextRow = row,
                            onOpen: (unit) => unit.onPath
                                ? AppNavigator.openUnit(
                                    context,
                                    unit.decks.first.id,
                                  )
                                : AppNavigator.openDeck(
                                    context,
                                    unit.decks.first.id,
                                  ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 32),
                            const BeyondTheCourse(),
                            if (view.otherDecks.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 24),
                              GroupedList(
                                header: l10n.pathOtherDecks,
                                outerRadius: AppRadii.card,
                                gap: 4,
                                children: <Widget>[
                                  for (final entry
                                      in view.otherDecks) ...<Widget>[
                                    DeckTile(
                                      entry: entry,
                                      badge: DeckBadge.forEntry(state, entry),
                                      onTap: () => AppNavigator.openDeck(
                                        context,
                                        entry.id,
                                      ),
                                    ),
                                    if (hasNumberPractice(state, entry))
                                      NumberPracticeTile(deck: entry),
                                  ],
                                ],
                              ),
                            ],
                            if (state.brokenDecks.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 24),
                              _BrokenFiles(files: state.brokenDecks),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Deck files that could not be read. A broken file has no language, so it
/// shows under every course.
class _BrokenFiles extends StatelessWidget {
  const _BrokenFiles({required this.files});

  final List<BrokenDeck> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return GroupedList(
      header: AppLocalizations.of(context)!.pathBrokenFiles,
      outerRadius: AppRadii.card,
      gap: 4,
      children: <Widget>[
        for (final file in files) BrokenDeckTile(broken: file),
      ],
    );
  }
}

/// "Where I am" (#475): an icon-only small floating button on the right of
/// the path, named by its tooltip and screen-reader label, its tap target
/// 48 dp. In `tertiary`, a role no card on the path uses (#466), so that it
/// reads as a control and not as one of the units under it, in light, dark
/// and pure black alike.
class _WhereIAmButton extends StatelessWidget {
  const _WhereIAmButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      heroTag: 'where-i-am',
      tooltip: label,
      backgroundColor: scheme.tertiary,
      foregroundColor: scheme.onTertiary,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onPressed: onPressed,
      child: const Icon(Icons.my_location),
    );
  }
}
