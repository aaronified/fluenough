# Plan: building sentences by reasoning

Written 2026-10-05.

## What the owner asked

> Sentence-building by reasoning (Language Transfer): give an English
> sentence; learner builds it from known pieces.
>
> add this once user learns to build sentences

On where the sentences come from, the owner answered:

> for en native decks, a set of english sentences, of different types,
> active/passive voice, direct/indirect speech, conjugations, etc, include
> some hard ones. for other native language decks, same thing for them.

Then, on cloze:

> also, show cloze options. for sentence building. put the meaning on top,
> then leave out one word in the sentence and let users fill that. in
> script or in ISO transcription.

## What exists

- **Word order** (`Ask.rearrange`) puts a sentence card's own words in order.
  The learner never builds a sentence they have not seen.
- **Grammar** is taught in tables and in sentence cards, along the path.
- **Every deck today teaches from English,** so the English bank comes first.
  Bengali and Hindi speakers learn from English decks for now (owner's
  ruling in `decks-from-github.md`).

## What it takes

1. **A bank of sentences per native language**, starting with English:
   - each with a permanent id;
   - its type: statement, question, negative, command; present, past,
     future; continuous, perfect; active or passive; direct or indirect
     speech; conditional; relative clause; comparison;
   - the grammar steps it needs;
   - a difficulty, with some hard ones that combine types (a passive in
     reported speech).

   About 200–300 sentences to start.
2. **Each course answers the bank:** for each sentence, its translations
   into the language, every accepted order, with reading and IPA. These are
   in a file per course, keyed by the bank's ids.
   - The validator checks that every word in an answer is taught earlier on
     the path, so the learner builds from known pieces.
   - A sentence a course cannot yet answer is left out.
3. **When it appears:** once the learner has learnt to build sentences,
   after the path's first sentence-grammar unit. Each sentence comes once
   every grammar step it needs is taught.
4. **How it is asked:** the English sentence is shown; the learner writes the
   sentence:
   - typed, or with tiles from the known words, as the word-order plan
     makes them (`word-order-tiles.md`);
   - or by speaking, where the phone can hear the language.

   Graded against the accepted answers, with the mistake explained
   (`explain-mistakes.md`).
5. **Cloze, a step before the whole sentence:**
   - the meaning, the sentence in the learner's language, on top;
   - under it the sentence in the language learned, with one word left
     out;
   - the learner fills the gap, in the script or in ISO Latin letters, by
     the Script / Latin letters switch, as typed answers do;
   - graded as a typed answer for that one word;
   - the gap is any word the learner has learnt (owner's choice), so the
     sentence is an item of its own, asked again with another gap.

   It needs no bank: every sentence card and every example sentence a deck
   already has can be asked this way.
6. **Scheduled** as a production pair of its own, so it is reviewed. Under
   `skill-model.md`, a sentence is produced in Write.
7. **Tests** for the bank, the validator's known-words check, unlocking by
   grammar step, grading with free word order, and cloze: one word left
   out, the gap filled in the script or in Latin letters, and graded as
   that word.

## To decide

- **Cloze:**
  - typed only, or also chosen from a few words as its easier grade;
  - whether it comes before the bank's sentences, from the first sentence
    cards, or with them.
- Typed, tiles or spoken, or each in turn as the sentence is learnt.
- How many bank sentences per grammar step.
- The format of the bank and of a course's answers. A new file kind needs
  the owner's answer (AGENTS.md).

## Estimate

| Part | Hours |
|---|---|
| The app: the bank, unlocking, the drill, grading | 4–6 |
| The English bank, 200–300 sentences | 4–6 |
| Answers for the eight courses, about 1–2 hours per 50 sentences | 32–96 |

Banks in other native languages come once decks are taught from them.
Confidence: medium for the app, low for the content.
