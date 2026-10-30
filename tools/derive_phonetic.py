#!/usr/bin/env python3
"""Derive a narrow `[ ... ]` IPA from a card's broad `ipa` by the language's
rules, for the cards Wiktionary has no form for (owner, 2026-10-26 and
2026-10-30; wiki: Plan-Ipa-Revamp-And-Language-Phonology).

Usage:
    python3 tools/derive_phonetic.py es                 # report only
    python3 tools/derive_phonetic.py es --write         # patch the decks
    python3 tools/derive_phonetic.py es --bracket-unchanged --write
    python3 tools/derive_phonetic.py es --report es-rules.md

Run it after `tools/import_phonetic.py`: a card that already has a
`phonetic` is skipped, so Wiktionary's form always wins. The rules are in
`decks/<lang>/<lang>-phonetics.yaml` (kind `phonetics`, see "Phonetic rules
files" in docs/DECK-FORMAT.md): an ordered list, each rule a regular
expression and its replacement, applied to the broad `ipa` with `re.sub`,
the first rule first, each on the result of the one before. Every rule names
its `source`. A rule that is not well attested is left out, not guessed.

A card gets `phonetic: "[...]"` and `phonetic_source: "rules"` only if the
result is different from its broad form: a card the rules do not change has
nothing narrower to say, and writing its broad form in brackets would claim a
precision nobody checked. `--bracket-unchanged` writes those too (the owner's
"every card gets the full [] notation"); the report counts them either way.

A result that is not IPA letters and marks in square brackets is refused (the
validator's own test) and counted `invalid`; it is never written.

Stdlib and PyYAML only.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import phonetic_patch as pp  # noqa: E402
import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

OUTCOMES = ["filled", "unchanged", "has phonetic", "no ipa line", "invalid"]


@dataclass(frozen=True)
class Rule:
    id: str
    pattern: re.Pattern
    replace: str
    source: str


@dataclass(frozen=True)
class RuleSet:
    language: str
    variety: str
    rules: list[Rule]


class RulesError(Exception):
    pass


def load_rules(path: Path) -> RuleSet:
    """The rules file at [path], or RulesError saying what is wrong. The
    validator's `check_phonetics_file` is the stricter judge; this refuses
    only what the tool cannot run."""
    raw = vd._load_raw(path)
    if not isinstance(raw, dict) or raw.get("kind") != "phonetics":
        raise RulesError(f"{path} is not a phonetics file (kind: \"phonetics\")")
    rules: list[Rule] = []
    for i, item in enumerate(raw.get("rules") or []):
        try:
            rules.append(Rule(str(item["id"]), re.compile(item["pattern"]),
                              item.get("replace", ""), str(item["source"])))
        except (KeyError, TypeError, re.error) as e:
            raise RulesError(f"{path}: rules[{i}]: {e}") from e
    if not rules:
        raise RulesError(f"{path} has no rules")
    return RuleSet(str(raw.get("language")), str(raw.get("variety")), rules)


def apply_rules(ipa: str, rules: list[Rule]) -> str:
    """[ipa] after each rule in turn."""
    for rule in rules:
        ipa = rule.pattern.sub(rule.replace, ipa)
    return ipa


def derive(ipa: str, rules: list[Rule]) -> tuple[str | None, str]:
    """The narrow form of [ipa] and the outcome: `filled` (the rules changed
    it), `unchanged` (they did not; the form is [ipa] in brackets) or
    `invalid` (the result is not narrow IPA; no form)."""
    out = apply_rules(ipa, rules)
    form = pp.normalise(f"[{out}]")
    if form is None:
        return None, "invalid"
    return form, ("unchanged" if out == ipa else "filled")


def run(lang: str, decks: Path, write: bool, bracket_unchanged: bool = False
        ) -> tuple[pp.Coverage, dict[Path, dict[str, tuple[str, str]]]]:
    ruleset = load_rules(decks / lang / f"{lang}-phonetics.yaml")
    coverage = pp.Coverage()
    fills: dict[Path, dict[str, tuple[str, str]]] = {}
    for card in pp.core_cards(decks, lang):
        deck = card.file.stem
        if card.phonetic is not None:
            coverage.add(deck, "has phonetic")
        elif card.ipa is None or not card.block:
            coverage.add(deck, "no ipa line")
        else:
            form, outcome = derive(card.ipa, ruleset.rules)
            coverage.add(deck, outcome)
            if form is not None and (outcome == "filled" or bracket_unchanged):
                fills.setdefault(card.file, {})[card.cid] = (form, "rules")
    if write:
        for path, fill in fills.items():
            text = path.read_text(encoding="utf-8")
            new, _ = pp.patch(text, fill)
            if new != text:
                path.write_text(new, encoding="utf-8", newline="")
    return coverage, fills


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Derive narrow IPA from broad IPA by a language's rules.")
    parser.add_argument("lang", help="the language's code, such as es")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--write", action="store_true",
                        help="patch the decks; without it, only report")
    parser.add_argument("--bracket-unchanged", action="store_true",
                        help="also write the broad form in brackets for a card the "
                             "rules leave as it is")
    parser.add_argument("--report", type=Path, help="write the report here")
    args = parser.parse_args(argv[1:])
    if not (args.decks / args.lang / f"{args.lang}-phonetics.yaml").is_file():
        print(f"error: {args.lang} has no rules file "
              f"decks/{args.lang}/{args.lang}-phonetics.yaml", file=sys.stderr)
        return 2
    try:
        coverage, _ = run(args.lang, args.decks, args.write, args.bracket_unchanged)
    except RulesError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    ruleset = load_rules(args.decks / args.lang / f"{args.lang}-phonetics.yaml")
    report = (f"# Narrow IPA by rules: {args.lang}\n\n"
              f"Variety: {ruleset.variety}. {len(ruleset.rules)} rules. "
              f"{'Written.' if args.write else 'Report only; nothing was written.'}\n\n"
              + coverage.render(args.lang, OUTCOMES, title="Coverage"))
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
