# Plan: the IPA course revamp, and a phonology deck for every language

Source of truth: this wiki page.


Written 2026-10-26. Builds on [Plan-Ipa-Course](Plan-Ipa-Course) and
[ADR-0041](ADR-0041-The-Ipa-Course), and touches
[ADR-0025](ADR-0025-Iso-15919-And-Ipa) (`ipa` is broad). Nothing here is
built. Everything marked **Proposed** is the author's, not a decision.

## What the owner asked (2026-10-26)

> i need an IPA based pronunciation checker engine. for that, all entries in the app needs the phonetic IPA code, not the phonemic code, like [ˈkʰæt] not /ˈkæt/. this should be possible with a Haiku running a code to replace this on all cards, right?

> the IPA course needs to start with the basics of IPA. like what it is, why it is created, and then how it is structured, before the notations. and the IPA chart should be understood by the users at some appropriate point of the course. the terminologies used in the IPA course, like phonemes, alveolar bridge, or whatever, needs to be specified with images and example sound contrasts. this needs to be immaculate.

> also users need to be told about extIPA and it's uses (though it is not taught).

> All languages should also have optional IPA decks that will be shown to people who knows IPA or want to learn it (will decide the structure later, now the focus is on the decks). these will contain the phonology / phonemic inventory of the language. and how to pronounce their words (will come a little later in sequence, maybe after B1 in path). for example: https://en.wikipedia.org/wiki/Bengali_phonology for bengali

The term is the **alveolar ridge**, not "bridge": the bony ridge behind the
upper teeth. The glossary uses it.

## What exists (verified 2026-10-26)

- `decks/ipa/`: eleven decks, `ipa-basics` first, then familiar, places,
  breath, retroflex, fricatives, liquids, vowels, diacritics, rare, narrow
  (`ipa-path.yaml`), with an English layer in `decks/ipa/en/`, a script guide
  `ipa-script.yaml` ("How the IPA works") and `ipa-facts.yaml`. Plan-Ipa-Course
  counted 179 cards when it was written.
- Cards carry examples marked "has this sound" or "does not" (`sounds`), the
  languages that use the symbol as tags, and notes on where the symbol sits
  on the chart.
- **Every `ipa` in the app is broad**, without slashes or brackets, and the
  validator checks it (DECK-FORMAT, the `ipa` field and "Sounds files"); a
  course example may write a narrow form in square brackets. About 11,000
  `ipa:` lines are in the decks.
- A language's sounds file (`<lang>-sounds.yaml`) lists the contrasts it
  tells apart, for the speaking drill. There is no phonology deck for any
  language. extIPA is mentioned once, in a fact in `ipa-facts.yaml` (the
  Extensions to the IPA, for transcribing disordered speech, first published
  in 1990); the course does not otherwise explain it.
- A card can carry its own image (`image`, a webp shipped with the deck, with
  `image_credit`). Decks are CC BY-SA 4.0 (ADR-0040), the licence of
  Wikipedia's text, so Wikipedia can be adapted with attribution; its pages
  vary in quality, so the primary sources below come first.

## 1. Narrow ("phonetic") transcription of every card

**Not a find-and-replace.** `/kæt/` to `[kʰæt]` needs the language's own
rules and the word's context: aspiration, flapping, dark l, vowel length
before voiced stops, nasalisation, devoicing, tone and stress. A script or a
Haiku can apply rules a phonetician has written; it cannot know them, and
would invent detail where the rule is missing.

**Proposed: derive, do not store.**

- Keep `ipa` broad and authoritative. Storing narrow forms would break the
  validator's rule, the sounds files and the speaking drill's contrast
  detection, which compare broad forms, and would change 11,000 lines at once.
- Add `decks/<lang>/<lang>-phonetics.yaml`: ordered allophone rules over broad
  symbols, per language and variety. A function in `lib/core` applies them to
  a broad `ipa` to give the narrow form, tested on pairs a phonetician
  supplies. The phonology decks below teach the same rules, so one rule file
  serves the learner and the checker.
- Primary downside: the rules cover only what is written, and varieties
  differ, so each rule file names its variety.
- **The checker itself is a separate project.** `speech_to_text` returns
  spelled text, not sounds. Checking against IPA needs an on-device
  phone-recognition model. That is not planned here. My inference (Medium
  confidence) is that such models are compared against broad forms with
  allophone tolerance, so narrow storage may not be needed at all.

## 2. The IPA course revamp

**Proposed order.** The first units are new; the existing units follow, and
no card id changes (ids are permanent).

| # | Unit | What it teaches |
|---|---|---|
| 1 | What the IPA is and why it exists | spelling does not say how a word sounds; the International Phonetic Association's aim of one symbol for one sound; a short history, with a dated, cited source |
| 2 | How the IPA is built | consonants by place, manner and voicing; vowels by height, backness and rounding; length, stress, tone; diacritics add detail |
| 3 | How to read a transcription | brackets: `/ /` phonemic, `[ ]` phonetic, `< >` spelling; the course's own convention (broad, no slashes) and why |
| 4 to 9 | the existing units, in their order | basics, familiar, places, breath, retroflex, fricatives |
| 10 | The whole chart | the pulmonic chart read as a map, once its rows and columns are known; **placed after the vowels**, so each axis has been met |
| 11 | Diacritics, rare sounds, fine detail | the existing units |
| 12 | extIPA and VoQS, not taught | one explanatory card set: what the extensions are for (speech disorders, voice quality), that they exist, where to read them. No drills |

**Terms.** Each term is a card with an image and an example contrast, built
from machinery that exists: `image` for the picture, `examples` with
`sounds: true` and `false` for the contrast. A term is introduced in the unit
whose idea needs it. First list: phoneme, allophone, minimal pair, voicing,
aspiration, place and manner of articulation, lips, teeth, **alveolar
ridge**, hard palate, soft palate (velum), uvula, glottis, tongue tip, blade
and back, retroflex, nasal and oral, stop, fricative, approximant, vowel
height, backness, rounding, length, stress, tone.

- **Images.** Original line drawings (mid-sagittal sections for place, one
  per place; a mouth-and-tongue view for vowels), made for the course and
  shipped as `image` webp with `image_credit`; or Wikimedia Commons figures
  under a compatible licence, credited. Primary downside of drawing our own:
  accuracy depends on a reviewer.
- **"Immaculate."** I can build it; I cannot certify phonetic accuracy. No
  unit is marked `reviewed` until a phonetician has read it, and the whole
  course stays `unreviewed` until then, as every deck does.

## 3. A phonology deck for every language

**Contents (Proposed; the structure of the offer is to be decided later):**

1. The consonant inventory, one card per phoneme: IPA symbol, an example word
   in the language's script, reading and broad IPA, and a minimal pair where
   one exists.
2. Vowels and diphthongs, the same way.
3. Prosody: stress, tone, length, nasalisation, as the language has them.
4. Syllable structure and what clusters are allowed.
5. Allophony: the rules of section 1, each with words that show it.
6. Spelling to sound: how the script is read, with the exceptions.
7. **Pronouncing words** (later; "maybe after B1"): word cards that give the
   narrow form `[ ]` beside the broad one, drawn from the language's own
   decks, using the rule file.

**Sources, in this order:** the language's "Illustration of the IPA" in the
*Journal of the International Phonetic Association* where one exists, then
reference grammars and phonologies, then Wikipedia for what is missing, each
with a citation in the deck. For Bengali that means the JIPA illustration of
Standard Bengali (a Bangladeshi-Standard one exists; I have not checked the
reference) and the Wikipedia page the owner named, which covers the Standard
Colloquial variety together with others; the deck must say which it teaches.

**Order:** the owner's deck priority (Telugu, Bengali, Spanish, Marathi,
Kannada, Assamese, Chinese, Hindustani, Japanese, Korean, Toki Pona), with
Bengali as the pilot because the owner named it (**Proposed**).

## Steps (Proposed, each one pull request)

| # | Step | Done when |
|---|---|---|
| 0 | Answer the Still open questions | the owner has decided |
| 1 | Terms glossary, ten terms with images and contrasts | a phonetician has read them; the card shape is settled |
| 2 | IPA course units 1 to 3 and 12 | they read in the app at 1.4x; the validator passes |
| 3 | The whole-chart unit | the chart is shown and read by axes |
| 4 | Phonology deck for Bengali, parts 1 to 6, with its rule file | a Bengali speaker or phonetician has checked the inventory |
| 5 | The rule function in `lib/core` and its tests | derived narrow forms equal the reviewer's pairs |
| 6 | The rest of the languages in the owner's order | each one as in step 4 |
| 7 | Pronouncing-words decks | after step 5, and after B1 for the path position |

Estimate (mine): steps 1 to 3 about 30 to 50 hours of content and 6 to 10 of
code if cards need no new field; one language's phonology deck 8 to 14 hours;
the rule function 8 to 12 hours. Confidence: low.

## Still open

1. **Derive or store the narrow form?** Derive: rules cover only what is
   written. Store: breaks the broad rule and the contrast detection. (I
   recommend derive.)
2. **Who writes it?** CLAUDE.md gives decks to Haiku; the IPA course was
   built by Sonnet (ADR-0041). Sonnet: costs more. Haiku: phonetics is
   where a weaker model invents, and one review may not catch it.
3. **Who reviews it?** A bilingual reviewer cannot check phonetics. A
   phonetician: not yet found. Without one, everything ships `unreviewed`.
4. **Which variety per language** (for Bengali, Standard Colloquial of
   Kolkata or the Bangladeshi Standard): one, named, with the other's
   differences noted. Downside: a learner of the other sees differences as
   exceptions.
5. **Where do phonology decks sit?** Optional and outside the path until B1
   exists for the language, or in the path after B1. The first is available
   now; the second waits on B1, which few languages have.
6. **Does this lift "decks stop at A1" (2026-10-23) for IPA decks?** The owner
   asked for them, so I read it as yes, for IPA decks only.
7. **Images:** our own drawings, or Wikimedia figures. Own: accuracy rests on
   us. Commons: credit and licence per figure.

See also: [Plan-Ipa-Course](Plan-Ipa-Course) · [Roadmap](Roadmap) ·
[Plans-Index](Plans-Index) · [Home](Home)
