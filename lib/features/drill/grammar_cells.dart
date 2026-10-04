import '../../core/data/pattern_expander.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/grammar_pattern.dart';

/// One cell of a grammar deck's pattern table: an entry and a slot, the unit
/// a grammar card drills.
///
/// The live drill finds a card's cell with [grammarCellOf], which matches
/// the card against each cell's expanded id rather than parsing
/// `<language>-<deck name>-<lemma>-<slot-index>` back out of it (decision 8
/// in the UI plan).
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

  /// The other forms accepted for the slot (#144), after [answer].
  List<String> get alternatives => entry.alternatives[slot] ?? const <String>[];

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

  /// [prompt] with the lemma's reading in place of the lemma, or null if
  /// the entry gives none (#47).
  String? get readingPrompt {
    final reading = entry.reading;
    if (reading == null) return null;
    return pattern.prompt.replaceAllMapped(
      _placeholder,
      (m) => switch (m[1]) {
        'lemma' => reading,
        'gloss' => entry.gloss,
        _ => slot,
      },
    );
  }

  /// The entry's whole row of the table, in slot order: each slot with its
  /// form and the form's reading, each null where the pattern marks the
  /// cell as having none or gives no reading.
  List<({String slot, String? form, String? reading})> get table =>
      <({String slot, String? form, String? reading})>[
        for (final s in pattern.slots)
          (slot: s, form: entry.forms[s], reading: entry.readings[s]?.first),
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

/// The cell of [deck]'s pattern that [card] was expanded from (#2), or null
/// if [card] is not one of its cells.
GrammarCell? grammarCellOf(Card card, Deck deck) {
  final pattern = deck.pattern;
  if (pattern == null) return null;
  for (final cell in grammarCells(pattern)) {
    if (patternCardId(deck, cell.entry, cell.slotIndex) == card.id) {
      return cell;
    }
  }
  return null;
}
