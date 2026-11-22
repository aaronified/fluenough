"""Script coverage of the multi-script languages (informational).

A language whose header lists several `scripts` (Hindustani: devanagari and
perso_arabic) gives each card its target in the first script and, where it
has one, its spelling in each other script as `target_scripts`. A learner who
reads or learns a script a card lacks sees no line in it, so this prints how
many cards have each non-primary script. It never fails a run: many cards
lack a second spelling today, and that is content work, not an error.
"""

from __future__ import annotations


def count_cards(lang: object, cards: object) -> tuple[str, list[str], int, dict[str, int]] | None:
    """(language code, its scripts, cards with a target, cards per non-primary
    script) for one deck's `cards`, or None for a language with one script."""
    if not isinstance(lang, dict) or not isinstance(cards, list):
        return None
    scripts = lang.get("scripts")
    code = lang.get("code")
    if (not isinstance(scripts, list) or len(scripts) < 2
            or not all(isinstance(x, str) for x in scripts)
            or not isinstance(code, str)):
        return None
    targeted = 0
    per: dict[str, int] = {s: 0 for s in scripts[1:]}
    for card in cards:
        if not isinstance(card, dict):
            continue
        target = card.get("target")
        if not isinstance(target, str) or not target.strip():
            continue
        targeted += 1
        spelled = card.get("target_scripts")
        if not isinstance(spelled, dict):
            continue
        for script in per:
            value = spelled.get(script)
            if isinstance(value, str) and value.strip():
                per[script] += 1
    return code, list(scripts), targeted, per


def report_lines(reports: list) -> list[str]:
    """The report, one line per language and non-primary script; empty where
    no language has several scripts. Totals add up every deck of a language."""
    scripts_of: dict[str, list[str]] = {}
    targeted_of: dict[str, int] = {}
    counts_of: dict[str, dict[str, int]] = {}
    for rep in reports:
        found = getattr(rep, "script_cards", None)
        if not found:
            continue
        code, scripts, targeted, per = found
        scripts_of[code] = scripts
        targeted_of[code] = targeted_of.get(code, 0) + targeted
        counts = counts_of.setdefault(code, {})
        for script, n in per.items():
            counts[script] = counts.get(script, 0) + n
    if not scripts_of:
        return []
    lines = ["", "Script coverage (informational, never fails):"]
    for code in sorted(scripts_of):
        scripts = scripts_of[code]
        targeted = targeted_of[code]
        for script in scripts[1:]:
            n = counts_of[code].get(script, 0)
            pct = f"{100 * n / targeted:.0f}%" if targeted else "n/a"
            lines.append(f"  coverage {code}: {n}/{targeted} cards with a target "
                         f"have a {script} spelling ({pct}); "
                         f"{targeted - n} lack it (primary {scripts[0]})")
    return lines
