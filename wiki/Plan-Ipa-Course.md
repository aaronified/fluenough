# Plan: the IPA, taught like a language

Source of truth: this wiki page.


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

The IPA line and the Settings > Learning > IPA pronunciations switch (#533) are
rebuilt on `main` from the drafts on `feat/ipa-line` (f5c8dba) and
`wip/v032-ui` (41e5573, 65df57e), which are not merged: they conflict in 34
files. The line sits on the drill's card, which scrolls, not in the fixed
feedback at its foot, where the draft overflowed on a production near miss.
Nothing overflows at 1.4x, the app's cap (#505). A grammar question shows
its word's IPA from the start and the form's once answered.

The draft of the app side (`LanguageInfo.typed` and `scoped`,
`CardExample.language`, and the `ipa` script needing no reading), and a
draft ADR, `docs/adr/0026-ipa-course-and-icons.md`, are not on `main`, and no
longer on branch `claude/ecstatic-wright-b1z4x5`: that branch was reused for
the skill model and the support mails (#432, #433), and `LanguageInfo` on
`main` has no `typed` or `scoped`. The app side is still to be written; the
next free ADR number is 0037.

## Decided with the owner, 2026-10-16

Plan item 4's two open points are answered ("Yes, recorded"; "Show, offer to
add"):

- The answers given through "The sounds of this word" button are recorded:
  they count as IPA course practice and are scheduled.
- The button shows for a learner who is not learning the IPA, and tapping it
  first offers to add the course.

The app side, plan items 1 (the example field), 3 and 4, is built on
`wip/ipa-course` and described in
[ADR-0041](ADR-0041-The-Ipa-Course) and DECK-FORMAT.md, "The IPA
course". The content, items 1 (the examples), 2 and 5, is not.

## Content, done 2026-10-16 (items 1 and 2)

The eleven decks, the path, the script guide and the facts are in the current
format (cores and an English layer, ids kept, every scalar quoted, every
script word in prose followed by its reading).

- **Examples.** Every card has a `language` on each example and at least one
  where the symbol's letter is not said with its sound (`sounds: false`,
  what it is said as instead in the layer). Another language is used where
  the app's languages lack the sound (German, French, Polish, Welsh, Zulu,
  Vietnamese, Swedish, Arabic and others). Example IPA of Indian-language
  words comes from `tools/transcribe.py`.
- **Order.** Confusable symbols are adjacent in each deck: ɒ ɔ ɑ, ʈ t̪ and
  ɖ d̪, ɪ i, ɾ r, e ɛ, ʃ ɕ, θ ð, and the narrow marks in pairs.
  `tools/test_ipa_course.py` checks the ids, both kinds of example and the
  adjacency.
- **Checks.** The validator's `ipa` letters now take the click letters, ⱱ, ꜜ
  and ⁿ.
- **For a speaker's check (item 5).** A second note on the card says what is
  doubtful: Hindi h and ɦ; r and ɾ; ɲ and ŋ; ts and dz for Telugu; ʂ for
  Marathi; Assamese ɛ, ʊ and ɒ; and the example words for ɢ, ɴ, ɻ, ʕ, ɰ, ʍ,
  ʀ, ʙ, ɺ, ɤ, n̥, b̤, ĕ, ʄ, the Yoruba tone and the Irish t.

## Open questions

27 symbols have no example yet where a letter is said with the sound; each
has the example where it is not, and a note saying one is wanted. They are
the lip flick ⱱ, ʟ, ɘ, ɞ, ɶ, ˑ, ʘ, ǂ, ɠ, ʛ, sʼ, ʜ, ʢ, ʡ, ꜜ, a̰, ɔ̹, ɔ̜, e̠, ë, e̽, t̼,
e̝, e̘, e̙, t̺ and t̻. I did not invent words. Which language and word do you
want for each? (A speaker or phonetician is needed.)

## What is left

Item 5: an independent rating, and the speaker's check above.

## Estimate

About 6–8 hours of work: 2 for the examples and ordering, 3–4 for the app,
2 for the per-card button. Confidence: medium.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
