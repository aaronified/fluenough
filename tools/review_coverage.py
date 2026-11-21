#!/usr/bin/env python3
"""The reviewer coverage report (ADR-0058, work package W5), for the OWNER.

Reads a checkout of the decks (the decks-live layout: `decks/<language>/...`)
and prints, per course, how far the review of its facets has got, as a
Markdown table:

- the share of facets that have reached the review quorum (`REVIEW_QUORUM`,
  tools/review_quorum.py): "Settled";
- the share where reviewers agreed on one fix, nothing left for a human to
  decide but to apply it: "Agreed fix" (fixes are compared after the
  per-script folds of `tools/review_facets.py`);
- the share still being checked (fewer reviews than the quorum, or none);
- the share flagged (a tag, no fix two agree on) and contested (reviewers
  disagree), which need a third speaker.

Every figure is a share of facets, with the number of facets it is a share
of. **Nothing here names or counts a reviewer**: no rater code, no
reviewer count, no tier. It is for the owner and is never shown in the app.

    python3 tools/review_coverage.py [ROOT] [--out FILE]

ROOT is the checkout holding `decks/` (default: the current directory).
Exit status: 0, or 2 for a bad argument. The manual workflow
`.github/workflows/review-coverage.yml` runs it against decks-live and writes
the table to the job summary.
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_facets as rf  # noqa: E402

# The columns, in order: the status of a facet (`facet_status`) each counts.
# "checking" and "unchecked" share the column "Being checked".
COLUMNS = (
    ("Settled", ("settled",)),
    ("Agreed fix", ("agreed_fix",)),
    ("Being checked", ("checking", "unchecked")),
    ("Flagged", ("flagged",)),
    ("Contested", ("contested",)),
)

# Entry forms (`proposals.Entry.form`) that hold the card itself, as
# `check_reviewed_cards` and the bot treat them: a reference to a card in
# another file owns no facet of it.
_HOLDS_CARD = ("single", "core", "layer-own")
_REFERENCES = ("ref", "core-ref")


def statuses_of(root: Path, lang: str) -> Counter:
    """How many facets of course [lang] are in each status."""
    counts: Counter = Counter()
    for entry in pr.entries(root, lang):
        if entry.form in _REFERENCES:
            continue
        codes = pr.checked_by(entry)
        held = rf.read_facet_data(entry.data.get("facet_checks"))
        native = pr.native_code_of(lang, entry)
        for facet in rf.owned_facets_of(entry.data, entry.form in _HOLDS_CARD):
            checks = rf.checks_of(codes, held, facet, lang)
            language = rf.language_of_facet(facet, lang, native or "")
            counts[rf.facet_status(checks, language=language)] += 1
    return counts


def _share(part: int, whole: int) -> str:
    return f"{100 * part / whole:.1f}%" if whole else "-"


def report(root: Path) -> str:
    """The Markdown table for the decks under [root]."""
    rows: list[tuple[str, Counter]] = []
    for lang in pr.languages(root):
        counts = statuses_of(root, lang)
        if sum(counts.values()):
            rows.append((lang, counts))
    total: Counter = Counter()
    for _lang, counts in rows:
        total.update(counts)
    head = ["Course", "Facets", *(name for name, _ in COLUMNS)]
    lines = ["| " + " | ".join(head) + " |",
             "|---|" + "---:|" * (len(head) - 1)]
    for lang, counts in [*rows, ("All courses", total)]:
        whole = sum(counts.values())
        cells = [_share(sum(counts[s] for s in statuses), whole) for _, statuses in COLUMNS]
        lines.append("| " + " | ".join([lang, str(whole), *cells]) + " |")
    note = ("Shares of facets (a facet is one checkable part of a card: its word, "
            "reading, meaning and so on). Settled means the quorum of reviews "
            "is reached with nobody disagreeing; Flagged and Contested need "
            "another speaker. Owner only: no reviewers are named or counted.")
    return "\n".join(["## Review coverage", "", *lines, "", note, ""])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("root", nargs="?", default=".", type=Path)
    parser.add_argument("--out", type=Path, help="write the table here as well")
    try:
        args = parser.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    if not (args.root / "decks").is_dir():
        print(f"no decks/ folder in {args.root}", file=sys.stderr)
        return 2
    text = report(args.root)
    print(text)
    if args.out:
        args.out.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
