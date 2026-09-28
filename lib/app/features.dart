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
  drillGrammar(2),
  drillPair(31),
  translitInput(47),

  // Today.
  dailyFacts(48),

  // Data.
  persistence(5),
  stats(18),
  leeches(19),
  logExport(20),
  logImport(20),

  // Adding decks.
  importFile(22),
  importUrl(22),
  importCsv(0),
  importAnki(23),

  // Settings.
  reminder(21),
  uiLanguage(46),
  voiceSettingsLink(0),

  // Appearance.
  appearance(15),
  colourSeeds(0),
  dynamicColour(0),
  contrast(26),
  cardSize(26),

  // Profiles.
  profiles(0),
  pinLock(0),
  deleteProfile(0);

  const Feature(this.issue);

  /// The issue whose PR turns this feature on, or, for a feature that is
  /// already on, the issue that asked for it.
  ///
  /// 0 means no issue exists yet. That is allowed only for the features the
  /// UI plan lists as having none — profiles and PINs, colour seeds and
  /// wallpaper colours, in-app CSV import, and the voice settings link, which
  /// needs a dependency first — and `test/app/features_test.dart` holds the
  /// list.
  final int issue;

  /// What this version ships switched on.
  ///
  /// The recognition, production and listening drills run on the bundled
  /// decks through `DeckParser`, `AnswerGrader` and in-memory SM-2. Everything
  /// else waits for its backend.
  static const Set<Feature> available = <Feature>{
    Feature.drillRecognition,
    Feature.drillProduction,
    Feature.drillListening,
    Feature.drillGrammar,
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
