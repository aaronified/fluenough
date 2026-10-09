import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_parameters.dart';

const ProgressKey pair = (cardId: 'hi-0231', mode: DrillMode.production);

const String header = '{"format":"fluenough-review-log","version":1}';

/// Everything a review holds, so two compare by value.
(ProgressKey, int, int, int, String?) fieldsOf(LoggedReview r) => (
  r.key,
  r.at.millisecondsSinceEpoch,
  r.grade,
  r.elapsed.inMilliseconds,
  r.answerGiven,
);

Matcher failsWith(String message) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', message),
);

void main() {
  final at = DateTime(2026, 9, 28, 19, 4, 5, 678);
  final reviews = <LoggedReview>[
    (
      key: pair,
      deckId: 'hi-en-market',
      at: at,
      grade: 4,
      elapsed: const Duration(milliseconds: 3120),
      answerGiven: 'बाज़ार',
    ),
    (
      key: (cardId: 'bn-0246', mode: DrillMode.recognition),
      deckId: 'bn-en-market',
      at: at.add(const Duration(days: 1)),
      grade: 1,
      elapsed: Duration.zero,
      answerGiven: null,
    ),
  ];
  final actions = <LeechAction>[
    LeechAction(
      at: at.add(const Duration(days: 2)),
      key: pair,
      kind: LeechActionKind.setAside,
    ),
  ];

  test('what is written reads back the same, to the millisecond', () {
    final text = LogJsonl.encode(reviews, actions);
    final back = LogJsonl.decode(text);
    expect(back.reviews.map(fieldsOf), reviews.map(fieldsOf));
    expect(back.reviews.first.at.isUtc, isFalse, reason: 'local on reading');
    expect(back.leechActions, hasLength(1));
    final action = back.leechActions.single;
    expect(action.key, pair);
    expect(action.kind, LeechActionKind.setAside);
    expect(action.at, actions.single.at);
  });

  test('one object per line: a header, then reviews, then leech actions', () {
    final lines = const LineSplitter().convert(
      LogJsonl.encode(reviews, actions),
    );
    expect(lines, hasLength(4));
    expect(jsonDecode(lines[0]), {
      'format': 'fluenough-review-log',
      'version': 1,
    });
    expect(jsonDecode(lines[1]), {
      'type': 'review',
      'ts': at.toUtc().toIso8601String(),
      'deck': 'hi-en-market',
      'card': 'hi-0231',
      'mode': 'production',
      'grade': 4,
      'elapsed_ms': 3120,
      'answer': 'बाज़ार',
    });
    expect(
      (jsonDecode(lines[2]) as Map).containsKey('answer'),
      isFalse,
      reason: 'a self-graded review has no answer',
    );
    expect(jsonDecode(lines[3]), {
      'type': 'leech',
      'ts': actions.single.at.toUtc().toIso8601String(),
      'card': 'hi-0231',
      'mode': 'production',
      'kind': 'setAside',
    });
    expect(lines[1], contains('Z"'), reason: 'times are written in UTC');
  });

  test('an empty log is a header alone, and reads back empty', () {
    final text = LogJsonl.encode(const [], const []);
    expect(text, '$header\n');
    final back = LogJsonl.decode(text);
    expect(back.reviews, isEmpty);
    expect(back.leechActions, isEmpty);
  });

  test('blank lines and line types it does not know are skipped', () {
    final back = LogJsonl.decode(
      '$header\r\n\n'
      '{"type":"note","text":"from a newer app"}\n'
      '{"type":"review","ts":"2026-09-28T13:34:05.678Z","deck":"d",'
      '"card":"c","mode":"listening","grade":5,"elapsed_ms":0}\n\n',
    );
    expect(back.reviews.single.key, (cardId: 'c', mode: DrillMode.listening));
    expect(
      back.reviews.single.at.toUtc(),
      DateTime.utc(2026, 9, 28, 13, 34, 5, 678),
    );
  });

  group('a file that is not a review log is refused, saying why', () {
    String withLine(String line) => '$header\n$line\n';
    const good =
        '"ts":"2026-09-28T13:34:05Z","deck":"d","card":"c",'
        '"mode":"recognition"';

    test('no header', () {
      expect(
        () => LogJsonl.decode(''),
        failsWith('not a Fluenough review log'),
      );
      expect(
        () => LogJsonl.decode('{"format":"anki"}'),
        failsWith('not a Fluenough review log'),
      );
    });

    test('a newer version', () {
      expect(
        () => LogJsonl.decode('{"format":"fluenough-review-log","version":2}'),
        failsWith('log version 2 is newer than this app reads'),
      );
    });

    test('a line that is not JSON, or not an object, by its number', () {
      expect(
        () => LogJsonl.decode(withLine('{"type":')),
        failsWith('line 2 is not JSON'),
      );
      expect(
        () => LogJsonl.decode(withLine('[1, 2]')),
        failsWith('line 2 is not a JSON object'),
      );
    });

    test('a review missing what it needs', () {
      expect(
        () =>
            LogJsonl.decode(withLine('{"type":"review",$good,"elapsed_ms":0}')),
        failsWith('line 2: grade is not a whole number'),
      );
      expect(
        () => LogJsonl.decode(
          withLine('{"type":"review",$good,"grade":6,"elapsed_ms":0}'),
        ),
        failsWith('line 2: grade 6'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"review",$good,"grade":3,"elapsed_ms":0,"answer":7}',
          ),
        ),
        failsWith('line 2: answer is not text'),
      );
      expect(
        () => LogJsonl.decode(
          withLine('{"type":"review",$good,"grade":3,"elapsed_ms":-5}'),
        ),
        failsWith('line 2: elapsed_ms -5'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"review","ts":"yesterday","deck":"d","card":"c",'
            '"mode":"recognition","grade":3,"elapsed_ms":0}',
          ),
        ),
        failsWith('line 2: ts is not a time'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"review","ts":"2026-09-28T13:34:05Z","deck":"d",'
            '"card":"c","mode":"typing","grade":3,"elapsed_ms":0}',
          ),
        ),
        failsWith('line 2: card or mode is missing'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"review","ts":"2026-09-28T13:34:05Z",'
            '"card":"c","mode":"recognition","grade":3,"elapsed_ms":0}',
          ),
        ),
        failsWith('line 2: deck is missing'),
      );
    });

    test('a leech action of a kind it does not know', () {
      expect(
        () => LogJsonl.decode(withLine('{"type":"leech",$good,"kind":"x"}')),
        failsWith('line 2: unknown kind'),
      );
    });
  });

  group('fitted parameters', () {
    final hear = FittedParameters(
      values: <double>[for (final (i, v) in Fsrs.w.indexed) v * (1 + i / 100)],
      fittedAt: at.add(const Duration(days: 3)),
      reviewCount: 1234,
      lossBefore: 0.4123456789,
      lossAfter: 0.3987654321,
    );
    final write = FittedParameters(
      values: Fsrs.w,
      fittedAt: at.add(const Duration(days: 4)),
      reviewCount: 800,
    );
    final fitted = <SkillKey, FittedParameters>{
      (language: 'hi', mode: DrillMode.production): write,
      (language: 'hi', mode: DrillMode.listening): hear,
    };

    test('are written after the log, and read back exactly', () {
      final text = LogJsonl.encode(reviews, actions, fitted: fitted);
      final lines = const LineSplitter().convert(text);
      expect(lines, hasLength(6));
      // By language, then in the order of the modes.
      expect(jsonDecode(lines[5]), {
        'type': 'parameters',
        'ts': hear.fittedAt.toUtc().toIso8601String(),
        'language': 'hi',
        'mode': 'listening',
        'w': hear.values,
        'reviews': 1234,
        'loss_before': 0.4123456789,
        'loss_after': 0.3987654321,
      });
      expect((jsonDecode(lines[4]) as Map).containsKey('loss_before'), isFalse);
      expect((jsonDecode(lines[4]) as Map)['mode'], 'production');

      final back = LogJsonl.decode(text);
      expect(back.reviews.map(fieldsOf), reviews.map(fieldsOf));
      expect(back.fitted, fitted);
      final values =
          back.fitted[(language: 'hi', mode: DrillMode.listening)]!.values;
      for (var i = 0; i < 21; i++) {
        expect(values[i], hear.values[i], reason: 'w$i, to the last bit');
      }
    });

    test('a backup from before fitting has none, and still reads', () {
      final back = LogJsonl.decode(LogJsonl.encode(reviews, actions));
      expect(back.fitted, isEmpty);
      expect(back.reviews, hasLength(2));
    });

    test('of two for one skill, the later is kept', () {
      final older = FittedParameters(
        values: Fsrs.w,
        fittedAt: at,
        reviewCount: 10,
      );
      final text = LogJsonl.encode(reviews, actions, fitted: fitted);
      final line = LogJsonl.encode(
        const [],
        const [],
        fitted: {(language: 'hi', mode: DrillMode.listening): older},
      ).split('\n')[1];
      final back = LogJsonl.decode('$text$line\n');
      expect(back.fitted[(language: 'hi', mode: DrillMode.listening)], hear);
    });

    test('a malformed set refuses the file, naming the line', () {
      String withLine(String line) => '$header\n$line\n';
      final w = jsonEncode(Fsrs.w);
      const ts = '"ts":"2026-09-28T13:34:05Z"';
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"parameters",$ts,"mode":"listening","w":$w,'
            '"reviews":1}',
          ),
        ),
        failsWith('line 2: language or mode is missing'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"parameters",$ts,"language":"hi",'
            '"mode":"listening","w":[1,2],"reviews":1}',
          ),
        ),
        failsWith('line 2: w is not 21 numbers'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"parameters",$ts,"language":"hi",'
            '"mode":"listening","w":$w}',
          ),
        ),
        failsWith('line 2: reviews is not a whole number'),
      );
      expect(
        () => LogJsonl.decode(
          withLine(
            '{"type":"parameters",$ts,"language":"hi",'
            '"mode":"listening","w":$w,"reviews":1,"loss_after":"x"}',
          ),
        ),
        failsWith('line 2: loss_after is not a number'),
      );
    });
  });

  test('a review is the same review by its pair and moment alone', () {
    final r = reviews.first;
    final regraded = (
      key: r.key,
      deckId: r.deckId,
      at: r.at,
      grade: 0,
      elapsed: Duration.zero,
      answerGiven: null,
    );
    expect(reviewIdentity(regraded), reviewIdentity(r));
    final later = (
      key: r.key,
      deckId: r.deckId,
      at: r.at.add(const Duration(milliseconds: 1)),
      grade: r.grade,
      elapsed: r.elapsed,
      answerGiven: r.answerGiven,
    );
    expect(reviewIdentity(later), isNot(reviewIdentity(r)));
  });
}
