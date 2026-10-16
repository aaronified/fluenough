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

Branch `feat/ipa-line`, on origin, shows each word's IPA on cards, with a
Settings > Learning > Show IPA switch. It is not in 0.3.2. It is stacked on
the ISO 15919 readings (#180) and an earlier head of the sound work (#182,
233c660). Before its PR opens:

- **It fails 3 tests.** With the IPA line, the near-miss feedback on a
  production card overflows by 28 px at text size 2.0:
  `drill_page_test.dart`, "at text scale 2.0 nothing overflows production,
  near miss, card text at 1.0" and "… at 1.4", and `accessibility_test.dart`,
  "at the largest font size, 2.0 on Android production, near miss".
- #180 and #182 are merged (0.3.2), so rebase it onto `main` and run the full suite.
- A grammar question does not show the IPA of the word it asks about; only
  Inspect does.

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
[ADR-0041](../adr/0041-the-ipa-course.md) and DECK-FORMAT.md, "The IPA
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
