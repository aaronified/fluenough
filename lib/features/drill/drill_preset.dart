import '../../core/models/card.dart';
import '../../core/models/drill_mode.dart';
import '../../core/scheduling/session_queue.dart';
import 'drill_session.dart';

/// A drill started part-way through, as the design's Gallery shows it: a
/// chosen card first, an answer typed, perhaps already checked.
///
/// For the debug gallery and for tests; a real session never has one. It
/// finds its card by the card's target text, never by id: no id is written
/// into the interface (AGENTS.md rule 1).
class DrillPreset {
  const DrillPreset({
    this.target,
    this.typed,
    this.check = false,
    this.reveal = false,
    this.inputMode,
    this.questions = false,
    this.choice,
    this.ask = Ask.own,
  });

  /// Starts on the first card of the request's decks whose target is this,
  /// in the request's skill, moved to the front of the session.
  final String? target;

  /// Typed into the answer field.
  final String? typed;

  /// Then checked, so the feedback shows. This records the answer, as a
  /// real check does, into the preview's own fixture progress.
  final bool check;

  /// Recognition: the answer is shown, with the rating buttons.
  final bool reveal;

  /// Script or transliteration, where the card offers the choice and
  /// `Feature.translitInput` is on. Null for the language's own.
  final InputMode? inputMode;

  /// A reading question: past the passage, to its first question.
  final bool questions;

  /// A reading question: past the passage, with this choice made, from 0.
  /// This records it, as a check does.
  final int? choice;

  /// How the preset's card is asked (ADR-0024). For match pairs, the next
  /// cards of the session whose meanings differ are matched with it.
  final Ask ask;

  /// [items] with the preset's card first. [cards] are the request's decks'
  /// cards, [mode] its skill's, and [stateOf] finds the card's state.
  List<SessionItem> reorder(
    List<SessionItem> items, {
    required Iterable<Card> cards,
    required DrillMode mode,
    required StateLookup stateOf,
  }) {
    final wanted = target;
    if (wanted == null) return items;
    for (final card in cards) {
      if (card.target != wanted) continue;
      final own = SessionItem(
        card: card,
        mode: mode,
        state: stateOf(card, mode),
      );
      final rest = <SessionItem>[
        for (final item in items)
          if (item.card.id != card.id) item,
      ];
      if (ask != Ask.matchPairs) {
        return <SessionItem>[own.askedAs(ask), ...rest];
      }
      final group = <SessionItem>[own];
      for (final item in rest) {
        if (group.length == matchSize) break;
        if (group.every(
          (g) =>
              g.card.native != item.card.native &&
              g.card.target != item.card.target,
        )) {
          group.add(item);
        }
      }
      return <SessionItem>[
        own.askedAs(Ask.matchPairs, group: group),
        for (final item in rest)
          if (!group.contains(item)) item,
      ];
    }
    return items;
  }

  /// Puts [session] where the preset says.
  void apply(DrillSession session) {
    if (reveal) session.reveal();
    final chosen = choice;
    if (questions || chosen != null) session.toQuestions();
    if (chosen != null) session.choose(chosen);
    final text = typed;
    if (check && text != null) session.check(text);
  }
}
