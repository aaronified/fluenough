/// Everything the design draws, and which of it this version can do.
///
/// The UI is built from the design as a whole (docs/adr/0008). A feature
/// whose backend has not landed is still built and shown, disabled, with a
/// "Feature incoming" badge; see `IncomingFeature` in
/// `lib/ui/widgets/incoming.dart`. This file is the single switch.
///
/// **To turn a feature on**, the PR that lands its backend adds it to
/// [Feature.available] — a one-line diff in a file nobody else edits — and
/// adds a widget test showing the screen working live.
///
/// This is interface policy, which is why it lives in `lib/app` and not in
/// `lib/core`.
enum Feature {
  // Drills.
  drillRecognition(10),
  drillProduction(11),
  drillListening(13),
  drillSpeaking(89),
  drillGrammar(2),
  drillPair(31),
  drillReading(98),
  translitInput(47),

  // Today.
  dailyFacts(48),

  // Data.
  persistence(5),
  stats(18),
  leeches(19),
  logExport(20),
  logImport(20),
  cloudBackup(112),

  // Adding decks.
  importFile(22),
  importUrl(22),
  importCsv(0),

  // Feedback: support, bug reports and feedback by mail. Until it is on,
  // every report button opens a new GitHub issue instead.
  feedbackMail(160),

  // The app's own log, its section in Settings, and the box that attaches
  // it to a report.
  logs(162),

  // Settings.
  reminder(90),
  uiLanguage(46),
  // Settings > Voices opens the phone's text-to-speech settings, through
  // the app's own platform channel (lib/app/system_settings.dart).
  voiceSettingsLink(0),

  // Appearance.
  appearance(15),
  colourSeeds(0),
  dynamicColour(0),
  contrast(26),
  cardSize(26),

  // Profiles.
  profiles(204),
  pinLock(204),
  deleteProfile(204);

  const Feature(this.issue);

  /// The issue whose PR turns this feature on, or, for a feature that is
  /// already on, the issue that asked for it.
  ///
  /// 0 means no issue exists yet. That is allowed only for the features the
  /// UI plan lists as having none — profiles and PINs, colour seeds and
  /// wallpaper colours, in-app CSV import, and the voice settings link, which
  /// was built without one — and `test/app/features_test.dart` holds the
  /// list.
  final int issue;

  /// What this version ships switched on.
  ///
  /// The recognition, production and listening drills run on the bundled
  /// decks through `DeckParser`, `AnswerGrader` and in-memory FSRS. Everything
  /// else waits for its backend.
  static const Set<Feature> available = <Feature>{
    Feature.drillRecognition,
    Feature.drillProduction,
    Feature.drillListening,
    Feature.drillGrammar,
    Feature.drillSpeaking,
    Feature.drillReading,
    Feature.translitInput,
    Feature.persistence,
    Feature.appearance,
    Feature.colourSeeds,
    Feature.contrast,
    Feature.cardSize,
    Feature.stats,
    Feature.leeches,
    Feature.dailyFacts,
    Feature.logExport,
    Feature.logImport,
    Feature.importFile,
    Feature.voiceSettingsLink,
    Feature.feedbackMail,
    Feature.logs,
  };
}

/// Which [Feature]s are switched on, read by widgets through `AppState`.
///
/// Production uses [FeatureRegistry.shipped]. Tests and the debug gallery use
/// [FeatureRegistry.all] to see every screen live, or [FeatureRegistry.only]
/// to pin a state.
class FeatureRegistry {
  const FeatureRegistry.only(this._on);

  /// What this version ships: [Feature.available].
  const FeatureRegistry.shipped() : _on = Feature.available;

  /// Every feature on, as if every backend had landed.
  FeatureRegistry.all() : _on = Set<Feature>.unmodifiable(Feature.values);

  final Set<Feature> _on;

  bool isAvailable(Feature feature) => _on.contains(feature);

  /// Built but not yet switched on: shown disabled, with a badge.
  bool isIncoming(Feature feature) => !isAvailable(feature);
}
