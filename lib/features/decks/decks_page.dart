import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/data/themes.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/language_chips.dart';
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
              // One screen-reader node, the bar's full 56 in height: alone,
              // the field inside is a 24-tall tap target (#26).
              child: MergeSemantics(
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
            ),
            const SizedBox(height: 12),
            LanguageChips(
              languages: state.languages,
              decks: state.decks,
              allLabel: l10n.decksFilterAll,
              semanticLabel: l10n.decksFilterLabel,
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
        final themes = _query.trim().isEmpty
            ? const <String, DeckTheme>{}
            : state.themesByDeck;
        final decks = <DeckEntry>[
          for (final entry in state.decks)
            if ((_language == null || entry.language.code == _language) &&
                deckMatches(
                  entry,
                  _query,
                  also: <String>[
                    ?themes[entry.id]?.name,
                    deckKindLabel(l10n, entry),
                  ],
                ))
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
                    state.progress.learnedIn(
                      entry.cards.map((card) => card.id),
                    ),
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

/// A course's decks under the course, or a run of decks outside any course
/// with theme decks, with no heading.
typedef DeckSection = ({DeckEntry? course, List<DeckEntry> decks});

/// [decks], in order, in sections: every deck of a course that teaches
/// themes under one heading for that course (#52), at the place its first
/// deck comes, grammar decks included (#119), and each run of other decks on
/// its own. Grouped by course rather than by neighbour, so that a course
/// stays together whatever order its decks come in.
List<DeckSection> courseSections(List<DeckEntry> decks, AppState state) {
  String courseOf(DeckEntry e) => '${e.language.code}/${e.deck.native.code}';
  // From every deck, not only those shown, so that a grammar deck a search
  // finds still sits under its course.
  final themed = <String>{
    for (final entry in state.decks)
      if (state.themeOf(entry) != null) courseOf(entry),
  };
  final sections = <DeckSection>[];
  final byCourse = <String, DeckSection>{};
  for (final entry in decks) {
    final course = courseOf(entry);
    if (themed.contains(course)) {
      final section = byCourse[course];
      if (section != null) {
        section.decks.add(entry);
      } else {
        sections.add(byCourse[course] = (course: entry, decks: [entry]));
      }
      continue;
    }
    if (sections.isEmpty || sections.last.course != null) {
      sections.add((course: null, decks: <DeckEntry>[]));
    }
    sections.last.decks.add(entry);
  }
  return sections;
}
