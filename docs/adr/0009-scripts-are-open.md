# ADR-0009: `script` is an open list, checked with a warning

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

A deck's `language.script` names its writing system. It decides whether a
card needs a `reading` (romanisation) shown under its target, and it will
guide rendering. The validator treated it as a closed enum of eleven names,
so Bengali, Gujarati and Telugu, three of the five starter languages, could
not declare their script honestly (#27). They would have had to say `other`.

A closed list also breaks the project's promise: a language is data, never
code. If adding Amharic needs a change to a Python constant first, a new
language is not only deck files.

The app's parser already accepts any script name.

## Decision

The validator keeps a list of the scripts it knows, now including the major
Indic ones (`bengali`, `gujarati`, `gurmukhi`, `odia`, `telugu`, `tamil`,
`kannada`, `malayalam`, `sinhala`). A lowercase name that is not on the list
is **accepted with a warning**. A value that is not a lowercase name (a
number, an empty string, `Bengali`) is still an error.

`LanguageInfo.needsReading` is unchanged: every script except `latin`,
`cyrillic` and `greek` expects a reading. An unknown script therefore gets the
cautious answer.

## Consequences

- A contributor can add a language in a script the validator has never heard
  of without touching code. The warning tells a reviewer to check the name,
  and to add it to the list if it is real.
- A typo such as `devanagri` passes with a warning instead of failing. That
  is the cost of an open list. The warning names the known scripts, so the
  typo is easy to spot.
- The parser and the validator stay in step: the parser never rejects a deck
  the validator accepts.
