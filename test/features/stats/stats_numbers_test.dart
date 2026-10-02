import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';

/// A known log on real cards of `es-en-core-100`, whose tags are `people`
/// (0001) and `home` (0006–0009). The clock is Mon 28 Sep 2026, 19:00.
///
/// | day | card, mode, grade |
/// | --- | --- |
/// | −100 | 0009 recognition 4 (outside the grid) |
/// | −40 | 0001 recognition 4 |
/// | −20 | 0001 production 1, 0006 recognition 5 |
/// | −3 | 0006 production 2, 0007 recognition 4 |
/// | −2 | 0007 recognition 4 |
/// | −1 | 0008 recognition 4 |
/// | 0 | 0001 recognition 3 |
MemoryProgress knownLog(DateTime now) {
  final progress = MemoryProgress();
  final today = dateOnly(now);
  void at(int day, String card, DrillMode mode, int grade) => progress.record(
    deckId: 'es-en-core-100',
    cardId: 'es-$card',
    mode: mode,
    grade: grade,
    now: addDays(today, day).add(const Duration(hours: 9)),
  );
  const r = DrillMode.recognition;
  const p = DrillMode.production;
  at(-100, '0009', r, 4);
  at(-40, '0001', r, 4);
  at(-20, '0001', p, 1);
  at(-20, '0006', r, 5);
  at(-3, '0006', p, 2);
  at(-3, '0007', r, 4);
  at(-2, '0007', r, 4);
  at(-1, '0008', r, 4);
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
        deckId: 'es-en-core-100',
        cardId: 'es-0001',
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

  test('a card remembered in two decks is learned once (ADR-0018)', () {
    final progress = MemoryProgress();
    for (final (i, deck) in <String>['es-en-core-100', 'es-en-other'].indexed) {
      progress.record(
        deckId: deck,
        cardId: 'es-0001',
        mode: DrillMode.values[i],
        grade: 5,
        now: addDays(app.now(), -1 - i),
      );
    }
    final n = StatsNumbers.of(
      progress,
      now: app.now(),
      range: StatsRange.week,
      cardOf: cardOf,
    );
    expect(n.reviews, 2);
    expect(n.learned, 1);
  });

  test('a card is looked up as the deck it was answered in lists it', () {
    // ভাড়া is written in the transport deck and listed by the home deck,
    // which gives its own gloss.
    expect(cardOf('bn-0283', deckId: 'bn-en-transport')!.native, 'fare; rent');
    expect(cardOf('bn-0283', deckId: 'bn-en-home')!.native, 'rent');
    expect(cardOf('bn-0283', deckId: 'bn-en-retired')!.id, 'bn-0283');
    expect(cardOf('bn-9999'), isNull);
  });

  test('a leech is shown in the deck it was last answered in', () {
    final progress = MemoryProgress();
    final start = DateTime(2026, 9, 1, 9);
    for (var i = 0; i < 12; i++) {
      progress.record(
        deckId: i < 11 ? 'bn-en-transport' : 'bn-en-home',
        cardId: 'bn-0283',
        mode: DrillMode.recognition,
        grade: i.isEven ? 4 : 1,
        now: start.add(Duration(days: i)),
      );
    }
    // The transport deck lists ভাড়া first on the path, so only the last
    // answer can put the leech in the home deck.
    final leech = findLeeches(progress, cardOf: cardOf).single;
    expect(leech.card.deckId, 'bn-en-home');
    expect(leech.card.native, 'rent');
  });

  group('by language', () {
    late LanguageLookup languageOf;
    setUpAll(() => languageOf = languageLookupOf(app));

    /// A Japanese review on each of [days], counted from today, beside the
    /// Spanish log.
    void addJapanese(MemoryProgress progress, List<int> days) {
      final deck = app.deckById('ja-en-hiragana')!;
      for (final day in days) {
        progress.record(
          deckId: deck.id,
          cardId: deck.cards.first.id,
          mode: DrillMode.recognition,
          grade: 4,
          now: addDays(dateOnly(app.now()), day).add(const Duration(hours: 9)),
        );
      }
    }

    StatsNumbers numbersIn(String? code) => StatsNumbers.of(
      progress,
      now: app.now(),
      range: StatsRange.week,
      cardOf: cardOf,
      deckFilter: code == null ? null : (deck) => languageOf(deck) == code,
    );

    test('one language counts its own reviews, with its own streak', () {
      addJapanese(progress, <int>[-6, -5]);
      final spanish = numbersIn('es');
      expect(spanish.reviews, 5);
      expect(spanish.streak, 4);
      expect(spanish.heatmapReviews, 8);

      final japanese = numbersIn('ja');
      expect(japanese.reviews, 2);
      expect(japanese.remembered, 1.0);
      expect(japanese.streak, 0, reason: 'nothing since five days ago');
      expect(japanese.learned, 1);
      expect(japanese.weakestTags.keys, isNot(contains('home')));
      expect(japanese.heatmapReviews, 2);

      final all = numbersIn(null);
      expect(all.reviews, 7);
      expect(all.streak, 4);
      expect(all.heatmapReviews, 10);
    });

    test('languages are listed most recently reviewed first', () {
      List<String> order() => <String>[
        for (final language in practisedLanguages(
          progress,
          languages: app.languages,
          languageOf: languageOf,
        ))
          language.code,
      ];
      // Recorded after the Spanish log, as an imported backup would be,
      // but older: Spanish was reviewed today.
      addJapanese(progress, <int>[-6]);
      expect(order(), <String>['es', 'ja']);
      progress.record(
        deckId: 'ja-en-hiragana',
        cardId: app.deckById('ja-en-hiragana')!.cards.first.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: app.now(),
      );
      expect(order(), <String>['ja', 'es']);
      expect(
        practisedLanguages(
          MemoryProgress(),
          languages: app.languages,
          languageOf: languageOf,
        ),
        isEmpty,
      );
    });

    test('a deck gone from the catalog is placed by the language its id '
        'names, if the catalog has it', () {
      expect(languageOf('es-en-core-100'), 'es');
      expect(languageOf('es-en-retired'), 'es');
      expect(languageOf('xx-en-retired'), isNull);
      expect(languageOf('nonsense'), isNull);
    });
  });

  test('a leech is a pair at or over the threshold, found in the states', () {
    for (var i = 0; i < kLeechThreshold; i++) {
      progress
        ..record(
          deckId: 'es-en-core-100',
          cardId: 'es-0002',
          mode: DrillMode.production,
          grade: 4,
          now: app.now(),
        )
        ..record(
          deckId: 'es-en-core-100',
          cardId: 'es-0002',
          mode: DrillMode.production,
          grade: 1,
          now: app.now(),
        );
    }
    final leeches = findLeeches(progress, cardOf: cardOf);
    expect(leeches.map((l) => l.card.id), <String>['es-0002']);
    expect(leeches.single.lapses, kLeechThreshold);
    expect(
      findLeeches(progress, cardOf: cardOf, threshold: kLeechThreshold + 1),
      isEmpty,
    );
  });

  test('leech actions are appended; the latest one sets the status', () {
    final actions = LeechActions.of(MemoryProgress());
    const key = (cardId: 'es-0002', mode: DrillMode.production);
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

  test('a reset leech stays listed, so its reset can be undone', () {
    final progress = MemoryProgress();
    const key = (cardId: 'hi-0231', mode: DrillMode.production);
    final start = DateTime(2026, 9, 1, 9);
    // Learned, then forgotten again and again.
    for (var i = 0; i < 12; i++) {
      progress.record(
        deckId: 'hi-en-market',
        cardId: key.cardId,
        mode: key.mode,
        grade: i.isEven ? 4 : 1,
        now: start.add(Duration(days: i)),
      );
    }
    final card = app.decks.first.cards.first;
    Card? cardOf(String cardId, {String? deckId}) =>
        cardId == key.cardId ? card : null;
    expect(findLeeches(progress, cardOf: cardOf), hasLength(1));

    progress.actOnLeech(
      key,
      LeechActionKind.reset,
      now: start.add(const Duration(days: 20)),
    );
    expect(progress.stateOf(key.cardId, key.mode), isNull);
    final listed = findLeeches(progress, cardOf: cardOf);
    expect(listed.single.key, key);
    expect(LeechActions.of(progress).statusOf(key), LeechStatus.reset);
  });
}
