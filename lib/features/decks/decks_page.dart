import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/language_bar.dart';
import '../../ui/widgets/language_glyph.dart';
import '../../ui/widgets/page_parts.dart';
import 'broken_deck_tile.dart';
import 'course_card.dart';
import 'course_hours.dart';
import 'number_practice_tile.dart';
import 'path_model.dart';
import 'path_view.dart';
import 'unit_search.dart';
import 'word_mastery.dart';

/// The Decks tab: under the language bar (#528), the course of the
/// language it shows, its path (the owner's design) opening where the
/// learner is; the search above the path; "Where I am" and Add deck.
///
/// Only the languages the learner learns show (owner, 2026-10-16: "No,
/// only my languages"). A unit on the path opens its screen; a deck the
/// path leaves out opens its own, from the path or from "Other decks"
/// under it.
class DecksPage extends StatefulWidget {
  const DecksPage({super.key, this.planOf, this.initialQuery});

  /// Each course's plan, in place of [coursePlanOf]: the levels and units
  /// coming, which no path marks yet. For tests and the debug gallery.
  final CoursePlan Function(String language)? planOf;

  /// A search to open with, for the debug gallery and tests.
  final String? initialQuery;

  @override
  State<DecksPage> createState() => _DecksPageState();
}

/// The room the path leaves at its end, so that the floating buttons hide
/// no card when it is scrolled to the bottom: their margin, their height
/// and a gap (#466).
const double fabClearance = kFloatingActionButtonMargin + 56 + 40;

class _DecksPageState extends State<DecksPage> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  final ScrollController _scroll = ScrollController();
  final GlobalKey _upNext = GlobalKey();

  /// The course the path last opened at its unit up next, so that it opens
  /// there once, not on every rebuild.
  String? _openedAt;

  @override
  void dispose() {
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

  void _scrollToUpNext({required bool animate}) {
    final target = _upNext.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeInOut,
    );
  }

  /// The search field above the path (#528, as the approved mockup drew
  /// it): always there, it finds units in the bar's course while it holds
  /// a search.
  Widget _searchField(AppLocalizations l10n) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 12),
    // One screen-reader node, the bar's full 56 in height (#26), named by
    // its hint even once the hint gives way to a search.
    child: MergeSemantics(
      child: Semantics(
        label: _search.text.isEmpty ? null : l10n.decksUnitSearchHint,
        child: SearchBar(
          controller: _search,
          hintText: l10n.decksUnitSearchHint,
          leading: const Icon(Icons.search),
          trailing: <Widget>[
            if (_search.text.isNotEmpty)
              IconButton(
                tooltip: l10n.decksSearchClose,
                icon: const Icon(Icons.close),
                onPressed: () => setState(_search.clear),
              ),
          ],
          elevation: const WidgetStatePropertyAll<double>(0),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsetsDirectional.symmetric(horizontal: 16),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    ),
  );

  bool get _searching => _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final languages = _languages(state);
    final code = state.shownLanguage;
    final ready = state.status == CatalogStatus.ready && code != null;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final where = ready && !_searching;
            // Both with their labels if they fit across, else icons alone.
            final compact =
                _Fab.extendedWidth(context, l10n.decksAdd) +
                    (where
                        ? _Fab.extendedWidth(context, l10n.decksWhereIAm) + 16
                        : 0) >
                constraints.maxWidth;
            return Row(
              children: <Widget>[
                if (where)
                  _Fab(
                    heroTag: 'where-i-am',
                    icon: Icons.my_location,
                    label: l10n.decksWhereIAm,
                    compact: compact,
                    distinct: true,
                    onPressed: _toUpNext,
                  ),
                const Spacer(),
                _Fab(
                  heroTag: 'add-deck',
                  icon: Icons.add,
                  label: l10n.decksAdd,
                  compact: compact,
                  onPressed: () => AppNavigator.openImport(context),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LanguageBarFrame(
          screen: LanguageBarScreen.decks,
          reportDetail: 'Decks',
          child: _body(context, state, languages, code),
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
    if (code == null && !_searching) {
      // No deck parsed: only broken files, if any.
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 96),
        children: <Widget>[
          _searchField(l10n),
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
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final view = _searching || code == null
            ? null
            : courseView(
                state,
                code,
                plan: widget.planOf?.call(code),
                answers: RecentAnswers(state.progress.log),
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
        return SingleChildScrollView(
          controller: _scroll,
          // Clear of the buttons that float over the path's end (#466):
          // their margin, their height and a gap, above any system inset.
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            4,
            16,
            fabClearance + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _searchField(l10n),
              if (_searching)
                SearchResults(
                  query: _search.text,
                  languages: languages,
                  planOf: widget.planOf,
                )
              else if (view != null) ...<Widget>[
                CourseCard(
                  view: view,
                  glyph: languageGlyph(view.language, state.decks),
                  hours: courseHours(state, code!),
                ),
                const SizedBox(height: 20),
                CoursePathView(
                  view: view,
                  state: state,
                  upNextKey: _upNext,
                  onOpen: (unit) => unit.onPath
                      ? AppNavigator.openUnit(context, unit.decks.first.id)
                      : AppNavigator.openDeck(context, unit.decks.first.id),
                ),
                const SizedBox(height: 32),
                const BeyondTheCourse(),
                if (view.otherDecks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  GroupedList(
                    header: l10n.pathOtherDecks,
                    outerRadius: AppRadii.card,
                    gap: 4,
                    children: <Widget>[
                      for (final entry in view.otherDecks) ...<Widget>[
                        DeckTile(
                          entry: entry,
                          badge: DeckBadge.forEntry(state, entry),
                          onTap: () => AppNavigator.openDeck(context, entry.id),
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

/// A floating button: with its label, or where two with their labels do
/// not fit across the screen, such as at a large text size, its icon alone,
/// named by its tooltip.
class _Fab extends StatelessWidget {
  const _Fab({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.distinct = false,
  });

  final Object heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  /// In `tertiary`, a role no card on the path uses (#466), so that "Where
  /// I am" reads as a control and not as one of the units under it, in
  /// light, dark and pure black alike.
  final bool distinct;

  /// About how wide the button is with its [label]: M3's 16 before the
  /// icon, the icon, 8 between, the label and 20 after it.
  static double extendedWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return 16 + 24 + 8 + width + 20;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = distinct ? scheme.tertiary : null;
    final fg = distinct ? scheme.onTertiary : null;
    if (compact) {
      return FloatingActionButton(
        heroTag: heroTag,
        tooltip: label,
        backgroundColor: bg,
        foregroundColor: fg,
        onPressed: onPressed,
        child: Icon(icon),
      );
    }
    return FloatingActionButton.extended(
      heroTag: heroTag,
      backgroundColor: bg,
      foregroundColor: fg,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
