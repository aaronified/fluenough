import 'package:flutter/material.dart';

import 'app.dart';
import 'app/added_decks.dart';
import 'app/app_info.dart';
import 'app/app_log.dart';
import 'app/app_state.dart';
import 'app/synonym_loader.dart';
import 'app/deck_catalog.dart';
import 'app/deck_downloads.dart';
import 'app/downloaded_decks.dart';
import 'app/pacing.dart';
import 'features/stats/progress_numbers.dart';
import 'app/profile.dart';
import 'app/profile_storage.dart';
import 'app/web_deck_fetcher.dart';
import 'app/web_frame.dart';
import 'core/scheduling/skill_fit.dart';
import 'core/tts/system_tts_engine.dart';

/// The web build's entry point (`.github/workflows/pages.yml`). Like
/// `main.dart` it is the one place that names concrete services, but it
/// names none that reads files, runs a platform channel or installs an APK:
/// the browser has none of them, and runs fitting and pacing in place, as it
/// has no isolates. Everything left out is the `AppState`
/// default, which does nothing.
///
/// Progress and settings are kept in the browser's storage by drift. The
/// decks are downloaded from GitHub on each visit, into memory; keeping them
/// in the browser's storage is not built.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = AppLog(store: MemoryLogStore());
  logErrors(log);
  await log.open();
  log.event('App started: ${AppInfo.version}');
  final storage = await openProfileStorage(Profile.defaultProfile);
  final downloaded = MemoryDownloadedDecks();
  runApp(
    FluenoughApp(
      frame: webPhoneFrame,
      state: AppState(
        catalog: DeckCatalog(
          DeckSources(<DeckSource>[AssetDeckSource(), downloaded]),
          added: MemoryDeckStore(),
        ),
        deckDownloads: DeckDownloads(
          fetcher: WebDeckFetcher(),
          files: downloaded,
          clock: DateTime.now,
          log: log,
        ),
        progress: storage.progress,
        synonymLoader: loadSynonymSets,
        settings: storage.settings,
        tts: SystemTtsEngine(),
        // A browser has no isolates: fitting and pacing run in place.
        fitRunner: (job) async => SkillFit.run(job),
        paceRunner: paceInPlace,
        progressRunner: progressInPlace,
        log: log,
      ),
    ),
  );
}
