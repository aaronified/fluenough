import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import 'settings.dart';

/// Keeps a profile's [settings] in its database (#15): restored when the app
/// opens, and each change saved as it happens, in order.
class StoredSettings {
  StoredSettings._(this.settings, this._db) : _saved = settings.toStored() {
    settings.addListener(_save);
  }

  /// The settings stored in [db], with the defaults for any not stored yet.
  static Future<StoredSettings> open(AppDatabase db) async => StoredSettings._(
    SettingsNotifier()..restore(await db.settingsDao.all()),
    db,
  );

  final SettingsNotifier settings;
  final AppDatabase _db;
  Map<String, String> _saved;
  Future<void> _writes = Future<void>.value();

  /// Completes once every change so far is in the database.
  Future<void> flush() => _writes;

  void _save() {
    final now = settings.toStored();
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
