#!/usr/bin/env python3
"""Fetches a recording for each sound card of a sounds deck (ADR-0059, #734).

A language's `<lang>-sound-inventory` deck has one card per sound. For each
card with no audio this tool looks for a recording it may ship, in this order
and stopping at the first usable one:

1. Wikimedia Commons's recording of the IPA symbol the card's `ipa` is (one
   clip per symbol, `File:Voiceless bilabial plosive.ogg`);
2. a Commons recording of the letter itself, from the language's
   `Category:<Language> pronunciation`;
3. with `--example-words --dump <kaikki.jsonl>`, the Wiktionary recording of
   the card's example word (the pages `tools/import_wiktionary.py --audio`
   reads), which is a recording of the word, not of the sound: off by default.

It reads each file's author, licence and page from the Commons API
(`imageinfo`, `extmetadata`) and skips a file with no named author (also
`Unknown author`, public domain included: ADR-0059 decision 8) and any
licence that cannot ship in a CC BY-SA 4.0 deck (GFDL alone, NC, ND). It
downloads the file, decodes it to 16-bit mono, trims the silence, normalises
the peak to -3 dBFS and encodes Ogg Opus mono at about 32 kbps, variable
bitrate, lower if the clip passes 16 kB (never above 128 kbps), writes
`decks/<lang>/audio/<card id>.opus`, and adds `audio` and `audio_credit` to
the card in the deck file, touching nothing else. A card with nothing usable
gets no `audio`: the phone's text-to-speech says it, as today.

    python3 tools/fetch_sound_audio.py --survey                   # counts only
    python3 tools/fetch_sound_audio.py --lang te --dry-run        # no writes
    python3 tools/fetch_sound_audio.py --lang te --limit 20       # a slice
    python3 tools/fetch_sound_audio.py --lang te --report te.md --json te.json

Exit codes: 0 done, 1 an error in the decks or files, 2 bad arguments, 3 the
run stopped at the rate limit or the request cap, 4 another Wikimedia error
(the report is still written) (rerun: it resumes from the
cache and from the cards already written).

Idempotent and resumable: a card with valid audio is skipped (`--refresh`
redoes it), every API answer and download is cached (`tools/wikimedia_client.py`),
and each card is written as soon as it is done. The tool writes only to the
decks' audio folders and the sound-inventory files (with `--dry-run` and
`--survey` to neither), to the cache, and to the report files named.

Needs Python 3.11+, PyYAML and, to encode, `ffmpeg` with libopus; no
other dependency. The encode step is `encode_clip`, which the tests replace.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402
import wikimedia_client as wc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TARGET_KBPS = 32
KBPS_LADDER = (32, 24, 16, 12)      # tried in turn until the clip fits
MAX_SECONDS = 10                    # a longer source is cut
MAX_SOURCE_BYTES = 5 * 1024 * 1024  # a larger file is skipped, not downloaded
MAX_SOURCE_SECONDS = 30             # so is a longer one
AUDIO_MIMES = frozenset({"audio/ogg", "application/ogg", "audio/x-wav", "audio/wav",
                         "audio/mpeg", "audio/flac", "audio/x-flac", "audio/webm",
                         "audio/opus", "video/ogg", "video/webm"})
PEAK_DB = -3.0
ESTIMATE_BYTES = 7000               # a clip of unknown length, in a survey
SURVEY_KBPS = 32
AUDIO_EXTENSIONS = (".ogg", ".oga", ".wav", ".mp3", ".flac", ".opus", ".webm")

# What counts as no author: Commons's own placeholders.
NO_AUTHOR = re.compile(r"(?i)(?:unknown(?: author)?|anonymous|n/?a|none|\?+)\.?")

# --- The IPA symbols' Commons recordings ----------------------------------------
# Commons names these by the sound's description (the Wikipedia IPA charts
# with audio use them), `<name>.ogg`. A symbol may have more than one name
# in use; each is tried, in this order. Unverified from the build session
# (the Commons API answered 429 there): the survey run says which exist, and
# `--symbols FILE` (JSON, symbol to a list of names) adds or replaces one.
IPA_CLIPS: dict[str, tuple[str, ...]] = {
    # plosives
    "p": ("Voiceless bilabial plosive",), "b": ("Voiced bilabial plosive",),
    "t": ("Voiceless alveolar plosive",), "d": ("Voiced alveolar plosive",),
    "ʈ": ("Voiceless retroflex plosive",), "ɖ": ("Voiced retroflex plosive",),
    "c": ("Voiceless palatal plosive",), "ɟ": ("Voiced palatal plosive",),
    "k": ("Voiceless velar plosive",), "ɡ": ("Voiced velar plosive",),
    "g": ("Voiced velar plosive",),
    "q": ("Voiceless uvular plosive",), "ɢ": ("Voiced uvular plosive",),
    "ʔ": ("Glottal stop", "Voiceless glottal plosive"),
    # nasals
    "m": ("Bilabial nasal", "Voiced bilabial nasal"), "ɱ": ("Labiodental nasal",),
    "n": ("Alveolar nasal", "Voiced alveolar nasal"), "ɳ": ("Retroflex nasal",),
    "ɲ": ("Palatal nasal",), "ŋ": ("Velar nasal",), "ɴ": ("Uvular nasal",),
    # trills and taps
    "ʙ": ("Voiced bilabial trill",), "r": ("Voiced alveolar trill", "Alveolar trill"),
    "ʀ": ("Voiced uvular trill",), "ⱱ": ("Voiced labiodental flap",),
    "ɾ": ("Voiced alveolar tap", "Alveolar tap", "Voiced alveolar flap"),
    "ɽ": ("Voiced retroflex flap",),
    # fricatives
    "ɸ": ("Voiceless bilabial fricative",), "β": ("Voiced bilabial fricative",),
    "f": ("Voiceless labiodental fricative",), "v": ("Voiced labiodental fricative",),
    "θ": ("Voiceless dental fricative",), "ð": ("Voiced dental fricative",),
    "s": ("Voiceless alveolar sibilant",), "z": ("Voiced alveolar sibilant",),
    "ʃ": ("Voiceless postalveolar fricative",), "ʒ": ("Voiced postalveolar fricative",),
    "ʂ": ("Voiceless retroflex sibilant",), "ʐ": ("Voiced retroflex sibilant",),
    "ç": ("Voiceless palatal fricative",), "ʝ": ("Voiced palatal fricative",),
    "x": ("Voiceless velar fricative",), "ɣ": ("Voiced velar fricative",),
    "χ": ("Voiceless uvular fricative",), "ʁ": ("Voiced uvular fricative",),
    "ħ": ("Voiceless pharyngeal fricative",), "ʕ": ("Voiced pharyngeal fricative",),
    "h": ("Voiceless glottal fricative",), "ɦ": ("Voiced glottal fricative",),
    # laterals and approximants
    "ɬ": ("Voiceless alveolar lateral fricative",), "ɮ": ("Voiced alveolar lateral fricative",),
    "l": ("Alveolar lateral approximant", "Voiced alveolar lateral approximant"),
    "ɭ": ("Retroflex lateral approximant",), "ʎ": ("Palatal lateral approximant",),
    "ʟ": ("Velar lateral approximant",),
    "ʋ": ("Labiodental approximant",),
    "ɹ": ("Alveolar approximant", "Voiced alveolar approximant"),
    "ɻ": ("Retroflex approximant",), "j": ("Palatal approximant",),
    "ɰ": ("Velar approximant",), "w": ("Voiced labio-velar approximant",),
    # vowels
    "i": ("Close front unrounded vowel",), "y": ("Close front rounded vowel",),
    "ɨ": ("Close central unrounded vowel",), "ʉ": ("Close central rounded vowel",),
    "ɯ": ("Close back unrounded vowel",), "u": ("Close back rounded vowel",),
    "ɪ": ("Near-close near-front unrounded vowel",), "ʏ": ("Near-close near-front rounded vowel",),
    "ʊ": ("Near-close near-back rounded vowel",),
    "e": ("Close-mid front unrounded vowel",), "ø": ("Close-mid front rounded vowel",),
    "ɘ": ("Close-mid central unrounded vowel",), "ɵ": ("Close-mid central rounded vowel",),
    "ɤ": ("Close-mid back unrounded vowel",), "o": ("Close-mid back rounded vowel",),
    "ə": ("Mid-central vowel",),
    "ɛ": ("Open-mid front unrounded vowel",), "œ": ("Open-mid front rounded vowel",),
    "ɜ": ("Open-mid central unrounded vowel",), "ɞ": ("Open-mid central rounded vowel",),
    "ʌ": ("Open-mid back unrounded vowel",), "ɔ": ("Open-mid back rounded vowel",),
    "æ": ("Near-open front unrounded vowel",), "ɐ": ("Near-open central vowel",),
    "a": ("Open front unrounded vowel",), "ɶ": ("Open front rounded vowel",),
    "ɑ": ("Open back unrounded vowel",), "ɒ": ("Open back rounded vowel",),
}
CLIP_EXTENSIONS = (".ogg", ".oga")


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def symbol_titles(ipa: str | None, clips: dict[str, tuple[str, ...]] | None = None
                  ) -> list[str]:
    """The Commons titles of the recording of [ipa], when it is one IPA
    symbol (slashes and brackets ignored); [] otherwise: `kʰ` or `aː` has
    no clip of its own."""
    clips = IPA_CLIPS if clips is None else clips
    if not ipa:
        return []
    symbol = nfc(ipa.strip().strip("/[]").strip())
    names = clips.get(symbol)
    if not names:
        return []
    return [f"File:{name}{ext}" for name in names for ext in CLIP_EXTENSIONS]


# --- The sound cards ------------------------------------------------------------

@dataclass
class SoundCard:
    lang: str
    cid: str
    target: str
    reading: str
    ipa: str | None
    examples: list[str]
    audio: str | None
    path: Path                      # the deck file the card is in

    @property
    def audio_path(self) -> str:
        return f"decks/{self.lang}/audio/{self.cid}.opus"


def inventory_file(decks: Path, lang: str) -> Path:
    return decks / lang / f"{lang}-sound-inventory.yaml"


def languages_with_inventory(decks: Path) -> list[str]:
    return sorted(d.name for d in decks.iterdir()
                  if d.is_dir() and inventory_file(decks, d.name).is_file())


def read_cards(decks: Path, lang: str) -> list[SoundCard]:
    """The sound cards of [lang]'s inventory deck: the cards it defines
    (a `ref` card has no sound of its own here)."""
    path = inventory_file(decks, lang)
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    cards: list[SoundCard] = []
    for card in data.get("cards") or []:
        if not isinstance(card, dict) or not isinstance(card.get("id"), str):
            continue
        examples = [e["target"] for e in card.get("examples") or []
                    if isinstance(e, dict) and isinstance(e.get("target"), str)]
        cards.append(SoundCard(
            lang=lang, cid=card["id"], target=str(card.get("target", "")),
            reading=str(card.get("reading", "")),
            ipa=card["ipa"] if isinstance(card.get("ipa"), str) else None,
            examples=examples,
            audio=card["audio"] if isinstance(card.get("audio"), str) else None,
            path=path))
    return cards


def audio_valid(decks: Path, card: SoundCard) -> bool:
    """Whether the card has audio that is right: named by the card, the file
    there, Ogg Opus, mono, at most 128 kbps and 16 kB."""
    if card.audio != card.audio_path:
        return False
    f = decks / card.lang / "audio" / f"{card.cid}.opus"
    try:
        data = f.read_bytes()
        channels, seconds = vd.ogg_opus_facts(data)
    except (OSError, ValueError):
        return False
    return (channels == 1 and len(data) <= vd.AUDIO_MAX_BYTES
            and len(data) * 8 / seconds / 1000 <= vd.AUDIO_MAX_KBPS)


# --- Judging a Commons file -----------------------------------------------------

@dataclass
class Verdict:
    # "ok", "missing", "no-author", "licence", "over-size", "bad-type"
    status: str
    title: str
    info: dict | None = None
    licence: str | None = None      # the deck's id, `CC-BY-SA-4.0`
    licence_name: str = ""          # Commons's, `CC BY-SA 4.0`
    credit: str = ""
    page: str = ""
    url: str = ""
    duration: float | None = None


def _meta(info: dict, key: str) -> str:
    value = (info.get("extmetadata") or {}).get(key, {})
    value = value.get("value") if isinstance(value, dict) else None
    return iw.strip_html(value) if isinstance(value, str) else ""


def judge(title: str, info: dict | None) -> Verdict:
    """Whether the Commons file [info] may ship, and its credit."""
    if info is None:
        return Verdict("missing", title)
    name = _meta(info, "LicenseShortName")
    base = dict(title=title, info=info, licence_name=name, url=info.get("url") or "",
                page=info.get("descriptionurl") or
                f"https://commons.wikimedia.org/wiki/{title.replace(' ', '_')}",
                duration=info.get("duration") if isinstance(info.get("duration"),
                                                              (int, float)) else None)
    mime = info.get("mime")
    if isinstance(mime, str) and mime.lower() not in AUDIO_MIMES:
        return Verdict("bad-type", **base)
    licence = iw.licence_id(name)
    if licence is None:
        return Verdict("licence", **base)
    credit = _meta(info, "Artist")
    if not credit or NO_AUTHOR.fullmatch(credit):
        return Verdict("no-author", licence=licence, **base)
    size = info.get("size")
    if (isinstance(size, (int, float)) and size > MAX_SOURCE_BYTES) or \
            (base["duration"] is not None and base["duration"] > MAX_SOURCE_SECONDS):
        return Verdict("over-size", licence=licence, **base)
    return Verdict("ok", licence=licence, credit=credit, **base)


# --- Encoding -------------------------------------------------------------------

def _ffmpeg_text(args: list[str]) -> str:
    """ffmpeg's stderr for [args]. Used only by encode_clip."""
    done = subprocess.run([iw.ffmpeg(), "-nostdin", "-hide_banner", "-y", *args],
                          check=True, capture_output=True)
    return done.stderr.decode("utf-8", "replace")


def encode_clip(data: bytes, suffix: str, kbps: int) -> bytes:
    """[data], a recording ending in [suffix], as Ogg Opus mono at about
    [kbps] kbps, variable bitrate: decoded to 16-bit mono PCM at 24 kHz,
    leading and trailing silence cut, the peak set to PEAK_DB dBFS. Needs
    ffmpeg with libopus; the tests replace this function."""
    # Streaming filters only: nothing buffers the whole source (no areverse).
    # Leading silence is cut, and the clip ends at the first long silence after
    # the sound. `-t` before `-i` bounds the input; `-protocol_whitelist file`
    # keeps ffmpeg to a local file.
    trim = ("silenceremove=start_periods=1:start_silence=0.04:start_threshold=-50dB:"
            "stop_periods=1:stop_duration=0.4:stop_threshold=-50dB")
    guard = ["-protocol_whitelist", "file"]
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / ("in" + (suffix if suffix.startswith(".") else "." + suffix))
        pcm = Path(tmp) / "pcm.wav"
        out = Path(tmp) / "out.opus"
        src.write_bytes(data)
        iw.convert([*guard, "-t", str(MAX_SOURCE_SECONDS), "-i", str(src), "-vn",
                    "-ac", "1", "-ar", "24000", "-af", trim, "-t", str(MAX_SECONDS),
                    "-c:a", "pcm_s16le", str(pcm)])
        report = _ffmpeg_text([*guard, "-i", str(pcm), "-af", "volumedetect", "-f", "null", "-"])
        peak = re.search(r"max_volume:\s*(-?[\d.]+) dB", report)
        gain = PEAK_DB - float(peak.group(1)) if peak else 0.0
        iw.convert([*guard, "-i", str(pcm), "-af", f"volume={gain:.2f}dB", "-ac", "1",
                    "-ar", "24000", "-c:a", "libopus", "-b:a", f"{kbps}k", "-vbr", "on",
                    "-application", "audio", "-map_metadata", "-1", str(out)])
        return out.read_bytes()


def encode_fitting(data: bytes, suffix: str, target_kbps: int = TARGET_KBPS
                   ) -> tuple[bytes | None, str]:
    """Encodes [data] at [target_kbps], then lower until the clip is at most
    16 kB and 128 kbps. Returns (opus, "") or (None, why)."""
    ladder = [k for k in KBPS_LADDER if k <= target_kbps] or [KBPS_LADDER[-1]]
    last = ""
    for kbps in ladder:
        try:
            opus = encode_clip(data, suffix, kbps)
            channels, seconds = vd.ogg_opus_facts(opus)
        except (OSError, ValueError, subprocess.CalledProcessError, iw.ImportError_) as e:
            return None, f"cannot encode: {e}"
        if channels != 1:
            return None, f"encoded {channels} channels, not mono"
        rate = len(opus) * 8 / seconds / 1000
        if len(opus) <= vd.AUDIO_MAX_BYTES and rate <= vd.AUDIO_MAX_KBPS:
            return opus, ""
        last = f"{len(opus)} bytes at {kbps} kbps over {seconds:.1f} s"
    return None, f"over {vd.AUDIO_MAX_BYTES} bytes even at {ladder[-1]} kbps ({last})"


# --- Editing a deck file --------------------------------------------------------

def _drop_audio(lines: list[str], start: int, end: int) -> int:
    """Removes the card's `audio` and `audio_credit` lines (with any deeper
    lines) from lines[start:end]; returns how many lines went."""
    i, removed = start + 1, 0
    while i < end - removed:
        if re.match(r"^    audio(?:_credit)?:", lines[i]):
            j = i + 1
            while j < end - removed and len(lines[j]) - len(lines[j].lstrip(" ")) > 4:
                j += 1
            del lines[i:j]
            removed += j - i
        else:
            i += 1
    return removed


def edit_card(text: str, cid: str, audio: str, credit: dict[str, str]) -> str:
    """[text] with `audio` and `audio_credit` set on card [cid]: replaced if
    it has them, else added after its `ipa` (or the last of `phonetic_source`,
    `phonetic`, `reading`, `target` it has). Everything else is untouched."""
    head = re.compile(rf'^  - id: "?{re.escape(cid)}"?\s*$')
    lines = text.split("\n")
    found = iw._block(lines, head, 2)
    if found is None:
        raise iw.ImportError_(f"card {cid} is not in the file")
    start, end = found
    end -= _drop_audio(lines, start, end)
    after = next((k for k in ("phonetic_source", "phonetic", "ipa", "reading", "target")
                  if any(re.match(rf"^    {k}:", lines[i]) for i in range(start, end))), None)
    new = [f"    audio: {iw.q(audio)}",
           f"    audio_credit: {iw.flow_map(list(credit.items()))}"]
    at = iw._insert_at(lines, start, end, after)
    lines[at:at] = new
    return "\n".join(lines)


def read_back(before: str, after: str, cid: str, audio: str, credit: dict[str, str]) -> None:
    """Raises unless [after] parses, has [audio] and [credit] on card [cid],
    and is the same as [before] everywhere else."""
    old, new = yaml.safe_load(before), yaml.safe_load(after)
    def strip(doc: dict) -> dict:
        doc = json.loads(json.dumps(doc, default=str))
        for card in doc.get("cards") or []:
            if isinstance(card, dict) and card.get("id") == cid:
                got = (card.pop("audio", None), card.pop("audio_credit", None))
                doc["_got"] = got
        return doc
    old, new = strip(old), strip(new)
    if new.get("_got") != (audio, credit) and new.get("_got") != [audio, credit]:
        raise iw.ImportError_(f"card {cid}: the audio lines did not read back")
    new.pop("_got", None)
    old.pop("_got", None)
    if old != new:
        raise iw.ImportError_(f"card {cid}: the edit changed something else in the file")


# --- The report -----------------------------------------------------------------

@dataclass
class LangReport:
    lang: str
    cards: int = 0
    already: int = 0
    asked: int = 0
    available: int = 0              # survey and dry run: a usable recording exists
    fetched: int = 0
    missing: int = 0
    skipped_no_author: int = 0
    skipped_licence: int = 0
    over_size: int = 0
    errors: int = 0
    bytes: int = 0
    estimated_bytes: int = 0
    sources: Counter = field(default_factory=Counter)
    licences: Counter = field(default_factory=Counter)
    ids: dict[str, list[str]] = field(default_factory=dict)
    skipped_files: list[dict] = field(default_factory=list)
    # IPA symbols whose Commons titles were all tried and not found: the
    # first survey's list of `--symbols` fixes.
    symbols_not_found: dict[str, list[str]] = field(default_factory=dict)

    def note(self, kind: str, cid: str) -> None:
        self.ids.setdefault(kind, []).append(cid)


@dataclass
class Report:
    mode: str
    langs: dict[str, LangReport] = field(default_factory=dict)
    existing_bytes: int = 0         # audio in the decks before the run
    requests: dict[str, int] = field(default_factory=dict)
    stopped: str = ""
    error: str = ""

    def lang(self, code: str) -> LangReport:
        return self.langs.setdefault(code, LangReport(code))

    def total(self, attr: str) -> int:
        return sum(getattr(r, attr) for r in self.langs.values())

    def ceiling_share(self) -> float:
        added = self.total("bytes") if self.mode in ("write", "dry-run") else \
            self.total("estimated_bytes")
        return 100 * (self.existing_bytes + added) / vd.AUDIO_TOTAL_MAX_BYTES

    def to_json(self) -> dict:
        def one(r: LangReport) -> dict:
            return {"lang": r.lang, "cards": r.cards, "already": r.already,
                    "asked": r.asked, "available": r.available, "fetched": r.fetched,
                    "missing": r.missing, "skipped_no_author": r.skipped_no_author,
                    "skipped_licence": r.skipped_licence, "over_size": r.over_size,
                    "errors": r.errors, "bytes": r.bytes,
                    "estimated_bytes": r.estimated_bytes,
                    "sources": dict(sorted(r.sources.items())),
                    "licences": dict(sorted(r.licences.items())),
                    "ids": {k: v for k, v in sorted(r.ids.items())},
                    "skipped_files": r.skipped_files,
                    "symbols_not_found": r.symbols_not_found}
        return {"mode": self.mode, "stopped": self.stopped, "error": self.error, "requests": self.requests,
                "total": {k: self.total(k) for k in (
                    "cards", "already", "asked", "available", "fetched", "missing",
                    "skipped_no_author", "skipped_licence", "over_size", "errors",
                    "bytes", "estimated_bytes")},
                "existing_bytes": self.existing_bytes,
                "ceiling_bytes": vd.AUDIO_TOTAL_MAX_BYTES,
                "ceiling_share_percent": round(self.ceiling_share(), 2),
                "languages": [one(self.langs[c]) for c in sorted(self.langs)]}

    def to_markdown(self) -> str:
        survey = self.mode == "survey"
        lines = [f"# Sound audio fetch report ({self.mode})", ""]
        if self.stopped:
            lines += [f"**Stopped early:** {self.stopped}", ""]
        if self.error:
            lines += [f"**Error:** {self.error}", ""]
        gotcol = "available" if self.mode in ("survey",) else "fetched"
        lines += [f"| Language | Cards | Already | Asked | {gotcol.capitalize()} | Missing | "
                  f"No author | Licence | Over size | Errors | Bytes |",
                  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
        for c in sorted(self.langs):
            r = self.langs[c]
            got = r.available if survey else r.fetched
            size = r.estimated_bytes if survey else r.bytes
            lines.append(f"| {c} | {r.cards} | {r.already} | {r.asked} | {got} | {r.missing} | "
                         f"{r.skipped_no_author} | {r.skipped_licence} | {r.over_size} | "
                         f"{r.errors} | {size}{' (estimated)' if survey else ''} |")
        got = self.total("available") if survey else self.total("fetched")
        size = self.total("estimated_bytes") if survey else self.total("bytes")
        lines += ["", f"Total: {got} {gotcol}, {size} bytes"
                      f"{' (estimated)' if survey else ''}. Audio in the decks before the "
                      f"run: {self.existing_bytes} bytes. Share of the "
                      f"{vd.AUDIO_TOTAL_MAX_BYTES // 1048576} MB ceiling after: "
                      f"{self.ceiling_share():.1f}%.", ""]
        if self.requests:
            lines += ["Requests: " + ", ".join(f"{k} {v}" for k, v in
                                               sorted(self.requests.items())) + ".", ""]
        for c in sorted(self.langs):
            r = self.langs[c]
            lines += [f"## {c}", ""]
            if r.sources:
                lines.append("Sources: " + ", ".join(f"{k} {v}" for k, v in
                                                     sorted(r.sources.items())) + ".")
            if r.licences:
                lines.append("Licences seen: " + ", ".join(f"{k} {v}" for k, v in
                                                           sorted(r.licences.items())) + ".")
            for kind, ids in sorted(r.ids.items()):
                lines.append(f"- {kind}: {', '.join(ids)}")
            if r.symbols_not_found:
                lines.append("IPA symbol clips not found on Commons (titles tried; fix with "
                             "`--symbols FILE`):")
                lines += [f"  - {sym}: {', '.join(t)}"
                          for sym, t in sorted(r.symbols_not_found.items())]
            for s in r.skipped_files:
                lines.append(f"- skipped {s['card']} {s['file']}: {s['reason']}")
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"


# --- The run --------------------------------------------------------------------

def audio_bytes_in(decks: Path) -> int:
    return sum(f.stat().st_size for f in decks.glob("*/audio/*.opus") if f.is_file())


def load_symbols(path: Path | None) -> dict[str, tuple[str, ...]]:
    clips = dict(IPA_CLIPS)
    if path is not None:
        data = json.loads(path.read_text(encoding="utf-8"))
        for symbol, names in data.items():
            clips[nfc(symbol)] = tuple([names] if isinstance(names, str) else names)
    return clips


def letter_titles(card: SoundCard, files: list[str]) -> list[str]:
    """Of a pronunciation category's [files], the ones named for the card's
    letter: `File:ట-te.ogg`, `File:ta.ogg`; sorted by title."""
    wanted = {nfc(x).lower() for x in (card.target, card.reading) if x}
    hits = []
    for title in files:
        stem = nfc(title.split(":", 1)[-1]).rsplit(".", 1)[0].lower()
        if stem in wanted or re.split(r"[-_ ]", stem)[0] in wanted:
            hits.append(title)
    return sorted(hits)


def word_candidates(card: SoundCard, entries: dict[str, list[dict]]) -> list[str]:
    """The Commons titles of the Wiktionary recordings of the card's example
    words, from a kaikki.org dump's [entries], in order."""
    titles = []
    for word in card.examples:
        for entry in entries.get(nfc(word), []):
            for sound in entry.get("sounds", []):
                name = sound.get("audio")
                if isinstance(name, str) and name.lower().endswith(AUDIO_EXTENSIONS):
                    titles.append(name if name.startswith("File:") else f"File:{name}")
    return list(dict.fromkeys(titles))


def estimate_bytes(v: Verdict) -> int:
    if v.duration is None:
        return ESTIMATE_BYTES
    return min(vd.AUDIO_MAX_BYTES, round(v.duration * SURVEY_KBPS * 125) + 1000)


@dataclass
class Options:
    decks: Path
    langs: list[str] | None = None
    limit: int | None = None
    survey: bool = False
    dry_run: bool = False
    refresh: bool = False
    letters: bool = True
    example_words: bool = False
    dump: Path | None = None
    symbols: Path | None = None
    kbps: int = TARGET_KBPS


def run(client: wc.Client, opts: Options) -> Report:
    mode = "survey" if opts.survey else "dry-run" if opts.dry_run else "write"
    report = Report(mode)
    decks = opts.decks
    report.existing_bytes = audio_bytes_in(decks)
    available = languages_with_inventory(decks)
    codes = opts.langs if opts.langs else available
    for code in codes:
        if code not in available:
            raise iw.ImportError_(f"{code}: no {code}-sound-inventory deck under {decks}")
    clips = load_symbols(opts.symbols)
    entries: dict[str, list[dict]] = {}

    # 1. Which cards need audio.
    todo: list[SoundCard] = []
    for code in codes:
        lr = report.lang(code)
        for card in read_cards(decks, code):
            lr.cards += 1
            if not opts.refresh and card.audio is not None and audio_valid(decks, card):
                lr.already += 1
                continue
            if card.audio is not None and not opts.refresh:
                lr.note("invalid-existing-audio (kept; --refresh redoes it)", card.cid)
                lr.errors += 1
                continue
            todo.append(card)
    if opts.limit is not None:
        todo = todo[:opts.limit]
    if opts.example_words and opts.dump is not None and todo:
        wanted = {nfc(w) for c in todo for w in c.examples}
        entries, _ = iw.read_dump(opts.dump, wanted)
    for card in todo:
        report.lang(card.lang).asked += 1

    try:
        _fetch(client, opts, report, todo, clips, entries)
    except (wc.RateLimited, wc.RequestCapReached) as e:
        report.stopped = str(e)
    except wc.WikimediaError as e:
        report.error = str(e)
    report.requests = {"api": client.stats.api_requests,
                       "downloads": client.stats.download_requests,
                       "cache_hits": client.stats.cache_hits,
                       "retries": client.stats.retries}
    return report


def _fetch(client: wc.Client, opts: Options, report: Report, todo: list[SoundCard],
           clips: dict[str, tuple[str, ...]], entries: dict[str, list[dict]]) -> None:
    # 2. Every card's candidates, in source order, from the cards alone and the
    #    language's pronunciation category.
    names: dict[str, str] = {}
    for code in {c.lang for c in todo}:
        names[code] = _language_name(opts.decks, code)
    category: dict[str, list[str]] = {}
    plan: dict[str, list[tuple[str, str]]] = {}      # card id -> [(source, title)]
    for card in todo:
        cands = [("ipa-symbol", t) for t in symbol_titles(card.ipa, clips)]
        if opts.letters and names.get(card.lang):
            if card.lang not in category:
                category[card.lang] = client.category_files(
                    f"Category:{names[card.lang]} pronunciation")
            cands += [("letter", t) for t in letter_titles(card, category[card.lang])]
        if opts.example_words:
            cands += [("example-word", t) for t in word_candidates(card, entries)]
        plan[f"{card.lang}/{card.cid}"] = cands
    titles = list(dict.fromkeys(t for c in plan.values() for _, t in c))
    infos = client.imageinfo(titles)

    # 3. The first usable file of each card; then fetch and write.
    for card in todo:
        lr = report.lang(card.lang)
        chosen: Verdict | None = None
        source = ""
        worst = "missing"
        symbol_hit = False
        for src, title in plan[f"{card.lang}/{card.cid}"]:
            v = judge(title, infos.get(title))
            if v.status != "missing":
                lr.licences[v.licence or v.licence_name or "?"] += 1
                if src == "ipa-symbol":
                    symbol_hit = True
            if v.status == "ok":
                chosen, source = v, src
                break
            if v.status != "missing":
                lr.skipped_files.append({"card": card.cid, "file": title,
                                         "reason": REASONS[v.status].format(v.licence_name)})
                if RANK[v.status] > RANK[worst]:
                    worst = v.status
        tried = symbol_titles(card.ipa, clips)
        if tried and not symbol_hit:
            lr.symbols_not_found[nfc(card.ipa.strip().strip("/[]"))] = tried
        if chosen is None:
            if worst == "no-author":
                lr.skipped_no_author += 1
                lr.note("skipped-no-author", card.cid)
            elif worst == "licence":
                lr.skipped_licence += 1
                lr.note("skipped-licence", card.cid)
            elif worst == "over-size":
                lr.over_size += 1
                lr.note("over-size", card.cid)
            else:
                lr.missing += 1
                lr.note("missing" if worst == "missing" else "missing (wrong file type)",
                        card.cid)
            continue
        if opts.survey:
            lr.available += 1
            lr.sources[source] += 1
            lr.estimated_bytes += estimate_bytes(chosen)
            lr.note("available", card.cid)
            continue
        _write_card(client, opts, lr, card, chosen, source)


REASONS = {"licence": "licence {!r} cannot ship",
           "no-author": "no machine-readable author",
           "over-size": "source file too large (over 5 MB or 30 s)",
           "bad-type": "not an audio file type"}
RANK = {"missing": 0, "bad-type": 1, "over-size": 2, "licence": 3, "no-author": 4}


def _language_name(decks: Path, code: str) -> str:
    try:
        data = yaml.safe_load(inventory_file(decks, code).read_text(encoding="utf-8")) or {}
        name = (data.get("language") or {}).get("name")
        return name if isinstance(name, str) else ""
    except (OSError, yaml.YAMLError):
        return ""


def _write_card(client: wc.Client, opts: Options, lr: LangReport, card: SoundCard,
                v: Verdict, source: str) -> None:
    suffix = Path(v.title).suffix.lower() or ".ogg"
    try:
        raw = client.get_bytes(v.url)
    except (wc.RateLimited, wc.RequestCapReached):
        raise
    except wc.WikimediaError as e:
        lr.errors += 1
        lr.note(f"error: {e}", card.cid)
        return
    opus, why = encode_fitting(raw, suffix, opts.kbps)
    if opus is None:
        if why.startswith("over"):
            lr.over_size += 1
            lr.note("over-size", card.cid)
            lr.skipped_files.append({"card": card.cid, "file": v.title, "reason": why})
        else:
            lr.errors += 1
            lr.note(f"error: {why}", card.cid)
        return
    credit = {"source": v.page, "license": v.licence or "", "credit": v.credit}
    if opts.dry_run:
        lr.fetched += 1
        lr.bytes += len(opus)
        lr.sources[source] += 1
        lr.note("would-fetch", card.cid)
        return
    out = (opts.decks / card.lang / "audio" / f"{card.cid}.opus").resolve()
    audio_dir = (opts.decks / card.lang / "audio").resolve()
    if out.parent != audio_dir or card.path.resolve().parent != (opts.decks / card.lang).resolve():
        raise iw.ImportError_(f"{card.cid}: refusing to write outside the decks' audio folders")
    before = card.path.read_text(encoding="utf-8")
    try:
        after = edit_card(before, card.cid, card.audio_path, credit)
        read_back(before, after, card.cid, card.audio_path, credit)
    except (iw.ImportError_, yaml.YAMLError) as e:
        lr.errors += 1
        lr.note(f"error: {e}", card.cid)
        return
    audio_dir.mkdir(parents=True, exist_ok=True)
    out.write_bytes(opus)
    try:
        card.path.write_text(after, encoding="utf-8")
    except OSError:
        out.unlink(missing_ok=True)      # no file without its card line
        raise
    lr.fetched += 1
    lr.bytes += len(opus)
    lr.sources[source] += 1
    lr.note("fetched", card.cid)


# --- Command line ---------------------------------------------------------------

def main(argv: list[str], client: wc.Client | None = None) -> int:
    p = argparse.ArgumentParser(description="Fetch audio for the sound cards of the "
                                "<lang>-sound-inventory decks (ADR-0059).")
    p.add_argument("--decks", type=Path, default=ROOT / "decks")
    p.add_argument("--lang", action="append", help="a language code; repeat or comma-separate "
                   "(default: every language with a sound-inventory deck)")
    p.add_argument("--survey", action="store_true", help="read-only: what is available, "
                   "estimated bytes, licences, skips; downloads no audio, writes nothing")
    p.add_argument("--dry-run", action="store_true", help="download and encode, but write "
                   "nothing to the decks")
    p.add_argument("--limit", type=int, help="cards to ask for in this run")
    p.add_argument("--refresh", action="store_true", help="redo cards that already have audio")
    p.add_argument("--refresh-cache", action="store_true",
                   help="ignore the cache: ask Wikimedia again")
    p.add_argument("--cache", type=Path, default=wc.DEFAULT_CACHE)
    p.add_argument("--max-requests", type=int, default=400, help="hard cap of requests per run")
    p.add_argument("--api-interval", type=float, default=1.0)
    p.add_argument("--no-letters", action="store_true",
                   help="skip the language's pronunciation category")
    p.add_argument("--example-words", action="store_true", help="also try the Wiktionary "
                   "recording of the example word (needs --dump)")
    p.add_argument("--dump", type=Path, help="a kaikki.org JSONL extract, for --example-words")
    p.add_argument("--symbols", type=Path, help="JSON: IPA symbol to Commons file names")
    p.add_argument("--kbps", type=int, default=TARGET_KBPS)
    p.add_argument("--report", type=Path, help="write the Markdown report here")
    p.add_argument("--json", type=Path, help="write the JSON report here")
    try:
        args = p.parse_args(argv)
    except SystemExit as e:
        return 0 if e.code in (0, None) else 2
    if args.survey and args.dry_run:
        print("--survey and --dry-run do not go together", file=sys.stderr)
        return 2
    if not 6 <= args.kbps <= vd.AUDIO_MAX_KBPS or (args.limit is not None and args.limit < 0):
        print("--kbps is 6 to 128; --limit is not negative", file=sys.stderr)
        return 2
    if args.example_words and args.dump is None:
        print("--example-words needs --dump", file=sys.stderr)
        return 2
    langs = [c for item in args.lang or [] for c in item.split(",") if c] or None
    client = client or wc.Client(cache_dir=args.cache, refresh=args.refresh_cache,
                                 max_requests=args.max_requests,
                                 api_interval=args.api_interval)
    opts = Options(decks=args.decks, langs=langs, limit=args.limit, survey=args.survey,
                   dry_run=args.dry_run, refresh=args.refresh, letters=not args.no_letters,
                   example_words=args.example_words, dump=args.dump, symbols=args.symbols,
                   kbps=args.kbps)
    try:
        report = run(client, opts)
    except (iw.ImportError_, OSError, yaml.YAMLError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    text = report.to_markdown()
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    if args.json:
        args.json.write_text(json.dumps(report.to_json(), indent=2, ensure_ascii=False) + "\n",
                             encoding="utf-8")
    print(text)
    return 3 if report.stopped else 4 if report.error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
