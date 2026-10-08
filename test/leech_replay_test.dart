import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

const ProgressKey pair = (cardId: 'hi-0231', mode: DrillMode.production);
const ProgressKey other = (cardId: 'hi-0232', mode: DrillMode.production);

final DateTime day0 = DateTime(2026, 9, 1, 9);
DateTime day(int n) => DateTime(day0.year, day0.month, day0.day + n, 9);

LoggedReview review(ProgressKey key, int d, int grade) => (
  key: key,
  deckId: 'hi-en-market',
  at: day(d),
  grade: grade,
  elapsed: Duration.zero,
  answerGiven: null,
);

LeechAction act(LeechActionKind kind, int d, {ProgressKey key = pair}) =>
    LeechAction(at: day(d).add(const Duration(hours: 1)), key: key, kind: kind);

(double, double, int, DateTime, int, int) fields(FsrsState s) => (
  s.stability,
  s.difficulty,
  s.intervalDays,
  s.dueAt,
  s.repetitions,
  s.lapses,
);

void main() {
  final history = <LoggedReview>[
    review(pair, 0, 4),
    review(pair, 1, 1),
    review(other, 1, 5),
    review(pair, 3, 4),
    review(pair, 5, 2),
  ];

  test('with no actions, replay is Fsrs.next review by review', () {
    FsrsState? state;
    for (final r in history.where((r) => r.key == pair)) {
      state = Fsrs.next(state, r.grade, now: r.at, rated: true);
    }
    final replayed = replayReviews(history);
    expect(fields(replayed.states[pair]!), fields(state!));
    expect(replayed.events, hasLength(5));
    expect(replayed.events.first.before, isNull);
  });

  test('a reset restarts the pair at the reset and keeps its reviews', () {
    final effects = LeechEffects([act(LeechActionKind.reset, 1)]);
    final replayed = replayReviews(history, effects: effects);

    expect(replayed.events, hasLength(5), reason: 'nothing is dropped');
    // Before the reset, reviews replay as they happened.
    expect(replayed.events[1].before, isNotNull);
    // The first review after it starts fresh.
    final firstAfter = replayed.events[3];
    expect(firstAfter.at, day(3));
    expect(firstAfter.before, isNull);

    var expected = Fsrs.next(null, 4, now: day(3), rated: true);
    expected = Fsrs.next(expected, 2, now: day(5), rated: true);
    expect(fields(replayed.states[pair]!), fields(expected));
    expect(
      fields(replayed.states[other]!),
      fields(replayReviews(history).states[other]!),
      reason: 'other pairs are untouched',
    );
  });

  test('a pair with no review since its reset has no state', () {
    final effects = LeechEffects([act(LeechActionKind.reset, 6)]);
    final replayed = replayReviews(history, effects: effects);
    expect(replayed.states.containsKey(pair), isFalse);
    expect(replayed.states.containsKey(other), isTrue);
  });

  test('an undone reset changes nothing', () {
    final effects = LeechEffects([
      act(LeechActionKind.reset, 1),
      act(LeechActionKind.undoReset, 1),
    ]);
    expect(effects.resetAt(pair), isNull);
    expect(
      fields(replayReviews(history, effects: effects).states[pair]!),
      fields(replayReviews(history).states[pair]!),
    );
  });

  test('the latest reset that holds is the one that counts', () {
    final effects = LeechEffects([
      act(LeechActionKind.reset, 1),
      act(LeechActionKind.reset, 4),
    ]);
    final replayed = replayReviews(history, effects: effects);
    expect(replayed.events[3].before, isNotNull, reason: 'day 3 is before');
    expect(replayed.events[4].before, isNull, reason: 'day 5 restarts');
  });

  test('undo takes back only the latest reset', () {
    final effects = LeechEffects([
      act(LeechActionKind.reset, 1),
      act(LeechActionKind.reset, 4),
      act(LeechActionKind.undoReset, 5),
    ]);
    expect(effects.resetAt(pair), act(LeechActionKind.reset, 1).at);
    expect(
      LeechEffects([
        act(LeechActionKind.reset, 1),
        act(LeechActionKind.undoReset, 2),
      ]).resetAt(pair),
      isNull,
    );
  });

  test('set aside holds until the pair is brought back', () {
    expect(
      LeechEffects([act(LeechActionKind.setAside, 0)]).isSetAside(pair),
      isTrue,
    );
    expect(
      LeechEffects([
        act(LeechActionKind.setAside, 0),
        act(LeechActionKind.bringBack, 1),
      ]).isSetAside(pair),
      isFalse,
    );
    expect(
      LeechEffects([act(LeechActionKind.setAside, 0)]).isSetAside(other),
      isFalse,
    );
    expect(LeechEffects.none.isSetAside(pair), isFalse);
  });
}
