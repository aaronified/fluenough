import '../models/card.dart';
import '../models/drill_mode.dart';
import 'session_queue.dart';

/// Which part of the script decks a session takes (owner, 2026-10-24: "Separate
/// script recognition and production from others. And script will contain
/// both.").
enum ScriptScope {
  /// Every card, as a session always was.
  any,

  /// Only the script decks' Recognition and Write: Today's Script tile.
  only,

  /// Everything but the script decks' Recognition and Write: the other
  /// tiles. Their Hear, Say and the rest still count.
  without,
}

/// Tells the script decks' own reviews from the rest, so that Today's
/// Script tile can hold script reading and writing, and Recognition and
/// Write hold what is left.
///
/// A script deck's Recognition is script reading ([DrillMode.readScript])
/// and its Write is script writing ([DrillMode.writeScript]), as
/// `SkillMap.scriptOf` counts them. Pure: no Flutter.
class ScriptSplit {
  const ScriptSplit(this.scriptDecks);

  /// The decks listed under `alphabet:` in their language's path.
  final Set<String> scriptDecks;

  /// The modes of a script deck that the Script tile takes.
  static const Set<DrillMode> modes = <DrillMode>{
    DrillMode.recognition,
    DrillMode.production,
  };

  /// The script skill a review of [card] in [mode] is, or null where it is
  /// not one: any other mode, or a card outside the script decks.
  DrillMode? skillOf(Card card, DrillMode mode) {
    if (!scriptDecks.contains(card.deckId)) return null;
    return switch (mode) {
      DrillMode.recognition => DrillMode.readScript,
      DrillMode.production => DrillMode.writeScript,
      _ => null,
    };
  }

  /// Whether [card] in [mode] is a script review.
  bool isScript(Card card, DrillMode mode) => skillOf(card, mode) != null;

  /// The cards a session of [scope] draws from.
  List<Card> cardsFor(ScriptScope scope, List<Card> cards) =>
      scope == ScriptScope.only
      ? <Card>[
          for (final card in cards)
            if (scriptDecks.contains(card.deckId)) card,
        ]
      : cards;

  /// The modes a session of [scope] may use, out of [allowed].
  Set<DrillMode> modesFor(ScriptScope scope, Set<DrillMode> allowed) =>
      scope == ScriptScope.only ? allowed.intersection(modes) : allowed;

  /// Whether a session of [scope] leaves the pair out.
  bool leavesOut(ScriptScope scope, Card card, DrillMode mode) =>
      scope == ScriptScope.without && isScript(card, mode);

  /// How many items [queue] drills in each mode, the script decks' Recognition
  /// and Write counted under [DrillMode.readScript] and
  /// [DrillMode.writeScript] instead. A queue holds a card once, so a card
  /// is in one count only.
  Map<DrillMode, int> countByMode(SessionQueue queue) {
    final counts = <DrillMode, int>{};
    for (final item in queue.items) {
      final mode = skillOf(item.card, item.mode) ?? item.mode;
      counts[mode] = (counts[mode] ?? 0) + 1;
    }
    return counts;
  }
}
