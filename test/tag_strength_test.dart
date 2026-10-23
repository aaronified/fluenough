// Weakest tags are of what is known now (#678): the share of a tag's taught
// pairs that are not known, by the star's rule, then lower recall, then name.

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/tag_strength.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _day0 = DateTime(2026, 9, 1, 9);

DateTime _day(int n) => _day0.add(Duration(days: n));

void _answer(
  MemoryProgress progress,
  String card,
  int day,
  int grade, {
  DrillMode mode = DrillMode.recognition,
}) => progress.record(
  deckId: 'xx-deck',
  cardId: card,
  mode: mode,
  grade: grade,
  now: _day(day),
);

/// Two right answers a day apart: known after the second.
void _known(MemoryProgress progress, String card, {int from = 0}) {
  _answer(progress, card, from, 4);
  _answer(progress, card, from + 1, 4);
}

List<TagStrength> _strengths(
  MemoryProgress progress,
  Map<String, List<String>> tags, {
  required DateTime now,
}) => tagStrengths(
  progress.log,
  tagsOf: (ReviewEvent e) => tags[e.cardId] ?? const <String>[],
  now: now,
);

void main() {
  test('tags are ranked by the share of their taught pairs not known, '
      'weakest first', () {
    final progress = MemoryProgress();
    _known(progress, 'a1');
    _known(progress, 'a2');
    _known(progress, 'b1');
    _answer(progress, 'b2', 1, 4);
    _answer(progress, 'c1', 1, 4);
    final ranked = _strengths(progress, <String, List<String>>{
      'a1': <String>['sea'],
      'a2': <String>['sea'],
      'b1': <String>['sky'],
      'b2': <String>['sky'],
      'c1': <String>['rock'],
    }, now: _day(1));
    expect(ranked.map((s) => s.tag), <String>['rock', 'sky', 'sea']);
    expect(ranked.map((s) => (s.known, s.taught)), <(int, int)>[
      (0, 1),
      (1, 2),
      (2, 2),
    ]);
    expect(ranked.map((s) => s.weakness), <double>[1, 0.5, 0]);
  });

  test('a tag that was weak long ago and is known now is not weak', () {
    final progress = MemoryProgress();
    // Missed three days running, then right five times in a row.
    for (var d = 0; d < 3; d++) {
      _answer(progress, 'old', d, 1);
    }
    for (var d = 3; d < 8; d++) {
      _answer(progress, 'old', d, 4);
    }
    // Always right, but only once: not yet known.
    _answer(progress, 'new', 7, 4);
    final ranked = _strengths(progress, <String, List<String>>{
      'old': <String>['recovered'],
      'new': <String>['fresh'],
    }, now: _day(7));
    expect(ranked.map((s) => s.tag), <String>['fresh', 'recovered']);
    final recovered = ranked.last;
    expect((recovered.known, recovered.taught), (1, 1));
    expect(recovered.weakness, 0);
    final all = progress.log.where((e) => e.cardId == 'old');
    expect(
      all.where((e) => e.passed).length / all.length,
      lessThan(0.7),
      reason: 'by the old measure, the share of right answers, it is weak',
    );
  });

  test('a pair is known by its last review: a miss after a known pair '
      'makes it unknown', () {
    final progress = MemoryProgress();
    _known(progress, 'w');
    _answer(progress, 'w', 2, 1);
    final ranked = _strengths(progress, <String, List<String>>{
      'w': <String>['slip'],
    }, now: _day(2));
    expect((ranked.single.known, ranked.single.taught), (0, 1));
  });

  test('a card counts once per mode and each mode is a pair', () {
    final progress = MemoryProgress();
    _known(progress, 'w');
    _answer(progress, 'w', 0, 4, mode: DrillMode.production);
    final ranked = _strengths(progress, <String, List<String>>{
      'w': <String>['both'],
    }, now: _day(1));
    expect((ranked.single.known, ranked.single.taught), (1, 2));
  });

  test('equal shares are broken by lower recall now, then by name', () {
    final progress = MemoryProgress();
    // Both tags: their one pair is not known. Answered long ago, its recall
    // has fallen further.
    _answer(progress, 'stale', 0, 4);
    _answer(progress, 'fresh', 29, 4);
    // Same card, same recall: only the name tells them apart.
    _answer(progress, 'twin', 29, 4);
    final ranked = _strengths(progress, <String, List<String>>{
      'stale': <String>['stale-tag'],
      'fresh': <String>['fresh-tag'],
      'twin': <String>['zebra', 'apple'],
    }, now: _day(30));
    expect(ranked.map((s) => s.weakness).toSet(), <double>{1});
    expect(ranked.first.tag, 'stale-tag');
    expect(ranked.first.recall, lessThan(ranked[1].recall));
    expect(ranked.skip(1).map((s) => s.tag), <String>[
      'apple',
      'fresh-tag',
      'zebra',
    ]);
  });

  test('a tag with nothing taught is not listed, and a card in two decks '
      'counts once', () {
    final progress = MemoryProgress();
    // Reading passages are not taught pairs.
    _answer(progress, 'p', 0, 4, mode: DrillMode.reading);
    _answer(progress, 'w', 0, 4);
    progress.record(
      deckId: 'yy-deck',
      cardId: 'w',
      mode: DrillMode.recognition,
      grade: 4,
      now: _day(1),
    );
    final ranked = _strengths(progress, <String, List<String>>{
      'p': <String>['passages'],
      'w': <String>['words', 'words'],
    }, now: _day(1));
    expect(ranked.map((s) => s.tag), <String>['words']);
    expect(ranked.single.taught, 1);
    expect(
      tagStrengths(
        const <ReviewEvent>[],
        tagsOf: (_) => <String>['x'],
        now: _day(0),
      ),
      isEmpty,
    );
  });
}
