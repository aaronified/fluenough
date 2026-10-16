import '../../core/models/card.dart';

/// How the screens read a card's notes, which the B1 format made a list of
/// typed notes (`NoteKind`, ADR-0036): a pair note names a word that sounds
/// almost the same, a region note names the regions it is about, and every
/// other note is prose to show.

/// The texts of [card]'s notes a card's face shows, in order: every note
/// but a pair note, whose text goes with its partner's warning instead.
/// Empty when it has none.
List<String> shownNotes(Card card) => <String>[
  for (final note in card.notes)
    if (note.kind != NoteKind.pair && note.text.trim().isNotEmpty) note.text,
];

/// [shownNotes] as one block of text, a note a line, or null when there is
/// none: what "Suggest a change" shows under Now for the notes.
String? notesText(Card card) {
  final notes = shownNotes(card);
  return notes.isEmpty ? null : notes.join('\n');
}

/// The words [card] sounds almost like, by card id, each once and in order:
/// its `pair`, then the partner of each of its pair notes, with that note's
/// text where it has one (the care note).
List<({String id, String? care})> pairsOf(Card card) {
  final seen = <String>{};
  final out = <({String id, String? care})>[];
  String? careFor(String id) {
    for (final note in card.notes) {
      if (note.kind == NoteKind.pair &&
          note.ref == id &&
          note.text.trim().isNotEmpty) {
        return note.text;
      }
    }
    return null;
  }

  void add(String? id) {
    if (id == null || !seen.add(id)) return;
    out.add((id: id, care: careFor(id)));
  }

  add(card.pair);
  for (final note in card.notes) {
    if (note.kind == NoteKind.pair) add(note.ref);
  }
  return out;
}

/// [card]'s region note: its first note that names regions of its
/// language's path, or null.
CardNote? regionNoteOf(Card card) {
  for (final note in card.notes) {
    if (note.regions.isNotEmpty) return note;
  }
  return null;
}
