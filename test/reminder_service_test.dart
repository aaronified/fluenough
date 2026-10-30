// The daily reminder (#90) with a fake scheduler: switching on asks the
// phone and schedules, switching off cancels, a refusal leaves it off, a new
// time re-plans, the app being open leaves today's out, and the text holds
// only a count.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/reminder_scheduler.dart';
import 'package:fluenough/app/reminder_service.dart';
import 'package:fluenough/app/reminder_words.dart';
import 'package:fluenough/app/settings.dart';

import 'support/fake_reminder_scheduler.dart';

void main() {
  // Friday 30 October 2026, 08:00: the default reminder, 19:30, is ahead.
  var now = DateTime(2026, 10, 30, 8);
  late SettingsNotifier settings;
  late FakeReminderScheduler scheduler;
  late List<int> due;
  var taps = 0;
  var featureOn = true;

  ReminderService build() => ReminderService(
    scheduler: scheduler,
    settings: settings,
    available: () => featureOn,
    forecast: () => due,
    words: () => reminderWordsFor(const Locale('en')),
    clock: () => now,
    onOpened: () => taps++,
  );

  setUp(() {
    now = DateTime(2026, 10, 30, 8);
    settings = SettingsNotifier();
    scheduler = FakeReminderScheduler();
    due = <int>[12, 0, 3, 3, 3, 3, 3];
    taps = 0;
    featureOn = true;
  });

  List<DateTime> times() => <DateTime>[for (final n in scheduler.pending) n.at];

  test(
    'switching on asks the phone, then schedules the days with cards due',
    () async {
      final service = build();
      expect(settings.reminder, isFalse, reason: 'off by default');
      expect(
        scheduler.asked,
        0,
        reason: 'never asked before it is switched on',
      );

      expect(await service.setOn(true), ReminderSetup.on);

      expect(scheduler.asked, 1);
      expect(settings.reminder, isTrue);
      expect(times(), <DateTime>[
        DateTime(2026, 10, 30, 19, 30),
        DateTime(2026, 11, 1, 19, 30),
        DateTime(2026, 11, 2, 19, 30),
        DateTime(2026, 11, 3, 19, 30),
        DateTime(2026, 11, 4, 19, 30),
        DateTime(2026, 11, 5, 19, 30),
      ]);
    },
  );

  test(
    'a refused permission leaves the reminder off and schedules nothing',
    () async {
      scheduler
        ..allowed = false
        ..askGrants = false;
      final service = build();

      expect(await service.setOn(true), ReminderSetup.refused);

      expect(settings.reminder, isFalse);
      expect(scheduler.pending, isEmpty);
      expect(scheduler.replaces, 0);
    },
  );

  test('switching off cancels what was scheduled', () async {
    final service = build();
    await service.setOn(true);
    expect(scheduler.pending, isNotEmpty);

    expect(await service.setOn(false), ReminderSetup.off);

    expect(settings.reminder, isFalse);
    expect(scheduler.pending, isEmpty);
  });

  test('a new time re-plans at the new time', () async {
    final service = build();
    await service.setOn(true);

    settings.reminderTime = const TimeOfDay(hour: 7, minute: 45);
    await service.replan();

    expect(
      times().first,
      DateTime(2026, 11, 1, 7, 45),
      reason: 'today 07:45 has passed, and tomorrow has nothing due',
    );
    expect(
      times().every((t) => t.hour == 7 && t.minute == 45),
      isTrue,
      reason: 'every pending reminder moved',
    );
  });

  test(
    'a time that has passed today is first planned for the next day',
    () async {
      now = DateTime(2026, 10, 30, 20);
      due = <int>[5, 5, 5];
      final service = build();
      await service.setOn(true);
      expect(times().first, DateTime(2026, 10, 31, 19, 30));
    },
  );

  test(
    'a day with nothing due gets no reminder, and no cards means none',
    () async {
      due = <int>[0, 0, 0, 0, 0, 0, 0];
      final service = build();
      await service.setOn(true);
      expect(scheduler.pending, isEmpty);
    },
  );

  test('the text is a count only, with the plural', () async {
    due = <int>[1, 1, 7];
    final service = build();
    await service.setOn(true);

    expect(
      <String>[for (final n in scheduler.pending) n.body],
      <String>[
        '1 card is due for review',
        '1 card is due for review',
        '7 cards are due for review',
      ],
    );
    expect(scheduler.pending.first.title, 'Time to practise');
    expect(scheduler.channelName, 'Daily reminder');
    expect(scheduler.channelDescription, isNotEmpty);
  });

  test(
    'while the app is open today is left out, and left again it is back',
    () async {
      final service = build();
      await service.setOn(true);
      expect(times().first, DateTime(2026, 10, 30, 19, 30));

      await service.appResumed();
      expect(times().first, DateTime(2026, 11, 1, 19, 30));

      await service.appPaused();
      expect(times().first, DateTime(2026, 10, 30, 19, 30));
    },
  );

  test('opening the app re-plans from what is due now', () async {
    final service = build();
    await service.setOn(true);
    await service.appPaused();
    expect(scheduler.pending, hasLength(6));

    due = <int>[0, 0, 0, 0, 0, 0, 2];
    await service.appResumed();
    expect(times(), <DateTime>[DateTime(2026, 11, 5, 19, 30)]);
  });

  test(
    'a reminder the phone stopped allowing is switched off when the app opens',
    () async {
      final service = build();
      await service.setOn(true);

      scheduler.allowed = false;
      await service.appResumed();

      expect(settings.reminder, isFalse);
      expect(scheduler.pending, isEmpty);
    },
  );

  test('nothing is scheduled while the feature is not on', () async {
    featureOn = false;
    settings.reminder = true;
    final service = build();
    await service.replan();
    expect(scheduler.pending, isEmpty);
    expect(scheduler.replaces, 0);
  });

  test('tapping a reminder opens the app on Today', () {
    build();
    scheduler.tap();
    expect(taps, 1);
  });

  test('a cold start from a reminder tap opens the app on Today', () async {
    scheduler.launched = true;
    build();
    await Future<void>.delayed(Duration.zero);
    expect(taps, 1);
  });

  test('a normal start does not open Today by itself', () async {
    build();
    await Future<void>.delayed(Duration.zero);
    expect(taps, 0);
  });

  test('changing the switch in settings directly re-plans too', () async {
    final service = build();
    settings.reminder = true;
    await service.replan();
    expect(scheduler.pending, isNotEmpty);
    settings.reminder = false;
    await service.replan();
    expect(scheduler.pending, isEmpty);
  });

  test('a scheduler that fails does not break the reminder', () async {
    final logged = <String>[];
    final broken = _Failing();
    final service = ReminderService(
      scheduler: broken,
      settings: settings..reminder = true,
      available: () => true,
      forecast: () => due,
      words: () => reminderWordsFor(const Locale('en')),
      clock: () => now,
      log: logged.add,
    );
    await service.replan();
    expect(logged.single, contains('Reminder error'));
    await service.replan();
    expect(logged, hasLength(2), reason: 'it goes on to the next plan');
  });
}

class _Failing extends FakeReminderScheduler {
  @override
  Future<void> replace(
    List<ReminderNotice> notices, {
    required String channelName,
    required String channelDescription,
  }) async => throw StateError('no channel');
}
