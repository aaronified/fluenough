import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import 'settings.dart';

/// Keeps a profile's [settings] in its database (#15): restored when the app
/// opens, and each change saved as it happens, in order.
class StoredSettings {
  StoredSettings._(this.settings, this._db, Map<String, String> inDatabase)
    : _saved = inDatabase {
    settings
      ..addListener(_save)
      ..todaySummaryChanges.addListener(_save);
  }

  /// The settings stored in [db], with the defaults for any not stored yet.
  /// What restoring changed (a store from an older version, migrated) is
  /// saved at once, so that it is not migrated again on every launch.
  static Future<StoredSettings> open(AppDatabase db) async {
    final inDatabase = await db.settingsDao.all();
    final stored = StoredSettings._(
      SettingsNotifier()..restore(inDatabase),
      db,
      inDatabase,
    );
    stored._save();
    return stored;
  }

  final SettingsNotifier settings;
  final AppDatabase _db;
  Map<String, String> _saved;
  Future<void> _writes = Future<void>.value();

  /// Completes once every change so far is in the database.
  Future<void> flush() => _writes;

  /// Every setting, and the Today summary beside them: a cache of this
  /// build, so it is stored here and never in a backup (#875).
  static Map<String, String> _snapshot(SettingsNotifier settings) =>
      <String, String>{
        ...settings.toStored(),
        SettingsNotifier.todaySummaryKey: settings.todaySummary ?? '',
      };

  void _save() {
    final now = _snapshot(settings);
    final changed = <String, String>{
      for (final MapEntry(:key, :value) in now.entries)
        if (_saved[key] != value) key: value,
    };
    _saved = now;
    _writes = _writes
        .then((_) async {
          for (final MapEntry(:key, :value) in changed.entries) {
            await _db.settingsDao.put(key, value);
          }
        })
        .catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'fluenough settings',
              context: ErrorDescription('while saving a setting'),
            ),
          );
        });
  }
}
