import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app/app_info.dart';
import 'app/added_decks.dart';
import 'app/app_log.dart';
import 'app/app_state.dart';
import 'app/deck_catalog.dart';
import 'app/links.dart';
import 'app/mail_share.dart';
import 'app/ota_installer.dart';
import 'app/profile.dart';
import 'app/profile_storage.dart';
import 'app/report_mail.dart';
import 'app/system_settings.dart';
import 'core/sound/system_sound_check.dart';
import 'core/speech/system_speech_engine.dart';
import 'core/tts/system_tts_engine.dart';
import 'core/tts/volume_monitor.dart';
import 'core/updates/apk_install.dart';
import 'core/updates/github_release_check.dart';
import 'core/updates/github_release_notes.dart';

export 'app.dart' show FluenoughApp;

/// Builds the app's services and starts it. This is the only place that
/// names a concrete service: everything below reads them through `AppScope`
/// (docs/adr/0007).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Where ota_update downloads: files/ota_update in the app's own storage,
  // which getApplicationSupportDirectory is on Android. The app log is
  // there too, in logs/, so that it outlives a crash (#162).
  final files = await getApplicationSupportDirectory();
  final log = AppLog(store: FileLogStore(File('${files.path}/logs/app.log')));
  logErrors(log);
  await log.open();
  log.event('App started: ${AppInfo.version}');
  final storage = await openProfileStorage(Profile.defaultProfile);
  // A report's app log is written to shared/ in the cache, the folder
  // MainActivity's FileProvider lends to the mail app (ADR-0021).
  final cache = await getTemporaryDirectory();
  final share = ChannelMailShare(folder: Directory('${cache.path}/shared'));
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
        volume: SystemVolumeMonitor(),
        soundCheck: SystemSoundCheck(),
        systemSettings: const ChannelSystemSettings(),
        reports: MailReportSender(
          address: AppLinks.feedbackEmail,
          links: const LauncherLinks(),
          share: share,
        ),
        // Review files go the same way (docs/plans/deck-browser.md).
        mailShare: share,
        log: log,
        releases: GitHubReleaseCheck(userAgent: 'fluenough/${AppInfo.version}'),
        releaseNotes: GitHubReleaseNotes(
          userAgent: 'fluenough/${AppInfo.version}',
        ),
        installer: OtaApkInstaller(),
        downloads: FileDownloadStore(Directory('${files.path}/ota_update')),
      ),
    ),
  );
}
