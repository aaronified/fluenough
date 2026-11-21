# Deck work queue: Hindustani completion plan

**Status 2026-11-21:** Hindustani is Complete on the app's completeness measure (every planned word unit through B1 written, grammar topics and culture shelves full). What follows is the plan and audit of 2026-11-14 to 2026-11-17, kept as written: where it says something is missing or not built, the measure is the newer reading. Review status is not part of the measure.

Status: audit and plan of 2026-11-15, re-read on 2026-11-15 from `origin/decks-live` after the waves merged (PRs [#1394](https://github.com/aaronified/fluenough/pull/1394) Urdu spelling, [#1411](https://github.com/aaronified/fluenough/pull/1411) sentences, [#1409](https://github.com/aaronified/fluenough/pull/1409) kinds, [#1423](https://github.com/aaronified/fluenough/pull/1423) notes, [#1449](https://github.com/aaronified/fluenough/pull/1449) recommendations, [#1470](https://github.com/aaronified/fluenough/pull/1470) review-queue rows; all merged 2026-11-15). Rows marked *re-counted* were measured in that re-read; *not re-counted* rows were not measured in it. Still open: **IPA is BLOCKED** on issue [#1466](https://github.com/aaronified/fluenough/issues/1466) (`IPA_RE` rejects precomposed `ä`; the issue reports 475 of 3,443 forms invalid, quoted from the issue and not re-counted here), so the HI-110 rerun is pending; **culture 4 was not built** (no pre-1900 source readable on a page); culture 1 to 3 hold 6, 7 and 8 cards against a planned 18 each; compound-verbs multi-word has 5 of 20; **professional decks are held**. Owner instruction (2026-11-15): one session per language; this session owns Hindustani (`hi`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Hindustani. The shape is that of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Hindustani for "Japanese": Devanagari readings are ISO 15919 as `tools/transcribe.py hi` writes them, never by hand).

Hindustani is ONE course with two scripts (owner, 2026-10-18): `script: "devanagari"`, `scripts: ["devanagari", "perso_arabic"]`; a card's Urdu spelling is `target_scripts: { perso_arabic: "..." }`. Every deliverable that depends on script covers both. Grammar tables are full tables covering every word (owner, 2026-10-23).

State was read from `origin/decks-live` (2026-11-15) with PyYAML over every `decks/hi/**` file, `hi-path.yaml`, `decks/sections.yaml`, `decks/creators`, `decks/recommendations`, `docs/review-queue/hi.md`, `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | not re-counted | last audit: `hi-path.yaml`, 120 units | none recorded |
| 2 | Cores and English layers | not re-counted | last audit: 128 vocab and 34 grammar cores. Own cards now 3,448 (re-counted; top-level `vocab` or `grammar` decks, cards with `id` and no `ref`; 70 `ref` cards excluded) | none recorded |
| 3 | Sentences decks | PRESENT (re-counted) | 74 of 74 word decks have a `-sentences` deck. 76 sentences decks in all, 919 sentence cards; 2 of them (`hi-grammar-sentences`, `hi-grammar-comparison-sentences`) belong to no word deck. Per-deck size against the 10 to 25 spec not re-counted | none for the gap; size check not re-counted |
| 4 | Reading decks | PARTLY (re-counted) | 52 `hi-en-reading-*` decks at the top of `decks/hi/`. 45 of 74 word decks have one; 29 do not | HI-092 (audit first) |
| 5 | Script decks | not re-counted | last audit: Devanagari and Perso-Arabic script decks present | none recorded |
| 6 | Phrasebook | not re-counted | last audit: 20 cards (limit 25) | none recorded |
| 7 | Situations | PRESENT (re-counted) | `hi-situations.yaml`: 10 sheets, 8 to 9 phrases each (sheet content not re-checked) | sheet count matches HI-050; content not re-checked |
| 8 | Topics incl. script topics | PARTLY (re-counted) | `hi-topics.yaml`: 12 topics (kinds: 6 grammar, 3 verbs, 2 script, 1 words). No topic has kind `other`, so the HI-041 additions are absent | HI-041 |
| 9 | Culture decks | PARTLY (re-counted) | `hi-culture-1` 6 cards, `hi-culture-2` 7, `hi-culture-3` 8 (planned 18 each). `hi-culture-4` is not built: no pre-1900 source readable on a page | HI-010..012 short; HI-013 not built |
| 10 | Creators, eras, legacy | PRESENT (re-counted) | `decks/creators/hi.yaml`: 38 creators, 5 eras. Legacy rule not re-counted | creators against culture cards not re-counted |
| 11 | Proverbs | PARTLY (re-counted) | `hi-proverbs-1` 17 cards, `hi-proverbs-2` 18, `hi-proverbs-3` 20 (planned 20 each) | HI-020..022 short by 3 and 2 on 1 and 2 |
| 12 | Multi-word verbs | PARTLY (re-counted) | `hi-multiword-compound-verbs` 5 of 20; `hi-multiword-conjunct-verbs` 18, `hi-multiword-ko-experiencer` 9, `hi-multiword-muhavare` 17 (planned 20 each) | HI-030..033: compound-verbs to 20 and the other three families short |
| 13 | Professional | HELD (not re-counted) | `professions: []` not re-counted | none (needs the owner) |
| 14 | Recommendations | PARTLY (re-counted) | `decks/recommendations/hi.yaml`: 16 entries (planned 20) | 4 more to reach the plan |
| 15 | Narrow IPA and broad `ipa` | **BLOCKED** on #1466 | `phonetic` on 1,403 of 3,448 own cards; broad `ipa` on 3,432 (16 cards without). Invalid-form count from #1466 (475 of 3,443), not re-counted here | HI-110 rerun after #1466 is fixed; HI-112 for the 16 cards without broad `ipa` |
| 16 | Review-queue rows | PARTLY (re-counted) | `docs/review-queue/hi.md`: 90 table rows (10 dated 2026-11-07, 80 dated 2026-11-15) | HI-120..122 as waves land |
| 17 | Sourcing list | **MISSING** (checked) | `wiki/Plan-Culture-Hindustani.md` is not on `origin/main` | HI-001 |
| 18 | Facts file | not re-counted | last audit: `hi-facts.yaml`, 42 entries | none recorded |
| + | Urdu spelling (`target_scripts.perso_arabic`) | PARTLY (re-counted) | 2,271 of 3,448 own cards have it (1,177 without). Set-like script and phonology decks are not split out in this count | HI-100..105 for the remaining word cards |
| + | Notes gap | PARTLY (re-counted) | 2,611 of 3,448 own cards have `notes` (837 without) | HI-130..137 for the remaining gap |
| + | Grammar tables | NOT AUDITED | 34 grammar decks; the full-table rule (owner, 2026-10-23) needs a read by a Sonnet | HI-093 |

## 2. Conventions every HI task carries

- **Header of a genre deck:** as `es-culture-1` with `language: { code: "hi", iso639_3: "hin", name: "Hindustani", script: "devanagari", scripts: ["devanagari", "perso_arabic"], tts: "hi-IN", icon: "हि" }`, `part: "core"`, `kind: "vocab"`, `genre`, `level`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`; layer `decks/hi/en/hi-en-<name>.yaml`.
- **Readings and IPA:** `reading` and broad `ipa` come from `python3 tools/transcribe.py hi "<text>" <hint>` (the hint is the word as typed in Latin letters, which tells the tool what is said). Never hand-written. No `phonetic` and no `phonetic_source` on a new card: HI-110 writes them. The tool is run from `origin/main`'s `tools/`, which a worker checks out into its worktree and never commits.
- **Urdu spelling:** every new card with a Hindustani word has `target_scripts: { perso_arabic: "..." }`, read from ur.wiktionary or the Rekhta dictionary page; a spelling not read goes to the review queue and the card gets none (never guessed). Set-like script and phonology decks are skipped.
- **Ids:** the course's reserved range is `hi-4000` to `hi-6999` (highest id today `hi-3084`), sub-ranges per task below, ascending, never reused.
- **Rights floor for culture:** an author who died in 1955 or earlier (the validator floor); anonymous works need a first publication before 1900. Texts, dates and lifespans are read by the builder from hi.wikipedia, ur.wikipedia, hi.wikisource, ur.wikisource or Rekhta; what could not be read is dropped (never filled in) and replaced from the reserve. Excerpt at most 25 words. Both Devanagari text and its `perso_arabic` form when the work is in both traditions.
- **Review queue:** every row goes into the task's report; the batch's HI-12x task collects them into `docs/review-queue/hi.md`.
- **Validator traps** (CI failures seen so far): confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with one of the seven valid kinds (no `register`); a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; at most 25 `phrasebook: true` cards per course; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, one PR to `decks-live`, ONE Sonnet review (report-only), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs. No agent runs the validator or the tests.
- **Shared files, one owner per wave:** `decks/hi/hi-topics.yaml` (HI-040/041), `decks/hi/hi-situations.yaml` (HI-050/051), `decks/creators/hi.yaml` (the culture tasks in order, then recommendations), `decks/recommendations/hi.yaml` (HI-060/061), `docs/review-queue/hi.md` (HI-120..122).

## 3. Task table

### 3.1 Wave A: the genre kinds (branch `decks/hi-kinds-wave1`)

| Id | Model | Creates / edits | Spec | Ids | Depends on |
|---|---|---|---|---|---|
| HI-001 | Sonnet, docs to main | `wiki/Plan-Culture-Hindustani.md` | The sourcing list, as `Plan-Culture-Spanish`: candidates for culture 1 to 4 (4 x 18 plus reserves), proverbs 1 to 3 (3 x 20), multiword (4 x 20), recommendations (20), each verified on a named page; both traditions (Hindi and Urdu authors, Bhakti, Sufi, ghazal, modern prose and verse, folk) | none | none |
| HI-010..013 | Haiku | `hi-culture-1..4` + layers, `creators/hi.yaml` | RULE-CULT as in 2. Culture 1 bhakti and sant poets; 2 classical Urdu poets; 3 modern Hindi and Urdu prose and verse to 1955; 4 anonymous and traditional pre-1900 (lullabies, paheliyan, folk songs, tales). 18 items each, fewer rather than padded | `hi-4000..4199` | HI-001; serial on `creators/hi.yaml` |
| HI-020..022 | Haiku | `hi-proverbs-1..3` + layers | `genre: "proverbs"`, `basis: "oral-tradition"`, 20 cards each (kahavatein and lokoktiyan); `source` with `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`; one `literal` note per card; only text read on the cited page | `hi-4200..4349` | HI-001 |
| HI-030..033 | Haiku | `hi-multiword-*` + layers | `genre: "multiword"`, `pattern_family`, a `usage` note on every card. Families: conjunct verbs (noun + karnā/honā), compound or vector verbs (V + jānā, lenā, denā...), idiomatic muhāvare, ko-experiencer constructions; parts already taught by `ref` | `hi-4350..4549` | HI-001 |
| HI-040 | Haiku | `hi-topics.yaml` | As `es-topics`: 12 topics (kind `grammar`/`words`/`verbs`), real deck ids only: postpositions, ne and ergativity, honorifics, gender, the verb to be, tenses, conditionals, subjunctive, compound verbs, Persian and Arabic loanwords, both scripts (script topics: Devanagari, Perso-Arabic) | none | none |
| HI-041 | Haiku | edit `hi-topics.yaml` | 8 `kind: "other"` topics over the merged culture, proverbs, multiword decks | none | HI-010..033 merged |
| HI-050 | Haiku | `hi-situations.yaml` | Deck-Format "Situations files", rules of #1145; 10 sheets (taxi, shops, eat, doctor, traffic, rail, hotel, post and bank, greetings and apologies, emergencies), icon keys each once, 8 to 12 phrases and at most 12 words per sheet, ids real `hi-` cards; at most 12 new cards where a phrase is missing | `hi-4550..4599` | none |
| HI-060 | Haiku | `recommendations/hi.yaml` (10), `creators/hi.yaml` | Shape of `recommendations/es.yaml`: films, series and books in Hindi and Urdu, 3 questions each, no quote, no link, creators added | strings | HI-013 merged |
| HI-061 | Haiku | edit both | 10 more: books, songs, podcast, comic | strings | HI-060 |

### 3.2 Wave C-1: Urdu spelling (branch `decks/hi-urdu-spelling`)

HI-100..105: add `target_scripts.perso_arabic` to the word-deck cards that lack it (about 350 cards). Files and counts: hi-school 50, hi-illness 50, hi-hobbies 50, hi-cooking 50, hi-food 47, hi-body 32, hi-places 30, hi-animals 25, hi-things 18, hi-clothes 18, hi-pronouns 3, hi-describing 1; the `-sentences` decks carry the same gap (school, illness, hobbies, cooking 10 each, comparison 9, phone 3, chores 3, appearance 3). Each worker takes about 60 cards; source ur.wiktionary or Rekhta; unread goes to the queue.

### 3.3 Wave B: sentences decks (branch `decks/hi-sentences-wave1`)

HI-080..091: sentences decks for the 56 word decks without one, 12 workers of about 4 or 5 decks each, 10 to 25 sentences per deck by the verb-pool rule of the existing hi decks (look at `hi-food-sentences`), ids `hi-4600..4999` and `hi-5000..5999`. Decks: sound-differences, questions, addressing, family, numbers-1-20, about-me, time, numbers-big, groceries, market, transport, body, places, things, home, clothes, animals, daily-life, weather, calendar, festivals, eating-out, help, verbs-3, journey, nature, adjectives-2, workplace, geography, registers, arabic-words, feelings, slang, news, opinions, travel, services, government, technology, careers, environment, agriculture, cinema, arts, history, weddings, sports, relationships, housing, emergencies, law, verbs-4, abstract-words, money, literature, verbs-5. A deck whose unit teaches no verb the pool allows is reported, not forced.

### 3.4 Wave C-2: notes (branch `decks/hi-notes`)

HI-130..137: typed notes only where a card has one teachable point; ids in the core, text in the layer. Files with the most gaps (cards without a note): hi-numbers-big 77, hi-health-sentences 25, hi-food-sentences 25, hi-directions-sentences 25, hi-work-sentences 24, hi-shopping-sentences 20, hi-home 19, hi-numbers-1-20 18, hi-daily-life 13, then 40 more files with 11 or fewer.

### 3.5 Other tasks

| Id | Model | Spec |
|---|---|---|
| HI-092 | Haiku | List the 29 word decks without a reading deck and report which have a natural passage; builds nothing |
| HI-093 | Sonnet | Audit the 34 grammar decks against the full-table rule (every word of a kind has a row in every table of that kind); report gaps as new tasks |
| HI-110 | tool run | After all content PRs merge: `python3 tools/import_phonetic.py hi --write`, then `python3 tools/derive_phonetic.py hi --bracket-unchanged --write`; report counts; no hand edit. Read issue #1369 first (rule fixes and `--rederive` of PR #1372) |
| HI-111 | Sonnet | If HI-110's report shows rule gaps (Urdu-origin sounds q, x, ɣ, z; nukta consonants), extend `decks/hi/hi-phonetics.yaml` with sourced rules; one coder at a time |
| HI-112 | Haiku | Broad `ipa` for the 5 non-set cards that lack it, from `tools/transcribe.py`; the 11 phonology cards are checked first |
| HI-120..122 | Haiku | Append review-queue rows from each wave's reports to `docs/review-queue/hi.md` |
| HI-140 | Haiku, docs to main | Update the Hindustani row of [Plan-Language-Completeness](Plan-Language-Completeness.md) and issue #1167 from a re-read, claiming only what is verified |

### 3.6 Grammar tables (HI-093 audit, 2026-11-15; follow-ups HI-094 to HI-099)

**Audit result** (a read of `decks-live`, not a build):

- Hindustani has no rules decks. All 34 `hi-grammar-*` cores with `kind: "grammar"` use `pattern.entries` keyed by lemma, with hand-picked lemmas. The other 16 `hi-grammar-*` cores are vocabulary. No `table:` or `rules:` appears in `decks/hi`.
- Bengali has 14 rules cores (noun-forms 1,634 rows; verb tenses about 418 rows each). Hindustani is therefore 0 of 14 against the owner's full-table rule (2026-10-23).
- Taught words (cards of the cores on the path to the B1 mark, by part of speech; repeated cards may be double-counted): nouns 1,245, verbs 232, adjectives 181, pronouns 16.
- Coverage by the grammar decks (union):
  - nouns: 11 of 1,245
  - verbs: 211 of 232 (21 missing, e.g. मुड़िए, चलिए, बढ़ना, बढ़ाना, गुज़रना, झपटना)
  - adjectives: 11 of 181
  - pronouns: 8 of 16 (missing मेरा, तेरा, तुम्हारा, आपका, हमारा, उसका, कुछ, अपना)
- The 12-slot tense decks (present, future, past, perfect, continuous) cover only 2 to 4 verbs each.
- Habitual-past (211 of 232), subjunctive, conditional, conjunctive, purpose, before-after and while (162 to 177 of 232) are nearly full.
- Other decks: imperatives 77, past-continuous 82, causative 31, passive 27, reported-speech 3, honorifics 4, irregular 6.

**Follow-ups, ranked.** Each is a rules core plus its English layer `decks/hi/en/hi-en-grammar-*.yaml`, converting the existing grammar deck, with Bengali's layout as the reference.

- **HI-094 (XL)**: `hi-grammar-noun-forms`, 1,245 rows, with slots plural, singular oblique and plural oblique; indeclinables go in `except`.
- **HI-095 (XL)**: verb tense rules cores for present, future, past, perfect and continuous, 232 rows each, with 12 person-gender-number slots (about 2,800 cells each).
- **HI-096 (L)**: complete imperatives (77 to 232), past-continuous (82 to 232) and the 21 verbs missing from the near-full decks; decide whether these become rules cores.
- **HI-097 (L)**: `hi-grammar-adjective-forms`, 181 rows, with agreement slots, plus the comparative.
- **HI-098 (S)**: `hi-grammar-pronoun-forms`, 16 rows, including the possessives and कुछ.
- **HI-099 (S/M)**: decide causative, passive, reported-speech, honorifics and irregular: rules cores, or stay grammar decks.

**Open**

- The tables for HI-094 and HI-095 are thousands of cells of inflected Hindi. They must be written by a rule-based generator with a reviewed rule set (as Bengali's were), not by hand. A Sonnet designs the generator first.
- It is not yet determined whether the validator accepts a per-tense `except` list of defective verbs.
- **Owner decision needed:** whether this is in scope for Hindustani now, given its size.

## 4. Order

1. HI-001 (docs, main) first; HI-040, HI-050, HI-092, HI-093 and wave C-1 have no dependency and run at once.
2. Wave A culture tasks run serial on `creators/hi.yaml`; proverbs and multiword in parallel with them.
3. Waves B and C-2 touch disjoint files from wave A and run in parallel on their own branches.
4. HI-110 last, after every content PR has merged.

## 5. Open questions

- Professional decks need the owner's profession list.
- A source-it-yourself mode for recommendations is specified in [Plan-Language-Completeness](Plan-Language-Completeness.md) but not implemented; HI-060 and HI-061 use the shape of `recommendations/es.yaml`.

## 6. Pause and resume plan (2026-11-16)

Owner directive via the parent session (2026-11-16): at most four language sessions run at once, so Hindustani is paused after the narrow-IPA run and the open pull requests. **Merged to `decks-live` on 2026-11-15:** #1394 (Urdu spelling), #1411 (56 sentences decks), #1409 (topics, situations, culture 1 to 3, proverbs, multi-word decks, creators), #1423 (notes), #1449 (recommendations and creators), #1470 (review-queue rows), #1482 (six more topics). **Also merged on 2026-11-16:** #1498, the narrow-IPA run (HI-110; tool bug #1466 fixed by #1469): 1,908 own cards now have a `phonetic` (705 from Wiktionary, 1,203 from rules, of which 1,476 are the broad `ipa` bracketed unchanged); 19 cards whose Wiktionary form changed a phoneme had it removed and are in the review queue. Nothing is in flight.

Resume in this order, each as its own pull request to `decks-live` with one Sonnet review:

1. **HI-094 to HI-099, the grammar tables** (owner rule 2026-10-23; the parent confirmed it is in scope on 2026-11-15). Spec: [Plan-Hindustani-Grammar-Tables](Plan-Hindustani-Grammar-Tables.md) (hybrid: forms from a reviewed rule set, checked against the kaikki dump and the existing pattern decks, disagreements to the review queue; Devanagari only for now; 8 and 4 distinct-form slots; causative, passive, reported speech, honorifics and irregular stay pattern decks). One Sonnet coder builds all tables on the shared branch `decks/hi-grammar-tables`, in the plan's order (HI-094a pos audit, generator in scratch, noun-forms, verb tenses, adjectives, pronouns, then the path edit). The branch holds two commits (the HI-094a `pos:` edits in a few cores); the rest is unbuilt. Merge `decks-live` first, since new cards need a row in every table of their kind.
2. **Second notes pass** (owner directive 2026-11-15): write a note on every card with a real teachable point (word order, politeness, collocation, stem change, usage), not only cards with one clear point; only plainly self-explanatory cards stay without. Cards still without notes are those listed in the HI-130..137 reports and the 2026-11-15 queue rows.
3. **Culture and sourced-item retry** (owner directive 2026-11-15): before dropping an item, try every reachable source. Branch `decks/hi-culture-refill` (empty). Items: culture 1 (6 of 18), culture 2 (7), culture 3 (8), culture 4 (none built: pre-1900 date not found on a page), proverbs 1 (17 of 20) and 2 (18 of 20), compound-verb multi-word (5 of 20), conjunct (18), idioms (17), ko-experiencer (9), recommendations (dropped: Lag Jaa Gale, Sholay, Panchayat, Tamas, Hum Log, Ranjish Hi Sahi, the podcast). Candidates and reserves: [Plan-Culture-Hindustani](Plan-Culture-Hindustani.md). Id ranges free: culture `hi-4008` to `hi-4049`, `hi-4057` to `hi-4099`, `hi-4108` to `hi-4199`; proverbs `hi-4217` to `hi-4249`, `hi-4268` to `hi-4299`; multi-word `hi-4368` to `hi-4399`, `hi-4405` to `hi-4449`, `hi-4467` to `hi-4499`, `hi-4509` to `hi-4549`. Hosts: reachable are en, hi and ur Wikipedia, hi, ur and en Wikisource, hi and en Wikiquote, Wiktionary and Wikidata; **blocked by the proxy:** rekhta.org, archive.org, britannica.com. Wikimedia answers HTTP 429 when several workers read at once: fetch one request at a time with backoff and a cache, and use plain `curl` (a custom user agent drew more 429s; Python urllib's default is refused with 403). The Punjabi candidates of culture 1 (Bulleh Shah, Guru Nanak, Baba Farid, Namdev, Sultan Bahu, Waris Shah) wait on an owner question: only Hindi or Urdu-script verses read on a page count. Each dropped item gets a one-line reason in `docs/review-queue/hi.md`.
4. **Urdu forms in rules tables**: needs a shared-code change (per-script row forms) and a release; filed through the parent.
5. **Open owner questions:** professional decks; the Urdu-register policy for Sanskritised words (queue row); era labels.

Leftover branches for the owner to delete (agents cannot): `decks/hi-ipa` (empty, replaced by `decks/hi-ipa-2`), and after their pull requests `decks/hi-grammar-tables` and `decks/hi-culture-refill` are work branches for the plan above, not leftovers.

## 7. Idle: precise resume list (2026-11-17)

Hindustani went idle on the parent's instruction (at most two language sessions at once). Nothing is running; nothing is in flight as a pull request. Merged to `decks-live`: #1394, #1411, #1409, #1423, #1449, #1470, #1482, #1498 (see section 6). **Against the app measure, left to do:**

| Line | State on decks-live | What is left |
|---|---|---|
| Culture | 21 of 72 (`hi-culture-1` 6, `-2` 7, `-3` 8; `-4` not built) | 51 items. Branch `decks/hi-culture-refill` is empty. The 2026-11-17 attempt only searched: hi.wikisource search works after backoff (hits for Surdas Bhramargit-sar, Bihari Ratnakar, Kabir Granthavali, Dadu Vani; Mirabai's hi.wikipedia page gives 1498 to 1547); no verse was read in full yet. Next candidates: culture 1 Mirabai, Surdas, Bihari, Dadu, Jayasi (Padmavat), Raidas, Malukdas, Paltu Sahib; culture 2 Quli Qutb Shah, Wali, Dard, Insha, Mushafi, Atish, Momin, Anees, Dabeer, Dagh, Minai, Hali, Nazeer; culture 3 and 4 from [Plan-Culture-Hindustani](Plan-Culture-Hindustani.md). Hosts now reachable: archive.org, web.archive.org, gutenberg.org, dli.gov.in, britannica.com besides the Wikimedia sites; use plain `curl`, one request at a time, Python `time.sleep` backoff on 429, a cache; python urllib is refused with 403. Work files of the helper: scratchpad of the 2026-11-17 session, not kept. The Punjabi candidates stay an owner question. Devanagari titles for culture works are also owed. |
| Grammar tables | Not on decks-live. Branch `decks/hi-grammar-tables` (sha 3f169f41a) holds 14 tables built (core and layer each, `unreviewed`, structural checks only, no validator run): noun-forms 1,269 rows (20 nulls), ten verb tables 231 rows each (4 excepted inflected-form cards: दीजिए, चलिए, मुड़िए, चाहिए), adjective-forms 189 rows, pronoun-forms 11 rows (7 excepted), possessive-forms 7 rows; plus 22 `pos:` fixes (HI-094a). | **HI-099b**: add each new deck to its unit in `decks/hi/hi-path.yaml` after its pattern deck (plan 4.3) and the rule names to the unit's `grammar` list, and add the review-queue rows; then merge `decks-live`, re-run the generator for cards added since (cards without a row: noun 0, verb 0, adjective 0, pronoun 0 at the last merge), open ONE pull request, one Sonnet review. Open for the review queue (not yet written): पीना future and subjunctive `पीऊँ` (pattern deck) versus `पियूँ` (dump); छूना imperative `छुइए`; 15 nouns where the dump disagrees with the rules (12 feminine consonant nouns whose dump plural equals the singular: खाद, पैंट, जैकेट, प्लेट, भाप, चॉकलेट, परिषद, शतरंज, साइकिल, गेंद, जेल, शक्ल; and कोहनी, झाड़ू, and the -ो nouns हीरो, किलो, रेडियो, वीडियो, फ़ोटो); 26 nouns where the card's gender differs from the dump's; 12 months, यार and 4 spelling-variant nouns with a gender taken from the dump; adjectives शर्मिंदा, दिवालिया, खुदरा set invariable; the nasal `ṅ` versus `m̐` reading in the future table; 29 ā-stem verb readings from the tool's rules. Not done by design: HI-099a (causative, passive, reported speech, honorifics, irregular stay pattern decks), HI-096c. The generator script lives only in the scratchpad of that session (`gen/`: load.py, lib.py, forms.py, run.py, build.py, specs.py, make.py); a rebuild is from [Plan-Hindustani-Grammar-Tables](Plan-Hindustani-Grammar-Tables.md). Urdu forms in tables need the shared-code change (per-script row forms). |
| Genre decks | Proverbs 55 of 60, multi-word 49 of 80 (compound verbs 5), recommendations 16 of 20, topics 18 | Refill items in section 6 point 3; dropped recommendations: Lag Jaa Gale, Sholay, Panchayat, Tamas, Hum Log, Ranjish Hi Sahi, the podcast. |
| Professional | none (`professions` now lists medicine, hospitality, business in `decks/sections.yaml`) | Six decks as Kannada's #1540: medicine (clinic, pharmacy), hospitality (reception, restaurant), business (email, meeting); hidden, `unreviewed`, one Sonnet review. |
| Notes | about 2,600 of 3,448 own cards have notes | Second pass: a note on every card with a real teachable point (word order, politeness, collocation, stem change, usage); only plainly self-explanatory cards stay without. |
| Readings | 52 reading decks; 29 word decks have none | Build them (audit HI-092 never ran: which word decks have a natural passage). |
| Narrow IPA | 1,908 own cards with `phonetic`; 19 removed to the queue | Done unless cards are added; rerun the tools after new content. |
| Urdu spelling | 2,271 of 3,448 own cards | The cards in the review queue (no verified spelling). |
| Review queue | 90+ rows | Rows from the grammar tables and the refill. |

Order on resume: finish HI-099b and merge the grammar tables first (the work is built), then professional decks, then the culture and sourced-item retry, then notes, readings and the remaining genre items.
