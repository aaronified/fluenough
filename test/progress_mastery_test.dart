// Progress's mastery view (#678): the known rule, the star's two shapes, the
// level and start date, the 7-day calendar, and the screen they are drawn on.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/core/progress/practice_week.dart';
import 'package:fluenough/features/stats/level_badge.dart';
import 'package:fluenough/features/stats/over_time_page.dart';
import 'package:fluenough/features/stats/progress_tiles.dart';
import 'package:fluenough/features/stats/practice_week_card.dart';
import 'package:fluenough/features/stats/skill_star.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/app/features.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('over time, each week counts only what had happened by then', () {
      final progress = MemoryProgress();
      _answer(progress, 'a', 4, Duration.zero);
      _answer(progress, 'a', 4, const Duration(days: 1));
      final weeks = masteryOverTime(
        progress.log,
        progress.scriptLog,
        totals: const <MasterySkill, int>{MasterySkill.read: 10},
        scriptCards: const <String>{},
        now: _start.add(const Duration(days: 28)),
        weeks: 5,
      );
      expect(weeks.map((m) => m[MasterySkill.read].taught), <int>[
        1,
        1,
        1,
        1,
        1,
      ]);
      expect(weeks.map((m) => m[MasterySkill.read].known), <int>[
        0,
        1,
        1,
        1,
        1,
      ]);
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
}
