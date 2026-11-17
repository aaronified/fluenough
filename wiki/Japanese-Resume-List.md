# Plan: Japanese resume list

This page is the resume list for the Japanese course: what is merged, what is
left, in what order, and what only the owner can decide. It builds nothing.

Source: the rows of `docs/review-queue/ja.md` added on 2026-11-17 (branch
`decks/ja-resume-list`, commit `4de40bbb5`). The review queue holds questions
for a bilingual reviewer only; status and owner-only text live here.

Related: [Plan-Language-Completeness](Plan-Language-Completeness.md) (the
checklist of every deliverable), [Plan-Culture-Japanese](Plan-Culture-Japanese.md),
[Plan-Japanese-B1-Wordlists](Plan-Japanese-B1-Wordlists.md),
[Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology.md).

## Status

As of 2026-11-17. Japanese is complete on every app line: stage, 100% to B1,
grammar 85 of 85, culture 72 of 72.

Merged pull requests: #1374, #1377, #1378, #1379, #1388, #1396, #1422, #1426,
#1439, #1589, #1590, #1592, #1594.

Open: #1591, Japanese professional decks (medicine, hospitality and business:
six hidden decks, 62 cards). It is not merged.

Still left (detail in the sections below):

- the shared tool fix for the hiragana file and the ASCII `g` bug;
- the phonetic backfill for the hiragana file and 14 culture cards;
- the notes pass, about 350 cards;
- the sentences decks for six A1 grammar units, and optional extras;
- the owner-only items.

## Shared tool task

This is for the architect. Language sessions do not edit `tools/`.

### 1. The hiragana file is skipped by the phonetic tools

The file `decks/ja/ja-en-hiragana.yaml` is a single-file deck: deck id
`ja-en-hiragana`, core id `ja-hiragana`, with the core and the English layer in
one file. `tools/import_phonetic.py ja` and `tools/derive_phonetic.py ja` skip
all 46 of its cards because of that shape.

- Failing example: the card for あ has broad `ipa` `a` and no `phonetic`. The
  derive dry run counts 5,691 cards with a `phonetic`, out of 5,737 cards that
  have a broad `ipa`. The 46 cards without one are exactly this file.
- Expected output: each of the 46 cards gets `phonetic` in `[...]` and
  `phonetic_source` set to `rules` (or `wiktionary`), as the other Japanese
  cards have. The rest of the file is unchanged.

### 2. `tools/transcribe.py ja` emits an ASCII `g`

For ぎゃ, ぎょ and ぎゅ the tool writes ASCII `g`. For example ぎょう gives
`gjoː`.

- Expected output: the script `ɡ` (U+0261), so ぎょう gives `ɡjoː`.

## Resume order

Each step is small. Step 2 waits for step 1.

1. **Tool fix** (the shared tool task above). Architect only.
2. **Phonetic backfill.** After the tool fix, run
   `derive_phonetic.py ja --bracket-unchanged --write` and
   `import_phonetic.py ja --write`, as one small pull request. It covers:
   - the 46 hiragana cards;
   - the 14 `ja-culture-3` cards with no `phonetic`: ja-4654, ja-4655, and
     ja-4657 to ja-4668. ja-4656 was dropped and its id is never reused.
3. **Notes pass.** About 350 cards have a real teachable point and no note.
   Order:
   - first, the 102 grammar-sentence cards, each with the grammar point it shows;
   - then about 235 vocabulary sentences with an inflected verb;
   - then the hiragana look-alike notes (shi/tsu, nu/me, ne/re/wa).

   A Sonnet agent sets the rule. Haiku builds the notes in 3 to 4 batches of
   about 100 cards.
4. **A1 grammar sentences.** Six A1 grammar units have no sentences deck and need
   one: units 25 (verb groups), 26 (aru/iru), 27 (adjectives), 37 (masu past),
   40 (tai) and 44 (mashou).
5. **Recommendations and creators.** Legacy lines for the 15 recommendation-only
   creators. Edo creators: 6, against 20 for Heian, so Edo needs more.
6. **Optional.** Up to four more situation sheets, for the unused icons school,
   work, bank and travel.

## Owner-only

Only the owner can decide these. Record the answer in this page and in the
issue it belongs to.

- **A2 plan.** The A2 plan has 905 words against the target of 1,050.
- **Native layers other than English.**
- **Kanji (#1146).** Kanji beyond the 1,026 taught, and the 438 kanji cards that
  have no taught word using them.
- **Source-it-yourself validator (T23).** Whether to build the mode that lets the
  validator check the 29 recommendations.
- **Unreviewed decks.** A native reviewer for the decks that have not been
  reviewed.
- **Proverbs 60 and multi-word verbs 58.** Are they final? Eight of the 20
  idioms are attested; the rest are not on ja.wiktionary.
- **Gon-gitsune (`ja-culture-3`).** The culture item needs the Aozora text of
  Niimi Nankichi. The proxy blocks Aozora, so the item cannot be sourced yet.
