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
}
