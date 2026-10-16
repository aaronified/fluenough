import 'dart:async';

import '../../app/app_info.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/settings.dart';
import '../../app/shell_tab.dart';
import '../../app/skill.dart';
import '../../core/speech/speech_engine.dart';
import '../../core/tts/fixed_tts_engine.dart';
import '../../core/tts/tts_engine.dart';
import '../../core/updates/apk_install.dart';
import '../../core/updates/release_check.dart';
import '../../core/updates/release_notes.dart';
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

  /// Settings with adult content (18+) on: its line says rude words show.
  static AppState adultOn(AppState app) => GalleryFixtures.state(app)
    ..settings.adultContent = true
    ..shellTab.value = ShellTab.settings;

  /// Voices with speaking on: Hindi and Spanish heard on the phone, Telugu
  /// only online, not yet allowed, and Spanish with two voices to choose
  /// from, one needing a connection.
  static AppState voicesSpeaking(AppState app) {
    final state = AppState(
      catalog: app.deckCatalog,
      progress: MemoryProgress(),
      tts: FixedTtsEngine(
        const <String>{'hi', 'es'},
        named: const <String, List<TtsVoice>>{
          'es': <TtsVoice>[
            TtsVoice(name: 'es-es-x-eea-local', locale: 'es-ES'),
            TtsVoice(
              name: 'es-es-x-eed-network',
              locale: 'es-ES',
              networkRequired: true,
            ),
          ],
        },
      ),
      speech: FixedSpeechEngine(
        onDevice: const <String>{'hi', 'es'},
        online: const <String>{'te'},
      ),
      settings: SettingsNotifier(
        enabledSkills: <Skill>{...Skill.values},
        learningChosen: true,
        spokenLanguages: const <String>['en'],
      ),
      clock: app.now,
      profiles: const [GalleryFixtures.aro, GalleryFixtures.mira],
      currentProfileId: GalleryFixtures.aro.id,
    );
    unawaited(state.startSpeech());
    return state;
  }

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

  /// A version newer than this build's: its next minor version, so that it
  /// stays newer whatever [AppInfo.version] becomes.
  static String get newerVersion {
    final numbers = parseVersion(AppInfo.version)!;
    final minor = numbers.length > 1 ? numbers[1] : 0;
    return '${numbers.first}.${minor + 1}.0';
  }

  /// Settings after the automatic check found [newerVersion]: the row offers
  /// the download, and the tab has its dot (ADR-0017).
  static AppState updateAvailable(AppState app) =>
      _checked(app, LatestRelease(newerVersion), automatic: true);

  /// Settings after a check found nothing newer than this build.
  static AppState upToDate(AppState app) =>
      _checked(app, const LatestRelease(AppInfo.version));

  /// Settings while GitHub has not answered, which it never does here.
  static AppState updateChecking(AppState app) => _checked(
    app,
    const LatestRelease(AppInfo.version),
    gate: Completer<void>(),
  );

  /// Settings after a check could not reach GitHub.
  static AppState updateFailed(AppState app) =>
      _checked(app, const LatestRelease.failed(ReleaseCheckFailure.offline));

  /// Settings while [newerVersion] downloads, 45% of the way, as it stays.
  static AppState updateDownloading(AppState app) => _installed(
    app,
    const <InstallEvent>[InstallEvent.downloading(45)],
    gate: Completer<void>(),
  );

  /// Settings once [newerVersion] has downloaded and Android's installer
  /// is open.
  static AppState updateInstalling(AppState app) =>
      _installed(app, const <InstallEvent>[
        InstallEvent.downloading(100),
        InstallEvent.installing(),
      ]);

  /// Settings after Android would not let the app install: what to allow,
  /// Try again, and the download page.
  static AppState updateNotAllowed(AppState app) =>
      _installed(app, const <InstallEvent>[
        InstallEvent.downloading(100),
        InstallEvent.failed(InstallFailure.notAllowed),
      ]);

  /// "What's new" with three releases, the first newer than this build and
  /// the second this build, so that it carries Installed. Their notes are
  /// as GitHub writes them.
  static AppState releaseNotesListed(AppState app) => GalleryFixtures.state(
    app,
    releaseNotes: FixedReleaseNotes(ReleaseNotes(sampleReleases)),
  );

  /// "What's new" when GitHub could not be reached, which is how the gallery
  /// always finds it: Try again, and the link to GitHub.
  static AppState releaseNotesFailed(AppState app) =>
      GalleryFixtures.state(app, releaseNotes: const NullReleaseNotes());

  /// Three releases newest first, [newerVersion], this build's and an earlier
  /// one, with notes in the shapes the release workflow writes: a heading,
  /// bullets that end in an author and a link, and a closing line in bold.
  static List<PublishedRelease> get sampleReleases => <PublishedRelease>[
    PublishedRelease(
      tag: 'v$newerVersion',
      publishedAt: DateTime.utc(2026, 10, 12, 12),
      body:
          "## What's Changed\n"
          '* **Review by skill** on Today, in every language you learn '
          'by @aaronified in https://example.org/pull/191\n'
          '* Read [the guide](https://example.org/guide) before you start '
          'by @aaronified in https://example.org/pull/195\n'
          '\n'
          '**Full Changelog**: https://example.org/compare/'
          'v${AppInfo.version}...v$newerVersion',
    ),
    PublishedRelease(
      tag: 'v${AppInfo.version}',
      publishedAt: DateTime.utc(2026, 10, 5, 12),
      body:
          "## What's Changed\n"
          '* Stop cutting every speaking listen off 3 seconds after the tap '
          'by @aaronified in https://example.org/pull/193\n'
          '\n'
          '**Full Changelog**: https://example.org/compare/'
          'v0.3.2...v${AppInfo.version}',
    ),
    PublishedRelease(
      tag: 'v0.3.2',
      publishedAt: DateTime.utc(2026, 10, 4, 12),
      body: '',
    ),
  ];

  /// Settings with an install of [newerVersion] started that reports
  /// [events], waiting after the first on [gate] if given.
  static AppState _installed(
    AppState app,
    List<InstallEvent> events, {
    Completer<void>? gate,
  }) {
    final state = GalleryFixtures.state(
      app,
      releases: FixedReleaseCheck(LatestRelease(newerVersion)),
      installer: FixedApkInstaller(events, gate: gate),
      settings: SettingsNotifier()..latestRelease = newerVersion,
    )..shellTab.value = ShellTab.settings;
    unawaited(state.updates.install());
    return state;
  }

  /// Settings with a check started that [answer]s, after [gate] if given.
  static AppState _checked(
    AppState app,
    LatestRelease answer, {
    Completer<void>? gate,
    bool automatic = false,
  }) {
    final state = GalleryFixtures.state(
      app,
      releases: FixedReleaseCheck(answer, gate: gate),
      settings: SettingsNotifier(autoUpdateCheck: automatic),
    )..shellTab.value = ShellTab.settings;
    unawaited(state.updates.check());
    return state;
  }
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
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) => Future<void>.value();

  @override
  Future<void> stop() => Future<void>.value();

  @override
  Future<void> dispose() => Future<void>.value();
}
