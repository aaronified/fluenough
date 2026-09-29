import 'package:flutter/material.dart';

import 'app.dart';
import 'app/app_state.dart';
import 'app/database_progress.dart';
import 'app/deck_catalog.dart';
import 'app/memory_progress.dart';
import 'app/profile.dart';
import 'core/tts/system_tts_engine.dart';

export 'app.dart' show FluenoughApp;

/// Builds the app's services and starts it. This is the only place that
/// names a concrete service: everything below reads them through `AppScope`
/// (docs/adr/0007).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    FluenoughApp(
      state: AppState(
        catalog: DeckCatalog.bundled(),
        progress: await openProgress(Profile.defaultProfile),
        tts: SystemTtsEngine(),
      ),
    ),
  );
}

/// [profile]'s saved progress. If its database cannot be opened, progress
/// in memory instead, which Today says is not saved, rather than no app.
Future<ProgressStore> openProgress(Profile profile) async {
  try {
    return await DatabaseProgress.openFor(profile);
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fluenough progress',
        context: ErrorDescription('while opening the progress database'),
      ),
    );
    return MemoryProgress();
  }
}
