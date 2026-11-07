# Persona: Hindi AMATEUR (hi)

Knowledge: the 100 words of the wordfreq Hindi list (`list_words` in `../hi-amateur-100.json`),
with their authored glosses in `hi-glossary.json`. Its card-level set is `known_generous`.
Nothing else is known.

Strategy when a word is unknown, in order: elimination (rule out an option whose gloss is a
known word's meaning and not the prompt's word), then similarity and cognates only where the
prompt is written (as the Spanish amateur, P3 and P6 in `../README.md`), then random ties
(seeded). Heard prompts give no text to compare, so they get elimination and chance only.

Two variants are run: `es`-style `hi-amateur-wordfreq` with cognates, and
`hi-amateur-wordfreq-nocognate` without P3 and P6 (chance guessing only).

Fidelity: near chance outside the known set, except where the cognate variant is named.
