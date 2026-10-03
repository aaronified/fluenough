import 'package:flutter/foundation.dart';

import '../../app/memory_progress.dart';
import '../../core/models/card.dart';
import '../../core/scheduling/replay.dart';
import '../../core/scheduling/sm2.dart';
import 'stats_numbers.dart';

/// Lapses at which a pair counts as a leech: #19's default. The copy takes it
/// as a placeholder (`leechesIntro`), so making it a setting changes no text.
const int kLeechThreshold = 5;

/// One pair missed again and again: [Sm2State.lapses] at or over the
/// threshold.
class Leech {
  const Leech({required this.key, required this.card, required this.state});

  final ProgressKey key;
  final Card card;
  final Sm2State state;

  int get lapses => state.lapses;
}

/// The pairs in [progress] with at least [threshold] lapses over their
/// whole history, most missed first. Lifetime lapses, so that a leech the
/// learner has reset stays listed and its reset can be undone. A pair whose card has left its deck is skipped: it cannot be drilled
/// or shown, and its history stays in the log.
List<Leech> findLeeches(
  ProgressStore progress, {
  required CardLookup cardOf,
  int threshold = kLeechThreshold,
}) {
  // A pair is shown in the deck it was last answered in.
  final lastDeck = <ProgressKey, String>{
    for (final event in progress.log) event.key: event.deckId,
  };
  final leeches = <Leech>[
    for (final MapEntry(:key, :value) in replayReviews(
      progress.log.map(logged),
    ).states.entries)
      if (value.lapses >= threshold)
        if (cardOf(key.cardId, deckId: lastDeck[key]) case final card?)
          Leech(key: key, card: card, state: value),
  ];
  leeches.sort((a, b) {
    final byLapses = b.lapses.compareTo(a.lapses);
    if (byLapses != 0) return byLapses;
    final byDeck = a.card.deckId.compareTo(b.card.deckId);
    if (byDeck != 0) return byDeck;
    final byCard = a.key.cardId.compareTo(b.key.cardId);
    return byCard != 0 ? byCard : a.key.mode.index.compareTo(b.key.mode.index);
  });
  return leeches;
}

/// What the learner has done about a leech, as its row shows it: its latest
/// action.
enum LeechStatus { active, reset, setAside }

/// Reset and Set aside on the leeches of one [ProgressStore], which records
/// them (#19): append-only beside the review log (AGENTS.md rule 9), saved
/// with the progress, and honoured by the scheduler. A reset restarts the
/// pair; a set-aside keeps it out of sessions. Listening to this is
/// listening to the store.
class LeechActions implements Listenable {
  const LeechActions._(this._progress);

  /// The actions taken on [progress]'s leeches.
  static LeechActions of(ProgressStore progress) => LeechActions._(progress);

  final ProgressStore _progress;

  /// Every action, oldest first. Append-only.
  List<LeechAction> get log => _progress.leechActions;

  /// What [key]'s row says: set aside before reset, as a pair set aside is
  /// out of every session whether reset or not.
  LeechStatus statusOf(ProgressKey key) {
    if (isSetAside(key)) return LeechStatus.setAside;
    if (isReset(key)) return LeechStatus.reset;
    return LeechStatus.active;
  }

  /// [key]'s actions alone, added up.
  LeechEffects _effectsOf(ProgressKey key) =>
      LeechEffects(log.where((a) => a.key == key));

  /// Whether a reset of [key] holds, whether or not it is also set aside.
  bool isReset(ProgressKey key) => _effectsOf(key).resetAt(key) != null;

  /// Whether [key] is set aside, whether or not it is also reset.
  bool isSetAside(ProgressKey key) => _effectsOf(key).isSetAside(key);

  void toggleReset(ProgressKey key, {required DateTime now}) =>
      _progress.actOnLeech(
        key,
        isReset(key) ? LeechActionKind.undoReset : LeechActionKind.reset,
        now: now,
      );

  /// Set aside, or Bring back if [key] was set aside.
  void toggleSetAside(ProgressKey key, {required DateTime now}) =>
      _progress.actOnLeech(
        key,
        isSetAside(key) ? LeechActionKind.bringBack : LeechActionKind.setAside,
        now: now,
      );

  @override
  void addListener(VoidCallback listener) => _progress.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _progress.removeListener(listener);
}
