import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/review_event.dart';
import 'deck_sampling.dart';
import 'fsrs.dart';

/// How the pairs placement credited for a course are reviewed (#761), chosen
/// per course after placement and changeable at any time.
enum PlacedReview {
  /// No reviews: the placed pairs count as known and wait for nothing.
  setInStone,

  /// The default (owner, 2026-10-23): the placed pairs count as known for
  /// #680's sampling, so a few stand for their deck each day, and a miss
  /// widens coverage as it does for any known card.
  spotCheck,

  /// Reviewed as usual, as any pair is.
  keepReviewing;

  /// What a course with no choice saved uses.
  static const PlacedReview fallback = spotCheck;

  /// The choice saved as [name], or null for anything else.
  static PlacedReview? parse(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// How the pair of [card] in [mode] is reviewed if placement credited it,
/// else null: a word learned after placement is always reviewed as usual.
typedef PlacedLookup = PlacedReview? Function(Card card, DrillMode mode);

/// Whether [state] is a pair whose only review is placement's credit: one
/// right answer, never missed, and no recall measured yet
/// ([FsrsState.recallAtReview] is 0 for a first review).
bool isPlacementOnly(FsrsState state) =>
    state.repetitions > 0 && state.lapses == 0 && state.recallAtReview == 0;

/// Whether a placed pair counts as known for sampling: known as any pair is
/// ([isKnownState]), or not yet reviewed since placement credited it.
bool isPlacedKnown(FsrsState state) =>
    isKnownState(state) || isPlacementOnly(state);

/// The pairs placement credited, found in [log] (oldest first): those whose
/// first review was written at one of the seconds [placedAt] gives for its
/// deck, as placement writes all its credit at one moment. A pair reviewed
/// before placement, or after it by the learner, is not one of them.
Set<ProgressKey> placedPairs(
  Iterable<ReviewEvent> log, {
  required Set<int> Function(String deckId) placedAt,
}) {
  final seen = <ProgressKey>{};
  final placed = <ProgressKey>{};
  for (final event in log) {
    final key = (cardId: event.cardId, mode: event.mode);
    if (!seen.add(key)) continue;
    final seconds = event.at.millisecondsSinceEpoch ~/ 1000;
    if (placedAt(event.deckId).contains(seconds)) placed.add(key);
  }
  return placed;
}
