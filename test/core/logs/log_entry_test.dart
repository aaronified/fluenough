import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/logs/log_entry.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);

  LogEntry at(DateTime time, [String message = 'Opened /deck']) =>
      LogEntry(time, LogLevel.event, message);

  group('a line', () {
    test('is the UTC time, the level and the message', () {
      expect(
        LogEntry(
          DateTime.utc(2026, 10, 9, 9, 52, 1, 123),
          LogLevel.event,
          'Opened /deck',
        ).line,
        '2026-10-09T09:52:01.123Z EVENT Opened /deck',
      );
      expect(LogEntry(now, LogLevel.warning, 'x').line, endsWith(' WARN x'));
      expect(LogEntry(now, LogLevel.error, 'x').line, endsWith(' ERROR x'));
    });

    test('keeps a message of many lines on one, and reads it back', () {
      final entry = LogEntry(
        now,
        LogLevel.error,
        'Uncaught: Bad state\n#0 main (a.dart:1)\r\nC:\\path\\n',
      );
      expect(entry.line, isNot(contains('\n')));
      expect(entry.line, isNot(contains('\r')));
      final back = LogEntry.parse(entry.line)!;
      expect(back.time, now);
      expect(back.level, LogLevel.error);
      expect(
        back.message,
        'Uncaught: Bad state\n#0 main (a.dart:1)\nC:\\path\\n',
      );
    });

    test('that is not an entry is skipped', () {
      for (final line in <String>[
        '',
        'nonsense',
        'yesterday EVENT x',
        '2026-10-09T09:52:01.123Z LOUD x',
      ]) {
        expect(LogEntry.parse(line), isNull, reason: line);
      }
      expect(
        parseLog('${at(now).line}\nnonsense\n\n${at(now, 'b').line}\n'),
        <LogEntry>[at(now), at(now, 'b')],
      );
    });

    test('with no message reads as an empty one', () {
      expect(LogEntry.parse('2026-10-09T09:52:01.123Z EVENT')!.message, '');
    });
  });

  group('the cap', () {
    test('drops entries older than 7 days', () {
      final old = at(now.subtract(const Duration(days: 7, seconds: 1)), 'old');
      final edge = at(now.subtract(const Duration(days: 7)), 'edge');
      final fresh = at(now.subtract(const Duration(hours: 1)), 'fresh');
      expect(capLog(<LogEntry>[old, edge, fresh], now), <LogEntry>[
        edge,
        fresh,
      ]);
    });

    test('keeps only the last 2,000 lines', () {
      final many = <LogEntry>[
        for (var i = 0; i < 2500; i++)
          at(now.subtract(Duration(seconds: 2500 - i)), '$i'),
      ];
      final kept = capLog(many, now);
      expect(kept, hasLength(logMaxLines));
      expect(kept.first.message, '500');
      expect(kept.last.message, '2499');
    });

    test('is whichever keeps fewer', () {
      // 3,000 lines over 10 days: the 7-day cut leaves 2,100, more than
      // 2,000, so the line cap decides.
      final busy = <LogEntry>[
        for (var i = 0; i < 3000; i++)
          at(now.subtract(Duration(minutes: (3000 - i) * 4.8 ~/ 1)), '$i'),
      ];
      expect(capLog(busy, now), hasLength(logMaxLines));
      // 100 lines over 10 days: the line cap leaves them all, and the
      // 7-day cut decides.
      final quiet = <LogEntry>[
        for (var i = 0; i < 100; i++)
          at(now.subtract(Duration(hours: (100 - i) * 24 * 10 ~/ 100))),
      ];
      expect(capLog(quiet, now), hasLength(70));
      expect(logMaxAge, const Duration(days: 7));
      expect(logMaxLines, 2000);
    });
  });

  test('the text is a line an entry, oldest first', () {
    final a = at(now, 'a');
    final b = at(now, 'b');
    expect(logText(<LogEntry>[a, b]), '${a.line}\n${b.line}');
    expect(logText(const <LogEntry>[]), '');
    expect(parseLog(logText(<LogEntry>[a, b])), <LogEntry>[a, b]);
  });

  test('an error keeps what was being done and the first frames only', () {
    final stack = StackTrace.fromString(
      List<String>.generate(20, (i) => '#$i frame$i').join('\n'),
    );
    final message = describeError(
      'Decks failed to load',
      StateError('no'),
      stack,
    );
    final lines = message.split('\n');
    expect(lines.first, 'Decks failed to load: StateError');
    expect(lines, hasLength(1 + logStackFrames));
    expect(lines.last, '#7 frame7');
    expect(describeError('x', 'y', null), 'x: String');
  });

  test("an error's text never reaches the log, which must not hold an "
      'answer or a card', () {
    // As sqlite's own does: the statement and its parameters, among them
    // what was typed.
    final message = describeError(
      'while saving a review',
      _Leaky(
        'disk I/O error\n  Causing statement: INSERT INTO reviews, '
        'parameters: es-0001, la casa secreta',
      ),
      StackTrace.fromString('#0 _write (database_progress.dart:160)'),
    );
    expect(message, isNot(contains('secreta')));
    expect(message, isNot(contains('Causing statement')));
    expect(
      message,
      'while saving a review: _Leaky\n#0 _write (database_progress.dart:160)',
    );
    expect(
      describeError(
        'Decks failed to load',
        const FormatException('x: "no"'),
        null,
      ),
      'Decks failed to load: FormatException',
    );
  });
}

class _Leaky implements Exception {
  _Leaky(this.text);

  final String text;

  @override
  String toString() => text;
}
