/// The levels a deck, a card or a passage may carry and the one gate every
/// levelled item passes (wiki/Plan-Deck-Kinds-And-Topics.md, D2). Pure Dart and
/// imports nothing, so that the models can use it; the learner's level and the
/// units that give it are in `lib/core/decks/levels.dart`.
library;

/// A CEFR-style level, in order: `A1 < A2 < B1 < B2 < C1 < C2`. The paths
/// reach B1, so a learner's level tops out at B1 today; B2 and above are valid
/// data that nobody sees until a path grows.
enum Level {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2;

  /// `A1`, `B2`: how a deck writes it and a learner reads it.
  String get label => name.toUpperCase();

  /// Whether this level is [other] or above it.
  bool isAtLeast(Level other) => index >= other.index;

  /// [value] as a level, or null when it is not one: `A1` to `C2`, in capitals
  /// as the decks write them. Anything else, including a number, is no level,
  /// so that a deck with a bad value is read as one without a level rather
  /// than refused (the validator is what refuses it).
  static Level? tryParse(Object? value) {
    if (value is! String) return null;
    for (final level in Level.values) {
      if (level.label == value) return level;
    }
    return null;
  }
}

/// The one gate a levelled item passes (D2): an item above the learner's level
/// is never drilled, never shown as content and never put in a result with its
/// text. Every place a levelled item reaches the learner calls it.
abstract final class LevelGate {
  /// Whether an item of level [item] may reach a learner at [learner]. An item
  /// with no level is open to everyone, and so are those of a learner at or
  /// above it. A language with no levels ([learner] null) offers no levelled
  /// item at all.
  static bool allows(Level? item, Level? learner) {
    if (item == null) return true;
    if (learner == null) return false;
    return learner.isAtLeast(item);
  }

  /// Whether [item] is above [learner]: the opposite of [allows], for the
  /// places that list such an item marked with its level (search).
  static bool isAbove(Level? item, Level? learner) => !allows(item, learner);

  /// The items of [items] a learner at [learner] may be given, in order.
  static List<T> filter<T>(
    Iterable<T> items,
    Level? learner,
    Level? Function(T item) levelOf,
  ) => <T>[
    for (final item in items)
      if (allows(levelOf(item), learner)) item,
  ];
}
