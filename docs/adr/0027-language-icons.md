# ADR-0027: Each language's icon is the first letter of its own name

- **Status:** Accepted
- **Date:** 2026-10-04

## Context

A language's chip, on the Decks tab and in Progress, showed the first
letter of the language's first card. Most courses open with a greeting,
so the chips read न, ন, న, ನ side by side. The owner: "fix the icons for
each language, you are using the same 'na' a lot". Asked what an icon
should show, they chose "the first letter of its own name".

## Decision

A language block may name its `icon`: the first letter of the language's
own name. The decks give हि for Hindi, म for Marathi, বা for Bengali, অ
for Assamese, తె for Telugu, ಕ for Kannada, ગુ for Gujarati, and Es for
Spanish (Español), where one Latin letter would say little. Every deck
file of a language names it. A chip shows the icon, or, for a language
that names none, the first letter of its first card, as before.

## Consequences

- `icon` sits in every deck file's language block, as the other language
  fields do. A new language must name its icon, or its chip falls back to
  its first card.
- Assamese অ is also Bengali's first vowel letter, but the two chips
  differ: Bengali shows বা.

## Alternatives considered

- **A table of icons in the app**: a language is data (AGENTS.md).
- **A letter only that language uses** (ৰ for Assamese, ळ for Marathi):
  Hindi and Bengali have none.
- **The two-letter code** (HI, BN): Latin letters, not the language's own
  script.
