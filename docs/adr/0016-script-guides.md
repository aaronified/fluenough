# ADR-0016: Each script has a guide to its recurring features

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

A script deck drills letters one by one. But much of what throws a
learner from English isn't any one letter. It's a few ideas that come
back in letter after letter, and that feel obvious to a native reader
because they've always been there. English has none of them. The
maintainer named Bengali's examples: the headline (মাত্রা) most letters
hang from, and the small knot (গুটলি) in ক, খ, ত, ল. Others are the
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
  - its term in the language, if it has one;
  - one example drawn large;
  - what to look for;
  - the letters that share it.
- **The drill shows it once,** before a session whose first script card
  is in a language with an unseen guide. The page ends in "Start the
  letters", which goes on to the drill and records the guide as seen
  (`script_guides_seen`). Today, a deck and placement all start drills
  the same way, so all of them show it.
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
  - any term or letters are quoted text.

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
