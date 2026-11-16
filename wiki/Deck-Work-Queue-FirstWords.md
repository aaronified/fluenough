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

## Status (2026-11-16, end of session)

Every language in scope has a merged first deck on `decks-live`, except the sign languages.

| Languages | PR | Notes |
|---|---|---|
| af, nl, id, uk | #1532 | phrasebook 20 + first words 29 to 30; reviewed against Wiktionary |
| fa, ps, sat | #1533 | fa, ps: phrasebook 20 + 30 words; 6 Pashto phrasebook cards still `doubtful`. sat: 36 attested words, 1 example; its 15 "phrasebook" cards are first-words cards marked as a stopgap |
| ne, kok, bho, awa, gbm | #1537 | phrasebook 20 + 39 words; Wiktionary and Swadesh-checked headwords; examples and most phrasebook phrases unsourced and `doubtful` |
| raj, hne, bgc, mag, kfy, doi | #1548 | 39 words each, no phrasebook; rebuilt from Grierson's Linguistic Survey; 9 to 25 of 39 still `doubtful` per language |
| lus, kha, gom, brx, sd, ks, tcy | #1538 | first words only. Bodo has 13 cards (12 `doubtful`) |
| arc, gmy, sux, egy, ine | #1539 | 30, 33, 34, 34, 30 words; arc 5 and ine 1 `doubtful` |
| mni | #1563 | 30 words; Bengali targets derived from the attested Meitei Mayek forms (kept in `target_scripts`); all `doubtful` |

Tool PRs on main: #1530 (path generator plans and SHIPPED list), #1545 (`PHRASEBOOK_PENDING`).

## Open points

- Phrasebooks: none for lus kha gom brx sd ks tcy mni sat arc gmy sux egy ine raj hne bgc mag kfy doi (`PHRASEBOOK_PENDING` in `tools/validate_decks.py`). Remove a code when its phrasebook exists. They need a native speaker or a sourced phrase book.
- Santali: missing no, tea, today, brother, sister, and, all phrases; examples for 35 of 36 words.
- Bodo: need a source for Devanagari spellings (brx.wikipedia, omniglot and dsal are not reachable from the build sessions).
- Manipuri: I, we, where, yes, no; Bengali spellings are derived, not attested.
- Signed languages ins and ase: no signed-deck format in Deck-Format; the parent asks the owner.
- Every deck is `unreviewed`: a speaker check is the real gate.
