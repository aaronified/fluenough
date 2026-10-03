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
    this.inputMode = InputMode.script,
    this.questions = false,
    this.choice,
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
  /// `Feature.translitInput` is on.
  final InputMode inputMode;

  /// A reading question: past the passage, to its first question.
  final bool questions;

  /// A reading question: past the passage, with this choice made, from 0.
  /// This records it, as a check does.
  final int? choice;

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
      final first = SessionItem(
        card: card,
        mode: mode,
        state: stateOf(card, mode),
      );
      return <SessionItem>[
        first,
        for (final item in items)
          if (item.card.id != card.id) item,
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
