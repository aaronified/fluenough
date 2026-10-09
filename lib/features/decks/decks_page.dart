import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import 'broken_deck_tile.dart';
import 'course_card.dart';
import 'course_chips.dart';
import 'number_practice_tile.dart';
import 'path_model.dart';
import 'path_view.dart';
import 'unit_search.dart';
import 'word_mastery.dart';

/// The Decks tab: a course's path (docs/plans/path-redesign.md, the owner's
/// design), chosen by the course chips, opening where the learner is; a
/// search across every course's units; "Where I am" and Add deck.
///
/// Every language the catalog teaches has a chip, those the profile learns
/// first, so that any course can be looked at and started, as before. A
/// unit on the path opens its screen; a deck the path leaves out opens its
/// own, from the path or from "Other decks" under it.
class DecksPage extends StatefulWidget {
  const DecksPage({
    super.key,
    this.planOf,
    this.initialLanguage,
    this.initialQuery,
  });

  /// Each course's plan, in place of [coursePlanOf]: the levels and units
  /// coming, which no path marks yet. For tests and the debug gallery.
  final CoursePlan Function(String language)? planOf;

  /// The course shown first, by language code; by default the first the
  /// profile learns.
  final String? initialLanguage;

  /// A search to open with, for the debug gallery and tests.
  final String? initialQuery;

  @override
  State<DecksPage> createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late bool _searching = widget.initialQuery != null;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _upNext = GlobalKey();

  /// The course chosen, by language code, or null for the default.
  late String? _language = widget.initialLanguage;

  /// The course the path last opened at its unit up next, so that it opens
  /// there once, not on every rebuild.
  String? _openedAt;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Every language the catalog teaches: those the profile learns first, in
  /// the order the learner chose them, then the rest in the catalog's
  /// order.
  List<LanguageInfo> _languages(AppState state) {
    final all = state.languages;
    final profile = state.currentProfile;
    final order = <String>[
      ...state.settings.learningLanguages,
      ...?profile.languages,
    ];
    int rank(LanguageInfo l) {
      final i = order.indexOf(l.code);
      return i < 0 ? order.length : i;
    }

    final learned = <LanguageInfo>[
      for (final l in all)
        if (profile.learns(l.code)) l,
    ];
    final ranked = learned.indexed.toList()
      ..sort((a, b) {
        final byRank = rank(a.$2).compareTo(rank(b.$2));
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return <LanguageInfo>[
      for (final (_, l) in ranked) l,
      ...all.where((l) => !profile.learns(l.code)),
    ];
  }

  /// Scrolls the path to the unit up next.
  void _toUpNext({bool animate = true}) {
    final target = _upNext.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeInOut,
    );
  }

  void _choose(String code) {
    if (code == _language) return;
    setState(() => _language = code);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final languages = _languages(state);
    final current = languages.any((l) => l.code == _language)
        ? _language
        : null;
    final code = current ?? languages.firstOrNull?.code;
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
                    secondary: true,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.decksTitle,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _searching
                        ? l10n.decksSearchClose
                        : l10n.decksSearchOpen,
                    isSelected: _searching,
                    icon: Icon(_searching ? Icons.close : Icons.search),
                    onPressed: _toggleSearch,
                  ),
                  ReportButton(detail: l10n.decksTitle),
                ],
              ),
            ),
            if (_searching) ...<Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSizes.gutter,
                ),
                // One screen-reader node, the bar's full 56 in height (#26).
                child: MergeSemantics(
                  child: SearchBar(
                    controller: _search,
                    autoFocus: widget.initialQuery == null,
                    hintText: l10n.decksUnitSearchHint,
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll<double>(0),
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                      EdgeInsetsDirectional.symmetric(horizontal: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (ready) ...<Widget>[
              ListenableBuilder(
                listenable: state.progress,
                builder: (context, _) => CourseChips(
                  languages: languages,
                  decks: state.decks,
                  due: <String, int>{
                    for (final language in languages)
                      if (state.currentProfile.learns(language.code))
                        language.code: state
                            .buildSession(
                              DrillRequest.today(language: language.code),
                            )
                            .due
                            .length,
                  },
                  selected: code,
                  onSelected: _choose,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(child: _body(context, state, languages, code)),
          ],
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
    if (_searching) {
      return SearchResults(
        query: _search.text,
        languages: languages,
        planOf: widget.planOf,
      );
    }
    if (code == null) {
      // No deck parsed: only broken files, if any.
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 96),
        children: <Widget>[
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
        final view = courseView(
          state,
          code,
          plan: widget.planOf?.call(code),
          answers: RecentAnswers(state.progress.log),
        );
        if (view == null) return const SizedBox.shrink();
        if (_openedAt != code) {
          _openedAt = code;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _toUpNext(animate: false);
          });
        }
        return SingleChildScrollView(
          controller: _scroll,
          // Clear of the buttons that float over the path's end.
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CourseCard(
                view: view,
                glyph: languageGlyph(view.language, state.decks),
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
    this.secondary = false,
  });

  final Object heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool compact;
  final bool secondary;

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
    final bg = secondary ? scheme.secondaryContainer : null;
    final fg = secondary ? scheme.onSecondaryContainer : null;
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
