import 'fsrs.dart';

/// How likely a pair was to be recalled at its last review, for it to count
/// as known (owner, 2026-10-23: "known bar 85%"). Below FSRS's own 90%
/// target, so a card reviewed a few days late still counts.
const double kKnownRecall = 0.85;

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
/// Each day a deck's known cards are sampled: [kSampleSize] of them, the
/// ones reviewed longest ago, so the rest wait only for their turn, a day
/// or so each, and every card is reviewed eventually. Today's samples are
/// the pairs reviewed today:
/// - known ones reviewed right count against the day's [kSampleSize], and
///   once that many are done the deck's other due cards wait until tomorrow;
/// - a pair reviewed and missed today (a lapse, even if it was then answered
///   right the same day) is a failed sample: the first asks [kStressMin] to
///   [kStressTotal] more, and a second brings every due known card of the
///   deck.
int sampleCount(
  List<FsrsState> due,
  Iterable<FsrsState> states, {
  required DateTime now,
}) {
  if (due.isEmpty) return 0;
  var passed = 0;
  var failed = 0;
  for (final s in states) {
    final l = s.lastReviewAt;
    if (l.year != now.year || l.month != now.month || l.day != now.day) {
      continue;
    }
    if (s.lapses > 0 && (s.repetitions == 0 || s.recallAtReview == 0)) {
      failed++;
    } else if (isKnownState(s)) {
      passed++;
    }
  }
  if (failed >= 2) return due.length;
  if (failed == 1) {
    if (passed >= kStressTotal) return 0;
    final more = kStressTotal - passed;
    return more < kStressMin ? kStressMin : more;
  }
  return passed >= kSampleSize ? 0 : kSampleSize - passed;
}
