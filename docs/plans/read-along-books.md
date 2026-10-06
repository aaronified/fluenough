# Plan: read-along books, with questions on the page you are on

Written 2026-10-06.

## What the owner asked

> can add a couple no copyright books in pdf format, that users can download
> and read along, while the app asks questions based on the page they are
> on. there can be multiple levels of these books. the books must be
> interesting and varied in terms of theme.

## What exists

- **Reading passages** (ADR-0019): a passage deck holds short texts with
  questions, drilled as reading and listening. Bengali's comes from Sahaj
  Path, and Telugu has one from Diddubatu.
- **The rules for texts** (#99): quoted lines only from works in the public
  domain, a source for every checkable claim, and a speaker's review before
  anything ships. #104 tracks classic literature.
- **Deck downloads** (`decks-from-github.md`) will fetch a language's files
  from the repository, which is how a book's PDF can reach the phone too.
- **B1 plans** (`b1-plans.md`) mark where A1, A2 and B1 end on each path;
  books can sit at those levels.

## The feature

1. **A shelf of books per course**, on the Decks tab, each with:
   - its cover, title, author and year, and a line on what it is about;
   - its level (A1, A2 or B1) and its theme;
   - its size, and Download.
2. **Varied themes,** so that each course's shelf mixes, for example:
   - folk tales and fables;
   - humour and nonsense verse;
   - adventure;
   - everyday life and childhood;
   - nature;
   - a life story.
3. **Levels:**
   - **A1 and A2:** retellings of public-domain stories in simple language,
     written for the app, so that the words match the course;
   - **B1:** the original text of short public-domain works.
4. **Read along:**
   - The learner reads the PDF, in their own PDF app or in the app (to
     decide).
   - They tell the app the page they are on, with a page stepper, and it
     remembers it.
   - For that page, the app asks questions:
     - what happens on it, by choosing;
     - words from it, with the line they are in;
     - its culture, where the page has some.
   - The new words on a page can join the learner's cards, as the import
     plan's words do (`import-text.md`).
   - Pages read show as done.
5. **Our own PDFs.** The questions are keyed to page numbers, so each book
   is a PDF the repository makes from the public-domain text, with a fixed
   layout. A tool, `tools/make_book.py`, typesets it from the text and
   records which lines fall on which page. The PDF is versioned with its
   question deck, so a page always matches its questions.

## Rights

A book is used only if it is in the public domain both in India and in the
United States, where GitHub serves it:

- **India:** the author died more than 60 years ago (Copyright Act 1957,
  s. 22), so before 1966 for 2026.
- **United States:** published before 1931, for 2026.
- **Its country of origin,** for a book from elsewhere, such as Spain for a
  Spanish book.

The retellings for A1 and A2 are new writing under the decks' own licence.
The source edition of each text is recorded, as #104 asks.

## Candidates, to verify

Named as starting points only. Each one's rights and fit need checking
before it is chosen (confidence: medium on authors and dates, low on the
publication dates' US status):

| Course | Book | Author, death | Theme |
|---|---|---|---|
| Bengali | Tuntunir Boi (1910) | Upendrakishore Ray Chowdhury, 1915 | Folk tales |
| Bengali | Abol Tabol (1923) | Sukumar Ray, 1923 | Nonsense verse |
| Assamese | Burhi Aair Sadhu (1911) | Lakshminath Bezbaroa, 1938 | Folk tales |
| Telugu | Diddubatu and other stories | Gurajada Apparao, 1915 | Everyday life |
| Hindi | Short stories published before 1931 | Premchand, 1936 | Village life |
| Spanish | A work from Project Gutenberg's public-domain list | — | — |

Marathi, Kannada and Gujarati need their own search.

## What it takes

1. **The format:** a `kind: book` file per book, with its PDF's path,
   level, theme, source edition and, per page, its questions and words. The
   validator checks that every page with questions exists in the PDF.
2. **The tool:** typesetting and the line-to-page map.
3. **The app:**
   - the shelf;
   - downloading the PDF (with deck downloads);
   - opening it;
   - the page stepper;
   - the questions per page;
   - progress.
4. **Content:** a couple of books per course to start, as the owner said,
   each with its questions, reviewed by a speaker.
5. **Tests:**
   - the format and the validator;
   - the page-to-questions mapping;
   - the stepper;
   - progress;
   - a book whose PDF is missing.

## Order

After deck downloads, which the PDFs are fetched with, and the B1 plans,
which give the levels.

## To decide

- **Reading the PDF:**
  - in the learner's own PDF app, which keeps the app simple;
  - or in the app, which needs a PDF package (`pubspec.yaml`, to
    coordinate) but can follow the page by itself.
- **The books,** per course, and how many to start with.
- **Retellings** for A1 and A2, or originals only.
- **Where the PDFs live:** in the repository with the decks, or attached to
  releases, since each is a few megabytes.
- **New words from a page** joining the learner's cards: always, on a tap,
  or never.

## Estimate

| Part | Hours |
|---|---|
| Format, validator, typesetting tool | 4–6 |
| The app: shelf, download, stepper, questions, progress | 6–8 |
| An in-app PDF viewer, if chosen | 2–3 |
| Each book: text, retelling where needed, questions per page | 4–8 |

Confidence: low for content; medium for the app.
