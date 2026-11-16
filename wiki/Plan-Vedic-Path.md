# Plan: the Vedic Sanskrit reading path

Status: design of 2026-11-16, task VSA-010 of [Deck-Work-Queue-VSA](Deck-Work-Queue-VSA.md) (tracker #1206). Nothing is built. This page proposes themes, grammar topic names, sizes and an order; it contains **no word list and no fact about the language**. A grammar feature is listed only if [Plan-Vedic-Engine](Plan-Vedic-Engine.md) names it (marked **E**) or it is marked **verify**: to be confirmed in Whitney (1879) or Macdonell (1916) by VSA-001 before any deck says it. The path today (`decks/vsn/vsn-path.yaml` on `origin/decks-live`, read 2026-11-16) is the generic template of `tools/gen_planned_paths.py` with modern themes removed; the rules of the course are those of [Plan-Language-Paths](Plan-Language-Paths.md) and [Plan-Language-Paths-Scheme](Plan-Language-Paths-Scheme.md): a reading course whose A1, A2 and B1 are three reading levels of 300, 400 and 600 words (`levels`, low confidence, owner 2026-10-31).

## 1. Findings about the current file

- **The A1 mark is on unit 30, not 33.** Counting the entries of `vsn-path.yaml`, `vsn-animals` (milestone `A1`) is the 30th unit; the A2 mark (`vsn-nature`) is unit 42, and the file has 59 units plus the closing `*`. The "33 / 46 / 61" in the audit of [Deck-Work-Queue-VSA](Deck-Work-Queue-VSA.md) counts the unit after `vsn-animals` as A1. This page makes A1 **33 units** as the task asks (unit 1 is written, 2 to 33 planned), so three more units fall inside A1 than today.
- **Word sizes today:** unit 1 has 10 words; the planned themes of units 2 to 30 sum to 290; so A1 is exactly 300 and the file is internally consistent. A2 adds 400 and B1 adds 600 (the `levels` are per level, not cumulative: 1,300 words in all).
- **Grammar units carry no `words`.** Their example words are counted inside the theme units; this page keeps that.
- **Themes that do not fit a hymn reader** (`about-me`, `work`, `places`, `things`, `home`, `clothes` in A1) are replaced. They are planned units only (no deck, no card), so dropping an id breaks nothing; the only references to check are the VSA-1xx task specs, which name units by id.

## 2. A1: units 1 to 33 (300 words)

Kind: **word** (theme unit, sized), **grammar** (a grammar core, no `words`), **script** (a script deck; `kind` of the unit is grammar, id `vsn-script-<name>`, as `S["devanagari"]` writes it). "Kept" = the id exists today and keeps its theme and place or moves. "New" ids need a `decks/themes.yaml` entry (section 5).

| # | Unit id | Kind | Theme or grammar topic | Words | Kept or new |
|---|---|---|---|---|---|
| 1 | `vsn-phrasebook` + first words | word (written) | first words, phrasebook | 10 | written |
| 2 | `vsn-sound-differences` | grammar | `sound-differences`, `pitch-accent` | 0 | kept |
| 3 | `vsn-questions` | word | questions | 5 | kept |
| 4 | `vsn-pronouns` | word | pronouns and people words | 16 | kept |
| 5 | `vsn-family` | word | family | 12 | kept |
| 6 | `vsn-numbers-1-20` | word | numbers 1 to 20 | 10 | kept |
| 7 | `vsn-script-letters` | script | `devanagari-letters` | 0 | kept |
| 8 | `vsn-script-conjuncts` | script | `conjunct-letters` | 0 | kept |
| 9 | `vsn-script-accent-marks` | script | `accent-marks` | 0 | kept |
| 10 | `vsn-script-reading` | script | `reading-words` | 0 | **new** |
| 11 | `vsn-everyday-verbs` | word | everyday verbs (the verbs the hymns use most; list from VSA-001) | 16 | kept |
| 12 | `vsn-gods` | word | gods and their epithets | 18 | **new** |
| 13 | `vsn-grammar-case-system` | grammar | `case-system` | 0 | kept |
| 14 | `vsn-cosmos` | word | sky, earth, sun, dawn, waters, wind (what the hymns address) | 22 | **new** |
| 15 | `vsn-adverbs` | word | adverbs | 16 | kept |
| 16 | `vsn-describing` | word | describing | 16 | kept |
| 17 | `vsn-grammar-a-stems` | grammar | `a-stem-nouns` | 0 | kept |
| 18 | `vsn-ritual` | word | ritual: fire, offering, priest | 20 | **new** |
| 19 | `vsn-quantities` | word | quantities | 10 | kept |
| 20 | `vsn-time` | word | time (day, night, year, as the hymns use them) | 8 | kept |
| 21 | `vsn-location` | word | location | 6 | kept |
| 22 | `vsn-grammar-present-system` | grammar | `present-system` | 0 | kept |
| 23 | `vsn-more-verbs` | word | more verbs | 14 | kept |
| 24 | `vsn-hymn-words` | word | praise, song, verse, prayer | 16 | **new** |
| 25 | `vsn-cattle-horse` | word | cattle, horse, herd and pasture | 16 | **new** |
| 26 | `vsn-body` | word | the body | 12 | kept |
| 27 | `vsn-food` | word | food and offerings | 14 | kept |
| 28 | `vsn-war` | word | battle, weapons, enemies, heroes | 14 | **new** |
| 29 | `vsn-grammar-preverbs-tmesis` | grammar | `preverbs`, `tmesis` | 0 | **new** |
| 30 | `vsn-people` | word | priests, singers, kings, tribes | 12 | **new** |
| 31 | `vsn-numbers-big` | word | tens and big numbers | 6 | kept |
| 32 | `vsn-directions` | word | directions | 5 | kept |
| 33 | `vsn-animals` | word | animals (A1 milestone) | 6 | kept |

Check: 10 + (5 + 16 + 12 + 10 + 16 + 18 + 22 + 16 + 16 + 20 + 10 + 8 + 6 + 14 + 16 + 16 + 12 + 14 + 14 + 12 + 6 + 5 + 6) = 10 + 290 = **300**. 23 word units, 9 grammar and script units, 32 planned units (2 to 33). Words are sized so the generator's sum rule holds: the theme words of a level add to `levels`.

Why this shape: the course opens with words, not letters (scheme: first four themes, then the script), and the script block sits at 7 to 10 as today. The nouns of the hymns (gods, cosmos, ritual, hymn words, cattle and horse, war, people) are the reading syllabus; the generic verbs, adverbs, quantities and numbers every reader needs stay. Whether a theme needs more or fewer words than sized is for the VSA-1xx builders to report, never to improvise; the sizes are a judgement (low confidence), as `levels` is.

### Grammar units of A1, and the features each teaches

| Unit | Features to teach | Status |
|---|---|---|
| `vsn-sound-differences` (`sound-differences`, `pitch-accent`) | pitch accent as pitch, not stress (**E**, section 2.5 of the engine plan); the letter ळ for the sound written ḷ (**E**); anusvara and visarga as signs, with their readings ṁ and ḥ (**E**); ai and au as long diphthongs and e and o as diphthongs: **verify**, the engine plan lists it as open for a Vedicist, so the deck states nothing until VSA-001 pins it | **E**, one **verify** |
| `vsn-grammar-case-system` (`case-system`) | the case names, number, and the vocative as a form of address: **verify** (no case feature is named in the engine plan) | verify |
| `vsn-grammar-a-stems` (`a-stem-nouns`) | the instrumental plural -ebhiḥ beside -aiḥ (**E**); the rest of the a-stem endings and the neuter: **verify** | **E** and verify |
| `vsn-grammar-present-system` (`present-system`) | person and number endings, active and middle: **verify**. The injunctive and the subjunctive are named in the engine plan but belong to the B1 moods unit, and are only pointed at here | verify |
| `vsn-grammar-preverbs-tmesis` (`preverbs`, `tmesis`) | tmesis, the preverb standing apart from its verb (**E**, section 2 findings of the queue page; the family of VSA-030 multi-word verbs); the list of preverbs and their meanings: **verify** | **E** and verify |

New grammar topic ids are `preverbs`, `tmesis`, `reading-words`; every other is already in the path or the generator's `S` and `G["vedic"]` tables.

## 3. Script decks: order and the accent policy

Four script decks, in this order. The order follows the engine plan: no accent mark appears in a deck before the accent-marks deck, and no deck's readings exist before the engine does.

| Order | Unit | Deck (task) | What it teaches | Marks in `target` |
|---|---|---|---|---|
| 1 | `vsn-script-letters` | `vsn-script-letters` (VSA-070) | the vowels, then the consonants by row, semivowels, sibilants and h; the signs anusvara, visarga, candrabindu, avagraha, virama; the Vedic letter ळ (**E**) | none |
| 2 | `vsn-script-conjuncts` | `vsn-script-conjuncts` (VSA-071) | how consonants join; the conjuncts the engine plan names (ज्ञ, क्ष; the sound ḷh written ळ्ह, **E**) | none |
| 3 | `vsn-script-accent-marks` | `vsn-script-accent-marks` (VSA-072) | the two marks of the Rigveda and Atharvaveda editions: the anudātta (U+0952) and the svarita (U+0951), with the udātta unmarked (**E**; the sign-to-accent mapping is **verify** in Macdonell) | U+0951, U+0952 only |
| 4 | `vsn-script-reading` | `vsn-script-reading` (VSA-075, new unit) | reading whole words, unmarked and then marked; hiatus stays hiatus, as written (engine rule: no sandhi across words) | U+0951, U+0952 only; the words are the A1 words of units 3 to 6, never new ones |

Policy, all from the engine plan (sections 1.1 to 1.3 and 2.5), restated so the path task is self-contained:

1. **Cards of the A1 word units carry no accent mark in `target`.** Marks appear only in the accent-marks deck, in the reading deck and in verse excerpts, where nobody types the line.
2. **The reading and the `ipa` never carry an accent**; the engine strips marks before reading and reports where they were. A script card shows the mark in `target` and says in a note which accent it is.
3. **Where a marked `target` could be typed, `alt_target` holds the unmarked spelling**, since the grader does not fold U+0951 and U+0952 (engine plan 1.3).
4. **Only U+0951 and U+0952 in A1.** The Vedic Extensions marks (other recitation traditions) and the letters ᳵ and ᳶ (jihvāmūlīya, upadhmānīya) are deferred to the A2 unit `vsn-script-signs` (section 4): they would cut a word in two in a layer's prose until the validator change of the engine plan is made.
5. **The accent-marks deck includes a rendered check** of a conjunct plus vowel sign with each mark (the strings are those the engine plan names: अ॒ग्नि and ई॑ळे), in light and dark at 1.4x text, before it merges (engine plan 1.2: the font's cmap covers the marks, its positioning is not proved).
6. **Blocked by VSA-110 (the `vedic` engine) and VSA-100's follow-ups:** decks 3 and 4 carry readings, so they start after the engine lands; decks 1 and 2 need readings too (every card has one), so VSA-070 to VSA-075 all wait for the engine, as the queue page already says. The path edit itself does not.
7. **`alphabet` in the path** stays `[]` until the four script decks are written; each is then listed in it in the same commit (queue page, VSA-070..075; the validator takes only written decks there).

## 4. A2 and B1: outline

Only themes and grammar topic names. Word counts are the shares of 400 and 600, to be rebalanced by the builders; every new theme or grammar topic needs a `decks/themes.yaml` entry or a VSA-001 check. The A2 mark falls on the last unit of A2, the B1 mark on the last of B1.

**A2 (400 words).** Grammar units keep the generator's `G["vedic"]["a2"]` names: `other-stems` (`other-noun-stems`, verify), `aorist-perfect` (`aorist`, `perfect`; the augmentless aorist is **E**), `imperatives` (`imperative`, verify), `participles` (`participles`, verify), `compounds` (`compounds`, verify).

| Unit id | Kind | Theme or topic | Words |
|---|---|---|---|
| `vsn-weather` | word | weather and storm | 40 |
| `vsn-calendar` | word | days, months, seasons | 25 |
| `vsn-nature` | word | land, water, trees | 55 |
| `vsn-journey` | word | paths, travel, chariot | 45 |
| `vsn-illness` | word | illness and healing (charm hymns; verify the scope) | 35 |
| `vsn-gods-2` | word | gods, second set (theme `gods`) | 50 |
| `vsn-ritual-2` | word | ritual, second set (theme `ritual`) | 50 |
| `vsn-war-2` | word | kings, battle and tribes, second set (theme `war`) | 40 |
| `vsn-verbs-3` | word | more daily and ritual actions | 60 |
| `vsn-script-signs` | script | the Vedic Extensions accents, ᳵ and ᳶ (core target only; validator change first) | 0 |
| five grammar units | grammar | the five above | 0 |

Sum: 40 + 25 + 55 + 45 + 35 + 50 + 50 + 40 + 60 = **400**.

**B1 (600 words).** Grammar units keep `G["vedic"]["b1"]`: `moods` (`subjunctive`, `injunctive` are **E**; `optative` verify), `infinitives` (-tave and -dhyai are **E**; -tum rarely, verify), `particles` (verify), `relative-clauses` (verify).

| Unit id | Kind | Theme | Words |
|---|---|---|---|
| `vsn-feelings` | word | feelings | 55 |
| `vsn-agriculture` | word | fields, ploughing, grain | 55 |
| `vsn-weddings` | word | marriage and the rites around it (verify the scope) | 50 |
| `vsn-law` | word | order, law and obligation (verify the scope) | 45 |
| `vsn-government` | word | kings, assemblies, tribes (verify the scope) | 45 |
| `vsn-arts` | word | poetry, metre, song | 50 |
| `vsn-abstract-words` | word | ideas and values | 70 |
| `vsn-verbs-4` | word | story actions | 75 |
| `vsn-health` | word | health | 55 |
| `vsn-opinions` | word | opinions | 50 |
| `vsn-gods-3` | word | gods and myths, third set (theme `gods`) | 50 |
| four grammar units | grammar | the four above | 0 |

Sum: 55 + 55 + 50 + 45 + 45 + 50 + 70 + 75 + 55 + 50 + 50 = **600**. Left out as modern: travel, history, relationships (kept in the generic template, not in a hymn reader); the owner may reinstate any.

## 5. Edits needed, and whether a deck PR can make them

**Short answer: yes. A deck pull request to `decks-live` makes all of them; no tools change, no release and no app change.**

1. **`decks/vsn/vsn-path.yaml` on `decks-live`, by hand.** Replace the planned units 2 to 30 with units 2 to 33 of section 2 (ids and order as the table), keep the unit-1 entry as it is, move `milestone: "A1"` to `vsn-animals` at its new place, add `vsn-script-reading` with `grammar: ["reading-words"]` and the new `vsn-grammar-preverbs-tmesis` with `grammar: ["preverbs", "tmesis"]`. Each planned unit keeps one `listening_passages` and one `reading_passages` entry (unique ids; the generator's phrasing is the model; placeholders until the passages are written). Replace the header comment's "written by tools/gen_planned_paths.py" with "hand-edited since 2026-11-16 (Plan-Vedic-Path)", as the file already says a unit may be taken over by hand. `levels`, `alphabet: []`, `genders` unchanged. The A2 and B1 units (section 4) go in the same PR or a second one; the outline is not blocking for A1.
2. **`decks/themes.yaml` on `decks-live`**, the deck-owned theme list (owner, 2026-11-11), gets the seven new theme ids: `gods`, `cosmos`, `ritual`, `hymn-words`, `cattle-horse`, `war`, `people`, each with a name. The validator requires a deck's `theme` to be in the file when the deck is written (`validate_decks.py:3203`, `:3911`); a planned unit's theme is checked only for its id shape. Never edit `main`'s `decks/themes.yaml` (it is only the bundled fallback).
3. **Not needed in `tools/gen_planned_paths.py`.** The generator's theme tables (`A1_THEMES`, `A2_THEMES`, `B1_THEMES`) are shared by all languages, and `test_themes_exist_in_themes_yaml` reads `decks/themes.yaml` **on main**, so adding Vedic themes to the shared tables would fail that test until main had them. The generator also never rewrites an existing path (`--only` without `--force`), and `--check` is not run for `vsn-path.yaml`. The `S["devanagari"]` script plan (letters, conjuncts, accent-marks) already matches units 7 to 9; unit 10 and the new grammar units exist only in the hand edit. **If the owner wants the generator to reproduce this path** (so a future `--force` does not undo it), a separate tools PR to main adds a per-language `THEMES["vsn"]` override and `"reading-words"` to `S["devanagari"]` for `vsn` only (not `sa` or `pli`, which share `devanagari_plain`): not recommended now, since it duplicates the hand edit.
4. **One thing the PR must check, not assume:** that two planned units may share a theme id (`vsn-gods-2` uses theme `gods` beside `vsn-gods`). If the validator or a test refuses it, give the second and third sets their own theme ids (`gods-2`, `gods-3`, and so on) and add them to `decks/themes.yaml`.
5. **Order against other tasks.** VSA-010 (this page, then the path edit) comes before the VSA-1xx unit builds, which name units by id; the path edit PR is small and can merge before any deck. VSA-001 must pin the **verify** features before a grammar deck states them; the path stores topic names only, so the edit does not wait for it. The engine (VSA-110) is needed only by the script decks and every card reading, not by the path.
