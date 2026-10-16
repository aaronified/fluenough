#!/usr/bin/env python3
"""Split a single-file deck into a core and an English (or other native)
layer, as docs/DECK-FORMAT.md, "Splitting a deck", describes (#397, #498).

    python3 tools/split_deck.py decks/te/te-en-home.yaml
    python3 tools/split_deck.py decks/hi/hi-script.yaml decks/hi/hi-sounds.yaml
    python3 tools/split_deck.py --check decks/te/te-en-home.yaml

A vocab or grammar deck `decks/<lang>/<lang>-<native>-<name>.yaml` becomes
the core `decks/<lang>/<lang>-<name>.yaml` (`part: "core"`) and the layer
`decks/<lang>/<native>/<lang>-<native>-<name>.yaml` (`kind: "layer"`). A
script guide or sounds file, `decks/<lang>/<lang>-script.yaml` or
`<lang>-sounds.yaml`, keeps its path as the core, and its English text goes
to `decks/<lang>/en/<lang>-en-script.yaml` ("Script guides" and "Sounds
files" in DECK-FORMAT.md). The old file is deleted.

The split is mechanical. Every card id, entry key and slot stays as it is,
so every learner keeps their schedule:

- A card's word goes to the core, its meaning, `alt_native`, `wiktionary`
  and note texts to the layer. A ref stays a ref.
- A note written as text becomes a core note `{ id: "n1", kind: "note" }`
  and its text the layer's `"n1"`; a list of notes keeps its kinds, and a
  note without an id is given `n<place>`.
- A card's `pair`, which a core cannot give, becomes a pair note. Where the
  card has one text note that names the partner, that note becomes the pair
  note; otherwise a pair note is added, its text the partner's target,
  reading and meaning ("Not to be confused with ...").
- A base written in full keeps its word, base, reading and IPA in the core;
  its meaning and `wiktionary` go to the layer, keyed by its word.
- Every scalar is quoted. Comments at the top of the file, and those
  directly above a card, are kept in the core.

Reading decks are not split: they stay single-file (owner, 2026-10-14,
#498: "Keep reading decks single-file"). Paths, facts, numbers and
romanisation files stay single-file by design.

`--check` writes nothing: it splits in memory and reports whether merging
the two files back gives the old deck.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_decks import DeckLoader  # noqa: E402

# What a core card may give; the rest of a card is the layer's (DECK-FORMAT
# "A core").
CORE_CARD = ("id", "target", "reading", "ipa", "alt_target", "pos", "gender",
             "tags", "audio", "audio_credit", "examples", "modes", "picture",
             "image", "image_credit", "notes", "phrasebook", "bases", "rules",
             "proposed", "checked_by")
CORE_REF = ("ref", "reading", "ipa", "tags", "modes", "examples", "notes",
            "proposed", "checked_by")
LAYER_ENTRY = ("native", "alt_native", "wiktionary")
CORE_ENTRY = ("lemma", "key", "reading", "ipa", "forms", "readings", "ipas")

# Keys whose mapping's own keys are data (ids, words, slots), quoted.
_DATA_MAPS = {"notes", "examples", "bases", "forms", "readings", "ipas",
              "entries", "slots", "features", "contrasts"}
# Lists whose mapping items are written one to a line, in flow style.
_FLOW_ITEMS = {"bases", "notes", "authors", "words"}


class SplitError(Exception):
    pass


# --- Writing YAML in the decks' own style --------------------------------

def q(value: object) -> str:
    """A scalar, quoted where it is text."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    raise SplitError(f"cannot write {value!r} as a scalar")


def _key(key: object, quoted: bool) -> str:
    if quoted or not isinstance(key, str) or not re.fullmatch(r"[a-z_][a-z0-9_]*", key):
        return q(key)
    return key


def _scalar(v: object) -> bool:
    return v is None or isinstance(v, (str, bool, int, float))


def _flat(v: object) -> bool:
    if _scalar(v):
        return True
    if isinstance(v, list):
        return all(_flat(x) for x in v)
    if isinstance(v, dict):
        return all(_flat(x) for x in v.values())
    return False


def _flow(v: object, quoted: bool = False) -> str:
    if _scalar(v):
        return q(v)
    if isinstance(v, list):
        return "[" + ", ".join(_flow(x) for x in v) + "]"
    if not v:
        return "{}"
    return "{ " + ", ".join(f"{_key(k, quoted)}: {_flow(x)}" for k, x in v.items()) + " }"


def _emit(value: object, key: str, indent: int, out: list[str],
          comments: dict[str, list[str]] | None = None) -> None:
    """[value], the value of [key], written below it at [indent]."""
    pad = " " * indent
    if isinstance(value, dict):
        quoted = key in _DATA_MAPS or key == "cards"
        for k, v in value.items():
            _line(k, v, quoted, indent, out)
        return
    for item in value:
        if isinstance(item, dict) and comments is not None:
            cid = item.get("id", item.get("ref"))
            for c in comments.get(cid, []):
                out.append(c)
        if isinstance(item, dict) and item and not (key in _FLOW_ITEMS and _flat(item)):
            first = True
            for k, v in item.items():
                sub: list[str] = []
                _line(k, v, False, indent + 2, sub)
                if first:
                    sub[0] = pad + "- " + sub[0][indent + 2:]
                    first = False
                out.extend(sub)
        else:
            out.append(f"{pad}- {_flow(item)}")


def _line(k: object, v: object, quoted: bool, indent: int, out: list[str]) -> None:
    pad = " " * indent
    name = _key(k, quoted)
    flow_list = isinstance(v, list) and all(_scalar(x) or (isinstance(x, list) and _flat(x))
                                            for x in v)
    if _scalar(v) or flow_list or (isinstance(v, dict) and k in ("language", "native")
                                   and _flat(v)) or v == {} or v == []:
        out.append(f"{pad}{name}: {_flow(v)}")
        return
    out.append(f"{pad}{name}:")
    _emit(v, k if isinstance(k, str) else "", indent + 2, out)


def render(doc: dict, header: list[str] | None = None,
           comments: dict[str, list[str]] | None = None) -> str:
    out = list(header or [])
    for k, v in doc.items():
        if k == "cards" and isinstance(v, list):
            out.append("cards:")
            _emit(v, "cards", 2, out, comments)
        else:
            _line(k, v, False, 0, out)
    return "\n".join(out) + "\n"


def _comments(text: str) -> tuple[list[str], dict[str, list[str]]]:
    """The comment lines at the top of [text], and those directly above each
    card, by the card's id."""
    lines = text.splitlines()
    header: list[str] = []
    i = 0
    while i < len(lines) and lines[i].startswith("#"):
        header.append(lines[i])
        i += 1
    above: dict[str, list[str]] = {}
    pending: list[str] = []
    for line in lines[i:]:
        stripped = line.strip()
        if stripped.startswith("#"):
            pending.append(line.rstrip())
            continue
        m = re.match(r"\s*-\s+(?:id|ref):\s*[\"']?([A-Za-z0-9-]+)", line)
        if m and pending:
            above[m.group(1)] = pending
        if stripped:
            pending = []
    return header, above


# --- Splitting ------------------------------------------------------------

def _nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def _split_notes(notes: object, where: str) -> tuple[list[dict], dict[str, str]]:
    """A single-file card's notes as core notes and the layer's texts."""
    if notes is None or (isinstance(notes, str) and not notes.strip()):
        return [], {}
    if isinstance(notes, str):
        return [{"id": "n1", "kind": "note"}], {"n1": notes}
    if not isinstance(notes, list):
        raise SplitError(f"{where}: notes must be text or a list")
    core, texts = [], {}
    for i, note in enumerate(notes, 1):
        if not isinstance(note, dict):
            raise SplitError(f"{where}: note {i} is not a mapping")
        nid = note.get("id") or f"n{i}"
        entry = {"id": nid}
        entry.update({k: v for k, v in note.items() if k not in ("id", "text")})
        core.append(entry)
        if "text" in note:
            texts[nid] = note["text"]
    return core, texts


def _split_bases(bases: list, where: str) -> tuple[list[dict], dict]:
    core, layer = [], {}
    for b in bases:
        if not isinstance(b, dict):
            raise SplitError(f"{where}: a base is not a mapping")
        core.append({k: v for k, v in b.items() if k not in ("meaning", "wiktionary")})
        if "meaning" in b or "wiktionary" in b:
            key = _nfc(b["word"])
            if "wiktionary" in b:
                layer[key] = {k: b[k] for k in ("meaning", "wiktionary") if k in b}
            else:
                layer[key] = b["meaning"]
    return core, layer


def _split_examples(examples: list, where: str) -> tuple[list[dict], dict]:
    core, layer = [], {}
    for e in examples:
        if not isinstance(e, dict) or "target" not in e:
            raise SplitError(f"{where}: an example needs a target")
        entry = {k: v for k, v in e.items() if k not in ("native", "bases")}
        trans: object = e.get("native")
        if "bases" in e:
            cb, lb = _split_bases(e["bases"], where)
            entry["bases"] = cb
            if lb:
                trans = {"native": e.get("native"), "bases": lb}
        entry["target"] = _nfc(e["target"])
        core.append(entry)
        if trans is not None:
            layer[_nfc(e["target"])] = trans
    return core, layer


def _with_pair(card: dict, notes: list[dict], texts: dict[str, str],
               cards_by_id: dict[str, dict]) -> None:
    """A card's `pair` as a pair note (a core has no `pair`)."""
    partner = card["pair"]
    if any(n.get("kind") == "pair" and n.get("ref") == partner for n in notes):
        return
    other = cards_by_id.get(partner)
    if other is None:
        raise SplitError(f"{card.get('id')}: its pair {partner} is not a card of the "
                         f"language; write its pair note by hand")
    text_notes = [n for n in notes if n.get("kind") == "note"]
    if (len(text_notes) == 1 and isinstance(other.get("target"), str)
            and other["target"] in texts.get(text_notes[0]["id"], "")):
        text_notes[0]["kind"] = "pair"
        text_notes[0]["ref"] = partner
        return
    reading = f" ({other['reading']})" if _is_text(other.get("reading")) else ""
    meaning = f", {other['native']}" if _is_text(other.get("native")) else ""
    notes.append({"id": "pair", "kind": "pair", "ref": partner})
    texts["pair"] = f"Not to be confused with {other['target']}{reading}{meaning}."


def _is_text(v: object) -> bool:
    return isinstance(v, str) and bool(v.strip())


def core_id_of(deck_id: str, lang: str, native: str) -> str:
    prefix = f"{lang}-{native}-"
    if not deck_id.startswith(prefix):
        raise SplitError(f"{deck_id}: a single-file deck taught from {native} has an id "
                         f"starting {prefix}")
    return f"{lang}-{deck_id[len(prefix):]}"


def split_deck(raw: dict, cards_by_id: dict[str, dict] | None = None
               ) -> tuple[dict, dict]:
    """A single-file vocab or grammar deck as (core, layer)."""
    kind = raw.get("kind", "vocab")
    if kind == "reading":
        raise SplitError(f"{raw.get('id')}: a reading deck stays single-file "
                         f"(DECK-FORMAT.md, Core and layer files)")
    if kind not in ("vocab", "grammar"):
        raise SplitError(f"{raw.get('id')}: cannot split a {kind!r} file")
    if "part" in raw:
        raise SplitError(f"{raw.get('id')}: already a core")
    lang, native = raw["language"]["code"], raw["native"]["code"]
    deck_id = raw["id"]
    cid = core_id_of(deck_id, lang, native)
    core: dict = {"schema": raw["schema"], "id": cid, "part": "core", "kind": kind,
                  "language": raw["language"], "license": raw["license"]}
    layer: dict = {"schema": raw["schema"], "id": deck_id, "kind": "layer", "core": cid,
                   "native": raw["native"], "name": raw["name"]}
    for k in ("authors", "source"):
        if k in raw:
            core[k] = raw[k]
    if "theme" in raw:
        core["theme"] = raw["theme"]
    if "description" in raw:
        layer["description"] = raw["description"]
    layer["license"] = raw["license"]
    if "tags" in raw:
        core["tags"] = list(raw["tags"])
        layer["tags"] = list(raw["tags"])
    unknown = set(raw) - {"schema", "id", "name", "kind", "language", "native", "license",
                          "description", "tags", "authors", "source", "theme", "cards",
                          "pattern"}
    if unknown:
        raise SplitError(f"{deck_id}: unknown fields {sorted(unknown)}")

    if kind == "grammar":
        p = raw["pattern"]
        core["pattern"] = {"slots": p["slots"], "entries": [
            {k: e[k] for k in CORE_ENTRY if k in e} for e in p["entries"]]}
        for e in p["entries"]:
            extra = set(e) - set(CORE_ENTRY) - {"gloss"}
            if extra:
                raise SplitError(f"{deck_id}: entry {e.get('lemma')}: unknown {sorted(extra)}")
        lp: dict = {k: p[k] for k in ("name", "slot_name", "prompt") if k in p}
        lp["entries"] = {(e.get("key") or e["lemma"]): e["gloss"] for e in p["entries"]}
        if "notes" in p:
            lp["notes"] = p["notes"]
        extra = set(p) - {"name", "slot_name", "prompt", "notes", "slots", "entries"}
        if extra:
            raise SplitError(f"{deck_id}: pattern: unknown {sorted(extra)}")
        layer["pattern"] = lp
        return core, layer

    by_id = dict(cards_by_id or {})
    for c in raw.get("cards") or []:
        if "id" in c:
            by_id.setdefault(c["id"], c)
    core_cards, layer_cards = [], {}
    for c in raw.get("cards") or []:
        is_ref = "ref" in c
        key = c["ref"] if is_ref else c["id"]
        where = f"{deck_id}: {key}"
        allowed = CORE_REF if is_ref else CORE_CARD
        extra = set(c) - set(allowed) - set(LAYER_ENTRY) - {"pair"}
        if extra:
            raise SplitError(f"{where}: cannot split {sorted(extra)}")
        if is_ref and "pair" in c:
            raise SplitError(f"{where}: a ref gives no pair")
        entry: dict = {}
        cc: dict = {}
        notes, texts = _split_notes(c.get("notes"), where)
        if "pair" in c:
            _with_pair(c, notes, texts, by_id)
        for k in allowed:
            if k not in c:
                continue
            if k == "notes":
                if notes:
                    cc["notes"] = notes
            elif k == "bases":
                cb, lb = _split_bases(c["bases"], where)
                cc["bases"] = cb
            elif k == "examples":
                ce, le = _split_examples(c["examples"], where)
                cc["examples"] = ce
            else:
                cc[k] = c[k]
        if "notes" not in c and notes:
            cc["notes"] = notes
        # The layer entry, in the order DECK-FORMAT writes it.
        for k in ("native", "alt_native", "wiktionary"):
            if k in c:
                entry[k] = c[k]
        if texts:
            entry["notes"] = texts
        if "examples" in c:
            _, le = _split_examples(c["examples"], where)
            if le:
                entry["examples"] = le
        if "bases" in c:
            _, lb = _split_bases(c["bases"], where)
            if lb:
                entry["bases"] = lb
        core_cards.append(cc)
        if entry:
            if key in layer_cards:
                raise SplitError(f"{where}: listed twice")
            layer_cards[key] = entry
    core["cards"] = core_cards
    layer["cards"] = layer_cards
    return core, layer


def split_guide(raw: dict, native: dict) -> tuple[dict, dict]:
    """A script guide or sounds file as (core, layer)."""
    kind = raw.get("kind")
    lang = raw["language"]
    ncode = native["code"]
    if "part" in raw:
        raise SplitError(f"{raw.get('id')}: already a core")
    core: dict = {"schema": raw["schema"], "kind": kind, "part": "core",
                  "id": raw["id"], "language": lang}
    layer: dict = {"schema": raw["schema"], "id": f"{lang}-{ncode}-{kind}",
                   "kind": "layer", "core": raw["id"], "native": native}
    if kind == "script":
        extra = set(raw) - {"schema", "kind", "id", "language", "name", "intro", "features"}
        if extra:
            raise SplitError(f"{raw['id']}: unknown {sorted(extra)}")
        layer["name"] = raw["name"]
        layer["intro"] = raw["intro"]
        core["features"] = [{k: v for k, v in f.items() if k not in ("name", "text")}
                            for f in raw["features"]]
        layer["features"] = {f["id"]: {"name": f["name"], "text": f["text"]}
                             for f in raw["features"]}
    elif kind == "sounds":
        extra = set(raw) - {"schema", "kind", "id", "language", "description", "contrasts"}
        if extra:
            raise SplitError(f"{raw['id']}: unknown {sorted(extra)}")
        if "description" in raw:
            layer["description"] = raw["description"]
        core["contrasts"] = [{k: v for k, v in c.items() if k != "name"}
                             for c in raw["contrasts"]]
        layer["contrasts"] = {c["id"]: c["name"] for c in raw["contrasts"]}
    else:
        raise SplitError(f"{raw.get('id')}: not a script guide or sounds file")
    return core, layer


# --- Merging back, to check a split -----------------------------------------

def merge_guide(core: dict, layer: dict) -> dict:
    """A script guide or sounds core and its layer as the single file."""
    out = {"schema": core["schema"], "kind": core["kind"], "id": core["id"],
           "language": core["language"]}
    if core["kind"] == "script":
        out["name"], out["intro"] = layer["name"], layer["intro"]
        out["features"] = []
        for f in core["features"]:
            texts = layer["features"][f["id"]]
            merged = {"id": f["id"], "name": texts["name"]}
            merged.update({k: v for k, v in f.items() if k != "id"})
            merged["text"] = texts["text"]
            out["features"].append(merged)
    else:
        if "description" in layer:
            out["description"] = layer["description"]
        out["contrasts"] = [{"id": c["id"], "name": layer["contrasts"][c["id"]],
                             **{k: v for k, v in c.items() if k != "id"}}
                            for c in core["contrasts"]]
    return out


def _canonical_guide(raw: dict) -> object:
    return json.loads(json.dumps(raw, sort_keys=True))


def check_guide(raw: dict, core: dict, layer: dict) -> list[str]:
    merged = merge_guide(core, layer)
    if _canonical_guide(merged) != _canonical_guide(raw):
        return [f"{raw['id']}: merging the core and layer does not give the file back"]
    return []


def check_deck(raw: dict, core: dict, layer: dict) -> list[str]:
    """What the split loses: every card id, word and text of [raw] must be
    in [core] and [layer]."""
    problems = []
    lcards = layer.get("cards") or {}
    if raw.get("kind") == "grammar":
        p, cp, lp = raw["pattern"], core["pattern"], layer["pattern"]
        if cp["slots"] != p["slots"]:
            problems.append("slots changed")
        for e, ce in zip(p["entries"], cp["entries"]):
            if {k: e[k] for k in e if k != "gloss"} != ce:
                problems.append(f"entry {e.get('key')} changed")
            if lp["entries"][e.get("key") or e["lemma"]] != e["gloss"]:
                problems.append(f"gloss of {e.get('key')} changed")
        if len(p["entries"]) != len(cp["entries"]):
            problems.append("entries lost")
        for k in ("name", "slot_name", "prompt", "notes"):
            if p.get(k) != lp.get(k):
                problems.append(f"pattern {k} changed")
        return problems
    ccards = core.get("cards") or []
    if len(ccards) != len(raw.get("cards") or []):
        problems.append("cards lost")
    for c, cc in zip(raw.get("cards") or [], ccards):
        key = c.get("id", c.get("ref"))
        if cc.get("id", cc.get("ref")) != key:
            problems.append(f"{key}: id changed")
            continue
        entry = lcards.get(key, {})
        for k, v in c.items():
            if k in ("notes", "pair", "bases", "examples"):
                continue
            got = entry.get(k) if k in LAYER_ENTRY else cc.get(k)
            if got != v:
                problems.append(f"{key}: {k} changed")
        texts = entry.get("notes", {})
        old = c.get("notes")
        old_texts = ([old] if isinstance(old, str) and old.strip() else
                     [n.get("text") for n in old] if isinstance(old, list) else [])
        new_texts = [texts.get(n["id"]) for n in cc.get("notes", [])]
        if [t for t in old_texts if t] != [t for t in new_texts
                                           if t and t in old_texts]:
            problems.append(f"{key}: a note text changed")
        if "pair" in c and not any(n.get("kind") == "pair" and n.get("ref") == c["pair"]
                                   and texts.get(n["id"])
                                   for n in cc.get("notes", [])):
            problems.append(f"{key}: pair lost")
        for b, cb in zip(c.get("bases") or [], cc.get("bases") or []):
            if {k: v for k, v in b.items() if k not in ("meaning", "wiktionary")} != cb:
                problems.append(f"{key}: base {b.get('word')} changed")
            if "meaning" in b:
                got = entry.get("bases", {}).get(_nfc(b["word"]))
                got = got.get("meaning") if isinstance(got, dict) else got
                if got != b["meaning"]:
                    problems.append(f"{key}: base meaning {b.get('word')} changed")
    return problems


# --- Files ------------------------------------------------------------------

ENGLISH = {"code": "en", "iso639_3": "eng", "name": "English"}


def _load(path: Path) -> dict:
    raw = yaml.load(path.read_text(encoding="utf-8"), Loader=DeckLoader)
    if not isinstance(raw, dict):
        raise SplitError(f"{path}: not a mapping")
    return raw


_CARDS: dict[Path, dict[str, dict]] = {}


def _language_cards(folder: Path) -> dict[str, dict]:
    """The cards the decks in [folder] write, single-file decks and cores,
    by id, so that a `pair` across decks finds its partner."""
    if folder in _CARDS:
        return _CARDS[folder]
    found: dict[str, dict] = {}
    for p in sorted(folder.glob("*.yaml")):
        try:
            raw = _load(p)
        except (SplitError, yaml.YAMLError):
            continue
        if raw.get("kind") not in (None, "vocab"):
            continue
        for c in raw.get("cards") or []:
            if isinstance(c, dict) and "id" in c:
                found.setdefault(c["id"], dict(c))
    # A core's card takes its meaning from its English layer.
    for p in sorted((folder / "en").glob("*.yaml")):
        try:
            raw = _load(p)
        except (SplitError, yaml.YAMLError):
            continue
        cards = raw.get("cards") if raw.get("kind") == "layer" else None
        for cid, entry in (cards.items() if isinstance(cards, dict) else []):
            if cid in found and isinstance(entry, dict) and "native" in entry:
                found[cid].setdefault("native", entry["native"])
    _CARDS[folder] = found
    return found


def plan(path: Path) -> tuple[Path, str, Path, str, list[str]]:
    """What splitting [path] writes: (core path, core text, layer path,
    layer text, problems found merging them back)."""
    text = path.read_text(encoding="utf-8")
    raw = _load(path)
    header, above = _comments(text)
    folder = path.parent
    if raw.get("kind") in ("script", "sounds"):
        core, layer = split_guide(raw, ENGLISH)
        core_path = folder / f"{core['id']}.yaml"
        layer_path = folder / "en" / f"{layer['id']}.yaml"
        problems = check_guide(raw, core, layer)
    else:
        needs_pairs = any(isinstance(c, dict) and "pair" in c for c in raw.get("cards") or [])
        core, layer = split_deck(raw, _language_cards(folder) if needs_pairs else None)
        core_path = folder / f"{core['id']}.yaml"
        layer_path = folder / raw["native"]["code"] / f"{raw['id']}.yaml"
        problems = check_deck(raw, core, layer)
        if core_path.exists() and core_path != path:
            problems.append(f"{core_path} already exists")
    core_text = render(core, header, above)
    layer_text = render(layer)
    # What is written must read back as what was split.
    if yaml.load(core_text, Loader=DeckLoader) != core:
        problems.append("the core does not read back as written")
    if yaml.load(layer_text, Loader=DeckLoader) != layer:
        problems.append("the layer does not read back as written")
    return core_path, core_text, layer_path, layer_text, problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="+", type=Path)
    ap.add_argument("--check", action="store_true",
                    help="split in memory only, and report what the split would lose")
    args = ap.parse_args(argv)
    status = 0
    for path in args.files:
        try:
            core_path, core_text, layer_path, layer_text, problems = plan(path)
        except (SplitError, KeyError, yaml.YAMLError) as exc:
            print(f"{path}: not split: {exc}", file=sys.stderr)
            status = 1
            continue
        if problems:
            for p in problems:
                print(f"{path}: {p}", file=sys.stderr)
            status = 1
            continue
        if args.check:
            print(f"{path}: splits into {core_path} and {layer_path}")
            continue
        layer_path.parent.mkdir(parents=True, exist_ok=True)
        if core_path != path:
            path.unlink()
        core_path.write_text(core_text, encoding="utf-8")
        layer_path.write_text(layer_text, encoding="utf-8")
        print(f"{path} -> {core_path} + {layer_path}")
    return status


if __name__ == "__main__":
    sys.exit(main())
