import 'package:flutter/foundation.dart';

import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/session_queue.dart';
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

/// A deck's numbers, as its row and its detail screen show them.
///
/// [due] and [fresh] are what a session on the deck would drill right now,
/// in every skill the learner has on; [session] is the two together, which is
/// what "Review all due" runs and a deck's badge counts.
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
       _currentProfileId = currentProfileId ?? profiles.first.id;

  /// An app on fakes, for widget tests: the real bundled decks unless
  /// [decks] is given, no voices unless [tts] has some, empty in-memory
  /// progress, and a clock fixed at [now] — by default Monday 28 September
  /// 2026, 19:00, the evening the design is drawn on.
  factory AppState.test({
    DeckSource? decks,
    TtsEngine tts = const NullTtsEngine(),
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
      features: features,
      clock: () => fixed,
      logFiles: logFiles,
      settings: settings,
      profiles: profiles,
      currentProfileId: currentProfileId,
    );
    // Past the first-launch setup (#53), unless a test brings its own.
    if (settings == null) state.settings.spokenLanguages = const <String>['en'];
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
  }

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

  Profile get currentProfile =>
      profileById(_currentProfileId) ?? _profiles.first;

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
    final cards = <Card>[
      for (final entry in decks)
        for (final card in entry.cards)
          if (tags.isEmpty || card.tags.any(tags.contains)) card,
    ];

    final skill = request.skill;
    final modes = skill == null
        ? sessionModes
        : <DrillMode>{
            if (skill.mode != null && features.isAvailable(skill.feature))
              skill.mode!,
          };

    var newLimit = newCardsLeftToday;
    final requested = request.newLimit;
    if (requested != null && requested < newLimit) newLimit = requested;

    final voiced = <String, bool>{
      for (final entry in decks) entry.id: hasVoice(entry.language),
    };
    final leeches = progress.leechEffects;
    final queue = SessionQueue.build(
      cards: cards,
      stateOf: (card, mode) => progress.stateOf(card.deckId, card.id, mode),
      hasVoice: (card) => voiced[card.deckId] ?? false,
      now: now(),
      newCardLimit: newLimit,
      isSetAside: (card, mode) => leeches.isSetAside((
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
      )),
      modes: modes,
    );
    return request.newOnly ? queue.withoutDue() : queue;
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

  @override
  void dispose() {
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
