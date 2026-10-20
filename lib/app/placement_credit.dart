import '../core/models/card.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/ask.dart';
import 'app_state.dart';
import 'placement.dart';
import 'placement_plan.dart';
import 'skill.dart';

/// The grade a placement entry is recorded with: 5, which Easy is when a
/// review has no answer given (`Fsrs.ratingOf`), so that a card placement
/// found known comes up rarely.
const int _placedGrade = 5;

typedef _Credit = ({String deckId, DrillMode mode, String? script});

/// What placement credits the learner with (#677): reviews in the log for
/// what it found they know, so the schedule has history for it.
extension PlacementCredit on AppState {
  /// Credits what placement found for [code]'s course, and returns how many
  /// reviews it wrote.
  ///
  /// - A script placed as read ([ScriptStanding.reads]) is credited Read
  ///   and Write: each card of its script decks gets a Recognition and a
  ///   Production review in the script, which are the script skills' reviews
  ///   (`SkillMap.scriptOf`).
  /// - A script placed at its letters or joined letters is credited Read
  ///   for the decks it placed, those of its letters and composites, and no
  ///   Write.
  /// - The cards of the other decks in [placed] get a review in each skill
  ///   the learner has switched on.
  ///
  /// The reviews are Easy answers given today, as if the learner had
  /// mastered the card, so each first comes due after the Easy interval and the
  /// card then comes up rarely. A pair that already has a review keeps it:
  /// a retake changes nothing.
  int creditPlacement(
    String code, {
    required Set<String> placed,
    Map<String, ScriptStanding> standings = const <String, ScriptStanding>{},
    String? native,
  }) {
    final wanted = <String, List<_Credit>>{};
    void want(Card card, String deckId, DrillMode mode, String? script) {
      if (progress.stateOf(card.id, mode) != null) return;
      final list = wanted.putIfAbsent(card.id, () => <_Credit>[]);
      if (list.any((c) => c.mode == mode)) return;
      list.add((deckId: deckId, mode: mode, script: script));
    }

    final scriptDeckIds = <String>{};
    for (final script in placementScripts(code, native: native)) {
      final standing = standings[script.script] ?? ScriptStanding.newTo;
      final credited = ScriptCheck.placedFor(script.decks, standing);
      for (final entry in script.decks) {
        if (!entry.isScript || !credited.contains(entry.id)) continue;
        if (!placed.contains(entry.id)) continue;
        scriptDeckIds.add(entry.id);
        for (final card in entry.cards) {
          want(card, entry.id, DrillMode.recognition, script.script);
          if (standing == ScriptStanding.reads) {
            want(card, entry.id, DrillMode.production, script.script);
          }
        }
      }
    }

    final on = <DrillMode>{
      for (final skill in Skill.values)
        if (!skill.hasSwitch || settings.isEnabled(skill)) ...skill.modes,
    };
    final speaks = settings.isEnabled(Skill.speaking);
    for (final id in placed) {
      final entry = deckById(id);
      if (entry == null || entry.language.code != code) continue;
      if (scriptDeckIds.contains(id) || entry.isScript) continue;
      for (final card in entry.cards) {
        for (final mode in card.modesIn(
          ttsAvailable: true,
          speechAvailable: speaks,
        )) {
          if (on.contains(mode)) want(card, id, mode, null);
        }
      }
    }
    if (wanted.isEmpty) return 0;

    final at = now();
    var written = 0;
    for (final MapEntry(key: id, value: credits) in wanted.entries) {
      for (final credit in credits) {
        progress.record(
          deckId: credit.deckId,
          cardId: id,
          mode: credit.mode,
          grade: _placedGrade,
          now: at,
          script: credit.script,
          asked: Ask.own,
        );
        written++;
      }
    }
    return written;
  }
}
