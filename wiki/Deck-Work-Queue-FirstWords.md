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

## Status (2026-11-16)

| Group (branch) | Languages | PR | State |
|---|---|---|---|
| European Latin and Cyrillic | af, nl, id, uk | #1532 | merged |
| Iranian and Santali | fa, ps, sat | #1533 | merged. Santali: 36 attested words, 1 example; its 15 "phrasebook" cards are first-words cards marked as a stopgap (clear once `sat` leaves `PHRASEBOOK_PENDING`) |
| Devanagari north Indo-Aryan | ne, kok, bho, awa, mag, hne, raj, doi, bgc, kfy, gbm | #1537 | source check and CI fixes in progress; most cards of all but ne `doubtful` |
| Other South Asian | lus, kha, gom, brx, sd, ks, tcy | #1538 | source check done; CI waits on #1545 (no phrasebooks) |
| Ancient and reconstructed | arc, gmy, sux, egy, ine | #1539 | source check in progress; egy and gmy under 25 words |
| Manipuri | mni | none | not built: needs a Bengali-letter spelling source (first script is Bengali); Meitei Mayek font (`NotoSansMeeteiMayek`, OFL) to be added with it |

## Open points

- Tool PRs to main: #1530 path generator and SHIPPED test list (merged); #1545 `PHRASEBOOK_PENDING` in the validator (the 15 to 25 phrasebook rule otherwise blocks first-words-only courses).
- Brx (Bodo): 13 cards, 12 `doubtful`; brx.wikipedia, omniglot and dsal are blocked in the build sessions.
- Fonts: all scripts used have fonts on decks-live except Meitei Mayek. The Perso-Arabic Nastaliq font lacks the Sindhi kaf (U+06AA): sd and ks need Naskh through `LANGUAGE_FONTS` and `fontScriptFor` (a 0.11.0 code PR by the parent session).
- Signed languages ins and ase: no format in Deck-Format; the parent asks the owner.
- Phrasebooks for every course in `PHRASEBOOK_PENDING` need native speakers or sourced phrase books.
- Every deck here is unreviewed: a speaker check is the real gate.
