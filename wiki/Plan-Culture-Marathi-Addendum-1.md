# Plan: Marathi culture sourcing, addendum 1 (re-opened items)

Task MR-R1, written 2026-11-16 as an addendum to [Plan-Culture-Marathi](Plan-Culture-Marathi.md) (task MR-001 of [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md)). The owner's directive was that obvious gaps are work, not accepted shortfalls: before an item is dropped, every reachable source is tried. This page adds new **verified** rows to culture 1 (sant poets), culture 2 (folk) and culture 3 (modern), continuing the numbering of that page, and lists what was dropped and why. The rows of the first page that this page does not mention stand as written there.

## Result in one table

| Deck | Rows on the first page | New verified rows here | Reaches 18 |
|---|---|---|---|
| Culture 1, sant poets (MR-010) | 11 text pages, 12 works, chapter text unread | 21 (rows 19 to 39) | yes, 21 |
| Culture 2, folk (MR-011) | 4 works, 3 unverified | 18 (rows 10 to 27) | yes, 18 |
| Culture 3, modern (MR-012) | 8 verified, 9 conditional on Balkavi | 30 (rows 19 to 48) | yes, 30 |

The first 18 rows that pass are the deck and the rest are the reserve, as on the first page. **Balkavi's death year is settled: 5 May 1918** (see "Decisions"), so the nine conditional Balkavi rows of the first page are promoted and five more Balkavi poems are added.

## How this page was checked

Everything below was read on 2026-11-15 and 2026-11-16 from the live wikis through their public APIs, one host at a time with 13 seconds between requests and a 40 to 60 second wait before each retry after an HTTP 429. **A fact is on this page only if a named page said it; nothing was written from memory.** Excerpts were copied by script from the page text and the script asserted that each one occurs on the page and has at most 25 words. Whitespace runs (the wide gaps that mark a caesura on several pages) are collapsed to one space; the characters are otherwise exactly the page's, spelling included.

- **Rights banner.** The pages carry the template `{{प्रताधिकार मुक्त साहित्य}}`, which is in the category प्रताधिकार मुक्त साहित्य-भारत. The wording of the template itself (read on mr.wikisource, साचा:प्रताधिकार मुक्त साहित्य) says the work was made in India and is now free, that under the Indian Copyright Act 1957 a work becomes free 60 years after the author's death, and that all works of authors who died before 1 January 1956 are therefore free. That is the same floor as the first page (death 1955 or earlier). Most of these pages also carry the tags "no source" and "to be checked" (तपासणी करायचे साहित्य), so the banner is a claim the reviewer still owns; the death year read from an author page is the proof used here.
- **Authors.** Years come from the mr.wikisource author page (the `साहित्यिक:` namespace, template fields जन्मवर्ष and मृत्यूवर्ष), the Wikidata-built list "विकिस्रोत:समस्त लेखक (कॉपीराईट फ्री)" (a table of authors who died before 1962 with Wikidata dates), Wikidata itself, and en or mr Wikipedia. A conflict between pages is stated.
- **Everything in the banner category was scanned.** The category प्रताधिकार मुक्त साहित्य-भारत has 516 pages, of which 368 are the daily sermon pages of श्रीब्रह्मचैतन्य महाराजांची प्रवचने (no author page or death year was read for them, so they are not used). The other 148 titles were all read for author and date; the ones that matter are below.

## Hosts reached and blocked

| Host | Result |
|---|---|
| mr.wikisource.org | reached; the main source. HTTP 429 on the first requests of the run and now and then later; every request was retried after a pause |
| en.wikipedia.org, mr.wikipedia.org | reached |
| www.wikidata.org | reached (`wbgetentities` and `wbsearchentities`) |
| mr.wikiquote.org | reached; the search "बालकवी" and "अनंत फंदी" returned 0 pages |
| commons.wikimedia.org, en.wikisource.org | reached (HTTP 301 on the front page); no scan was needed |
| www.britannica.com | **blocked** (the agent proxy refused the connection, HTTP 403 on CONNECT) |
| archive.org | **blocked** (same refusal) |
| mr.wikibooks.org | **blocked** (no connection); it is where mr.wikisource's page "श्यामची आई" redirects to (`{{Redirect|mr:b:श्यामची आई}}`) |
| www.gutenberg.org, dsal.uchicago.edu, www.wikiwand.com, indianculture.gov.in, www.loc.gov | **blocked** (no connection) |
| sahitya-akademi.gov.in, marathivishwakosh.org | the proxy reported a refusal for these two hosts while this run was active; no request to them was made by the scripts of this task |

No national library, university or Britannica page could be reached, so no fact here rests on one.

## Decisions on the re-opened items

- **Changdev Pasashti is by Dnyaneshwar.** The page चांगदेव पासष्टी has the author field "ज्ञानेश्वर विठ्ठल कुलकर्णी"; the author page साहित्यिक:ज्ञानेश्वर is a redirect to साहित्यिक:ज्ञानेश्वर विठ्ठल कुलकर्णी (read: `#पुनर्निर्देशन`), and that page says "संत ज्ञानेश्वर (जन्म : इ.स. १२७५ - समाधी : इ.स. १२९६)" and lists the works ज्ञानेश्वरी, चांगदेव पासष्टी, हरिपाठ and अमृतानुभव (categories 1275 चा जन्म, 1296 चा मृत्यू). A second page of the same text, चांगदेवपासष्टी, has the author field "ज्ञानेश्वर", and its last ovi ends "ज्ञानदेवो म्हणे ॥ ६५ ॥" (the poet's own signature). So "Dnyaneshwar Vitthal Kulkarni" is Dnyaneshwar, Vitthalpant's son named in the Marathi style, and the creator is written `Dnyaneshwar`.
- **Balkavi died 5 May 1918.** Four pages agree: Wikidata Q55739 (born 1890-08-13, died 1918-05-05; also year-precision values 1890 and 1918), en.wikipedia "Trimbak Bapuji Thombre" (reached by redirect from "Balkavi": "13 August 1890 – 5 May 1918"), mr.wikipedia त्र्यंबक बापूजी ठोंबरे (reached by redirect from "बालकवी": "१३ ऑगस्ट १८९० - ५ मे १९१८"), and the mr.wikisource author page साहित्यिक:त्र्यंबक बापूजी ठोंबरे (Dates 1890-1918; साहित्यिक:बालकवी also says 1890 and 1918). The "?" read on the first page was a different author page. The rights floor is met. The poem pages carry the banner and the tag "no source"; the builder cites the Wikisource page as the edition.
- **Gadkari and Govindagraj are one person with working pages.** Poems by him exist under the titles in rows 36 to 38 below (author field "राम गणेश गडकरी"; the last lines of two of them are signed 'गोविंदाग्रज'). The author page and en.wikipedia give 26 May 1885 to 23 January 1919. The play "वेद्याचा बाजार" is still not found.
- **Savarkar fails.** Vinayak Damodar Savarkar's en.wikipedia page says "28 May 1883 – 26 February 1966". He is out. (Narayan Damodar Savarkar, 1888 to 1949 on the author list, has no work page in the banner category.)
- **Honaji Bala (shahir).** mr.wikipedia and en.wikipedia say 1754 to 1844 and Wikidata Q13122397 has the years 1754 and 1844 (the mr.wikisource author page has "?" for both). The page घनश्याम श्रीधराची भूपाळी opens with "शाहीर होनाजी बाळा यांनी श्रीकृष्णाला उठविण्यासाठी ही भूपाळी रचलेली आहे", and mr.wikipedia says this bhupali became "अजरामर" (immortal) in Marathi culture. This is the only one of the 14 bhupali pages that names an author.

## Authors used (years and where read)

| Creator | Born, died | Where read |
|---|---|---|
| Dnyaneshwar | 1275 to 1296 | mr.wikisource author page (redirect above); Wikidata Q1033695 (1275, 1296) |
| Namdev | traditionally c. 26 Oct 1270 to c. 3 Jul 1350 | mr.wikisource साहित्यिक:नामदेव दामाजी रेळेकर (1270, 1350; "जन्म:- २६ आक्टोबर १२७०"); en.wikipedia "Namdev" (the same traditional dates, details "unclear") |
| Eknath | 1533 to 1599 | mr.wikisource author page; Wikidata Q2587826; the first page gave 1533 to 25 Feb 1600 (en.wikipedia), so write `circa` |
| Samarth Ramdas | 1608 to 1681 | Wikidata Q55780; the authors list; the first page gave c. 1608 to 1682 (en.wikipedia), so write `circa` |
| Tukaram | 1608 to 1650 | Wikidata Q468361; the authors list; the first page gave 1598 or 1608 to 1649 or 1650 (en.wikipedia), so write `circa` |
| Honaji Bala | 1754 to 1844 | mr.wikipedia होनाजी बाळा; en.wikipedia "Honaji Bala"; Wikidata Q13122397 |
| Jyotirao Phule | 11 Apr 1827 to 28 Nov 1890 | first page, row 2 (en.wikipedia "Jyotirao Phule"); not re-read here. The page तृतीय रत्न gives "सन १८५५" and the author field "जोतीराव गोविंदराव फुले" |
| Bahinabai Chaudhari | 1880 to 1951 (24 Aug 1880 to 3 Dec 1951 on the list) | mr.wikisource साहित्यिक:बहिणाबाई चौधरी (1880, 1951); the authors list |
| Sane Guruji | 24 Dec 1899 to 11 Jun 1950 | mr.wikisource साहित्यिक:पांडुरंग सदाशिव साने (1899, 1950); Wikidata Q55769 |
| Balkavi | 13 Aug 1890 to 5 May 1918 | see Decisions |
| Keshavsut | 1866 to 7 Nov 1905 | mr.wikisource साहित्यिक:केशवसुत (1866, 1905); Wikidata Q3633220 (7 Oct 1866, 7 Nov 1905); the list gives 15 Mar 1866 for the birth day, a conflict in the day only |
| Bhaskar Ramchandra Tambe | 1873 or 1874 to 1941 | author page 1873 (birth), the authors list 1874 to 1941; the birth years conflict, the death year does not |
| Ram Ganesh Gadkari | 26 May 1885 (24 May on the list) to 23 Jan 1919 | author page (1885, 1919); en.wikipedia "Ram Ganesh Gadkari"; the authors list |
| Shripad Krishna Kolhatkar | 29 Jun 1871 to 1934 | author page साहित्यिक:श्रीपाद कृष्ण कोल्हटकर (1871, 1934, "जून २९, १८७१ - १९३४"); the page names "बहु असोत सुंदर" as his song |
| Krishnaji Prabhakar Khadilkar | 25 Nov 1872 to 26 Aug 1948 | the authors list; each of the five song pages says "कृष्णाजी प्रभाकर खाडिलकर (१८७२ - १९४८) ह्यांचा १९११ सालातल्या संगीत मानापमान मधील हे पद" |
| Bal Gangadhar Tilak | 23 Jul 1856 to 1 Sep 1920 | the authors list (row for साहित्यिक:बाळ गंगाधर टिळक); the page's note says the lecture was given 7 September 1906 |

The first page's Phule row says "PD by death in 1890"; nothing here changes it. For the Stri-Jeevan songs (anonymous, collected), the rights basis is the collector's death (Sane, 1950) and the 1940 print named on the page, as on the first page, row 1.

## Source pages

All on mr.wikisource.org. "Rights banner" is what the page itself carries; "Author field" is the शीर्ष template field साहित्यिक and the year field where the page has one. A page without a banner is marked.

| Key | Page | Link | Revision read | Author field | Rights banner on the page |
|---|---|---|---|---|---|
| P1 | पसायदान | [page](https://mr.wikisource.org/wiki/पसायदान) | 2023-05-21T18:50:47Z | ज्ञानेश्वर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| P2 | चांगदेवपासष्टी | [page](https://mr.wikisource.org/wiki/चांगदेवपासष्टी) | 2022-09-09T18:07:42Z | ज्ञानेश्वर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| P3 | ज्ञानेश्वरी/अध्याय पहिला | [page](https://mr.wikisource.org/wiki/ज्ञानेश्वरी/अध्याय_पहिला) | 2024-12-23T13:50:57Z | संत ज्ञानेश्वर (year १२९०) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| P4 | नामदेव अभंगगाथा | [page](https://mr.wikisource.org/wiki/नामदेव_अभंगगाथा) | 2023-04-08T12:28:01Z | नामदेव | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| P5 | भावार्थ रामायण/अध्याय पहिला | [page](https://mr.wikisource.org/wiki/भावार्थ_रामायण/अध्याय_पहिला) | 2022-09-09T18:16:39Z | (blank) | none on the chapter page; its parent page `भावार्थ रामायण` carries category प्रताधिकार मुक्त साहित्य-भारत and author field एकनाथ |
| P6 | करुणाष्टके | [page](https://mr.wikisource.org/wiki/करुणाष्टके) | 2023-05-21T18:17:57Z | रामदास स्वामी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| P7 | उत्तम गुण | [page](https://mr.wikisource.org/wiki/उत्तम_गुण) | 2023-05-21T18:22:24Z | रामदास स्वामी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| P8 | शिवराजास आठवावें | [page](https://mr.wikisource.org/wiki/शिवराजास_आठवावें) | 2022-11-14T10:28:02Z | रामदास स्वामी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| P9 | तुकाराम गाथा/गाथा १ ते ३०० | [page](https://mr.wikisource.org/wiki/तुकाराम_गाथा/गाथा_१_ते_३००) | 2022-09-06T14:12:52Z | तुकाराम | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| P10 | सवाई | [page](https://mr.wikisource.org/wiki/सवाई) | read 2026-11-16 | (blank) | tag "no source"; tag "to be checked" |
| P11 | चतुर्दश मारूती स्तोत्रे | [page](https://mr.wikisource.org/wiki/चतुर्दश_मारूती_स्तोत्रे) | read 2026-11-16 | (blank) | tag "no source"; tag "to be checked" |
| F1 | घनश्याम श्रीधराची भूपाळी | [page](https://mr.wikisource.org/wiki/घनश्याम_श्रीधराची_भूपाळी) | 2022-09-09T18:06:40Z | (blank) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F2 | छत्रपति शिवाजी राजे भोसले यांचा पवाडा | [page](https://mr.wikisource.org/wiki/छत्रपति_शिवाजी_राजे_भोसले_यांचा_पवाडा) | 2022-06-03T05:34:54Z | (blank) | none on the page |
| F3 | सुगरणीचा खोपा | [page](https://mr.wikisource.org/wiki/सुगरणीचा_खोपा) | 2026-06-11T14:10:49Z | बहिणाबाई चौधरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F4 | अरे संसार संसार | [page](https://mr.wikisource.org/wiki/अरे_संसार_संसार) | 2026-06-11T14:09:52Z | बहिणाबाई चौधरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F5 | आला पह्यला पाऊस | [page](https://mr.wikisource.org/wiki/आला_पह्यला_पाऊस) | 2026-06-11T14:09:58Z | बहिणाबाई चौधरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F6 | कशाला काय म्हणूं नही? | [page](https://mr.wikisource.org/wiki/कशाला_काय_म्हणूं_नही%3F) | 2026-06-11T14:10:04Z | बहिणाबाई चौधरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F7 | देव अजब गारोडी | [page](https://mr.wikisource.org/wiki/देव_अजब_गारोडी) | 2026-06-11T14:10:27Z | बहिणाबाई चौधरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| F8 | स्त्री-जीवन/बहिणभाऊ | [page](https://mr.wikisource.org/wiki/स्त्री-जीवन/बहिणभाऊ) | 2026-07-31T07:41:46Z (rendered text) | साने गुरुजी (year 1940) | none on the page (Stri-Jeevan 1940 print; see note) |
| F9 | स्त्री-जीवन/मायलेकरें | [page](https://mr.wikisource.org/wiki/स्त्री-जीवन/मायलेकरें) | 2026-07-31T07:41:48Z (rendered text) | साने गुरुजी (year 1940) | none on the page (Stri-Jeevan 1940 print; see note) |
| F10 | स्त्री-जीवन/मुलगी | [page](https://mr.wikisource.org/wiki/स्त्री-जीवन/मुलगी) | 2026-07-31T07:41:50Z (rendered text) | साने गुरुजी (year 1940) | none on the page (Stri-Jeevan 1940 print; see note) |
| F11 | स्त्री-जीवन/सुखदुःखाचे अनुभव | [page](https://mr.wikisource.org/wiki/स्त्री-जीवन/सुखदुःखाचे_अनुभव) | 2026-07-31T07:41:51Z (rendered text) | साने गुरुजी (year 1940) | none on the page (Stri-Jeevan 1940 print; see note) |
| M1 | आनंदी आनंद गडे | [page](https://mr.wikisource.org/wiki/आनंदी_आनंद_गडे) | 2026-06-11T14:09:53Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M2 | निर्झरास | [page](https://mr.wikisource.org/wiki/निर्झरास) | 2026-06-11T14:10:30Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M3 | ती फुलराणी | [page](https://mr.wikisource.org/wiki/ती_फुलराणी) | 2026-06-11T14:10:22Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M4 | प्रीति हवी तर | [page](https://mr.wikisource.org/wiki/प्रीति_हवी_तर) | 2026-06-11T14:10:32Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M5 | शून्य मनाचा घुमट | [page](https://mr.wikisource.org/wiki/शून्य_मनाचा_घुमट) | 2026-06-11T14:10:45Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M6 | औदुंबर | [page](https://mr.wikisource.org/wiki/औदुंबर) | 2026-06-11T14:10:10Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M7 | कोठुनि येते मला कळेना | [page](https://mr.wikisource.org/wiki/कोठुनि_येते_मला_कळेना) | 2026-06-11T14:10:09Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M8 | घरटा | [page](https://mr.wikisource.org/wiki/घरटा) | 2026-06-11T14:10:19Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M9 | अनंत | [page](https://mr.wikisource.org/wiki/अनंत) | 2026-06-11T14:09:50Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M10 | गाणाऱ्या पक्ष्यास | [page](https://mr.wikisource.org/wiki/गाणाऱ्या_पक्ष्यास) | 2026-06-11T14:10:18Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M11 | दोष असती जगतात किती याचे | [page](https://mr.wikisource.org/wiki/दोष_असती_जगतात_किती_याचे) | 2026-06-11T14:10:28Z | बालकवी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M12 | तुतारी | [page](https://mr.wikisource.org/wiki/तुतारी) | 2026-06-11T14:10:24Z | केशवसुत | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M13 | आम्ही कोण? | [page](https://mr.wikisource.org/wiki/आम्ही_कोण%3F) | 2026-06-11T14:09:55Z | केशवसुत (year १९०१) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M14 | तुझे नाम मुखी | [page](https://mr.wikisource.org/wiki/तुझे_नाम_मुखी) | 2026-06-11T14:10:23Z | केशवसुत | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M15 | रांगोळी घालतांना पाहून | [page](https://mr.wikisource.org/wiki/रांगोळी_घालतांना_पाहून) | 2026-06-11T14:10:42Z | केशवसुत | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M16 | जन पळभर म्हणतील, हाय हाय | [page](https://mr.wikisource.org/wiki/जन_पळभर_म्हणतील,_हाय_हाय) | 2026-06-11T14:10:20Z | भास्कर रामचंद्र तांबे | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| M17 | तीनी सांजा सखे, मिळाल्या, देई वचन तुला | [page](https://mr.wikisource.org/wiki/तीनी_सांजा_सखे,_मिळाल्या,_देई_वचन_तुला) | 2026-06-11T14:10:22Z | [[भास्कर रामचंद्र तांबे)]] | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| M18 | शिवरायांचा पाळणा | [page](https://mr.wikisource.org/wiki/शिवरायांचा_पाळणा) | 2022-09-09T18:23:07Z | राम गणेश गडकरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M19 | केशवसुत मेले? | [page](https://mr.wikisource.org/wiki/केशवसुत_मेले%3F) | 2026-06-11T14:10:06Z | राम गणेश गडकरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M20 | केशवसुतांची कविता वाचून | [page](https://mr.wikisource.org/wiki/केशवसुतांची_कविता_वाचून) | 2026-06-11T14:10:07Z | राम गणेश गडकरी | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M21 | बहु असोत सुंदर | [page](https://mr.wikisource.org/wiki/बहु_असोत_सुंदर) | 2019-01-21T10:48:27Z | श्रीपादकृष्ण कोल्हटकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत |
| M22 | खरा तो प्रेमा ना धरी लोभ मनी | [page](https://mr.wikisource.org/wiki/खरा_तो_प्रेमा_ना_धरी_लोभ_मनी) | 2026-06-11T14:10:17Z | कृष्णाजी प्रभाकर खाडिलकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M23 | रवि मी | [page](https://mr.wikisource.org/wiki/रवि_मी) | 2026-06-11T14:10:41Z | कृष्णाजी प्रभाकर खाडिलकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M24 | मला मदन भासे हा | [page](https://mr.wikisource.org/wiki/मला_मदन_भासे_हा) | 2026-06-11T14:10:37Z | कृष्णाजी प्रभाकर खाडिलकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M25 | युवतिमना दारुण रण | [page](https://mr.wikisource.org/wiki/युवतिमना_दारुण_रण) | 2026-06-11T14:10:40Z | कृष्णाजी प्रभाकर खाडिलकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M26 | शूरा मी वंदिले | [page](https://mr.wikisource.org/wiki/शूरा_मी_वंदिले) | 2026-06-11T14:10:46Z | कृष्णाजी प्रभाकर खाडिलकर | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M27 | बलसागर भारत होवो | [page](https://mr.wikisource.org/wiki/बलसागर_भारत_होवो) | 2019-01-21T10:48:26Z | पांडुरंग सदाशिव साने | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत |
| M28 | स्वभाषेची अभिवृद्धी | [page](https://mr.wikisource.org/wiki/स्वभाषेची_अभिवृद्धी) | 2022-09-09T18:33:58Z | बाळ गंगाधर टिळक (year १९०६) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |
| M29 | तृतीय रत्न | [page](https://mr.wikisource.org/wiki/तृतीय_रत्न) | 2022-06-03T05:34:53Z | जोतीराव गोविंदराव फुले (year १८५५) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "to be checked" |
| M30 | जन्मभूमीचा त्याग | [page](https://mr.wikisource.org/wiki/जन्मभूमीचा_त्याग) | 2022-09-09T18:08:08Z | पांडुरंग सदाशिव साने (year १९४१) | `{{प्रताधिकार मुक्त साहित्य}}`; category प्रताधिकार मुक्त साहित्य-भारत; tag "no source"; tag "to be checked" |

Notes on three sources. **P5** (Bhavartha Ramayan chapter 1) has the heading "॥ श्रीएकनाथमहाराजकृत ॥" and no banner of its own. **F2** (Phule's powada) has no author field and no banner: its author is given only by the category वर्ग:जोतिराव फुले and by the neighbouring page तृतीय रत्न, whose "पुढील" link points to it; the first page already said so. **F8 to F11** (Stri-Jeevan chapters 1 to 4) are transcluded from a scanned 1940 print, so their text was read from the rendered page, not the wikitext.

## Culture 1: sant poets, new rows (MR-010)

The rows continue after row R5 of the first page. Creators are in the table above.

| # | Creator | Work | Excerpt (verbatim, at most 25 words; ` / ` marks a line break on the page) | Words | Source | Note |
|---|---|---|---|---|---|---|
| 19 | Dnyaneshwar | Pasayadan | आतां विश्वात्मके देवे, येणे वाग्यज्ञे तोषावे, / तोषोनि मज द्यावे, पसायदान हे \|\|१\|\| | 12 | P1 |  |
| 20 | Dnyaneshwar | Pasayadan | जे खळांचि व्यंकटी सांडो, तया सत्कर्मी रती वाढो, / भूतां परस्परे जडो, मैत्र जीवांचे \|\|२\|\| | 14 | P1 |  |
| 21 | Dnyaneshwar | Changdev Pasashti, ovi 1 | स्वस्ति श्री वटेशु । जो लपोनि जगदाभासु । दावी मग ग्रासु । प्रगटला करी ॥ १ ॥ | 17 | P2 |  |
| 22 | Dnyaneshwar | Changdev Pasashti, ovi 3 | बहु जन्व जंव होये । तंव तंव कांहींच न होये । कांहीं नहोनि आहे । अवघाचि जो ॥ ३ ॥ | 20 | P2 |  |
| 23 | Dnyaneshwar | Dnyaneshwari, ch. 1, opening | ॐ नमोजी आद्या । वेद प्रतिपाद्या । / जय जय स्वसंवेद्या । आत्मरुपा ॥१॥ | 13 | P3 |  |
| 24 | Dnyaneshwar | Dnyaneshwari, ch. 1, ovi 3 | हें शब्दब्रह्म अशेष \| तेचि मूर्ति सुवेष \| / तेथ वर्णवपु निर्दोष \| मिरवत असे \|\|३\|\| | 15 | P3 |  |
| 25 | Namdev | Namdev Abhangagatha, abhang 9 | क्षीरसागरांत अससीं बैसला । धांवोनी मजला भेटी देई ॥१॥ कैलासीचा शिव पूजितो तुजला । धांवोनी मजला भेटी देई ॥२॥ | 19 | P4 |  |
| 26 | Namdev | Namdev Abhangagatha, abhang 10 | चक्रवाक पक्षी वियोगें बहाती । झालें मजप्रती तैसें आतां ॥१॥ चुकलिया माय बाळकें रडती । झालें मजप्रती तैंसे आतां ॥२॥ | 20 | P4 |  |
| 27 | Namdev | Namdev Abhangagatha, abhang 12 | न वर्णवे वाचें जन्ममरण दु:ख । दावी आतां मुख पांडुरंगा ॥१॥ कुरळा केश भाळीं शोभे तो टिळक । दावीं आतां मुख पांडुरंगा ॥२॥ | 23 | P4 |  |
| 28 | Eknath | Bhavartha Ramayan, Balakand, ch. 1, Ganesh vandan | ॐ नमो अनादि आद्या । वेदवेदांतवेद्या । / वंद्यांही परमवंद्या । स्वसंवेद्या श्रीगणेशा ॥ १ ॥ | 15 | P5 |  |
| 29 | Eknath | Bhavartha Ramayan, Balakand, ch. 1, ovi 3 | यालागीं जैसा अससी तैसियासी । नमन साकार निराकारासी । / तंव अंगत्व मुकले अंगासी । भज्यभजकासी अद्वैत ॥ ३ ॥ | 19 | P5 |  |
| 30 | Samarth Ramdas | Karunashtake, verse 1 | अनुदिन अनुतापें तापलों रामराया । / परमदिनदयाळा नीरसी मोहमाया ॥ | 9 | P6 |  |
| 31 | Samarth Ramdas | Karunashtake, verse 2 | भजनरहित रामा सर्वही जन्म गेला । / स्वजनजनधनाचा व्यर्थ म्यां स्वार्थ केला ॥ | 12 | P6 |  |
| 32 | Samarth Ramdas | Uttam Gun, verse 2 | वाट पुसल्याविण जाउ नये। फळ ओळखल्याविण खाऊ नये॥ / पडिली वस्तु घेऊ नये। येकायेकी॥२॥ | 13 | P7 |  |
| 33 | Samarth Ramdas | Uttam Gun, verse 3 | विचारेविण बोलो नये। विवंचनेविण चालो नये॥ / मर्यादेविण हालो नये। काही येक॥३॥ | 11 | P7 |  |
| 34 | Samarth Ramdas | Shivrajas Athavave, verse 1 | अखंड सावधान असावे\| दुश्चित कदापि नसावे\| तजविजा करीत बसावे\| एकांत स्थळी\|\|१\|\| | 11 | P8 |  |
| 35 | Samarth Ramdas | Shivrajas Athavave, verse 4 | पाटवणी तुंब निघेना\| तरी मग पाणी चालेना\| तैसे सज्जनांच्या मना\| कळले पाहिजे\|\|४\|\| | 12 | P8 |  |
| 36 | Tukaram | Tukaram Gatha, abhang 1 | समचरणदृष्टि विटेवरी साजिरी । तेथें माझी हरी वृत्ति राहो ॥१॥ / आणीक न लगे मायिक पदार्थ । तेथें माझें आर्त्त नको देवा ॥ध्रु.॥ | 22 | P9 |  |
| 37 | Tukaram | Tukaram Gatha, abhang 2 | सुंदर तें ध्यान उभे विटेवरी । कर कटावरी ठेवूनियां ॥१॥ / तुळसीचे हार गळां कासे पीतांबर । आवडे निरंतर तें चि रूप ॥ध्रु.॥ | 22 | P9 |  |
| 38 | Samarth Ramdas | Savai | तुझा भाट मी वर्णितो रामराया । / सदा सर्वदा गाय ब्रीदे सवाया ।। | 12 | P10 | no rights banner on the page; floor met by the author's death year |
| 39 | Samarth Ramdas | Chaturdash Maruti Stotre, verse 1 | वनारी अंजनीसूता रामदूता प्रभंजना ॥१॥ / महाबली प्राणदाता सकळां ऊठवी बळें । | 11 | P11 | no rights banner on the page; floor met by the author's death year |

Rows 38 and 39 are on pages without the banner; the author's death year (1681) carries the rights floor, and the builder cites the author page.

## Culture 2: folk, new rows (MR-011)

Rows continue after row 9 of the first page. Rows 10 to 12 are a named shahir's bhupali, rows 13 to 15 a named poet's powada, rows 16 to 22 Bahinabai Chaudhari's poems in ovi-style folk Marathi, and rows 23 to 27 oral women's songs collected by Sane Guruji (the card names Sane as `author` and says "collected by").

| # | Creator | Work | Excerpt (verbatim, at most 25 words; ` / ` marks a line break on the page) | Words | Source | Note |
|---|---|---|---|---|---|---|
| 10 | Honaji Bala | Bhupali: Ghanashyam Sundara Shridhara | घनश्याम सुंदरा श्रीधरा अरुणोदय झाला । / उठीं लवकरि वनमाळी । उदयाचळीं मित्र आला ॥ ध्रु ॥ | 16 | F1 |  |
| 11 | Honaji Bala | Bhupali: Ghanashyam Sundara Shridhara, verse 1 | सायंकाळी एके मेळीं द्विजगण अवघे वृक्षीं । / अरुणोदय होतांचि उडाले चरावया पक्षी । | 13 | F1 |  |
| 12 | Honaji Bala | Bhupali: Ghanashyam Sundara Shridhara, verse 2 | घरोघरी दीप अखंड त्यांच्या सरसावुनि वाती । / गीत गाति सप्रेमें गोपी सदना येति जाती ॥ | 15 | F1 |  |
| 13 | Jyotirao Phule | Powada on Shivaji, opening | कुळवाडी - भुषण पवाडा गातो भोसल्याचा \| / छत्रपती शिवाजीचा \|\| | 10 | F2 |  |
| 14 | Jyotirao Phule | Powada on Shivaji, birth of Shivaji | शिवनेरी किल्ल्यामध्ये बाळ शिवाजी जन्मले \| / जिजाबाईस रत्न सापडले \|\| | 10 | F2 |  |
| 15 | Jyotirao Phule | Powada on Shivaji, the infant | सानकटी सिंहापरी छाती मांस दुनावले \| / नांव शिवाजी शोभले \|\| | 10 | F2 |  |
| 16 | Bahinabai Chaudhari | Sugaranicha Khopa | अरे खोप्यामधी खोपा / सुगरणीचा चांगला / देखा पिलासाठी तिनं / झोका झाडाले टांगला \|\|१\|\| | 12 | F3 |  |
| 17 | Bahinabai Chaudhari | Are Sansar Sansar | अरे संसार संसार, जसा तवा चुल्ह्यावर, / आधी हाताला चटके, तेव्हा मिळते भाकर । | 13 | F4 |  |
| 18 | Bahinabai Chaudhari | Are Sansar Sansar, verse 2 | अरे संसार संसार, होटा कधी म्हनू नाही / राउळीच्या कयसाले, लोटा कधी म्हनू नाही । | 14 | F4 |  |
| 19 | Bahinabai Chaudhari | Aala Pahyala Paus | आला पह्यला पाऊस / शिपडली भुई सारी / धरत्रीचा परमय / माझं मन गेलं भरी | 12 | F5 |  |
| 20 | Bahinabai Chaudhari | Aala Pahyala Paus, verse 2 | आला पाऊस पाऊस / आतां सरीवर सरी / शेतं शिवारं भिजले / नदी नाले गेले भरी | 13 | F5 |  |
| 21 | Bahinabai Chaudhari | Kashala Kay Mhanu Nahi | बिना कपाशीनं उले / त्याले बोंड म्हनूं नहीं / हरी नामाईना बोले / त्याले तोंड म्हनूं नहीं | 14 | F6 |  |
| 22 | Bahinabai Chaudhari | Dev Ajab Garodi | धरत्रीच्या कुशीमधीं / बीयबियानं निजलीं / वर्‍हे पसरली माटी / जशी शाल पांघरली | 10 | F7 |  |
| 23 | Sane Guruji (compiler) | Stri-Jeevan, ch. 1, brother songs | नको धन नको मुद्रा नको मोतियाचे हार / देई प्रेमाश्रूंची धार भाईराया ॥ | 12 | F8 |  |
| 24 | Sane Guruji (compiler) | Stri-Jeevan, ch. 1, brother songs | येरे येरे भाऊ किती झाले दडपण / कधी हृदय उघडीन तुझ्यापुढें ॥ | 11 | F8 |  |
| 25 | Sane Guruji (compiler) | Stri-Jeevan, ch. 2, mother and child songs | माझें तान्हे बाळ देवाचें मंगल / अमृताचें फळ संसाराचें ॥ | 9 | F9 |  |
| 26 | Sane Guruji (compiler) | Stri-Jeevan, ch. 3, daughter songs | कन्या झाली म्हणुन नको करूं हेळसांड / गोपूबाळाच्या शेजारी उषाताईचा पाट मांड ॥ | 12 | F10 |  |
| 27 | Sane Guruji (compiler) | Stri-Jeevan, ch. 4, joys and sorrows | सासरी सासुरवास माहेरी माहेरवास / सत्तेचा परी घास सासऱ्यास ॥ | 9 | F11 |  |

## Culture 3: modern prose, verse and theatre, new rows (MR-012)

Rows continue after row R7 of the first page. Rows 19 to 29 are Balkavi (six pages named on the first page, re-read here, and five new ones), rows 30 to 33 Keshavsut (the first page lists seven of his pages; these four are the ones re-read), 34 and 35 Tambe, 36 to 38 Gadkari, 39 Kolhatkar, 40 to 44 Khadilkar, and 45 to 48 Sane Guruji's song "Balsagar Bharat Hovo", then prose and theatre from Tilak, Phule and Sane Guruji.

| # | Creator | Work | Excerpt (verbatim, at most 25 words; ` / ` marks a line break on the page) | Words | Source | Note |
|---|---|---|---|---|---|---|
| 19 | Balkavi | Anandi Anand Gade | आनंदी आनंद गडे, इकडे तिकडे चोहिकडे \|\| धृ.\|\| | 8 | M1 |  |
| 20 | Balkavi | Nirjharas | गिरिशिखरे, वनमालाही दरीदरी घुमवित येई / कड्यावरुनि घेऊन उड्या खेळ लतावलयी फुगड्या | 11 | M2 |  |
| 21 | Balkavi | Ti Phulrani | हिरवे हिरवेगार गालिचे, हरित तृणाच्या मखमालीचे; / त्या सुंदर मखमालीवरती, फुलराणी ही खेळत होती. | 13 | M3 |  |
| 22 | Balkavi | Preeti Havi Tar | प्रीति हवी तर जीव आधि कर अपुला कुरबान, / प्रीति हवी तर तळहातावर घे कापुनि मान ! | 16 | M4 |  |
| 23 | Balkavi | Shunya Manacha Ghumat | शून्य मनाच्या घुमटांत / कसलें तरि घुमतें गीत; / अर्थ कळेना कसलाही, / विश्रांती परि त्या नाहीं; | 14 | M5 |  |
| 24 | Balkavi | Audumbar | ऐल तटावर पैल तटावर हिरवाळी घेउन / निळासावळा झरा वाहतो बेटांबेटांतुन. | 10 | M6 |  |
| 25 | Balkavi | Kothuni Yete Mala Kalena | कोठुनि येते मला कळेना / उदासीनता ही हृदयाला / काय बोचते ते समजेना / हृदयाच्या अंतर्हृदयाला ।। | 14 | M7 |  |
| 26 | Balkavi | Gharta | चिव चिव चिव रे / तिकडे तू कोण रे ? / कपिलामावशी कपिलामावशी / घरटा मोडून तू का जाशी ? | 17 | M8 |  |
| 27 | Balkavi | Anant | अनंत तारा नक्षत्रे ही अनंत या गगनात / अनंत दीप्ती, अनंत वसुधा, हे शशिसूर्य अनंत. | 14 | M9 |  |
| 28 | Balkavi | Ganarya Pakshyas | समय रात्रीचा कोण हा भयाण! / बळे गर्जे हे त्यांत घोर रान. / अशा समयी छबुकड्या पाखरा तू, / गात अससी; बा काय तुझा हेतू? | 22 | M10 |  |
| 29 | Balkavi | Dosh Asati Jagatat Kiti Yache | दोष असती जगतात किती याचे / नसे मजला सामर्थ्य गणायाचे, / दोष माझा परि हाच मला वाटे / दोष बघता सत्प्रेम कसे आटे? | 20 | M11 |  |
| 30 | Keshavsut | Tutari | एक तुतारी द्या मज आणुनि / फुंकिन मी जी स्वप्राणाने / भेदुनि टाकिन सगळी गगनें / दीर्घ जिच्या त्या किंकाळीने | 17 | M12 |  |
| 31 | Keshavsut | Amhi Kon? | आम्ही कोण म्हणूनि काय पुससी? आम्ही असू लाडके / देवाचे दिधले असे जग तये आम्हांस खेळावया; | 15 | M13 |  |
| 32 | Keshavsut | Tujhe Naam Mukhi | तुझे नाम मुखी ध्यान तुझे डोळा / व्रुत्ती या चंचळा स्थिरावल्या॥ | 10 | M14 |  |
| 33 | Keshavsut | Rangoli Ghalatana Pahun | होते अंगण गोमये सकलही संमार्जिले सुंदर, / बालार्के अपुली प्रभा वितरली नेत्रोत्सवा त्यावर; | 12 | M15 |  |
| 34 | Bhaskar Ramchandra Tambe | Jan Palbhar Mhanatil, Haay Haay | जन पळभर म्हणतील, 'हाय हाय!' / मी जातां राहील कार्य काय।। / सूर्य तळपतील चंद्र झळकतील। / तारे अपुला क्रम आचरतील।। | 18 | M16 |  |
| 35 | Bhaskar Ramchandra Tambe | Teeni Sanja Sakhe | तीनी सांजा सखे, मिळाल्या, देई वचन तुला / आजपासुनी जिवे अधिक तू माझ्या हृदयाला | 13 | M17 |  |
| 36 | Ram Ganesh Gadkari (Govindagraj) | Shivrayancha Palna | गुणी बाळ असा जागसि का रे वांया \| नीज रे नीज शिवराया / अपरात्री प्रहर लोटला बाई \| तरि डोळा लागत नाही \|\| | 22 | M18 |  |
| 37 | Ram Ganesh Gadkari (Govindagraj) | Keshavsut Mele? | जगतास जागवायाला केशवसुत गाउनि गेले ! / इंग्लंद भूमि शेलेची माहेर जडाचें बनले, | 12 | M19 |  |
| 38 | Ram Ganesh Gadkari (Govindagraj) | Keshavsutanchi Kavita Vachun | शिवरायाच्या मागें आम्ही लालमहालीं फिरणें / तसेंच तुमच्या मागें आम्ही नवीन कविता करणें / असेंच कांही कांही करुनी जीवित त्याला गणणें / 'गोविंदाग्रज' म्हणे असे हे आम्हां लाजिरवाणें | 25 | M20 |  |
| 39 | Shripad Krishna Kolhatkar | Bahu Asot Sundar | बहु असोत सुंदर संपन्‍न की महा / प्रिय अमुचा एक महाराष्ट्र देश हा / गगनभेदि गिरिविण अणु नच जिथे उणे / आकांक्षांपुढति जिथे गगन ठेंगणे | 22 | M21 |  |
| 40 | Krishnaji Prabhakar Khadilkar | Manapaman: Khara To Prema | खरा तो प्रेमा ना धरी लोभ मनी ॥ / नभि जनहितरत भास्कर तापत / विकसत पहा नलिनी ॥ | 16 | M22 |  |
| 41 | Krishnaji Prabhakar Khadilkar | Manapaman: Ravi Mi | रवि मी, हा चंद्र कसा मग मिरवितसे लावित पिसे ॥ | 10 | M23 |  |
| 42 | Krishnaji Prabhakar Khadilkar | Manapaman: Mala Madan Bhase Ha | मला मदन भासे हा मोही मना । / मानी जना या भामामना ॥ | 12 | M24 |  |
| 43 | Krishnaji Prabhakar Khadilkar | Manapaman: Yuvatimana Darun Ran | युवतिमना दारुण रण रूचिर प्रेमसे झाले । / रणभजना संसारी असे अमर मी केले ॥ | 14 | M25 |  |
| 44 | Krishnaji Prabhakar Khadilkar | Manapaman: Shura Mi Vandile | शूरा मी वंदिले । / धारातीर्थी तप जे आचरती । / सेनापति यश याचि बले ॥ | 14 | M26 |  |
| 45 | Sane Guruji | Balsagar Bharat Hovo | बलसागर भारत होवो, विश्वात शोभुनी राहो / हे कंकण करि बांधियले, जनसेवे जीवन दिधले | 13 | M27 |  |
| 46 | Bal Gangadhar Tilak | Svabhashechi Abhivriddhi (lecture, 7 Sep 1906) | मराठी ही आमची भाषा आहे. आमचे वाडवडील ती बोलत आले, त्या भाषेतच आमचा जन्म झाला, म्हणून ती चांगली अगर वाईट हा विचार आम्हांस नाहीं. | 24 | M28 | prose |
| 47 | Jyotirao Phule | Tritiya Ratna (play, 1855) | बाई : महाराज, काय? काय झाले? ही भिक्षा नव्हे काय? | 10 | M29 | theatre; dialogue |
| 48 | Sane Guruji | Manu Baba: Janmabhumicha Tyag (1941) | बहुळा नदीच्या तीरावर सायगाव म्हणून एक गाव होता. गाव मोठा सुखी व समृद्ध होता. | 14 | M30 | prose |

The Khadilkar rows are song lyrics of Manapaman; the music is by Govindrao Tembe (1881 to 9 Oct 1955 on the authors list), which does not matter for the lyrics' rights. Rows 36 to 38 are the Gadkari poems named in the decisions above.

## Dropped, and why

**Culture 1**

- **Rukmini Swayamvar (Eknath).** The page रुख्मिणी स्वयंवर is a stub of one sentence (447 characters, "एकूण ओवीसंख्या १८००" in the header) and its chapter pages रुख्मिणी स्वयंवर/अध्याय पहिला and /अध्याय दुसरा do not exist; a prefix search for रुख्मिणी स्वयंवर/ returned nothing and the category वर्ग:रुख्मिणी स्वयंवर holds only the stub. No text can be taken.
- **Bhavartha Ramayan chapter subpages.** Only भावार्थ रामायण/अध्याय पहिला exists (a prefix search returned that one page; the category pages are empty; a misspelt prefix भवार्थ returned none). Chapter 1 is used in rows 28 and 29; the 297 chapters the header names are not on the wiki.
- **Atmaram (Ramdas).** The page आत्माराम is a redirect to "आत्माराम (समर्थ रामदास कृत)", and that page does not exist. The category वर्ग:रामदास स्वामी यांचे साहित्य lists उत्तम गुण, करुणाष्टके, चतुर्दश मारूती स्तोत्रे, मनाचे श्लोक, शिवराजास आठवावें, सवाई, सोलिव सुख and the category दासबोध, with no Atmaram. The first page's "link exists" was this redirect link.
- **Haripath and Amrutanubhav (Dnyaneshwar).** The pages हरिपाठ/श्री ज्ञानदेव हरिपाठ and अमृतानुभव do not exist (a prefix search for हरिपाठ returned none). Only the author page's red links remain.
- **Muktabai** (1279 to 1297 on the authors list; the author page has "?" for both years), **Janabai** (author page: died 1350, birth "?"), **Chokhamela** (author page: died 1338, birth "?"; mr.wikipedia: 1273 to 1338), **Sena Nhavi**, **Mukteshwar**, **Savata Mali**, **Gora Kumbhar**, **Narahari Sonar** (author page "?" and "?"). For Savata Mali, Gora Kumbhar and Mukteshwar mr.wikisource has author pages of only 5 to 8 words (साहित्यिक:सावता माळी, साहित्यिक:गोरा कुंभार, साहित्यिक:मुक्तेश्वर); for the others it has the author page too. The banner-category list has no work page of any of them, and mr.wikisource searches for Janabai, Chokhamela, Sena Nhavi, Narahari Sonar, Savata Mali, Gora Kumbhar and Mukteshwar found none either (Muktabai was not searched by title). Sena Nhavi also has no year anywhere: en.wikipedia and mr.wikipedia say none and Wikidata Q7449924 has no birth or death date. en.wikipedia "Mukteshwar" is a village in Uttarakhand, not the poet. Dropped: no text page, and for Sena no year.
- **Niloba** (the page निळोबाराय अभंगगाथा has the author field निळोबाराय, 1.7 thousand characters): there is no author page साहित्यिक:निळोबा, en.wikipedia "Niloba" does not exist and Wikidata has no person of that name. No death year, dropped.
- **Kalyan Swami** (समर्थ कल्याण संवाद and सोलिव सुख): the first has the year field "१७ वे शतक" only; en.wikipedia "Kalyan Swami (saint)" does not exist. No death year, dropped.
- **Dasopant** (1551 to 1615), **Sheikh Muhammad** (1560 to 1650), **Mukundraj** (the list says died "1200", the author page has "?", en.wikipedia says some earlier scholars dated him to the 12th century) and **Mhaimbhat** (1300 on the list) have no work page in the banner category. **Moropant** (1729 to 1794, Wikidata Q6913270): his author page lists works (such as आर्य केकावल...), but a prefix search for केकावल, मदालसोपाख्यान and the category वर्ग:मदालसोपाख्यान returned no work page, and the author page's own death year is "?".
- **The anthologies** संतवचनामृत (44 thousand words) and रामदासवचनामृत carry no compiler or date on the search results; their compilers' death years were not read, so they are not used.
- **गाहा सत्तसई (Hala Satavahana).** It is in Maharashtri Prakrit and dated "इस पुर्व २०० ते इस २००"; it is not Marathi.

**Culture 2**

- **Ram Joshi.** mr.wikipedia has a page राम जोशी and en.wikipedia "Ram Joshi" exists, but both have an empty introduction, Wikidata search finds no entry, and mr.wikisource has no page by him. The years on the first page (1762 to 1812, from en.wikipedia "Powada") are unchanged and no text exists.
- **Anant Phandi.** mr.wikipedia अनंत फंदी has an empty introduction, en.wikipedia "Anant Phandi" does not exist, Wikidata has no entry, and a mr.wikisource title and full-text search finds only mentions in modern books. No text.
- **Prabhakar (shahir).** mr.wikipedia प्रभाकर (शाहीर) and en.wikipedia "Prabhakar (shahir)" do not exist; no text.
- **Eknath's Bharud.** Searches for "intitle:भारूड" and "intitle:भारुड" and the category भारुड returned nothing.
- **Gondhal.** The category गोंधळ is empty and the full-text search finds only unrelated modern books.
- **Lavani texts.** "intitle:लावणी" and the category लावणी returned nothing. Honaji Bala has lavanis (mr.wikipedia says about 250 are attributed to him) but none is on mr.wikisource; only his bhupali is.
- **Other powadas.** "intitle:पोवाडा" and the category पोवाडा returned nothing; Phule's powada (row 13 to 15) is the only one.
- **The other 13 bhupali pages, the aartis, the Devi bhajans and khelgani (श्रीदेवीची भजने, श्रीदेवीची खेळगाणी, देवीला दंडवत), भुलाबाईची गाणी, श्री शिवस्तुति.** Each carries the banner and the tag "no source" and has no author field, and none gives a date. The Rama, Maruti, Shankar, river and Dashavatar bhupalis end with a line signed "दास" or "रामदास" (for example रामाची भूपाळी: "रामदासाचे मानसी"), which is a signature and not an attribution: no page names an author. An anonymous work needs a first publication before 1900 read from a page; none is on these pages. Dropped, as on the first page.

**Culture 3**

- **Vinayak Damodar Savarkar** died in 1966 and fails the floor.
- **Sane Guruji, Shyamchi Aai.** On mr.wikisource the page श्यामची आई is only `{{Redirect|mr:b:श्यामची आई}}`, i.e. to mr.wikibooks, which the proxy blocks. The page cannot be read, so the novel stays unverified; other Sane Guruji texts are used instead (rows 45 and 48 here, and the Stri-Jeevan rows 23 to 27 of culture 2).
- **Govind Ballal Deval** (1855 to 1916; en.wikipedia "Govind Ballal Deval" says the same). mr.wikisource has essays about him (पायवाट/देवलांची शारदा, सांगली आणि सांगलीकर) but none of his own works.
- **Ram Ganesh Gadkari, Vedyacha Bazar.** No page; the poems in the rows above replace it.
- **Hari Narayan Apte** (8 Mar 1864 to 3 Mar 1919 on en.wikipedia), **Vishnushastri Chiplunkar**, **Balwant Pandurang Kirloskar**, **Tarabai Shinde** (the page स्त्रीपुरुष तुलना, 1882, is only a two-line index of subpages: the author is on the list, 1850 to 1910, but no text page was read). None has a text page in the banner category.
- **Kusumagraj, Ambedkar, Mardhekar, Palwankar** remain out (first page).

## What the builder needs to know

1. Each row has a source key; the builder reads the page again, copies the line, and runs `tools/transcribe.py`. The excerpt here is the page text of 2026-11-15 to 2026-11-16 and may change if a Wikisource editor changes the page: check the revision column.
2. The creators file takes `Dnyaneshwar` for rows 19 to 24 (the decision above), and the other creators' lifespans as in the table, with `circa` where the table says so.
3. Wikisource banners are claims, not proofs; every page still goes to the reviewer. This page's contribution is the author's death year read from a named page, and a line copied from the page.
