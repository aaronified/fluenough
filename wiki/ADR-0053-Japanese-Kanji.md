# ADR-0053: Japanese kanji is the `han` script of a two-script language, with the kana reading as the card's second spelling

Source of truth: this wiki page.

- **Status:** Accepted.
- **Date:** 2026-11-02
- **Builds on:** [ADR-0009](ADR-0009-Scripts-Are-Open) (scripts are open),
  [ADR-0016](ADR-0016-Script-Guides), [ADR-0052](ADR-0052-Minimum-App-Version-In-The-Deck-Index).
  Reuses `scripts` and `target_scripts` (#623) and the Chinese course's
  characters units.

## Context

The Japanese path plans six kanji units (`script-kanji-1` to `-6`, path
units 43, 56, 74, 93, 109 and 127) and the course's cards are all in kana
with a romaji reading. The owner was asked how kanji should enter the decks
and chose "Kanji targets, kana readings (Recommended)" (2026-11-02): "From
each kanji unit on, cards write the target in kanji with the kana reading
shown (like Chinese hanzi with pinyin); earlier cards stay kana. Needs a
format and validator change for a kanji script plus the existing Kanji/Hanzi
resources." The build is for the next release: "The build needs to go in the
next release as well, so prioritise that."

Most of the machinery exists. `han` is already Japanese's second script in
`assets/languages.yaml` (named "Kanji" in the app, drawn in Noto Sans JP),
so the Languages page already has Read and Write pills for kana and kanji.
A card already carries a second spelling in each of its language's other
scripts (`target_scripts`), and the app already shows a learner the script
they learn, with the other spellings beneath it, writes in the script they
choose, and skips a script's units when it is not learned. What the format
lacked was a way to say that the second spelling of a kanji word is its
kana, and a check that it is kana. (The "Kanji/Hanzi resources" of the
decision are the per-language `resources.yaml`, #832, "where else to learn":
they need nothing here.)

## Owner's answers (2026-11-02)

On the first version of the pull request the owner answered five questions:
1. Romaji beside the kana: keep both, the romaji reading and the kana
   beneath the kanji.
2. Example sentences: "Add a kana line."
3. Typing: writing in kana grades kana and accepts kanji, writing in kanji
   grades kanji only. OK as designed.
4. A script known (Read kanji = Know) but not learned: keep the existing
   rule, which shows known scripts only when none is learned.
5. A check of the kana against the romaji `reading`: not asked. It is not
   built.

## Decision

- **No new field and no new script.** A kanji deck is `script: han`,
  `scripts: [han, kana]`. A card's `target` is in kanji (with its okurigana),
  and its kana reading is `target_scripts.kana`. `reading` stays the Hepburn
  romaji, because typed romaji answers, `ipa` and the readings in prose follow
  it. Kana before the first kanji unit is untouched: those decks stay
  `script: kana`, with no `scripts`.
- **The validator** accepts `kana` as a script whose letters it checks
  (hiragana, katakana, ー, ・, halfwidth katakana), so a "kana reading" with a
  kanji or romaji in it is refused; counts 々, 〆 and 〇 as kanji; and requires
  `target_scripts.kana` on every target of a `han` deck listing `kana` that
  has a kanji in it. A kana-only target (ありがとう) gives none.
- **A script unit of kanji** (`ja-kanji-N`, under `alphabet`) is a vocab deck
  tagged `script`, as Chinese's `characters-N`, one card per kanji. Its
  `target_scripts.kana` is the one reading the unit teaches the kanji by; the
  other on and kun readings are in the layer's notes, and the kanji's words
  are taught by the examples and by the kanji word cards after it.
- **The app** needs one change. `primaryScript` counts decks to decide which
  script a course starts with, and the kanji decks will outnumber the kana
  ones; a `han` deck that lists kana now counts for kana, so a learner who
  has not chosen is still learning kana, sees kana in kanji decks, and
  leaves the kanji script units out until they choose Learn on Read kanji.
  Everything else is the #623 behaviour, now tested for Japanese: kanji with
  the kana beneath it, kana alone, either script written, the script check
  asking about kana then kanji.
- **Example sentences take `target_scripts`** (the only format change; owner
  answer 2): an example in a kanji deck has the kana line as
  `target_scripts: { kana: ... }`, the translation staying in each layer keyed
  by the example's `target`. The validator checks its letters as a card's and
  requires it on an example with a kanji in it; an example in kana alone gives
  none. The app shows the kana line under the kanji example (smaller, as a
  card's other spelling) for a learner who learns both, and the kana alone for
  one who learns kana only.
- **Typed answers.** Writing in kana grades the kana and accepts the kanji;
  writing in kanji grades the kanji. A learner who learns both chooses with the
  Write option, as for any two-script course.

## Card shapes

A kanji word card:

```yaml
- id: "ja-0301"
  target: "食べる"
  target_scripts: { kana: "たべる" }
  words: ["食べる"]
  reading: "taberu"
  pos: "verb"
```

A card of a `script-kanji-N` unit:

```yaml
- id: "ja-0401"
  target: "日"
  target_scripts: { kana: "ひ" }
  words: ["日"]
  reading: "hi"
  pos: "noun"
  notes: [{ id: "n1", kind: "note" }]   # layer: on ニチ (nichi), ジツ (jitsu); kun ひ (hi), か (ka)
```

## Sequencing

CI's "Released app reads the decks" runs the latest released app against a
pull request's decks, and deck files that use something a release does not
read break it. This change is code, tools, docs and a test fixture only: it
touches no file in `decks/`. The kanji decks, and the first cards written in
kanji, land after the release that carries it, each file held to that release
with `decks/min_app.json` (ADR-0052). Until then Japanese is as it was.

## Consequences

- A kanji unit and every word card after it are written once, in kanji; the
  kana is shown, never typed twice.
- An example's kana line is written by hand beside its romaji. The kana is
  not checked against the romaji `reading` (owner answer 5: not wanted).
- Furigana inside an example, a kanji's stroke order and handwriting
  ([Plan-Handwriting](Plan-Handwriting)) are not part of this.
