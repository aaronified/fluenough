# Plan: Telugu genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task TE-001 of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md), written 2026-11-14 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Japanese](Plan-Culture-Japanese.md), for the tasks TE-035 to TE-046. The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md). The Spanish counterpart is [Plan-Culture-Spanish](Plan-Culture-Spanish.md).

**Nothing on this page is a checked fact.** Every work below is a *candidate*. No date, lifespan, text, edition or rights status has been read or verified by the author of this page. The builder reads each work's and author's page on te.wikipedia or en.wikipedia and a cited Wikisource edition, reports what it read, and drops any candidate whose dates or text it could not read, replacing it from the reserve. Nothing is filled in from memory. No Telugu speaker reviews the decks (owner, 2026-11-13): everything ships `unreviewed`, and doubts go to `docs/review-queue/te.md`. If this page and a task row of the plan differ, this page wins.

## Rules applied

- **Rights floor.** The author's death year must be 1955 or earlier (the validator's floor). India's term (life plus 60 years) would allow later deaths, but the floor rules. An anonymous work needs a first publication before 1900. The floor catches typos; the reviewer owns the legal opinion.
- **Basis `public-domain` only, no `quotation` items.** The `source` block is as in batch 1 of the Japanese culture deck: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **Text as printed in the cited edition**, in Telugu script. A classical poem is **not modernised**. Every archaic form in an excerpt is listed in the layer with its modern form, as the glossary of the existing reading deck `te-en-reading-diddubatu` does.
- **`reading` and `ipa` from the tool**: `python3 tools/transcribe.py te "<Telugu>" "<typed Latin hint of how it is said>"`. Readings are based on ISO 15919 (never "strictly follow it"); a word-final anusvara is written `ṁ` (owner, 2026-10-19). A doubtful reading or spelling goes to the review queue, never guessed. No `phonetic` (TE-058 writes it).
- **One excerpt per card**: one verse or line, at most 25 words. **18 items per deck**, short items first, level B1 unless the item is short and plain (A2). The first 18 candidates that pass are the deck; the rest are the reserve. Fewer than 18 may pass: the report says so, the deck is never padded.
- **Dates are never guessed.** `date` takes a shape the validator's `parse_years` accepts (a year, `c. YEAR` or `A-B`); an uncertain year or lifespan is `circa`; the creator's `born` and `died` must satisfy `MAX_LIFESPAN` (120).
- **Translations** are the builder's own plain renderings.
- **Creators** (file `decks/creators/te.yaml`, created by TE-035): a short A2-level English bio, `born` and `died`, era, one legacy line with a checkable item and a source link, no image. Eras: Kakatiya, Vijayanagara, Nayaka, colonial, twentieth century (the builder confirms the boundaries from its sources).
- **Order of work.** TE-035 to TE-038 run one after another because they share `creators/te.yaml`; TE-045 and TE-046 come after them on the same file. Proverbs and multi-word decks are independent of that lane.
- **Notes** are Latin prose; every Telugu word in a note is followed by its reading in parentheses.

## Culture decks (TE-035 to TE-038, 4 x 18 plus reserves)

Rights basis, dates and text are **to be read** in every row and are not repeated.

### TE-035, `te-culture-1`: classical epics and prabandhas (te-8750 to 8799)

| # | Candidate work | Creator |
|---|---|---|
| 1 | Andhra Mahabharatam, opening verses | Nannaya |
| 2 | Andhra Mahabharatam, Virata Parvam | Tikkana |
| 3 | Andhra Mahabharatam, Aranya Parvam | Errana |
| 4 | Andhra Maha Bhagavatham, Gajendra Moksham | Pothana |
| 5 | Andhra Maha Bhagavatham, Prahlada charitra | Pothana |
| 6 | Manucharitra | Allasani Peddana |
| 7 | Parijatapaharanam | Nandi Thimmana |
| 8 | Sringara Naishadham | Srinatha |
| 9 | Molla Ramayanam | Molla |
| 10 | Amuktamalyada | Sri Krishnadevaraya |
| 11 | Panduranga Mahatyam | Tenali Ramakrishna |
| 12 | Vasucharitra | Ramarajabhushanudu |
| 13 | Kalahasti Mahatyam | Dhurjati |
| 14 | Kalapurnodayam | Pingali Surana |
| 15 | Nirvachanottara Ramayanam | Tikkana |
| 16 | Navanatha Charitra | Gaurana |
| 17 | Basava Puranam | Palkuriki Somanatha |
| 18 | Ranganatha Ramayanam | Gona Budda Reddy |

Reserve: another Pothana verse, another Peddana verse. This task creates `decks/creators/te.yaml` with its eras and the creators.

### TE-036, `te-culture-2`: devotional verse and music (te-8800 to 8849)

The plan gives candidates in no fixed order. The builder keeps only items whose text it reads on the cited Wikisource page.

| Candidate | Creator |
|---|---|
| Sankirtanas, such as "Brahmam okkate", "Muddugare Yashoda", "Cheri Yashodaku" | Annamayya |
| Kritis in Telugu, such as "Endaro Mahanubhavulu", "Nagumomu", "Sri Rama Jaya Rama" | Tyagaraja |
| Prahlada Bhakti Vijayam | Tyagaraja |
| Padams | Kshetrayya |
| Keertanas, such as "Paluke Bangaramayena" | Bhadrachala Ramadasu |
| Krishna Leela Tarangini | Narayana Tirtha |
| Poems | Tallapaka Tirumalamma |
| Radhika Santwanam | Muddupalani |
| Devotional verse | Pothana |
| Several padyams | Vemana |
| Dasarathi Satakam | Dasarathi |
| Ramadasu verse | Gopanna |

### TE-037, `te-culture-3`: modern prose and verse, authors who died by 1955 (te-8850 to 8899)

Candidate authors and works; the death year of each is to be read, and one who fails the floor is dropped. The existing reading deck `te-en-reading-diddubatu` already uses Gurajada Apparao's "Diddubatu", so other works are used.

| Candidate | Creator |
|---|---|
| Kanyasulkam (other than the Diddubatu excerpt) | Gurajada Apparao |
| Desamunu preminchumanna | Gurajada Apparao |
| Rajasekhara Charitramu | Kandukuri Veeresalingam |
| A work or poem | Gidugu Ramamurthy |
| Gayopakhyanam | Chilakamarti Lakshmi Narasimham |
| Krushivaludu | Duvvuri Rami Reddy |
| A work or poem | Tripuraneni Ramaswamy Chowdary |
| A work or poem | Garimella Satyanarayana |
| A work or poem | Panuganti Lakshminarasimha Rao |
| A work or poem | Basavaraju Apparao |
| A work or poem | Nyapati Subba Rao |

The plan names Viswanatha Satyanarayana, Sri Sri, Gurram Jashuva, Devulapalli Krishnasastri and Rayaprolu as expected to fail the floor (to be confirmed by the builder's reading); they appear in the recommendations instead. Fewer than 18 may pass.

### TE-038, `te-culture-4`: satakams, padyams and anonymous verse before 1900 (te-8900 to 8949)

Each only with the text and the author read on the cited page.

| Candidate | Creator |
|---|---|
| Sumati Satakam | anonymous |
| Padyams | Yogi Vemana |
| Dasarathi Satakam | Dasarathi |
| Bhaskara Satakam | to be read |
| Kumari Satakam | to be read |
| Narasimha Satakam | Seshappa |
| Krishna Satakam | to be read |
| Kalahasteeswara Satakam | Dhurjati |
| Srirama Satakam | to be read |

## Proverbs (TE-039 to TE-041, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`; each card has a `literal` note and a meaning. Sources, cited with page: te.wikiquote "తెలుగు సామెతలు" and "A Collection of Telugu Proverbs" (Carr, 1868, on Wikisource or archive.org; the builder reads whether and how it is in the public domain). **A proverb whose text the builder did not read on the cited page is dropped.** No proverb is listed here; the page names themes only.

| Task | Deck | Themes | Ids |
|---|---|---|---|
| TE-039 | `te-proverbs-1` | animals, food, family, work, money, weather (short first) | te-8950 to 8999 |
| TE-040 | `te-proverbs-2` | friends and neighbours, learning, luck, time, speech, farming | te-9000 to 9049 |
| TE-041 | `te-proverbs-3` | love, age, honesty, effort, appearances, wit | te-9050 to 9099 |

TE-040 and TE-041 use no proverb of an earlier deck.

## Multi-word verbs (TE-042 to TE-044, 3 x 20)

Genre `multiword`, a `pattern_family`, a `usage` note on every card; the card's citation form is the verbal noun in -ḍaṁ (`రావడం`). Parts already taught are written by `ref`. Fewer than 20 attested: report the count, do not fill.

| Task | Deck and `pattern_family` | Candidates and selection | Ids |
|---|---|---|---|
| TE-042 | `te-multiword-conjunct-verbs`, `conjunct-verb` | A noun plus చేయడం, అవడం, పడడం, కొట్టడం or ఇవ్వడం. Selection by procedure: scan the cores `te-grammar-conjunct-verbs`, `te-work`, `te-school`, `te-health`, `te-hobbies`, `te-phone`, `te-workplace` in that order, nouns in id order, and take each noun whose te.wiktionary entry (or a cited dictionary page) lists a noun-plus-verb compound, until 20. Seeds to check first: సహాయం చేయడం, ప్రయాణం చేయడం, స్నానం చేయడం, భోజనం చేయడం, ఫోన్ చేయడం, పని చేయడం | te-9100 to 9149 |
| TE-043 | `te-multiword-compound-verbs`, `aspectual-compound` | The verbal participle (-ఇ) plus పోవడం (completion), పడడం, వేయడం, ఇవ్వడం or పెట్టడం (benefactive), కోవడం (reflexive), చూడడం (trial), రావడం, ఉండడం; each auxiliary paired with two or three verbs taught by `te-verbs`, `te-more-verbs`, `te-verbs-3`. Only compounds attested on te.wiktionary or a cited page | te-9150 to 9199 |
| TE-044 | `te-multiword-dative-subject`, `dative-subject` | The construction X-కు plus a noun, adjective or verb of feeling, need or knowing. Candidates to check first: నాకు ఇష్టం, నాకు కావాలి, నాకు తెలుసు, నాకు అర్థమైంది, నాకు ఆకలిగా ఉంది, నాకు దాహంగా ఉంది, నాకు నిద్ర వస్తోంది, నాకు కోపం వచ్చింది, నాకు నవ్వు వచ్చింది, నాకు భయంగా ఉంది, నాకు జ్వరం వచ్చింది, నాకు తలనొప్పిగా ఉంది, నాకు గుర్తు ఉంది, నాకు సంతోషంగా ఉంది, నాకు చలిగా ఉంది, నాకు వేడిగా ఉంది, నాకు బాధగా ఉంది, నాకు సహాయం కావాలి, నాకు సమయం లేదు, నాకు ఆశ్చర్యంగా ఉంది. The rules decks `te-grammar-likes` and `te-grammar-needs` already teach the pattern, so these are phrase cards with a `usage` note; the builder searches the course for duplicates first | te-9200 to 9249 |

The Telugu strings above are the plan's candidates; their spelling is not checked by this page and goes through the tool and the review queue.

## Recommendations (TE-045 and TE-046, 10 + 10)

File `decks/recommendations/te.yaml`, in the shape of `recommendations/ja.yaml`: `id: "te-rec-<name>"`, `medium`, `title { text, reading }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each, tags; no quotation and no link. The learner sources these works themselves, so rights are not a gate; year and creator are **to be read** from the work's Wikipedia page, and a work whose facts the builder could not read is replaced from the reserve. Creators are added to `creators/te.yaml` where missing.

| Task | Medium | Candidates |
|---|---|---|
| TE-045 | films | Maya Bazaar (1957; the builder checks whether it is in the public domain, and if so it goes to culture instead), Shankarabharanam (1980), Sagara Sangamam (1983), Pelli Choopulu (2016), Baahubali: The Beginning (2015), RRR (2022), Sita Ramam (2022), Mahanati (2018), Jersey (2019), Eega (2012). Reserve: Swathi Muthyam (1986), Malleswari (1951), Ala Vaikunthapurramuloo (2020), Jathi Ratnalu (2021) |
| TE-046 | television, books, film, a song, a comic, a podcast or radio programme | Amrutham (TV serial), Chivaraku Migiledi (novel, Buchi Babu), Maidanam (Chalam), Amaravati Kathalu (Satyam Sankaramanchi), Maa Telugu Talliki (state song), Pathala Bhairavi (1951), Veyipadagalu (Viswanatha Satyanarayana), Kanyasulkam (stage and film versions, if the builder confirms), a Bapu comic, a podcast or radio programme the builder can verify |

The years in parentheses and the attributions are the plan's, not checked by this page.

## Review-queue rule

Everything is `unreviewed`. Each unread, uncertain or dropped item is a row in the builder's report, in the table shape of `docs/review-queue/te.md`; TE-059 to TE-061 collect the rows into that file, one batch at a time.

## Overlaps to settle, and open questions

- **Names that appear twice in the plan's lists.** Dasarathi Satakam and Vemana's padyams are candidates in both TE-036 and TE-038; Pothana's devotional verse (TE-036) overlaps TE-035's Bhagavatham items; "Gopanna (Ramadasu)" and "Bhadrachala Ramadasu" in TE-036 may name one person; Kanyasulkam is a culture candidate (TE-037) and a recommendation (TE-046). The builders take each work once, in the earlier task, and the later task uses its reserve.
- **Professional decks** are held for the owner's profession list.
- **Muddupalani's Radhika Santwanam** (TE-036): the builder reads its publication and any content concern on the cited page and reports it; it is dropped if the page leaves doubt.
