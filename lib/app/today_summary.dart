import 'dart:convert';

import 'app_info.dart';
import 'skill.dart';

/// The skill tiles' numbers and what sits beside them, as Today last drew
/// them, kept as plain data (#857, #875).
///
/// Today draws them at launch, before the catalog is read, so that the
/// tiles are there at once instead of a spinner; the live numbers replace
/// them as soon as the catalog is ready. Nothing here is a source of truth:
/// a summary that does not read back, or that was written by another app
/// version, for other languages or with other skills switched on, is
/// ignored ([TodaySummaries.read]).
class TodaySummary {
  const TodaySummary({
    required this.hasDecks,
    required this.due,
    required this.bySkill,
    required this.dueIn,
    required this.revisable,
    required this.script,
    required this.noVoice,
    required this.streak,
    required this.newWords,
  });

  /// Whether the profile learned a language that has a deck.
  final bool hasDecks;

  /// Words in today's session.
  final int due;

  /// Today's session per skill, for each skill that had a tile.
  final Map<Skill, int> bySkill;

  /// What a review of each skill alone held.
  final Map<Skill, int> dueIn;

  /// With nothing due, the words a skill could revise.
  final Map<Skill, int> revisable;

  /// The Script tile's numbers, or null when there was none.
  final ({int count, int due, int revisable})? script;

  /// Listening was on but no voice was on the phone.
  final bool noVoice;

  /// Days in a row with a review.
  final int streak;

  /// Words taught that day.
  final int newWords;

  Map<String, Object?> toJson() => <String, Object?>{
    'decks': hasDecks,
    'due': due,
    'by': _named(bySkill),
    'in': _named(dueIn),
    'rev': _named(revisable),
    'script': script == null
        ? null
        : <int>[script!.count, script!.due, script!.revisable],
    'voice': noVoice,
    'streak': streak,
    'new': newWords,
  };

  /// The summary [json] holds, or null if any part of it is missing or of
  /// the wrong kind.
  static TodaySummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final decks = json['decks'];
    final due = json['due'];
    final voice = json['voice'];
    final streak = json['streak'];
    final fresh = json['new'];
    final by = _skills(json['by']);
    final dueIn = _skills(json['in']);
    final rev = _skills(json['rev']);
    if (decks is! bool ||
        due is! int ||
        voice is! bool ||
        streak is! int ||
        fresh is! int ||
        by == null ||
        dueIn == null ||
        rev == null) {
      return null;
    }
    final raw = json['script'];
    ({int count, int due, int revisable})? script;
    if (raw != null) {
      if (raw is! List || raw.length != 3 || !raw.every((n) => n is int)) {
        return null;
      }
      script = (
        count: raw[0] as int,
        due: raw[1] as int,
        revisable: raw[2] as int,
      );
    }
    return TodaySummary(
      hasDecks: decks,
      due: due,
      bySkill: by,
      dueIn: dueIn,
      revisable: rev,
      script: script,
      noVoice: voice,
      streak: streak,
      newWords: fresh,
    );
  }

  static Map<String, int> _named(Map<Skill, int> counts) => <String, int>{
    for (final MapEntry(:key, :value) in counts.entries) key.name: value,
  };

  static Map<Skill, int>? _skills(Object? json) {
    if (json is! Map) return null;
    final names = Skill.values.asNameMap();
    final out = <Skill, int>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final skill = names[key];
      if (skill == null || value is! int) return null;
      out[skill] = value;
    }
    return out;
  }
}

/// The saved [TodaySummary] of each language shown (a language's code, or
/// `*` for all together), under a stamp that says what they were worked out
/// for.
abstract final class TodaySummaries {
  /// Bumped when the saved form changes.
  static const int format = 1;

  /// The stamp of a summary: this format, this app version, the languages
  /// learned in the learner's order, and the skills switched on. Any change
  /// makes the saved summaries stale, which are then ignored.
  static String stamp({
    required Iterable<String> languages,
    required Iterable<Skill> enabled,
  }) =>
      '$format|${AppInfo.version}|${languages.join(',')}|'
      '${[for (final s in enabled) s.name].join(',')}';

  /// [summary] for [language], added to what [saved] holds for the same
  /// [stamp], as text to keep.
  static String write({
    required String? saved,
    required String stamp,
    required String language,
    required TodaySummary summary,
  }) {
    final held = _held(saved, stamp);
    held[language] = summary.toJson();
    return jsonEncode(<String, Object?>{'stamp': stamp, 'languages': held});
  }

  /// The summary [saved] holds for [language], or null if there is none, it
  /// is stale (another [stamp]) or it is unreadable.
  static TodaySummary? read({
    required String? saved,
    required String stamp,
    required String language,
  }) => TodaySummary.fromJson(_held(saved, stamp)[language]);

  static Map<String, Object?> _held(String? saved, String stamp) {
    if (saved == null || saved.isEmpty) return <String, Object?>{};
    try {
      final json = jsonDecode(saved);
      if (json is! Map || json['stamp'] != stamp) return <String, Object?>{};
      final languages = json['languages'];
      if (languages is! Map) return <String, Object?>{};
      return <String, Object?>{
        for (final MapEntry(:key, :value) in languages.entries)
          if (key is String) key: value,
      };
    } on FormatException {
      return <String, Object?>{};
    }
  }
}
