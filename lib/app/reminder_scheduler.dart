import 'package:flutter/foundation.dart';

/// One reminder to show: when, and what it says. The text is chosen by the
/// app and holds only a count, never a card, as a notification shows on the
/// lock screen (#90).
@immutable
class ReminderNotice {
  const ReminderNotice({
    required this.at,
    required this.title,
    required this.body,
  });

  /// When to show it, local time.
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderNotice &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(at, title, body);

  @override
  String toString() => 'ReminderNotice($at, $body)';
}

/// The phone's local notifications, as the daily reminder needs them: an
/// interface so that tests, the web build and the desktop need no plugin
/// (docs/adr/0007). `lib/app/plugin_reminder_scheduler.dart` is the
/// implementation on Android, and only `lib/main.dart` names it.
abstract interface class ReminderScheduler {
  /// Whether this build can show notifications at all: false on the web and
  /// desktop, where the reminder's switch is shown but cannot be changed.
  bool get supported;

  /// Whether the phone lets the app show notifications now.
  Future<bool> permitted();

  /// Asks the phone to let the app show notifications, where it asks
  /// (Android 13 and later), and says whether it does now. Call only when the
  /// learner switches the reminder on, never at launch.
  Future<bool> requestPermission();

  /// Makes [notices] the only reminders pending: cancels those pending and
  /// schedules these, inexactly, on one notification channel named
  /// [channelName] and described by [channelDescription].
  Future<void> replace(
    List<ReminderNotice> notices, {
    required String channelName,
    required String channelDescription,
  });

  /// Cancels every reminder still pending. One already shown stays.
  Future<void> cancelAll();

  /// Opens the phone's notification settings for the app, for the learner
  /// who refused; says whether it could.
  Future<bool> openNotificationSettings();

  /// Called when the learner taps a reminder: the app opens on Today.
  set onOpened(VoidCallback? callback);
}

/// A [ReminderScheduler] with no notifications: the web build, desktop and
/// anything not given a real one. It cannot be allowed, so the reminder
/// stays off.
class NullReminderScheduler implements ReminderScheduler {
  const NullReminderScheduler();

  @override
  bool get supported => false;

  @override
  Future<bool> permitted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replace(
    List<ReminderNotice> notices, {
    required String channelName,
    required String channelDescription,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> openNotificationSettings() async => false;

  @override
  set onOpened(VoidCallback? callback) {}
}
