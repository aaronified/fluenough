import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/grading/diacritics.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart' show QuestionCard;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import 'broken_deck_tile.dart';
import 'deck_content.dart';
import 'path_model.dart';
import 'path_parts.dart';
import 'unit_page.dart' show CardRow;
import 'word_mastery.dart';
import 'word_sheet.dart';

/// One thing a search on the Decks tab finds.
sealed class SearchHit {
  const SearchHit(this.language);

  final LanguageInfo language;
}

/// A written unit of a course.
final class UnitHit extends SearchHit {
  const UnitHit(
    super.language, {
    required this.number,
    required this.title,
    required this.decks,
    this.level,
  });

  final int number;
  final String title;
  final List<DeckEntry> decks;
  final CefrLevel? level;
}

/// A unit a course's plan names, not written yet.
final class ComingHit extends SearchHit {
  const ComingHit(super.language, this.unit);

  final ComingUnit unit;
}

/// A deck its course leaves out.
final class DeckHit extends SearchHit {
  const DeckHit(super.language, this.entry);

  final DeckEntry entry;
}

/// One card a search found: its own row, never grouped by meaning (#527).
final class CardHit extends SearchHit {
  const CardHit(super.language, this.card);

  final Card card;
}

/// [text] as the search compares it: lower case, Latin diacritics folded
/// away, so that `kalam` is found in `kalaṁ`.
String searchForm(String text) => foldDiacritics(text.toLowerCase());

/// Whether every word of [query] is found, ignoring case and Latin
/// diacritics, in one of [fields]. An empty query matches nothing: the
/// search shows nothing until something is typed. With [folded] the fields
/// are already in [searchForm], as a cached index holds them.
bool matchesAll(String query, Iterable<String> fields, {bool folded = false}) {
  final words = <String>[
    for (final word in searchForm(query).split(RegExp(r'\s+')))
      if (word.isNotEmpty) word,
  ];
  if (words.isEmpty) return false;
  final searchable = folded
      ? fields
      : <String>[for (final f in fields) searchForm(f)];
  return words.every((word) => searchable.any((field) => field.contains(word)));
}

/// The most card rows one search lists: the rows are built at once, inside
/// the Decks tab's own scrolling.
const int maxCardHits = 60;

/// A card and its searchable text, folded once.
typedef _IndexedCard = ({Card card, List<String> fields});

/// A deck's searchable cards, built the first time it is searched and kept
/// as long as the deck is.
final Expando<List<_IndexedCard>> _cardIndex = Expando<List<_IndexedCard>>(
  'card search index',
);

/// What a search can find a card by: its target, its spellings in the
/// course's other scripts, its readings, its meaning and its other meanings.
List<String> _cardFields(Card card) => <String>[
  card.target,
  ...card.targetScripts.values,
  ...card.readings,
  card.native,
  ...card.altNative,
  for (final sense in card.senses) sense.native,
];

List<_IndexedCard> _indexOf(DeckEntry entry) =>
    _cardIndex[entry] ??= <_IndexedCard>[
      // A grammar deck's cells and a rules deck's are forms of words taught
      // elsewhere, as on a unit's screen; set cards are not cards at all.
      if (entry.deck.pattern == null &&
          entry.deck.kind != DeckKind.reading &&
          entry.deck.kind != DeckKind.rules)
        for (final card in entry.cards)
          if (card is! QuestionCard && !card.practiceOnly)
            (
              card: card,
              fields: <String>[
                for (final field in _cardFields(card))
                  if (field.isNotEmpty) searchForm(field),
              ],
            ),
    ];

/// The cards of [language]'s course that [query] finds, each card once.
List<CardHit> searchCards(
  AppState state,
  String query,
  LanguageInfo language, {
  int limit = maxCardHits,
}) {
  final native = state.courseNative(language.code);
  final seen = <String>{};
  final hits = <CardHit>[];
  for (final entry in state.decks) {
    if (entry.language.code != language.code ||
        entry.deck.native.code != native) {
      continue;
    }
    for (final indexed in _indexOf(entry)) {
      if (hits.length >= limit) return hits;
      if (matchesAll(query, indexed.fields, folded: true) &&
          seen.add(indexed.card.id)) {
        hits.add(CardHit(language, indexed.card));
      }
    }
  }
  return hits;
}

/// What [query] finds in every course, in the order of [languages]: units by
/// their name, their decks' names, kinds and themes, their level or their
/// language; units still being written by name; and decks a course leaves
/// out, as the old deck list found them; then the course's cards, one row
/// each (#527).
List<SearchHit> searchCourses(
  AppState state,
  AppLocalizations l10n,
  String query,
  List<LanguageInfo> languages, {
  CoursePlan Function(String language)? planOf,
}) {
  final themes = state.themesByDeck;
  final hits = <SearchHit>[];
  final cards = <SearchHit>[];
  for (final language in languages) {
    final code = language.code;
    final plan = planOf?.call(code) ?? coursePlanOf(state, code);
    final units = state.courseUnits(code);
    final inCourse = <String>{};
    for (final (i, decks) in units.indexed) {
      inCourse.addAll(decks.map((e) => e.id));
      final title = unitTitle(state, decks);
      final found = unitOfDeck(state, decks.first.id, plan: plan);
      final fields = <String>[
        title,
        language.name,
        ?found?.level?.label,
        for (final entry in decks) ...<String>[
          entry.deck.name,
          ?themes[entry.id]?.name,
          deckKindLabel(l10n, entry),
        ],
      ];
      if (matchesAll(query, fields)) {
        hits.add(
          UnitHit(
            language,
            number: i + 1,
            title: title,
            decks: decks,
            level: found?.level,
          ),
        );
      }
    }
    for (final coming in plan.coming) {
      if (matchesAll(query, <String>[
        coming.title,
        language.name,
        ?coming.level?.label,
      ])) {
        hits.add(ComingHit(language, coming));
      }
    }
    for (final entry in state.decks) {
      if (entry.language.code != code || inCourse.contains(entry.id)) continue;
      if (matchesAll(query, <String>[
        entry.deck.name,
        language.name,
        ?themes[entry.id]?.name,
        deckKindLabel(l10n, entry),
      ])) {
        hits.add(DeckHit(language, entry));
      }
    }
    cards.addAll(searchCards(state, query, language));
  }
  return hits..addAll(cards);
}

/// The search's results: a row per unit found, with its course, level and
/// line and a pill saying where it stands; then deck files that could not
/// be read, by name.
class SearchResults extends StatelessWidget {
  const SearchResults({
    super.key,
    required this.query,
    required this.languages,
    this.planOf,
  });

  final String query;
  final List<LanguageInfo> languages;
  final CoursePlan Function(String language)? planOf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final hits = query.trim().isEmpty
            ? const <SearchHit>[]
            : searchCourses(state, l10n, query, languages, planOf: planOf);
        final q = query.trim().toLowerCase();
        final answers = RecentAnswers(state.progress.log);
        final broken = <BrokenDeck>[
          if (q.isNotEmpty)
            for (final file in state.brokenDecks)
              if (file.fileName.toLowerCase().contains(q)) file,
        ];
        if (hits.isEmpty && broken.isEmpty) {
          if (q.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.gutter,
              vertical: 32,
            ),
            child: Text(
              l10n.decksEmptySearch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        // Inside the Decks tab's own scrolling, under its search field
        // (#528), which leaves room for the buttons floating over its end.
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: <Widget>[
            if (hits.isNotEmpty)
              GroupedList(
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final hit in hits)
                    if (hit is CardHit)
                      CardRow(
                        card: hit.card,
                        language: hit.language,
                        mastery: answers.of(hit.card.id),
                        onTap: () => showWordSheet(
                          context,
                          card: hit.card,
                          language: hit.language,
                        ),
                      )
                    else
                      _HitTile(hit: hit, state: state),
                ],
              ),
            if (broken.isNotEmpty) ...<Widget>[
              if (hits.isNotEmpty) const SizedBox(height: 16),
              GroupedList(
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final file in broken) BrokenDeckTile(broken: file),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One result: its name, "Telugu · A1 · 18 words · 2 rules", and a pill.
class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.state});

  final SearchHit hit;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hit = this.hit;
    final language = hit.language.name;
    final (
      String title,
      String line,
      Widget pill,
      VoidCallback? onTap,
    ) = switch (hit) {
      UnitHit() => (
        hit.title,
        joinParts(l10n, <String>[
          language,
          ?hit.level?.label,
          unitMeta(l10n, state, UnitContent(hit.decks)),
        ]),
        _unitPill(hit),
        () => opensUnit(state, hit.decks.first.id)
            ? AppNavigator.openUnit(context, hit.decks.first.id)
            : AppNavigator.openDeck(context, hit.decks.first.id),
      ),
      ComingHit() => (
        hit.unit.title,
        joinParts(l10n, <String>[
          language,
          ?hit.unit.level?.label,
          if (hit.unit.words case final words?)
            l10n.pathComingWords(words)
          else
            l10n.pathComing,
        ]),
        Pill(
          text: l10n.pathComing,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
        null,
      ),
      // Drawn as a CardRow, not as a tile.
      CardHit() => (hit.card.target, language, const SizedBox.shrink(), null),
      DeckHit() => (
        hit.entry.deck.name,
        joinParts(l10n, <String>[language, deckKindLabel(l10n, hit.entry)]),
        DeckBadge.forEntry(state, hit.entry),
        () => AppNavigator.openDeck(context, hit.entry.id),
      ),
    };
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            pill,
          ],
        ),
      ),
    );
    return MergeSemantics(
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }

  /// A unit's pill: reviews due, Done, Not done, or Start for a language
  /// the profile does not learn.
  Widget _unitPill(UnitHit hit) {
    final language = hit.decks.first.language.code;
    if (!state.currentProfile.learns(language)) {
      return const DeckBadge(kind: DeckBadgeKind.start);
    }
    final due = state
        .buildSession(
          DrillRequest(deckIds: <String>{for (final e in hit.decks) e.id}),
        )
        .due
        .length;
    if (due > 0) return DeckBadge(kind: DeckBadgeKind.due, count: due);
    return hit.decks.every(state.isFinished)
        ? const DeckBadge(kind: DeckBadgeKind.done)
        : const DeckBadge(kind: DeckBadgeKind.notDone);
  }
}
