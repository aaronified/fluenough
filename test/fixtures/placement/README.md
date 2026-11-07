# Placement fixtures: simulated learners

These fixtures test the placement logic ("Find my level") against simulated
learners. Each simulated learner answers a multiple-choice question with a
decision rule. The rules below are precise enough for another agent to
implement them in Dart.

Files in this folder:

- `es-amateur-100.json`: the known-word sets for the Spanish AMATEUR-100 learner
  (source, rules, known card ids, list words without a card, path position).
- `README.md`: this file, the simulated-learner profiles P1 to P9.

## The sources, and what they do and do not say

**Lexodle (primary).** The owner's word-list source is the Spanish list in
`aaronified/lexodle`, `app/assets/words/es.txt`, at commit `e0b6111`
(Version 0.7.3), retrieved 2026-11-06. The licence is CC BY-SA 4.0
(`app/assets/words/LICENSE.md`), so storing the words is allowed with
attribution. The list is built from wordfreq and filtered to 4 to 8 letters.
**It is not the literal top 100 Spanish words.** Short function words are
missing: de, la, que, el, en, y, a, o, los, se, un, por, con, no, una. The
AMATEUR-100 uses the first 100 entries of the file as "the 100 most common
words", as the owner specified, and records the gap.

**Wiktionary top 100 (sensitivity variant).** The OpenSubtitles-based list on
`en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Spanish1000` (revision
68654381, retrieved 2026-11-06) gives the true top 100, function words
included. The fetched page did not state a licence. Wiktionary content is
normally CC BY-SA, which must be verified before any wider publication. It is
stored under `variant_wiktionary_top100` in the fixture, for comparison only.

## Matching rules (how the known sets were made)

The rules are implemented in a scratch script, not in the repo. They read
`decks/es/es-*.yaml`, skip the sentence and reading decks (their cards are
whole sentences), and use only cards with `kind: vocab`.

- **STRICT.** A card is known when its target, with the articles el, la, los,
  las, un, una, unos, unas, lo removed, is one word exactly equal (accents
  included) to a list word. Example: `la casa` matches `casa`.
- **GENEROUS.** A card is known when the first content word of its target
  equals a list word, or the lemma of that word equals the lemma of a list
  word. A lemma is the `base` in the deck's `bases` field for that surface
  word. A list word with no deck entry is its own lemma. Strict matches are
  always generous matches. Example: `el año` is generous via `años`.

Limits, stated plainly:

- **Lemmas come from the decks only.** The deck does not teach `está` or
  `estoy` as vocab cards, so `está` has no lemma `estar` in the data. A
  learner who knows `está` would also be credited with `estar`. The fixture
  does not credit that. It understates generous knowledge for forms such as
  está, dice, hizo and es.
- **Determiners lemmatise to their masculine form.** `esta` maps to `este`
  through the deck's bases, so `esta casa` counts as generous.
- **Accents matter in the strict rule.** `esta` and `está` are different words.

## Results (2026-11-06)

Lexodle list: 40 strict, 43 generous known cards. 57 list words have no vocab
card, for example `como`, `está`, `esta`, `todo`. Wiktionary list: 40 strict,
57 generous known cards; 45 list words have no card.

The known cards sit mostly in path units 1 to 11 (phrasebook through
`es-quantities`): 26 of the 43 generous cards for the Lexodle list, and 49 of
57 for the Wiktionary list. A sparse tail of matches reaches unit 100. The
amateur's position depends on the cut. Under the 70% rule (first path unit where
the cumulative known generous cards reach 70%), the Lexodle set gives **unit 42**
(`es-things`) and the Wiktionary set gives **unit 8** (`es-core-100`). Known cards are spread
along the path, so no single unit is "where the words run out". Use both values; do not
read one as the truth.

## Simulated learners: decision rules

Each profile answers one question at a time. A question is:

- `prompt`: a Spanish string, for example `estoy durmiendo`;
- `options`: 2 to 4 items, each with a `label` (the text shown, for example
  `dormir (to sleep) — yo`) and its parts: `es` (the Spanish headword),
  `gloss` (the English gloss in parentheses), `cue` (the suffix after the
  dash, here `yo` or `él/ella`);
- `correct`: the index of the correct option.

The profiles use only the question data, the profile's known set, and a seeded
random generator (seed = the learner's draw number). A profile never reads the
correct answer.

- **P1 RANDOM.** Choose one option uniformly at random.
- **P2 FIRST.** Always choose option 0.
- **P3 SIMILAR.** Choose the option whose full label has the highest
  normalised similarity to the prompt, `1 − levenshtein(prompt, label) /
  max(len)`. Ties go to the lower index. (Variant P3-H uses only the headword
  `es`.)
- **P4 ODD-ONE-OUT.** Compare the `cue` fields. If three options share one cue
  and one option differs, choose uniformly among the three. If all cues are
  equal, behave as P1. Rationale (an assumption, not yet checked against the
  bank): if the distractors are built from the same conjugation, the odd cue
  is the decoy and the majority group holds the answer. Verify this on the
  bank before trusting P4's accuracy.
- **P5 LONGEST.** Choose the option with the longest label. Ties go to the lower
  index.
- **P6 COGNATE.** Score each option by the multiset of letters shared between
  its English `gloss` and the Spanish `prompt`, ignoring spaces. Choose the
  highest score. Ties are broken at random.
- **P7 ELIMINATION.** For each option, its `es` headword is ruled out if it
  is a known word for this learner and it is not the prompt's word. Choose
  uniformly among the options not ruled out. If every option is ruled out, or
  none is, choose uniformly among all options. For the AMATEUR-100 this rarely
  rules anything out, because the distractors are rarely on the list.
- **P8 AMATEUR-100.** Uses the known set `known_generous` of
  `es-amateur-100.json` (and `known_strict` for the strict variant). Rules:
  1. If the prompt word, or a word of the correct option's headword, is in the
     known set, answer the correct option. This is the only place P8 uses the
     answer key, and it is restricted to known words. It models knowing the
     word.
  2. Otherwise, play the combined guess. Each of P3, P4, P6 and P7 casts one
     vote: P3 gives 1 to its top option, P6 gives 1 split over its tied top
     options, P4 gives 1/3 to each option in the majority cue group (0 to the
     odd one out), P7 gives 1/k to each of its k surviving options. Choose the
     option with the highest total; ties are broken at random.
  Rule 2 never uses the key. An amateur who does not know a word must be
  near chance on those questions. The check for that is in the report, not
  assumed.
- **P9 MIXTURE.** For each question, pick one of P1 to P8 uniformly at random
  (seeded), then use its rule.

## Worked example: `estoy durmiendo`

The question the owner saw:

```
What does this word mean?  estoy durmiendo
  0  dormir (to sleep) — yo
  1  comer (to eat) — yo
  2  vivir (to live) — yo
  3  escribir (to write) — él/ella
correct = 0 (dormir: "estoy durmiendo" = "I am sleeping", yo form)
```

Scores computed from these rules (the script that computed them is not in the
repo; the numbers can be reproduced from the definitions above):

| Profile | Choice | Correct? | Why |
|---|---|---|---|
| P1 random | any | 25% | uniform |
| P2 first | 0 | yes | by position, a coincidence |
| P3 similar (whole label) | 1 `comer` | no | similarity 0.211 for comer, against 0.136 for dormir (the longer label dilutes it) |
| P3-H (headword only) | tie 0 `dormir` / 3 `escribir` | 50% | both 0.267 |
| P4 odd-one-out | 0, 1 or 2 | 1/3 | cue `él/ella` is the odd one out, so the majority group is picked at random |
| P5 longest | 3 `escribir` | no | 29 characters, longest label |
| P6 cognate | tie 0 `dormir` / 3 `escribir` | 50% | 5 shared letters each ("to sleep", "to write") |
| P7 elimination | any | 25% | none of the four headwords is in the AMATEUR-100 known set, so nothing is ruled out |
| P8 amateur | 1 `comer` | no | totals: comer 1 (P3) + 1/3 (P4) + 1/4 (P7) = 1.58; dormir 1/3 + 1/2 + 1/4 = 1.08; escribir 1/2 + 1/4 = 0.75; vivir 1/3 + 1/4 = 0.58; comer wins |
| P9 mixture | depends on draw | | |

**Which one wins?** On this single question the simplest cues do not beat
chance reliably. P2 wins only by position. P3 and P5 get it wrong, and P8, the
AMATEUR-100 that combines the heuristics, gets it wrong too. The lesson for the
placement test is that a question like this measures the learner's known set,
not guessing skill. The amateur's answers on items outside its known set must
be close to 25% in the report.

## Fidelity checks (to run on the answers)

Per profile and per answer draw, report:

- accuracy by level and unit band (unit ranges 1 to 11, 12 to 40, 41 and up);
- accuracy by question type;
- accuracy on questions about words OUTSIDE the profile's known set. For P1, P7
  and the beginner and amateur personas, this must be within a few points of
  chance (1/number of options). Anything above that is leakage, and it must be
  flagged.

## Hindi (hi, Hindustani course)

- Known lists: `hi-amateur-100.json`. Primary: the wordfreq Hindi top 100
  (`wordfreq.top_n_list('hi', 100)`, wordfreq 3.1.1, data CC BY-SA 4.0, code MIT,
  retrieved 2026-11-06). The list is corpus-based and includes news vocabulary
  (भारत, देश, सरकार). Variant: the Wiktionary "Top 1900 Hindi Words" appendix, ranks
  1 to 100 (licence per the Wiktionary frequency-list page: CC BY-SA; corpus not
  named in the fetched text).
- Matching: as for Spanish, against decks/hi (vocab cards only). Strict 50 and
  generous 143 known cards for the wordfreq list; strict 34 and generous 112 for
  the Wiktionary list. 28 and 48 list words have no vocab card.
- True position (70% rule, see above): path unit 35 (`hi-grammar-differences`) for
  wordfreq; unit 46 for Wiktionary. Hindi known cards are spread along the path
  (function words recur in grammar units).
- Glosses: `personas/hi-glossary.json` is AUTHORED from the agent's own knowledge,
  limited to the 62 list words present in the bank, and flagged as such.
- Answers: `answers/hi-<persona>-draw<k>.json` (qid -> option index; tiles -> bool),
  generated by `personas/make_answers.py`-style code from `hi-bank.json` (1895 questions)
  with the expert truth in `personas/hi-expert-truth.json`. `hi-fidelity.json` holds
  the per-persona reports.
- Personas: `personas/hi-{beginner,amateur,expert,native}.md` and
  `personas/README-nocognate.md` (the no-cognate amateur, both languages).
