"""Shared set-up of the deck-kinds validator tests (not a test itself).

Each test copies test/fixtures/deck-kinds/decks, the valid example set of the
plan's kinds (wiki/Plan-Deck-Kinds-And-Topics.md) in a made-up language, into
a temporary directory, breaks one thing, and checks the message. The fixture
is the passing case of every rule. Today is frozen so a rule that reads the
year (the public-domain floor, a date in the future) does not drift.
"""

from __future__ import annotations

import contextlib
import datetime
import io
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import yaml

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import validate_decks  # noqa: E402

REPO = TOOLS.parent
FIXTURE = REPO / "test" / "fixtures" / "deck-kinds" / "decks"
TODAY = datetime.date(2026, 11, 12)

CULTURE = "zz/zz-culture-ejemplo.yaml"
CULTURE_LAYER = "zz/en/zz-en-culture-ejemplo.yaml"
READING = "zz/zz-en-culture-lectura.yaml"
PROVERBS = "zz/zz-proverbs-ejemplo.yaml"
MULTIWORD = "zz/zz-multiword-ejemplo.yaml"
MEDICINE = "zz/zz-medicine-registro.yaml"
PATH = "zz/zz-path.yaml"
TOPICS = "zz/zz-topics.yaml"
SCRIPT = "zz/zz-script.yaml"
CREATORS = "creators/zz.yaml"
RECS = "recommendations/zz.yaml"
SECTIONS = "sections.yaml"


def load(path: Path) -> object:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=validate_decks.DeckLoader)


def dump(data: object) -> str:
    return yaml.safe_dump(data, allow_unicode=True, sort_keys=False, width=1000)


def card(deck: dict, cid: str) -> dict:
    return next(c for c in deck["cards"] if c.get("id") == cid)


class KindsCase(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.root = self.tmp / "decks"
        shutil.copytree(FIXTURE, self.root)
        patch = mock.patch.object(validate_decks, "_today", return_value=TODAY)
        patch.start()
        self.addCleanup(patch.stop)

    # Files ------------------------------------------------------------------

    def p(self, rel: str) -> Path:
        return self.root / rel

    def data(self, rel: str) -> dict:
        return load(self.p(rel))

    def put(self, rel: str, data: object) -> Path:
        path = self.p(rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else dump(data), encoding="utf-8")
        return path

    def restore(self, rel: str) -> None:
        """Puts a fixture file back as it was."""
        shutil.copyfile(FIXTURE / rel, self.p(rel))

    def edit(self, rel: str, change) -> None:
        data = self.data(rel)
        change(data)
        self.put(rel, data)

    # Running ----------------------------------------------------------------

    def errors(self, rel: str) -> list[str]:
        """The errors of one file, validated alone."""
        return validate_decks.validate(self.p(rel)).errors

    def run_main(self) -> tuple[int, str]:
        """The validator's exit code and output over the whole fixture tree."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = validate_decks.main(["validate_decks.py", str(self.root)])
        return code, out.getvalue()

    def assertValid(self) -> None:
        code, text = self.run_main()
        self.assertEqual(code, 0, text)

    def assertRejected(self, needle: str) -> None:
        """The whole tree fails with a message holding [needle]."""
        code, text = self.run_main()
        self.assertEqual(code, 1, text)
        self.assertIn(needle, text)

    def assertAccepted(self, needle: str) -> None:
        """The whole tree is valid, and [needle] is not a message of it."""
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertNotIn(needle, text)
