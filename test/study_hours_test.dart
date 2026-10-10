import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/study_hours.dart';

final DateTime t0 = DateTime.utc(2026, 10, 1);

FsrsState stateWith(int intervalDays, {double stability = 2}) => FsrsState(
  stability: stability,
  difficulty: 5,
  intervalDays: intervalDays,
  dueAt: t0.add(Duration(days: intervalDays)),
  lastReviewAt: t0,
);

ReviewEvent answer(
  int seconds, {
  DrillMode mode = DrillMode.recognition,
  int grade = 4,
}) => ReviewEvent(
  at: t0,
  deckId: 'es-core',
  cardId: 'es-0001',
  mode: mode,
  grade: grade,
  elapsed: Duration(seconds: seconds),
  before: null,
  after: stateWith(2),
);

void main() {
  group('hours spent', () {
    test('each answer counts for at most a minute', () {
      expect(StudyHours.capped(const Duration(seconds: 45)).inSeconds, 45);
      expect(StudyHours.capped(const Duration(minutes: 30)).inSeconds, 60);
      expect(StudyHours.capped(const Duration(seconds: -3)), Duration.zero);
    });

    test('is the sum of the capped times', () {
      final spent = StudyHours.spent(<ReviewEvent>[
        answer(10),
        answer(20),
        answer(600),
      ]);
      expect(spent.inSeconds, 90);
      expect(StudyHours.spent(const <ReviewEvent>[]), Duration.zero);
    });

    test('in hours, as a fraction', () {
      expect(StudyHours.hours(const Duration(minutes: 90)), 1.5);
    });
  });

  group('time per answer', () {
    test('is 20 seconds until a skill has 20 answers', () {
      final times = StudyHours.answerTimes(<ReviewEvent>[
        for (var i = 0; i < 19; i++) answer(5),
      ]);
      expect(times[DrillMode.recognition], StudyHours.defaultAnswerTime);
      expect(
        StudyHours.timeIn(times, DrillMode.production),
        const Duration(seconds: 20),
      );
    });

    test('is then the median of the capped times, skill by skill', () {
      final times = StudyHours.answerTimes(<ReviewEvent>[
        for (var i = 0; i < 10; i++) answer(4),
        for (var i = 0; i < 11; i++) answer(8),
        // Capped at 60 s: a median, so outliers move it no further.
        for (var i = 0; i < 20; i++)
          answer(i < 10 ? 3600 : 6, mode: DrillMode.production),
      ]);
      expect(times[DrillMode.recognition], const Duration(seconds: 8));
      expect(times[DrillMode.production], const Duration(seconds: 33));
    });
  });

  group('share of misses', () {
    test('is the share of answers below the passing grade', () {
      expect(StudyHours.missShare(const <ReviewEvent>[]), 0);
      expect(
        StudyHours.missShare(<ReviewEvent>[
          answer(5, grade: 1),
          answer(5),
          answer(5),
          answer(5),
        ]),
        0.25,
      );
    });

    test('is held at a half', () {
      expect(
        StudyHours.missShare(<ReviewEvent>[
          for (var i = 0; i < 4; i++) answer(5, grade: 0),
        ]),
        StudyHours.maxMissShare,
      );
    });
  });

  group('reviews still needed', () {
    test('none once the interval reaches 21 days', () {
      expect(StudyHours.isRemembered(stateWith(21)), isTrue);
      expect(StudyHours.isRemembered(stateWith(20)), isFalse);
      expect(StudyHours.isRemembered(null), isFalse);
      expect(StudyHours.rightAnswersToRemember(stateWith(30)), 0);
    });

    test('a new pair needs the right answers FSRS takes to reach 21 days', () {
      final count = StudyHours.rightAnswersToRemember(null);
      // Replayed by hand: Good on each due day until 21 days.
      FsrsState? state;
      var expected = 0;
      while (state == null || state.intervalDays < 21) {
        state = Fsrs.review(
          state,
          Rating.good,
          now: state?.dueAt ?? DateTime.utc(2000),
        );
        expected++;
      }
      expect(count, expected);
      expect(count, greaterThan(1));
    });

    test('a pair further along needs fewer', () {
      final fresh = StudyHours.rightAnswersToRemember(null);
      final along = StudyHours.rightAnswersToRemember(
        stateWith(10, stability: 10),
      );
      expect(along, lessThan(fresh));
      expect(along, greaterThan(0));
    });

    test('are raised by the learner\'s share of misses', () {
      final right = StudyHours.rightAnswersToRemember(null);
      expect(StudyHours.reviewsToRemember(null), right);
      expect(StudyHours.reviewsToRemember(null, missShare: 0.5), right * 2);
      expect(StudyHours.reviewsToRemember(null, missShare: 0.9), right * 2);
    });
  });

  group('hours left', () {
    test('sum each pair left: its reviews times its skill\'s time', () {
      final right = StudyHours.rightAnswersToRemember(null);
      final left = StudyHours.left(
        <(DrillMode, FsrsState?)>[
          (DrillMode.recognition, null),
          (DrillMode.production, null),
          // Remembered: counts for nothing.
          (DrillMode.recognition, stateWith(40)),
        ],
        times: const <DrillMode, Duration>{
          DrillMode.recognition: Duration(seconds: 10),
        },
      );
      // Production has no time of its own, so takes the default 20 s.
      expect(left, Duration(seconds: right * (10 + 20)));
    });

    test('nothing left when every pair is remembered, or there are none', () {
      expect(
        StudyHours.left(<(DrillMode, FsrsState?)>[
          (DrillMode.listening, stateWith(21)),
        ], times: const <DrillMode, Duration>{}),
        Duration.zero,
      );
      expect(
        StudyHours.left(
          const <(DrillMode, FsrsState?)>[],
          times: const <DrillMode, Duration>{},
        ),
        Duration.zero,
      );
    });

    test('uses the parameters that schedule each skill', () {
      final asked = <DrillMode>[];
      StudyHours.left(
        <(DrillMode, FsrsState?)>[(DrillMode.listening, null)],
        times: const <DrillMode, Duration>{},
        parametersOf: (mode) {
          asked.add(mode);
          return Fsrs.w;
        },
      );
      expect(asked, <DrillMode>[DrillMode.listening]);
    });
  });
}
