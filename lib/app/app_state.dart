import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/course_path.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import '../core/models/number_rules.dart';
import '../core/numbers/number_practice.dart';
import '../core/scheduling/session_queue.dart';
import '../core/speech/speech_engine.dart';
import '../core/tts/tts_engine.dart';
import '../core/data/themes.dart';
import '../core/models/fact.dart';
import '../core/scheduling/daily_fact.dart';
import 'deck_catalog.dart';
import 'features.dart';
import 'log_files.dart';
import 'memory_progress.dart';
import 'profile.dart';
import 'session.dart';
import 'settings.dart';
import 'shell_tab.dart';
import 'skill.dart';

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
    this.features = const FeatureRegistry.shipped(),
    this._clock = DateTime.now,
    this.logFiles = const PickerLogFiles(),
    SettingsNotifier? settings,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
  }) : assert(profiles.isNotEmpty, 'there is always a profile'),
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

  /// An app on fakes, for widget tests: the real bundled decks unless
  /// [decks] is given, no voices unless [tts] has some, empty in-memory
  /// progress, and a clock fixed at [now] — by default Monday 28 September
  /// 2026, 19:00, the evening the design is drawn on.
  factory AppState.test({
    DeckSource? decks,
    TtsEngine tts = const NullTtsEngine(),
    SpeechEngine speech = const NullSpeechEngine(),
    ProgressStore? progress,
    FeatureRegistry features = const FeatureRegistry.shipped(),
    DateTime? now,
    LogFiles logFiles = const PickerLogFiles(),
    SettingsNotifier? settings,
    List<Profile> profiles = const <Profile>[Profile.defaultProfile],
    String? currentProfileId,
  }) {
    final fixed = now ?? DateTime(2026, 9, 28, 19);
    final state = AppState(
      catalog: decks == null ? DeckCatalog.bundled() : DeckCatalog(decks),
      progress: progress ?? MemoryProgress(),
      tts: tts,
      speech: speech,
      features: features,
      clock: () => fixed,
      logFiles: logFiles,
      settings: settings,
      profiles: profiles,
      currentProfileId: currentProfileId,
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

  /// The catalog loader. Screens read decks through [decks] and [deckById];
  /// this is exposed so that gallery fixtures can share one loaded catalog.
  final DeckCatalog deckCatalog;

  final TtsEngine _tts;
  final SpeechEngine _speech;
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

  Future<void> _load() async {
    try {
      _catalog = await deckCatalog.load();
      _status = CatalogStatus.ready;
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
  /// Completes when playback ends. Does nothing without a voice.
  Future<void> speak(
    String text,
    LanguageInfo language, {
    bool slower = false,
  }) => _tts.speak(
    text,
    bcp47: language.ttsTag,
    rate: settings.ttsRate(slower: slower),
  );

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
  Set<DrillMode> get sessionModes => <DrillMode>{
    for (final skill in Skill.values)
      if (skill.mode != null &&
          settings.isEnabled(skill) &&
          features.isAvailable(skill.feature))
        skill.mode!,
  };

  /// Whether this version can drill anything in [entry]: some card has a
  /// mode whose drill is available. A grammar deck cannot until its drill
  /// ships (#14). The learner's own skill switches do not count here.
  bool canDrill(DeckEntry entry) {
    final shipped = <DrillMode>{
      for (final skill in Skill.values)
        if (skill.mode != null && features.isAvailable(skill.feature))
          skill.mode!,
    };
    return entry.cards.any(
      (card) => card.modesIn(ttsAvailable: true).any(shipped.contains),
    );
  }

  /// New pairs today may still introduce: the daily cap less those already
  /// introduced.
  int get newCardsLeftToday {
    final left = settings.newCardsPerDay - progress.newIntroducedOn(now());
    return left < 0 ? 0 : left;
  }

  /// The queue for [request], built by [SessionQueue] from the catalog, the
  /// progress store, the settings, the feature registry and the voices.
  ///
  /// Today's counts, a deck's counts and the drill itself all come from
  /// here, so they always agree.
  SessionQueue buildSession(DrillRequest request) {
    final ids = request.deckIds;
    final decks = ids == null
        ? profileDecks
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

    final skill = request.skill;
    final modes = skill == null
        ? sessionModes
        : <DrillMode>{
            if (skill.mode != null && features.isAvailable(skill.feature))
              skill.mode!,
          };

    var newLimit = request.revise
        ? 0
        : request.pastDailyCap
        ? cards.length
        : newCardsLeftToday;
    final requested = request.newLimit;
    if (requested != null && requested < newLimit) newLimit = requested;

    final voiced = <String, bool>{
      for (final entry in this.decks) entry.id: hasVoice(entry.language),
    };
    final heard = <String, bool>{
      for (final entry in this.decks) entry.id: canHear(entry.language),
    };
    final leeches = progress.leechEffects;
    SessionQueue queueOf(
      List<Card> cards, {
      required int newCardLimit,
      bool Function(Card card)? canIntroduce,
    }) => SessionQueue.build(
      cards: cards,
      stateOf: (card, mode) => progress.stateOf(card.deckId, card.id, mode),
      hasVoice: (card) => voiced[card.deckId] ?? false,
      canHear: (card) => heard[card.deckId] ?? false,
      now: now(),
      newCardLimit: newCardLimit,
      isSetAside: (card, mode) => leeches.isSetAside((
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
      )),
      reviseAll: request.revise,
      modes: modes,
      canIntroduce: canIntroduce,
    );

    // Today, and "Learn 5 new", teach new cards only from the pending units
    // (ADR-0013): an equal share of the day's for each language, in a block
    // of its own, each block mixing its course's two units. Reviews come
    // from every deck the profile learns.
    final SessionQueue queue;
    if (ids == null && !request.revise) {
      final byLanguage = <String, List<List<DeckEntry>>>{};
      for (final unit in pendingUnits) {
        (byLanguage[unit.first.language.code] ??= <List<DeckEntry>>[]).add(
          unit,
        );
      }
      final blocks = <List<SessionItem>>[
        for (final units in byLanguage.values)
          queueOf(
            tagged(_alternating(units)),
            newCardLimit: newLimit,
            canIntroduce: (card) =>
                units.any((unit) => unit.any((e) => e.id == card.deckId)),
          ).fresh,
      ];
      queue = SessionQueue.of(
        due: queueOf(cards, newCardLimit: 0).due,
        fresh: SessionQueue.fairShares(blocks, newLimit),
      );
    } else {
      queue = queueOf(cards, newCardLimit: newLimit);
    }
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

  /// The units of [language]'s course, in teaching order: the course taught
  /// from the best-known language the learner speaks that has one, else the
  /// first in the catalog. Its path's units, or without a path each deck as
  /// a unit, in catalog order; a deck its path leaves out follows as a unit
  /// of its own. Empty if no deck teaches [language]. Whether the profile
  /// learns it does not matter: placement asks before it does.
  List<List<DeckEntry>> courseUnits(String language) {
    final teaching = <DeckEntry>[
      for (final entry in decks)
        if (entry.language.code == language) entry,
    ];
    if (teaching.isEmpty) return const <List<DeckEntry>>[];
    int rank(DeckEntry e) =>
        settings.rankOf(e.deck.native.code) ?? settings.spokenLanguages.length;
    final native = teaching
        .reduce((best, e) => rank(e) < rank(best) ? e : best)
        .deck
        .native
        .code;
    final course = <DeckEntry>[
      for (final entry in teaching)
        if (entry.deck.native.code == native) entry,
    ];
    final byId = <String, DeckEntry>{for (final e in course) e.id: e};
    final path = pathOf(course.first);
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

  /// Cards in [deck] with a pair never drilled, in every skill the learner
  /// has on, whatever today's cap allows. None left means the deck is
  /// finished: its badge says Done when nothing is due, and it can be
  /// revised.
  int notStudiedIn(DeckEntry deck) =>
      buildSession(DrillRequest.learnAnyway(deck.id)).fresh.length;

  /// How numbers are spelled in [language], or null for a language with no
  /// number rules (#54).
  NumberRules? numberRulesFor(LanguageInfo language) =>
      _catalog.numberRules[language.code];

  /// Generated numbers to practise in [deck]'s language, in the skills the
  /// learner has on, by ear only with a voice. Never recorded (ADR-0011).
  List<SessionItem> numberPracticeFor(DeckEntry deck, {Random? random}) {
    final rules = numberRulesFor(deck.language);
    if (rules == null) return const <SessionItem>[];
    return numberPractice(
      rules,
      deckId: deck.id,
      modes: <DrillMode>{
        for (final mode in sessionModes)
          if (mode != DrillMode.listening || hasVoice(deck.language)) mode,
      },
      random: random ?? Random(),
    );
  }

  /// A deck's due reviews, new pairs within today's allowance, and cards
  /// learned, in every skill the learner has on.
  DeckCounts countsFor(DeckEntry deck) {
    final queue = buildSession(DrillRequest.deck(deck.id));
    return (
      due: queue.due.length,
      fresh: queue.fresh.length,
      learned: progress.learnedIn(deck.id),
    );
  }

  /// Records [grade] for [item] the moment the answer is given, and returns
  /// the review. Minimal pairs have no mode and are not recorded.
  ReviewEvent record(
    SessionItem item,
    int grade, {
    Duration elapsed = Duration.zero,
    String? answerGiven,
  }) => progress.record(
    deckId: item.card.deckId,
    cardId: item.card.id,
    mode: item.mode,
    grade: grade,
    now: now(),
    elapsed: elapsed,
    answerGiven: answerGiven,
  );

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_forgetPending);
    progress.removeListener(_forgetPending);
    shellTab.dispose();
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
