/// Culture woven through the course (wiki/Plan-Deck-Kinds-And-Topics.md, D11,
/// T20; the approved mockup `culture-in-course.html`): the items of a
/// language's culture and proverbs decks, which unit of its path each is woven
/// into, and the one next for a learner. Pure functions over data, free of
/// Flutter, so that the rules are tested in milliseconds.
///
/// The rule, as the owner approved it with the default variants: one item per
/// unit by default; an item at the unit's own level first (a proverb at A1, a
/// stanza at A2, a passage with its gloss at B1 are what the decks hold at
/// those levels), then a lower one left over; an item above the learner's level
/// is never woven (D2); the items are a bonus and do not count toward the
/// path's progress.
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
  const WovenCulture({
    this.byUnit = const <int, List<CultureItem>>{},
    this.above = const <CultureItem>[],
  });

  /// Nothing woven.
  static const WovenCulture none = WovenCulture();

  /// The items woven into each unit, by the unit's index in the path's plan,
  /// each at or below the learner's level.
  final Map<int, List<CultureItem>> byUnit;

  /// The items above the learner's level, in order: they are never woven.
  final List<CultureItem> above;

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

  /// The lowest level among [above]: where "N items unlock at B1" points, or
  /// null when nothing is above.
  Level? get nextUnlock {
    Level? lowest;
    for (final item in above) {
      if (lowest == null || item.level.index < lowest.index) {
        lowest = item.level;
      }
    }
    return lowest;
  }
}

/// How many items a unit is given, by default (the mockup's proposal).
const int defaultCulturePerUnit = 1;

/// The most a learner may ask for per unit.
const int maxCulturePerUnit = 3;

/// Weaves [items] into the written units of [plan] for a learner at
/// [learner] (null: a language with no levels, which is offered no levelled
/// item). A unit gets [perUnit] items: those at its own level first, in deck
/// order, then lower ones not used yet. An item is woven once. An item above
/// the learner is listed in [WovenCulture.above] and never woven.
WovenCulture weaveCulture(
  List<PlanUnit> plan,
  List<CultureItem> items,
  Level? learner, {
  int perUnit = defaultCulturePerUnit,
}) {
  if (items.isEmpty) return WovenCulture.none;
  final shown = <CultureItem>[];
  final above = <CultureItem>[];
  for (final item in items) {
    if (LevelGate.allows(item.level, learner)) {
      shown.add(item);
    } else {
      above.add(item);
    }
  }
  final per = perUnit < 1
      ? 1
      : perUnit > maxCulturePerUnit
      ? maxCulturePerUnit
      : perUnit;
  final unused = List<CultureItem>.of(shown);
  final byUnit = <int, List<CultureItem>>{};
  for (final (index, unit) in plan.indexed) {
    if (unused.isEmpty) break;
    if (unit.decks.isEmpty) continue;
    final level = levelOfUnit(plan, index);
    if (level == null) continue;
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
  return WovenCulture(
    byUnit: Map<int, List<CultureItem>>.unmodifiable(byUnit),
    above: List<CultureItem>.unmodifiable(above),
  );
}
