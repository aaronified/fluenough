// Start-up timing marks (#1699): a span logs one line with where it ran and
// its counts, passes its result and its error on, and the summary names the
// slowest spans; instrumentation never throws.

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/startup_marks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLog log;
  late StartupMarks marks;

  setUp(() {
    log = AppLog(store: MemoryLogStore());
    marks = StartupMarks(log);
  });

  List<String> lines() => <String>[for (final e in log.entries) e.message];

  test('a span logs one line with its isolate and counts and returns the '
      'result', () async {
    final result = await marks.span<int>(
      'catalog: read files',
      () => 42,
      extra: <String, Object?>{'count': 3, 'bytes': 120},
    );
    expect(result, 42);
    final line = lines().single;
    expect(line, startsWith('Startup: catalog: read files took '));
    expect(
      line,
      matches(
        RegExp(r'took \d+ ms \(isolate=main, count=3, bytes=120\) at \d+ ms$'),
      ),
    );
  });

  test('a span names the isolate it ran in', () async {
    await marks.span<void>('replay', () async {}, isolate: 'worker');
    expect(lines().single, contains('(isolate=worker)'));
  });

  test('a span passes an error on and still logs the line', () async {
    await expectLater(
      marks.span<void>('boom', () => throw StateError('x')),
      throwsStateError,
    );
    expect(lines().single, startsWith('Startup: boom took '));
  });

  test('a span waits for an async body', () async {
    final result = await marks.span<String>('later', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 'done';
    });
    expect(result, 'done');
    final ms = RegExp(r'took (\d+) ms').firstMatch(lines().single)!.group(1)!;
    expect(int.parse(ms), greaterThanOrEqualTo(15));
  });

  test('record logs a span timed elsewhere', () {
    marks.record('font a.ttf', 7, extra: <String, Object?>{'bytes': 9});
    expect(
      lines().single,
      contains('font a.ttf took 7 ms (isolate=main, bytes=9)'),
    );
  });

  test('the summary names the five slowest spans, slowest first', () {
    for (final (name, ms) in <(String, int)>[
      ('a', 10),
      ('b', 60),
      ('c', 30),
      ('d', 50),
      ('e', 20),
      ('f', 40),
    ]) {
      marks.record(name, ms);
    }
    marks.summary();
    final summary = lines().last;
    expect(summary, startsWith('Startup summary: total '));
    expect(summary, contains('b 60 ms, d 50 ms, f 40 ms, c 30 ms, e 20 ms'));
    expect(summary, isNot(contains('a 10 ms')));
  });

  test('a mark logs the time since the clock started', () {
    marks.mark('runApp');
    expect(lines().single, matches(RegExp(r'^Startup: runApp at \d+ ms$')));
  });

  test('counts are logged as key and value pairs', () {
    marks.count('loaded', <String, Object?>{'decks': 2, 'cards': 5});
    expect(lines().single, contains('loaded: decks=2, cards=5'));
  });
}
