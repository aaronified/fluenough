# ADR-0018: A card id names the language, and a word is one card

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

A card id named its deck, so it named its course too: `bn-en-groceries-0013`.
Scheduling state was keyed by `(deck, card, mode)`. So the same word in two
decks was two cards with two schedules. ফল is taught in the script unit and
again in groceries, and a learner who knew it from the first met it as new
in the second. The maintainer wants each theme to cover its important words,
repeats included, so there will be more of these.

The maintainer decided, on 3 October 2026 (#143):

- "Make it card id and make card id independent of decks. Then repeat words
  get the same card id and its done."
- "Cards should be named after the language itself. If i learnt telugu via
  english and then picked it up again via bengali, i do not want to learn
  the same stuff."
- A word is written once, and other decks list it by ref, "with overrides,
  as needed for the card id to work across native languages".
- Grammar cells move to the same native-language-agnostic scheme. Some decks
  have cards for one native language only; they use the same numbering.
- Every deck-shape change goes in one pass, so this takes in #144 too:
  alternative forms in a grammar cell.
- Nothing old is kept: the maintainer is the only user, testing.

## Decision

- **A card id is the language learned and a number:** `bn-0042`. Numbers are
  per language, shared by every course that teaches it, and taken in order;
  `python3 tools/validate_decks.py --next-id bn` prints the next free one.
  The validator requires the shape and refuses an id written twice in the
  language.
- **A word is written once.** Any other deck of the language, in any course,
  lists it as `- ref: bn-0042`. The ref may give the native side: `native`,
  `alt_native`, `reading`, `notes`, `tags`, `examples` and `modes`. The
  card's `target`, `alt_target`, `pos`, `gender` and `audio` stay its own. A
  deck taught from the language the card was written for takes the card's
  native side where the ref gives none. A deck taught from another language
  takes nothing from that side and must give its own `native`.
- **One schedule per card and mode.** Scheduling state is keyed by
  `(card_id, mode)`. A card listed in two decks is learned in both, and a
  session takes it once. `reviews` still records the deck each answer was
  given in.
- **Grammar cells drop the course.** A cell's id is
  `<language>-<deck name>-<key>-<slot index>`, the deck name being the deck
  id without its course: `bn-en-grammar-present` expands to
  `bn-grammar-present-kora-0`. The same table taught from another language
  expands to the same cards.
- **A grammar cell may list its forms (#144):** `["এলাম", "আসলাম"]`. The
  first is shown, and every one is accepted.
- **Every deck was renamed once,** in path order, and words already repeated
  in a language became refs. A homograph stays two cards: দিন "please give"
  is not দিন "day". So does a spelling drill, where কে "ke, k with the e
  sign" is not the question word কে "who". Schema 4 rebuilds `card_states`
  under the new key. Reviews under the old ids match no card, like a retired
  card's.

## Consequences

- Rule 1 of AGENTS.md stands for the new ids: permanent, never renumbered or
  reused. This rename is its second exception, after #51.
- Two pull requests that add cards to one language can take the same number.
  The validator fails the second to land, and it takes the next free ones.
- A deck no longer reads on its own where it lists refs. The validator
  resolves them from the repository's decks even when one file is checked.
- A card's gloss can differ by deck, since a ref may give its own native,
  but its schedule cannot. A recognition review from either deck counts for
  both.
- A course from another native language can list every card of an existing
  one and give only the native side, and its learners keep what they already
  know.

## Alternatives considered

- **Keeping the ids and dropping only the deck from the key.** That was the
  cheapest change, but an id would still name a deck it may not live in. It
  would also name the native language, and a course taught from another
  language could not share it.
- **A full copy of the card in each deck, required to match.** Each file
  would stay self-contained, but every edit would have to be made in every
  copy. It would also leave no way to give another language's gloss.
- **One card bank per course, with decks listing ids only.** There would be
  no duplication at all, but every deck edit would touch two files, and a
  deck would no longer be readable on its own.
