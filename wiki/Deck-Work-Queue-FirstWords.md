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

## Update 2026-11-20 (completion session)

| Item | Result |
|---|---|
| Phrasebooks | Merged on decks-live: #1646 (lus kha gom brx sd ks tcy mni sat), #1647 (arc), #1648 (raj hne bgc mag kfy doi), 15 to 20 phrases each. Almost every phrase is `doubtful`: only Wiktionary and Wikipedia were reachable (Wikivoyage, omniglot, bible.com, ebible.org, archive.org downloads, glottolog, elar, brx.wikipedia and sat.wikisource are blocked from build sessions). `PHRASEBOOK_PENDING` now holds only gmy, sux, egy, ine (main PR #1649). |
| gmy, sux, egy, ine | Phrasebooks were built, reviewed and dropped: no attested phrases exist, and the constructed ones were ungrammatical (wrong case, word order, number), so they would teach errors. They need an Assyriologist, Egyptologist, Mycenologist or Indo-Europeanist and attested formulae. |
| Source gaps | PR #1650 (decks/fw-source-gaps): Santali gains no, tea, today, and (attested) and elder brother and sister (`doubtful`, community wiki only); Manipuri gains I, we, where, yes, no (Meitei Mayek attested in DSAL Sharma and Wiktionary, Bengali spellings derived) and its three adjective stems follow Sharma; Bodo fixes father and water and gains 11 Wiktionary-attested words. Unresolved: Santali examples (only 6 sentences have a source translation; the rest are researcher glosses), Santali `ᱮᱸᱜᱟ` (sat-0117, 'mother') is 'female animal' per sat.wiktionary and the attested 'mother' is `ᱟᱭᱳ`; `ᱟᱠᱳ` has no headword; Bodo 'there' and 'where' and the numerals 2, 4 to 9 are not found on a reachable source; Pashto phrases (ps-0002, 0003, 0004, 0008, 0014) are attested only by their parts, so their `doubtful` tags stay. |
| American Sign Language | No deck built. No SignWriting data with ASL glosses under a CC-BY-SA-compatible licence was reachable: SignBank is CC-BY-NC; Commons has hello and good only as images; the sutton-signwriting repos (MIT, CC BY 4.0) hold unglossed samples; signwriting.org, signpuddle.net and the Commons PDF 'American Sign Language Hand Symbols' (Frost and Sutton, CC BY 3.0) are blocked from build sessions. Owner options: allow those hosts, get written permission from Sutton, or have a Deaf ASL reviewer write original signs. Indian Sign Language was not built: the source decision is the owner's. |
| B1Progress check | Every first-words deck has its path (unit 1 lists it), English layer and language entry; the older languages' 10-word first decks are by design. Script fonts for Ol Chiki, Meitei Mayek, cuneiform, Linear B and hieroglyphs are handled by the app's script checks; runtime rendering was not verified from a build session. |

## Open points

- Phrasebooks for gmy, sux, egy, ine: need a specialist and attested formulae (see above).
- Every phrasebook and most first-words examples are `doubtful`: a native-speaker check is the real gate.
- Santali, Manipuri, Bodo and Pashto unresolved items are listed in the 2026-11-20 table.
- Signed languages ase and ins: the owner's decisions are pending (see above).

**CC BY-NC sources (open, 2026-11-20).** The owner asked why CC BY-NC sources cannot be used. The code is GPL-3.0 and deck content is CC BY-SA 4.0; NC adds a NonCommercial restriction that neither allows, so SignBank and SignBank Plus cannot be redistributed under the project's licence, and NC would bar commercial use of the decks. [ADR-0003](ADR-0003-Licence) chose not to use a non-commercial licence. Options: (1) keep the ban and ask SignBank's owners for a permissive licence on a subset (recommended; depends on a reply, and a one-off grant is not a licence change); (2) ship sign decks as a separate NC pack outside the BY-SA decks (decks are no longer uniformly BY-SA, and an ADR-0003 amendment is needed first); (3) the ASL options above (allow the blocked hosts, written permission from Sutton, or a Deaf ASL reviewer). No decision; the owner said to move on for now, so ASL and ISL stay unbuilt. See [Owner-Decisions-History](Owner-Decisions-History#cc-by-nc-sources-2026-11-20).
- Every deck is `unreviewed`: a speaker check is the real gate.
