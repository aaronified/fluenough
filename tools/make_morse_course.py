#!/usr/bin/env python3
"""Builds the Morse code course (ADR-0057): its deck files and the tone
recording of every card.

Run it from the repository root, on the branch that holds the decks
(`decks-live`), never by hand-editing the generated files:

    python3 tools/make_morse_course.py            # writes decks/qmo/
    python3 tools/make_morse_course.py out/       # writes out/qmo/ instead

Needs Python 3.11+, PyYAML is not used, and `ffmpeg` with libopus on the path
(to turn each WAV into the Opus file a deck ships).

The signs are Recommendation ITU-R M.1677-1, International Morse code
(2009): letters, digits, punctuation and procedural signs, plus SOS from the
ITU Radio Regulations. Each card's recording is one sign: a 600 Hz sine,
15 words per minute (a dot of 80 ms), ITU timing of one unit for a dot, three
for a dash and one between the signs of a character, with 5 ms ramps at each
tone's edges so that it does not click. The tones are generated, so they are
released under CC0-1.0.
"""
from __future__ import annotations

import math
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

CODE = "qmo"
ROOT = Path(__file__).resolve().parent.parent
WPM = 15
FREQ = 600
RATE = 24000
RAMP = 0.005
UNIT = 1.2 / WPM  # seconds per dot, from "PARIS" at WPM words per minute

DOT, DASH = "•", "–"  # • and –, both in the bundled Roboto

SOURCE = ("Recommendation ITU-R M.1677-1, International Morse code (10/2009), "
          "International Telecommunication Union "
          "(https://www.itu.int/rec/R-REC-M.1677-1-200910-I)")

# (pattern in . and -, native meaning, note after the sound line)
FIRST = [
    ("." , "e", "The shortest sign: a single dot, the most common letter in English."),
    ("-", "t", "A single dash, the next most common letter."),
    ("..", "i", "Two dots."),
    (".-", "a", "A dot and a dash."),
    ("-.", "n", "The reverse of a: a dash and a dot."),
    ("--", "m", "Two dashes."),
]
SECOND = [
    ("...", "s", "Three dots."),
    ("..-", "u", "Two dots and a dash."),
    (".-.", "r", "Dot, dash, dot."),
    (".--", "w", "A dot and two dashes."),
    ("-..", "d", "A dash and two dots."),
    ("-.-", "k", "Dash, dot, dash. Also the invitation to transmit: go ahead."),
    ("--.", "g", "Two dashes and a dot."),
    ("---", "o", "Three dashes."),
]
THIRD = [
    ("....", "h", "Four dots."),
    ("...-", "v", "Three dots and a dash, like the opening of Beethoven's fifth."),
    ("..-.", "f", "Two dots, a dash, a dot."),
    (".-..", "l", "A dot, a dash and two dots."),
    (".--.", "p", "A dot, two dashes and a dot."),
    (".---", "j", "A dot and three dashes."),
    ("-...", "b", "A dash and three dots."),
    ("-..-", "x", "Dash, two dots, dash. The multiplication sign is the same pattern."),
    ("-.-.", "c", "Dash, dot, dash, dot."),
    ("-.--", "y", "A dash, a dot and two dashes."),
    ("--..", "z", "Two dashes and two dots."),
    ("--.-", "q", "Two dashes, a dot and a dash."),
]
DIGITS = [
    (".----", "1", "A dot and four dashes: the digits count up by trading a dot for a dash."),
    ("..---", "2", "Two dots and three dashes."),
    ("...--", "3", "Three dots and two dashes."),
    ("....-", "4", "Four dots and a dash."),
    (".....", "5", "Five dots."),
    ("-....", "6", "A dash and four dots: from 6 on, dashes come first."),
    ("--...", "7", "Two dashes and three dots."),
    ("---..", "8", "Three dashes and two dots."),
    ("----.", "9", "Four dashes and a dot."),
    ("-----", "0", "Five dashes."),
]
PUNCTUATION = [
    (".-.-.-", "full stop (.)", "ITU: full stop. Dot, dash repeated three times."),
    ("--..--", "comma (,)", "ITU: comma."),
    ("---...", "colon (:)", "ITU: colon or division sign."),
    ("..--..", "question mark (?)", "ITU: question mark, a request for repetition."),
    (".----.", "apostrophe (')", "ITU: apostrophe."),
    ("-....-", "hyphen (-)", "ITU: hyphen or minus sign."),
    ("-..-.", "slash (/)", "ITU: fraction bar or division sign."),
    ("-.--.-", "brackets: ( and )", "ITU: left and right bracket are the same sign: it opens and closes."),
    (".-..-.", "quotation marks (\")", "ITU: quotation marks, the same sign before and after the quoted words."),
    ("-...-", "equals sign (=)", "ITU: double hyphen. Also the break sign, which pauses a message."),
    (".--.-.", "at sign (@)", "ITU: commercial at, added to the code in 2004 for e-mail addresses."),
]
SIGNS = [
    ("...-.", "understood", "ITU procedural sign: understood, the sender's message was received."),
    ("........", "error", "ITU procedural sign: eight dots, a correction. The sender starts the word again."),
    (".-...", "wait", "ITU procedural sign: wait. Sent as one run, with no gap between its letters."),
    ("...-.-", "end of work", "ITU procedural sign: end of work. Sent as one run, with no gap between its letters."),
    ("-.-.-", "starting signal", "ITU procedural sign: starting signal, the call that begins a transmission."),
    ("...---...", "SOS: distress signal", "ITU Radio Regulations: the international distress signal. Nine signs sent as one run, with no gap between its letters, so it is not the three letters S, O, S."),
]

DECKS = [
    ("qmo-letters-1", "Morse: the first six letters", "E, T, I, A, N and M: the six signs of one or two tones. Every longer letter is built from these.", FIRST),
    ("qmo-letters-2", "Morse: S to O", "S, U, R, W, D, K, G and O: the letters of three tones.", SECOND),
    ("qmo-letters-3", "Morse: the other letters", "H, V, F, L, P, J, B, X, C, Y, Z and Q: the letters of four tones.", THIRD),
    ("qmo-digits", "Morse: numbers", "The digits 1 to 0, each of five tones: they run from one dot and four dashes to five dashes.", DIGITS),
    ("qmo-punctuation", "Morse: punctuation", "The punctuation of Recommendation ITU-R M.1677-1: full stop, comma, colon, question mark, apostrophe, hyphen, slash, brackets, quotation marks, equals sign and at sign.", PUNCTUATION),
    ("qmo-signs", "Morse: procedural signs", "The procedural signs of Recommendation ITU-R M.1677-1 (understood, error, wait, end of work, starting signal) and SOS.", SIGNS),
]


def symbols(pattern: str) -> str:
    return "".join(DOT if c == "." else DASH for c in pattern)


def say(pattern: str) -> str:
    """The pattern as learners say it: di for a dot, dah for a dash, dit for
    a dot that ends it."""
    out = []
    for i, c in enumerate(pattern):
        last = i == len(pattern) - 1
        out.append("dah" if c == "-" else ("dit" if last else "di"))
    return "-".join(out)


def tone(seconds: float) -> list[float]:
    n = int(RATE * seconds)
    ramp = int(RATE * RAMP)
    out = []
    for i in range(n):
        gain = min(1.0, i / ramp, (n - 1 - i) / ramp) if ramp else 1.0
        out.append(0.6 * gain * math.sin(2 * math.pi * FREQ * i / RATE))
    return out


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def samples(pattern: str) -> list[float]:
    out: list[float] = silence(0.1)
    for i, c in enumerate(pattern):
        if i:
            out += silence(UNIT)
        out += tone(UNIT if c == "." else 3 * UNIT)
    return out + silence(0.1)


def write_opus(pattern: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "tone.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(
                struct.pack("<h", int(max(-1, min(1, s)) * 32767))
                for s in samples(pattern)))
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libopus",
             "-b:a", "24k", "-application", "audio", "-map_metadata", "-1", str(dest)],
            check=True)


def q(text: str) -> str:
    """A double-quoted YAML scalar."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "decks"
    base = out / CODE
    (base / "en").mkdir(parents=True, exist_ok=True)
    lang = (f'{{ code: "{CODE}", iso639_3: "zxx", name: "Morse Code", '
            f'script: "morse", icon: {q(DOT + DASH)} }}')
    cid = 0
    path_units = []
    all_cards = []
    for deck_id, name, description, rows in DECKS:
        core = ["# modes: opt-out; Morse is never spoken aloud, so every card leaves out speaking",
                "schema: 1", f'id: {q(deck_id)}', 'part: "core"', 'kind: "vocab"',
                f"language: {lang}", 'license: "CC-BY-SA-4.0"', f"source: {q(SOURCE)}",
                'tags: ["beginner", "unreviewed", "script"]', "cards:"]
        layer = ["schema: 1", f'id: {q(deck_id.replace("qmo-", "qmo-en-", 1))}',
                 'kind: "layer"', f'core: {q(deck_id)}',
                 'native: { code: "en", iso639_3: "eng", name: "English" }',
                 f"name: {q(name)}", f"description: {q(description)}",
                 'license: "CC-BY-SA-4.0"', 'tags: ["beginner", "unreviewed", "script"]',
                 "cards:"]
        for pattern, native, note in rows:
            cid += 1
            card = f"{CODE}-{cid:04d}"
            write_opus(pattern, base / "audio" / f"{card}.opus")
            core += [f'  - id: {q(card)}', f"    target: {q(symbols(pattern))}",
                     f'    audio: {q(f"decks/{CODE}/audio/{card}.opus")}',
                     '    audio_credit: { source: "Generated by tools/make_morse_course.py '
                     f'({FREQ} Hz, {WPM} words per minute, ITU timing)", license: "CC0-1.0", '
                     'credit: "Generated tone, no speaker" }',
                     '    modes: ["speaking"]', "    notes:",
                     '      - { id: "n1", kind: "note" }']
            layer += [f'  {q(card)}:', f"    native: {q(native)}", "    notes:",
                      f'      "n1": {q("Sounds like " + say(pattern) + ". " + note)}']
            all_cards.append((card, pattern))
        (base / f"{deck_id}.yaml").write_text("\n".join(core) + "\n", encoding="utf-8")
        (base / "en" / f'{deck_id.replace("qmo-", "qmo-en-", 1)}.yaml').write_text(
            "\n".join(layer) + "\n", encoding="utf-8")
        path_units.append(deck_id)

    letters = {"timing": [FIRST[0][0], FIRST[1][0]], "tree": [r[0] for r in FIRST],
               "digits": [r[0] for r in DIGITS]}
    (base / "qmo-script.yaml").write_text("\n".join([
        "# How Morse code works: the ideas behind its patterns, shown before the first",
        "# card and from a deck's Tips. See ADR-0016 and ADR-0057.",
        "schema: 1", 'kind: "script"', 'part: "core"', 'id: "qmo-script"', f'language: "{CODE}"',
        "features:",
        '  - id: "timing"', f"    example: {q(symbols('.-'))}",
        f"    letters: [{', '.join(q(symbols(p)) for p in letters['timing'])}]",
        '  - id: "tree"', f"    example: {q(symbols('..'))}",
        f"    letters: [{', '.join(q(symbols(p)) for p in letters['tree'])}]",
        '  - id: "digits"', f"    example: {q(symbols('.....'))}",
        f"    letters: [{', '.join(q(symbols(p)) for p in letters['digits'])}]",
        '  - id: "run"', f"    example: {q(symbols('...---...'))}",
        f"    letters: [{q(symbols('...---...'))}]",
    ]) + "\n", encoding="utf-8")
    (base / "en" / "qmo-en-script.yaml").write_text("\n".join([
        "schema: 1", 'id: "qmo-en-script"', 'kind: "layer"', 'core: "qmo-script"',
        'native: { code: "en", iso639_3: "eng", name: "English" }',
        'name: "How Morse code works"',
        'intro: "Morse code writes each letter, digit and sign as a short pattern of dots and dashes, sent as tones. It is learned by ear, as a rhythm, more than by counting dots: tap the speaker on every card and say the sound, di for a dot and dah for a dash."',
        "features:",
        '  "timing":', '    name: "Dot and dash: one beat and three"',
        '    text: "A dot is one beat of tone and a dash is three. Between the dots and dashes of one letter is a gap of one beat, between letters three, between words seven. Here a card plays one letter, at 15 words per minute and 600 Hz."',
        '  "tree":', '    name: "Start with six"',
        '    text: "E, T, I, A, N and M are one or two tones long, and every longer letter extends one of them: the fastest way to learn the code is to know these six cold, then add the letters of three tones, then four."',
        '  "digits":', '    name: "Digits count in tones"',
        '    text: "Every digit is five tones. 1 to 5 begin with 1 dot and 4 dashes and trade a dash for a dot each time, until 5 is five dots; 6 to 0 do the same from a dash first, until 0 is five dashes."',
        '  "run":', '    name: "Some signs run together"',
        '    text: "Procedural signs such as understood, wait, end of work and SOS are sent with no gap between their letters, as one long sign. So SOS, sent as a run, is not the three letters S, O and S."',
    ]) + "\n", encoding="utf-8")
    (base / "qmo-path.yaml").write_text("\n".join([
        "# The order Morse code is taught in: the six shortest letters, the rest of the",
        "# alphabet by length, the digits, the punctuation and the procedural signs",
        "# (ADR-0057). Morse is taught to no level, so the path has no B1 plan.",
        "#",
        "# Every qmo deck is listed, by its core id, exactly once. See ADR-0013 and",
        "# docs/DECK-FORMAT.md.",
        "schema: 1", 'kind: "path"', 'id: "qmo-path"', f'language: "{CODE}"',
        "# No theme decks here, so no unit but the last can end in \"*\": a deck a learner adds goes in the last unit.",
        "units:",
        *[f'  - ["{d}"]' for d in path_units],
        '  - ["*"]',
    ]) + "\n", encoding="utf-8")
    print(f"{len(all_cards)} cards written to {base}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
