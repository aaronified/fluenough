import '../core/data/course_path.dart' show PlanUnit;
import '../core/decks/deck_index.dart';
import '../core/decks/topic_resolver.dart';
import '../core/models/level.dart';
import '../core/models/situation.dart';
import 'deck_catalog.dart';
import 'learner_levels.dart';

/// A language's topics (deck-kinds plan, D6) resolved against the catalog and
/// the index: what each names, and the cards a drill on it uses. No screens
/// (the topic page waits for its mockup); the app log reports
/// [Topics.problems] once per catalog.
class Topics {
  Topics._(this.language, this.world, this.resolved, this.problems);

  /// Builds the topics of [language] from [catalog]; empty when it has no
  /// topics file. [shelves], the index's decks with a genre, add the hidden
  /// decks not on the phone, which a topic may name and which are not drilled
  /// until a learner adds them. Never throws: a topic that cannot be resolved
  /// is reported in [problems] and the rest is used.
  factory Topics.of(
    Catalog catalog,
    String language, {
    Iterable<IndexShelf> shelves = const <IndexShelf>[],
  }) {
    final problems = <String>[];
    final file = catalog.topics[language];
    if (file == null) {
      return Topics._(
        language,
        const TopicWorld(),
        const <ResolvedTopic>[],
        const <String>[],
      );
    }
    TopicWorld world = const TopicWorld();
    var resolved = const <ResolvedTopic>[];
    try {
      world = _worldOf(catalog, language, shelves);
      resolved = resolveTopics(file.topics, world);
      for (final r in resolved) {
        for (final u in r.unresolved) {
          problems.add('${r.topic.id}: ${u.replaceFirst(':', ' ')} not found');
        }
      }
    } on Object catch (e) {
      problems.add('$language topics could not be resolved: $e');
    }
    return Topics._(language, world, resolved, problems);
  }

  final String language;
  final TopicWorld world;

  /// Every topic, resolved, in the file's order.
  final List<ResolvedTopic> resolved;

  /// References that name nothing the language has, one line each.
  final List<String> problems;

  ResolvedTopic? byId(String id) {
    for (final r in resolved) {
      if (r.topic.id == id) return r;
    }
    return null;
  }

  /// The ids of the cards a drill on topic [id] uses for a learner at
  /// [learner]; empty for an unknown topic or one above the level.
  List<String> drillCards(String id, Level? learner) {
    final r = byId(id);
    return r == null ? const <String>[] : topicDrillCards(r, world, learner);
  }

  /// The topics a learner at [learner] may start: none above their level.
  List<ResolvedTopic> startable(Level? learner) => <ResolvedTopic>[
    for (final r in resolved)
      if (LevelGate.allows(r.topic.level, learner)) r,
  ];

  static TopicWorld _worldOf(
    Catalog catalog,
    String language,
    Iterable<IndexShelf> shelves,
  ) {
    final byCore = <String, TopicDeckFact>{};
    void add(DeckEntry entry, {required bool hidden}) {
      if (entry.language.code != language) return;
      final core = LearnerLevels.coreIdOf(
        entry.id,
        language,
        entry.deck.native.code,
      );
      if (core == null || byCore.containsKey(core)) return;
      byCore[core] = TopicDeckFact(
        coreId: core,
        level: entry.deck.level,
        hidden: hidden,
        added: hidden,
        cards: <TopicCardFact>[
          for (final card in entry.deck.cards)
            TopicCardFact(id: card.id, level: card.level),
        ],
      );
    }

    for (final entry in catalog.decks) {
      add(entry, hidden: false);
    }
    for (final entry in catalog.hidden) {
      add(entry, hidden: true);
    }
    // A hidden deck the index lists but the phone does not hold: it exists
    // (a topic may name it), is not drilled, and has no cards to name.
    for (final shelf in shelves) {
      if (shelf.file.language != language || !shelf.hidden || shelf.isCore) {
        continue;
      }
      byCore.putIfAbsent(
        shelf.deckKey,
        () => TopicDeckFact(
          coreId: shelf.deckKey,
          level: shelf.level,
          hidden: true,
        ),
      );
    }
    final plan = catalog.languagePaths[language]?.plan ?? const <PlanUnit>[];
    final concepts = <String>{
      for (final unit in plan) ...unit.grammar,
      for (final entry in catalog.decks)
        if (entry.language.code == language)
          for (final rule in entry.deck.rules) ...<String>[
            rule.id,
            rule.id.substring(rule.id.lastIndexOf('-') + 1),
          ],
    };
    return TopicWorld(
      decks: byCore.values.toList(),
      plan: plan,
      concepts: concepts,
      situations: <String>{
        for (final s
            in catalog.situations[language]?.situations ?? const <Situation>[])
          s.id,
      },
      scriptUnits: <String>{
        for (final guide in catalog.scriptGuides.values)
          if (guide.language == language)
            for (final feature in guide.features) feature.id,
      },
    );
  }
}
