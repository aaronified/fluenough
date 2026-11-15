# Plan: Kannada genre decks, verified sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task KN-001 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md), written 2026-11-15 under the Kannada override of rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Telugu](Plan-Culture-Telugu.md), for the tasks KN-010 to KN-013, KN-020 to KN-022, KN-030 to KN-032 and KN-060. The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md).

**Unlike the Telugu page, this one has been read.** Each row says what the author of this page actually read on a named page on 2026-11-15, and marks the rest `unverified`. Nothing is filled in from memory: a row whose fact was not read says so, and the builder reads it before using it (or drops it). No Kannada speaker reviews the decks (owner, 2026-11-13): everything ships `unreviewed`, and doubts go to `docs/review-queue/kn.md`. If this page and a task row of the queue differ, this page wins.

## How a row is marked

Two columns appear in the culture tables.

- **ID** (identity): `V` means the creator's two lifespan endpoints (a circa year is accepted, as the validator's `circa` allows) were both read on the cited en.wikipedia or kn.wikipedia page, so `born` and `died` can be written. `P` means only a century, a period or one endpoint was read. `U` means nothing usable was read. The work's own date is in the row; a work whose year is unknown takes the creator's lifespan as its `date` span, as batch 1 of the Japanese deck does.
- **Text**: where the text of the item is, and whether the author of this page saw it. `read` means the verse was read verbatim on the named Wikisource page. `page` means the Wikisource page or its title list exists (the title of a vachana or a song is its first line) but the text itself was not shown. `none` means no readable source was found. **A builder never writes a card from a `page` or `none` row without reading the text itself, and drops the row if it cannot.**

A pre-modern poet whose death is only known as a century is far inside the rights floor (died 1955 or earlier); the century goes in the source block as a circa lifespan, never as a made-up year. One caution applies to every Wikisource text: **Wikisource may hold a 20th-century editor's edition**. The Kumaravyasa text on kn.wikisource is from the Bharata Kathamanjari edited by Kuvempu and Masti (page footnote, read), and Kuvempu died in 1994 and Masti in 1986. The poet's rights are not the editor's; the reviewer owns that legal opinion (D10), and the builder uses a Wikisource text only if the page states a licence or edition that is free (the Pampabharata page cites a 1931 edition, read; the Sarvajna page cites no edition, read, and is CC BY-SA 4.0 for the transcription).

## Rules applied

- **Rights floor.** Author died 1955 or earlier; an anonymous work first published before 1900. India's term would allow more, the floor rules. Basis `public-domain`, no `quotation` items. The `source` block is as in batch 1 of the Japanese culture deck: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **Text as printed in the cited edition**, in Kannada script, **not modernised**. Old Kannada has the letters ೞ and ಱ (seen in the Pampabharata verses below) and archaic forms; the layer lists each with its modern form. Whether `tools/transcribe.py kn` handles ೞ and ಱ is a check for the builder before any Old Kannada card (it goes to the review queue, never guessed).
- **`reading` and `ipa` from the tool**: `python3 tools/transcribe.py kn "<Kannada>" "<typed Latin hint>"`, never by hand; readings based on ISO 15919; no `phonetic` (KN-110 to KN-112 write it).
- **One excerpt per card**: one verse or line, at most 25 words; **18 items per culture deck**, short items first. The first 18 rows that pass are the deck; the rest are the reserve. Fewer than 18 may pass, and the deck is never padded.
- **Dates are never guessed.** `date` takes a year, `c. YEAR` or `A-B`. Where sources disagree the row says so and the wider range is used with `circa`.
- **Creators** (`decks/creators/kn.yaml`, created by KN-010): short A2-level English bio, `born`, `died`, era, one legacy line with a checkable source link, no image. Candidate eras, each from what was read: Rashtrakuta and Ganga (Old Kannada, c. 850 to 1000: Kavirajamarga, Pampa, Ranna, Ponna), Western Chalukya and Hoysala (c. 1000 to 1300: Durgasimha, Nayasena, Janna, Harihara, Raghavanka, Kesiraja, the Sharana vachanakaras), Vijayanagara (c. 1336 to 1646: Kumara Vyasa, Chamarasa, Purandara Dasa, Kanaka Dasa, Vyasatirtha), Mysore and Nayaka (c. 1600 to 1800: Honnamma, Vijaya Dasa, Gopala Dasa), colonial (1800 to 1947: Kittel, Basavappa Shastri, Gulvadi, Muddana, Kerur, Shishunala Sharifa), twentieth century. The builder confirms the boundaries.
- **Order of work.** KN-010 to KN-013 run one after another (shared `creators/kn.yaml`); KN-060 follows. Proverbs and multi-word decks are independent. **Ids:** culture `kn-6000` to `kn-6199` (50 per deck), proverbs `kn-6200` to `kn-6349`, multi-word `kn-6350` to `kn-6499`, all inside the queue's reserved genre range 6000 to 6999.
- **Notes** are Latin prose; every Kannada word in a note is followed by its reading in parentheses.

## Culture decks (KN-010 to KN-013, 4 x 18 plus reserves)

Years and lifespans are as stated on the page named; "c." is the page's own. Sources: [Pampa](https://en.wikipedia.org/wiki/Pampa_(poet)), [Ranna](https://en.wikipedia.org/wiki/Ranna_(Kannada_poet)), [Kumara Vyasa](https://en.wikipedia.org/wiki/Kumara_Vyasa), [Ratnakaravarni](https://en.wikipedia.org/wiki/Ratnakaravarni), [Kavirajamarga](https://en.wikipedia.org/wiki/Kavirajamarga), [Ponna](https://en.wikipedia.org/wiki/Ponna_(poet)), [Durgasimha](https://en.wikipedia.org/wiki/Durgasimha), [Harihara](https://en.wikipedia.org/wiki/Harihara_(poet)), [Raghavanka](https://en.wikipedia.org/wiki/Raghavanka), [Keshiraja](https://en.wikipedia.org/wiki/Keshiraja), [Chamarasa](https://en.wikipedia.org/wiki/Chamarasa), [Lakshmisha](https://en.wikipedia.org/wiki/Lakshmisha), [Nagavarma II](https://en.wikipedia.org/wiki/Nagavarma_II) (en.wikipedia); [Janna](https://kn.wikipedia.org/wiki/ಜನ್ನ), [Nayasena](https://kn.wikipedia.org/wiki/ನಯಸೇನ) (404 on en.wikipedia, kn.wikipedia read), [Sanchi Honnamma](https://kn.wikipedia.org/wiki/ಸಂಚಿ_ಹೊನ್ನಮ್ಮ) (kn.wikipedia).

### KN-010, `kn-culture-1`: Old and Middle Kannada court poetry (kn-6000 to 6049)

Wikisource texts: [Pampabharata](https://kn.wikisource.org/wiki/ಪಂಪಭಾರತ) (14 ashvasa pages, 1931 edition), [Kumaravyasa Bharata](https://kn.wikisource.org/wiki/ಕುಮಾರವ್ಯಾಸ_ಭಾರತ) (10 parva pages), [Jaimini Bharata](https://kn.wikisource.org/wiki/ಜೈಮಿನಿ_ಭಾರತ) (34 sandhi pages). No kn.wikisource page was found (404) for Ranna, Harihara, Raghavanka, Janna, Kavirajamarga or Kumaravyasa-as-author.

| # | Work (date as read) | Creator (lifespan as read) | ID | Text |
|---|---|---|---|---|
| 1 | Vikramarjuna Vijaya (Pampabharata), ashvasa 1, verses 1 to 3 (c. 939 to 941, the Adi purana; the Vikramarjuna Vijaya "shortly after", no exact year) | Pampa (c. 902 to 955) | V | read: v.1 "ಶ್ರೀಯನರಾತಿ ಸಾಧನ ಪಯೋನಿಧಿಯೊಳ್ ಪಡೆದುಂ ಧರಿತ್ರಿಯಂ", v.2 "ಮುಳಿಸು ಲಲಾಟನೇತ್ರಶಿಖಿ ಮೆಚ್ಚೆ ವಿನೂತ ರಸಪ್ರಸಾದಮು", v.3 "ಚಂಡ ವಿರೋಧಿಸಾಧನ ತಮಸ್ತಮಮೋಡೆ ವಿಶಿಷ್ಟ ಪದ್ಮಿನೀ" (first lines of each four-line verse; one verse per card, a line may need trimming to 25 words) |
| 2 | Pampabharata, another ashvasa (page `ಪಂಪಭಾರತ ದ್ವಿತೀಯಾಶ್ವಾಸಂ` and on) | Pampa | V | page: 14 ashvasa pages listed; text beyond ashvasa 1 not read |
| 3 | Kavirajamarga (850; authorship: Amoghavarsha I or Srivijaya, or both, so no lifespan) | disputed | P | none: no kn.wikisource page found |
| 4 | Sahasa Bhima Vijaya (Gadayuddha) (27 October 982) | Ranna (c. 949 to 1020) | V | none: no kn.wikisource page found |
| 5 | Shantipurana (no date given) | Ponna (c. 945 to "10th or 11th century") | P | none |
| 6 | Panchatantra (c. 1025; Govinda Pai proposes 8 March 1031) | Durgasimha (11th century, no lifespan) | P | none |
| 7 | Dharmamrita (1112) | Nayasena (page garbles the century) | P | none |
| 8 | Yashodhara Charite (no date given; 310 kanda verses) | Janna (period c. 1150 to 1250, no lifespan years) | P | none |
| 9 | Girija Kalyana (before 1245; quoted in a work of that year) | Harihara (13th century on the infobox, 12th in the lead; no years) | P | none |
| 10 | Harishchandra Kavya (c. 1200 or c. 1225) | Raghavanka (late 12th to early 13th century) | P | none |
| 11 | Shabdamanidarpana (1260) | Kesiraja (13th century, died 13th or 14th) | P | none |
| 12 | Prabhulinga Lile (1430) | Chamarasa (c. 1425, no lifespan years) | P | none |
| 13 | Karnata Bharata Katha Manjari, introductory verse (1430) | Kumara Vyasa (1419 to 1446, or 1447) | V | read, 2 lines: "ವೇದ ಪುರುಷನ ಸುತನ ಸುತನ ಸ" / "ಹೋದರನ ಹೆಮ್ಮಗನ ಮಗನ ತ" (edition caveat above) |
| 14 | Karnata Bharata Katha Manjari, a parva excerpt (page `ಸಭಾಪರ್ವ` lists; the `ಆದಿಪರ್ವ` page is an index, verses from sandhi 9 not yet typed) | Kumara Vyasa | V | page |
| 15 | Jaimini Bharata (date uncertain: c. 1415, mid-16th century or late 17th, per en.wikipedia) | Lakshmisha (no lifespan) | P | page: 34 sandhi pages; first verse not read |
| 16 | Bharatesha Vaibhava (c. 1557, Karkala) | Ratnakaravarni (c. 1500 to c. 1560) | V | none |
| 17 | Hadibadeya Dharma (c. 1680, 420 verses) | Sanchi Honnamma (late 17th century) | P | none |
| 18 | Karnataka Bhashabhushana or Kavyavalokana (c. 1042 or c. 1145 to 1150, two dating schools) | Nagavarma II (mid-11th or mid-12th century) | P | none |

Counts: **ID V 6 of 18; text read 2 of 18** (rows 1 and 13); text page located 5 (rows 1, 2, 13, 14, 15). A builder reads Wikisource for rows 3 to 12, 16 to 18 and drops each it cannot read. Reserve: more Pampabharata ashvasas, more Kumaravyasa parvas.

### KN-011, `kn-culture-2`: Sharana vachanas (kn-6050 to 6099)

The Sharana vachanas are 12th-century prose-poems (en.wikipedia "Vachana sahitya": emerged in the 11th century, flourished in the 12th; over 200 vachanakaras, over thirty women). The [kn.wikisource vachana page](https://kn.wikisource.org/wiki/ವಚನ_ಸಾಹಿತ್ಯ) lists 17 linked vachanakaras and 27 unlinked women. Caution from en.wikipedia (Basava): the collections as they exist are probably much later than Basava (one scholar dates them c. 15th century), so each card's `date` is the poet's lifespan and the note says the attribution is traditional.

Page titles are the opening line of the vachana. Pages: [ಬಸವಣ್ಣ](https://kn.wikisource.org/wiki/ಬಸವಣ್ಣ), [ಅಕ್ಕಮಹಾದೇವಿ](https://kn.wikisource.org/wiki/ಅಕ್ಕಮಹಾದೇವಿ) (433 numbered vachana pages, two of them red links).

| # | Item (title = first line, read on the index) | Creator (lifespan as read) | ID | Text |
|---|---|---|---|---|
| 1 to 5 | Akka Mahadevi: "ಅಳಿಸಂಕುಲವೆ ಮಾಮರನೆ" (page opened: category, raga Shanmukhapriya, taala Eka, CC BY-SA 4.0, revision of 24 August 2017), "ಮಾಟ ಮದುವೆಯ ಮನೆ.", "ಸತಿ ಎಂಬುದು ಮಾಟ,", "ಬಯಲು ಲಿಂಗವೆಂಬೆನೆ ?", "ಕಂಡಡೆ ಒಂದು ಸುಖ," | Akka Mahadevi (c. 1130 to 1160, no death year stated) | V | page (the verse text was not shown to the author of this page) |
| 6 to 9 | Basavanna: titles "ಆಸೆ", "ಆಕಳ", "ಎಲವೋ", "ಎಂದೊ" (opening words as listed; the page's list is truncated at 100,000 characters of 182,566) | Basavanna (1131 to 1196) | V | page |
| 10, 11 | Allama Prabhu, two vachanas (titles to be read on the page) | Allama Prabhu (early 12th century, died "12th or 13th", no years) | P | none read |
| 12 | Devara Dasimayya, one vachana | Devara Dasimayya (mid-11th century on one line, 10th-century by category: the page conflicts) | P | none read |
| 13 | Channabasavanna, one vachana | Channabasavanna (12th century) | P | none read |
| 14 | Sonnalige Siddharama, one vachana | no lifespan read (en.wikipedia page missing) | U | none read |
| 15 | Amugeraayamma: "ಎನ್ನ ಕಣ್ಣೊಳಗಿನ ಕಟ್ಟಿಗೆಯ ನಾನೇ ಮುರಿಯಬೇಕು" (first line read) | Amugeraayamma (no dates read) | U | first line read |
| 16 | Akkamma: "ಆವ ಪ್ರಕಾರವಾದಡೇನು, ಅರಿವೆ ಮುಖ್ಯವಯ್ಯಾ" (first line read) | Akkamma (no dates read) | U | first line read |
| 17 | Gangamma: "ಆವ ಕಾಯಕ ಮಾಡಿದರೂ ಒಂದೇ ಕಾಯಕವಯ್ಯಾ" (first line read) | Gangamma (no dates read) | U | first line read |
| 18 | Allama and Muktayakka's dialogue (a section on the index page) | Allama Prabhu and Muktayakka (no lifespans read) | P | page |

Counts: **ID V 9 of 18; full text read 0 of 18** (first lines read for 3 and titles for 12). The Telugu lesson applies: a title list is not a text, so the builder reads each page and drops what has no readable text. Reserve: other vachanas from the 433 Akka pages and the Basavanna list.

### KN-012, `kn-culture-3`: Haridasa songs, Sarvajna tripadis and Sharifa (kn-6100 to 6149)

Pages: [ದಾಸ ಸಾಹಿತ್ಯ](https://kn.wikisource.org/wiki/ದಾಸ_ಸಾಹಿತ್ಯ) (15 poets and sub-pages), [ಪುರಂದರದಾಸರ ಸಾಹಿತ್ಯ](https://kn.wikisource.org/wiki/ಪುರಂದರದಾಸರ_ಸಾಹಿತ್ಯ), [ಕನಕದಾಸರ ಸಾಹಿತ್ಯ](https://kn.wikisource.org/wiki/ಕನಕದಾಸರ_ಸಾಹಿತ್ಯ), [ಶರೀಫ ಸಾಹಿತ್ಯ](https://kn.wikisource.org/wiki/ಶರೀಫ_ಸಾಹಿತ್ಯ) (20 songs), [ಸರ್ವಜ್ಞ](https://kn.wikisource.org/wiki/ಸರ್ವಜ್ಞ) (8 sub-pages), [ಅನ್ನಾಹಾರ-ವೈದ್ಯ](https://kn.wikisource.org/wiki/ಅನ್ನಾಹಾರ-ವೈದ್ಯ). **The fetch tool the author used refused to print song lyrics**, so no song text was read at all; every song row is `page`. Attribution is as the Wikisource list gives it; the builder checks it against the poet's page (for instance en.wikipedia ascribes "Bhagyada Lakshmi Baaramma" to Purandara Dasa, but the Wikisource page order must be read, not assumed).

| # | Item (title as listed) | Creator (lifespan as read) | ID | Text |
|---|---|---|---|---|
| 1 to 4 | Purandara Dasa: "ಅನುಗಾಲವು ಚಿಂತೆ", "ಕಲ್ಲು ಸಕ್ಕರೆ ಕೊಳ್ಳಿರೊ", "ಬಂದದೆಲ್ಲ ಬರಲಿ", "ಭಾಗ್ಯದ ಲಕ್ಷ್ಮೀ ಬಾರಮ್ಮ" | Purandara Dasa (c. 1470 to 2 January 1564; other scholars give 1480, 1484 or 1494) | V | page |
| 5 to 7 | Kanaka Dasa: "ಆರಿಗಾರಿಲ್ಲ ಆಪತ್ಕಾಲದೊಳಗೆ", "ಆರೂ ಸಂಗಡ ಬಾಹೋರಿಲ್ಲ", "ಅಡಿಗೆಯನು ಮಾಡಬೇಕಣ್ಣ" | Kanaka Dasa (1509 to 1606 in the lead; the page's categories say 1609) | V | page |
| 8 to 11 | Shishunala Sharifa: "ಬಿದ್ದಿಯಬ್ಬೇ ಮುದುಕಿ", "ಗಿರಣಿ ವಿಸ್ತಾರ ನೋಡಮ್ಮ", "ಅಳಬೇಡ ತಂಗಿ ಅಳಬೇಡ", "ಸೋರುತಿಹುದು ಮನೆಯ ಮಾಳಿಗಿ" | Shishunala Sharifa (7 March 1819 to 3 July 1889; he never wrote his songs down, so a card's source is the collector's edition, to be named) | V | page |
| 12 | Sarvajna tripadi, from the page `ಅನ್ನಾಹಾರ-ವೈದ್ಯ`: "ಅನ್ನ ದೇವರ ಮುಂದೆ ಇನ್ನು ದೇವರು ಉಂಟೆ? ಅನ್ನವಿರುವನಕ ಪ್ರಾಣವು; ಜಗದೊಳ ಗನ್ನವೇ ದೈವ! ಸರ್ವಜ್ಞ" (transcription CC BY-SA 4.0, no print edition named, last edited 2 August 2013) | Sarvajna (16th century in the lead, early 15th on the infobox, accuracy flagged; no death year) | P | read |
| 13 | A second Sarvajna tripadi (page `ಡಂಭಾಚಾರ-ಪೊಳ್ಳು ಭಕ್ತಿ` or `ಸಜ್ಜನ-ದುರ್ಜನ`) | Sarvajna | P | page |
| 14 | Vijaya Dasa, a song from [ವಿಜಯದಾಸರ ಸಾಹಿತ್ಯ](https://kn.wikisource.org/wiki/ವಿಜಯದಾಸರ_ಸಾಹಿತ್ಯ) (title to read) | Vijaya Dasa (c. 1682 to c. 1755) | V | page |
| 15 | Gopala Dasa, a song from `ಗೋಪಾಲದಾಸರ ಸಾಹಿತ್ಯ` | Gopala Dasa (1722 to 1762, kn.wikipedia) | V | page |
| 16 | Vyasaraya, a song from `ವ್ಯಾಸರಾಯರ ಸಾಹಿತ್ಯ` | Vyasaraya = Vyasatirtha (22 April 1447 to 8 March 1539; the same page also says 1460 and 1469 for birth) | V | page |
| 17 | Sripadaraja, a song from `ಶ್ರೀಪಾದರಾಜರ ಸಾಹಿತ್ಯ` | Sripadaraja (1422 to 1480; the page's navbox says 1404 to 1502) | P | page |
| 18 | Jagannatha Dasa, a song from `ಜಗನ್ನಾಥದಾಸರ ಸಾಹಿತ್ಯ` | Jagannatha Dasa (18th century, no years) | P | page |

Counts: **ID V 14 of 18; text read 1 of 18** (the Sarvajna tripadi, row 12; its creator is P); text page located 17. Reserve: Helavanakatte Giriyamma (c. 1750 on a kn.wikipedia page that itself says it needs sources: not verified), Mahipati Dasa, Raghavendra Tirtha (c. 1595 to c. 1671).

### KN-013, `kn-culture-4`: the colonial and early-modern period, authors who died by 1955 (kn-6150 to 6199)

**Rights check made from the lifespans below: all pass the floor** (the latest death read is Hardekar Manjappa, 1947). **No readable text source was found for any row**: no kn.wikisource author page was found for Muddana (404), and archive.org (the likely home of printed editions) is blocked in this session, so every text is `none` until a builder reads one from a source it can fetch. If none is readable, this deck stays short or is held.

| # | Work (year as read) | Creator (lifespan as read) | ID | Text |
|---|---|---|---|---|
| 1 | Kathamale (1862) | Ferdinand Kittel (7 April 1832 to 18 December 1903) | V | none |
| 2 | Shala Nighantu, English-Kannada school dictionary (1876) | Kittel | V | none |
| 3 | Kannada-English dictionary, about 70,000 words (1894) | Kittel | V | none |
| 4 | Kannada translation of Kalidasa's Shakuntala (1883) | Basavappa Shastri (2 May 1843 to February 1891; kn.wikipedia) | V | none |
| 5 | Adbhuta Ramayanam (first published 1895, magazine Karnataka Kavya Manjari) | Muddana (24 January 1870 to 15 February 1901) | V | none |
| 6 | Sri Rama Pattabhishekam (1896) | Muddana | V | none |
| 7 | Sri Ramashwamedha (1899 to 1901) | Muddana | V | none |
| 8 | Indirabai, or Saddharma Vijaya (1898) | Gulvadi Venkata Rao (1844 to 1907; kn.wikipedia) | V | none |
| 9 | Bhagirathi (1900) | Gulvadi Venkata Rao | V | none |
| 10 | Seemantini (1907) | Gulvadi Venkata Rao | V | none |
| 11 | Indira (novel, 1908) | Kerur Vasudevacharya (1866 to 1921; kn.wikipedia) | V | none |
| 12 | English Geetegalu (1921) | B. M. Srikantaiah (3 January 1884 to 5 January 1946) | V | none |
| 13 | Kural (1940, Bangalore, a translation of the Tirukkural) | B. M. Srikantaiah | V | none |
| 14 | Huthariya Haadu (no year given) | Panje Mangesh Rao (22 February 1874 to 1937) | V | none |
| 15 | Naagara Haave (no year given) | Panje Mangesh Rao | V | none |
| 16 | Gandhi Charithre (no year given) | Hardekar Manjappa (18 February 1886 to 3 January 1947) | V | none |
| 17 | Mudramanjusha (1823 per a garbled sentence; edited and printed 1873 by Rev. J. Stevenson) | Kempu Narayana (no lifespan on kn.wikipedia) | U | none |
| 18 | Kittur Chennamma ballads (folk, lavani and gigi pada; no print date) | anonymous; the heroine lived 14 November 1778 to 21 February 1829 | U | none |

Counts: **ID V 16 of 18; text read 0 of 18.** Rows 1 to 3 are linguistic works: a card may quote a short example sentence only if its text is read. Note for rows 12 and 13: Srikantaiah's work is a translation; its source language text is out of scope.

**Culture total: ID V 45 of 72 rows; full or partial verse text read 3 (rows 1 and 13 of KN-010, row 12 of KN-012).** The remaining 69 rows depend on the builder reading Wikisource, and it is likely that fewer than 18 per deck will pass. The plan's way out, under the queue's own rule, is to build the decks short rather than pad them.

## Proverbs (KN-020 to KN-022, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`; each card has a `literal` note and a meaning. The one source read is [kn.wikiquote "ಗಾದೆಗಳು"](https://kn.wikiquote.org/wiki/ಗಾದೆಗಳು), a list of about 230,000 characters (the author of this page read the three ranges at characters 0 to 100,000, 50,000 to 150,000 and 100,000 to 200,000 of it). It is a volunteer list with **no citation per proverb**, so each is attested only by that page; a second corroboration exists in en.wikiquote ["Kannada proverbs"](https://en.wikiquote.org/wiki/Kannada_proverbs), which cites U. B. Narasinga Rao, "A Handbook of Kannada Proverbs, with English Equivalents" (1912), whose English lines the builder may match to a Kannada proverb to prove the saying is old (that page gives English only, not the Kannada). **Caveats:** the text below came back through a summarising fetch tool, so the builder re-reads each line on the live page and corrects the spelling to the page; a proverb whose line it cannot find on the page is dropped. Five lines on the page were skipped on purpose: a Sanskrit tag "ಲಂಘನಮ್ ಪರಮೌಷಧಮ್", "ಅಶ್ವಿನೀ ಸಸ್ಯನಾಶಿನೀ" (weather lore with no clear meaning), two with crude content ("ಉಚ್ಚೆ ಕುಡಿದರೂ ತನ್ನಿಚ್ಚೇಲಿರಬೇಕು", "ಭಂಗಿ ದೇವರಿಗೆ ಹೆಂಡಗುಡುಕ ಪೂಜರಿ") and one whose meaning is unclear ("ಅಪ್ಪಂತೋನಿಗೆ ಇಪ್ಪತ್ತೊಂದು ಕಾಯಿಲೆ"). Meanings are the builder's own plain renderings; an unclear meaning goes to the review queue. **All 60 below were read on the page: verified.** The Telugu rule holds: no card without the line read on the cited page.

### KN-020, `kn-proverbs-1`: animals, food, family, work, money, weather (kn-6200 to 6249)

| # | Proverb (read on the page) | Theme |
|---|---|---|
| 1 | ಬೊಗಳುವ ನಾಯಿ ಕಚ್ಚುವುದಿಲ್ಲ | animals |
| 2 | ನಾಯಿ ಬಾಲ ಡೊಂಕು | animals |
| 3 | ಇಲಿಯ ವ್ಯಾಜ್ಯಕ್ಕೆ ಬೆಕ್ಕು ಸಾಕ್ಷಿ | animals |
| 4 | ಬೇಲಿನೆ ಎದ್ದು ಹೊಲ ಮೇಯಿತಂತೆ | animals |
| 5 | ಅಂಕೆ ಇಲ್ಲದ ಚತುರೆ, ಲಗಾಮು ಇಲ್ಲದ ಕುದುರೆ | animals |
| 6 | ಅಕ್ಕಿ ಉಂಡವ ಹಕ್ಕಿ, ಜೋಳ ಉಂಡವ ತೋಳ | food |
| 7 | ಉಪ್ಪು ತಿಂದವನು ನೀರು ಕುಡಿಯಲೇ ಬೇಕು | food |
| 8 | ಪಾಲಿಗೆ ಬಂದದ್ದೆ ಪರಮಾನ್ನ. | food |
| 9 | ಕೈ ಕೆಸರಾದ್ರೆ ಬಾಯಿ ಮೊಸರು | food, work |
| 10 | ಅನ್ನ ಹಾಕಿದ ಮನೆಗೆ ಕನ್ನ ಹಾಕಿದಂತೆ | food, family |
| 11 | ಅಪ್ಪ ಗುಡಿ ಕಟ್ಟಿದರೆ ಮಗ ಕಳಸ ಇಟ್ಟ | family |
| 12 | ಅಪ್ಪನ ಮಾತು ಕೇಳದವನು ಅಮ್ಮನ ಮಾತು ಕೇಳಿಯಾನೆ? | family |
| 13 | ಅತ್ತೆಗೊಂದು ಕಾಲ, ಸೊಸೆಗೊಂದು ಕಾಲ. | family |
| 14 | ಅಪ್ಪ ಮಾಡಿದ ಪುಣ್ಯ ಮಕ್ಕಳ ಕಾಲಕ್ಕೆ. | family |
| 15 | ದುಡಿಮೆಯೇ ದೇವರು | work |
| 16 | ಎದ್ದವನು ಗೆದ್ದಾನು | work |
| 17 | ಆಸೆಗೆ ತಕ್ಕ ಪರಿಶ್ರಮ ಬೇಕು. | work |
| 18 | ಹಣ ಅಂದ್ರೆ ಹೆಣವೂ ಬಾಯಿ ಬಿಡ್ತದೆ | money |
| 19 | ಲಕ್ಷ್ಮಿ ಚಂಚಲೆ | money |
| 20 | ಮಳೆ ಹುಯ್ದರೆ ಕೇಡಲ್ಲ | weather |

Reserve: ಆರಿದ್ರೆ ಮಳೆಯಲ್ಲಿ ಆದವನೇ ಒಡೆಯ.; ಆದರೆ ಆರಿದ್ರಾ ಇಲ್ವಾದ್ರೆ ದರಿದ್ರ!; ಅನುರಾಧ ಬಂದರೆ ನಮ್ಮ ರಾಗಿ ನಮ್ಮದು.; ಅಜ್ಜಿ ಸಾಕಿದ ಮಗ ಬೊಜ್ಜಕ್ಕೂ ಬಾರದು.

### KN-021, `kn-proverbs-2`: friends, learning, luck, time, speech, farming (kn-6250 to 6299)

| # | Proverb (read on the page) | Theme |
|---|---|---|
| 1 | ಆಪತ್ತಿಗಾದವನೇ ನಿಜವಾದ ಗೆಳೆಯ. | friends |
| 2 | ಅಲ್ಪರ ಸಂಗ ಅಭಿಮಾನ ಭಂಗ | friends |
| 3 | ಸಜ್ಜನರ ಸಂಗ ಹೆಜ್ಜೇನು ಸವಿದಂತೆ | friends |
| 4 | ಅತಿ ಸ್ನೇಹ ಗತಿ ಕೇಡು | friends |
| 5 | ವಿದ್ಯೆ ಬಲ್ಲವ ಎಲ್ಲಿದ್ದರು ಸಲ್ಲುವ | learning |
| 6 | ದೇಶ ಸುತ್ತು ; ಕೋಶ ಓದು. | learning |
| 7 | ಅರ್ಧ ಕಲಿತವನ ಆಬ್ಬರ ಹೆಚ್ಚು. | learning |
| 8 | ಲೋಕ ತಿಳಿಯಬೇಕು ಲೆಕ್ಕ ಕಲಿಯಬೇಕು | learning |
| 9 | ಯೋಗ ಇದ್ದಷ್ಟೇ ಭೋಗ | luck |
| 10 | ವಿಧಿ ಕಾಣದ ಎಡೆಗಳಿಲ್ಲ | luck |
| 11 | ಗಾಳಿ ಬಂದಾಗ ತೂರಿಕೋ | luck, time |
| 12 | ತಾಳಿದವನು ಬಾಳಿಯಾನು | time |
| 13 | ತಡವ ಮಾಡುವವನ ಗೊಡವೆ ಬೇಡ | time |
| 14 | ಅಪಾಯ ತೀರಿತು, ದೇವರನ್ನು ಮರೆತಾಯಿತು. | time |
| 15 | ಮಾತು ಬೆಳ್ಳಿ, ಮೌನ ಬಂಗಾರ | speech |
| 16 | ನಿಜ ಆಡಿದರೆ ನಿಷ್ಠೂರ | speech |
| 17 | ಅರಿತರೆ ಮಾತನಾಡು, ಮರೆತರೆ ಕೂತು ನೋಡು. | speech |
| 18 | ಬಳ್ಳಿಗೆ ಕಾಯಿ ಭಾರವೇ | farming |
| 19 | ಆಕಳಿಲ್ಲದವ ಬೆಳೆಸು ಮಾಡ್ಯಾನ, ಆಕಳಿದ್ದವ ಮಕ್ಕಳ ಸಾಕ್ಯಾನ. | farming |
| 20 | ಅಕಾಲದಲ್ಲಿ ಬೆಳೆಯಿದ್ದಂತೆ ವೃದ್ಧಾಪ್ಯದಲ್ಲಿ ಮಕ್ಕಳು. | farming |

Reserve: ಅಕ್ಷರ ಕಲಿಯುವುದಕ್ಕೆ ಬೇಧಭಾವ ಬೇಡ.; ಅನುಭವಿಗೆ ಬೇರೆ ಮತವಿಲ್ಲ.

### KN-022, `kn-proverbs-3`: love, age, honesty, effort, appearances, wit (kn-6300 to 6349)

| # | Proverb (read on the page) | Theme |
|---|---|---|
| 1 | ಆತ್ಮೀಯವಾದ ಪ್ರೇಮ ಅಮರವಾದದ್ದು. | love |
| 2 | ಒಲ್ಲದ ಗಂಡನಿಗೆ ಮೊಸರಲ್ಲಿ ಕಲ್ಲು | love |
| 3 | ಅರಗಿನಂತೆ ತಾಯಿ, ಮರದಂತೆ ಮಕ್ಕಳು | age, family |
| 4 | ಅಯ್ಯೋ ಅಂದರೆ ಅರೆ ವಯಸ್ಸು | age |
| 5 | ಸತ್ಯಕ್ಕೆ ಸಾವಿಲ್ಲ; ಸುಳ್ಳಿಗೆ ಸುಖವಿಲ್ಲ | honesty |
| 6 | ಅಳಿವುದೇ ಕಾಯ ಉಳಿವುದೇ ಕೀರ್ತಿ | honesty |
| 7 | ಅಪಕೀರ್ತಿ ತರುವ ಮಗನಿಗಿಂತ, ಸತ್ಕೀರ್ತಿ ತರುವ ಆಳೇ ಮೇಲು. | honesty |
| 8 | ಮಾಡಿದ್ದುಣ್ಣೋ ಮಾರಾಯ | effort |
| 9 | ಮಾಡಿದ ಕರ್ಮ ಬೆನ್ನಾಡಿ ಬಂತು | effort |
| 10 | ಆಸೆ ಆಕಾಶದಷ್ಟು, ಸಾಧನೆ ಸಾಸಿವೆಯಷ್ಟೇ. | effort |
| 11 | ಎರಡೂ ಕೈ ತಟ್ಟಿದರೆ ಸದ್ದು | effort |
| 12 | ತುಂಬಿದ ಕೊಡ ತುಳುಕುವುದಿಲ್ಲ | appearances |
| 13 | ಆಳವಿಲ್ಲದ ನೀರು ಭಾರಿ ಶಬ್ದ ಮಾಡೀತು. | appearances |
| 14 | ದೀಪದ ಕೆಳಗೆ ಯಾವತ್ತೂ ಕತ್ತಲೇ | appearances |
| 15 | ಕಬ್ಬು ಡೊಂಕಾದ್ರೆ ಸವಿ ಡೊಂಕೇ | appearances |
| 16 | ಹುಟ್ಟು ಗುಣ ಸುಟ್ಟರೂ ಹೊಗೊದಿಲ್ಲ | appearances |
| 17 | ರವಿ ಕಾಣದ್ದನ್ನು ಕವಿ ಕಂಡ | wit |
| 18 | ಗುರುವಿಗೇ ತಿರುಮಂತ್ರ | wit |
| 19 | ಜಟ್ಟಿ ಜಾರಿದರೆ ಅದೂ ಒಂದು ಪಟ್ಟು | wit |
| 20 | ಅತಿಯಾದರೆ ಅಮೃತವೂ ವಿಷ | wit |

Reserve: ಅರೆಗೊಡದ ಅಬ್ಬರವೇ ಬಹಳ.; ಕುರುಡು ಕಣ್ಣಿಗಿಂತ ಮೆಳ್ಳೆ ಗಣ್ಣು ವಾಸಿ; ಅರಮನೆಯ ಮುಂದಿರಬೇಡ, ಕುದರೆಯ ಹಿಂದಿರಬೇಡ; ಅತಿ ಆಸೆ ಗತಿಗೇಡು. KN-021 and KN-022 use no proverb of an earlier deck (checked above: 60 distinct lines).

## Multi-word verbs (KN-030 to KN-032, 3 x 20 targeted)

Genre `multiword`, a `pattern_family`, a `usage` note on every card; the citation form is the Kannada verb root with its infinitive in -ಲು as the dictionary gives (for example ಮಾಡು, ಮಾಡಲು); parts already taught are written by `ref`. **This is the weakest section.** The grammar sources that fetched are thin: en.wiktionary entries give the verb senses and conjugation tables, with almost no phrase lists, and en.wikipedia "Kannada grammar" has only the ಇರು aspect compounds. Two sources that would carry the examples could not be fetched: the Heidelberg-hosted *A Manual of Modern Kannada* (`hasp.ub.uni-heidelberg.de`, host not allowed in this session) and sublearn.com, open-exam-prep.com, polyglotclub.com (not allowed). A web search summarised them, so rows from them are second-hand and marked `second-hand`.

| Task | Deck and `pattern_family` | Rows read directly (verified) | Rows to check (unverified) | Ids |
|---|---|---|---|---|
| KN-030 | `kn-multiword-conjunct-verbs`, `conjunct-verb` | **1:** ಅಡುಗೆ ಮಾಡು (to cook; en.wiktionary ಕೊಳ್ಳು example "ಅವನು ತಾನೇ ಅಡುಗೆ ಮಾಡಿಕೊಂಡನು." "He cooked for himself.") | noun plus ಮಾಡು, ಆಗು, ಪಡು or ಕೊಡು: ಸಹಾಯ ಮಾಡು (en.wiktionary ಸಹಾಯ gives only the noun, ನೆರವು a synonym: the phrase is not attested there), ಕೆಲಸ ಮಾಡು, ಸ್ನಾನ ಮಾಡು, ಪ್ರಯಾಣ ಮಾಡು, ಫೋನ್ ಮಾಡು, ಕಷ್ಟಪಡು, ಸಂತೋಷ ಆಗು, ಹೆದರಿಕೆ ಆಗು. Also the -isu verbaliser (en.wikipedia: "nouns and Sanskrit words generally are verbalized": ಪಾಠ plus -ಇಸು gives ಪಾಠಿಸು, **verified**). Selection by procedure as Telugu TE-042 (scan the cores `kn-grammar-conjunct-verbs`, work, school, health, nouns in id order; take each whose entry a cited dictionary page lists), the dictionary page to be named | kn-6350 to 6399 |
| KN-031 | `kn-multiword-compound-verbs`, `aspectual-compound` | **5:** ಹೋಗು as a completive auxiliary ("Used with the past verbal participle of verbs to give a completive aspect", en.wiktionary ಹೋಗು, no example given); ಕೊಳ್ಳು as a reflexive auxiliary (ಮಾಡಿಕೊಂಡನು, example above); ಕೊಡು as a benefactive (ಮಾಡಿಕೊಟ್ಟನು, "made (something) for someone", en.wiktionary ಮಾಡು, not labelled a compound there); the converb sequence "ಮನೆಗೆ ಸುತ್ತಿ ಕೊಂಡು ಬಂದನು." "He circled around and came home." (en.wikipedia Kannada grammar); the periphrastic passive with ಪಡೆ (transliteration only, "suḍal paṭṭanu", "he burned himself"). **Aspect with ಇರು (en.wikipedia, script and gloss read):** ಹೋಗುತ್ತಿದ್ದೇವೆ, ಬರುತ್ತಿದ್ದರು, ಬರೆದಿದ್ದಾಳೆ, ತರಿಸಿದ್ದರು, ಮಾಡುತ್ತಿರುವೆ, ಮಾಡಿರುತ್ತದೆ (these are verb forms, not lexical compounds: they belong in a rules deck, and are listed only so a builder knows they exist) | the light verbs ಬಿಡು, ಕೊಡು, ಕೊಳ್ಳು, ಹೋಗು are named as a set of twelve in a summary of Bhat's Kannada grammar (`second-hand`); ಬಿಡು (en.wiktionary gives only "leave, let go; quit", no auxiliary), ಹಾಕು, ಇಡು, ಬೀಳು (17 senses, no auxiliary notes), ತೆಗೆ, ಬರು (en.wiktionary: one sense, no auxiliary), ಕಾಣು: each paired with two or three verbs taught by `kn-verbs`, to be found on a cited page | kn-6400 to 6449 |
| KN-032 | `kn-multiword-dative-subject` and `kn-multiword-idiomatic` (10 and 10, or one deck of 20 if the builder prefers; two `pattern_family` values) | **0 read directly.** `second-hand` (from the *Manual of Modern Kannada*, via a search summary): ನನಗೆ ಆ ಪುಸ್ತಕ ಬೇಕು ("I want that book"), ನನಗೆ ನೀರು ಬೇಕು ("I need water"), ನನಗೆ ಬೇಡ (negative). en.wiktionary ಬೇಕು: a noun, "indispensability; necessity" (the dative forms in its table only) | the dative-subject set to check first: ನನಗೆ ಇಷ್ಟ, ನನಗೆ ಗೊತ್ತು, ನನಗೆ ಹಸಿವು ಆಗಿದೆ, ನನಗೆ ಬಾಯಾರಿಕೆ ಆಗಿದೆ, ನನಗೆ ಕೋಪ ಬಂತು, ನನಗೆ ನಿದ್ದೆ ಬರುತ್ತಿದೆ, ನನಗೆ ಜ್ವರ ಬಂದಿದೆ, ನನಗೆ ಅರ್ಥವಾಯಿತು, ನನಗೆ ನೆನಪಿದೆ: **all unverified**. en.wiktionary ಇಷ್ಟ and ಗೊತ್ತು returned 404 or nothing usable. Idioms: ಮೂಗು ತೂರಿಸು ("to insert the nose", "to interfere", from an exam-prep page, `second-hand`) is the only idiom named; the rest are to be found on a cited Kannada page, and the queue should hold the idiomatic half until a source is found | kn-6450 to 6499 |

Count of rows directly read: **7 verbs or forms** (ಅಡುಗೆ ಮಾಡು, ಹೋಗು, ಕೊಳ್ಳು, ಕೊಡು, the converb sequence, the ಪಡೆ passive, the -ಇಸು verbaliser) plus six ಇರು aspect forms. Dative-subject: 0 verified, 3 second-hand. Idiomatic: 0 verified, 1 second-hand. Fewer than 20 may be attested: report the count, do not fill. The Telugu lesson (issue #1357, #1361) on word-final forms applies when the citation form is written.

## Recommendations (KN-060, 20)

File `decks/recommendations/kn.yaml`, in the shape of `recommendations/ja.yaml`: `id: "kn-rec-<name>"`, `medium`, `title { text, reading }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each, tags; no quotation, no link. Rights are not a gate for a source-it-yourself work; year and creator were read on the page named. Creators are added to `creators/kn.yaml` where missing. Source for every row is the title's en.wikipedia page (read 2026-11-15) unless noted.

| # | Title | Creator | Year (as read) | Medium | Rights note | Status |
|---|---|---|---|---|---|---|
| 1 | Bedara Kannappa | H. L. N. Simha, lead Rajkumar | 1954 (released 7 May 1954) | film | in copyright (source yourself) | verified |
| 2 | Kittur Chennamma | B. R. Panthulu, lead B. Saroja Devi | 1961 (released 24 February 1961) | film | source yourself | verified |
| 3 | Sandhya Raga | A. C. Narasimha Murthy (S. K. Bhagavan says he directed it but was not credited) | 1966 | film | source yourself | verified |
| 4 | Samskara | Pattabhirama Reddy; novel by U. R. Ananthamurthy, written 1965 | 1970 | film | source yourself | verified |
| 5 | Vamsha Vriksha | B. V. Karanth and Girish Karnad; novel by S. L. Bhyrappa (novel year not on the page) | 1971 | film | source yourself | verified (film year, directors); novel year unverified |
| 6 | Kasturi Nivasa | Dorai-Bhagavan, lead Rajkumar | 1971 | film | source yourself | verified |
| 7 | Bangarada Manushya | S. Siddalingaiah, lead Rajkumar | 1972 | film | source yourself | verified |
| 8 | Mayura | Vijay, lead Rajkumar | 1975 | film | source yourself | verified |
| 9 | Chomana Dudi | B. V. Karanth; novel by K. Shivaram Karanth (novel year not on the page) | 1975 | film | source yourself | verified (film year, director); novel year unverified |
| 10 | Ghatashraddha | Girish Kasaravalli; novella by U. R. Ananthamurthy | 1977 | film | source yourself | verified |
| 11 | Ondanondu Kaladalli | Girish Karnad | 1978 | film | source yourself | verified |
| 12 | Kanooru Heggadithi | Girish Karnad; novel by Kuvempu (1936) | 1999 | film | source yourself | verified |
| 13 | Nagamandala | Girish Karnad | 1988 | play | source yourself | verified |
| 14 | Marali Mannige | K. Shivaram Karanth (10 October 1902 to 9 December 1997) | 1941 (en.wikipedia; other lists say 1942, so the builder confirms) | book | source yourself | verified, year to confirm |
| 15 | Mookajjiya Kanasugalu | K. Shivaram Karanth | 1968 | book | source yourself | verified |
| 16 | Mysooru Mallige | K. S. Narasimhaswamy ("Mallige Kavi") | 1942 | poetry collection | source yourself | verified |
| 17 | Jaya Bharata Jananiya Tanujate | Kuvempu (Kuppalli Venkatappa Puttappa, 1904 to 1994) | 1924 (publication; state anthem 10 January 2004, a truncated version) | poem, song | source yourself | verified |
| 18 | Karnata Bharata Katha Manjari | Kumara Vyasa (1419 to 1446) | 1430 | book (verse epic) | **public domain by age**; text on kn.wikisource, edition caveat above | verified |
| 19 | Malegalalli Madumagalu | Kuvempu | not read (the en.wikipedia page redirected to Kuvempu's page, which names it a notable novel) | book | source yourself | unverified (year) |
| 20 | Sri Ramayana Darshanam | Kuvempu | not read (named on his page as an epic) | book (epic poem) | source yourself | unverified (year) |

Counts: **18 of 20 verified** (title, creator and year read on a cited page; rows 5, 9 and 14 each carry one caveat, written in the status), **2 unverified** (rows 19 and 20 lack a year). Reserve: Sarvajna's tripadis (public domain by age, text on kn.wikisource, creator dates disputed), Pampabharata (public domain, 1931 edition on kn.wikisource), R. K. Narayan's Malgudi Days (the TV series year and director were not on the page read: unverified; a Kannada-language series, to be checked). No television programme, podcast or radio programme was verified for Kannada; the builder adds one only after reading its page. Film years above are release years, not the year of the source novel.

## Blocked and weak sources

- **Blocked in this session** (host did not resolve): `hasp.ub.uni-heidelberg.de` (the *Manual of Modern Kannada*, best source for dative-subject and compound verbs), `archive.org` (printed Kannada editions), `sublearn.com`, `open-exam-prep.com`, `polyglotclub.com`. A builder in a session with those hosts allowed can unblock KN-013 and KN-031 to KN-032.
- **Fetch tool limits.** It summarises, so a verbatim verse or proverb needs a second read by the builder, and it **refuses to print song lyrics**: every song row is `page` only. Its answers about Wikipedia dates are used as read.
- **Missing pages (404):** en.wikipedia for Janna, Kerur Vasudevacharya, Gulvadi Venkata Rao, Basavappa Shastri, Sanchi Honnamma, Nayasena, Mudramanjusha, Siddharama, Helavanakatte Giriyamma, Muktayakka and Kempu Narayana; kn.wikisource author pages for Ranna, Harihara, Raghavanka, Janna, Kavirajamarga, Kumara Vyasa, Muddana and Shishunala Sharifa (the Sharifa songs are on `ಶರೀಫ ಸಾಹಿತ್ಯ` instead). kn.wikipedia was read for the poets without an en.wikipedia page.
- **Dates that conflict, and so are circa:** Sripadaraja (1422 to 1480 against 1404 to 1502), Kanaka Dasa (death 1606 against 1609), Vyasatirtha (birth 1447, 1460 or 1469), Purandara Dasa (birth c. 1470, 1480, 1484 or 1494), Devara Dasimayya (10th against mid-11th century), Sarvajna (early 15th against 16th century, accuracy flagged), Harihara (12th against 13th century), Nagavarma II (mid-11th against mid-12th century), Durgasimha (c. 1025 against 1031).

## Review-queue rule

Everything is `unreviewed`. Each unread, uncertain or dropped item, every conflicting date above, and every Wikisource edition-copyright doubt is a row in the builder's report, in the table shape of `docs/review-queue/kn.md`; KN-120 collects the rows into that file, one batch at a time.

## Overlaps to settle, and open questions

- **Names that appear twice.** Vyasaraya (Wikisource) and Vyasatirtha (en.wikipedia) are one poet; Pampa appears as culture row 1 and 2 of KN-010 and must not repeat as a recommendation (the recommendation list uses Kumara Vyasa and modern works); Karnata Bharata Katha Manjari is a culture candidate (KN-010 rows 13 and 14) and recommendation 18: the builders take it once, in the culture deck, and KN-060 uses its reserve.
- **Professional decks** are held for the owner's profession list.
- **Editor copyright of Wikisource editions** (Kumaravyasa, possibly vachana and dasa collections): decided by the reviewer; the builder drops a text whose edition it cannot show to be free.
- **Question for the owner** (no sensible default): KN-013 has no readable text source in this session. Either allow `archive.org` for the builders, or accept a short KN-013 or none.
