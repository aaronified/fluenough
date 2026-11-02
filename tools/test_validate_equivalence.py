#!/usr/bin/env python3
"""The validator says the same thing however it is run.

tools/validate_decks.py was made faster (#speed-up): each YAML text is read
once, by libyaml where PyYAML has it, and the files are checked by several
worker processes. None of that may change a word of what it prints, or its
exit code. This holds it to that on deliberately broken decks:

* each of about sixty small breakages of the valid example sets (the zz
  language of tools/fixtures/b1 and the Spanish sample of tools/fixtures/index)
  is validated by `--jobs 1`, by `--jobs 3` and by the pure-Python YAML reader,
  and all three must print the same, byte for byte, standard error and exit
  code included;
* together the breakages make at least forty different errors and warnings, so
  the comparison is not of silence;
* when `VALIDATOR_REFERENCE_ROOT` names a checkout of the validator from before
  the change (the temporary workflow validator-equivalence does, with the pull
  request's base), each is also validated by that one, and the outputs must be
  the same.

Each validation is a subprocess against a throwaway tree, like the other
tests of the validator, so nothing here depends on this process's state.
Stdlib `unittest` plus PyYAML.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Callable

REPO = Path(__file__).resolve().parent.parent
FIXTURES = REPO / "tools" / "fixtures"
ZZ = FIXTURES / "b1" / "zz"
ES = FIXTURES / "index" / "es-en-core-100.yaml"
THEMES = ("schema: 1\nkind: themes\nthemes:\n"
          "  - { id: first-words, name: \"First words\" }\n"
          "  - { id: family, name: \"Family\" }\n")

Files = dict[str, "str | bytes"]


def zz_tree() -> Files:
    """The valid zz example, as {path under decks/: text}."""
    files: Files = {}
    for p in sorted(ZZ.rglob("*.yaml")):
        files[f"zz/{p.relative_to(ZZ).as_posix()}"] = p.read_text(encoding="utf-8")
    files["themes.yaml"] = THEMES
    return files


def zy_tree() -> Files:
    """The Spanish sample made the language zy, which the repository has no
    decks of, with the path every language needs."""
    text = ES.read_text(encoding="utf-8")
    for old, new in (("es-0", "zy-0"), ("es-en-core-100", "zy-en-core-100"),
                     ("code: es,", "code: zy,"), ("name: Spanish", "name: Zyish"),
                     ("name: Spanish Core", "name: Zyish Core")):
        text = text.replace(old, new)
    return {
        "zy/zy-en-core-100.yaml": text,
        "zy/zy-path.yaml": ("schema: 1\nkind: path\nid: zy-path\nlanguage: zy\n"
                            "units:\n  - [zy-core-100]\n"),
        "themes.yaml": THEMES,
    }


def sub(files: Files, rel: str, old: str, new: str) -> None:
    text = files[rel]
    assert isinstance(text, str) and old in text, f"{old!r} is not in {rel}"
    files[rel] = text.replace(old, new, 1)


HOME = "zz/zz-home.yaml"
LAYER = "zz/en/zz-en-home.yaml"
RULES = "zz/zz-grammar-case-endings.yaml"
RULES_LAYER = "zz/en/zz-en-grammar-case-endings.yaml"
PATH = "zz/zz-path.yaml"
SPANISH = "zy/zy-en-core-100.yaml"


def drop_phrasebook(files: Files) -> None:
    sub(files, HOME, '  - { id: "zz-9115", target: "అమ్మ 15!", reading: "amma 15!", '
                     'pos: "phrase", phrasebook: true }\n', "")
    sub(files, LAYER, '  "zz-9115": { native: "Mother 15!" }\n', "")


def second_path(files: Files) -> None:
    files["zz/zz-old-path.yaml"] = str(files[PATH]).replace('id: "zz-path"', 'id: "zz-old-path"')


def duplicate_stem(files: Files) -> None:
    files["zz/zz-en-home.yaml"] = files[LAYER]


def layer_in_wrong_folder(files: Files) -> None:
    files["zz/bn/zz-en-home.yaml"] = files.pop(LAYER)


def offensive_lookalike(files: Files) -> None:
    sub(files, HOME, '  - id: "zz-9006"',
        '  - id: "zz-9201"\n    target: "అమ్మా"\n    reading: "ammā"\n    pos: "noun"\n'
        '    register: "offensive"\n  - id: "zz-9006"')
    sub(files, LAYER, '  "zz-9006":', '  "zz-9201": { native: "rude" }\n  "zz-9006":')


def facts_file(files: Files) -> None:
    files["zz/zz-facts.yaml"] = ('schema: 1\nkind: facts\nid: zz-facts\nlanguage: zz\nfacts:\n'
                                 '  - { id: "zz-fact-1", text: "One fact is too few." }\n')


def tab_in_yaml(files: Files) -> None:
    sub(files, HOME, 'tags: ["unreviewed"]', 'tags:\n\t- "unreviewed"')


def not_utf8(files: Files) -> None:
    files[HOME] = b"schema: 1\nid: \xff\xfe\n"


# (name, which tree, change). Every change breaks the valid tree in one way.
MUTATIONS: list[tuple[str, str, Callable[[Files], None]]] = [
    ("valid zz", "zz", lambda f: None),
    ("valid es", "zy", lambda f: None),
    ("core id is not the file's", "zz", lambda f: sub(f, HOME, 'id: "zz-home"', 'id: "zz-hom"')),
    ("duplicate key", "zz", lambda f: sub(f, HOME, 'kind: "vocab"\n', 'kind: "vocab"\nkind: "vocab"\n')),
    ("merge key", "zz", lambda f: sub(f, HOME, 'kind: "vocab"\n',
                                      'kind: "vocab"\nx: &a { b: 1 }\n<<: *a\n')),
    ("yaml syntax error", "zz", lambda f: sub(f, HOME, 'tags: ["unreviewed"]', 'tags: ["unreviewed"')),
    ("tab in yaml", "zz", tab_in_yaml),
    ("not utf-8", "zz", not_utf8),
    ("root is a list", "zz", lambda f: f.__setitem__(HOME, "- 1\n")),
    ("boolean target", "zz", lambda f: sub(f, HOME, 'target: "ఇల్లు"', "target: true")),
    ("number as reading", "zz", lambda f: sub(f, HOME, 'reading: "illu"', "reading: 007")),
    ("unknown card field", "zz", lambda f: sub(f, HOME, '    reading: "illu"\n',
                                              '    reading: "illu"\n    bogus: 1\n')),
    ("duplicate card id", "zz", lambda f: sub(f, HOME, 'id: "zz-9004"', 'id: "zz-9001"')),
    ("card id of another language", "zz", lambda f: sub(f, HOME, 'id: "zz-9101"', 'id: "xx-9101"')),
    ("card without target", "zz", lambda f: sub(f, HOME, '    target: "అమ్మ"\n', "")),
    ("unknown pos", "zz", lambda f: sub(f, HOME, 'pos: "verb"', 'pos: "verbo"')),
    ("empty license", "zz", lambda f: sub(f, HOME, 'license: "CC-BY-SA-4.0"', 'license: ""')),
    ("wrong schema", "zz", lambda f: sub(f, HOME, "schema: 1", "schema: 2")),
    ("language icon differs", "zz", lambda f: sub(f, RULES, 'icon: "తె"', 'icon: "x"')),
    ("unknown modes", "zz", lambda f: sub(f, HOME, '    reading: "illu"\n',
                                         '    reading: "illu"\n    modes: ["flying"]\n')),
    ("unknown note kind", "zz", lambda f: sub(f, HOME, 'kind: "usage"', 'kind: "wrong"')),
    ("pair names no card", "zz", lambda f: sub(f, HOME, '    reading: "illu"\n',
                                              '    reading: "illu"\n    pair: "zz-9998"\n')),
    ("proposal without fields", "zz", lambda f: sub(f, HOME, '    reading: "illu"\n',
                                                  '    reading: "illu"\n    proposed: [{ id: x }]\n')),
    ("checked_by malformed", "zz", lambda f: sub(f, HOME, '    reading: "illu"\n',
                                                '    reading: "illu"\n    checked_by: "me"\n')),
    ("rules names no rule", "zz", lambda f: sub(f, HOME, 'rules: ["zz-rule-ki"]', 'rules: ["zz-rule-xx"]')),
    ("base names no card", "zz", lambda f: sub(f, HOME, 'ref: "zz-9001"', 'ref: "zz-9999"')),
    ("base word not in the target", "zz", lambda f: sub(f, HOME, 'word: "ఇంటికి"', 'word: "ఇల్లు"')),
    ("phrasebook of fourteen", "zz", drop_phrasebook),
    ("offensive look-alike", "zz", offensive_lookalike),
    ("layer of no core", "zz", lambda f: sub(f, LAYER, 'core: "zz-home"', 'core: "zz-nope"')),
    ("layer id is not the file's", "zz", lambda f: sub(f, LAYER, 'id: "zz-en-home"', 'id: "zz-en-hom"')),
    ("layer in the wrong folder", "zz", layer_in_wrong_folder),
    ("layer with a theme", "zz", lambda f: sub(f, LAYER, 'name: "Home"', 'name: "Home"\ntheme: "family"')),
    ("layer for an unknown card", "zz", lambda f: sub(f, LAYER, '  "zz-9004":',
                                                    '  "zz-0000": { native: "x" }\n  "zz-9004":')),
    ("layer with an empty native", "zz", lambda f: sub(f, LAYER, 'native: "mother"', 'native: ""')),
    ("layer note of no note", "zz", lambda f: sub(f, LAYER, '"address": "Also', '"adres": "Also')),
    ("layer note with a missing placeholder", "zz", lambda f: sub(f, LAYER, "becomes {1}", "becomes {2}")),
    ("layer prose in a script", "zz", lambda f: sub(f, LAYER, 'native: "mother"', 'native: "mother ఇల్లు"')),
    ("layer wiktionary flag", "zz", lambda f: sub(f, LAYER, "wiktionary: true", 'wiktionary: "yes"')),
    ("layer key read as a number", "zz", lambda f: sub(f, LAYER, '  "zz-9004":', '  1: x\n  "zz-9004":')),
    ("rules row of no card", "zz", lambda f: sub(f, RULES, 'word: "zz-9001"', 'word: "zz-9777"')),
    ("rules slot without a form", "zz", lambda f: sub(f, RULES, ', "nunci": "ఇంటి నుంచి" }', " }")),
    ("rule of an unknown slot", "zz", lambda f: sub(f, RULES, 'slots: ["lo"]\n    words',
                                                   'slots: ["lx"]\n    words')),
    ("rules layer prompt of no card", "zz", lambda f: sub(f, RULES_LAYER, '"zz-9001": {',
                                                         '"zz-9555": {')),
    ("rules layer without an explanation", "zz", lambda f: sub(
        f, RULES_LAYER, '    explanation: "{1} means with: with a person, or with a tool."\n', "")),
    ("path lists no deck", "zz", lambda f: sub(f, PATH, 'decks: ["zz-home"]', 'decks: ["zz-hom"]')),
    ("path with an unknown milestone", "zz", lambda f: sub(f, PATH, 'milestone: "A1"', 'milestone: "C9"')),
    ("path with negative words", "zz", lambda f: sub(f, PATH, "words: 4", "words: -4")),
    ("path with an unknown grammar topic", "zz", lambda f: sub(
        f, PATH, 'grammar: ["lo", "ki", "to", "nunci"]', 'grammar: ["lo", "ki", "to", "nunci", 3]')),
    ("planned unit without a theme", "zz", lambda f: sub(f, PATH, ', theme: "health"', "")),
    ("repeated region", "zz", lambda f: sub(f, PATH, '  - { id: "rayalaseema", name: { "en": "Rayalaseema" } }',
                                           '  - { id: "telangana", name: { "en": "Rayalaseema" } }')),
    ("second path", "zz", second_path),
    ("two decks of one id", "zz", duplicate_stem),
    ("facts of one fact", "zz", facts_file),
    ("zy duplicate card id", "zy", lambda f: sub(f, SPANISH, "id: zy-0002", "id: zy-0001")),
    ("zy invalid ipa", "zy", lambda f: sub(f, SPANISH, 'ipa: "el ˈombɾe"', 'ipa: "el ˈombɾe!"')),
    ("zy picture of no file", "zy", lambda f: sub(f, SPANISH, 'picture: "👨"', 'picture: "🦖"')),
    ("zy empty native", "zy", lambda f: sub(f, SPANISH, "native: the man", 'native: ""')),
    ("zy tags not a list", "zy", lambda f: sub(f, SPANISH, "tags: [people]", "tags: people")),
    ("zy id is not the file's", "zy", lambda f: sub(f, SPANISH, "id: zy-en-core-100", "id: zy-en-core")),
    ("zy unknown theme", "zy", lambda f: sub(f, SPANISH, "tags: [beginner, core]",
                                            "tags: [beginner, core]\ntheme: nonexistent")),
    ("zy path of no deck", "zy", lambda f: sub(f, "zy/zy-path.yaml", "[zy-core-100]", "[zy-core-1]")),
    ("zy note that is not a string", "zy", lambda f: sub(f, SPANISH, 'notes: "la amiga when the friend is female."',
                                                        "notes: 12")),
]


def run(tool: Path, decks: Path, *args: str, env: dict[str, str] | None = None) -> tuple[str, str, int]:
    """One validation: standard output and error, with the throwaway tree's
    directory taken out so that two trees compare, and the exit code."""
    done = subprocess.run(
        [sys.executable, str(tool), *args, str(decks)],
        capture_output=True, cwd=decks.parent, check=False,
        env={**os.environ, "FLUENOUGH_SKIP_INDEX_CHECK": "1", **(env or {})})
    out = done.stdout.decode("utf-8", "surrogateescape").replace(str(decks.parent), "<tmp>")
    err = done.stderr.decode("utf-8", "surrogateescape").replace(str(decks.parent), "<tmp>")
    if "Traceback (most recent call last)" in err:
        # A crash reads the same in the file and line numbers of two versions
        # of the tool: keep the exception, which is what must not change.
        err = "Traceback: " + err.strip().splitlines()[-1] + "\n"
    return out, err, done.returncode


def build(root: Path, tree: str, change: Callable[[Files], None]) -> Path:
    files = zz_tree() if tree == "zz" else zy_tree()
    change(files)
    decks = root / "decks"
    for rel, content in files.items():
        path = decks / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")
    return decks


def kind_of(line: str) -> str:
    """A message without what is particular to it: quoted values, numbers and
    paths, so that two breakages of the same rule are one kind."""
    line = re.sub(r"\S*/decks/\S*|<tmp>\S*", "", line)
    line = re.sub(r"'[^']*'|\"[^\"]*\"|\d+|\[[^\]]*\]|\{[^}]*\}", "_", line)
    where, _, message = line.partition(": ")
    words = (message or where).split()
    return " ".join(words[:7])


class Equivalence(unittest.TestCase):
    maxDiff = None
    tool = REPO / "tools" / "validate_decks.py"
    cache: dict[str, dict[str, tuple[str, str, int]]] = {}

    def results(self, name: str, tree: str, change: Callable[[Files], None]
                ) -> dict[str, tuple[str, str, int]]:
        """The output of each way of running the new validator on one tree."""
        tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, tmp, True)
        decks = build(tmp, tree, change)
        found = {
            "jobs 1": run(self.tool, decks, "--jobs", "1"),
            "jobs 3": run(self.tool, decks, "--jobs", "3"),
            "pure yaml": run(self.tool, decks, "--jobs", "1",
                             env={"FLUENOUGH_PURE_YAML": "1"}),
        }
        root = os.environ.get("VALIDATOR_REFERENCE_ROOT")
        if root:
            found["before"] = run(Path(root) / "tools" / "validate_decks.py", decks)
        return found

    def test_every_way_of_running_prints_the_same(self) -> None:
        for name, tree, change in MUTATIONS:
            with self.subTest(name):
                found = self.results(name, tree, change)
                base = found["jobs 1"]
                for how, got in found.items():
                    self.assertEqual(got, base, f"{how} differs from jobs 1: {name}")

    def test_the_breakages_are_forty_different_errors_and_warnings(self) -> None:
        kinds: set[str] = set()
        for name, tree, change in MUTATIONS:
            tmp = Path(tempfile.mkdtemp()).resolve()
            self.addCleanup(shutil.rmtree, tmp, True)
            out, _, _ = run(self.tool, build(tmp, tree, change), "--jobs", "1")
            for line in out.splitlines():
                stripped = line.strip()
                if stripped.startswith(("error", "warning")):
                    kinds.add(kind_of(re.sub(r"^(error:?|warning)\s+", "", stripped)))
        self.assertGreaterEqual(len(kinds), 40, sorted(kinds))

    def test_a_valid_tree_is_valid(self) -> None:
        for tree in ("zz", "zy"):
            tmp = Path(tempfile.mkdtemp()).resolve()
            self.addCleanup(shutil.rmtree, tmp, True)
            out, err, code = run(self.tool, build(tmp, tree, lambda f: None), "--jobs", "1")
            self.assertEqual((code, err), (0, ""), out)


CHECK_ORDER = """
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import validate_decks as vd

paths = vd.collect(Path(sys.argv[2]))
serial = vd.validate_many(paths, 1)
assert any(r.errors for r in serial), "nothing to compare"
for jobs in (2, 4, 7):
    parallel = vd.validate_many(paths, jobs)
    assert [r.path for r in parallel] == paths, f"--jobs {jobs}: order"
    assert parallel == serial, f"--jobs {jobs}: reports"
print("ok", len(paths))
"""


class ManyFiles(unittest.TestCase):
    """More files than a worker takes at a time, reported in the order given."""

    def test_jobs_make_the_reports_of_one_process_in_order(self) -> None:
        # In a process of its own: a test runner's process has threads, and
        # forking one is what the validator itself declines to do.
        tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, tmp, True)
        files = zz_tree()
        # Forty single-file decks of the zz language, every other one broken.
        deck = ('schema: 1\nid: "zz-en-x@N@"\nname: "X"\n'
                'language: { code: "zz", iso639_3: "zzz", name: "Testlang", '
                'script: "telugu", tts: "te-IN", icon: "తె" }\n'
                'native: { code: "en", iso639_3: "eng", name: "English" }\n'
                'license: "CC-BY-SA-4.0"\ncards:\n'
                '  - { id: "zz-@ID@", target: "పిల్లి", reading: "pilli", native: "cat", pos: "noun" }\n')
        for n in range(40):
            text = deck.replace("@N@", f"{n:02d}").replace("@ID@", str(7000 + n))
            files[f"zz/zz-en-x{n:02d}.yaml"] = text if n % 2 else text.replace('pos: "noun"', 'pos: "nope"')
        decks = build(tmp, "zz", lambda f: f.update(files))
        done = subprocess.run([sys.executable, "-c", CHECK_ORDER, str(REPO / "tools"), str(decks)],
                              capture_output=True, text=True, check=False)
        self.assertEqual((done.returncode, done.stdout.split()[:1]), (0, ["ok"]),
                         done.stdout + done.stderr)


if __name__ == "__main__":
    unittest.main()
