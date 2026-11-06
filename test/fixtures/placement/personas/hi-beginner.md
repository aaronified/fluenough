# Persona: Hindi BEGINNER (hi, Hindustani course, Devanagari)

Knowledge: the first 25 words of the wordfreq Hindi top-100 list
(`list_words[0:25]` of `../hi-amateur-100.json`) that have an authored gloss in
`es-glossary.json`-style file `hi-glossary.json` (authored, flagged). Nothing else is
known.

Strategy when a word is unknown: no elimination, no similarity, no cognates. Draw
uniformly over the options with the seeded RNG.

Answer rule: if the prompt word (written or heard) is in the known set and an option
matches its authored gloss, pick it. Otherwise pick uniformly at random.

Fidelity: answer from these files only. Do not use your own Hindi to decide.
