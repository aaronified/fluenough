"""How many reviews a facet needs: the one number (ADR-0058, decision 12).

The same number is `kReviewQuorum` in `lib/core/review/review_quorum.dart`;
`test/review_quorum_test.dart` reads both files and keeps them equal. It is
never shown in the app. This replaces the GitHub variable or secret
`REVIEW_AGREEMENTS_NEEDED` of ADR-0038: changing the number is a code change
in both files.

Imported by `tools/review_bot.py` (and so `tools/mail_to_issues.py`) and by
the deck tools.
"""

from __future__ import annotations

from typing import Iterable

# Reviews by distinct reviewers a facet needs.
REVIEW_QUORUM = 2

# Whether the quorum also needs a Verified reviewer among the checks. Off
# until W7 (signed reviewer keys) turns it on: every reviewer is Provisional
# today. Matches `kQuorumNeedsVerified` in the Dart file.
QUORUM_NEEDS_VERIFIED = False

PROVISIONAL = "provisional"
VERIFIED = "verified"
TRUSTED = "trusted"
TIERS = (PROVISIONAL, VERIFIED, TRUSTED)


def facet_reached_quorum(
        checks: Iterable[tuple],
        quorum: int = REVIEW_QUORUM,
        needs_verified: bool = QUORUM_NEEDS_VERIFIED) -> bool:
    """Whether [checks] give a facet the quorum; the same rule as
    `facetReachedQuorum` in the Dart file.

    [checks] are tuples (rater code, tier) or (rater code, tier, endorses),
    in the order they were made, for ONE facet. With no third item a check
    is a bare endorsement (a code in `checked_by`); pass False for a flag.
    The caller must not drop flags: a flag is how a rater's later answer
    replaces an earlier "right". Each code counts once, by its latest
    answer. If any code's latest answer is a flag the facet is not settled.
    Otherwise it needs [quorum] distinct codes, and with [needs_verified] at
    least one Verified or Trusted; a code counts at the best tier it appears
    at, and an unknown tier is Provisional."""
    endorsing: dict[str, bool] = {}
    best: dict[str, int] = {}
    for check in checks:
        rater, tier = check[0], check[1]
        key = (rater or "").strip().upper()
        if not key:
            continue
        endorsing[key] = check[2] if len(check) > 2 else True
        rank = TIERS.index(tier) if tier in TIERS else 0
        best[key] = max(best.get(key, 0), rank)
    if not all(endorsing.values()) or len(endorsing) < quorum:
        return False
    return not needs_verified or any(rank > 0 for rank in best.values())
