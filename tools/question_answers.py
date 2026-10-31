#!/usr/bin/env python3
"""The daily questions' answers, counted, and what two agreeing answers do
(#519). Used by the review bot (`tools/review_bot.py`) on a fresh checkout
of `main`.

The app writes short questions from card data and sends the answers by mail,
one file per language, `fluenough-questions` (lib/core/review/
questions_file.dart). A question is about one data point of one card, named
`<card>|<point>`; the point is `meaning`, `example:<8 hex>`,
`confusable:<item id>`, `sound` or `image:<File>` (the answer pins the file).

The answers are kept in `review-answers/<language>.json`, one entry a data
point:

    {
     "version": 1,
     "points": {
      "te-0001|meaning": {
       "kind": "meaning",
       "answers": {"FL-7K3M-Q9TD-6": {"answer": "yes"}},
       "settled": "yes"
      }
     }
    }

A rater code has one answer to a point; answering again before it is
settled replaces it.

**Yes answers settle by agreement** (owner, 2026-10-13): the other reviewers
needed (REVIEW_AGREEMENTS_NEEDED, 1 unless the owner sets it) plus the
first, so by default two. The same "yes" from that many rater codes settles
the point as right (`settled: "yes"`). A settled point never changes again.
Settled right, the point is also listed in the card's `verified` (see
WRITE_VERIFIED) so the app stops asking about it and the generator skips it.

**A "no" opens a pull request; the second answer merges or closes it**
(owner, 2026-10-30: "1st review opens PR. Second review either merges or
closes it."). The first answer that is not a "yes" (a "no", or a "flag" on a
recording) marks the point `flag: {"by": <rater code>}`. The review bot
(`Bot.sweep_flags`) then opens one pull request for the point, kept open:

- the second reviewer's answer decides it, as the existing proposal flow's
  agreement does. The same "no" or "flag" from REVIEW_AGREEMENTS_NEEDED other
  rater codes merges it: the point is `settled: "no"`. A "yes" from any
  other code closes it, and that is final (`settled: "closed"`): nothing is
  asked about the point again, and a disagreement is not sent to a third
  reviewer;
- what merging does: for a recording (`sound`), the card's `audio` and
  `audio_credit` are taken out of the deck and the file with them (the
  validator refuses a recording no card plays), so the card uses
  text-to-speech until a new recording exists. Every other point has no
  proposal that could be written: an answer is a plain "no" with no
  replacement text, and the proposal model (ADR-0038) changes a field only
  to a text, never blanks one. So its pull request is a flag note: its only
  change is the record, `settled: "no"`, and the body names the card and the
  point for the owner to act on.

Never kept: what a reviewer wrote in `why`, which stays in the mail, and
mail addresses. Only rater codes, card ids, points, answers and reasons.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
from rater_codes import rater_code  # noqa: E402

# Whether the bot writes a settled-right point into the card's `verified`
# (docs/DECK-FORMAT.md). False until a released app reads the field: a
# released app refuses an unknown card key, and learners keep the decks they
# have rather than take a batch with a file that fails (ADR-0037), so decks
# carry `verified` only a release after the app that reads it ships (owner,
# 2026-10-30). Until it is True the tally in `review-answers/` is the only
# record and the app asks everything once, as before.
WRITE_VERIFIED = False

DIR = "review-answers"
FORMAT = "fluenough-questions"
VERSION = 1

# What each kind may be answered, and why. The reasons are the keys the app
# offers (lib/core/review/review_question.dart); a reason the kind does not
# know is dropped, the answer kept.
ANSWERS = {
    "meaning": ("yes", "no"),
    "example": ("yes", "no"),
    "confusable": ("yes", "no"),
    "sound": ("yes", "flag"),
    "image": ("yes", "no"),
}
REASONS = {
    "meaning": ("wrong", "awkward"),
    "example": ("unnatural", "wrong"),
    "confusable": ("not_real", "wrong_word"),
    "sound": ("noisy", "wrong_word", "not_native"),
    "image": ("not_the_word", "unclear", "not_fit"),
}
POINTS = {
    "meaning": re.compile(r"^meaning$"),
    "example": re.compile(r"^example:[0-9a-f]{8}$"),
    "confusable": re.compile(r"^confusable:[A-Za-z0-9_.-]{1,64}$"),
    "sound": re.compile(r"^sound$"),
    # A Commons file name: no spaces, slashes or pipes.
    "image": re.compile(r"^image:[^\s|/\\]{1,200}$"),
}
CARD = re.compile(r"^[a-z]{2,3}-[0-9]{4,}$")


@dataclass(frozen=True)
class Answer:
    lang: str
    card: str
    point: str
    kind: str
    answer: str
    reason: str = ""

    @property
    def key(self) -> str:
        return f"{self.card}|{self.point}"


@dataclass
class Batch:
    """What a mail's questions files say, by one rater code."""
    answers: list[Answer] = field(default_factory=list)
    # Answers dropped for a card, point, kind or answer that cannot be right,
    # and files dropped for a language that is not a language code.
    dropped: int = 0


def read_questions(files: list[dict], code: str) -> Batch:
    """The answers of [files], the questions files of one mail, all by
    [code]. What does not read as an answer is counted, never guessed at."""
    out = Batch()
    for f in files:
        lang = f.get("language")
        if not isinstance(lang, str) or rater_code(f.get("rater_code")) != code:
            continue
        # The language names a folder: anything but a language code could
        # reach another path.
        if not pr.vd.LANG_RE.fullmatch(lang):
            out.dropped += 1
            continue
        items = f.get("answers") if isinstance(f.get("answers"), list) else []
        for a in items:
            if not isinstance(a, dict):
                out.dropped += 1
                continue
            card, point, kind, answer = (a.get(k) for k in ("card", "point", "kind", "answer"))
            if not (isinstance(card, str) and isinstance(point, str)
                    and isinstance(kind, str) and isinstance(answer, str)
                    and CARD.fullmatch(card) and card.startswith(f"{lang}-")
                    and kind in ANSWERS and answer in ANSWERS[kind]
                    and POINTS[kind].fullmatch(point)):
                out.dropped += 1
                continue
            reason = a.get("reason")
            out.answers.append(Answer(
                lang, card, point, kind, answer,
                reason if isinstance(reason, str) and reason in REASONS[kind] else ""))
    return out


# --- The record --------------------------------------------------------------

def path_of(root: Path, lang: str) -> Path:
    return root / DIR / f"{lang}.json"


def load(root: Path, lang: str) -> dict:
    """[lang]'s record, empty when there is none or it cannot be read."""
    try:
        data = json.loads(path_of(root, lang).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    points = data.get("points") if isinstance(data, dict) else None
    return {"version": VERSION, "points": points if isinstance(points, dict) else {}}


def save(root: Path, lang: str, data: dict) -> None:
    path = path_of(root, lang)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True)
                    + "\n", encoding="utf-8")


def yes_count(point: dict) -> int:
    """How many rater codes answered "yes" to [point]."""
    return sum(1 for given in point.get("answers", {}).values()
               if isinstance(given, dict) and given.get("answer") == "yes")


def flagger(point: dict) -> str:
    """The rater code whose answer opened [point]'s pull request, "" when
    it has none."""
    flag = point.get("flag")
    by = flag.get("by") if isinstance(flag, dict) else None
    return by if isinstance(by, str) else ""


def flag_state(point: dict, needed: int) -> str:
    """What the answers say of a flagged point: "close" when another code
    said "yes", "merge" when [needed] other codes said the same "no" or
    "flag" (as many as the proposal flow's agreement), else "open"."""
    first = flagger(point)
    others = [g.get("answer") for code, g in point.get("answers", {}).items()
              if code != first and isinstance(g, dict)]
    if "yes" in others:
        return "close"
    return "merge" if len(others) >= needed else "open"


def flag_branch(lang: str, key: str) -> str:
    """The branch of the pull request of the flagged point [key]."""
    card, _, point = key.partition("|")
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:10]
    kind = point.split(":", 1)[0]
    return f"review-bot/flag/{lang}-{card}-{kind}-{digest}"


@dataclass
class Counted:
    """What recording a mail's answers did."""
    # (lang, card, point) newly recorded or changed.
    recorded: list[tuple[str, str, str]] = field(default_factory=list)
    # Answers to a point already settled, or by a code that already gave
    # that answer.
    ignored: int = 0
    # Answers about a card the language does not have.
    missing: int = 0
    # (lang, card, point) points two agreeing "yes" answers settled right.
    settled: list[tuple[str, str, str]] = field(default_factory=list)
    # Points that now have a pull request to open (a first "no"), and those
    # a "yes" closed (a second reviewer disagreed).
    flagged: list[tuple[str, str, str]] = field(default_factory=list)
    closed: list[tuple[str, str, str]] = field(default_factory=list)
    # Cards given `verified` lines (only while WRITE_VERIFIED), and those
    # that cannot be edited a line at a time, left for the owner.
    verified: list[str] = field(default_factory=list)
    unsupported: list[str] = field(default_factory=list)
    touched: set[str] = field(default_factory=set)

    @property
    def changed(self) -> bool:
        return bool(self.recorded or self.verified)


def record(root: Path, batch: Batch, code: str, agreements: int,
           result: Counted | None = None) -> Counted:
    """Writes [batch], by [code], into the records of `root`. A point of
    [agreements] plus one agreeing "yes" answers is settled right; a first
    answer that is not a "yes" flags the point for a pull request of its
    own (Bot.sweep_flags); a "yes" from another code closes a flagged
    point. Settled-right points are written to the cards' `verified` when
    WRITE_VERIFIED."""
    result = result or Counted()
    needed = agreements + 1
    records: dict[str, dict] = {}
    right: dict[tuple[str, str], list[str]] = {}
    for a in batch.answers:
        if not pr.card_exists(root, a.lang, a.card):
            result.missing += 1
            continue
        data = records.setdefault(a.lang, load(root, a.lang))
        point = data["points"].setdefault(a.key, {"kind": a.kind, "answers": {}})
        if point.get("settled"):
            result.ignored += 1
            continue
        given = {"answer": a.answer, **({"reason": a.reason} if a.reason else {})}
        if point["answers"].get(code) == given:
            result.ignored += 1
            continue
        point["answers"][code] = given
        result.recorded.append((a.lang, a.card, a.point))
        result.touched.add(a.lang)
        where = (a.lang, a.card, a.point)
        if a.answer == "yes" and flagger(point):
            if flagger(point) == code:
                # The one who flagged it took it back.
                del point["flag"]
            else:
                point["settled"] = "closed"
                result.closed.append(where)
                continue
        if a.answer == "yes":
            if not flagger(point) and yes_count(point) >= needed:
                point["settled"] = "yes"
                result.settled.append(where)
                right.setdefault((a.lang, a.card), []).append(a.point)
            continue
        if not flagger(point):
            point["flag"] = {"by": code}
            result.flagged.append(where)
    for lang, data in records.items():
        for key, point in data["points"].items():
            # A flag taken back leaves another code's "no" to open it.
            if point.get("settled") or flagger(point):
                continue
            first = next((c for c, g in point.get("answers", {}).items()
                          if isinstance(g, dict) and g.get("answer") != "yes"), None)
            if first:
                point["flag"] = {"by": first}
                card, _, pt = key.partition("|")
                result.flagged.append((lang, card, pt))
    if WRITE_VERIFIED:
        for (lang, card), points in right.items():
            outcome = pr.settle_points(root, lang, card, points)
            if outcome == "written":
                result.verified.append(card)
            elif outcome == "unsupported":
                result.unsupported.append(card)
    for lang, data in records.items():
        save(root, lang, data)
    return result


def flagged_points(root: Path) -> list[tuple[str, str, dict]]:
    """Every point of `main` with a pull request to open or decide:
    (language, key, point), flagged and not settled, in file order."""
    out = []
    directory = root / DIR
    for path in sorted(directory.glob("*.json")) if directory.is_dir() else []:
        lang = path.stem
        if not pr.vd.LANG_RE.fullmatch(lang):
            continue
        for key, point in load(root, lang)["points"].items():
            if isinstance(point, dict) and flagger(point) and not point.get("settled"):
                out.append((lang, key, point))
    return out


def settle_no(root: Path, lang: str, key: str) -> str:
    """What the pull request of the flagged point [key] changes: the point
    is `settled: "no"`, and for a recording the card's `audio` and
    `audio_credit` go, and the file. Returns "removed" when a recording
    was taken off, "noted" for a flag note (the record alone), "unsupported"
    for a recording on a card that cannot be edited a line at a time (the
    note is still written), "" when there is nothing to settle."""
    data = load(root, lang)
    point = data["points"].get(key)
    if not isinstance(point, dict) or point.get("settled") or not flagger(point):
        return ""
    card, _, name = key.partition("|")
    point["settled"] = "no"
    outcome = "noted"
    if point.get("kind") == "sound":
        outcome = pr.remove_fields(root, lang, card, ("audio", "audio_credit"))
        if outcome == "removed":
            # The validator refuses a recording no card plays, so the file
            # goes with the line that named it.
            (root / "decks" / lang / "audio" / f"{card}.opus").unlink(missing_ok=True)
        elif outcome == "none":
            outcome = "noted"
    save(root, lang, data)
    return outcome
