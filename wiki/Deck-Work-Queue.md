# Deck work queue: what is open, and the tasks the Haiku builders take

Owner orders of 2026-11-14, recorded as given:

- Up to three Haiku deck builders work in parallel, on byte-sized, fully specified tasks. Sonnet reviews each pull request once.
- "Do not leave anything in the middle. Complete the culture decks as well. Complete Japanese, then move on to Spanish, then Telugu, then French. Then the others."
- "Build the kanjis as well." (about 1000 kanji by B1, #1146: the deferral is lifted)
- "For each blocker create separate issues" and "the codes must be language agnostic": every code or tool need is a general mechanism driven by per-language data, never Japanese logic in `lib/` or `tools/`.

This page is a plan. It builds nothing. The sections for Spanish, Telugu, French and the others are added when Japanese is done. State was read from `origin/decks-live` (f7ec2370) and `origin/main` on 2026-11-14.

## Rules that every task carries

1. **Report issues, never improvise.** A builder that meets anything unclear, missing or different from its task stops that item and reports it. The architect re-specifies. No guessing a reading, a date, a source or an id.
2. **Guarded, logged code.** Any script a builder writes wraps its work in try/catch (including around loops over items, so one failure does not stop the rest), sends every caught failure to the app's existing logger (never a silent catch, never only a print), and repeats it in the report. No new logger.
3. **Ids.** Card ids come only from the task's reserved range, ascending. A range left partly unused stays unused. An id is never reused or renumbered. A deck that needs more ids than reserved stops and reports.
4. **Quote every YAML scalar** except `true`, `false` and whole numbers. Tag every new file `"unreviewed"`. Licence `CC-BY-SA-4.0`.
5. **No local tests, no local validator, no tag, no new branch after a merge.** CI checks the pull request. Pull requests target `decks-live`. One Sonnet review per pull request. No deck file edits `decks/min_app.json`.
6. **Sources.** A date or legacy claim is read from the creator's or work's Japanese Wikipedia page by the builder. What was not read goes to the review queue as unverified. Nothing from memory is asserted as checked.
7. **No quoted text.** Works are named by title and creator. A card carries only what its kind allows (the batch-1 shape), never a passage longer than that shape; nothing is copied from a translation, a dictionary or a lyric sheet. Translations are the builder's own plain renderings.
8. **Review-queue rows** are written into the task's report (and the pull request description), one line each in the file's table shape. Only the task that owns `docs/review-queue/ja.md` in a batch edits it; the batch's `JA-04x` task collects the rest.
9. **Shared files** (`decks/creators/ja.yaml`, `decks/ja/ja-topics.yaml`, `decks/recommendations/ja.yaml`, `docs/review-queue/ja.md`, `decks/ja/ja-path.yaml`, the rules decks) have exactly one owner per batch, named in the task. A task that does not own a shared file never edits it. The one exception is stated under "Kanji lanes".
10. **Genre decks are not on the path.** A deck with a `genre` (culture, proverbs, multiword) needs no path edit; a vocab, rules or script deck without one must be listed on the path in the same pull request.

## Japanese

### State on decks-live, 2026-11-14 (what the issues no longer say)

Issue #378's checklist (2026-11-13) is out of date: batches 1 to 4 have merged since.

| Fact | Value |
|---|---|
| Path `decks/ja/ja-path.yaml` | 137 units plus the `*` line: 116 written, 21 planned (7 word units of 350 words, 9 grammar units, 5 kanji units) |
| Cards in `decks/ja/*.yaml` | 4,032; highest Japanese id `ja-4577` |
| Core files / layer files | 239 files in `decks/ja/`, 298 in `decks/ja/en/` |
| Listed decks missing a file | 0 (every deck a written unit lists exists, sentences and readings included) |
| Culture | `ja-culture-1` (18 items), 25 creators, 8 eras, 9 recommendations |
| Proverbs / multi-word | `ja-proverbs-1` 12 cards; `ja-multiword-compound-verbs` 8, `ja-multiword-te-auxiliaries` 9 |
| Topics / situations | 9 topics; `ja-situations`, 6 sheets |
| Kanji | `ja-kanji-1`, 7 cards (days of the week) |
| Cards without notes | 900: 850 on sentence cards, 40 in `ja-en-hiragana`, 10 on word cards |
| Broad `ipa` missing | 6 cards, all in `ja-family` |
| `phonetic` | 0 of 4,032 cards; no `decks/ja/ja-phonetics.yaml` |
| Facts file | none (`decks/ja/ja-facts.yaml` does not exist) |
| Review queue | 262 rows in `docs/review-queue/ja.md` |
| Ids in use | 1 to 4577; the ranges below sit above them |

### A. Everything still open on the Japanese checklist

| # | Open item | Size | Tasks |
|---|---|---|---|
| 1 | Path: 21 planned units. 7 word units (money, society, university, food-culture, literature, verbs-5, abstract-words: 350 words, each with sentences and a reading deck) and 9 grammar units (conjunctions, adjective past, likes, comparison, relative clauses, sonkeigo, kenjougo, transitivity, teineigo) | 16 units | JA-023 to JA-038 |
| 2 | Path: the 5 planned kanji units are replaced by 37 (below) | 1 path edit | JA-001 |
| 3 | Culture decks beyond batches 1 and 2 (default taken: complete is 4 culture decks of 18, so 3 more) | 54 items, about 36 new creators | JA-002, 005, 008 |
| 4 | More proverbs (12 now) | 40 cards, 2 decks | JA-003, 006 |
| 5 | More multi-word decks (17 cards now) | 60 cards, 3 decks | JA-004, 007, 009 |
| 6 | Topics growth (9 now) | about 14 topics: 8 culture, 6 kanji | JA-010, JA-011 |
| 7 | Creators and eras growth | rides on 3 | with JA-002, 005, 008 |
| 8 | More recommendations (9 now, source-it-yourself) | 20 works | JA-012 |
| 9 | Situations growth (6 sheets) | 4 sheets | JA-013 |
| 10 | Notes gap | 900 cards | JA-014 to JA-022 |
| 11 | Professional decks (#1139, hidden) | none: `professions` is empty in `decks/sections.yaml` | held, nothing to build; needs the owner's list of professions first |
| 12 | Narrow IPA for every card; broad `ipa` on the 6 missing | 4,032 cards plus all new | JA-039 to JA-041 |
| 13 | Review-queue rows for everything new | per batch | JA-042 to JA-044 |
| 14 | Facts file | about 30 facts | JA-046 |
| 15 | Kanji, about 1,000 by B1 | 1,026 school kanji, 7 done | JA-100 to JA-137 |
| 16 | Docs: stale statements (build-deck skill says narrow IPA tools are unbuilt; #378 and Plan-Language-Completeness counts) | 3 small edits | JA-045 |
| 17 | Blockers that need code or tools | 3 issues | section C |

### B. The buildable task queue

Order and parallelism: three builders at most. A **lane** is a serial chain on one builder. Lanes marked PARALLEL share no file and may run at once.

| Batch | Lane A (culture) | Lane B (path and kanji) | Lane C (genre decks) |
|---|---|---|---|
| 1 | JA-002 | JA-001, then JA-101 to JA-103 | JA-003 then JA-004 |
| 2 | JA-005, then JA-008 | JA-104 to JA-108 (and JA-100's lists feed 109 on) | JA-006, JA-007, JA-009 |
| 3 | JA-010, JA-012 | JA-109 to JA-137 in grade order, then JA-011 | JA-013, JA-046 |
| 4 | Sentence notes JA-014 to JA-022: three at a time, any lane | Word units JA-023 to JA-029, then grammar units JA-030 to JA-038, serial (they own the path and the rules decks) | |
| Last | JA-039, JA-040, JA-041 serial, only after every content pull request has merged (the IPA run touches every file) | | |

Review-queue carriers JA-042 to JA-044 run after batches 1, 2 and 3. JA-045 and JA-100 are docs and go straight to main (JA-100 is the Sonnet job).

**The first three parallel-ready tasks: JA-001, JA-002, JA-003.** (JA-101 waits for JA-001's path merge.)

#### Reserved id ranges (disjoint, all above ja-4577, all four digits)

| Task | Range | Task | Range |
|---|---|---|---|
| JA-002 culture-2 | ja-4600 to 4649 | JA-004 suru verbs | ja-4850 to 4899 |
| JA-005 culture-3 | ja-4650 to 4699 | JA-007 compound verbs 2 | ja-4900 to 4949 |
| JA-008 culture-4 | ja-4700 to 4749 | JA-009 idiomatic verbs | ja-4950 to 4999 |
| JA-003 proverbs-2 | ja-4750 to 4799 | Kanji JA-1nn (nn 01 to 37) | ja-(5000 + 60 x (nn - 1)) for 60 ids; JA-101 5000 to 5059, JA-137 7160 to 7219 |
| JA-006 proverbs-3 | ja-4800 to 4849 | JA-013 situations | ja-7300 to 7499 |
| Word unit JA-023 to JA-029 | 150 each from ja-8000 (JA-023 8000 to 8149, JA-029 8900 to 9049) | Grammar unit JA-030 to JA-038 | 60 each from ja-9100 (JA-030 9100 to 9159, JA-038 9580 to 9639) |

Recommendations take string ids (`ja-rec-...`), creators `ja-<name>`, topics `ja-<name>`: no numbers.

#### Content rule sets

- **RULE-CULT.** Template: `decks/ja/ja-culture-1.yaml` and its layer, `decks/creators/ja.yaml`, `wiki/Plan-Culture-Japanese.md` ("Rules applied"). 18 items per deck, short items first, level A2 or B1 per item. Public-domain basis only: the author died in 1955 or earlier (the validator floor), an anonymous work first published before 1900; no `quotation` items; each item has the batch-1 `source` block. Text shown in modern kana. Each creator: a short A2-level bio, dates (`circa` where uncertain), era, a legacy line with one or two checkable items each with a source link, no image. A creator whose dates the builder could not read, or an item whose text it could not read on the page, is dropped and replaced from the reserve list; it is never filled in.
- **RULE-PV.** Template `ja-proverbs-1`. `genre: "proverbs"`, `basis: "oral-tradition"`, `source` block as in proverbs-1, one `literal` note and a meaning, modern kana, level A2 or B1. Proverbs not already used in `ja-proverbs-1` (the builder lists those first).
- **RULE-MW.** Template `ja-multiword-compound-verbs`. `genre: "multiword"`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part, parts already taught are written by `ref`, a new part gets a card.
- **RULE-NOTE.** Add a typed note (`usage`, `note`, `register` or the kinds Deck-Format "Notes" lists) only where the sentence has one teachable point: a particle choice, a politeness level, an ellipsis, a word-order point. Ids of the notes in the core, text in the layer, transliteration after every Japanese word in note prose. A card with nothing to teach gets no note and is listed in the report. Card ids and every existing field stay as they are.
- **RULE-UNIT** (word and grammar units). `.claude/skills/build-deck/SKILL.md` in full: core, layer, `-sentences` core and layer, the reading deck (single-file, passages from the path entry), the unit's rules rows (every word of its kind, in every table of its kind), the `ja-` set card where it teaches a closed group, the facts the checklist asks for. The path entry changes from `planned` to written in the same pull request. A conjunctions unit follows the shape of `bn-grammar-conjunctions` (a vocab core with a set card).
- **RULE-KANJI**, below.

#### Kanji

Source of the set: the school kanji (kyoiku kanji), 1,026 characters in six grades (80, 160, 200, 202, 193, 191), from the Ministry of Education's grade-by-grade list (the Course of Study's appended table, cited by name only); about 1,000 by B1 is the owner's target. A list of characters is a fact. Readings and meanings are written by the builder in its own words from the joyo kanji table's readings; KANJIDIC2 and every dictionary text are not copied (no share-alike obligation enters the deck). No stroke-order images.

**RULE-KANJI** (each of JA-101 to JA-137, one deck of 20 to 40 kanji, `ja-kanji-N` with N = task number minus 99):

- Files: `decks/ja/ja-kanji-N.yaml`, `decks/ja/en/ja-en-kanji-N.yaml`, and the unit's path entry (written form, deck also added to `alphabet`). Template: `ja-kanji-1` and `ja-en-kanji-1`, and Deck-Format "Japanese kanji". `script: han`, `scripts: [han, kana]`, tags `script`, `unreviewed`, `level` by the unit's place in the path (before the A2 milestone `A2`, after it `B1`).
- One card per kanji, in the task's list order. `target` the kanji, `target_scripts.kana` the one reading the unit teaches it by (the word it stands for alone, else its commonest word), `words`, romaji `reading` (Hepburn, `ja-romanisation`), broad `ipa`, `pos: "letter"`, `bases: "self"`. No `phonetic`. The layer's note `n1` has this exact shape: `X (kana): on readings ... ; kun readings .... It is in W (romaji), meaning.` with every kana followed by its romaji.
- Two examples per card, each with `target_scripts.kana`, `reading`, `ipa`, `words`. **Examples use only words already taught**: a word that is a card of a deck listed on the path at an earlier unit than this one (or an earlier card of this deck). The card's kanji appears in at least one example. A kanji with fewer than two such examples is not built: the builder reports it and the architect moves it to a later deck.
- **The rule for when new sentences may show kanji (proposed here, default taken):** in any card or example written after JA-001, a kanji is written as a kanji only if it is taught by then (its card is in a kanji deck at an earlier path position, or earlier in the same deck). Every other kanji in that sentence is written in kana. Existing kana decks are untouched and ids never change (ADR-0053). Until blocker B2 lands this rule is the builder's and the reviewer's, not the validator's.
- Uncertain readings, grade membership or meanings: one review-queue row per kanji, in the report.
- Not touched: `ja-topics.yaml` (JA-011), the path outside the task's own entry, `decks/min_app.json`, other kanji decks.

**Kanji lanes (the one exception to rule 9).** JA-001 first rewrites the five planned kanji units into 37 planned units and spaces them with at least one other unit between every two, so the entries never touch. A kanji task then edits only its own entry. Two kanji lanes may run at once under this rule; if a rebase finds a conflict in the path, the builder stops and reports.

| Task | Kanji (grade) | Count | Deck, ids |
|---|---|---|---|
| JA-100 | **Sonnet, docs on main:** writes `wiki/Plan-Kanji-Japanese.md` with the exact lists for grades 3 to 6 (counts 200, 202, 193, 191, no repeats, checked against the grade table) and the split of JA-109 to JA-137; the lists for grades 1 and 2 below are copied into it | docs | none |
| JA-101 | 一右雨円王音下花貝学気九休玉空犬見五口校左三山子 (1) | 24 | ja-kanji-2 |
| JA-102 | 四糸字耳七車手十出女小上森人正生青夕石赤千川先早 (1) | 24 | ja-kanji-3 |
| JA-103 | 草足村大男竹中虫町天田二入年白八百文本名目立力林六 (1) | 25 | ja-kanji-4 |
| JA-104 | 引羽雲園遠何科夏家歌画回会海絵外角楽活間丸岩顔汽記帰弓牛魚京強教 (2) | 32 | ja-kanji-5 |
| JA-105 | 近兄形計元言原戸古午後語工公広交光考行高黄合谷国黒今才細作算止市 (2) | 32 | ja-kanji-6 |
| JA-106 | 矢姉思紙寺自時室社弱首秋週春書少場色食心新親図数西声星晴切雪船線 (2) | 32 | ja-kanji-7 |
| JA-107 | 前組走多太体台地池知茶昼長鳥朝直通弟店点電刀冬当東答頭同道読内南 (2) | 32 | ja-kanji-8 |
| JA-108 | 肉馬売買麦半番父風分聞米歩母方北毎妹万明鳴毛門夜野友用曜来里理話 (2) | 32 | ja-kanji-9 |
| JA-109 to 116 | grade 3, from JA-100's list | 8 x 25 | ja-kanji-10 to 17 |
| JA-117 to 123 | grade 4 | 6 x 29 and 1 x 28 | ja-kanji-18 to 24 |
| JA-124 to 130 | grade 5 | 6 x 28 and 1 x 25 | ja-kanji-25 to 31 |
| JA-131 to 137 | grade 6 | 6 x 27 and 1 x 29 | ja-kanji-32 to 38 |

The grade 1 list (80) is the seven in `ja-kanji-1` plus the 73 above; grade 2 is the 160 above. Both were counted (no repeats, no overlap); the reviewer checks them against the grade table.

#### The task table

Fields common to all rows: branch is `decks/ja-<topic>` off `decks-live`; "Not touched" always includes every file not named; the fixed rule 1 and 2 apply.

| Id | Branch | Creates / edits | Content rules | Inputs | Expected output | Owns (shared) | Not touched | Lane, parallel |
|---|---|---|---|---|---|---|---|---|
| JA-001 | decks/ja-kanji-path | edit `decks/ja/ja-path.yaml` | Replace the planned units `ja-kanji-2` to `-6` (grammar `script-kanji-2` to `-6`, words 0) by planned units `ja-kanji-2` to `ja-kanji-38`, in grade order, spread from the A1 milestone to the B1 milestone (about one per 2.4 units), each after the units that teach the words its examples will use; at least one other unit between two kanji units; each with one listening and one reading passage in English naming taught kanji | the path file, the grade table above | one path edit, 37 planned kanji entries | the path (batch 1) | everything else | B, first; PARALLEL with A and C |
| JA-002 | decks/ja-culture-2 | create `ja-culture-2`, layer `ja-en-culture-2`; edit `creators/ja.yaml` | RULE-CULT, 18 items. Candidate works (title and creator only): Tosa Nikki (Ki no Tsurayuki), Taketori Monogatari (anonymous), Genji Monogatari (Murasaki Shikibu), a waka of Ono no Komachi, Tsurezuregusa (Yoshida Kenko), Heike Monogatari (anonymous), Manyoshu poems by Kakinomoto no Hitomaro and Otomo no Yakamochi, Makura no Soshi-era court women's diaries (Izumi Shikibu), Basho's disciples Kikaku and Joso, Chikamatsu Monzaemon (Sonezaki Shinju), Zeami (Fushikaden), Ihara Saikaku, Yosa Buson's prose, Kobayashi Issa's diary. Reserve: Fujiwara no Teika, Saigyo, Sugawara no Michizane | `wiki/Plan-Culture-Japanese.md`, `ja-culture-1.yaml` as the template | 18 cards, about 12 creators, 1 era if new | creators/ja.yaml (batch 1) | topics, recommendations, path | A, first; PARALLEL |
| JA-003 | decks/ja-proverbs-2 | create `ja-proverbs-2`, layer | RULE-PV, 20 cards from the Edo iroha karuta set not yet used | ja.wikipedia page on the iroha karuta | 20 cards | none | creators, topics | C; PARALLEL |
| JA-004 | decks/ja-multiword-suru | create `ja-multiword-suru-verbs`, layer | RULE-MW, `pattern_family: "suru-verb"`, 20 noun plus する verbs already taught as nouns (refs) | taught nouns of the path | 20 cards | none | other | C after 003 |
| JA-005 | decks/ja-culture-3 | `ja-culture-3`, layer, creators | RULE-CULT, 18 items. Candidates: Ishikawa Takuboku (Ichiaku no Suna), Miyazawa Kenji (Kaze no Matasaburo), Akutagawa (Kumo no Ito), Kaneko Misuzu (poems), Nakahara Chuya, Kajii Motojiro (Lemon), Higuchi Ichiyo (Takekurabe), Mori Ogai (Maihime), Natsume Soseki (Botchan), Dazai Osamu (Hashire Merosu), Kitahara Hakushu (Kono michi), Masaoka Shiki's tanka, Yosano Akiko's other tankas. Dazai (died 1948) and later authors need the floor check | as 002 | 18 cards | creators (batch 2) | as 002 | A; after 002 merges |
| JA-006 | decks/ja-proverbs-3 | `ja-proverbs-3`, layer | RULE-PV, 20 cards from the Kamigata (Kyoto and Osaka) iroha karuta sets | ja.wikipedia | 20 | none | | C |
| JA-007 | decks/ja-multiword-compound-2 | `ja-multiword-compound-verbs-2`, layer | RULE-MW, `compound-verb`, 20 more verb stem plus verb pairs (not in the first deck) | | 20 | none | | C, PARALLEL with 005 |
| JA-008 | decks/ja-culture-4 | `ja-culture-4`, layer, creators | RULE-CULT, 18 items. Candidates: anonymous songs first published before 1900 (Kagome Kagome, Edo lullabies, work songs, Soran Bushi), Kokinshu and Shin Kokinshu poems by Saigyo and Fujiwara no Teika, Hyakunin Isshu compilation, Noh and kabuki by Zeami and Chikamatsu if not used in 002, Sei Shonagon's contemporaries, Kamo no Chomei's second work, Kobayashi Issa's later haiku. Visual or music works are not culture cards here (no text to show): they go to recommendations | | 18 | creators (batch 2) | | A after 005 |
| JA-009 | decks/ja-multiword-idioms | `ja-multiword-idiomatic-verbs`, layer | RULE-MW, `pattern_family: "idiomatic-verb"`: fixed verb phrases built on ki, me, te, kuchi, atama (ki ni naru, me ga au...), 20 cards, meaning not literal; the literal reading in a note | | 20 | none | | C |
| JA-010 | decks/ja-topics-culture | edit `ja-topics.yaml` | add 8 culture topics (haiku, waka and tanka, classical prose, Heian court, Edo literature, school songs, proverbs, modern literature): each `summary` in English, `decks` and `cards` of the culture, proverb and multiword decks that exist | merged culture decks | 8 topics | `ja-topics.yaml` (batch 3) | | A |
| JA-011 | decks/ja-topics-kanji | edit `ja-topics.yaml` | 6 `kind: "script"` topics, one per grade: `decks` and `chars` copied from the merged kanji decks (no char taught in none of them) | merged kanji decks | 6 topics | `ja-topics.yaml` (after JA-010) | | B, after the grade decks merge |
| JA-012 | decks/ja-recommendations-2 | edit `recommendations/ja.yaml`, `creators/ja.yaml` | 20 works not in the public domain (film, series, book, song, play, comic), the shape of the nine existing, 3 to 8 questions each, no quote, no link unless checked; creators added where needed | the file | 20 entries | recommendations, creators (batch 3) | | A |
| JA-013 | decks/ja-situations-2 | edit `ja-situations.yaml`, layer | 4 sheets (hotel, post and bank, greetings and apologies, emergencies), widely used words and phrases only, no over-translation | situations rules | 4 sheets | situations file | | C |
| JA-014 to 022 | decks/ja-notes-1 to -9 | edit the cores and layers named | RULE-NOTE. The files per task (cards without notes in brackets): 014 about-me 6, addressing 6, adjectives-2 14, adverbs 6, animals 10, appearance 17, arts 8, body 8, business 8, calendar 10, careers 8, chores 18 (all `-sentences`) plus `ja-calendar` 2; 015 cinema, clothes, cooking, daily-life, demonstratives, describing, directions, eating-out, emergencies, environment, everyday-verbs, family, feelings sentences, plus `ja-clothes`, `ja-demonstratives`, `ja-family` 1 each; 016 festivals, food, geography, government and the grammar sentences case-particles to more-particles; 017 grammar sentences nagara-tari to te-kudasai, groceries, health; 018 help to market sentences; 019 more-verbs to quantities sentences plus `ja-numbers-1-20` 2, `ja-pronouns` 1; 020 questions to things sentences plus `ja-questions`, `ja-seasons` 1; 021 time to workplace sentences; 022 `ja-en-hiragana` (40 cards: a note on the sound or the look-alike) | the named files | notes where a point exists | none | other files | any lane, PARALLEL with all |
| JA-023 to 029 | decks/ja-unit-money, -society, -university, -food-culture, -literature, -verbs-5, -abstract-words | the unit's files (RULE-UNIT) | order: money 45 words, society 50, university 50, food-culture 50, literature 50, verbs-5 50, abstract-words 55; the rules rows | the path entries | per unit: core, layer, sentences, reading, rules rows, path entry | path and the rules decks (serial) | | D, serial |
| JA-030 to 038 | decks/ja-gram-conjunctions, -adjective-past, -likes, -comparison, -relative, -sonkeigo, -kenjougo, -transitivity, -teineigo | RULE-UNIT | grammar units as planned in the path | the path entries | per unit: rules core, layer, sentences, reading | path and rules decks (serial) | | D, serial after 029 |
| JA-039 | decks/ja-ipa-family | edit `ja-family.yaml` | add the broad `ipa` to the 6 cards, by `tools/transcribe.py ja` | | 6 cards | | | last-batch prep, PARALLEL |
| JA-040 | decks/ja-phonetics-rules | create `decks/ja/ja-phonetics.yaml` | **Sonnet.** `kind: "phonetics"`, ordered regex rules over the broad `ipa`, each with a `source`; only well-attested rules (vowel devoicing, moraic nasal assimilation, the usual allophones), nothing guessed. The validator's IPA test refuses U+1D5D (compressed-vowel mark): use combining marks only, and report if a rule needs it | the Plan-Ipa page, `decks/es/es-phonetics.yaml` as the shape | one rules file | | | last |
| JA-041 | decks/ja-ipa-run | edit every `decks/ja/**` file via the tools | run `tools/import_phonetic.py ja --write`, then `tools/derive_phonetic.py ja --write`, report counts (filled, unchanged, invalid) | JA-040 merged, every content PR merged | `phonetic` and `phonetic_source` on every card; no hand edit | every `decks/ja` file | | last, serial |
| JA-042 to 044 | decks/ja-queue-1 to -3 | edit `docs/review-queue/ja.md` | append the rows from the reports of the batch, one line each, table shape of the file | the reports | rows | the file | | after each batch |
| JA-045 | main, docs | edit the build-deck skill (narrow IPA tools exist, `ja` is waiting for a rules file), the #378 checklist, `Plan-Language-Completeness` | straight to main | the audit above | 3 edits | | | docs |
| JA-046 | decks/ja-facts | create `decks/ja/ja-facts.yaml` | Deck-Format "Facts files": 30 short, true, surprising facts, each tagged, each read from a ja.wikipedia page; uncertain ones left out | | one file | | | C |

### C. Blockers that need code or tools

Each is a separate issue to open (owner: "For each blocker create separate issues"), and each is language-agnostic. Checked and **not** blockers: conjunction and particle tables (Bengali and Assamese built conjunctions as vocab decks with a set card, and `ja-grammar-case-particles` is a rules deck), the narrow-IPA deriver (`tools/derive_phonetic.py`, per-language `decks/<lang>/<lang>-phonetics.yaml`, built for es, bn, hi), the kanji format (ADR-0053, `target_scripts`, #994), and the source-it-yourself recommendations (built in the app).

#### B1. Structured character data on script-unit cards

- **Title:** Script-unit cards carry structured character data: readings by kind, level, strokes, radical.
- **Generic mechanism:** an optional `character` block on a card of a script deck: `readings` (a list of `{ kind, text, reading }`), `level` (a named scheme and its value), `strokes` (a number), `radical` (a character). The model, the parser, the validator and Deck-Format get it. Today a kanji's on and kun readings, and a hanzi's, are only prose in a layer's note, so no filter, no question and no search can use them.
- **Data a language supplies:** the reading kinds it has, with names for the app (`on`, `kun` for Japanese; `pinyin` for Chinese), the script each kind's text is written in, and its level schemes (`grade`, `jlpt`; `hsk`). The language entry or the path carries them; no language name appears in `lib/` or `tools/`.
- **Languages that would use it:** Japanese (1,026 kanji), Chinese (the `characters-N` decks), Cantonese, Korean hanja.
- **Fixture:** `zz` with a character deck of three cards (two readings kinds, one with a level and strokes), one card with a reading in the wrong script (error), one with a negative stroke count (error), a layer carrying the prose as before.
- **AGENTS.md fit:** a language is data (kinds and schemes are data); `lib/core` stays Flutter-free; a new card field is refused by released apps, so the deck files that use it carry a `decks/min_app.json` entry (ADR-0052); card ids untouched; tests check behaviour. Until it lands, the kanji tasks keep the readings in the fixed note shape, and a later task migrates them.

#### B2. Character gating: a card shows only the characters the path has taught

- **Title:** A path can gate a script: a card or example may use only the characters already taught.
- **Generic mechanism:** a path declares, per script, `character_gating: { script, mode }` (`warn` or `error`) with an optional allow-list. For each unit position the validator computes the set of characters taught so far by the path's character decks (script-tagged decks in `alphabet`, one character per card) and checks every target, example and `target_scripts` spelling in a unit at that position: a character of a gated script not yet taught is reported. A card whose spelling is written in another script of the language (kana) is not checked.
- **Data a language supplies:** the gated script ids, the mode, the allow-list (a character that is taught outside a deck, such as a repeat mark).
- **Languages that would use it:** Japanese (kanji), Cantonese and Chinese if their courses gate hanzi, Korean for hanja.
- **Fixture:** `zz` path with a character unit of two characters; a sentence in a later unit using only those: ok; a sentence using a third: error; the same sentence in a unit before the character unit: error; `mode: warn` turns the error into a warning; a sentence in the language's other script: ok.
- **AGENTS.md fit:** pure data in the path; no language branch in the validator; the existing checks are untouched when `character_gating` is absent, so no existing deck changes; `lib/core` untouched. It turns the builder rule of JA-1nn ("show a kanji only if taught") into a CI check.

#### B3. Script topics: `chars` checked against the listed decks

- **Title:** A script topic's `chars` must match the cards of its `decks`, and a tool writes them.
- **Generic mechanism:** for a topic of `kind: "script"` that lists `decks`, the validator checks that every character in `chars` is the `target` of a card of those decks (or a `script_units` feature) and that no single-character card of those decks is left out; `tools/topic_chars.py <lang>` writes `chars` from the decks, so a topic of 200 kanji is never copied by hand. Today `chars` is only checked for shape (`validate_decks.py`, the topics checks), so a copy error ships.
- **Data a language supplies:** none beyond the topic's own `decks`.
- **Languages that would use it:** every language with script topics: Japanese (hiragana, katakana, six kanji grades), Bengali, Hindustani, Telugu and the other Indic scripts, Chinese.
- **Fixture:** `zz` topics file: a topic whose `chars` match its deck (ok), one with an extra character (error), one missing a card's character (error), one with only `script_units` (ok); the tool run on a copy writes the matching list.
- **AGENTS.md fit:** a generic tool and a generic check driven by existing data; no new card field; stdlib and PyYAML only like the other tools; tests added beside the tool.

### Verification notes

Counts above come from reading every `decks/ja/*.yaml` on decks-live with PyYAML (cards, notes, ids, `ipa`, `phonetic`) and the path file. The grade 1 and 2 lists were counted (80 including the seven built, 160) with no repeats. The culture, proverb and multi-word candidate lists name works and creators only; their dates and legal basis are read by the builder from the creator's Japanese Wikipedia page, as in Plan-Culture-Japanese, and the reviewer owns the legal opinion. Nothing in this page was run through the validator; CI does that on each pull request.
