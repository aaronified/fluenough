# Plan: a phrasebook, then words, then rules, then sentences

Written 2026-10-07. **With the B1 plans** (`b1-plans.md`), owner's order:
paths are rewritten then anyway. No interim change to lessons before it
(owner's choice).

## What the owner asked

> Check the current deck pacing of telugu. It feels i am learning way too
> many telugu sentences even before having a decent vocabulary. Is there any
> research on the learning levels before moving on to the next stage?

Then:

> I think ideally we should not teach sentences beyond ultra basic phrases
> (greetings and i don't know telugu types) before teaching all their words
> and grammar should start with word forms, conjunction, preposition etc
> rules. The current preposition teaching was just 3, and always with the
> same words, not in a rule form. I have completed 6 decks now. And feel lost
> instead of feeling like i made progress.

Decided with the owner:

- **A small phrasebook** is taught whole from the first lesson: 15–25
  survival chunks per language.
- **Any other sentence waits** until every word in it, by its base word, and
  every rule it uses are known.
- **Known means mastered:** the learner recalls a word or rule right on
  80–90% of their recent answers to it, as in mastery learning.
- **Grammar is taught as rules,** starting with word forms, endings and
  postpositions, and conjunctions, practised across the words the learner
  knows.
- **When:** with the B1 plans.

## What exists

Measured on Telugu (main, 2026-10-07):

- **The first eight units, before the script,** hold 95 single words, 47
  sentences and phrases, and 77 grammar cells. Unit 1 is 6 words and 16
  sentences.
- **Every lesson takes three "hard" items in nine** (`lessonItems`,
  ADR-0024): phrases, sentences of three words or more, and grammar cells.
  The pool is the next two unfinished units, interleaved, so sentences come
  from the first lesson on.
- **The sentences' words are mostly untaught:** 0% known in every sentence
  of the first six lessons; 0–50% by lesson 12, counting exact word forms.
- **Grammar decks are fixed phrases, not rules:**
  - "Endings for in, to and with" is three phrases: గదిలో (gadilō, in the
    room), బడికి (baḍiki, to school), అమ్మతో (ammatō, with mother);
  - the postpositions deck is 10 fixed phrases, never applied to other
    nouns. The rule is only in the notes.
- **What the owner had finished:** six decks, about 33 single words and 32
  sentences or phrases.

## The research

No study gives a fixed number of words to learn before sentences, but the
evidence points one way. It was checked from abstracts and search records,
not full texts. Confidence: High means the citation and finding were both
seen in an abstract or repository record; Medium means the finding came
from a summary.

| Finding | Source | Confidence |
|---|---|---|
| Understanding a text needs 95–98% of its words known. 80% was the lowest coverage tested | Hu & Nation 2000; Laufer & Ravenhorst-Kalovski 2010; Schmitt, Jiang & Grabe 2011 (no sharp threshold: comprehension rises with coverage) | High |
| Listening needs about 95% | van Zeeland & Schmitt 2013 | Medium |
| Guessing a word from context needs about 95% of the others known | Liu & Nation 1985 | Medium |
| The more unknown words in a sentence, from 0 to 7, the worse it is understood, especially beyond 5 | de la Garza & Harris 2017 | High |
| For new words, a translation, alone or in one short sentence, works as well as or better than a longer context | Prince 1996; Laufer & Shmueli 1997; Webb 2007; Webb, Yanagisawa & Uchihara 2020 (meta-analysis) | High |
| Recalling a meaning beats inferring it from context, for retention | van den Broek et al. 2018; Mondria & Wit-de Boer 1991 | High / Medium |
| Fixed chunks help from the start, and are later broken into parts and reused | Wray 2002; Myles, Hooper & Mitchell 1998 | High |
| A first "survival" syllabus of about 120 words and phrases | Nation & Crabbe 1991 | High |
| Mastery learning (80–90% before moving on) raises scores by about half a standard deviation, at a cost in time; the effect on standardised tests is weaker | Bloom 1968; Kulik, Kulik & Bangert-Drowns 1990; Slavin 1987 | High |
| A grammar structure can only be taught once the learner is ready for it. No sequence exists for Telugu | Pienemann 1984, 1998; Spada & Lightbown 1999 | High / Medium |
| Deliberate study should be about a quarter of a course; input and fluency work need almost every word known | Nation 2007 (Four Strands) | High |
| The CEFR gives no word counts; for English, A1 is under 1,500 words and B1 is 2,750–3,250 | Council of Europe 2001; Milton & Alexiou 2009 | Medium |

What follows for this plan (inferences):

- A sentence whose words are all known is what the evidence supports. The
  owner's rule, that every word and rule is taught first, meets it. In a
  sentence of four to six words, a single unknown word already means only
  80–83% known.
- Phrasebook chunks need not wait for their parts.
- Words are best taught first as words, with their translations.
- "Known" should be counted by stem and ending, not by whole word: a
  Telugu word can hide several new parts. The coverage figures were measured
  on English and are untested for Telugu.

## The design

### 1. A phrasebook

- **A card marked `phrasebook: true`** is taught whole and is never held
  back:
  - greetings, thanks, sorry;
  - yes and no;
  - "I don't know Telugu", "I don't understand", "please speak slowly";
  - and the like.
- **15–25 per language,** taught in the first lessons.
- Its words are not counted as taught by it: each word comes again as a
  word, and its base words (`b1-plans.md`) say which.

### 2. Words

- Every word is taught as a word before any sentence that uses it, with its
  base form, reading and meaning. A unit's words come first in that unit.

### 3. Rules

- **A rule card** is a new kind of item. It holds:
  - the rule's name;
  - its explanation, with readings, e.g. "-లో (-lō) means *in*; it joins the
    noun's oblique stem: ఇల్లు (illu) → ఇంట్లో (iṇṭlō)";
  - the forms it makes.
- **Taught,** then **practised as a table over known words:**
  - the rows are the words of the right kind the learner has been taught
    (nouns for endings, verbs for person endings);
  - the columns are the rule's forms (-లో, -కి, -తో, -నుంచి);
  - each cell is a grammar question.

  So a postposition is practised on every known noun, not on three fixed
  phrases. The grammar-table format already expands a table into cards;
  what is new is the rule card, and rows filled from known words.
- **First come word forms:**
  - nouns: plural, the oblique stem, the case endings and postpositions;
  - pronouns and their forms;
  - verbs: person and tense endings;
  - then conjunctions.

### 4. Sentences

- **A sentence names the rules it uses** (`rules: [te-rule-lo, …]`), beside
  its base words (`bases`, `b1-plans.md`).
- **It unlocks** once all of them are known, at the mastery bar. Until then
  it is not offered, and does not hold back its unit.
- **Reviews never wait:** the bar decides only when new sentences appear.
- **Sentences are built from what is known,** so most are practice, not new
  material.

### 5. Lessons

- The fixed three of each difficulty goes.
- A lesson's new items are the next eligible ones in the path's order:
  - phrasebook;
  - the unit's words;
  - the rules whose words are taught;
  - the sentences now unlocked.
- **Progress shows in those terms:** words, rules and sentences unlocked, so
  that a learner sees what they can now build.

### 6. Paths

Each unit of a B1 plan is its theme's words, then the rules they need, then
its sentences. Each rule counts once toward the plan's grammar topics.

### 7. Existing decks

Converted as each language's B1 plan is written:

- `first-words` splits into the phrasebook and words;
- each grammar deck becomes rule cards and tables;
- its sentences are tagged with their rules and bases, and move behind
  them.

## What it takes

1. **Format:**
   - the `phrasebook` mark;
   - rule cards;
   - `rules` on sentences;
   - tables whose rows come from known words;
   - the parser, the validator, `docs/DECK-FORMAT.md`, and an ADR.
2. **The validator:**
   - every rule a sentence names exists;
   - every phrasebook list is 15–25 cards;
   - a sentence's words resolve to cards or bases (`b1-plans.md`).
3. **Lessons:**
   - no fixed quota;
   - the unlock gate, with the mastery bar per word and rule;
   - rule tables filled from taught words.
4. **The rule card's drill:** taught, then its table's cells as grammar
   questions.
5. **Content,** per language with its B1 plan:
   - the phrasebook;
   - the word-form rules;
   - sentences tagged.
6. **Tests:**
   - a sentence held back until its last word and rule are taught;
   - the phrasebook never held back;
   - a rule's table growing as nouns are learned;
   - lessons without the quota.

## To decide

- **The exact mastery bar,** between 80% and 90%, and how many recent
  answers it counts.
- **How a rule makes its forms:**
  - from each word's stem, with exceptions listed on the word's card; or
  - every form listed per word.

  Telugu's oblique stems (ఇల్లు → ఇంటి-) make the first harder to get right.
- **How many cells of a growing table** a lesson asks at once.

## Estimate

| Part | Hours |
|---|---|
| Format, parser, validator, ADR | 4–6 |
| Lessons: gate, no quota, rule tables | 4–6 |
| Rule card drill | 2–3 |
| Content per language: phrasebook, rules, tagging | 4–8 each |

Confidence: medium for the app; low for content.
