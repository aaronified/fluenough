#!/usr/bin/env python3
"""Tests for generate_roadmap.py, offline, on a recorded fixture."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_roadmap as gr  # noqa: E402

FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "roadmap_api.json")
                     .read_text(encoding="utf-8"))
PLANS = [
    {"name": "Plan-Tracked", "title": "Tracked", "written": "Written 2026-10-10.", "tracks": [12]},
    {"name": "Plan-Loose", "title": "Loose", "written": "", "tracks": []},
]


def issue(number: int, login: str = "aaronified", labels: tuple = (), **kw) -> dict:
    return {"number": number, "title": "t", "state": "open",
            "user": {"login": login}, "labels": [{"name": n} for n in labels], **kw}


class Approval(unittest.TestCase):
    def test_owner_and_approved_label_count(self) -> None:
        self.assertTrue(gr.is_approved(issue(1)))
        self.assertTrue(gr.is_approved(issue(1, "x", ("approved",))))

    def test_strangers_app_reports_and_pull_requests_stay_out(self) -> None:
        self.assertFalse(gr.is_approved(issue(1, "x")))
        self.assertFalse(gr.is_approved(issue(1, labels=("from-app",))))
        self.assertTrue(gr.is_approved(issue(1, labels=("from-app", "approved"))))
        self.assertFalse(gr.is_approved(issue(1, pull_request={})))


class Rendering(unittest.TestCase):
    def setUp(self) -> None:
        self.text = gr.render(FIXTURE, PLANS)

    def test_releases_newest_first_and_drafts_left_out(self) -> None:
        self.assertLess(self.text.index("v0.5.0"), self.text.index("v0.4.3"))
        self.assertNotIn("v0.5.1", self.text)

    def test_milestones_in_version_order_not_text_order(self) -> None:
        self.assertLess(self.text.index("### 0.6.0"), self.text.index("### 0.10.0"))

    def test_groups_by_label_then_description_order(self) -> None:
        t = self.text
        self.assertLess(t.index("#12"), t.index("#14"))  # bugs, by description then number
        self.assertLess(t.index("#14"), t.index("#10"))  # bugs before enhancements
        self.assertLess(t.index("#10"), t.index("#11"))  # enhancements before the rest

    def test_unapproved_issues_are_absent(self) -> None:
        for n in ("#13", "#15", "#17"):
            self.assertNotIn(n, self.text)

    def test_unscheduled_section_and_any_order(self) -> None:
        section = self.text.split("## Approved, not scheduled")[1].split("## Plans")[0]
        self.assertIn("#16", section)
        self.assertNotIn("#12", section)

    def test_untracked_plan_is_flagged(self) -> None:
        line = next(l for l in self.text.splitlines() if "Plan-Loose" in l)
        self.assertIn("no tracking issue", line)
        tracked = next(l for l in self.text.splitlines() if "Plan-Tracked" in l)
        self.assertIn("tracks #12", tracked)

    def test_plan_labelled_issue_naming_the_plan_tracks_it(self) -> None:
        data = {**FIXTURE, "issues": FIXTURE["issues"] + [
            issue(99, labels=("plan",), body="See Plan-Loose in the wiki.")]}
        line = next(l for l in gr.render(data, PLANS).splitlines() if "Plan-Loose" in l)
        self.assertIn("tracks #99", line)

    def test_same_input_gives_same_file(self) -> None:
        self.assertEqual(self.text, gr.render(FIXTURE, PLANS))


class PlanParsing(unittest.TestCase):
    def test_title_written_and_tracks(self) -> None:
        p = gr.parse_plan("Plan-X", "# Plan: Profiles\n\nWritten 2026-10-10.\nTracks #204 (a) and\n#97 (b).\n\nMore #5.\n")
        self.assertEqual(p["title"], "Profiles")
        self.assertEqual(p["written"], "Written 2026-10-10.")
        self.assertEqual(p["tracks"], [97, 204])


class Overwrite(unittest.TestCase):
    def test_hand_edit_is_overwritten_and_clean_file_is_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            fx, out = Path(d) / "f.json", Path(d) / "Roadmap.md"
            fx.write_text(json.dumps(FIXTURE), encoding="utf-8")
            args = ["--fixture", str(fx), "--out", str(out)]
            self.assertEqual(gr.main(args), 0)
            clean = out.read_text(encoding="utf-8")
            self.assertEqual(gr.main(args + ["--check"]), 0)
            out.write_text(clean + "\nhand edit\n", encoding="utf-8")
            self.assertEqual(gr.main(args + ["--check"]), 1)
            gr.main(args)
            self.assertEqual(out.read_text(encoding="utf-8"), clean)


if __name__ == "__main__":
    unittest.main()
