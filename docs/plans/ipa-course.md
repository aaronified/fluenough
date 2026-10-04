# Plan: the IPA, taught like a language

Postponed to next week (2026-10-04). The content is written; the app does
not offer it yet, and the owner's later asks are not in it.

## What the owner asked

> And add one deck for IPA, which will be for learning how the IPA alphabet
> works, not only via repetition (which will be via practice), but with as
> much logical structure as possible. Do a little bit research on this.
> This will also be offered like a language.

> The IPA deck: all symbols will have at least two example usage, one for
> how it sounds, and one for how it doesn't. And optional sound for both.
> Like o in dog and o in otter. Both IPA symbols will be grouped in close
> cards. For some sounds you may need to use other languages, which is fine
> too.

> And each card in every language will also have a button to take them
> through a curated IPA deck that only has the symbols used in the card.

Decided with the owner:

- The course covers the whole IPA chart (2020). It is offered twice in the
  languages to learn: **"IPA: my languages"**, only the symbols the
  languages being learned use, and **"IPA: whole chart"**. They share
  progress.
- Each symbol is heard in an example word, in one of the app's languages,
  in that language's phone voice.

The owner's own example needs care: the o of *dog* and of *otter* are the
same sound in British English (/ɒ/), and differ only in American English
(/dɔɡ/, /ˈɑtɚ/). A pair that differs everywhere is *hot* /ɒ/ and *go*
/əʊ/.

## What exists

Branch `wip/v032-ipa`, commit `d21d3df`, on origin:

- `decks/ipa/`: 11 decks of 179 cards, `ipa-0001` to `ipa-0179`. Units:
  basics, familiar letters, places, breath, retroflex, fricatives, liquids,
  vowels, diacritics, rare, narrow.
- Each card's notes explain where its symbol sits on the chart and how its
  shape is built.
- Each card's tags give the languages that use the sound, plus `core` for
  the symbols every learner needs.
- `ipa-en-path.yaml`, the script guide `ipa-script.yaml` ("How the IPA
  works", 13 features), and `ipa-facts.yaml` (37 facts in en, bn and hi).
- The language block: `{ code: ipa, iso639_3: zxx, name: IPA, script: ipa,
  typed: false, icon: "ə" }`.

Branch `claude/ecstatic-wright-b1z4x5` has a draft of the app side:
`LanguageInfo.typed` and `scoped`, `CardExample.language`, and the `ipa`
script needing no reading. It also has a draft ADR,
`docs/adr/0026-ipa-course-and-icons.md`, to renumber.

## What is left

1. **Examples, by the new rule.** Every symbol has at least two examples:
   - one where a letter is said with the symbol's sound;
   - one where the same letter is not, with what it is said as instead.

   Both carry a speaker. Use another language where the app's languages
   lack the sound. This needs a field on an example, such as
   `sounds: false`, and a line on the card that says which is which.
2. **Confusable symbols side by side.** Order each deck so that symbols
   learners mix up are adjacent: ɒ and ɔ, ʈ and t̪, ɪ and i, ɾ and r.
3. **The app:**
   - `pubspec.yaml` lists `decks/ipa/`; the validator stops warning about
     a missing tts tag for `script: ipa`.
   - Two entries in the languages list, one language: a per-language
     setting, "my languages" or "whole chart". Cards are filtered by their
     tags against the languages being learned, in one place, so that
     counts, lessons, finished decks and Inspect agree.
   - Production asked by choosing when `typed: false`: in reviews, in
     lessons, and for the hard words' check.
   - An IPA card plays its examples in their languages' voices,
     preferring the languages being learned.
4. **The button on every card**, "The sounds of this word": it opens a
   session of the IPA cards whose symbols occur in the card's `ipa`. To
   decide: whether those answers are recorded in the IPA course, and
   whether the button shows for a learner who is not learning the IPA.
5. **Review:** an independent rating, and a speaker's check of the tags
   the content agent was least sure of: Hindi h and ɦ; r and ɾ; ŋ and ɲ;
   ts and dz in Telugu; ʂ in Marathi; Assamese ɛ, ʊ and ɒ.

## Estimate

About 6–8 hours of work: 2 for the examples and ordering, 3–4 for the app,
2 for the per-card button. Confidence: medium.
