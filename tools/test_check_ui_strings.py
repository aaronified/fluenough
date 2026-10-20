#!/usr/bin/env python3
"""Tests for the rule 10 gate.

The case that matters most is the multi-line one. `dart format` splits a widget
call across lines as soon as it passes 80 columns, which is most of them, so a
line-oriented check passes a tree full of literals and reports success. The
first draft of this checker did exactly that.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parent / "check_ui_strings.py"

CLEAN = """\
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

class Screen extends StatelessWidget {
  const Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      children: <Widget>[
        Text(l10n.appTitle),
        Text(
          l10n.scaffoldingTagline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
"""


class UiStringGate(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.lib = self.tmp / "lib"
        self.lib.mkdir()

    def write(self, body: str) -> None:
        (self.lib / "screen.dart").write_text(body, encoding="utf-8")

    def check(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(CHECKER), str(self.lib)],
            capture_output=True,
            text=True,
            check=False,
        )

    def _tokens_only_passes(self) -> None:
        self.write(CLEAN)
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)

    def _catches_a_literal_on_the_same_line(self) -> None:
        self.write(CLEAN.replace("Text(l10n.appTitle)", "Text('Fluenough')"))
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Fluenough", result.stdout)

    def _catches_a_literal_split_across_lines(self) -> None:
        """The regression: `dart format` puts the argument on its own line."""
        self.write(CLEAN.replace("          l10n.scaffoldingTagline,",
                                 "          'Fluent enough.',"))
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("Fluent enough.", result.stdout)


    def _an_explicitly_allowed_literal_passes(self) -> None:
        self.write(CLEAN.replace(
            "Text(l10n.appTitle)",
            "Text('—'),  // ui-literal-ok: an em dash is not language"))
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)


    def test_a_literal_is_caught(self) -> None:
        cases = (
            self._catches_a_literal_on_the_same_line,
            self._catches_a_literal_split_across_lines,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_tokens_and_allowed_literals_pass(self) -> None:
        cases = (
            self._tokens_only_passes,
            self._an_explicitly_allowed_literal_passes,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
