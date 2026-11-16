import '../core/languages/language_skills.dart';
import '../core/placement/placement_check.dart';
import '../core/placement/placement_questions.dart' show PlacementSkill;
import '../core/scheduling/placement_withdrawal.dart';
import '../core/scheduling/replay.dart' show logged;
import 'app_state.dart';
import 'placement_run_setup.dart';

/// Checking a placement again (wiki, Plan-Placement-V2, point 17): which
/// moments of a language's credit are unconfirmed, what level they hold, and
/// what Keep the old level writes. What Use the new level writes is
/// `writePlacementRun` with `recheck`.
extension PlacementRecheck on AppState {
  /// The moments of [code]'s credit an earlier version found and the learner
  /// has not confirmed: at or after 0.9.0, with no model stamp or the stamp of
  /// the model before V3, not kept, and
  /// with credit still in the log. Worked out each time, never stored.
  Set<int> unconfirmedMomentsOf(String code) {
    final placed = settings.placedAtOf(code);
    // Credit of V3 is confirmed; that of the guess-proof model of 0.9.2 and
    // the unstamped credit of 0.9.0 and 0.9.1 are not (thin evidence).
    final stamped = <int>{
      for (final MapEntry(:key, :value)
          in settings.placedModelsOf(code).entries)
        if (isConfirmedModel(value)) key,
    };
    final kept = settings.placementKeptOf(code);
    // Most profiles have none: their log is never looked at.
    final candidates = flaggableMoments(
      placedAt: placed,
      stamped: stamped,
      kept: kept,
    );
    if (candidates.isEmpty) return const <int>{};
    final live = <int>{};
    for (final e in progress.log) {
      if (e.grade != 5 || e.answerGiven != null) continue;
      final moment = momentOf(e.at);
      if (!candidates.contains(moment) || live.contains(moment)) continue;
      if (deckLanguage(e.deckId) != code) continue;
      if (hasCreditShape(logged(e))) live.add(moment);
    }
    return unconfirmedMoments(
      placedAt: placed,
      stamped: stamped,
      kept: kept,
      live: live,
    );
  }

  /// For each word skill, the highest path index of a deck of [plan] that
  /// holds a credited pair of the skill's drills at an unconfirmed moment,
  /// after earlier withdrawals (point 17.4). Worked out from the log, never
  /// stored; a skill with no such credit is not in the map (-1 is "from the
  /// start" on the screen, but there is nothing to compare for it).
  Map<PlacementSkill, int> creditedLevelsOf(
    String code,
    PlacementRunPlan plan,
  ) {
    final moments = unconfirmedMomentsOf(code);
    if (moments.isEmpty) return const <PlacementSkill, int>{};
    final index = <String, int>{
      for (final (i, entry) in plan.decks.indexed) entry.id: i,
    };
    const word = <PlacementSkill>[
      PlacementSkill.read,
      PlacementSkill.hear,
      PlacementSkill.say,
      PlacementSkill.write,
    ];
    final out = <PlacementSkill, int>{};
    for (final e in progress.log) {
      if (e.grade != 5 || e.answerGiven != null || e.script != null) continue;
      final at = index[e.deckId];
      if (at == null || !moments.contains(momentOf(e.at))) continue;
      if (deckLanguage(e.deckId) != code || !hasCreditShape(logged(e))) {
        continue;
      }
      for (final skill in word) {
        if (!placementModesOf(skill).contains(e.mode)) continue;
        final was = out[skill];
        if (was == null || at > was) out[skill] = at;
      }
    }
    return out;
  }

  /// Keep the old level: the unconfirmed moments are kept, nothing else is
  /// written (no credit, labels or Verified marks), and the paused run is
  /// dropped.
  void keepOldLevel(String code) {
    settings.keepPlacementMoments(code, unconfirmedMomentsOf(code));
    settings.setPlacementRun(code, null);
  }

  /// The keys a script known from another language started as Know in
  /// [code] (`autoKnownFrom`), over [shape]'s scripts and the learner's other
  /// languages, English included. Worked out at run time, never stored
  /// (point 17.6).
  Set<SkillKey> autoKnownKeysOf(String code, List<SkillKey> shape) {
    final scripts = <String>{
      for (final key in shape)
        if (key.script != null) key.script!,
    };
    final others = <String, LanguageSkills>{
      for (final other in settings.languagesWithSkills)
        if (other != code && other != englishCode)
          other: LanguageSkills.fromStored(
            settings.languageSkillsOf(other) ?? const <String, String>{},
          ),
      if (code != englishCode) englishCode: englishKnownByDefault(),
    };
    return autoKnownFrom(scripts: scripts, others: others).keys.toSet();
  }
}
