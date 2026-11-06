import 'assurance_model.dart';
import 'placement_data.dart';
import 'placement_questions.dart';

// A paused "Find my level" run (wiki/Plan-Placement-V2.md, section 5.5 and
// row n of section 6): "the run is saved after every answer; resumed within
// 7 days with the same deck set and app version, else discarded with no
// answer carried; nothing is written until the run ends or the learner
// stops". The run's state is its answers, so what is saved is the settings of
// the run and the events of its session (`PlacementSession.events`).

/// How long a paused run waits to be resumed.
const Duration savedRunLife = Duration(days: 7);

/// A run saved after an answer.
class SavedPlacementRun {
  const SavedPlacementRun({
    required this.language,
    required this.declaration,
    required this.skills,
    required this.seed,
    required this.microphone,
    required this.deckSet,
    required this.appVersion,
    required this.savedAt,
    required this.events,
  });

  /// The language's code.
  final String language;

  /// The learner's first answer, kept for the run only (never shown after).
  final PlacementDeclaration declaration;

  /// The skills in play.
  final Set<PlacementSkill> skills;

  final int seed;

  /// Whether the recogniser worked when the run began.
  final bool microphone;

  /// A key of the deck set the run was asked from ([placementDeckSetKey]).
  final String deckSet;

  final String appVersion;

  /// When it was saved, in whole seconds since the epoch.
  final int savedAt;

  /// The session's events: `a1`, `a0`, `k`, `m`.
  final List<String> events;

  /// Whether the run can still be carried on at [nowSeconds], with the deck
  /// set and app version it was saved under.
  bool isFresh({
    required int nowSeconds,
    required String deckSet,
    required String appVersion,
  }) =>
      this.deckSet == deckSet &&
      this.appVersion == appVersion &&
      nowSeconds >= savedAt &&
      nowSeconds - savedAt <= savedRunLife.inSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
    'language': language,
    'declaration': declaration.name,
    'skills': <String>[for (final s in skills) s.name]..sort(),
    'seed': seed,
    'microphone': microphone,
    'deck_set': deckSet,
    'app_version': appVersion,
    'saved_at': savedAt,
    'events': events,
  };

  /// The run [json] holds, or null for anything that is not one.
  static SavedPlacementRun? fromJson(Object? json) {
    if (json is! Map) return null;
    final language = json['language'];
    final declaration = PlacementDeclaration.values
        .asNameMap()[json['declaration']];
    final skills = json['skills'];
    final seed = json['seed'];
    final microphone = json['microphone'];
    final deckSet = json['deck_set'];
    final appVersion = json['app_version'];
    final savedAt = json['saved_at'];
    final events = json['events'];
    if (language is! String ||
        declaration == null ||
        skills is! List ||
        seed is! int ||
        microphone is! bool ||
        deckSet is! String ||
        appVersion is! String ||
        savedAt is! int ||
        events is! List) {
      return null;
    }
    const known = <String>{'a1', 'a0', 'k', 'm'};
    final names = PlacementSkill.values.asNameMap();
    return SavedPlacementRun(
      language: language,
      declaration: declaration,
      skills: <PlacementSkill>{for (final s in skills) ?names[s]},
      seed: seed,
      microphone: microphone,
      deckSet: deckSet,
      appVersion: appVersion,
      savedAt: savedAt,
      events: <String>[
        for (final e in events)
          if (e is String && known.contains(e)) e,
      ],
    );
  }
}

/// A key of what a run is asked from: the decks in path order with how many
/// cards each has, and the cards left out as already known well. A run saved under another key is discarded,
/// because its answers would not replay onto other questions.
String placementDeckSetKey(PlacementLanguageData data) {
  // FNV-1a over the deck ids and card counts: stable on every platform.
  var hash = 0x811c9dc5;
  void mix(int unit) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }

  for (final deck in data.decks) {
    for (final unit in deck.id.codeUnits) {
      mix(unit);
    }
    mix(0x7c);
    for (final unit in '${deck.cards.length}'.codeUnits) {
      mix(unit);
    }
    mix(0x3b);
  }
  // Cards the learner has since come to know well are left out of the
  // questions, so they are part of the key too.
  for (final id in data.stableCardIds.toList()..sort()) {
    for (final unit in id.codeUnits) {
      mix(unit);
    }
    mix(0x2c);
  }
  return '${data.decks.length}-${hash.toRadixString(16)}';
}
