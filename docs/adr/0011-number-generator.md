# ADR-0011: Generated numbers are spelled from each language's rules, and not logged

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Prices, bus numbers and years need numbers beyond the two number decks
(#54). The maintainer decided on a generator, not a deck: it makes number
cards on the fly. It must never produce a number whose words the learner
was not taught. Hindi and Bengali have a word of their own for every number
up to 99 and the beta teaches only 1–20 and the tens, so they can spell 2020
but not 2026. Telugu builds 21–99 from parts, so it can spell any.

The issue names this ADR 0010; that number went to the theme decks.
Two questions were left to this ADR:
- whether generated cards are scheduled, and under what ids
- where the generator sits in the theme path

## Decision

- **A rules file per language**, `decks/<code>/<code>-numbers.yaml`,
  `kind: numbers`. It holds the words for 1–99 the decks teach, and the
  hundreds and thousands. Hundreds and thousands also have a form for when
  more follows, where the language changes it (Telugu's వందలు → వందల), and
  a flag for building 21–99 from tens and units (Telugu). Each value is one
  spelling or a list, the usual one first; the others are accepted as
  answers.
- **The speller is language-free.** `spellNumber` in `lib/core/numbers`
  joins the parts of a number from 1 to 9,999. A number whose last two
  digits have no taught word is not spellable, so it is never generated.
- **The validator enforces "taught".** Every word a rules file spells with
  must appear in a card of that language's `numbers-1-20` or `numbers-big`
  deck. Forms the generator needs were added to those decks as cards:
  Bengali's joined hundreds, and Telugu's వందలు, వందల, నూట, వేలు and వేల.
- **Practice only (maintainer's decision).** Answers to generated numbers
  are not written to the review log and not scheduled; numbers are picked at
  random from those that can be spelled. Nothing is permanent, so logging
  can be added later without touching rule 1 or 9.
- **Placement (maintainer's decision):** its own row in each course's theme
  list, right after `numbers-big`, drawn like a deck. Its second line says
  the numbers are random and not recorded.
- **The drill.** A practice session is ten different four-digit numbers.
  They take the skills the learner has on, in turn:
  - Recognition shows the words, then the digits. The learner rates the
    recall; the rating buttons show no interval, because nothing is
    scheduled.
  - Production shows the digits and grades the typed words as any card's
    target, near misses included.
  - Listening speaks the words and the learner types the digits, only with a
    voice. Digits are right or wrong: 2021 is not a slip for 2020. Spaces
    and commas are ignored.

  The summary counts the answers as usual.

## Consequences

- A language gets generated numbers by adding one data file. Its words
  cannot drift from its decks, because CI checks them.
- Number practice does not count toward stats or the streak.
- Words are typed in the language's script. The rules carry no readings, so
  typing a number in Latin letters (#47) waits for them.
- Years are spelled as numbers (1950 as 'one thousand nine hundred fifty').
  The "nineteen hundred fifty" reading, common in Hindi and Bengali, is not
  generated. The calendar decks' notes teach it.
- 21–99 words for Hindi and Bengali, and so numbers like 2026, wait for a
  deck that teaches them.
