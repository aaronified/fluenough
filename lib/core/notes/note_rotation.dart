import 'dart:math';

import '../models/card.dart';

/// Which note of a card to show next (#421, DECK-FORMAT.md, Notes): one at a
/// time, chosen at random, and none shown again until every note of the card
/// has been shown once. Then a new round starts, and its first note is never
/// the one that ended the last, so that a card with two notes alternates.
///
/// The notes are remembered by card id and note id, so a deck that reorders
/// its notes, or adds one, does not restart the round: an unseen note is
/// still due, and a note the deck dropped is forgotten. Kept in memory for
/// the run of the app.
class NoteRotation {
  NoteRotation(this._random);

  final Random _random;

  /// The notes shown so far in each card's current round, by card id.
  final Map<String, Set<String>> _shown = <String, Set<String>>{};

  /// The note that ended each card's last round, by card id.
  final Map<String, String> _lastOfRound = <String, String>{};

  /// The next of [notes] to show for the card [cardId], and counts it shown.
  /// Null when [notes] is empty.
  CardNote? next(String cardId, List<CardNote> notes) {
    if (notes.isEmpty) return null;
    final ids = <String>{for (final n in notes) n.id};
    final shown = (_shown[cardId] ?? <String>{})..retainWhere(ids.contains);
    var due = <CardNote>[
      for (final n in notes)
        if (!shown.contains(n.id)) n,
    ];
    if (due.isEmpty) {
      // Every note has been shown: a new round.
      shown.clear();
      due = notes;
      final last = _lastOfRound[cardId];
      if (due.length > 1 && last != null) {
        due = <CardNote>[
          for (final n in due)
            if (n.id != last) n,
        ];
      }
    }
    final pick = due[_random.nextInt(due.length)];
    shown.add(pick.id);
    _shown[cardId] = shown;
    if (shown.length == ids.length) _lastOfRound[cardId] = pick.id;
    return pick;
  }
}
