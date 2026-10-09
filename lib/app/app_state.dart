import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/course_path.dart';
import '../core/feedback/report.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import '../core/models/number_rules.dart';
import '../core/models/reading.dart';
import '../core/models/romanisation.dart';
import '../core/models/script_guide.dart';
import '../core/models/sound_contrasts.dart';
import '../core/numbers/number_practice.dart';
import '../core/scheduling/skill_map.dart';
import '../core/scheduling/session_queue.dart';
import '../core/sound/sound_check.dart';
import '../core/speech/speech_engine.dart';
import '../core/tts/tts_engine.dart';
import '../core/tts/volume_monitor.dart';
import '../core/updates/apk_install.dart';
import '../core/updates/release_check.dart';
import '../core/updates/release_notes.dart';
import '../core/data/themes.dart';
import '../core/models/fact.dart';
import '../core/scheduling/ability.dart';
import '../core/scheduling/daily_fact.dart';
import '../core/scheduling/lesson.dart';
import 'added_decks.dart';
import 'deck_catalog.dart';
import 'deck_import.dart';
import 'features.dart';
import 'links.dart';
import 'log_files.dart';
import 'fsrs_tuner.dart';
import 'memory_progress.dart';
import 'pacing.dart';
import 'profile.dart';
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
    this._speech = const NullSpeechEngine(),
    this.soundCheck = const NullSoundCheck(),
    this.features = const FeatureRegistry.shipped(),
    this._clock = DateTime.now,
    this.logFiles = const PickerLogFiles(),
    this.deckFiles = const PickerDeckFiles(),
    this.links = const LauncherLinks(),
    this.systemSettings = const NullSystemSettings(),
    this.reports = const NullReportSender(),
    this._releases = const NullReleaseCheck(),
    this.releaseNotes = const NullReleaseNotes(),
    this._installer = const NullApkInstaller(),
    this._downloads = const NullDownloadStore(),
    this._fitRunner = fitInIsolate,
    this._paceRunner = paceInIsolate,
    SettingsNotifier? settings,
    VolumeMonitor? volume,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
    Random? random,
  }) : assert(profiles.isNotEmpty, 'there is always a profile'),
       random = random ?? Random(),
       volume = volume ?? FixedVolumeMonitor(),
       deckCatalog = catalog,
       settings = settings ?? SettingsNotifier(),
       _ownsSettings = settings == null,
       _profiles = List<Profile>.of(profiles),
       _currentProfileId = currentProfileId ?? profiles.first.id {
    // What is pending follows progress, settings and this state's own
    // changes: the catalog, voices and the profile.
    for (final source in <Listenable>[this, this.settings, progress]) {
      source.addListener(_forgetPending);
    }
  }

  /// Where a drill's chance comes from, such as the order of a question's
  /// options: seeded in tests and the gallery, so that they repeat.
  final Random random;

  /// Whether the phone's media volume is at zero (ADR-0026).
  final VolumeMonitor volume;

  /// Whether a question that needs sound should ask for the volume to be
  /// raised: sound is on in the app, but the phone is at zero. Such
  /// questions are still asked; with sound off they are skipped instead.
  bool get needsVolume => settings.soundOn && volume.muted;

  /// An app on fakes, for widget tests: the real bundled decks unless
  /// [decks] is given, decks added in memory, no voices unless [tts] has some, empty in-memory
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
    SpeechEngine speech = const NullSpeechEngine(),
    SoundCheckEngine soundCheck = const NullSoundCheck(),
    ProgressStore? progress,
    FeatureRegistry features = const FeatureRegistry.shipped(),
    DateTime? now,
    LogFiles logFiles = const PickerLogFiles(),
    DeckFiles deckFiles = const PickerDeckFiles(),
    DeckStore? addedDecks,
    LinkOpener? links,
    SystemSettings systemSettings = const NullSystemSettings(),
    ReportSender reports = const NullReportSender(),
    ReleaseCheckEngine releases = const NullReleaseCheck(),
    ReleaseNotesEngine releaseNotes = const NullReleaseNotes(),
    ApkInstaller installer = const NullApkInstaller(),
    DownloadStore downloads = const NullDownloadStore(),
    FitRunner fitRunner = fitInPlace,
    PaceRunner paceRunner = paceInPlace,
    SettingsNotifier? settings,
    VolumeMonitor? volume,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
  }) {
    final fixed = now ?? DateTime(2026, 9, 28, 19);
    final state = AppState(
      catalog: DeckCatalog(
        decks ?? AssetDeckSource(),
        added: addedDecks ?? MemoryDeckStore(),
      ),
      progress: progress ?? MemoryProgress(),
      tts: tts,
      speech: speech,
      soundCheck: soundCheck,
      features: features,
      clock: () => fixed,
      logFiles: logFiles,
      deckFiles: deckFiles,
      links: links ?? FixedLinks(),
      systemSettings: systemSettings,
      reports: reports,
      releases: releases,
      releaseNotes: releaseNotes,
      installer: installer,
      downloads: downloads,
      fitRunner: fitRunner,
      paceRunner: paceRunner,
      settings: settings,
      volume: volume,
      profiles: profiles,
      currentProfileId: currentProfileId,
      random: Random(0),
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

  /// Scheduling state and the review log. Has its own notifier.
  final ProgressStore progress;

  /// Where the review log's backup is saved and read from (#20).
  final LogFiles logFiles;

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

  /// Settings' "Check for updates", the check at launch, and installing
  /// what it finds (ADR-0017). Has its own notifier; what it finds is kept
  /// in [settings].
  late final UpdateChecker updates = UpdateChecker(
    engine: _releases,
    settings: settings,
    clock: _clock,
    installer: _installer,
    downloads: _downloads,
  );
  final ReleaseCheckEngine _releases;

  /// Settings' "What's new": the app's recent releases and their notes,
  /// fetched when the page opens and never before (ADR-0031).
  final ReleaseNotesEngine releaseNotes;
  final ApkInstaller _installer;
  final DownloadStore _downloads;

  /// Fits FSRS to the learner: Settings' "Adjust to me", and the automatic
  /// refit after a review (`docs/plans/skill-model.md`). Has its own
  /// notifier.
  late final FsrsTuner tuner = FsrsTuner(
    progress: progress,
    clock: _clock,
    runner: _fitRunner,
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

  final TtsEngine _tts;
  final SpeechEngine _speech;

  /// The microphone and speaker, for the first launch's sound check (#89).
  final SoundCheckEngine soundCheck;
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
  List<DeckEntry> get decks => _catalog.decks;

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

  /// Today's fact for each language the profile learns that has facts
  /// (#48), with its text in each language the learner speaks, best known
  /// first. Choosing one records it as shown today, after this call, so
  /// that it stays today's fact.
  List<TodayFact> todaysFacts() {
    final spoken = settings.spokenLanguages;
    final learned = <String, LanguageInfo>{
      for (final entry in profileDecks) entry.language.code: entry.language,
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
      );
      if (fact == null) continue;
      today.add((
        language: language,
        fact: fact,
        texts: factTexts(fact, spoken),
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

  DeckEntry? deckById(String id) => _catalog.byId(id);

  /// The path of [entry]'s course (ADR-0013), or null if it has none.
  CoursePath? pathOf(DeckEntry entry) => _catalog.pathOf(entry);

  /// The deck a card came from.
  DeckEntry? deckOf(Card card) => _catalog.byId(card.deckId);

  /// The decks in the languages the current profile learns.
  ///
  /// Decks taught from a language the learner speaks come first, best known
  /// first (#53); otherwise the catalog's order holds.
  List<DeckEntry> get profileDecks {
    final mine = <DeckEntry>[
      for (final entry in decks)
        if (currentProfile.learns(entry.language.code)) entry,
    ];
    int rank(DeckEntry e) =>
        settings.rankOf(e.deck.native.code) ?? settings.spokenLanguages.length;
    final byRank = mine.indexed.toList()
      ..sort((a, b) {
        final order = rank(a.$2).compareTo(rank(b.$2));
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return <DeckEntry>[for (final (_, entry) in byRank) entry];
  }

  /// Every language the catalog teaches, one per code.
  List<LanguageInfo> get languages => _catalog.languages;

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
    await _reloadDecks();
  }

  /// Forgets the added deck [deckId]. Its cards' history stays, and comes
  /// back if the deck is added again.
  Future<void> removeDeck(String deckId) async {
    await deckCatalog.added!.remove(deckId);
    await _reloadDecks();
  }

  /// Reads the catalog again without going back to loading, so the screen
  /// that added or removed a deck stays.
  Future<void> _reloadDecks() async {
    deckCatalog.invalidate();
    _catalog = await deckCatalog.load();
    _mapSkills();
    notifyListeners();
    await refreshVoices();
  }

  /// Tells progress which decks ask for what is heard rather than what it
  /// means, so that a right answer there implies Write, not Recognition
  /// (ADR-0034).
  void _mapSkills() {
    progress.skills = SkillMap(
      formHeardIn: <String>{
        for (final entry in decks)
          if (needsAlphabet(entry)) entry.id,
      },
    );
  }

  Future<void> _load() async {
    try {
      _catalog = await deckCatalog.load();
      _status = CatalogStatus.ready;
      _mapSkills();
    } catch (error) {
      _loadError = error;
      _status = CatalogStatus.failed;
    }
    notifyListeners();
    await refreshVoices();
    // Never asks: only a permission granted before lets the phone be
    // checked at launch (ADR-0014). Not awaited: the check can take
    // seconds, and until it answers speaking waits, not the app.
    unawaited(_checkSpeechQuietly());
  }

  Future<void> _checkSpeechQuietly() async {
    if (await _speech.hasPermission() && !_disposed) await startSpeech();
  }

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
      _speechLanguages = ready ? await _speech.languages() : const <String>{};
      setup = ready
          ? SpeechSetup.ready
          : await _speech.hasPermission()
          ? SpeechSetup.noRecogniser
          : SpeechSetup.refused;
    } catch (_) {
      _speechReady = false;
      _speechLanguages = const <String>{};
    } finally {
      _speechChecking = false;
      if (!_disposed) notifyListeners();
    }
    return setup;
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
        return const SpeechHeard.failed(SpeechFailure.notOnDevice);
      case SpeechStatus.missing:
        return const SpeechHeard.failed(SpeechFailure.unsupported);
      case SpeechStatus.off || SpeechStatus.checking:
        return const SpeechHeard.failed(SpeechFailure.noRecogniser);
    }
    final heard = await _speech.listen(
      bcp47: language.ttsTag,
      onDevice: onDevice,
    );
    switch (heard.failure) {
      case SpeechFailure.notOnDevice when onDevice:
        settings.foundSpeech(code);
      case SpeechFailure.unsupported:
        settings.foundSpeech(code, unsupported: true);
      default:
    }
    return heard;
  }

  /// Stops a listen early, keeping what was heard.
  Future<void> stopListening() => _speech.stop();

  // ---------------------------------------------------------------------------
  // Voices

  final Map<String, bool> _voices = <String, bool>{};

  /// Whether the phone has a voice for [language], by its `ttsTag`.
  VoiceStatus voiceStatus(LanguageInfo language) =>
      switch (_voices[language.ttsTag]) {
        true => VoiceStatus.available,
        false => VoiceStatus.missing,
        null => VoiceStatus.checking,
      };

  bool hasVoice(LanguageInfo language) =>
      voiceStatus(language) == VoiceStatus.available;

  /// Whether [language] can be heard now: the phone has a voice for it, and
  /// sound is on in Settings. What decides whether listening is drilled;
  /// with sound off it is skipped, as on a phone with no voice at all.
  /// [voiceStatus] and [hasVoice] stay the phone's own, for the Voices page
  /// and for whether a speaker shows.
  bool canSpeak(LanguageInfo language) =>
      settings.soundOn && hasVoice(language);

  /// Asks the engine about every catalog language again, for when the
  /// learner has been off to install a voice.
  Future<void> refreshVoices() async {
    for (final language in languages) {
      final tag = language.ttsTag;
      try {
        _voices[tag] = await _tts.isLanguageAvailable(tag);
      } catch (_) {
        _voices[tag] = false;
      }
    }
    notifyListeners();
  }

  /// The voices the engine offers for [language].
  Future<List<TtsVoice>> voicesFor(LanguageInfo language) =>
      _tts.voicesFor(language.ttsTag);

  /// Speaks [text] in [language] at the learner's speech rate, or slower.
  /// Completes when playback ends. Does nothing without a voice, or while
  /// sound is off in Settings.
  Future<void> speak(
    String text,
    LanguageInfo language, {
    bool slower = false,
  }) async {
    if (!settings.soundOn) return;
    await _tts.speak(
      text,
      bcp47: language.ttsTag,
      rate: settings.ttsRate(slower: slower),
    );
  }

  Future<void> stopSpeaking() => _tts.stop();

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

  /// Cards due tomorrow, as Today will count them: in the decks the profile
  /// learns, in the skills switched on, and not set aside.
  int dueTomorrow() {
    final modes = _modes(ignorePauses: true);
    final learned = <String>{
      for (final entry in profileDecks)
        for (final card in entry.cards) card.id,
    };
    final leeches = progress.leechEffects;
    return progress.dueTomorrow(
      now(),
      counts: (key) =>
          learned.contains(key.cardId) &&
          modes.contains(key.mode) &&
          !leeches.isSetAside(key),
    );
  }

  /// Whether this version can drill anything in [entry]: some card has a
  /// mode whose drill is available. A grammar deck cannot until its drill
  /// ships (#14). The learner's own skill switches do not count here.
  bool canDrill(DeckEntry entry) {
    final shipped = <DrillMode>{
      for (final skill in Skill.values)
        if (features.isAvailable(skill.feature)) ...skill.modes,
    };
    return entry.cards.any(
      (card) => card.modesIn(ttsAvailable: true).any(shipped.contains),
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
    return <LanguageInfo>[
      for (final code in <String>[
        ...chosen.where(all.containsKey),
        ...all.keys.where((code) => !chosen.contains(code)),
      ])
        if (buildSession(DrillRequest.today(language: code)).isNotEmpty)
          all[code]!,
    ];
  }

  /// The queue for [request], built by [SessionQueue] from the catalog, the
  /// progress store, the settings, the feature registry and the voices.
  ///
  /// Today's counts, a deck's counts and the drill itself all come from
  /// here, so they always agree.
  /// [ignorePauses] builds it as if no skill were paused: a pause lasts an
  /// hour and does not make a deck finished, so [notStudiedIn] ignores it.
  SessionQueue buildSession(DrillRequest request, {bool ignorePauses = false}) {
    final ids = request.deckIds;
    final language = request.language;
    final decks = ids == null
        ? <DeckEntry>[
            for (final entry in profileDecks)
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
    final cards = tagged(<Card>[for (final entry in decks) ...entry.cards]);

    // A named skill is drilled even if switched off in Settings, as the
    // deck page offers it, but not while it is paused.
    final named = request.named;
    final modes = named == null
        ? _modes(ignorePauses: ignorePauses)
        : <DrillMode>{
            for (final skill in named)
              if (features.isAvailable(skill.feature) &&
                  (ignorePauses || !settings.isPaused(skill, now())))
                ...skill.modes,
          };

    // A new pair is a new skill of a word already taught: a word is new
    // once, in its lesson (ADR-0024). Only an untaught request takes those
    // of words not taught yet.
    final newLimit = request.revise ? 0 : cards.length;

    // A skill switched off for a language is not drilled in it (#89), and
    // nothing is heard while sound is off.
    final voiced = <String, bool>{
      for (final entry in this.decks)
        entry.id:
            canSpeak(entry.language) &&
            !settings.isOffFor(Skill.listening, entry.language.code),
    };
    final heard = <String, bool>{
      for (final entry in this.decks)
        entry.id:
            canHear(entry.language) &&
            !settings.isOffFor(Skill.speaking, entry.language.code),
    };
    final leeches = progress.leechEffects;
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
          leeches.isSetAside((cardId: card.id, mode: mode)),
      reviseAll: request.revise,
      // A session of new cards only offers a card's new pair even while
      // another of its pairs is due, so a deck with reviews due is not
      // taken for finished.
      newEvenIfDue: request.newOnly,
      modes: modes,
      canIntroduce: canIntroduce,
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

  void _forgetPending() => _pendingUnits = null;

  /// Whether placement found the learner already knows [entry]. It reads
  /// Done and Today does not teach it, though it can still be studied.
  bool isPlaced(DeckEntry entry) => settings.isPlaced(entry.id);

  /// Whether the path is past [entry]: it is placed, this version can drill
  /// nothing in it, or every card in it is learned in the skills on.
  bool isFinished(DeckEntry entry) =>
      isPlaced(entry) || !canDrill(entry) || notStudiedIn(entry) == 0;

  /// The units Today teaches new cards from: for each language the profile
  /// learns, the first unit of its course's path that is not finished and
  /// the one after it. The course is the one taught from the best-known
  /// language the learner speaks, as [profileDecks] orders them. A course
  /// without a path is taught as if each deck were a unit, in catalog order,
  /// and a deck its path leaves out follows it as a unit of its own.
  List<List<DeckEntry>> get pendingUnits => _pendingUnits ??= _findPending();

  /// Whether [entry] is in one of the [pendingUnits].
  bool isPending(DeckEntry entry) =>
      pendingUnits.any((unit) => unit.any((e) => e.id == entry.id));

  List<List<DeckEntry>> _findPending() {
    final languages = <String>{
      for (final entry in profileDecks) entry.language.code,
    };
    return List<List<DeckEntry>>.unmodifiable(<List<DeckEntry>>[
      for (final code in languages)
        ...courseUnits(code).where((unit) => !unit.every(isFinished)).take(2),
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
  /// [alphabet] overrides whether the alphabet is learned, and [native]
  /// which language it is learned from, for placement, which asks before
  /// either is saved.
  List<List<DeckEntry>> courseUnits(
    String language, {
    bool? alphabet,
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
    // need it.
    if (path != null && !(alphabet ?? settings.learnsAlphabet(language))) {
      course.removeWhere((e) => path.alphabet.contains(e.id));
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
      !settings.learnsAlphabet(entry.language.code) && needsAlphabet(entry);

  /// Whether [entry] is one of its course's decks that need the alphabet:
  /// a script, spelling or reading deck.
  bool needsAlphabet(DeckEntry entry) =>
      pathOf(entry)?.alphabet.contains(entry.id) ?? false;

  /// Whether the learner is past [language]'s script units: the first run
  /// of units on its path whose decks all need the alphabet, each finished
  /// or placed. Until then typed answers start in Latin letters and count
  /// in full. True for a course with no such units.
  bool scriptLearned(String language) {
    final units = courseUnits(language, alphabet: true);
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
  /// chosen among its own row's alone ([formChoices], spec 4.8).
  List<Card> choicePool(Card card, Ask ask) {
    final entry = deckOf(card);
    if (entry == null) return const <Card>[];
    if (ask.choosesAmongForms) return formChoices(card, ask, entry.cards);
    final right = ask.optionOf(card);
    final cell = card.modes.contains(DrillMode.grammar);
    bool alike(Card c) =>
        c.id != card.id &&
        c is! QuestionCard &&
        c is! NumberCard &&
        c.modes.contains(DrillMode.grammar) == cell &&
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
    final entry = deckOf(card);
    if (id == null || entry == null) return null;
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
  /// one (spec 4.8: a row of two forms is still a choice). Without, it is
  /// asked its own way.
  bool canChoose(Card card, Ask ask) =>
      choicePool(card, ask).map(ask.optionOf).toSet().length >=
      (ask.choosesAmongForms ? 1 : 2);

  /// The items of the session for [request], each asked as a review asks it
  /// ([reviewAsks]): what a drill runs.
  List<SessionItem> sessionItems(DrillRequest request) => reviewAsks(
    _limited(buildSession(request).items, request.limit),
    canChoose: (item) => canChoose(
      item.card,
      item.ask == Ask.own ? Ask.chooseMeaning : item.ask,
    ),
    hearsForm: (item) => hearsForm(item.card),
    recallsFirst: (item) => recallsFirst(item.card, item.mode),
  );

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
  /// means: a card of a deck that teaches the alphabet, which is script
  /// practice (ADR-0034), or a generated number.
  bool hearsForm(Card card) {
    if (card is NumberCard) return true;
    final entry = deckOf(card);
    return entry != null && needsAlphabet(entry);
  }

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
  int revisableIn(Set<Skill>? skills) => <String>{
    for (final item in buildSession(
      DrillRequest(revise: true, skills: skills),
    ).items)
      item.card.id,
  }.length;

  // ---------------------------------------------------------------------------
  // Lessons (ADR-0024)

  /// Whether [card] has been taught: some skill of it has been drilled.
  bool isTaught(Card card) =>
      DrillMode.values.any((mode) => progress.stateOf(card.id, mode) != null);

  /// The modes [card] can be drilled in now: those it takes, switched on
  /// and not paused, by ear only with a voice and sound on and by mouth
  /// only with a recogniser, each on for its language, and none set aside.
  Set<DrillMode> drillableModes(Card card) {
    final entry = deckOf(card);
    if (entry == null) return const <DrillMode>{};
    final language = entry.language;
    final modes = _modes(ignorePauses: false);
    final leeches = progress.leechEffects;
    return <DrillMode>{
      for (final mode in card.modesIn(
        ttsAvailable:
            canSpeak(language) &&
            !settings.isOffFor(Skill.listening, language.code),
        speechAvailable:
            canHear(language) &&
            !settings.isOffFor(Skill.speaking, language.code),
      ))
        if (modes.contains(mode) &&
            !leeches.isSetAside((cardId: card.id, mode: mode)))
          mode,
    };
  }

  /// The cards a lesson in [language] can teach, in their order: from
  /// [deckId], or else from the pending units (ADR-0013). Those not taught
  /// yet that can be drilled now.
  List<Card> untaughtCards(String language, {String? deckId}) {
    final cards = deckId != null
        ? deckById(deckId)?.cards ?? const <Card>[]
        : _alternating(<List<DeckEntry>>[
            for (final unit in pendingUnits)
              if (unit.first.language.code == language) unit,
          ]);
    final seen = <String>{};
    return <Card>[
      for (final card in cards)
        if (seen.add(card.id) &&
            !isTaught(card) &&
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
  List<SessionItem> lessonFor(DrillRequest request) {
    final cards = untaughtCards(
      request.language!,
      deckId: request.deckIds?.single,
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
    return <SessionItem>[
      for (final item in lessonPlan(
        lessonItems(cards.takeWhile((card) => card is! QuestionCard)),
        modesOf: drillableModes,
        canChoose: (card, ask) => canChoose(
          card,
          ask == Ask.hearMeaning && hearsForm(card) ? Ask.hearAndChoose : ask,
        ),
      ))
        item.ask == Ask.hearMeaning && hearsForm(item.card)
            ? item.askedAs(Ask.hearAndChoose)
            : item,
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
  int notStudiedIn(DeckEntry deck) => <String>{
    for (final item in buildSession(
      DrillRequest.untaught(deck.id),
      ignorePauses: true,
    ).fresh)
      if (!isTaught(item.card)) item.card.id,
  }.length;

  /// How numbers are spelled in [language], or null for a language with no
  /// number rules (#54).
  NumberRules? numberRulesFor(LanguageInfo language) =>
      _catalog.numberRules[language.code];

  /// [language]'s script guide (#30, ADR-0016), or null if it has none.
  ScriptGuide? scriptGuideFor(LanguageInfo language) =>
      _catalog.scriptGuides[language.code];

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
  ReviewEvent record(
    SessionItem item,
    int grade, {
    Duration elapsed = Duration.zero,
    String? answerGiven,
  }) {
    final event = progress.record(
      deckId: item.card.deckId,
      cardId: item.card.id,
      mode: item.mode,
      grade: grade,
      now: now(),
      elapsed: elapsed,
      answerGiven: answerGiven,
    );
    if (settings.autoAdjust) tuner.afterReview(event);
    return event;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_forgetPending);
    progress.removeListener(_forgetPending);
    shellTab.dispose();
    updates.dispose();
    tuner.dispose();
    pacing.dispose();
    volume.dispose();
    if (_ownsSettings) settings.dispose();
    super.dispose();
  }
}

/// A language's fact for today, and its text in the learner's languages.
typedef TodayFact = ({
  LanguageInfo language,
  Fact fact,
  List<({String code, String text})> texts,
});
