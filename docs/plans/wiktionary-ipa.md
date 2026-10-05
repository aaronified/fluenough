# Plan: take the IPA from Wiktionary where it has the word

Postponed to next week (2026-10-04).

## What the owner asked

> The ISO and IPA fields can come in from wikitionary. That will make them
> truthful and I can then claim that in the readme.

Decided with the owner: **Wiktionary's IPA where Wiktionary has the word,
and the tool's for the rest.** The owner has allowed `en.wiktionary.org`
and `kaikki.org` in the cloud environment's network access, and both
answer from a session.

## What Wiktionary can and cannot give

- **IPA:** yes, for many Hindi and Bengali words. Coverage is thin for
  Assamese, Kannada and Gujarati, and phrases and inflected forms are mostly
  missing.
- **ISO 15919 readings:** the owner wants these from Wiktionary or a similar
  source too: "all decks will still get transliteration from wikitionary or
  soemthing" (5 October). Wiktionary romanises each language in its own
  scheme, close to ISO 15919 for some languages and not for others. Its
  romanisations would need converting to ISO 15919 as said, and checking
  against the decks' readings. Readings made in the app are only for
  sentences the learner adds (`in-app-readings.md`).
- **Licence:** Wiktionary is CC BY-SA 4.0; the decks are CC0. Every IPA
  taken from it needs attribution, and those fields are share-alike. A deck
  that takes any says so in its `license` and `source`, and the README says
  which IPA comes from where.

## Steps

1. Download kaikki.org's extract of English Wiktionary, one JSON file per
   language, rather than calling Wiktionary's API once per word.
2. A tool, `tools/wiktionary_ipa.py` (stdlib only), that:
   - matches each card's `target` to an entry;
   - takes its IPA, preferring the standard pronunciation, and turns it
     broad, as the decks write it;
   - writes it in place of the generated one;
   - marks where it came from, as a field such as `ipa_source:
     wiktionary`, or a list in the deck's header.
3. Compare: where Wiktionary and the tool disagree, list the words for
   review instead of overwriting silently. The disagreements are where the
   tool's rules are wrong, and the tool should be fixed too.
4. README and ADR-0025: say which IPA is sourced and which is generated, in
   numbers per language.

## To decide

- Whether a deck may mix CC0 and CC BY-SA fields, or whether every deck
  that takes Wiktionary IPA moves to CC BY-SA 4.0 as a whole.
- What to do where Wiktionary gives several pronunciations: the first, or
  the one closest to the reading.

## Estimate

About 3–5 hours, most of it the comparison and review. Confidence: low,
until the extract's coverage is known.
