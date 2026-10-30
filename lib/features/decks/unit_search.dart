import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/unlocks.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/grading/diacritics.dart';
import '../../core/data/themes.dart' show DeckTheme;
import '../../core/models/card.dart' hide wordsOf;
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/leech_action.dart' show LeechEffects;
import '../../core/models/reading.dart' show QuestionCard;
import '../../core/models/review_event.dart' show ProgressKey;
import '../../core/search/fuzzy.dart';
import '../../core/search/query.dart';
import '../../core/search/script_of.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import 'broken_deck_tile.dart';
import 'deck_content.dart';
import 'path_model.dart';
import 'path_parts.dart';
import 'unit_page.dart' show CardRow;
import 'word_sheet.dart';

/// One thing a search on the Decks tab finds.
sealed class SearchHit {
  const SearchHit(this.language, {this.rank = 0, this.kind, this.tag});

  final LanguageInfo language;

  /// How well it matched, lower first: the quality of the worst word found
  /// ([MatchQuality]) twice, and one more for a match by a theme's tag.
  final int rank;

  /// What it is, for the chip on its row; null for a sentence deck.
  final SearchKind? kind;

  /// The theme tag it was found by, when not by its name.
  final String? tag;

  /// Whether it was found despite a typo.
  bool get isClose => rank ~/ 2 >= MatchQuality.close.index;
}

/// A written unit of a course.
final class UnitHit extends SearchHit {
  const UnitHit(
    super.language, {
    required this.number,
    required this.title,
    required this.decks,
    this.level,
    super.rank,
    super.kind,
    super.tag,
  });

  final int number;
  final String title;
  final List<DeckEntry> decks;
  final CefrLevel? level;
}

/// A unit a course's plan names, not written yet.
final class ComingHit extends SearchHit {
  const ComingHit(super.language, this.unit, {super.rank});

  final ComingUnit unit;
}

/// A deck its course leaves out.
final class DeckHit extends SearchHit {
  const DeckHit(
    super.language,
    this.entry, {
    super.rank,
    super.kind,
    super.tag,
  });

  final DeckEntry entry;
}

/// One card a search found: its own row, never grouped by meaning (#527).
final class CardHit extends SearchHit {
  const CardHit(super.language, this.card, {super.rank, super.kind});

  final Card card;
}

/// [text] as the search compares it: lower case, Latin diacritics folded
/// away, so that `kalam` is found in `kalaṁ`.
String searchForm(String text) => foldDiacritics(text.toLowerCase());

/// The words of [query], in [searchForm].
List<String> queryWords(String query) => <String>[
  for (final word in searchForm(query).split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// How well every word of [words] is found in [fields], all in
/// [searchForm]: the worst of the words' [MatchQuality] indexes, or null if
/// one is not found. With [typos] a word found only despite a typo counts
/// as [MatchQuality.close].
int? rankAll(List<String> words, List<String> fields, {bool typos = true}) {
  if (words.isEmpty) return null;
  var worst = 0;
  for (final word in words) {
    final quality = matchWord(word, fields, typos: typos);
    if (quality == null) return null;
    if (quality.index > worst) worst = quality.index;
  }
  return worst;
}

/// Whether every word of [query] is found, ignoring case and Latin
/// diacritics, in one of [fields], exactly. An empty query matches nothing:
/// the search shows nothing until something is typed. With [folded] the
/// fields are already in [searchForm], as a cached index holds them.
bool matchesAll(String query, Iterable<String> fields, {bool folded = false}) {
  final searchable = folded
      ? fields.toList()
      : <String>[for (final f in fields) searchForm(f)];
  return rankAll(queryWords(query), searchable, typos: false) != null;
}

/// What a deck is, for the `kind:` token and its chip, read from what decks
/// carry today, with no new deck field: reading; grammar (a pattern, a
/// grammar or rules deck, or the grammar tag); script (the script tag); a
/// deck whose cards are sentences for half or more, or phrasebook chunks,
/// has no kind (owner, 2026-10-16: "Leave out phrases as that will
/// otherwise confuse people"); every other deck is words.
SearchKind? searchKindOf(DeckEntry entry) {
  final deck = entry.deck;
  if (deck.kind == DeckKind.reading) return SearchKind.reading;
  if (deck.pattern != null ||
      deck.kind == DeckKind.grammar ||
      deck.kind == DeckKind.rules ||
      deck.tags.contains('grammar')) {
    return SearchKind.grammar;
  }
  if (entry.isScript) return SearchKind.script;
  final cards = deck.cards;
  if (cards.isEmpty) return SearchKind.words;
  final sentences = cards.where((c) => c.phrasebook || isSentence(c)).length;
  return sentences * 2 >= cards.length ? null : SearchKind.words;
}

/// A card and its searchable text, folded once.
typedef _IndexedCard = ({DeckEntry entry, Card card, List<String> fields});

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
              entry: entry,
              card: card,
              fields: <String>[
                for (final field in _cardFields(card))
                  if (field.isNotEmpty) searchForm(field),
              ],
            ),
    ];

/// A card's status as the `status:` token reads it (#527): set aside is
/// read over all the card's skills, since the drillable ones leave
/// set-aside pairs out; struggling counts lifetime lapses, as the Leeches
/// page does.
CardStatus Function(Card card) cardStatusReader(AppState state) {
  final modesOf = state.drillableModesNow();
  final effects = LeechEffects(state.progress.leechActions);
  final now = state.now();
  final lapses = <ProgressKey, int>{
    for (final leech in state.progress.index.leeches()) leech.key: leech.lapses,
  };
  return (card) {
    final setAside = DrillMode.drills.any(
      (mode) => effects.isSetAside((cardId: card.id, mode: mode)),
    );
    final skills = <SkillState>[
      for (final mode in modesOf(card))
        _skillOf(state, card, mode, now, lapses[(cardId: card.id, mode: mode)]),
    ];
    return cardStatusOf(setAside: setAside, skills: skills);
  };
}

SkillState _skillOf(
  AppState state,
  Card card,
  DrillMode mode,
  DateTime now,
  int? lapses,
) {
  final s = state.progress.stateOf(card.id, mode);
  return SkillState(
    scheduled: s != null,
    intervalDays: s?.intervalDays ?? 0,
    due: s?.isDue(now) ?? false,
    lapses: lapses ?? 0,
  );
}

/// The themes [language]'s course has a theme deck for, in
/// `decks/themes.yaml`'s order: what `theme:` offers (owner, 2026-10-16:
/// "Only this course's").
List<DeckTheme> courseThemes(AppState state, String language) {
  final used = <String>{
    for (final entry in state.decks)
      if (entry.language.code == language)
        if (state.themeOf(entry) case final theme?) theme.id,
  };
  return <DeckTheme>[
    for (final theme in state.themes)
      if (used.contains(theme.id)) theme,
  ];
}

/// The script [text] is typed in when it is not one the course reads: not
/// Latin (read as the transliteration and as English) and not one of
/// [language]'s. Such a query is not searched; the learner is offered what
/// to do instead (mockup section 7).
String? foreignScript(String text, LanguageInfo language) {
  final script = scriptOf(text);
  if (script == null || script == 'latin') return null;
  return scriptBelongsTo(script, language.allScripts) ? null : script;
}

/// What a search found, with what the screen says about it.
class SearchOutcome {
  const SearchOutcome({
    this.hits = const <SearchHit>[],
    this.broken = const <BrokenDeck>[],
    this.parsed = const ParsedSearch(),
    this.chips = const <SearchToken, String>{},
    this.closeOnly = false,
    this.otherKinds = 0,
    this.foreign,
  });

  final List<SearchHit> hits;
  final List<BrokenDeck> broken;

  /// The bar's text read, with the typed tokens in [chips] as well.
  final ParsedSearch parsed;

  /// Every chip: those the bar holds and those typed.
  final Map<SearchToken, String> chips;

  /// Everything was found despite a typo: "Close matches for ...".
  final bool closeOnly;

  /// With a kind chosen and nothing of it, how many results of the other
  /// kinds there are.
  final int otherKinds;

  /// A script the course does not read, which the query is typed in.
  final String? foreign;

  /// Whether there is anything to search for: text or a chip.
  bool get active => parsed.text.isNotEmpty || chips.isNotEmpty;

  bool get isEmpty => hits.isEmpty && broken.isEmpty;
}

/// What the bar's [text] and [chips] find in [languages]' courses, in the
/// order of [languages]: units by their name, their decks' names, kinds and
/// themes (and a theme's tags, after names), their level or their language;
/// units still being written by name; decks a course leaves out; then the
/// course's cards, one row each, however many (#527). Exact matches come
/// first, then those found despite a typo, which are looked for only when
/// nothing is found exactly. `kind:`, `status:` and `theme:` narrow it, and
/// with chips and no text everything they allow is listed, in path order.
SearchOutcome runSearch(
  AppState state,
  AppLocalizations l10n, {
  required String text,
  Map<SearchToken, String> chips = const <SearchToken, String>{},
  required List<LanguageInfo> languages,
  CoursePlan Function(String language)? planOf,
}) {
  final parsed = parseSearch(
    text,
    themes: <String>[for (final t in state.themes) t.id],
  );
  final all = <SearchToken, String>{...chips, ...parsed.chips};
  final words = queryWords(parsed.text);
  final q = parsed.text.trim();
  final broken = <BrokenDeck>[
    if (q.isNotEmpty)
      for (final file in state.brokenDecks)
        if (file.fileName.toLowerCase().contains(q.toLowerCase())) file,
  ];
  if (words.isEmpty && all.isEmpty) {
    return SearchOutcome(parsed: parsed, chips: all);
  }
  if (languages.isNotEmpty && words.isNotEmpty) {
    final foreign = foreignScript(parsed.text, languages.first);
    if (foreign != null) {
      return SearchOutcome(parsed: parsed, chips: all, foreign: foreign);
    }
  }
  List<SearchHit> collect(
    Map<SearchToken, String> chips, {
    bool typos = false,
  }) => _collect(state, l10n, words, chips, languages, planOf, typos);

  var hits = collect(all);
  var closeOnly = false;
  if (hits.isEmpty && words.isNotEmpty) {
    hits = collect(all, typos: true);
    closeOnly = hits.isNotEmpty;
  }
  var otherKinds = 0;
  if (hits.isEmpty && all.containsKey(SearchToken.kind)) {
    final without = <SearchToken, String>{...all}..remove(SearchToken.kind);
    var other = collect(without);
    if (other.isEmpty && words.isNotEmpty) {
      other = collect(without, typos: true);
    }
    otherKinds = other.length;
  }
  return SearchOutcome(
    hits: hits,
    broken: broken,
    parsed: parsed,
    chips: all,
    closeOnly: closeOnly,
    otherKinds: otherKinds,
  );
}

List<SearchHit> _collect(
  AppState state,
  AppLocalizations l10n,
  List<String> words,
  Map<SearchToken, String> chips,
  List<LanguageInfo> languages,
  CoursePlan Function(String language)? planOf,
  bool typos,
) {
  final kindChip = chips[SearchToken.kind] == null
      ? null
      : SearchKind.values.byName(chips[SearchToken.kind]!);
  final statusChip = switch (chips[SearchToken.status]) {
    final slug? => CardStatus.values.firstWhere((s) => s.slug == slug),
    null => null,
  };
  final themeChip = chips[SearchToken.theme];
  final themes = state.themesByDeck;
  final statusOf = statusChip == null ? null : cardStatusReader(state);
  final narrowed = chips.isNotEmpty;

  bool deckAllowed(DeckEntry e) =>
      (kindChip == null || searchKindOf(e) == kindChip) &&
      (themeChip == null || state.themeOf(e)?.id == themeChip);

  // A rank from the words, by names first and then by a theme's tags.
  (int, String?)? rankOf(List<String> names, List<String> tags) {
    if (words.isEmpty) return (0, null);
    final byName = rankAll(words, names, typos: typos);
    if (byName != null) return (byName * 2, null);
    if (tags.isEmpty) return null;
    final byTag = rankAll(words, <String>[...names, ...tags], typos: typos);
    if (byTag == null) return null;
    final tag = tags.firstWhere(
      (t) => matchWord(words.first, <String>[t], typos: typos) != null,
      orElse: () => tags.first,
    );
    return (byTag * 2 + 1, tag);
  }

  List<String> fold(Iterable<String> texts) => <String>[
    for (final t in texts)
      if (t.isNotEmpty) searchForm(t),
  ];

  final units = <SearchHit>[];
  final cards = <SearchHit>[];
  for (final language in languages) {
    final code = language.code;
    final plan = planOf?.call(code) ?? coursePlanOf(state, code);
    final courseUnits = state.courseUnits(code);
    final inCourse = <String>{};
    for (final (i, decks) in courseUnits.indexed) {
      inCourse.addAll(decks.map((e) => e.id));
      if (statusChip != null) continue;
      if (!decks.any(deckAllowed)) continue;
      final title = unitTitle(state, decks);
      final found = unitOfDeck(state, decks.first.id, plan: plan);
      final names = fold(<String>[
        title,
        language.name,
        ?found?.level?.label,
        for (final entry in decks) ...<String>[
          entry.deck.name,
          ?themes[entry.id]?.name,
          deckKindLabel(l10n, entry),
        ],
      ]);
      final tags = fold(<String>[
        for (final entry in decks) ...?themes[entry.id]?.tags,
      ]);
      final ranked = rankOf(names, tags);
      if (ranked == null) continue;
      units.add(
        UnitHit(
          language,
          number: i + 1,
          title: title,
          decks: decks,
          level: found?.level,
          rank: ranked.$1,
          kind: kindChip ?? decks.map(searchKindOf).nonNulls.firstOrNull,
          tag: ranked.$2,
        ),
      );
    }
    if (!narrowed) {
      for (final coming in plan.coming) {
        final r = rankAll(
          words,
          fold(<String>[coming.title, language.name, ?coming.level?.label]),
          typos: typos,
        );
        if (r != null) units.add(ComingHit(language, coming, rank: r * 2));
      }
    }
    final native = state.courseNative(code);
    for (final entry in state.decks) {
      if (entry.language.code != code) continue;
      if (!inCourse.contains(entry.id) &&
          statusChip == null &&
          deckAllowed(entry)) {
        final names = fold(<String>[
          entry.deck.name,
          language.name,
          ?themes[entry.id]?.name,
          deckKindLabel(l10n, entry),
        ]);
        final ranked = rankOf(names, fold(themes[entry.id]?.tags ?? const []));
        if (ranked != null) {
          units.add(
            DeckHit(
              language,
              entry,
              rank: ranked.$1,
              kind: searchKindOf(entry),
              tag: ranked.$2,
            ),
          );
        }
      }
    }
    final seen = <String>{};
    for (final entry in state.decks) {
      if (entry.language.code != code || entry.deck.native.code != native) {
        continue;
      }
      if (!deckAllowed(entry)) continue;
      final kind = searchKindOf(entry);
      for (final indexed in _indexOf(entry)) {
        var rank = 0;
        if (words.isNotEmpty) {
          final r = rankAll(words, indexed.fields, typos: typos);
          if (r == null) continue;
          rank = r * 2;
        }
        if (statusOf != null && statusOf(indexed.card) != statusChip) {
          continue;
        }
        if (seen.add(indexed.card.id)) {
          cards.add(CardHit(language, indexed.card, rank: rank, kind: kind));
        }
      }
    }
  }
  // Stable: equal ranks keep the path's order.
  List<SearchHit> ordered(List<SearchHit> hits) {
    final indexed = hits.indexed.toList()
      ..sort((a, b) {
        final byRank = a.$2.rank.compareTo(b.$2.rank);
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return <SearchHit>[for (final (_, hit) in indexed) hit];
  }

  return <SearchHit>[...ordered(units), ...ordered(cards)];
}

/// The hits of [query] alone, the units first and then the cards: the
/// search without the bar's chips. [chips] narrow it as the bar's do.
List<SearchHit> searchCourses(
  AppState state,
  AppLocalizations l10n,
  String query,
  List<LanguageInfo> languages, {
  CoursePlan Function(String language)? planOf,
  Map<SearchToken, String> chips = const <SearchToken, String>{},
}) => runSearch(
  state,
  l10n,
  text: query,
  chips: chips,
  languages: languages,
  planOf: planOf,
).hits;

/// One line the search suggests while typing (mockup section 1): a
/// completion of what is typed.
class SearchSuggestion {
  const SearchSuggestion(this.text, {this.token});

  /// The whole text it puts in the bar.
  final String text;

  /// The token it names, if it is a token's name.
  final SearchToken? token;
}

/// At most [max] completions of [typed], never what is typed itself: the
/// token names that start with it, then the course's deck and unit names,
/// then the words its cards know, the commonest first. None for a typo with
/// no completion, and none for a query in another script.
List<SearchSuggestion> searchSuggestions(
  AppState state,
  AppLocalizations l10n,
  String typed,
  LanguageInfo language, {
  int max = 3,
}) {
  final text = typed.trimLeft();
  final folded = searchForm(text.trimRight());
  if (folded.isEmpty) return const <SearchSuggestion>[];
  final script = scriptOf(folded);
  if (script != null && script != 'latin') return const <SearchSuggestion>[];
  final split = text.lastIndexOf(RegExp(r'\s'));
  final before = split < 0 ? '' : text.substring(0, split + 1);
  final last = searchForm(text.substring(split + 1));
  if (last.isEmpty) return const <SearchSuggestion>[];
  final out = <SearchSuggestion>[];
  final seen = <String>{folded};
  void add(SearchSuggestion s) {
    if (out.length < max && seen.add(searchForm(s.text))) out.add(s);
  }

  if (before.isEmpty) {
    for (final token in SearchToken.values) {
      final name = '${token.key}:';
      if (name.startsWith(last) && name != last) {
        add(SearchSuggestion(name, token: token));
      }
    }
  }
  final code = language.code;
  for (final decks in state.courseUnits(code)) {
    for (final name in <String>[unitTitle(state, decks)]) {
      if (searchForm(name).startsWith(folded)) add(SearchSuggestion(name));
    }
    for (final entry in decks) {
      if (searchForm(entry.deck.name).startsWith(folded)) {
        add(SearchSuggestion(entry.deck.name));
      }
    }
  }
  if (out.length < max) {
    final native = state.courseNative(code);
    final counts = <String, int>{};
    for (final entry in state.decks) {
      if (entry.language.code != code || entry.deck.native.code != native) {
        continue;
      }
      for (final indexed in _indexOf(entry)) {
        for (final field in indexed.fields) {
          for (final word in wordsOf(field)) {
            if (word.length > last.length &&
                word.startsWith(last) &&
                isLatinText(word)) {
              counts[word] = (counts[word] ?? 0) + 1;
            }
          }
        }
      }
    }
    final words = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    for (final word in words) {
      add(SearchSuggestion('$before$word'));
    }
  }
  return out;
}

/// The search's results, as slivers inside the Decks tab's own scrolling
/// (#528): a row per unit, deck or card found, built as the list scrolls (no
/// cap, owner, 2026-10-21), each with its kind as a chip that narrows the
/// search to that kind when tapped; then deck files that could not be read.
class SearchResultsSliver extends StatelessWidget {
  const SearchResultsSliver({
    super.key,
    required this.outcome,
    required this.query,
    required this.onKind,
    required this.onRemoveKind,
  });

  final SearchOutcome outcome;

  /// The text the learner typed, for the lines that quote it.
  final String query;

  /// A kind chip on a row was tapped.
  final ValueChanged<SearchKind> onKind;

  /// "Remove kind: ..." was tapped.
  final VoidCallback onRemoveKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answers = state.recentAnswers;
    final hits = outcome.hits;
    final quoted = outcome.parsed.text.isEmpty
        ? query.trim()
        : outcome.parsed.text;
    if (hits.isEmpty && outcome.broken.isEmpty) {
      if (!outcome.active || outcome.foreign != null) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      final kind = outcome.chips[SearchToken.kind];
      final kindLabel = kind == null
          ? null
          : searchKindLabel(l10n, SearchKind.values.byName(kind));
      final noKind = kindLabel != null && outcome.otherKinds > 0;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.gutter,
            vertical: 32,
          ),
          child: Column(
            children: <Widget>[
              Text(
                noKind
                    ? l10n.searchNoKind(kindLabel.toLowerCase(), quoted)
                    : l10n.searchNothing(quoted),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                noKind
                    ? l10n.searchOtherKinds(outcome.otherKinds)
                    : l10n.searchNothingBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (noKind) ...<Widget>[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRemoveKind,
                  child: Text(l10n.searchRemoveKind(kindLabel)),
                ),
              ],
            ],
          ),
        ),
      );
    }
    const outer = Radius.circular(AppRadii.card);
    const inner = Radius.circular(AppRadii.innerRow);
    BorderRadius radius(int i) => BorderRadius.vertical(
      top: i == 0 ? outer : inner,
      bottom: i == hits.length - 1 ? outer : inner,
    );
    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (outcome.closeOnly && hits.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
              child: Text(
                l10n.searchCloseMatches(quoted),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final hit = hits[i];
            final Widget row = hit is CardHit
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      CardRow(
                        card: hit.card,
                        language: hit.language,
                        mastery: answers.of(hit.card.id),
                        onTap: () => showWordSheet(
                          context,
                          card: hit.card,
                          language: hit.language,
                        ),
                      ),
                      _KindChipLine(kind: hit.kind, onKind: onKind),
                    ],
                  )
                : _HitTile(hit: hit, state: state, onKind: onKind);
            return Padding(
              padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 4),
              child: Material(
                color: scheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: radius(i)),
                child: row,
              ),
            );
          },
        ),
        if (outcome.broken.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                top: hits.isNotEmpty ? 16 : 0,
              ),
              child: GroupedList(
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final file in outcome.broken)
                    BrokenDeckTile(broken: file),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A kind's name as the chip and the token's value show it.
String searchKindLabel(AppLocalizations l10n, SearchKind kind) =>
    switch (kind) {
      SearchKind.words => l10n.searchKindWords,
      SearchKind.grammar => l10n.searchKindGrammar,
      SearchKind.script => l10n.searchKindScript,
      SearchKind.reading => l10n.searchKindReading,
    };

/// A row's kind as a chip; a tap narrows the search to that kind.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.onKind});

  final SearchKind kind;
  final ValueChanged<SearchKind> onKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = searchKindLabel(l10n, kind);
    return Semantics(
      button: true,
      label: l10n.searchChip(SearchToken.kind.key, label),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onKind(kind),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium!
                .copyWith(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}

/// The line holding a card row's kind chip.
class _KindChipLine extends StatelessWidget {
  const _KindChipLine({required this.kind, required this.onKind});

  final SearchKind? kind;
  final ValueChanged<SearchKind> onKind;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    if (kind == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _KindChip(kind: kind, onKind: onKind),
      ),
    );
  }
}

/// One result: its name, "Telugu · A1 · 18 words · 2 rules", and a pill.
class _HitTile extends StatelessWidget {
  const _HitTile({
    required this.hit,
    required this.state,
    required this.onKind,
  });

  final SearchHit hit;
  final AppState state;
  final ValueChanged<SearchKind> onKind;

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
                  if (hit.tag case final tag?)
                    Text(
                      l10n.searchTagged(tag),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (hit.kind case final kind?)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 6),
                      child: _KindChip(kind: kind, onKind: onKind),
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
