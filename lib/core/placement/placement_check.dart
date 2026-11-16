// Which placements are unconfirmed, and what a recheck changes (wiki,
// Plan-Placement-V2, point 17). Pure: no Flutter, no storage.

/// The model of Find my level V3 (wiki/Plan-Placement-V3.md), which every
/// credit it writes is stamped with (`placed_by`). The credit of the guess-
/// proof model of 0.9.2 (model 2, with its 95% stop and its P(none) readout)
/// and the unstamped credit of 0.9.0 and 0.9.1 are older than it: they are
/// unconfirmed until the learner checks again or keeps them
/// ([isConfirmedModel]).
const int kPlacementModel = 3;

/// The model of Find my level before V3 (0.9.2 and later): thin evidence and
/// a readout the plan no longer stands behind.
const int kV2PlacementModel = 2;

/// Whether credit stamped with [model] is confirmed: V3's own, and the older
/// placement test's (which is a different test, never flagged).
bool isConfirmedModel(int model) =>
    model == kOlderPlacementModel || model >= kPlacementModel;

/// The model of the older placement test (onboarding and the language
/// picker), which every credit it writes from 0.9.3 on is stamped with. It is
/// a stamp like any other, so it is never unconfirmed; it only says which
/// test made the credit. A moment stamped before 0.9.3 keeps the model it
/// has: the older test's credit of the 0.9.2 window carries the stamp 2, which
/// is also the stamp of Find my level before V3, and the two cannot be told
/// apart. Such a moment is therefore offered "Check again" like the credit of
/// the guess-proof model (a harmless offer: Keep the old level confirms it).
/// Credit stamped with this constant (1) or with [kPlacementModel] or later is
/// never flagged.
const int kOlderPlacementModel = 1;

/// The release of 0.9.0 (2026-11-06T20:08:07Z), when Find my level first
/// shipped. A credit before it comes from the older placement test and is not
/// flagged.
const int kPlacementCheckFrom = 1793995687;

/// The moments of a language whose placement is unconfirmed: those in
/// [placedAt] at or after [from], with no model in [stamped], not [kept] by
/// the learner at a Check again, and with credit still [live] in the log (a
/// moment all of whose credit is withdrawn has nothing left to confirm).
///
/// Worked out each time and never stored, so evaluating it twice gives the
/// same answer, nothing has to run once, and a settings map restored without
/// `placed_by` or `placement_kept` is flagged again, which is right.
Set<int> unconfirmedMoments({
  required Set<int> placedAt,
  required Set<int> stamped,
  required Set<int> kept,
  required Set<int> live,
  int from = kPlacementCheckFrom,
}) => <int>{
  for (final moment in placedAt)
    if (moment >= from &&
        !stamped.contains(moment) &&
        !kept.contains(moment) &&
        live.contains(moment))
      moment,
};

/// The moments of [placedAt] that could be unconfirmed before the log is
/// looked at: the rest of [unconfirmedMoments]'s rule, so that a profile with
/// none never has its log scanned.
Set<int> flaggableMoments({
  required Set<int> placedAt,
  required Set<int> stamped,
  required Set<int> kept,
  int from = kPlacementCheckFrom,
}) => unconfirmedMoments(
  placedAt: placedAt,
  stamped: stamped,
  kept: kept,
  live: placedAt,
  from: from,
);
