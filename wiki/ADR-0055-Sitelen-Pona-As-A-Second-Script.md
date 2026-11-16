# ADR-0055: Toki Pona's sitelen pona is a second script of its cards

Source of truth: this wiki page.

- **Status:** Accepted (owner, 2026-11-16: "Yes, accept MIT for any font.
  Also add sitelen pona decks.")
- **Date:** 2026-11-16

## Context

Toki Pona has a writing of its own, sitelen pona, in which each word is one
glyph. Unicode has no block for it, but the Under-ConScript Unicode Registry
(UCSUR) puts it at U+F1900 to U+F19FF, in the private-use area, and the
open fonts that draw it use those code points. The decks hold Toki Pona in
Latin letters. A learner should be able to choose to read it in either, as a
Hindustani learner chooses Devanagari or Perso-Arabic and a Punjabi learner
Gurmukhi or Shahmukhi.

## Decision

1. **A second script, following the existing pattern.** The script key is
   `sitelen_pona`. A Toki Pona vocab core lists `scripts: ["latin",
   "sitelen_pona"]` in its language block, its `target` stays in Latin, and
   each card and each example gives its sitelen pona under `target_scripts:
   { sitelen_pona: ... }` ([Deck Format](Deck-Format), "A card's other
   scripts"). No new format, no second deck set, and no card id changes. The
   `reading` and the `ipa` stay Latin, as with every other second script.
2. **Written by a tool, not by hand.** `tools/tok_sitelen.py` writes the
   spelling from the registry's word table: one glyph per word (`ali` and
   `ale` the same), a name in a cartouche (U+F1990 and U+F1991 around the
   glyphs of a word starting with each letter), words spaced, punctuation
   kept. A word the table lacks stops the tool. It is deterministic and
   checks that only the added fields differ. The validator checks that the
   spelling has no Latin letter left (`SCRIPT_BLOCKS`).
3. **One font, downloaded with the course.** `decks/fonts/sitelen_pona`
   holds sitelen seli kiwen asuki (Kreative Software, SIL OFL-1.1) subset to
   the UCSUR block, 582 KB, registered in `FONTS` and drawn under
   `FluenoughScript-sitelen_pona` like every script font
   ([ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course)). The font check
   asks about it when the learner says they read sitelen pona; a phone's own
   font never has the glyphs, so the answer is "No" and it downloads. The
   licence rule is widened (owner, 2026-11-16): MIT and other permissive
   licences are accepted for fonts when their text is kept with the font,
   though this one did not need it.
4. **The learner picks.** The Languages you know sheet asks which scripts the
   learner reads Toki Pona in, with a question and an answer for each, as
   for Hindustani.
5. **What stays Latin.** Grammar tables (`pattern`) and reading passages have
   no other-script field in the format, so they are not converted; adding one
   would be a format change and is left for the owner.

## Consequences

- Nothing a learner has changes until they choose the script; the Latin
  cards, ids and history are untouched.
- A later deck run through `tools/tok_sitelen.py --check` keeps the
  spellings in step; CI could run it.
- The glyph variants, long glyphs and combinations the font also offers are
  not used.

## Alternatives considered

- **A second deck set per script.** Rejected: it doubles every id and the
  review history, which the format avoids.
- **A ligature font on the Latin text.** Rejected: the same font can do it,
  but the app would then have no per-card spelling to show, count or check,
  and a screen reader would read the glyphs, not the words.

See also: [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) ·
[Script Fonts Inventory](Script-Fonts-Inventory) · [ADR-Index](ADR-Index)
