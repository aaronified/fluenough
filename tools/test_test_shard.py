#!/usr/bin/env python3
"""Tests for tools/test_shard.py, the split of the Flutter tests over CI shards."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import test_shard as ts  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "test_shard.py"
REPO = Path(__file__).resolve().parent.parent


def tree(names: list[str], weights: dict | None = None) -> Path:
    """A throwaway repo with these test files (and a weights file, if given)."""
    root = Path(tempfile.mkdtemp())
    for n in names:
        p = root / n
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("void main() {}\n")
    (root / "test" / "support").mkdir(parents=True, exist_ok=True)
    (root / "test" / "support" / "helper.dart").write_text("// not a test\n")
    if weights is not None:
        (root / "test" / "shard_weights.json").write_text(json.dumps(weights))
    return root


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True
    )


class Discover(unittest.TestCase):
    def test_finds_test_files_at_any_depth_and_nothing_else(self):
        root = tree(["test/a_test.dart", "test/features/x/b_test.dart"])
        self.assertEqual(
            ts.discover(root), ["test/a_test.dart", "test/features/x/b_test.dart"]
        )


class Assign(unittest.TestCase):
    FILES = [f"test/f{i:02}_test.dart" for i in range(20)]

    def test_every_file_lands_in_exactly_one_shard(self):
        weights = {f: 1 + (i * 7) % 13 for i, f in enumerate(self.FILES)}
        shards = ts.assign(self.FILES, weights, 5, 8)
        flat = [f for s in shards for f in s]
        self.assertEqual(sorted(flat), sorted(self.FILES))
        self.assertEqual(len(flat), len(set(flat)))

    def test_the_heaviest_file_has_a_shard_to_itself_when_it_must(self):
        weights = {"test/big_test.dart": 100, "test/a_test.dart": 50, "test/b_test.dart": 50}
        shards = ts.assign(list(weights), weights, 1, 2)
        self.assertIn(["test/big_test.dart"], shards)
        self.assertIn(["test/a_test.dart", "test/b_test.dart"], shards)

    def test_the_result_does_not_depend_on_the_input_order(self):
        weights = {f: 1 + (i * 5) % 11 for i, f in enumerate(self.FILES)}
        a = ts.assign(self.FILES, weights, 3, 8)
        b = ts.assign(list(reversed(self.FILES)), weights, 3, 8)
        self.assertEqual(a, b)

    def test_a_file_without_a_weight_is_still_placed_and_weighs_the_default(self):
        files = ["test/known_test.dart", "test/new_test.dart"]
        shards = ts.assign(files, {"test/known_test.dart": 10}, 10, 2)
        self.assertEqual(sorted(f for s in shards for f in s), sorted(files))
        # Equal weights: the two files take different shards.
        self.assertTrue(all(len(s) == 1 for s in shards))

    def test_balanced_when_the_weights_allow_it(self):
        weights = {f: 10 for f in self.FILES}
        loads = [sum(weights[f] for f in s) for s in ts.assign(self.FILES, weights, 1, 4)]
        self.assertEqual(max(loads) - min(loads), 0)


class Command(unittest.TestCase):
    def test_the_shards_together_are_every_file_once(self):
        names = [f"test/t{i}_test.dart" for i in range(11)]
        root = tree(names, {"default": 3, "files": {"test/t0_test.dart": 40}})
        got: list[str] = []
        for i in range(4):
            r = run("--total-shards", "4", "--shard-index", str(i), "--root", str(root))
            self.assertEqual(r.returncode, 0, r.stderr)
            got += r.stdout.split()
        self.assertEqual(sorted(got), sorted(names))

    def test_a_shard_with_no_files_fails_rather_than_running_everything(self):
        root = tree(["test/only_test.dart"])
        r = run("--total-shards", "3", "--shard-index", "2", "--root", str(root))
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stdout, "")
        self.assertIn("no test files", r.stderr)

    def test_a_missing_weights_file_still_splits(self):
        root = tree([f"test/t{i}_test.dart" for i in range(4)])
        r = run("--total-shards", "2", "--shard-index", "0", "--root", str(root))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(r.stdout.split()), 2)

    def test_a_bad_index_is_a_usage_error(self):
        for idx in ("8", "-1"):
            r = run("--total-shards", "8", "--shard-index", idx)
            self.assertEqual(r.returncode, 2, idx)


class CommittedWeights(unittest.TestCase):
    """The real test/shard_weights.json against the real test/ folder."""

    def setUp(self):
        self.files = ts.discover(REPO)
        self.weights, self.default = ts.load_weights(ts.WEIGHTS)

    def test_every_listed_file_exists(self):
        # A renamed or deleted test file leaves its weight behind: list it
        # under its new name or drop it.
        gone = sorted(set(self.weights) - set(self.files))
        self.assertEqual(gone, [], "shard_weights.json lists files that are gone")

    def test_weights_are_positive_numbers(self):
        self.assertGreater(self.default, 0)
        for f, w in self.weights.items():
            self.assertGreater(w, 0, f)

    def test_eight_shards_stay_close_to_even(self):
        shards = ts.assign(self.files, self.weights, self.default, 8)
        loads = [sum(self.weights.get(f, self.default) for f in s) for s in shards]
        self.assertTrue(all(shards), "an empty shard")
        self.assertLessEqual(max(loads), 1.1 * sum(loads) / 8)

    def test_no_file_is_heavier_than_a_shard_should_be(self):
        # One file longer than an eighth of the suite sets the wall time on
        # its own: split it by its groups (see the split of
        # lesson_and_review_test.dart).
        total = sum(self.weights.get(f, self.default) for f in self.files)
        for f in self.files:
            self.assertLessEqual(self.weights.get(f, self.default), total / 8 / 1.1, f)


if __name__ == "__main__":
    unittest.main()
