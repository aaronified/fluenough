import 'package:flutter/material.dart';

import 'app.dart';
import 'app/app_state.dart';
import 'app/deck_catalog.dart';
import 'app/profile.dart';
import 'app/profile_storage.dart';
import 'core/tts/system_tts_engine.dart';

export 'app.dart' show FluenoughApp;

/// Builds the app's services and starts it. This is the only place that
/// names a concrete service: everything below reads them through `AppScope`
/// (docs/adr/0007).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await openProfileStorage(Profile.defaultProfile);
  runApp(
    FluenoughApp(
      state: AppState(
        catalog: DeckCatalog.bundled(),
        progress: storage.progress,
        settings: storage.settings,
        tts: SystemTtsEngine(),
      ),
    ),
  );
}
