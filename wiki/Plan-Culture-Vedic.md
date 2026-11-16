# Plan: Vedic Sanskrit genre decks, verified sourcing list (culture, creators, sayings, multi-word verbs, recommendations, facts)

Task VSA-001 of [Deck-Work-Queue-VSA](Deck-Work-Queue-VSA.md), written 2026-11-16. It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Tamil](Plan-Culture-Tamil.md), for the tasks VSA-011 to VSA-014 (culture), VSA-020 (sayings), VSA-030 (multi-word verbs), VSA-060 (recommendations), VSA-080 (facts) and the grammar notes of VSA-005. The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) (D1, D4, D5, D13).

**What "verified" means on this page.** Every entry below was **read** by the author on 2026-11-16 on the page named in its "Read at" column, through the MediaWiki pages of sa.wikisource, en.wikisource, en.wikipedia and en.wikiquote. Nothing was written from memory. Dates, counts and attributions are what the named page says; where two pages disagree the disagreement is recorded, not resolved. Nothing was run locally (no tests, no validator, no `tools/transcribe.py`). The pages were read as text, so **the builder re-reads each page, copies the Devanagari from it, and takes `reading` and `ipa` from the tool (VSA-110), never from this page.** Anything that could not be read to the point of use is under [Dropped](#dropped-unverifiable), not in a deck list. Every Vedic deck ships `unreviewed` (owner, 2026-11-13) and doubts go to `docs/review-queue/vsn.md`.

Quotations: Devanagari strings below are the first line of a hymn (5 to 10 words each, far under the 25-word rule) copied from the `<poem>` block of the sa.wikisource page named, and short words or phrases. English glosses are the author's own plain words, not Griffith's.

## 1. Hosts tested on 2026-11-16

"Blocked" is the agent proxy answering `CONNECT tunnel failed, response 403` to `curl -I`. The Wikimedia hosts rate-limit hard (HTTP 429 with `retry-after`, roughly one page per 30 to 90 seconds after any burst); every read below went through one polite queue that honoured `retry-after`.

| Host | Status | What it gave |
|---|---|---|
| sa.wikisource.org | reachable | `ऋग्वेदः सूक्तं <chapter>.<hymn>` pages (all 10 mandalas, one page per hymn: Devanagari text in a `<poem>` block, a `{{header}}` naming the rishi, deity and metre, then Sayana's commentary, with pitch accent marks, and editorial notes). `अथर्ववेदः/अथर्ववेद: काण्डं N` and `यजुर्वेदः`, `यजुर्वेदभाष्यम् (दयानन्दसरस्वतीविरचितम्)` pages exist (titles seen, not read) |
| en.wikisource.org | reachable | Griffith's *Hymns of the Rigveda* per hymn; Whitney's *Sanskrit Grammar* per chapter; Macdonell's *A History of Sanskrit Literature* per chapter; DNB and Britannica biographies; Griffith's Atharva-Veda and Sama-Veda; the Sacred Books of the East index. **Also the web edit view of `Page:` pages gives the DjVu OCR text layer** (`index.php?title=Page:Vedic_Mythology.djvu/30&action=edit`, the `wpTextbox1` field): this is how Macdonell's *Vedic Mythology* was read, unproofread OCR |
| en.wikipedia.org | reachable | page extracts and full text through `action=query&prop=extracts` |
| commons.wikimedia.org | reachable | API only: file records for the DjVu scans (`Vedic Mythology.djvu` 216 pages, 17,284,014 bytes; `The Religion of the Veda.djvu` 316 pages, 19,601,999 bytes). Scan not downloaded; no DjVu tool (`djvutxt`) is installed here |
| en.wikiquote.org | reachable | `Rigveda` page read; weak (see Dropped) |
| www.wikidata.org | reachable | `wbsearchentities` works (Rigveda is Q727413, "most ancient Veda of the Hindus"); nothing else needed |
| upload.wikimedia.org, dumps.wikimedia.org, query.wikidata.org, meta.wikimedia.org, en.m.wikisource.org, www.wikisource.org, en.wiktionary.org, sa.wikipedia.org, hi.wikisource.org | reachable (HTTP 200 or 301 on the root) | not used |
| archive.org, gutenberg.org, sacred-texts.com, sanskritdocuments.org, gretil.sub.uni-goettingen.de, titus.uni-frankfurt.de, books.google.com | **blocked (403)** | the seven the queue named |
| wikisource.org (bare), dsal.uchicago.edu, babel.hathitrust.org, www.wisdomlib.org, en.wikibooks.org, wikimedia.org, www.mediawiki.org | **blocked (403)** | other plausible hosts tried once each |

## 2. Which host gives a readable copy of which work

| Work (as the VSA queue lists it) | Readable on a reachable host? | Page read |
|---|---|---|
| Rigveda, Devanagari text | **Yes**, sa.wikisource (no print edition named on the pages read; every page has rishi, deity and metre in its header) | `ऋग्वेदः सूक्तं ...`, 25 pages (section 3) |
| Rigveda, English | **Yes**, Griffith, en.wikisource (title page says 1896; DNB says Benares 1889-92, 2nd edition 1896-7) | `The Hymns of the Rigveda/Book N/Hymn M`, `The Hymns of the Rigveda/Preface` |
| Griffith, Atharvaveda (1895-96) | Index only on en.wikisource (Books 1 to 20 listed, title page says 1896); no hymn read | `Hymns of the Atharva-Veda` |
| Griffith, Sama Veda | Preface only (title page says 1895; DNB says Benares 1893) | `The Hymns of the Samaveda` |
| Griffith, Yajurveda (1899) | **No**: `The Texts of the White Yajurveda` does not exist on en.wikisource; DNB gives the year | DNB 1912 supplement, Griffith |
| Whitney, *Sanskrit Grammar* | **Yes**, en.wikisource per chapter (the title page transcribed says 1889 and "1950, Harvard", the author page lists 1879 for the first edition) | `Sanskrit Grammar (Whitney)` and `/Introduction`, `/Chapter I, II, V, VIII, XIII, XV` read; `/Appendix`, `/General Index` exist, not read |
| Whitney, *Roots, Verb-forms* (1885) | **No**: only a red link on the author page, both titles tried are missing | `Author:William Dwight Whitney` |
| Whitney and Lanman, *Atharva-Veda Samhita* (Harvard Oriental Series 7 and 8, 1905) | Hosted on en.wikisource (Books I to XX, front matter, indexes); only the contents page read | `Atharva-Veda Samhita` |
| Macdonell, *Vedic Grammar* (1910) | **No text**: the page is a transcribed title page and contents (Phonology, Sandhi, Accent, Nominal stems, Compounds, Declension, Verb, Indeclinables), "overview" only | `Vedic Grammar` |
| Macdonell, *Vedic Grammar for Students* (1916) and *A Vedic Reader for Students* (1917) | **No**: no page under either title, no search hit | search results |
| Macdonell, *Vedic Mythology* (1897) | **Yes, as OCR only**: en.wikisource Index "To be proofread", about 189 pages; pages 11 to 60 read through the edit view, with OCR errors | `Page:Vedic Mythology.djvu/11, 13, 16-19, 22, 24, 36, 60` |
| Macdonell, *A History of Sanskrit Literature* (1900) | **Yes**, en.wikisource per chapter | `.../Chapter 3`, `/4`, `/7` read |
| Müller, *Sanskrit Grammar for Beginners* (1866) | **No**: only a DNB bibliography line ("A Sanskrit Grammar, London, 1866") | DNB 1901 supplement, Max Müller |
| Müller, *Rig-Veda-Sanhita* (6 vols, 1849-73) and *Hymns to the Maruts* (1869) | **No text**: DNB gives the dates; SBE vol. 32 *Vedic Hymns* part 1 (Müller, 1891) is listed in the SBE index, no volume pages | same, and `Sacred Books of the East` |
| Lanman, *Sanskrit Reader* | **Partly**: en.wikisource holds the 1903 edition, "Text and Vocabulary Notes"; only Selection I (the story of Nala, Mahabharata) and its notes exist, so no Vedic selection | `A Sanskrit Reader`, `/Selection I` |
| Muir, *Original Sanskrit Texts* | **No text**: DNB (five volumes 1858-70, 2nd edition 1868-73) | DNB 1885-1900, Muir, John |
| Monier-Williams, dictionary (1899) | **No text**: DNB only (he "devoted himself almost exclusively" to classical Sanskrit, taking little interest in the Vedas) | DNB 1901 supplement, Monier-Williams |
| Bloomfield, *Vedic Concordance* (1906 in the queue) | **No text**: red link; the author page and Britannica 1911 both say **1907** | `Author:Maurice Bloomfield`, `1911 Encyclopaedia Britannica/Bloomfield, Maurice` |
| Oldenberg, SBE 46; Bloomfield, SBE 42 | listed in the SBE index (1897 each), no volume pages | `Sacred Books of the East` |

**Reading verdict.** The Vedic text (Devanagari with pitch accent), Griffith's translation, Whitney's grammar and Macdonell's history are readable from this sandbox. The Vedic grammar of Macdonell, Müller and Lanman is not. So Section 7 (grammar features) is confirmed from Whitney, and a feature that only Macdonell's grammar could confirm is marked UNVERIFIED.

## Rules applied

- **Rights floor** (as in the Tamil page: validator floor 1955, India's term is life plus 60). The Vedic hymns are anonymous and ancient: `author: anonymous`, a `date` the validator's `parse_years` accepts, the traditional rishi (from the sa.wikisource header) in the notes. No rishi has a known year, so **no rishi gets a creator entry** with invented `born`/`died` (D5 requires `born < died`); they are named in the notes only. The creator file holds the modern scholars and translators (Section 4), whose years were read. Basis `public-domain` for culture cards, no `quotation` items.
- **Text as printed on the sa.wikisource page**: only the `<poem>` block. The Sayana commentary (a 14th-century work per en.wikipedia) and the `{{टिप्पणी}}` notes on the same pages are modern editors' apparatus and are not used. The pages name no print edition for the verse text, so the builder writes `edition` as "sa.wikisource.org, page title, revision N" (revision numbers are in Section 3) and the `url`, and the notes say the transcription's source is not named on the page.
- **One excerpt per card**: one first line, at most 25 words (every line below is 4 to 10 words). **At most 3 cards from one mandala per deck.** The deck is never padded: Section 3 lists 25 hymns and three corpus cards, so each of the three decks ships short of 18 and the report says so.
- **`reading` and `ipa` from `tools/transcribe.py`**: the `vedic` engine does not exist yet (VSA-110), and VSA-100 settles whether the accent marks pass the validator. Culture, saying and verb builds that need a reading start after VSA-110. Readings are based on ISO 15919 (never "strictly follows"). The reconstruction note stands: there are no living speakers.
- **Pitch accent policy (for VSA-100).** The poem blocks on sa.wikisource carry no accent marks; the Sayana section of the same page does (U+0951 and U+0952, 118 and 212 occurrences on `ऋग्वेदः सूक्तं १०.१२९`, for example `नास॑दासी॒न्नो`). A card's `target` therefore takes the unaccented poem line; an accented form would have to be copied from the commentary quotation, which is not planned.
- **Translations** are the builder's own plain renderings. Griffith's pages are read to check the sense, not copied. One Griffith page, 10.34, carries "Translation revised 25 April 2006 by Anthony Appleyard following Arthur Anthony Macdonnell's book 'A Vedic Reader'": its English is a modern revision, so no wording is taken from it at all.
- **Pacing.** Reads were polite and followed `retry-after`; a builder that gets HTTP 429 waits.

## 3. Culture decks (VSA-011 to VSA-014)

**Counts.** 25 hymns read in Devanagari on sa.wikisource and in English on en.wikisource, plus 4 corpus cards (the four Vedas, text of three not read); 1 further hymn (1.179) was looked at and dropped. Four decks: three of hymns (10, 8 and 7), one of the four Vedas.

Common to every hymn row: **jurisdiction IN**, basis `public-domain` (anonymous rule), `date` a range in negative years given as `-1500 to -1000` (en.wikipedia, Rigveda: "between 1500 and 1000 BCE, although a wider approximation of c. 1900-1200 BCE has also been given"; **the bulk was composed in the second half of the second millennium BCE** per the same page; en.wikiquote says 1700-1100 BCE; the validator fit of a BCE range is unchecked, see Open points). "Rishi, deity, metre" are as the sa.wikisource `{{header}}` gives them (the attribution is the traditional one). Every row's first line is on the page named; verse counts are the number of numbered verses on both the sa.wikisource and Griffith pages, and are given only where the two agree.

Pages: sa.wikisource `https://sa.wikisource.org/wiki/ऋग्वेदः_सूक्तं_<chapter>.<hymn>` with the Devanagari digits shown below; Griffith `https://en.wikisource.org/wiki/The_Hymns_of_the_Rigveda/Book_<N>/Hymn_<M>`. "rev" is the sa.wikisource revision read.

### VSA-011, `vsn-culture-1`: creation and cosmos (10 hymns)

| # | Hymn | Rishi, deity, metre (header) | Verses | First line (sa.wikisource) | Own gloss of the hymn, from the Griffith page | rev |
|---|---|---|---|---|---|---|
| 1 | RV 10.129 (en.wikipedia "Nasadiya Sukta": the hymn of creation, named from its opening words) | प्रजापतिः परमेष्ठी; भाववृत्तम्; त्रिष्टुप् | 7 | नासदासीन्नो सदासीत्तदानीं नासीद्रजो नो व्योमा परो यत्। | before anything existed; ends by doubting whether even the highest knows how it began (v. 6 and 7) | 402226 |
| 2 | RV 10.90 (en.wikipedia "Purusha Sukta": Purusha, the Cosmic Being) | नारायणः; पुरुषः; अनुष्टुप्, v. 16 त्रिष्टुप् | 16 | सहस्रशीर्षा पुरुषः सहस्राक्षः सहस्रपात् । | the world made from a cosmic sacrifice; v. 9 says the Rik and Saman verses and the Yajus were born from it | 336240 |
| 3 | RV 10.121 (en.wikipedia "Hiranyagarbha": the golden womb) | हिरण्यगर्भः प्राजापत्यः; कः (प्रजापतिः); त्रिष्टुप् | 10 | हिरण्यगर्भः समवर्तताग्रे भूतस्य जातः पतिरेक आसीत् । | one lord of all that lives; each verse ends with the question "what god shall we worship"; v. 10 names Prajapati | 400427 |
| 4 | RV 10.125 | वागाम्भृणी; आत्मा; त्रिष्टुप्, v. 2 जगती | 8 | अहं रुद्रेभिर्वसुभिश्चराम्यहमादित्यैरुत विश्वदेवैः । | a goddess speaks in the first person: "I travel with the Rudras and Vasus", "I am the Queen" (v. 3) | 400730 |
| 5 | RV 10.71 | बृहस्पतिराङ्गिरसः; ज्ञानम् | 11 | बृहस्पते प्रथमं वाचो अग्रं यत्प्रैरत नामधेयं दधानाः । | the first naming of things and how the wise made speech (v. 1 and 2) | 333626 |
| 6 | RV 1.164 | दीर्घतमा औचथ्यः; विश्वे देवाः (and others by verse) | 52 | अस्य वामस्य पलितस्य होतुस्तस्य भ्राता मध्यमो अस्त्यश्नः । | a long riddle hymn; v. 20 the two birds on one tree, v. 46 "the One" with many names | 402071 |
| 7 | RV 1.154 | दीर्घतमा औचथ्यः; विष्णुः; त्रिष्टुप् | 6 | विष्णोर्नु कं वीर्याणि प्र वोचं यः पार्थिवानि विममे रजांसि । | Vishnu's three strides across the world | 403472 |
| 8 | RV 10.151 | श्रद्धा कामायनी; श्रद्धा; अनुष्टुप् | 5 | श्रद्धयाग्निः समिध्यते श्रद्धया हूयते हविः । | the hymn to Faith: by faith the fire is lit | 208435 |
| 9 | RV 10.127 | कुशिकः सौभरः, रात्रिर्वा भारद्वाजी; रात्रिः; गायत्री | 8 | रात्री व्यख्यदायती पुरुत्रा देव्यक्षभिः । | the hymn to Night | 203194 |
| 10 | RV 10.85 | सावित्री सूर्या ऋषिका; verses 6-16 सूर्याविवाहः | 47 | सत्येनोत्तभिता भूमिः सूर्येणोत्तभिता द्यौः । | the wedding of Surya; opens by saying truth and the sun uphold earth and sky; long, take one verse | 401018 |

Read at, all rows: the sa.wikisource page `ऋग्वेदः सूक्तं १०.१२९` (and its siblings `१०.९०`, `१०.१२१`, `१०.१२५`, `१०.७१`, `१.१६४`, `१.१५४`, `१०.१५१`, `१०.१२७`, `१०.८५`), the Griffith page of the same hymn, and where a name is given the en.wikipedia page. 10.129.3 and 7.86.2 contain `ळ` (see Section 7). 10.125's Griffith page opens "I travel with the Rudras and the Vasus"; the card's `notes` say the speaker is the goddess Vac per the header (author `वागाम्भृणी`), a header reading, not a page's own words.

### VSA-012, `vsn-culture-2`: gods and nature (8 hymns)

| # | Hymn | Rishi, deity, metre (header) | Verses | First line (sa.wikisource) | Own gloss | rev |
|---|---|---|---|---|---|---|
| 1 | RV 1.1 | मधुच्छन्दा वैश्वामित्रः; अग्निः; गायत्री | 9 | ॐ अग्निमीळे पुरोहितं यज्ञस्य देवमृत्विजम् । | the first hymn of the Rigveda, to Agni (en.wikipedia "Rigvedic deities": Agni and Indra are the most invoked, Griffith's Preface and Macdonell's History ch. 4: Agni has more than 200 hymns) | 410218 |
| 2 | RV 1.32 | हिरण्यस्तूप आङ्गिरसः; इन्द्रः; त्रिष्टुप् | (not counted: the two pages disagree by one) | इन्द्रस्य नु वीर्याणि प्र वोचं यानि चकार प्रथमानि वज्री । | Indra kills the serpent and frees the waters (Griffith v. 1) | 403053 |
| 3 | RV 3.62 | गाथिनो विश्वामित्रः; verses 10 to 12 सविता; गायत्री and त्रिष्टुप् | 18 | इमा उ वां भृमयो मन्यमाना युवावते न तुज्या अभूवन् । | a hymn to several gods whose verse 10 is the Gayatri verse to Savitr (en.wikipedia "Gayatri Mantra": RV 3.62.10, attributed to Vishvamitra) | 330443 |
| 4 | RV 5.83 | भौमोऽत्रिः; पर्जन्यः | 10 | अच्छा वद तवसं गीर्भिराभि स्तुहि पर्जन्यं नमसा विवास । | the rain god Parjanya makes the plants grow | 400496 |
| 5 | RV 7.86 | मैत्रावरुणिर्वसिष्ठः; वरुणः; त्रिष्टुप् | 8 | धीरा त्वस्य महिना जनूंषि वि यस्तस्तम्भ रोदसी चिदुर्वी । | the poet asks how he may be reconciled with Varuna and asks to be freed from sin | 324074 |
| 6 | RV 7.103 | मैत्रावरुणिर्वसिष्ठः; मण्डूकाः (पर्जन्यः) | 10 | संवत्सरं शशयाना ब्राह्मणा व्रतचारिणः । | the frogs' hymn: priests who lay quiet for a year, and the frogs that sing when the rain comes | 400502 |
| 7 | RV 4.57 | वामदेवो गौतमः; क्षेत्रपतिः and others | 8 | क्षेत्रस्य पतिना वयं हितेनेव जयामसि । | a farmer's hymn to the Lord of the Field and the furrow | 400528 |
| 8 | RV 3.33 | गाथिनो विश्वामित्रः; नद्यः | 13 on the Griffith page; the sa.wikisource page numbers only 8, so no count is stated | प्र पर्वतानामुशती उपस्थादश्वे इव विषिते हासमाने । | two rivers, the Vipas and the Sutudri, run down from the mountains (named in Griffith v. 1); the header makes Vishvamitra and the rivers the speakers | 360653 |

### VSA-013, `vsn-culture-3`: people, speech and life (7 hymns)

| # | Hymn | Rishi, deity, metre (header) | Verses | First line (sa.wikisource) | Own gloss | rev |
|---|---|---|---|---|---|---|
| 1 | RV 10.10 | वैवस्वती यमी ऋषिका (most verses); यमः | 14 | ओ चित्सखायं सख्या ववृत्यां तिरः पुरू चिदर्णवं जगन्वान् । | the dialogue of Yama and his twin sister Yami (Griffith v. 1: she wants a son by her friend) | 214277 |
| 2 | RV 10.14 | वैवस्वतो यमः; यमः and others | 16 | परेयिवांसं प्रवतो महीरनु बहुभ्यः पन्थामनुपस्पशानम् । | honour to King Yama who found the way for many (Griffith v. 1 to 3: Yama found a home for us) | 403512 |
| 3 | RV 10.18 | संकुसुको यामायनः; मृत्युः, पितृमेधः | 14 | परं मृत्यो अनु परेहि पन्थां यस्ते स्व इतरो देवयानात् । | a funeral hymn: "Go hence, O Death" (v. 1); the living are divided from the dead and go out "for dancing and for laughter" (v. 3) | 353436 |
| 4 | RV 10.34 | कवष ऐलूषः; अक्षाः, कृषिः | 14 | प्रावेपा मा बृहतो मादयन्ति प्रवातेजा इरिणे वर्वृतानाः । | the gambler's lament; v. 13 tells him to play no more and farm (Griffith page is a 2006 revision, see Rules) | 206574 |
| 5 | RV 10.95 | ऐलः पुरूरवाः; उर्वशी | 18 | हये जाये मनसा तिष्ठ घोरे वचांसि मिश्रा कृणवावहै नु । | the dialogue of Pururavas and Urvashi (en.wikipedia "Pururavas": RV X.95.18 calls him a son of Ila) | 401030 |
| 6 | RV 10.108 | पणयोऽसुराः; सरमा देवशुनी ऋषिका | 11 | किमिच्छन्ती सरमा प्रेदमानड्दूरे ह्यध्वा जगुरिः पराचैः । | Sarama, Indra's messenger, meets the Panis who hold stolen wealth | 403476 |
| 7 | RV 10.117 | भिक्षुराङ्गिरसः; धनान्नदानं | 9 | न वा उ देवाः क्षुधमिद्वधं ददुरुताशितमुप गच्छन्ति मृत्यवः । | on giving to the needy; also source of the sayings in Section 5 | 219288 |

### VSA-014, `vsn-culture-4`: the four Vedas (4 corpus cards, no excerpt of text read)

Each card is about a work, not a quotation. A card needs an excerpt only if the validator requires one for a corpus card: the builder tries it and drops the Yajurveda card if it does.

| # | Work | What the page says (own words) | Read at |
|---|---|---|---|
| 1 | The Rigveda | 10 books (mandalas), 1,028 hymns in about 10,600 verses; books 2 to 7 are the family books, the oldest, 38% of the text; books 1 and 10 have 191 hymns each | en.wikipedia "Rigveda"; Macdonell, *A History of Sanskrit Literature*, ch. 3 (the tenth book has as many hymns as the first) |
| 2 | The Samaveda | 1,875 verses, all but 75 from the Rigveda (en.wikipedia); "all its verses except seventy-five" (Macdonell ch. 7, the two agree) | en.wikipedia "Samaveda"; *A History of Sanskrit Literature*, ch. 7; Griffith, *The Hymns of the Samaveda* (Preface read) |
| 3 | The Yajurveda | formulas for the whole sacrificial ritual (Macdonell ch. 7); en.wikipedia: Witzel estimates its composition at 1200 to 800 BCE | `Yajurveda` (en.wikipedia), ch. 7 |
| 4 | The Atharvaveda | 730 hymns, about 6,000 mantras, 20 books, "a late addition", language different from Rigvedic (en.wikipedia); Griffith's translation of it lists Books 1 to 20 (en.wikisource, title page 1896) | en.wikipedia "Atharvaveda"; `Hymns of the Atharva-Veda` |

## 4. Creators and eras (`decks/creators/vsn.yaml`, created by VSA-011)

D5 asks `born < died` and a lifespan of at most 120, so only people with read years are creators. Years are as read; a second source is named where two were read.

| Creator | born | died | Sources read | Role |
|---|---|---|---|---|
| Friedrich Max Müller | 1823 (6 Dec) | 1900 (28 Oct) | en.wikipedia "Max Müller"; DNB 1901 supplement ("Born at Dessau on 6 Dec. 1823", died 28 Oct. 1900) | edited the Rigveda with Sayana's commentary, 6 vols, 1849-73 (2nd edition 1890-2) |
| William Dwight Whitney | 1827 (9 Feb) | 1894 | en.wikipedia "William Dwight Whitney" says 7 June 1894; *The Encyclopedia Americana* (1920) says 9 June 1894. **The two disagree on the day; both say 1894.** | *Sanskrit Grammar* (author page 1879; the page read is headed 1889) |
| Arthur Anthony Macdonell | 1854 (11 May) | 1930 (28 Dec) | en.wikipedia; the en.wikisource *Vedic Grammar* page says its longest-living author died in 1930 | *Vedic Mythology* (1897), *A History of Sanskrit Literature* (1900), *Vedic Grammar* (1910) |
| Ralph T. H. Griffith | 1826 (25 May) | 1906 (7 Nov) | en.wikipedia ("25 May 1826 - 7 November 1906"); DNB 1912 supplement (1826-1906, "born ... on 25 May 1826") | translated the Rigveda (Benares 1889-92, 2nd edition 1896-7), Samaveda (1893), Atharvaveda (1895-6), White Yajurveda (1899) per DNB |
| Charles Rockwell Lanman | 1850 (8 Jul) | 1941 (20 Feb) | en.wikipedia; *Encyclopaedia Britannica* 1911 gives the birth only; the en.wikisource author page marks the work PD/US "1941" (died 1941, passes the 1955 floor) | edited the Whitney *Atharva-Veda Samhita*, 1905 |
| Maurice Bloomfield | 1855 (23 Feb) | 1928 (12 Jun) | en.wikipedia; Britannica 1911 (birth); the en.wikisource author page marks PD/US "1928" | *Hymns of the Atharva-Veda* (SBE 42, 1897), *A Vedic Concordance* (**1907**, Britannica 1911 and the author page; the queue says 1906) |
| Sir Monier Monier-Williams | 1819 (12 Nov) | 1899 (11 Apr) | en.wikipedia; DNB 1901 supplement ("1819-1899", "He died at Cannes on 11 April 1899") | Sanskrit-English dictionary, 2nd edition finished just before his death |
| John Muir | 1810 (5 Feb) | 1882 (7 Mar) | en.wikipedia; DNB 1885-1900 ("born at Glasgow on 5 Feb. 1810", "died ... on 7 March 1882") | *Original Sanskrit Texts*, 5 volumes 1858-70 |
| Rudolf von Roth | 1821 (3 Apr) | 1895 (23 Jun) | en.wikipedia (one source) | founder of Vedic philology; dictionary with Böhtlingk |
| Otto von Böhtlingk | 1815 (30 May) | 1904 (19 Mar) | en.wikipedia (one source) | Sanskrit-German dictionary |
| Hermann Oldenberg | 1854 (31 Oct) | 1920 (18 Mar) | en.wikipedia (one source) | SBE 46 *Vedic Hymns* part 2 (per the SBE index) |
| Karl Friedrich Geldner | 1852 (17 Dec) | 1929 (5 Feb) | en.wikipedia (one source) | Vedic and Avestan texts |

One-source creators carry `checked_by` empty and a review-queue row. Sayana (died 1387, "14th-century", en.wikipedia) has no `born`, so he is not a creator; he is named in the notes of the commentary-bearing cards only if the builder wants.

**Rishis.** Named by the sa.wikisource headers and en.wikipedia, never given years (the notes carry them, the cards say `author: anonymous`): मधुच्छन्दा वैश्वामित्रः (1.1), हिरण्यस्तूप आङ्गिरसः (1.32), दीर्घतमा औचथ्यः (1.154 and 1.164; en.wikipedia "Dirghatamas": hymns 140 to 164 of book 1), गाथिनो विश्वामित्रः (3.33, 3.62; en.wikipedia "Vishvamitra": most of mandala 3, Gayatri 3.62.10), वामदेवो गौतमः (4.57; en.wikipedia "Vamadeva": mandala 4), भौमोऽत्रिः (5.83; en.wikipedia "Atri": book 5 is the Atri Mandala), मैत्रावरुणिर्वसिष्ठः (7.86 and 7.103; en.wikipedia "Vasishtha": chief author of mandala 7), बृहस्पतिराङ्गिरसः (10.71), प्रजापतिः परमेष्ठी (10.129), plus Gritsamada (most of mandala 2), Bharadvaja (mandala 6 above all), Kanva (some hymns), Agastya and Lopamudra (hymns 1.165 to 1.191, en.wikipedia "Agastya"). Women and goddess speakers the headers name: यमी (10.10), वागाम्भृणी (10.125), सावित्री सूर्या (10.85), सरमा (10.108), श्रद्धा कामायनी (10.151), उर्वशी (10.95). A header's attribution is traditional, and en.wikipedia says of Lopamudra's era only "1950 BC-1100 BC", which is not used.

**Eras** (negative years are BCE; the validator fit is unchecked):

| Era id | name | from | to | Source |
|---|---|---|---|---|
| `rigvedic` | The Rigvedic period | -1500 | -1000 | en.wikipedia "Rigveda": "between 1500 and 1000 BCE" |
| `vedic` | The Vedic period | -1500 | -500 | en.wikipedia "Vedic period": "c. 1500 - c. 500 BCE", the Vedas "c. 1500-900 BCE" |
| `padapatha-fixing` | The fixing of the pada text | -600 | -500 | en.wikipedia "Rigveda": the padapatha was fixed "in roughly the 6th century BCE" (the `to` is the author's choice, flagged) |
| `western-vedic-studies` | Western Vedic philology | 1849 | 1930 | Müller 1849-73 (DNB), Griffith 1889-92 (DNB), Macdonell d. 1930: a span of the people above, drawn from them, not from a page |

## 5. Attested sayings (VSA-020): few, and honestly so

Vedic has no proverb tradition as a genre. The only candidates are lines of the hymns that stand as sayings. Eight were read; no collection of sayings is readable here (Bloomfield's Concordance is not on any reachable host). Genre `proverbs`, `basis: "oral-tradition"` would be wrong for hymn lines: the builder uses `source` = the hymn, `date` as in Section 3, and asks the validator whether a proverb card may carry a hymn source; if not, these become culture-deck cards of VSA-013. One deck of at most 8; never padded.

| # | Saying (sa.wikisource) | Own gloss (checked on the Griffith page) | Read at |
|---|---|---|---|
| 1 | एकं सद्विप्रा बहुधा वदन्त्यग्निं यमं मातरिश्वानमाहुः ॥४६॥ (RV 1.164.46, second line) | the wise speak of what is One in many names | `ऋग्वेदः सूक्तं १.१६४`; Griffith 1.164 v. 46 ("To what is One, sages give many a title"); also en.wikiquote "Rigveda" (the one independent hit) |
| 2 | केवलाघो भवति केवलादी (RV 10.117.6, end of line 2) | the one who eats alone has only sin | `ऋग्वेदः सूक्तं १०.११७`; Griffith 10.117 v. 6 ("All guilt is he who eats with no partaker") |
| 3 | ओ हि वर्तन्ते रथ्येव चक्रान्यमन्यमुप तिष्ठन्त रायः (10.117.5, line 2) | wealth goes round like the wheels of a car | same; Griffith v. 5 |
| 4 | वदन्ब्रह्मावदतो वनीयान् (10.117.7, start of line 2) | the speaking priest is better than the silent one | same; Griffith v. 7 |
| 5 | समौ चिद्धस्तौ न समं विविष्टः (10.117.9, line 1) | two hands are alike, their work is not | same; Griffith v. 9 |
| 6 | अक्षैर्मा दीव्यः कृषिमित्कृषस्व (10.34.13, line 1) | do not gamble, farm your field | `ऋग्वेदः सूक्तं १०.३४`; Griffith v. 13 (the 2006 revision, sense only) |
| 7 | न वा उ देवाः क्षुधमिद्वधं ददुः (10.117.1, line 1, first half) | the gods did not ordain hunger as death | `ऋग्वेदः सूक्तं १०.११७`; Griffith v. 1 |
| 8 | श्रद्धयाग्निः समिध्यते श्रद्धया हूयते हविः (10.151.1) | by faith the fire is lit, by faith the offering is made | `ऋग्वेदः सूक्तं १०.१५१` |

Items 2 to 5 and 7 are all of hymn 10.117, so at most 3 may sit in a deck (the cap applies), leaving 6 cards; the builder says so.

## 6. Multi-word verbs (VSA-030): preverb plus verb, the preverb free in the Veda

Whitney, `Sanskrit Grammar (Whitney)/Chapter XV`, section 1076: the verb forms "occur very frequently in combination with certain words of direction ... the so-called prepositions or the verbal prefixes". Section 1081 a: "In the earlier language, however (especially in the Veda ...), its position is quite free: it may be separated from the verb by another word or words, and may even come after the form to which it belongs". Section 1077 lists 19 verbal prefixes, with the order of frequency "in the older language (as estimated by the number of roots with which they are found used in RV. and AV.)": pra, a, vi, sam, abhi, ni, ud, pari, anu, upa, prati, ava, nis, ati, apa, para, adhi, api, antar. The 19 are the prefix inventory for a deck of "which preverb"; Whitney glosses each one (for example pra "forward, onward, forth", a "to, unto, at").

Every row below was read on the sa.wikisource hymn page (Devanagari) and the sense checked on the Griffith page of the same verse. "Gap" is what stands between preverb and verb in the line read.

### VSA-030, `vsn-multiword-tmesis`: preverb and verb apart (7 attested in a read hymn)

| # | Preverb + verb | Place (verse) | Gap | Own gloss (Griffith checked) |
|---|---|---|---|---|
| 1 | आ ... वक्षति | RV 1.1.2: स देवाँ एह वक्षति | एह (a = a + iha) | he shall bring the gods here (Whitney 1081 b quotes this line) |
| 2 | उप ... एमसि | RV 1.1.7: उप त्वाग्ने दिवेदिवे दोषावस्तर्धिया वयम् । नमो भरन्त एमसि | five words | we come to you, day by day, bringing homage |
| 3 | वि ... तस्तम्भ | RV 7.86.1: वि यस्तस्तम्भ रोदसी चिदुर्वी | यः | who propped heaven and earth apart |
| 4 | प्र ... नुनुदे | RV 7.86.1: प्र नाकमृष्वं नुनुदे बृहन्तम् | नाकमृष्वम् | who pushed the high sky forth |
| 5 | अव ... सृज | RV 7.86.5: अव द्रुग्धानि पित्र्या सृजा नः | द्रुग्धानि पित्र्या | set us free from the wrongs of our fathers |
| 6 | परि ... बभूव | RV 10.121.10: प्रजापते न त्वदेतान्यन्यो विश्वा जातानि परि ता बभूव | ता | Prajapati, you alone embrace all these created things |
| 7 | प्र ... वान्ति | RV 5.83.4: प्र वाता वान्ति पतयन्ति विद्युतः | वाताः | the winds blow forth |

### VSA-031, `vsn-multiword-preverb-adjacent`: preverb standing before the verb as its own word (9 attested)

| # | Preverb + verb | Place (verse) | Own gloss |
|---|---|---|---|
| 1 | आ गमत् | RV 1.1.5: देवो देवेभिरा गमत् | may he come here with the gods |
| 2 | प्र वोचम् | RV 1.32.1 and 1.154.1: ... वीर्याणि प्र वोचम् | I will declare the heroic deeds (both hymns open so) |
| 3 | प्र वोचत् | RV 10.129.6: को अद्धा वेद क इह प्र वोचत् | who can declare it here |
| 4 | सं वदे | RV 7.86.2: उत स्वया तन्वा सं वदे | I talk it over with myself |
| 5 | अभि ख्यम् | RV 7.86.2: ... सुमना अभि ख्यम् | may I look on him kindly |
| 6 | आ विवेश | RV 10.125.6: द्यावापृथिवी आ विवेश | I have entered heaven and earth |
| 7 | प्र वामि | RV 10.125.8: अहमेव वात इव प्र वाम्यारभमाणा | I blow forth like the wind |
| 8 | नि षिञ्च | RV 5.83.8: महान्तं कोशमुदचा नि षिञ्च | pour down |
| 9 | अभि क्रन्द | RV 5.83.7: अभि क्रन्द स्तनय गर्भमा धा | roar |

### VSA-032, `vsn-multiword-whitney`: Latin quotations, read in Whitney only (4)

The four examples Whitney gives under section 1081 b (in his transliteration, with accents, from the RV and AV, no Devanagari on the page for these): *tā́v ā́ yātam úpa dravát* (RV, "do ye two come hither quickly"), *prá ṇa ā́yūṅṣi tāriṣat* (AV, "may he lengthen out our lives"), *gámad vā́jebhir ā́ sá naḥ* (RV, the preverb after the verb), *pári mā́m pári me prajā́m pári ṇaḥ pāhi yád dhánam* (AV). **None is attested here in a read hymn**: the builder finds the Devanagari on a sa.wikisource hymn page, or the item is dropped. They are the only examples of the preverb *after* the verb.

**Count.** 7 + 9 + 4 = 20 headwords, 16 of them attested in a read hymn. The deck is two families of 7 and 9 plus at most 4.

## 7. Grammar features (for VSA-005 and the grammar units)

Confirmed on the Whitney page named (Whitney's chapter and section numbers), on 2026-11-16. A feature whose name Whitney does not use is marked.

| Feature | Whitney on the read page | Status |
|---|---|---|
| Injunctive | Whitney does not use the word on the pages read (Chapter VIII). He describes it as the unaugmented forms of the imperfect and aorist: section 587, "forms identical with those of augment-tenses save for the lack of an augment is quite frequent" in the early language, "especially in the RV."; used non-modally with present or past sense or modally; after mā prohibitive (579, "the imperative negative, or prohibitive, is from the earliest period ... regularly ... expressed by the particle mā́ with an augmentless past form") | **the phenomenon CONFIRMED, the label "injunctive" UNVERIFIED** (Macdonell's grammar is unreadable here) |
| Subjunctive | sections 557 to 563: "three or four times as common as the optative in the Rig-Veda", the first-person ending in -ni and -ā; "improper subjunctive" for the unaugmented forms (563) | CONFIRMED |
| Infinitives -tave, -dhyai | section 968: the later language has the single infinitive in -tum; 969 to 970: in the Veda many verbal nouns are used infinitively, the dative of the noun in *tu* ends in *tave* or *tavāi* (970 b); 976: the ending *dhyāi* is irregular, with an *a* before it, as in *pibadhyāi* ("to drink"), *huvadhyāi*; the -tum infinitive is rare in the Veda per 968 | CONFIRMED (Whitney writes -dhyāi, -tavāi) |
| Preverb separate from the verb ("tmesis") | section 1081 a and b, quoted in Section 6; Whitney does not use the word "tmesis" on the pages read | **the phenomenon CONFIRMED, the label "tmesis" UNVERIFIED** |
| Pitch accent | sections 80 to 86: the primary tones udatta ("raised", acute) and anudatta ("not raised", grave); svarita is secondary, the fusion of acute and grave; 87 a: in Rigveda manuscripts the acute is left unmarked, the svarita has a short vertical stroke above, the grave before an acute a horizontal stroke below, as in अ॒ग्निम् agním; 88: the Atharva-Veda, Vajasaneyi and Taittiriya manuscripts differ "of trifling importance". The queue's claim that Samaveda and Yajurveda systems differ is **not** confirmed (Whitney's trifling-difference statement covers three texts, not the Samaveda) | CONFIRMED for the Rigveda marks; Samaveda UNVERIFIED |
| Instrumental plural -ebhiḥ | section 329 d: the instrumental ends later always in -āis, "but in the Veda is found abundantly the more normal form -ebhis (in RV., nearly as frequently as -āis; in AV., only one fifth as frequent)"; also 329 a: nominative plural -āsas "one third of the occurrences in RV." | CONFIRMED (Whitney writes -ebhis; the card shows -ebhiḥ) |
| Vedic ळ (ḷ for intervocalic ḍ) | section 54: "Some of the Vedic texts have another l-sound ... substituted for a lingual ḍ ... between two vowels", examples ईळे īḻe for ईडे īḍe, मीळ्हुषे; "especially in the Rig-Veda". Also seen in the verse text: ईळे (RV 1.1.1), गूळ्हम् (10.129.3), मृळीकम् (7.86.2), दूळभ (7.86.4) on sa.wikisource | CONFIRMED |

## 8. Facts for the path (VSA-080): 45 verified candidates

Each fact is a claim of one read page (two where marked). The builder phrases it itself and cites the page; a fact with a number is the page's number.

| # | Fact | Read at |
|---|---|---|
| 1 | The Rigveda has 10 books (mandalas) and 1,028 hymns in about 10,600 verses | en.wikipedia "Rigveda" |
| 2 | Books 1 and 10 have 191 hymns each | en.wikipedia "Rigveda"; Macdonell ch. 3 says the tenth has as many as the first |
| 3 | Books 2 to 7 are the family books, the oldest part, 38% of the text | en.wikipedia "Rigveda" |
| 4 | The hymns are arranged by rishi family; Agni and Indra are the gods most invoked | Griffith, Preface |
| 5 | Agni is the god of more than 200 hymns, next to Indra | Macdonell, *A History of Sanskrit Literature*, ch. 4 |
| 6 | The bulk of the Rigveda is dated to the second half of the second millennium BCE | en.wikipedia "Rigveda" |
| 7 | The padapatha was fixed in the later Brahmana period, about the 6th century BCE | en.wikipedia "Rigveda" |
| 8 | The Vedic period is c. 1500 to c. 500 BCE; the Vedas c. 1500 to 900 BCE | en.wikipedia "Vedic period" |
| 9 | RV 10.129 has 7 verses and its header names Prajapati Paramesthin | sa.wikisource page; Griffith |
| 10 | RV 10.90 has 16 verses (the 16th in a different metre) | sa.wikisource; Griffith |
| 11 | RV 10.121 has 10 verses and ends each of its first verses with the same question | Griffith 10.121 |
| 12 | The Gayatri verse is RV 3.62.10, to Savitr | en.wikipedia "Gayatri Mantra"; sa.wikisource 3.62 header (verses 10 to 12 to Savitr) |
| 13 | RV 1.1 has 9 verses, is addressed to Agni and is in the gayatri metre | sa.wikisource 1.1; Griffith |
| 14 | RV 1.164 has 52 verses | sa.wikisource; Griffith; the commentary on the page says "द्विपञ्चाशदृचम्" |
| 15 | RV 1.164.46 says the One is called by many names | sa.wikisource; Griffith; en.wikiquote |
| 16 | RV 10.85 has 47 verses; verses 6 to 16 are the wedding of Surya | sa.wikisource header; Griffith |
| 17 | RV 10.34 (the gambler) has 14 verses | sa.wikisource; Griffith |
| 18 | RV 10.95, the dialogue of Pururavas and Urvashi, has 18 verses | sa.wikisource; Griffith |
| 19 | RV 7.103, the frogs, has 10 verses | sa.wikisource; Griffith |
| 20 | RV 5.83, to Parjanya, has 10 verses and the rishi is Bhauma Atri per the header | sa.wikisource; Griffith |
| 21 | RV 10.18 is a funeral hymn of 14 verses | sa.wikisource header (मृत्युः, पितृमेधः); Griffith |
| 22 | RV 3.33 names the rivers Vipas and Sutudri in its first verse | Griffith 3.33 |
| 23 | The Samaveda has 1,875 verses, all but 75 from the Rigveda | en.wikipedia "Samaveda"; Macdonell ch. 7 |
| 24 | The Atharvaveda has 730 hymns, about 6,000 mantras, in 20 books | en.wikipedia "Atharvaveda" |
| 25 | The Yajurveda is dated by Witzel to 1200 to 800 BCE | en.wikipedia "Yajurveda" |
| 26 | Sayana, a 14th-century commentator, died in 1387 | en.wikipedia "Sayana" |
| 27 | Müller edited the Rigveda with Sayana's commentary (6 vols, 1849-73; 2nd edition 1890-92) | DNB 1901 supplement, Max Müller |
| 28 | Griffith's Rigveda translation appeared at Benares in 1889-92, a second edition in 1896-7 | DNB 1912 supplement, Griffith |
| 29 | Atri: the fifth book is called the Atri Mandala | en.wikipedia "Atri" |
| 30 | Vasishtha is the chief author of mandala 7; Vishvamitra wrote most of mandala 3; Vamadeva is credited with mandala 4 | en.wikipedia "Vasishtha", "Vishvamitra", "Vamadeva" |
| 31 | Gritsamada: most of mandala 2 is attributed to him | en.wikipedia "Gritsamada" |
| 32 | Dirghatamas is the author of hymns 140 to 164 of book 1 | en.wikipedia "Dirghatamas" |
| 33 | Agastya and Lopamudra are the authors of hymns 1.165 to 1.191 | en.wikipedia "Agastya" |
| 34 | Vedic pitch accent has three qualities: udatta, anudatta, svarita | en.wikipedia "Vedic accent"; Whitney 81 |
| 35 | In Rigveda manuscripts the grave before an acute has a horizontal stroke below and the svarita a vertical stroke above | Whitney 87 a |
| 36 | The sa.wikisource Sayana section writes the accent with U+0951 and U+0952 | `ऋग्वेदः सूक्तं १०.१२९` (118 and 212 occurrences) |
| 37 | The subjunctive is three or four times as common as the optative in the Rigveda | Whitney 557 |
| 38 | Unaugmented past forms are common in the Rigveda and follow mā to forbid | Whitney 587 and 579 |
| 39 | The later language has one infinitive (-tum); the Veda has several, including -dhyāi | Whitney 968 to 976 |
| 40 | In the Veda the preverb may stand apart from the verb, even after it | Whitney 1081 a |
| 41 | The most frequent preverb in the Rigveda and Atharvaveda is pra, then ā, vi, sam | Whitney 1077 a |
| 42 | The Rigveda instrumental plural has -ebhis nearly as often as -āis | Whitney 329 d |
| 43 | A Vedic ḷ replaces ḍ between two vowels, especially in the Rigveda | Whitney 54 |
| 44 | Indra and Varuna are the two leading gods in the Rigveda per Macdonell (Indra the warrior, Varuna the moral ruler); Ushas is the sister of Night | Macdonell, *Vedic Mythology*, `Page:Vedic Mythology.djvu/30` (printed page 20) and `/60` (OCR, unproofread) |
| 45 | Ushas is almost the only goddess to whom whole hymns are addressed | Macdonell, *A History of Sanskrit Literature*, ch. 4 |

## 9. Recommendations (VSA-060)

File `decks/recommendations/vsn.yaml`: every entry is a public-domain edition or study; shape of `recommendations/ja.yaml`: `id: "vsn-rec-<name>"`, `medium: book`, title, `creator` (a Section 4 id), `year`, `level`, `briefing { en }` in the builder's own words, three to eight questions, `rights_checked` and `jurisdiction`; nothing of the work shipped, no link. "Year" is as the page says; disagreements are shown.

| # | Title | Creator | Year (as read) | Level | Read at |
|---|---|---|---|---|---|
| 1 | *The Hymns of the Rigveda* | Griffith | 1896 (title page); first edition 1889-92 (DNB) | A1 on | en.wikisource, all |
| 2 | *Sanskrit Grammar, including both the Classical Language, and the older Dialects, of Veda and Brahmana* | Whitney | 1879 (author page); the transcribed title page is 1889 and the 1950 printing | A2 to B1 | en.wikisource `Sanskrit Grammar (Whitney)`; readable; Section 7 is built from it |
| 3 | *A History of Sanskrit Literature* | Macdonell | 1900 | A2 on | en.wikisource, ch. 3, 4, 7 read |
| 4 | *Vedic Mythology* | Macdonell | 1897 (title page and Index) | B1 | en.wikisource Index "To be proofread"; OCR read |
| 5 | *Vedic Grammar* | Macdonell | 1910 | B1 | en.wikisource, a title and contents page only |
| 6 | *Atharva-Veda Samhita* (Harvard Oriental Series 7, 8) | Whitney, rev. Lanman | 1905 | B1 | en.wikisource contents |
| 7 | *The Hymns of the Atharva-Veda* | Griffith | 1896 (title page); DNB 1895-6 | A2 on | en.wikisource index |
| 8 | *The Hymns of the Samaveda* | Griffith | 1895 (title page); DNB 1893 | A2 | en.wikisource preface; **the two disagree** |
| 9 | *Rig-Veda-Sanhita* with Sayana's commentary | Müller | 1849-73 (6 vols), 1890-2 (2nd edition) | B1 | DNB only |
| 10 | *A Vedic Concordance* (Harvard Oriental Series) | Bloomfield | 1907 | B1 | author page, Britannica 1911; **not 1906** |
| 11 | *Vedic Hymns*, part 1 (SBE 32) and part 2 (SBE 46) | Müller; Oldenberg | 1891; 1897 | B1 | SBE index; DNB for Müller |
| 12 | *Hymns of the Atharva-Veda* (SBE 42) | Bloomfield | 1897 | B1 | SBE index; Britannica 1911 |
| 13 | *Original Sanskrit Texts on the Origin and History of the People of India* | Muir | 1858-70 (5 vols), 2nd edition 1868-73 | B1 | DNB |
| 14 | *The Religion of the Veda* | Bloomfield | 1908 | A2 | author page; the Index page exists; text not read |

Each of these is a recommendation (a book to read), so the "source it yourself" mode does not matter: they are all in the public domain, and nothing is quoted. The builder must be careful with the Whitney grammar's year (1879 is the first edition: the author page; the page read is a later printing).

## Dropped, unverifiable

Each item below was looked for on 2026-11-16 and not read to the point of use. None is in a deck list above. A builder may bring one back by reading its page and its text.

**A. Works with no readable text on a reachable host (15):**

1. Müller, *Sanskrit Grammar for Beginners* (1866): only a DNB line "A Sanskrit Grammar, London, 1866".
2. Müller, *Rig-Veda-Sanhita* (text and Sayana, 1849-73): DNB dates only.
3. Müller, *Hymns to the Maruts* (1869) and SBE 32 *Vedic Hymns* part 1 (1891): the SBE index lists it; no volume page exists under `Sacred Books of the East/Volume 32`.
4. Oldenberg, SBE 46: same.
5. Bloomfield, SBE 42: `Sacred Books of the East/Volume 42` is missing.
6. Whitney, *Roots, Verb-forms and Primary Derivatives* (1885): red link; both titles tried are missing.
7. Macdonell, *Vedic Grammar for Students* (1916): no page, no search hit.
8. Macdonell, *A Vedic Reader for Students* (1917): same.
9. Macdonell, *Vedic Grammar* (1910): the page is contents only; no chapter text, so no grammar card is sourced from it.
10. Lanman, *Sanskrit Reader*: the page is the 1903 edition with Selection I, the story of Nala (Mahabharata); the queue's 1884 and any Vedic selection are not on the page.
11. Monier-Williams dictionary: no text host; and DNB says he cared little for the Vedic period.
12. Muir, *Original Sanskrit Texts*: DNB dates only, no text.
13. Bloomfield, *A Vedic Concordance*: red link; no text.
14. Griffith, *The Texts of the White Yajurveda* (1899): the page does not exist; DNB date only.
15. Macdonell's *Vedic Index of Names and Subjects* (1912): the author page lists it and the Index page for volume 1 exists (375 bytes); the title page is missing and its second author was not read.

**B. Hymns and cards looked at and not usable (11):**

16. RV 1.179 (Lopamudra and Agastya): the Griffith page says only that the hymn "was originally only found in the Appendix, with certain lines translated in Latin"; the sa.wikisource page was not read.
17. The Ushas hymn RV 1.113 (and the other dawn hymns): not read; en.wikipedia "Ushas" page read, hymn text not; a card needs the hymn page.
18. The Battle of the Ten Kings (RV 7.18): en.wikipedia page read, hymn text not read.
19. Soma hymns (book 9), the Maruts, the Ashvins, Rudra hymns, the Surya hymn 1.50, the arrow hymn 6.75: not read (the page of "Soma (Vedic)" is missing on en.wikipedia).
20. Atharvaveda hymns in Devanagari: the sa.wikisource `अथर्ववेदः/अथर्ववेद: काण्डं N` pages exist (titles seen) and no hymn was read.
21. Yajurveda verses in Devanagari: the sa.wikisource pages are Dayananda's commentary (`यजुर्वेदभाष्यम् (दयानन्दसरस्वतीविरचितम्)`) titles seen, not read.
22. Pada-patha on sa.wikisource: the queue says `ऋग्वेद-पदपाठः/मण्डलम्-१` to `-१०` exist; this run could not list them under the rate limit and did not read one. The preverb examples above come from the sukta pages instead.
23. The vocabulary of the hymn pages (Sayana's glosses): not used (Rules).
24. en.wikipedia pages missing under the names tried: Sarama (Rigveda), Vak (goddess), Devi Sukta, Ghosha, Soma (Vedic), Thomas Aufrecht.
25. Multi-word candidates left out: *anu parehi* (RV 10.18.1), because the analysis of *pare-* is uncertain; *ā rohata* (10.18.6), whose sense needs a check against a source not read; *upa spṛśāmi* (10.125.7), whose text on the page joins the preverb by sandhi (`वर्ष्मणोप स्पृशामि`).
26. The Rigveda's "Tilak" date of 6000 to 4000 BCE: en.wikipedia records it as one author's astronomical argument; not used.

**C. Facts and claims the queue made that were not confirmed (6):**

27. "Injunctive" and "tmesis" as terms in Whitney: not on the pages read (Section 7).
28. The Samaveda and Yajurveda accent systems differ from the Rigveda's: Whitney 88 covers only the Atharva-Veda, Vajasaneyi-Samhita and Taittiriya texts ("trifling" differences).
29. Whitney, *Sanskrit Grammar*, 1879: the page read is headed 1889 and 1950.
30. Bloomfield's Concordance, 1906: the pages say 1907.
31. The en.wikiquote quotations other than 1.164.46: uncited or taken from partisan authors, with translations of unknown origin (II.33.4, III.58.6, VI.45.31, VII.95.2, VIII.48, IX.57.3, X, and others); the page's own dating "1700 to 1100 BCE" differs from en.wikipedia's.
32. Lopamudra's era ("1950 BC-1100 BC"): en.wikipedia; not used.

**Count of dropped items: 32.**

## Review-queue rule

Everything is `unreviewed`. Each uncertain item is a row in the builder's report in the shape of `docs/review-queue/vsn.md`. The rows this page already raises: the Whitney death day (7 or 9 June 1894), the Whitney grammar's year (1879 against 1889), the Griffith and Samaveda years (1896 and 1895 on the title pages, 1889-92 and 1893 in DNB), the 10.34 Griffith revision, the BCE `date` shape of every hymn, the header attributions of the rishis (traditional), the sa.wikisource transcription source (no print edition named on the pages read), the OCR of *Vedic Mythology*, the three unverified terms of Section 7, and the course-wide reconstructed pronunciation.

## Open points for the builders and the orchestrator

- **Validator fit for BCE dates.** The anonymous rule needs a `date` shape that `parse_years` accepts. A range beginning before the common era may not parse; nothing was run. The first culture builder tries one hymn in the PR's CI and reports; the fallback is `circa` with the earliest positive century, or the Rigveda card says the period in `notes` only.
- **Accent marks (VSA-100).** The poem lines on sa.wikisource are unaccented; only the commentary quotations carry U+0951 and U+0952. If the course wants accented targets, the text must come from a source that was not read here, so this plan assumes unaccented `target` text, and the card's note says Vedic hymns were recited with pitch accent (Whitney 80 to 87).
- **Decks are short.** 10, 8 and 7 hymns, and 4 corpus cards: all three hymn decks ship below 18 and the report says so. A builder with more time reads more hymns on sa.wikisource, which has every hymn of every mandala; the first candidates are the dawn hymns (1.113), the Maruts, the Ashvins, Soma (book 9) and 6.75, each of which needs its Griffith page read as well.
- **Macdonell's grammar and reader are not reachable.** If the owner wants a Vedic grammar source beyond Whitney, someone with an unrestricted network must read them; the VSA grammar units use Whitney only.
- **Shared text rules.** Hymn text is public domain by age; the sa.wikisource transcription's CC BY-SA notice covers the page's layout and apparatus, so the builder never copies the commentary or the notes.
