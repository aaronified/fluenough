import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/data/course_path.dart';
import '../core/feedback/report.dart';
import '../core/logs/log_entry.dart';
import '../core/models/card.dart';
import '../core/models/card_set.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import '../core/models/number_rules.dart';
import '../core/models/reading.dart';
import '../core/models/romanisation.dart';
import '../core/models/script_guide.dart';
import '../core/models/sound_contrasts.dart';
import '../core/numbers/number_practice.dart';
import '../core/progress/recent_answers.dart' show MasteryLevel;
import '../core/scheduling/placed_review.dart';
import '../core/scheduling/daily_budget.dart';
import '../core/scheduling/daily_timer.dart';
import '../core/scheduling/script_split.dart';
import '../core/scheduling/skill_map.dart';
import '../core/scheduling/session_queue.dart';
import '../core/scheduling/study_hours.dart';
import '../core/network/network_probe.dart';
import '../core/sound/sound_check.dart';
import '../core/speech/speech_engine.dart';
import '../core/tts/clip_player.dart';
import '../core/tts/tts_engine.dart';
import '../core/tts/volume_monitor.dart';
import '../core/updates/apk_install.dart';
import '../core/updates/release_check.dart';
import '../core/updates/release_notes.dart';
import '../core/data/themes.dart';
import '../core/decks/adult_gate.dart';
import '../core/models/fact.dart';
import '../core/models/situation.dart';
import '../core/scheduling/ability.dart';
import '../core/scheduling/daily_fact.dart';
import '../core/scheduling/lesson.dart';
import '../core/scheduling/lesson_sets.dart';
import 'added_decks.dart';
import '../core/decks/deck_index.dart';
import 'app_log.dart';
import 'card_media.dart';
import 'card_sets.dart';
import 'unlocks.dart';
import 'daily_plan.dart';
import '../core/decks/ipa_course.dart';
import 'deck_catalog.dart';
import 'deck_downloads.dart';
import 'font_check.dart';
import 'deck_import.dart';
import 'features.dart';
import 'language_choice.dart';
import 'language_skills.dart';
import 'links.dart';
import 'log_files.dart';
import 'mail_share.dart';
import 'fsrs_tuner.dart';
import 'memory_progress.dart';
import 'pacing.dart';
import 'profile.dart';
import 'reminder_scheduler.dart';
import 'reminder_service.dart';
import 'reminder_words.dart';
import 'repository_decks.dart';
import 'backup_files.dart';
import 'backup_store.dart';
import 'backups.dart';
import 'reviewing.dart';
import 'session.dart';
import 'settings.dart';
import 'shell_tab.dart';
import 'skill.dart';
import 'system_settings.dart';
import 'update_checker.dart';

/// A native language that teaches a course, as the learner is offered it
/// (ADR-0036): the language, and how many of the language's written units
/// its decks teach, of how many. Both are null for a language with no
/// path, where coverage is not defined.
typedef NativeOption = ({LanguageInfo native, int? covered, int? total});

/// The current time. Injected so that tests and the gallery can fix it.
typedef Clock = DateTime Function();

/// A language the learner can choose to learn: from the decks on GitHub's
/// index (#210), or the catalog's where nothing downloads. [taughtFrom] is
/// the name of the language its decks teach from when the learner speaks
/// none of those it is taught from ("Taught from English"); [size] what
/// choosing it downloads, 0 when it is on the phone.
typedef OfferedLanguage = ({
  String code,
  String name,
  String? icon,
  String? taughtFrom,
  int size,
});

/// Where the deck catalog is in loading.
enum CatalogStatus { loading, ready, failed }

/// Whether the phone can speak a language.
enum VoiceStatus {
  /// Not asked yet, or the answer is not back. Treated as no voice.
  checking,
  available,
  missing,
}

/// What came of switching speaking on (#89, ADR-0014).
enum SpeechSetup {
  /// The recogniser is ready.
  ready,

  /// The microphone permission was refused.
  refused,

  /// The microphone is allowed, but the phone has no speech recogniser.
  noRecogniser,
}

/// Whether the phone can recognise speech in a language (#89, ADR-0014).
enum SpeechStatus {
  /// The recogniser has not been readied: speaking has not been switched
  /// on since launch, the microphone was refused, or the phone has no
  /// recogniser. Says nothing of the Settings switch.
  off,

  /// The recogniser has not answered yet.
  checking,

  /// Recognised on the phone, as far as is known: listens ask to stay on
  /// it.
  onDevice,

  /// Recognised only online, which the learner has not allowed.
  onlineOnly,

  /// Recognised only online, and the learner has allowed it.
  online,

  /// Not recognised on this phone, on the device or online.
  missing,
}

/// A deck's numbers, as its row and its detail screen show them.
///
/// [due] and [fresh] are what a session on the deck would drill right now,
/// in every skill the learner has on; the two together are what "Review all
/// due" runs. A deck's badge counts [due] only.
typedef DeckCounts = ({int due, int fresh, int learned});

/// Everything the interface reads and does, in one place (ADR-0007).
///
/// Services arrive through the constructor, so that a test builds the whole
/// app from fakes: [AppState.test]. Screens reach this through `AppScope`
/// and never import a concrete service.
///
/// **What notifies.** This object notifies only on app-level changes: the
/// catalog loading, voices being checked, and the current profile or the
/// profile list changing. Settings and progress change far more often and
/// have their own notifiers, [settings] and [progress]; listen to those with
/// a `ListenableBuilder` where they are shown.
class AppState extends ChangeNotifier {
  AppState({
    required DeckCatalog catalog,
    required this.progress,
    required this._tts,
    this._clips = const NullClipPlayer(),
    this._media,
    this._speech = const NullSpeechEngine(),
    this.soundCheck = const NullSoundCheck(),
    this.networkProbe = const NullNetworkProbe(),
    this.features = const FeatureRegistry.shipped(),
    this._clock = DateTime.now,
    this.logFiles = const PickerLogFiles(),
    this._backupFiles = const PickerBackupFiles(),
    this._backupStore,
    this.deckFiles = const PickerDeckFiles(),
    this.links = const LauncherLinks(),
    this.systemSettings = const NullSystemSettings(),
    ReminderScheduler reminderScheduler = const NullReminderScheduler(),
    this.reports = const NullReportSender(),
    this._mailShare = const NullMailShare(),
    AppLog? log,
    this._releases = const NullReleaseCheck(),
    this.releaseNotes = const NullReleaseNotes(),
    this._installer = const NullApkInstaller(),
    this._downloads = const NullDownloadStore(),
    this._fitRunner = fitInIsolate,
    this._paceRunner = paceInIsolate,
    this.deckDownloads,
    SettingsNotifier? settings,
    VolumeMonitor? volume,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
    Random? random,
    this._secureRandom,
  }) : assert(profiles.isNotEmpty, 'there is always a profile'),
       random = random ?? Random(),
       volume = volume ?? FixedVolumeMonitor(),
       deckCatalog = catalog,
       settings = settings ?? SettingsNotifier(),
       _ownsSettings = settings == null,
       log = log ?? AppLog(),
       _ownsLog = log == null,
       _profiles = List<Profile>.of(profiles),
       _currentProfileId = currentProfileId ?? profiles.first.id {
    // What is pending follows progress, settings and this state's own
    // changes: the catalog, voices and the profile.
    for (final source in <Listenable>[this, this.settings, progress]) {
      source.addListener(_forgetPending);
    }
    progress.addListener(_progressChanged);
    this.settings.addListener(_settingsChanged);
    addListener(_structureChanged);
    _loggedTab = shellTab.value;
    shellTab.addListener(_logTab);
    shellTabMoving.addListener(_logTab);
    deckDownloads?.onFilesChanged = _filesDownloaded;
    deckDownloads
      ?..wantsFont = fontCheck.wants
      ..usesFont = fontCheck.uses;
    this.settings.addListener(_reviewerToDownloads);
    _reviewerToDownloads();
    this.settings.addListener(_languageShownChanged);
    addListener(_rememberShown);
    reminders = ReminderService(
      scheduler: reminderScheduler,
      settings: this.settings,
      available: () => features.isAvailable(Feature.reminder),
      forecast: dueForecast,
      words: () => reminderWordsFor(PlatformDispatcher.instance.locale),
      clock: now,
      // A tap on a reminder opens Today.
      onOpened: () => shellTab.value = ShellTab.today,
      log: (message) => this.log.event(message),
    );
  }

  /// The daily reminder (#90): its permission, its plan and the
  /// notifications. Switched on and off in Settings > Reminders.
  late final ReminderService reminders;

  /// The language shown when this state last notified, so that a change
  /// in settings that shows another rebuilds every screen that reads this
  /// state (#461), as the catalog loading or the profile changing do.
  String? _lastShown;
  bool _lastProgressAll = false;
  bool _lastAdult = false;

  void _rememberShown() {
    _lastAdult = settings.adultContent;
    _lastShown = shownLanguage;
    _lastProgressAll = progressShowsAll;
  }

  void _languageShownChanged() {
    final shown = shownLanguage;
    final all = progressShowsAll;
    final adult = settings.adultContent;
    if (shown == _lastShown && all == _lastProgressAll && adult == _lastAdult) {
      return;
    }
    _lastAdult = adult;
    _lastShown = shown;
    _lastProgressAll = all;
    notifyListeners();
  }

  /// A reviewer is offered a deck update when only proposals changed, as
  /// they see them; a learner is not (#444).
  void _reviewerToDownloads() => deckDownloads?.reviewer = settings.reviewDecks;

  /// Logs the tab the shell settled on. While the pages slide the bar
  /// follows them through tabs nobody opened, so nothing is logged until
  /// they stop, and a drag that springs back logs nothing.
  void _logTab() {
    if (shellTabMoving.value || shellTab.value == _loggedTab) return;
    _loggedTab = shellTab.value;
    log.event('Opened tab ${_loggedTab.name}');
  }

  ShellTab _loggedTab = ShellTab.today;

  /// Where a drill's chance comes from, such as the order of a question's
  /// options: seeded in tests and the gallery, so that they repeat.
  final Random random;

  /// Whether the phone's media volume is at zero (ADR-0026).
  final VolumeMonitor volume;

  /// Whether a question that needs sound should ask for the volume to be
  /// raised: sound is on in the app, but the phone is at zero. Such
  /// questions are still asked; with sound off they are skipped instead.
  bool get needsVolume => settings.soundOn && volume.muted;

  /// An app on fakes, for widget tests: the repository's decks, as a phone
  /// that downloaded every language has them, unless [decks] is given, decks added in memory, no voices unless [tts] has some, empty in-memory
  /// progress, links that open unless [links] says otherwise, phone settings
  /// that open nothing unless [systemSettings] does, no network
  /// for the update check unless [releases] answers, none for the release
  /// notes unless [releaseNotes] does, no download unless
  /// [installer] does one, a clock fixed at [now] — by default Monday 28
  /// September 2026, 19:00, the evening the design is drawn on — and chance
  /// seeded the same every time.
  factory AppState.test({
    DeckSource? decks,
    TtsEngine tts = const NullTtsEngine(),
    ClipPlayer clips = const NullClipPlayer(),
    CardMedia media = const NoCardMedia(),
    SpeechEngine speech = const NullSpeechEngine(),
    SoundCheckEngine soundCheck = const NullSoundCheck(),
    NetworkProbe networkProbe = const NullNetworkProbe(),
    ProgressStore? progress,
    FeatureRegistry features = const FeatureRegistry.shipped(),
    DateTime? now,
    LogFiles logFiles = const PickerLogFiles(),
    BackupFiles backupFiles = const PickerBackupFiles(),
    BackupStore? backupStore,
    DeckFiles deckFiles = const PickerDeckFiles(),
    DeckStore? addedDecks,
    LinkOpener? links,
    SystemSettings systemSettings = const NullSystemSettings(),
    ReminderScheduler reminderScheduler = const NullReminderScheduler(),
    ReportSender reports = const NullReportSender(),
    MailShare mailShare = const NullMailShare(),
    AppLog? log,
    ReleaseCheckEngine releases = const NullReleaseCheck(),
    ReleaseNotesEngine releaseNotes = const NullReleaseNotes(),
    ApkInstaller installer = const NullApkInstaller(),
    DownloadStore downloads = const NullDownloadStore(),
    FitRunner fitRunner = fitInPlace,
    PaceRunner paceRunner = paceInPlace,
    DeckDownloads? deckDownloads,
    SettingsNotifier? settings,
    VolumeMonitor? volume,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
  }) {
    final fixed = now ?? DateTime(2026, 9, 28, 19);
    final state = AppState(
      catalog: DeckCatalog(
        decks ?? RepositoryDeckSource(),
        added: addedDecks ?? MemoryDeckStore(),
      ),
      progress: progress ?? MemoryProgress(),
      tts: tts,
      clips: clips,
      media: media,
      speech: speech,
      soundCheck: soundCheck,
      networkProbe: networkProbe,
      features: features,
      clock: () => fixed,
      logFiles: logFiles,
      backupFiles: backupFiles,
      backupStore: backupStore ?? MemoryBackupStore(),
      deckFiles: deckFiles,
      links: links ?? FixedLinks(),
      systemSettings: systemSettings,
      reminderScheduler: reminderScheduler,
      reports: reports,
      mailShare: mailShare,
      log: log,
      releases: releases,
      releaseNotes: releaseNotes,
      installer: installer,
      downloads: downloads,
      fitRunner: fitRunner,
      paceRunner: paceRunner,
      deckDownloads: deckDownloads,
      settings: settings,
      volume: volume,
      profiles: profiles,
      currentProfileId: currentProfileId,
      random: Random(0),
      secureRandom: Random(1),
    );
    // Past the first-launch setup (#53, #117), unless a test brings its
    // own: speaking English, and learning every language.
    if (settings == null) {
      state.settings
        ..spokenLanguages = const <String>['en']
        ..learningChosen = true;
    }
    return state;
  }

  /// Which features are switched on. Read it; wrap what it says is incoming
  /// in `IncomingFeature`.
  final FeatureRegistry features;

  /// The learner's settings. Has its own notifier.
  final SettingsNotifier settings;

  /// The font check (#611): what to ask the learner about the scripts of
  /// their courses, and what their answers do.
  FontCheck get fontCheck =>
      _fontCheck ??= FontCheck(settings: settings, downloads: deckDownloads);
  FontCheck? _fontCheck;

  /// Scheduling state and the review log. Has its own notifier.
  final ProgressStore progress;

  /// Where the review log's backup is saved and read from (#20).
  final LogFiles logFiles;

  final BackupFiles _backupFiles;
  final BackupStore? _backupStore;

  /// Backing up and restoring the whole app, and the backups kept on the
  /// phone (#470). Has its own notifier.
  late final Backups backups = Backups(
    settings: settings,
    progress: progress,
    store: _backupStore ?? MemoryBackupStore(),
    files: _backupFiles,
    clock: _clock,
    log: log,
    languagesOnPhone: () => deckDownloads?.languagesOnPhone ?? <String>{},
    restored: _downloadRestored,
  );

  /// After a restore, the languages the backup lists that are not on the
  /// phone download, one after another, with the usual progress.
  void _downloadRestored(List<String> languages) {
    final downloads = deckDownloads;
    if (downloads == null) return;
    unawaited(() async {
      for (final code in languages) {
        if (_disposed) return;
        if (downloads.languagesOnPhone.contains(code)) continue;
        try {
          await downloadLanguage(code);
        } on Object catch (e) {
          log.warning(
            'Restored language $code not downloaded: ${e.runtimeType}',
          );
        }
      }
    }());
  }

  /// Where a deck to add is read from, and its template saved to (#22).
  final DeckFiles deckFiles;

  /// Opens links in the browser, or the app that handles them.
  final LinkOpener links;

  /// Opens the phone's own settings: Settings > Voices' "Install voices in
  /// phone settings".
  final SystemSettings systemSettings;

  /// Where a report from the bug icon goes once mail is on (ADR-0021): the
  /// reporter's mail app, or nowhere in a build that was given none.
  final ReportSender reports;

  /// Reviewer mode (docs/plans/deck-browser.md): the rater code, the
  /// reviews kept until sent, and the mail that sends them to [AppLinks.feedbackEmail]
  /// through [_mailShare], the phone's share.
  late final Reviewing reviewing = Reviewing(
    settings: settings,
    clock: _clock,
    random: _secureRandom ?? Random.secure(),
    share: _mailShare,
    address: AppLinks.feedbackEmail,
    deckById: reviewDeckById,
    log: log,
  );
  final MailShare _mailShare;

  /// Where rater codes come from: the phone's secure source, unless a test
  /// gives a seeded one.
  final Random? _secureRandom;

  /// The app's own log (#162): errors, warnings and key events, which
  /// Settings shows and a report attaches if the reporter agrees.
  final AppLog log;
  final bool _ownsLog;

  /// Settings' "Check for updates", the check at launch, and installing
  /// what it finds (ADR-0017). Has its own notifier; what it finds is kept
  /// in [settings].
  late final UpdateChecker updates = UpdateChecker(
    engine: _releases,
    settings: settings,
    clock: _clock,
    installer: _installer,
    downloads: _downloads,
    backUp: (version) => backups.keep(BackupKind.update, forVersion: version),
  );
  final ReleaseCheckEngine _releases;

  /// Settings' "What's new": the app's recent releases and their notes,
  /// fetched when the page opens and never before (ADR-0031).
  final ReleaseNotesEngine releaseNotes;
  final ApkInstaller _installer;
  final DownloadStore _downloads;

  /// Fits FSRS to the learner: Settings' "Adjust to me", and the automatic
  /// refit after a review (ADR-0035). Has its own
  /// notifier.
  late final FsrsTuner tuner = FsrsTuner(
    progress: progress,
    clock: _clock,
    runner: _fitRunner,
    log: log,
  );
  final FitRunner _fitRunner;

  /// How each skill is paced beside how it started: How you learn, and
  /// Today's strip and tile marks. Worked out off the main thread, only
  /// when asked for. Has its own notifier.
  late final Pacing pacing = Pacing(
    progress: progress,
    clock: _clock,
    runner: _paceRunner,
  );
  final PaceRunner _paceRunner;

  /// The catalog loader. Screens read decks through [decks] and [deckById];
  /// this is exposed so that gallery fixtures can share one loaded catalog.
  final DeckCatalog deckCatalog;

  /// Downloads the decks from GitHub and keeps them up to date (#210,
  /// ADR-0037). Has its own notifier. Null where decks do not download, as
  /// in tests and the gallery: the catalog's decks are then all there is.
  final DeckDownloads? deckDownloads;

  final TtsEngine _tts;

  /// Plays a card's own recording (#518).
  final ClipPlayer _clips;

  final CardMedia? _media;

  /// Where cards' recordings and images are on the phone: those downloaded
  /// with their decks, unless one was given.
  CardMedia get media => _media ?? deckDownloads?.files ?? const NoCardMedia();

  /// The file on the phone of [path], a card's recording or image, or null
  /// where there is none.
  String? mediaFile(String? path) =>
      path == null ? null : media.localPath(path);
  final SpeechEngine _speech;

  /// The microphone and speaker, for the first launch's sound check (#89).
  final SoundCheckEngine soundCheck;

  /// Asked why the network failed, once, after a speech network failure.
  final NetworkProbe networkProbe;
  final Clock _clock;
  final bool _ownsSettings;

  /// The current time, from the injected clock.
  DateTime now() => _clock();

  /// Whether reviews outlive the app: persistence ships and [progress] is a
  /// store that keeps them. Today says so when not.
  bool get progressIsSaved =>
      features.isAvailable(Feature.persistence) && progress.persists;

  /// The tab the shell shows. A notifier of its own, so that a page pushed
  /// over the shell — the summary's "Done", Today's "See all" — can switch
  /// tabs; use `AppNavigator.selectTab` or `AppNavigator.backToShell`.
  final ValueNotifier<ShellTab> shellTab = ValueNotifier<ShellTab>(
    ShellTab.today,
  );

  /// True while the tab pages slide; see `TabPager.moving`.
  final ValueNotifier<bool> shellTabMoving = ValueNotifier<bool>(false);

  // ---------------------------------------------------------------------------
  // Decks

  CatalogStatus _status = CatalogStatus.loading;
  Catalog _catalog = Catalog.empty;
  Object? _loadError;
  Future<void>? _loading;

  CatalogStatus get status => _status;

  /// Why the catalog failed to load, when [status] is [CatalogStatus.failed].
  /// A deck that fails to parse is not this: it is a [BrokenDeck].
  Object? get loadError => _loadError;

  /// Every deck that parsed, in path order. Empty until loaded.
  List<DeckEntry> get decks => _view.decks;

  /// Every deck, adult decks and rude cards too, whatever "Adult content"
  /// says. Only what names a rude word to warn of it reads this: the sound-
  /// alike warning, which hides the word itself (#628).
  List<DeckEntry> get allDecks => _catalog.decks;

  /// The decks the Offensive words review lists: the learner's [decks] and,
  /// only with Adult content on (owner, 2026-10-24, #630: "Require Adult
  /// on"), the adult decks no native speaker has rated yet, which no learner
  /// sees and only a reviewer reads, in the catalog's order.
  List<DeckEntry> get reviewDecks {
    final shown = <String, DeckEntry>{
      for (final entry in decks) entry.path: entry,
    };
    final adult = settings.adultContent;
    return <DeckEntry>[
      for (final entry in _catalog.decks)
        if (isUnratedAdultDeck(entry.deck))
          ?(adult ? entry : null)
        else
          ?shown[entry.path],
    ];
  }

  /// The catalog as the learner has it: without the adult decks and the rude
  /// cards while Adult content is off, so that the counts, lessons, finished
  /// decks and the word sheet read one list (#628).
  Catalog get _view {
    final adult = settings.adultContent;
    if (!identical(_adultOf, _catalog) || _adultOn != adult) {
      _adultOf = _catalog;
      _adultOn = adult;
      _adultScoped = _catalog.forAdult(adult: adult);
    }
    return _adultScoped;
  }

  Catalog? _adultOf;
  bool _adultOn = false;
  Catalog _adultScoped = Catalog.empty;

  /// Every deck file that did not parse, for the "couldn't read" rows.
  List<BrokenDeck> get brokenDecks => _catalog.broken;

  /// The shared theme path (ADR-0010), and one theme on it.
  List<DeckTheme> get themes => _catalog.themes;
  DeckTheme? themeOf(DeckEntry entry) => _catalog.themeById(entry.deck.theme);

  /// The theme each deck is taught under, by deck id: its own, or for a deck
  /// with none, such as grammar, that of a theme deck in its unit of the
  /// course's path. The Decks tab searches by it.
  Map<String, DeckTheme> get themesByDeck {
    final out = <String, DeckTheme>{};
    for (final code in <String>{for (final e in decks) e.language.code}) {
      for (final unit in courseUnits(code)) {
        final theme = unit.map(themeOf).nonNulls.firstOrNull;
        if (theme == null) continue;
        for (final entry in unit) {
          out[entry.id] = theme;
        }
      }
    }
    for (final entry in decks) {
      if (themeOf(entry) case final own?) out[entry.id] = own;
    }
    return out;
  }

  /// The facts that name [card], in [language]'s facts file, for the
  /// languages the learner speaks, each with its text in them, best known
  /// first (#546): what the Facts section at the end of a card's sheet
  /// lists. Empty when none names the card.
  List<CardFact> factsNaming(Card card, LanguageInfo language) {
    final file = _catalog.facts[language.code];
    if (file == null) return const <CardFact>[];
    final spoken = settings.spokenLanguages;
    return <CardFact>[
      for (final fact in factsNamingCard(file.facts, card.id, spoken: spoken))
        (fact: fact, texts: factTexts(fact, spoken)),
    ];
  }

  /// [language]'s situation sheets (#724), or null where it has none.
  SituationsFile? situationsOf(String language) =>
      _catalog.situations[language];

  /// The languages Today's fact can be shown in (#926): those the learner
  /// knows, in their order.
  List<String> get factLanguageChoices => settings.spokenLanguages;

  /// Those of [factLanguageChoices] whose box is checked.
  Set<String> get factLanguagesChecked =>
      checkedFactLanguages(factLanguageChoices, settings.factLanguages);

  /// A tap on [code]'s box of the fact card's menu; the last checked one
  /// stays checked.
  void toggleFactLanguage(String code) {
    settings.factLanguages = toggledFactLanguages(
      factLanguageChoices,
      settings.factLanguages,
      code,
    );
  }

  /// Today's fact for each language the profile learns that has facts
  /// (#48), with its text in each language the learner speaks, best known
  /// first. Choosing one records it as shown today, after this call, so
  /// that it stays today's fact.
  List<TodayFact> todaysFacts() {
    final spoken = settings.spokenLanguages;
    final learned = <String, LanguageInfo>{
      for (final entry in profileDecks) entry.language.code: entry.language,
    };
    // A fact that names a card being studied comes first (#546): a card
    // with a schedule state that is not new, so answered in some skill.
    final studied = <String>{
      for (final key in progress.states.keys) key.cardId,
    };
    final today = <TodayFact>[];
    for (final language in learned.values) {
      final file = _catalog.facts[language.code];
      if (file == null) continue;
      final shown = settings.factsShownFor(language.code);
      final fact = factForToday(
        file.facts,
        spoken: spoken,
        shownAt: shown,
        now: now(),
        studied: studied,
      );
      if (fact == null) continue;
      today.add((
        language: language,
        fact: fact,
        texts: shownFactTexts(fact, spoken, settings.factLanguages),
      ));
      final at = shown[fact.id];
      if (at == null || !isSameDay(at, now())) {
        final code = language.code;
        final id = fact.id;
        final when = now();
        Future<void>.microtask(() => settings.markFactShown(code, id, when));
      }
    }
    return today;
  }

  DeckEntry? deckById(String id) => _view.byId(id);

  /// [deckById], or a deck no native speaker has rated yet (#630): what a
  /// review of it reads, sent from the review screens alone.
  DeckEntry? reviewDeckById(String id) =>
      reviewDecks.where((entry) => entry.id == id).firstOrNull;

  /// The path of [entry]'s course (ADR-0013), or null if it has none.
  CoursePath? pathOf(DeckEntry entry) => _catalog.pathOf(entry);

  /// [language]'s own path (ADR-0036), shared by every native language it
  /// is taught from, with the units it plans and its regions; null if it
  /// has none.
  LanguagePath? languagePathOf(String language) =>
      _catalog.languagePaths[language];

  /// The deck a card came from.
  DeckEntry? deckOf(Card card) => _view.byId(card.deckId);

  /// The decks in the languages the current profile learns, and of those,
  /// only the [shownLanguage]'s while one is chosen (#461): what Today
  /// teaches and reviews, so that its counts and its sessions agree.
  ///
  /// Each language's decks taught from the language its course is learned
  /// from ([courseNative]) come first, then those taught from a language
  /// the learner speaks, best known first (#53); otherwise the catalog's
  /// order holds. A review takes a card shared across native languages from
  /// the first deck that has it, so it is shown as the course teaches it.
  List<DeckEntry> get profileDecks => derived<List<DeckEntry>>(
    'profileDecks',
    () => _learnedDecks(onlyShown: true),
  );

  List<DeckEntry> _learnedDecks({required bool onlyShown}) {
    final profile = currentProfile;
    final shown = onlyShown ? shownLanguage : null;
    final mine = <DeckEntry>[
      for (final entry in decks)
        if (profile.learns(entry.language.code) &&
            LanguageChoice.shows(shown, entry.language.code))
          entry,
    ];
    final natives = <String, String?>{
      for (final code in <String>{for (final e in mine) e.language.code})
        code: courseNative(code),
    };
    int rank(DeckEntry e) => e.deck.native.code == natives[e.language.code]
        ? -1
        : settings.rankOf(e.deck.native.code) ??
              settings.spokenLanguages.length;
    final byRank = mine.indexed.toList()
      ..sort((a, b) {
        final order = rank(a.$2).compareTo(rank(b.$2));
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return <DeckEntry>[for (final (_, entry) in byRank) entry];
  }

  /// Every language the catalog teaches, one per code.
  List<LanguageInfo> get languages => _view.languages;

  /// The languages the language bar at the top of Today, Decks and
  /// Progress offers (#461, #528): those the profile learns that have
  /// decks, in the order the learner chose them ([LanguageChoice.options]).
  /// Progress's All is not one of these.
  List<LanguageInfo> get languageChoices {
    final profile = currentProfile;
    final learned = <String, LanguageInfo>{
      for (final language in languages)
        if (profile.learns(language.code)) language.code: language,
    };
    return <LanguageInfo>[
      for (final code in LanguageChoice.options(
        // The learner's order: as chosen, else as the profile lists them.
        learning: <String>[
          ...<String>{...settings.learningLanguages, ...?profile.languages},
        ],
        available: learned.keys,
      ))
        learned[code]!,
    ];
  }

  /// The language the whole app shows, by code (#461, #528): the one
  /// chosen in the language bar while the profile still learns it, else
  /// the first of [languageChoices]. Null only while there is none.
  String? get shownLanguage => LanguageChoice.shown(
    settings.languageChoice,
    <String>[for (final language in languageChoices) language.code],
  );

  /// Whether [code]'s lessons, decks and numbers show, given the
  /// [shownLanguage].
  bool showsLanguage(String code) => LanguageChoice.shows(shownLanguage, code);

  /// Shows only [code]'s content across the app. Kept in Settings. With
  /// [allOff], as on Progress, it turns Progress's All off too (#528).
  void showLanguage(String code, {bool allOff = false}) {
    settings.languageChoice = code;
    if (allOff) settings.progressAll = false;
  }

  /// Whether Progress counts every language together (#528): its All
  /// button is on, and there is more than one language to count.
  bool get progressShowsAll =>
      settings.progressAll && languageChoices.length > 1;

  /// The language whose numbers Progress shows, or null for every
  /// language's together ([progressShowsAll]).
  String? get progressLanguage => progressShowsAll ? null : shownLanguage;

  /// Loads the catalog, then checks which languages have a voice. Safe to
  /// call more than once; later calls wait on the first.
  Future<void> load() => _loading ??= _load();

  /// Reads the catalog again from its source, for "Try again" after the
  /// catalog failed to load: back to [CatalogStatus.loading], then the same
  /// as [load]. A load already under way is joined rather than repeated.
  Future<void> reload() {
    final loading = _loading;
    if (loading != null && _status == CatalogStatus.loading) return loading;
    deckCatalog.invalidate();
    _status = CatalogStatus.loading;
    _loadError = null;
    notifyListeners();
    return _loading = _load();
  }

  /// Whether decks can be added: the catalog has somewhere to keep them.
  bool get canAddDecks => deckCatalog.added != null;

  /// What adding [text], the file [fileName], as a deck would do (#22).
  DeckCheck checkDeck(String text, String fileName) =>
      checkAddedDeck(text, fileName: fileName, decks: decks);

  /// Keeps [text], the file of [deck], with the decks added before,
  /// replacing one with its id, and reads the catalog again. The path puts
  /// it where its wildcards say (`CoursePath.placing`).
  Future<void> addDeck(Deck deck, String text) async {
    await deckCatalog.added!.save(deck.id, text);
    log.event('Deck added: ${deck.id}');
    await _reloadDecks();
  }

  /// Forgets the added deck [deckId]. Its cards' history stays, and comes
  /// back if the deck is added again.
  Future<void> removeDeck(String deckId) async {
    await deckCatalog.added!.remove(deckId);
    log.event('Deck removed: $deckId');
    await _reloadDecks();
  }

  /// Reads the catalog again without going back to loading, so the screen
  /// that added or removed a deck stays.
  Future<void> _reloadDecks() async {
    deckCatalog.invalidate();
    _catalog = await deckCatalog.load();
    _status = CatalogStatus.ready;
    _loadError = null;
    _mapSkills();
    notifyListeners();
    await refreshVoices();
  }

  // ---------------------------------------------------------------------------
  // Deck downloads (#210, ADR-0037)

  /// Reads the catalog again once downloaded files are on the phone, after
  /// the first load if it is still under way.
  Future<void> _filesDownloaded() async {
    if (_disposed) return;
    await _loading;
    if (!_disposed) await _reloadDecks();
  }

  /// At launch, once the catalog is read: finishes downloads cut short,
  /// then looks for deck updates, at most once a day, unless the learner
  /// has turned that off. In the background.
  Future<void> _afterLaunch() async {
    final downloads = deckDownloads;
    if (downloads == null || _disposed) return;
    // What the Languages page left out is removed now, at this open (#907).
    await removeUnneededDecks();
    if (!settings.learningChosen || _disposed) return;
    final spoken = settings.spokenLanguages;
    await downloads.resume(learningCodes, spoken);
    if (!_disposed && downloads.checksAutomatically) {
      await downloads.checkForUpdates(spoken);
    }
  }

  /// The codes of the languages the current profile learns.
  Set<String> get learningCodes =>
      currentProfile.languages ?? settings.learningLanguages.toSet();

  /// The languages the learner can choose to learn, in the index's order
  /// then the catalog's: every language on GitHub, and every one on the
  /// phone. Where decks do not download, the catalog's languages.
  List<OfferedLanguage> get languagesOnOffer {
    final spoken = settings.spokenLanguages;
    final index = deckDownloads?.index;
    final onPhone = deckDownloads?.languagesOnPhone ?? const <String>{};
    final offered = <String, OfferedLanguage>{};
    for (final language in index?.languages ?? const <IndexLanguage>[]) {
      final natives = language.nativesFor(spoken);
      offered[language.code] = (
        code: language.code,
        name: language.name,
        icon: language.icon,
        taughtFrom: language.taughtFromOther(spoken)
            ? language.natives
                  .where((n) => n.code == natives.first)
                  .firstOrNull
                  ?.name
            : null,
        size: onPhone.contains(language.code)
            ? 0
            : language
                  .filesFor(natives)
                  .fold(0, (sum, file) => sum + file.size),
      );
    }
    for (final language in languages) {
      offered.putIfAbsent(
        language.code,
        () => (
          code: language.code,
          name: language.name,
          icon: language.icon,
          taughtFrom: null,
          size: 0,
        ),
      );
    }
    return offered.values.toList();
  }

  /// Those of [codes] that must download before they can be learned.
  List<String> languagesToDownload(Iterable<String> codes) {
    final downloads = deckDownloads;
    if (downloads == null) return const <String>[];
    final spoken = settings.spokenLanguages;
    return <String>[
      for (final code in codes)
        if (!downloads.isReady(code, spoken)) code,
    ];
  }

  /// The languages the current profile learns with no deck on the phone,
  /// that GitHub offers or may: what the app downloads before it opens, as
  /// after updating from a version that bundled its decks. A language with
  /// some of its decks in is not one: what it lacks, such as the decks of a
  /// language the learner has since said they speak, comes in the
  /// background or as an update, and the app opens offline. Empty until the
  /// catalog is read, and where decks do not download.
  List<String> get missingLanguages {
    final downloads = deckDownloads;
    if (downloads == null ||
        _status == CatalogStatus.loading ||
        !settings.learningChosen) {
      return const <String>[];
    }
    final index = downloads.index;
    return <String>[
      for (final code in learningCodes)
        if (!downloads.hasDecks(code) &&
            (index == null || index.language(code) != null))
          code,
    ];
  }

  /// Downloads [language]'s first decks, and the rest behind them. Null
  /// once it can be learned, else why not.
  Future<DeckDownloadFailure?> downloadLanguage(String language) {
    final downloads = deckDownloads!;
    final started = downloads.download(language, settings.spokenLanguages);
    // The font check asks about the scripts the course is read in, once
    // the index says which they are (#611).
    unawaited(
      downloads.ensureIndex().then((known) {
        if (known) _askAboutFonts(language);
      }),
    );
    return started;
  }

  /// The font check: [language]'s scripts the learner reads that have a
  /// font to download and no answer yet.
  void _askAboutFonts(String language) {
    final fonts = deckDownloads?.index?.language(language)?.fonts;
    if (fonts == null || fonts.isEmpty) return;
    // The language block's script comes first in the index's list.
    final scripts = <String>[for (final font in fonts) font.script];
    final learned = settings.scriptsLearned(language, primary: scripts.first);
    fontCheck.request(scripts.where(learned.contains));
  }

  /// Deletes [language]'s decks from the phone, and stops learning it. Its
  /// progress stays in the review log, by card id, and comes back with its
  /// decks.
  Future<void> removeLanguage(String language) async {
    if (learningCodes.contains(language)) {
      setLearningLanguages(<String>[
        for (final code in learningCodes)
          if (code != language) code,
      ]);
    }
    await deckDownloads!.remove(language);
  }

  /// Tells progress which cards ask for what is heard rather than what it
  /// means ([hearsForm]), so that a right answer there implies Write, not
  /// Recognition (ADR-0034).
  void _mapSkills() {
    final scriptDecks = <String>{
      for (final entry in decks)
        if (needsAlphabet(entry)) entry.id,
    };
    // The decks listed under `alphabet:` in a path are also the script
    // skills' (#556): their answers make Read script and Write script,
    // rebuilt from the log whenever the decks are read.
    // Script-deck answers from before the script was kept per answer
    // count for the course's primary script (#653).
    progress.skills = SkillMap(
      formHeardCards: <String>{
        for (final entry in decks)
          for (final card in entry.cards)
            if (hearsForm(card)) card.id,
      },
      scriptDecks: scriptDecks,
      primaryScripts: <String, String>{
        for (final code in <String>{for (final e in decks) e.language.code})
          code: primaryScript(code),
      },
    );
  }

  Future<void> _load() async {
    try {
      // What is downloaded, before the catalog reads it. Never the network.
      await deckDownloads?.open();
      _catalog = await deckCatalog.load();
      _status = CatalogStatus.ready;
      _mapSkills();
      log.event('Decks loaded: ${decks.length}');
      unawaited(_afterLaunch());
    } catch (error, stack) {
      _loadError = error;
      _status = CatalogStatus.failed;
      log.error(describeError('Decks failed to load', error, stack));
    }
    notifyListeners();
    await refreshVoices();
    // Never asks: only a permission granted before lets the phone be
    // checked at launch (ADR-0014). Not awaited: the check can take
    // seconds, and until it answers speaking waits, not the app.
    unawaited(_checkSpeechQuietly());
  }

  Future<void> _checkSpeechQuietly() async {
    try {
      if (!await _speech.hasPermission() || _disposed) return;
    } catch (e) {
      log.warning('Speech error: permission ${_errorCode(e)}');
      return;
    }
    await startSpeech();
  }

  /// A speech or voice error's code for the app log: the engine's own, or
  /// else the error's type. Never what was said or spoken.
  static String _errorCode(Object error) => switch (error) {
    SpeechError(:final code) || TtsFailure(:final code) => code,
    _ => '${error.runtimeType}',
  };

  // ---------------------------------------------------------------------------
  // Speech recognition (#89, ADR-0014)

  bool? _speechReady;
  bool _speechChecking = false;
  Set<String> _speechLanguages = const <String>{};

  /// Whether the recogniser is ready: null until speaking has been switched
  /// on, false if the microphone was refused or the phone has none.
  bool? get speechReady => _speechReady;

  /// Readies the recogniser and asks which languages it knows. Asks for the
  /// microphone permission if it has not been granted, so call it only when
  /// the learner switches speaking on.
  Future<SpeechSetup> startSpeech() async {
    _speechChecking = true;
    notifyListeners();
    var setup = SpeechSetup.noRecogniser;
    try {
      final ready = await _speech.start();
      _speechReady = ready;
      _speechLanguages = ready ? await _recognised() : const <String>{};
      setup = ready
          ? SpeechSetup.ready
          : await _speech.hasPermission()
          ? SpeechSetup.noRecogniser
          : SpeechSetup.refused;
      if (setup != SpeechSetup.ready) {
        log.warning('Speech error: start ${setup.name}');
      }
    } catch (e) {
      log.warning('Speech error: start ${_errorCode(e)}');
      _speechReady = false;
      _speechLanguages = const <String>{};
    } finally {
      _speechChecking = false;
      if (!_disposed) notifyListeners();
    }
    return setup;
  }

  /// The languages the recogniser lists, or none when it cannot say, which
  /// goes to the app log: every language is then tried on the device.
  Future<Set<String>> _recognised() async {
    try {
      return await _speech.languages();
    } catch (e) {
      log.warning('Speech error: languages ${_errorCode(e)}');
      return const <String>{};
    }
  }

  /// Asks the recogniser again which languages it knows, and forgets what
  /// listens found, for after installing a language pack. Does nothing
  /// unless speaking has been set up, so it never asks for the microphone.
  Future<void> recheckSpeech() async {
    if (_speechReady != true) return;
    settings.forgetFoundSpeech();
    await startSpeech();
  }

  /// Switches speaking on, asking for the microphone first (ADR-0014), or
  /// off. It stays off unless the recogniser is ready. Returns what came of
  /// switching it on, or [SpeechSetup.ready] for switching it off.
  Future<SpeechSetup> setSpeaking(bool on) async {
    if (!on) {
      settings.setSkillEnabled(Skill.speaking, false);
      return SpeechSetup.ready;
    }
    final setup = await startSpeech();
    settings.setSkillEnabled(Skill.speaking, setup == SpeechSetup.ready);
    return setup;
  }

  /// Whether the phone can recognise [language], and where.
  ///
  /// Android 13 and later list only the on-device recogniser's languages,
  /// so one it does not list may still be heard online. A phone that lists
  /// none, because it cannot say, is tried on the device. Either way the
  /// first listen settles it, and is remembered in [settings].
  SpeechStatus speechStatus(LanguageInfo language) {
    if (_speechChecking) return SpeechStatus.checking;
    if (_speechReady != true) return SpeechStatus.off;
    final code = language.code;
    if (settings.speechUnsupported.contains(code)) return SpeechStatus.missing;
    final listed = _speechLanguages.isEmpty || _speechLanguages.contains(code);
    if (listed && !settings.speechNotOnDevice.contains(code)) {
      return SpeechStatus.onDevice;
    }
    return settings.allowsOnlineSpeech(code)
        ? SpeechStatus.online
        : SpeechStatus.onlineOnly;
  }

  /// Whether a speaking drill in [language] can be graded now.
  bool canHear(LanguageInfo language) => switch (speechStatus(language)) {
    SpeechStatus.onDevice || SpeechStatus.online => true,
    _ => false,
  };

  /// Listens for [language]: on the device while it may be recognised
  /// there, otherwise online if the learner allowed it. What a listen finds
  /// out is remembered: a language the device does not know, so that the
  /// drill can ask before going online, and one online does not know
  /// either, which is then [SpeechStatus.missing].
  Future<SpeechHeard> listenFor(LanguageInfo language) async {
    final code = language.code;
    final bool onDevice;
    switch (speechStatus(language)) {
      case SpeechStatus.onDevice:
        onDevice = true;
      case SpeechStatus.online:
        onDevice = false;
      case SpeechStatus.onlineOnly:
        return _logUnheard(
          language,
          const SpeechHeard.failed(SpeechFailure.notOnDevice),
        );
      case SpeechStatus.missing:
        return _logUnheard(
          language,
          const SpeechHeard.failed(SpeechFailure.unsupported),
        );
      case SpeechStatus.off || SpeechStatus.checking:
        return _logUnheard(
          language,
          const SpeechHeard.failed(SpeechFailure.noRecogniser),
        );
    }
    final heard = await _speech.listen(
      bcp47: language.ttsTag,
      onDevice: onDevice,
    );
    if (heard.failed) _logUnheard(language, heard);
    switch (heard.failure) {
      case SpeechFailure.notOnDevice when onDevice:
        settings.foundSpeech(code);
      case SpeechFailure.unsupported:
        settings.foundSpeech(code, unsupported: true);
      default:
    }
    return heard;
  }

  /// Puts a listen that gave nothing to grade in the app log (#162): the
  /// language, why, and the recogniser's own code, or "none" when the app
  /// knew beforehand. Never what was said. Returns [heard].
  SpeechHeard _logUnheard(LanguageInfo language, SpeechHeard heard) {
    final why = heard.failure ?? SpeechFailure.noMatch;
    log.warning(
      'Speech error: ${language.ttsTag} ${why.name} ${heard.code ?? 'none'}',
    );
    return heard;
  }

  /// Stops a listen early, keeping what was heard. A failure goes to the
  /// app log.
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      log.warning('Speech error: stop ${_errorCode(e)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Voices

  final Map<String, bool> _voices = <String, bool>{};

  /// Whether the phone has a voice for [language], by its `ttsTag`.
  ///
  /// A notation has none, and nothing to check: the IPA's examples are said
  /// in their own languages' voices (ADR-0041), and braille is read, not
  /// heard (ADR-0043).
  VoiceStatus voiceStatus(LanguageInfo language) => language.isNotation
      ? VoiceStatus.missing
      : switch (_voices[language.ttsTag]) {
          true => VoiceStatus.available,
          false => VoiceStatus.missing,
          null => VoiceStatus.checking,
        };

  /// Whether the phone can say [language]'s cards: it has the voice, or the
  /// course's other voice stands in for it ([backupVoice]).
  bool hasVoice(LanguageInfo language) =>
      voiceStatus(language) == VoiceStatus.available ||
      backupVoice(language) != null;

  /// The course's other voice that says [language]'s cards while the
  /// deck's own is missing from the phone, or null (#641): another voice
  /// tag of the same course that the phone has, in a script that
  /// [language]'s decks also give each card in (`target_scripts`). The
  /// Perso-Arabic decks are voiced `ur-PK`; with only the Hindi voice,
  /// `hi-IN`, installed, it says each card's Devanagari spelling.
  LanguageInfo? backupVoice(LanguageInfo language) => derived<LanguageInfo?>((
    'backupVoice',
    language.ttsTag,
    language.code,
    language.script,
  ), () => _backupVoice(language));

  LanguageInfo? _backupVoice(LanguageInfo language) {
    // Only once the phone has said the deck's own voice is missing.
    if (language.isNotation || _voices[language.ttsTag] != false) return null;
    for (final other in voiceLanguages) {
      if (other.code == language.code &&
          other.ttsTag != language.ttsTag &&
          other.script != language.script &&
          _voices[other.ttsTag] == true &&
          _spelledIn(language, other.script)) {
        return other;
      }
    }
    return null;
  }

  /// Whether a deck voiced as [language] gives its cards in [script] too,
  /// not only names the script among the language's.
  bool _spelledIn(LanguageInfo language, String script) => derived<bool>(
    ('spelledIn', language.ttsTag, script),
    () => decks.any(
      (d) =>
          d.language.ttsTag == language.ttsTag &&
          d.deck.cards.any((c) => c.targetScripts.containsKey(script)),
    ),
  );

  /// Every voice the course of [code] uses, one language block per voice
  /// tag, in the order its decks name them: `hi-IN` and `ur-PK` for
  /// Hindustani.
  List<LanguageInfo> voiceBlocksOf(String code) => <LanguageInfo>[
    for (final language in voiceLanguages)
      if (language.code == code) language,
  ];

  /// Whether [language] can be heard now: the phone has a voice for it, and
  /// sound is on in Settings. What decides whether listening is drilled;
  /// with sound off it is skipped, as on a phone with no voice at all.
  /// [voiceStatus] stays the phone's own, for the Voices page; [hasVoice] is
  /// what decides whether a speaker shows.
  bool canSpeak(LanguageInfo language) =>
      settings.soundOn && hasVoice(language);

  /// Every voice the app can say a word in: for each language the decks
  /// teach, one block per distinct voice tag its decks name (`hi-IN` and
  /// `ur-PK` for Hindustani, #641), then the languages they teach from,
  /// one per code, where no deck teaches them. The notations, which have
  /// no voice, left out. An IPA card's examples are said in these (ADR-0041).
  List<LanguageInfo> get voiceLanguages {
    // Asked for by every deck's voice check, so kept until the catalog
    // changes.
    if (identical(_voiceCatalog, _catalog)) return _voiceList;
    final found = <String, LanguageInfo>{};
    for (final entry in _catalog.decks) {
      final language = entry.language;
      if (!language.isNotation) {
        found.putIfAbsent(
          '${language.code}/${language.ttsTag}',
          () => language,
        );
      }
    }
    final codes = <String>{for (final language in found.values) language.code};
    for (final entry in _catalog.decks) {
      final native = entry.deck.native;
      if (codes.add(native.code)) {
        found['${native.code}/${native.ttsTag}'] = native;
      }
    }
    _voiceCatalog = _catalog;
    return _voiceList = List<LanguageInfo>.unmodifiable(found.values);
  }

  Catalog? _voiceCatalog;
  List<LanguageInfo> _voiceList = const <LanguageInfo>[];

  /// The language with [code], as the decks name it, or null when none does:
  /// what an example in that language is said in.
  LanguageInfo? languageByCode(String code) {
    for (final language in voiceLanguages) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Asks the engine about every catalog language again, for when the
  /// learner has been off to install a voice.
  Future<void> refreshVoices() async {
    for (final language in voiceLanguages) {
      final tag = language.ttsTag;
      try {
        _voices[tag] = await _tts.isLanguageAvailable(tag);
      } catch (e) {
        log.warning('Voice error: $tag availability ${_errorCode(e)}');
        _voices[tag] = false;
      }
    }
    notifyListeners();
  }

  /// The voices the engine offers for [language]: none when it cannot say,
  /// which goes to the app log.
  Future<List<TtsVoice>> voicesFor(LanguageInfo language) async {
    try {
      return await _tts.voicesFor(language.ttsTag);
    } catch (e) {
      log.warning('Voice error: ${language.ttsTag} voices ${_errorCode(e)}');
      return const <TtsVoice>[];
    }
  }

  /// Speaks [text] in [language] at the learner's speech rate, or slower,
  /// in the voice chosen for it on the Voices page (#123). Completes when
  /// playback ends. Does nothing without a voice, or while sound is off in
  /// Settings.
  ///
  /// Returns the engine's error code when it could not speak, or null. The
  /// error goes to the app log too, by its code and the language, never
  /// the text.
  Future<String?> speak(
    String text,
    LanguageInfo language, {
    bool slower = false,
  }) async {
    if (!settings.soundOn) return null;
    try {
      await _tts.speak(
        text,
        bcp47: language.ttsTag,
        rate: settings.ttsRate(slower: slower),
        voice: settings.voiceFor(language.code),
      );
      return null;
    } catch (e) {
      final code = _errorCode(e);
      log.warning('Voice error: ${language.ttsTag} $code');
      return code;
    }
  }

  /// Says [card]'s target in [language]: its own recording, a person's
  /// voice, where it has one on the phone (#518), else the phone's voice
  /// ([speak]). A recording is only ever of exactly the card's text, so a
  /// sentence with none is always spoken. A recording that cannot play is
  /// logged, and the phone's voice says the card instead.
  Future<String?> speakCard(
    Card card,
    LanguageInfo language, {
    bool slower = false,
  }) async {
    if (!settings.soundOn) return null;
    if (mediaFile(card.audio) case final file?) {
      try {
        // "Slower" plays a recording at 0.7 times its speed.
        await _clips.play(file, rate: slower ? 0.7 : 1);
        return null;
      } catch (e) {
        log.warning('Recording error: ${card.id} ${e.runtimeType}');
      }
    }
    // While the deck's own voice is missing, the course's other voice says
    // the card's spelling in its own script (#641). A card with none, such
    // as a bare mark, is not said.
    if (backupVoice(language) case final backup?) {
      final spelling = card.targetIn(
        backup.script,
        firstScript: language.script,
      );
      return spelling == null ? null : speak(spelling, backup, slower: slower);
    }
    return speak(card.target, language, slower: slower);
  }

  Future<void> stopSpeaking() async {
    await _clips.stop();
    await _tts.stop();
  }

  // ---------------------------------------------------------------------------
  // Profiles

  final List<Profile> _profiles;
  String _currentProfileId;
  int _nextProfile = 1;

  /// Everyone practising on this phone. In memory until #3.
  List<Profile> get profiles => List<Profile>.unmodifiable(_profiles);

  /// The profile practising now. A profile with no languages of its own,
  /// such as the default one, learns those its settings name once the
  /// learner has chosen (#117): profiles are not stored yet (#3), and
  /// settings are. A profile made with its own languages keeps them.
  Profile get currentProfile {
    final profile = profileById(_currentProfileId) ?? _profiles.first;
    final chosen = settings.learningLanguages;
    return chosen.isEmpty || profile.languages != null
        ? profile
        : profile.copyWith(languages: chosen.toSet());
  }

  Profile? profileById(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Makes [id] the current profile. Checking a PIN first is the caller's
  /// business: see [checkPin].
  void selectProfile(String id) {
    if (id == _currentProfileId || profileById(id) == null) return;
    _currentProfileId = id;
    notifyListeners();
  }

  /// Sets the languages the current profile learns (#117): its own, if it
  /// was made with some, else the setting a profile without its own follows.
  void setLearningLanguages(List<String> codes) {
    final i = _profiles.indexWhere((p) => p.id == _currentProfileId);
    final at = i < 0 ? 0 : i;
    final profile = _profiles[at];
    if (profile.languages == null) {
      settings.learningLanguages = codes;
      return;
    }
    _profiles[at] = profile.copyWith(languages: codes.toSet());
    notifyListeners();
  }

  /// Adds a profile and returns it. It does not become current; call
  /// [selectProfile] for that.
  Profile createProfile({
    required String name,
    required Set<String> languages,
    AvatarShape shape = AvatarShape.cookie,
    AvatarTone tone = AvatarTone.secondary,
    String? pin,
    String nativeLanguage = 'en',
  }) {
    var id = 'profile-${_nextProfile++}';
    while (profileById(id) != null) {
      id = 'profile-${_nextProfile++}';
    }
    final profile = Profile(
      id: id,
      name: name.trim(),
      languages: Set<String>.unmodifiable(languages),
      shape: shape,
      tone: tone,
      pin: pin,
      nativeLanguage: nativeLanguage,
    );
    _profiles.add(profile);
    notifyListeners();
    return profile;
  }

  /// Whether [pin] opens [profileId]. A profile without a PIN opens with any.
  bool checkPin(String profileId, String pin) {
    final profile = profileById(profileId);
    return profile != null && (profile.pin == null || profile.pin == pin);
  }

  // ---------------------------------------------------------------------------
  // Sessions

  /// The modes a session may use: skills the learner has switched on, whose
  /// drill is available, and which the scheduler knows.
  Set<DrillMode> get sessionModes => _modes(ignorePauses: false);

  Set<DrillMode> _modes({required bool ignorePauses}) => <DrillMode>{
    for (final skill in Skill.values)
      if (settings.isEnabled(skill) &&
          (ignorePauses || !settings.isPaused(skill, now())) &&
          features.isAvailable(skill.feature))
        ...skill.modes,
  };

  /// Whether a pair counts as due, as Today counts it: in the decks the
  /// profile learns, in the skills switched on, and not set aside.
  bool Function(ProgressKey key) _countsAsDue({bool onlyShown = true}) {
    final modes = _modes(ignorePauses: true);
    final learned = <String>{
      for (final entry
          in onlyShown ? profileDecks : _learnedDecks(onlyShown: false))
        for (final card in entry.cards) card.id,
    };
    final leeches = progress.leechEffects;
    return (key) =>
        learned.contains(key.cardId) &&
        modes.contains(key.mode) &&
        !leeches.isSetAside(key);
  }

  /// Cards due tomorrow, as Today will count them: in the decks the profile
  /// learns, in the skills switched on, and not set aside.
  int dueTomorrow() => progress.dueTomorrow(now(), counts: _countsAsDue());

  /// Cards due by the end of each of the next [days] days, counted as Today
  /// counts them and across every language the profile learns (the language
  /// bar's choice does not narrow it): index 0 is today. What the daily
  /// reminder is planned from (#90).
  List<int> dueForecast({int days = 7}) => progress.dueByDay(
    now(),
    days: days,
    counts: _countsAsDue(onlyShown: false),
  );

  /// Whether this version can drill anything in [entry]: some card has a
  /// mode whose drill is available. A grammar deck cannot until its drill
  /// ships (#14). The learner's own skill switches do not count here.
  bool canDrill(DeckEntry entry) {
    final shipped = <DrillMode>{
      for (final skill in Skill.values)
        if (features.isAvailable(skill.feature)) ...skill.modes,
    };
    return entry.cards.any(
      (card) => card
          .modesIn(ttsAvailable: true, siblings: siblingsOf(card))
          .any(shipped.contains),
    );
  }

  /// The languages with something to do in Today's session, each its own
  /// session (`DrillRequest.today(language:)`), in the order the learner
  /// chose to learn them, then the decks' order.
  List<LanguageInfo> get todayLanguages {
    final all = <String, LanguageInfo>{
      for (final entry in profileDecks) entry.language.code: entry.language,
    };
    final chosen = settings.learningLanguages;
    final order = <String>[
      ...chosen.where(all.containsKey),
      ...all.keys.where((code) => !chosen.contains(code)),
    ];
    return <LanguageInfo>[
      for (final (index, code) in order.indexed)
        // A language not worked out yet has nothing shown until it is.
        if (lazyFor<bool>(
              'hasToday',
              code,
              () => buildSession(DrillRequest.today(language: code)).isNotEmpty,
              first: firstLanguage(index),
            ) ??
            false)
          all[code]!,
    ];
  }

  /// The languages the summary after [finished]'s part of Today offers
  /// next (#528): the others of [languageChoices], in their order, with
  /// something left in their own session. Starting one switches the
  /// language bar to it.
  List<LanguageInfo> nextTodayLanguages(String finished) => <LanguageInfo>[
    for (final language in languageChoices)
      if (language.code != finished &&
          buildSession(DrillRequest.today(language: language.code)).isNotEmpty)
        language,
  ];

  /// The queue for [request], built by [SessionQueue] from the catalog, the
  /// progress store, the settings, the feature registry and the voices.
  ///
  /// Today's counts, a deck's counts and the drill itself all come from
  /// here, so they always agree.
  /// [ignorePauses] builds it as if no skill were paused: a pause lasts an
  /// hour and does not make a deck finished, so [notStudiedIn] ignores it.
  SessionQueue buildSession(DrillRequest request, {bool ignorePauses = false}) {
    // A queue is immutable, so one built for the same request is shared
    // until progress, settings or this state change (#852).
    List<String>? sorted(Iterable<String>? values) =>
        values == null ? null : (values.toList()..sort());
    final key = (
      'buildSession',
      sorted(request.deckIds)?.join('\u0000'),
      request.skill,
      sorted(request.skills?.map((s) => s.name))?.join(','),
      sorted(request.tags)?.join('\u0000'),
      request.newOnly,
      request.numbers,
      request.untaught,
      request.revise,
      request.lesson,
      request.daily,
      request.language,
      request.limit,
      sorted(request.cardIds)?.join('\u0000'),
      request.script,
      ignorePauses,
    );
    // The cache is per language, so an answer in one leaves the others'
    // queues cached (#852). A request over several languages is scoped '*'.
    var scope = request.language;
    if (scope == null && request.deckIds != null) {
      for (final id in request.deckIds!) {
        final code = deckById(id)?.language.code;
        scope = scope == null || scope == code ? code : '*';
      }
    }
    scope ??= '*';
    // Approximation: the clock counts in 30 second steps, so a card that
    // falls due shows up to 30 seconds late in a cached queue.
    final stamp = _stampOf(scope);
    final cache = _sessions.putIfAbsent(scope, _SessionCache.new);
    if (cache.stamp != stamp) {
      cache.queues.clear();
      cache.stamp = stamp;
    }
    return cache.queues.putIfAbsent(key, () {
      sessionBuilds[scope!] = (sessionBuilds[scope] ?? 0) + 1;
      return _buildSession(request, ignorePauses: ignorePauses);
    });
  }

  // Versions that say what a cached queue was built from (#852). An answer
  // follows the progress store's own version of its language (a baseline
  // change touches them all); any other change to progress, a settings
  // change and a structural change (decks, voices, profile) bump the rest.
  final Map<String, _SessionCache> _sessions = <String, _SessionCache>{};
  int _anyProgressVersion = 0;
  int _otherProgressVersion = 0;
  int _settingsVersion = 0;
  int _structureVersion = 0;
  String? _recordingLanguage;

  /// How many queues were built, by scope, for the tests: no answer may
  /// build one for a language it did not touch.
  @visibleForTesting
  final Map<String, int> sessionBuilds = <String, int>{};

  void _progressChanged() {
    _anyProgressVersion++;
    final language = _recordingLanguage;
    if (language == null) {
      _otherProgressVersion++;
      // An import or a restore changes the log other than at its end; a
      // refit does not, and keeps what was counted.
      final length = progress.log.length;
      if (_newWordsAt?.read != length) _newWordsAt = null;
      if (_timesRead != length) {
        _answerTimes.clear();
        _timesRead = 0;
      }
    }
  }

  void _settingsChanged() => _settingsVersion++;

  final Map<String, _Kept> _keptValues = <String, _Kept>{};

  /// [compute]'s value for [key] about language [code], kept until that
  /// language's progress, the settings or the structure change: an answer
  /// in another language leaves it (#853).
  T keptFor<T>(String code, Object key, T Function() compute) {
    final stamp = _stampOf(code);
    final kept = _keptValues.putIfAbsent(code, _Kept.new);
    if (kept.stamp != stamp) {
      kept.values.clear();
      kept.stamp = stamp;
    }
    return kept.values.putIfAbsent(key, compute) as T;
  }

  void _structureChanged() {
    if (!_lazyNotifying) _structureVersion++;
  }

  /// What a value kept for language [scope] ('*' for all) was worked out
  /// from. Approximation: the clock counts in 30 second steps, so a card
  /// that falls due shows up to 30 seconds late in a kept value.
  Object _stampOf(String scope) => (
    scope == '*' ? _anyProgressVersion : progress.versionOf(scope),
    _otherProgressVersion,
    _settingsVersion,
    _structureVersion,
    now().millisecondsSinceEpoch ~/ 30000,
  );

  // Batching (#852): Today's value for a language that is not among the
  // first few is worked out in an idle slot, one language at a time, and
  // until then the last one worked out shows, so that no frame works out
  // every language of a learner of forty.
  static const int _lazyAfter = 4;
  final Map<String, (Object, Object?)> _lazy = <String, (Object, Object?)>{};
  final Map<String, void Function()> _lazyPending = <String, void Function()>{};
  bool _lazyScheduled = false;
  bool _lazyNotifying = false;

  /// [compute]'s value for [kind] of language [code], the one worked out
  /// for the current stamp, or when [first] (one of the first languages)
  /// worked out now. Otherwise the last value, or null when there is none
  /// yet, and a refresh is queued.
  T? lazyFor<T>(
    String kind,
    String code,
    T Function() compute, {
    required bool first,
  }) {
    final key = '$kind/$code';
    final stamp = _stampOf(code);
    final kept = _lazy[key];
    if (kept != null && kept.$1 == stamp) return kept.$2 as T?;
    if (first || _lazyOff) {
      final value = compute();
      _lazy[key] = (stamp, value);
      _lazyPending.remove(key);
      return value;
    }
    _lazyPending[key] = () => _lazy[key] = (_stampOf(code), compute());
    _scheduleLazy();
    return kept?.$2 as T?;
  }

  /// Whether the language at [index] of Today's order is one of those
  /// worked out at once.
  static bool firstLanguage(int index) => index < _lazyAfter;

  /// Set by the tests, which have no idle slots to wait for.
  @visibleForTesting
  bool lazyOff = false;
  bool get _lazyOff => lazyOff;

  void _scheduleLazy() {
    if (_lazyScheduled || _disposed) return;
    _lazyScheduled = true;
    try {
      SchedulerBinding.instance.scheduleTask<void>(_runLazy, Priority.idle);
    } catch (_) {
      _lazyScheduled = false;
      _lazyOffNow();
    }
  }

  /// Without a scheduler there is nothing to wait for: work the queue out.
  void _lazyOffNow() {
    while (_lazyPending.isNotEmpty) {
      _lazyPending.remove(_lazyPending.keys.first)!();
    }
  }

  void _runLazy() {
    _lazyScheduled = false;
    if (_disposed || _lazyPending.isEmpty) return;
    _lazyPending.remove(_lazyPending.keys.first)!();
    // Tell the screens without making every kept value stale.
    _lazyNotifying = true;
    try {
      notifyListeners();
    } finally {
      _lazyNotifying = false;
    }
    if (_lazyPending.isNotEmpty) _scheduleLazy();
  }

  /// Words first drilled today, counted from the log once and then from
  /// the answers added since, so an answer costs one event and not the
  /// whole log. [now] is the clock.
  int newWordsToday(DateTime now) {
    final today = dateOnly(now);
    final log = progress.log;
    var at = _newWordsAt;
    if (at == null || at.day != today || log.length < at.read) {
      at = _newWordsAt = _NewWords(today);
    }
    for (var i = at.read; i < log.length; i++) {
      final e = log[i];
      if (e.at.isBefore(today)) {
        at.earlier.add(e.cardId);
      } else if (isSameDay(e.at, now)) {
        at.todays.add(e.cardId);
      }
    }
    at.read = log.length;
    return at.todays.where((id) => !at!.earlier.contains(id)).length;
  }

  _NewWords? _newWordsAt;

  SessionQueue _buildSession(
    DrillRequest request, {
    bool ignorePauses = false,
  }) {
    final ids = request.deckIds;
    final language = request.language;
    // A request that names a language takes its decks even while the bar
    // shows another, as the summary offers the next language (#528).
    final decks = ids == null
        ? <DeckEntry>[
            for (final entry
                in language == null
                    ? profileDecks
                    : _learnedDecks(onlyShown: false))
              if (language == null || entry.language.code == language) entry,
          ]
        : <DeckEntry>[
            for (final entry in this.decks)
              if (ids.contains(entry.id)) entry,
          ];
    final tags = request.tags;
    List<Card> tagged(Iterable<Card> cards) => <Card>[
      for (final card in cards)
        if (tags.isEmpty || card.tags.any(tags.contains)) card,
    ];
    // The script decks' Recognition and Write are the Script tile's, apart
    // from the word skills' (owner, 2026-10-24).
    final split = ScriptSplit(progress.skills.scriptDecks);
    final scope = request.script;
    final cards = split.cardsFor(
      scope,
      tagged(<Card>[for (final entry in decks) ...entry.cards]),
    );

    // A named skill is drilled even if switched off in Settings, as the
    // deck page offers it, but not while it is paused.
    final named = request.named;
    final modes = split.modesFor(
      scope,
      named == null
          ? _modes(ignorePauses: ignorePauses)
          : <DrillMode>{
              for (final skill in named)
                if (features.isAvailable(skill.feature) &&
                    (ignorePauses || !settings.isPaused(skill, now())))
                  ...skill.modes,
            },
    );

    // A new pair is a new skill of a word already taught: a word is new
    // once, in its lesson (ADR-0024). Only an untaught request takes those
    // of words not taught yet.
    final newLimit = request.revise ? 0 : cards.length;

    // A skill switched off for a language is not drilled in it (#89), and
    // nothing is heard while sound is off.
    final voiced = derived<Map<String, bool>>(
      'voiced',
      () => <String, bool>{
        for (final entry in this.decks)
          entry.id:
              canSpeak(entry.language) &&
              !settings.isOffFor(Skill.listening, entry.language.code),
      },
    );
    final heard = derived<Map<String, bool>>(
      'heard',
      () => <String, bool>{
        for (final entry in this.decks)
          entry.id:
              canHear(entry.language) &&
              !settings.isOffFor(Skill.speaking, entry.language.code),
      },
    );
    final leeches = progress.leechEffects;
    final fromToday =
        ids == null &&
        request.cardIds == null &&
        !request.revise &&
        !request.lesson &&
        !request.numbers;
    SessionQueue queueOf(
      List<Card> cards, {
      required int newCardLimit,
      bool Function(Card card)? canIntroduce,
    }) => SessionQueue.build(
      cards: cards,
      stateOf: (card, mode) => progress.stateOf(card.id, mode),
      hasVoice: (card) => voiced[card.deckId] ?? false,
      canHear: (card) => heard[card.deckId] ?? false,
      now: now(),
      newCardLimit: newCardLimit,
      isSetAside: (card, mode) =>
          leeches.isSetAside((cardId: card.id, mode: mode)) ||
          split.leavesOut(scope, card, mode),
      reviseAll: request.revise,
      // A session of new cards only offers a card's new pair even while
      // another of its pairs is due, so a deck with reviews due is not
      // taken for finished.
      newEvenIfDue: request.newOnly,
      // Today and a language's review show a few of a deck's known cards
      // for the deck (#680); a deck's own review, a lesson and revising
      // show them all.
      sampleKnown: fromToday,
      // A session of one skill samples a deck by what the deck had today in
      // every skill that is on, as Today's does: else a miss in another
      // skill makes Today ask more cards than the skill's tile then finds.
      sampleModes: fromToday ? _modes(ignorePauses: ignorePauses) : null,
      // What placement credited follows its course's choice (#761), but
      // only in Today: from a deck page the learner can revise or practise
      // placed words, whatever the choice.
      placedOf: fromToday ? placedReviewOf : null,
      modes: modes,
      canIntroduce: canIntroduce,
      siblingsOf: siblingsOf,
    );

    final queue = queueOf(
      cards,
      newCardLimit: newLimit,
      canIntroduce: request.untaught ? null : isTaught,
    );
    return request.newOnly ? queue.withoutDue() : queue;
  }

  // ---------------------------------------------------------------------------
  // The path (#117, ADR-0013)

  List<List<DeckEntry>>? _pendingUnits;
  Set<String>? _placed;

  void _forgetPending() {
    if (_lazyNotifying) return;
    _pendingUnits = null;
    _placed = null;
    _derived.clear();
  }

  /// Values worked out from progress, settings and the decks, kept until
  /// any of them changes, so that a screen rebuilding for another reason
  /// does not work them out again.
  final Map<Object, Object?> _derived = <Object, Object?>{};

  /// [compute]'s value for [key], worked out once and kept until progress,
  /// settings or this state changes. [key] must name what [compute] reads
  /// besides those.
  T derived<T>(Object key, T Function() compute) {
    if (_derived.containsKey(key)) return _derived[key] as T;
    final value = compute();
    _derived[key] = value;
    return value;
  }

  /// Whether placement found the learner already knows [entry]. It reads
  /// Done and Today does not teach it, though it can still be studied.
  ///
  /// Placement is saved by deck id, in the course it was taken in. What it
  /// found holds in the language's other courses too (ADR-0036), so that
  /// changing the language a course is learned from keeps it: a deck reads
  /// as placed where its core's deck in another course was placed, and so
  /// does every deck of a unit of the language's path placed whole in
  /// another course.
  bool isPlaced(DeckEntry entry) =>
      (_placed ??= _placedAcross()).contains(entry.id);

  /// How [card] is reviewed when its deck is placed (#761, #860): by its
  /// course's choice, [SettingsNotifier.placedReviewOf], whatever the card's
  /// history, as placement is by deck. Null for a card of a deck that is not
  /// placed, and for a course set to Keep reviewing, whose placed words are
  /// reviewed as any are.
  PlacedReview? placedReviewOf(Card card, DrillMode mode) {
    final entry = deckById(card.deckId);
    if (entry == null || !isPlaced(entry)) return null;
    final choice = settings.placedReviewOf(entry.language.code);
    return choice == PlacedReview.keepReviewing ? null : choice;
  }

  /// Whether answering [item] writes no review (#761): a pair placement
  /// credited in a course set to Set in stone, which the learner can still
  /// revise or practise from a deck page, as it counts as learnt already.
  bool keepsOutOfLog(SessionItem item) =>
      placedReviewOf(item.card, item.mode) == PlacedReview.setInStone;

  Set<String> _placedAcross() {
    final placed = settings.placedDecks;
    if (placed.isEmpty) return const <String>{};
    final out = <String>{...placed};
    final natives = <String, Set<String>>{};
    for (final entry in decks) {
      natives
          .putIfAbsent(entry.language.code, () => <String>{})
          .add(entry.deck.native.code);
    }
    // The same core's deck in each course: hi-en-market is hi-bn-market.
    for (final id in placed) {
      final entry = deckById(id);
      if (entry == null) continue;
      final language = entry.language.code;
      final prefix = '$language-${entry.deck.native.code}-';
      if (!id.startsWith(prefix)) continue;
      final name = id.substring(prefix.length);
      for (final native in natives[language] ?? const <String>{}) {
        final sibling = '$language-$native-$name';
        if (deckById(sibling) != null) out.add(sibling);
      }
    }
    // A unit placed whole in one course is placed in each, decks its
    // native language alone has included: the courses read one path, so
    // their plans' units line up.
    final byLanguage = <String, List<CoursePath>>{};
    for (final path in _catalog.paths.values) {
      byLanguage.putIfAbsent(path.language, () => <CoursePath>[]).add(path);
    }
    for (final paths in byLanguage.values) {
      for (final from in paths) {
        for (final (i, unit) in from.plan.indexed) {
          if (unit.decks.isEmpty || !unit.decks.every(placed.contains)) {
            continue;
          }
          for (final to in paths) {
            if (i < to.plan.length) out.addAll(to.plan[i].decks);
          }
        }
      }
    }
    return out;
  }

  /// Whether nothing is left that a lesson may teach in [entry]: it is
  /// placed, this version can drill nothing in it, or every card a lesson
  /// may teach is taught. A closed sentence does not count.
  bool _isTaughtOut(DeckEntry entry) =>
      isPlaced(entry) || !canDrill(entry) || notStudiedOpenIn(entry) == 0;

  /// Whether the path is past [entry]: it is placed, this version can drill
  /// nothing in it, or every card in it is learned in the skills on.
  bool isFinished(DeckEntry entry) => keptFor<bool>(entry.language.code, (
    'isFinished',
    entry.id,
  ), () => isPlaced(entry) || !canDrill(entry) || notStudiedIn(entry) == 0);

  /// The units Today teaches new cards from: for each language the profile
  /// learns, the first unit of its course's path that is not finished and
  /// the one after it. The course is the one taught from [courseNative]
  /// ([courseUnits]). A course
  /// without a path is taught as if each deck were a unit, in catalog order,
  /// and a deck its path leaves out follows it as a unit of its own.
  List<List<DeckEntry>> get pendingUnits => _pendingUnits ??= _findPending();

  /// Whether [entry] is in one of the [pendingUnits].
  bool isPending(DeckEntry entry) =>
      pendingUnits.any((unit) => unit.any((e) => e.id == entry.id));

  List<List<DeckEntry>> _findPending() {
    // Every language learned, whichever is shown: where a course's path
    // has got to does not depend on the language menu.
    final languages = <String>{
      for (final entry in _learnedDecks(onlyShown: false)) entry.language.code,
    };
    return List<List<DeckEntry>>.unmodifiable(<List<DeckEntry>>[
      for (final code in languages)
        ...courseUnits(code).where((unit) => !unit.every(_isTaughtOut)).take(2),
    ]);
  }

  /// The native languages the learner may learn [language] from, in
  /// catalog order, each with its coverage (ADR-0036): those that teach it
  /// and that the learner speaks, or, when they speak none of them, every
  /// one that teaches it. Empty if no deck teaches [language].
  List<NativeOption> nativeOptions(String language) {
    final natives = <String, LanguageInfo>{
      for (final entry in decks)
        if (entry.language.code == language)
          entry.deck.native.code: entry.deck.native,
    };
    final spoken = <LanguageInfo>[
      for (final native in natives.values)
        if (settings.rankOf(native.code) != null) native,
    ];
    CoursePath? pathOf(LanguageInfo native) =>
        _catalog.paths['$language/${native.code}'];
    return <NativeOption>[
      for (final native in spoken.isEmpty ? natives.values : spoken)
        (
          native: native,
          covered: pathOf(native)?.coveredUnits,
          total: pathOf(native)?.writtenUnits,
        ),
    ];
  }

  /// The native language [language] is offered from first: the one whose
  /// decks teach the most of its written units, ties going to the
  /// best-known language the learner speaks, else to the first in the
  /// catalog. With only one to choose from, that one.
  String? suggestedNative(String language) {
    final options = nativeOptions(language);
    if (options.isEmpty) return null;
    int rank(NativeOption o) =>
        settings.rankOf(o.native.code) ?? settings.spokenLanguages.length;
    return options
        .reduce((best, o) {
          final more = (o.covered ?? 0).compareTo(best.covered ?? 0);
          if (more != 0) return more > 0 ? o : best;
          return rank(o) < rank(best) ? o : best;
        })
        .native
        .code;
  }

  /// The native language [language]'s course is taught from: the one the
  /// learner chose, while it still teaches it, else [suggestedNative]. A
  /// unit with no deck in it is "Coming", never taught from another
  /// language's decks. Null if no deck teaches [language].
  String? courseNative(String language) {
    final chosen = settings.courseNative(language);
    if (chosen != null &&
        nativeOptions(language).any((o) => o.native.code == chosen)) {
      return chosen;
    }
    return suggestedNative(language);
  }

  /// Whether to ask the learner which language to learn [language] from:
  /// more than one they speak teaches it, and they have not chosen among
  /// these. Asked on opening the course the first time, and once more when
  /// a native language starts teaching a course already chosen for; never
  /// again for the same choice.
  bool needsNativeChoice(String language) {
    if (!offersNativeChoice(language)) return false;
    final offered = settings.nativesOffered(language);
    return settings.courseNative(language) == null ||
        nativeOptions(language).any((o) => !offered.contains(o.native.code));
  }

  /// Whether the learner has a choice of languages to learn [language]
  /// from: more than one they speak teaches it. Settings then offers
  /// "Learn Telugu from".
  bool offersNativeChoice(String language) {
    final options = nativeOptions(language);
    return options.length > 1 &&
        options.every((o) => settings.rankOf(o.native.code) != null);
  }

  /// Records that [language] is learned from [native], among the options
  /// offered now.
  void chooseNative(String language, String native) => settings.setCourseNative(
    language,
    native,
    offered: <String>[
      for (final option in nativeOptions(language)) option.native.code,
    ],
  );

  /// The units of [language]'s course, in teaching order: the course taught
  /// from [courseNative], or [native] where given. Its path's units, or
  /// without a path each deck as a unit, in catalog order; a deck its path
  /// leaves out follows as a unit of its own. Without its alphabet, the
  /// decks the path marks as needing it are left out. Empty if no deck
  /// teaches [language]. Whether the profile learns it does not matter:
  /// placement asks before it does.
  ///
  /// [alphabet] overrides whether the alphabet is learned, [scripts] which
  /// scripts are (over [alphabet]), and [native] which language it is
  /// learned from, for placement, which asks before any is saved.
  List<List<DeckEntry>> courseUnits(
    String language, {
    bool? alphabet,
    Set<String>? scripts,
    String? native,
  }) {
    final teaching = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == language) entry,
    ];
    if (teaching.isEmpty) return const <List<DeckEntry>>[];
    native ??= courseNative(language);
    final course = <DeckEntry>[
      for (final entry in teaching)
        if (entry.deck.native.code == native) entry,
    ];
    final path = pathOf(course.first);
    // Learned without its alphabet, the course leaves out the decks that
    // need it; with several scripts, those of each script not learned.
    if (path != null) {
      course.removeWhere(
        (e) =>
            path.alphabet.contains(e.id) &&
            !learnsScriptOf(e.language, alphabet: alphabet, scripts: scripts),
      );
    }
    final byId = <String, DeckEntry>{for (final e in course) e.id: e};
    return <List<DeckEntry>>[
      if (path != null)
        for (final unit in path.units)
          if (<DeckEntry>[for (final id in unit) ?byId[id]] case final found
              when found.isNotEmpty)
            found,
      for (final entry in course)
        if (path?.unitOf(entry.id) == null) <DeckEntry>[entry],
    ];
  }

  /// Whether [entry] needs an alphabet the learner is not learning: its
  /// course leaves it out (#47). It can still be opened and studied.
  bool leavesOut(DeckEntry entry) =>
      needsAlphabet(entry) && !learnsScriptOf(entry.language);

  /// The script [code]'s course starts with: the one most of its decks use.
  String primaryScript(String code) {
    // The script most of the course's decks are written in: a deck in the
    // second script lists that script first, so the first deck found could
    // be one of those.
    final counts = <String, int>{};
    for (final entry in decks) {
      if (entry.language.code != code) continue;
      final script = entry.language.script;
      counts[script] = (counts[script] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'latin';
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Whether the learner learns the script [language] is written in here:
  /// a script deck's own (#623), so a Devanagari reader learning
  /// Perso-Arabic skips the Devanagari script units. A script the language
  /// does not list follows whether the alphabet is learned at all.
  ///
  /// [alphabet] overrides whether the alphabet is learned, for placement,
  /// which asks before it saves: true means the scripts chosen, or the
  /// primary script where none is stored, never every script. [scripts]
  /// overrides both: the scripts chosen and not saved yet.
  bool learnsScriptOf(
    LanguageInfo language, {
    bool? alphabet,
    Set<String>? scripts,
  }) {
    final code = language.code;
    final listed = _courseScripts(language);
    if (!listed.contains(language.script)) {
      if (scripts != null) return scripts.isNotEmpty;
      return alphabet ?? settings.learnsAlphabet(code);
    }
    return scriptsLearnedOf(
      code,
      alphabet: alphabet,
      scripts: scripts,
    ).contains(language.script);
  }

  /// The scripts [code] is learned in: [scripts] where given; else as
  /// [alphabet] says, where given (see [learnsScriptOf]); else as saved.
  Set<String> scriptsLearnedOf(
    String code, {
    bool? alphabet,
    Set<String>? scripts,
  }) {
    if (scripts != null) return scripts;
    final primary = primaryScript(code);
    if (alphabet == null) {
      return settings.scriptsLearned(code, primary: primary);
    }
    if (!alphabet) return const <String>{};
    final chosen = settings.hasScriptsChosen(code)
        ? settings.scriptsLearned(code, primary: primary)
        : const <String>{};
    return chosen.isEmpty ? <String>{primary} : chosen;
  }

  /// The scripts [language]'s cards are read in, in course order: those
  /// the learner learns (#623). None when they learn none. [scripts]
  /// overrides what is saved, as placement's choice does before it is.
  List<String> learnedScripts(LanguageInfo language, {Set<String>? scripts}) {
    final learned = scriptsLearnedOf(language.code, scripts: scripts);
    return <String>[
      for (final script in _courseScripts(language))
        if (learned.contains(script)) script,
    ];
  }

  /// [language]'s scripts, in course order: its course's primary first.
  Set<String> _courseScripts(LanguageInfo language) => <String>{
    primaryScript(language.code),
    ...language.allScripts,
  };

  /// The scripts the learner reads through the languages they know (#554,
  /// Languages I know): a script answered for a language by name
  /// (`hi:perso_arabic`), and a language's own script answered by its code
  /// alone, as its decks, or else the deck index, name it.
  Set<String> get scriptsReadKnown => scriptReadersKnown.keys.toSet();

  /// The languages the learner knows that they read each script through,
  /// by code, in the order answered: what placement's "Do you read
  /// Devanagari?" says they read it through (#481).
  Map<String, List<String>> get scriptReadersKnown {
    final readers = <String, List<String>>{};
    for (final MapEntry(:key, :value) in settings.scriptsRead.entries) {
      if (!value) continue;
      final parts = key.split(':');
      final script = parts.length == 2 ? parts[1] : _ownScriptOf(key);
      if (script == null) continue;
      readers.putIfAbsent(script, () => <String>[]).add(parts.first);
    }
    return readers;
  }

  /// The script [code] is written in first: its decks', or the deck
  /// index's for a language with none on the phone. Null if neither knows.
  String? _ownScriptOf(String code) {
    if (decks.any((e) => e.language.code == code)) return primaryScript(code);
    for (final language
        in deckDownloads?.index?.languages ?? const <IndexLanguage>[]) {
      if (language.code == code) return language.script;
    }
    return null;
  }

  /// The scripts [language]'s cards are shown in, in course order: those
  /// learned; for a language written in several but learned in none, those
  /// the learner reads already through a language they know, which need not
  /// be learned to be read (owner, 2026-10-20). A language written in one
  /// script and learned without it shows none, as before.
  List<String> _shownScripts(LanguageInfo language, {Set<String>? scripts}) {
    final learned = learnedScripts(language, scripts: scripts);
    final all = _courseScripts(language);
    if (learned.isNotEmpty || all.length < 2) return learned;
    final read = scriptsReadKnown;
    return <String>[
      for (final script in all)
        if (read.contains(script)) script,
    ];
  }

  /// Whether [language]'s cards show their reading first (#47): the
  /// learner learns none of its scripts and reads none of them already
  /// ([_shownScripts]). What drills and placement both ask; [scripts] as
  /// for [learnedScripts].
  bool readsFirst(LanguageInfo language, {Set<String>? scripts}) =>
      _shownScripts(language, scripts: scripts).isEmpty;

  /// The other spellings of [card] to show beneath [targetShown]'s, smaller
  /// (#623): when the learner learns its script and another too, the others
  /// that it has. None for a card or a learner with one script. [scripts]
  /// as for [learnedScripts].
  List<({String text, LanguageInfo language})> otherSpellings(
    Card card,
    LanguageInfo language, {
    Set<String>? scripts,
  }) {
    final first = language.script;
    final shown = _shownScripts(language, scripts: scripts);
    if (!shown.contains(first)) {
      return const <({String text, LanguageInfo language})>[];
    }
    return <({String text, LanguageInfo language})>[
      for (final script in shown)
        if (script != first)
          if (card.targetIn(script, firstScript: first) case final text?)
            (text: text, language: language.inScript(script)),
    ];
  }

  /// How [card] is shown as [language]'s text: the learner's script and
  /// that script's language, which draws it in its direction (#623). The
  /// card's own target and [language] unless they learn only another
  /// script (or, learning none, read only another), and the card has its
  /// spelling in it. [scripts] as for [learnedScripts].
  ({String text, LanguageInfo language}) targetShown(
    Card card,
    LanguageInfo language, {
    Set<String>? scripts,
  }) {
    final first = language.script;
    final shown = _shownScripts(language, scripts: scripts);
    if (shown.isEmpty || shown.contains(first)) {
      return (text: card.target, language: language);
    }
    for (final script in shown) {
      if (card.targetIn(script, firstScript: first) case final text?) {
        return (text: text, language: language.inScript(script));
      }
    }
    return (text: card.target, language: language);
  }

  /// Whether [entry] is one of its course's decks that need the alphabet:
  /// a script, spelling or reading deck.
  bool needsAlphabet(DeckEntry entry) =>
      pathOf(entry)?.alphabet.contains(entry.id) ?? false;

  /// Whether the learner is past [language]'s script units: the first run
  /// of units on its path whose decks all need the alphabet, each finished
  /// or placed. Until then typed answers start in Latin letters and count
  /// in full. True for a course with no such units.
  bool scriptLearned(String language) {
    // The script units of the scripts learned (#623): one skipped is not
    // waited for.
    final units = courseUnits(language);
    final path = units.isEmpty ? null : pathOf(units.first.first);
    if (path == null) return true;
    bool script(List<DeckEntry> unit) =>
        unit.every((e) => path.alphabet.contains(e.id));
    final start = units.indexWhere(script);
    if (start < 0) return true;
    for (final unit in units.skip(start)) {
      if (!script(unit)) break;
      if (!unit.every(isFinished)) return false;
    }
    return true;
  }

  /// The cards a [ask] question about [card] takes its other options from
  /// (ADR-0024): its deck's other cards of the same kind, each showing a
  /// different option, or, when they show fewer than three, those of every
  /// deck of its course as well. A rules table's form, or its meaning, is
  /// chosen among its own row's alone ([formChoices], DECK-FORMAT.md, Rules
  /// decks).
  List<Card> choicePool(Card card, Ask ask) {
    final entry = deckOf(card);
    if (entry == null) return const <Card>[];
    if (ask.choosesAmongForms) return formChoices(card, ask, entry.cards);
    final right = ask.optionOf(card);
    final cell = card.isGrammarCell;
    bool alike(Card c) =>
        c.id != card.id &&
        c is! QuestionCard &&
        !c.practiceOnly &&
        c.isGrammarCell == cell &&
        ask.optionOf(c) != right;
    final own = entry.cards.where(alike).toList();
    if (own.map(ask.optionOf).toSet().length >= 3) return own;
    return <Card>[
      ...own,
      for (final other in decks)
        if (other.id != entry.id &&
            other.language.code == entry.language.code &&
            other.deck.native.code == entry.deck.native.code)
          ...other.cards.where(alike),
    ];
  }

  /// [card]'s minimal-pair partner (ADR-0034), as a deck of its language and
  /// native language lists it, or null.
  Card? pairOf(Card card) {
    final id = card.pair;
    return id == null ? null : cardInCourseOf(card, id);
  }

  /// The card [id], as a deck of [card]'s language and native language lists
  /// it, or null where the learner has no such card in that course.
  Card? cardInCourseOf(Card card, String id) {
    final entry = deckOf(card);
    if (entry == null) return null;
    for (final other in decks) {
      if (other.language.code != entry.language.code ||
          other.deck.native.code != entry.deck.native.code) {
        continue;
      }
      for (final c in other.cards) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// Whether a [ask] question about [card] has at least two wrong options
  /// to offer, or, choosing among a rules table's forms or their meanings,
  /// one (DECK-FORMAT.md, Rules decks: a row of two forms is still a choice).
  /// Without, it is asked its own way.
  bool canChoose(Card card, Ask ask) =>
      choicePool(card, ask).map(ask.optionOf).toSet().length >=
      (ask.choosesAmongForms ? 1 : 2);

  /// The items of the session for [request], each asked as a review asks it
  /// ([reviewAsks]): what a drill runs.
  List<SessionItem> sessionItems(DrillRequest request) =>
      _asked(_limited(buildSession(request).items, request.limit));

  /// [items], each asked as a review asks it ([reviewAsks]).
  List<SessionItem> _asked(List<SessionItem> items) => reviewAsks(
    items,
    canChoose: (item) => canChoose(
      item.card,
      item.ask == Ask.own ? Ask.chooseMeaning : item.ask,
    ),
    hearsForm: (item) => hearsForm(item.card),
    recallsFirst: (item) => recallsFirst(item.card, item.mode),
    typed: (item) => isTyped(item.card),
    siblingsOf: siblingsOf,
  );

  // ---------------------------------------------------------------------------
  // The day's session (#521, #485)

  /// The most new words one daily session teaches (owner, 2026-10-30).
  static const int dailyNewCap = DailyPlanner.newCap;

  /// What the log says of the time answers took, for [language] (every
  /// language when null). The log is read once, each answer added to its
  /// language's tally as it comes, so an answer costs one event however
  /// long the log is (#852).
  final Map<String?, _AnswerTimes> _answerTimes = <String?, _AnswerTimes>{};
  int _timesRead = 0;
  Object? _timesFirst;

  _AnswerTimes _timesIn(String? language, DateTime at) {
    final log = progress.log;
    // A replayed or replaced log is read again from its start.
    if (_timesRead > log.length ||
        (_timesRead > 0 && !identical(_timesFirst, log.first))) {
      _answerTimes.clear();
      _timesRead = 0;
    }
    if (_timesRead == 0 && log.isNotEmpty) _timesFirst = log.first;
    for (var i = _timesRead; i < log.length; i++) {
      final e = log[i];
      final time = StudyHours.capped(e.elapsed);
      final day = dateOnly(e.at);
      for (final key in <String?>{Abilities.languageOf(e.cardId), null}) {
        final tally = _answerTimes.putIfAbsent(key, _AnswerTimes.new);
        tally.seconds.add(time.inMilliseconds / 1000);
        tally.byDay[day] = (tally.byDay[day] ?? Duration.zero) + time;
      }
    }
    _timesRead = log.length;
    final tally = _answerTimes.putIfAbsent(language, _AnswerTimes.new);
    tally.day = at;
    return tally;
  }

  /// Seconds a card takes this learner in [language] (every language when
  /// null): their own median once they have answered 20 cards, else 17.5.
  double secondsPerCardIn(String? language) =>
      _timesIn(language, now()).secondsPerCard;

  /// The time spent today on [language]: answers and teach cards.
  Duration dailySpent(String language) {
    final at = now();
    return _timesIn(language, at).spent +
        settings.teachTimeOn(at, language: language) +
        settings.clockTimeOn(at, language: language);
  }

  /// What the daily planner is given for [language], and plans: the same
  /// for Today ([dailyPlanFor]) and for the session ([nextDailyRound]), so
  /// that Today's numbers are the session's (#886, #885).
  DailyRound _planDaily(
    String language, {
    required Duration left,
    required int due,
    required int closest,
    required int fresh,
    required DateTime at,
    int taught = 0,
    bool whole = false,
  }) {
    final times = _timesIn(language, at);
    final teach = settings.teachTimeTotal(language: language);
    final dayCards = DailyBudget.cardsFor(
      settings.dailyMinutesFor(language),
      secondsPerCard: times.secondsPerCard,
    );
    final plan = whole ? DailyPlanner.whole : DailyPlanner.next;
    return plan(
      left: left,
      due: due,
      newAvailable: fresh,
      closest: closest,
      secondsPerReview: times.secondsPerCard,
      secondsPerTeach: DailyBudget.secondsPerTeach(teach.time, teach.cards),
      taughtSoFar: taught,
      catchingUp: due > DailyBudget.backlogDays * dayCards,
    );
  }

  /// The cards a daily round draws on in [language], none of them in
  /// [asked]: those due, the most forgotten first, and those not due, the
  /// closest to due first.
  ({List<SessionItem> due, List<SessionItem> closest}) _dailyPools(
    String language,
    DateTime at,
    Set<String> asked,
  ) {
    final due = <SessionItem>[
      for (final item in DailyBudget.mostForgottenFirst(
        buildSession(DrillRequest.today(language: language)).items,
        at,
      ))
        if (!asked.contains(item.card.id)) item,
    ];
    final closest = <SessionItem>[
      for (final item in buildSession(
        DrillRequest(revise: true, language: language),
      ).items)
        if (item.state != null &&
            !item.state!.isDue(at) &&
            !asked.contains(item.card.id))
          item,
    ]..sort((a, b) => a.state!.dueAt.compareTo(b.state!.dueAt));
    return (due: due, closest: closest);
  }

  /// [language]'s day: its minutes, what is spent, what waits, and what
  /// the rest of the budget buys. What it buys is the session's own plan
  /// ([DailyPlanner.whole]) for the time left, so that Today and the
  /// session agree (#886, #885).
  DailyPlan dailyPlanFor(LanguageInfo language) {
    final code = language.code;
    final at = now();
    final goal = settings.dailyMinutesFor(code);
    final extra = settings.dailyExtraFor(code, at);
    final minutes = max(DailyBudget.minMinutes, goal + extra);
    final times = _timesIn(code, at);
    // Teach cards are timed like answers (#886), in the settings.
    final spent =
        times.spent +
        settings.teachTimeOn(at, language: code) +
        settings.clockTimeOn(at, language: code);
    final pools = _dailyPools(code, at, const <String>{});
    final fresh = untaughtCards(code).length;
    final left = minutes * 60 - spent.inSeconds;
    // With the budget spent, the split is what "Keep going" would buy.
    final round = _planDaily(
      code,
      left: left > 0
          ? Duration(seconds: left)
          : const Duration(minutes: DailyBudget.stepMinutes),
      due: pools.due.length,
      closest: pools.closest.length,
      fresh: fresh,
      at: at,
      whole: true,
    );
    final dayCards = DailyBudget.cardsFor(
      goal,
      secondsPerCard: times.secondsPerCard,
    );
    return DailyPlan(
      language: language,
      goalMinutes: goal,
      extraMinutes: extra,
      spent: spent,
      secondsPerCard: times.secondsPerCard,
      due: pools.due.length,
      newAvailable: min(dailyNewCap, fresh),
      split: DailySplit(
        reviews: round.reviews + round.fillers,
        newWords: round.newWords,
        catchingUp: pools.due.length > DailyBudget.backlogDays * dayCards,
      ),
    );
  }

  /// Adds [minutes] (negative to take off) to [language]'s day today, never
  /// taking it below the least a day may be.
  void addDailyMinutes(String language, int minutes) {
    final at = now();
    final goal = settings.dailyMinutesFor(language);
    final extra = settings.dailyExtraFor(language, at) + minutes;
    settings.setDailyExtra(
      language,
      max(DailyBudget.minMinutes - goal, extra),
      at,
    );
  }

  /// The day's session in [language], run on a clock (#886): the time left
  /// today, which is the day's minutes less what is spent, or a step of
  /// minutes once it is all spent ("Keep going"). Null for a language the
  /// learner has no decks of.
  DailyRun? startDaily(String language) {
    final info = <LanguageInfo>[
      for (final entry in decks)
        if (entry.language.code == language) entry.language,
    ].firstOrNull;
    if (info == null) return null;
    final plan = dailyPlanFor(info);
    final left = Duration(minutes: plan.minutes) - plan.spent;
    return DailyRun(
      language: language,
      clock: DailyCountdown(
        budget: left > Duration.zero
            ? left
            : const Duration(minutes: DailyBudget.stepMinutes),
        now: now(),
      ),
      spentAtStart: plan.spent,
    );
  }

  /// The next round of [run]'s session, built only when the last is done
  /// (#886, owner, 2026-10-29 and 2026-10-30): empty when the time is used
  /// up or nothing is left to ask.
  ///
  /// The round's size follows the time left ([DailyPlanner.next]). While
  /// reviews are due they come most forgotten first, with new words
  /// between. With none due, new words are taught, up to 15 in all, and
  /// asked twice with older reviews mixed in; the rest of the time is
  /// filled with reviews of the cards closest to due.
  List<SessionItem> nextDailyRound(DailyRun run) {
    final at = now();
    final language = run.language;
    final pools = _dailyPools(language, at, run.asked);
    final due = pools.due;
    final closest = pools.closest;
    var fresh = untaughtCards(language).length;
    for (var attempt = 0; attempt < 2; attempt++) {
      final round = _planDaily(
        language,
        left: run.clock.remainingAt(at),
        due: due.length,
        closest: closest.length,
        fresh: fresh,
        at: at,
        taught: run.taught,
      );
      if (round.isEmpty) return const <SessionItem>[];
      final pick = round.reviews > 0
          ? due.take(round.reviews)
          : closest.take(round.fillers);
      final older = _asked(pick.toList());
      final teaches = <SessionItem>[];
      final firstPass = <SessionItem>[];
      final secondPass = <SessionItem>[];
      if (round.newWords > 0) {
        final seen = <String>{};
        for (final item in lessonFor(
          DrillRequest.lesson(language: language),
          words: round.newWords,
          beyondRoom: true,
        )) {
          if (item.ask.onlyShows) {
            teaches.add(item);
          } else if (seen.add(item.card.id)) {
            firstPass.add(item);
          } else {
            secondPass.add(item);
          }
        }
        if (teaches.isEmpty && firstPass.isEmpty) {
          // Nothing to teach after all: plan again without new words.
          fresh = 0;
          continue;
        }
      }
      final items = DailyPlanner.arrange<SessionItem>(
        older: older,
        taught: teaches,
        firstPass: firstPass,
        secondPass: secondPass,
      );
      if (items.isEmpty) return items;
      final taughtIds = <String>{};
      for (final item in teaches.isEmpty ? firstPass : teaches) {
        final members = item.group.isEmpty ? <SessionItem>[item] : item.group;
        taughtIds.addAll(members.map((member) => member.card.id));
      }
      run.taught += taughtIds.length;
      for (final item in items) {
        run.asked.add(item.card.id);
        for (final member in item.group) {
          run.asked.add(member.card.id);
        }
      }
      return items;
    }
    return const <SessionItem>[];
  }

  final Expando<FormSiblings> _siblingIndex = Expando<FormSiblings>();

  /// The siblings of [card] in its deck ([formSiblings]), the deck's cards
  /// grouped once.
  List<Card> siblingsOf(Card card) {
    final entry = deckOf(card);
    if (entry == null) return const <Card>[];
    return (_siblingIndex[entry] ??= FormSiblings(entry.cards)).of(card);
  }

  /// Whether an answer about [card] can be typed: false for the IPA
  /// (`typed: false` in its language block), whose production is chosen
  /// (ADR-0041).
  bool isTyped(Card card) => deckOf(card)?.language.typed ?? true;

  /// The ability layer (ADR-0034), rebuilt when the log grows.
  Abilities get abilities {
    final log = progress.log;
    final skills = progress.skills;
    if (_abilities == null ||
        _abilitiesAt != log.length ||
        _abilitiesSkills != skills) {
      _abilities = Abilities.replay(
        <({String cardId, String deckId, DrillMode mode, int grade})>[
          for (final e in log)
            (cardId: e.cardId, deckId: e.deckId, mode: e.mode, grade: e.grade),
        ],
        skills: skills,
      );
      _abilitiesAt = log.length;
      _abilitiesSkills = skills;
    }
    return _abilities!;
  }

  Abilities? _abilities;
  int _abilitiesAt = -1;
  SkillMap? _abilitiesSkills;

  /// The strength from which a pair never asked in [mode] starts at recall
  /// rather than choice: the learner gets most words right there.
  static const double recallFirstStrength = 0.8;

  /// How many answers a strength must rest on before it is trusted.
  static const int recallFirstAnswers = 20;

  /// Whether [card], never asked in [mode], starts at recall (ADR-0034):
  /// the learner's ability there says a choice would be too easy.
  bool recallsFirst(Card card, DrillMode mode) {
    final language = Abilities.languageOf(card.id);
    final a = abilities;
    return a.answersIn(language, mode) >= recallFirstAnswers &&
        a.strength(language, mode) >= recallFirstStrength;
  }

  /// Whether hearing [card] asks for what was heard rather than what it
  /// means: a letter or a digit (`pos`), a card marked `hears: form`
  /// ([Card.hearsForm]), which is script practice (ADR-0034); a generated
  /// number is marked so.
  bool hearsForm(Card card) => card.hearsForm;

  /// At most [limit] of [items], one per word, picked at random: a quick
  /// revision (ADR-0029). All of them, in order, when [limit] is null.
  List<SessionItem> _limited(List<SessionItem> items, int? limit) {
    if (limit == null) return items;
    final shuffled = List<SessionItem>.of(items)..shuffle(random);
    final words = <String>{};
    return <SessionItem>[
      for (final item in shuffled)
        if (words.length < limit && words.add(item.card.id)) item,
    ];
  }

  /// How many words a quick revision can pick from: every word taught, in a
  /// skill it can be drilled in now.
  int get revisableCount => revisableIn(null);

  /// How many words a revision of [skills] can pick from, or of every skill
  /// switched on when null.
  ///
  /// With [script], the script decks' share of it (Today's tiles).
  int revisableIn(Set<Skill>? skills, {ScriptScope script = ScriptScope.any}) =>
      <String>{
        for (final item in buildSession(
          DrillRequest(revise: true, skills: skills, script: script),
        ).items)
          item.card.id,
      }.length;

  // ---------------------------------------------------------------------------
  // Lessons (ADR-0024)

  /// Whether [card] has been taught: some skill of it has been drilled.
  bool isTaught(Card card) =>
      DrillMode.drills.any((mode) => progress.stateOf(card.id, mode) != null);

  /// The modes [card] can be drilled in now: those it takes, switched on
  /// and not paused, by ear only with a voice and sound on and by mouth
  /// only with a recogniser, each on for its language, and none set aside.
  Set<DrillMode> drillableModes(Card card) => drillableModesNow()(card);

  /// [drillableModes] for many cards: the skills switched on and the
  /// leeches set aside read once, not once a card.
  Set<DrillMode> Function(Card card) drillableModesNow() {
    final modes = _modes(ignorePauses: false);
    final leeches = progress.leechEffects;
    return (card) => _drillableModes(card, modes, leeches);
  }

  Set<DrillMode> _drillableModes(
    Card card,
    Set<DrillMode> modes,
    LeechEffects leeches,
  ) {
    final entry = deckOf(card);
    if (entry == null) return const <DrillMode>{};
    final language = entry.language;
    return <DrillMode>{
      for (final mode in card.modesIn(
        ttsAvailable:
            canSpeak(language) &&
            !settings.isOffFor(Skill.listening, language.code),
        speechAvailable:
            canHear(language) &&
            !settings.isOffFor(Skill.speaking, language.code),
        siblings: siblingsOf(card),
      ))
        if (modes.contains(mode) &&
            !leeches.isSetAside((cardId: card.id, mode: mode)))
          mode,
    };
  }

  /// The cards a lesson in [language] can teach, in their order: from
  /// [deckId], or else from the pending units (ADR-0013). Those not taught
  /// yet that can be drilled now, and with [tags] given, only those
  /// carrying one of them: a deck page's tag chips. A sentence waits until
  /// its words and rules are known, and a rules table's cell until its word
  /// is ([Unlocks.isOpen], ADR-0046).
  List<Card> untaughtCards(
    String language, {
    String? deckId,
    Set<String> tags = const <String>{},
  }) {
    final cards = deckId != null
        ? deckById(deckId)?.cards ?? const <Card>[]
        : _alternating(<List<DeckEntry>>[
            for (final unit in pendingUnits)
              if (unit.first.language.code == language) unit,
          ]);
    final seen = <String>{};
    final gate = unlocks;
    return <Card>[
      for (final card in cards)
        if ((tags.isEmpty || card.tags.any(tags.contains)) &&
            seen.add(card.id) &&
            !isTaught(card) &&
            gate.isOpen(card) &&
            drillableModes(card).isNotEmpty)
          card,
    ];
  }

  /// The items of the lesson [request] asks for (ADR-0024), or none when
  /// there is nothing left to teach.
  ///
  /// When the first card left is a reading question, the lesson is its
  /// passage: the questions about it, heard, then read. Otherwise it is up
  /// to nine words before the next passage, as [lessonItems] picks them,
  /// each taught, checked and practised ([lessonPlan]).
  ///
  /// A set card one of them is a member of (DECK-FORMAT.md, Set cards)
  /// comes first, whole or in parts, with every new member of it taught in
  /// the lesson, whatever the cap; a rules table's cell it taught goes
  /// straight to its question ([lessonSets], #515).
  ///
  /// With [words], the lesson teaches that many words at most, the easiest
  /// first: the new words of a day's session (#485).
  ///
  /// With [beyondRoom], [words] is not held to what the mastery bar leaves
  /// room for: the daily session's own cap says how many (#886, owner,
  /// 2026-10-30: "Placement allows. But capped at 15").
  List<SessionItem> lessonFor(
    DrillRequest request, {
    int? words,
    bool beyondRoom = false,
  }) {
    final cards = untaughtCards(
      request.language!,
      deckId: request.deckIds?.single,
      tags: request.tags,
    );
    if (cards.isEmpty) return const <SessionItem>[];
    final first = cards.first;
    if (first is QuestionCard) {
      final questions = <QuestionCard>[
        for (final card in cards)
          if (card is QuestionCard && card.sharesPassage(first)) card,
      ];
      return inPassages(<SessionItem>[
        for (final mode in const <DrillMode>[
          DrillMode.reading,
          DrillMode.listening,
        ])
          for (final question in questions)
            if (drillableModes(question).contains(mode))
              SessionItem(card: question, mode: mode, state: null),
      ]);
    }
    final taught = cards.takeWhile((card) => card is! QuestionCard);
    // As many new items as the mastery bar allows (ADR-0046): fewer while
    // words and rules taught are not known yet.
    final room = lessonRoom(inProgressIn(request.language!));
    final picked = lessonItems(
      taught,
      room: words == null ? room : (beyondRoom ? words : min(room, words)),
    );
    final modesOf = drillableModesNow();
    final lesson = lessonSets(
      picked,
      sets: _lessonSets(picked),
      // A set's members are taught whole, but none the gate holds back
      // (ADR-0046).
      isNew: (card) =>
          !isTaught(card) && unlocks.isOpen(card) && modesOf(card).isNotEmpty,
      isKnown: isTaught,
    );
    final gate = unlocks;
    final introduced = <String>{};
    return <SessionItem>[
      for (final part in lesson.parts)
        SessionItem.set(part, DrillMode.recognition),
      for (final item in lessonPlan(
        lesson.cards,
        modesOf: modesOf,
        canChoose: (card, ask) => canChoose(
          card,
          ask == Ask.hearMeaning && hearsForm(card) ? Ask.hearAndChoose : ask,
        ),
        // A rule is taught by its rule card, then its cells are asked
        // (#417).
        straightToQuestion: (card) => card.rule != null,
        typed: isTyped,
        siblingsOf: siblingsOf,
      )) ...<SessionItem>[
        // The rule card, before the first question of a rule none of whose
        // cells was answered yet.
        if (item.card.rule case final cell?
            when gate.ruleStanding(cell.ruleId).level == MasteryLevel.fresh &&
                introduced.add(cell.ruleId))
          SessionItem(
            card: item.card,
            mode: DrillMode.grammar,
            state: null,
            ask: Ask.teachRule,
          ),
        item.ask == Ask.hearMeaning && hearsForm(item.card)
            ? item.askedAs(Ask.hearAndChoose)
            : item,
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // The sounds of a word (ADR-0041)

  /// Whether the current profile learns the IPA course.
  bool get learnsIpa => currentProfile.learns(ipaLanguageCode);

  /// Adds the IPA course to the languages the current profile learns. A profile that learned every language, having chosen
  /// none, keeps learning them: they are named, and the IPA with them.
  void addIpaCourse() {
    final codes = learningCodes.isEmpty
        ? <String>[
            for (final language in languages)
              if (!language.isNotation) language.code,
          ]
        : learningCodes.toList();
    if (!codes.contains(ipaLanguageCode)) codes.add(ipaLanguageCode);
    setLearningLanguages(codes);
  }

  /// The IPA cards whose symbols occur in the IPA of [card], in the
  /// course's order, as the course is taught from [courseNative]'s language,
  /// or an empty list for a card with no IPA or while the IPA decks are not
  /// on the phone. Of the whole chart: the symbols of a word are what the word
  /// needs.
  List<Card> soundsOfWord(Card card) {
    final ipa = card.ipa;
    if (ipa == null) return const <Card>[];
    final native = courseNative(ipaLanguageCode);
    final seen = <String>{};
    final cards = <Card>[
      for (final entry in _catalog.decks)
        if (entry.language.isIpa &&
            (native == null || entry.deck.native.code == native))
          for (final c in entry.cards)
            if (seen.add(c.id)) c,
    ];
    // A course taught from no language the learner speaks still has cards.
    if (cards.isEmpty && native != null) {
      for (final entry in _catalog.decks) {
        if (entry.language.isIpa) {
          cards.addAll(entry.cards.where((c) => seen.add(c.id)));
        }
      }
    }
    return ipaCardsFor(ipa, cards);
  }

  /// The session of "The sounds of this word" for [card], or null where
  /// there are none to practise: its IPA cards, recorded in the IPA course.
  DrillRequest? soundsOfWordRequest(Card card) {
    final cards = soundsOfWord(card);
    if (cards.isEmpty) return null;
    return DrillRequest.sounds(<String>{for (final c in cards) c.id});
  }

  /// The items of the sounds session [request] asks for: each card taught,
  /// checked and practised as a lesson does (ADR-0024), in the course's
  /// order, every one of them, whatever it has been taught before.
  List<SessionItem> soundsItems(DrillRequest request) {
    final ids = request.cardIds ?? const <String>{};
    final byId = <String, Card>{};
    final native = courseNative(ipaLanguageCode);
    for (final entry in decks) {
      if (!entry.language.isIpa) continue;
      for (final card in entry.cards) {
        if (!ids.contains(card.id)) continue;
        // One card, taught from the course's language where there is one.
        if (!byId.containsKey(card.id) || entry.deck.native.code == native) {
          byId[card.id] = card;
        }
      }
    }
    final modesOf = drillableModesNow();
    return lessonPlan(
      <Card>[for (final id in ids) ?byId[id]],
      modesOf: modesOf,
      canChoose: canChoose,
      typed: isTyped,
    );
  }

  /// The sets of the courses [picked] is taught in.
  List<ResolvedSet> _lessonSets(List<Card> picked) {
    final courses = <(String, String)>{
      for (final card in picked)
        if (deckOf(card) case final entry?)
          (entry.language.code, entry.deck.native.code),
    };
    return <ResolvedSet>[
      for (final (language, native) in courses) ...courseSets(language, native),
    ];
  }

  /// Whether a lesson in [language] was finished today.
  bool lessonDoneToday(String language) {
    final at = settings.lessonDoneAt(language);
    return at != null && isSameDay(at, now());
  }

  /// Whether [language]'s course has decks that need its alphabet, so that
  /// it can be learned without them.
  bool hasAlphabet(String language) {
    for (final entry in decks) {
      if (entry.language.code != language) continue;
      if (pathOf(entry)?.alphabet.contains(entry.id) ?? false) return true;
    }
    return false;
  }

  /// [units]' cards, one from each unit in turn, so that a day's new cards
  /// mix the pending units rather than finishing one first.
  static List<Card> _alternating(List<List<DeckEntry>> units) {
    final queues = <List<Card>>[
      for (final unit in units) <Card>[for (final e in unit) ...e.cards],
    ];
    final mixed = <Card>[];
    for (var i = 0; queues.any((q) => i < q.length); i++) {
      for (final queue in queues) {
        if (i < queue.length) mixed.add(queue[i]);
      }
    }
    return mixed;
  }

  /// Cards in [deck] not taught yet, that some skill the learner has on can
  /// drill (ADR-0024). None left means the deck is finished: its badge says
  /// Done when nothing is due, and it can be revised. A taught word's other
  /// skills come with its reviews.
  int notStudiedIn(DeckEntry deck) => keptFor<int>(
    deck.language.code,
    ('notStudiedIn', deck.id),
    () => <String>{
      for (final item in buildSession(
        DrillRequest.untaught(deck.id),
        ignorePauses: true,
      ).fresh)
        if (!isTaught(item.card)) item.card.id,
    }.length,
  );

  /// [notStudiedIn] without the cards a lesson may not teach yet: a closed
  /// sentence, a cell of a word not known yet (ADR-0046). The path moves on
  /// from a unit when this is none, so that sentences waiting for their
  /// words do not hold the unit back.
  int notStudiedOpenIn(DeckEntry deck) {
    final gate = unlocks;
    return <String>{
      for (final item in buildSession(
        DrillRequest.untaught(deck.id),
        ignorePauses: true,
      ).fresh)
        if (!isTaught(item.card) && gate.isOpen(item.card)) item.card.id,
    }.length;
  }

  /// How numbers are spelled in [language], or null for a language with no
  /// number rules (#54).
  NumberRules? numberRulesFor(LanguageInfo language) =>
      _catalog.numberRules[language.code];

  /// The script guide for a deck in [language] (#30, ADR-0016): the guide
  /// for the deck's own script ([LanguageInfo.script]), else the language's
  /// default guide, or null if it has neither.
  ScriptGuide? scriptGuideFor(LanguageInfo language) =>
      _catalog.scriptGuideFor(language.code, language.script);

  /// The script guide with [key] (`ScriptGuide.key`), with the language as
  /// one of its script decks names it: the Tips page shows the guide's
  /// letters in that language's script. Null if no script deck on the phone
  /// uses it.
  (ScriptGuide, LanguageInfo)? scriptGuideByKey(String key) {
    for (final entry in decks) {
      if (!entry.isScript) continue;
      final guide = scriptGuideFor(entry.language);
      if (guide != null && guide.key == key) return (guide, entry.language);
    }
    return null;
  }

  /// [language]'s sound contrasts (#89, ADR-0015), or null if it has no
  /// sounds file.
  SoundContrasts? soundsFor(LanguageInfo language) =>
      _catalog.sounds[language.code];

  /// How [language] is romanised (#47), or null if it has no romanisation
  /// file.
  Romanisation? romanisationFor(LanguageInfo language) =>
      _catalog.romanisations[language.code];

  /// A card in [language] whose target is [text], as the grader compares
  /// them, for saying what a word heard instead means. Null if no deck has
  /// one.
  Card? cardSaying(LanguageInfo language, String text) {
    final wanted = normaliseForContrast(text);
    if (wanted.isEmpty) return null;
    for (final entry in decks) {
      if (entry.language.code != language.code) continue;
      for (final card in entry.cards) {
        if (normaliseForContrast(card.target) == wanted) return card;
      }
    }
    return null;
  }

  /// Generated numbers to practise in [deck]'s language, in the skills the
  /// learner has on, by ear only with a voice and sound on. Never recorded
  /// (ADR-0011).
  List<SessionItem> numberPracticeFor(DeckEntry deck, {Random? random}) {
    final rules = numberRulesFor(deck.language);
    if (rules == null) return const <SessionItem>[];
    return numberPractice(
      rules,
      deckId: deck.id,
      modes: <DrillMode>{
        for (final mode in sessionModes)
          if (mode != DrillMode.listening || canSpeak(deck.language)) mode,
      },
      random: random ?? Random(),
    );
  }

  /// A deck's due reviews, words not taught yet (ADR-0024), and cards
  /// learned, in every skill the learner has on.
  DeckCounts countsFor(DeckEntry deck) {
    final queue = buildSession(DrillRequest.deck(deck.id));
    return (
      due: queue.due.length,
      fresh: notStudiedIn(deck),
      learned: progress.learnedIn(deck.cards.map((card) => card.id)),
    );
  }

  /// Records [grade] for [item] the moment the answer is given, and returns
  /// the review. Minimal pairs have no mode and are not recorded. With
  /// "Adjust automatically" on, the review's skill is then refitted in the
  /// background if it has grown enough ([FsrsTuner.afterReview]).
  ///
  /// [script] is the script the learner learns that the card was shown, or
  /// the answer typed, in, null for transliteration, and [asked] how it was
  /// asked: what the script skills are worked out from (#653).
  ReviewEvent record(
    SessionItem item,
    int grade, {
    Duration elapsed = Duration.zero,
    String? answerGiven,
    String? script,
    Ask? asked,
  }) {
    _recordingLanguage = deckById(item.card.deckId)?.language.code;
    final ReviewEvent event;
    try {
      event = _record(item, grade, elapsed, answerGiven, script, asked);
    } finally {
      _recordingLanguage = null;
    }
    if (settings.autoAdjust) tuner.afterReview(event);
    return event;
  }

  ReviewEvent _record(
    SessionItem item,
    int grade,
    Duration elapsed,
    String? answerGiven,
    String? script,
    Ask? asked,
  ) {
    final event = progress.record(
      deckId: item.card.deckId,
      cardId: item.card.id,
      mode: item.mode,
      grade: grade,
      now: now(),
      elapsed: elapsed,
      answerGiven: answerGiven,
      script: script,
      asked: asked,
    );
    return event;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    reminders.dispose();
    settings
      ..removeListener(_forgetPending)
      ..removeListener(_reviewerToDownloads)
      ..removeListener(_languageShownChanged);
    progress.removeListener(_forgetPending);
    progress.removeListener(_progressChanged);
    settings.removeListener(_settingsChanged);
    removeListener(_structureChanged);
    shellTab
      ..removeListener(_logTab)
      ..dispose();
    shellTabMoving
      ..removeListener(_logTab)
      ..dispose();
    updates.dispose();
    _fontCheck?.dispose();
    deckDownloads?.onFilesChanged = null;
    tuner.dispose();
    pacing.dispose();
    volume.dispose();
    if (_ownsSettings) settings.dispose();
    if (_ownsLog) log.dispose();
    super.dispose();
  }
}

/// A fact that names a card, and its text in the learner's languages (#546).
typedef CardFact = ({Fact fact, List<({String code, String text})> texts});

/// A language's fact for today, and its text in the learner's languages.
typedef TodayFact = ({
  LanguageInfo language,
  Fact fact,
  List<({String code, String text})> texts,
});

/// The time answers took in one language, as [AppState] caches it.
class _AnswerTimes {
  /// What each answer took, in seconds, each capped as hours spent caps it.
  final List<double> seconds = <double>[];

  /// The time answers took, by day.
  final Map<DateTime, Duration> byDay = <DateTime, Duration>{};

  /// The day [spent] asks about.
  DateTime day = DateTime.fromMillisecondsSinceEpoch(0);

  /// The time answers took on [day].
  Duration get spent => byDay[dateOnly(day)] ?? Duration.zero;

  double _perCard = DailyBudget.defaultSecondsPerCard;
  int _perCardAt = -1;

  /// The median answer time. Approximation: the median of a long log moves
  /// little with one answer, so it is worked out again only every 25
  /// answers once the learner has the 20 that count.
  double get secondsPerCard {
    if (_perCardAt < 0 ||
        seconds.length < DailyBudget.ownTimeAnswers + 25 ||
        seconds.length - _perCardAt >= 25) {
      _perCard = DailyBudget.secondsPerCard(seconds);
      _perCardAt = seconds.length;
    }
    return _perCard;
  }
}

/// One language's, or every language's, queues built for [AppState]
/// requests, with what they were built from.
class _SessionCache {
  Object? stamp;
  final Map<Object, SessionQueue> queues = <Object, SessionQueue>{};
}

/// The words first drilled today, counted as far as [read] answers of the
/// log.
class _NewWords {
  _NewWords(this.day);
  final DateTime day;
  int read = 0;
  final Set<String> earlier = <String>{};
  final Set<String> todays = <String>{};
}

/// Values kept for one language, with what they were worked out from.
class _Kept {
  Object? stamp;
  final Map<Object, Object?> values = <Object, Object?>{};
}
