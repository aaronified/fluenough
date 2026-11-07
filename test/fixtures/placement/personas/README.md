# Scripted persona answers (calibrated)

`make_scripted_answers.py` produces the answer tables for any placement bank from a
truth file (`--truth`: `{question_id: correct_option_index}` for pick questions). It
never reads a key itself; whoever holds the key makes the truth file.

    python3 -I personas/make_scripted_answers.py --lang es \
      --bank banks/es-bank.json --truth <TRUTH_es.json> \
      --glossary personas/es-glossary.json --outdir answers/v3 [--ids IDS.txt] [--draws 1 2 3]

Outputs, per draw: `<lang>-expert`, `<lang>-native`, `<lang>-amateur-<primary>`,
`<lang>-amateur-<primary>-nocognate`, `<lang>-amateur-wiktionary`, `<lang>-beginner`
(pick = option index, tiles = bool), and `<lang>-scripted-fidelity.json` (accuracy vs
the truth file by band, type and known/unknown items).

## Calibration (measured on bank v2, expert and native against the expert's own answers)

| Persona | Units 1-40 | Units 41-100 | Units 101+ | Slip form |
|---|---|---|---|---|
| expert | 0 | 0.053 | 0.095 | false friend (most similar option); tiles marked wrong |
| native | 0.001 | 0.001 | 0.042 | same |

Measured v2 band accuracy (mean of 3 draws): expert es 100 / 100 / 94.9 / 90.5, hi
100 / 100 / 94.6 / 90.5; native es 100 / 100 / 100 / 97.2, hi 100 / 100 / 99.8 / 94.5.

Scripted v2 reproduction (seeded): expert es 100 / 92.9 / 90.1, hi 100 / 94.7 / 88.7;
native es 100 / 99.7 / 95.1, hi 99.8 / 99.9 / 95.9. Within about two points.

## Validation on new v3 items (role-played sample)

400 random new v3 pick questions per language were answered as the expert from the
agent's own knowledge (`validation/<lang>-v3-roleplay-expert.json`; ids in
`validation/<lang>-v3-sample-ids.txt`). Running the scripted expert on those ids with
the role-play answers as truth gives realized agreement (`validation/*-scripted-vs-roleplay.json`):

- es expert: 1-40 100, 41-100 96.9, 101+ 91.2 (overall 94.9)
- hi expert: 1-40 100, 41-100 95.8, 101+ 89.5 (overall 95.3)
- native es / hi: 101+ 95.3 / 95.4

This confirms the slip mechanism reproduces the calibrated rates. It does not measure
accuracy against the key. That comparison needs the truth file and is for whoever
holds the key.

## Amateur and beginner

Rules unchanged: known set from the list (glossary tags), elimination, similarity and
cognate votes on written prompts only (none for heard prompts, and none in the
no-cognate variant), random ties (seeded). The glossaries are authored from the agent's
own knowledge and flagged as such in each file.
