import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _day0 = DateTime(2025, 1, 1, 12);

MemoryProgress _progress() => MemoryProgress();

void _answer(MemoryProgress p, String card, int grade, int minutes) =>
    p.record(
      deckId: '${card.split('-').first}-en-core',
      cardId: card,
      mode: DrillMode.recognition,
      grade: grade,
      now: _day0.add(Duration(minutes: minutes)),
    );

void main() {
  test('the index counts leeches as a replay of the log would', () {
    final p = _progress();
    var t = 0;
    // te-1: right, then six misses (5 lapses is the leech line, the first
    // miss after a right answer is lapse one); te-2: all misses (no lapse);
    // hi-1: right, four misses (4 lapses).
    for (final g in <int>[4, 0, 4, 0, 4, 0, 4, 0, 4, 0, 4, 0]) {
      _answer(p, 'te-1', g, t++);
    }
    for (var i = 0; i < 6; i++) {
      _answer(p, 'te-2', 0, t++);
    }
    for (final g in <int>[4, 0, 4, 0, 4, 0, 4, 0]) {
      _answer(p, 'hi-1', g, t++);
    }
    final replayed = replayReviews(p.log.map(logged)).states;
    final expected = <ProgressKey>{
      for (final e in replayed.entries)
        if (e.value.lapses >= 5) e.key,
    };
    final found = <ProgressKey>{
      for (final l in p.index.leeches()) l.key,
    };
    expect(found, expected);
    expect(found, <ProgressKey>{(cardId: 'te-1', mode: DrillMode.recognition)});
    expect(p.index.leechCount('te'), 1);
    expect(p.index.leechCount('hi'), 0);
    expect(p.index.lapsesOf((cardId: 'hi-1', mode: DrillMode.recognition)), 4);
  });

  test('recording an answer does not replay and leaves other languages alone', () {
    final p = _progress();
    // 40 languages, a few answers each.
    final codes = <String>[for (var i = 0; i < 40; i++) 'l$i'];
    var t = 0;
    for (final code in codes) {
      for (var c = 0; c < 5; c++) {
        _answer(p, '$code-$c', 4, t++);
      }
    }
    final replaysBefore = MemoryProgress.replays;
    final others = <String, int>{for (final c in codes) c: p.versionOf(c)};
    final hindiDays = p.index.perDay('l1');
    final global = p.version;

    _answer(p, 'l0-0', 0, t++);

    expect(MemoryProgress.replays, replaysBefore);
    expect(p.index.length, 201);
    expect(p.versionOf('l0'), greaterThan(others['l0']!));
    for (final code in codes.skip(1)) {
      expect(p.versionOf(code), others[code], reason: code);
    }
    expect(identical(p.index.perDay('l1'), hindiDays), isTrue);
    expect(p.version, greaterThan(global));
  });

  test('a change to every language moves every language version', () {
    final p = _progress();
    _answer(p, 'te-1', 4, 0);
    final before = p.versionOf('hi');
    p.actOnLeech(
      (cardId: 'te-1', mode: DrillMode.recognition),
      LeechActionKind.reset,
      now: _day0,
    );
    expect(p.versionOf('hi'), greaterThan(before));
  });

  test('the index holds 300k reviews over 40 languages and adds in O(1)', () {
    final state = Fsrs.next(null, 4, now: _day0);
    ReviewEvent at(int i) {
      final language = 'l${i % 40}';
      return ReviewEvent(
        at: _day0.add(Duration(minutes: i * 3)),
        deckId: '$language-en-core',
        cardId: '$language-${i % 5000}',
        mode: DrillMode.recognition,
        grade: i % 7 == 0 ? 0 : 4,
        elapsed: Duration.zero,
        before: null,
        after: state,
      );
    }

    final index = ProgressIndex()
      ..rebuild(<ReviewEvent>[for (var i = 0; i < 300000; i++) at(i)]);
    expect(index.length, 300000);
    expect(index.languages.length, 40);
    expect(index.reviewsIn('l7'), 7500);
    final days = index.perDay('l3').values.reduce((a, b) => a + b);
    expect(days, 7500);

    final other = index.perDay('l9');
    final total = index.reviewsIn('l9');
    index.add(at(300000));
    expect(index.length, 300001);
    expect(index.reviewsIn('l9'), total);
    expect(identical(index.perDay('l9'), other), isTrue);
  });
}
