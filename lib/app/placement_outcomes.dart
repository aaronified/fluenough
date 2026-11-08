import '../core/placement/outcome_log.dart';
import '../core/placement/placement_profile.dart';
import '../core/placement/placement_questions.dart' show PlacementSkill;
import '../core/placement/v3_result.dart';
import '../core/placement/v3_session.dart';
import 'app_state.dart';
import 'placement_run_setup.dart';

// The local outcome log of Find my level V3 and what is done with it
// (wiki/Plan-Placement-V3.md, "Adapting placement to a language"): a record of
// every placement, joined with the learner's own first real reviews of the
// pairs it placed, giving signals (placed too high, too low, range too narrow
// or wide); bounded, reversible corrections of the language's profile, applied
// only after enough evidence and only inside the language's gated edge; and
// the opt-in export. Local only, never shown to the learner.

/// How many of a skill's first real reviews after a placement the join reads.
const int kJoinReviews = 60;

/// Whether [refreshPlacementSignals] may also move a language's correction.
/// Off: it records the signals and never changes the carefulness, so the
/// profile of a run is always the file's. Turning it on needs a fix first
/// (wiki/Plan-Placement-V3.md, "Step 8b"): step only on new decided signals
/// since the last step, and tally only outcomes made at the current
/// correction, or the same evidence is applied again on every run.
const bool kAutoCorrectPlacement = false;

extension PlacementOutcomes on AppState {
  /// Records the placement [run] ended with, as [result] states it and the
  /// learner's changes left it, under [profile].
  void logPlacementOutcome(
    String code,
    V3Run run,
    V3Result result,
    PlacementProfile profile,
    PlacementBand band,
  ) {
    final edge = kGatedEdges[code];
    final skills = <String, SkillOutcome>{
      for (final s in result.skills)
        if (s.placed)
          s.skill.name: SkillOutcome(
            start: s.startUnit,
            low: s.lowUnit,
            high: s.highUnit,
            label: switch (s.confidence?.name) {
              'high' => 'sure',
              'medium' => 'fairlySure',
              _ => 'notSureYet',
            },
          ),
    };
    final outcome = PlacementOutcome(
      language: code,
      day: now().toUtc().millisecondsSinceEpoch ~/ 86400000,
      profileVersion: profile.version,
      carefulness: edge == null ? 0 : carefulnessOf(profile, edge),
      band: band.name,
      skills: skills,
      itemsByFormat: run.itemsByFormat,
      right: run.rightAnswers,
      wrong: run.wrongAnswers,
      dontKnow: run.dontKnowAnswers,
      drillCases: run.drillCases,
    );
    settings.setPlacementOutcomes(code, <PlacementOutcome>[
      ...settings.placementOutcomesOf(code),
      outcome,
    ]);
  }

  /// Joins [code]'s recorded placements with the learner's own real reviews
  /// since, fills in each placement's signals, and moves the language's
  /// correction one bounded step when the evidence is enough (logged). A
  /// language with no gated edge is never moved.
  void refreshPlacementSignals(String code, PlacementRunPlan plan) {
    final outcomes = settings.placementOutcomesOf(code);
    if (outcomes.isEmpty) return;
    final deckIndex = <String, int>{
      for (final (i, entry) in plan.decks.indexed) entry.id: i,
    };
    final next = <PlacementOutcome>[];
    var tally = const SignalTally();
    for (final o in outcomes) {
      final signals = Map<String, String>.of(o.signals);
      for (final MapEntry(key: name, value: skill) in o.skills.entries) {
        if (signals.containsKey(name)) continue;
        final skillValue = PlacementSkill.values.asNameMap()[name];
        if (skillValue == null) continue;
        final modes = placementModesOf(skillValue);
        final samples = <ReviewSample>[];
        final seen = <String>{};
        for (final e in progress.log) {
          if (samples.length >= kJoinReviews) break;
          if (e.isPlaced || !modes.contains(e.mode)) continue;
          if (e.at.toUtc().millisecondsSinceEpoch ~/ 86400000 <= o.day) {
            continue;
          }
          final at = deckIndex[e.deckId];
          if (at == null) continue;
          // The first review of a pair only (the log is in order).
          if (!seen.add('${e.deckId}|${e.cardId}|${e.mode.name}')) continue;
          samples.add(
            ReviewSample(
              skill: name,
              unitsFromStart: at + 1 - skill.start,
              correct: e.passed,
            ),
          );
        }
        final s = signalOf(skill, samples);
        if (s != PlacementSignal.insufficient) signals[name] = s.name;
      }
      next.add(signals.length == o.signals.length ? o : o.withSignals(signals));
      for (final v in signals.values) {
        final s = PlacementSignal.values.asNameMap()[v];
        if (s != null) tally = tally.plus(s);
      }
    }
    if (next.length == outcomes.length &&
        <bool>[
          for (var i = 0; i < next.length; i++) identical(next[i], outcomes[i]),
        ].every((same) => same)) {
      // Nothing new to record; the correction is still looked at below.
    } else {
      settings.setPlacementOutcomes(code, next);
    }
    if (!kAutoCorrectPlacement) return;
    final current = settings.placementCorrectionOf(code);
    final proposed = correctedCarefulness(
      tally: tally,
      current: current,
      hasEdge: kGatedEdges.containsKey(code),
    );
    if (proposed != current) {
      settings.setPlacementCorrection(code, proposed);
      log.event(
        'Placement correction: $code carefulness $current to $proposed '
        '(too high ${tally.tooHigh}, too low ${tally.tooLow}, '
        'ok ${tally.ok}, narrow ${tally.narrow}, wide ${tally.wide})',
      );
    }
  }

  /// [resolved] moved further toward [code]'s gated edge by the learner's own
  /// corrections, if there are any (never past the edge, never for a language
  /// without one).
  PlacementProfile correctedPlacementProfile(
    String code,
    PlacementProfile resolved,
  ) {
    final edge = kGatedEdges[code];
    final c = settings.placementCorrectionOf(code);
    if (edge == null || c <= 0) return resolved;
    final base = carefulnessOf(resolved, edge);
    if (c <= base) return resolved;
    final moved = profileAt(c, edge);
    return PlacementProfile(
      version: resolved.version,
      declarationWeight: moved.declarationWeight,
      togetherShare: moved.togetherShare,
      temper: moved.temper,
      guessScale: moved.guessScale,
      slipScale: moved.slipScale,
      standApartItems: moved.standApartItems,
      mixedBonus: moved.mixedBonus,
    ).within(edge);
  }

  /// The opt-in export of every recorded placement ("Share placement data"):
  /// no words, no answers, no audio, no dates finer than a day. Null when
  /// there is nothing to share.
  String? placementExport(String appVersion) {
    final all = settings.allPlacementOutcomes.toList();
    return all.isEmpty ? null : exportOutcomes(all, appVersion);
  }
}
