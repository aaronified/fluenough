"""The review quorum constant and its rule (ADR-0058, W2).

The equality with the Dart constant is tested in
`test/review_quorum_test.dart`, which reads both files.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import review_quorum as rq  # noqa: E402


class QuorumTest(unittest.TestCase):
    def test_two_and_the_verified_switch_is_off(self) -> None:
        self.assertEqual(rq.REVIEW_QUORUM, 2)
        self.assertFalse(rq.QUORUM_NEEDS_VERIFIED)

    def test_distinct_codes_reach_it(self) -> None:
        p = rq.PROVISIONAL
        self.assertFalse(rq.facet_reached_quorum([]))
        self.assertFalse(rq.facet_reached_quorum([("A", p)]))
        self.assertFalse(rq.facet_reached_quorum([("A", p), (" a ", p)]))
        self.assertTrue(rq.facet_reached_quorum([("A", p), ("B", p)]))
        self.assertFalse(rq.facet_reached_quorum([("", p), ("  ", p), ("A", p)]))

    def test_the_verified_switch(self) -> None:
        p, v, t = rq.PROVISIONAL, rq.VERIFIED, rq.TRUSTED
        two = [("A", p), ("B", p)]
        self.assertFalse(rq.facet_reached_quorum(two, needs_verified=True))
        self.assertTrue(rq.facet_reached_quorum(
            [("A", v), ("B", p)], needs_verified=True))
        self.assertTrue(rq.facet_reached_quorum(
            [("A", p), ("B", t)], needs_verified=True))
        # One code at two tiers is one reviewer.
        self.assertFalse(rq.facet_reached_quorum(
            [("A", p), ("A", v)], needs_verified=True))
        # An unknown tier is Provisional.
        self.assertFalse(rq.facet_reached_quorum(
            [("A", "bogus"), ("B", p)], needs_verified=True))

    def test_right_flag_right_is_not_settled(self) -> None:
        p = rq.PROVISIONAL
        self.assertFalse(rq.facet_reached_quorum(
            [("A", p, True), ("B", p, False), ("C", p, True)]))

    def test_a_rater_changing_right_to_flag_stops_counting(self) -> None:
        p = rq.PROVISIONAL
        two = [("A", p), ("B", p)]
        self.assertTrue(rq.facet_reached_quorum(two))
        self.assertFalse(rq.facet_reached_quorum(two + [("b", p, False)]))
        self.assertTrue(rq.facet_reached_quorum(
            two + [("B", p, False), ("B", p, True)]))


if __name__ == "__main__":
    unittest.main()
