# Plan: Gujarati genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task GU-001 of [Deck-Work-Queue-GU](Deck-Work-Queue-GU.md), written 2026-11-15 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Telugu](Plan-Culture-Telugu.md) and [Plan-Culture-Hindustani](Plan-Culture-Hindustani.md), for the tasks GU-010 to GU-013 (culture), GU-020 to GU-022 (proverbs), GU-030 to GU-033 (multi-word verbs) and GU-060 and GU-061 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md). If this page and a task row differ, this page wins.

## How this page was checked

Everything below was read on 2026-11-15 on the page named; nothing is written from memory. The columns say what was read.

- **E** en.wikipedia (creator's years, work, language, year). **WS** gu.wikisource: a category or work page was opened; the "page read" cell says whether the work page itself was opened (author, scan edition and licence line seen) or only listed in its author's category. **WQ** gu.wikiquote letter pages (`ગુજરાતી કહેવતો/<letter>`), read in full. **W** en.wiktionary entry or category page.
- **The poems' lines were not read in full by this page.** The page-reading tool used would not return song lyrics, so for a work marked "page read" this page confirms the title exists, the author field, the scan edition and the licence line, not the wording of a line. The builder opens the page, takes one verse or line of at most 25 words, counts it, and drops the item if it cannot read or count it.
- **Nothing here is unverified except where a cell says "builder reads".** Items that could not be verified on a named page were dropped (the list is in "Dropped and open").
- Network note: `gu.wikisource`, `gu.wikiquote` and the Wikimedia API rate-limit a shared proxy hard (HTTP 429); the builder should space its requests and prefer `index.php?action=raw` for wikiquote.
- gu.wikisource transcludes the text from page scans, so the wikitext of a work page holds only a header; the builder reads the rendered page (or the `Page:` namespace) for the text.

## Rules applied

- **Rights floor.** The author's death year must be 1955 or earlier (the validator's floor). `jurisdiction`: `IN`. An anonymous or traditional work needs a first publication before 1900. Where a gu.wikisource page names a scan but no year of first publication, an anonymous work **cannot** be shown to meet the floor and goes to the review section, not into a deck. The floor catches typos; the reviewer owns the legal opinion.
- **Basis `public-domain` only for culture decks, no `quotation` items.** `source` block as in batch 1 of the Japanese culture deck: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction`, `rights_checked`. `edition` is the scan the gu.wikisource page names (for example "Bruhad Kavyadohan Granth 1"). gu.wikisource text is CC BY-SA 4.0, which matches the course licence.
- **Text as printed in the cited edition**, in Gujarati script; archaic forms are listed in the layer with their modern form. Attribution is "attributed to" where a poem's credit is doubtful (the Mirabai pages cite a bhajan anthology, and en.wikipedia names no Gujarati-language poems of hers).
- **One excerpt per card**: one verse, line or sentence, at most **25 words** (whitespace-separated). **18 items per culture deck**, short items first. The first 18 that pass are the deck, the rest the reserve; fewer than 18 may pass and the deck is never padded.
- **`reading` and `ipa` from the tool**: `python3 tools/transcribe.py gu "<Gujarati>"`; never by hand. Readings are based on ISO 15919 (never "strictly follow it"). A doubtful reading or spelling goes to `docs/review-queue/gu.md`.
- **Dates are never guessed.** `date` takes a year, `c. YEAR` or `A-B`; where the pages disagree the year is `circa`. The creator's `born` and `died` must satisfy `MAX_LIFESPAN` (120).
- **Translations** are the builder's own plain renderings.
- **Creators** (file `decks/creators/gu.yaml`, created by GU-010): a short A2-level English bio, `born` and `died`, era, one legacy line with a checkable item and a source link, no image. The id ranges below are the plan's suggestion inside the queue's genre block `gu-6000..6999`; the architect may move them.
- **Order of work.** GU-010 to GU-013 run one after another because they share `creators/gu.yaml`; recommendations (GU-060, GU-061) follow on the same file. Proverbs and multi-word decks are independent of that lane.
- **Header.** `language: { code: "gu", ... }` as in the existing `gu` cores, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`.

## Creators checked (years read)

| Creator | Years read | Page | Note |
|---|---|---|---|
| Narsinh Mehta | c. 1414 to 1488 | E | the page also says "lived until 79" and lists a 1481 death category; use `circa` |
| Mirabai | c. 1498 to c. 1546 | E | the page also gives 1499, 1547 and 1548; `circa`; no Gujarati poems named on E |
| Akho (Akha Bhagat) | c. 1591 to 1656 | E | the page says exact dates unknown; `circa` |
| Premanand Bhatt | 1636 to 1714 | E | the page spells the name "Premanand Bhatt" |
| Shamal Bhatt | born c. 1696 to 1698, alive in 1765, death not given | E | `circa`; no death year, so the builder reads one or drops him |
| Dayaram | 1777 to 1853 | E | |
| Dalpatram | 1820 to 1898 | E, WS | Kathan Saptashati (proverb collection) named on WS |
| Karsandas Mulji | 1832 to 1871 | E | the page notes Britannica gives 1875 |
| Narmad | 1833 to 1886 | E | |
| Navalram Pandya | 1836 to 1888 | E | |
| Mahipatram Nilkanth | 1829 to 1891 | E | |
| Govardhanram Tripathi | 1855 to 1907 | E, WS | Saraswatichandra volumes 1887, 1892, 1898, 1901 (E) |
| Manilal Dwivedi | 1858 to 1898 | E | |
| Narasinhrao Divatia | 1859 to 1937 | E | page title is `Narsinhrao_Divatia` |
| Balwantray Thakore | 1869 to 1952 | E | |
| Kalapi | 1874 to 1900 | E, WS | E says the death date is uncertain; WS says 9 June 1900 |
| Nanalal (Nhanalal) | 1877 to 1946 | E, WS | |
| Ranjitram Mehta | 1881 to 1917 | E | |
| Ardeshar Khabardar | 1881 to 1953 | E, WS | |
| Zaverchand Meghani | 1896 to 1947 | E | folk collections with years listed on E |
| Mahatma Gandhi | 1869 to 1948 | E | Gujarati works are taken from WS (below) |

All pass the 1955 floor.

## Culture decks (GU-010 to GU-013, 4 x 18 plus reserves)

Page-read key: **R** = the work page was opened (author field, scan and licence seen); **L** = the work is listed in the author's category on gu.wikisource, page not opened (the builder opens it); **A** = author page on gu.wikisource opened and the work named there.

### GU-010, `gu-culture-1`: bhakti poets (gu-6000 to 6049)

All 18 rows are real titles of works read on gu.wikisource; the Gujarati wording of the lines is for the builder to read and count.

| # | Work (gu.wikisource title) | Creator | Page | Edition named on the page | Rights verdict |
|---|---|---|---|---|---|
| 1 | જાગીને જોઉં તો (prabhatiya) | Narsinh Mehta | R | Bruhad Kavyadohan Granth 1 | passes; `circa` |
| 2 | ભુતળ ભક્તિ પદારથ | Narsinh Mehta | R | Bruhad Kavyadohan Granth 1 | passes; `circa` |
| 3 | અખિલ બ્રહ્માંડમાં એક તું શ્રી હરિ | Narsinh Mehta | L | builder reads | passes; `circa` |
| 4 | જૂનું તો થયું રે દેવળ | Mirabai | R | Bhajan Sar Sindhu | passes; `circa`; "attributed to" |
| 5 | અખંડ વરને વરી | Mirabai | L | builder reads | passes; "attributed to" |
| 6 | ઝેર તો પીધાં છે જાણી જાણી | Mirabai | L | builder reads | passes; "attributed to" |
| 7 | અરજ કરે છે મીરાં રાંકડી | Mirabai | L | builder reads | passes; "attributed to" |
| 8 | અખાના છપ્પા, ભક્તિ અંગ (chhappa 217 to 219 seen) | Akho | R | Bruhad Kavyadohan Granth 1 | passes; `circa` |
| 9 | અખાના છપ્પા, ગુરુ અંગ | Akho | L | builder reads | passes; `circa` |
| 10 | અખાના છપ્પા, માયા અંગ | Akho | L | builder reads | passes; `circa` |
| 11 | અખાના છપ્પા, સંત અંગ | Akho | L | builder reads | passes; `circa` |
| 12 | લટકંતા આવે લાલ | Premanand | R | Bhajano ane Bhaktipado | passes |
| 13 | મામેરૂં (Kunvarbai nu Mameru) | Premanand | L | builder reads | passes |
| 14 | સુદામા ચરિત | Premanand | L | builder reads | passes |
| 15 | શિક્ષા શાણાને | Dayaram | R | Dayaram Lekhan | passes |
| 16 | વૈષ્ણવ નથી થયો તું રે હરિજન નથી થયો તું રે | Dayaram | L | builder reads | passes |
| 17 | હરિ, જેવો તેવો હું દાસ તમારો | Dayaram | L | builder reads | passes |
| 18 | ચિત્ત તું શીદને ચિંતા ધરે | Dayaram | L | builder reads | passes |

Reserve (all titles read in the same categories): Narsinh Mehta "પ્રાણ થકી મને વૈષ્ણવ વ્હાલા", "ધ્યાન ધર હરિતણું", "નારાયણનું નામ જ લેતાં", "બાપજી પાપ મેં"; Mirabai "ચલો મન ગંગા-જમુના તીર", "કર્મનો સંગાથી કોઈ નથી"; Dayaram "મનજી ! મુસાફર રે ! ચલો નિજ દેશ ભણી !". This task creates `decks/creators/gu.yaml` (`kind: "creators"`, `id: "creators-gu"`, `language: "gu"`). Caution for the builder: the Narsinh Mehta category (123 pages) was read only to its first 80 titles; "Vaishnav Jan To" was not among them and is **not** listed here because no page for it was read.

### GU-011, `gu-culture-2`: garba, bhajan and songs of named poets (gu-6050 to 6099)

| # | Work (gu.wikisource title) | Creator | Page | Rights verdict |
|---|---|---|---|---|
| 1 | આંખોમાં ઊડે ગુલાલ | Dayaram | L | passes |
| 2 | કાનુડો કામણગારો રે | Dayaram | L | passes |
| 3 | મુજને અડશો મા ! | Dayaram | L | passes |
| 4 | હો વાંસલડી ! | Dayaram | L | passes |
| 5 | મોરલી | Dayaram | L | passes |
| 6 | વાંસળી | Dayaram | L | passes |
| 7 | આનંદનો ગરબો | Vallabh Bhatt | R (Bruhat Kavyadohan Granth 2, edition of 1913) | **dates not read**: builder reads his years on en.wikipedia or gu.wikipedia, else drops |
| 8 | આકાશની ગરબી | Dalpatram | R (Dalpatram Rachit Kavyo) | passes |
| 9 | ખેલો ખેલો હોળી રે ખેલૈયા | Narmad | L | passes |
| 10 | ડાંડિયાની ડાંડિ | Narmad | L | passes |
| 11 | પારણે પોઢ્યાં શ્રી પુરષોત્તમ | Narsinh Mehta | L | passes; `circa` |
| 12 | જાગને જાદવા! રાત થોડી રહી | Narsinh Mehta | L | passes; `circa` |
| 13 | જશોદા! તારા કાનુડાને | Narsinh Mehta | L | passes; `circa` |
| 14 | ઓધા નહીં રે આવું | Mirabai | L | passes; "attributed to" |
| 15 | ઊંચા ઊંચા આભમાં | Mirabai | L | passes; "attributed to" |
| 16 | જાગો રે અલબેલા કા'ના | Mirabai | L | passes; "attributed to" |
| 17 | કોણ ભરે કોણ ભરે પાણી જમુનાનાં | Mirabai | L | passes; "attributed to" |
| 18 | હાલરડાં (Meghani's lullaby collection, 1929 on E) | Zaverchand Meghani, compiler | L | the songs are traditional; the compiler died 1947; rights basis goes to review (see "Review") |

Reserve: Narsinh Mehta "પ્રેમરસ પાને"; Dayaram "ઓ વ્રજનારી !"; Meghani "હાલો ગલૂડાં રમાડવા જી રે". Traditional garba pages (see "Review") are held out of the deck until a first-publication year is read.

### GU-012, `gu-culture-3`: modern prose and verse, authors who died by 1955 (gu-6100 to 6149)

| # | Work | Creator | Page | Rights verdict |
|---|---|---|---|---|
| 1 | જય! જય! ગરવી ગુજરાત! (E gives 1873) | Narmad | R (Narmad Lekhan) | passes |
| 2 | યા હોમ કરીને પડો | Narmad | R (Narmad Lekhan) | passes |
| 3 | કબીરવડ | Narmad | L | passes |
| 4 | a poem from Kalapino Kekarav (E: 1903, posthumous) | Kalapi | A (his WS author page opened; no poem titles listed there) | passes; builder finds a poem on WS |
| 5 | a passage of Kashmirno Pravas (E: 1912) | Kalapi | A | passes; builder finds it on WS |
| 6 | a poem | Nanalal Kavi | A (works named: Kurukshetra 1926 to 40, Ketlank Kavyo) | passes; builder finds a poem on WS |
| 7 | a sonnet from Bhankaar (E: 1918 or 1917; Mhara Sonnet 1935) | Balwantray Thakore | E | passes; builder finds it on WS |
| 8 | a poem from Kavyarasika (E: 1901) or Bharat no Tankar (E: 1909) | Ardeshar Khabardar | A (WS author page opened, 15 collections listed) | passes (died 1953) |
| 9 | a poem from Kusumamala (E: 1887) or Hridyavina (E: 1896) | Narasinhrao Divatia | E | passes (died 1937) |
| 10 | સોરઠ, તારાં વહેતાં પાણી (1937) | Zaverchand Meghani | R (fifth edition 2000 named; Gurjar Grantharatna; marked public domain on the page) | passes (died 1947) |
| 11 | સિંધુડો (E: 1930) | Zaverchand Meghani | L | passes |
| 12 | અનાસક્તિયોગ (Gita translation, Navajivan, samvat 1989) | Mahatma Gandhi | R (page says public domain under Indian law) | passes (died 1948) |
| 13 | આરોગ્યની ચાવી (Navajivan, 1948) | Mahatma Gandhi | R (page makes no public-domain statement; CC BY-SA only) | passes the floor; flag in review |
| 14 | a passage of Saraswatichandra, part 1 (E: 1887) | Govardhanram Tripathi | A (four parts linked on WS) | passes |
| 15 | a passage of Vanraj Chavdo (E: 1881) | Mahipatram Nilkanth | E | passes |
| 16 | a passage of Meghadut translation (E: 1870) | Navalram Pandya | E | passes |
| 17 | a passage of Atmanimajjan (E: 1895) or Kanta (E: 1882) | Manilal Dwivedi | E | passes |
| 18 | a passage of Ahmad Rupande (E: 1908) | Ranjitram Mehta | E | passes (died 1917) |

Rows marked R have a page read; rows with "a poem" or "a passage" need the builder to find the exact page on gu.wikisource and drop the item if there is none. Reserve: Karsandas Mulji (E: 1832 to 1871; his 1865 history is in English, so a Gujarati work is needed), Dalpatram, Meghani "સોરઠી સંતો", "રા' ગંગાજળિયો". Prose is hard at A2; keep each excerpt to one sentence.

### GU-013, `gu-culture-4`: narrative and didactic verse before 1900 (gu-6150 to 6199)

| # | Work (gu.wikisource title) | Creator | Page | Rights verdict |
|---|---|---|---|---|
| 1 | ઓખાહરણ | Premanand | L | passes |
| 2 | નળાખ્યાન | Premanand | L | passes |
| 3 | કૃષ્ણ - સુદામાનો મેળાપ | Premanand | L | passes |
| 4 | પછી શામળિયોજી બોલિયા | Premanand | L | passes |
| 5 | અખેગીતા, કડવું ૧ લું - હરિગુરુસંતની સ્તુતિ | Akho | L (title in the WS list) | passes; `circa` |
| 6 | અખેગીતા, કડવું ૧૦ મું - ભક્તિ, જ્ઞાન, વૈરાગ્યનું માહાત્મ્ય | Akho | L | passes; `circa` |
| 7 | અખેગીતા, કડવું ૧૧ મું - સર્વાત્મભાવ તેજ પ્રેમલક્ષણા ભક્તિ | Akho | L | passes; `circa` |
| 8 | અખેગીતા, કડવું ૧૩ મું - જીવન્મુક્તની દશા - ૧ | Akho | L | passes; `circa` |
| 9 | અખાના છપ્પા, અજ્ઞાન અંગ | Akho | L | passes; `circa` |
| 10 | અખાના છપ્પા, વૈરાગ્ય અંગ | Akho | L | passes; `circa` |
| 11 | અખાના છપ્પા, તીર્થ અંગ | Akho | L | passes; `circa` |
| 12 | રસિકવલ્લભ (1838 on E) | Dayaram | L | passes |
| 13 | સુદામા ચરિત (Narsinh Mehta's own, E lists "Sudama Charit") | Narsinh Mehta | E | passes; `circa`; builder reads a WS page or drops |
| 14 | Hundi or Kunvarbai nu Mameru (E) | Narsinh Mehta | E | passes; `circa`; builder reads a WS page or drops |
| 15 | Simhasanbatrishi | Shamal Bhatt | E | **death year not given**; builder reads one, else drops |
| 16 | a verse of Kathan Saptashati (proverb collection) | Dalpatram | A | passes (died 1898) |
| 17 | a verse of Farbas Virah (first Gujarati elegy, per WS) | Dalpatram | A | passes |
| 18 | a verse of Mithyabhiman (play, 1870 on E) | Dalpatram | E | passes |

Reserve: Narsinh Mehta "નાગદમન" (WS category) and Dana Leela (E, no WS page read); Akho "અખેગીતા" other kadvu pages. Items 13 to 15 and 16 to 18 have no gu.wikisource page read: they are the most likely to fall to the reserve.

## Proverbs (GU-020 to GU-022, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`; each card has a `literal` note and a meaning. **Source** for every row: gu.wikiquote, the letter page named, read in full on 2026-11-15 (about 920 numbered lines over 37 pages: `ગુજરાતી કહેવતો/<letter>` for અ, આ, ઈ, ઉ, ઊ, એ, ઓ, ક to હ, ક્ષ and જ્ઞ; the index page `ગુજરાતી કહેવતો` carries a "Dead end" maintenance tag, and the pages cite no collection). Each text was checked by exact match against the page. Trailing full stops were dropped.

Rights and caveats, all to be repeated in the review queue: these are community-edited unsourced lists, so each proverb is `oral-tradition` with no named collection, date or edition; `source.collection` is "gu.wikiquote: ગુજરાતી કહેવતો", `source.date` is the year the page was read (2026), `jurisdiction` is `IN`. Several lines on the same pages are idioms rather than proverbs and were left out; a few proverbs appear on two pages with small spelling differences (the builder takes the form shown). The reviewer owns the legal opinion on whether an unsourced traditional saying needs a first-publication date; the stronger source, Dalpatram's Kathan Saptashati (WS author page names it as a proverb collection, died 1898), is the alternative reserve if a printed collection is wanted.

### GU-020, `gu-proverbs-1`: animals, food, family, work, money and weather (gu-6200 to 6249)

Themes: animals, food, family, work, money, weather. All 20 rows below are **verified**: the exact text was read on the gu.wikiquote letter page named. Reserve (verified the same way): ઊગતા સૂરજને સૌ નમે (/ઊ), કરડે માકણ ને બળવું ખાટલાને (/ક).

| # | Kahevat (text as read) | Page read on gu.wikiquote | Words |
|---|---|---|---|
| 1 | અન્ન એવો ઓડકાર | ગુજરાતી કહેવતો/અ | 3 |
| 2 | દીવા તળે અંધારું | ગુજરાતી કહેવતો/દ | 3 |
| 3 | ઊંટના અઢારે અંગ વાંકા જ હોય | ગુજરાતી કહેવતો/ઊ | 6 |
| 4 | ઊંદર બિલાડીની રમત | ગુજરાતી કહેવતો/ઊ | 3 |
| 5 | ઝાઝા રસોઇયા રસોઇ બગાડે | ગુજરાતી કહેવતો/ઝ | 4 |
| 6 | ઝાઝા હાથ રળીયામણા | ગુજરાતી કહેવતો/ઝ | 3 |
| 7 | ખાડો ખોદે તે પડે | ગુજરાતી કહેવતો/ખ | 4 |
| 8 | ગધેડા ઉપર અંબાડી ન શોભે | ગુજરાતી કહેવતો/ગ | 5 |
| 9 | ચાદર જોઈને પગ પહોળા કરાય | ગુજરાતી કહેવતો/ચ | 5 |
| 10 | આજ રોકડા, કાલ ઉધાર | ગુજરાતી કહેવતો/આ | 4 |
| 11 | દીકરી તો પારકી થાપણ કહેવાય | ગુજરાતી કહેવતો/દ | 5 |
| 12 | ચમડી તૂટે પણ દમડી ન છૂટે | ગુજરાતી કહેવતો/ચ | 6 |
| 13 | ઘર ફૂટે ઘર જાય | ગુજરાતી કહેવતો/ઘ | 4 |
| 14 | છેલ્લું ઓસડ છાશ | ગુજરાતી કહેવતો/છ | 3 |
| 15 | ધોબીનો કૂતરો, નહિ ઘરનો નહિ ઘાટનો | ગુજરાતી કહેવતો/ધ | 6 |
| 16 | નબળી ગાયને બગાઈ ઝાઝી | ગુજરાતી કહેવતો/ન | 4 |
| 17 | બાપ શેર તો દીકરો સવા શેર | ગુજરાતી કહેવતો/બ | 6 |
| 18 | ઘરના ભુવા ને ઘરના ડાકલાં | ગુજરાતી કહેવતો/ઘ | 5 |
| 19 | શિયાળો ભોગીનો ઉનાળો જોગીનો | ગુજરાતી કહેવતો/શ | 4 |
| 20 | ખિસ્સા ખાલી ને ભભકો ભારી | ગુજરાતી કહેવતો/ખ | 5 |

### GU-021, `gu-proverbs-2`: friends and neighbours, learning, luck, time, speech (gu-6250 to 6299)

Themes: friends and neighbours, learning, luck, time, speech. All 20 rows below are **verified**: the exact text was read on the gu.wikiquote letter page named. Reserve (verified the same way): ઓળખાણ સૌથી મોટી ખાણ છે (/ઓ), જાગ્યા ત્યાંથી સવાર (/જ), ઝાઝી કીડીઓ સાપને તાણે (/ઝ).

| # | Kahevat (text as read) | Page read on gu.wikiquote | Words |
|---|---|---|---|
| 1 | પહેલો સગો પાડોશી | ગુજરાતી કહેવતો/પ | 3 |
| 2 | સંગ તેવો રંગ | ગુજરાતી કહેવતો/જ | 3 |
| 3 | એક હાથે તાળી ન પડે | ગુજરાતી કહેવતો/એ | 5 |
| 4 | એક કરતાં બે ભલા | ગુજરાતી કહેવતો/એ | 4 |
| 5 | સંપ ત્યાં જંપ | ગુજરાતી કહેવતો/જ | 3 |
| 6 | ગરજ સરી એટલે વૈદ વેરી | ગુજરાતી કહેવતો/ગ | 5 |
| 7 | ભણેલા ભીંત ભૂલે | ગુજરાતી કહેવતો/ભ | 3 |
| 8 | ઠોકર વાગે ત્યારે જ અક્કલ આવે | ગુજરાતી કહેવતો/ઠ | 6 |
| 9 | ભાગ્યશાળીને ભૂત રળે | ગુજરાતી કહેવતો/ભ | 3 |
| 10 | પડ્યા પર પાટું | ગુજરાતી કહેવતો/પ | 3 |
| 11 | તેજીને ટકોરો, ગધેડાને ડફણાં | ગુજરાતી કહેવતો/ત | 4 |
| 12 | ગઈ તિથિ જોશી પણ ન વાંચે | ગુજરાતી કહેવતો/ગ | 6 |
| 13 | રાત ગઈ અને વાત ગઈ | ગુજરાતી કહેવતો/ર | 5 |
| 14 | બગાસું ખાતા પતાસું મળ્યું | ગુજરાતી કહેવતો/બ | 4 |
| 15 | ચેતતો નર સદા સુખી | ગુજરાતી કહેવતો/ચ | 4 |
| 16 | ન બોલવામાં નવ ગુણ | ગુજરાતી કહેવતો/ન | 4 |
| 17 | સબસે બડી ચૂપ | ગુજરાતી કહેવતો/સ | 3 |
| 18 | ભીંતને પણ કાન હોય છે | ગુજરાતી કહેવતો/ભ | 5 |
| 19 | અક્કલ ઉધાર ન મળે | ગુજરાતી કહેવતો/અ | 4 |
| 20 | એક ઘાએ કૂવો ન ખોદાય | ગુજરાતી કહેવતો/એ | 5 |

### GU-022, `gu-proverbs-3`: love, age, honesty, effort, appearances, wit (gu-6300 to 6349)

Themes: love, age, honesty, effort, appearances, wit. All 20 rows below are **verified**: the exact text was read on the gu.wikiquote letter page named. Reserve (verified the same way): આપ ભલા તો જગ ભલા (/આ), ખાલી ચણો વાગે ઘણો (/ખ).

| # | Kahevat (text as read) | Page read on gu.wikiquote | Words |
|---|---|---|---|
| 1 | પ્રીત પરાણે ન થાય | ગુજરાતી કહેવતો/પ | 4 |
| 2 | હસે તેનું ઘર વસે | ગુજરાતી કહેવતો/હ | 4 |
| 3 | દયા ધર્મનું મૂળ છે | ગુજરાતી કહેવતો/દ | 4 |
| 4 | સંતોષી નર સદા સુખી | ગુજરાતી કહેવતો/સ | 4 |
| 5 | ધીરજના ફળ મીઠા હોય | ગુજરાતી કહેવતો/ધ | 4 |
| 6 | ઉતાવળે આંબા ન પાકે | ગુજરાતી કહેવતો/ઉ | 4 |
| 7 | કરે સેવા તેને મળે મેવા | ગુજરાતી કહેવતો/ક | 5 |
| 8 | કરો તેવું પામો, વાવો તેવું લણો | ગુજરાતી કહેવતો/ક | 6 |
| 9 | મન હોય તો માળવે જવાય | ગુજરાતી કહેવતો/મ | 5 |
| 10 | નમે તે સૌને ગમે | ગુજરાતી કહેવતો/ન | 4 |
| 11 | શાંત પાણી ઊંડા હોય | ગુજરાતી કહેવતો/શ | 4 |
| 12 | ઉજળું એટલું દુધ નહિ | ગુજરાતી કહેવતો/ઉ | 4 |
| 13 | ડુંગર દૂરથી રળિયામણા | ગુજરાતી કહેવતો/ડ | 3 |
| 14 | ચીંથરે વીંટાળેલું રતન | ગુજરાતી કહેવતો/ચ | 3 |
| 15 | કમળો હોય તેને પીળું દેખાય | ગુજરાતી કહેવતો/ક | 5 |
| 16 | ઘરડા ગાડા વાળે | ગુજરાતી કહેવતો/ઘ | 3 |
| 17 | દગો કોઈનો સગો નહિ | ગુજરાતી કહેવતો/દ | 4 |
| 18 | અતિ લોભ તે પાપનું મૂળ | ગુજરાતી કહેવતો/અ | 5 |
| 19 | અતિની ગતિ નહીં | ગુજરાતી કહેવતો/અ | 3 |
| 20 | થાકશે, ત્યારે પાકશે | ગુજરાતી કહેવતો/થ | 3 |


## Multi-word verbs (GU-030 to GU-033, 4 x 20)

Genre `multiword`, a `pattern_family`, a `usage` note on every card; the citation form is the dictionary form in -વું / -વી (`કરવું`). Parts already taught are written by `ref`. **Sources**: en.wiktionary `Category:Gujarati verbs` (443 pages, first 200 read; **11 multi-word titles** among them, all listed below), `Category:Gujarati phrases` (34 pages, read in full), `Category:Gujarati idioms` (4 pages, read in full) and the entry pages named. **Honest count: fewer than 20 attested items per family can be verified on en.wiktionary; the builder must also use gu.wiktionary and a cited dictionary page, and reports the count rather than padding.** Every `usage` note and example is the builder's own.

| Task | Deck and `pattern_family` | Verified seeds (entry read) | Ids |
|---|---|---|---|
| GU-030 | `gu-multiword-conjunct-verbs`, `conjunct-verb` | noun plus કરવું: **દાખલ કરવું** "to admit (into a hospital)" (W read); **દાઢી કરવું** "to shave" (W read); noun plus બોલવું or મારવું: **જુઠ્ઠું બોલવું** "to lie" (W read); **ગુલ્લી મારવી** "to ditch, skip" (W read). Listed in the category, entry not opened: ગાંડ આંગળી કરવું. The noun મદદ (W read) lists no compound verbs, so "મદદ કરવી" is **not** claimed | gu-6400 to 6449 |
| GU-031 | `gu-multiword-compound-verbs`, `compound-verb` | verb plus a light verb: **ખાઈ જવું** "to eat, eat up" (W read, no examples). Listed, entry not opened: અટવાય જવું. The builder scans the cores `gu-verbs`, `gu-more-verbs` and the other verb units for a stem plus જવું, લેવું, દેવું, નાખવું, પડવું, બેસવું or રહેવું and takes each combination attested on gu.wiktionary or a cited page | gu-6450 to 6499 |
| GU-032 | `gu-multiword-idiomatic-verbs`, `idiomatic-verb` | **આડું પડવું** "lie down, rest, go to sleep" (W read; examples "થોડીક વાર માટે આડો પડ", "હું બે-ત્રણ કલાક માટે આડો પડીશ"); **આવી બનવું** "to be in trouble" (W read; example "જો બાપા તારી સિગારેટ્સ શોધી કાઢશે, તો તારું આવી બનશે."); **ખબર હોવી** "to know", synonym જાણવું (W read; example "મને ખબર નથી" "I do not know"). Listed, entry not opened: આગ ઝરવું. The four idiom-category pages (પોદળો, રામકહાણી, શું હું ફારસી બોલું છું, સિતારો) are single items, not verb families | gu-6500 to 6549 |
| GU-033 | `gu-multiword-dative-subject`, `dative-subject` | the experiencer takes -ને or the genitive and the thing is the subject. Verified entries: **ગમવું** "to like, enjoy" (W read; "મને બિલાડી ગમતી નથી" "I don't like cats"); **જોઈએ** "to want, need, should", dative with -ને, defective verb (W read; "મને જોઈએ છે" "I want [it]", "મારે કરવું જોઈએ" "I should do [it]"); **આવડવું** "to know (a skill), to learn" (W read; "મને ગાડી ચલાવતાં આવડે છે"). Verified phrase pages (Category:Gujarati phrases, titles read): મને ભૂખ લાગી છે, મને તરસ લાગી છે, મને ઠંડી લાગે છે, મારું માથું દુખે છે, મારી પાસે પૈસા નથી, ખબર હોવી (above). The entry લાગવું (W read) gives only "to touch or feel", no example, so the pattern is taken from the phrase pages. Builder checks the existing grammar decks for the pattern first and writes phrase cards with a `usage` note | gu-6550 to 6599 |

Not claimed: any compound or conjunct verb not listed above; the Telugu and Hindustani plans' seed lists are not carried over, because their Gujarati forms were not read.

## Recommendations (GU-060 and GU-061, 10 + 10)

File `decks/recommendations/gu.yaml`, in the shape of `recommendations/es.yaml`: `id: "gu-rec-<name>"`, `medium`, `title { text }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each that only someone who read, watched or heard the work could answer, `tags: ["unreviewed"]`. No quotation and no link. `basis: "source-yourself"` (see [Plan-Language-Completeness](Plan-Language-Completeness.md)), so rights are not a gate. Year, creator and language below are from the page named, opened on 2026-11-15; en.wikipedia is the page unless noted. Creators are added to `creators/gu.yaml` where missing.

| # | Medium | Title | Creator and year read | Page |
|---|---|---|---|---|
| 1 | film | Kanku | Kantilal Rathod, 1969; from Pannalal Patel's short story; won the National Film Award for Best Feature Film in Gujarati | Gujarati cinema |
| 2 | film | Liludi Dharati | Vallabh Choksi, 1968; from Chunilal Madia's novel; called the first colour Gujarati film | Gujarati cinema |
| 3 | film | Gharsansar | Krishnakant (KK), 1978 | Gujarati cinema |
| 4 | film | Bhavni Bhavai | Ketan Mehta, 1980; Gujarati; folklore-based satire from the Bhavai tradition | Bhavni Bhavai |
| 5 | film | Chhello Divas | Krishnadev Yagnik, 2015; comedy about eight college friends | Chhello Divas |
| 6 | film | Hellaro | Abhishek Shah, 2019; 1970s Kutch village, women and dance | Hellaro |
| 7 | film | The Good Road | Gyan Correa, 2013; India's Oscar entry, Gujarati, Kutch highway | The Good Road |
| 8 | film | Kevi Rite Jaish | Abhishek Jain, 2012; satire of Patel emigration to the U.S. | Kevi Rite Jaish |
| 9 | film | Bey Yaar | Abhishek Jain, 2014; Ahmedabad friends and a painting | Bey Yaar |
| 10 | film | Reva | Rahul Bhole and Vinit Kanojia, 2018; Narmada ashram | Reva (film) |
| 11 | film | Narsinh Mehta | 1932; first full-length Gujarati talkie, released 9 April 1932 | Gujarati cinema |
| 12 | film | Mena Gurjari | Dinesh Raval, 1975 | Gujarati cinema |
| 13 | novel | Malela Jeev | Pannalal Patel, 1941; Kanji and Jivi, lovers from different castes | Malela Jeev |
| 14 | novel | Saraswatichandra | Govardhanram Tripathi; volumes 1887, 1892, 1898, 1901 | Govardhanram Tripathi (Saraswatichandra is a disambiguation page that confirms it is a Gujarati novel) |
| 15 | novel | Tulsi-Kyaro | Zaverchand Meghani, 1940 | Jhaverchand Meghani (E page title) |
| 16 | biography | Manasai na Diva | Zaverchand Meghani, 1945 on the page's citation; won the Mahida Award in 1946 | Jhaverchand Meghani |
| 17 | book | Sorath, Tara Vaheta Pani | Zaverchand Meghani, 1937; fifth edition 2000 named on the page | gu.wikisource |
| 18 | stage | Mena Gurjari | Rasiklal Parikh, 1953; a Bhavai play | Bhavai |
| 19 | stage | Jasma Odan | written and directed by Shanta Gandhi; year not given on the page; Bhavai play from a folk tale | Bhavai |
| 20 | poem and state song | Jai Jai Garvi Gujarat | Narmad, 1873 on E | Narmad |

Reserve (read): film Malela Jeev (1956, Manhar Raskapur), Akhand Saubhagyavati (1963, first Gujarati film financed by the Film Finance Corporation), Ghar Jamai (1935, Homi Master), Manorama (1924, from Kalapi's poem Hridaya Triputi), novel Vevishal (Meghani, year not given). Dropped: a singer entry (the Hemu Gadhvi page did not exist under the title tried); "Mehndi Rang Lagyo" (the page names it only in a production list, with no year or director for it).

## Review

Everything is `unreviewed`. Each uncertain or dropped item is a row in the builder's report in the table shape of `docs/review-queue/gu.md`; GU-130 and the review-queue task collect the rows into that file.

Items for review, none of them in a deck until resolved:

- **Traditional songs without a year.** These gu.wikisource pages name an anonymous author and a scan but **no first-publication year**, so they cannot be shown to meet the "anonymous, before 1900" floor: અંબેમાની ચુંદડી (garba; scan "Garba.pdf", author "Unknown"), અમે ઈડરિયો ગઢ જીત્યા (wedding song; "Lagnageeto.pdf"), અચકો મચકો કાં રે લી (folk song, "Lokgeeto.pdf", author field "લોકગીત"), અડકો દડકો દહીં દડૂકો (children's rhyme, "Balgeeto.pdf"). The builder reads the scan's year; if it is before 1900 they move into GU-011.
- **Meghani's Halarda (1929)** and similar compilations: compiler died 1947, songs are traditional.
- **Mirabai's Gujarati pages** cite a bhajan anthology; en.wikipedia names no Gujarati poem of hers. Cards say "attributed to".
- **Death-year disagreements**: Narsinh Mehta (1481, 1488 or about 1493), Mirabai (1546 to 1548), Kalapi (E says uncertain), Karsandas Mulji (1871 or 1875).
- **Shamal Bhatt** has no death year on the page; **Vallabh Bhatt**'s years were not read.
- **Gandhi's આરોગ્યની ચાવી** page makes no public-domain statement (only the CC BY-SA text licence); the author died 1948.
- **Proverbs** are from a community-edited, unsourced wiki list.

## Dropped and open

Dropped because no page could be read to verify them: Mirabai's Gujarati-language poems on en.wikipedia (the page names none, so only the gu.wikisource pages support her); Narsinh Mehta "Vaishnav Jan To" as a deck item (named on E as his notable work and Gandhi's favourite, but no gu.wikisource page for it was read); the en.wikipedia pages `Premananda_Bhatt`, `Narhari_Dwarkadas_Parikh`, `Narasimharao_Divetia`, `Ramanarayan_V._Pathak`, `Manvi_Ni_Bhavai` and `Hemu_Gadhvi` (not found, and no substitute was read); Balwantray Thakore's Wikisource page (not found under the title tried); Mahipatram's and Karsandas's Gujarati prose texts (works named on E, no WS page read); the Wikimedia API's full page lists (rate-limited). Not planned here: professional decks (held for the owner's profession list), and a Gujarati quotation deck (no `quotation` items per the rules above).
