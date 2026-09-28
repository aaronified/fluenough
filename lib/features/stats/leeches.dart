import 'package:flutter/foundation.dart';

import '../../app/memory_progress.dart';
import '../../core/models/card.dart';
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

/// The pairs in [progress] with at least [threshold] lapses, most missed
/// first. A pair whose card has left its deck is skipped: it cannot be drilled
/// or shown, and its history stays in the log.
List<Leech> findLeeches(
  ProgressStore progress, {
  required CardLookup cardOf,
  int threshold = kLeechThreshold,
}) {
  final leeches = <Leech>[
    for (final MapEntry(:key, :value) in progress.states.entries)
      if (value.lapses >= threshold)
        if (cardOf(key.deckId, key.cardId) case final card?)
          Leech(key: key, card: card, state: value),
  ];
  leeches.sort((a, b) {
    final byLapses = b.lapses.compareTo(a.lapses);
    if (byLapses != 0) return byLapses;
    final byDeck = a.key.deckId.compareTo(b.key.deckId);
    if (byDeck != 0) return byDeck;
    final byCard = a.key.cardId.compareTo(b.key.cardId);
    return byCard != 0 ? byCard : a.key.mode.index.compareTo(b.key.mode.index);
  });
  return leeches;
}

/// What the learner has done about a leech.
enum LeechStatus { active, reset, setAside }

/// One thing done to a leech. Each undoes nothing in place: Undo and Bring
/// back are events of their own.
enum LeechActionKind { reset, undoReset, setAside, bringBack }

class LeechAction {
  const LeechAction({required this.at, required this.key, required this.kind});

  final DateTime at;
  final ProgressKey key;
  final LeechActionKind kind;
}

/// Reset and Set aside, kept as an append-only log of their own beside the
/// review log (AGENTS.md rule 9): nothing here removes or rewrites a review.
/// A leech's status is its latest action.
///
/// In memory only, one per [ProgressStore], like the progress it annotates.
/// The scheduler does not read it yet: until #19 gives the store a reset and
/// a suspend event that replay honours, a reset pair keeps its SM-2 state
/// and a set-aside pair is still queued.
class LeechActions extends ChangeNotifier {
  LeechActions();

  static final Expando<LeechActions> _byStore = Expando<LeechActions>(
    'LeechActions',
  );

  /// The actions taken on [progress]'s leeches.
  static LeechActions of(ProgressStore progress) =>
      _byStore[progress] ??= LeechActions();

  final List<LeechAction> _log = <LeechAction>[];

  /// Every action, oldest first. Append-only.
  List<LeechAction> get log => List<LeechAction>.unmodifiable(_log);

  LeechStatus statusOf(ProgressKey key) {
    for (final action in _log.reversed) {
      if (action.key != key) continue;
      return switch (action.kind) {
        LeechActionKind.reset => LeechStatus.reset,
        LeechActionKind.setAside => LeechStatus.setAside,
        LeechActionKind.undoReset ||
        LeechActionKind.bringBack => LeechStatus.active,
      };
    }
    return LeechStatus.active;
  }

  /// Reset, or Undo if [key] was reset.
  void toggleReset(ProgressKey key, {required DateTime now}) => _append(
    key,
    statusOf(key) == LeechStatus.reset
        ? LeechActionKind.undoReset
        : LeechActionKind.reset,
    now,
  );

  /// Set aside, or Bring back if [key] was set aside.
  void toggleSetAside(ProgressKey key, {required DateTime now}) => _append(
    key,
    statusOf(key) == LeechStatus.setAside
        ? LeechActionKind.bringBack
        : LeechActionKind.setAside,
    now,
  );

  void _append(ProgressKey key, LeechActionKind kind, DateTime now) {
    _log.add(LeechAction(at: now, key: key, kind: kind));
    notifyListeners();
  }
}
