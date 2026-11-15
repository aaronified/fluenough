# Plan: Marathi genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task MR-001 of [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), written 2026-11-15 in the shape of [Plan-Culture-Telugu](Plan-Culture-Telugu.md) and [Plan-Culture-French](Plan-Culture-French.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, for the tasks MR-010 to MR-013 (culture), MR-020 to MR-022 (proverbs), MR-030 to MR-033 (multi-word verbs) and MR-060 and MR-061 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) (D1, D4, D5, D13).

Marathi runs in its own session by the owner's instruction of 2026-11-15, which overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md) for Marathi. Every deck ships `unreviewed` (owner, 2026-11-13); doubts go to `docs/review-queue/mr.md` through the builder's report and tasks MR-120 to MR-122.

## How this page was checked

On 2026-11-15 the author read the named pages below (mr.wikipedia, en.wikipedia, mr.wikisource, mr.wikiquote, en.wiktionary) and, for the proverbs, the raw wikitext of mr.wikiquote "म्हणी". **A fact is on this page only if a named page said it.** Nothing was filled in from memory. Each row says what was read:

- **verified** means the named page was read and states the fact in the row (a date, a lifespan, a work, a text that exists on the page).
- **unverified, review queue** means the page was read or searched and did not settle the fact, or no page could be reached. The builder reads it before using the item and drops it if it cannot; it is never filled in.
- A year written "c." or with two values is exactly as unsettled as the page says; the builder writes it as `circa` and puts the doubt in a note.

mr.wiktionary answered HTTP 429 during the run, so the multi-word list rests on fewer pages than planned (see that section). A builder reads with `curl` and a User-Agent, one request every 15 to 20 seconds, never in parallel with another worker, as in the French plan.

## Rules applied

- **Rights floor.** The author's death year must be 1955 or earlier (the validator's floor; India's term is life plus 60 years, so the floor is stricter). An anonymous work needs a first publication before 1900, read from a cited page. The reviewer owns the legal opinion. Several Wikisource pages carry notices ("most of this content may be copyrighted", "pages without a source"); such a notice is not a rights proof, so the row says what else the builder must read.
- **Basis `public-domain` only for culture, no `quotation` items.** `source` block: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction` (`"IN"`), `rights_checked`.
- **Text as printed on the cited page**, in Devanagari, not modernised. One excerpt per card: one line or one couplet, **at most 25 words**. 18 items per deck, short items first, level A2 or B1. The first 18 candidates that pass are the deck; the rest are the reserve. **Fewer than 18 may pass: the deck is never padded** (this page expects it for culture 2 and culture 4).
- **`reading` and `ipa`** come from `python3 tools/transcribe.py mr "<text>" <hint>`, never by hand. No `phonetic` (MR-110, MR-111). Readings are based on ISO 15919.
- **Translations** are the builder's own plain renderings. Wikiquote's explanations are contributors' words and are not copied.
- **Creators** (`decks/creators/mr.yaml`, created by MR-010, then MR-011 to MR-013 and the recommendations, in order): `born` and `died` a plain year or `{ year, circa: true }`, `source.author` equals the creator's exact `name.en.text`, `legacy` 1 to 6 items with sources. The trap list is in [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), section 2.
- **Ids** from the queue: culture `mr-4000..4199` (50 per deck), proverbs `mr-4200..4349`, multi-word `mr-4350..4549`.

### Authors the floor removes (read on mr.wikisource, "विकिस्रोत:समस्त लेखक (कॉपीराईट फ्री)")

That page lists these authors with these years, so they **fail** the floor: बाबासाहेब आंबेडकर 1891 to 1956, बाळ सीताराम मर्ढेकर 1909 to 1956, काशिनाथ रावजी पालवणकर 1897 to 1956. Annabhau Sathe (1920 to 1969, en.wikipedia "Lavani") fails too. Kusumagraj's poem "कणा" is in Wikisource's poetry category, but its page gives no death year, so it is **dropped, not proven**.

## Culture 1: sant poets (MR-010, mr-4000 to 4049)

Creator facts were read on en.wikipedia (page named) and, where noted, on the mr.wikisource author page. "Text page" says whether mr.wikisource has a page the builder can take one line from.

| # | Creator | Work | Date as read | Basis | Page that verifies | Text page | Status |
|---|---|---|---|---|---|---|---|
| 1 | Dnyaneshwar | Dnyaneshwari (Bhavarthadeepika), 18 chapters | 1275 to 1296; work about 1290 (mr.wikipedia ज्ञानेश्वर; it notes some sources give 1271 for birth) | PD, died 1296 | mr.wikipedia ज्ञानेश्वर; mr.wikisource ज्ञानेश्वरी | yes, 18 chapter subpages; the page says Shaka 1212 (1290) and CC BY-SA 4.0 | verified; chapter text not read, builder picks a line |
| 2 | Dnyaneshwar | Changdev Pasashti | as row 1 | PD | mr.wikisource साहित्यिक:ज्ञानेश्वर | yes (link exists) | verified existence; text unread |
| 3 | Dnyaneshwar | Haripath (28 abhangs); Amrutanubhav | as row 1 | PD | mr.wikipedia ज्ञानेश्वर | **no** (red links on the author page) | text unverified, reserve |
| 4 | Tukaram | Tukaram Gatha (abhangs), 15 subpages of about 300 gathas each | born 1598 or 1608, died 1649 or 1650 (en.wikipedia "Tukaram"); Gatha composed about 1632 to 1650; first modern print 1869 (Indu Prakash) | PD | en.wikipedia Tukaram; mr.wikisource तुकाराम गाथा | yes; the page names **no edition or year** | verified creator; builder cites the edition it reads; `circa` dates |
| 5 | Eknath | Rukmini Swayamvar | c. 1533 to 25 Feb 1600 (en.wikipedia "Eknath"; the Wikisource list says 1533 to 1599) | PD | en.wikipedia Eknath; mr.wikisource साहित्यिक:एकनाथ | yes (link exists) | verified existence; work date not on either page |
| 6 | Eknath | Bhavartha Ramayan | as row 5 | PD | same | yes (link exists) | as row 5 |
| 7 | Eknath | Eknathi Bhagwat; Bharud (about 300) | as row 5 | PD | en.wikipedia Eknath | **no** (red links) | text unverified, reserve |
| 8 | Samarth Ramdas | Manache Shlok, 205 verses | c. 1608 to 1682 (en.wikipedia; its categories say 1681, so `circa`) | PD | en.wikipedia Samarth Ramdas; mr.wikisource मनाचे श्लोक | yes; verse 1 read, first line "गणाधीश जो ईश सर्वां गुणांचा" (5 words); no print edition named | **verified** |
| 9 | Samarth Ramdas | Karunashtake | as row 8 | PD | mr.wikisource साहित्यिक:समर्थ रामदास स्वामी | yes (link exists) | verified existence |
| 10 | Samarth Ramdas | Uttam Gun | as row 8 | PD | same | yes (also in वर्ग:श्लोक) | verified existence |
| 11 | Samarth Ramdas | Savai | as row 8 | PD | same | yes | verified existence |
| 12 | Samarth Ramdas | Atmaram | as row 8 | PD | same | yes | verified existence |
| 13 | Samarth Ramdas | Shivrajas Athavave; Nishchayacha Mahameru | as row 8 | PD | same | yes (both) | verified existence |
| 14 | Muktabai | Tatiche Abhang | 1279 to 1297 (en.wikipedia "Muktabai"; another source gives 1277 for birth); 41 abhangs | PD | en.wikipedia Muktabai | not found on mr.wikisource | creator verified; text unverified, review queue |
| 15 | Janabai | abhangs, about 300 attributed | died 1350; birth uncertain (the page gives both "1258" and "7th or 8th decade of the 13th century") | PD | en.wikipedia Janabai | not found | creator verified (`circa`); text unverified |
| 16 | Namdev | abhangs; aartis such as "Yuge Atthavis" (attribution doubtful) | traditional c. 1270 to c. 1350; other scholars 1207 to 1287 or 1309 to 1372 | PD | en.wikipedia Namdev | not found | creator verified as uncertain; text unverified |
| 17 | Bahinabai (the saint) | Atmanivedan, abhangs, Pundalika-Mahatmya | 1628 to 1700 | PD | en.wikipedia Bahinabai | not found | creator verified; text unverified. Not the poet Bahinabai Chaudhari (culture 2) |
| 18 | Gora Kumbhar | abhangs | about 1267 to about 1317 | PD | en.wikipedia Gora Kumbhar | not found | creator verified; text unverified |
| R1 | Narahari Sonar | abhangs | died 1313 (Ranade, per en.wikipedia); birth not given | PD | en.wikipedia Narahari Sonar | not found | reserve |
| R2 | Kanhopatra | ovi and abhanga, about thirty survive | 15th century; estimates 1428 to 1480 | PD | en.wikipedia Kanhopatra | not found | reserve, `circa` |
| R3 | Chokhamela | abhangs, e.g. "Abir Gulal Udhlit Rang" | 13th to 14th century; no years on the page | PD | en.wikipedia Chokhamela | not found | reserve; dates unverified |
| R4 | Sena Nhavi | abhangs | no birth or death year on the page | PD | en.wikipedia Sena Nhavi | not found | dropped unless a year is read |
| R5 | Nivruttinath | none of his own on the page | 1273 to 1297 | PD | en.wikipedia Nivruttinath | n/a | creator only (legacy line in Dnyaneshwar's entry) |

Not found at all (HTTP 404 on en.wikipedia): Sant Sawta Mali and Sopandev under those titles. They are not listed.

**Count, culture 1:** a text page was verified to exist for 11 rows (12 works: rows 1, 2, 4, 5, 6, 8, 9, 10, 11, 12 and 13 with two works). Five creators are verified without a text page (rows 14 to 18) and four more are reserve (R1 to R4); R5 is a creator only. The deck can reach 18 from the 12 text pages by taking several lines per work (one card each) if the builder reads them; if it cannot, the deck is short.

## Culture 2: powada, lavani, ovi and folk (MR-011, mr-4050 to 4099)

The plan expects **fewer than 18 distinct works** here: the only folk texts the author could confirm on a Wikisource page are rows 1 to 3 and 5. Everything else is a named-poet fact with no text found.

| # | Creator | Work | Date as read | Basis | Page that verifies | Status |
|---|---|---|---|---|---|---|
| 1 | Sane Guruji (compiler) | Stri-Jeevan, women's ovi songs in 4 sections: बहिणभाऊ, मायलेकरें, मुलगी, सुखदुःखाचे अनुभव | printed 25 Feb 1940, Prakash Mandal, Pune; Sane 24 Dec 1899 to 11 Jun 1950 (en.wikipedia "Sane Guruji") | PD by the compiler's death (1950); the songs are oral and anonymous; the card names Sane as `author` and says "collected by" | mr.wikisource स्त्री-जीवन (transcription of the 1940 print, scan on Commons) | **verified**; about 1,500 songs in volume 1, so 18 cards are available |
| 2 | Jyotirao Phule | Powada on Shivaji (छत्रपति शिवाजी राजे भोसले यांचा पवाडा) | June 1869; Phule 11 Apr 1827 to 28 Nov 1890 (en.wikipedia "Jyotirao Phule", which lists the 1869 powada) | PD, died 1890 | mr.wikisource page (attribution only by its category जोतिराव फुले; no edition cited); en.wikipedia | verified date and lifespan; **Wikisource attribution is category-only**; the page is about 3,900 words, so one line only |
| 3 | Bahinabai Chaudhari | ovi-metre poems: "सुगरणीचा खोपा" (first line "अरे खोप्यामधी खोपा"), "अरे संसार संसार", "आला पह्यला पाऊस" and two more | 1880 to 3 Dec 1951 (mr.wikisource author page); poems first published 1952 as Bahinabainchi Gani (en.wikipedia "Bahinabai Chaudhari") | PD, died 1951 | mr.wikisource साहित्यिक:बहिणाबाई चौधरी (5 poem pages exist, 41 red); en.wikipedia | **verified** (two poem pages read; no source book named on them) |
| 4 | Eknath | Rukmini Swayamvar (ovi, 764 verses per en.wikipedia) | see culture 1 | PD | mr.wikisource; en.wikipedia | verified existence; used once, in the earlier task |
| 5 | Samarth Ramdas | Savai (a page that explains the ovi form) | see culture 1 | PD | mr.wikisource सवाई | verified existence |
| 6 | named shahirs | Ram Joshi (1762 to 1812), Anant Phandi (1744 to 1819), Honaji Bala (1754 to 1844), Prabhakar (1769 to 1843) | years as en.wikipedia "Powada" gives them; "Lavani" repeats them but also lists "Parasharam (1754 to 1844)", the same years as Honaji Bala, which looks like an error | PD if the dates hold | en.wikipedia Powada and Lavani; mr.wikisource साहित्यिक:होनाजी बाळा gives **no years and no works** | **unverified, review queue**; no text found |
| 7 | Eknath | Bharud, about 300 | see culture 1 | PD | en.wikipedia Eknath | text unverified, reserve |
| 8 | anonymous | Bhupali (morning songs), 14 pages on mr.wikisource (e.g. गंगेची भूपाळी, पंढरीची भूपाळी) | **no author, no date, no source** on the two pages read; they carry a copyright-review notice | none provable | mr.wikisource वर्ग:भूपाळी | **unverified, dropped** (an anonymous work needs a first publication before 1900 read from a page) |
| 9 | anonymous | Gondhal songs | the en.wikipedia "Gondhal" page is about a 2025 film and says nothing of the songs | none | en.wikipedia Gondhal | unverified, dropped |

The en.wikipedia "Ovi (poetry)" page verifies the form only: ovi is a Marathi metre, women's grinding-stone songs were passed on orally, and Dnyaneshwar first used it in literature. The "Powada" page says the form is a traditional Marathi ballad about heroes such as Shivaji; it names Agnidas's "Killing of Afzal Khan" as the earliest notable powada without a date, so it is not a row.

**Count, culture 2:** 4 works verified to a usable text page (rows 1, 2, 3, 5; row 4 is used once in the earlier task), 3 rows unverified (6, 7, 8), 1 dropped (9).

## Culture 3: modern prose, verse and theatre by authors who died in 1955 or earlier (MR-012, mr-4100 to 4149)

Lifespans from the mr.wikisource list "समस्त लेखक (कॉपीराईट फ्री)" and each author's page; a conflict between pages is stated.

| # | Creator | Work (pages that exist) | Date as read | Page that verifies | Status |
|---|---|---|---|---|---|
| 1 to 7 | Keshavsut (Krishnaji Keshav Damle) | "तुतारी" (first line "एक तुतारी द्या मज आणुनि", 6 words), "आम्ही कोण?", "नवा शिपाई", "सतारीचे बोल", "स्फूर्ती", "तुझे नाम मुखी", "रांगोळी घालतांना पाहून" | 7 Oct 1866 to 7 Nov 1905 (en.wikipedia "Keshavsut"; mr.wikisource 1866 to 1905); Tutari 1893, Nava Shipai 1898, Gofan Keli Chan 1905 (en.wikipedia) | mr.wikisource साहित्यिक:कृष्णाजी केशव दामले (these 7 links exist; झपुर्झा, हरपले श्रेय, मूर्तिभंजन, गोफण are red); the तुतारी page read | **verified** (7 text pages); the poem pages name no source, so each card's date is the poem or collection date the builder reads |
| 8 to 16 | Balkavi (Trimbak Bapuji Thombare) | "औदुंबर", "श्रावणमासी हर्ष मानसी", "आनंदी आनंद गडे", "निर्झरास", "फुलराणी", "दोष आणि प्रीति", "तूं तर चाफेकळी!", "प्रीति हवी तर", "शून्य मनाचा घुमट" (9 pages exist, 48 red; "मधुयामिनी" also exists) | 1890 to 1918 on the author list; **the author's own page gives "?" for both**, a conflict | mr.wikisource list and author page; three poem pages read (श्रावणमासी and औदुंबर first lines 6 words each; आनंदी आनंद गडे carries a "public domain is disputed" notice) | text verified; **lifespan conflicting, notices and "no source" tags**: conditional, review queue until a page gives the death year |
| 17 | Bhaskar Ramchandra Tambe | "जन पळभर म्हणतील, हाय हाय" | 27 Oct 1873 (author page) or 1874 (list) to 1941; collection not stated | mr.wikisource poem and author pages | text verified; the birth years conflict, the death year 1941 does not, so the floor passes |
| 18 | Sane Guruji | Shyamchi Aai (link exists; the page shows only a title, no author, edition or chapters) | 1899 to 1950; the novel's year is not on the pages read | mr.wikisource साहित्यिक:पांडुरंग सदाशिव साने; en.wikipedia "Sane Guruji" (no publication year) | **unverified, review queue** for date and text |
| R1 to R5 | Krishnaji Prabhakar Khadilkar | five songs of Manapaman (1911): "खरा तो प्रेमा ना धरी लोभ मनी", "रवि मी", "मला मदन भासे हा", "युवतिमना दारुण रण", "शूरा मी वंदिले" | 25 Nov 1872 to 26 Aug 1948; Keechakvadh 1906, Bhaubandki 1909, Manapaman 1911 (author page) | author page; the five song pages exist | reserve; text unread |
| R6 | Govind Ballal Deval | Mrichchhakatik (adaptation, 1887) | 1855 to 1916; Sangeet Sharada 1899 (author page) | mr.wikisource author page | reserve; the Sharada page is a red link |
| R7 | Ram Ganesh Gadkari | Vedyacha Bazar | 1885 to 1919 (author page) | the author page links a page, but the page itself returned **404** | unverified, dropped |

Authors that pass the floor but have **no text page found** (creators only, for a legacy line or a later batch): Hari Narayan Apte 1864 to 1919 (about 35 works listed, every work page red), Vishnushastri Chiplunkar 1850 to 1882 (no works listed), Balwant Pandurang Kirloskar 1843 to 1885 (no works listed), Tarabai Shinde 1850 to 1910 (Stri Purush Tulana, 1882, en.wikipedia; no Wikisource work page), Savitribai Phule 3 Jan 1831 to 10 Mar 1897 (Kavya Phule 1854, en.wikipedia; no Wikisource page read), Bal Gangadhar Tilak 1856 to 1920 (Gitarahasya has a page; his other entries are red or PDFs).

**Count, culture 3:** 8 poem pages verified for authors with a settled death year (Keshavsut 7, Tambe 1); 9 Balkavi pages conditional on his death year; 1 unverified (Sane); reserve 5 Khadilkar songs. So **8 verified plus 9 conditional** reach 17, and 18 only with one reserve song.

## Culture 4: anonymous and traditional works first published before 1900 (MR-013, mr-4150 to 4199)

This theme reached **one verified item**. Wikisource's devotional pages have no author, date or source, and the bakhar article gives no first-print dates. A short deck is expected, or the owner may fold the theme into culture 2 (see the open questions).

| # | Candidate | Date as read | Rights basis | Page that verifies | Status |
|---|---|---|---|---|---|
| 1 | श्रीमंत नारायणराव पेशवे यांची बखर, with the Karbhari-party accounts | printed 1887 (Shaka 1809), Pune, series No. 21, edited by Kashinath Narayan Sane; **original author unknown** per the editor's footnote | anonymous, first published 1887 (before 1900) | mr.wikisource page (5,407 words, revision 210652) | **verified**; the Wikisource infobox calls the editor "author", the builder writes `anonymous` and names the editor in the `edition` |
| 2 | 91 Kalmi Bakhar | 18th century; Sen puts it c. 1760 | anonymous | en.wikipedia "Bakhar" | unverified (no first print, no text), review queue |
| 3 | Aartis: श्री शांतादुर्गेची आरती, आरती करू तुज गजानना, श्री विंध्यवासिनी माता आरती, two Shankar aartis (भस्मप्रिया भूतपते सदय; जयजयजी मदनांतक गौरीशंकरा) | no date, author or source on any page read (each tagged "no source"; two carry a copyright-review banner) | none provable | mr.wikisource search "intitle:आरती" and the pages | **unverified, dropped** |
| 4 | Bhupali songs | as culture 2 row 8 | none provable | mr.wikisource | dropped |
| 5 | Marathi Proverbs, collected by Alfred Manwaring, Clarendon Press, Oxford | 1899; Marathi text, transliteration, translation; word index pp. 249 to 271 (Open Library) | named collector; his death year was not read, so the floor cannot be applied | Open Library entries; no digitised page read | unverified, review queue |
| 6 | Krista Purana, Thomas Stephens | first published 1616, in Roman script (en.wikipedia "Marathi literature") | author's death year not read | en.wikipedia Marathi literature | unverified |
| 7 | Peshwyanchi Bakhar (c. 1818), Sabhasad Bakhar (c. 1697, Krishnaji Anant Sabhasad), Chitnis Bakhar (c. 1811) | composition dates from en.wikipedia "Bakhar", **not** first-print dates | named authors, death years not read | en.wikipedia Bakhar | unverified, no text page |

Not found: en.wikipedia "Lilacharitra" returned 404; Mahanubhav literature has no work page on mr.wikisource (the search "intitle:लीळाचरित्र" returned nothing and Mhaimbhat's author page returned 404).

**Count, culture 4:** 1 verified, 6 unverified or dropped.

## Proverbs, mhani (MR-020 to MR-022, 3 x 20 plus 10 reserve)

Genre `proverbs`, `basis: "oral-tradition"`, `source` with `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`. **Source, read in full:** mr.wikiquote "म्हणी" (raw wikitext), a long list grouped by letter with about 977 bullet lines; each entry has an explanation by Wikiquote contributors and some give a Sanskrit equivalent (संस्कृतपर्याय). No entry names an older source, so a card's `collection` is "Marathi Wikiquote, म्हणी" and `date` is the revision date the builder reads from the page. Also read: en.wiktionary "Category:Marathi proverbs" has 7 pages (आपलेच दात आपलेच ओठ; एका हाताने टाळी वाजत नाही; कुत्र्याचे शेपूट वाकडे ते वाकडेच; घरोघरी मातीच्या चुली; नाचता येइना अंगण वाकडे; पदरी पडले पवित्र झाले; वास्तू तथास्तु म्हणते). Four of them are also in the lists below (set 1, rows 5, 10, 15 and 16), which gives those four a second page.

**Verified:** all 70 proverbs below were present on the mr.wikiquote page, each with the page's own explanation, when the wikitext was read on 2026-11-15; they are the short ones (six words or fewer) and were chosen by that rule, not by taste. The page has spelling variants (आंधळं and अंधळं both appear, some entries carry a joiner character); the builder writes one spelling and notes the other. **No proverb is used in two decks.**

### MR-020, `mr-proverbs-1` (mr-4200 to 4249)

| # | Proverb |
|---|---|
| 1 | अती तेथे माती |
| 2 | अंधळं दळतं आणि कुत्र पीठ खातं |
| 3 | असेल दाम तर होईल काम |
| 4 | आधी पोटोबा मग विठोबा |
| 5 | आपलेच दात आणि आपलेच ओठ |
| 6 | आग लागल्यावर विहीर खणणे |
| 7 | आगीशिवाय धूर दिसत नाही |
| 8 | इच्छा तेथे मार्ग |
| 9 | एक घाव दोन तुकडे |
| 10 | एका हाताने टाळी वाजत नाही |
| 11 | एकटा जीव सदाशिव |
| 12 | ऐकावे जनाचे करावे मनाचे |
| 13 | काट्याने काटा काढावा |
| 14 | कोल्ह्याला द्राक्षे आंबट |
| 15 | कुत्र्याचे शेपूट वाकडे ते वाकडेच |
| 16 | घरोघरी मातीच्या चुली |
| 17 | गर्वाचे घर खाली |
| 18 | चोराच्या उलट्या बोंबा |
| 19 | चोरावर मोर, शेरास सव्वाशेर |
| 20 | कुंपणाने शेत खाल्ले |

### MR-021, `mr-proverbs-2` (mr-4250 to 4299)

| # | Proverb |
|---|---|
| 1 | अंथरूण पाहून पाय पसरावे |
| 2 | असतील शिते तर जमतील भुते |
| 3 | आडात नाही तर पोहऱ्यात कोठून येणार |
| 4 | आयजीच्या जीवावर बायजी उदार |
| 5 | आयत्या बिळात नागोबा |
| 6 | आयत्या पिठावर रेघोट्या |
| 7 | आपल्या हाताने आपल्याच पायावर दगड |
| 8 | इकडे आड, तिकडे विहीर |
| 9 | उथळ पाण्याला खळखळाट फार |
| 10 | उंटावरून शेळ्या हाकणे |
| 11 | एक ना धड भाराभर चिंध्या |
| 12 | काखेत कळसा गावाला वळसा |
| 13 | कानामागून आली अन तिखट झाली |
| 14 | कामापुरता मामा आणि ताकापुरती आजी |
| 15 | काप गेली भोके राहिली |
| 16 | गरज सरो,वैद्य मरो |
| 17 | गाढवाला गुळाची चव काय? |
| 18 | चार दिवस सासूचे चार दिवस सुनेचे |
| 19 | चोराच्या मनात चांदणे |
| 20 | आळश्याला दुप्पट काम |

### MR-022, `mr-proverbs-3` (mr-4300 to 4349)

| # | Proverb |
|---|---|
| 1 | अडली गाय खाते काय |
| 2 | अहो रूपम अहो ध्वनी |
| 3 | अर्ध्या हळकुंडाने पिवळे होणे |
| 4 | आले देवाजिच्या मना तेथे कोणाचे चालंना |
| 5 | आधणातले रडतात, सुपातले हसतात |
| 6 | आजा मेला, नातू झाला |
| 7 | आधी करावे मग सांगावे |
| 8 | आपण आपल्याच सावलीला भितो |
| 9 | आपण सुखी तर जग सुखी |
| 10 | आपली पाठ आपल्याला दिसत नाही |
| 11 | आरोग्य हीच धनसंपत्ती |
| 12 | उडाला तर कावळा बुडाला तर बेडूक |
| 13 | औट घटकेचे राज्य |
| 14 | कर नाही त्याला डर कशाला? |
| 15 | करावे तसे भरावे |
| 16 | कोल्हा काकडीला राजी |
| 17 | गाता गळा, शिंपता मळा |
| 18 | गाव करी ते राव न करी |
| 19 | घेतला वसा टाकू नये |
| 20 | चढेल तो पडेल |

### Reserve (10)

| # | Proverb |
|---|---|
| 1 | अती शहाणा त्याचा बैल रिकामा |
| 2 | एका म्यानात दोन तलवारी राहत नाहीत |
| 3 | एका माळेचे मणी |
| 4 | कोठेही गेला तरी पळसाला पाने तीनच |
| 5 | खाण तशी माती |
| 6 | घाण्याचा बैल |
| 7 | उठता लाथ बसता बुक्की |
| 8 | ओळखीचा चोर जीवे न सोडी |
| 9 | अव्हढासा पोर, घर राखण्यात थोर |
| 10 | उशिराने उठे काम साठे |

The builder sorts each deck's 20 by theme (animals, food, home, money, work, speech, luck, pride) and may swap a row for a reserve row, never for a proverb not read on the page.

## Multi-word verbs (MR-030 to MR-033, 4 x 20)

Genre `multiword`, a `pattern_family`, a `usage` note on every card; the citation form is the infinitive in -णे. Parts already taught are written by `ref` (cores such as `mr-verbs`, `mr-more-verbs`, `mr-verbs-3` to `mr-verbs-5`).

**What could be verified.** The Wiktionary route that the Telugu plan uses did not work for Marathi: of 127 noun-plus-verb titles tested on en.wiktionary (a noun with करणे, होणे, लागणे, येणे, वाटणे, घेणे or देणे), **only 3 pages exist**: मदत करणे (to help; a compound of मदत and करणे), विचार करणे (intransitive, to think or consider) and नमस्कार करणे. mr.wiktionary could not be read (HTTP 429). So the lists rest on:

- **mr.wikipedia क्रियापद** (read): names संयुक्त क्रियापद and gives the examples "मुले खेळू लागली" (the participle खेळू plus the auxiliary लागली), "खाऊन टाक" (खाऊन plus टाक), "तो वाचत बसला", "करू पाहतो" and "जाऊ दे".
- **The course itself**, read from `origin/decks-live`: `mr-grammar-compound-verbs` and `mr-grammar-conjunct-verbs` already teach the cards listed below. They are course content, not an outside source, and are unreviewed.

| Task | Deck and `pattern_family` | Candidates | Status |
|---|---|---|---|
| MR-030 | `mr-multiword-conjunct-verbs`, `conjunct-verb` (noun + करणे or होणे) | **3 verified on en.wiktionary:** मदत करणे, विचार करणे, नमस्कार करणे. **In the course, so a seed and not an outside proof:** काम करणे, फोन करणे, सुरू करणे, सुरू होणे, बंद करणे, लग्न करणे, तयार होणे. The builder takes more nouns from the cores in id order, only where a cited dictionary or Wiktionary page lists the compound | 3 verified, 7 course-internal, the rest unverified, review queue |
| MR-031 | `mr-multiword-compound-verbs`, `aspectual-compound` (participle in -ऊन plus टाकणे, घेणे, देणे, जाणे, येणे, ठेवणे, बसणे, लागणे, पाहणे) | **Verified on mr.wikipedia:** खाऊन टाकणे, खेळू लागणे, वाचत बसणे, करू पाहणे, जाऊ देणे. **Course sentences (seeds):** विसरून जाणे, लिहून ठेवणे, समजून घेणे, करून देणे, घेऊन येणे, घेऊन जाणे, निघून जाणे | 5 verified, 7 course-internal, the rest unverified |
| MR-032 | `mr-multiword-idiomatic-verbs`, `idiomatic` (वाक्प्रचार) | No outside source was found for the family. Four verbal phrases are entries on mr.wikiquote and can seed it if the builder reads them as phrases and not as proverbs: उंटावरून शेळ्या हाकणे, आग लागल्यावर विहीर खणणे, अर्ध्या हळकुंडाने पिवळे होणे, चालत्या गाडीला खीळ घालणे. The first three are rows of the proverbs decks above (set 2 row 10, set 1 row 6, set 3 row 3), so the builder uses each in one deck only | 4 verified as entries, the family itself unverified; **a better source is an open question** |
| MR-033 | `mr-multiword-dative-subject`, `dative-subject` (मला plus a noun and a verb of feeling) | **Course sentences (seeds):** भूक लागणे, तहान लागणे, झोप येणे, भीती वाटणे, आठवण येणे, राग येणे, थंडी वाजणे (each is shown in the course as "मला ..."). Not verified outside the course: mr.wikipedia क्रियापद does not cover it, and en.wikipedia "Marathi grammar" was read and has no section on it | 0 verified outside the course, 7 course-internal |

If fewer than 20 are attested for a family, the deck ships short; it is never filled. Every Marathi phrase is written by the builder from the page it read, never typed from this plan's memory.

## Recommendations (MR-060 and MR-061, 10 + 10)

File `decks/recommendations/mr.yaml`, in the shape of `recommendations/es.yaml` and the source-yourself mode of [Plan-Language-Completeness](Plan-Language-Completeness.md): `id: "mr-rec-<name>"`, `medium`, `title { text, reading }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each, tags, `rights_checked` and `jurisdiction`; no quotation, no link, no media. Rights are not a gate. Title, year and creator below were read on the page named; the builder adds the reading and the questions.

| # | Medium | Title | Creator | Year as read | Page that verifies | Status |
|---|---|---|---|---|---|---|
| 1 | film | Shwaas | Sandeep Sawant | 2004 (National Film Award for Best Feature Film, 2003 awards) | en.wikipedia Shwaas | verified |
| 2 | film | Sairat | Nagraj Manjule | 2016 | en.wikipedia Sairat | verified |
| 3 | film | Natarang | Ravi Jadhav; from the 1978 novel by Anand Yadav | 2010 | en.wikipedia Natarang | verified |
| 4 | film | Court | Chaitanya Tamhane | 2014 (Venice premiere; Indian release 2015); Marathi, Hindi, Gujarati, English | en.wikipedia Court (2014 film) | verified |
| 5 | film | Harishchandrachi Factory | Paresh Mokashi | 2009 (Indian release 29 Jan 2010) | en.wikipedia | verified |
| 6 | film | Fandry | Nagraj Manjule | 2013 (Indian release Feb 2014) | en.wikipedia | verified |
| 7 | film | Killa | Avinash Arun | 2015 (released 26 Jun 2015; Berlin 2014) | en.wikipedia Killa (film) | verified |
| 8 | film | Deool | Umesh Vinayak Kulkarni | 2011 | en.wikipedia | verified |
| 9 | film | Duniyadari | Sanjay Jadhav; from the novel by Suhas Shirvalkar | 2013 | en.wikipedia | verified |
| 10 | film | Natsamrat | Mahesh Manjrekar | 2016 | en.wikipedia Natsamrat | verified |
| 11 | play | Natsamrat | Kusumagraj (V. V. Shirwadkar) | first staged 1970 | en.wikipedia Natsamrat | verified |
| 12 | play | Ghashiram Kotwal | Vijay Tendulkar | first staged 16 Dec 1972, Pune | en.wikipedia | verified |
| 13 | play and film | Katyar Kaljat Ghusali | Purushottam Darvhekar (play); Subodh Bhave (film) | play 1967; film 2015 | en.wikipedia (a disambiguation page; the film's language is not stated, so the builder confirms it) | verified, language to confirm |
| 14 | book | Yayati | V. S. Khandekar | 1959 (Sahitya Akademi 1960, Jnanpith 1974) | en.wikipedia Yayati (novel) | verified |
| 15 | book | Chhava | Shivaji Sawant | 1980 (Sawant 31 Aug 1940 to 18 Sep 2002) | en.wikipedia Shivaji Sawant | verified |
| 16 | film | Sant Tukaram (1936) | Vishnupant Govind Damle and Sheikh Fattelal | 12 Dec 1936 | en.wikipedia Sant Tukaram (1936 film) | verified; public-domain status not read, so a recommendation only, never culture |
| 17 | book | Vyakti ani Valli | P. L. Deshpande (8 Nov 1919 to 12 Jun 2000) | the page says the Sahitya Akademi Award in 1965; publication year not stated | en.wikipedia Pu. La. Deshpande | title and creator verified; year unverified, review queue |
| 18 | book | Batatyachi Chal | P. L. Deshpande | not on the pages read (the Batatyachi Chal URL led to the author's page) | none | unverified, review queue |
| 19 | book | Mrityunjay | Shivaji Sawant | no publication year on the page; Hindi translation 1974, English 1989, TV series 1996 | en.wikipedia Shivaji Sawant (the novel's own page returned 404) | creator verified; year unverified |
| 20 | book | Shyamchi Aai | Sane Guruji | no publication year on the pages read | mr.wikisource; en.wikipedia | unverified; also a culture 3 row, used once |

**Counts, recommendations:** 16 verified (rows 1 to 16), 4 partly or fully unverified (rows 17 to 20). MR-060 takes rows 1 to 10 (films); MR-061 takes rows 11 to 20, replacing each unverified row from a reserve the builder has read on a page.

## Review-queue rule

Everything is `unreviewed`. Every row marked unverified, conflicting or dropped above is a row in the builder's report, in the table shape of `docs/review-queue/mr.md`; MR-120 to MR-122 collect them.

## Totals

| List | Verified | Unverified, review queue or dropped |
|---|---|---|
| Culture 1, sant poets | 11 rows with a text page (12 works); 5 creators without a text page | R1 to R4 reserve; 1 dropped (R4) |
| Culture 2, folk | 4 works | 3 unverified (rows 6, 7, 8), 1 dropped (row 9) |
| Culture 3, modern | 8 poems; 9 conditional on Balkavi's death year | Sane, Gadkari |
| Culture 4, anonymous | 1 | 6 |
| Proverbs | 70 (60 plus 10 reserve) | 0 |
| Multi-word verbs | 12 outside the course (3 Wiktionary, 5 mr.wikipedia, 4 phrase entries), plus 14 course seeds | the four families cannot be filled from outside sources |
| Recommendations | 16 | 4 |

## Open questions

- **Culture 4 cannot reach 18** from what the named pages show. The options: ship it short (one verified item), fold the theme into culture 2, or widen it to pre-1900 named works whose author died by 1955 (Krista Purana, Manwaring's proverbs, the named bakhars) after the builder reads their dates. The architect decides; nothing is invented meanwhile.
- **Balkavi's death year** is "1918" on the author list and "?" on his own page. The builder reads a third page before any Balkavi card is built.
- **A multi-word source.** en.wiktionary has 3 Marathi noun-plus-verb pages. A grammar or dictionary page the builder can read (for example a public-domain Marathi dictionary) would make MR-030 to MR-033 fully verified; none was reached.
- **Wikisource notices.** Several pages read (Balkavi, the aartis, the bhupali songs) carry a "may be copyrighted, may be deleted" banner and the "no source" tag. They are not rights proofs.
- **Professional decks** are held for the owner's profession list.
