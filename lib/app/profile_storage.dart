import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import 'database_progress.dart';
import 'memory_progress.dart';
import 'profile.dart';
import 'settings.dart';
import 'stored_settings.dart';

/// What a profile keeps: its progress and its settings.
typedef ProfileStorage = ({ProgressStore progress, SettingsNotifier settings});

/// The file [profile]'s database lives in, without its extension. One file
/// per profile, so removing a profile removes one file.
String databaseFileName(Profile profile) => 'fluenough-${profile.id}';

/// Opens [profile]'s database, `<databaseFileName>.sqlite` in the app's
/// documents directory, for its progress and settings. If it cannot be
/// opened, both are kept in memory instead, which Today says is not saved,
/// rather than there being no app.
Future<ProfileStorage> openProfileStorage(Profile profile) async {
  try {
    final db = AppDatabase(driftDatabase(name: databaseFileName(profile)));
    return (
      progress: await DatabaseProgress.open(db),
      settings: (await StoredSettings.open(db)).settings,
    );
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fluenough storage',
        context: ErrorDescription('while opening the profile database'),
      ),
    );
    return (progress: MemoryProgress(), settings: SettingsNotifier());
  }
}
