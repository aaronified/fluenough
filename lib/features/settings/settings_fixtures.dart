import 'dart:async';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/settings.dart';
import '../../core/tts/tts_engine.dart';
import '../gallery/fixtures.dart';

/// Fixture states for Settings, Appearance and Voices in the gallery and the
/// tests. All on the real bundled decks.
abstract final class SettingsFixtures {
  /// Every feature on, with the reminder switched on so its time shows.
  static AppState allOn(AppState app) => GalleryFixtures.state(
    app,
    features: FeatureRegistry.all(),
    settings: SettingsNotifier(reminder: true),
  );

  /// Appearance as the design draws it: every control live.
  static AppState appearanceLive(AppState app) =>
      GalleryFixtures.state(app, features: FeatureRegistry.all());

  /// Voices while the phone has not answered yet.
  static AppState voicesChecking(AppState app) => AppState(
    catalog: app.deckCatalog,
    progress: MemoryProgress(),
    tts: const PendingTtsEngine(),
    clock: app.now,
    profiles: const [GalleryFixtures.aro, GalleryFixtures.mira],
    currentProfileId: GalleryFixtures.aro.id,
  );

  /// No decks loaded, so there is no language to check.
  static AppState noDecks(AppState app) => AppState(
    catalog: DeckCatalog(MemoryDeckSource(const <String, String>{})),
    progress: MemoryProgress(),
    tts: const PendingTtsEngine(),
    clock: app.now,
  );
}

/// A [TtsEngine] that never answers: every language stays "Checking…".
/// For the gallery's checking state only.
class PendingTtsEngine implements TtsEngine {
  const PendingTtsEngine();

  @override
  Future<bool> isLanguageAvailable(String bcp47) => Completer<bool>().future;

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) =>
      Completer<List<TtsVoice>>().future;

  @override
  Future<void> speak(String text, {required String bcp47, double rate = 0.5}) =>
      Future<void>.value();

  @override
  Future<void> stop() => Future<void>.value();

  @override
  Future<void> dispose() => Future<void>.value();
}
