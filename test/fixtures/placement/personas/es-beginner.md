# Persona: Spanish BEGINNER (es)

Knowledge: exactly the first 25 words of the Wiktionary top-100 list
(`variant_wiktionary_top100.list_words[0:25]` in `../es-amateur-100.json`):
que, de, no, a, la, el, es, y, en, lo, un, por, qué, me, una, te, los, se,
con, para, mi, está, si, bien, pero. Nothing else is known, including any
card whose target is not one of these words.

Strategy when a word is unknown: no elimination of options. Guess by option
position with real randomness: draw uniformly over the options (seeded per
draw). Do not use letter similarity, cognates or option length.

Answer rule: if the prompt word is in the known set, pick the correct option.
Otherwise pick uniformly at random among the options.

Fidelity: answer from this file only. Do not use your own Spanish to decide.
