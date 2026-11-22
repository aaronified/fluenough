#!/usr/bin/env python3
"""Fetches a portrait for each creator and a poster, cover or title page for
each work of the culture decks, from Wikimedia Commons (ADR-0060,
wiki/Plan-Culture-Media.md, work package 2).

The owner's design: "a loop of fetch requests, whatever is fetched, gets
packaged in decks-live with their cards. Whatever cannot be fetched, remain as
is." For each entry of `decks/creators/<lang>.yaml` (a creator) and
`decks/recommendations/<lang>.yaml` (a work) with no valid `image`:

1. Wikidata item. The entry's own `wikidata` key; else a Wikidata search by
   its name or title, accepted ONLY if the item fits: a creator is a human
   (Q5) whose label or alias matches and whose birth and death years agree
   with the deck's; a work is of the right type for its medium, with a
   matching label, a publication year within a year of the deck's and (when
   the deck's creators resolve) one of those creators. An unsure match is
   skipped and reported as `ambiguous` for a human; a wrong entity never
   supplies an image. A verified QID is written back as `wikidata`.
2. Candidate files, named by the item's statements only (Wikidata allows
   Commons file names there): a creator P18; a work P3383 (film poster), P18,
   P996 (document scan or cover), in that order. Never Wikipedia's REST
   `originalimage`, never a file under `upload.wikimedia.org/wikipedia/en/`
   (fair use), never a host that is not Commons's file server.
3. Each file's author, licence, licence URL, source page and description are
   read from Commons's `extmetadata`. The licence is judged by the validator's
   own rule (`validate_decks.check_licence_and_source`: CC0, public domain,
   CC BY and CC BY-SA 2.0 to 4.0; never NC, ND, GFDL alone or fair use). A
   file with no machine-readable author is skipped (a public-domain file is
   credited "Unknown author": ADR-0060 decision 7). A bare `Unknown`,
   `Unknown author`, `Anonymous`, `?` or Commons's `No machine-readable author
   provided. X assumed` counts as no author (the sound tool's placeholder
   rule), and an author Commons writes twice (`Unknown authorUnknown author`)
   is read once. Every skip is reported with its reason.
4. The file is downloaded through the shared client (`wikimedia_client.py`:
   own download budget, body limit, cache), decoded and resized with ffmpeg so
   that the longest side is at most 1024 px (a portrait) or 2048 px (a work),
   NEVER upscaled, and written as WebP, quality 80 down to 60 until it is at
   most 500 KB (else skipped, `over-size`), as
   `decks/creators/images/<creator id>.webp` or
   `decks/recommendations/images/<work id>.webp`, and the entry gets an
   `image:` block (file, credit, author, licence, licence_url, source_url,
   retrieved, and `kind` where the source says what the picture is) in the
   YAML, touching nothing else.
5. A living creator gets no portrait (decision 9): Wikidata must give a date
   of death, at least `--min-years-dead` years ago (`--include-living` lifts
   it).

    python3 tools/fetch_culture_media.py --survey                  # counts only
    python3 tools/fetch_culture_media.py --lang te --dry-run       # no writes
    python3 tools/fetch_culture_media.py --lang te --kind creators --limit 10
    python3 tools/fetch_culture_media.py --lang te --facts         # Wikidata vs deck
    python3 tools/fetch_culture_media.py --lang te --report te.md --json te.json

Exit codes: 0 done, 1 an error in the decks or files, 2 bad arguments, 3 the
run stopped at the rate limit or the request cap, 4 another Wikimedia error
(the report is still written; rerun: it resumes from the cache and from the
entries already written). A stop at the rate limit lists the entries not yet
written as `deferred` in the report. One file that fails (an error, over size,
a refused licence) never keeps the others from being tried; only a rate limit
stops the run. `--wait-rate-limit` sleeps out a `Retry-After` of up to 900 s
instead of stopping, and `--download-interval` paces the file downloads, as in
`fetch_sound_audio.py`.

Idempotent and resumable: an entry with a valid image is skipped (`--refresh
ID` redoes that entry), every API answer and download is cached, and each entry
is written as soon as it is done. The tool writes only to the images folders,
the two kinds of YAML file, the cache and the report files named; `--survey`
and `--facts` write nothing and download no image; `--dry-run` downloads and
encodes in memory and writes nothing to the decks.

Needs Python 3.11+, PyYAML and `ffmpeg` with libwebp. The encode step is
`encode_webp`, which the tests replace.
"""

from __future__ import annotations

import argparse
import datetime
import html
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
import urllib.parse
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fetch_sound_audio as fsa  # noqa: E402  (NO_AUTHOR, the one placeholder test)
import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402
import wikimedia_client as wc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

PORTRAIT_PX = 1024              # ADR-0060 decision 3: portraits
WORK_PX = 2048                  # and works (the owner's "2k" maximum)
QUALITY_LADDER = (80, 75, 70, 65, 60)
MAX_SOURCE_BYTES = 15 * 1024 * 1024   # a larger source file is skipped
ESTIMATE_BYTES_PER_PIXEL = 0.2  # a survey's guess; the first runs replace it
ESTIMATE_MIN_BYTES = 20 * 1024
IMAGE_MIMES = frozenset({"image/jpeg", "image/png", "image/webp", "image/gif",
                         "image/tiff"})
SOURCE_PROPS = {"P3383": "poster", "P996": "title-page"}   # what a source says it is
CREATOR_PROPS = ("P18",)
WORK_PROPS = ("P3383", "P18", "P996")
COMMONS_FILE_PATH = "/wikipedia/commons/"
COMMONS_PAGE = "https://commons.wikimedia.org/wiki/"
UNSURE_CATEGORY = re.compile(r"(?i)\b(?:fictional|alleged|disputed|unidentified)\b")
# Commons serves thumbnails only at these widths (anything else is HTTP 400).
STANDARD_WIDTHS = (20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840)
FFMPEG_TIMEOUT = 120            # seconds, for one encode
SEARCH_LIMIT = 8
MAX_QUERIES = 3
ENTITY_CHUNK = 20               # items per wbgetentities call (claims are big)
HUMAN = "Q5"
# What a work's `medium` may be on Wikidata (P31). Written from memory and
# meant to grow: a work whose item is none of these is `ambiguous`, never fetched.
WORK_TYPES: dict[str, frozenset[str]] = {
    "film": frozenset({"Q11424", "Q24862", "Q202866", "Q226730", "Q93204", "Q506240",
                       "Q2431196"}),
    "book": frozenset({"Q571", "Q7725634", "Q8261", "Q49084", "Q35760", "Q25379",
                       "Q5185279", "Q37484"}),
    "play": frozenset({"Q25379", "Q7725634"}),
    "song": frozenset({"Q7366", "Q134556", "Q482994", "Q105543609"}),
    "comic": frozenset({"Q1004", "Q1760610", "Q8274", "Q21198342"}),
    "series": frozenset({"Q5398426", "Q1259759"}),
    "podcast": frozenset({"Q24634210"}),
}
CREATOR_CLAIMS = ("P50", "P57", "P58", "P86", "P170", "P175")
KINDS = ("creators", "works")
KIND_DIR = {"creators": "creators", "works": "recommendations"}
KIND_LIST = {"creators": "creators", "works": "recommendations"}


# --- Reading the decks ------------------------------------------------------------

@dataclass
class Entry:
    kind: str                       # "creators" or "works"
    lang: str
    eid: str
    path: Path
    labels: list[tuple[str, str]]   # (language, text) the deck names it by
    born: tuple[int, bool] | None = None    # (year, circa)
    died: tuple[int, bool] | None = None
    living: bool = False
    year: int | None = None
    medium: str = ""
    wikidata: str | None = None
    creators: list[str] = field(default_factory=list)
    image: dict | None = None

    @property
    def folder(self) -> str:
        return KIND_DIR[self.kind]

    @property
    def rel_file(self) -> str:
        return f"decks/{self.folder}/images/{self.eid}.webp"

    @property
    def key(self) -> str:
        return f"{self.lang}/{self.eid}"


def _label_texts(value: object, lang: str, out: list[tuple[str, str]]) -> None:
    """The names a `name` or `title` block gives: strings, `{text: ...}`, and
    one level of language keys."""
    if isinstance(value, str):
        out.append((lang, value))
    elif isinstance(value, dict):
        if isinstance(value.get("text"), str):
            out.append((lang, value["text"]))
        for k, v in value.items():
            if k in ("text", "reading", "ipa", "phonetic"):
                continue
            if isinstance(k, str) and isinstance(v, (str, dict)):
                _label_texts(v, k, out)


def _date(value: object) -> tuple[int, bool] | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value, False
    if isinstance(value, dict) and isinstance(value.get("year"), int):
        return value["year"], bool(value.get("circa"))
    return None


def read_entries(decks: Path, lang: str, kind: str) -> list[Entry]:
    path = decks / KIND_DIR[kind] / f"{lang}.yaml"
    if not path.is_file():
        return []
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    out: list[Entry] = []
    for raw in data.get(KIND_LIST[kind]) or []:
        if not isinstance(raw, dict) or not isinstance(raw.get("id"), str):
            continue
        labels: list[tuple[str, str]] = []
        _label_texts(raw.get("name" if kind == "creators" else "title"), lang, labels)
        creators = raw.get("creator")
        out.append(Entry(
            kind=kind, lang=lang, eid=raw["id"], path=path,
            labels=list(dict.fromkeys(labels)),
            born=_date(raw.get("born")), died=_date(raw.get("died")),
            living=raw.get("living") is True,
            year=raw["year"] if isinstance(raw.get("year"), int) else None,
            medium=raw.get("medium") if isinstance(raw.get("medium"), str) else "",
            wikidata=raw["wikidata"] if isinstance(raw.get("wikidata"), str) else None,
            creators=[c for c in creators if isinstance(c, str)]
            if isinstance(creators, list) else [],
            image=raw["image"] if isinstance(raw.get("image"), dict) else None))
    return out


def languages(decks: Path) -> list[str]:
    found: set[str] = set()
    for kind in KINDS:
        found.update(p.stem for p in (decks / KIND_DIR[kind]).glob("*.yaml"))
    return sorted(found)


def image_valid(decks: Path, entry: Entry) -> bool:
    """An entry has an image that is there: its file exists under the decks."""
    image = entry.image
    if not image or not isinstance(image.get("file"), str):
        return False
    prefix = f"decks/{entry.folder}/images/"
    f = image["file"]
    return f.startswith(prefix) and "/" not in f[len(prefix):] and \
        (decks / entry.folder / "images" / f[len(prefix):]).is_file()


def image_bytes_in(decks: Path) -> int:
    return sum(f.stat().st_size for d in KIND_DIR.values()
               for f in (decks / d / "images").glob("*") if f.is_file())


# --- Wikidata ----------------------------------------------------------------------

def norm(text: str) -> str:
    """A name as compared: no accents, case or punctuation."""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return "".join(c for c in text.casefold() if c.isalnum())


def statements(entity: dict, prop: str) -> list[dict]:
    """The usable statements of [prop]: not deprecated, preferred first."""
    found = [s for s in (entity.get("claims") or {}).get(prop) or []
             if isinstance(s, dict) and s.get("rank") != "deprecated"]
    return sorted(found, key=lambda s: s.get("rank") != "preferred")


def values(entity: dict, prop: str) -> list[object]:
    out = []
    for s in statements(entity, prop):
        snak = s.get("mainsnak") or {}
        value = (snak.get("datavalue") or {}).get("value")
        if snak.get("snaktype") == "value" and value is not None:
            out.append(value)
    return out


def item_ids(entity: dict, prop: str) -> list[str]:
    return [v["id"] for v in values(entity, prop)
            if isinstance(v, dict) and isinstance(v.get("id"), str)]


def time_year(value: object) -> int | None:
    """The year of a Wikidata time value, or None when it is vaguer than a
    year (a century, a decade)."""
    if not isinstance(value, dict) or not isinstance(value.get("time"), str):
        return None
    m = re.match(r"([+-])(\d+)-", value["time"])
    if not m or int(value.get("precision") or 0) < 9:
        return None
    return int(m.group(2)) * (-1 if m.group(1) == "-" else 1)


def years(entity: dict, prop: str) -> list[int]:
    return [y for v in values(entity, prop) if (y := time_year(v)) is not None]


def entity_names(entity: dict) -> set[str]:
    names = set()
    for v in (entity.get("labels") or {}).values():
        names.add(norm(v.get("value", "")))
    for aliases in (entity.get("aliases") or {}).values():
        names.update(norm(a.get("value", "")) for a in aliases)
    names.discard("")
    return names


def label_en(entity: dict) -> str:
    return ((entity.get("labels") or {}).get("en") or {}).get("value", "")


def describe(qid: str, entity: dict) -> str:
    desc = ((entity.get("descriptions") or {}).get("en") or {}).get("value", "")
    return f"{qid} {label_en(entity)!r}" + (f" ({desc})" if desc else "")


def _agree(deck: tuple[int, bool] | None, wd: list[int]) -> bool | None:
    """True: Wikidata's year is within a year of the deck's (five if the deck
    says `circa`); False: it is not; None: one side has no year to compare."""
    if deck is None or not wd:
        return None
    tolerance = 5 if deck[1] else 1
    return any(abs(deck[0] - y) <= tolerance for y in wd)


def creator_fits(entry: Entry, entity: dict) -> bool:
    if HUMAN not in item_ids(entity, "P31"):
        return False
    names = {norm(t) for _, t in entry.labels}
    if not names & entity_names(entity):
        return False
    checks = [_agree(entry.born, years(entity, "P569")),
              _agree(entry.died, years(entity, "P570"))]
    return False not in checks and True in checks


def work_fits(entry: Entry, entity: dict, creator_qids: set[str]) -> bool:
    wanted = WORK_TYPES.get(entry.medium)
    if not wanted or not wanted & set(item_ids(entity, "P31")):
        return False
    if not {norm(t) for _, t in entry.labels} & entity_names(entity):
        return False
    wd_years = years(entity, "P577") + years(entity, "P571")
    if entry.year is None or _agree((entry.year, False), wd_years) is not True:
        return False
    named = {q for p in CREATOR_CLAIMS for q in item_ids(entity, p)}
    if entry.creators:          # the item must name one of the deck's verified creators
        return bool(named & creator_qids)
    return True                 # no creator on either side: label, year and type decide


@dataclass
class Resolution:
    status: str                     # "ok", "no-entity", "ambiguous"
    qid: str = ""
    entity: dict | None = None
    source: str = ""                # "deck" or "search"
    candidates: list[str] = field(default_factory=list)
    note: str = ""


def search_terms(entry: Entry) -> list[tuple[str, str]]:
    """(term, language) to search Wikidata with: English names first."""
    terms = sorted(entry.labels, key=lambda lt: lt[0] != "en")
    return list(dict.fromkeys((t, l) for l, t in terms if t.strip()))[:MAX_QUERIES]


def entities(client: wc.Client, ids: list[str]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for i in range(0, len(ids), ENTITY_CHUNK):
        out.update(client.wikidata_entities(
            ids[i:i + ENTITY_CHUNK], props="labels|aliases|descriptions|claims"))
    return out


def resolve(client: wc.Client, entry: Entry, creator_qids: set[str]) -> Resolution:
    if entry.wikidata:                  # trusted only after the same identity check
        got = entities(client, [entry.wikidata]).get(entry.wikidata)
        if not got or "missing" in got:
            return Resolution("ambiguous", note=f"the deck's wikidata {entry.wikidata} "
                                                f"is not a Wikidata item")
        fits = creator_fits(entry, got) if entry.kind == "creators" \
            else work_fits(entry, got, creator_qids)
        if not fits:
            return Resolution("ambiguous", candidates=[describe(entry.wikidata, got)],
                              note="the deck's wikidata does not match the entry's "
                                   "label, dates, type or creator")
        return Resolution("ok", entry.wikidata, got, "deck")
    if entry.kind == "works" and entry.creators and not creator_qids:
        return Resolution("ambiguous", note="none of the work's creators has a verified "
                                            "Wikidata item")
    hits: list[str] = []
    for term, lang in search_terms(entry):
        data = client.get_json(wc.WIKIDATA_API, {
            "action": "wbsearchentities", "search": term, "language": lang,
            "uselang": "en", "type": "item", "limit": str(SEARCH_LIMIT)})
        hits += [h["id"] for h in data.get("search") or [] if isinstance(h.get("id"), str)]
    hits = list(dict.fromkeys(hits))
    if not hits:
        return Resolution("no-entity")
    found = entities(client, hits)
    fits = [q for q in hits if q in found and (
        creator_fits(entry, found[q]) if entry.kind == "creators"
        else work_fits(entry, found[q], creator_qids))]
    if len(fits) == 1:
        return Resolution("ok", fits[0], found[fits[0]], "search")
    named = {norm(t) for _, t in entry.labels}
    close = [q for q in hits if q in found and named & entity_names(found[q])]
    if fits:
        return Resolution("ambiguous", candidates=[describe(q, found[q]) for q in fits],
                          note="more than one item fits")
    if close:
        return Resolution("ambiguous", candidates=[describe(q, found[q]) for q in close[:5]],
                          note="a label matches but the type, dates or creator do not "
                               "confirm it")
    return Resolution("no-entity")


# --- Candidate files and the licence gate -------------------------------------------

@dataclass
class Candidate:
    title: str                      # File:Name.jpg
    prop: str


def candidates(entry: Entry, entity: dict) -> list[Candidate]:
    props = CREATOR_PROPS if entry.kind == "creators" else WORK_PROPS
    out: list[Candidate] = []
    for prop in props:
        for name in values(entity, prop):
            if isinstance(name, str) and name.strip():
                title = "File:" + name.strip().replace("_", " ")
                if all(c.title != title for c in out):
                    out.append(Candidate(title, prop))
    return out


def file_url_refusal(url: str) -> str | None:
    """Why [url] may not be downloaded, or None: only Commons files on
    upload.wikimedia.org or thumb.wikimedia.org (never a local wiki's upload, such as the fair-use
    files under /wikipedia/en/)."""
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname not in wc.DOWNLOAD_HOSTS:
        return "not a Commons file on upload.wikimedia.org or thumb.wikimedia.org"
    if not parts.path.startswith(COMMONS_FILE_PATH):
        return "not under /wikipedia/commons/ (a local wiki's upload, maybe fair use)"
    return None


def _raw_meta(info: dict, key: str) -> str:
    value = (info.get("extmetadata") or {}).get(key, {})
    value = value.get("value") if isinstance(value, dict) else None
    return value if isinstance(value, str) else ""


def _meta(info: dict, key: str) -> str:
    raw = _raw_meta(info, key)
    return iw.strip_html(raw) if raw else ""


_KEEP_TOGETHER = re.compile(r"(?i)</?(?:b|i|u|em|strong|sup|sub|small|big|font|abbr)\b[^>]*>")
_ANY_TAG = re.compile(r"<[^>]+>")


def clean_author(raw: str) -> str:
    """Commons's `Artist` as plain text. Block and inline-container tags
    (`<span>`, `<bdi>`, `<br>`, `<a>`...) become a space, so two neighbouring
    elements never run together; a name Commons writes twice (a hidden copy
    next to the shown one) is kept once."""
    if not raw:
        return ""
    text = _ANY_TAG.sub(" ", _KEEP_TOGETHER.sub("", raw))
    text = re.sub(r"\s+", " ", html.unescape(text)).strip()
    for sep in ("", " "):
        n = len(text) - len(sep)
        if n >= 10 and n % 2 == 0 and text[:n // 2] == text[n // 2 + len(sep):] \
                and text[n // 2:n // 2 + len(sep)] == sep:
            text = text[:n // 2]
            break
    return text


def no_author(text: str) -> bool:
    """Whether [text] names nobody: empty, a placeholder of the sound tool's
    rule, or Commons's `author assumed` line."""
    return not text or bool(fsa.NO_AUTHOR.fullmatch(text)) \
        or bool(fsa.ASSUMED_PREFIX.match(text))


def gate_error(licence: str, page: str) -> str | None:
    """The validator's one licence-and-source rule, applied to a candidate."""
    r = vd.Report(Path("fetch_culture_media"))
    vd.check_licence_and_source(r, "image", "licence", licence, "source_url", page,
                                "image", generated_ok=False)
    return "; ".join(r.errors) or None


@dataclass
class Verdict:
    # "ok", "missing", "licence", "no-author", "over-size", "bad-type", "refused",
    # "restricted", "no-licence-url"
    status: str
    title: str
    prop: str = ""
    api_title: str = ""             # the title as the API returned it (normalised)
    info: dict | None = None
    licence: str = ""               # the deck's id, `CC-BY-SA-4.0`
    licence_name: str = ""          # Commons's, `CC BY-SA 4.0`
    licence_url: str = ""
    author: str = ""
    page: str = ""
    url: str = ""
    width: int = 0
    height: int = 0
    reason: str = ""


def judge(cand: Candidate, info: dict | None) -> Verdict:
    """Whether the Commons file [info] may ship, and its credit."""
    if info is None:
        return Verdict("missing", cand.title, cand.prop)
    name = _meta(info, "LicenseShortName")
    url = info.get("url") or ""
    page = info.get("descriptionurl") or f"{COMMONS_PAGE}{cand.title.replace(' ', '_')}"
    base = dict(title=cand.title, prop=cand.prop, info=info,
                api_title=info.get("title") or cand.title, licence_name=name, url=url,
                page=page, width=int(info.get("width") or 0),
                height=int(info.get("height") or 0))
    if why := file_url_refusal(url):
        return Verdict("refused", reason=why, **base)
    if not page.startswith(COMMONS_PAGE):
        return Verdict("refused", reason="source page is not on commons.wikimedia.org",
                       **base)
    mime = info.get("mime")
    if not isinstance(mime, str) or mime.lower() not in IMAGE_MIMES:
        return Verdict("bad-type", reason=f"file type {mime!r} is not a picture we read",
                       **base)
    licence = iw.licence_id(name)
    if licence is None or gate_error(licence, page):
        return Verdict("licence", reason=f"licence {name!r} cannot ship", **base)
    if _meta(info, "Restrictions"):
        return Verdict("restricted", licence=licence,
                       reason=f"Commons notes restrictions: {_meta(info, 'Restrictions')}",
                       **base)
    author = clean_author(_raw_meta(info, "Artist"))
    if no_author(author):
        if licence != "public-domain":
            return Verdict("no-author", licence=licence,
                           reason="no machine-readable author", **base)
        author = vd.UNKNOWN_AUTHOR          # ADR-0060 decision 7
    author = re.sub(r"[<>]", "", author)
    if len(author) > vd.IMAGE_AUTHOR_MAX:
        author = author[:vd.IMAGE_AUTHOR_MAX - 1].rstrip() + "…"
    licence_url = _meta(info, "LicenseUrl")
    if licence_url.startswith("http://"):
        licence_url = "https://" + licence_url[len("http://"):]
    if licence != "public-domain" and not licence_url.startswith("https://"):
        return Verdict("no-licence-url", licence=licence,
                       reason="Commons gives no licence URL", **base)
    size = info.get("size")
    if isinstance(size, (int, float)) and size > MAX_SOURCE_BYTES:
        return Verdict("over-size", licence=licence,
                       reason=f"source file over {MAX_SOURCE_BYTES // 1048576} MB", **base)
    return Verdict("ok", licence=licence, licence_url=licence_url
                   if licence_url.startswith("https://") else "", author=author, **base)


# --- Resizing and encoding -----------------------------------------------------------

def scale_filter(max_side: int) -> str:
    """ffmpeg's scale for a longest side of at most [max_side] px: the box is
    never larger than the picture, so a small picture is never upscaled."""
    return (f"scale='min({max_side},iw)':'min({max_side},ih)'"
            f":force_original_aspect_ratio=decrease")


def ffmpeg_args(src: Path, out: Path, max_side: int, quality: int) -> list[str]:
    return ["-protocol_whitelist", "file", "-i", str(src), "-vf", scale_filter(max_side),
            "-frames:v", "1", "-map_metadata", "-1", "-c:v", "libwebp",
            "-quality", str(quality), str(out)]


def encode_webp(data: bytes, suffix: str, max_side: int, quality: int) -> bytes:
    """[data], a picture ending in [suffix], as WebP at [quality] with the
    longest side at most [max_side], never upscaled, metadata dropped (the
    input's EXIF orientation is applied: ffmpeg's `-autorotate` is on by default
    and runs before the filter). Needs
    ffmpeg with libwebp; the tests replace this function."""
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / ("in" + suffix)
        out = Path(tmp) / "out.webp"
        src.write_bytes(data)
        subprocess.run([iw.ffmpeg(), "-nostdin", "-loglevel", "error", "-y",
                        *ffmpeg_args(src, out, max_side, quality)],
                       check=True, capture_output=True, timeout=FFMPEG_TIMEOUT)
        return out.read_bytes()


def encode_fitting(data: bytes, suffix: str, max_side: int,
                   limit: int = vd.SHARED_IMAGE_MAX_BYTES) -> tuple[bytes | None, str]:
    """WebP of [data] of at most [limit] bytes, trying QUALITY_LADDER in turn;
    (None, why) if even the lowest quality is over."""
    smallest = 0
    for quality in QUALITY_LADDER:
        try:
            out = encode_webp(data, suffix, max_side, quality)
        except Exception as e:      # ffmpeg missing or failed: a message, not a crash
            if isinstance(e, iw.ImportError_):
                raise
            return None, f"encode failed: {getattr(e, 'stderr', b'') or e}"
        smallest = len(out)
        if smallest <= limit:
            side = vd.image_size(out)
            if side is not None and max(side) > max_side:
                return None, f"encoded {side[0]} x {side[1]} px, over {max_side}"
            return out, ""
    return None, f"over-size: {smallest} bytes at quality {QUALITY_LADDER[-1]}, " \
                 f"limit {limit}"


def thumb_width(width: int, height: int, max_side: int) -> int:
    """The Commons thumbnail width (the URL parameter is a width, even for a
    tall picture) that makes the longest side at most [max_side], never above
    the picture's own width."""
    longest = max(width, height)
    side = min(max_side, longest)
    return max(1, min(width, round(width * side / longest)))


def standard_width(needed: int, original_width: int) -> int | None:
    """The smallest standard thumbnail width that is at least [needed] and not
    above the picture's own width (so never an upscale), or None: use the
    original. ffmpeg then resizes the thumbnail to the exact target."""
    return next((w for w in STANDARD_WIDTHS if needed <= w <= original_width), None)


def estimate_bytes(v: Verdict, max_side: int) -> int:
    longest = max(v.width, v.height, 1)
    scale = min(1.0, max_side / longest)
    pixels = v.width * v.height * scale * scale
    return int(min(vd.SHARED_IMAGE_MAX_BYTES,
                   max(ESTIMATE_MIN_BYTES, pixels * ESTIMATE_BYTES_PER_PIXEL)))


# --- Editing a deck file --------------------------------------------------------------

def _drop_keys(lines: list[str], start: int, end: int, keys: tuple[str, ...]) -> int:
    """Removes the entry's top-level [keys] (with their deeper lines) from
    lines[start:end]; returns how many lines went."""
    i, removed = start + 1, 0
    while i < end - removed:
        if any(re.match(rf"^    {k}:", lines[i]) for k in keys):
            j = i + 1
            while j < end - removed and (not lines[j].strip()
                                         or len(lines[j]) - len(lines[j].lstrip(" ")) > 4):
                j += 1
            del lines[i:j]
            removed += j - i
        else:
            i += 1
    return removed


def image_lines(image: dict[str, str]) -> list[str]:
    return ["    image:"] + [f"      {k}: {iw.q(v)}" for k, v in image.items()]


def edit_entry(text: str, eid: str, image: dict[str, str], wikidata: str | None) -> str:
    """[text] with `image` (and `wikidata`, when given) set on entry [eid]:
    replaced if it has them, else added at the end of the entry. Everything
    else is untouched."""
    head = re.compile(rf'^  - id: "?{re.escape(eid)}"?\s*$')
    lines = text.split("\n")
    found = iw._block(lines, head, 2)
    if found is None:
        raise iw.ImportError_(f"{eid} is not in the file")
    start, end = found
    end -= _drop_keys(lines, start, end, ("image", "wikidata") if wikidata else ("image",))
    new = ([f"    wikidata: {iw.q(wikidata)}"] if wikidata else []) + image_lines(image)
    lines[end:end] = new
    return "\n".join(lines)


def read_back(before: str, after: str, list_key: str, eid: str, image: dict[str, str],
              wikidata: str | None) -> None:
    """Raises unless [after] parses, has [image] (and [wikidata]) on entry
    [eid], and is the same as [before] everywhere else."""
    def load(text: str) -> dict:
        return json.loads(json.dumps(yaml.safe_load(text), default=str))

    old, new = load(before), load(after)
    got: dict[str, object] = {}
    for doc, strip in ((old, False), (new, True)):
        for item in doc.get(list_key) or []:
            if isinstance(item, dict) and item.get("id") == eid:
                if strip:
                    got = {"image": item.pop("image", None),
                           "wikidata": item.pop("wikidata", None)}
                else:
                    item.pop("image", None)
                    item.pop("wikidata", None)
    if got.get("image") != image:
        raise iw.ImportError_(f"{eid}: the image lines did not read back")
    if wikidata and got.get("wikidata") != wikidata:
        raise iw.ImportError_(f"{eid}: the wikidata line did not read back")
    if old != new:
        raise iw.ImportError_(f"{eid}: the edit changed something else in the file")


# --- The report -------------------------------------------------------------------------

@dataclass
class LangReport:
    lang: str
    entries: int = 0
    already: int = 0
    asked: int = 0
    available: int = 0              # survey and dry run: a usable image exists
    fetched: int = 0
    missing: int = 0                # no Wikidata item, no image statement, no file
    skipped_no_author: int = 0
    skipped_licence: int = 0
    skipped_other: int = 0          # restricted, not a picture, refused host...
    over_size: int = 0
    ambiguous: int = 0
    living: int = 0
    errors: int = 0
    deferred: int = 0               # picked, not written: the run stopped at the rate limit
    bytes: int = 0
    estimated_bytes: int = 0
    by_kind: dict[str, Counter] = field(default_factory=dict)
    licences: Counter = field(default_factory=Counter)
    ids: dict[str, list[str]] = field(default_factory=dict)
    skipped_files: list[dict] = field(default_factory=list)
    review: list[dict] = field(default_factory=list)      # ambiguous matches
    facts: list[str] = field(default_factory=list)

    def note(self, kind: str, eid: str) -> None:
        self.ids.setdefault(kind, []).append(eid)

    def count(self, kind: str, what: str) -> None:
        self.by_kind.setdefault(kind, Counter())[what] += 1


COUNTERS = ("entries", "already", "asked", "available", "fetched", "missing",
            "skipped_no_author", "skipped_licence", "skipped_other", "over_size",
            "ambiguous", "living", "errors", "deferred", "bytes", "estimated_bytes")


@dataclass
class Report:
    mode: str
    langs: dict[str, LangReport] = field(default_factory=dict)
    existing_bytes: int = 0         # images in the decks before the run
    requests: dict[str, int] = field(default_factory=dict)
    stopped: str = ""
    error: str = ""
    fatal: bool = False             # an error in the decks or files: exit 1

    def lang(self, code: str) -> LangReport:
        return self.langs.setdefault(code, LangReport(code))

    def total(self, attr: str) -> int:
        return sum(getattr(r, attr) for r in self.langs.values())

    def ceiling_share(self) -> float:
        added = self.total("bytes") if self.mode in ("write", "dry-run") else \
            self.total("estimated_bytes")
        return 100 * (self.existing_bytes + added) / vd.IMAGE_TOTAL_MAX_BYTES

    def to_json(self) -> dict:
        def one(r: LangReport) -> dict:
            d = {k: getattr(r, k) for k in COUNTERS}
            d.update(lang=r.lang, licences=dict(sorted(r.licences.items())),
                     by_kind={k: dict(sorted(v.items())) for k, v in sorted(r.by_kind.items())},
                     ids={k: v for k, v in sorted(r.ids.items())},
                     skipped_files=r.skipped_files, ambiguous_review=r.review,
                     facts=r.facts)
            return d
        return {"mode": self.mode, "stopped": self.stopped, "error": self.error,
                "requests": self.requests,
                "total": {k: self.total(k) for k in COUNTERS},
                "existing_bytes": self.existing_bytes,
                "ceiling_bytes": vd.IMAGE_TOTAL_MAX_BYTES,
                "ceiling_share_percent": round(self.ceiling_share(), 2),
                "languages": [one(self.langs[c]) for c in sorted(self.langs)]}

    def to_markdown(self) -> str:
        survey = self.mode in ("survey", "facts")
        lines = [f"# Culture media fetch report ({self.mode})", ""]
        if self.stopped:
            lines += [f"**Stopped early:** {self.stopped}", ""]
        if self.error:
            lines += [f"**Error:** {self.error}", ""]
        gotcol = "available" if survey else "fetched"
        lines += [f"| Language | Entries | Already | Asked | {gotcol.capitalize()} | Missing | "
                  f"No author | Licence | Other skips | Over size | Ambiguous | Living | "
                  f"Errors | Deferred | Bytes |",
                  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
        for c in sorted(self.langs):
            r = self.langs[c]
            got = r.available if survey else r.fetched
            size = r.estimated_bytes if survey else r.bytes
            lines.append(f"| {c} | {r.entries} | {r.already} | {r.asked} | {got} | "
                         f"{r.missing} | {r.skipped_no_author} | {r.skipped_licence} | "
                         f"{r.skipped_other} | {r.over_size} | {r.ambiguous} | {r.living} | "
                         f"{r.errors} | {r.deferred} | {size}{' (estimated)' if survey else ''} |")
        got = self.total("available") if survey else self.total("fetched")
        size = self.total("estimated_bytes") if survey else self.total("bytes")
        lines += ["", f"Total: {got} {gotcol}, {size} bytes"
                      f"{' (estimated)' if survey else ''}. Images in the decks before the "
                      f"run: {self.existing_bytes} bytes. Share of the "
                      f"{vd.IMAGE_TOTAL_MAX_BYTES // 1048576} MB ceiling after: "
                      f"{self.ceiling_share():.1f}%.", ""]
        if self.requests:
            lines += ["Requests: " + ", ".join(f"{k} {v}" for k, v in
                                               sorted(self.requests.items())) + ".", ""]
        for c in sorted(self.langs):
            r = self.langs[c]
            lines += [f"## {c}", ""]
            for kind, counts in sorted(r.by_kind.items()):
                lines.append(f"{kind}: " + ", ".join(f"{k} {v}" for k, v in
                                                     sorted(counts.items())) + ".")
            if r.licences:
                lines.append("Licences seen: " + ", ".join(f"{k} {v}" for k, v in
                                                           sorted(r.licences.items())) + ".")
            for kind, ids in sorted(r.ids.items()):
                lines.append(f"- {kind}: {', '.join(ids)}")
            for s in r.skipped_files:
                lines.append(f"- skipped {s['id']} {s['file']}: {s['reason']}")
            if r.review:
                lines.append("Ambiguous, for a human to settle (add a `wikidata` key to "
                             "the entry to fix one):")
                for a in r.review:
                    lines.append(f"  - {a['id']}: {a['note']}; "
                                 f"{'; '.join(a['candidates']) or 'no candidates'}")
            if r.facts:
                lines += ["Wikidata facts (verification only; nothing is written):"]
                lines += [f"  - {f}" for f in r.facts]
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"


# --- The run ----------------------------------------------------------------------------

@dataclass
class Options:
    decks: Path
    langs: list[str] | None = None
    kinds: tuple[str, ...] = KINDS
    limit: int | None = None
    survey: bool = False
    dry_run: bool = False
    facts: bool = False
    refresh: frozenset[str] = frozenset()
    include_living: bool = False
    min_years_dead: int = 5
    portrait_px: int = PORTRAIT_PX
    work_px: int = WORK_PX
    today: datetime.date | None = None

    @property
    def read_only(self) -> bool:
        return self.survey or self.facts


def run(client: wc.Client, opts: Options) -> Report:
    mode = "facts" if opts.facts else "survey" if opts.survey else \
        "dry-run" if opts.dry_run else "write"
    report = Report(mode)
    decks = opts.decks
    report.existing_bytes = image_bytes_in(decks)
    available = languages(decks)
    codes = opts.langs if opts.langs else available
    for code in codes:
        if code not in available:
            raise iw.ImportError_(f"{code}: no creators or recommendations file under {decks}")

    creators: dict[str, Entry] = {}
    todo: list[Entry] = []
    for code in codes:
        lr = report.lang(code)
        for kind in KINDS:
            for entry in read_entries(decks, code, kind):
                if kind == "creators":
                    creators[entry.eid] = entry
                if kind not in opts.kinds:
                    continue
                lr.entries += 1
                if entry.eid not in opts.refresh and image_valid(decks, entry):
                    lr.already += 1
                    continue
                if entry.image is not None and entry.eid not in opts.refresh \
                        and not opts.facts:
                    lr.note("invalid-existing-image (kept; --refresh ID redoes it)",
                            entry.eid)
                    lr.errors += 1
                    continue
                todo.append(entry)
    if opts.limit is not None:
        todo = todo[:opts.limit]
    for entry in todo:
        report.lang(entry.lang).asked += 1
    try:
        _fetch(client, opts, report, todo, creators)
    except (wc.RateLimited, wc.RequestCapReached) as e:
        report.stopped = str(e)
    except wc.WikimediaError as e:
        report.error = str(e)
    except (iw.ImportError_, OSError, yaml.YAMLError, ValueError) as e:
        report.error, report.fatal = str(e), True
    report.requests = {"api": client.stats.api_requests,
                       "downloads": client.stats.download_requests,
                       "cache_hits": client.stats.cache_hits,
                       "retries": client.stats.retries}
    return report


def _death_refusal(opts: Options, entry: Entry, res: Resolution) -> str | None:
    """Why a creator may not have a portrait (decision 9), or None."""
    if opts.include_living:
        return None
    if entry.living:
        return "the deck says the creator is living"
    died = years(res.entity or {}, "P570")
    if not died:
        return "Wikidata gives no date of death"
    today = opts.today or datetime.date.today()
    if today.year - max(died) < opts.min_years_dead:
        return f"died {max(died)}, less than {opts.min_years_dead} years ago"
    return None


def _fetch(client: wc.Client, opts: Options, report: Report, todo: list[Entry],
           creators: dict[str, Entry]) -> None:
    # 1. Creators first: a work is verified against its creators' items.
    wanted = list(todo)
    seen = {e.key for e in wanted}
    for entry in todo:
        if entry.kind == "works":
            for cid in entry.creators:
                c = creators.get(cid)
                if c and c.key not in seen:
                    wanted.append(c)
                    seen.add(c.key)
    wanted.sort(key=lambda e: e.kind != "creators")
    resolved: dict[str, Resolution] = {}
    for entry in wanted:
        qids = {resolved[f"{entry.lang}/{c}"].qid for c in entry.creators
                if f"{entry.lang}/{c}" in resolved and resolved[f"{entry.lang}/{c}"].qid}
        resolved[entry.key] = resolve(client, entry, qids)

    # 2. Candidates of every entry that resolved and may have an image.
    plans: dict[str, list[Candidate]] = {}
    for entry in todo:
        lr = report.lang(entry.lang)
        res = resolved[entry.key]
        if opts.facts and res.status == "ok":
            lr.facts.append(_facts_line(client, entry, res))
        if res.status == "ambiguous":
            lr.ambiguous += 1
            lr.note("ambiguous", entry.eid)
            lr.review.append({"id": entry.eid, "kind": entry.kind, "note": res.note,
                              "candidates": res.candidates})
            continue
        if res.status != "ok":
            lr.missing += 1
            lr.note("missing (no Wikidata item)", entry.eid)
            continue
        if entry.kind == "creators" and (why := _death_refusal(opts, entry, res)):
            lr.living += 1
            lr.note("living", entry.eid)
            lr.skipped_files.append({"id": entry.eid, "file": "-", "reason": why})
            continue
        cands = candidates(entry, res.entity or {})
        if not cands:
            lr.missing += 1
            lr.note("missing (no image statement)", entry.eid)
            continue
        plans[entry.key] = cands
    if opts.facts:
        return
    titles = list(dict.fromkeys(c.title for cs in plans.values() for c in cs))
    infos = client.imageinfo(titles, props="url|size|mime|extmetadata") if titles else {}

    # 3. The first usable file of each entry; then fetch and write.
    chosen: dict[str, Verdict] = {}
    for entry in todo:
        cands = plans.get(entry.key)
        if not cands:
            continue
        lr = report.lang(entry.lang)
        best: Verdict | None = None
        for cand in cands:
            v = judge(cand, infos.get(cand.title))
            if v.status != "missing":
                lr.licences[v.licence or v.licence_name or "?"] += 1
            if v.status == "ok":
                best = v
                break
            if v.status != "missing":
                lr.skipped_files.append({"id": entry.eid, "file": cand.title,
                                         "reason": v.reason or v.status})
                if best is None or RANK[v.status] > RANK[best.status]:
                    best = v
        if best is None or best.status == "missing":
            lr.missing += 1
            lr.note("missing (file not on Commons)", entry.eid)
        elif best.status == "ok":
            chosen[entry.key] = best
        else:
            _count_skip(lr, best.status, entry.eid)
    if chosen:
        _check_categories(client, report, todo, chosen)
    ready = [e for e in todo if e.key in chosen]
    for i, entry in enumerate(ready):
        v = chosen[entry.key]
        lr = report.lang(entry.lang)
        px = opts.portrait_px if entry.kind == "creators" else opts.work_px
        if opts.survey:
            lr.available += 1
            lr.count(entry.kind, "available")
            lr.estimated_bytes += estimate_bytes(v, px)
            lr.note("available", entry.eid)
            continue
        try:
            _write(client, opts, lr, entry, v, resolved[entry.key], px)
        except (wc.RateLimited, wc.RequestCapReached):
            # Not willing to wait: this entry and the rest are deferred; a
            # rerun resumes from the cache and from the entries written.
            for left in ready[i:]:
                report.lang(left.lang).deferred += 1
                report.lang(left.lang).note("deferred", left.eid)
            raise
        except (iw.ImportError_, OSError):
            raise                       # the decks or the disk: stop
        except Exception as e:          # noqa: BLE001  one file never stops the others
            lr.errors += 1
            lr.note(f"error: {type(e).__name__}: {e}", entry.eid)


RANK = {"missing": 0, "bad-type": 1, "refused": 1, "over-size": 2, "restricted": 3,
        "no-licence-url": 3, "licence": 4, "no-author": 5}


def _count_skip(lr: LangReport, status: str, eid: str) -> None:
    if status == "no-author":
        lr.skipped_no_author += 1
        lr.note("skipped-no-author", eid)
    elif status == "licence":
        lr.skipped_licence += 1
        lr.note("skipped-licence", eid)
    elif status == "over-size":
        lr.over_size += 1
        lr.note("over-size", eid)
    else:
        lr.skipped_other += 1
        lr.note(f"skipped-{status}", eid)


def _check_categories(client: wc.Client, report: Report, todo: list[Entry],
                      chosen: dict[str, Verdict]) -> None:
    """A creator's chosen file whose Commons categories say Fictional, Alleged,
    Disputed or Unidentified is not taken by itself: it goes to the review
    list (Plan-Culture-Media, "Which creators can have a portrait")."""
    by_title = {chosen[e.key].api_title: e for e in todo
                if e.kind == "creators" and e.key in chosen}
    for batch in wc.batched(list(by_title)):
        cats: dict[str, list[str]] = {}
        extra: dict[str, str] = {}
        for _ in range(20):
            data = client.get_json(wc.COMMONS_API, {
                "action": "query", "prop": "categories", "cllimit": "max",
                "formatversion": "2", "titles": "|".join(batch), **extra})
            for page in (data.get("query") or {}).get("pages") or []:
                cats.setdefault(page.get("title"), []).extend(
                    c.get("title", "") for c in page.get("categories") or [])
            more = data.get("continue")
            if not isinstance(more, dict) or not more:
                break
            extra = {k: str(v) for k, v in more.items()}
        for title in batch:
            hit = next((c for c in cats.get(title, []) if UNSURE_CATEGORY.search(c)), None)
            if hit is None:
                continue
            entry = by_title[title]
            lr = report.lang(entry.lang)
            del chosen[entry.key]
            lr.ambiguous += 1
            lr.note("ambiguous", entry.eid)
            lr.review.append({"id": entry.eid, "kind": entry.kind,
                              "note": f"the file {title} is in {hit!r}",
                              "candidates": [title]})


def _facts_line(client: wc.Client, entry: Entry, res: Resolution) -> str:
    """Wikidata's dates and places next to the deck's (decision 15: it only
    verifies; nothing is written)."""
    ent = res.entity or {}

    def deck(d: tuple[int, bool] | None) -> str:
        return "-" if d is None else f"{d[0]}{' circa' if d[1] else ''}"

    def span(prop: str) -> str:
        return "/".join(map(str, years(ent, prop))) or "-"

    def places(*props: str) -> str:
        ids = [q for p in props for q in item_ids(ent, p)]
        labels = entities_labels(client, ids)
        return ", ".join(labels.get(q, q) for q in ids) or "-"

    if entry.kind == "creators":
        return (f"{entry.eid} ({res.qid}, {res.source}): born deck {deck(entry.born)} / "
                f"Wikidata {span('P569')}; died deck {deck(entry.died)} / Wikidata "
                f"{span('P570')}; birthplace {places('P19')}; death place {places('P20')}")
    return (f"{entry.eid} ({res.qid}, {res.source}): year deck {entry.year or '-'} / "
            f"Wikidata {'/'.join(map(str, years(ent, 'P577') + years(ent, 'P571'))) or '-'}; "
            f"country of origin {places('P495')}")


def entities_labels(client: wc.Client, ids: list[str]) -> dict[str, str]:
    if not ids:
        return {}
    got = client.wikidata_entities(list(dict.fromkeys(ids)), props="labels")
    return {q: label_en(e) or q for q, e in got.items()}


def _thumb_url(client: wc.Client, v: Verdict, px: int) -> str | None:
    """The Commons thumbnail to fetch, or None to fetch the original: the
    original is used when it is already within [px] and small enough for the
    client's body limit, or when no standard thumbnail width fits under its own
    width. Commons serves only STANDARD_WIDTHS; the thumbnail is at least the
    target, and ffmpeg makes the final resize. The URL is kept as the API gave
    it."""
    size = (v.info or {}).get("size") or 0
    if not (v.width and v.height):
        return None
    if max(v.width, v.height) <= px and size <= wc.MAX_DOWNLOAD_BYTES:
        return None
    width = standard_width(thumb_width(v.width, v.height, px), v.width)
    if width is None:
        return None
    data = client.get_json(wc.COMMONS_API, {
        "action": "query", "prop": "imageinfo", "iiprop": "url", "formatversion": "2",
        "iiurlwidth": str(width), "titles": v.api_title})
    pages = (data.get("query") or {}).get("pages") or [{}]
    info = (pages[0].get("imageinfo") or [{}])[0]
    url = info.get("thumburl")
    return url if isinstance(url, str) and url else None


def _get_picture(client: wc.Client, v: Verdict, px: int) -> tuple[bytes | None, str, str]:
    """(bytes, url, "") for the picture, or (None, "", why). A thumbnail
    that Commons refuses (HTTP 400 or 404) falls back to the original when that
    fits the body limit; raises ResponseTooLarge when only a too-large original
    is left, and the client's rate-limit errors."""
    size = (v.info or {}).get("size") or 0
    original_ok = size <= wc.MAX_DOWNLOAD_BYTES
    thumb = _thumb_url(client, v, px)
    if thumb is None and not original_ok:
        raise wc.ResponseTooLarge(f"{v.url} is over the body limit and has no thumbnail")
    tried = [("thumb", thumb)] if thumb else []
    if original_ok:
        tried.append(("original", v.url))
    why = ""
    for kind, url in tried:
        if refusal := file_url_refusal(url):
            why = refusal
            continue
        try:
            return client.get_bytes(url), url, ""
        except wc.HttpError as e:
            if e.status not in (400, 404):
                raise
            why = f"bad-thumb: HTTP {e.status} for the {kind}"
    return None, "", why or "bad-thumb: no usable download"


def _write(client: wc.Client, opts: Options, lr: LangReport, entry: Entry, v: Verdict,
           res: Resolution, px: int) -> None:
    try:
        raw, url, why = _get_picture(client, v, px)
        if raw is None:
            lr.skipped_other += 1
            lr.note("skipped-bad-thumb" if why.startswith("bad-thumb") else "skipped-refused",
                    entry.eid)
            lr.skipped_files.append({"id": entry.eid, "file": v.title, "reason": why})
            return
    except (wc.RateLimited, wc.RequestCapReached):
        raise
    except wc.ResponseTooLarge:
        lr.over_size += 1
        lr.note("over-size", entry.eid)
        lr.skipped_files.append({"id": entry.eid, "file": v.title,
                                 "reason": "download over the client's body limit"})
        return
    except wc.WikimediaError as e:
        lr.errors += 1
        lr.note(f"error: {e}", entry.eid)
        return
    webp, why = encode_fitting(raw, Path(urllib.parse.urlsplit(url).path).suffix.lower()
                               or ".jpg", px)
    if webp is None:
        if why.startswith("over"):
            lr.over_size += 1
            lr.note("over-size", entry.eid)
            lr.skipped_files.append({"id": entry.eid, "file": v.title, "reason": why})
        else:
            lr.errors += 1
            lr.note(f"error: {why}", entry.eid)
        return
    kind = SOURCE_PROPS.get(v.prop) if entry.kind == "works" else None
    image = {"file": entry.rel_file,
             "credit": f"{v.author}, {v.licence_name}, via Wikimedia Commons",
             "author": v.author, "licence": v.licence}
    if v.licence_url:
        image["licence_url"] = v.licence_url
    image["source_url"] = v.page
    image["retrieved"] = (opts.today or datetime.date.today()).isoformat()
    if kind:
        image["kind"] = kind
    qid = res.qid if res.source == "search" else None
    if opts.dry_run:
        lr.fetched += 1
        lr.bytes += len(webp)
        lr.count(entry.kind, "fetched")
        lr.note("would-fetch", entry.eid)
        return
    folder = (opts.decks / entry.folder / "images").resolve()
    out = (folder / f"{entry.eid}.webp").resolve()
    if out.parent != folder or entry.path.resolve().parent != (opts.decks / entry.folder
                                                               ).resolve():
        raise iw.ImportError_(f"{entry.eid}: refusing to write outside the images folders")
    before = entry.path.read_text(encoding="utf-8")
    try:
        after = edit_entry(before, entry.eid, image, qid)
        read_back(before, after, KIND_LIST[entry.kind], entry.eid, image, qid)
    except (iw.ImportError_, yaml.YAMLError) as e:
        lr.errors += 1
        lr.note(f"error: {e}", entry.eid)
        return
    # The new file is checked in a scratch folder first, then replaced
    # atomically; the old file and YAML survive any failure (--refresh).
    with tempfile.TemporaryDirectory() as tmp:
        mirror = Path(tmp) / entry.folder
        (mirror / "images").mkdir(parents=True)
        (mirror / "images" / out.name).write_bytes(webp)
        check = vd.Report(mirror / entry.path.name)
        vd.check_image(check, entry.eid, image, entry.eid, entry.living,
                       mirror / entry.path.name, folder=entry.folder)
    if check.errors:
        lr.errors += 1
        lr.note(f"error: the validator refuses it: {'; '.join(check.errors)}", entry.eid)
        return
    folder.mkdir(parents=True, exist_ok=True)
    old = out.read_bytes() if out.is_file() else None
    part = out.with_name(out.name + ".part")
    try:
        part.write_bytes(webp)
        os.replace(part, out)
    except OSError:
        part.unlink(missing_ok=True)
        raise
    try:
        entry.path.write_text(after, encoding="utf-8")
    except OSError:
        if old is None:
            out.unlink(missing_ok=True)      # no file without its entry lines
        else:
            out.write_bytes(old)
        raise
    lr.fetched += 1
    lr.bytes += len(webp)
    lr.count(entry.kind, "fetched")
    lr.note("fetched", entry.eid)


# --- Command line -----------------------------------------------------------------------

def main(argv: list[str], client: wc.Client | None = None) -> int:
    p = argparse.ArgumentParser(description="Fetch portraits and posters for the culture "
                                "decks' creators and works from Wikimedia Commons "
                                "(ADR-0060).")
    p.add_argument("--decks", type=Path, default=ROOT / "decks")
    p.add_argument("--lang", action="append", help="a language code; repeat or "
                   "comma-separate (default: every language with a creators or "
                   "recommendations file)")
    p.add_argument("--kind", choices=("works", "creators"), help="only creators' portraits "
                   "or only works' images (default: both)")
    p.add_argument("--survey", action="store_true", help="read-only: what is available, "
                   "estimated bytes, licences, skips, ambiguous matches; downloads no "
                   "image, writes nothing")
    p.add_argument("--dry-run", action="store_true", help="download and encode, but write "
                   "nothing to the decks")
    p.add_argument("--facts", action="store_true", help="read-only: print Wikidata's dates "
                   "and places next to each entry for checking; writes nothing")
    p.add_argument("--limit", type=int, help="entries to ask for in this run")
    p.add_argument("--refresh", action="append", metavar="ID", help="redo this entry "
                   "although it has an image (repeat for more)")
    p.add_argument("--refresh-cache", action="store_true",
                   help="ignore the cache: ask Wikimedia again")
    p.add_argument("--cache", type=Path, default=wc.DEFAULT_CACHE)
    p.add_argument("--max-requests", type=int, default=400, help="hard cap per run")
    p.add_argument("--api-interval", type=float, default=1.0,
                   help="seconds between API requests (default 1)")
    p.add_argument("--download-interval", type=float, default=wc.DEFAULT_DOWNLOAD_INTERVAL,
                   help="seconds between file downloads (default 5: upload.wikimedia.org "
                   "answers 429 to a faster loop)")
    p.add_argument("--wait-rate-limit", action="store_true",
                   help="sleep out a Retry-After of up to 900 s instead of stopping with "
                   "exit 3 (off by default: a long wait needs this opt-in). There is "
                   "no total runtime bound: up to four 900 s sleeps a request")
    p.add_argument("--include-living", action="store_true",
                   help="also take portraits of creators with no date of death (off)")
    p.add_argument("--min-years-dead", type=int, default=5,
                   help="a creator who died less than this many years ago has no portrait")
    p.add_argument("--portrait-px", type=int, default=PORTRAIT_PX)
    p.add_argument("--work-px", type=int, default=WORK_PX)
    p.add_argument("--report", type=Path, help="write the Markdown report here")
    p.add_argument("--json", type=Path, help="write the JSON report here")
    try:
        args = p.parse_args(argv)
    except SystemExit as e:
        return 0 if e.code in (0, None) else 2
    if sum([args.survey, args.dry_run, args.facts]) > 1:
        print("--survey, --dry-run and --facts do not go together", file=sys.stderr)
        return 2
    if args.api_interval < 0 or args.download_interval < 0:
        print("--api-interval and --download-interval are not negative", file=sys.stderr)
        return 2
    if (args.limit is not None and args.limit < 0) or args.min_years_dead < 0 or \
            not 16 <= args.portrait_px <= vd.SHARED_IMAGE_MAX_SIDE or \
            not 16 <= args.work_px <= vd.SHARED_IMAGE_MAX_SIDE:
        print(f"--limit is not negative; --portrait-px and --work-px are 16 to "
              f"{vd.SHARED_IMAGE_MAX_SIDE}", file=sys.stderr)
        return 2
    langs = [c for item in args.lang or [] for c in item.split(",") if c] or None
    client = client or wc.Client(cache_dir=args.cache, refresh=args.refresh_cache,
                                 max_requests=args.max_requests,
                                 api_interval=args.api_interval,
                                 download_interval=args.download_interval,
                                 wait_rate_limit=args.wait_rate_limit)
    opts = Options(decks=args.decks, langs=langs,
                   kinds=(args.kind,) if args.kind else KINDS, limit=args.limit,
                   survey=args.survey, dry_run=args.dry_run, facts=args.facts,
                   refresh=frozenset(args.refresh or ()),
                   include_living=args.include_living, min_years_dead=args.min_years_dead,
                   portrait_px=args.portrait_px, work_px=args.work_px)
    try:
        report = run(client, opts)
    except (iw.ImportError_, OSError, yaml.YAMLError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    text = report.to_markdown()
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    if args.json:
        args.json.write_text(json.dumps(report.to_json(), indent=2, ensure_ascii=False)
                             + "\n", encoding="utf-8")
    print(text)
    return 1 if report.fatal else 3 if report.stopped else 4 if report.error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
