import 'assurance_model.dart';
import 'placement_questions.dart';
import 'saved_run.dart' show savedRunLife;
import 'v3_session.dart' show V3ScriptStart;

// A paused V3 "Find my level" run (wiki/Plan-Placement-V3.md, step 7): the
// settings of the run and its events ([V3Run.events]); the run is rebuilt by
// [V3Run.replay]. It is stored in the same settings slot as the V2 run was
// ([SavedPlacementRun]): the two readers each return null for the other's
// JSON, so an old paused run is dropped, never misread (the version key `v`
// is 3 here, absent there).

/// The version of the V3 saved run.
const int kSavedRunVersion = 3;

class SavedV3Run {
  const SavedV3Run({
    required this.language,
    required this.skills,
    required this.seed,
    required this.audio,
    required this.recogniser,
    required this.scriptStart,
    required this.deckSet,
    required this.appVersion,
    required this.savedAt,
    required this.events,
    this.declaration,
    this.starter = false,
    this.profile = 1,
  });

  final String language;
  final PlacementDeclaration? declaration;
  final Set<PlacementSkill> skills;
  final int seed;

  /// What the phone could do when the run began: its answers replay onto
  /// other questions if that changes.
  final bool audio;
  final bool recogniser;
  final V3ScriptStart scriptStart;
  final String deckSet;
  final String appVersion;
  final int savedAt;
  final List<String> events;

  /// Whether the run began with the first formats' items only.
  final bool starter;

  /// The version of the calibration profile the run read its constants from:
  /// a run is resumed on the same constants it began with.
  final int profile;

  bool isFresh({
    required int nowSeconds,
    required String deckSet,
    required String appVersion,
  }) =>
      this.deckSet == deckSet &&
      this.appVersion == appVersion &&
      nowSeconds >= savedAt &&
      nowSeconds - savedAt <= savedRunLife.inSeconds;

  /// Whether this phone can still ask the run as it was begun.
  bool fitsDevice({required bool audio, required bool recogniser}) =>
      (audio || !this.audio) && (recogniser || !this.recogniser);

  Map<String, Object?> toJson() => <String, Object?>{
    'v': kSavedRunVersion,
    'language': language,
    'declaration': declaration?.name,
    'skills': <String>[for (final s in skills) s.name]..sort(),
    'seed': seed,
    'audio': audio,
    'recogniser': recogniser,
    'script_start': scriptStart.name,
    'deck_set': deckSet,
    'app_version': appVersion,
    'saved_at': savedAt,
    'events': events,
    'starter': starter,
    'profile': profile,
  };

  /// The run [json] holds, or null for anything that is not one (a V2 run
  /// included).
  static SavedV3Run? fromJson(Object? json) {
    if (json is! Map || json['v'] != kSavedRunVersion) return null;
    final language = json['language'];
    final skills = json['skills'];
    final seed = json['seed'];
    final audio = json['audio'];
    final recogniser = json['recogniser'];
    final deckSet = json['deck_set'];
    final appVersion = json['app_version'];
    final savedAt = json['saved_at'];
    final events = json['events'];
    if (language is! String ||
        skills is! List ||
        seed is! int ||
        audio is! bool ||
        recogniser is! bool ||
        deckSet is! String ||
        appVersion is! String ||
        savedAt is! int ||
        events is! List) {
      return null;
    }
    const known = <String>{'r', 'w', 'd', 'u', 'm', 'a', 'k', 'x'};
    final names = PlacementSkill.values.asNameMap();
    return SavedV3Run(
      language: language,
      declaration: PlacementDeclaration.values.asNameMap()[json['declaration']],
      skills: <PlacementSkill>{for (final s in skills) ?names[s]},
      seed: seed,
      audio: audio,
      recogniser: recogniser,
      scriptStart:
          V3ScriptStart.values.asNameMap()[json['script_start']] ??
          V3ScriptStart.ask,
      deckSet: deckSet,
      appVersion: appVersion,
      savedAt: savedAt,
      events: <String>[
        for (final e in events)
          if (e is String && known.contains(e)) e,
      ],
      starter: json['starter'] == true,
      profile: json['profile'] is int && (json['profile'] as int) > 0
          ? json['profile'] as int
          : 1,
    );
  }
}
