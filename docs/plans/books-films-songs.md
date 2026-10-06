# Plan: books, films and songs you bring, with questions on them

Written 2026-10-06.

## What the owner asked

> at later stages, can ask students to see particular films / listen to
> songs and then ask them questions on them (the films / songs will not be
> provided), including questions on the culture.

> can add a couple no copyright books in pdf format, that users can download
> and read along, while the app asks questions based on the page they are
> on. there can be multiple levels of these books. the books must be
> interesting and varied in terms of theme.

Then:

> or we can ask users to get the books on their own as well. all these and
> the songs and the movies are optional and the user will get to choose from
> a carousel as per their interests. the catalogue will be curated (as we
> will need to ask questions).

Decided with the owner:

- **Learners get the works themselves,** books included. The app ships no
  PDFs, video or audio.
- **Book questions are keyed to chapters,** since editions differ.
- **At A1 and A2,** the shelf offers real children's books and songs,
  nothing written by the app.

## What exists

- **Reading passages** (ADR-0019): a deck of short texts with questions.
  The same question kinds suit questions on a work the app does not hold.
- **The rules for culture content** (#99):
  - names and titles are fine;
  - lines are quoted only from public-domain works;
  - every checkable claim has a source;
  - a speaker reviews it before it ships;
  - religion, caste and politics are handled with care.

  #103 (films) and #104 (literature) track parts of this.
- **#169** starts a course from the words in famous titles. This plan is the
  other end: whole works, once a learner can follow them.

## The shelf

1. **A carousel per course,** "Beyond the course", on the Decks tab, off the
   path. Everything on it is optional and never holds back the path.
2. **Filtered by interest:**
   - the learner picks themes they like: folk tales, humour, adventure,
     romance, history, nature, music, cinema, and so on;
   - the carousel shows matching items at or below their level first.
3. **Each item:**
   - its kind (book, film or song);
   - title, its own name, creator and year;
   - level, themes and length;
   - a line on why it is worth it;
   - where to find it: a link to a free copy for public-domain works
     (Wikisource, Project Gutenberg), or "find it where you watch or buy";
   - nothing is played, downloaded or quoted, apart from public-domain
     lines.
4. **Curated:** an item is on the shelf only once its questions are written,
   sourced and reviewed by a speaker.

## Questions

- **Books, by chapter:**
  - the learner says which chapter they have read up to, and the app
    remembers it;
  - each chapter has its questions: what happens, words and phrases from
    it, and its culture.
- **Films:** by part, e.g. the first and second halves, or as a whole.
- **Songs:** as a whole: what it is about, its words, its place in the
  culture.
- **Answered by choosing,** since the app cannot check what was read,
  watched or heard. A question on a word can also be typed.
- **Words worth keeping** can join the learner's cards on a tap, with the
  chapter or song as their source, as `import-text.md`'s words do.

## Levels

| Level | What the shelf offers |
|---|---|
| A1–A2 | Children's picture books and stories, and well-known songs, real works chosen for simple language |
| B1 | Novels, short stories, films and popular songs |

## The format

- A `kind: shelf` file per course lists the items, each with:
  - its id, kind, title, own name, creator and year;
  - level, themes and length;
  - its source for the facts given;
  - a free link where there is one.
- Each item's questions are a passage deck (ADR-0019). Its passage is the
  chapter, part or song's name and a short note, not its text. A book's
  questions name their chapter.
- The validator checks:
  - every item has questions and a source;
  - every chapter named exists in the item;
  - no question quotes a work not marked public domain (by a flag the
    reviewer sets).

## What it takes

1. The format and the validator.
2. The app:
   - the carousel and the interest picker;
   - an item's page;
   - chapter progress;
   - the questions;
   - adding a word to cards.
3. Content, per course: a first shelf of about six items across the levels
   and themes, each with its questions, sourced and reviewed.
4. Tests:
   - the format and the validator;
   - filtering by interest and level;
   - chapter progress;
   - the questions;
   - a word joining the cards.

## Order

After the B1 plans (`b1-plans.md`), whose levels the items carry, and after
deck downloads, which the shelf's files come with.

## To decide

- **The first items** per course, and who suggests them.
- **The themes** offered in the interest picker.
- **Films:** questions by part, or for the whole film only.

## Estimate

| Part | Hours |
|---|---|
| Format and validator | 2–3 |
| The app: carousel, interests, item page, chapters, questions | 6–8 |
| Each item: facts, questions, sources | 2–5, a book more than a song |

Confidence: medium for the app; low for content, which depends on review.
