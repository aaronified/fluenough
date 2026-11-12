/// Search items and kinds (wiki/Plan-Deck-Kinds-And-Topics.md, D10, T16): the
/// things the Decks search finds beyond cards (situations, topics, decks,
/// grammar concepts, units, culture and proverbs), each with a search kind
/// that is data (`decks/sections.yaml`), typo-tolerant through the existing
/// FTS5 index and the matcher in `fuzzy.dart`, and level-aware. Free of
/// Flutter, so that it is tested in milliseconds.
///
/// Two steps, as ADR-0049: the [ItemCorpus] holds every row and, where the
/// platform has FTS5, narrows them through [CardSearchIndex]; the matcher then
/// decides, exactly as it does for cards, so the results are the same with or
/// without the index.
///
/// The level rule (D2): a deck, topic, situation, unit or concept above the
/// learner's level is listed marked ([ItemResult.aboveLevel]) and is not
/// startable, and the setting "Hide what is above my level" ([hideAbove])
/// removes it; a card above the level, culture and proverb cards included, is
/// never in a result at all.
library;

import '../data/course_path.dart' show LanguagePath;
import '../data/sections.dart';
import '../decks/deck_index.dart' show IndexShelf;
import '../decks/levels.dart' show levelOfUnit;
import '../grading/diacritics.dart';
import '../models/card.dart';
import '../models/creator.dart';
import '../models/deck.dart';
import '../models/level.dart';
import '../models/reading.dart' show QuestionCard;
import '../models/situation.dart';
import '../models/topic.dart';
import 'card_index.dart';
import 'fuzzy.dart';

/// Where an item comes from; its search kind is separate, and data.
enum SearchItemType { card, deck, unit, concept, topic, situation }

/// The search kinds the code itself knows, by id; the file may list more that
/// reuse a row template.
abstract final class ResultKind {
  static const String situations = 'situations';
  static const String topics = 'topics';
  static const String decks = 'decks';
  static const String concepts = 'concepts';
  static const String cards = cardsKind;
  static const String units = 'units';
}

/// [text] as the search compares it: lower case, Latin diacritics folded away.
String foldForSearch(String text) => foldDiacritics(text.toLowerCase());

/// The words of [query], folded.
List<String> searchWords(String query) => <String>[
  for (final word in foldForSearch(query).split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// What a search can find a card by: its target, its spellings in the
/// course's other scripts, its readings, its meaning and its other meanings
/// (as `unit_search.dart` indexes them).
List<String> cardSearchFields(Card card) => <String>[
  card.target,
  ...card.targetScripts.values,
  ...card.readings,
  card.native,
  ...card.altNative,
  for (final sense in card.senses) sense.native,
];

/// The id of an item other than a card: its type and its own id, so that no
/// item's id is another's, and a card keeps its plain id.
String itemKey(SearchItemType type, String id) =>
    type == SearchItemType.card ? id : '${type.name}:$id';

/// One searchable row, with what a result needs to be drawn.
class ItemRow {
  const ItemRow({
    required this.type,
    required this.id,
    required this.kind,
    required this.fields,
    this.language = '',
    this.level,
    this.parent,
    this.hidden = false,
    this.collapseTo,
  });

  final SearchItemType type;

  /// The item's id within its type (a card id, a deck id, `<lang>:3` for a
  /// unit, ...).
  final String id;

  /// The search kind (tab) it is found under.
  final String kind;

  /// Its text, one string per field, folded ([foldForSearch]).
  final List<String> fields;
  final String language;
  final Level? level;

  /// For a card, the deck it is in.
  final String? parent;

  /// Whether it is a hidden deck, or a card of one.
  final bool hidden;

  /// For a card of a hidden deck, the key of the deck's own row: a result for
  /// it is shown as that row, with the card as its snippet, and never as a
  /// card.
  final String? collapseTo;

  String get key => itemKey(type, id);
}

/// One result.
class ItemResult {
  const ItemResult({
    required this.row,
    required this.rank,
    this.aboveLevel = false,
    this.snippetCard,
  });

  /// The row found (a deck's own row, for a card of a hidden deck).
  final ItemRow row;

  /// How well it matched, lower first: the quality of the worst word found
  /// ([MatchQuality]) twice, as `unit_search.dart` ranks.
  final int rank;

  /// Whether it is above the learner's level: listed, marked, not startable.
  final bool aboveLevel;

  /// The card of a hidden deck that matched best, when the result is the
  /// deck's row found by a card.
  final String? snippetCard;

  bool get isClose => rank ~/ 2 >= MatchQuality.close.index;

  /// Whether a learner may start it from the result.
  bool get startable => !aboveLevel;
}

/// One tab.
class SearchTab {
  const SearchTab({required this.kind, required this.count, this.row});

  final String kind;
  final int count;

  /// The row template of the kind (`scene`, `topic`, `deck`, `concept`,
  /// `card`, `unit`), or null for a kind the sections file does not list.
  final String? row;
}

/// What a search found: the results, the tabs that have any, and the tab to
/// open first.
class ItemSearchOutcome {
  const ItemSearchOutcome({
    this.results = const <ItemResult>[],
    this.tabs = const <SearchTab>[],
  });

  static const ItemSearchOutcome empty = ItemSearchOutcome();

  /// Best first.
  final List<ItemResult> results;

  /// Only the kinds with results, the best match's first, then the rest in
  /// the order the sections file gives (#1140).
  final List<SearchTab> tabs;

  /// The tab that opens first: the best match's, or null for no results.
  String? get openKind => tabs.isEmpty ? null : tabs.first.kind;

  /// The results of [kind], best first.
  List<ItemResult> ofKind(String kind) => <ItemResult>[
    for (final r in results)
      if (r.row.kind == kind) r,
  ];

  /// How many results [kind] has.
  int countOf(String kind) {
    for (final tab in tabs) {
      if (tab.kind == kind) return tab.count;
    }
    return 0;
  }
}

/// The rows of the search, kept by parent, and the FTS5 index that narrows
/// them where there is one. Never a source of truth: rebuilt from the decks.
class ItemCorpus {
  ItemCorpus({CardSearchIndex? index}) : _index = index;

  /// The FTS5 index, or null where the platform has none or it failed once:
  /// every row is then scanned, which gives the same results.
  CardSearchIndex? get index => _index;
  CardSearchIndex? _index;
  final Map<String, List<ItemRow>> _byParent = <String, List<ItemRow>>{};

  /// Whether [parent]'s rows are held.
  bool has(String parent) => _byParent.containsKey(parent);

  /// Puts [rows] in under [parent], in place of any it held. A failure of the
  /// index leaves the rows held and the search to scan them.
  void replace(String parent, Iterable<ItemRow> rows) {
    final list = List<ItemRow>.unmodifiable(rows);
    _byParent[parent] = list;
    final index = _index;
    if (index == null) return;
    try {
      index.replace(parent, <IndexRow>[
        for (final r in list)
          IndexRow(
            item: r.key,
            kind: r.kind,
            fields: r.fields,
            language: r.language,
            level: r.level,
          ),
      ]);
    } on Object {
      // An index that missed rows would hide results: turn it off, and let
      // the matcher scan everything.
      _index = null;
      try {
        index.close();
      } on Object {
        // Nothing to do.
      }
    }
  }

  /// Every row held.
  Iterable<ItemRow> get rows sync* {
    for (final list in _byParent.values) {
      yield* list;
    }
  }

  /// Searches [query].
  ///
  /// * [kinds] limits it to those search kinds; [languages] to rows of those
  ///   languages (a row with no language is in every one).
  /// * [levelOf] gives a language's learner level (null: no levels).
  /// * [hideAbove] is the setting "Hide what is above my level".
  /// * [sections] orders the tabs.
  ItemSearchOutcome search(
    String query, {
    Set<String>? kinds,
    Set<String>? languages,
    Level? Function(String language)? levelOf,
    bool hideAbove = false,
    bool typos = true,
    DeckSections sections = DeckSections.empty,
  }) {
    final words = searchWords(query);
    if (words.isEmpty) return ItemSearchOutcome.empty;
    Set<String>? narrowed;
    final index = _index;
    if (index != null) {
      try {
        narrowed = index.candidates(words, typos: typos, kinds: kinds);
      } on Object {
        narrowed = null;
      }
    }
    final deckRows = <String, ItemRow>{
      for (final row in rows)
        if (row.type == SearchItemType.deck) row.key: row,
    };
    final best = <String, ItemResult>{};
    for (final row in rows) {
      if (kinds != null && !kinds.contains(row.kind)) continue;
      if (languages != null &&
          row.language.isNotEmpty &&
          !languages.contains(row.language)) {
        continue;
      }
      if (narrowed != null && !narrowed.contains(row.key)) continue;
      final worst = _rank(words, row.fields, typos);
      if (worst == null) continue;
      final rank = worst * 2;
      final learner = levelOf == null ? null : levelOf(row.language);
      final above = LevelGate.isAbove(row.level, learner);
      final isCard = row.type == SearchItemType.card;
      // A card above the level never reaches a result with its text.
      if (above && isCard) continue;
      // A card of a hidden deck is the deck's row, found by that card.
      final collapsed = row.collapseTo;
      final shown = isCard && collapsed != null ? deckRows[collapsed] : null;
      if (isCard && collapsed != null && shown == null) continue;
      final result = shown == null
          ? ItemResult(row: row, rank: rank, aboveLevel: above)
          : ItemResult(
              row: shown,
              rank: rank,
              aboveLevel: LevelGate.isAbove(
                shown.level,
                levelOf == null ? null : levelOf(shown.language),
              ),
              snippetCard: row.id,
            );
      if (result.aboveLevel && hideAbove) continue;
      final key = '${result.row.kind}|${result.row.key}';
      final earlier = best[key];
      if (earlier == null || result.rank < earlier.rank) {
        best[key] = ItemResult(
          row: result.row,
          rank: result.rank,
          aboveLevel: result.aboveLevel,
          snippetCard: result.snippetCard ?? earlier?.snippetCard,
        );
      } else if (earlier.snippetCard == null && result.snippetCard != null) {
        best[key] = ItemResult(
          row: earlier.row,
          rank: earlier.rank,
          aboveLevel: earlier.aboveLevel,
          snippetCard: result.snippetCard,
        );
      }
    }
    final order = <String, int>{
      for (final k in sections.searchKinds) k.id: k.order,
    };
    int orderOf(String kind) => order[kind] ?? 100000;
    final results = best.values.toList()
      ..sort((a, b) {
        final byRank = a.rank.compareTo(b.rank);
        if (byRank != 0) return byRank;
        final byKind = orderOf(a.row.kind).compareTo(orderOf(b.row.kind));
        if (byKind != 0) return byKind;
        return a.row.key.compareTo(b.row.key);
      });
    if (results.isEmpty) return ItemSearchOutcome.empty;
    final counts = <String, int>{};
    for (final r in results) {
      counts[r.row.kind] = (counts[r.row.kind] ?? 0) + 1;
    }
    final first = results.first.row.kind;
    final rest = counts.keys.where((k) => k != first).toList()
      ..sort((a, b) {
        final byOrder = orderOf(a).compareTo(orderOf(b));
        return byOrder != 0 ? byOrder : a.compareTo(b);
      });
    return ItemSearchOutcome(
      results: List<ItemResult>.unmodifiable(results),
      tabs: <SearchTab>[
        for (final k in <String>[first, ...rest])
          SearchTab(
            kind: k,
            count: counts[k]!,
            row: sections.searchKind(k)?.row,
          ),
      ],
    );
  }

  /// The worst [MatchQuality] index over every word, or null when one word is
  /// not found.
  static int? _rank(List<String> words, List<String> fields, bool typos) {
    var worst = 0;
    for (final word in words) {
      final quality = matchWord(word, fields, typos: typos);
      if (quality == null) return null;
      if (quality.index > worst) worst = quality.index;
    }
    return worst;
  }
}

/// Everything of one language the search is built from. All optional: a
/// language with no path, topics or situations has none of those items.
class SearchSource {
  const SearchSource({
    required this.language,
    this.decks = const <Deck>[],
    this.addedHidden = const <Deck>[],
    this.shelves = const <IndexShelf>[],
    this.path,
    this.topics,
    this.situations,
    this.creators,
    this.sections = DeckSections.empty,
    this.themeNames = const <String, String>{},
    this.plainCards = true,
  });

  final String language;

  /// The decks a learner is given.
  final List<Deck> decks;

  /// Hidden decks a learner added: on the phone, searched like any deck, and
  /// their cards found as their deck's row.
  final List<Deck> addedHidden;

  /// Hidden decks the index lists (`shelves`) that may not be on the phone:
  /// searchable from the moment the index is read, by their title and
  /// profession. One whose deck is among [addedHidden] is that deck's row.
  final List<IndexShelf> shelves;
  final LanguagePath? path;
  final TopicsFile? topics;
  final SituationsFile? situations;

  /// The language's creators: their names are searchable on the cards that
  /// quote them.
  final CreatorsFile? creators;
  final DeckSections sections;

  /// Theme ids to their names, so that a deck is found by its theme.
  final Map<String, String> themeNames;

  /// Whether the cards of a deck with no genre (plain words and sentences) are
  /// rows too. The Decks tab's own word search finds those, so it turns this
  /// off and the corpus holds only what that search does not: genre decks'
  /// cards and every deck's own row.
  final bool plainCards;
}

List<String> _folded(Iterable<String?> texts) => <String>[
  for (final text in texts)
    if (text != null && text.trim().isNotEmpty) foldForSearch(text),
];

/// The search kind of a deck's own row (D10): the genre's kind when it is one
/// drawn as a scene (a professional deck), else `decks`.
String deckKind(Deck deck, DeckSections sections) {
  final kind = sections.genre(deck.genre)?.searchKind;
  if (kind != null && sections.searchKind(kind)?.row == 'scene') return kind;
  if (deck.professional != null && sections.genre(deck.genre) == null) {
    return ResultKind.situations;
  }
  return ResultKind.decks;
}

/// The search kind of a card of [deck]: the genre's, else `cards`.
String cardKind(Deck deck, DeckSections sections) =>
    sections.genre(deck.genre)?.searchKind ?? ResultKind.cards;

String _coreKey(Deck deck) {
  final prefix = '${deck.language.code}-${deck.native.code}-';
  return deck.id.startsWith(prefix) && deck.id.length > prefix.length
      ? '${deck.language.code}-${deck.id.substring(prefix.length)}'
      : deck.id;
}

/// The rows of [deck]'s cards. A hidden deck's cards collapse to its row.
/// Grammar tables, rules and reading decks are not indexed as cards (their
/// cells are forms of words taught elsewhere), as on the unit screens.
List<ItemRow> deckCardRows(Deck deck, SearchSource source) {
  if (deck.pattern != null ||
      deck.kind == DeckKind.reading ||
      deck.kind == DeckKind.rules) {
    return const <ItemRow>[];
  }
  final sections = source.sections;
  final kind = cardKind(deck, sections);
  final rows = <ItemRow>[];
  for (final card in deck.cards) {
    if (card is QuestionCard || card.practiceOnly) continue;
    final extra = <String?>[];
    for (final id in card.creators) {
      final creator = source.creators?.byId(id);
      if (creator == null) continue;
      extra.addAll(creator.names.values.map((n) => n.text));
      extra.addAll(creator.names.values.map((n) => n.reading));
    }
    final block = card.sourceBlock;
    if (block != null) extra.addAll(<String?>[block.author, block.work]);
    rows.add(
      ItemRow(
        type: SearchItemType.card,
        id: card.id,
        kind: deck.hidden ? deckKind(deck, sections) : kind,
        fields: _folded(<String?>[...cardSearchFields(card), ...extra]),
        language: source.language,
        level: card.level ?? deck.level,
        parent: deck.id,
        hidden: deck.hidden,
        collapseTo: deck.hidden ? itemKey(SearchItemType.deck, deck.id) : null,
      ),
    );
  }
  return rows;
}

/// The row of [deck] itself: its name, description, profession, genre and
/// theme.
ItemRow deckRow(Deck deck, SearchSource source) {
  final sections = source.sections;
  final profession = sections.profession(deck.professional);
  return ItemRow(
    type: SearchItemType.deck,
    id: deck.id,
    kind: deckKind(deck, sections),
    fields: _folded(<String?>[
      deck.name,
      deck.description,
      ...?profession?.names.values,
      deck.professional,
      ...?sections.genre(deck.genre)?.names.values,
      source.themeNames[deck.theme],
    ]),
    language: source.language,
    level: deck.level,
    hidden: deck.hidden,
  );
}

/// Puts everything [source] holds in [corpus], each group replacing what the
/// corpus held of it before. A group that cannot be built is skipped and
/// named in the result; the rest is indexed. Never throws.
List<String> indexLanguage(ItemCorpus corpus, SearchSource source) {
  final problems = <String>[];
  final language = source.language;

  void guarded(String what, void Function() build) {
    try {
      build();
    } on Object catch (e) {
      problems.add('$language search $what could not be indexed: $e');
    }
  }

  final allDecks = <Deck>[...source.decks, ...source.addedHidden];
  for (final deck in allDecks) {
    guarded('cards of ${deck.id}', () {
      final skipped = !source.plainCards && deck.genre == null;
      corpus.replace(
        deck.id,
        skipped ? const <ItemRow>[] : deckCardRows(deck, source),
      );
    });
  }
  guarded('decks', () {
    final loaded = <String>{for (final d in allDecks) d.id};
    corpus.replace('group:decks:$language', <ItemRow>[
      for (final deck in allDecks) deckRow(deck, source),
      for (final shelf in source.shelves)
        if (shelf.hidden &&
            !shelf.isCore &&
            !loaded.contains(_shelfDeckId(shelf, language)))
          _shelfRow(shelf, source),
    ]);
  });
  guarded('units', () {
    final plan = source.path?.plan;
    if (plan == null) {
      corpus.replace('group:units:$language', const <ItemRow>[]);
      return;
    }
    final namesOfCore = <String, List<String>>{};
    for (final deck in source.decks) {
      (namesOfCore[_coreKey(deck)] ??= <String>[]).add(deck.name);
    }
    corpus.replace('group:units:$language', <ItemRow>[
      for (final (i, unit) in plan.indexed)
        ItemRow(
          type: SearchItemType.unit,
          id: '$language:$i',
          kind: ResultKind.units,
          fields: _folded(<String?>[
            for (final core in unit.decks) ...?namesOfCore[core],
            unit.planned?.id.replaceAll('-', ' '),
            unit.planned?.theme?.replaceAll('-', ' '),
          ]),
          language: language,
          level: levelOfUnit(plan, i),
        ),
    ]);
  });
  guarded('concepts', () {
    final plan = source.path?.plan ?? const [];
    final ids = <String>{for (final unit in plan) ...unit.grammar};
    corpus.replace('group:concepts:$language', <ItemRow>[
      for (final id in ids)
        ItemRow(
          type: SearchItemType.concept,
          id: '$language:$id',
          kind: ResultKind.concepts,
          fields: _folded(<String?>[id, id.replaceAll('-', ' ')]),
          language: language,
        ),
    ]);
  });
  guarded('topics', () {
    corpus.replace('group:topics:$language', <ItemRow>[
      for (final topic in source.topics?.topics ?? const <Topic>[])
        ItemRow(
          type: SearchItemType.topic,
          id: topic.id,
          kind: ResultKind.topics,
          fields: _folded(<String?>[
            ...topic.names.values,
            ...topic.summary.values,
            topic.term?.text,
            topic.term?.reading,
            for (final c in topic.chars) c.text,
          ]),
          language: language,
          level: topic.level,
        ),
    ]);
  });
  guarded('situations', () {
    corpus.replace('group:situations:$language', <ItemRow>[
      for (final s in source.situations?.situations ?? const <Situation>[])
        ItemRow(
          type: SearchItemType.situation,
          id: '$language:${s.id}',
          kind: ResultKind.situations,
          fields: _folded(s.title.values),
          language: language,
        ),
    ]);
  });
  return problems;
}

/// The id the deck of [shelf] has once loaded: the index lists a deck by its
/// core id (`te-health`), and the deck of a native language is
/// `te-en-health`.
String _shelfDeckId(IndexShelf shelf, String language) {
  final core = shelf.deckKey;
  final native = shelf.file.native;
  return native != null && core.startsWith('$language-')
      ? '$language-$native-${core.substring(language.length + 1)}'
      : core;
}

ItemRow _shelfRow(IndexShelf shelf, SearchSource source) {
  final sections = source.sections;
  final genre = sections.genre(shelf.genre);
  final searchKind = genre?.searchKind;
  final kind =
      searchKind != null && sections.searchKind(searchKind)?.row == 'scene'
      ? searchKind
      : shelf.professional != null && genre == null
      ? ResultKind.situations
      : ResultKind.decks;
  return ItemRow(
    type: SearchItemType.deck,
    id: _shelfDeckId(shelf, source.language),
    kind: kind,
    fields: _folded(<String?>[
      shelf.title,
      shelf.professional,
      ...?sections.profession(shelf.professional)?.names.values,
      ...?genre?.names.values,
    ]),
    language: source.language,
    level: shelf.level,
    hidden: shelf.hidden,
  );
}
