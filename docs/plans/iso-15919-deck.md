# Plan: a deck that teaches ISO 15919, in each language

Postponed to next week (2026-10-04).

## What the owner asked

> And add one deck for ISO-15919 as well, as that is the transliteration
> standard we will use.

Decided with the owner: **a deck in each Indian language**, not a course
of its own. Each language's course gets one "Reading the Latin letters"
deck with only that language's letters.

## Why it is needed

Since #180, every reading is in ISO 15919's letters, spelled as the word is
said: *pālu*, *pāṭa*, *kôthā*. A learner meets ā, ṭ, ś and m̐ on the first
card, and the README's table is not in the app.

## The deck

- One vocab deck per language, `<code>-en-iso-letters`, placed in the
  path's first unit or straight after it, before the sounds-to-tell-apart
  deck.
- A card is a letter of ISO 15919 as that language's readings use it:
  - `target` is the Latin letter or letters (ā, ṭh, m̐);
  - `native` says what they mean ("a, held twice as long");
  - `notes` give the script letter it stands for, and how it differs from
    the plain letter;
  - examples are words from the language's own decks.
- Only the letters the language's readings use: Bengali has ô and no ē,
  Telugu has ē and ō, Assamese has x.
- Modes: recognition and production by choosing. The letters cannot be
  typed on most phone keyboards, so the language block or the deck needs a
  way to say so; the IPA course needs `typed: false` too.
- The cards are written in the language's own deck, so their ids are
  `<code>-NNNN`, from each language's next free number.

## To decide

- Whether the deck is in the alphabet units, skipped by a learner who
  learns without the alphabet. Probably not: the readings are what such a
  learner reads.
- Whether a letter's card plays a word with it.

## Estimate

About 3 hours for seven decks, the validator and the path changes.
Confidence: medium.
