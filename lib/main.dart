import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app/app_info.dart';
import 'app/added_decks.dart';
import 'app/app_state.dart';
import 'app/deck_catalog.dart';
import 'app/ota_installer.dart';
import 'app/profile.dart';
import 'app/profile_storage.dart';
import 'core/sound/system_sound_check.dart';
import 'core/speech/system_speech_engine.dart';
import 'core/feedback/report.dart';
import 'core/tts/system_tts_engine.dart';
import 'core/updates/apk_install.dart';
import 'core/updates/github_release_check.dart';

export 'app.dart' show FluenoughApp;

/// Where reports from the bug icon go: the relay's address, given at build
/// time (`--dart-define=REPORT_URL=…`, ADR-0021). Not a secret: the relay
/// holds the token. Empty in a build given none, which then cannot send.
const String reportUrl = String.fromEnvironment('REPORT_URL');

/// Builds the app's services and starts it. This is the only place that
/// names a concrete service: everything below reads them through `AppScope`
/// (docs/adr/0007).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await openProfileStorage(Profile.defaultProfile);
  // Where ota_update downloads: files/ota_update in the app's own storage,
  // which getApplicationSupportDirectory is on Android.
  final files = await getApplicationSupportDirectory();
  runApp(
    FluenoughApp(
      state: AppState(
        catalog: DeckCatalog.bundled(
          null,
          FileDeckStore(Directory('${files.path}/decks')),
        ),
        progress: storage.progress,
        settings: storage.settings,
        tts: SystemTtsEngine(),
        speech: SystemSpeechEngine(),
        soundCheck: SystemSoundCheck(),
        reports: reportUrl.isEmpty
            ? const NullReportSender()
            : RelayReportSender(
                Uri.parse(reportUrl),
                userAgent: 'fluenough/${AppInfo.version}',
              ),
        releases: GitHubReleaseCheck(userAgent: 'fluenough/${AppInfo.version}'),
        installer: OtaApkInstaller(),
        downloads: FileDownloadStore(Directory('${files.path}/ota_update')),
      ),
    ),
  );
}
