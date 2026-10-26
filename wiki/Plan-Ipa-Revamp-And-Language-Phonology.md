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

Answers (owner, 2026-10-26, to the questions in this plan's first draft):

> Decision for you: write a plan page first, as with the question-engine plan, before any deck work? yes. plan it.

> Images: try checking wikidata for these.

> IPA transcription (phonetic [kʰæt] on every card): wikitionary has this. i dont trust rules here because a lot of languages have a lot of exceptions (e.g. engllish)

Later the same day (owner, 2026-10-26):

> the other 26 terms, including alveolar ridge, hard palate, glottis and the manner terms, have no image on Wikidata. They need to be fetched from elsewhere and must not be our drawings.

> add the IPA extras, and find the images

> the IPA deck should teach me the different manners of articulation, places, phonation, oral/nasal, median-lateral, airstream meachanism, etc as well.

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
rules and the word's context, and, as the owner says, rules have many
exceptions (English most of all). A script or a Haiku can apply rules; it
cannot know the exceptions.

**Decided (owner, 2026-10-26): do not derive by rules; take the transcription
from Wiktionary.** This replaces the author's first proposal (a rule file per
language), which the owner rejected.

- **What Wiktionary has** (verified for one word): its English entry for
  *cat* gives `/ˈkæt/` with `[ˈkʰæt]` for RP and for General American, and
  other accents' narrow forms, through `{{IPA|en|/ˈkæt/|[ˈkʰæt]|a=RP}}`.
  A word has one form per accent, so a card needs to say which accent its
  narrow form is.
- **Licence:** Wiktionary's text is CC BY-SA 4.0, the decks' licence
  (ADR-0040), so it can be used with attribution (page, revision, licence).
  I checked neither the current Wiktionary licence nor the attribution it
  asks for; do that before any import.
- **Coverage is unmeasured.** I tried to sample 20 words in each of six
  languages through Wiktionary's API and was rate limited (HTTP 429), so I
  have no figure. Do not assume other languages are like English: many
  Wiktionary entries give only `/…/`, and some give IPA that a template
  generates from the spelling by rules, which is the thing the owner distrusts.
  Measure first, from a Wiktextract dump (kaikki.org, reachable from here),
  not from the live API: for each language, the share of the app's words that
  have a hand-entered `[…]` form, a generated one, a `/…/` only, or none.
- **Where it is stored (Proposed):** a new optional card field, `phonetic`,
  one quoted string in square brackets, beside `ipa`, which stays broad and
  keeps its validator rule, its sounds files and the speaking drill. A card
  with no Wiktionary narrow form has none; the checker falls back to the
  broad one. The field needs a release that reads it before a deck uses it
  (released apps reject unknown fields), a validator rule (square brackets,
  IPA letters only), a credit line, and the accent it is for.
- **A word not on Wiktionary** (inflected forms, phrases, example
  sentences) has no narrow form until someone writes one. Not generated.
- **The checker itself is a separate project.** `speech_to_text` returns
  spelled text, not sounds. Checking against IPA needs an on-device
  phone-recognition model. That is not planned here. My inference (Medium
  confidence) is that such models are compared against broad forms with
  allophone tolerance, so narrow forms may help less than the owner expects.

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

**The dimensions the course teaches (owner, 2026-10-26), each a unit with
images and sound contrasts.** Proposed order and wording; the unit list in the
table above is regrouped around them.

| Dimension | What it teaches | Contrast examples (sounds that differ in only this) |
|---|---|---|
| Place | where the airflow is shaped: bilabial to glottal, with the diagrams above | /p/ and /t/ and /k/ |
| Manner | stop, nasal, trill, tap or flap, fricative, approximant, affricate | /t/ and /s/; /s/ and /ɹ/ |
| Phonation | voiced and voiceless; breathy and creaky voice; aspiration | /p/ and /b/; /pʰ/ and /p/; Hindustani /b/ and /bʱ/ |
| Oral and nasal | whether air also goes through the nose | /d/ and /n/ |
| Central (median) and lateral | air over the middle of the tongue, or over its sides | /s/ and /ɬ/; /ɹ/ and /l/ |
| Airstream mechanism | pulmonic (lungs); glottalic: ejective and implosive; velaric: clicks | /k/ and /kʼ/; /b/ and /ɓ/; clicks in Zulu |
| Vowels | height, backness, rounding, length, nasalisation | /i/ and /u/ and /y/ |
| Secondary articulation and coarticulation | palatalised, velarised, labialised, pharyngealised; labial-velar | /t/ and /tʲ/; /w/ |
| Suprasegmentals | stress, tone, length, intonation | tone minimal pairs |
| Reading the whole chart | each cell as the meeting of these dimensions, once all have been met | after vowels |
| extIPA and VoQS | what they are for, one explanatory set, with the 2025 chart (CC BY-SA 4.0) and the VoQS chart; not taught | none |

Examples take their languages from the course's tags (Hindustani, Bengali,
Telugu, Spanish and others), as the existing cards do; where the app has no
language with the sound, another language is used, as the cards already do.

**Terms.** Each term is a card with an image and an example contrast, built
from machinery that exists: `image` for the picture, `examples` with
`sounds: true` and `false` for the contrast. A term is introduced in the unit
whose idea needs it. First list: phoneme, allophone, minimal pair, voicing,
aspiration, place and manner of articulation, lips, teeth, **alveolar
ridge**, hard palate, soft palate (velum), uvula, glottis, tongue tip, blade
and back, retroflex, nasal and oral, stop, fricative, approximant, vowel
height, backness, rounding, length, stress, tone.

- **Images (decided, owner, 2026-10-26): fetched from elsewhere, never our
  drawings.** Searched on Wikidata (SPARQL) and Wikimedia Commons, 2026-10-26.
  Wikidata's `image` property covers 17 of 43 terms, mostly ordinary photos;
  Commons has what the course needs, as whole series:

  | What | Files on Commons (as found) | Licence as listed |
  |---|---|---|
  | One sagittal diagram per sound, plosives | `IPA t Sagittal Section.svg`, `IPA d …`, `IPA g …`, `IPA q …`, `IPA ɢ …`, and others | CC0 |
  | One diagram per sound, fricatives, approximants, nasals, trills, uvular and pharyngeal | `Voiceless alveolar fricative articulation.svg`, `Voiced retroflex approximant.svg`, `Voiced uvular nasal.svg`, `Voiceless pharyngeal fricative articulation.svg`, and others | CC BY-SA 4.0 (one CC BY 4.0) |
  | The places, one image each | `Bilabial.svg`, `Dental.png`, `Alveolar.svg`, `Retroflex.svg`, `Palataal.svg`, `Velar.svg`, `Glotal.svg`, `Laryngaal.svg`, `Epiglotal consonant.svg`, `Faryngal consonant.svg`, `Labiodentaal.svg` | public domain, CC BY-SA 3.0 (Bilabial, Alveolar), CC BY 3.0 (Dental) |
  | Mouth, palate, soft palate, uvula, larynx (alveolar ridge, hard palate, glottis) | `Illu mouth.jpg`, `Illu01 head neck.jpg`, `Gray855.png`, `Gaumen.png`, `Labeled Human Mouth.jpg`, `Larynx.svg` | public domain, CC BY-SA 3.0 and 4.0, CC0 |
  | Vowel charts | `IPA vowels.svg` (CC0), `IPA vowel chart.svg`, `Cardinal vowels on a vowel chart.svg` (CC BY-SA 4.0), the IPA's 2015 vowels (CC BY-SA 3.0) | as listed |
  | The whole chart | `IPA chart 2020.svg` and `.pdf` | CC BY-SA 3.0 |
  | extIPA and VoQS | `ExtIPA chart (2025).pdf` (CC BY-SA 4.0), `ExtIPA chart (2021).pdf` (CC BY-SA 3.0), `ExtIPA chart (2015).pdf` (public domain), `VOQS chart (2016).pdf` (public domain) | as listed |
  | Phoneme and allophone | `Phoneme-allophone-determination-chart.svg` | public domain |

  **Not found yet:** voicing and aspiration (a voice-onset-time figure),
  tone, stress, minimal pairs, the airstream mechanisms (ejective, implosive,
  click), lateral and the nasal-versus-oral contrast as a pair. Commons'
  search is weak for these; next try its categories and the IPA symbols'
  own pages.
  **Checks before any file is used:** the licence on the file page itself
  (this list is from the API), the author and credit line for
  `image_credit`, and the deck licence. Decks are CC BY-SA 4.0; CC0, public
  domain and BY-SA 4.0 files fit it; a BY-SA 3.0 file is shown unmodified
  with its own licence and credit, and whether it may sit in a 4.0 deck is
  to be confirmed. SVG and PDF files are rasterised to the webp the `image`
  field takes, with the credit kept. The Commons and Wikidata APIs rate
  limited this environment repeatedly (HTTP 429), so the list is from slow,
  batched reads.
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
5. Allophony: the language's main allophone rules, each with words that show it (taught, not used to generate forms).
6. Spelling to sound: how the script is read, with the exceptions.
7. **Pronouncing words** (later; "maybe after B1"): word cards that give the
   narrow form `[ ]` beside the broad one, from the `phonetic` field.

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
| 0 | Measure Wiktionary's narrow-form coverage per language from a Wiktextract dump; read the images' licences from a machine that reaches Commons; answer the Still open questions | a table per language; the owner has decided |
| 1 | Terms glossary, ten terms with images and contrasts | a phonetician has read them; the card shape is settled |
| 2 | IPA course units 1 to 3 and 12 | they read in the app at 1.4x; the validator passes |
| 3 | The whole-chart unit | the chart is shown and read by axes |
| 4 | Phonology deck for Bengali, parts 1 to 6, | a Bengali speaker or phonetician has checked the inventory |
| 5 | The `phonetic` field: format, validator, release, then an import tool from the dump with credit | the validator accepts it; imported forms match Wiktionary's |
| 6 | The rest of the languages in the owner's order | each one as in step 4 |
| 7 | Pronouncing-words decks | after step 5, and after B1 for the path position |

Estimate (mine): steps 1 to 3 about 30 to 50 hours of content and 6 to 10 of
code if cards need no new field; one language's phonology deck 8 to 14 hours;
the `phonetic` field and import tool 10 to 16 hours. Confidence: low.

## Still open

1. ~~Derive or store the narrow form?~~ Decided: take it from Wiktionary (section 1). Left: the field's name and shape, and the accent per form.
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
7. ~~Images~~ Decided: fetched, never our drawings (see Images). Left: the sounds' images not found yet, and the BY-SA 3.0 question above.

See also: [Plan-Ipa-Course](Plan-Ipa-Course) · [Roadmap](Roadmap) ·
[Plans-Index](Plans-Index) · [Home](Home)
