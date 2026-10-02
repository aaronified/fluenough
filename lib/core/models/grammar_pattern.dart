/// One row of a pattern table: a lemma and its inflected forms.
class PatternEntry {
  const PatternEntry({
    required this.lemma,
    required this.gloss,
    required this.forms,
    this.key,
    this.alternatives = const <String, List<String>>{},
  });

  /// The word the row inflects, as the drill shows it.
  final String lemma;
  final String gloss;

  /// An ASCII name for the row, for a [lemma] that cannot go into an id,
  /// such as जाना (#58). Null when the lemma is its own key.
  final String? key;

  /// What the row puts into every expanded card id: [key], or else [lemma].
  /// Changing it orphans the row's history.
  String get idPart => key ?? lemma;

  /// One form per slot, keyed by slot label. A `null` form marks a cell with no
  /// valid form — a defective verb, say — which is skipped rather than drilled.
  /// It is the form shown; [alternatives] holds any others accepted.
  final Map<String, String?> forms;

  /// Other forms accepted for a slot, after the one in [forms]: West Bengal
  /// এলাম and Bangladesh আসলাম, say (#144). Slots with none are absent.
  final Map<String, List<String>> alternatives;
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
  /// card's id is `<deck-id>-<key>-<slot-index>` and the index is positional,
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
