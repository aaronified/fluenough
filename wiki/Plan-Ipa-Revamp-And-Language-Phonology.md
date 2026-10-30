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

And (owner, 2026-10-26), on what "the IPA extras" meant:

> no to first, i meant the extra decks needed for IPA. just mention extIPA and VoQS.

> and also add [] IPA to all decks using a code via haiku

> and add that to the deck building guideline

On what to do where Wiktionary has no narrow form, after the coverage numbers (owner, 2026-10-26):

> add all from wikitionary, then use rules for the rest, add a field to denote the source. the app will use them accordingly. the weak notation keeps being used as is

And (owner, 2026-10-26):

> ok. the IPA deck should also define what a plosive or a implosive is, as well. all terminology, basically

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
- **Coverage, measured 2026-10-26** (a Haiku, from the Wiktextract dumps; share of
  each language's card targets with a hand-or-template-entered `[…]` form):
  Korean 70%, Hindustani 55%, Bengali 41%, Spanish 36%, Japanese 31%,
  Marathi 16%, Telugu 5%, Kannada, Assamese and Chinese under 1%; Toki Pona is
  not on `kaikki.org`. Phrases and sentences are mostly not covered. The
  Hindustani and Bengali forms look generated by Wiktionary's own
  spelling-to-sound templates (inference, Medium confidence: the dump does not
  say which template wrote a form).
- **Decided (owner, 2026-10-26): Wiktionary first, rules for the rest, a field
  says which.** Every card Wiktionary has a narrow form for gets it. Every
  other card gets a form derived by per-language rules. A field records the
  source, so the app can treat them differently (for example, a checker may
  accept more variation against a rules-derived form). The broad `ipa`
  ("the weak notation") **keeps being used as it is**. This replaces the
  earlier "do not derive by rules" decision for the cards Wiktionary lacks.
  **Proposed shape:** `phonetic: "[ˈkʰæt]"` and `phonetic_source`, one of
  `wiktionary` or `rules` (a card with neither has no narrow form);
  `tools/import_phonetic.py` writes the first; `tools/derive_phonetic.py`
  writes the second from `decks/<lang>/<lang>-phonetics.yaml`, an ordered
  rule file per language and variety, written by Sonnet from the sources
  named in it and checked on pairs a phonetician supplies. Rules are known to
  have exceptions (English most of all); the `rules` source says so on the
  card, which is the reason for the field. The accent a Wiktionary form is for
  is kept too (Hindustani's forms carry ten accent tags), shape to be set
  from the coverage data.
- **Where it is stored (Proposed):** a new optional card field, `phonetic`,
  one quoted string in square brackets, beside `ipa`, which stays broad and
  keeps its validator rule, its sounds files and the speaking drill. A card
  with no Wiktionary narrow form has none; the checker falls back to the
  broad one. The field needs a release that reads it before a deck uses it
  (released apps reject unknown fields), a validator rule (square brackets,
  IPA letters only), a credit line, and the accent it is for.
- **How it reaches every deck (owner, 2026-10-26): a tool, run by Haiku.** A
  tool, `tools/import_phonetic.py` (written and reviewed by Sonnet, since it
  is code), reads a Wiktextract dump and writes `phonetic` on each card whose
  word Wiktionary gives a hand-entered `[…]` form for, with the accent and a
  credit. Haiku runs it language by language and opens one pull request per
  language, which Sonnet reviews once. It writes only what Wiktionary has, so
  "all decks" means every card Wiktionary covers, not every card. Order: the
  field, its validator rule and the coverage table first (a pull request,
  then a release that reads it, since released apps reject unknown fields);
  the import pull requests go to `decks-next` after that release. Until
  then a deck builder writes no narrow form by hand (see
  `.claude/skills/build-deck/SKILL.md`).
- **Built (owner asked, 2026-10-30: "make all decks compliant with the full []
  IPA notations"; not run on any deck yet).** The field, its two sources and
  the validator rule exist (`phonetic`, `phonetic_source`; 0.6.6 reads them).
  The tools are `tools/import_phonetic.py` and `tools/derive_phonetic.py`
  (commands in [Deck-Tools](Deck-Tools)); both patch the deck text after the
  card's `ipa:` line, skip a card that has a `phonetic`, and report coverage
  per deck. What had to be decided, and how:
  - **Data source.** The kaikki.org per-language JSONL
    (`https://kaikki.org/dictionary/<Language>/kaikki.org-dictionary-<Language>.jsonl`),
    downloaded once into the git-ignored `.cache/phonetic/`, not the live
    API (which rate limited the first sample). `urllib` only.
  - **Which form.** Each sound in the dump has a `note` and/or `tags`
    naming its variety. A form is taken only if it is marked as the
    course's variety, or is untagged (Wiktionary's default); a form with
    another note or tag is not. Syllable dots are dropped, as the decks'
    `ipa` has none, and Latin g is written ɡ. A word whose entries disagree is
    left alone (ambiguous), and a form that is not IPA letters and marks in
    brackets is counted invalid and never written.
  - **Variety per language (open question 4, decided for the first three).**
    Bengali: the Kolkata standard, Wiktionary's `Rarh` (the decks' broad
    `ipa` is the Kolkata standard; Dhaka and Vanga forms exist and are not
    taken). Hindustani: Wiktionary's "Hindi, Standard" forms and untagged
    ones, from the Hindi dump only (Devanagari; the Urdu entries are not
    read). Spanish: the untagged form, which Wiktionary does not say is
    Castilian or Latin American while the decks' `ipa` writes θ, so a
    Latin-American learner's card shows a Castilian broad form beside a
    form of unknown accent: left for the owner. Any other language needs its
    variety named in `VARIETIES` first.
  - **Rules.** One YAML file per language, `decks/<lang>/<lang>-phonetics.yaml`
    (kind `phonetics`, a new file kind, see "Phonetic rules files" in
    [Deck-Format](Deck-Format)): ordered regular-expression rules, each with a
    named `source`. Only well-attested rules are in: Spanish has eleven
    (nasal place assimilation, /b d ɡ/ as approximants, /s/ voiced, dental
    /t d/), Hindustani four and Bengali two (nasal place assimilation
    only), because the broad `ipa` of those two already writes the dental
    stops, aspirates, flap and nasal vowels. A rule left out is not a claim
    it does not exist. A card the rules leave unchanged gets no `phonetic`
    (its broad form in brackets would claim a precision nobody checked);
    `--bracket-unchanged` writes them anyway. The owner decides which.
  - **Not verified.** The rules and their `source` citations were written
    from memory of the literature and Wikipedia's phonology pages and are
    not checked against the works; nobody has run the tools on a deck. The
    Wiktionary licence's attribution wording was not read (the plan's
    earlier warning stands); the credit is the tool's `wiktionary` source and
    this page.
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
| 12 | extIPA and VoQS: a mention only | one note in the course's script guide, "How the IPA works": the Extensions to the IPA exist for disordered speech and VoQS for voice quality, and where to read them (the 2025 and 2016 charts below). No deck, no cards, no drills |

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
| extIPA and VoQS | a mention only, in the script guide (owner, 2026-10-26: "just mention extIPA and VoQS") | none |

Examples take their languages from the course's tags (Hindustani, Bengali,
Telugu, Spanish and others), as the existing cards do; where the app has no
language with the sound, another language is used, as the cards already do.

**The extra decks (owner, 2026-10-26: "the extra decks needed for IPA").**
Proposed names and order, each a deck in `decks/ipa/` with an English layer,
new card ids only; the eleven existing decks stay as they are.

| Deck | Holds |
|---|---|
| `ipa-what` | what the IPA is, why it was made, how it is built |
| `ipa-notation` | brackets (`/ /`, `[ ]`, `< >`), broad and narrow, how to read a transcription |
| `ipa-terms` | the glossary: one card per term, with its image and its contrast |
| `ipa-place` | the places of articulation, one card each, with the diagram |
| `ipa-manner` | stop, nasal, trill, tap, fricative, approximant, affricate |
| `ipa-phonation` | voiced, voiceless, breathy, creaky, aspiration (voice onset time) |
| `ipa-nasal-lateral` | oral and nasal; central (median) and lateral |
| `ipa-airstream` | pulmonic; ejective and implosive; clicks |
| `ipa-vowel-dimensions` | height, backness, rounding, length, nasalisation |
| `ipa-secondary` | palatalised, velarised, labialised, pharyngealised; labial-velar |
| `ipa-suprasegmentals` | stress, tone, length, intonation |
| `ipa-chart` | the whole chart read by its axes |

Where an existing deck already teaches the symbols (places, breath,
retroflex, vowels), the new deck teaches the dimension and refers to those
cards by `ref`; a symbol is still taught once (ipa-path.yaml's rule).

**Terms (owner, 2026-10-26: "all terminology, basically").** `ipa-terms`
defines every technical term the course uses, each as a card with a plain
definition, an image where one was found (never one of ours), and an example
sound contrast (`sounds: true` and `false`). **The rule (Proposed):** a term
a card's notes use has a card in `ipa-terms`, and its card comes before the
first card that uses it; a test in `tools/test_ipa_course.py` checks both.
The IPA chart's own vocabulary (its place, manner, airstream, height,
backness and tone lists, read from the IPA's interactive chart on 2026-10-26)
is the spine; the list below is the author's start, to be completed against
every note in the course:

| Group | Terms |
|---|---|
| The units | phoneme, allophone, minimal pair, broad and narrow transcription, diacritic, tie bar and ligature, syllable |
| Articulators | lips, teeth, alveolar ridge, hard palate, soft palate (velum), uvula, pharynx, epiglottis, larynx, vocal folds, glottis, tongue tip, blade, body and root |
| Places | bilabial, labiodental, dental, alveolar, postalveolar, retroflex, palatal, velar, uvular, pharyngeal, epiglottal, glottal; labial-velar, labial-palatal |
| Manners | plosive (stop), nasal, trill, tap or flap, fricative, lateral fricative, approximant, lateral approximant, affricate |
| Airstream | pulmonic, egressive and ingressive, **ejective, implosive, click** (non-pulmonic) |
| Phonation | voiced, voiceless, aspirated and unaspirated, breathy voice, creaky voice, voice onset time |
| Oral and nasal; central and lateral | oral, nasal, central (median), lateral |
| Vowels | close, close-mid, open-mid, open; front, central, back; rounded and unrounded; diphthong, nasalised vowel, length |
| Secondary articulation | palatalisation, velarisation, labialisation, pharyngealisation, coarticulation |
| Prosody | stress, tone (level and contour), intonation |
| The extensions | extIPA and VoQS: named and explained in a line each in the script guide, not taught |

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

  **Not found in the first search** (the second, below, found most): voicing
  and aspiration, tone, minimal pairs, the airstream mechanisms, lateral and
  the nasal-versus-oral contrast.
  **Second search (Commons categories), 2026-10-26:**

  | For | Files and licence as listed |
  |---|---|
  | Voicing and aspiration | `Vot.svg` (voice onset time, public domain); `Bilabial plosives English.svg`, `… French.svg`, `… Mandarin.svg`, `… Thai.svg` (the same contrast in four languages, CC0) |
  | Airstream | `Ipa-chart-consonants-nonpulmonic.png` (the non-pulmonic chart, CC BY-SA 3.0); `Doke … nasal click.svg` (clicks, CC BY-SA 4.0) |
  | Lateral | `Lateral-l-variation.svg` (CC BY 3.0) |
  | Nasal | `Bilabial Nasal.png` (public domain) |
  | Tone | `Amoy tones.JPG` (public domain), `Teochew tones.svg` (CC BY-SA 3.0) |
  | **Audio**, a recording per sound | Commons holds recordings for ejectives, implosives, clicks, laterals, nasals and aspirated consonants (`Alveolar ejective plosive.ogg`, `Voiced bilabial implosive.ogg`, `Velar click.ogg`, `Alveolar lateral approximant.ogg`, `Alveolar nasal.ogg` and many more), CC BY-SA 3.0 or 4.0, some CC0. They fit "optional sound for both" examples (Plan-Ipa-Course) |

  Still not found: stress, a sagittal diagram for the lateral, breathy and
  creaky phonation, and a diagram for ejective and implosive airstreams.

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
| 5 | (Fields, validator and both tools are built, 2026-10-30; the runs per language are not.) The `phonetic` and `phonetic_source` fields: format, validator, `tools/import_phonetic.py` and `tools/derive_phonetic.py` (Sonnet), then a release; then Haiku runs the import per language (one pull request each on `decks-next`, one Sonnet review each), then the rules per language | the validator accepts both fields; every Wiktionary form is imported; each remaining card has a rules form marked `rules`; the app reads the source |
| 6 | The rest of the languages in the owner's order | each one as in step 4 |
| 7 | Pronouncing-words decks | after step 5, and after B1 for the path position |

Estimate (mine): steps 1 to 3 about 30 to 50 hours of content and 6 to 10 of
code if cards need no new field; one language's phonology deck 8 to 14 hours;
the `phonetic` field and import tool 10 to 16 hours. Confidence: low.

## Still open

1. ~~Derive or store the narrow form?~~ Decided: take it from Wiktionary, rules for the rest, a field says which (section 1). Built 2026-10-30: the field is `phonetic` with `phonetic_source`; the accent per form is not stored (only the course's variety is taken).
2. **Who writes it?** CLAUDE.md gives decks to Haiku; the IPA course was
   built by Sonnet (ADR-0041). Sonnet: costs more. Haiku: phonetics is
   where a weaker model invents, and one review may not catch it.
3. **Who reviews it?** A bilingual reviewer cannot check phonetics. A
   phonetician: not yet found. Without one, everything ships `unreviewed`.
4. **Which variety per language.** Decided 2026-10-30 for bn, hi and es (section 1, "Built"); the others when their import runs. Original question: (for Bengali, Standard Colloquial of
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
