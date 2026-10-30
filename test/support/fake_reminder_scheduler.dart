import 'package:flutter/foundation.dart';

import 'package:fluenough/app/reminder_scheduler.dart';

/// A [ReminderScheduler] that keeps what it is asked, so a test can read
/// what is pending, and answers the permission as the test says.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.allowed = true, this.askGrants = true});

  /// What the phone lets the app do now.
  bool allowed;

  /// Whether asking for the permission is granted.
  bool askGrants;

  @override
  bool supported = true;

  /// What is pending now.
  List<ReminderNotice> pending = <ReminderNotice>[];

  /// How many times the permission was asked.
  int asked = 0;

  /// How many times everything pending was cancelled, by [cancelAll] alone.
  int cancels = 0;

  /// How many times the pending reminders were replaced.
  int replaces = 0;

  /// How many times the phone's notification settings were opened.
  int settingsOpened = 0;

  /// The channel the last replace named.
  String? channelName;
  String? channelDescription;

  VoidCallback? _opened;

  /// Whether a tap on a reminder started the app.
  bool launched = false;

  /// The learner taps a reminder.
  void tap() => _opened?.call();

  @override
  Future<bool> permitted() async => allowed;

  @override
  Future<bool> requestPermission() async {
    asked++;
    if (askGrants) allowed = true;
    return allowed;
  }

  @override
  Future<void> replace(
    List<ReminderNotice> notices, {
    required String channelName,
    required String channelDescription,
  }) async {
    replaces++;
    pending = List<ReminderNotice>.of(notices);
    this.channelName = channelName;
    this.channelDescription = channelDescription;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    pending = <ReminderNotice>[];
  }

  @override
  Future<bool> openNotificationSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  set onOpened(VoidCallback? callback) => _opened = callback;

  @override
  Future<bool> launchedByReminder() async => launched;
}
