import '../models/leech_action.dart';
import '../models/review_event.dart';
import 'sm2.dart';

/// One review as the log keeps it: enough to replay it.
typedef LoggedReview = ({
  ProgressKey key,
  DateTime at,
  int grade,
  Duration elapsed,
  String? answerGiven,
});

/// Replays [reviews], in the order given, through [Sm2.next]: every review
/// with its pair's state before and after it, and each pair's state at the
/// end (ADR-0005).
///
/// A pair reset in [effects] starts fresh at its reset: reviews before it
/// replay as they happened, the first one after it starts from a fresh
/// state, and a pair with no review since its reset has no state at the end.
/// An undone reset is not in [effects], so it changes nothing.
({List<ReviewEvent> events, Map<ProgressKey, Sm2State> states}) replayReviews(
  Iterable<LoggedReview> reviews, {
  LeechEffects effects = LeechEffects.none,
}) {
  final states = <ProgressKey, Sm2State>{};
  final restarted = <ProgressKey>{};
  final events = <ReviewEvent>[];
  for (final review in reviews) {
    final key = review.key;
    final resetAt = effects.resetAt(key);
    if (resetAt != null && review.at.isAfter(resetAt) && restarted.add(key)) {
      states.remove(key);
    }
    final before = states[key];
    final after = Sm2.next(
      before ?? Sm2State.fresh(review.at),
      review.grade,
      now: review.at,
    );
    states[key] = after;
    events.add(
      ReviewEvent(
        at: review.at,
        deckId: key.deckId,
        cardId: key.cardId,
        mode: key.mode,
        grade: review.grade,
        elapsed: review.elapsed,
        answerGiven: review.answerGiven,
        before: before,
        after: after,
      ),
    );
  }
  for (final key in effects.resets.keys) {
    if (!restarted.contains(key)) states.remove(key);
  }
  return (events: events, states: states);
}

/// [event] as the log keeps it.
LoggedReview logged(ReviewEvent event) => (
  key: event.key,
  at: event.at,
  grade: event.grade,
  elapsed: event.elapsed,
  answerGiven: event.answerGiven,
);
