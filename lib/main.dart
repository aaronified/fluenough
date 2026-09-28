import 'package:flutter/material.dart';

import 'app.dart';
import 'app/app_state.dart';
import 'app/deck_catalog.dart';
import 'app/memory_progress.dart';
import 'core/tts/system_tts_engine.dart';

export 'app.dart' show FluenoughApp;

/// Builds the app's services and starts it. This is the only place that
/// names a concrete service: everything below reads them through `AppScope`
/// (docs/adr/0007).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    FluenoughApp(
      state: AppState(
        catalog: DeckCatalog.bundled(),
        progress: MemoryProgress(),
        tts: SystemTtsEngine(),
      ),
    ),
  );
}
