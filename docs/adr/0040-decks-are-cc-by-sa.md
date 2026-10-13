# ADR-0040: Decks are CC BY-SA 4.0; the app's code stays GPL-3.0

- **Status:** Accepted (owner, 2026-10-13, #506: "Relicense decks to CC
  BY-SA"; approval 4: "Approve as proposed"; the ADR is written "In the
  relicensing issue", #510).
- **Date:** 2026-10-13
- **Supersedes:** ADR-0003. Its decision for the app's code, GPL-3.0 with
  an App Store Distribution Exception, is carried over here unchanged, and
  its reasoning still stands.

## Context

ADR-0003 licensed the app. The decks declared their own licence per file,
and every deck in the repository was `CC0-1.0`, public domain.

The card data planned on #506 (`docs/DECK-FORMAT.md`, "Card data") takes
much of its content from outside: word data from Wiktionary (#518),
recordings from Wikimedia Commons with it, and frequency counted from each
language's Wikipedia (#516). Wiktionary and Wikipedia are CC BY-SA, and so
are many Commons recordings. None of it can go into a CC0 deck: CC BY-SA
requires attribution and that derived work carry the same licence.

## Decision

1. **Deck content is CC BY-SA 4.0, with attribution.** Every deck in the
   repository declares `license: "CC-BY-SA-4.0"`, and so does the deck
   template. New decks contributed to the repository are under it too.
2. **The app's code stays GPL-3.0 with the App Store Distribution
   Exception** ([LICENSE](../../LICENSE),
   [LICENSE-EXCEPTION.md](../../LICENSE-EXCEPTION.md)), exactly as ADR-0003
   decided and for its reasons.
3. **CC0 content already given stays usable.** CC0 allows any reuse,
   relicensing included, so the decks' existing content needs no new
   permission from the contributors who gave it.
4. **Data from outside names its source, per item** (owner: "Per item").
   Each item taken from Wiktionary, Wikimedia Commons, Wikipedia or Tatoeba
   names where it came from. The shape of that per-item `source` comes with
   the card data fields (#511, #512, #513, #516, #517) and the Wiktionary
   import (#518).
5. **The app credits the sources.** Settings, Sources, names CC BY-SA 4.0
   for deck content, and credits Wiktionary, Wikimedia Commons, Wikipedia
   and Tatoeba when the decks use their data.
6. **The change is made before any Wiktionary or Tatoeba data goes in.**

The pictures stay Noto Emoji under Apache-2.0
([assets/pictures/LICENSE](../../assets/pictures/LICENSE)).

## Consequences

- Anyone may reuse the decks, commercially or not, with attribution and
  under the same licence. A fork of the decks stays open, as a fork of the
  code does.
- Wiktionary (CC BY-SA 4.0), Wikipedia counts (CC BY-SA) and Tatoeba
  (CC BY 2.0 FR) data may now be used, each with its source named. Commons
  recordings each keep their own licence and speaker credit.
- A deck added from a file in the app is the learner's own and may declare
  any licence; the validator still accepts any SPDX identifier in
  `license`.
- Leipzig Corpora lists are not used: their terms conflict (#516).
  IndoWordNet is not used either (owner: "Don't use it").
