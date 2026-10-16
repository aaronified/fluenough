#!/usr/bin/env python3
"""Rank a language's words by how often its Wikipedia uses them, and write
each card's `frequency` (#516).

Usage:
    python3 tools/wikipedia_frequency.py hi hiwiki-20261001-pages-articles.xml.bz2
    python3 tools/wikipedia_frequency.py hi hiwiki-20261001-pages-articles.xml.bz2 --write
    python3 tools/wikipedia_frequency.py hi extract/ --month 2026-10 --counts hi-counts.tsv
    python3 tools/wikipedia_frequency.py hi --from-counts hi-counts.tsv --month 2026-10 --write

Owner, 2026-10-13: frequency is "Count from Wikipedia instead". The count
is CC BY-SA, as the decks are (ADR-0040), and this tool regenerates it.

The text is a Wikipedia dump, `<lang>wiki-<date>-pages-articles.xml.bz2`
from https://dumps.wikimedia.org/<lang>wiki/, or a folder or file of plain
text taken from one (WikiExtractor's output, for one). In a dump, only
articles are counted (namespace 0, no redirects), with their markup taken
out. A word is a run of letters and marks, joiners included; numbers and
punctuation part words. Words are compared as the validator compares them:
in NFC, case folded. The commonest word is rank 1, and words used equally
often are ranked by their text, so that a run can be repeated.

`--counts` saves the count, a word and its number per line, most frequent
first, so that `--from-counts` can rank again without the dump.

Each card in the language's decks whose target is one word, and that has no
`frequency`, is given its word's rank, with the count's source:

    frequency: { rank: 412, source: "hi.wikipedia.org, 2026-10" }

The source names the Wikipedia and the dump's month (`--month`, or the date
in the dump's name). A word Wikipedia never uses is left without one, and
listed. A card that has a `frequency` keeps it: a count is never rewritten
by hand, and a new one is written by removing the old first. A phrase gets
none: its words' ranks are not its own.

Needs only Python 3.11+ and PyYAML, like the other deck tools.
"""

from __future__ import annotations

import argparse
import bz2
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path
from typing import Iterable, Iterator

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# The joiners, which are part of a word in the Indian scripts.
JOINERS = "‌‍"


# --- Reading the text -----------------------------------------------------------

def words(text: str) -> Iterator[str]:
    """The words of [text], as the count keys them: runs of letters, marks
    and joiners, in NFC, case folded."""
    word: list[str] = []
    for c in unicodedata.normalize("NFC", text):
        if unicodedata.category(c)[0] in "LM" or (c in JOINERS and word):
            word.append(c)
        elif word:
            yield vd._key("".join(word).strip(JOINERS))
            word = []
    if word:
        yield vd._key("".join(word).strip(JOINERS))


# Wiki markup taken out of an article before its words are counted.
_MARKUP = [
    (re.compile(r"<!--.*?-->", re.S), " "),
    (re.compile(r"<ref[^>/]*/>"), " "),
    (re.compile(r"<ref[^>]*>.*?</ref>", re.S), " "),
    (re.compile(r"<[^>]+>"), " "),
    (re.compile(r"\{\|.*?\|\}", re.S), " "),                  # tables
    (re.compile(r"\[\[(?:[^\[\]|]*:)[^\[\]]*\]\]"), " "),     # files, categories
    (re.compile(r"\[\[[^\[\]|]*\|([^\[\]]*)\]\]"), r"\1"),    # [[page|text]]
    (re.compile(r"\[\[([^\[\]]*)\]\]"), r"\1"),               # [[page]]
    (re.compile(r"\[https?://\S+\s*([^\]]*)\]"), r"\1"),      # [url text]
    (re.compile(r"https?://\S+"), " "),
    (re.compile(r"&[a-z]+;"), " "),
]
_TEMPLATE = re.compile(r"\{\{[^{}]*\}\}")


def plain(wikitext: str) -> str:
    """An article's text without its markup: templates, tables, references,
    files, categories and tags out; a link's text kept."""
    text = wikitext
    while True:
        stripped = _TEMPLATE.sub(" ", text)
        if stripped == text:
            break
        text = stripped
    for pattern, repl in _MARKUP:
        text = pattern.sub(repl, text)
    return text


def dump_articles(path: Path) -> Iterator[str]:
    """The wikitext of each article in a pages-articles dump: namespace 0,
    not a redirect."""
    opener = bz2.open if path.suffix == ".bz2" else open
    with opener(path, "rb") as f:
        ns = text = None
        redirect = False
        for _, elem in ET.iterparse(f, events=("end",)):
            tag = elem.tag.rsplit("}", 1)[-1]
            if tag == "ns":
                ns = elem.text
            elif tag == "redirect":
                redirect = True
            elif tag == "text":
                text = elem.text or ""
            elif tag == "page":
                if ns == "0" and not redirect and text is not None:
                    yield text
                ns = text = None
                redirect = False
                elem.clear()


def is_dump(path: Path) -> bool:
    return path.is_file() and (path.name.endswith(".xml") or path.name.endswith(".xml.bz2"))


def texts(path: Path) -> Iterator[str]:
    """The text to count: a dump's articles, a text file, or every file in a
    folder of extracted text, in name order."""
    if is_dump(path):
        for article in dump_articles(path):
            yield plain(article)
        return
    files = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
    for p in files:
        with p.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                # WikiExtractor's own lines, <doc ...> and </doc>, are no text.
                if not line.startswith(("<doc ", "</doc>")):
                    yield line


def count(chunks: Iterable[str]) -> Counter[str]:
    counts: Counter[str] = Counter()
    for chunk in chunks:
        counts.update(words(chunk))
    return counts


def ranks(counts: Counter[str]) -> dict[str, int]:
    """Each word's rank, 1 the most frequent; equal counts in text order."""
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return {word: i + 1 for i, (word, _) in enumerate(ordered)}


def write_counts(counts: Counter[str], path: Path) -> None:
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    path.write_text("".join(f"{w}\t{n}\n" for w, n in ordered), encoding="utf-8")


def read_counts(path: Path) -> Counter[str]:
    counts: Counter[str] = Counter()
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        word, _, number = line.partition("\t")
        if not number.strip().isdigit():
            raise ValueError(f"{path}:{n}: expected a word, a tab and a number")
        counts[vd._key(word)] += int(number)
    return counts


def month_of(path: Path | None) -> str | None:
    """The month of a dump named as Wikimedia names them,
    `hiwiki-20261001-pages-articles.xml.bz2`."""
    m = re.search(r"wiki-(\d{4})(\d{2})\d{2}-", path.name) if path else None
    return f"{m.group(1)}-{m.group(2)}" if m else None


# --- Writing the decks -------------------------------------------------------------

def deck_files(decks: Path, code: str) -> list[Path]:
    """The language's files that hold cards with a target: its cores and its
    single-file decks."""
    out = []
    for p in sorted((decks / code).glob("*.yaml")):
        raw = vd._load_raw(p)
        if isinstance(raw, dict) and isinstance(raw.get("cards"), list) \
                and raw.get("kind", "vocab") in ("vocab", "grammar"):
            out.append(p)
    return out


def fill(decks: Path, code: str, rank: dict[str, int], source: str,
         write: bool) -> tuple[int, list[str], list[str], int]:
    """Gives each one-word card without a frequency its rank. Returns how
    many it gave, the cards whose word Wikipedia does not use, the cards
    written in flow style (left alone), and how many kept their own."""
    given = 0
    unused: list[str] = []
    flow: list[str] = []
    kept = 0
    for path in deck_files(decks, code):
        raw = vd._load_raw(path)
        text = path.read_text(encoding="utf-8")
        new = text
        for card in raw["cards"]:
            if not isinstance(card, dict) or not vd._is_str(card.get("id")) \
                    or not vd._is_str(card.get("target")):
                continue
            cid, target = card["id"], card["target"]
            if "frequency" in card:
                kept += 1
                continue
            found = vd._words(target)
            if len(found) != 1:
                continue
            r = rank.get(vd._key(found[0]))
            if r is None:
                unused.append(f"{cid} {target}")
                continue
            head = re.compile(rf'^  - id: "?{re.escape(cid)}"?\s*$')
            if not any(head.match(line) for line in new.split("\n")):
                flow.append(cid)
                continue
            line = f"    frequency: {iw.flow_map([('rank', r), ('source', source)])}"
            new = iw.apply(new, head, 2, [(None, [line])])
            given += 1
        if write and new != text:
            path.write_text(new, encoding="utf-8")
    return given, unused, flow, kept


def report(code: str, source: str, counted: int, distinct: int, given: int,
           unused: list[str], flow: list[str], kept: int) -> str:
    lines = [f"# Wikipedia frequency: {code}", "",
             f"- Source: {source}",
             f"- Words counted: {counted}, {distinct} different",
             f"- Cards given a rank: {given}",
             f"- Cards that keep their own: {kept}",
             f"- Cards whose word Wikipedia does not use: {len(unused)}"]
    if flow:
        lines.append(f"- Written in flow style, left alone: {', '.join(flow)}")
    if unused:
        lines += ["", "## Not in the count", "", *[f"- {u}" for u in unused]]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Rank a language's words by its Wikipedia, and write each card's "
                    "frequency.")
    parser.add_argument("lang", help="the language's code, such as hi")
    parser.add_argument("text", type=Path, nargs="?",
                        help="a pages-articles dump (.xml or .xml.bz2), or a file or "
                             "folder of plain text taken from one")
    parser.add_argument("--from-counts", type=Path,
                        help="rank from a count saved with --counts, in place of text")
    parser.add_argument("--counts", type=Path, help="save the count here")
    parser.add_argument("--month", help="the dump's month, YYYY-MM (default: from "
                                        "the dump's name)")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--write", action="store_true",
                        help="write the ranks into the cards; without it, only report")
    args = parser.parse_args(argv[1:])

    def fail(msg: str) -> int:
        print(f"error: {msg}", file=sys.stderr)
        return 2

    if not vd.LANG_RE.fullmatch(args.lang) or not (args.decks / args.lang).is_dir():
        return fail(f"no decks for {args.lang!r} in {args.decks}")
    if (args.text is None) == (args.from_counts is None):
        return fail("give the text to count, or --from-counts, not both")
    source_path = args.text or args.from_counts
    if not source_path.exists():
        return fail(f"{source_path} does not exist")
    month = args.month or month_of(args.text)
    if month is None:
        return fail("give the dump's month with --month YYYY-MM: the source names it")
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", month):
        return fail(f"--month must be YYYY-MM, got {month!r}")
    try:
        counts = read_counts(args.from_counts) if args.from_counts else count(texts(args.text))
    except (ValueError, ET.ParseError, OSError) as e:
        return fail(str(e))
    if not counts:
        return fail(f"{source_path} has no words to count")
    if args.counts:
        write_counts(counts, args.counts)
    source = f"{args.lang}.wikipedia.org, {month}"
    given, unused, flow, kept = fill(args.decks, args.lang, ranks(counts), source,
                                     args.write)
    print(report(args.lang, source, sum(counts.values()), len(counts), given, unused,
                 flow, kept), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
