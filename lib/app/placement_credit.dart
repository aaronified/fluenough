import 'dart:math';

import '../core/models/card.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/ask.dart';
import '../core/scheduling/fsrs.dart';
import 'app_state.dart';
import 'placement.dart';
import 'placement_plan.dart';
import 'skill.dart';

/// The soonest a placed card first comes due, in days after placement
/// (`docs/plans/placement-v2.md`, "Placed cards get reviews").
const int kPlacedFirstDueMin = 14;

/// One past the latest: first due dates fall on days 14 to 27, so every
/// placed card is due within four weeks.
const int kPlacedFirstDueEnd = 28;

/// The grade a placement entry is recorded with: Good (4), as if the card
/// was answered once on the day of placement.
const int _placedGrade = 4;

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
  /// The reviews are placement entries: Good answers given on the day of
  /// placement, dated so that the first due dates are spread evenly over
  /// days [kPlacedFirstDueMin] to [kPlacedFirstDueEnd] after it, in an order
  /// [random] shuffles (seed it in tests), so that placement does not make
  /// a pile of reviews on one day. A pair that already has a review keeps it:
  /// a retake never replaces a real review.
  int creditPlacement(
    String code, {
    required Set<String> placed,
    Map<String, ScriptStanding> standings = const <String, ScriptStanding>{},
    String? native,
    Random? random,
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

    final ids = wanted.keys.toList()..sort();
    ids.shuffle(random ?? Random());
    final base = now();
    const span = kPlacedFirstDueEnd - kPlacedFirstDueMin;
    var written = 0;
    for (final (i, id) in ids.indexed) {
      final due = kPlacedFirstDueMin + i * span ~/ ids.length;
      for (final credit in wanted[id]!) {
        final interval = Fsrs.next(
          null,
          _placedGrade,
          now: base,
          rated: true,
          parameters: progress.parameters.forPair((
            cardId: id,
            mode: credit.mode,
          )),
        ).intervalDays;
        // Dated so that its interval ends on the day it is to come due: the
        // log replays to the same state.
        progress.record(
          deckId: credit.deckId,
          cardId: id,
          mode: credit.mode,
          grade: _placedGrade,
          now: base.add(Duration(days: due - interval)),
          script: credit.script,
          asked: Ask.own,
        );
        written++;
      }
    }
    return written;
  }
}
