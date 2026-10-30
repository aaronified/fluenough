import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../core/scheduling/reminder_schedule.dart';
import 'reminder_scheduler.dart';
import 'settings.dart';

/// What the notification says, in the learner's language. Chosen where the
/// locale is known; the service only asks for it when it plans.
class ReminderWords {
  const ReminderWords({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;

  /// The text for a day with [due] cards due. Only the count: no card, word
  /// or language, as a notification shows on the lock screen.
  final String Function(int due) body;

  final String channelName;
  final String channelDescription;
}

/// What came of switching the reminder on or off.
enum ReminderSetup {
  /// On, and planned.
  on,

  /// Off.
  off,

  /// The phone does not allow notifications: the reminder stays off.
  refused,
}

/// The daily reminder (#90): plans it from the due forecast and hands the
/// times to the [ReminderScheduler]. It re-plans when the reminder is
/// switched on, off or moved, when the app opens, and whenever the app is
/// left, so what is pending always matches what is due.
///
/// Everything is scheduled inexactly ahead for seven days at most. A
/// reboot is covered by the plugin's boot receiver, which puts back what was
/// scheduled; a change of time zone while the app is away is not seen until
/// the app opens, when this plans again from the phone's clock.
///
/// Not in lib/core: it reads settings and the platform's interface.
class ReminderService {
  ReminderService({
    required this.scheduler,
    required this.settings,
    required this.available,
    required this.forecast,
    required this.words,
    this.clock = DateTime.now,
    this.onOpened,
    this.log,
  }) : _wasOn = settings.reminder,
       _wasAt = settings.reminderTime {
    settings.addListener(_settingsChanged);
    scheduler.onOpened = () => onOpened?.call();
  }

  final ReminderScheduler scheduler;
  final SettingsNotifier settings;

  /// Whether the reminder is built in this version (`Feature.reminder`).
  final bool Function() available;

  /// Cards due by the end of each day, today first
  /// (`AppState.dueForecast`).
  final List<int> Function() forecast;

  final ReminderWords Function() words;
  final DateTime Function() clock;

  /// Opens Today: the learner tapped a reminder.
  final VoidCallback? onOpened;
  final void Function(String message)? log;

  TimeOfDay _wasAt;
  bool _wasOn;

  // The app is open until it is left. While it is, today's reminder is not
  // pending: nothing fires while the app is in use (#90).
  bool _open = true;

  Future<void> _queue = Future<void>.value();

  void _settingsChanged() {
    if (settings.reminder == _wasOn && settings.reminderTime == _wasAt) return;
    _wasOn = settings.reminder;
    _wasAt = settings.reminderTime;
    unawaited(replan());
  }

  /// Whether this build can show notifications at all.
  bool get supported => scheduler.supported;

  /// Opens the phone's notification settings for the app, for the learner
  /// who refused; says whether it could.
  Future<bool> openNotificationSettings() =>
      scheduler.openNotificationSettings();

  /// Switches the reminder on or off. Switching on asks the phone to allow
  /// notifications first, and when it does not, leaves the reminder off and
  /// says [ReminderSetup.refused].
  Future<ReminderSetup> setOn(bool on) async {
    if (!on) {
      settings.reminder = false;
      await replan();
      return ReminderSetup.off;
    }
    if (!await scheduler.requestPermission()) {
      settings.reminder = false;
      return ReminderSetup.refused;
    }
    settings.reminder = true;
    await replan();
    return ReminderSetup.on;
  }

  /// The app opened or came back: plans from now, with today's reminder left
  /// out as the learner is here.
  ///
  /// This is also where a reminder the phone no longer allows is found and
  /// switched off, so that the switch tells the truth.
  Future<void> appResumed() {
    _open = true;
    return replan(verify: true);
  }

  /// The app was left: plans again, today's reminder included.
  Future<void> appPaused() {
    _open = false;
    return replan();
  }

  /// Makes the pending reminders match the settings and what is due. Runs
  /// one at a time, in order.
  ///
  /// With [verify], a reminder that is on but not allowed by the phone any
  /// more is switched off, as the learner took the permission back in the
  /// phone's settings.
  Future<void> replan({bool verify = false}) =>
      _queue = _queue.then((_) => _plan(verify)).catchError((Object error) {
        log?.call('Reminder error: $error');
      });

  Future<void> _plan(bool verify) async {
    if (!available() || !settings.reminder) {
      await scheduler.cancelAll();
      return;
    }
    if (!await scheduler.permitted()) {
      await scheduler.cancelAll();
      if (verify) {
        log?.call('Reminder off: notifications not allowed');
        settings.reminder = false;
      }
      return;
    }
    final now = clock();
    final due = List<int>.of(forecast());
    if (_open && due.isNotEmpty) due[0] = 0;
    final time = settings.reminderTime;
    final fires = ReminderSchedule.plan(
      now: now,
      hour: time.hour,
      minute: time.minute,
      dueByDay: due,
    );
    final text = words();
    final today = DateTime(now.year, now.month, now.day);
    final notices = <ReminderNotice>[];
    for (var i = 0; i < due.length; i++) {
      // The same expression the plan used, so the times are equal.
      final at = DateTime(
        today.year,
        today.month,
        today.day + i,
        time.hour,
        time.minute,
      );
      if (fires.contains(at)) {
        notices.add(
          ReminderNotice(at: at, title: text.title, body: text.body(due[i])),
        );
      }
    }
    await scheduler.replace(
      notices,
      channelName: text.channelName,
      channelDescription: text.channelDescription,
    );
  }

  void dispose() {
    settings.removeListener(_settingsChanged);
    scheduler.onOpened = null;
  }
}
