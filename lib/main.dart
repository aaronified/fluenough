import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app/app_info.dart';
import 'app/added_decks.dart';
import 'app/app_log.dart';
import 'app/app_state.dart';
import 'app/backup_store.dart';
import 'app/deck_catalog.dart';
import 'app/deck_downloads.dart';
import 'app/downloaded_decks.dart';
import 'app/file_snapshot_store.dart';
import 'app/junk_cleanup.dart';
import 'app/links.dart';
import 'app/mail_share.dart';
import 'app/ota_installer.dart';
import 'app/plugin_reminder_scheduler.dart';
import 'app/profile.dart';
import 'app/profile_storage.dart';
import 'app/reminder_scheduler.dart';
import 'app/report_mail.dart';
import 'app/system_settings.dart';
import 'core/decks/deck_fetch.dart';
import 'core/network/network_probe.dart';
import 'core/sound/system_sound_check.dart';
import 'core/speech/system_speech_engine.dart';
import 'core/tts/system_clip_player.dart';
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
  // The decks, downloaded from GitHub into the app's own storage (#210,
  // ADR-0037); only the theme list is bundled.
  final downloaded = FileDownloadedDecks(Directory('${files.path}/downloaded'));
  // The daily reminder's notifications (#90). Without them the reminder's
  // switch stays off.
  ReminderScheduler reminderScheduler = const NullReminderScheduler();
  try {
    reminderScheduler = await PluginReminderScheduler.start();
  } catch (e) {
    log.warning('Reminder error: start failed: $e');
  }
  runApp(
    FluenoughApp(
      state: AppState(
        catalog: DeckCatalog(
          DeckSources(<DeckSource>[AssetDeckSource(), downloaded]),
          added: FileDeckStore(Directory('${files.path}/decks')),
          parser: parseInIsolate,
          // The decks' YAML, kept as JSON between launches and read again
          // only for a file whose SHA-256 changed (#875, ADR-0048).
          snapshots: CatalogSnapshots(
            store: FileSnapshotStore(
              File('${files.path}/catalog-snapshot.json'),
            ),
            app: AppInfo.version,
            knownShas: () async => <String, String>{
              for (final e in (await downloaded.manifest()).entries)
                e.key: e.value.sha256,
            },
            runner: runJobInIsolate,
          ),
        ),
        deckDownloads: DeckDownloads(
          fetcher: GitHubDeckFetcher(userAgent: 'fluenough/${AppInfo.version}'),
          files: downloaded,
          clock: DateTime.now,
          log: log,
        ),
        progress: storage.progress,
        settings: storage.settings,
        tts: SystemTtsEngine(),
        clips: SystemClipPlayer(),
        speech: SystemSpeechEngine(),
        volume: SystemVolumeMonitor(),
        soundCheck: SystemSoundCheck(),
        networkProbe: SystemNetworkProbe(),
        systemSettings: const ChannelSystemSettings(),
        reminderScheduler: reminderScheduler,
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
        // Backups, kept in the app's own storage, which an update leaves
        // alone (#470).
        backupStore: FileBackupStore(Directory('${files.path}/backups')),
        installer: OtaApkInstaller(directory: '${files.path}/ota_update'),
        downloads: FileDownloadStore(Directory('${files.path}/ota_update')),
      ),
    ),
  ); // Junk (old update files, half-written downloads, stale report
  // attachments) is cleaned once a day, a little after the first frame so
  // that it never delays the start (#493).
  final junk = JunkCleanup(
    files: DiskJunkFiles(
      updates: Directory('${files.path}/ota_update'),
      downloads: downloaded.directory,
      cache: cache,
    ),
    stamp: FileJunkStamp(File('${files.path}/junk-cleanup.stamp')),
    log: log,
    version: AppInfo.version,
    hasPending: () => storage.settings.pendingUpdate != null,
  );
  unawaited(Future<void>.delayed(const Duration(seconds: 15), junk.runIfDue));
}
