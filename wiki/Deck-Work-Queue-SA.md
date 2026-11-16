# Deck work queue: Classical Sanskrit completion plan

Status: audit and plan of 2026-11-16. Owner instruction (2026-11-15): one session per language; this session owns Classical Sanskrit (`sa`, tracker #356) and takes it as far toward completeness as is verifiable, "by delegating to agents". Classical Sanskrit is the one second-list language that goes **to full B1** (owner, 2026-11-06: "Only classical sanskrit to B1"), with a **heavy focus on Pāṇini's grammar** (owner, 2026-11-02). The shape is that of [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md) and [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md); Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task (read Sanskrit for "Japanese"). The conventions and validator traps of section 2 of the Kannada queue apply word for word (read `sa` for `kn`, `iso639_3: "san"`) with the additions of section 2 below. **Vedic Sanskrit (`vsn`) is a separate course with its own session: no task here touches `decks/vsn/` or `vsn-*` ids.**

State was read from `origin/decks-live` and `origin/main` on 2026-11-16: `git ls-tree` over `decks/sa*`, `decks/vsn/`, `decks/pli/`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/`, plus `decks/sections.yaml`, `decks/themes.yaml`, `decks/min_app.json`, `tools/gen_planned_paths.py`, `tools/transcribe.py`, `tools/phonetic_languages.yaml` and the `sa` entry of `assets/languages.yaml`. A scratch run of `gen_planned_paths.py --only sa` (into a scratch root, nothing committed) gave the unit list quoted below.

## 1. Audit against the completeness checklist

Nothing exists: there is no `decks/sa/` directory on `decks-live` or on `main` (no path, no phrasebook, no first words, no layer), no `sa-*` file anywhere under `decks/`, no `sa` row in `decks/creators/`, `decks/recommendations/` or `docs/review-queue/`. What exists is the language entry (`assets/languages.yaml`: code `sa`, `iso639_3: "san"`, own name `संस्कृतम्`, scripts `["devanagari"]`, family `indo_aryan`), the course data in `tools/gen_planned_paths.py` (entry `sanskrit` at ~line 601, `sa` at ~line 745, `script="devanagari_plain"`, `levels={"A1": 400, "A2": 600, "B1": 900}`, `sound=["vowel-length","sandhi"]`, `ancient_reason="is read here, not spoken"`) and a B1-plan scheme paragraph ([Plan-Language-Paths-Scheme](Plan-Language-Paths-Scheme.md), 2.3).

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **MISSING** | no `decks/sa/sa-path.yaml`; the generator makes one of 60 units (A1 mark at unit 29, A2 at 42, B1 at 60; running word total 400, then 1,000, then 1,900: the levels are increments of 400, 600 and 900) but its themes are generic (weather 86 words, festivals 76, illness 95, cooking 95, journey 114) and its grammar list lacks most of the Pāṇinian focus | SA-003 |
| 2 | Cores and English layers | **MISSING** | no file under `decks/sa/`; highest id: none (first id `sa-0001`) | SA-004, SA-1xx, SA-2xx |
| 3 | Sentences decks | **MISSING** | none | SA-300.. |
| 4 | Reading decks | **MISSING** | none | SA-400.., SA-410.. |
| 5 | Script decks | **MISSING** | no `sa-script-*`, no `sa-spelling`, no `sa-romanisation`, no `sa-sounds`; path units 7 and 8 are planned | SA-010..018 |
| 6 | Phrasebook | **MISSING** | no `sa-phrasebook` (path unit 1 names it and `sa-first-words`; neither exists, so the path ships only with them, as `vsn` and `pli` did) | SA-004 |
| 7 | Situations | **MISSING** | no `sa-situations.yaml` | SA-510 |
| 8 | Topics incl. script topics | **MISSING** | no `sa-topics.yaml` | SA-500 |
| 9 | Culture decks | **MISSING** (sourcing list open) | no `sa-culture-*`; no `Plan-Culture-Sanskrit` | SA-001, SA-520..523 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/sa.yaml` (decks-live has as, bn, es, fr, hi, ja, mr, te) | rides on SA-520..523, SA-550 |
| 11 | Proverbs (subhāṣita) | **MISSING** | none (owner 2026-11-13: built for every priority language) | SA-540..542 |
| 12 | Multi-word verbs | **MISSING** | the genre exists (`decks/sections.yaml`); no `sa` deck. Sanskrit's families: upasarga plus dhātu, nominal compounds, periphrastic forms | SA-530..532 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/sa.yaml` | SA-550 |
| 15 | Narrow IPA and broad `ipa` | **BLOCKED** | no `sa` block or engine in `tools/transcribe.py` (`BLOCKS` has hi mr bn as gu ta te kn ml; dispatch has es fr ja ko zh tok ml ta), no `sa` in `tools/phonetic_languages.yaml`, no `sa-phonetics.yaml` | SA-002 first, then SA-600..602 |
| 16 | Review-queue rows | **MISSING** | no `docs/review-queue/sa.md` (files exist for as bn es fr hi ja kn mr ta te zh) | SA-620 |
| 17 | Sourcing list | **MISSING** | no `wiki/Plan-Culture-Sanskrit.md` | SA-001 |
| 18 | Facts file | **MISSING** | no `sa-facts.yaml` | SA-005 |

### The path the generator makes (unit list, for SA-003)

| Level | Units | Grammar units in it |
|---|---|---|
| A1 (to unit 29, 400 words) | first words and phrasebook (1), sound differences with `vowel-length`, `sandhi` (2), questions, pronouns, family, numbers 1 to 20 (3 to 6), script letters (7), script conjuncts (8), about me, everyday verbs, adverbs, quantities, describing (9 to 13), case system (14), time, location, more verbs, work (15 to 18), a-stems (19), numbers-big, food, directions, body, places (20 to 24), present system and verb classes (25), things, home, clothes, animals (26 to 29) | 6 |
| A2 (to unit 42, +600 words) | weather, karakas (31), calendar, other noun stems (33), festivals, past tenses (35), illness, participles (37), cooking, samasa (39), journey, imperatives (41), nature | 6 |
| B1 (to unit 60, +900 words) | health, feelings, opinions, sutra-style rules (46), travel, government, passive (49), agriculture, arts, causatives (52), history, weddings, absolutives and infinitives (55), relationships, law, optative (58), verbs-4, abstract words | 5 |

## 2. Findings that shape the plan

- **No Sanskrit transcription engine, but a cheap one is feasible.** `tools/transcribe.py` has no `sa`. Running the `hi` engine over Sanskrit gives wrong output: `संस्कृतम्` comes out `saṁskritam` /sə̃skrɪt̪əm/ (ऋ read as Hindi `ri`, `ṁ` as nasalisation), `ऋषि` `riśi` (ṣ read as ś), `कृष्ण` `kriśṇa`. The Hindi schwa deletion is not the problem: Classical Sanskrit keeps **every** inherent a, word-final included, and `default_choices` only drops a schwa for `hi mr gu bn as`, so a language not in that list keeps all of them. **Shared-code change for the parent to file as an issue** (a tools PR to main, Sonnet, with tests in `tools/test_transcribe.py`; nothing in the app changes): add an `sa` engine to `tools/transcribe.py` on the Devanagari block:
  1. `BLOCKS["sa"] = 0x0900`.
  2. `VOWEL_TABLES["sa"]` and the vowel dicts: ऋ `ṛ`, ॠ `ṝ`, and **ऌ `ḷ`** (offset 0x0C, today only Telugu's `TE_VOWELS`); e and o are always long and written `e`, `o`; `ai`, `au` as diphthongs; short `a` and long `ā` kept apart in the IPA.
  3. `CONSONANT_TABLES["sa"]`: `ś` /ɕ/ and `ṣ` /ʂ/ kept apart (the `hi` table folds ṣ into ś); `ñ`, `ṅ`, `ṇ`; `jñ` as the plain cluster j+ñ (not Hindi `gy`); no nukta letters.
  4. Anusvara written **`ṃ`** always (IAST, no homorganic respelling in the reading), the IPA taking the nasal of the next stop (ṅ ñ ṇ n m), a nasalised vowel before semivowels, sibilants and `h`, and `m` word-finally; visarga `ḥ` /h/; avagraha `ऽ` written `'` (line 200 already parses it); virama and conjuncts as `hi`.
  5. Keep every line `lang in ("hi", "mr", "gu")` (around lines 623, 654, 870, 874) from applying to `sa`, and add `sa` to the test table, to `tools/transcribe_decks.py`'s language list, and to the CLI docstring.
  6. Which vowel IPA the course uses for short a (/ɐ/ or /ə/) and for ṛ (/r̩/ or /ɻ̩/) is read from the Sanskrit phonology section of Wikipedia (en and sa) by the builder, not from memory, and recorded on the PR.
  Until it merges nothing is hand-written: SA-004 (phrasebook, first words) is the first task that needs the tool and so waits for it.
- **Reading convention: IAST, as `vsn` does.** `decks/vsn/vsn-first-words.yaml` writes `अहम्` as `aham`, `अहं` as `ahaṃ`, `नमः` as `namaḥ`, `ज्ञा` as `jñā`: IAST letters with `ṃ` and `ḥ`. Classical Sanskrit **matches `vsn`**: the two courses share material, the Sanskrit texts a learner meets are in IAST, and a learner moving between them should see one scheme. This departs from the project's "based on ISO 15919" rule in four letters only (`ṃ` for ISO `ṁ`, `ṛ ṝ ḷ` for ISO `r̥ r̥̄ l̥`, and `e o` for ISO `ē ō`); the course's romanisation file (`sa-romanisation`, SA-016) states each difference. **Decision for the parent to confirm with the owner** (recorded as made, not asked): CLAUDE.md says readings are based on ISO 15919 and the Telugu word-final anusvara is `ṁ` course-wide; Sanskrit is scholarly IAST. The engine of the item above writes IAST for `sa`.
- **A reading course, not a spoken one** (`ancient_reason: "is read here, not spoken"`). `vsn` and `pli` have `listening_passages` placeholders, as the generator writes them. No task asks for speaking practice; recognition, reading and grammar modes lead. The path header says so.
- **The generator's themes are for modern life.** Its grammar list is the family's generic list. SA-003 (Sonnet) re-plans the path by hand after generating it: it keeps the three marks and the word budget (400, +600, +900), replaces the modern themes with reading themes (kinship, body, animals of the fables, nature, kingship and government, dharma and conduct, time, food, travel, verbs by class), and **adds the Pāṇinian grammar units of section 3 in their places**, because the generator has sandhi only as a sound topic, no dhātu and gaṇa unit, no taddhita, kṛt or gerundive, and one sūtra unit. Every path unit must still be a unit with a deck or a `planned:` entry; each unit moves from `planned` to `decks` in the commit that builds it.
- **Sandhi policy for cards (decided, owner may override).** A word card's `target` is the word in its isolated (pada) form (`रामः`, `रामम्`). A sentence card's `target` is written with its sandhi applied as in the texts, with spaces between the words; its `words` entries are the written pieces, and `bases[].word` is one written piece. Every junction that changed shape carries a layer note (kind `note`) naming the sandhi rule and the unit that teaches it. From unit 14 on, sentences use only sandhi taught by then.
- **The grammar units are RULES units with row tables** ([Deck-Format](Deck-Format.md), "Rules decks"). The owner's rule of 2026-10-23 applies: noun and verb tables are **full tables covering every word** (all eight cases and three numbers; every person and number of a tense, parasmaipada and ātmanepada), as Bengali's and Hindustani's are. A paradigm is taught on one model word, then the table is filled by rows for the course's own words. A grammar unit writes **no reading deck**.
- **Rights.** Pāṇini, the Hitopadeśa, the Pañcatantra, the Gītā, Kālidāsa, Bhartṛhari and Whitney (1889) are public domain; modern editions and translations are not copied. Excerpts are at most 25 words; translations are the builder's own plain rendering (Deck-Work-Queue rule 7). A creator or work whose dates cannot be read on a cited page is dropped with a one-line reason in the review queue, never filled from memory. Wikisource's typed Sanskrit is CC BY-SA, which the decks' licence matches, and carries typing errors: a form is checked against a second page before it goes on a card.
- **Ancient creators and the format.** Creators need `born` and `died` (a plain year or `{ year, circa: true }`), `source.author` equal to the creator's exact `name.en.text`, and works with `author_died` for a public-domain `source`; Pāṇini, Viṣṇuśarman, Vyāsa and others have no certain dates. SA-001 reads each person's Wikipedia page and records either a `circa: true` year range as the page gives it or "anonymous" for a compilation; where neither is possible the item is dropped and listed. If the creators format cannot hold a person at all, SA-550 stops and reports to the parent.
- **The sūtras are read, not remembered.** Sūtra numbers and wording in SA-136..139 come from the pages of `sa.wikisource.org/wiki/अष्टाध्यायी` (table at the end of this page), each cited with chapter, pāda and number. Examples the sourcing task checks on those pages first: 1.1.1 `वृद्धिरादैच्`, 6.1.77 `इको यणचि`, 1.4.24 `ध्रुवमपायेऽपादानम्`. A sūtra not read on the page is not used.
- **Validator traps (CI failures seen so far; brief every worker).** Confusable ids are `[a-z0-9-]+`. A base word appears once per card (case-insensitive). `words` must join exactly to the whole target with no spaces inside entries. `bases[].word` is one word of the target. An entry has `ref` or `base`, never both, and a `ref` entry has no `reading`. A layer's `bases` gloss only inline words, never an empty `bases`. Every layer note needs a matching core `notes: [{id, kind}]` with kind one of behaviour, culture, homograph, lookalike, note, pair, usage. A layer meaning is ONE sentence (join clauses with `;`). Sentence cards need 2 to 3 confusables (existing word-card ids; layer keys equal core ids). Every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses. Creators' `born`/`died` is a plain year or `{ year, circa: true }`, never `circa: false`; `source.author` equals the creator's exact `name.en.text`; `legacy` has 1 to 6 items with sources. `source.date` accepts a year, a range or `c. year` only. At most 25 `phrasebook: true` cards per course. Excerpts are at most 25 words. A grammar unit writes NO reading deck. Every word of a kind in every B1 deck needs a row in every rules table of that kind. YAML indentation errors can nest cards as examples. Quote every YAML scalar (except `true`, `false`, whole numbers). Card ids are permanent. Also: the phrasebook of a course needs at least 15 cards (the generator's own note on Aramaic); `decks/min_app.json` is never touched for `sa` (the language entry is already in the released app).
- **Conventions copied from `kn` section 2, with `sa` values.** Header: copy the block of `decks/vsn/vsn-first-words.yaml` (language `sa`, `iso639_3: "san"`, `script: "devanagari"`, `icon` as `assets/languages.yaml` or `संस्कृतम्`'s first syllable `सं`, chosen once by SA-004), `part: "core"`, `kind`, `license: "CC-BY-SA-4.0"`, `tags: [..., "unreviewed"]`, layer `decks/sa/en/sa-en-<name>.yaml`. Model the Devanagari script decks on `decks/hi/hi-script-*` (vowels, consonants, vowel signs, conjuncts, digits, reading, `hi-script`, `hi-spelling`, `hi-romanisation`, `hi-sounds`) and the grammar decks on `decks/hi/hi-grammar-*` and Telugu, Kannada and Bengali rules decks. Ids (reserved, ascending in a task, never reused): `sa-0001..0099` first words and phrasebook, `sa-0400..0999` grammar words, `sa-1000..2999` vocab, `sa-3000..3999` sentences, `sa-4000..4499` script, `sa-6000..6199` culture, `sa-6200..6399` proverbs, `sa-6400..6599` multi-word. `phonetic` is written last by tools, never by a builder.
- **Shared files, one owner per wave.** `sa-path.yaml` (SA-003, then each unit's builder moves its own entry), `sa-topics.yaml` (SA-500), `sa-situations.yaml` (SA-510), `decks/creators/sa.yaml` (culture tasks in order, then SA-550), `decks/recommendations/sa.yaml` (SA-550), `docs/review-queue/sa.md` (SA-620), `decks/themes.yaml` on decks-live (deck-owned; a new theme id is added there, by the SA-003 PR only).

## 3. Task table

Model: **Haiku** = fully specified, guarded and logged code, never improvises; **Sonnet** = rules, design, reviews. Every deck task is on a shared level branch (rule 17); a Sonnet specs the tables of each paradigm unit before the Haiku fills it.

**Order.** B1-path first (owner): the three level waves, A1 then A2 then B1, come before any genre deck; inside a wave the grammar units come first, then script, word units, sentences, readings. Genre decks, topics, situations and recommendations follow the B1 merge, and narrow IPA runs last, after every content PR has merged. Sourcing (SA-001) and the engine issue (SA-002) run first and in parallel.

### 3.1 Sourcing, tools, path, first words, facts

| Id | Model | Branch | Spec | Depends on |
|---|---|---|---|---|
| SA-001 | Sonnet | main (docs) | `wiki/Plan-Culture-Sanskrit.md`, public-domain only: culture (4 decks), proverbs/subhāṣita (3 decks of 20), multi-word families, recommendations, and the list of Aṣṭādhyāyī sūtras for SA-136..139, every entry read on a cited page of the reachable hosts below; each dropped item has a one-line reason | none |
| SA-002 | Sonnet | `tools/sa-transcribe` (tools PR to main, issue filed by the parent) | the `sa` engine of section 2 (IAST reading, broad IPA), tests in `tools/test_transcribe.py`; verified against the Wikipedia Sanskrit phonology tables and a dozen words with known IAST | none |
| SA-003 | Sonnet | `decks/sa-a1-wave1` | `python3 tools/gen_planned_paths.py --only sa` (run on the branch; never rewrites an existing path), then the hand re-plan of section 2 (reading themes, Pāṇinian units, marks and budgets kept), `alphabet` filled as script decks land; any new theme id into `decks/themes.yaml` on decks-live | SA-001 for themes |
| SA-004 | Haiku | `decks/sa-a1-wave1` | `sa-phrasebook` (20 cards, `phrasebook: true`, widely used phrases only: namaste, dhanyavāda, svāgatam, kṣamyatām, śubham, om, …) and `sa-first-words` (10 words) with layers, ids `sa-0001..0099`; unit 1 of the path points at them. Readings and IPA only from the SA-002 tool | SA-002, SA-003 |
| SA-005 | Haiku | `decks/sa-a1-wave1` | `sa-facts.yaml`, only facts with a read source (the language's age, Pāṇini and the Aṣṭādhyāyī's size, the ten lakāras, Devanagari, the pratyāhāra, the family of Indo-Aryan) | SA-001 |

### 3.2 Script, pronunciation and sandhi (path units 2, 7, 8 and the sandhi units)

| Id | Model | Branch | Spec | Depends on |
|---|---|---|---|---|
| SA-010..015 | Haiku | `decks/sa-a1-wave1` | `sa-script-vowels` (a ā i ī u ū ṛ ṝ ḷ e ai o au, with ṃ ḥ), `sa-script-consonants` (the five varga rows plus semivowels, sibilants, h; no nukta letters), `sa-script-vowel-signs`, `sa-script-conjuncts` (क्ष, ज्ञ, त्र, श्र, द्य, … with the virama; ids `sa-4000..4499`), `sa-script-digits` (० to ९), `sa-script-reading` (reading words); `alphabet` set in the path; modelled on `hi-script-*` | SA-002 |
| SA-016 | Haiku | `decks/sa-a1-wave1` | `sa-script` (guide), `sa-spelling` and `sa-romanisation` (IAST letters, and the four differences from ISO 15919 of section 2) | SA-010..015 |
| SA-017 | Sonnet | `decks/sa-a1-wave1` | `sa-sounds` (sounds file) and the rules unit `sa-sound-differences` (path unit 2): short and long vowels, the sthāna rows (kaṇṭhya, tālavya, mūrdhanya, dantya, oṣṭhya), voiced and aspirated, ṃ and ḥ, savarṇa and the pratyāhāra `अइउण्`, `ऋऌक्`, … read from the Aṣṭādhyāyī page; the pronunciation of ṛ ḷ ś ṣ is read from Wikipedia | SA-002 |
| SA-018 | Sonnet | `decks/sa-a1-wave1` | the `devanagari-letters` and `conjunct-letters` topics in `sa-topics.yaml` stay with SA-500; this task only checks the six script decks against section 2 (report only) | SA-010..016 |

### 3.3 Pāṇinian grammar: rules units (the heavy focus)

Each is a rules core `sa-grammar-<name>` with its layer, ids `sa-0400..0999`, full tables, notes naming the sūtra where one applies, and a path entry moved from `planned` to `decks`. A Sonnet writes the model words and the table specification (from Whitney, Wikipedia and the Aṣṭādhyāyī page); a Haiku fills the rows for the course's own words; one Sonnet reads the whole wave. Words used in a table must already be taught by the path at that point.

| Id | Level | Unit | Content |
|---|---|---|---|
| SA-100 | A1 | `sa-grammar-case-system` | the eight vibhaktis (prathamā to saptamī, and sambodhana), three numbers, what each case does; one model word |
| SA-101 | A1 | `sa-grammar-a-stems` | masculine and neuter a-stems (`राम`, `फल`): the full 8 x 3 table, then every course word |
| SA-102 | A1 | `sa-grammar-present-system` | dhātu, the thematic present (`laṭ`) of the first gaṇa (`भू`, `गम्`, `पठ्`) in parasmaipada, all 9 forms, plus `verb-classes` as an overview of the ten gaṇas |
| SA-103 | A1 | `sa-grammar-sandhi-vowel` | vowel (ac) sandhi: savarṇa-dīrgha, guṇa, vṛddhi, yaṇ, ayādi; row tables of junctions, each with its sūtra |
| SA-104 | A1 | `sa-grammar-pronouns` | `asmad`, `yuṣmad`, `tad`, `etad`, `idam`, `kim`, `yad`, `sarva`: full tables |
| SA-105 | A1 | `sa-grammar-atmanepada` | parasmaipada against ātmanepada: the endings of `laṭ` in both, which dhātus take which |
| SA-110 | A2 | `sa-grammar-karakas` | the six kārakas (kartṛ, karman, karaṇa, sampradāna, apādāna, adhikaraṇa) and the vibhakti each takes, with the sūtras of 1.4 read from the page, plus the upapada vibhaktis |
| SA-111 | A2 | `sa-grammar-sandhi-consonant` | consonant (hal) sandhi: voicing, nasal, `ch`, `cch`, ṇ/n, `ṭ`, retroflexion |
| SA-112 | A2 | `sa-grammar-sandhi-visarga` | visarga sandhi: `ḥ` to `o`, `r`, `s`, `ś`, `ṣ`, or dropped |
| SA-113 | A2 | `sa-grammar-gana-1` and `sa-grammar-gana-2` | the ten gaṇas (bhvādi, adādi, juhotyādi, divādi, svādi, tudādi, rudhādi, tanādi, kryādi, curādi) in two units, `laṭ` of a model dhātu of each; the gaṇa decides the stem |
| SA-114 | A2 | `sa-grammar-other-stems` | i, ī, u, ū, ṛ-stems, ā-feminines, consonant stems (`rājan`, `bhavat`, `vāc`): full tables |
| SA-115 | A2 | `sa-grammar-past-tenses` | the imperfect (`laṅ`), perfect (`liṭ`) and aorist (`luṅ`), with the augment |
| SA-116 | A2 | `sa-grammar-lakaras` | the ten lakāras (laṭ, laṅ, loṭ, vidhiliṅ, liṭ, luṅ, lṛṭ, lṛṅ, luṭ, āśīrliṅ) in one overview table and what each is for |
| SA-117 | A2 | `sa-grammar-imperatives` | `loṭ`, all persons, parasmaipada and ātmanepada |
| SA-118 | A2 | `sa-grammar-participles` | `kta`, `ktavatu`, `śatṛ`, `śānac` with their declension |
| SA-119 | A2 | `sa-grammar-samasa` | the compound types (dvandva, tatpuruṣa and its kinds, karmadhāraya, dvigu, bahuvrīhi, avyayībhāva), each with a row table and the sūtra where read |
| SA-120 | A2 | `sa-grammar-taddhita` | secondary derivation: `aṇ` (vṛddhi), `tva`, `tā`, `matup`, `vatup`, `ya`, with the changes they cause |
| SA-130 | B1 | `sa-grammar-krt` | primary derivation by kṛt: `ghañ`, `lyuṭ`, `tṛc`, `ktin`, `ṇvul` and how the root changes |
| SA-131 | B1 | `sa-grammar-gerundives` | `tavya`, `anīya`, `ya` (`yat`, `ṇyat`): forms and the passive sense |
| SA-132 | B1 | `sa-grammar-absolutives-infinitives` | `ktvā`, `lyap` and `tumun` |
| SA-133 | B1 | `sa-grammar-passive` | `yak` and the bhāve and karmaṇi constructions, the voice endings |
| SA-134 | B1 | `sa-grammar-causatives` | `ṇic`: vṛddhi, the `p` insertion, the endings |
| SA-135 | B1 | `sa-grammar-optative` | `vidhiliṅ` in both padas, uses |
| SA-136..139 | B1 | `sa-grammar-sutra-1` to `-4` | reading selected Aṣṭādhyāyī rules: (1) saṃjñā and paribhāṣā (1.1), (2) the sandhi sūtras of 6.1, (3) the kāraka sūtras of 1.4, (4) samāsa and kṛt sūtras; for each sūtra: the text, its padaccheda, the anuvṛtti, an example, all read from the page; at most 25 words per excerpt |

### 3.4 Word units, sentences, readings

| Id | Model | Branch | Spec | Depends on |
|---|---|---|---|---|
| SA-200..SA-2xx | Haiku | `decks/sa-a1-wave1`, `-a2-wave1`, `-b1-wave1` | the vocab decks of the re-planned path, in path order (about 40 units), ids `sa-1000..2999`, each word read on its Wiktionary page and in a text; an a-stem noun gets its gender; every word carries the dhātu or stem as its base | SA-003, SA-002 |
| SA-300..SA-3xx | Haiku | the same level branches | one `-sentences` core and layer per word unit, 2 to 3 confusables per card, the 8 rules of the sentences section of the Deck-Work-Queue (taught words only; sandhi policy of section 2); ids `sa-3000..3999` | its word unit |
| SA-400..SA-4xx | Haiku | the same level branches | one reading deck per word unit named by the path (a grammar unit has none): passages built only from that unit's sentences, no new Sanskrit | its sentences |
| SA-410..SA-413 | Haiku | `decks/sa-b1-wave1` | authentic-text reading decks: `sa-en-reading-hitopadesa`, `-panchatantra`, `-gita`, `-kalidasa`, public-domain verses and prose of at most 25 words, each read on its Wikisource page, the builder's own translation | SA-001, SA-118, SA-119 |

### 3.5 Genre decks, topics, situations, creators, recommendations

| Id | Model | Branch | Spec |
|---|---|---|---|
| SA-500 | Haiku | `decks/sa-topics-wave1` | `sa-topics.yaml`: script topics (vowels, consonants, conjuncts, digits), sandhi, vibhakti, dhātu and gaṇa topics, word and culture topics |
| SA-510 | Haiku | `decks/sa-situations-wave1` | `sa-situations.yaml`: 6 sheets of widely used living phrases (greeting and leave-taking, thanks and apology, introducing oneself, classroom, prayer and ceremony, travel and questions), marked draft; owner: "no over-translation" |
| SA-520..523 | Haiku | `decks/sa-culture-wave1` | `sa-culture-1` to `-4` with creators and eras, from SA-001 only |
| SA-530..532 | Haiku | `decks/sa-multiword-wave1` | `sa-multiword-*`: upasarga plus dhātu (`प्र + स्था`, `सम् + गम्`), noun-and-verb collocations, nominal compounds; only verified families, each card's compound status read from a cited source; ids `sa-6400..6599` |
| SA-540..542 | Haiku | `decks/sa-proverbs-wave1` | `sa-proverbs-1` to `-3` (subhāṣita), 20 cards each, `basis: public-domain` with the text's source named, ids `sa-6200..6399` |
| SA-550 | Haiku | `decks/sa-recs-wave1` | `decks/recommendations/sa.yaml` (public-domain texts to find: Hitopadeśa, Pañcatantra, Gītā, Śākuntalam, Meghadūta; plus source-it-yourself works as the format allows) and `decks/creators/sa.yaml` |

### 3.6 IPA, review queue, branch scheme

| Id | Model | Branch | Spec |
|---|---|---|---|
| SA-600..602 | Sonnet design, then tools | `phonetics/sa` | `sa` entry in `tools/phonetic_languages.yaml` (dump `Sanskrit`; run `import_phonetic.py sa --dump` first to see whether Wiktionary has word-level `[ ]` forms: it is a fetch, so it is run once by the Sonnet), `decks/sa/sa-phonetics.yaml` rules (retroflexes, aspirates, anusvara allophones, visarga, vowel length; the lessons of Telugu #1390 and Kannada section 4), then `derive_phonetic.py sa` over every card, last, after the content PRs merge |
| SA-620 | Haiku | rides on each wave | `docs/review-queue/sa.md`: a row for every uncertain card (gender, sandhi form, sūtra reference, a gloss), in the README's table shape |

**Branches (rule 17).** One shared integration branch per level, one PR to `decks-live` each, one Sonnet review each (a second only for a breaking bug): `decks/sa-a1-wave1` (SA-003, 004, 005, 010..017, 100..105, A1 word units, sentences and readings), `decks/sa-a2-wave1` (SA-110..120 and the A2 units), `decks/sa-b1-wave1` (SA-130..139 and the B1 units, SA-410..413). The genre and topic branches of section 3.5 are separate, one PR each. Parallel workers use their own worktrees, merge `origin/decks-live` and the shared branch before every fast-forward push, never force, never open a PR, never use session-management tools, and run no tests or validator. The first review's fixes are applied by the workers; while a review runs, two fewer deck workers run for each (owner, 2026-11-14).

**Resume order.** SA-001 and SA-002 (parallel) first; then SA-003 and SA-017; the A1 wave (grammar SA-100..105 with SA-103 first, script SA-010..016, SA-004, SA-005, A1 word units, sentences, readings) as one PR; then A2, then B1; then the genre branches, topics, situations, recommendations by the order of [Plan-Language-Completeness](Plan-Language-Completeness.md) (c); then SA-600..602 last.

## 4. Sources reachable from the sandbox (tested 2026-11-16, one request each)

The sandbox's egress proxy allows only some hosts. A blocked host answers `CONNECT tunnel failed, response 403` (a policy denial: do not retry). Wikimedia hosts and `kaikki.org` work.

| Host | Result | Use |
|---|---|---|
| en.wikipedia.org | **reachable** (200, 2.0 MB) | dates, lifespans, phonology, English articles |
| sa.wikipedia.org | **reachable** (200, 344 KB) | Sanskrit-language articles on the same |
| sa.wikisource.org | **reachable** (200, 78 KB; `action=raw` returns wikitext) | the Sanskrit texts below |
| en.wikisource.org | **reachable** (200, 83 KB) | the PD grammars and translations below |
| en.wikiquote.org | **reachable** (`Hitopadesha` 200; `Sanskrit_proverbs` is a 404: no such page) | cross-check only |
| commons.wikimedia.org | **reachable** (200, 429 KB) | images and scans, with licences |
| en.wiktionary.org | reachable (200; an extra host, tested) | word glosses, forms |
| kaikki.org | reachable (200; an extra host, the Wiktionary dump the phonetic tools use) | SA-600 |
| sanskritdocuments.org | **blocked** (403) | none |
| gretil.sub.uni-goettingen.de | **blocked** (403) | none |
| gutenberg.org | **blocked** (403) | none |
| archive.org | **blocked** (403) | none (so Macdonell's grammar and dictionary, Monier-Williams scans) |
| books.google.com | **blocked** (403) | none |
| dsal.uchicago.edu | **blocked** (403) | none (Monier-Williams digital) |
| sanskrit-lexicon.uni-koeln.de | **blocked** (403) | none (Cologne dictionaries: Monier-Williams, Macdonell) |
| ashtadhyayi.com | **blocked** (403) | none |

**Public-domain texts that were fetched and read** (a header and the first lines; the full text is read by the builder). Use `https://<host>/w/index.php?title=<page>&action=raw`, or the `/wiki/<page>` form for a browser.

| Text | Where (host, page title) | What was seen |
|---|---|---|
| Aṣṭādhyāyī, sūtra text | sa.wikisource.org: `अष्टाध्यायी` (index), `अष्टाध्यायी/प्रथमः अध्यायः`, `/द्वितीयः अध्यायः`, `/पञ्चमः अध्यायः`, `/सप्तमः अध्यायः` (four of the eight chapter pages were listed by search; the other four are found by the same title pattern) | header "अष्टाध्यायी १", author पाणिनि, begins with the pratyāhāra sūtras `अइउण्` |
| Hitopadeśa | sa.wikisource.org: `हितोपदेशः` (index), `हितोपदेशम् 03क`, `हितोपदेशम् 04क`, `हितोपदेशम् 05क` | verses with verse references (`हित्_२.१०१`), typed with some odd markers: check against a second page |
| Pañcatantra | sa.wikisource.org: `पञ्चतन्त्रम्`, `पञ्चतन्त्रम् ०२ग`, `०३`, `०३क`, `०३ग`, `०४क`; en.wikisource.org: `The Panchatantra (Purnabhadra's Recension of 1199 CE)` and `Panchatantra` (listed by search; the edition and translator are read from each page before citing) | Sanskrit verses and prose; the English pages exist |
| Bhagavad Gītā | sa.wikisource.org: `भगवद्गीता` (an index with a search box), chapter pages such as `भगवद्गीता/मोक्षसंन्यासयोगः` (a very large page); en.wikisource.org: `The Bhagavad Gita (Arnold translation)` (Edwin Arnold, header read), `Bhagavad-Gita (Besant 4th)`, `The Glories of the Bhagavad Gita (Telang translation)` | text and header read |
| Subhāṣita collection | sa.wikisource.org: `सुभाषितरत्नभाण्डागारः/सङ्कीर्णक-प्रकरणम्` (483 KB, listed by search, not opened) | for SA-540..542 |
| Whitney, *Sanskrit Grammar* (1889) | en.wikisource.org: `Sanskrit Grammar (Whitney)` and subpages (`/Preface`, `/Appendix`, …), `{{PD-old}}`, from a djvu index | header read |
| Lanman, *A Sanskrit Reader* (1903) | en.wikisource.org: `A Sanskrit Reader` (parts, selections, notes) | index read: Part I, from the Mahābhārata and other selections |
| Macdonell's grammar and Practical Dictionary | not found: two searches on en.wikisource returned no such page (`A History of Sanskrit Literature` and `Vedic Grammar` are listed; their authors were not read). archive.org, Cologne and dsal are blocked | not fetchable; use Whitney and Wiktionary |
| Monier-Williams | blocked (dsal, Cologne); Wiktionary and the kaikki.org dump stand in | glosses from Wiktionary entries, each read on its page |
| Kālidāsa (Śākuntalam, Meghadūta) | one search each on sa.wikisource returned no play or poem page; not found | SA-001 tries `शाकुन्तलम्`, `मेघदूतम्`, `कुमारसम्भवम्`, `रघुवंशम्` and en.wikisource before dropping an item, and records a reason |

## Progress

- 2026-11-16, SA-003: branch `decks/sa-a1-wave1` pushed at `86651e5e` with the re-planned `decks/sa/sa-path.yaml`: 77 units (unit 1 is `sa-phrasebook`, `sa-first-words`, `*`; then 76 planned): A1 33 units (mark on `sa-work`, 400 words), A2 22 (mark on `sa-verbs-3`, 600), B1 21 (mark on `sa-verbs-4`, 900). Grammar units follow SA-100 to SA-139 with `sa-grammar-sutra-1` to `-4`. Three themes added to `decks/themes.yaml` on that branch: `dharma`, `ritual`, `learning`. `alphabet` is `[]` until the script decks exist.
- 2026-11-16: the parent confirmed IAST readings (ṃ, ṛ) as vsn does, and is building the `sa` engine in `tools/transcribe.py`; readings of word decks wait for it.

## Pause and resume plan (2026-11-16)

Owner instruction relayed by the parent: pause the deck workers until 2 PM IST on 2026-11-16; start no new workers or phases; running workers finish and push; merge nothing new unless CI is already green.

State at the pause: shared branch `decks/sa-a1-wave1` at `4ca09dbf8` (no PR yet, CI not yet run on it). On it: the re-planned path (77 units; units 7 and 8 are the written script units; `alphabet` lists the six script decks), `sa-phrasebook` and `sa-first-words` (ids sa-0001 to sa-0030), `sa-facts` (30), six script decks (sa-4000 to sa-4101), `docs/review-queue/sa.md`, and every file at minimum app version 0.10.7 in `decks/min_app.json` (the parent cuts 0.10.7 with the Dart IAST parser). One Sonnet worker (SA-016, SA-017, SA-100 to SA-102: script/spelling/romanisation, sounds and sound-differences, case system, a-stems, present system) was still running at the pause and finishes on its own.

Resume, in order:
1. Read the Sonnet worker's report (or `git log origin/decks/sa-a1-wave1`); re-brief it for anything unfinished.
2. Open ONE PR `decks/sa-a1-wave1` to `decks-live`; read CI (`gh api repos/aaronified/fluenough/commits/<sha>/check-runs`); only "Validate decks" and "Released app reads the decks" matter; fix failures on the branch.
3. Run, on the same branch, Haiku word-unit workers (SA-200.., ids sa-1000..2999, one worktree each, at most 6) for the A1 word units in path order, then sentences (SA-300..), readings (SA-400..), and Sonnet rules units SA-103, SA-104, SA-105; drop 2 workers per running review.
4. One Sonnet review of the A1 PR (report-only, BLOCKING/NIT); workers apply fixes; merge when green.
5. Then `decks/sa-a2-wave1` (SA-110..120) and `decks/sa-b1-wave1` (SA-130..139, SA-410..413), the genre decks (SA-500..550, from Plan-Culture-Sanskrit), the narrow IPA (SA-600..602) and the review queue (SA-620), each on its own shared branch and PR.
