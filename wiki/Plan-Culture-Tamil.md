# Plan: Tamil genre decks, verified sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task TA-001 of [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md), written 2026-11-15. It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Telugu](Plan-Culture-Telugu.md) and [Plan-Culture-French](Plan-Culture-French.md), for the tasks TA-010 to TA-013 (culture), TA-020 to TA-022 (proverbs), TA-030 to TA-032 (multi-word verbs) and TA-060 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) (D1, D4, D5, D13). The Source-it-yourself rules are in [Plan-Language-Completeness](Plan-Language-Completeness.md#source-it-yourself-works-and-the-rights-floor).

**What "verified" means on this page.** Unlike the Telugu and French pages, every entry below was **read** by the author on 2026-11-15 at the page named in the "Read at" column, through the MediaWiki pages of ta.wikisource, en.wikisource, en.wikipedia and en.wiktionary. Nothing was written from memory. Dates, lifespans, page structure and attributions are what the named page says, with the disagreements between pages recorded rather than resolved. Nothing was run locally (no tests, no validator, no `tools/transcribe.py`). The reads went through a page-summarising fetch tool, so a Tamil string copied here may carry a slip: **the builder re-reads each page, copies the text from it, and takes `reading` and `ipa` from the tool, never from this page.** Anything that could not be read to the point of use is under [Dropped, unverifiable](#dropped-unverifiable), not in a deck list. No Tamil speaker reviews the decks (owner, 2026-11-13): everything ships `unreviewed`, and doubts go to `docs/review-queue/ta.md`.

Quotations: this page quotes no verse. The only Tamil strings are proverb texts (section 2) and verb headwords (section 3), each of them well under 25 words, and work titles.

## Rules applied

- **Rights floor** (the Telugu page's rule, validator floor 1955). A named author must have died in 1955 or earlier. India's term is life plus 60, so the floor is stricter than the law. An anonymous work needs a first publication before 1900. Basis `public-domain` only for culture cards, no `quotation` items. A work not in the public domain is a recommendation (source-yourself), where nothing of it is shipped.
- **Ancient works with no datable author.** The Sangam anthologies, the Kural, the Naladiyar, the epics and the older devotional works have no author whose death year any page gives (the Kural, Silappatikaram and Tirumantiram pages give only a range of centuries, and the en.wikipedia pages note disputed attribution). For these the builder uses the anonymous rule (`author: anonymous`, a `date` the validator's `parse_years` accepts, first year before 1900) and puts the attributed name in the notes, or leaves the item out if the validator refuses the date shape. **Not checked here against the validator**; the builder reports the result. A named ancient poet is never given an invented `born` or `died`; `circa` with the century range the page states, or no creator entry.
- **Text as printed on the cited Wikisource page**, not modernised. The Wikisource pages cite no print edition for most of these works (stated per row). The builder writes `edition` as "ta.wikisource.org, page title, revision" and the `url`, and says in the notes where a page names a printed edition. Wikisource's CC BY-SA 4.0 notice covers the transcription; the underlying work is what the rights basis rests on.
- **One excerpt per card**: one verse or one short line, at most 25 words. **At most 3 cards from one work** (4 for a work with sub-collections), so a deck holds a spread, not one work. **18 items per deck**; the report says so when fewer pass, the deck is never padded.
- **`reading` and `ipa` from `tools/transcribe.py ta`**: it does not exist yet (TA-110). Culture, proverb and verb builds that need a reading start only after TA-110 is merged. Readings are based on ISO 15919 (never "strictly follow it").
- **Creators** (file `decks/creators/ta.yaml`, created by the first culture task): lifespans only as read (below); eras confirmed by the builder from its own reads.
- **Translations** are the builder's own plain renderings.
- **Pacing.** Reads were polite (one page at a time, no retries). A builder that gets HTTP 429 waits and drops what it cannot read after a polite retry.

## 1. Culture decks (TA-010 to TA-013)

**Counts.** 25 works read to the point of use (text seen on the page); the four decks below hold them. With the 3-card cap the capacity is above 18 per deck for decks 1 to 3; deck 4 holds 4 works read (its capacity is about 12 to 16, so it ships short unless a Bharathiyar collection page is read, see the dropped list). 12 further candidates were read only to an index page and are dropped until their text is read (40 dropped items in all, see the end of the page).

Common to every row: **jurisdiction IN**. "Dates" are only what the page named in the row states.

### TA-010, `ta-culture-1`: Sangam anthologies and early classics (9 works read)

| # | Work | Creator (as the page names them) | Dates as read | Rights basis | Read at |
|---|---|---|---|---|---|
| 1 | Kuruntokai, poems 1 to 10 (ten different poets are named on the page, such as Thippuththolar, Iraiyanar, Oramboakiyar) | 205 ancient poets, compiler Purikko (en.wikipedia) | 100 to 300 CE (Takahashi) or 1st century BCE to 2nd century CE (Zvelebil), en.wikipedia | ancient, anonymous rule; no author death year | [ta.wikisource](https://ta.wikisource.org/wiki/குறுந்தொகை_01_முதல்_10_முடிய), [en.wikipedia](https://en.wikipedia.org/wiki/Kuruntokai). The page cites no printed edition |
| 2 | Purananuru, poems 1 to 10 (ten poets named, such as Perunthevanar, Paranar, Kapilar) | 157 poets, 14 anonymous (en.wikipedia) | 1st century BCE to 5th century CE, mostly 2nd to 5th (Zvelebil) | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/புறநானூறு/பாடல்_01-10), [en.wikipedia](https://en.wikipedia.org/wiki/Purananuru). No printed edition cited |
| 3 | Akananuru, poems 1 to 10 (the page names a poet only for poem 10, Ammuvanar) | 144 poets, 3 anonymous | earliest layer 1st century BCE to 2nd century CE, later layers to 5th century CE | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/அகநானூறு/01_முதல்_10_முடிய), [en.wikipedia](https://en.wikipedia.org/wiki/Akananuru). No printed edition cited |
| 4 | Kalittokai, Palaikkali, poems 2 to 10 | Perunkadungon named on the page (the work's authorship is disputed, en.wikipedia) | 3rd century CE or later (en.wikipedia) | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/கலித்தொகை/1.பாலைக்கலி/02-10), [en.wikipedia](https://en.wikipedia.org/wiki/Kalittokai). No printed edition cited; includes editorial commentary, text only is used |
| 5 | Pattinappalai, 301 lines | Katiyalur Uruttirankannanar (en.wikipedia), Kadiyalur Uruthirankannanar (ta.wikisource) | 1st to 2nd century CE (Zvelebil) | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/பட்டினப்பாலை), [en.wikipedia](https://en.wikipedia.org/wiki/Pattinappalai) |
| 6 | Tirukkural, chapter 1 (10 kurals) in the Parimelazhagar edition | Valluvar, "traditionally credited", the text itself does not name its author (en.wikipedia) | proposals from 300 BCE to the 5th century CE; "current scholarly consensus" about 500 CE (Blackburn, cited by en.wikipedia); 1,330 couplets in 133 chapters | ancient, anonymous rule; the 1921 government year 31 BCE is not a date to use | [ta.wikisource chapter 1](https://ta.wikisource.org/wiki/திருக்குறள்_பரிமேலழகர்_உரை/அறத்துப்பால்/1.கடவுள்வாழ்த்து) (section "பிழைநீக்கிய மெய்ப்பதிப்பு", revision 1490389), [en.wikipedia](https://en.wikipedia.org/wiki/Tirukkural). Other chapters exist as pages of the same pattern (31 chapter pages confirmed to exist by a title search; only chapter 1 was read) |
| 7 | Naladiyar, invocation and chapter 1 (poems 1 to 10) | Jain monks, no poet named; 400 quatrains | 100 to 500 CE (en.wikipedia); the page's only date is "Chennai, 1940", the publication of the Vedagiri Mudaliar edition whose commentary the page shows | ancient, anonymous rule; use the verse only, never the 1940 commentary | [ta.wikisource](https://ta.wikisource.org/wiki/நாலடியார்), [en.wikipedia](https://en.wikipedia.org/wiki/Naladiyar) |
| 8 | Silappatikaram, Madurai Kandam, canto 20 (about 85 to 90 lines; take a few lines) | Ilango Adigal, traditional, "doubtful" (en.wikipedia) | 5th century CE in most sources, estimates 2nd to 6th | ancient, anonymous rule | [ta.wikisource (via the API parse of the page)](https://ta.wikisource.org/wiki/சிலப்பதிகாரம்/மதுரைக்_காண்டம்/20.வழக்குரை_காதை), [en.wikipedia](https://en.wikipedia.org/wiki/Silappatikaram). No edition cited on the page. The direct page URL with a dot in it returned 404, so link with the `?title=` form |
| 9 | Manimekalai (30 cantos with a prologue; text seen through canto 17) | Seethalai Saathanar | 2nd to 6th century (en.wikipedia) | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/மணிமேகலை), [en.wikipedia](https://en.wikipedia.org/wiki/Manimekalai) |

### TA-011, `ta-culture-2`: devotional verse and the epic (6 works read)

| # | Work | Creator | Dates as read | Rights basis | Read at |
|---|---|---|---|---|---|
| 1 | Tiruppavai, 30 verses | Andal | "8th century CE" (en.wikipedia); the ta.wikisource page gives no date | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/திருப்பாவை), [en.wikipedia](https://en.wikipedia.org/wiki/Andal) |
| 2 | Nachiyar Tirumozhi, 143 verses in 14 decads, verses 504 to 646 of the Nalayira Divya Prabandham | Andal | as above | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/நாச்சியார்_திருமொழி) |
| 3 | Thiruvasagam, "Tiruppalliyezhuchi" (10 verses) | Manikkavacakar | no dates; 3rd or 6th century CE according to scholars (en.wikipedia) | ancient, anonymous rule | [ta.wikisource](https://ta.wikisource.org/wiki/திருவாசகம்/திருப்பள்ளியெழுச்சி), [en.wikipedia](https://en.wikipedia.org/wiki/Manikkavacakar). A separate page, "நீத்தல் விண்ணப்பம்", was confirmed to exist (27,832 bytes), not read |
| 4 | Tirumantiram, first tantiram (verse numbers seen from 113 to 213) | Tirumular | no dates (en.wikipedia); the work is dated from the 2nd century BCE to the 4th century CE | ancient, anonymous rule; the page credits a commentator (S. Dandapani Desikar), so use the verse only | [ta.wikisource](https://ta.wikisource.org/wiki/திருமந்திரம்/முதலாம்_தந்திரம்), [en.wikipedia](https://en.wikipedia.org/wiki/Tirumular) |
| 5 | Thiruppugazh (songs seen from number 1 to 38) | Arunagirinathar | c. 1370 to 1450 CE (Zvelebil, en.wikipedia); "15th century" (ta.wikisource page); the two roughly agree | ancient, anonymous rule, or `circa` creator with 1370 to 1450; the page text has stray characters and is "not a scholarly critical edition" | [ta.wikisource](https://ta.wikisource.org/wiki/திருப்புகழ்), [en.wikipedia](https://en.wikipedia.org/wiki/Arunagirinathar) |
| 6 | Kamba Ramayanam, Sundara Kandam, Katchi Padalam (153 numbered verses and 25 extra) | Kamban | **disagreement within en.wikipedia**: the Kamban page says 1180 to 1250 (born in Therazhundur, died in Nattarasankottai); the Ramavataram page says the work is 12th century | author's death year uncertain, so use the anonymous rule or leave to the reserve; never write 1250 as `author_died` unless the builder reads a second source | [ta.wikisource](https://ta.wikisource.org/wiki/கம்பராமாயணம்/சுந்தர_காண்டம்/காட்சிப்_படலம்), [en.wikipedia Kamban](https://en.wikipedia.org/wiki/Kamban). Other padalams were confirmed to exist (Ganga Kan, Nandarai Suzhchi, Surpanagai), not read |

### TA-012, `ta-culture-3`: didactic verse and the first novels (6 works read)

| # | Work | Creator | Dates as read | Rights basis | Read at |
|---|---|---|---|---|---|
| 1 | Aathichudi, 109 entries, each with a short explanation | Avvaiyar (the page: "12th century") | en.wikipedia says "Avvaiyar" is an honorific, the poets include a 1st century BCE Sangam poet, an 8th century and a 12th century poet. The ta.wikisource page says 12th century | pre-1900 work, author not datable by year: anonymous rule; say in the notes that the attribution is to "a 12th century Avvaiyar" per that page | [ta.wikisource](https://ta.wikisource.org/wiki/ஆத்திசூடி), [en.wikipedia](https://en.wikipedia.org/wiki/Avvaiyar) |
| 2 | Mutharai (Vakkundam), 31 verses | Avvaiyar (same note) | same | same | [ta.wikisource](https://ta.wikisource.org/wiki/மூதுரை) |
| 3 | Konrai Vendan (invocation of 2 lines, 91 numbered lines) | Avvaiyar (same note) | same | same | [ta.wikisource](https://ta.wikisource.org/wiki/நீதிக்_களஞ்சியம்/கொன்றை_வேந்தன்) |
| 4 | Prathapa Mudaliar Charithram (chapter 1 onward; the page lists at least 26 chapters) | Samuel Vedanayagam Pillai | 1826 to 1889; written 1857, published 1879 (en.wikipedia). **The ta.wikisource page's header says 1979 and says the transcription is from a 1979 printed edition**: that is an edition date and an editor's apparatus, not the work's; the builder takes only the 1879 text and reports the edition question to the reviewer | died 1889 (floor passes); one source for the death year | [ta.wikisource](https://ta.wikisource.org/wiki/பிரதாப_முதலியார்_சரித்திரம்), [en.wikipedia](https://en.wikipedia.org/wiki/Samuel_Vedanayagam_Pillai) |
| 5 | Kamalambal Charitram (the page calls it the second Tamil novel; the 1894 date is the page's own commentary) | P. R. Rajamaiyar, B. R. Rajam Iyer | 1872 to 1898, written 1893 to 1895 (en.wikipedia); ta.wikisource says he lived 26 years and gives year 1894, consistent | died 1898 (floor passes) | [ta.wikisource](https://ta.wikisource.org/wiki/முதல்_ஐந்து_தமிழ்_நாவல்கள்/கமலாம்பாள்_சரித்திரம்), [en.wikipedia](https://en.wikipedia.org/wiki/B._R._Rajam_Iyer). The text is "taken from a machine-scanned (OCR) edition" with possible errors, so the builder checks every line against the scan |
| 6 | Padmavathi Charithram, extract (series "முதல் ஐந்து தமிழ் நாவல்கள்", edited by K. N. Subramanyam) | A. Madhaviah | **dates disagree**: 1872 to 22 October 1925 (en.wikipedia) against 1874 to 1926 (the ta.wikisource page). Both deaths are before 1955 | died 1925 or 1926, floor passes either way; record `died` only after a third read, else `circa` | [ta.wikisource](https://ta.wikisource.org/wiki/முதல்_ஐந்து_தமிழ்_நாவல்கள்/பத்மாவதி_சரித்திரம்), [en.wikipedia](https://en.wikipedia.org/wiki/A._Madhaviah). Transcription glitches are noted on the page |

### TA-013, `ta-culture-4`: Bharathiyar (4 works read, ships short)

Subramania Bharati: born 11 December 1882, died 11 September 1921 (en.wikipedia; one source read, the builder reads a second before writing it). Died 1921, floor passes. en.wikipedia says his poems were "the first to be nationalised in India in 1949" and does not explain what that means; it does not matter for the floor, but the builder reports it to the reviewer.

| # | Work | Dates of the work as read | Read at |
|---|---|---|---|
| 1 | Kuyil Pattu (nine numbered sections, about 260 lines; take a few lines) | page gives none | [ta.wikisource](https://ta.wikisource.org/wiki/குயிற்_பாட்டு/குயிற்_பாட்டு) |
| 2 | Pappa Pattu (16 stanzas of four lines, in the collection பாரதியாரின் பல்வகைப் பாடல்கள், section 2) | page gives none | [ta.wikisource](https://ta.wikisource.org/w/api.php?action=parse&page=பாரதியாரின்_பல்வகைப்_பாடல்கள்/2._பாப்பாப்_பாட்டு&prop=text&format=json) |
| 3 | Nalladhor Veenai (two numbered stanzas, in பாரதியாரின் தெய்வப்பாடல்கள், section 12) | page gives none | [ta.wikisource](https://ta.wikisource.org/w/api.php?action=parse&page=பாரதியாரின்_தெய்வப்பாடல்கள்/12._நல்லதோர்_வீணை&prop=text&format=json) |
| 4 | Gnanaratham (prose, in chapters; text from a scan, "மின்வருடப்பட்ட பதிப்பு") | page gives none | [ta.wikisource](https://ta.wikisource.org/wiki/பாரதியார்_கதைகள்/ஞானரதம்) |

The en.wikipedia page says only that Kuyil Pattu, Panchali Sabatham and Kannan Pattu were "composed in 1912" and gives no publication years. Nothing more is claimed here. To fill the deck the builder reads, one at a time, more of the collection pages listed under [Dropped](#dropped-unverifiable) (Kannan Pattu, Panchali Sabatham, the national songs).

## 2. Proverbs (TA-020 to TA-022, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, as `ja-proverbs-1`; each card has a `literal` note and a meaning.

**Source for all 60: Rev. P. Percival, *Tamil Proverbs, with their English translation*, "containing upwards of six thousand proverbs", second edition, Dinavartamani Press, Madras, 1874.** en.wikisource says it is a scan (Index:Tamil_proverbs.pdf), that Percival is the translator, and that the work is public domain worldwide (published before 1931, author died over 100 years ago). Read at [en.wikisource, Tamil Proverbs](https://en.wikisource.org/wiki/Tamil_Proverbs): two prefaces, then 99 sections by Tamil letter, அ to வௌ. Each proverb below was read on its section page: [அ](https://en.wikisource.org/wiki/Tamil_Proverbs/அ), [க](https://en.wikisource.org/wiki/Tamil_Proverbs/க), [ப](https://en.wikisource.org/wiki/Tamil_Proverbs/ப), [ம](https://en.wikisource.org/wiki/Tamil_Proverbs/ம). The number is Percival's. The English is Percival's own wording, shown only to identify the proverb; **the builder writes its own literal and meaning**. Percival's printed Tamil is 1874 spelling and may differ from today's; the builder copies it exactly and flags differences.

The truncated section page of அ (it was cut at 100,000 characters) means the numbers 1 to 614 were seen only up to that cut; the 20 chosen are from the part read.

### TA-020, `ta-proverbs-1`: animals, food, family, money (no clean weather or work proverb was read for this deck, so those themes are absent)

| Percival no. | Tamil as read | Percival's English (to identify it) |
|---|---|---|
| 61 | அசைந்து தின்கிறது மாடு, அசையாமல் தின்கிறது வீடு. | A cow eats moving; a house eats standing. |
| 126 | அடியாத மாடு படியாது. | An unchastised bullock will not obey. |
| 72 | அஞ்சினவனை குஞ்சும் வெருட்டும். | Even a fledgeling may scare the timid. |
| 94 | அடங்காத பாம்பிற்கு ராஜா மூங்கில்த்தடி. | A bamboo staff is the king of a vicious snake. |
| 5106 | மண் பூனை ஆனாலும் எலிப் பிடித்தால் சரி. | Though the cat is made of mud, if it catch rats, it is enough. |
| 5131 | மயிலே மயிலே என்றால் இறகு கொடுக்குமா? | If you exclaim O peacock, will it give you its feathers? |
| 4435 | பசுவைக் கொன்றால் கன்று பிழைக்குமா? | If you slaughter a cow, will its calf live? |
| 4637 | பன்றி பல குட்டி, சிங்கம் ஒரு குட்டி. | The sow has many young ones, the lioness only one. |
| 607 | அன்னம் முட்டானால் எல்லாம் முட்டு. | When food or grain is scarce, all is scarce. |
| 329 | அரிசி மறந்த உலைக்கு உப்பு என்ன? | Of what use is salt in a pot without rice? |
| 4412 | பசிக்குக் கறி வேண்டாம், தூக்கத்துக்குப் பாய் வேண்டாம். | When hungry curry is not needed, nor a mat when sleepy. |
| 4425 | பசி ருசி அறியாது, நித்திரை சுகம் அறியாது. | Hunger is ignorant of flavours, sleep of enjoyment. |
| 5150 | மருந்தே ஆயினும் விருந்தோடு உண். | (Percival: share before eating it, though little) |
| 611 | அன்னைக்கு உதவாதான் ஆருக்கு உதவுவான். | Whom will he help that does not help his mother? |
| 5105 | மண்பிள்ளை ஆனாலும் தன் பிள்ளை. | Though earthen, one's own child is precious. |
| 588 | அன்றற ஆயிரம் பொன்னிலும், நின்றற ஒரு காசு பெரிது. | A single cash saved is greater than thousands spent at once. |
| 574 | அற்பன் பணம் படைத்தால் வைக்க வகை அறியான். | A mean person with wealth knows not how to keep it. |
| 4503 | பணம் இல்லாதவன் பிணம். | He who has no money is a corpse. |
| 4498 | பணத்துக்குப் பெயர் ஆட்கொல்லி. | Money is called a man-slayer. |
| 5083 | மடியிலே கனம் இருந்தால் வழியிலே பயம். | If you have money in your waist-cloth, you may be afraid on the way. |

### TA-021, `ta-proverbs-2`: friends, learning, time, speech, sayings of caution

| Percival no. | Tamil as read | Percival's English |
|---|---|---|
| 582 | அன்பான சிநேகிதனை ஆபத்திலே அறி. | Know a loving friend in adversity. |
| 571 | அற்பர் சிநேகிதம் பிராண கண்டிதம். | The friendship of the mean will issue in fatal results. |
| 4402 | பகைவர் உறவு புகை எழு நெருப்பு. | The friendship of foes is like fire concealed in smoke. |
| 4545 | பரிகாரி உறவு தெருவாசல் மட்டும். | The friendship of the doctor ends at the threshold. |
| 5200 | மனதிலே பகை உதட்டிலே உறவு. | Enmity at heart, friendship on the lips. |
| 540 | அறிவீனனிடத்தில் புத்தி கேளாதே. | Do not ask advice of the ignorant. |
| 239 | அப்பியாச வித்தைக்கு அழிவு இல்லை. | Thoroughly acquired knowledge does not fail. |
| 1946 | கசடான கல்வியினும் கல்வியீனம் நலம். | Ignorance is better than imperfect knowledge. |
| 1945 | கசடறக் கல்லார்க்கு இசை உறல் இல்லை. | Persons of imperfect learning have no reputation. |
| 1944 | கசடருக்கு இல்லைக் கற்றோர் உறவு. | The base do not enjoy the friendship of the learned. |
| 589 | அன்றிறுக்கலாம் நின்றிறுக்கலாகாது. | Pay at once, delay is bad. |
| 4514 | பதறாத காரியம் சிதறாது. | A thing done without haste never fails. |
| 4559 | பருவத்தே பயிர் செய். | Cultivate in due time. |
| 4589 | பழுத்த பழம் கொம்பில் இராது. | Ripe fruit does not remain on the branch. |
| 361 | அரைச்சொற் கொண்டு அம்பலம் ஏறலாமோ? | Can one go before an assembly with half a word? |
| 5184 | மவுனம் மலையைச் சாதிக்கும். | Silence may defy a mountain. |
| 5079 | மடக் கேழ்விக்கு மாறுத்தரம் இல்லை. | A stupid question needs no answer. |
| 1953 | கடலிலே துரும்பு கிடந்தாலும் மனதிலே ஒரு சொல் கிடவாது. | A rush may remain in the sea, but a secret will not remain in the mind. |
| 1955 | கடலைத் தூர்த்தும் காரியம் முடிக்க வேண்டும். | You must accomplish your undertaking, though you fill up the ocean. |
| 1959 | கடல் தாண்ட ஆசை உண்டு, கால்வாய் தாண்டக் கால் இல்லை. | He wishes to cross the ocean, but has no feet to cross a drain. |

### TA-022, `ta-proverbs-3`: farming, work, wit, comparisons

| Percival no. | Tamil as read | Percival's English |
|---|---|---|
| 4513 | பண்ணிய பயிரில் புண்ணியம் தெரியும். | A man's merit may be seen in the grain he grows. |
| 4594 | பள்ளம் இறைத்தவன் பங்கு கொண்டுபோகிறான். | He who irrigated the low ground takes his share. |
| 5143 | மரம் வைத்தவன் தண்ணீர் வார்ப்பான். | He who planted the tree will water it. |
| 5171 | மலையில் விளைந்தாலும் உரலில் மசியவேண்டும். | Although produced on the mountains, rice must be pounded in a mortar. |
| 5158 | மலிந்த பண்டம் கடையிலே வரும். | When commodities are abundant, they come to market. |
| 107 | அடிக்கும் காற்றிலே எடுத்துத் தூற்றவேண்டும். | Winnow while the wind blows. |
| 4481 | பட்டடை வாய்த்தால் பணி வாய்க்கும். | If the anvil is good, the work will be good. |
| 5162 | மலை உச்சியில் கல் ஏற்றுதல் அரிது. | It is difficult to roll a stone to the top of a hill. |
| 5137 | மரத்தை இலை காக்கும் மானத்தைப் பணம் காக்கும். | Leaves cover a tree, money covers one's nakedness. |
| 5104 | மண் பறித்து உண்ணேல். | Do not live by extortion. |
| 4505 | பணம் என்ன செய்யும் பத்து விதம் செய்யும். | What can money effect? it can do ten kinds of things. |
| 1938 | கங்கையில் மூழ்கினாலும் காக்கை அன்னம் ஆகுமா? | Will a crow become a swan by bathing in the Ganges? |
| 1942 | கங்கையிலே பிறந்த நத்தை சாலக்கிராமம் ஆகாது. | A snail of the Ganges is not a Shalgram. |
| 1952 | கடலில் இட்ட பெருங்காயம்போல. | Like assafoetida cast into the ocean. |
| 1954 | கடலில் கரைத்த புளிபோல. | Like tamarind acid dissolved in the sea. |
| 1956 | கடலை தூர்த்தாலும் காரியம் முடியாது. | Though the sea be filled up, the thing cannot be effected. |
| 1957 | கடல் கொதித்தால் விளாவ நீர் எங்கே? | Should the sea boil, whence water to cool it? |
| 1960 | கடல் மீனுக்கு நுளையன் இட்டதே சட்டம். | As regards the fish of the sea, whatever name the fisherman gives is final. |
| 1963 | கடல் பெருகினால் கரையும் பெருகுமா? | Will the shore extend when the sea flows? |
| 1962 | கடல் வற்றிக் கருவாடு தின்னலாமென்று உடல் வற்றிச் செத்ததாம் கொக்கு. | The stork died waiting for the ocean to dry, hoping for dried fish. |

**A second attestation (reserve).** en.wiktionary's [Category:Tamil proverbs](https://en.wiktionary.org/wiki/Category:Tamil_proverbs) has 45 entry titles (read through the API). Titles that read as proverbs include: ஆழம் தெரியாமல் காலை விடாதே; இனம் இனத்தோடு சேரும்; எதிரிக்கு எதிரி நண்பன்; கடுகு சிறுத்தாலும் காரம் குறையாது; கற்றது கைமண்ணளவு கல்லாதது உலகளவு; காலம் பொன் போன்றது; சிறு துளி பெரு வெள்ளம்; தவளை தன் வாயால் கெடும்; தாயைப் போல பிள்ளை நூலைப் போல சேலை; முள்ளை முள்ளால் எடு; யானைக்கும் அடி சறுக்கும். The builder reads each entry's page for its gloss and sources before use; a Wiktionary page alone is the attestation, and a proverb on that list that is also in Percival gets both. Wiktionary has variant spellings of several (for example three spellings of "குரைக்கிற நாய் கடிக்காது"), so the builder takes one and notes the others.

## 3. Multi-word verbs (TA-030 to TA-032, 3 x 20 at most)

The headwords below are page titles of en.wiktionary or ta.wiktionary, read through the API on 2026-11-15, so each is **attested as a Wiktionary entry**. **No gloss is written here**: the builder reads each entry's page for its sense and its usage note, and drops a headword whose page it cannot read. The citation form of each card is the entry's own headword, spelled as Wiktionary spells it (some are written without a space, for example "ஃபோன் பண்ணு" with a space and "சோதனைபண்ணு" without; the builder keeps Wiktionary's spelling and notes the variant).

Source pages read: [பண்ணு](https://en.wiktionary.org/wiki/பண்ணு) (senses: do, make, cook; a "highly productive" verbaliser; formal Tamil prefers செய், colloquial speech prefers பண்ணு, especially with English loanwords), [போடு](https://en.wiktionary.org/wiki/போடு) (auxiliary sense "added to a transitive verb to convey force or expression"; a long list of compounds), [கொள்](https://en.wiktionary.org/wiki/கொள்) (auxiliary senses: reflexive, for one's own benefit, without external agency; spoken -kkō), [விடு](https://en.wiktionary.org/wiki/விடு) (auxiliary senses: certainty or intensity; action done to someone or something else), and the category pages [Tamil compound verbs](https://en.wiktionary.org/wiki/Category:Tamil_compound_verbs) (21 entries), [Tamil auxiliary verbs](https://en.wiktionary.org/wiki/Category:Tamil_auxiliary_verbs) (22 entries: ஆ, இரு, உண், உள், ஓங்கு, கிட, கூடாது, கூடு, கொடு, கொள், செய், படு, பார், பெறு, போ, போடு, முடி, வா, விடு, வேண்டாம், வேண்டும், வை) and [Tamil idioms](https://en.wiktionary.org/wiki/Category:Tamil_idioms) (74 entries). The en.wiktionary page for போடு notes that it differs from வை by suggesting a "somewhat reckless placing"; the builder uses that in the `usage` note only if it re-reads it.

### TA-030, `ta-multiword-conjunct-verbs`, `conjunct-verb` (24 attested; take 20)

A noun plus பண்ணு, செய் or போடு.

- With பண்ணு or செய் (the பண்ணு page lists these as conjunct verbs, and the search of en.wiktionary titles shows the entries exist): ஃபோன் பண்ணு, ஃபீல் பண்ணு, காலி பண்ணு, சோதனைபண்ணு, தற்கொலை பண்ணு, தற்கொலை செய், உண்டுபண்ணு, அறிக்கைபண்ணு, கைது பண்ணு, அடக்கம் பண்ணு (the last two are named only as examples in the பண்ணு page, so the builder reads whether they have entries of their own). ta.wiktionary also has பிகு பண்ணு and வேலைபண்ணு.
- With போடு (listed as compounds on the போடு page): சத்தம்போடு, சீன் போடு, நடைபோடு, ஓட்டுப்போடு, கடைபோடு, ஊசிபோடு, தாளம்போடு, பீட்டர் போடு, போட்டிபோடு, முழுக்குப்போடு, குட்டிபோடு, சோறுபோடு, இஸ்திரிபோடு, எடைபோடு.

### TA-031, `ta-multiword-aspectual-compound`, `aspectual-compound` (21 attested; take 20)

A verbal participle plus an auxiliary, as the கொள், விடு and போடு pages list them.

- With கொள் (listed on the கொள் page as compounds): ஏற்றுக்கொள், ஒத்துக்கொள், கட்டிக்கொள், கண்டுகொள், கலந்துகொள், பார்த்துக்கொள், வைத்துக்கொள்; and கற்றுக்கொள் (also in Category:Tamil compound verbs).
- With கொடு, வா, போ: கற்றுக்கொடு, கொண்டுபோ, கொண்டுவா, தள்ளிப்போ (the last two groups are listed on the கொள் page and in the compound-verbs category).
- With விடு (the விடு page lists these as derived terms and states that the entry itself does not label them as auxiliary constructions, so the builder reads each before use): விட்டுவிடு, விட்டுக்கொடு, மாட்டிவிடு.
- With போடு: தள்ளிப்போடு, ஒத்திப்போடு, தூக்கிப்போடு, எட்டிப்போடு, சுற்றிப்போடு, வளைத்துப்போடு.

(Not taken: போகவிடு is a causative "let go", not an aspectual compound.)

### TA-032, `ta-multiword-idiomatic`, `idiomatic-verb` (21 attested; take 20)

Verb-final idioms from the en.wiktionary category: உயிரெடு, உயிரைவாங்கு, ஒருகைபார், எட்டிப்பார், கண்ணைக்கசக்கு, கம்பியெண்ணு, கழுத்தறு, குட்டையைக்குழப்பு, கோட்டைவிடு, தம்பட்டம் அடி, மண்ணைக்கவ்வு, மண்ணைப்போடு, மலையேறு, மூக்கைநுழை, மூச்சுவிடு, மென்றுவிழுங்கு, வாகைசூடு, வெட்டிமுறி, தலைக்குனி, கைநீட்டு, கையேந்து. (Some of these are also listed in Category:Tamil compound verbs, for example கம்பியெண்ணு, ஒருகைபார், மூக்கைநுழை; the builder gives each headword to one deck only.)

**Count.** 24 + 21 + 21 = 66 attested headwords; 60 to be taken. Fewer than 20 may pass in a family if the builder cannot read the pages: the report says so.

## 4. Recommendations (TA-060, 20)

File `decks/recommendations/ta.yaml`, shape of `recommendations/ja.yaml`: `id: "ta-rec-<name>"`, `medium`, `title { text, reading }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three to eight questions each, `rights_checked` and `jurisdiction`; nothing of the work shipped, no link. The learner sources these themselves, so rights are not a gate. **Year and creator are as read on the en.wikipedia page named** (one source each). `level` and `briefing` are the builder's.

| # | Title (as en.wikipedia titles it) | Medium | Creator | Year | Read at |
|---|---|---|---|---|---|
| 1 | Parasakthi | film | directors Krishnan and Panju, writer M. Karunanidhi | 1952 | [en.wikipedia](https://en.wikipedia.org/wiki/Parasakthi_(1952_film)) |
| 2 | Veerapandiya Kattabomman | film | B. R. Panthulu | 1959 | [en.wikipedia](https://en.wikipedia.org/wiki/Veerapandiya_Kattabomman_(film)) |
| 3 | Kadhalikka Neramillai | film | C. V. Sridhar | 1964 | [en.wikipedia](https://en.wikipedia.org/wiki/Kadhalikka_Neramillai) |
| 4 | Muthal Mariyathai | film | Bharathiraja | 1985 | [en.wikipedia](https://en.wikipedia.org/wiki/Muthal_Mariyathai) |
| 5 | Mouna Ragam | film | Mani Ratnam | 1986 | [en.wikipedia](https://en.wikipedia.org/wiki/Mouna_Ragam) |
| 6 | Nayakan | film | Mani Ratnam | 1987 | [en.wikipedia](https://en.wikipedia.org/wiki/Nayakan) |
| 7 | Roja | film | Mani Ratnam | 1992 | [en.wikipedia](https://en.wikipedia.org/wiki/Roja_(film)) |
| 8 | Thevar Magan | film | Bharathan | 1992 | [en.wikipedia](https://en.wikipedia.org/wiki/Thevar_Magan) |
| 9 | Anbe Sivam | film | Sundar C | 2003 | [en.wikipedia](https://en.wikipedia.org/wiki/Anbe_Sivam) |
| 10 | Kaadhal | film | Balaji Sakthivel | 2004 | [en.wikipedia](https://en.wikipedia.org/wiki/Kaadhal_(2004_film)) |
| 11 | Subramaniapuram | film | Sasikumar | 2008 | [en.wikipedia](https://en.wikipedia.org/wiki/Subramaniapuram) |
| 12 | Aadukalam | film | Vetrimaaran | 2011 | [en.wikipedia](https://en.wikipedia.org/wiki/Aadukalam) |
| 13 | Naveena Saraswathi Sabatham | film | K. Chandru | 2013 | [en.wikipedia](https://en.wikipedia.org/wiki/Naveena_Saraswathi_Sabatham) |
| 14 | Visaranai | film | Vetrimaaran | 2015 | [en.wikipedia](https://en.wikipedia.org/wiki/Visaranai) |
| 15 | Pariyerum Perumal | film | Mari Selvaraj | 2018 | [en.wikipedia](https://en.wikipedia.org/wiki/Pariyerum_Perumal) |
| 16 | '96 | film | C. Prem Kumar | 2018 | [en.wikipedia](https://en.wikipedia.org/wiki/96_(film)) |
| 17 | Asuran | film | Vetrimaaran | 2019 | [en.wikipedia](https://en.wikipedia.org/wiki/Asuran_(2019_film)) |
| 18 | Soorarai Pottru | film | Sudha Kongara | 2020 | [en.wikipedia](https://en.wikipedia.org/wiki/Soorarai_Pottru) |
| 19 | One Part Woman | novel | Perumal Murugan | 2010 (Tamil), 2013 (English translation) | [en.wikipedia](https://en.wikipedia.org/wiki/One_Part_Woman) |
| 20 | Sivagamiyin Sapatham | novel | Kalki Krishnamurthy | serialised 1944 to 1946, book 1948 | [en.wikipedia](https://en.wikipedia.org/wiki/Sivagamiyin_Sapatham) |

Reserve, all read on en.wikipedia: Kaaka Muttai (2015, M. Manikandan), Karnan (2021, Mari Selvaraj), Jai Bhim (2021, T. J. Gnanavel), Anjali (1990, Mani Ratnam), Kuttrame Thandanai (2016, M. Manikandan), Sillunu Oru Kaadhal (2006, Krishna). en.wikipedia says Kaaka Muttai is 2015; some other pages may say 2014, so the builder reads a second source before writing the year.

**Medium balance.** 18 of the 20 are films, 2 novels, no music, television, comic or podcast. That is the result of what could be verified in this run, not a choice: the pages of Karukku, Oru Puliyamarathin Kathai, Vishnupuram and Madhorubhagan were not found under the titles tried, and the TV serial Metti Oli page gives no year. A builder with more time replaces films by other media from the reads listed under [Dropped](#dropped-unverifiable).

Creators to add to `decks/creators/ta.yaml` where missing, with the lifespans en.wikipedia gives (one source): Kalki Krishnamurthy 9 September 1899 to 5 December 1954 (co-founded the magazine Kalki in 1941; wrote more than 120 short stories and five novels). Others are recommendations' directors, who need a bio only if the builder wants one; living creators carry `born` and no `died`.

## Dropped, unverifiable

Each item below was looked for on 2026-11-15 and not read to the point of use. None is in a deck list above. A builder may bring one back by reading its page and its text.

**A. Index or contents page read, text not read (12):**

1. Natrinai (ta.wikisource "நற்றிணை 1" is the index of Pulliyur Kesikan's 1967 Pari Nilayam commentary edition, poems 1 to 200; the poems are on subpages not read; a 20th century edition also raises a rights question).
2. Tirumurukarruppatai (the ta.wikisource page is an index with three subpages; text not read; poet Nakkeerar per the page).
3. Ainkurunuru (the page "ஐங்குறுநூறு 111-120" shows prose summaries, not the verse, and names Ammuvanar; other pages exist, not read).
4. Tevaram, first Tirumurai (a landing page only, naming Sambandar and the compiler Nambiyandar Nambi; hymns not read).
5. Tirukkovaiyar (the ta.wikisource page lists 25 chapters and no verse; en.wikipedia says 9th century CE).
6. Manonmaniyam (P. Sundaram Pillai, 1855 to 1897 per the page and en.wikipedia, first published 1891, five acts; the dialogue is on subpages not read).
7. Meyyaram, 1917 (V. O. Chidambaram Pillai, 5 September 1872 to 18 November 1936 per en.wikipedia; second edition, Chennai, 1917; the page is a table of contents).
8. Pudhumaipithan's stories (the ta.wikisource page is the contents of the 2000 Kalachuvadu edition edited by A. R. Venkatachalapathy; stories on subpages not read; en.wikipedia gives 25 April 1906 to 30 June 1948; a modern edition's apparatus is also a rights question).
9. Sivagamiyin Sapatham as culture (ta.wikisource index only; header year 1944; chapter pages not read; it is a recommendation below).
10. Ponniyin Selvan (ta.wikisource index only: 5 parts, 293 chapters; Kalki died 5 December 1954 per en.wikipedia; en.wikipedia says serialised 1950 to 1954 and published as five volumes in 1955, the ta.wikisource page says serialised 1950 to 1955: the two disagree).
11. Kannan Pattu (the ta.wikisource page is a contents list of 23 poems; poem pages not read).
12. Panchali Sabatham (the ta.wikisource page has an introduction and contents, five cantos; poems on subpages not read).

**B. Page missing, not found, or without the needed fact (12):**

13. Periya Puranam (no ta.wikisource page under the title tried).
14. Thiruvilaiyadal Puranam (no en.wikipedia page; the ta.wikisource page tried returned an error).
15. Thiruvarutpa (Ramalinga Swamigal, 5 October 1823 to 30 January 1874 per en.wikipedia; no ta.wikisource work page found).
16. Nandanar Charitram (Gopalakrishna Bharati, 1811 to 1881 per en.wikipedia; no work page found).
17. Rama Natakam (Arunachala Kavi, 1711 to 1779 per en.wikipedia; no ta.wikisource page found).
18. Bethlehem Kuravanji (no page on either wiki).
19. Karukku (Bama, born 1958; no en.wikipedia page for the book under the titles tried).
20. Oru Puliyamarathin Kathai (Sundara Ramaswamy, 1931 to 2005; page not found).
21. Vishnupuram (Jeyamohan; page not found).
22. Vaadivaasal (page not found).
23. Vikram Vedha, 2017 (no en.wikipedia page under that title).
24. Metti Oli (the en.wikipedia page was read; it gives no year).

**C. Fails the rights floor, or the page for it was not found or not read (6):**

25. Bharathidasan (K. Subburathinam, 29 April 1891 to 21 April 1964 per en.wikipedia: died after 1955).
26. Namakkal Kavignar (1888 to 1972 per en.wikipedia).
27. Mayilai Seeni. Venkatasami (16 December 1900 to 8 May 1980 per en.wikipedia).
28. Kavimani Desigavinayagam Pillai (27 July 1876 to 26 September 1954 per en.wikipedia, which passes the floor; no ta.wikisource work page was found by the search, so no text was read).
29. Ku. Pa. Rajagopalan (no en.wikipedia page found).
30. U. V. Swaminatha Iyer, "En Sarithiram" (en.wikipedia: 19 February 1855 to 28 April 1942, passes the floor; the ta.wikisource page "என் சரித்திரம்" is a 1,036 byte index, not read).

**D. Existence seen only (10):** the title exists on ta.wikisource, with the length the API gave; no author, date or text was read: Inna Narpathu, Nanmanikkadigai, Kar Narpathu, Thirikadugam, Elathi, Acharakkovai, Sirupanchamoolam, Pazhamozhi Nanooru, Mudumozhikkanchi, Nalvazhi. (en.wikipedia's Eighteen Lesser Texts page dates the group "between 100 and 500 CE" and names no poet for any single text; the en.wikipedia pages for Iniyavai Narpathu and Kar Narpathu credit Putham Sernthanar and Kannankoothanaar, but their ta.wikisource texts were not read.)

**Count of dropped items: 12 + 12 + 6 + 10 = 40.**

## Review-queue rule

Everything is `unreviewed`. Each uncertain item is a row in the builder's report in the table shape of `docs/review-queue/ta.md`. The rows this page already raises: the Kamban dates (row 6 of culture 2), the Madhaviah dates (culture 3), the 1979 edition date on the Prathapa Mudaliar page, the OCR text of Kamalambal Charitram, the Ponniyin Selvan serialisation years, Percival's 1874 spellings, and the unvalidated anonymous-rule fit for every ancient work.

## Open points for the builders and the orchestrator

- **Validator fit for ancient works.** The anonymous rule needs a `date` shape `parse_years` accepts. A range that begins before the common era (the Kural, the Sangam anthologies) may not parse. Nothing was run. The first culture builder tries one such item in the PR's CI and reports; the fallback is `circa` creator entries and the earliest positive century.
- **Deck 4 is short.** `ta-culture-4` has four works read. It should wait for one more Bharathiyar collection page to be read (Kannan Pattu, Panchali Sabatham or the national songs list), or ship with 12 to 16 cards.
- **Overlaps.** Aathichudi, Mutharai and Konrai Vendan are all attributed to "a 12th century Avvaiyar" on the page read; the en.wikipedia Avvaiyar page says three poets bear the name, so no single creator entry with a lifespan is made for them. Kalki's Sivagamiyin Sapatham is a recommendation here and could also be a culture item once chapter text is read.
- **Review count.** The Tamil review-queue file (`docs/review-queue/ta.md`) currently carries a course-wide hand-written-readings row; TA-120 appends rows for each card.
