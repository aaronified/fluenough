import '../models/card.dart';
import '../models/deck.dart';
import '../models/drill_mode.dart';
import '../models/rule.dart';

/// A merged rules deck's table as cards: one per filled cell whose word is
/// taught in the deck's native language and whose rule the deck's layer
/// gives (B1 format, spec 4.6).
///
/// - **id** [ruleCellId]: `<core id>-<part>-<slot index>`, the part being
///   the row's `key`, else the digits of its word. A skipped row or slot
///   shifts no other cell's id.
/// - **target** the cell's first form, **altTarget** the rest, with their
///   readings and IPA.
/// - **native** the layer's prompt for the cell, else the slot's label with
///   `{meaning}` filled with the word's meaning, the first part of its
///   card's native; a label without `{meaning}` follows the meaning.
/// - **modes** `grammarUnderstood` and `grammar`.
/// - **rule** its rule, its word and the row's other forms it makes.
///
/// [wordOf] gives a row's word card as this deck's learners are taught it,
/// or null, and the row is skipped. Returns no cards for a deck without a
/// table.
List<Card> expandRules(
  Deck deck, {
  required Card? Function(String cardId) wordOf,
}) {
  final table = deck.table;
  if (table == null) return const <Card>[];
  final ruleOf = <String, String>{
    for (final rule in deck.rules)
      for (final slot in rule.slots) slot: rule.id,
  };
  final cards = <Card>[];
  for (final row in table.rows) {
    final word = wordOf(row.word);
    if (word == null) continue;
    final meaning = word.firstMeaning;
    // The row's cells, before each knows the others, its options.
    final cells = <(int, String, String, String)>[
      for (final (i, slot) in table.slots.indexed)
        if (row.forms[slot] case final form? when ruleOf.containsKey(slot))
          (i, slot, form, _prompt(row, slot, table.labels[slot], meaning)),
    ];
    for (final (i, slot, form, native) in cells) {
      final seen = <String>{form};
      cards.add(
        Card(
          id: ruleCellId(deck, row, i),
          deckId: deck.id,
          target: form,
          altTarget: row.alternatives[slot] ?? const <String>[],
          reading: row.readings[slot]?.first,
          altReading: row.readings[slot]?.skip(1).toList() ?? const <String>[],
          ipa: row.ipas[slot],
          native: native,
          modes: const <DrillMode>{
            DrillMode.grammarUnderstood,
            DrillMode.grammar,
          },
          rule: RuleCell(
            ruleId: ruleOf[slot]!,
            word: row.word,
            wordTarget: word.target,
            wordReading: word.reading,
            slot: slot,
            options: List<RuleOption>.unmodifiable(<RuleOption>[
              for (final (_, _, other, prompt) in cells)
                if (seen.add(other)) RuleOption(form: other, prompt: prompt),
            ]),
          ),
        ),
      );
    }
  }
  return List<Card>.unmodifiable(cards);
}

/// The meaning a cell expresses: the layer's whole prompt for it, or its
/// slot's [label] with the word's [meaning] in it.
String _prompt(RuleRow row, String slot, String? label, String meaning) {
  if (row.prompts[slot] case final prompt?) return prompt;
  final template = label ?? slot;
  return template.contains(_meaning)
      ? template.replaceAll(_meaning, meaning)
      : '$meaning: $template';
}

const String _meaning = '{meaning}';

/// The id of the card [deck]'s table expands from [row] at slot
/// [slotIndex]: the core's id, the row's id part and the index. The core's
/// id is the merged deck's without its native language, so a cell is one
/// card whichever language it is learned from (ADR-0018).
String ruleCellId(Deck deck, RuleRow row, int slotIndex) {
  final course = '${deck.language.code}-${deck.native.code}-';
  final core = deck.id.startsWith(course)
      ? '${deck.language.code}-${deck.id.substring(course.length)}'
      : deck.id;
  return '$core-${row.idPart}-$slotIndex';
}
