# Deck work queue: Kannada completion plan

Status: audit and plan of 2026-11-15. Owner instruction (2026-11-15): one session per language; this session owns Kannada (`kn`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Kannada. The shape is that of [Deck-Work-Queue-GU](Deck-Work-Queue-GU.md), [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Kannada for "Japanese"). Kannada readings are ISO 15919-based, written by `tools/transcribe.py kn`, never by hand. Kannada is a Dravidian language close to Telugu in script and phonology: read the Telugu lessons in [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) (issues #1357, #1361, word-final handling) before the phonetics tasks.

State was read from `origin/decks-live` on 2026-11-15 with PyYAML over every `decks/kn/**` file and `kn-path.yaml`, plus `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/` and `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** | `kn-path.yaml`: 115 entries (110 units plus 5 mark lists), every unit has its deck; A1, A2 and B1 marks present | none (KN-090 checks the grammar tables) |
| 2 | Cores and English layers | **DONE** | 134 files directly in `decks/kn/` (96 vocab, 30 grammar, plus sounds, numbers, script, facts, romanisation, reading, path), 128 layers in `decks/kn/en/`; 2,003 cards, highest id `kn-1733` | none |
| 3 | Sentences decks | **BIG GAP** | only `kn-grammar-sentences`; none of the 96 vocab decks has a `-sentences` deck | KN-100..KN-1xx |
| 4 | Reading decks | **BIG GAP** | `kn-en-reading-ravi` and `kn-script-reading` only | KN-200..KN-2xx |
| 5 | Script decks | **DONE** | vowels, consonants, vowel signs, conjuncts, digits, reading, `kn-script`, `kn-spelling`, `kn-romanisation` (conjunct coverage to check) | KN-091 checks |
| 6 | Phrasebook | **DONE** | `kn-phrasebook`: 20 cards (limit 25) | none |
| 7 | Situations | **MISSING** | no `kn-situations.yaml` | KN-050 |
| 8 | Topics incl. script topics | **MISSING** | no `kn-topics.yaml` | KN-040 |
| 9 | Culture decks | **MISSING** | no `kn-culture-*` | KN-001, KN-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/kn.yaml` | rides on KN-010..013, 060 |
| 11 | Proverbs | **MISSING** | none (owner 2026-11-13: built for every priority language) | KN-020..022 |
| 12 | Multi-word verbs | **MISSING** | rules decks `kn-grammar-compound-verbs` and `kn-grammar-conjunct-verbs` exist (not genre decks) | KN-030..032 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/kn.yaml` | KN-060 |
| 15 | Narrow IPA and broad `ipa` | **GAP** | no `kn` entry in `tools/phonetic_languages.yaml`, no `decks/kn/kn-phonetics.yaml`; 0 of 2,003 cards have `phonetic`; 1,715 have a broad `ipa`, 288 do not | KN-110..112 |
| 16 | Review-queue rows | **PARTLY** | `docs/review-queue/kn.md`: 12 rows, all 2026-11-07 | KN-120 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Kannada` | KN-001 |
| 18 | Facts file | **DONE** | `kn-facts.yaml`: 44 facts | none |

## 2. Conventions every KN task carries

- **Header of a deck:** copy the exact block from `decks/kn/kn-first-words.yaml` (language code `kn`, `iso639_3: "kan"`, script, tts, icon as there), `part: "core"`, `kind: "vocab"` or `grammar`, `license: "CC-BY-SA-4.0"`, `tags: [..., "unreviewed"]`; layer `decks/kn/en/kn-en-<name>.yaml`. Read the build-deck skill and one built unit of the same kind first.
- **Readings and IPA:** `reading` and broad `ipa` from `python3 tools/transcribe.py kn "<text>" <hint>`, run from `origin/main`'s `tools/` checked out into the worker's worktree, never committed. Never hand-written. No `phonetic` on a new card: KN-110..112 write them.
- **Ids:** highest today `kn-1733`; the validator's `--next-id` is not run locally, so ranges are reserved: sentences `kn-7000..8499`, genre kinds `kn-6000..6999`. Sub-ranges per task, ascending, never reused.
- **Rights floor for culture:** author died 1955 or earlier; anonymous works first published before 1900. Every text, date and lifespan is read from kn.wikipedia, kn.wikisource, Wikipedia or a cited dictionary page; what cannot be read is dropped, never filled from memory. Excerpt at most 25 words.
- **Validator traps (CI failures seen so far):** confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with kind one of behaviour, culture, homograph, lookalike, note, pair, usage; a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` is a year, a range or `c. year` only; at most 25 `phrasebook: true` cards per course; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, ONE PR to `decks-live`, ONE Sonnet review (report-only, BLOCKING or NIT), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests.
- **Haiku guard (owner, 2026-11-10):** code a Haiku writes is in try/catch and reports every caught issue to the app logger and the report. Haiku never improvises: it stops and reports.
- **Shared files, one owner per wave:** `kn-topics.yaml` (KN-040), `kn-situations.yaml` (KN-050), `decks/creators/kn.yaml` (culture tasks in order, then recommendations), `decks/recommendations/kn.yaml` (KN-060), `docs/review-queue/kn.md` (KN-120).

## 3. Task table

| Id | Model | Branch | Spec |
|---|---|---|---|
| KN-001 | Sonnet | main (docs) | `Plan-Culture-Kannada`: verified sourcing list for culture (4 decks), proverbs (3), multi-word families, recommendations; nothing from memory |
| KN-100..KN-1xx | Haiku | `decks/kn-sentences-wave1` | One `-sentences` core and layer for each of the 96 vocab decks in path order, 2 to 3 confusables per card, notes where a base changes stem; word units only (grammar units have none) |
| KN-200..KN-2xx | Haiku | `decks/kn-readings-wave1` | One reading deck per word unit named by the path, built after its sentences deck exists |
| KN-010..013 | Haiku | `decks/kn-culture-wave1` | `kn-culture-1` to `-4` with creators and eras, from KN-001 only |
| KN-020..022 | Haiku | `decks/kn-proverbs-wave1` | `kn-proverbs-1` to `-3`, 20 cards each, `basis: oral-tradition` |
| KN-030..032 | Haiku | `decks/kn-multiword-wave1` | `kn-multiword-*` families (compound verbs, conjunct verbs, dative-subject, idiomatic) |
| KN-040 | Haiku | `decks/kn-topics-wave1` | `kn-topics.yaml`: script topics (vowels, consonants, conjuncts, digits) plus grammar, word and culture topics |
| KN-050 | Haiku | `decks/kn-situations-wave1` | `kn-situations.yaml`: 10 sheets, widely used phrases only, marked draft |
| KN-060 | Haiku | `decks/kn-recs-wave1` | `decks/recommendations/kn.yaml`, public-domain and source-it-yourself, from KN-001 |
| KN-090..091 | Sonnet | report only | Read the 30 grammar cores against the full-table rule (owner 2026-10-23) and script-conjunct coverage |
| KN-110..112 | Sonnet design, then tools | `phonetics/kn` (tools PR to main) | `kn` entry in `tools/phonetic_languages.yaml`, `decks/kn/kn-phonetics.yaml` rules (lessons of #1369 and Telugu #1390), then `import_phonetic.py`/`derive_phonetic.py` over all cards |
| KN-120 | Haiku | rides on each wave | Review-queue rows for every uncertain card |

## 4. KN-110: narrow IPA for Kannada (design and runbook, 2026-11-15)

Status: designed and built on two branches, not merged. No pull request is open.

| Part | Branch | What |
|---|---|---|
| Registry | `tools/kn-phonetics` (off main) | `kn` entry in `tools/phonetic_languages.yaml`: dump `Kannada`, `untagged: false`, no notes, no tags, no `normalise`. Rules only, as Assamese |
| Rules and cards | `decks/kn-phonetics-wave1` (off decks-live) | `decks/kn/kn-phonetics.yaml` (7 rules) and `phonetic` plus `phonetic_source: "rules"` on the 1,715 cards that had a broad `ipa` |

**Why no Wiktionary import.** The kaikki.org dump `Kannada` (9 MB, modified 2026-10-30, fetched through the proxy 2026-11-15) holds 27 narrow `[ ]` forms in all: letter and vowel-sign names, the anusvara with notes (`normally`, `before gutturals`, ...) and four words (ಕೊಟ್ಟಿಗೆ `[kɔʈ.ʈɪ.ɡɛ]`, ಬುಟ್ಟಿ `[buʈːi]`, ಪರ್ಣ `[parɳa]`, ಕಫ `[kɐ.fa]`) written with syllable dots and in three conventions. `import_phonetic.py kn --dump` reports 0 filled. The entry therefore takes no untagged form; flip `untagged` to true only after Wiktionary has word forms that agree with the rules.

**The rules** (order matters; sources are in each rule's `source`, the Kannada section of Wikipedia read 2026-11-15; Krishnamurti 2003 and Sridhar 1990 were not read):

| Id | Change | Why |
|---|---|---|
| `kn-n-dental` | n before t̪ or d̪ becomes n̪ | the broad `ipa` writes a plain n there (86 occurrences); the Telugu lesson of `te-n-dental` (PR #1433) |
| `kn-r-tap` | r becomes ɾ (not rr) | the table gives ɾ for ರ; the trill ಱ is archaic |
| `kn-a-central` | short a becomes ɐ, except in ai and au and aː | the vowel notes |
| `kn-i-lowered`, `kn-u-lowered`, `kn-e-lowered`, `kn-o-lowered` | short i u e o become ɪ ʊ ɛ ɔ when not word-final and not next to a vowel | "tend to be pronounced [ɐ ɪ ʊ ɛ ɔ]; in a final position less frequently" |

Retroflex and dental stops, aspirates, length, geminates and the nasals before velar, palatal and retroflex stops are already in the broad `ipa` (counted over decks-live: dental t̪ d̪ 783, ɖ ʈ 431, ɭ 152, ɳ 126, ʰ ʱ 150, ŋ ɲ 59), so no rule repeats them. Left out on purpose, and why, are in the file's `description`: ʂ to ʃ, palatalisation of k and ɡ before front vowels, glide onsets, the colloquial final e to i, the northern ts dz, and a reduced word-final u.

### Lessons carried from Telugu (TE-058, #1390) and Spanish (#1369)

- A rule is written only for what the broad `ipa` does not already say, and its order is checked: the three consonant rules never touch vowels, and `kn-a-central` runs before the lowering rules, whose lookbehind names ɐ.
- A rule whose scope is not attested is left out, not guessed (Telugu's affricate rule). Each lowering rule skips a vowel next to another vowel, so a diphthong glide or a hiatus is never changed.
- The tools write the cards, never a hand edit; the patch only adds two lines per card (`phonetic`, `phonetic_source`), nothing else changes.

### Runbook

Run last, serially, after every Kannada content PR (sentences, readings, culture, topics) has merged, because the narrow form derives from the broad `ipa` and a new card has none. Worktree off `origin/decks-live` with main's `tools/` laid over it (CI's `main-tools` does this); never in the main checkout; no tests and no validator locally.

1. Merge `tools/kn-phonetics` to main (one registry entry). Merge `decks/kn-phonetics-wave1` to decks-live (one Sonnet review; deck-only CI: "Validate decks" and "Released app reads the decks").
2. Cards added after that branch: `python3 tools/import_phonetic.py kn --write` (expected: 0 filled, a dump is fetched into `.cache/phonetic/` on the first run; to avoid the fetch, skip this step: nothing is imported), then `python3 tools/derive_phonetic.py kn --bracket-unchanged --write`. Expected: only the new cards are filled (cards that have a `phonetic` are skipped), `invalid` 0, `could not write (layout)` 0.
3. After any change to the rules file: `python3 tools/derive_phonetic.py kn --rederive --bracket-unchanged --write` re-derives every `rules` card; a card whose form does not change is not rewritten.
4. Counts on the branch (2026-11-15): 1,715 cards with a broad `ipa`: 1,513 filled, 202 unchanged and bracketed, 0 invalid. 288 cards have no broad `ipa` and get no `phonetic`: the broad `ipa` is the tools' job first (`tools/transcribe.py kn`).
5. Open for a phonetician (rules ship `unreviewed`): whether the lowering of short i u e o should be written for the standard (it is a tendency in one source, plus Wiktionary's one entry), and whether ʂ and the k/ɡ palatalisation should join. Drop a rule by deleting its entry and running step 3.

## 5. Progress, 2026-11-15

| Task | State |
|---|---|
| KN-001 | Done: [Plan-Culture-Kannada](Plan-Culture-Kannada.md) |
| KN-100 | Merged (#1464): 70 sentences decks; `kn-numbers-1-20`, `kn-quantities` still owed (too few earlier words; re-specify or widen the vocabulary rule) |
| KN-110 | Merged (#1462, #1463): registry entry, 7 rules, `phonetic` on 1,715 cards; the vowel-lowering rules need a phonetician; rerun derive last |
| KN-020..022 | Merged (#1467): 60 proverbs |
| KN-040 | Merged (#1465): 53 topics |
| KN-010..013 | **Held**: PR #1468 closed (English of the 3 Pampa lines wrong); no readable source for decks 2 to 4; branch `decks/kn-culture-wave1` left for the owner to delete |
| KN-120 | 42 rows added; more with each wave |
| KN-200.. | In progress: reading decks for word units (`decks/kn-readings-wave1`) |
| KN-050 | In progress (`decks/kn-situations-wave1`) |
| KN-030..032, KN-060 | Next: multi-word verbs (only verified families), recommendations with creators |

## 6. Pause and resume plan (2026-11-16)

Owner directive via the parent session: at most four language sessions at once, so Kannada is **paused**. No new worker starts until the parent says resume. Workers already running finish; four notes workers and the culture worker were cut off by the usage limit and are listed below with the state they left.

### 6.1 Open work at the pause

| Item | State | Resume action |
|---|---|---|
| PR #1486 situations | CI green | One review (running), merge when it has no blocker |
| PR #1487 recommendations and creators | **Held, review found blocking defects.** Format fixes are pushed (fields dropped, books name `script`), but: the briefing and questions of `kn-rec-mysooru-mallige` describe the 1992 film, not the 1942 poetry collection; `kn-rec-karnata-bharata-katha-manjari` says the epic ends with Duryodhana's death where the cited page says Yudhishthira's coronation; about 20 questions can be answered from the briefing or the title alone, and several test credits or locations, not the work (kittur-chennamma, samskara, vamsha-vriksha, ghatashraddha, kanooru-heggadithi, marali-mannige, bangarada-manushya, mayura, chomana-dudi, ondanondu, nagamandala q2 unverified) | Rewrite those briefings and questions from sources read, replace answerable-without-the-work questions with plot questions the briefing does not state, mark `born` of `kn-kumara-vyasa` circa, then merge. Dropped works: reasons in the review queue. The rights fields come back with task T23 |
| Merged #1486 situations | Merged 2026-11-16. Review nits to fix later: full-sentence cards in taxi, hotel, post-bank, doctor and emergencies sheets are not widely used phrases (kn-7790, kn-7792, kn-8254, kn-8255, kn-7518, kn-7859, kn-7814, kn-7815, kn-7451); kn-8299 "Move the car" is a rude imperative; kn-7445 reads "Where is the police?"; marginal words kn-1620, kn-1601, kn-1609, kn-1591; mixed title style |
| PR #1489 readings (53 word units, listed in `kn-path.yaml`) | CI failed on one reading the tool cannot produce (`ಆ್ಯಪ್`); the word is now written `ಆಪ್` | Wait for CI green and the review, merge |
| Branch `decks/kn-multiword-wave1` | 4 cards (`kn-6400..6402`, `kn-6350`), held: sources do not label the compound status and some glosses are the builder's | Do not open a PR. Re-source with Wiktionary and the Kannada grammar pages before building the other families (dative-subject, idiomatic, light verbs, passive) |
| Branch `decks/kn-culture-wave1` | PR #1468 closed (English of the three Pampa lines wrong) | Left for the owner to delete once `decks/kn-culture-wave2` replaces it |
| Branch `decks/kn-culture-wave2` | Sonnet retry cut off by the limit; saved work only | Resume the Sonnet (same task: try every reachable source, correct translations, report blocked hosts, a one-line reason for each dropped item) |
| Branch `decks/kn-notes-wave1` | Five Haiku note workers cut off. Each has a local worktree `/tmp/claude-0/kn-n0` to `kn-n4` with uncommitted work, which a new container will not have | Start again: the 826 cards without notes are split into five groups in the brief (`notes-brief.md`, in the session scratch; rewrite it from section 2 and the owner directive of 2026-11-15: a note on every card with a real teachable point, doubtful ones listed, never guessed) |
| `kn-numbers-1-20`, `kn-quantities` sentences | Not built (too few earlier words) | Widen the vocabulary rule to the unit and the whole of the first twelve path units, then build |
| `decks/kn/kn-phonetics.yaml` | Merged; 288 cards had no broad `ipa` | Last step of the course: rerun `derive_phonetic.py kn` after every content PR merged; ask a phonetician about the four vowel-lowering rules |

### 6.2 Order after the resume

1. Merge #1486, #1487, #1489.
2. Notes wave (five Haiku workers, one Sonnet review).
3. Culture wave 2 (Sonnet), then its PR, one review.
4. Multi-word verbs and the missing sentences decks.
5. Final derive run, review-queue tidy, completeness grid update.
6. A dropped item always carries a one-line reason in the review queue.

## 7. Second pause and state (2026-11-16, until the parent resumes at 2 PM IST)

Owner instruction via the parent: no new deck workers or phases until 2 PM IST; running workers finish and push; merge only what CI already passed.

| Item | State | On resume |
|---|---|---|
| PR #1508 notes (about 530 notes, `decks/kn-notes-wave1`) | Review done; blockers fixed (nine `pair`/`homograph`/`lookalike` kinds without `ref`, a false -ಗೆ/-ಕ್ಕೆ rule, ಯಾವಾಗಲೂ), three suffix readings added after CI | Merge when "Decks: validate" is green |
| PR #1487 recommendations | Two reviews done, no blocker; two unverified lines dropped | Merge when CI is green (its checks had not started at the pause) |
| Culture retry (`decks/kn-culture-wave2`) | **Built, pushed, no PR yet** (34 cards: culture-1 7 Pampa whole verses `kn-6000..6006`; culture-2 10 vachanas `kn-6050..6059`; culture-3 12 dasa and Sharifa songs `kn-6100..6111`; culture-4 5 cards `kn-6150..6154`; creators file adds eras and 8 creators to the 13 of #1487) | After the resume: merge #1487 first, then merge `decks-live` into the branch (the two `decks/creators/kn.yaml` files add/add conflict: keep both creator lists), open one PR, one Sonnet review (check the English of the whole-verse cards, the three cards marked for a Kannada speaker `kn-6006`, `kn-6108`, `kn-6052`, the Muddana maxim `kn-6150`, `circa` on Akka, Purandara, Kanaka), merge on green CI |
| Culture items dropped, with reasons | Pampa verses 8, 10, 13: garbled text or hedged gloss; Pampa Banavasi verse: not on the pages read; Pampabharata ashvasas 2 to 14: only ashvasa 1 parses cleanly with its gloss; Kumara Vyasa: only the Kuvempu and Masti edition exists on kn.wikisource, rights unresolved; Allama Prabhu, Sarvajna, Devara Dasimayya, Channabasavanna, Siddarama, Muktayakka: the validator needs `born` and `died` and no read source gives years (Britannica is the next source to try); Vijaya Dasa, Gopala Dasa, Vyasaraya, Sripadaraja, Jagannatha Dasa: no song text fetched yet; Kavirajamarga, Ranna, Ponna, Durgasimha, Nayasena, Janna, Harihara, Raghavanka, Kesiraja, Chamarasa, Ratnakaravarni, Honnamma, Nagavarma II: no kn.wikisource page; Kittel, Basavappa Shastri, Gulvadi, Kerur, Srikantaiah, Hardekar Manjappa, Kempu Narayana, Kittur ballads: no readable Kannada text found; Kailasam: authorship of the pages unverified | Next sources to try: Britannica (lifespans), Project Gutenberg, Digital Library of India scans (colonial authors), Google Books public-domain pages. Hosts reached: en and kn Wikipedia, kn.wikisource, en and kn Wikiquote, Wikidata (Wikimedia API 429s: pace 6 s). Blocked: archive.org, hasp.ub.uni-heidelberg.de |
| Multi-word verbs | Not retried yet | Re-source from Wiktionary and the Kannada grammar pages, then build the families with verified rows |
| `kn-numbers-1-20`, `kn-quantities` sentences | Not built | Widen the vocabulary rule, build |
| Derive run | Not done | Last step: `derive_phonetic.py kn` after every content PR; ask a phonetician about the four vowel-lowering rules |

## 8. State at the end of the 2026-11-16 session

All of these are merged to `decks-live` (PRs #1462, #1463, #1464, #1465, #1467, #1486, #1487, #1489, #1508, #1517, #1522, #1523, #1524) except the held items below.

| Deliverable | State |
|---|---|
| Sentences | All 72 word units |
| Readings | 53 decks, listed in `kn-path.yaml` |
| Topics, situations, proverbs | 53 topics, 10 sheets, 60 proverbs |
| Culture | 34 cards (7, 10, 12, 5) and 8 creators; the items dropped and why are in section 7 |
| Multi-word verbs | 46 new cards plus 11 refs; dropped candidates with reasons are in the run report (no auxiliary sense in any source read, or no gloss) |
| Recommendations | 11 works after the review fix; Kittur Chennamma and Marali Mannige dropped (no plot source) |
| Notes | About 530 cards; doubtful ones left without a note and queued |
| Narrow IPA | `phonetic` on every card with a broad `ipa` |
| Held | Professional situations (owner), culture beyond the 34 cards (needs sources), the review-queue rows for a Kannada speaker, the four vowel-lowering rules (phonetician) |
| Branches left for the owner to delete | `decks/kn-culture-wave1`, `decks/kn-multiword-wave1` |

## 9. Recommendations wave 2 and professional decks (2026-11-16)

**Recommendations: 20 of 20** on branch `decks/kn-recs-wave2` (no PR yet). Added: Bedara Kannappa, Kittur Chennamma, Sandhya Raga, Kasturi Nivasa (films), Marali Mannige, Mookajjiya Kanasugalu, Malegalalli Madumagalu, Sri Ramayana Darshanam (books), and the 2019 film of Mookajjiya Kanasugalu as the twentieth. Creators added: H. L. N. Simha (kn.wikipedia), A. N. Krishna Rao, S. K. Bhagavan, P. Sheshadri (en.wikipedia). Sources: en and kn Wikipedia; Marali Mannige's plot questions come from the 1959 Bengali translation scanned by the Digital Library of India on archive.org, plus en.wikipedia.

Doubts for a Kannada speaker: Kittur Chennamma's film plot is on no readable page, so its questions rest on cast, credits, soundtrack and premise; Marali Mannige's plot questions come from a translation, not the Kannada text; the year of Sri Ramayana Darshanam is the first volume (1949; the volume and Jnanpith years conflict between en and kn Wikipedia); Sandhya Raga's director credit is disputed (Narasimha Murthy credited, Bhagavan says he directed), so only Anakru is the creator.

Still dropped: the national anthem poem (lyrics). **Professional decks: still held.** The profession list is open owner question 6 of Plan-Deck-Kinds-And-Topics (`professions` is one shared list in `decks/sections.yaml`, not per language), so no Kannada professional deck was built.
