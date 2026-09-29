import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import 'broken_deck_tile.dart';
import 'deck_content.dart';
import 'number_practice_tile.dart';

/// The Decks tab: search, language chips, every deck with its badge,
/// broken-deck rows, and Add deck.
///
/// Design screen `decks`. The chips are the languages the loaded decks teach
/// (`AppState.languages`), never a list in code. Every deck is listed, not
/// only the profile's: a deck in a language the profile does not learn says
/// "Start".
class DecksPage extends StatefulWidget {
  const DecksPage({super.key});

  @override
  State<DecksPage> createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// The language chip chosen, by code, or null for All.
  String? _language;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppNavigator.openImport(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.decksAdd),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TabHeader(title: l10n.decksTitle),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.gutter,
              ),
              child: SearchBar(
                controller: _search,
                hintText: l10n.decksSearchHint,
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll<double>(0),
                constraints: const BoxConstraints(minHeight: 56),
                padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsetsDirectional.symmetric(horizontal: 16),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 12),
            _LanguageChips(
              state: state,
              selected: _language,
              onSelected: (code) => setState(() => _language = code),
            ),
            const SizedBox(height: 12),
            Expanded(child: _list(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, AppState state) {
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

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final decks = <DeckEntry>[
          for (final entry in state.decks)
            if ((_language == null || entry.language.code == _language) &&
                deckMatches(entry, _query))
              entry,
        ];
        final q = _query.trim().toLowerCase();
        // A broken file has no language, so it shows under All only.
        final broken = <BrokenDeck>[
          if (_language == null)
            for (final file in state.brokenDecks)
              if (file.fileName.toLowerCase().contains(q)) file,
        ];

        if (decks.isEmpty && broken.isEmpty) {
          final nothingAtAll = state.decks.isEmpty && state.brokenDecks.isEmpty;
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.gutter,
              vertical: 32,
            ),
            child: Text(
              nothingAtAll ? l10n.decksEmpty : l10n.decksEmptySearch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        Widget tile(DeckEntry entry) {
          final theme = state.themeOf(entry);
          return DeckTile(
            entry: entry,
            badge: DeckBadge.forEntry(state, entry),
            meta: theme == null
                ? null
                : l10n.deckMetaTheme(
                    state.themes.indexOf(theme) + 1,
                    state.progress.learnedIn(entry.id),
                    entry.itemCount,
                  ),
            onTap: () => AppNavigator.openDeck(context, entry.id),
          );
        }

        final sections = courseSections(decks, state);
        return ListView(
          // Clear of Add deck, which floats over the list's end.
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 96),
          children: <Widget>[
            for (final (i, section) in sections.indexed) ...<Widget>[
              if (i > 0) const SizedBox(height: 20),
              GroupedList(
                header: section.course == null
                    ? null
                    : l10n.decksCourseHeading(
                        section.course!.language.name,
                        section.course!.deck.native.name,
                      ),
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final entry in section.decks) ...<Widget>[
                    tile(entry),
                    if (hasNumberPractice(state, entry))
                      NumberPracticeTile(deck: entry),
                  ],
                  if (i == sections.length - 1)
                    for (final file in broken) BrokenDeckTile(broken: file),
                ],
              ),
            ],
            if (sections.isEmpty)
              GroupedList(
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final file in broken) BrokenDeckTile(broken: file),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// All, then one chip per language the decks teach, scrolling sideways.
class _LanguageChips extends StatelessWidget {
  const _LanguageChips({
    required this.state,
    required this.selected,
    required this.onSelected,
  });

  final AppState state;
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// The glyph of the first deck in [language], so a language's chip shows
  /// the same character as its deck.
  String _glyphOf(LanguageInfo language) {
    for (final entry in state.decks) {
      if (entry.language.code == language.code) return entry.glyph;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[
      FilterChip(
        label: Text(l10n.decksFilterAll),
        selected: selected == null,
        onSelected: (_) => onSelected(null),
      ),
      for (final language in state.languages)
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ChipGlyph(
                glyph: _glyphOf(language),
                language: language,
                selected: selected == language.code,
              ),
              const SizedBox(width: 6),
              Text(language.name),
            ],
          ),
          selected: selected == language.code,
          onSelected: (_) => onSelected(language.code),
        ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.decksFilterLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSizes.gutter,
        ),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < chips.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A language's character on a small tile inside its chip.
class _ChipGlyph extends StatelessWidget {
  const _ChipGlyph({
    required this.glyph,
    required this.language,
    required this.selected,
  });

  final String glyph;
  final LanguageInfo language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.surfaceContainerLowest
              : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          glyph,
          locale: Locale(language.code),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 14,
            height: 22 / 14,
            color: selected ? scheme.onSurface : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// A run of deck rows: a course's theme decks, under the course, or decks
/// outside the theme path, with no heading.
typedef DeckSection = ({DeckEntry? course, List<DeckEntry> decks});

/// [decks], in order, cut into sections: each run of one course's theme
/// decks under that course (#52), and each run of other decks on its own.
/// The catalog already puts a course's theme decks together, in path order.
List<DeckSection> courseSections(List<DeckEntry> decks, AppState state) {
  String? courseOf(DeckEntry e) => state.themeOf(e) == null
      ? null
      : '${e.language.code}/${e.deck.native.code}';
  final sections = <DeckSection>[];
  String? current;
  for (final entry in decks) {
    final course = courseOf(entry);
    if (sections.isEmpty || course != current) {
      sections.add((
        course: course == null ? null : entry,
        decks: <DeckEntry>[],
      ));
      current = course;
    }
    sections.last.decks.add(entry);
  }
  return sections;
}
