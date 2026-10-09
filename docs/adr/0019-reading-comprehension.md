# ADR-0019: Reading comprehension is passages whose questions are scheduled like cards

- **Status:** Accepted. SM-2 is superseded by ADR-0033 (FSRS-6): where this
  record says SM-2, read FSRS-6.
- **Date:** 2026-10-03

## Context

Fluenough drilled words and sentences, one at a time, but never a text
(#98). After a theme's words, a learner should read a short passage that
uses them, or hear it, and answer a few questions. #98 left two questions
for an ADR: whether a passage is scheduled once or each question is, and
whether passages appear on the Decks tab or inside sessions.

The first Bengali passages come from two books in the public domain,
Rabindranath Tagore's *Sahaj Path*, part 1 (1930), and Sukumar Ray's *Abol
Tabol* (1923). The owner asked for them to be credited: "mention somewhere
that we are using sahaj path for the bengali teaching", "in the app as well
as in the readme", and then "same for aboltabol. zero misquote, mentions in
app (when the card appears, same for sahaj path) and the readme." Both are
older Bengali, and the owner warned that they "may put the user in a
difficult pickle if they have had no primer on sadhu and chalit."

The coordinator decided the format, the scheduling, where passages appear,
the drill and the sources, on 2 and 3 October 2026.

## Decision

- **A reading deck is a deck,** `kind: reading`, with `passages` in place of
  `cards`. Each passage has a permanent id, a title, sentences of text and
  reading, 2 to 4 questions, and optionally a source, the theme it follows
  and a glossary. Each question has a permanent id, a prompt keyed by the
  learner's language as a fact's text is (`en` required), 2 to 4 options
  keyed the same way or none for true or false, and the answer. The
  details are in docs/DECK-FORMAT.md, "Reading decks".
- **Each question is a card.** The parser makes every question a
  `QuestionCard`, a `Card` that also carries its passage, so it is
  scheduled, recorded, counted and backed up as every card is: its own
  SM-2 state per mode, in the existing review log, keyed by the question's
  id, a card id of the language, and the mode (ADR-0018). No table changes. Its target is the passage's
  first sentence, so a list of cards, such as the leeches, shows which
  passage it is.
- **A new mode, `reading`, and a skill for it.** Reading has its own switch
  in Settings and its own feature, `drillReading`, which ships. The mode is
  declared before `listening`, so that a new question is read before it is
  heard. A card cannot take it.
- **Heard is listening.** Where the phone has a voice for the language and
  listening is on, a question is also scheduled in `listening`: the
  passage is read aloud and its text is hidden until the question is
  answered. It is the listening skill in every way: its switch, off for one
  language, the pause, and Can't listen now.
- **A passage's questions keep together.** Its new questions are introduced
  all at once or not at all: when its first fits under the day's cap, the
  rest come too. In a session, every question of a passage follows its
  first, those heard before those read, so the text is never seen before it
  is heard. The passage shows on its own once, then its questions one by
  one, as Duolingo Stories puts its questions after the scene. It shows on
  its own again only when it comes back in the other mode.
- **A choice is right or wrong, and recorded at once.** Right is Good,
  grade 4, not Easy, since a choice can be guessed; wrong is 1. The log's
  answer is the option's number, or `true` or `false`, as the deck writes
  them.
- **The drill.** The passage page shows the title, each sentence with
  TargetText and a button to hear it, and the reading when Show
  romanisation is on. A question page shows the question in the best
  language the learner speaks that it is written in (#53), large choices,
  and the passage again under them to look back at. Then the feedback:
  right or wrong, and the right answer. Screen readers read the passage in
  the deck's language, and a question in the interface's, or in its own
  when the two differ.
- **The glossary is behind a Words button.** For the older Bengali of the
  books, a passage may gloss words: as written, today's form, its reading,
  its meaning and a note. Words opens it in a sheet, wherever the passage's
  text shows: on the passage page, under each question, and for a heard
  passage once the text is revealed. This was chosen over showing it under
  the passage after the questions: a learner needs a word's modern form
  while reading, where they first meet it, and a sheet keeps the passage
  in view, as KOReader's dictionary pop-up does (docs/market-research.md,
  "Reading with look-up"), and the drill's layout as it is.
- **Sources are data, shown wherever the text is.** A passage's `source`,
  or else its deck's, shows on every screen of its passage and questions,
  small and in full, and on the deck's page. Settings has a Sources
  section, a row per language, gathered from the decks' `source` fields,
  so a new book needs no code; its wording, "passages for reading", is in
  the arb. The README names both books, as static text.
- **Text is kept letter for letter.** The parser and the validator never
  trim, normalise or correct a passage's text or a glossary's words. The
  validator warns of spaces at the ends, and never of Unicode
  normalisation.
- **Reading decks are ordinary decks.** They are on the Decks tab, their
  page has the counts, the skills and a preview of the passages, and the
  course's path places them in a unit after the theme they use, so their
  new questions come through Today as other new cards do. Placement asks
  nothing of them: a question needs its passage. A unit of nothing but
  reading is known when placement reaches it, as any unit with nothing to
  ask is.
- **The validator** checks the format, and that every glossary word is in
  its passage character for character. It warns, without failing, of words
  in a passage that no deck of the course teaches, glossed words aside, and
  of a passage on the path no later than its theme's deck.
- **Settings remember which skills are off.** `enabled_skills` now lists
  every skill, a switched-off one marked `!`, so that a skill added later
  keeps its default. Settings stored before this change knew every skill
  but reading, so reading is on for every learner who updates.

## Consequences

- The day's cap on new cards can be passed by up to three, to keep a
  passage whole.
- A passage heard and then read in one session shows twice, and so does a
  passage whose questions come back on different days. That is the cost of
  scheduling each question.
- Heard, the text is revealed after each answer and hidden again for the
  next question. By then the learner has heard it, and has seen it once.
- The words warning is noisy for an inflected language: Bengali's পড়ে is
  not the deck's পড়া. It is a list for a content writer to read, not a
  gate.
- Placement cannot tell whether a learner reads well.
- Today's skill tiles do not count reading, as they do not count speaking.
  Today's total does.
- The deck format grew a kind, which DeckParser, the validator and the
  catalog all know about.

## Follow-ups

- **Tap a word to see its card.** It is in #98's description but not its
  acceptance, so it is left for another issue.
- Dialogues (#110) may reuse the passage and its questions.

## Alternatives considered

- **One review per passage.** Simpler, but one hard question would fail the
  whole passage, and an easy one would carry a hard one. Per question is
  what SM-2 can schedule well.
- **A passage returning only when answered badly.** SM-2 decides when each
  question returns, as for every card; no rule of its own is needed.
- **Passages only on the Decks tab, outside sessions.** Then they would
  never be reviewed. As ordinary decks they are both on the tab and in
  sessions.
- **A mode of its own for heard passages.** It would need its own switch,
  pause and voice check, all of which listening has.
- **The question data as fields on `Card`.** `card.dart` is the most shared
  model in the repository; a subclass leaves it alone, as `NumberCard`
  does.
- **The glossary under the passage, after its questions.** Shown too late
  to help with reading.
