// A finished session's minutes are the time spent answering, not the time
// the app was open.

import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a long pause adds only the capped answer time (#486)', () {
    final start = DateTime(2026, 10, 21, 9);
    final result = SessionResult(
      answers: const <SessionAnswer>[
        SessionAnswer(
          skill: Skill.recognition,
          grade: 4,
          time: Duration(seconds: 20),
        ),
        SessionAnswer(
          skill: Skill.recognition,
          grade: 4,
          time: Duration(minutes: 30),
        ),
      ],
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 31)),
    );
    // 20 s + the 60 s cap = 80 s, which rounds to 1 minute, not 31.
    expect(result.minutes, 1);
  });

  test('a lesson counts every card, grades only the answers (#486)', () {
    final start = DateTime(2026, 10, 21, 9);
    final answers = <SessionAnswer>[
      for (var i = 0; i < 13; i++)
        SessionAnswer(
          skill: Skill.recognition,
          grade: i < 11 ? 4 : 1,
          time: const Duration(seconds: 15),
        ),
      for (var i = 0; i < 5; i++)
        SessionAnswer(
          skill: Skill.production,
          grade: i < 4 ? 4 : 1,
          time: const Duration(seconds: 15),
        ),
    ];
    final result = SessionResult(
      answers: answers,
      taught: 9,
      taughtTimes: List<Duration>.filled(9, const Duration(seconds: 10)),
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 31)),
    );
    expect(result.cards, 27);
    expect(result.total, 18);
    expect(result.correct, 15);
    expect(result.accuracy, closeTo(15 / 18, 1e-9));
    // The skill rows add up to the answered count.
    expect(result.bySkill.map((s) => s.total).reduce((a, b) => a + b), 18);
    expect(
      result.bySkill.map((s) => (s.correct, s.total)).toList(),
      <(int, int)>[(11, 13), (4, 5)],
    );
    // 18 x 15 s + 9 x 10 s = 360 s, not the 31 minutes on the wall clock.
    expect(result.minutes, 6);
  });

  test('a long pause on a taught card is capped too (#486)', () {
    final start = DateTime(2026, 10, 21, 9);
    final result = SessionResult(
      answers: const <SessionAnswer>[],
      taught: 1,
      taughtTimes: const <Duration>[Duration(minutes: 20)],
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 20)),
    );
    expect(result.cards, 1);
    expect(result.minutes, 1);
  });
}
