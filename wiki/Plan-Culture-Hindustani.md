# Plan: Hindustani genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task HI-001 of [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), written 2026-11-15 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Spanish](Plan-Culture-Spanish.md) and [Plan-Culture-Japanese](Plan-Culture-Japanese.md), for the tasks HI-010 to HI-013 (culture), HI-020 to HI-022 (proverbs), HI-030 to HI-033 (multi-word verbs), HI-060 and HI-061 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) (D1, D4, D5, D13). If this page and a task row differ, this page wins.

Hindustani (`hi`) is one course taught in two scripts, Devanagari and Perso-Arabic (Urdu). Every list below draws on both the Hindi and the Urdu tradition; each card carries its Devanagari `target` and its `target_scripts.perso_arabic` form.

## How this page was checked

- **Verified** means: the author of this page opened the cited page on 2026-11-15 and read the creator's years, and the work or collection, on it. The "Opened" column says which page: **E** en.wikipedia, **H** hi.wikipedia, **U** ur.wikipedia, **W** en.wiktionary (category page). Where the page gave two years, both are shown and the year is `circa`.
- **Unverified, builder must read** means no page was opened or the page did not state it. Nothing in that column is a fact. The builder reads the page (hi.wikipedia, ur.wikipedia, hi.wikisource first) and fills the column in its report, or drops the item and takes the next reserve.
- Specific poems and texts were **not** read by this page, only the creator's dates and works list. The builder reads the exact line on hi.wikisource or the creator's wiki page, and drops a line it could not read.
- Hosts that could not be reached from the session: rekhta.org, urdu.la.utexas.edu, wp.nyu.edu (not in the allowed network list). The builder may use Rekhta only if its own session can reach it; otherwise ur.wikipedia and ur.wikisource.
- Two page-to-page conflicts found while checking, both flagged below: Umrao Jan Ada (1899 on one page, 1905 on another), and Wali Deccani (page says it needs citations).

## Rules applied

- **Rights floor.** An author's death year must be 1955 or earlier (the validator's floor). `jurisdiction`: `IN` for a creator from India, `PK` for Pakistan, else the country the builder reads; the 1955 floor applies to all. An anonymous or traditional work needs a first publication before 1900. A work between those years goes to the reserve with a review-queue row. The floor catches typos; the reviewer owns the legal opinion.
- **Basis `public-domain` only, no `quotation` items.** `source` block as in batch 1 of the Japanese culture deck: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **One excerpt per card**: one couplet, verse, sentence or line, at most **25 words** (counted in whitespace-separated words; Devanagari and Perso-Arabic both have spaces). Archaic Braj, Awadhi or Persianate spelling is shown as the cited edition spells it where the learner can read it, otherwise in modern Hindustani spelling with the `edition` field saying so.
- **18 items per deck, short items first**, each A2 or B1. The first 18 candidates that pass are the deck; the rest are the reserve. Fewer than 18 may pass: the report says so, the deck is never padded.
- **Dates are never guessed.** `date` takes a shape the validator's `parse_years` accepts (a year, `c. YEAR` or `A-B`); explanations go in notes. An uncertain year is `circa`. Every unread or uncertain item goes to `docs/review-queue/hi.md`.
- **Attribution.** Where a verse is traditionally credited to a poet but the credit is doubtful (Amir Khusro's Hindavi verses, Surdas's Sur Sagar, Raidas, Namdev, Baba Farid), the card says "attributed to" and the `source.author` follows. That is a reviewer check.
- **Translations** are the builder's own plain renderings, never a quotation of anyone's translation.
- **Both scripts.** Culture 1 and 3 may balance Hindi and Urdu; culture 2 is Urdu-script-first with Devanagari on the card. The builder transliterates with the repo tools and never writes `ipa` or `reading` by hand (`python3 tools/transcribe.py hi "<text>"`).
- **Creators** (file `decks/creators/hi.yaml`, created by HI-010): a short A2-level English bio, `born` and `died` (`circa` if uncertain), era, one legacy line with a checkable item and a source link, no image.
- **Order of work.** HI-010 to HI-013 run one after another because they share `creators/hi.yaml`; recommendations (HI-060, HI-061) follow on the same file. Proverbs and multi-word decks are independent of that lane.
- **Header.** `language: { code: "hi", iso639_3: "hin", name: "Hindustani", script: "devanagari", scripts: ["devanagari", "perso_arabic"], tts: "hi-IN", icon: "हि" }`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`.

## Culture decks (HI-010 to HI-013, 4 x 18 plus reserves)

### HI-010, `hi-culture-1`: bhakti, sant and Sufi poets (hi-4000 to 4049)

All 18 verified. Opened: E for all, H also for Kabir.

| # | Work to read | Creator, dates read | Opened | Rights verdict |
|---|---|---|---|---|
| 1 | a Sakhi couplet (Bijak / Sakhi) | Kabir; 1398 to 1494 or 1518 (pages disagree; E says death year not given) | E, H | passes (any proposed year before 1955); `circa`; attributed |
| 2 | Dohavali, or a verse of Ramcharitmanas | Tulsidas; c. 1532 to c. 1623 | E | passes |
| 3 | "Payoji maine Ram Ratan dhan payo" | Mirabai; c. 1498 to c. 1546 (E also says 1547) | E | passes; `circa`; attributed |
| 4 | a pad of Sur Sagar | Surdas; c. 1483 to c. 1563 | E | passes; `circa`; Sur Sagar partly by later poets |
| 5 | a pad | Raidas (Ravidas); dates disputed, latest proposed 1528 | E | passes; `circa`; attributed |
| 6 | a doha | Rahim (Abdul Rahim Khan-i-Khana); 1556 to 1627 | E | passes (E does not name Rahim Satsai) |
| 7 | a Hindavi couplet | Amir Khusro; 1253 to 1325 | E | passes; E says no evidence the Hindavi verses are his before the 18th century, so "attributed" |
| 8 | the kafi "Bullah Ki Jaana" | Bulleh Shah; c. 1680 to 1757 (one scholar 1758) | E | passes; Punjabi, builder checks the line is readable at A2/B1 |
| 9 | a verse of Japji Sahib | Guru Nanak; 1469 to 1539 | E | passes; Gurmukhi source, shown in Devanagari and Perso-Arabic |
| 10 | a verse of Dadu Anubhav Vani | Dadu Dayal; 1544 to 1603 | E | passes |
| 11 | a verse of Padmavat (1540 to 1541) | Malik Muhammad Jayasi; 1477 (debated) to 1542 | E | passes; Awadhi |
| 12 | a verse of Premavatika | Raskhan; died 1628 (birth 1548 or later, disputed) | E | passes; `circa` |
| 13 | a shloka | Baba Farid; c. 1188 to c. 1266 | E | passes; some shlokas may be by a later Farid |
| 14 | a pad | Namdev; traditional c. 1270 to c. 1350, other estimates | E | passes; `circa`; some pads misattributed |
| 15 | a couplet of Satasai | Bihari (Bihari Lal); 1595 to 1663 | E | passes |
| 16 | a verse of Abyat-e-Bahu | Sultan Bahu; 1630 to 1691 | E | passes; Punjabi |
| 17 | a verse of Rasikpriya (1591) | Keshavdas; c. 1555 to c. 1617 | E | passes |
| 18 | a verse of Heer (1766 version) | Waris Shah; 1722 to 1798 or 1799 (page disagrees) | E | passes; Punjabi, `circa` |

Reserve, **unverified, builder must read**: Malukdas, Paltu Sahib, Charandas, Sahajo Bai, Dharamdas. This task creates `decks/creators/hi.yaml` (`kind: "creators"`, `id: "creators-hi"`, `language: "hi"`) with eras (read from the builder's sources) and the 18 creators.

### HI-011, `hi-culture-2`: classical Urdu poets (ghazal, nazm, marsiya) (hi-4050 to 4099)

18 verified, 2 unverified in the reserve. Opened: E for all; U also for Ghalib. Genres: ghazal unless noted.

| # | Work to read | Creator, dates read | Opened | Rights verdict |
|---|---|---|---|---|
| 1 | a ghazal | Muhammad Quli Qutb Shah; 1565 to 1612 | E | passes; Kulliyat, first Urdu diwan |
| 2 | a ghazal | Wali Mohammed Wali; 1667 to 1707 (E: needs citations) | E | passes; `circa` |
| 3 | a qasida or ghazal | Sauda; 1713 to 1781 | E | passes |
| 4 | a ghazal | Khwaja Mir Dard; 1720 to 1785 | E | passes |
| 5 | a ghazal from Kulliyat-e-Mir | Mir Taqi Mir; 1723 to 1810 | E | passes |
| 6 | a ghazal; or a line of Rani Ketki Ki Kahani | Insha Allah Khan Insha; c. 1752 to 1817 | E | passes |
| 7 | a ghazal | Ghulam Hamdani Mushafi; 1751 to 1844 (page also tags 1824) | E | passes; `circa` |
| 8 | a ghazal from Diwan-e-Aatish | Haidar Ali Atish; 1764 to 1846 (infobox 1847) | E | passes; `circa` |
| 9 | a ghazal | Zauq; 1789 to 1854 | E | passes |
| 10 | a ghazal | Momin Khan Momin; 1800 to 1852 | E | passes |
| 11 | a ghazal from Diwan-e-Ghalib | Mirza Ghalib; 27 Dec 1797 to 15 Feb 1869 | E, U | passes |
| 12 | "Lagta nahin hai dil mera" | Bahadur Shah Zafar; 1775 to 1862 | E | passes |
| 13 | marsiya "Jab qat'a ki masafat-e-shab aftab ne" (as E titles it) | Mir Anees; 1800 or 1803 to 1874 | E | passes; marsiya, builder takes one short stanza |
| 14 | a marsiya or salam | Mirza Dabeer; 1803 to 1875 | E | passes |
| 15 | a ghazal from Gulzar-e-Daagh | Dagh Dehlvi; 1831 to 1905 | E | passes |
| 16 | a ghazal | Ameer Minai; 1829 to 1900 | E | passes |
| 17 | a verse of Musaddas-e-Hali (1879) | Altaf Hussain Hali; 1837 to 1914 | E | passes; nazm / musaddas |
| 18 | Banjaranama, or a festival nazm | Nazeer Akbarabadi; 1735 (uncertain) to 1830 | E | passes; nazm |

Reserve, **unverified, builder must read**: Imam Bakhsh Nasikh, Mustafa Khan Shefta. Each marsiya or nazm card is one short stanza, 25 words at most.

### HI-012, `hi-culture-3`: modern Hindi and Urdu prose and verse, authors who died by 1955 (hi-4100 to 4149)

21 candidates verified; the first 18 are the deck, the last 3 the reserve. The floor is each author's own death year. Opened: E.

| # | Work to read | Creator, dates read | Verdict and note |
|---|---|---|---|
| 1 | "Idgah" (Chand, Aug 1933) | Premchand; 1880 to 8 Oct 1936 | passes; Hindi and Urdu both |
| 2 | "Panch Parameshvar" (Sarasvati, June 1916) | Premchand | passes |
| 3 | a poem from Bang-e-Dara (1924); the poem text is unread, builder reads it | Muhammad Iqbal; 1877 to 21 Apr 1938 | passes; E does not mention Shikwa, Jawab-e-Shikwa or "Lab pe aati hai dua" |
| 4 | "Sare Jahan se Accha" (early period, before 1905 per E) | Iqbal | passes |
| 5 | Andher Nagari (1881) | Bharatendu Harishchandra; 1850 to 1885 | passes |
| 6 | Kamayani (1936), a verse | Jaishankar Prasad; 1889 to 1937 | passes |
| 7 | "Usne Kaha Tha" (1915) | Chandradhar Sharma Guleri; 1883 to 1922 | passes |
| 8 | "Jhansi Ki Rani" | Subhadra Kumari Chauhan; 1904 to 1948 | passes; year of the poem not on E |
| 9 | "Toba Tek Singh" (1955) or "Khol Do" (1948) | Saadat Hasan Manto; 1912 to 18 Jan 1955 | passes, near the floor; the reviewer checks the Pakistani term |
| 10 | Subh-e-Watan, or "Ramayan ka ek Scene" | Brij Narayan Chakbast; 1882 to 1926 | passes |
| 11 | "Chupke Chupke Raat Din" | Hasrat Mohani; 1875 (some sources 1880, 1881) to 13 May 1951 | passes; `circa` birth |
| 12 | Umrao Jan Ada | Mirza Hadi Ruswa; 1857 to 21 Oct 1931 | passes; **first publication 1905 on Ruswa's page, 1899 on the 1981 film's page**, both before 1955 floor and any date goes in notes as `circa` |
| 13 | Mirat-ul-Uroos (1869) | Nazir Ahmad Dehlvi; 1831 to 1912 | passes |
| 14 | Hungama Hai Kyon Barpa | Akbar Allahabadi; 1846 to 1921 | passes; year of the ghazal not on E |
| 15 | Aab-e-Hayat (1880) | Muhammad Husain Azad; 1830 to 1910 | passes |
| 16 | "Aawara" | Majaz; 1911 to 5 Dec 1955 | passes, near the floor; poem date not on E |
| 17 | Hindi Sahitya Ka Itihas (1928 to 1929) | Ramchandra Shukla; 1884 to 1941 | passes |
| 18 | Lokokti Shatak | Pratap Narayan Mishra; 1856 to 1894 | passes |

Reserve (also verified on E): Mahavir Prasad Dwivedi, 1864 to 1938 (Saraswati editor, 1903 to 1920); Shibli Nomani, 1857 to 1914 (Sher-ul-Ajam); Sir Syed Ahmad Khan, 1817 to 1898 (Asar-us-Sanadid, 1847). Two more opened but with the work not dated: Devaki Nandan Khatri, 1861 to 1913 (Chandrakanta, year not on E: **unverified**); Ayodhya Singh Upadhyay Hariaudh, 1865 to 1947 (Priyapravas, year not on E: **unverified**). Authors who fail the floor are not candidates (for example any poet who died after 1955); the builder reads each death year and drops what fails.

### HI-013, `hi-culture-4`: anonymous and traditional works before 1900 (hi-4150 to 4199)

A song or text whose author or first printing the builder cannot show goes to the reserve. **Fewer than 18 are expected to pass; the report says so.** 10 verified, 8 unverified.

| # | Candidate work | Creator | Opened | What was read | Verdict |
|---|---|---|---|---|---|
| 1 | Panchatantra, a short tale | traditional, narrator Vishnusharma (E: both names probably fictitious) | E | current form 4th to 6th century CE; Pahlavi translation c. 550 CE | passes |
| 2 | Hitopadesha, a short tale | Narayana (E: composed c. 800 to 950 CE, text of 12th century; oldest manuscript 1373) | E | named author, medieval | passes |
| 3 | Baital Pachisi, one tale | anonymous frame story | E | oldest recension Somadeva 1070 CE; Braj version by Surat Kabishwar between 1719 and 1749; Hindustani version 1805 | passes |
| 4 | Singhasan Battisi, one tale | author and date unknown (E) | E, H | E: Hindi versions by Lallu Lal and Kazim Ali Javan, year not given; H gives no author or Hindi dates | passes; Hindi edition year **unverified** |
| 5 | Dastan-e-Amir Hamza, a short passage | anonymous oral roots | E | earliest printed Urdu version 1801 (Khalil Ali Khan Ashk); Nawal Kishore edition 1871 | passes |
| 6 | Alha-Khand, a short verse | Jagnik (believed); original lost | E | Charles Elliott's recension 1865; first printed edition 1871 | passes |
| 7 | Kajari, a folk song | traditional | E | folk genre; Pandit Beniram composed Kajari songs in the 1860s | passes if the builder names one song and its record |
| 8 | Hindavi paheli or couplet | attributed to Amir Khusro (1253 to 1325) | E | E: riddles attributed, but no evidence the Hindavi verses are his before the 18th century | passes if the builder shows a printing before 1900; else reserve |
| 9 | Bagh-o-Bahar, an opening line | Mir Amman; 1748 to 1806 | E | first published 1804, Calcutta | passes; named author, so `source.author` is his |
| 10 | Prem Sagar, a line | Lallu Lal; composed 1804 to 1810; died 1835 | E | published partly 1805, completed 1810 | passes |
| 11 | lullaby "Chanda mama door ke" | traditional | none | not opened | **unverified**, needs a record before 1900 |
| 12 | nursery rhyme "Machhli jal ki rani hai" | traditional | none | not opened | **unverified** |
| 13 | a Holi folk song | traditional | none | not opened | **unverified** |
| 14 | a Sohar (birth song) | traditional | none | not opened | **unverified** |
| 15 | a Birha song | traditional | none | not opened | **unverified** |
| 16 | thumri "Babul mora naihar chhooto jaye" | attributed in tradition | none | the page tried returned 404 | **unverified**; attribution and date to be read |
| 17 | a Barahmasa folk poem | traditional | none | not opened | **unverified** |
| 18 | a tale from an Urdu qissa (Tota Kahani, Gul-e-Bakawali) | named in tradition | none | not opened | **unverified** |

Reserve: a Kabir ulatbansi, a paheli from a printed 19th-century collection (builder names it). The deck takes only items the builder can show a pre-1900 record for.

## Proverbs (HI-020 to HI-022, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`. The `source` block has `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`. Each card carries a `literal` note and a meaning, level A2 or B1. Sources the builder cites with page and date: **en.wiktionary Category:Hindi proverbs** (42 entries, opened), **Category:Hindi idioms** (210 entries, opened), **Category:Urdu proverbs** (5 entries, opened), **en.wikiquote "Hindi proverbs"** (14 entries, opened). **A kahavat whose entry page the builder did not read is dropped.** The titles below were read on the category pages; the meaning, literal gloss and theme are for the builder to read on the entry page (the category pages show titles only).

| Task | Deck | Themes, in order | Ids |
|---|---|---|---|
| HI-020 | `hi-proverbs-1` | blame and guilt, proof and show-off, life and regret, effort and willpower, insiders and strangers, money and value, patience, shared work | hi-4200 to 4249 |
| HI-021 | `hi-proverbs-2` | rulers and the powerful, pride and fame, learning and ignorance, family and likeness, waiting and delay, neighbours, luck, change over time | hi-4250 to 4299 |
| HI-022 | `hi-proverbs-3` | work and idleness, fate and results, custom and place, trust and speech, danger, courage and talk, sense and nonsense, deals and friends | hi-4300 to 4349 |

Candidates (Devanagari as it appears on the category page), all titles read:

- **HI-020 candidates (20):** उल्टा चोर कोतवाल को डांटे; हाथ कंगन को आरसी क्या; जान है तो जहान है; जिसकी लाठी उसकी भैंस; घर का भेदी लंका ढाये; बंदर क्या जाने अदरक का स्वाद; नाच न जाने आँगन टेढ़ा; दूर के ढोल सुहावने लगते हैं; घर की मुर्ग़ी दाल बराबर; अंत भला तो सब भला; अकेला चना भाँड़ नहीं फोड़ता; एक हाथ से ताली नहीं बजती; चिराग़ तले अँधेरा; ऊँची दुकान फीका पकवान; जहाँ चाह वहाँ राह; जैसी करनी वैसी भरनी; सब्र का फल मीठा होता है; अधजल गगरी छलकत जाय; जल में रहकर मगर से बैर ठीक नहीं (wikiquote); अब पछताए होत क्या जब चिड़िया चुग गई खेत (wikiquote).
- **HI-021 candidates (20):** अंधों में काना राजा; अपनी गली में कुत्ता भी शेर होता है; काला अक्षर भैंस बराबर; घर का जोगी जोगड़ा, आन गाँव का सिद्ध; चार दिन की चाँदनी; चोर की दाढ़ी में तिनका; जैसा बाप, वैसा बेटा; दिल्ली अभी दूर है; न रहेगा बाँस न बजेगी बाँसुरी; बकरे की माँ कब तक ख़ैर मनायेगी; मुल्ला की दौड़ मस्जिद तक; यथा राजा तथा प्रजा; यह मुँह और मसूर की दाल; रस्सी जल गई पर बल नहीं गया; सौ सुनार की, एक लोहार की; एक गंदी मछली पूरे तालाब को गंदा कर देती है; कुआँ प्यासे के पास नहीं जाता, प्यासा ही कुएँ के पास जाता है; दिल्ली का लड्डू; जाति ना पूछो साधु की; पूछ लीजिए ज्ञान; आम के आम गुठलियों के दाम (idioms category).
- **HI-022 candidates (20):** ख़ाली दिमाग़ शैतान का घर; खोदा पहाड़ निकली चुहिया; गेहूँ के साथ घुन भी पिसता है; घर में नहीं दाने अम्मा चली भुनाने; चमड़ी जाए पर दमड़ी न जाए; जैसा देस वैसा भेस; जो गरजते हैं वो बरसते नहीं; डूबते को तिनके का सहारा; ढाक के तीन पात; दो नावों की सवारी; नाम बड़े और दर्शन छोटे; बोया पेड़ बबूल का तो आम कहाँ से होए; मन चंगा तो कठौती में गंगा; मरता क्या न करता; मियाँ बीवी राज़ी तो क्या करेगा काज़ी; लातों के भूत बातों से नहीं मानते; लौट के बुद्धू घर को आए; सर सलामत तो पगड़ी हज़ार; साँच को आँच नहीं; दूध का जला छाछ भी फूँक फूँक कर पीता है.
- **Urdu-script and Urdu-tradition entries** (opened, Category:Urdu proverbs): رات گئی بات گئی; صبر کا پھل میٹھا ہوتا ہے (the Hindi form सब्र का फल मीठा होता है is also listed); ناچ نہ جانے آنگن ٹیڑھا (also in Hindi, HI-020); گاتے گاتے کلاونت ہو جاتے ہیں; گانتھ کا پورا عقل کا اندھا. The builder puts the two that are not yet in a Hindi deck (رات گئی بات گئی; گاتے گاتے کلاونت ہو جاتے ہیں) into HI-021 and HI-022 first; the rest of the five go in as the Perso-Arabic `target_scripts` of the matching Hindi card.
- **Reserve (read on the idioms category, usable if an entry page fails):** एक पंथ दो काज; खट्टे अंगूर; बहती गंगा में हाथ धोना; अंधेर नगरी चौपट राजा; कंगाली में आटा गीला; ऊँट के मुँह में जीरा; आस्तीन का साँप.
- HI-021 and HI-022 list the earlier decks' targets first and use none of them again. Some titles on the idioms category are idioms rather than proverbs (those go to HI-032); the builder decides by the entry page's part of speech and replaces from the reserve. A kahavat may sit on both category pages in two spellings (for example दूर के ढोल सुहावने लगते हैं and दूर के ढोल सुहावने होते हैं); use one.

## Multi-word verbs (HI-030 to HI-033, 4 x 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part; parts already taught are written by `ref`, a part not yet a card gets a card. Shape: `ja-multiword-te-auxiliaries`. The repo's rules decks `hi-grammar-conjunct-verbs` and `hi-grammar-compound-verbs` were read on disk: the cards named there already exist (reuse by `ref`); everything else is a candidate for the builder to confirm. A pattern the builder cannot support is reported, not replaced from memory. Source for the constructions: en.wikipedia "Hindustani grammar" (opened: compound verbs with ānā, jānā, rahnā; ko marks dative subjects) and the "Dative subject" page (opened: one Hindustani example with ko).

| Task | Deck and `pattern_family` | Candidates (Devanagari) | Ids |
|---|---|---|---|
| HI-030 | `hi-multiword-conjunct`, `conjunct-verb` | **Already cards** (read on disk): काम करना, बात करना, मदद करना, इंतज़ार करना, शुरू करना, ख़त्म करना, कोशिश करना, फ़ोन करना, साफ़ करना, शादी करना, आराम करना, याद करना, ग़लती करना, याद आना, देर होना, डर लगना. **To confirm, unverified:** इस्तेमाल करना, पसंद करना, इनकार करना, शुरू होना, तैयार होना, ख़ुश होना, इकट्ठा करना, ज़िक्र करना | hi-4350 to 4399 |
| HI-031 | `hi-multiword-compound`, `vector-verb` | **Already cards** (read on disk): खा लेना, दे देना, रख देना, आ जाना, हो जाना, सो जाना, बैठ जाना, समझ जाना, भूल जाना. **To confirm, unverified:** उठ जाना, पी लेना, कर लेना, कर देना, कह देना, देख लेना, ले आना, ले जाना, निकल जाना, चल पड़ना, बोल उठना, गिर पड़ना, मार डालना | hi-4400 to 4449 |
| HI-032 | `hi-multiword-muhavare`, `idiom` | read as titles on the idioms category (W): आग बबूला होना; आईना दिखाना; अपना उल्लू सीधा करना; आटे दाल का भाव मालूम होना; कलेजा फटना; कमर तोड़ना; खट्टे अंगूर; ख़याली पुलाव; घड़ियाली आँसू; घोड़े बेचकर सोना; चुल्लू भर पानी में डूब मरना; छत्तीस का आँकड़ा; जले पर नमक छिड़कना; दाल में कुछ काला होना; दिन में तारे देखना; नौ दो ग्यारह होना; नाक कटना; मुँह मीठा करना; सिट्टीपिट्टी गुम होना; दम नाक में आना | hi-4450 to 4499 |
| HI-033 | `hi-multiword-ko-experiencer`, `ko-experiencer` | **Already cards** (read on disk): मुझे ... पसंद है, मुझे अच्छा लगता है, आपको ... चाहिए, मुझे ... की ज़रूरत है. **To confirm, unverified:** भूख लगना, प्यास लगना, ठंड लगना, डर लगना (already a card), नींद आना, गुस्सा आना, याद आना (already a card), शर्म आना, समझ आना, पता होना, मालूम होना, मुझे हिंदी आती है (आना, "know a skill"), बुखार होना, दर्द होना, बुरा लगना | hi-4500 to 4549 |

HI-030 writes one card per conjunct verb with the noun and the light verb as `words`, as `मदद करना`. HI-033 teaches the pattern with `मुझे` / `आपको` / `उसे` as the experiencer, so the card text is a short sentence, not a bare verb; the builder shows the dative form on the card.

## Recommendations (HI-060 and HI-061, 10 + 10)

File `decks/recommendations/hi.yaml`, in the shape of `recommendations/es.yaml`: `id: "hi-rec-<name>"`, `medium`, `title { text }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each that only someone who watched, read or heard the work could answer, `tags: ["unreviewed"]`. No quotation and no link. These are not public domain (`basis: "source-yourself"`, see [Plan-Language-Completeness](Plan-Language-Completeness.md)), so rights are not a gate; year and creator are from the page named, opened on 2026-11-15. A work whose facts the builder cannot read is replaced from the reserve. Creators are added to `creators/hi.yaml` where missing.

| Task | Medium | Title | Creator and year as read | Opened | Language note |
|---|---|---|---|---|---|
| HI-060 | film | Sholay | Ramesh Sippy; 1975 | E | Hindi |
| HI-060 | film | Mughal-e-Azam | K. Asif; 1960 | E | Hindi and Urdu |
| HI-060 | film | Pyaasa | Guru Dutt; 1957 | E | Hindi and Urdu |
| HI-060 | film | Pakeezah | Kamal Amrohi; 1972 | E | Hindustani |
| HI-060 | film | Umrao Jaan | Muzaffar Ali; 1981 | E | Urdu |
| HI-060 | film | Dilwale Dulhania Le Jayenge | Aditya Chopra; 1995 | E | Hindi |
| HI-060 | film | 3 Idiots | Rajkumar Hirani; 2009 | E | Hindi |
| HI-060 | film | Lagaan | Ashutosh Gowariker; 2001 | E | Hindi |
| HI-060 | film | Jaane Bhi Do Yaaro | Kundan Shah; 1983 | E | Hindi |
| HI-060 | series | Panchayat | The Viral Fever (TVF); first season 2020 | E | Hindi |
| HI-061 | series | Dhoop Kinare | writer Haseena Moin; 1987, PTV | E | Urdu |
| HI-061 | series | Malgudi Days | Shankar Nag (seasons 1 to 3), Kavitha Lankesh (season 4); aired 1986 to 2006 | E | Hindi and English |
| HI-061 | book | Raag Darbari | Shrilal Shukla (1925 to 2011); 1968 | E | Hindi |
| HI-061 | book | Gunahon Ka Devta | Dharmveer Bharti; 1949 | E | Hindi |
| HI-061 | book | Aag Ka Darya | Qurratulain Hyder; 1959 | E | Urdu |
| HI-061 | book (verse) | Madhushala | Harivansh Rai Bachchan; 1935 | E | Hindi |
| HI-061 | book | Tamas | Bhisham Sahni (1915 to 2003); 1974 (E: original Hindi) | E | Hindi |
| HI-061 | song | "Lag Jaa Gale", from Woh Kaun Thi? | music Madan Mohan, lyrics Raja Mehdi Ali Khan, voice Lata Mangeshkar; 1964, dir. Raj Khosla | E | Hindustani |
| HI-061 | song | "Hum Dekhenge" | Faiz Ahmad Faiz, written 1979; Iqbal Bano performed it in 1986 | E | Urdu |
| HI-061 | podcast | **Unverified, builder must read** | candidates Sonu ki Diary (NYU, narrative series for learners), Learn Hindi On The Go (Jaibodh Pandey, Shraddha Pandey, Ritansh), Fluent Fiction - Hindi; seen only in search snippets, no page opened | none | Hindi |

The medium for the song entries is `song`, for Madhushala `book`. Reserve, **unverified**: Hum Log (1984, E lists it as an Indian soap opera, language and channel not stated there), Mother India (Mehboob Khan, 1957, verified on E but a film much like the others), Ranjish Hi Sahi (Mehdi Hassan 1927 to 2012; E lists 1981; poet Ahmed Faraz per the builder to read). HI-060 has the 9 films and 1 series, HI-061 the rest. The Tamas year shown is that of the Hindi novel per E. The Hum Dekhenge pairing ties to the Faiz creator page; Faiz's own death year is for the builder to read. Counted: 19 verified entries, 1 unverified (the podcast).

## Review-queue rule

Everything is `unreviewed`. Each unread, uncertain or dropped item is a row in the builder's report, in the table shape of `docs/review-queue/hi.md`; the tasks HI-120 to HI-122 collect the rows into that file, one batch at a time. Every row where the page named a conflict (Kabir, Raidas, Mirabai, Umrao Jan Ada, Wali, Waris Shah, Hasrat Mohani's birth) is a review-queue row by default.

## Not planned, and open questions for the owner

1. **Which script leads on a culture card.** Culture 2 is Urdu-script-first by genre (ghazal, marsiya); culture 1 and 3 are mixed. Confirm the learner's chosen script decides the order on the card, as it does elsewhere in the course.
2. **Punjabi and Marathi texts in a Hindustani deck.** Bulleh Shah, Sultan Bahu, Waris Shah, Guru Nanak, Baba Farid and Namdev wrote in Punjabi, Sant Bhasha or Marathi. The builder picks lines a Hindustani reader can follow; if the owner wants strictly Hindi and Urdu, these six move to the reserve and culture 1 is filled from Malukdas, Paltu Sahib and the others once verified.
3. **Rekhta.** The session could not reach rekhta.org. Allow it in the network settings, or say whether ur.wikipedia and ur.wikisource are enough for Urdu texts.
4. **Hindi and Urdu term of copyright.** The floor is the plan's rule (author died 1955 or earlier). A reviewer should confirm the legal term before the decks ship, especially for Manto and Majaz, who died in 1955.
5. **A resources file** (`hi-resources.yaml`, as `ja-resources.yaml`). Not on the checklist, so not planned.
