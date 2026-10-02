# ADR-0016: Each script has a guide to its recurring features

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

A script deck drills letters one by one. But much of what throws a
learner from English isn't any one letter. It's a few ideas that come
back in letter after letter, and that feel obvious to a native reader
because they've always been there. English has none of them. The
maintainer named Bengali's examples: the headline (মাত্রা) most letters
hang from, and the small knot in ক, খ, ত, ল. Others are the
vowel signs written before a letter but read after it, the ways two
consonants join, and letters that differ by one dot.

Duolingo opens its character lessons with a tips page before the chart
(docs/market-research.md, "Script lessons"). The maintainer chose, on 2
October 2026:
- a guide page plus a short drill deck;
- shown once before the first letter, and from a Tips button;
- each script's guide in its own file per language.

## Decision

- **A guide file per language,** `kind: script`, beside its decks:
  `decks/bn/bn-script.yaml`. It has a title, an introductory paragraph,
  and the features. Each feature has:
  - a name in English;
  - its term in the language, if it has one, and the term's reading,
    shown under it when Show romanisation is on, as on a card;
  - one example drawn large;
  - what to look for;
  - the letters that share it.
- **The drill shows it once,** before a session with script cards in a
  language whose guide is unseen. A session with two such languages shows
  both, in the order it reaches them. Each page ends in "Start the
  letters", which records that guide as seen (`script_guides_seen`) and
  goes on to the next guide or the drill. The session is built after the
  last guide, so the reading isn't timed as the first answer. Today, a
  deck, learning new cards and revising all start the drill this way, so
  all of them show it; number practice has no script cards.
- **A script deck's page has Tips,** which opens the guide again with
  Done. Opening it there doesn't count as seen.
- **The drill deck is ordinary data.** Each language's path puts a short
  deck of first words to read in its first unit. Those words use only
  the letters, and put the features and look-alikes to work. No new
  drill is needed.
- **The validator checks the guide:**
  - the id and the folder match the language;
  - it has a name, an intro and features;
  - feature ids are unique;
  - each feature has a name, an example and text;
  - any term, reading or letters are quoted text, and a reading has a
    term.
- **Only the term has a reading.** The example and the letters are shapes
  to look at, not words to read, and the text gives a sound where it
  matters, as a card's notes do.

## Consequences

- A new script gets its guide as data. No code changes.
- The guide is read, not drilled. What it teaches is drilled by the
  letters and the reading deck.
- Guides are content for a native speaker to check, as decks tagged
  `unreviewed` are. The guide has no tag of its own; its PR says so.

## Alternatives considered

- **Inside the first script deck,** as a long description and notes. No
  new file kind, but no structure: no sections, no example per feature.
- **Features as drill cards only.** A note after a card is the wrong
  place to meet an idea for the first time.
- **Only on a Tips button.** The learner who most needs it, on the first
  day, wouldn't know to look.
