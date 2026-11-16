/// The levels a deck, a card or a passage may carry (wiki/Plan-Deck-Kinds-And-
/// Topics.md, D2). A level orders and labels content; it never blocks it
/// (owner, 2026-11-16: everything is viewable and learnable). Pure Dart and
/// imports nothing, so that the models can use it; the units that carry a level
/// are in `lib/core/decks/levels.dart`.
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
