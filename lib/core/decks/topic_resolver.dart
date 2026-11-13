/// Resolving a topic's references (wiki/Plan-Deck-Kinds-And-Topics.md, D6, T14)
/// against the other files of its language, and the cards a drill on it uses.
/// Pure functions over plain data, free of Flutter: the app builds a
/// [TopicWorld] from its catalog, path, situations file and script guides
/// (`lib/app/topics.dart`).
///
/// Nothing here throws on a reference that does not resolve: it is reported in
/// [ResolvedTopic.unresolved] (and logged by the caller), because a deck that
/// is not on the phone, a hidden deck not yet added, or a file a later app
/// reads are all ordinary.
library;

import '../data/course_path.dart' show PlanUnit;
import '../models/level.dart';
import '../models/topic.dart';
import 'levels.dart' show levelOfUnit;

/// One card of a deck, as a topic's drill needs it.
class TopicCardFact {
  const TopicCardFact({required this.id, this.level});

  final String id;

  /// The card's own level, else null (the deck's applies).
  final Level? level;
}

/// One deck of the language, by its core id.
class TopicDeckFact {
  const TopicDeckFact({
    required this.coreId,
    this.level,
    this.hidden = false,
    this.added = false,
    this.cards = const <TopicCardFact>[],
  });

  /// The core id the path and topics name it by (`es-ser-estar`).
  final String coreId;
  final Level? level;
  final bool hidden;

  /// Whether the learner added it (a hidden deck is on the phone only then);
  /// only meaningful for a hidden deck.
  final bool added;
  final List<TopicCardFact> cards;
}

/// What a language has, for a topic to name.
class TopicWorld {
  const TopicWorld({
    this.decks = const <TopicDeckFact>[],
    this.plan = const <PlanUnit>[],
    this.concepts = const <String>{},
    this.situations = const <String>{},
    this.scriptUnits = const <String>{},
    this.topicIds = const <String>{},
    this.knownCardIds = const <String>{},
  });

  final List<TopicDeckFact> decks;

  /// The language's path, in order.
  final List<PlanUnit> plan;

  /// Path `grammar:` concept ids and rules-table names.
  final Set<String> concepts;

  /// Ids of situation sheets.
  final Set<String> situations;

  /// Feature ids of the language's script guides.
  final Set<String> scriptUnits;

  /// Ids of the topics of the file (set by [resolveTopics]).
  final Set<String> topicIds;

  /// Card ids known beyond those of [decks] (cards of hidden decks the index
  /// lists but the phone does not hold).
  final Set<String> knownCardIds;

  TopicDeckFact? deck(String coreId) {
    for (final deck in decks) {
      if (deck.coreId == coreId) return deck;
    }
    return null;
  }

  /// The index in [plan] of the first unit with [ref] among the core ids it
  /// lists, or whose planned id it is; -1 if none.
  int unitIndex(String ref) {
    for (final (i, unit) in plan.indexed) {
      if (unit.decks.contains(ref) || unit.planned?.id == ref) return i;
    }
    return -1;
  }

  bool hasCard(String id) =>
      knownCardIds.contains(id) ||
      decks.any((deck) => deck.cards.any((card) => card.id == id));
}

/// A topic with each reference resolved. References that name nothing the
/// language has are in [unresolved], as `key:ref` such as `decks:es-foo`; the
/// topic is never refused for one.
class ResolvedTopic {
  const ResolvedTopic({
    required this.topic,
    required this.decks,
    required this.units,
    required this.cards,
    required this.concepts,
    required this.situations,
    required this.related,
    required this.scriptUnits,
    required this.unresolved,
  });

  final Topic topic;

  /// Core ids of the decks that exist.
  final List<String> decks;

  /// Indexes into the path of the units that exist.
  final List<int> units;

  /// Card ids that exist.
  final List<String> cards;
  final List<String> concepts;
  final List<String> situations;

  /// Related topics of the file, other than this one.
  final List<String> related;
  final List<String> scriptUnits;
  final List<String> unresolved;

  @override
  String toString() => 'ResolvedTopic(${topic.id})';
}

/// [topic] resolved against [world]. A topic that names itself does not
/// relate to itself.
ResolvedTopic resolveTopic(Topic topic, TopicWorld world) {
  final unresolved = <String>[];
  List<String> keep(String key, List<String> refs, bool Function(String) has) {
    final found = <String>[];
    for (final ref in refs) {
      if (has(ref)) {
        found.add(ref);
      } else {
        unresolved.add('$key:$ref');
      }
    }
    return List<String>.unmodifiable(found);
  }

  final units = <int>[];
  for (final ref in topic.units) {
    final i = world.unitIndex(ref);
    if (i < 0) {
      unresolved.add('units:$ref');
    } else if (!units.contains(i)) {
      units.add(i);
    }
  }
  return ResolvedTopic(
    topic: topic,
    decks: keep('decks', topic.decks, (r) => world.deck(r) != null),
    units: List<int>.unmodifiable(units),
    cards: keep('cards', topic.cards, world.hasCard),
    concepts: keep('grammar', topic.grammar, world.concepts.contains),
    situations: keep('situations', topic.situations, world.situations.contains),
    related: keep(
      'topics',
      topic.topics.where((t) => t != topic.id).toList(),
      world.topicIds.contains,
    ),
    scriptUnits: keep(
      'script_units',
      topic.scriptUnits,
      world.scriptUnits.contains,
    ),
    unresolved: List<String>.unmodifiable(unresolved),
  );
}

/// Every topic of [topics], resolved against [world] (whose [TopicWorld.topicIds]
/// are filled from the topics), in order.
List<ResolvedTopic> resolveTopics(Iterable<Topic> topics, TopicWorld world) {
  final all = topics.toList();
  final full = TopicWorld(
    decks: world.decks,
    plan: world.plan,
    concepts: world.concepts,
    situations: world.situations,
    scriptUnits: world.scriptUnits,
    topicIds: <String>{for (final t in all) t.id},
    knownCardIds: world.knownCardIds,
  );
  return <ResolvedTopic>[for (final t in all) resolveTopic(t, full)];
}

/// The ids of the cards a drill on [resolved] uses, in order and each once:
/// the cards of its `decks`, its `cards`, and the cards of the decks of its
/// `units`, kept when the topic, the deck and the card are at or below
/// [learner] (the one gate, [LevelGate]). A hidden deck's cards are used only
/// when it was added. A topic above the learner's level gives none.
List<String> topicDrillCards(
  ResolvedTopic resolved,
  TopicWorld world,
  Level? learner,
) {
  if (!LevelGate.allows(resolved.topic.level, learner)) return const <String>[];
  final out = <String>[];
  final seen = <String>{};

  void takeDeck(TopicDeckFact deck) {
    if (deck.hidden && !deck.added) return;
    if (!LevelGate.allows(deck.level, learner)) return;
    for (final card in deck.cards) {
      if (LevelGate.allows(card.level, learner) && seen.add(card.id)) {
        out.add(card.id);
      }
    }
  }

  for (final core in resolved.decks) {
    final deck = world.deck(core);
    if (deck != null) takeDeck(deck);
  }
  for (final i in resolved.units) {
    // A unit above the learner's level is not drilled either.
    if (!LevelGate.allows(levelOfUnit(world.plan, i), learner)) continue;
    for (final core in world.plan[i].decks) {
      final deck = world.deck(core);
      if (deck != null) takeDeck(deck);
    }
  }
  for (final id in resolved.cards) {
    if (seen.contains(id)) continue;
    for (final deck in world.decks) {
      if (deck.hidden && !deck.added) continue;
      for (final card in deck.cards) {
        if (card.id != id) continue;
        if (LevelGate.allows(deck.level, learner) &&
            LevelGate.allows(card.level, learner)) {
          seen.add(id);
          out.add(id);
        }
      }
    }
  }
  return List<String>.unmodifiable(out);
}
