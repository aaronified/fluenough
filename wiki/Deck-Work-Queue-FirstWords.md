# First words and phrases: queue for languages with no decks

Owner brief (2026-11-16): "add one more session now to add just the first words and phrases decks for all planned languages ... This will enable their additions and name their scripts on the app as well. Do not do this for copyright issue languages (dothraki, sindarin, etc). Those will be filled via private decks."

Per language: a phrasebook (15 to 20 phrases), a first-words deck (25 to 30 words), their English layers and a path stub, on `decks-live`, one pull request per family group, one Sonnet review each. Words and phrases that a builder could not attest are tagged `doubtful` and listed here.

## Scope (derived 2026-11-16 from `assets/languages.yaml` and `decks/index.json` on decks-live)

Skipped, by design:

| Code | Language | Reason |
|---|---|---|
| tlh, sjn, qya, qdo, qhv | Klingon, Sindarin, Quenya, Dothraki, High Valyrian | Franchise-owned constructed languages: private decks (owner brief) |
| sa | Classical Sanskrit | Own session |
| ipa, qbe | IPA, English Braille | Notations, already have courses |
| en | English | The native language |
| ins, ase | Indian and American Sign Language | No script, and Deck-Format has no signed-deck format: reported to the orchestrator, no format invented |

## Status

| Group (branch) | Languages | Status |
|---|---|---|
| European Latin and Cyrillic (`decks/first-words-european-latin`) | af, nl, id, uk | building |
| Iranian and Santali (`decks/first-words-iranian-santali`) | fa, ps, sat | building |
| Devanagari north Indo-Aryan | ne, doi, bho, raj, mag, hne, awa, bgc, kfy, gbm, kok | queued; path generator lacks these codes |
| Other South Asian | brx, ks, sd, mni, tcy, gom | queued; path generator lacks these codes |
| North-east India | lus, kha | queued |
| Ancient and reconstructed | gmy, sux, egy, arc, ine | queued; gmy, sux, egy, ine have path files already |

## Open points

- The path generator (`tools/gen_planned_paths.py`) knows af, fa, id, nl, ps, sat, uk only. The others need entries in its `LANGS` table (own PR to main), or a hand-made one-unit path.
- Signed languages: see the table above.
