import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// [ReminderScheduler] through the `flutter_local_notifications` plugin
/// (#90, owner, 2026-10-30), on Android.
///
/// Only `lib/main.dart` imports this file, so the web build, which starts
/// from `lib/main_web.dart`, never reaches the plugin.
///
/// Every reminder is scheduled **inexactly**
/// ([AndroidScheduleMode.inexactAllowWhileIdle]): a daily reminder does not
/// need to fire on the minute, and exact alarms need a permission Android 14
/// restricts (the manifest has none). One notification channel is used. The
/// plugin's boot receiver, which `tools/brand_android.py` declares, puts what
/// was scheduled back after a reboot.
class PluginReminderScheduler implements ReminderScheduler {
  PluginReminderScheduler._(this._plugin);

  /// The one notification channel the reminder uses.
  static const String channelId = 'daily_reminder';

  /// What a reminder's tap hands back.
  static const String payload = 'today';

  /// The launcher icon flutter create writes, which `tools/brand_android.py`
  /// replaces with the app's own.
  static const String icon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin _plugin;
  VoidCallback? _onOpened;

  /// Starts the plugin. Throws if the platform cannot (the caller falls back
  /// to [NullReminderScheduler]).
  static Future<PluginReminderScheduler> start() async {
    // The plugin needs a local location only for repeating notifications, and
    // the reminder schedules instants in UTC, which are the same moment in
    // any zone. The planning is done in the phone's own local time, in Dart.
    tz.setLocalLocation(tz.UTC);
    final scheduler = PluginReminderScheduler._(
      FlutterLocalNotificationsPlugin(),
    );
    await scheduler._plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(icon),
      ),
      onDidReceiveNotificationResponse: (_) => scheduler._onOpened?.call(),
    );
    return scheduler;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get supported => true;

  @override
  Future<bool> permitted() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() ?? false) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replace(
    List<ReminderNotice> notices, {
    required String channelName,
    required String channelDescription,
  }) async {
    await _plugin.cancelAllPendingNotifications();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    for (final notice in notices) {
      await _plugin.zonedSchedule(
        // One id per calendar day, so a day is never scheduled twice.
        id: notice.at.year * 10000 + notice.at.month * 100 + notice.at.day,
        title: notice.title,
        body: notice.body,
        scheduledDate: tz.TZDateTime.from(notice.at, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAllPendingNotifications();

  @override
  Future<bool> openNotificationSettings() async =>
      await _android?.openAppNotificationSettings() ?? false;

  @override
  set onOpened(VoidCallback? callback) => _onOpened = callback;

  @override
  Future<bool> launchedByReminder() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }
}
