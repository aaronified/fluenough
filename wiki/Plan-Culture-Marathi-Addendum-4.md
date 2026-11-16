# Marathi culture, multi-word verbs and situations: addendum 4 (gaps re-opened)

Task MR-R4 of [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), written 2026-11-16, an addendum to [Plan-Culture-Marathi](Plan-Culture-Marathi.md) and to [Addendum 1](Plan-Culture-Marathi-Addendum-1.md), [Addendum 2](Plan-Culture-Marathi-Addendum-2.md) and [Addendum 3](Plan-Culture-Marathi-Addendum-3.md). The owner's directive: "Do not accept gaps!" Every gap recorded in section 6 of the queue page and in the "dropped and why" lists of the three addenda was re-opened with the network allowlist now widened (gutenberg.org, archive.org, web.archive.org, britannica.com, dli.gov.in, sanskritdocuments.org). Where a row below says "not found", every host named in "Hosts" was tried.

## How this addendum was checked

Pages were read on 2026-11-16 as raw wikitext (`index.php?action=raw` or `action=query&prop=revisions`), 10 to 20 seconds between requests to one host and a 45 to 60 second wait before each retry after an HTTP 429 (the Wikimedia APIs answered 429 many times; every request listed here was retried to a 200). The archive.org texts were read as `/stream/<id>/<id>_djvu.txt`. **A fact is here only if the named page said it; nothing was written from memory.** Each quoted excerpt was copied by script from the saved page text, which asserted that the excerpt occurs on the page (wiki link brackets and bold or italic marks removed, whitespace runs collapsed) and has at most 25 words. Infobox values are given as the infobox field, not as a quotation. Everything here is `unreviewed`: the builder copies the words again from the page, and a Marathi reviewer sees every row through `docs/review-queue/mr.md`.

**A caution about the new textbook source.** The best new source for sections B and C is a grammar in Roman script, Dhongde and Wali, *Marathi* (London Oriental and African Language Library 13, John Benjamins, 2009, copyright 2009), read from archive.org item `marathi_20210812`. It writes Marathi in a Roman transliteration with glosses (for example `tya-na kam sampw-un tak-l-a`), not in Devanagari, and it is in copyright, so only short excerpts of at most 25 words are given and no row copies a passage. A card built from it needs its Devanagari spelling from a Marathi reviewer or from a second page; the Roman form here is the page's, not a spelling choice.


## Hosts: reached and blocked

| Host | Result on 2026-11-16 |
|---|---|
| en.wikipedia.org, mr.wikipedia.org, en.wiktionary.org, mr.wiktionary.org, www.wikidata.org | Reached. HTTP 429 under load for minutes at a time on all five; pages were fetched in batches of up to 10 titles per request (`action=query&prop=revisions&titles=A&#124;B&#124;C`) with a 15 second gap, which went through. |
| archive.org | **Reached** for `advancedsearch.php` and for `/stream/<id>/<id>_djvu.txt` (HTTP 200, 200 KB to 8.5 MB each). **But the Devanagari in the scans is not recognised**: the Molesworth Marathi-English dictionary (`10522290bsb`, `compendiumofmole00mole`, `dictionaryenglis00mole`), the Marathi English Primer (`marathienglishp00bhidgoog`) and the 1873 English-Marathi dictionary text contain 0 Devanagari characters and the headwords are garbage (`ATAT`, `FITT`). Search-engine hits for Marathi phrasebooks on archive.org were all Gandhian pamphlets, children's books and parliamentary debates. Two Roman-script books were readable and are used: Dhongde and Wali, *Marathi* (2009; `marathi_20210812`) and Manwaring, *Marathi Proverbs* (Clarendon Press, 1899; `MarathiProverbs`). |
| web.archive.org | Connection refused (HTTP 000 from the proxy on `/`). |
| en.wikivoyage.org, mr.wikivoyage.org | **Not reachable**: `curl` got `CONNECT tunnel failed, response 403` and `WebFetch` answered `getaddrinfo ENOTFOUND`. They are not on the allowlist the task names, so the Wikivoyage Marathi phrasebook (the best planned source for section C) could not be read. It has to be added to the network allowlist before the 30 situation phrases can be sourced from it. |
| www.britannica.com | HTTP 403 to a plain `curl`; `WebFetch` answered `getaddrinfo ENOTFOUND www.britannica.com`. A browser User-Agent is not allowed by the harness and was not used. Not read. |
| www.gutenberg.org | HTTP 503 on the home page. Not read. |
| sanskritdocuments.org | HTTP 403. Not read. |
| dli.gov.in | No answer (HTTP 000). Not read. |

## A. Recommendations

### A1. Songs (7 rows, all verified)

A song row needs a Wikipedia page that gives the year, the composer, the lyricist and the film. Seven pages do. The creator is the composer or lyricist with a stated birth date; where a person has none the row says so. The quiz facts (three questions each) are the ones quoted.

| # | Song | Verified facts | Words on the page |
|---|---|---|---|
| S1 | Chandra (2022, film Chandramukhi) | Infobox of en.wikipedia "Chandra (song)": released 29 April 2022 (`{{Start date&#124;df=yes&#124;2022&#124;04&#124;29}}`), composer Ajay-Atul, lyricist Guru Thakur, singer Shreya Ghoshal, genre Filmi and Lavani, length 5:41. | "is the title song of the 2022 Indian Marathi period romantic drama film Chandramukhi, directed by Prasad Oak"; "The song was composed by Ajay-Atul, with lyrics penned by Guru Thakur and sung by Shreya Ghoshal" |
| S2 | Sairat Zaala Ji (2016, film Sairat) | Infobox: released 11 April 2016 (`2016&#124;04&#124;11`), composer Ajay-Atul, label Zee Music Company. The album page en.wikipedia "Sairat (soundtrack)" gives the album's date as 1 April 2016 (the single was later, so a question names the song's 11 April or only the year). | "is the title song of the 2016 Marathi-language Sairat, directed by Nagraj Manjule"; "It is composed and co-written by Ajay-Atul and sung by Chinmayi Sripaada alongside Ajay Gogavale" |
| S3 | Kombadi Palali (film Jatra: Hyalagaad Re Tyalagaad) | Song page: film year **2005**, composer Ajay-Atul, lyricist Jitendra Joshi, singers Anand Shinde and Vaishali Samant. The title means "The Hen Ran Away" (literal translation note on the page). **Year conflict:** en.wikipedia "Kedar Shinde" lists the film under 2006, so a question must use the song page's 2005 and say "per Wikipedia", or leave the year out. | "is a Marathi-language song from the soundtrack album of the 2005 comedy film Jatra: Hyalagaad Re Tyalagaad, directed by Kedar Shinde" |
| S4 | Sukh Kalale (2022, film Ved) | Infobox: released 27 December 2022, composer and writer Ajay-Atul, singer Shreya Ghoshal, genre Indian pop. A second version is sung by Ajay Gogavale. | "is a Marathi-language song from the soundtrack album of the film Ved, directed by Riteish Deshmukh"; "The song was digitally released on 27 December 2022" |
| S5 | Marathi Abhimaangeet (2010) | Writer Suresh Bhat, composer Kaushal Inamdar; released 27 February 2010 in Thane on Marathi Bhasha Diwas; sung by 112 established singers and a chorus of 356. | "is a song written in Marathi by the noted poet Suresh Bhat and set to music by well known composer Kaushal Inamdar"; "has been sung by 112 established singers and a chorus of 356 upcoming singers" |
| S6 | The songs of Jait Re Jait (1977 film) | Film released 9 November 1977 (`{{Film date&#124;1977&#124;11&#124;09&#124;df=y}}`), directed by Jabbar Patel, music Hridaynath Mangeshkar, most lyrics N. D. Mahanor, sung by Lata Mangeshkar, Asha Bhosle, Usha Mangeshkar, Ravindra Sathe and Chandrakant Kale. The film won the President's silver medal for Best Feature Film in Marathi. | "The popular songs of the film are composed by Pt. Hridaynath Mangeshkar, with most of the lyrics by N. D. Mahanor" |
| S7 | The Chandramukhi soundtrack (2022 album) | Album released 28 April 2022; six songs; the singles Chandra (30 March 2022), To Chand Rati, Bai Ga and Sawaal Jawaab; composer Ajay-Atul, lyrics Guru Thakur. | "The film's musical score and six-song soundtrack is composed by Ajay–Atul with lyrics written by Guru Thakur" |

**Creator dates for the song rows** (en.wikipedia infoboxes, read on the same day):

| Person | Date | Page and words |
|---|---|---|
| Ajay-Atul (Ajay and Atul Gogavale) | Ajay born 21 August 1976, Atul born 11 September 1974 | en.wikipedia "Ajay-Atul", infobox `birth_date = {{birth-date and age&#124;21 August 1976}} (Ajay)` and `{{birth-date and age&#124;11 September 1974}} (Atul)`; "is an Indian music composer duo comprising brothers Ajay Ashok Gogavale and Atul Ashok Gogavale". A duo is two people, so a creator row uses one name and notes the other, or names the duo with Ajay's date. |
| Suresh Bhat | 15 April 1932 to 14 March 2003 | en.wikipedia "Suresh Bhat": "Suresh Bhat (15 April 1932 – 14 March 2003) was a Marathi poet from the state of Maharashtra" |
| Kaushal Inamdar | born 2 October 1971 | en.wikipedia "Kaushal Inamdar": "Kaushal S. Inamdar (born 2 October 1971) is an Indian music composer and singer" |
| Hridaynath Mangeshkar | born 26 October 1937 | en.wikipedia "Hridaynath Mangeshkar": "born 26 October 1937) is an Indian music director and singer" |
| Jabbar Patel | born 23 June 1942 | en.wikipedia "Jabbar Patel": "(born 23 June 1942) is a former paediatrician and a Marathi-language theatre and film director of India" |
| Kedar Shinde | born 16 January 1973 | en.wikipedia "Kedar Shinde": "born 16 January 1973) is an Indian film director and screenwriter from Mumbai, India" |
| Guru Thakur (lyricist of Chandra) | **no year**: the infobox has `birth_date = 18 July` only | en.wikipedia "Guru Thakur". Not usable as a creator with `born`; the row names Ajay-Atul. |

### A2. Television series (5 rows with a premise; 4 new, 1 from Addendum 3)

Series have a channel and a premiere date, but no page names a person creator with a birth date, so they cannot carry the creator field a recommendation row needs unless the schema accepts a company or channel. They are verified as fact bases for quiz questions (premiere, channel, premise) and as `culture` quiz facts.

| # | Series | Verified facts | Words on the page |
|---|---|---|---|
| T1 | Home Minister (Zee Marathi) | First aired 13 September 2004 (`{{start date&#124;df=yes&#124;2004&#124;09&#124;13}}`); host Aadesh Bandekar; the winner of the games gets a Paithani saree. | "is an Indian Marathi reality game show which aired on Zee Marathi"; "the host Aadesh Bandekar, visiting the homes of women in different cities of Maharashtra and playing various games with them" |
| T2 | Jai Malhar (Zee Marathi) | Premiered 18 May 2014; 942 episodes (infobox); producers Mahesh Kothare and Adinath Kothare. | "It is based on the legend of the Hindu god Khandoba, an avatar (incarnation) of Shiva"; "It premiered from 18 May 2014 by replacing Tu Tithe Me" |
| T3 | Asambhav (Zee Marathi) | Premiered 12 February 2007; 774 episodes (infobox); the title is `{{translation&#124;Impossible}}`; writers Vivek Agnihotri and Chinmay Mandlekar, director Satish Rajwade (infobox). | "It premiered from 12 February 2007 by replacing Vadalvaat"; "The series is based on the concept of reincarnation in Hinduism" |
| T4 | Majhi Tujhi Reshimgath (Zee Marathi) | Premiered 23 August 2021; 458 episodes (infobox); title means "Mine & Your Silk Knot"; written by Sankarshan Karhade, directed by Ajay Mayekar. | "It premiered from 23 August 2021 by replacing Aggabai Sunbai"; "Neha Kamat, a single mother, lives in a chawl with her 5-year-old daughter, Pari" |
| T5 | Chala Hawa Yeu Dya (Zee Marathi) | In [Addendum 3](Plan-Culture-Marathi-Addendum-3.md) section A: premiered 18 August 2014. | (read earlier) |

### A3. The works dropped for creator dates: outcome of the re-open

| Work | Result | Page and the words relied on |
|---|---|---|
| **Ventilator** (2016 film), creator Rajesh Mapuskar | **Now verified** (this was a drop in Addendum 3). Birth date 26 September 1968; film released 4 November 2016; premise stated. | en.wikipedia "Rajesh Mapuskar": "was born on 26 September 1968 in Shrivardhan, a village in coastal Maharashtra". en.wikipedia "Ventilator (2016 film)" (the title "Ventilator (film)" redirects to a disambiguation page): "is a 2016 Indian Marathi-language comedy drama film written and directed by Rajesh Mapuskar"; "It tells the story of the Kamerkar family, whose oldest and most beloved member enters a coma"; "put on a medical ventilator a few days before the Ganesh Chaturthi festival celebrations"; release date from the infobox `{{Film date&#124;df=yes&#124;2016&#124;11&#124;4}}`. Director's award: "including the National Film Award for Best Director". |
| **Sant Dnyaneshwar** (1940 film) | **Now verified**, with Damle as the creator. | en.wikipedia "Sant Dnyaneshwar (film)": "is a 1940 Marathi-Hindi biographical devotional film directed by Vishnupant Govind Damle and Sheikh Fattelal and produced by Prabhat Film Company"; "The film was released on 18 May 1940 and is based on the life of the 13th-century Marathi saint and poet Dnyaneshwar". Plot paragraph names the parents Vitthal Govind Kulkarni and Rukmini of Apegaon near Paithan. Damle's dates: mr.wikipedia "विष्णुपंत गोविंद दामले": "(ऑक्टोबर १४, इ.स. १८९२ - जुलै ५ इ.स. १९४५)" (14 October 1892 to 5 July 1945, the same as the en.wikipedia date in Addendum 3). |
| **Sant Tukaram** (1936 film) | **Usable with Damle as the creator**; Fattelal's dates are still not found. | mr.wikipedia "संत तुकाराम (चित्रपट)": "इ.स. १९३६ मध्ये प्रभात फिल्म कंपनीच्या बॅनरखाली विष्णूपंत दामले आणि फत्तेलाल शेख यांनी केली"; release "डिसेंबर १२, इ.स. १९३६ साली प्रदर्शित झालेल्या". The Marathi spelling of the second director is फत्तेलाल शेख. Searches this run: mr.wikipedia "फत्तेलाल शेख" and "शेख फत्तेलाल" do not exist; en.wikipedia "Sheikh Fattelal" does not exist; Wikidata `wbsearchentities` for "Fattelal" returned an empty list ("Sheikh Fattelal" and "Fatehlal" were answered with HTTP 429 and not retried to a result). |
| **Shwaas** (2004 film), creator Sandeep Sawant | **Still not found**: birth year. The film itself is verified (see Addendum 3 A1). | en.wikipedia "Sandeep Sawant" says only "Sawant resides in Vile Parle, Mumbai. He is a psychology graduate" and its categories include "Living people"; mr.wikipedia "संदीप सावंत" says "सावंत हे मुंबईतील विलेपार्ले येथे राहतात. ते मानसशास्त्राचे पदवीधर आहेत." with no year; Wikidata `wbsearchentities` finds one entity, Q17122764 "Indian filmographer" (Addendum 3: no birth date); britannica.com is not reachable. The film page's other credited people are the story writer "Madhavi Gharpure" (no page) and the composer Bhaskar Chandavarkar (not read). The row stays as a recommendation only if the schema accepts a creator without `born`. |

### A4. Podcasts, radio series and further songs: not found

- **Podcasts and radio series.** A web search restricted to en.wikipedia for Marathi podcasts and radio series returned only television pages and **Mann Ki Baat** (a Hindi-language radio programme with translated versions in Marathi, per the search-result summary of its en.wikipedia page; the page itself was not read and no date is used). No page for a Marathi-original podcast or radio series with a creator and a year was found, so none is a row. Reason recorded for the queue page: no readable page, not a host block (en.wikipedia answered).
- **Further songs.** The pages that were read are the ones above. "Zingaat" is the fourth song of the Sairat album (the album page's track list); its own page was not read.

## B. Multi-word verbs

The meanings below come from Dhongde and Wali (2009), section 3.4.2 "Compound verbs" and the surrounding chapters (read as `marathi_20210812`), from the Bhide dictionary entries on mr.wiktionary (credited on each page "सरस्वती शब्दकोश, कोशकार - कै.विद्याधर वामन भिडे") and from en.wiktionary. For Dhongde and Wali the example is given in the book's Roman transliteration plus its English gloss, with the example's number in the book. The Devanagari spelling is not on the page.

### B1. The eight structure-only compound-verb rows of Addendum 3 B2 now have a stated meaning

| Addendum 3 B2 row | Phrase | Meaning now stated | Page and the words relied on |
|---|---|---|---|
| 1 | खाऊन टाकणे | the V2 टाकणे marks completion, "to finish off"; "get rid of" | Dhongde and Wali 3.4.2.1, terminatives, ex. 45: `tya-na kam sampw-un tak-l-a` glossed "He brought the work to a finish"; 3.4.2.2 ex. 61 `tya-la te de-un tak na!` glossed "Finish it by giving it to him, won't you?" under the V2 gloss `tak` "get rid of". The page does not give खाऊन टाकणे itself; the pattern and the meaning of V2 are stated. |
| 2 | खेळू लागणे | "to begin to play" (inceptive लागणे) | Ex. 40: `to rad-u` ... `lag-l-a` glossed "He began to cry / He began crying"; the page's list: "ii. Inceptives: ghal" ... lag. The same inceptive frame with the verb खेळणे is not on the page; the pattern is. |
| 4 | जाऊ देणे | "let (someone) go"; permissive देणे | 3.4.2.3: "The permissive de" marks V1 with the inceptive -u, ex. 76 `to/tya-la bol-u de` glossed "Let him speak". |
| 5 | करू पाहणे | "to wish or try to do"; desiderative पाहणे | Ex. 83 `to khel-u pah-t-o` glossed "He wishes to play"; the list names `pah` among "Desideratives are expressed by six verbs". |
| 6 | जिंकू या | "let us win"; the hortative -u + या | Ex. in the television text: `swagat karu ya` glossed "Let us give a thunderous applause to welcome all the singers"; the telephone text has `bhet-u` glossed "Let's meet" (hortative). The verb जिंकणे is not on the page; the pattern is. |
| 7 | करून टाकणे | "to do (something) completely" | As row 1 (terminative टाकणे, ex. 45 and 61). |
| 8 | लिहून काढणे | "to write out"; काढणे is an intensive explicator of the action | 3.4.2.2: "encode the intensity of an action"; ex. 57 `nawr-ya-na ti-la phod-un kadh-l-a` glossed "Her husband beat her up" under `kadh` "draw, take out". The page gives no example with लिहिणे; "write out" is the pattern's reading, not a quoted gloss. |
| 9 | लिहून टाकणे | "to finish writing, to write off" | Ex. 56 (V2 "ho"): `tya-c-a patra lih-un jha-l-a` glossed "He finished writing the letter"; टाकणे as in row 1. |
| 16 | खाल्ला जाणे | passive with जाणे | The page states that जाणे is a passive voice marker: "passive voice markers ja" (and ye). |

**8 of 8 structure-only rows resolved** (rows 1, 2, 4 to 9) plus row 16. Row 3 वाचत बसणे was already glossed; Dhongde and Wali ex. 35 adds the iterative बसणे: `to rad-at bas-l-a` glossed "He kept on crying" (the page adds "ludicrous" as a nuance).

### B2. The gloss-only dative-subject rows 16 to 20 of Addendum 3 B4 now have a stated sentence

| B4 row | Verb | Stated sentence | Page |
|---|---|---|---|
| 16 | आवडणे | `tya-la na amba awad-t-o`, "he likes mangoes" | Dhongde and Wali, particle `na`, ex. 296. The same book lists the dative-subject verbs: "The subject of these verbs, which encodes the experiences, is in the dative" (the list starts `awad`, `dis`, `pat`, `samaj`, `ruc`, `rag ye`, `malmal`). |
| 17 | सुचणे | `kalpana suc-li`, glossed "idea struck" (the scan reads "idea struk") | Dhongde and Wali, child-language sample (speaker Ab). One example only, in a child-language transcript; keep it as `unreviewed`. |
| 18 | दिसणे | `ekasarkhya dis-t-at` in `lili ani mini ekasarkhya dis-t-at`, glossed "Lili and Mini look alike" | Dhongde and Wali, ex. 27 (not a dative subject here; the verb in the dative list is `dis`). |
| 19 | येणे (राग येणे) | `ti-la rag a-l-a`, "She got angry" | Dhongde and Wali, ex. 43, with `ti-la thandi waj-t-e` glossed "She feels cold" (ex. 41) and `ti-la baksis mila-l-a` glossed "She received a gift" (ex. 44). |
| 20 | वेड लागणे | the book's list of phrasal verbs: `wed lag` glossed "madness come to touch = be mad" | Dhongde and Wali, section 3.4.3 phrasal verbs. This is the phrase's meaning, not only the base word's. en.wiktionary लागणे (read) also gives "to develop" with the example सवय लागणे, "to develop a habit". |

**5 of 5 resolved.**

### B3. Base words with no gloss in Addendum 3: 3 of 10 resolved, 7 not found

| Base word | Result | Page and the words relied on |
|---|---|---|
| तटका | **Gloss found** | mr.wiktionary "तटका" (Bhide): "ताजे,टवटवीत (फुल,फळे,भाजी)" (fresh, fresh-looking: of flowers, fruit, vegetables). Related phrase entries found in the same sweep: mr.wiktionary "तटका तोडणे": "मागे पुढे न पाहता किं.भीड मुरवत न धरता साप आणि स्पष्टपणे आपले मत सांगून टाकणे" (to say one's opinion plainly without hesitation or deference; the page's word साप is as printed, presumably a typing slip for साफ) and "तटका तुटणे": "निकलांत निघने" (printed so; the wording is not standard Marathi and goes to the review queue). |
| तकटून | **Gloss found** | mr.wiktionary "तकट, तकटून": "सईलपणे न राहील अशा रीतीनें (बांधणे)" and "पोटांत रिकामी जागा न राहील अशा रीतीनें (खाणे,पिणे)" (so that no looseness or empty space remains: tying, eating, drinking). Phrase entries: "तकटून खाणे": "आकंठ खाणे" (to eat up to the throat) and "तकटून बांधणे": "घट्ट बांधणे" (to tie tight). |
| लागणे (in वेड लागणे) | **Resolved** | See B2 row 20 and en.wiktionary लागणे (the page lists the senses "to be hit, shoved", "to commence (a particular activity)", "to develop", "to be affixed, applied"). |
| अटकेपार | not found | mr.wiktionary and en.wiktionary have no page; the title list of mr.wiktionary (3,674 pages read via `list=allpages`) has no title containing it; Dhongde and Wali and Manwaring have no occurrence (Roman search `atke`, `atak`). |
| विश्वे | not found | Same: no page on either wiktionary, no occurrence in the two books. |
| सर्वस्व | not found | Same (Roman searches `sarvasv` and `sarwasw`: 0). |
| पणाला | not found | Same (Roman search `panal` found only the unrelated `kripanala`). |
| सामोरे | not found as a gloss | Dhongde and Wali list the postposition `samor`: "pudhe / samor" glossed "in front", and ex. 274 `ghar-a-samor aygan ahe` "There is a yard in front of the house". That is समोर, not सामोरे; no page glosses सामोरे itself, so सामोरे जाणे is not given a meaning. |
| घिसाडघाई | not found | The only `ghis` in the books is the reduplicator example `ghasa&#124;ghis` ("bargaining"), a different word. |
| पदरी | not found as a gloss | Manwaring proverb 1517 (public domain, 1899): `Deva ala dyayala to padara nahi ghyayala` with the translation "God came to give but he had no lap in which to receive". It shows पदर glossed "lap", not the locative पदरी, so पदरी पडणे is not given a meaning. |

### B4. A full mr.wiktionary sweep

`list=allpages` was read to the end: **mr.wiktionary now has 3,674 pages** (Addendum 3 counted 2,628). 600 titles contain a space; 177 of those contain Devanagari, and the rest are English software-menu strings ("Copy to Folder") and administration pages. None of the 177 is in a category of phrase entries named नामयोगी क्रियापद, संयुक्त क्रियापद or वाक्प्रचार: the pages "नामयोगी क्रियापद", "संयुक्त क्रियापद", "वाक्प्रचार", "वर्ग:मराठी वाक्प्रचार" and "वेड लागणे", "लागणे", "वेड" **do not exist** on mr.wiktionary (all answered "missing"). The Devanagari multi-word entries are Bhide entries about the words त-ट-: the six read above plus "तटास लागणे": "अटीस पडणे किं.पेटणे" (to be obstinate or to flare up), and "आली गेली": "नफा नुकसान ; जमा खर्च; आय व्यय." (profit and loss; credit and debit; income and expenditure). So the phrase entries that matter are the five **new multi-word rows** above: तकटून खाणे, तकटून बांधणे, तटका तोडणे, तटका तुटणे (review), तटास लागणे (**5 new idiom-style rows**, each with its Bhide gloss). The Marathi-English dictionary of Molesworth cannot be used (see Hosts).

**Section B total:** 8 compound rows resolved + row 16 + 5 dative rows resolved (the fifth is वेड लागणे) + 2 base words glossed (तटका, तकटून) + 5 new Bhide phrase entries = **21 items now usable**; 7 base words still not found.

## C. Situations

`decks/mr/mr-situations.yaml` on decks-live has 10 sheets with English titles only (`title: { en: ... }`), so the Marathi names of the ten sheets are the first gap. The topic words below were read as the translation lines of the English entries on en.wiktionary (raw wikitext). A line is `* Marathi: {{t|mr|WORD}}` under the sense named in the table. These are words, not phrases.

### C1. Marathi names for the ten sheets and nearby words (verified)

| Sheet | Marathi word | Page and the line read |
|---|---|---|
| taxi | टॅक्सी | en.wiktionary taxi: `* Marathi: {{t+&#124;mr&#124;टॅक्सी&#124;f}}` |
| taxi (rickshaw) | रिक्शा | en.wiktionary rickshaw: `* Marathi: {{t&#124;mr&#124;रिक्शा&#124;f}}` |
| shops | दुकान | en.wiktionary shop: `* Marathi: {{tt&#124;mr&#124;दुकान&#124;f}}` |
| eat | उपहारगृह (restaurant) | en.wiktionary restaurant: `* Marathi: {{t+&#124;mr&#124;उपहारगृह}}` |
| eat / hotel | नाष्टा (breakfast) | en.wiktionary breakfast, sense "first meal of the day": `* Marathi: {{t&#124;mr&#124;नाष्टा&#124;m}}` |
| eat / hotel | नाष्टा करणे (to have breakfast) | en.wiktionary breakfast, sense "to eat the morning meal": `* Marathi: {{t&#124;mr&#124;नाष्टा करणे}}` |
| doctor | डॉक्टर | en.wiktionary doctor: `* Marathi: {{t&#124;mr&#124;डॉक्टर&#124;m}}` |
| doctor | रुग्णालय, इस्पितळ, हॉस्पिटल, दवाखाना (hospital) | en.wiktionary hospital: `* Marathi: {{tt+&#124;mr&#124;रुग्णालय&#124;n}}, {{tt&#124;mr&#124;इस्पितळ&#124;n}}, {{tt&#124;mr&#124;हॉस्पिटल&#124;n}}, {{tt&#124;mr&#124;दवाखाना&#124;m}}` |
| doctor | फार्मसी, औषधालय, दवाखाना (pharmacy) | en.wiktionary pharmacy: `* Marathi: {{t&#124;mr&#124;फार्मसी}}, {{t+&#124;mr&#124;औषधालय}}, {{t&#124;mr&#124;दवाखाना&#124;m}}` |
| emergencies | रुग्णवाहिका (ambulance) | en.wiktionary ambulance: `* Marathi: {{t&#124;mr&#124;रुग्णवाहिका&#124;f}}` |
| emergencies | पोलीस (police) | en.wiktionary police: `* Marathi: {{t&#124;mr&#124;पोलीस}}` |
| emergencies | आणीबाणी (emergency) | en.wiktionary emergency, sense "situation requiring urgent assistance": `* Marathi: {{t&#124;mr&#124;आणीबाणी&#124;f}}` |
| traffic | रहदारी | en.wiktionary traffic, sense "pedestrians or vehicles on roads or on the air": `* Marathi: {{t&#124;mr&#124;रहदारी&#124;f}}` |
| traffic | चलान (traffic ticket, fine) | en.wiktionary ticket, sense "traffic citation": `* Marathi: {{t&#124;mr&#124;चलान&#124;n}}` |
| rail | फलाट (platform) | en.wiktionary platform, sense "travel: raised structure for passengers": `* Marathi: {{t&#124;mr&#124;फलाट&#124;m}}` |
| rail | तिकीट (ticket) | en.wiktionary ticket, senses "admission to entertainment" and "pass for transportation": `* Marathi: {{t&#124;mr&#124;तिकीट&#124;n}}` |
| rail | आगगाडी, रेल्वे, गाडी, ट्रेन (train) | en.wiktionary train: `* Marathi: {{tt&#124;mr&#124;आगगाडी&#124;f}}, {{tt+&#124;mr&#124;रेल्वे&#124;f}}, {{tt&#124;mr&#124;गाडी&#124;f}}, {{t&#124;mr&#124;ट्रेन&#124;f}}` |
| hotel | हॉटेल | en.wiktionary hotel: `* Marathi: {{tt&#124;mr&#124;हॉटेल}}` |
| post and bank | बँक | en.wiktionary bank: `* Marathi: {{tt&#124;mr&#124;बँक}}` |
| hotel (reception) | स्वागतकक्ष (reception counter) | mr.wiktionary "रिसेप्शन काउंटर": `[[स्वागतकक्ष]]`; the page is tagged "सुचवलेला शब्द मनोगती" (a word suggested on the Manogat site), so it is a suggested coinage, not an attested usage. |
| greetings | शुभेच्छा (good wishes, "all the best") | mr.wiktionary "ऑल द बेस्ट": `[[शुभेच्छा]]` (the same "suggested word" tag). |

**Not found in any reachable page:** a Marathi word for "post office", "railway station", "licence", "fine" (as a penalty), "fever", "parcel" or "size": the en.wiktionary entries (read) have no Marathi translation line for them. The titles of the ten sheets as a whole ("Taxi and rickshaw", "Doctor and pharmacy") are not on any page; the words above are the building blocks for a title a Marathi reviewer chooses.

### C2. The ~30 phrases with no card: nothing exact found, three doctor-visit lines found as extras

None of the 30 phrases was found as a Marathi sentence on any page that could be read. The two sources planned for them, the Wikivoyage Marathi phrasebooks, are not reachable (Hosts), and the archive.org Marathi textbooks that exist as scans have no recognised Devanagari. The Roman-script grammar has a doctor-and-patient conversation (section 12.2.2) which is the nearest text. Its lines are given with the page's gloss; none is one of the 30 phrases, but they fit the doctor sheet and the book's own sentences are real Marathi:

| Doctor-sheet candidate | Roman line on the page | Gloss on the page |
|---|---|---|
| a doctor's question | `dam-ya-ca ajar ... ahe ka tumha-la` | "Do you have asthema?" |
| a doctor's instruction | `lam lam Swas` ... `ghy-a` | "Take a deep breath" |
| a doctor's instruction | `tikde tond kara` | "Turn your face to that direction" |
| leave-taking (greetings sheet) | `bay` (Marathi pronunciation of "bye") | "Bye" (telephone conversation 12.2.1) |

Phrase by phrase, outcome:

| Sheet | Phrase | Outcome |
|---|---|---|
| taxi | please wait here; take me home | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| shops | do you have a bigger size?; I want to return this; can I try it? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| eat | I am vegetarian; is this spicy? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| doctor | I have a fever; I need a doctor; where is the pharmacy?; where is the hospital? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| traffic | show your licence; I will pay the fine | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| rail | which platform?; which train goes to ...?; is this train late? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| hotel | I have a booking; room key please; what time is breakfast/check-out? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| post and bank | I want to send this parcel; I want to open an account; where is the post office? | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| greetings | sorry I am late; good morning | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |
| emergencies | call an ambulance; call the police; there is a fire | **not found** (Wikivoyage unreachable; no Wiktionary phrasebook entry; textbook scans have no Devanagari). The single words in C1 exist for it. |

The 30 phrases stay as the English sheet entries awaiting a Marathi reviewer. The only addition to the plan is that Wikivoyage (en and mr) must be on the network allowlist to source them.

## Verified counts

| Section | New verified rows |
|---|---|
| A1 songs | 7 (S1 to S7), with 6 creator dates (Ajay and Atul, Suresh Bhat, Kaushal Inamdar, Hridaynath Mangeshkar, Jabbar Patel, Kedar Shinde) |
| A2 television series | 4 new (T1 to T4), no person creator date available |
| A3 works dropped for creator dates | 3 of 4 now usable (Ventilator fully; Sant Dnyaneshwar and Sant Tukaram with Damle's dates); Shwaas still without Sandeep Sawant's birth year |
| A4 podcasts and radio | 0 |
| B multi-word | 8 structure-only compound rows resolved, row 16, 5 dative rows resolved (including वेड लागणे), 2 base words glossed (तटका, तकटून), 5 new Bhide phrase entries; 7 base words not found |
| C situations | 0 of ~30 phrases; 21 topic-word rows verified for the 10 sheets (C1) and 3 extra doctor-visit lines |

## Dropped, and why

- **Sandeep Sawant's birth year.** en.wikipedia, mr.wikipedia and Wikidata have none; britannica.com is not reachable from this session (WebFetch cannot resolve it; a plain `curl` got HTTP 403, and a browser User-Agent is not allowed). The Shwaas row stays creator-dateless or is replaced by another work.
- **Sheikh Fattelal's dates.** No page exists on en.wikipedia or mr.wikipedia under the names tried; Wikidata search for "Fattelal" is empty. The two films he co-directed use Damle as the creator.
- **Marathi-original podcasts and radio series.** No page found (see A4).
- **Molesworth's Marathi-English and English-Marathi dictionaries and the other dictionaries and primers on archive.org.** Reached, but the OCR has no Devanagari, so no headword can be searched; dli.gov.in, gutenberg.org (503), sanskritdocuments.org (403) and britannica.com did not answer.
- **Seven base words** (अटकेपार, विश्वे, सर्वस्व, पणाला, सामोरे, घिसाडघाई, पदरी) have no page that glosses them: the two wiktionaries have no entry, the 3,674-title list of mr.wiktionary has none, and the two Roman-script books do not contain them (सामोरे and पदरी have only the near forms समोर "in front" and पदर "lap").
- **The 30 situation phrases.** Not found (section C2).
- **Three TV facts not kept:** the number of episodes of Home Minister (6287 "as of 7 November 2026" in the infobox, a counter that changes) is not a quiz fact.

## Review-queue rule

Everything is `unreviewed`. The builder reports to `docs/review-queue/mr.md`: the Kombadi Palali year conflict (2005 song page, 2006 director's filmography), the Sairat single and album dates (11 April and 1 April 2016), the typing slip "साप" for "साफ" on mr.wiktionary तटका तोडणे, the non-standard "निकलांत निघने", the Manogat "suggested word" tags on स्वागतकक्ष and शुभेच्छा, and every Roman-script example from Dhongde and Wali that needs a Devanagari spelling.
