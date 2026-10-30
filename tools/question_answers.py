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
settled replaces it. **A data point is settled by agreeing answers** (owner,
2026-10-13): the other reviewers needed (REVIEW_AGREEMENTS_NEEDED, 1 unless
the owner sets it) plus the first, so by default two. The same answer from
that many rater codes settles it, and a disagreement leaves it open for a
third. A settled point never changes again.

What a settled point does:

- a recording flagged, `sound` and `flag`: the card's `audio` and
  `audio_credit` are taken out of the deck, and the file with them (the
  validator refuses a recording no card plays), so the card uses
  text-to-speech until a new recording exists;
- every other point is recorded, and a point settled "no" is listed for
  the owner in the PR: the answers carry no replacement text, so there
  is nothing the bot could write. A point settled "yes" is a data point two
  reviewers confirmed.

Never kept: what a reviewer wrote in `why`, which stays in the mail, and
mail addresses. Only rater codes, card ids, points, answers and reasons.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
from rater_codes import rater_code  # noqa: E402

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


def settled_answer(point: dict, needed: int) -> str:
    """The answer [needed] rater codes agree on, "" when none yet. When two
    answers both have enough, the one a code gave first in the record's
    order wins: the first to be reached."""
    tally: dict[str, int] = {}
    for given in point.get("answers", {}).values():
        if isinstance(given, dict) and isinstance(given.get("answer"), str):
            tally[given["answer"]] = tally.get(given["answer"], 0) + 1
    for answer, n in tally.items():
        if n >= needed:
            return answer
    return ""


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
    # (lang, card, point, answer) points this batch settled.
    settled: list[tuple[str, str, str, str]] = field(default_factory=list)
    # Recordings taken off a card.
    removed: list[tuple[str, str]] = field(default_factory=list)
    # Settled points the bot cannot apply: a flagged recording whose card
    # cannot be edited a line at a time.
    unsupported: list[tuple[str, str]] = field(default_factory=list)
    touched: set[str] = field(default_factory=set)

    @property
    def changed(self) -> bool:
        return bool(self.recorded or self.removed)


def record(root: Path, batch: Batch, code: str, agreements: int,
           result: Counted | None = None) -> Counted:
    """Writes [batch], by [code], into the records of `root`, and carries
    out what the points it settles ask. [agreements] is how many other
    reviewers must agree: a point is settled by [agreements] plus one."""
    result = result or Counted()
    needed = agreements + 1
    records: dict[str, dict] = {}
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
        agreed = settled_answer(point, needed)
        if not agreed:
            continue
        point["settled"] = agreed
        result.settled.append((a.lang, a.card, a.point, agreed))
        if a.kind == "sound" and agreed == "flag":
            outcome = pr.remove_fields(root, a.lang, a.card, ("audio", "audio_credit"))
            if outcome == "removed":
                # The validator refuses a recording no card plays, so the
                # file goes with the line that named it.
                (root / "decks" / a.lang / "audio" / f"{a.card}.opus").unlink(missing_ok=True)
                result.removed.append((a.lang, a.card))
            elif outcome == "unsupported":
                result.unsupported.append((a.lang, a.card))
    for lang, data in records.items():
        save(root, lang, data)
    return result
