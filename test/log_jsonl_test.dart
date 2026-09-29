import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/replay.dart';

const ProgressKey pair = (
  deckId: 'hi-en-market',
  cardId: 'hi-en-market-0001',
  mode: DrillMode.production,
);

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
      at: at,
      grade: 4,
      elapsed: const Duration(milliseconds: 3120),
      answerGiven: 'बाज़ार',
    ),
    (
      key: (
        deckId: 'bn-en-market',
        cardId: 'bn-en-market-0004',
        mode: DrillMode.recognition,
      ),
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
      'card': 'hi-en-market-0001',
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
      'deck': 'hi-en-market',
      'card': 'hi-en-market-0001',
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
    expect(back.reviews.single.key, (
      deckId: 'd',
      cardId: 'c',
      mode: DrillMode.listening,
    ));
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
        failsWith('line 2: deck, card or mode is missing'),
      );
    });

    test('a leech action of a kind it does not know', () {
      expect(
        () => LogJsonl.decode(withLine('{"type":"leech",$good,"kind":"x"}')),
        failsWith('line 2: unknown kind'),
      );
    });
  });

  test('a review is the same review by its pair and moment alone', () {
    final r = reviews.first;
    final regraded = (
      key: r.key,
      at: r.at,
      grade: 0,
      elapsed: Duration.zero,
      answerGiven: null,
    );
    expect(reviewIdentity(regraded), reviewIdentity(r));
    final later = (
      key: r.key,
      at: r.at.add(const Duration(milliseconds: 1)),
      grade: r.grade,
      elapsed: r.elapsed,
      answerGiven: r.answerGiven,
    );
    expect(reviewIdentity(later), isNot(reviewIdentity(r)));
  });
}
