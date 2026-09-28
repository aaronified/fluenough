import '../../core/models/grammar_pattern.dart';

/// One cell of a grammar deck's pattern table: an entry and a slot, the unit
/// a grammar card drills.
///
/// This is local to the drill on purpose. The expander (#2) turns cells into
/// cards, and it should hand the drill each card's `(entry, slot)` directly,
/// so that nothing has to parse `<deck-id>-<lemma>-<slot-index>` back out of
/// an id (decision 8 in the UI plan). Until then the drill runs on cells
/// shaped here from the real pattern. When #2 lands, build these from its
/// cards rather than from [grammarCells].
class GrammarCell {
  const GrammarCell({
    required this.pattern,
    required this.entry,
    required this.slotIndex,
  });

  final GrammarPattern pattern;
  final PatternEntry entry;

  /// The slot's position in [GrammarPattern.slots].
  final int slotIndex;

  /// The slot's label, like "nosotros".
  String get slot => pattern.slots[slotIndex];

  /// The form to type. [grammarCells] never yields a cell without one.
  String get answer => entry.forms[slot]!;

  /// The pattern's `prompt` with `{lemma}`, `{gloss}` and `{slot}` filled in:
  /// "hablar (to speak) — nosotros". Deck content, shown as written.
  String get prompt => pattern.prompt.replaceAllMapped(
    _placeholder,
    (m) => switch (m[1]) {
      'lemma' => entry.lemma,
      'gloss' => entry.gloss,
      _ => slot,
    },
  );

  /// The entry's whole row of the table, in slot order: each slot with its
  /// form, or null where the pattern marks the cell as having none.
  List<({String slot, String? form})> get table =>
      <({String slot, String? form})>[
        for (final s in pattern.slots) (slot: s, form: entry.forms[s]),
      ];

  static final RegExp _placeholder = RegExp(r'\{(lemma|gloss|slot)\}');
}

/// Every drillable cell of [pattern], entry by entry and slot by slot,
/// skipping cells whose form is null (a defective verb, say), as the
/// expander does.
List<GrammarCell> grammarCells(GrammarPattern pattern) => <GrammarCell>[
  for (final entry in pattern.entries)
    for (var i = 0; i < pattern.slots.length; i++)
      if (entry.forms[pattern.slots[i]] != null)
        GrammarCell(pattern: pattern, entry: entry, slotIndex: i),
];

/// The cell for [lemma] and [slot] in [pattern], or null: how a fixture names
/// the cell it wants, by content rather than by id.
GrammarCell? findGrammarCell(
  GrammarPattern pattern, {
  required String lemma,
  required String slot,
}) {
  for (final cell in grammarCells(pattern)) {
    if (cell.entry.lemma == lemma && cell.slot == slot) return cell;
  }
  return null;
}
