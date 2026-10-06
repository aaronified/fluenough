# Plan: a B1 plan in every path

Written 2026-10-06. **After `skill-model.md`, before deck downloads**
(owner's order).

## What the owner asked

> Every deck path will have a B1 plan from now on. The app will use this
> explicitly.

Asked what it should entail, the owner decided:

- **Completeness:** words drive the percentage, and grammar topics are shown
  beside it: "18% of B1 · 12 of 30 grammar topics".
- **Themes per level** come from the current CEFR descriptors.
- **Units not written yet** show to learners as "Coming".
- **When:** the plans are written before deck downloads, so the deck index
  is designed around them.

## What exists

- A path (`decks/<lang>/<lang>-<native>-path.yaml`, ADR-0013) is a list of
  units, each a list of existing deck ids in teaching order, plus the decks
  that need the alphabet. Telugu's has 30 units.
- Nothing marks a level, and nothing records what is still to write.
- `language-paths.md` sets B1 as the target, about 2,500–3,000 words, and
  estimates 280–420 hours of content for the seven Indian languages to get
  there. Today they teach 450–680 vocabulary cards each, and Spanish 41.

## What a B1 plan is

Written in the path, by whoever writes the course, and read by the app
unchanged:

1. **Every unit up to B1**, written or not, in teaching order.
2. **A unit not written yet** is `planned`, with its future deck id and its
   theme or grammar topic.
3. **Each unit's planned size** in words (`words`). A grammar unit names its
   topic (`grammar`), which counts toward the grammar figure, not the words.
4. **Milestones:** `milestone: A1`, `A2` and `B1` on the unit where each
   level ends.

```yaml
units:
  - decks: [te-en-family, te-en-grammar-be, "*"]
    words: 45
    grammar: [be]
  - decks: [te-en-work, te-en-grammar-demonstratives, "*"]
    words: 45
    grammar: [demonstratives]
    milestone: A1
  - planned: { id: te-en-health, theme: health, words: 60 }
  - planned: { id: te-en-grammar-conditional, grammar: conditional }
    milestone: B1
```

Units after the B1 mark, if any, are written as today. Units with the
alphabet stay where they are; they count neither words nor grammar.

## The skeleton, from the CEFR descriptors

The CEFR's global scale describes each level by what a learner can do
(Council of Europe, 2001, kept in the 2020 Companion Volume). Paraphrased:

| Level | Can do | Themes and grammar it implies |
|---|---|---|
| A1 | Use everyday expressions for concrete needs; introduce themselves and others; ask and answer about where they live, people they know and what they have | Greetings, self and family, home, numbers, basic needs; present tense, questions, pronouns |
| A2 | Understand frequent expressions on personal and family information, shopping, local geography and work; exchange information on routine matters; describe their background and surroundings | Shopping, directions, work, daily routine, time and calendar; past, future, comparison |
| B1 | Follow the main points of clear standard speech on work, school and leisure; handle most situations while travelling; write simple connected text; describe experiences, hopes and plans, and give reasons and opinions | Travel, health, services, feelings, opinions, events and news; subordinate clauses, conditionals, reported speech, the language's own B1 grammar |

The descriptors describe abilities, not word lists, so the skeleton turns
each into themes and grammar topics. It is written once and shared. Each
language adds its family's grammar in the scheme's order
(`language-paths-scheme.md`).

## Films, songs and books: off the path

The owner first asked for films and songs "near the bottom" of the path,
then chose to make them, with books, an optional shelf the learner picks
from by interest: `books-films-songs.md`.

- They are **not units** of the B1 plan and never hold back the path.
- Each item on the shelf carries a level, A1, A2 or B1. Songs and films come
  at every level; books only at B1, for learners who learn the script. The
  finale, a great film without subtitles, is offered at the B1 mark.
- They count toward neither words nor grammar topics. The picker can show
  them apart, e.g. "2 films, 1 book done".

## Where the app uses it

| Where | How |
|---|---|
| Language picker (`language-picker.md`) | "18% of B1 · 12 of 30 grammar topics": words = Σ min(a unit's words, its plan) ÷ Σ planned words up to B1; grammar = topics with a written unit ÷ topics planned |
| Decks tab | Planned units show greyed, with "Coming", in their place; they cannot be started |
| Lessons and Today | Planned units are skipped |
| Achievements (`achievements.md`) | The A1, A2 and B1 badges come from the milestones |
| Hours per language (`hours-per-language.md`) | "Hours left" counts down to the end of the B1 plan |
| Pacing (`language-paths.md`) | The scheme's phases line up with the milestones |
| Deck downloads (`decks-from-github.md`) | The index carries each plan and the counted words, so the picker shows completeness before a download |

The words a unit has are always counted from its decks: distinct
vocabulary cards. Script decks, grammar tables and learners' own decks
(`"*"`) are left out.

## What the validator checks

- **Errors:**
  - a path without its A1, A2 and B1 marks, in that order;
  - a unit up to B1 without a planned size or grammar topic;
  - a planned id that does not follow deck naming, or names a deck that
    already exists.
- **Warnings:**
  - a unit with more words than planned, since then the plan needs raising;
  - planned words up to B1 outside 2,000–3,500, as a sanity check. Nothing
    is stored.
- When a planned deck's file appears, it counts as written. Its `planned`
  entry is turned into `decks` in the same change.

## What it takes

1. **Format:** the path parser, the validator, `docs/DECK-FORMAT.md`, and
   an ADR.
2. **The skeleton**, from the descriptors above.
3. **A plan for each of the eight courses.** Telugu and Kannada are written
   together with their reorder to the Dravidian order, which
   `language-paths.md` calls for.
4. **"Coming"** on the Decks tab, and lessons skipping planned units.
5. **Tests:** the parser, each validator rule, the counts, and the Decks tab
   and lessons with planned units.

## To decide

- The word sizes per level: how the 2,500–3,000 words split between A1, A2
  and B1.
- Whether a planned unit also names its listening and reading passages, or
  only words and grammar.

## Estimate

| Part | Hours |
|---|---|
| Format, parser, validator, docs, ADR | 2–3 |
| The skeleton | 2–3 |
| Plans for the seven Indian languages | 7–14 |
| Spanish | 2 |
| "Coming" on the Decks tab, lessons skipping planned units | 1–2 |
| **All** | **14–24** |

Writing the plans does not write the content. The content to reach B1 is
`language-paths.md`'s estimate. Confidence: medium.
