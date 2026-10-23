// Progress's mastery view (#678): the known rule, the star's two shapes, the
// level and start date, the 7-day calendar, and the screen they are drawn on.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/core/progress/practice_week.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/level_badge.dart';
import 'package:fluenough/features/stats/over_time_page.dart';
import 'package:fluenough/features/stats/progress_tiles.dart';
import 'package:fluenough/features/stats/practice_week_card.dart';
import 'package:fluenough/features/stats/progress_mastery.dart';
import 'package:fluenough/features/stats/skill_star.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/app/features.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/harness.dart';

final DateTime _start = DateTime(2026, 9, 1, 9);

ReviewEvent _answer(
  MemoryProgress progress,
  String card,
  int grade,
  Duration after, {
  DrillMode mode = DrillMode.recognition,
  Duration elapsed = Duration.zero,
}) => progress.record(
  deckId: 'xx-deck',
  cardId: card,
  mode: mode,
  grade: grade,
  now: _start.add(after),
  elapsed: elapsed,
);

Mastery _mastery(MemoryProgress progress, {DateTime? asOf, int total = 10}) =>
    masteryAt(
      progress.log,
      progress.scriptLog,
      totals: <MasterySkill, int>{MasterySkill.read: total},
      scriptCards: const <String>{},
      asOf: asOf,
    );

void main() {
  group('known', () {
    test('a right answer at 85% recall or better makes a card known; the '
        'first answer, an answer after it faded, and a miss do not', () {
      final progress = MemoryProgress();
      _answer(progress, 'a', 4, Duration.zero);
      var star = _mastery(progress)[MasterySkill.read];
      expect(star.taught, 1);
      expect(star.known, 0, reason: 'the first answer has no recall to meet');

      _answer(progress, 'a', 4, const Duration(days: 1));
      star = _mastery(progress)[MasterySkill.read];
      expect(star.known, 1);
      expect(star.fill, 0.1, reason: 'known over the B1 total of 10');
      expect(star.outline, 1.0, reason: 'known over taught');

      _answer(progress, 'a', 4, const Duration(days: 400));
      expect(_mastery(progress)[MasterySkill.read].known, 0);

      _answer(progress, 'b', 4, Duration.zero);
      _answer(progress, 'b', 1, const Duration(days: 1));
      expect(
        _mastery(progress)[MasterySkill.read].known,
        0,
        reason: 'b was missed, a was recalled late',
      );
    });

    test('the outline is never inside the fill, and sits at the centre '
        'where nothing is taught', () {
      final progress = MemoryProgress();
      for (final card in <String>['a', 'b', 'c']) {
        _answer(progress, card, 4, Duration.zero);
      }
      _answer(progress, 'a', 4, const Duration(days: 1));
      final mastery = _mastery(progress, total: 3);
      for (final skill in MasterySkill.values) {
        final star = mastery[skill];
        expect(star.outline ?? 0, greaterThanOrEqualTo(star.fill));
      }
      expect(mastery[MasterySkill.say].outline, isNull);
      expect(mastery[MasterySkill.say].fill, 0);
    });

    test('a card is known by the tuned parameters of its skill, the ones that '
        'schedule it', () {
      final progress = MemoryProgress();
      _answer(progress, 'a', 4, Duration.zero);
      _answer(progress, 'a', 4, const Duration(days: 5));
      // A first Good lasts about 2.3 days: after 5, FSRS-6's defaults give
      // about 84% recall, under the line. A fit that forgets more slowly
      // after the due date gives about 89%.
      final slow = <double>[...Fsrs.w]..[20] = 0.01;
      expect(_mastery(progress)[MasterySkill.read].known, 0);
      final tuned = masteryAt(
        progress.log,
        progress.scriptLog,
        totals: const <MasterySkill, int>{MasterySkill.read: 10},
        scriptCards: const <String>{},
        parametersOf: (_) => slow,
      );
      expect(tuned[MasterySkill.read].known, 1);
      expect(
        wordCounts(progress.log, parametersOf: (_) => slow).mastered,
        1,
        reason: 'the words use the same parameters',
      );
      expect(wordCounts(progress.log).mastered, 0);
    });

    test('a skill total is never under what is taught, and All sums the '
        'languages', () {
      final one = MemoryProgress();
      for (final card in <String>['a', 'b', 'c']) {
        _answer(one, card, 4, Duration.zero);
        _answer(one, card, 4, const Duration(days: 1));
      }
      final two = MemoryProgress();
      _answer(two, 'x', 4, Duration.zero);
      _answer(two, 'x', 4, const Duration(days: 1));
      Mastery of(MemoryProgress p, int total) => masteryAt(
        p.log,
        p.scriptLog,
        totals: <MasterySkill, int>{
          MasterySkill.read: total,
          MasterySkill.grammar: 4,
        },
        scriptCards: const <String>{},
      );
      final small = of(one, 2);
      expect(small[MasterySkill.read].total, 3, reason: 'taught is 3 of 2');
      expect(small[MasterySkill.read].fill, 1.0);
      expect(small[MasterySkill.grammar].total, 4);
      expect(small[MasterySkill.grammar].fill, 0);
      expect(small[MasterySkill.grammar].outline, isNull);

      final all = sumMastery(<Mastery>[small, of(two, 10)]);
      expect(all[MasterySkill.read].known, 4);
      expect(all[MasterySkill.read].taught, 4);
      expect(all[MasterySkill.read].total, 13);
      expect(all[MasterySkill.grammar].total, 8);
      expect(all[MasterySkill.read].fill, closeTo(4 / 13, 1e-9));
    });

    test('a word is mastered when every skill it was taught in is known', () {
      final progress = MemoryProgress();
      for (final card in <String>['a', 'b']) {
        _answer(progress, card, 4, Duration.zero);
        _answer(progress, card, 4, const Duration(days: 1));
      }
      _answer(progress, 'b', 4, Duration.zero, mode: DrillMode.production);
      expect(wordCounts(progress.log), (mastered: 1, taught: 2));
    });
  });

  group('level and start date', () {
    CoursePath path() => CoursePath(
      id: 'xx-path',
      language: 'xx',
      native: 'en',
      units: const <List<String>>[
        <String>['xx-en-a'],
        <String>['xx-en-b'],
        <String>['xx-en-c'],
      ],
      plan: const <PlanUnit>[
        PlanUnit(decks: <String>['xx-en-a'], milestone: Milestone.a1),
        PlanUnit(decks: <String>['xx-en-b'], milestone: Milestone.a2),
        PlanUnit(decks: <String>['xx-en-c'], milestone: Milestone.b1),
      ],
    );

    test('the level is the last milestone whose units are all finished', () {
      expect(levelReached(path(), (_) => false), isNull);
      expect(levelReached(path(), (id) => id == 'xx-en-a'), Milestone.a1);
      expect(levelReached(path(), (id) => id != 'xx-en-c'), Milestone.a2);
      expect(
        levelReached(path(), (id) => id == 'xx-en-b' || id == 'xx-en-c'),
        isNull,
        reason: 'A2 needs A1 behind it',
      );
      expect(levelReached(path(), (_) => true), Milestone.b1);
    });

    test('the course started on the day of its first answer', () {
      final progress = MemoryProgress();
      _answer(progress, 'a', 4, const Duration(days: 3));
      _answer(progress, 'a', 4, Duration.zero);
      expect(startedOn(progress.log), DateTime(2026, 9, 1));
      expect(startedOn(const <ReviewEvent>[]), isNull);
    });
  });

  group('the 7-day calendar', () {
    test('a day is a flame at the quota, two at twice it, a dot for some '
        'practice and empty for none; a line joins practised days', () {
      final progress = MemoryProgress();
      const min = Duration(minutes: 1);
      // Day 0 .. 6 = 1 Sep .. 7 Sep.
      void day(int d, int minutes) => _answer(
        progress,
        'c$d',
        4,
        Duration(days: d),
        elapsed: min * minutes,
      );
      // Sixty-second cap per answer: ask in 15 answers of 60 s.
      void minutes(int d, int n) {
        for (var i = 0; i < n; i++) {
          _answer(
            progress,
            'c$d-$i',
            4,
            Duration(days: d, minutes: i),
            elapsed: min,
          );
        }
      }

      day(0, 0);
      minutes(1, 15);
      minutes(2, 30);
      day(3, 0);
      // Days 4 and 5 are empty; day 6 has one short answer.
      day(6, 0);
      progress.record(
        deckId: 'xx-deck',
        cardId: 'last',
        mode: DrillMode.recognition,
        grade: 4,
        now: _start.add(const Duration(days: 6, hours: 1)),
      );
      final week = practiceWeek(
        progress.log,
        now: _start.add(const Duration(days: 6, hours: 2)),
      );
      expect(week.map((d) => d.mark), <DayMark>[
        DayMark.some,
        DayMark.met,
        DayMark.twice,
        DayMark.some,
        DayMark.none,
        DayMark.none,
        DayMark.some,
      ]);
      expect(week.map((d) => d.joinsNext), <bool>[
        true,
        true,
        true,
        false,
        false,
        false,
        false,
      ]);
    });
  });

  group('days keep the zone of the answer', () {
    ReviewEvent at(DateTime when, String card) => MemoryProgress().record(
      deckId: 'xx-deck',
      cardId: card,
      mode: DrillMode.recognition,
      grade: 4,
      now: when,
    );

    test('a late-evening UTC answer stays on its own day, however the '
        'device is set', () {
      final late = at(DateTime.utc(2026, 9, 3, 23, 30), 'a');
      expect(startedOn(<ReviewEvent>[late]), DateTime.utc(2026, 9, 3));
      final week = practiceWeek(<ReviewEvent>[
        late,
      ], now: DateTime.utc(2026, 9, 7, 12));
      expect(week.first.day, DateTime.utc(2026, 9, 1));
      expect(week.map((d) => d.mark), <DayMark>[
        DayMark.none,
        DayMark.none,
        DayMark.some,
        DayMark.none,
        DayMark.none,
        DayMark.none,
        DayMark.none,
      ]);
    });

    test('a local late-evening answer stays on its own day too', () {
      final late = at(DateTime(2026, 9, 3, 23, 45), 'a');
      expect(startedOn(<ReviewEvent>[late]), DateTime(2026, 9, 3));
      final week = practiceWeek(<ReviewEvent>[
        late,
      ], now: DateTime(2026, 9, 7, 8));
      expect(week[2].mark, DayMark.some);
      expect(week[3].mark, DayMark.none);
    });

    test('the second before midnight and the midnight after are two days, '
        'joined', () {
      final week = practiceWeek(<ReviewEvent>[
        at(DateTime.utc(2026, 9, 3, 23, 59, 59), 'a'),
        at(DateTime.utc(2026, 9, 4), 'b'),
      ], now: DateTime.utc(2026, 9, 7, 12));
      expect(week[2].mark, DayMark.some);
      expect(week[3].mark, DayMark.some);
      expect(week[4].mark, DayMark.none);
      expect(week[2].joinsNext, isTrue);
      expect(week[3].joinsNext, isFalse);
    });

    test('UTC answers are placed on the week of a local clock by their own '
        'date', () {
      final week = practiceWeek(<ReviewEvent>[
        at(DateTime.utc(2026, 9, 3, 23, 30), 'a'),
      ], now: DateTime(2026, 9, 7, 12));
      expect(week[2].mark, DayMark.some);
    });
  });

  group('the level badge', () {
    test('every metal passes contrast with its text at every stop', () {
      double lum(Color c) => c.computeLuminance();
      for (final badge in <LevelBadge>[
        LevelBadge.bronze,
        LevelBadge.silver,
        LevelBadge.gold,
      ]) {
        for (final stop in badge.stops) {
          final hi = lum(stop) > lum(LevelBadge.text) ? stop : LevelBadge.text;
          final lo = hi == stop ? LevelBadge.text : stop;
          expect(
            (lum(hi) + 0.05) / (lum(lo) + 0.05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    });

    testWidgets('the tile is bronze, silver or gold by level, says the level '
        'in text and to screen readers, and is plain before A1', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final started = DateTime(2026, 8, 3);
      Future<void> show(Milestone? level, {bool all = false}) => pumpScreen(
        tester,
        Scaffold(
          body: Row(
            children: <Widget>[
              Expanded(
                child: LevelTile(
                  level: level,
                  started: started,
                  allLanguages: all,
                ),
              ),
            ],
          ),
        ),
      );
      Gradient? gradient() => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(LevelTile),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .first
          .gradient;

      for (final (level, text, badge) in <(Milestone, String, LevelBadge)>[
        (Milestone.a1, 'A1', LevelBadge.bronze),
        (Milestone.a2, 'A2', LevelBadge.silver),
        (Milestone.b1, 'B1', LevelBadge.gold),
      ]) {
        await show(level);
        expect(find.text(text), findsOneWidget);
        expect(gradient(), badge.gradient);
        expect(
          find.bySemanticsLabel(RegExp('Level $text, started')),
          findsOneWidget,
        );
      }

      await show(null);
      expect(gradient(), isNull);
      expect(find.bySemanticsLabel(RegExp('No level reached')), findsOneWidget);

      // On All languages: the start date alone, plain.
      await show(Milestone.b1, all: true);
      expect(gradient(), isNull);
      expect(find.text('B1'), findsNothing);
      expect(find.text('Level'), findsNothing);
      expect(find.text('Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the Progress tab', () {
    testWidgets('shows words, level, the week and the star; the star opens '
        'the two charts over time; All languages shows the start date '
        'only', (tester) async {
      usePhone(tester, textScale: 1.4);
      final app = AppState.test();
      await app.load();
      final state = GalleryFixtures.state(app, features: FeatureRegistry.all());
      await pumpScreen(tester, const StatsPage(), state: state);
      await tester.tap(
        find.descendant(
          of: find.byType(LanguageBar),
          matching: find.text(l10nOf(tester).languageBarAll),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text(l10n.progressStartedTitle), findsOneWidget);
      expect(find.text(l10n.progressLevelTitle), findsNothing);
      state.showLanguage('es', allOff: true);
      await tester.pumpAndSettle();
      expect(find.text(l10n.progressLevelTitle), findsOneWidget);
      expect(find.byType(WordsTile), findsOneWidget);
      expect(find.byType(LevelTile), findsOneWidget);
      expect(find.byType(PracticeWeekCard), findsOneWidget);
      expect(find.byType(SkillStarCard), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');

      await tester.tap(find.byType(SkillStarCard));
      await tester.pumpAndSettle();
      expect(find.byType(OverTimePage), findsOneWidget);
      expect(find.text(l10n.progressMasteryChart), findsOneWidget);
      expect(find.text(l10n.progressTaughtChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Progress for a course', () {
    Future<AppState> fixture() async {
      final app = AppState.test();
      await app.load();
      final state = GalleryFixtures.state(app, features: FeatureRegistry.all());
      await state.load();
      return state;
    }

    DeckEntry spanish(AppState state) =>
        state.decks.firstWhere((e) => e.id == 'es-en-core-100');

    testWidgets('is worked out once per change of the progress, and again '
        'after one', (tester) async {
      final state = await fixture();
      final first = ProgressMastery.of(state, 'es');
      expect(
        identical(ProgressMastery.of(state, 'es'), first),
        isTrue,
        reason: 'nothing changed: the weekly snapshots are not rebuilt',
      );
      final all = ProgressMastery.of(state, null);
      expect(identical(ProgressMastery.of(state, null), all), isTrue);

      final fresh = spanish(state).cards.last;
      state.progress.record(
        deckId: 'es-en-core-100',
        cardId: fresh.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: state.now(),
      );
      final next = ProgressMastery.of(state, 'es');
      expect(identical(next, first), isFalse);
      expect(
        next.now[MasterySkill.read].taught,
        first.now[MasterySkill.read].taught + 1,
      );
    });

    testWidgets('over time ends at now, and never taught less before it', (
      tester,
    ) async {
      final state = await fixture();
      final mastery = ProgressMastery.of(state, 'es');
      final series = mastery.overTime();
      expect(series, hasLength(12));
      for (final skill in MasterySkill.values) {
        expect(series.last[skill].known, mastery.now[skill].known);
        expect(series.last[skill].taught, mastery.now[skill].taught);
        for (var i = 1; i < series.length; i++) {
          expect(
            series[i][skill].taught,
            greaterThanOrEqualTo(series[i - 1][skill].taught),
          );
        }
      }
      expect(
        series.first[MasterySkill.read].taught,
        lessThan(series.last[MasterySkill.read].taught),
        reason: 'the history is twelve days, the series twelve weeks',
      );
    });

    testWidgets('the totals are the B1 plan: words at least the planned '
        'count, grammar and script from the course decks', (tester) async {
      final state = await fixture();
      final entry = spanish(state);
      final path = state.pathOf(entry)!;
      final inCourse = <DeckEntry>[
        for (final id in path.deckIds)
          if (state.deckById(id) case final e?) e,
      ];
      var words = 0;
      var grammar = 0;
      var script = 0;
      for (final e in inCourse) {
        for (final card in e.cards) {
          if (path.alphabet.contains(e.id)) {
            script++;
          } else if (card.isGrammarCell) {
            grammar++;
          } else {
            words++;
          }
        }
      }
      final now = ProgressMastery.of(state, 'es').now;
      final expected = path.plannedWords < words ? words : path.plannedWords;
      for (final skill in <MasterySkill>[
        MasterySkill.read,
        MasterySkill.write,
        MasterySkill.hear,
        MasterySkill.say,
      ]) {
        expect(now[skill].total, expected, reason: skill.name);
      }
      expect(now[MasterySkill.grammar].total, grammar);
      expect(now[MasterySkill.script].total, script * 2);
    });

    testWidgets('on All, the words and the star count the same languages: a '
        'review in a language that cannot be told counts in neither', (
      tester,
    ) async {
      final state = await fixture();
      final before = ProgressMastery.of(state, null);
      for (final days in <int>[2, 1]) {
        state.progress.record(
          deckId: 'zz-unknown',
          cardId: 'zz-card',
          mode: DrillMode.recognition,
          grade: 4,
          now: state.now().subtract(Duration(days: days)),
        );
      }
      final after = ProgressMastery.of(state, null);
      expect(after.words, before.words);
      expect(
        after.now[MasterySkill.read].taught,
        before.now[MasterySkill.read].taught,
      );
      expect(after.started, before.started);
    });
  });

  group('Progress on screen', () {
    testWidgets('the tiles do not shrink their text out of reach at 1.4x', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        Scaffold(
          body: ProgressTiles(
            words: (mastered: 312, taught: 540),
            level: Milestone.a2,
            started: DateTime(2026, 8, 3),
            allLanguages: false,
          ),
        ),
      );
      // A FittedBox hides overflow by shrinking, so measure the shrinking:
      // each line keeps at least 60% of its 1.4x size.
      final fitted = find.descendant(
        of: find.byType(ProgressTiles),
        matching: find.byType(FittedBox),
      );
      expect(fitted, findsNWidgets(3));
      for (final box in fitted.evaluate()) {
        final render = box.renderObject! as RenderFittedBox;
        final child = render.child!.size;
        final scale = child.width <= render.size.width
            ? 1.0
            : render.size.width / child.width;
        expect(scale, greaterThanOrEqualTo(0.6));
        expect(child.height, lessThan(70), reason: 'one line, never wrapped');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('each day is a labelled image saying its state and minutes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      usePhone(tester, textScale: 1.4);
      const marks = <DayMark>[
        DayMark.none,
        DayMark.some,
        DayMark.met,
        DayMark.twice,
        DayMark.none,
        DayMark.some,
        DayMark.met,
      ];
      final week = <PracticeDay>[
        for (final (i, mark) in marks.indexed)
          PracticeDay(
            day: DateTime(2026, 9, 1 + i),
            spent: Duration(minutes: const <int>[0, 4, 15, 31, 0, 6, 16][i]),
            mark: mark,
            joinsNext: false,
          ),
      ];
      await pumpScreen(
        tester,
        Scaffold(
          body: PracticeWeekCard(week: week, quota: kDefaultDailyQuota),
        ),
      );
      final l10n = l10nOf(tester);
      String state(DayMark m) => switch (m) {
        DayMark.none => l10n.progressDayNone,
        DayMark.some => l10n.progressDaySome,
        DayMark.met => l10n.progressDayMet,
        DayMark.twice => l10n.progressDayTwice,
      };
      for (final (i, day) in week.indexed) {
        final name = DateFormat.EEEE('en').format(day.day);
        final label = i == week.length - 1
            ? l10n.progressDayLabelToday(
                name,
                state(day.mark),
                day.spent.inMinutes,
                15,
              )
            : l10n.progressDayLabel(
                name,
                state(day.mark),
                day.spent.inMinutes,
                15,
              );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(label))),
          findsOneWidget,
          reason: label,
        );
      }
    });

    testWidgets('the weakest tags and the leeches are shown, for the '
        'language chosen', (tester) async {
      usePhone(tester, textScale: 1.4);
      final app = AppState.test();
      await app.load();
      final state = GalleryFixtures.state(app, features: FeatureRegistry.all());
      await pumpScreen(tester, const StatsPage(), state: state);
      state.showLanguage('es', allOff: true);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      final cardOf = cardLookupOf(state);
      final numbers = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardOf,
        deckFilter: (id) => id.startsWith('es-'),
      );
      expect(numbers.weakestTags, isNotEmpty);
      final leeches = findLeeches(
        state.progress,
        cardOf: cardOf,
      ).where((l) => l.card.deckId.startsWith('es-')).length;
      expect(leeches, greaterThan(0));

      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(l10n.statsWeakestTags),
        200,
        scrollable: list,
      );
      for (final tag in numbers.weakestTags.keys) {
        expect(find.text(tag), findsWidgets, reason: tag);
      }
      await tester.scrollUntilVisible(
        find.text(l10n.statsLeeches(leeches)),
        200,
        scrollable: list,
      );
      expect(find.text(l10n.statsLeeches(leeches)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the star', () {
    Mastery full(int value) => Mastery(<MasterySkill, SkillScore>{
      for (final skill in MasterySkill.values)
        skill: SkillScore(known: value, taught: value, total: value),
    });

    Future<void> pumpStar(
      WidgetTester tester, {
      required Mastery mastery,
      double width = 360,
      double textScale = 1.4,
      TextDirection direction = TextDirection.ltr,
      bool reducedMotion = false,
    }) async {
      usePhone(tester, textScale: textScale);
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: SkillStarCard(mastery: mastery, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void expectLabelsInside(WidgetTester tester) {
      final box = tester.getRect(find.byKey(const ValueKey<String>('star')));
      for (var i = 0; i < 6; i++) {
        final finder = find.byKey(ValueKey<String>('star-label-$i'));
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(box.left - 0.01), reason: '$i');
        expect(rect.right, lessThanOrEqualTo(box.right + 0.01), reason: '$i');
        expect(rect.top, greaterThanOrEqualTo(box.top - 0.01), reason: '$i');
        expect(rect.bottom, lessThanOrEqualTo(box.bottom + 0.01), reason: '$i');
        // Text that does not fit its box is clamped to it: its natural
        // height at that width is what shows it.
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          paragraph.getMaxIntrinsicHeight(rect.width),
          lessThanOrEqualTo(rect.height + 0.5),
          reason: 'label $i is not cut short',
        );
      }
    }

    for (final direction in TextDirection.values) {
      testWidgets('every label stays inside the star at 1.4x on a 360 px '
          'phone with 100% and 100% ($direction)', (tester) async {
        await pumpStar(tester, mastery: full(100), direction: direction);
        expectLabelsInside(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the star mirrors in right-to-left text', (tester) async {
      await pumpStar(tester, mastery: full(10));
      final centre = tester
          .getCenter(find.byKey(const ValueKey<String>('star')))
          .dx;
      expect(
        tester.getCenter(find.byKey(const ValueKey<String>('star-label-1'))).dx,
        greaterThan(centre),
      );
      await pumpStar(tester, mastery: full(10), direction: TextDirection.rtl);
      final mirrored = tester
          .getCenter(find.byKey(const ValueKey<String>('star')))
          .dx;
      expect(
        tester.getCenter(find.byKey(const ValueKey<String>('star-label-1'))).dx,
        lessThan(mirrored),
      );
    });

    testWidgets('it grows over 400 ms, once, and not at all under reduced '
        'motion', (tester) async {
      final mastery = full(10);
      await pumpStar(tester, mastery: mastery);
      final grow = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(grow.duration, kStarGrowTime);
      expect(kStarGrowTime, const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'still growing at 200 ms',
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.binding.transientCallbackCount, 0, reason: 'done by 450');

      await pumpStar(tester, mastery: mastery, reducedMotion: true);
      final still = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(still.duration, Duration.zero);
      expect(still.tween.begin, 1.0, reason: 'drawn full-grown at once');
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('nothing is written under the star', (tester) async {
      await pumpStar(tester, mastery: full(10));
      final star = tester.getRect(find.byKey(const ValueKey<String>('star')));
      final texts = find.descendant(
        of: find.byType(SkillStarCard),
        matching: find.byType(Text),
      );
      for (final text in texts.evaluate()) {
        final rect = tester.getRect(find.byWidget(text.widget));
        expect(rect.top, lessThan(star.bottom - 1));
      }
      expect(
        tester.getRect(find.byType(SkillStarCard)).bottom - star.bottom,
        lessThanOrEqualTo(20),
        reason: 'the card ends where the star does, bar its padding',
      );
    });
  });
}
