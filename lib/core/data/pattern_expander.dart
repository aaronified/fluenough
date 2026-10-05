import '../models/card.dart';
import '../models/deck.dart';
import '../models/drill_mode.dart';
import '../models/grammar_pattern.dart';

/// One grammar deck's pattern table as cards: one per `(entry, slot)` cell
/// that has a form (docs/DECK-FORMAT.md, "Expansion").
///
/// - **id** [patternCardId]: `<language>-<deck name>-<key>-<slot-index>`,
///   where the deck name is the deck id without its course, and the key is
///   the entry's `key`, or its lemma when it has none. `bn-en-grammar-present`
///   and a `bn-hi-grammar-present` both expand to `bn-grammar-present-…`, so
///   a cell is one card whichever language it is learned from (ADR-0018).
///   The slot index is positional, so reordering a deck's `slots` rewrites
///   every id and orphans history; that is the documented scheme, and this
///   does not defend against it.
/// - **target** the cell's form, and **alt_target** the others it accepts
///   (#144); **native** the prompt with `{lemma}`,
///   `{gloss}` and `{slot}` filled in; **notes** the pattern's notes, shown
///   after answering; **modes** `grammar` only.
///
/// A cell whose form is null (a defective verb) is skipped, not drilled.
/// Returns no cards for a deck without a pattern.
List<Card> expandPattern(Deck deck) {
  final pattern = deck.pattern;
  if (pattern == null) return const <Card>[];
  return <Card>[
    for (final entry in pattern.entries)
      for (final (i, slot) in pattern.slots.indexed)
        if (entry.forms[slot] case final form?)
          Card(
            id: patternCardId(deck, entry, i),
            deckId: deck.id,
            target: form,
            altTarget: entry.alternatives[slot] ?? const <String>[],
            reading: entry.readings[slot]?.first,
            altReading:
                entry.readings[slot]?.skip(1).toList() ?? const <String>[],
            ipa: entry.ipas[slot],
            native: pattern.prompt.replaceAllMapped(
              _placeholder,
              (m) => switch (m[1]) {
                'lemma' => entry.lemma,
                'gloss' => entry.gloss,
                _ => slot,
              },
            ),
            notes: pattern.notes,
            modes: const <DrillMode>{DrillMode.grammar},
          ),
  ];
}

/// The id of the card [deck]'s pattern expands from [entry] at slot
/// [slotIndex]. The one place the scheme is written, so that the drill finds
/// a card's cell by the same id the expander gave it.
String patternCardId(Deck deck, PatternEntry entry, int slotIndex) {
  final course = '${deck.language.code}-${deck.native.code}-';
  final name = deck.id.startsWith(course)
      ? '${deck.language.code}-${deck.id.substring(course.length)}'
      : deck.id;
  return '$name-${entry.idPart}-$slotIndex';
}

final RegExp _placeholder = RegExp(r'\{(lemma|gloss|slot)\}');
