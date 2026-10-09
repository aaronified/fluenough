import '../models/leech_action.dart';
import '../models/review_event.dart';
import 'fsrs.dart';
import 'skill_map.dart';

/// One review as the log keeps it: enough to replay it.
typedef LoggedReview = ({
  ProgressKey key,
  String deckId,
  DateTime at,
  int grade,
  Duration elapsed,
  String? answerGiven,
});

/// Replays [reviews], in the order given, through [Fsrs.next]: every review
/// with its pair's state before and after it, and each pair's state at the
/// end (ADR-0005).
///
/// A pair reset in [effects] starts fresh at its reset: reviews before it
/// replay as they happened, the first one after it starts from a fresh
/// state, and a pair with no review since its reset has no state at the end.
/// An undone reset is not in [effects], so it changes nothing.
///
/// With [skills], a right answer also counts in part for the skills it
/// implies, of the same card, where that pair has a state ([implyReview]).
/// Without, each pair is its own reviews alone: what the database's
/// `card_states` caches.
({List<ReviewEvent> events, Map<ProgressKey, FsrsState> states}) replayReviews(
  Iterable<LoggedReview> reviews, {
  LeechEffects effects = LeechEffects.none,
  SkillMap? skills,
}) {
  final states = <ProgressKey, FsrsState>{};
  final restarted = <ProgressKey>{};
  final events = <ReviewEvent>[];
  for (final review in reviews) {
    final key = review.key;
    final resetAt = effects.resetAt(key);
    if (resetAt != null && review.at.isAfter(resetAt) && restarted.add(key)) {
      states.remove(key);
    }
    final before = states[key];
    final after = Fsrs.next(
      before,
      review.grade,
      now: review.at,
      rated: review.answerGiven == null,
    );
    states[key] = after;
    if (skills != null) implyReview(states, skills, review);
    events.add(
      ReviewEvent(
        at: review.at,
        deckId: review.deckId,
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

/// Credits [review], if right, in part to each skill [skills] says it
/// implies, of the same card, in [states] (ADR-0034). A pair with no state
/// is not started by it: it is new until it is asked itself.
void implyReview(
  Map<ProgressKey, FsrsState> states,
  SkillMap skills,
  LoggedReview review,
) {
  if (review.grade < Fsrs.passingGrade) return;
  for (final MapEntry(key: mode, value: share)
      in skills.impliedBy(review.key.mode, review.deckId).entries) {
    final key = (cardId: review.key.cardId, mode: mode);
    final state = states[key];
    if (state != null) {
      states[key] = Fsrs.implied(state, share, now: review.at);
    }
  }
}

/// [event] as the log keeps it.
LoggedReview logged(ReviewEvent event) => (
  key: event.key,
  deckId: event.deckId,
  at: event.at,
  grade: event.grade,
  elapsed: event.elapsed,
  answerGiven: event.answerGiven,
);

/// [reviews] oldest first, keeping the order they were given in for a tie.
/// The log replays by time, not by when a row was written, so that a
/// backup's older history merged in (#20) takes its place.
List<LoggedReview> inTimeOrder(Iterable<LoggedReview> reviews) {
  final indexed = reviews.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.at.compareTo(b.$2.at);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return <LoggedReview>[for (final (_, r) in indexed) r];
}

/// [actions] oldest first, keeping their order for a tie.
List<LeechAction> actionsInTimeOrder(Iterable<LeechAction> actions) {
  final indexed = actions.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.at.compareTo(b.$2.at);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return <LeechAction>[for (final (_, a) in indexed) a];
}
