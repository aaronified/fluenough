import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';

/// A known log on real cards of `es-core-100`, whose tags are `people`
/// (0001) and `home` (0010–0013). The clock is Mon 28 Sep 2026, 19:00.
///
/// | day | card, mode, grade |
/// | --- | --- |
/// | −100 | 0013 recognition 4 (outside the grid) |
/// | −40 | 0001 recognition 4 |
/// | −20 | 0001 production 1, 0010 recognition 5 |
/// | −3 | 0010 production 2, 0011 recognition 4 |
/// | −2 | 0011 recognition 4 |
/// | −1 | 0012 recognition 4 |
/// | 0 | 0001 recognition 3 |
MemoryProgress knownLog(DateTime now) {
  final progress = MemoryProgress();
  final today = dateOnly(now);
  void at(int day, String card, DrillMode mode, int grade) => progress.record(
    deckId: 'es-core-100',
    cardId: 'es-core-$card',
    mode: mode,
    grade: grade,
    now: addDays(today, day).add(const Duration(hours: 9)),
  );
  const r = DrillMode.recognition;
  const p = DrillMode.production;
  at(-100, '0013', r, 4);
  at(-40, '0001', r, 4);
  at(-20, '0001', p, 1);
  at(-20, '0010', r, 5);
  at(-3, '0010', p, 2);
  at(-3, '0011', r, 4);
  at(-2, '0011', r, 4);
  at(-1, '0012', r, 4);
  at(0, '0001', r, 3);
  return progress;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState app;
  late CardLookup cardOf;
  late MemoryProgress progress;
  setUpAll(() async {
    app = AppState.test();
    await app.load();
    cardOf = cardLookupOf(app);
  });
  setUp(() => progress = knownLog(app.now()));

  StatsNumbers numbers(StatsRange range) =>
      StatsNumbers.of(progress, now: app.now(), range: range, cardOf: cardOf);

  test('7 days: reviews, remembered, streak, learned, skills, tags', () {
    final n = numbers(StatsRange.week);
    expect(n.reviews, 5);
    expect(n.remembered, 4 / 5);
    expect(n.streak, 4);
    expect(n.learned, 2, reason: '0011 and 0012 were first remembered');
    expect(n.bySkill.keys, <Skill>[Skill.recognition, Skill.production]);
    expect(n.bySkill[Skill.recognition]!.ratio, 1.0);
    expect(n.bySkill[Skill.production]!.ratio, 0.0);
    expect(n.weakestTags.keys, <String>['home', 'people']);
    expect(n.weakestTags['home']!.ratio, 3 / 4);
  });

  test('30 days and all time widen every number', () {
    final month = numbers(StatsRange.month);
    expect(month.reviews, 7);
    expect(month.remembered, 5 / 7);
    expect(month.learned, 3);

    final all = numbers(StatsRange.all);
    expect(all.reviews, 9);
    expect(all.remembered, 7 / 9);
    expect(all.learned, 5);
    expect(all.longestStreak, 4);
    expect(all.bySkill[Skill.production]!.ratio, 0.0);
    expect(all.weakestTags.keys, <String>['people', 'home']);
    expect(all.weakestTags['people']!.ratio, 2 / 3);
  });

  test('the grid covers 84 days ending today, in five steps', () {
    final n = numbers(StatsRange.week);
    expect(n.heatmap, hasLength(kHeatmapDays));
    expect(n.activeDays, 6, reason: 'day −100 is outside the grid');
    expect(n.heatmapReviews, 8);
    expect(n.heatmap.last, 1);
    expect(n.heatmap[kHeatmapDays - 1 - 3], 2);
    expect(n.levelOf(0), 0);
    expect(n.levelOf(1), 2);
    expect(n.levelOf(2), kHeatmapLevels - 1);
  });

  test('a range with no reviews has no remembered share', () {
    final quiet = MemoryProgress()
      ..record(
        deckId: 'es-core-100',
        cardId: 'es-core-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: addDays(app.now(), -20),
      );
    final n = StatsNumbers.of(
      quiet,
      now: app.now(),
      range: StatsRange.week,
      cardOf: cardOf,
    );
    expect(n.reviews, 0);
    expect(n.remembered, isNull);
    expect(n.streak, 0);
    expect(n.bySkill, isEmpty);
  });

  test('a leech is a pair at or over the threshold, found in the states', () {
    for (var i = 0; i < kLeechThreshold; i++) {
      progress
        ..record(
          deckId: 'es-core-100',
          cardId: 'es-core-0002',
          mode: DrillMode.production,
          grade: 4,
          now: app.now(),
        )
        ..record(
          deckId: 'es-core-100',
          cardId: 'es-core-0002',
          mode: DrillMode.production,
          grade: 1,
          now: app.now(),
        );
    }
    final leeches = findLeeches(progress, cardOf: cardOf);
    expect(leeches.map((l) => l.card.id), <String>['es-core-0002']);
    expect(leeches.single.lapses, kLeechThreshold);
    expect(
      findLeeches(progress, cardOf: cardOf, threshold: kLeechThreshold + 1),
      isEmpty,
    );
  });

  test('leech actions are appended; the latest one sets the status', () {
    final actions = LeechActions();
    const key = (
      deckId: 'es-core-100',
      cardId: 'es-core-0002',
      mode: DrillMode.production,
    );
    final now = app.now();
    actions.toggleReset(key, now: now);
    expect(actions.statusOf(key), LeechStatus.reset);
    actions.toggleSetAside(key, now: now);
    expect(actions.statusOf(key), LeechStatus.setAside);
    actions.toggleSetAside(key, now: now);
    expect(actions.statusOf(key), LeechStatus.active);
    actions.toggleReset(key, now: now);
    actions.toggleReset(key, now: now);
    expect(actions.statusOf(key), LeechStatus.active);
    expect(actions.log.map((a) => a.kind), <LeechActionKind>[
      LeechActionKind.reset,
      LeechActionKind.setAside,
      LeechActionKind.bringBack,
      LeechActionKind.reset,
      LeechActionKind.undoReset,
    ]);
  });
}
