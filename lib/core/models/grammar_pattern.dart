/// One row of a pattern table: a lemma and its inflected forms.
class PatternEntry {
  const PatternEntry({
    required this.lemma,
    required this.gloss,
    required this.forms,
  });

  /// Part of every expanded card id, so changing it orphans the row's history.
  final String lemma;
  final String gloss;

  /// One form per slot, keyed by slot label. A `null` form marks a cell with no
  /// valid form — a defective verb, say — which is skipped rather than drilled.
  final Map<String, String?> forms;
}

/// A grammar deck's inflection table, before it is expanded into cards.
///
/// Each `(entry, slot)` cell becomes one grammar card. Keeping the table
/// unexpanded lets the parser and the expander stay separate steps.
class GrammarPattern {
  const GrammarPattern({
    required this.name,
    required this.slotName,
    required this.slots,
    required this.prompt,
    required this.entries,
    this.notes,
  });

  /// Describes the inflection.
  final String name;

  /// What the slots are: `person`, `case`, `tense`, `number`…
  final String slotName;

  /// Slot labels, in declaration order. The order is load-bearing: an expanded
  /// card's id is `<deck-id>-<lemma>-<slot-index>` and the index is positional,
  /// so reordering this list rewrites every id in the deck and orphans its
  /// review history. That is why this is a [List] and never a [Set] or a
  /// [Map]. New slots go at the end.
  final List<String> slots;

  /// Template for the card prompt. `{lemma}`, `{gloss}` and `{slot}` are
  /// substituted.
  final String prompt;

  final List<PatternEntry> entries;

  /// Shown after answering.
  final String? notes;
}
