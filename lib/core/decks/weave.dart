/// Culture woven through the course (wiki/Plan-Deck-Kinds-And-Topics.md, D11,
/// T20; the approved mockup `culture-in-course.html`): the items of a
/// language's culture and proverbs decks, which unit of its path each is woven
/// into, and the one next for a learner. Pure functions over data, free of
/// Flutter, so that the rules are tested in milliseconds.
///
/// The rule, as the owner approved it with the default variants: one item per
/// unit by default; an item at the unit's own level first (a proverb at A1, a
/// stanza at A2, a passage with its gloss at B1 are what the decks hold at
/// those levels), then a lower one left over; the items are a bonus and do not
/// count toward the path's progress. A level orders; it never keeps an item out.
library;

import '../data/course_path.dart' show PlanUnit;
import '../models/card.dart';
import '../models/card_source.dart';
import '../models/deck.dart';
import '../models/reading.dart';
import 'levels.dart';

/// What a culture item is, which names it on its row: a proverb, a line or
/// stanza of verse or prose, a passage.
enum CultureKind { proverb, line, passage }

/// The genres whose decks are culture items.
const Set<String> cultureGenres = <String>{'culture', 'proverbs'};

/// One culture item: a card of a culture or proverbs deck, or a passage of a
/// culture reading deck.
class CultureItem {
  const CultureItem({
    required this.id,
    required this.deckId,
    required this.deckName,
    required this.kind,
    required this.level,
    required this.target,
    required this.cardIds,
    this.cards = const <Card>[],
    this.reading,
    this.meaning,
    this.source,
    this.creators = const <String>[],
    this.glossary = const <GlossEntry>[],
    this.card,
    this.passage,
  });

  /// The card's id, or the passage's.
  final String id;
  final String deckId;
  final String deckName;
  final CultureKind kind;

  /// The card's level, else its deck's, else A1.
  final Level level;

  /// The text, a passage's sentences one to a line.
  final String target;
  final String? reading;

  /// What it means in the language the learner speaks, from the deck's layer;
  /// a passage has none.
  final String? meaning;
  final CardSource? source;

  /// The ids of its creators in the language's creators file; none for a folk
  /// saying nobody wrote.
  final List<String> creators;

  /// A passage's glossary: older or unusual words with today's form.
  final List<GlossEntry> glossary;

  /// The ids the learner meets it by: its card, or a passage's questions.
  /// Practising it asks these.
  final List<String> cardIds;

  /// Those cards, as the deck holds them: what a practice drills.
  final List<Card> cards;
  final Card? card;
  final Passage? passage;

  bool get isPassage => passage != null;
}

/// The culture items of [decks] (a language's, in the course's native
/// language so that no card is twice), in deck order: those whose genre is a
/// culture one and which [weaves]. A deck or a card that cannot be read costs
/// only itself; [onProblem] hears why.
List<CultureItem> cultureItemsOf(
  Iterable<Deck> decks, {
  required bool Function(Deck deck) weaves,
  void Function(String problem)? onProblem,
}) {
  final items = <CultureItem>[];
  final seen = <String>{};
  for (final deck in decks) {
    try {
      if (!cultureGenres.contains(deck.genre) || !weaves(deck)) continue;
      final proverbs = deck.genre == 'proverbs';
      if (deck.kind == DeckKind.reading) {
        for (final passage in deck.passages) {
          if (passage.sentences.isEmpty || !seen.add(passage.id)) continue;
          items.add(
            CultureItem(
              id: passage.id,
              deckId: deck.id,
              deckName: deck.name,
              kind: CultureKind.passage,
              level: passage.level ?? deck.level ?? Level.a1,
              target: passage.sentences.map((s) => s.text).join('\n'),
              reading: _joined(<String?>[
                for (final s in passage.sentences) s.reading,
              ]),
              source: passage.sourceBlock,
              creators: passage.creators,
              glossary: passage.glossary,
              cardIds: <String>[for (final q in passage.questions) q.id],
              cards: <Card>[
                for (final c in deck.cards)
                  if (c is QuestionCard && c.passage.id == passage.id) c,
              ],
              passage: passage,
            ),
          );
        }
        continue;
      }
      for (final card in deck.cards) {
        if (card is QuestionCard || !seen.add(card.id)) continue;
        items.add(
          CultureItem(
            id: card.id,
            deckId: deck.id,
            deckName: deck.name,
            kind: proverbs ? CultureKind.proverb : CultureKind.line,
            level: card.level ?? deck.level ?? Level.a1,
            target: card.target,
            reading: card.reading,
            meaning: card.native.isEmpty ? null : card.native,
            source: card.sourceBlock,
            creators: card.creators,
            cardIds: <String>[card.id],
            cards: <Card>[card],
            card: card,
          ),
        );
      }
    } on Object catch (error) {
      onProblem?.call('Culture deck ${deck.id} could not be read: $error');
    }
  }
  return items;
}

String? _joined(List<String?> lines) {
  final kept = <String>[
    for (final line in lines)
      if (line != null && line.isNotEmpty) line,
  ];
  return kept.isEmpty ? null : kept.join('\n');
}

/// Which item is woven into which unit of a path.
class WovenCulture {
  const WovenCulture({this.byUnit = const <int, List<CultureItem>>{}});

  /// Nothing woven.
  static const WovenCulture none = WovenCulture();

  /// The items woven into each unit, by the unit's index in the path's plan.
  final Map<int, List<CultureItem>> byUnit;

  /// Every woven item in path order.
  List<CultureItem> get all => <CultureItem>[
    for (final index in (byUnit.keys.toList()..sort())) ...byUnit[index]!,
  ];

  /// The items woven into the unit at [index].
  List<CultureItem> of(int index) => byUnit[index] ?? const <CultureItem>[];

  /// The first woven item [isDone] says is not done yet, in path order; null
  /// when every one is.
  CultureItem? next(bool Function(CultureItem item) isDone) {
    for (final item in all) {
      if (!isDone(item)) return item;
    }
    return null;
  }
}

/// How many items a unit is given when no number is passed: one.
const int defaultCulturePerUnit = 1;

/// The level whose units hold an item of [level]: [level] itself when the path
/// has a unit of it, else the next level up that has one; null when none does.
Level? _homeLevel(Level level, Set<Level> unitLevels) {
  for (final candidate in Level.values) {
    if (candidate.index >= level.index && unitLevels.contains(candidate)) {
      return candidate;
    }
  }
  return null;
}

/// The units of [plan] that can hold culture, with the level of each: those
/// with decks, on a path that has levels.
List<(int, Level)> _cultureUnits(List<PlanUnit> plan) => <(int, Level)>[
  for (final (index, unit) in plan.indexed)
    if (unit.decks.isNotEmpty)
      if (levelOfUnit(plan, index) case final level?) (index, level),
];

/// How many items a unit of each level is given, so that every item appears
/// and none piles into the first unit: the items of the level divided by the
/// units of the level, rounded up, and at least 1. An item of a level the path
/// has no unit of counts for the next level up that has one, where the weave
/// puts it. A level with no unit has no entry.
Map<Level, int> culturePerUnitByLevel(
  List<PlanUnit> plan,
  Iterable<CultureItem> items,
) {
  final units = <Level, int>{};
  for (final (_, level) in _cultureUnits(plan)) {
    units[level] = (units[level] ?? 0) + 1;
  }
  final unitLevels = units.keys.toSet();
  final demand = <Level, int>{};
  for (final item in items) {
    final home = _homeLevel(item.level, unitLevels);
    if (home != null) demand[home] = (demand[home] ?? 0) + 1;
  }
  return <Level, int>{
    for (final MapEntry(:key, :value) in units.entries)
      key: _atLeastOne(_ceilDiv(demand[key] ?? 0, value)),
  };
}

int _ceilDiv(int n, int d) => d <= 0 ? 0 : (n + d - 1) ~/ d;

int _atLeastOne(int n) => n < 1 ? 1 : n;

/// Weaves [items] into the written units of [plan]. A unit gets [perByLevel]
/// of its level, else [perUnit], items: those at its own level first, in deck
/// order, then lower ones not used yet. An item is woven once. The level only
/// orders; it never keeps an item out (owner, 2026-11-16).
WovenCulture weaveCulture(
  List<PlanUnit> plan,
  List<CultureItem> items, {
  int perUnit = defaultCulturePerUnit,
  Map<Level, int> perByLevel = const <Level, int>{},
}) {
  if (items.isEmpty) return WovenCulture.none;
  final unused = List<CultureItem>.of(items);
  final byUnit = <int, List<CultureItem>>{};
  for (final (index, unit) in plan.indexed) {
    if (unused.isEmpty) break;
    if (unit.decks.isEmpty) continue;
    final level = levelOfUnit(plan, index);
    if (level == null) continue;
    final per = _atLeastOne(perByLevel[level] ?? perUnit);
    final picked = <CultureItem>[];
    for (final item in unused) {
      if (item.level == level) picked.add(item);
      if (picked.length == per) break;
    }
    if (picked.length < per) {
      final lower = <CultureItem>[
        for (final item in unused)
          if (item.level.index < level.index) item,
      ]..sort((a, b) => a.level.index.compareTo(b.level.index));
      for (final item in lower) {
        if (picked.length == per) break;
        picked.add(item);
      }
    }
    if (picked.isEmpty) continue;
    unused.removeWhere(picked.contains);
    byUnit[index] = List<CultureItem>.unmodifiable(picked);
  }
  return WovenCulture(byUnit: Map<int, List<CultureItem>>.unmodifiable(byUnit));
}
