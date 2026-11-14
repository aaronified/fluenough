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
5. **No local tests, no local validator, no tag, no new branch after a merge.** CI checks the pull request. Pull requests target `decks-live`. One Sonnet review per pull request. `decks/min_app.json` is owned by the kanji tasks alone, one line each (see "Kanji lanes"); no other task edits it.
6. **Sources.** A date or legacy claim is read from the creator's or work's Japanese Wikipedia page by the builder. What was not read goes to the review queue as unverified. Nothing from memory is asserted as checked.
7. **No quoted text.** Works are named by title and creator. A card carries only what its kind allows (the batch-1 shape), never a passage longer than that shape; nothing is copied from a translation, a dictionary or a lyric sheet. Translations are the builder's own plain renderings.
8. **Review-queue rows** are written into the task's report (and the pull request description), one line each in the file's table shape. Only the task that owns `docs/review-queue/ja.md` in a batch edits it; the batch's `JA-04x` task collects the rest.
9. **Shared files** (`decks/creators/ja.yaml`, `decks/ja/ja-topics.yaml`, `decks/recommendations/ja.yaml`, `docs/review-queue/ja.md`, `decks/ja/ja-path.yaml`, the rules decks) have exactly one owner per batch, named in the task. A task that does not own a shared file never edits it. The one exception is stated under "Kanji lanes".
10. **Genre decks are not on the path.** A deck with a `genre` (culture, proverbs, multiword) needs no path edit; a vocab, rules or script deck without one must be listed on the path in the same pull request.
11. **One base per word per card.** In a layer BASES list, list each base word once per card, even if it occurs twice in the text (validator: `bases[n].word X is given twice`).
12. **Plain English meanings.** A base `meaning` is plain English only: no kana, kanji or romanisation (validator: `has no transliteration beside it`).
13. **Latin notes.** A layer NOTE is Latin prose. Every Japanese word or kanji in it is followed by its Latin reading in parentheses (Hepburn, the same as the deck readings), for example `四 (shi)`.
14. **Hepburn readings.** Readings follow kana-based Hepburn, as the merged decks do: とお is `oo`, おう is `ou`, the particle は is `wa` in readings and IPA, and geminates are written (`jottsɯ`, not `jotsɯ`). Read each kanji's readings from the cited source page, never from memory.
15. **Dates and lifespans.** A `date` field uses a shape `tools/validate_decks.py` `parse_years` accepts: a year, `c. YEAR` or `A-B`. Explanations go in notes. A creator's born and died must satisfy the validator's `MAX_LIFESPAN` (120).

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
| 15b | Examples for the kanji cards built without them | per flag | JA-048 to JA-050 |
| 16 | Docs: stale statements (build-deck skill says narrow IPA tools are unbuilt; #378 and Plan-Language-Completeness counts) | 3 small edits | JA-045 |
| JA-048 to 050 | decks/ja-kanji-examples-1 (decks ja-kanji-2 to 9), -2 (10 to 24), -3 (25 to 38) | edit the cores and layers of those kanji decks | After the word units JA-023 to JA-029 have merged: for every card flagged "no example" or "one example" in the review queue, add examples to two by the procedure of the kanji rules, now with the larger taught vocabulary; edit only those cards, ids and every other field unchanged; remove none of the flags (the reviewer does) | the review-queue rows, the decks | cards with two examples | none | everything else | after JA-029; each PARALLEL with the others |
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

- **RULE-CULT.** Template: `decks/ja/ja-culture-1.yaml` and its layer, `decks/creators/ja.yaml`, `wiki/Plan-Culture-Japanese.md` ("Rules applied"). 18 items per deck, short items first, level A2 or B1 per item. Public-domain basis only: the author died in 1955 or earlier (the validator floor), an anonymous work first published before 1900; no `quotation` items; each item has the batch-1 `source` block. Text shown in modern kana. Each creator: a short A2-level bio, dates (`circa` where uncertain), era, a legacy line with one or two checkable items each with a source link, no image. Candidates are taken in the order listed in the task: the first 18 that pass are the deck and the rest are the reserve. The excerpt is no longer than the longest excerpt in `ja-culture-1`. A creator whose dates the builder could not read, or an item whose text it could not read on the page, is dropped and replaced from the reserve list; it is never filled in.
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
- **Examples: an exact decision procedure.** An example is a short sentence of taught words (a card of a deck on the path before this unit's place, or an earlier kanji deck), with `target_scripts.kana`, `reading`, `ipa`, `words`. A kanji is **taught for this purpose if its card is in an earlier kanji deck or anywhere in this deck** (any card, any order): so 先生 is allowed in the deck that teaches both 先 and 生. A word may be shown in kanji only if every kanji in it is taught in this sense; its okurigana and every other word are in kana. No new vocabulary is ever added to make an example. For each kanji K, in order:
  1. List the taught words whose standard spelling uses K (read the spelling on ja.wiktionary). Write up to two examples with K shown in kanji. Two found: done.
  2. Exactly one found: build the card with that one example and write a review-queue row "one example".
  3. None found, but the word K stands for alone (its card reading) is a taught word: write one example in which that word is written with K; row "one example".
  4. Still none: build the card **with no `examples`** and write a review-queue row "no example: no taught word uses this kanji". The kanji is never dropped, never moved and never left out ("Do not leave anything in the middle"); its examples come later from the retrofit tasks JA-048 to JA-050 once more vocabulary is taught. Card, id, readings, meaning and notes are complete as always.
  Expected thin cards the builder can predict (they still follow the procedure): in JA-101 貝 玉 王 左 右; in JA-102 糸 字 手 正 生 青 石 赤 先 (先 and 生 now give 先生 and 学生 as taught words once both are taught in the deck); in JA-103 虫 竹 力 林 立. The 9 JA-102 kanji the builder left unbuilt are built by the same builder with the procedure above, on the same branch.
- **The rule for when new sentences may show kanji (proposed here, default taken):** in any card or example written after JA-001, a kanji is written as a kanji only if it is taught by then (its card is in a kanji deck at an earlier path position, or earlier in the same deck). Every other kanji in that sentence is written in kana. Existing kana decks are untouched and ids never change (ADR-0053). Until blocker B2 lands this rule is the builder's and the reviewer's, not the validator's.
- Uncertain readings, grade membership or meanings: one review-queue row per kanji, in the report.
- **min_app.** Every kanji deck's examples use `target_scripts`, so the deck's file gets one line in `decks/min_app.json` under `files`: `"decks/ja/ja-kanji-N.yaml": "0.8.1"` (the same value as `ja-kanji-1`), added in the same pull request. `tools/deck_index.py` does not gate this automatically (only the kinds in `MIN_APP_KINDS` are gated that way), and it refuses an entry only for a file the latest release tag already contains, which a new file is not. The layer file needs no entry. Add the line in path order inside `files`; the kanji tasks are the only ones to touch this file, and a rebase conflict there is theirs to report.
- **Names, exactly.** Branch `decks/ja-kanji-N`, core `decks/ja/ja-kanji-N.yaml` with `id: "ja-kanji-N"`, layer `decks/ja/en/ja-en-kanji-N.yaml` with `id: "ja-en-kanji-N"`, `core: "ja-kanji-N"`, `kind: "layer"`, `name: "Kanji N: grade G, part P"` (the shape of `ja-en-kanji-1`: name, a description saying it is not yet checked by a Japanese speaker, licence, tags `script` and `unreviewed`), N being the task number minus 99. The Branch column below is the only branch the task uses.
- Not touched: `ja-topics.yaml` (JA-011), the path outside the task's own entry, other kanji decks.

**Kanji lanes (the one exception to rule 9).** JA-001 first rewrites the five planned kanji units into 37 planned units and spaces them with at least one other unit between every two, so the entries never touch. A kanji task then edits only its own entry, and its one `decks/min_app.json` line. Two kanji lanes may run at once under this rule; if a rebase finds a conflict in the path or in `min_app.json`, the builder stops and reports.

Each kanji task writes its own decks/min_app.json line at 0.8.1 for its deck (stated exception to rule 5).

| Task | Kanji (grade) | Count | Branch (exact) | Deck, ids |
|---|---|---|---|
| JA-100 | **Done (Sonnet, docs on main):** the exact lists for grades 3 to 6 (200, 202, 193, 191 = 786, no repeats, none missing, checked against the Wikipedia grade table) and the split into JA-109 to JA-137 are in the rows below; grades 1 and 2 are the lists above, unchanged | docs | none |
| JA-101 | 一右雨円王音下花貝学気九休玉空犬見五口校左三山子 (1) | 24 | decks/ja-kanji-2 | ja-kanji-2, ids ja-5000 to ja-5059 |
| JA-102 | 四糸字耳七車手十出女小上森人正生青夕石赤千川先早 (1) | 24 | decks/ja-kanji-3 | ja-kanji-3, ids ja-5060 to ja-5119 |
| JA-103 | 草足村大男竹中虫町天田二入年白八百文本名目立力林六 (1) | 25 | decks/ja-kanji-4 | ja-kanji-4, ids ja-5120 to ja-5179 |
| JA-104 | 引羽雲園遠何科夏家歌画回会海絵外角楽活間丸岩顔汽記帰弓牛魚京強教 (2) | 32 | decks/ja-kanji-5 | ja-kanji-5, ids ja-5180 to ja-5239 |
| JA-105 | 近兄形計元言原戸古午後語工公広交光考行高黄合谷国黒今才細作算止市 (2) | 32 | decks/ja-kanji-6 | ja-kanji-6, ids ja-5240 to ja-5299 |
| JA-106 | 矢姉思紙寺自時室社弱首秋週春書少場色食心新親図数西声星晴切雪船線 (2) | 32 | decks/ja-kanji-7 | ja-kanji-7, ids ja-5300 to ja-5359 |
| JA-107 | 前組走多太体台地池知茶昼長鳥朝直通弟店点電刀冬当東答頭同道読内南 (2) | 32 | decks/ja-kanji-8 | ja-kanji-8, ids ja-5360 to ja-5419 |
| JA-108 | 肉馬売買麦半番父風分聞米歩母方北毎妹万明鳴毛門夜野友用曜来里理話 (2) | 32 | decks/ja-kanji-9 | ja-kanji-9, ids ja-5420 to ja-5479 |
| JA-109 | 丁予化区反世主仕他代写去号央平打氷由申皮皿礼両全列 (3) | 25 | decks/ja-kanji-10 | ja-kanji-10, ids ja-5480 to ja-5539 |
| JA-110 | 向守安州式曲有次死羊血住助医君坂対局役投決究豆身返 (3) | 25 | decks/ja-kanji-11 | ja-kanji-11, ids ja-5540 to ja-5599 |
| JA-111 | 事使具取受味命和始委定実岸幸所放昔服板油波注泳物者 (3) | 25 | decks/ja-kanji-12 | ja-kanji-12, ids ja-5600 to ja-5659 |
| JA-112 | 育苦表乗係品客屋度待急拾持指昭柱洋炭界畑発相県研神 (3) | 25 | decks/ja-kanji-13 | ja-kanji-13, ids ja-5660 to ja-5719 |
| JA-113 | 秒級美負追送重面倍勉員宮島庫庭息旅根流消病真荷起速 (3) | 25 | decks/ja-kanji-14 | ja-kanji-14, ids ja-5720 to ja-5779 |
| JA-114 | 配酒院動商問宿帳悪族深球祭章笛第終習転進部都勝寒悲 (3) | 25 | decks/ja-kanji-15 | ja-kanji-15, ids ja-5780 to ja-5839 |
| JA-115 | 暑期植歯温港湖湯登着短童筆等落葉軽遊運開陽階集飲想 (3) | 25 | decks/ja-kanji-16 | ja-kanji-16, ids ja-5840 to ja-5899 |
| JA-116 | 意感暗業漢福詩路農鉄様緑練銀駅鼻横箱調談整橋薬館題 (3) | 25 | decks/ja-kanji-17 | ja-kanji-17, ids ja-5900 to ja-5959 |
| JA-117 | 不井夫欠氏付令以功加包司失必未末札民辺争仲伝兆共印各好成灯 (4) | 29 | decks/ja-kanji-18 | ja-kanji-18, ids ja-5960 to ja-6019 |
| JA-118 | 老衣阪位低佐児兵冷初別利努労完岐希折改材束求沖臣良芸例典刷 (4) | 29 | decks/ja-kanji-19 | ja-kanji-19, ids ja-6020 to ja-6079 |
| JA-119 | 卒協参周固奈季官岡底府径念松果治法泣牧的芽英阜便信勇単城変 (4) | 29 | decks/ja-kanji-20 | ja-kanji-20, ids ja-6080 to ja-6139 |
| JA-120 | 建昨栃栄浅省祝約茨要軍飛香倉候借孫害差席帯徒挙料案梅残浴特 (4) | 29 | decks/ja-kanji-21 | ja-kanji-21, ids ja-6140 to ja-6199 |
| JA-121 | 笑訓連郡健側副唱埼崎巣康敗望梨械清産票菜貨陸鹿博媛富散景最 (4) | 29 | decks/ja-kanji-22 | ja-kanji-22, ids ja-6200 to ja-6259 |
| JA-122 | 極満滋無然焼結給街覚賀達量隊順飯働塩愛戦照節続置試辞群察徳 (4) | 29 | decks/ja-kanji-23 | ja-kanji-23, ids ja-6260 to ja-6319 |
| JA-123 | 旗漁熊種管説関静億器標潟熱縄課輪選養機積録観類験鏡願競議 (4) | 28 | decks/ja-kanji-24 | ja-kanji-24, ids ja-6320 to ja-6379 |
| JA-124 | 久士仏支比刊句可史圧布弁旧永犯示仮件任再因団在似余判告囲 (5) | 28 | decks/ja-kanji-25 | ja-kanji-25, ids ja-6380 to ja-6439 |
| JA-125 | 均序志応快技条災状防価制効妻居往性招易枝武毒河版肥舎述非 (5) | 28 | decks/ja-kanji-26 | ja-kanji-26, ids ja-6440 to ja-6499 |
| JA-126 | 保則厚型政故査独祖紀迷逆限修個容師格桜殺留益破粉素耕能脈 (5) | 28 | decks/ja-kanji-27 | ja-kanji-27, ids ja-6500 to ja-6559 |
| JA-127 | 航財造停務基堂婦寄常張得情授採接救断液混率現略眼移経術規 (5) | 28 | decks/ja-kanji-28 | ja-kanji-28, ids ja-6560 to ja-6619 |
| JA-128 | 設許貧責険備喜営報属復提検減測程税統絶証評象貯貸費貿過勢 (5) | 28 | decks/ja-kanji-29 | ja-kanji-29, ids ja-6620 to ja-6679 |
| JA-129 | 墓夢幹損準禁罪義解豊資鉱飼像境増態慣構歴演精綿総製複適酸 (5) | 28 | decks/ja-kanji-30 | ja-kanji-30, ids ja-6680 to ja-6739 |
| JA-130 | 銅際雑領導暴潔確編賛賞質燃築興衛輸績講謝織職額識護 (5) | 25 | decks/ja-kanji-31 | ja-kanji-31, ids ja-6740 to ja-6799 |
| JA-131 | 亡寸己干仁収尺片冊処幼庁穴危后吸存宅宇机灰至舌乱卵否困 (6) | 27 | decks/ja-kanji-32 | ja-kanji-32, ids ja-6800 to ja-6859 |
| JA-132 | 孝忘我批私系並乳供券刻呼垂宗宙宝届延忠承担拝拡枚沿若奏 (6) | 27 | decks/ja-kanji-33 | ja-kanji-33, ids ja-6860 to ja-6919 |
| JA-133 | 姿宣専巻律映染段泉洗派皇看砂紅肺胃背退革俳俵値党射将展 (6) | 27 | decks/ja-kanji-34 | ja-kanji-34, ids ja-6920 to ja-6979 |
| JA-134 | 座従恩朗株班秘納純胸蚕討針降陛除骨域密捨探推欲済異盛窓 (6) | 27 | decks/ja-kanji-35 | ja-kanji-35, ids ja-6980 to ja-7039 |
| JA-135 | 翌脳著視訪訳郵郷閉頂割創勤善尊就揮敬晩棒痛筋策衆裁装補 (6) | 27 | decks/ja-kanji-36 | ja-kanji-36, ids ja-7040 to ja-7099 |
| JA-136 | 詞貴傷幕暖源盟絹署聖腸腹蒸裏誠賃預層暮模疑磁穀誌認誤銭 (6) | 27 | decks/ja-kanji-37 | ja-kanji-37, ids ja-7100 to ja-7159 |
| JA-137 | 閣障劇敵権潮熟蔵誕論諸遺奮憲操樹激糖縦鋼優厳縮覧簡臨難臓警 (6) | 29 | decks/ja-kanji-38 | ja-kanji-38, ids ja-7160 to ja-7219 |

The grade 1 list (80) is the seven in `ja-kanji-1` plus the 73 above; grade 2 is the 160 above. Both were counted (no repeats, no overlap); the reviewer checks them against the grade table.

**Kanji lists and card shape (JA-100, read 2026-11-14).** Sources: Japanese Wikipedia 学年別漢字配当表 (the official grade table, order within a grade is reading order) and English Wikipedia "Kyōiku kanji" (numbers 1 to 1,026, strokes, on and kun readings, short meanings), both read 2026-11-14. Verified: grades 1 to 6 are 80, 160, 200, 202, 193, 191 = 1,026 (the 2020 table; grade 4 gained 20 prefecture kanji, so the older 200/185/181 counts no longer hold); both pages agree on every grade's set; grades 1 and 2 above equal the pages' sets; the 786 kanji of JA-109 to JA-137 have no repeat and none is missing. Order inside a grade: fewest strokes first (a component usually has fewer strokes than the kanji built on it), ties in the English page's number order; the lists below are plain characters, the rows keep the ids reserved above (`ja-(5000 + 60 x (nn - 1))`, 60 ids per task).

Card shape, as in `decks/ja/ja-kanji-1.yaml` and `decks/ja/en/ja-en-kanji-1.yaml` on `decks-live`: deck header `schema: 1`, `id: "ja-kanji-N"`, `part: "core"`, `kind: "vocab"`, `language: { code: "ja", iso639_3: "jpn", name: "Japanese", script: "han", scripts: ["han", "kana"], tts: "ja-JP" }`, `license: "CC-BY-SA-4.0"`, `tags: ["script", "unreviewed"]`. Each card: `id`, `target` (the kanji), `target_scripts: { kana: "..." }`, `words: ["<kanji>"]`, `reading` (romaji), `ipa` (broad), `pos: "letter"`, `notes: [{ id: "n1", kind: "usage" }]`, `bases: "self"`. The English layer (`kind: "layer"`, `core`, `native: { code: "en", ... }`, `name`, `description`) maps each card id to `native` (a short meaning) and `notes.n1` in the RULE-KANJI shape. Where to read the data: on and kun readings, strokes and the short meaning from the English Wikipedia "Kyōiku kanji" table; the readings are re-written in the builder's own words, never pasted from a dictionary. Anything a builder cannot read there or is unsure of goes to the review queue as unverified.

#### The task table

Fields common to all rows: branch is `decks/ja-<topic>` off `decks-live`; "Not touched" always includes every file not named; the fixed rule 1 and 2 apply.

| Id | Branch | Creates / edits | Content rules | Inputs | Expected output | Owns (shared) | Not touched | Lane, parallel |
|---|---|---|---|---|---|---|---|---|
| JA-001 | decks/ja-kanji-path | edit `decks/ja/ja-path.yaml` only | **Exact procedure.** (1) Delete the five planned entries whose `planned.id` is `ja-kanji-2`, `-3`, `-4`, `-5`, `-6` (each is the `- planned: { id: "ja-kanji-N", grammar: "script-kanji-N", words: 0 }` line and its `listening_passages` and `reading_passages`). They are path unit names, not cards, so deleting and renumbering them touches no card id and no history. The `ja-kanji-1` entry (`- decks: ["ja-kanji-1"]`, `words: 0`, `milestone: "A1"`) and its place in `alphabet` stay as they are. (2) Insert 37 new entries, one per N from 2 to 38, each directly **after the unit whose id is the anchor** in the list below (an anchor is a unit's first `decks` entry, or `planned.id` for a planned unit; ids, not line numbers). Two kanji entries never share an anchor, and every anchor is a non-kanji unit, so at least one other unit sits between two kanji units. Entry shape, with N filled in: `  - planned: { id: "ja-kanji-N", grammar: "script-kanji-N", words: 0 }` then `    listening_passages:` with `      - { id: "kanji-N-heard", text: { "en": "Hearing words whose kanji unit N teaches" } }` then `    reading_passages:` with `      - { id: "kanji-N-signs", text: { "en": "Reading signs and short lines that use the kanji taught up to unit N" } }`. (3) No `words`, `milestone` or `alphabet` change: the entries count 0 words, the milestones stay on `ja-kanji-1` (A1), `ja-geography` (A2) and `ja-grammar-teineigo` (B1), and the header comment's word totals stay. **The rule:** the 37 decks are spread evenly after `ja-kanji-1`: grades 1 to 4 (23 decks, ja-kanji-2 to 24) over the 39 non-kanji units between `ja-help` and `ja-geography` (anchor index floor(j x 39 / 23) minus 1, j = 1 to 23), grades 5 and 6 (14 decks, ja-kanji-25 to 38) over the 45 non-kanji units between `ja-geography` and `ja-grammar-teineigo` (index floor(j x 45 / 14) minus 1, j = 1 to 14). Anchors: ja-kanji-2 after ja-daily-life; 3 after ja-grammar-te-kudasai; 4 after ja-seasons; 5 after ja-grammar-te-iru; 6 after ja-grammar-conjunctions; 7 after ja-weather; 8 after ja-grammar-plain-present; 9 after ja-shopping; 10 after ja-grammar-adjective-past; 11 after ja-eating-out; 12 after ja-grammar-permission; 13 after ja-hobbies; 14 after ja-grammar-comparison; 15 after ja-music; 16 after ja-grammar-giving-receiving; 17 after ja-grammar-obligation; 18 after ja-chores; 19 after ja-verbs-3; 20 after ja-phone; 21 after ja-journey; 22 after ja-nature; 23 after ja-grammar-potential; 24 after ja-grammar-intention; 25 after ja-feelings; 26 after ja-grammar-quotation; 27 after ja-grammar-te-auxiliaries; 28 after ja-grammar-relative-clauses; 29 after ja-business; 30 after ja-manners; 31 after ja-cinema; 32 after ja-history; 33 after ja-festivals; 34 after ja-housing; 35 after ja-law; 36 after ja-onomatopoeia; 37 after ja-society; 38 after ja-verbs-5. When a kanji deck is later written its words come from the units before its anchor, so its examples are never circular. If the file differs from decks-live f7ec2370 (an anchor missing), stop and report. | the path file | one path edit, 37 planned kanji entries, 5 removed | the path (batch 1) | everything else | B, first; PARALLEL with A and C |
| JA-002 | decks/ja-culture-2 | create `ja-culture-2`, layer `ja-en-culture-2`; edit `creators/ja.yaml` | RULE-CULT, 18 items. Ordered candidates (work, creator): 1 Tosa Nikki, Ki no Tsurayuki; 2 Taketori Monogatari, anonymous; 3 Genji Monogatari, Murasaki Shikibu; 4 a Kokin Wakashu waka, Ono no Komachi; 5 Tsurezuregusa, Yoshida Kenko; 6 Heike Monogatari, anonymous; 7 a Manyoshu poem, Kakinomoto no Hitomaro; 8 a Manyoshu poem, Otomo no Yakamochi; 9 a waka, Izumi Shikibu; 10 a haiku, Kikaku; 11 a haiku, Joso; 12 Sonezaki Shinju, Chikamatsu Monzaemon; 13 Fushikaden, Zeami; 14 Koshoku Ichidai Otoko, Ihara Saikaku; 15 Oraga Haru, Kobayashi Issa; 16 a Manyoshu poem, Yamanoue no Okura; 17 a Kokin Wakashu waka, Ki no Tomonori; 18 a Kokin Wakashu waka, Oshikochi no Mitsune; reserve 19 Fujiwara no Toshiyuki, 20 Henjo | `wiki/Plan-Culture-Japanese.md`, `ja-culture-1.yaml` as the template | 18 cards, up to 18 creators, an era only if new | creators/ja.yaml (batch 1) | topics, recommendations, path | A, first; PARALLEL |
| JA-003 | decks/ja-proverbs-2 | create `ja-proverbs-2`, layer | RULE-PV, 20 cards: the Edo iroha karuta proverbs in iroha order (starting from い), skipping those already in `ja-proverbs-1` (list its ids and targets first), taking the first 20 whose text the builder read on the page | ja.wikipedia page on the iroha karuta | 20 cards | none | creators, topics | C; PARALLEL |
| JA-004 | decks/ja-multiword-suru | create `ja-multiword-suru-verbs`, layer | RULE-MW, `pattern_family: "suru-verb"`. Selection: scan the cores of `ja-work`, `ja-school`, `ja-business`, `ja-technology`, `ja-phone`, `ja-hobbies`, `ja-sports` in that order, cards in id order, and take each `pos: "noun"` card whose entry on ja.wiktionary lists a noun plus する verb, until 20; the noun is written by `ref`, the card's `target` is the noun plus する (modern kana), `words` is the two parts. Fewer than 20 found: report the count, do not fill | taught nouns of those decks | 20 cards | none | other | C after 003 |
| JA-005 | decks/ja-culture-3 | `ja-culture-3`, layer, creators | RULE-CULT, 18 items. Ordered candidates (work, creator): 1 Ichiaku no Suna, Ishikawa Takuboku; 2 Kaze no Matasaburo, Miyazawa Kenji; 3 Kumo no Ito, Akutagawa Ryunosuke; 4 a poem, Kaneko Misuzu; 5 a poem, Nakahara Chuya; 6 Lemon, Kajii Motojiro; 7 Takekurabe, Higuchi Ichiyo; 8 Maihime, Mori Ogai; 9 Botchan, Natsume Soseki; 10 Hashire Merosu, Dazai Osamu; 11 Kono michi, Kitahara Hakushu; 12 a tanka, Masaoka Shiki; 13 a tanka, Yosano Tekkan; 14 Yume Juya, Natsume Soseki (a second item for the creator, no new creator row); 15 a poem, Ishikawa Takuboku (second item, no new row); 16 a poem, Hagiwara Sakutaro (died 1942); 17 Gongitsune, Niimi Nankichi (died 1943); 18 a short story, Izumi Kyoka (died 1939); reserve 19 a second poem, Yosano Akiko; 20 a second poem, Miyazawa Kenji. Every item passes the floor check (died 1955 or earlier) or is dropped | as 002 | 18 cards | creators (batch 2) | as 002 | A; after 002 merges |
| JA-006 | decks/ja-proverbs-3 | `ja-proverbs-3`, layer | RULE-PV, 20 cards: the Kyoto and Osaka (Kamigata) iroha karuta proverbs in iroha order, skipping any whose meaning is already in proverbs-1 or -2, the first 20 whose text the builder read on the page | ja.wikipedia | 20 | none | | C |
| JA-007 | decks/ja-multiword-compound-2 | `ja-multiword-compound-verbs-2`, layer | RULE-MW, `compound-verb`. Pairs: the stem of a verb taught in `ja-everyday-verbs`, `ja-more-verbs`, `ja-verbs-3` or `ja-verbs-4` plus one of these second verbs: だす, すぎる, あう, かえる, なおす, こむ, あげる, おす, わすれる, きる, かける, つく. Take pairs in the order of that second-verb list and card ids, only those attested as compound verbs on ja.wiktionary, until 20, excluding the 8 targets of `ja-multiword-compound-verbs` | the decks named | 20 | none | | C, PARALLEL with 005 |
| JA-008 | decks/ja-culture-4 | `ja-culture-4`, layer, creators | RULE-CULT, 18 items. Ordered candidates (work, creator): 1 Kagome Kagome, anonymous; 2 an Edo lullaby, anonymous; 3 Soran Bushi, anonymous; 4 Kuroda Bushi, anonymous; 5 a poem from Sankashu, Saigyo; 6 a Shin Kokinshu poem, Fujiwara no Teika; 7 to 14 eight Hyakunin Isshu poems by eight different poets not used in 002, 005 or earlier, taken in poem-number order, skipping poets whose dates are unknown; 15 Ise Monogatari, anonymous; 16 Sarashina Nikki, the daughter of Sugawara no Takasue; 17 Ukigumo, Futabatei Shimei (died 1909); 18 the Kana preface of Kokin Wakashu, Ki no Tsurayuki; reserve 19 Konjaku Monogatari, anonymous; 20 a second Saigyo poem. Visual and music works are not culture cards (no text to show): they go to recommendations | | 18 | creators (batch 2) | | A after 005 |
| JA-009 | decks/ja-multiword-idioms | `ja-multiword-idiomatic-verbs`, layer | RULE-MW, `pattern_family: "idiomatic-verb"`. The 20 targets, in kana: きになる, きにいる, きをつける, きがつく, きにする, めがあう, めをとおす, めをさます, てがかかる, てをかす, てをぬく, くちがかるい, くちをだす, あたまにくる, あたまをひやす, はなにつく, みみにする, ほねがおれる, うでをみがく, かおがひろい; one that ja.wiktionary or ja.wikipedia does not attest is dropped and replaced, in order, by きがきく, めがたかい, みみがいたい. Meaning not literal; the literal reading in a `usage` note | | 20 | none | | C |
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

## Sentence gate rules (Spanish and Hindustani sentence tasks)

Owner, 2026-11-14: "More clean Spanish and Hindi sentences would bring them back [placement sentence picks], and that is deck work. Then list them as issues and then do them in their decks." Issues #1244 (Spanish) and #1245 (Hindustani). The gate is `lib/core/placement/sentence_gate.dart` (PR #1240, not yet merged on 2026-11-14), the failing cards are listed in `docs/placement-bad-sentences.md` on the same branch. The audit measures how guessable a pick is from word-pair cues; Spanish passes the 0.32 bound only if its eligible sentences grow beyond n = 185 with varied structures, and Hindustani (about 70 eligible) needs about 130 or more. The bound is not loosened. Rules 1 to 10 above apply to every task here.

**Every new sentence card must satisfy all of these** (a card that cannot is not written; the builder reports it):

1. **Whole sentence:** one complete thought with a finite verb, 4 to 10 words in the target (words counted by spaces), ending with a full stop (`.` in Spanish, `।` or `.` as the course's cards do in Hindustani) or a question mark. No phrase, no fragment, no gloss, no title.
2. **Faithful full translation:** the layer's `native` is one English sentence that says everything the target says and nothing more: capital letter, end mark, 2 to 16 words, no brackets for notes inside the meaning, one meaning only (no `;` alternatives), not cut at a comma, not a word-for-word gloss.
3. **Same mood on both sides:** a target with `?` has a meaning that ends in `?`, and the other way round. Within one task about 20 of the 25 sentences are statements and about 5 are questions; the questions are spread through the deck, not grouped.
4. **Taught words only:** every word is a word of a deck listed on the path at or before the task's unit (its cards, or a closed-class word such as an article, a preposition or a particle that the course teaches). A word not taught is not used; the builder never adds vocabulary to make a sentence work.
5. **No template text:** no `…`, `...`, `___`, braces, `TODO` or `???`, in the target or the meaning. A sentence about a name or a place uses a real name or place.
6. **Script:** the target is in the course's script only (Latin for Spanish; Devanagari for Hindustani, no Latin letter in it), never mixed.
7. **Unique:** no target and no meaning equal to any other card of the course (search the language's decks first), so the right pick can be told from the wrong ones.
8. **Not a question card:** the new cards are ordinary cards of a sentences deck, never a reading deck's question.

**Variety rules** (the audit rewards sentences that cannot be guessed from a pair of words):

- **Frames are strict.** A frame is a sentence's skeleton: subject, verb form and the shape of its complement (for example "I + am + adjective", "you + want + noun + place"). No two sentences of a task share a frame, and no two start with the same two words more than twice. No two sentences differ by a single word.
- **Verb cap by pool.** Count the task's pool P: the verb lemmas taught on the path up to the task's unit (cards with `pos: "verb"` of the decks listed there, plus verbs the unit's grammar decks teach, such as a reflexive or a copula-like verb). If P is 13 or more, no verb is used more than twice; if P is 8 to 12, no verb more than three times; if P is under 8 the task is not run and is reported. A sentence count the cap cannot reach (verbs x cap) is never forced: the task ships fewer sentences.
- **Counts are 20 to 25, never padded.** A task ships between 20 and 25 sentences (12 or 15 for a repair task, as stated in its row). It never repeats a frame to reach 25. The scale below applies to the number n shipped: about n/5 questions (the rest statements); at least floor(n/5) sentences in each length group (4 to 5 words, 6 to 7, 8 to 10); at least five different shapes (a plain statement, a question, a negative, a past or future form, a time or place phrase, two verbs, a reason or a contrast); at least min(8, P) different verbs; no content noun more than twice.
- Lengths and shapes are measured per task, not per deck.
- Every sentence uses at least one word of the task's own unit and, across the task, at least 10 different words from earlier units, so the bank is not all one theme.
- The wrong options of a pick are drawn from other cards by the app: write each sentence so that its meaning is not guessable from a single word it shares with its `confusables`.
- Order: shuffle, so that no run of three cards has the same shape or mood.

**Card shape:** the shape of the unit's existing sentences deck (`pos: "phrase"`, `tags: ["sentence"]` in Spanish, `bases` for every word with a `ref` where the word is a card and `base` where it is a closed-class word or an inflected form, `confusables` of 2 with a `why` in the layer, notes where the sentence has one point). No `phonetic` and no `phonetic_source` in any new card: they are written only by the tools (ES-010 and HI-007). Card ids are never changed or reused.

### Spanish (`es`)

State on decks-live ddcff92f: 102 path units, none planned; 2,536 cards, highest id `es-3124` (the ranges below start at `es-3200`); 66 sentences decks, each with about six sentences, so a deck grows by appending. Spanish conventions: `ipa` from `python3 tools/transcribe.py es "<sentence>"` (the decks use the Spain pronunciation, `θ`), no `reading` (Latin script), meanings in the layer, `native` capitalised with the Spanish inverted marks kept on the target (`¿...?`), the target starts with a capital and ends with its mark.

#### Spanish repairs (failing cards in `docs/placement-bad-sentences.md`)

The cards below are not sentences (phrases) or duplicate an earlier card. A card's meaning never changes and ids are permanent, so **none is edited**: the gate leaves them out and that is correct. ES-009 writes full-sentence replacements for what they taught.

| Card | Target | Cause | Replaced by (ES-009) |
|---|---|---|---|
| es-0065 | a qué hora | phrase | 2 sentences asking at what time something happens |
| es-0262 | mi nombre es | fragment | 2 sentences giving a name with a real name |
| es-0341 | todos los días | phrase | 2 sentences with "every day" |
| es-0934 | por la mañana | phrase | 2 sentences with "in the morning" |
| es-0935 | por la tarde | phrase | 2 sentences with "in the afternoon" |
| es-1217 | el centro comercial | phrase | 2 sentences with the shopping centre |
| es-0097, es-0103 | ¿cómo te llamas?, ¿Cómo se llama usted? | same meaning | none: later card is dropped by the gate; new sentences must not repeat either meaning |
| es-1000 | Mi cumpleaños es en mayo. | same meaning | none: do not write another birthday-in-May sentence |

#### Spanish tasks

Each ES-001 to ES-008 appends 25 sentences to **one existing sentences deck** (core and layer), so no path edit is needed. Files are disjoint, so **ES-001 to ES-009 may all run in parallel** (three builders at a time). Branch is `decks/es-<topic>`; ids are `es-` plus four digits from the reserved range, ascending.

| Id | Branch | Edits (append only) | Taught-words scope (path units up to) | Ids | Cards |
|---|---|---|---|---|---|
| ES-001 | decks/es-sent-about-me | `decks/es/es-about-me-sentences.yaml`, `decks/es/en/es-en-about-me-sentences.yaml` | unit of `es-about-me` (7) | es-3200 to 3239 | 25 |
| ES-002 | decks/es-sent-food | `es-food-sentences`, `es-en-food-sentences` | `es-food` (26) | es-3240 to 3279 | 25 |
| ES-003 | decks/es-sent-directions | `es-directions-sentences`, `es-en-directions-sentences` | `es-directions` (28) | es-3280 to 3319 | 25 |
| ES-004 | decks/es-sent-shopping | `es-shopping-sentences`, `es-en-shopping-sentences` | `es-shopping` (43) | es-3320 to 3359 | 25 |
| ES-005 | decks/es-sent-hobbies | `es-hobbies-sentences`, `es-en-hobbies-sentences` | `es-hobbies` (49) | es-3360 to 3399 | 25 |
| ES-006 | decks/es-sent-journey | `es-journey-sentences`, `es-en-journey-sentences` | `es-journey` (57) | es-3400 to 3439 | 25 |
| ES-007 | decks/es-sent-health | `es-health-sentences`, `es-en-health-sentences` | `es-health` (65) | es-3440 to 3479 | 25 |
| ES-008 | decks/es-sent-travel | `es-travel-sentences`, `es-en-travel-sentences` | `es-travel` (72) | es-3480 to 3519 | 25 |
| ES-009 | decks/es-sent-repairs | `es-time-sentences`, `es-en-time-sentences` | `es-time` (32); a function whose words are not taught by then is reported and skipped | es-3520 to 3559 | 12 (the table above) |
| ES-010 | decks/es-sent-phonetics | every new card of ES-001 to 009 via the tools | after all nine merge | none | tool run |
| ES-011 | none (Sonnet, no PR) | runs the placement audit on the new Spanish bank and reports F5 and F17 accuracy against 0.32 at the new n; if it fails, the architect orders ES-012 onward (the same shape, other units: `es-money`, `es-news`, `es-weather`, `es-places`, ids from es-3600) | after ES-010 | none | audit |

**Verb pools, counted from the path position of each deck** (verb cards of the decks listed up to the unit; ES-001 also counts the verbs its unit's grammar teaches, 11 in all as its builder found: ser, estar, tener, ir, hablar, comer, estudiar, trabajar, sentir, llamarse, vivir):

| Task | Pool P | Cap per verb | Cards to ship |
|---|---|---|---|
| ES-001 | 11 | 3 | 20 to 25 (frames strict, no padding) |
| ES-002 | 47 | 2 | 25 |
| ES-003 | 55 | 2 | 25 |
| ES-004 | 102 | 2 | 25 |
| ES-005 | 141 | 2 | 25 |
| ES-006 | 213 | 2 | 25 |
| ES-007 | 233 | 2 | 25 |
| ES-008 | 265 | 2 | 25 |
| ES-009 | 64 | 2 | 12 (3 per length group, 2 questions, 6 shapes, 6 verbs at least) |

Content rules: the gate rules and the variety rules above; Spanish conventions above. Append at the end of the existing `cards:` and the layer's `cards:`; touch no existing card. The layer gives each new card `native`, `bases` meanings, `confusables` with `why`. The layer's `description` ("Six sentences...") is updated to the new count in the same edit. Not touched: any other file, the path, `decks/min_app.json`. Review-queue rows go in the report (rule 8). ES-010: `python3 tools/import_phonetic.py es --write` then `python3 tools/derive_phonetic.py es --write` (the tools skip cards that already have a form), report the counts.

### Hindustani (`hi`)

State on decks-live ddcff92f (the first Hindustani anchor, `hi-about-me` at unit 12, was dropped: no verb card is taught by then, only the copula, so no sentence with a taught verb exists; `hi-work` at unit 19 replaces it); 114 path units; 2,516 cards, highest id `hi-2835` (ranges start at `hi-2900`); only 15 sentences decks, so most themes have none and each HI task **creates a new sentences deck** for one unit. Conventions: Devanagari target with `target_scripts: { perso_arabic: "..." }` (the course offers Devanagari or the Perso-Arabic script, so every card has both, the Urdu spelling written as a native reader would, a doubtful spelling goes to the review queue), `reading` from `python3 tools/transcribe.py hi "<word>"` (letters based on ISO 15919: `maim̐`, `ē`, `ō`, long vowels with macrons; a word-final anusvara as the tool writes it; never write that it strictly follows ISO 15919), `ipa` from the same tool, `pos: "phrase"`, `bases` with `base` and `reading` for each inflected word, `confusables` with `kind`. Gender and honorific forms: a sentence about the speaker's own gender says so in the meaning ("said by a man") as the decks do; the verb agrees. Deck header as `hi-pronouns-sentences`: `kind: "vocab"`, `part: "core"`, `language` with `script: "devanagari"`, `scripts: ["devanagari", "perso_arabic"]`, tags `beginner` and `unreviewed`.

#### Hindustani repairs (`docs/placement-bad-sentences.md`)

Same principle: no existing card is edited. The gate leaves the phrases out, which is correct; HI-006 writes full sentences for what the template cards taught.

| Card | Target | Cause | Replaced by (HI-006) |
|---|---|---|---|
| hi-0188 | मेरा नाम … है। | template `…` | 3 sentences giving a name (a real name each) |
| hi-0190 | मैं … से हूँ। | template | 3 sentences naming a real city or country |
| hi-0191 | मैं … में रहता हूँ। | template | 3 sentences with a real place, one with रहती (said by a woman) |
| hi-0126, hi-0127 | तुम सुनते हो।, तू सुनता है। | same meaning | none; new meanings must differ ("You listen" is taken) |
| hi-0120, 0121, 0423, 0443, 0445, 0446, 0447, 0454, 1397, 1398, 1399 | noun phrases and infinitives (father's house, bedroom, to brush one's teeth, lunch, dinner, to go to work, usually, climate...) | phrase | HI-006: one sentence for each of the six everyday ones (teeth, lunch, dinner, work, bedroom, usually); the compound-with-ओ expressions are left as they are |

#### Hindustani tasks

Each task creates one new sentences deck (core and layer) and edits **only one line of `decks/hi/hi-path.yaml`**: the `decks:` list of its unit, inserting the new deck's core id directly after the unit's first entry (the one-line exception of "Kanji lanes": different lines, so the tasks stay parallel; a rebase conflict there is the builder's to report). `words` is unchanged. **HI-001 to HI-006 may run in parallel** with each other and with the Spanish tasks (three builders at a time overall).

| Id | Branch | Creates | Path line edited (unit's first deck) | Taught-words scope | Ids | Cards |
|---|---|---|---|---|---|---|
| HI-001 | decks/hi-sent-work | `decks/hi/hi-work-sentences.yaml`, `decks/hi/en/hi-en-work-sentences.yaml` | the unit of `hi-work` (19; its line is `decks: ["hi-work", "*"]`) | up to unit 19 | hi-2900 to 2939 | 25 |
| HI-002 | decks/hi-sent-food | `hi-food-sentences`, `hi-en-food-sentences` | `hi-food` (29) | up to 29 | hi-2940 to 2979 | 25 |
| HI-003 | decks/hi-sent-directions | `hi-directions-sentences`, `hi-en-directions-sentences` | `hi-directions` (36; its line lists `hi-grammar-continuous` after it) | up to 36 | hi-2980 to 3019 | 25 |
| HI-004 | decks/hi-sent-shopping | `hi-shopping-sentences`, `hi-en-shopping-sentences` | `hi-shopping` (53) | up to 53 | hi-3020 to 3059 | 25 |
| HI-005 | decks/hi-sent-health | `hi-health-sentences`, `hi-en-health-sentences` | `hi-health` (76) | up to 76 | hi-3060 to 3099 | 25 |
| HI-006 | DROPPED | Dropped 2026-11-14 by the architect: the vocabulary taught by unit 17 (hi-time) cannot support it. None of the six phrase functions (teeth, lunch, dinner, work, bedroom, usually) has its words taught by unit 17, no personal name is taught, and the only real place taught is दिल्ली, so at most 2 to 9 sentences were possible against the 12-sentence minimum. The unit has no sentences deck; its words are covered by the sentences decks of later units (HI-002, HI-003, HI-005). | none | none | none | none |
| HI-007 | decks/hi-sent-phonetics | every new card of HI-001 to 006 via the tools | none | after HI-001 to HI-005 merge | none | tool run |
| HI-008 | none (Sonnet, no PR) | runs the placement audit on the new Hindustani bank, reports F5 and F17 against 0.32 at the new n (need about 130 eligible or more; the task adds about 140); if it fails, follow-ups HI-009 onward are ordered with the same shape (`hi-work`, `hi-home`, `hi-weather`, `hi-money`, ids from hi-3200) | after HI-007 | none | audit |

**Verb pools, counted from the path position of each deck** (verb cards of the decks listed up to the unit): 

| Task | Pool P | Cap per verb | Cards to ship |
|---|---|---|---|
| HI-001 (unit 19) | 50 | 2 | 25 |
| HI-002 (unit 29) | 50 | 2 | 25 |
| HI-003 (unit 36) | 52 | 2 | 25 |
| HI-004 (unit 53) | 66 | 2 | 25 |
| HI-005 (unit 76) | 169 | 2 | 25 |
| HI-006 (unit 17) | 25 | 2 | DROPPED (see HI-006) |

Content rules: the gate and variety rules above. HI-007: `python3 tools/import_phonetic.py hi --write` then `python3 tools/derive_phonetic.py hi --write` (`decks/hi/hi-phonetics.yaml` exists), counts reported. Not touched: other decks, `decks/min_app.json`, existing cards. Review-queue rows in the report: every Perso-Arabic spelling the builder is not sure of, every gender or honorific choice, and every translation with a nuance.

### Counts

Spanish: 9 builder tasks, 1 tool run, 1 audit (11). Hindustani: 6 builder tasks, 1 tool run, 1 audit (8).
