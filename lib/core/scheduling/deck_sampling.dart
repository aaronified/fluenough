import 'fsrs.dart';

/// How likely a pair was to be recalled at its last review, for it to count
/// as known (owner, 2026-10-23: "Recall >=90% at last review").
const double kKnownRecall = 0.9;

/// More samples asked after the first fails, at least [kStressMin] and
/// bringing the deck's passes up to [kStressTotal] (owner, 2026-10-20: "ask
/// 3-5 more").
const int kStressMin = 3;
const int kStressTotal = 5;

/// How many due known cards of a deck stand for it at first (owner,
/// 2026-10-20: "ask 1-2 as review").
const int kSampleSize = 2;

/// Whether [state] is a known pair: its last review was right, and FSRS
/// predicted at least [kKnownRecall] recall for it at that moment
/// ([FsrsState.recallAtReview]).
bool isKnownState(FsrsState state) =>
    state.repetitions > 0 && state.recallAtReview >= kKnownRecall;

/// How many of a deck's due known cards to show now, out of [due] of them
/// (#680), worked out from the deck's pair [states] alone, so that it holds
/// after a restart and records nothing in the log.
///
/// The deck became pending when its first known card, [due] oldest first,
/// came due. Since then:
/// - a known pair reviewed right and not due again holds the deck: its other
///   due cards are not shown, until that pair comes due itself, which sends
///   the deck round again, the cards reviewed longest ago first, so every
///   card has a turn before any is repeated;
/// - a pair reviewed and missed (a lapse, with no right answer since) is a
///   failed sample: the first asks [kStressMin] to [kStressTotal] more, and a
///   second brings every due known card of the deck.
int sampleCount(
  List<FsrsState> due,
  Iterable<FsrsState> states, {
  required DateTime now,
}) {
  if (due.isEmpty) return 0;
  var since = due.first.dueAt;
  for (final s in due) {
    if (s.dueAt.isBefore(since)) since = s.dueAt;
  }
  var passed = 0;
  var failed = 0;
  for (final s in states) {
    if (!s.lastReviewAt.isAfter(since)) continue;
    if (s.repetitions == 0 && s.lapses > 0) {
      failed++;
    } else if (isKnownState(s) && s.dueAt.isAfter(now)) {
      passed++;
    }
  }
  if (failed >= 2) return due.length;
  if (failed == 1) {
    if (passed >= kStressTotal) return 0;
    final more = kStressTotal - passed;
    return more < kStressMin ? kStressMin : more;
  }
  return passed > 0 ? 0 : kSampleSize;
}
