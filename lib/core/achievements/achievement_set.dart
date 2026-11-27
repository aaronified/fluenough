/// A set the achievements count (#322, decision 7 of the achievements
/// mockup): one deck group of a language's path, chosen once in the path
/// file under `achievement_sets:`, such as Pronouns or Past tense.
///
/// In the path file its [decks] are core ids the path lists (the deck, its
/// sentences deck and its reading deck); in a course's path they are the
/// course's own decks. A set is mastered when every card of those decks has
/// been known (decision 8).
class AchievementSet {
  const AchievementSet({
    required this.id,
    required this.grammar,
    required this.decks,
  });

  /// Permanent, `[a-z0-9-]+`: it names the set's badge.
  final String id;

  /// Whether it is a grammar table (`kind: grammar`) rather than a word set
  /// (`kind: word`). Word sets are placed on the path first.
  final bool grammar;

  /// The decks that make the set, by core id in the path file and by deck id
  /// in a course's path.
  final List<String> decks;

  @override
  String toString() => 'AchievementSet($id)';
}
