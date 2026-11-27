// What a finished session announces (#323, decision 4 of the achievements
// mockup), how a chain of badges is shown, and the cards a badge's sheet
// lists: all rules over the engine's reports, no widgets.

import 'package:fluenough/core/achievements/achievement.dart';
import 'package:fluenough/core/achievements/achievement_evaluator.dart';
import 'package:fluenough/core/achievements/achievement_news.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/achievements/badge_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/achievement_fixture.dart';
import 'support/achievement_screens_fixture.dart';

void main() {
  group('the news of a session', () {
    final report = learnedToA1();
    final earnedIds = <String>{for (final r in report.earned) r.def.id};
    final courseIds = <String>{
      for (final r in report.earned)
        if (!r.def.isAppWide) r.def.id,
    };
    final appIds = earnedIds.difference(courseIds);
    // After every date in the fixture's log.
    final later = DateTime.utc(2027);
    final before = DateTime.utc(2026);

    test('the fixture earns course and app-wide badges', () {
      expect(courseIds, contains('level-a1'));
      expect(courseIds, contains('other-first-lesson'));
      expect(appIds, contains('other-streak-3'));
      expect(appIds, contains('other-streak-30'));
    });

    test('a first look finds the earned badges as past reviews', () {
      final news = AchievementNews.of(
        report,
        seenCourse: null,
        seenApp: null,
        since: later,
      );
      expect(news.fresh, isEmpty);
      expect({for (final r in news.past) r.def.id}, earnedIds);
      expect(news.isEmpty, isFalse);
      expect(news.courseIds, courseIds);
      expect(news.appIds, appIds);
    });

    test('past badges come earliest first', () {
      final news = AchievementNews.of(
        report,
        seenCourse: null,
        seenApp: null,
        since: later,
      );
      final dates = <DateTime>[for (final r in news.past) r.earnedAt!];
      expect([...dates]..sort(), dates);
    });

    test('a badge earned since the session began is fresh, even at the '
        'first look', () {
      final news = AchievementNews.of(
        report,
        seenCourse: null,
        seenApp: null,
        since: before,
      );
      expect(news.past, isEmpty);
      expect({for (final r in news.fresh) r.def.id}, earnedIds);
    });

    test('once a scope was looked at, every badge not seen is fresh', () {
      final news = AchievementNews.of(
        report,
        seenCourse: <String>{'level-a1'},
        seenApp: const <String>{},
        since: later,
      );
      expect(news.past, isEmpty);
      final fresh = <String>{for (final r in news.fresh) r.def.id};
      expect(fresh, isNot(contains('level-a1')));
      expect(fresh, contains('other-first-lesson'));
      expect(fresh, containsAll(appIds));
    });

    test('the two scopes are looked at separately', () {
      // The course was looked at, the app-wide badges never were.
      final news = AchievementNews.of(
        report,
        seenCourse: courseIds,
        seenApp: null,
        since: later,
      );
      expect(news.fresh, isEmpty);
      expect({for (final r in news.past) r.def.id}, appIds);
    });

    test('nothing is announced when everything has been seen', () {
      final news = AchievementNews.of(
        report,
        seenCourse: courseIds,
        seenApp: appIds,
        since: before,
      );
      expect(news.isEmpty, isTrue);
      expect(news.shown, isEmpty);
      expect(news.more, 0);
    });

    test('two cards are shown in full and the rest are counted', () {
      final news = AchievementNews.of(
        report,
        seenCourse: const <String>{},
        seenApp: const <String>{},
        since: before,
      );
      expect(news.fresh.length, earnedIds.length);
      expect(news.shown, hasLength(kAnnouncedCards));
      expect(news.shown, news.fresh.take(kAnnouncedCards).toList());
      expect(news.more, earnedIds.length - kAnnouncedCards);
    });

    test('a report with no badge earned has no news', () {
      final news = AchievementNews.of(
        untouched(),
        seenCourse: null,
        seenApp: null,
        since: before,
      );
      expect(news.isEmpty, isTrue);
      expect(news.courseIds, isEmpty);
      expect(news.appIds, isEmpty);
    });
  });

  group('a chain of badges', () {
    final facts = courseFacts();
    final report = learnedToA1(facts: facts);

    BadgeShown shownOf(List<BadgeView> views, String id) =>
        views.firstWhere((v) => v.def.id == id).shown;

    test('only the next badge shows progress and the rest are locked', () {
      final levels = chainViews(report.ofKind(AchievementKind.level));
      expect(levels.map((v) => v.def.id), <String>[
        'level-a1',
        'level-a2',
        'level-b1',
      ]);
      expect(shownOf(levels, 'level-a1'), BadgeShown.earned);
      expect(shownOf(levels, 'level-a2'), BadgeShown.progress);
      expect(shownOf(levels, 'level-b1'), BadgeShown.locked);
    });

    test('the words are a chain too', () {
      final words = chainViews(report.ofKind(AchievementKind.wordCount));
      expect(shownOf(words, 'words-100'), BadgeShown.progress);
      expect(shownOf(words, 'words-500'), BadgeShown.locked);
      expect(shownOf(words, 'words-1000'), BadgeShown.locked);
      expect(shownOf(words, 'words-2500'), BadgeShown.locked);
    });

    test('a chain with nothing started shows its first badge locked', () {
      final levels = chainViews(untouched().ofKind(AchievementKind.level));
      expect(levels.map((v) => v.shown), everyElement(BadgeShown.locked));
    });

    test('a skill marked Leave is dimmed and not part of the plan', () {
      final left = evaluateAchievements(
        log: const [],
        facts: courseFacts(
          leave: <SkillKey>{const SkillKey(SkillKind.write, 'devanagari')},
        ),
      );
      final views = chainViews(<AchievementResult>[
        for (final r in left.results)
          if (r.def.skill == const SkillKey(SkillKind.write, 'devanagari')) r,
      ]);
      expect(views, hasLength(2));
      expect(views.map((v) => v.shown), everyElement(BadgeShown.left));
    });

    test('an earned badge stays earned after a locked one', () {
      final chain = chainViews(<AchievementResult>[
        locked(AchievementDef.words(100)),
        earned(AchievementDef.words(500), screensStart),
      ]);
      expect(chain.map((v) => v.shown), <BadgeShown>[
        BadgeShown.locked,
        BadgeShown.earned,
      ]);
    });
  });

  group('the cards a badge lists', () {
    test('a level lists the first cards still to know, in path order', () {
      final log = FixtureLog(screensStart)..know('zz-9001', 0);
      final report = evaluateAchievements(
        log: log.events,
        facts: courseFacts(),
      );
      final a1 = report['level-a1']!;
      expect(a1.status, AchievementStatus.inProgress);
      expect(a1.have, 1);
      expect(a1.cards, <String>['zz-9002', 'zz-9003', 'zz-9004']);
      expect(a1.cards, hasLength(kShownCards));
    });

    test('an earned level lists none', () {
      expect(learnedToA1()['level-a1']!.cards, isEmpty);
    });

    test('an earned word count lists the first words known', () {
      final facts = courseFacts();
      final log = FixtureLog(screensStart);
      var day = 0;
      for (var unit = 2; unit <= 51; unit++) {
        for (final id in unitCards(unit)) {
          log.know(id, day);
          day++;
        }
      }
      final report = evaluateAchievements(log: log.events, facts: facts);
      final hundred = report['words-100']!;
      expect(hundred.isEarned, isTrue);
      expect(hundred.cards, <String>[
        'zz-201',
        'zz-202',
        'zz-301',
        'zz-302',
        'zz-401',
      ]);
      expect(hundred.cards, hasLength(kShownWords));
      // A count not reached lists nothing.
      expect(report['words-500']!.cards, isEmpty);
    });

    test('a level earned before keeps its place when a deck grows', () {
      final grown = courseFacts(extraCardsInUnitOne: 2);
      final report = evaluateAchievements(
        log: FixtureLog(screensStart).events,
        facts: grown,
        earnedBefore: <String, DateTime>{'level-a1': screensStart},
      );
      expect(report['level-a1']!.isEarned, isTrue);
      expect(report['level-a1']!.earnedAt, screensStart);
    });
  });
}
