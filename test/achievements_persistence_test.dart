// Earned badges are kept (#323): the settings keep the date each was first
// earned and which were shown, in the profile's own store, so that a restart
// or a deck that grows takes none away. The review log is never touched.

import 'dart:convert';

import 'package:fluenough/app/achievements_holder.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _early = DateTime.utc(2026, 1, 5, 9);
final DateTime _late = DateTime.utc(2026, 2, 7, 18);

/// Answers one card of [language] on each of [days] consecutive days from
/// [first], so that a streak of that many days is earned.
void _answerDaily(AppState state, String language, int days, DateTime first) {
  for (var i = 0; i < days; i++) {
    state.progress.record(
      deckId: '$language-core',
      cardId: '$language-1',
      mode: DrillMode.recognition,
      grade: 4,
      now: first.add(Duration(days: i)),
      elapsed: const Duration(seconds: 3),
      answerGiven: 'x',
    );
  }
}

void main() {
  group('the settings keep the earned badges', () {
    test('a badge is added with its date and never taken away', () {
      final settings = SettingsNotifier();
      expect(settings.achievementsEarnedOf('hi'), isEmpty);

      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _late,
      });
      expect(settings.achievementsEarnedOf('hi'), <String, DateTime>{
        'level-a1': _late,
      });

      // An earlier date wins, a later one does not move it, a new id is
      // added, and nothing is removed.
      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _early,
        'words-100': _late,
      });
      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _late,
      });
      settings.rememberAchievements('hi', const <String, DateTime>{});
      expect(settings.achievementsEarnedOf('hi'), <String, DateTime>{
        'level-a1': _early,
        'words-100': _late,
      });
      expect(settings.achievementsEarnedOf('bn'), isEmpty);
    });

    test('a language and the app are kept apart', () {
      final settings = SettingsNotifier()
        ..rememberAchievements('hi', <String, DateTime>{'level-a1': _early})
        ..rememberAchievements(kAppAchievements, <String, DateTime>{
          'other-streak-3': _late,
        });
      expect(settings.achievementsEarnedOf('hi').keys, <String>['level-a1']);
      expect(settings.achievementsEarnedOf(kAppAchievements).keys, <String>[
        'other-streak-3',
      ]);
    });

    test('saying the same again tells no one', () {
      final settings = SettingsNotifier();
      var told = 0;
      settings.addListener(() => told++);
      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _early,
      });
      expect(told, 1);
      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _early,
      });
      settings.rememberAchievements('hi', <String, DateTime>{
        'level-a1': _late,
      });
      expect(told, 1);
      settings.markAchievementsSeen('hi', const <String>['level-a1']);
      expect(told, 2);
      settings.markAchievementsSeen('hi', const <String>['level-a1']);
      expect(told, 2);
    });

    test('the dates survive a restart, as the store writes and reads them', () {
      final before = SettingsNotifier()
        ..rememberAchievements('hi', <String, DateTime>{
          'level-a1': _early,
          'set-family': _late,
        })
        ..rememberAchievements(kAppAchievements, <String, DateTime>{
          'other-streak-7': _late,
        });
      final stored = before.toStored();
      final after = SettingsNotifier()..restore(stored);
      expect(after.achievementsEarnedOf('hi'), <String, DateTime>{
        'level-a1': _early,
        'set-family': _late,
      });
      expect(after.achievementsEarnedOf(kAppAchievements), <String, DateTime>{
        'other-streak-7': _late,
      });
    });

    test('the seen badges survive, and a scope looked at stays looked at', () {
      final before = SettingsNotifier();
      expect(before.achievementsSeenOf('hi'), isNull);
      before
        ..markAchievementsSeen('hi', const <String>['level-a1', 'words-100'])
        ..markAchievementsSeen('bn', const <String>[]);
      final after = SettingsNotifier()..restore(before.toStored());
      expect(after.achievementsSeenOf('hi'), <String>{'level-a1', 'words-100'});
      // Looked at with nothing earned: empty, not never looked at.
      expect(after.achievementsSeenOf('bn'), isEmpty);
      expect(after.achievementsSeenOf('bn'), isNotNull);
      expect(after.achievementsSeenOf('ta'), isNull);
    });

    test('unreadable stored values are skipped, the rest is kept', () {
      final settings = SettingsNotifier()
        ..restore(<String, String>{
          'achievements_earned': jsonEncode(<String, Object>{
            'HI': <String, String>{'level-a1': '2026-01-01T00:00:00Z'},
            'hi': <String, String>{
              'Bad Id': '2026-01-01T00:00:00Z',
              'words-100': 'not a date',
              'level-a2': '2026-01-02T00:00:00Z',
            },
            'bn': 7,
          }),
          'achievements_seen': jsonEncode(<String, Object>{
            'hi': <Object>['level-a2', 7, 'BAD'],
            'bn': 'nothing',
          }),
        });
      expect(settings.achievementsEarnedOf('HI'), isEmpty);
      expect(settings.achievementsEarnedOf('hi'), <String, DateTime>{
        'level-a2': DateTime.utc(2026, 1, 2),
      });
      expect(settings.achievementsEarnedOf('bn'), isEmpty);
      expect(settings.achievementsSeenOf('hi'), <String>{'level-a2'});
      expect(settings.achievementsSeenOf('bn'), isNull);
    });

    test('a store with nothing about badges restores cleanly', () {
      final settings = SettingsNotifier()..restore(const <String, String>{});
      expect(settings.achievementsEarnedOf('hi'), isEmpty);
      expect(settings.achievementsSeenOf('hi'), isNull);
    });
  });

  group('the evaluator is given what was kept', () {
    test('a badge kept stays earned when its rule no longer holds', () {
      final report = computeAchievements(
        AchievementJob(
          language: null,
          facts: null,
          log: const [],
          parameters: const {},
          earnedBefore: <String, DateTime>{'other-streak-7': _early},
        ),
      );
      final streak = report['other-streak-7']!;
      expect(streak.isEarned, isTrue);
      expect(streak.earnedAt, _early);
      // The ones not kept are still locked.
      expect(report['other-streak-3']!.isEarned, isFalse);
    });
  });

  group('the holder keeps what it works out', () {
    test('a badge earned is written to the settings, with its date', () async {
      final state = AppState.test();
      await state.load();
      _answerDaily(state, 'zz', 3, DateTime.utc(2026, 5, 1, 8));
      final report = state.achievements.of(null)!;
      expect(report['other-streak-3']!.isEarned, isTrue);
      // Written once the build that asked is over.
      await Future<void>.delayed(Duration.zero);
      final kept = state.settings.achievementsEarnedOf(kAppAchievements);
      expect(kept.keys, contains('other-streak-3'));
      expect(kept['other-streak-3'], report['other-streak-3']!.earnedAt);
      expect(kept.keys, isNot(contains('other-streak-7')));
    });

    test('what was kept is given to the next report', () async {
      final state = AppState.test();
      await state.load();
      state.settings.rememberAchievements(kAppAchievements, <String, DateTime>{
        'other-streak-30': _early,
      });
      final report = state.achievements.of(null)!;
      expect(report['other-streak-30']!.isEarned, isTrue);
      expect(report['other-streak-30']!.earnedAt, _early);
    });

    test('the news of a session is marked seen once', () async {
      final state = AppState.test();
      await state.load();
      state.settings
        ..markAchievementsSeen('zz', const <String>[])
        ..markAchievementsSeen(kAppAchievements, const <String>[]);
      _answerDaily(state, 'zz', 3, DateTime.utc(2026, 5, 1, 8));
      final since = DateTime.utc(2026, 5, 1);
      final news = state.achievements.newsFor('zz', since: since)!;
      expect(
        {for (final r in news.fresh) r.def.id},
        <String>{'other-streak-3'},
      );

      state.achievements.markSeen('zz', news);
      expect(state.settings.achievementsSeenOf(kAppAchievements), <String>{
        'other-streak-3',
      });
      final again = state.achievements.newsFor('zz', since: since)!;
      expect(again.isEmpty, isTrue);
    });

    test('the first look finds past reviews, not new badges', () async {
      final state = AppState.test();
      await state.load();
      _answerDaily(state, 'zz', 3, DateTime.utc(2026, 5, 1, 8));
      final news = state.achievements.newsFor(
        'zz',
        since: DateTime.utc(2026, 6, 1),
      )!;
      expect(news.fresh, isEmpty);
      expect({for (final r in news.past) r.def.id}, <String>{'other-streak-3'});
    });
  });
}
