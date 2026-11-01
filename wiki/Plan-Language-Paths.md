# Plan: language paths, pacing by difficulty, and every language in the scheme

Source of truth: this wiki page.


Written 2026-10-05.

**Later plans change how courses are written, and are current where they
differ from this one:**

- decks are a core and a layer per native language (built; see
  `docs/DECK-FORMAT.md`, "Core and layer files");
- a course is a phrasebook, then words, then rules, then sentences, and a
  lesson's new items come in that order (`words-rules-sentences.md`);
- "Writing the planned decks" in `b1-plans.md`.

So the parts that write or reorder courses (#298, #300, #301, #350) wait
for #392 and #413.

## What the owner asked

> this is the language path planned. all of the languages mentioned will
> need to be added. the existing languages will need to be adjusted to fit
> the scheme, and the rest will be generated as per the scheme.

The scheme is in `language-paths-scheme.md`, word for word. It earlier came
up as "we will also have a different pacing for different languages."

## Corrections to the scheme's figures

From the current FSI list, the State Department's, as search results quote
it. I did not open the page itself:

- **German** is in Category II at **36 weeks, 900 hours**, with Malay,
  Swahili, Indonesian and Haitian Creole. So its multiplier is ×1.5, not
  ×1.25, and the scheme's tiers II and III merge. 750 hours is the figure on
  older lists.
- **Nepali, Tamil, Telugu and Somali** are on the FSI list, at 44 weeks,
  1,100 hours. Their tier is confirmed, not inferred.

The other figures check out:

- 0.5 h × 365 = 182.5 h a year;
- 600 ÷ 182.5 = 3.3 years, … 2,200 ÷ 182.5 = 12.1;
- the multipliers are hours ÷ 600.

## Target level

Decided with the owner: **a full course takes a learner to CEFR B1, about
ILR 1+**, independent in daily life. A1 and A2 are milestones along the
path.

- **Words:** B1 needs roughly 2,500–3,000 words a language (Milton and
  Alexiou, 2009, from learners of French and Greek; confidence medium).
  Today's Indian courses teach 450–680 vocabulary cards, and Spanish 41.
  So each course grows about fivefold, with grammar and listening to match.
- **ILR and CEFR:** there is no official equivalence. ILR 1+ ≈ B1 and
  ILR 3 ≈ C1 are the usual approximations.
- **Pacing:** the scheme's FSI hours lead to ILR 3, far past B1. Its tiers
  and phase lengths still set the pacing, but a course ends at B1. Where B1
  falls among the phases is to decide.

## What exists

- **Eight languages:** Hindi, Bengali, Assamese, Marathi, Gujarati, Telugu,
  Kannada (52–60 files each) and Spanish (41 cards and one grammar deck).
  Japanese has a hiragana deck, kept but hidden.
- **Paths** (ADR-0013) are units of decks, in order. Today every Indian
  language follows one template:
  - first words, sounds, grammar differences;
  - five themes, each with its grammar;
  - then the script, numbers and the rest.

  The script units are skipped by a learner who learns without the
  alphabet (ADR-0023).
- **Pacing is the same for every language:** a lesson teaches nine new words
  a day (three easy, three medium, three hard, ADR-0024), and reviews are
  whatever is due. There is no daily time budget.
- **Scripts:**
  - the validator already knows Latin, Cyrillic, Greek, Arabic, Hebrew,
    Devanagari, Bengali, Gujarati, Gurmukhi, Odia, Telugu, Tamil, Kannada,
    Malayalam, Sinhala, kana, kanji, hanzi, Hangul and Thai, and a language can be
    right to left (`rtl`);
  - but the only scripts shipped are Devanagari, Bengali, Gujarati, Telugu,
    Kannada and Latin.
- **Readings and IPA** come from `tools/transcribe.py`, which knows the seven
  Indian languages and Spanish only.

## The scheme, in the app

1. **A language's tier.** Its language block gains its FSI hours. The
   multiplier is hours ÷ 600.
2. **Phases.** Each unit of a path names its phase: Foundations, Core,
   Functional, Expansion or Sharpening. A phase lasts its base length times
   the multiplier:

   | Language (×) | Foundations | Core | Functional | Expansion |
   |---|---|---|---|---|
   | Spanish (×1.0) | 14 days | 28 days | 42 days | 91 days |
   | German, Malay, Swahili (×1.5) | 21 | 42 | 63 | 137 |
   | Hindi and tier IV (×1.83) | 26 | 51 | 77 | 167 |
   | Japanese and tier V (×3.67) | 51 | 103 | 154 | 334 |

3. **Pacing.** New words a day = the phase's new cards ÷ its days, within
   the ten minutes the day gives to new material. That replaces the fixed
   nine a day.
4. **The 30-minute day:** ten minutes of review, ten of new material, and
   ten of listening and speaking from day one. Each block is sized by time,
   using how long each kind of question takes this learner, from the review
   log's answer times.
5. **Variants**, where the scheme says to choose: Spanish, Portuguese,
   Norwegian, Arabic, Irish, Vietnamese, Malay, Quechua, Punjabi, Serbian.
   **The learner chooses** (owner's answer). Each variant is a set of decks
   of its own, so each of these languages carries more content.
6. **The common start for all:** sounds → greetings → survival phrases →
   numbers → pronouns. Then the family's own order.
   - **The script still comes late** (owner's answer), as in today's
     courses, and not straight after the sounds as the scheme puts it.
   - Until then, words are read in their romanisation, and a learner who
     learns without the alphabet still skips the script (ADR-0023).
   - For Japanese, Korean, Thai and the others with a new script, this means
     starting in romaji, Revised Romanization or the like.

## Fitting the existing languages to it

This is judged from the decks' names, not from a full read of their
content.

- **Indo-Aryan (Hindi, Marathi, Gujarati, Bengali, Assamese):**
  - The path is reordered to the scheme's grammar order. The script keeps
    its place, late. Numbers move up into the common start.
  - Missing everywhere: subjunctive, relative–correlative clauses, and the
    oblique case as a step of its own.
  - Ergative: Marathi, Gujarati and Assamese need it; Hindi has
    `grammar-ne`.
  - Bengali and Assamese need classifiers. Bengali needs compound verbs. Its
    gender deck becomes natural gender only, and it skips agreement and the
    ergative.
- **Dravidian (Telugu, Kannada):** these were built on the Indo-Aryan
  template, with articles, compound and conjunct verbs, and postpositions.
  They need suffix logic, cases in place of postpositions, verbal
  participles, relative participles and conditionals, in the Dravidian
  order. Honorifics exist as registers and addressing.
- **Spanish** needs a whole Romance course: ser/estar early, articles and
  gender, the present regular and irregular, prepositions, object pronouns,
  reflexives, preterite and imperfect, future and conditional, subjunctive,
  compound tenses. It also needs its variant chosen.

## The languages to add

The scheme names 47 (Serbian/Croatian as one). Eight exist, so 39 are new.

| Family | New languages | New scripts for the app |
|---|---|---|
| Indo-Aryan | Urdu, Punjabi, Odia, Nepali | Perso-Arabic (Nastaliq, RTL), Gurmukhi and Shahmukhi, Odia |
| Dravidian | Tamil, Malayalam | Tamil, Malayalam |
| Classical | Sanskrit | — |
| Romance | Portuguese, Italian, French, Catalan | — |
| Germanic | German, Swedish, Norwegian, Yiddish | Hebrew (RTL) |
| Slavic | Russian, Polish, Serbian/Croatian | Cyrillic |
| Greek | Greek | Greek |
| Agglutinative | Turkish, Finnish, Hungarian, Basque | — |
| Celtic | Irish | — |
| Semitic | Arabic, Hebrew | Arabic and Hebrew (RTL) |
| East Asian | Mandarin, Cantonese, Japanese, Korean | Hanzi (simplified and traditional), kana and kanji, Hangul |
| Southeast Asian | Vietnamese, Thai, Filipino, Malay | Thai |
| African | Swahili, Hausa, Somali | — |
| Andean | Quechua | — |
| Constructed | Esperanto | — |

Each new language needs what an existing one has:

- a path, with its B1 plan: the units up to B1, their milestones and
  planned sizes, which the app reads to show completeness
  (the language picker, built in #443 and #626);
- vocabulary and grammar decks;
- facts, 30 or more (AGENTS.md);
- sounds, number rules, a script guide, and its romanisation.

## The generated paths (#959)

`tools/gen_planned_paths.py` writes the path file of every planned language
except the sign and fiction ones: the 26 living languages (Portuguese,
Italian, Catalan, Swedish, Norwegian, Yiddish, Russian, Polish,
Serbo-Croatian, Greek, Hebrew, Finnish, Hungarian, Turkish, Basque, Irish,
Arabic, Cantonese, Thai, Vietnamese, Filipino, Malay, Swahili, Hausa, Somali,
Quechua) and the nine ancient and reconstructed ones: Vedic Sanskrit,
Latin, Old English, Middle English, the Archaic, Classical and Koine stages
of Ancient Greek, Pali and Ashokan Prakrit. Each path holds the whole plan to B1 from the scheme's template: the
sounds, the first four themes, the script where the language has one to
learn, then the other themes woven with the grammar of the language's family
(cases for Slavic, suffixes and harmony for Turkic and Uralic, root and
pattern for Semitic, tones for Cantonese, Thai, Vietnamese and Hausa, noun
classes for Swahili, ergativity for Basque, mutations for Irish). Grammar
topics are generic category names, never a stated rule of the language. Only
unit 1 is written (`<code>-phrasebook` and `<code>-first-words`, 10 words);
every other unit is `planned:` with placeholder listening and reading
passages, to be reworded when written. Egyptian, Sumerian, Mycenaean Greek,
Proto-Indo-European and Imperial Aramaic are not in the generator: they are
taken out of this change, and their path and first-words files stay as main
has them (Aramaic has no decks on main, so its files are removed), until the
validator's phrasebook rule is settled (their phrasebooks would be below its
15-card minimum).

Living languages use the plan's sizes (A1 700, A2 900, B1 1,200 words); the
nine ancient ones set `levels` (Latin 600, 800 and 1,100; Vedic 300, 400 and
600; Old English 400, 600 and 800; Middle English 350, 500 and 700; the three
Greek stages 400, 600 and 900, Koine 400, 700 and 1,000; Pali and Prakrit 400,
600 and 900) and leave out themes of modern life. The generator also turns unit 1 of the courses
that already had a full all-planned path (German, Esperanto, Maithili,
Malayalam, Odia, Punjabi, Tamil, Lojban, Interslavic) into the written unit
and touches nothing else of them. `--check` fails when a file differs from the
generator. To change a language's plan before its decks exist, edit the
generator's data and run it again; once a unit is written, edit the path by
hand and take the language out of the generator.

## What the app needs for new scripts

- **Fonts** for Nastaliq, Hebrew, Arabic, Thai, hanzi, kanji and Hangul, where
  Android lacks them.
- **Right to left** checked end to end for Urdu, Arabic, Hebrew and
  Yiddish.
- **Scripts without spaces** (Thai, Chinese, Japanese) break the split into
  words that word-order tiles, lessons and the listening tier use. Their
  cards need their words given.
- **A romanisation standard per script.** ISO 15919 covers the Indian
  scripts. The others need their own: pinyin, Jyutping, Hepburn, Revised
  Romanization, and standards for Thai, Cyrillic, Greek, Hebrew and Arabic.
- **Grading folds** per script:
  - Arabic short vowels, Hebrew niqqud and Greek accents can be ignored;
  - whether tones in Vietnamese and pinyin are ignored is to decide.
- **Readings and IPA:** `transcribe.py` knows only eight languages. For the
  rest, the IPA can come from Wiktionary (`tools/import_wiktionary.py`, #518), which covers
  European languages better than Indian ones.
- **Voices and recognition** vary by phone. Several of these languages,
  such as Quechua, Hausa, Somali and Esperanto, may have no Android voice, so
  listening and speaking would be off for them.

## Order, and what comes first

- Deck downloads first (done, ADR-0037): new languages then reach learners without
  an app release, and the APK does not grow with them.
- `tools/import_wiktionary.py` (#518) before the new languages, for their IPA.
- The 30-minute day can use FSRS (done: ADR-0033) for the review block, and the
  listening tier (`listening-in-context.md`) for the listening block, but
  needs neither to start.

## Quality

No speaker of any of these languages checks the content here. It would be
written by agents, validated, and marked for review, as the existing
courses are. Languages with less written material, such as Quechua, Hausa,
Somali and Odia, carry more risk of errors.

## To decide

Decided with the owner: the learner chooses a variant; new languages are
built **one full course at a time**; the script comes late everywhere.

- **The order** of the new languages: by family, by tier, or by number of
  speakers.
- **Variants:** which ones each language offers, such as Mexican and
  Spain Spanish, and which comes first.
- **Several languages:** whether the 30 minutes is split between them, or is
  30 minutes each.
- **Serbian and Croatian:** one course with two scripts, or two courses.
- **Romanisation** standards for the scripts beyond ISO 15919.
- **Sanskrit texts:** which editions of the Hitopadeśa and the Gītā, in the
  public domain.

## Estimate

| Part | Hours |
|---|---|
| The app: tiers, phases, pacing, the 30-minute day, variants | 11–16 |
| New scripts: fonts, RTL, word splitting, folds, romanisation | 25–40 |
| Fitting the seven Indian languages to the scheme | 28–42 |
| Taking the seven Indian languages to B1, about 2,000 more words each, at 40–60 h each | 280–420 |
| Spanish as a full course to B1 | 50–75 |
| 39 new languages, full courses to B1 one at a time, at 50–75 h each | 1,950–2,925 |
| A second variant, where a language offers one, per variant | 25–40 |

These scale today's rate: about 10–15 hours for a course of about 500
vocabulary cards. The listening tier and the extra word-order tiles grow
with the cards.

- Before the first new language, with the existing courses at B1: about
  394–593 hours, or roughly 66–99 working days of 6 hours.
- Then each new language: about 50–75 hours, or 8–13 days.
- All of it: about 2,350–3,500 hours, plus the variants.

Confidence: low. The content hours are the biggest unknown, and the scripts
need checking on a phone.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
