#!/usr/bin/env python3
"""Convert a CSV wordlist into a Fluenough deck.

    python3 tools/import_csv.py words.csv \
        --id es-food --name "Spanish food" \
        --language es --language-name Spanish --tts es-ES \
        --license CC0-1.0 > decks/es/es-food.yaml

The CSV needs a header row. `target` and `native` are required; `reading`,
`tags`, `pos`, `notes`, `alt_target` and `alt_native` are used if present.
List columns are split on `|`. Column names are matched case-insensitively,
and `front`/`back` are accepted as aliases for target/native.

Always run tools/validate_decks.py on the result before committing.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import unicodedata
from pathlib import Path

ALIASES = {"front": "target", "back": "native", "word": "target",
           "meaning": "native", "translation": "native", "romaji": "reading",
           "romanization": "reading", "reading": "reading"}
LIST_FIELDS = {"tags", "alt_target", "alt_native"}
SIMPLE_FIELDS = ["reading", "pos", "gender", "notes"]

# YAML resolves these bare words to booleans, and numeric-looking values to
# numbers. Anything matching must be quoted. See docs/DECK-FORMAT.md.
YAML_BOOLS = {"y", "n", "yes", "no", "true", "false", "on", "off"}
NUMERIC = re.compile(r"^[-+]?(\d[\d_]*\.?\d*([eE][-+]?\d+)?|\.\d+)$")


def quote(value: str) -> str:
    """Emit a YAML scalar, quoting whenever a bare word would be misread."""
    needs = (
        value == ""
        or value.strip() != value
        or value.lower() in YAML_BOOLS
        or NUMERIC.match(value) is not None
        or value[0] in "#&*!|>%@`[]{},?:-'\""
        or ": " in value
        or " #" in value
    )
    if not needs:
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("csv_file", type=Path)
    p.add_argument("--id", required=True, help="deck id; must match the filename stem")
    p.add_argument("--name", required=True)
    p.add_argument("--language", required=True, help="language code being learned, e.g. es")
    p.add_argument("--language-name", required=True)
    p.add_argument("--script", default="latin")
    p.add_argument("--tts", default=None, help="BCP-47 voice tag, e.g. es-ES")
    p.add_argument("--native", default="en")
    p.add_argument("--native-name", default="English")
    p.add_argument("--license", required=True, help="SPDX id, or CC0-1.0")
    p.add_argument("--tags", default="", help="deck-level tags, comma separated")
    p.add_argument("--delimiter", default=",")
    args = p.parse_args()

    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", args.id):
        sys.exit(f"error: --id must match [a-z0-9-]+, got {args.id!r}")

    with args.csv_file.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh, delimiter=args.delimiter)
        if reader.fieldnames is None:
            sys.exit("error: the CSV has no header row")
        headers = {h: ALIASES.get(h.strip().lower(), h.strip().lower())
                   for h in reader.fieldnames if h}
        if "target" not in headers.values() or "native" not in headers.values():
            sys.exit(f"error: need target and native columns, found {sorted(set(headers.values()))}")
        rows = [{headers[k]: (v or "").strip()
                 for k, v in row.items() if k in headers} for row in reader]

    out: list[str] = [
        "schema: 1",
        f"id: {args.id}",
        f"name: {quote(args.name)}",
        "kind: vocab",
        f"language: {{ code: {args.language}, name: {quote(args.language_name)}, "
        f"script: {args.script}"
        + (f", tts: {args.tts}" if args.tts else "") + " }",
        f"native:   {{ code: {args.native}, name: {quote(args.native_name)} }}",
        f"license: {args.license}",
    ]
    if args.tags:
        tags = [t.strip() for t in args.tags.split(",") if t.strip()]
        out.append("tags: [" + ", ".join(quote(t) for t in tags) + "]")
    out += ["", "cards:"]

    seen: set[str] = set()
    written = skipped = 0
    for i, row in enumerate(rows, 1):
        target, native = row.get("target", ""), row.get("native", "")
        if not target or not native:
            print(f"warning: row {i} has an empty target or native; skipped",
                  file=sys.stderr)
            skipped += 1
            continue

        # Card ids key the user's review history forever, so they must be
        # stable and meaningful. A non-Latin target slugifies to nothing, so
        # fall back to the reading, then to the row number.
        stem = slugify(target) or slugify(row.get("reading", "")) or f"{i:04d}"
        base = f"{args.id}-{stem}"
        card_id, n = base, 2
        while card_id in seen:
            card_id, n = f"{base}-{n}", n + 1
        seen.add(card_id)

        out.append(f"  - id: {card_id}")
        out.append(f"    target: {quote(target)}")
        out.append(f"    native: {quote(native)}")
        for field in SIMPLE_FIELDS:
            if row.get(field):
                out.append(f"    {field}: {quote(row[field])}")
        for field in LIST_FIELDS:
            if row.get(field):
                items = [x.strip() for x in row[field].split("|") if x.strip()]
                if items:
                    out.append(f"    {field}: [" + ", ".join(quote(x) for x in items) + "]")
        written += 1

    print("\n".join(out))
    print(f"imported {written} cards"
          + (f", skipped {skipped}" if skipped else ""), file=sys.stderr)
    if not written:
        return 1
    print("now run: python3 tools/validate_decks.py <the file you saved this to>",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
