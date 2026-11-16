# Plan: Marathi sourcing, addendum 3 (recommendations and multi-word verbs)

Task MR-R3 of [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), written 2026-11-16, an addendum to [Plan-Culture-Marathi](Plan-Culture-Marathi.md) (the "Recommendations" and "Multi-word verbs" sections). The owner's directive: obvious gaps are work, so every reachable source was tried before an item was dropped.

## How this addendum was checked

On 2026-11-16 the author read the pages named in each row through the MediaWiki API with `curl` (en.wikipedia, mr.wikipedia, mr.wiktionary, en.wiktionary, mr.wikiquote, Wikidata, en.wikisource and mr.wikisource searches), one request every 12 to 20 seconds, retrying after HTTP 429. **A fact is here only if the named page said it.** The "words relied on" are copied from the page (Wiktionary glosses are quoted from the wikitext). Nothing was written from memory. A row that a page did not settle is under "Dropped and why".

**Hosts blocked** (HTTP CONNECT 403 through the session proxy, and `WebFetch` could not resolve britannica.com): archive.org, britannica.com, imdb.com, en.wikibooks.org and mr.wikibooks.org, gutenberg.org, hathitrust.org, loc.gov, dsal.uchicago.edu (Molesworth's dictionary), ncert.nic.in, ebalbharati.in. **Reachable but empty for this task:** mr.wikisource and en.wikisource searches for Molesworth (0 hits), Wikidata (no birth year for Sandeep Sawant). The Wikimedia hosts answered 429 many times; all were retried to a 200 except where a row says otherwise.

## A. Recommendations

### A1. The five rows that were left out

| Item | Result | Page and the words relied on |
|---|---|---|
| Shwaas (film), year | 2004 | en.wikipedia Shwaas: "Shwaas ('The Breath') is a Marathi film, released in 2004." |
| Shwaas, premise | verified | same page, Plot: "A villager (Vichare) brings his 8-year-old grandson Parshuraam (also known as Parshya) to a doctor in Pune to diagnose the child's eyes." ... "Dr. Sane quickly diagnoses child with retinoblastoma — a rare retinal cancer." ... "the only way to save the child's life is to perform an operation that will leave the child blind." |
| Shwaas, creator Sandeep Sawant, **birth year** | **not found** | en.wikipedia Sandeep Sawant, mr.wikipedia संदीप सावंत and Wikidata Q17122764 give no birth date (Wikidata has occupation and citizenship only). Dropped, see below. |
| Natsamrat (play), premise | verified | mr.wikipedia नटसम्राट (नाटक): "नटसम्राट गणपतराव ऊर्फ अप्पासाहेब बेलवलकर ही प्रमुख भूमिका"; "नटसम्राट हे नाटक मुळात विल्यम शेक्सपियरच्या एकाहून अधिक अजरामर कलाकृतींवर बेतले होते". The film page (en.wikipedia Natsamrat) states the story: "the tragic family life of a stage actor who has retired from acting but is unable to forget his fond memories of theatre and the stage" and "Appa ... bequeaths his entire wealth and property to his children, keeping nothing for himself". |
| Natsamrat (play), year and creator | verified | mr.wikipedia: first show "२३ डिसेंबर, इ.स. १९७० रोजी बिर्ला मातोश्री सभागृह, मुंबई येथे" by "दि गोवा हिंदू असोशिएशन". en.wikipedia Kusumagraj: "Vishnū Vāman Shirwādkar (27 February 1912 – 10 March 1999)", "1974 Sahitya Akademi Award in Marathi for Natsamrat". |
| Katyar Kaljat Ghusali, the right pages | verified | **Play:** en.wikipedia "Katyar Kaljat Ghusali (play)": "a Marathi musical play (Sangeet Natak), originally released in 1967", "written by Purushottam Darvhekar", "The story depicts clash of two gharanas". **Film:** en.wikipedia "Katyar Kaljat Ghusali (film)": "a 2015 Indian Marathi-language epic musical drama film based on a play by the same name. Directed by Subodh Bhave". The bare title is a disambiguation page, so a row always names the (play) or (film) page. The film's language is therefore settled: Marathi. |
| Katyar, premise | verified | play page, Plot: "an Indian classical vocalist, Khansaheb who is extremely proud about his musical gharana, unwilling to reveal the style of his gharana to anyone else"; Sadashiv Gurav "a boy from Miraj" asks Khansaheb to teach him. |
| Katyar, creators | verified | en.wikipedia Purushottam Darvhekar: "(1 June 1926 – 21 September 1999)"; Subodh Bhave: "born 9 November 1975". |
| Chhava (novel), year and premise | verified | en.wikipedia Shivaji Sawant: "His novel Chhava, published in 1980, is based on the life of Chhatrapati Sambhaji Maharaj." and "Shivaji Sawant (31 August 1940 – 18 September 2002)". en.wikipedia Chhaava (the 2025 Hindi film) agrees: "based on the life of Sambhaji, the second ruler of the Maratha Empire" and "An adaptation of the Marathi novel Chhava by Shivaji Sawant". The novel has no page of its own (en.wikipedia "Chhava (novel)" is missing), so these two pages are the working sources. |
| Sant Tukaram (1936 film), year and premise | verified | en.wikipedia Sant Tukaram (1936 film): "a 1936 Marathi film, produced by Prabhat Film Company and based on the life of Tukaram (1608–50)"; "first released on 12 December 1936 at the Central Cinema hall in Bombay"; "directed by Vishnupant Govind Damle and Sheikh Fattelal". Plot: "Tukaram - a farmer and grocer - loses interest in the material world after losing his first wife and child in a famine." |
| Sant Tukaram, creator Damle | verified | en.wikipedia Vishnupant Govind Damle: "(14 October 1892 – 5 July 1945)". The Damle page itself dates the film "1937" in one sentence and "1936" in the filmography list, so the builder uses the film page's 1936 and release date. |
| Sant Tukaram, creator Sheikh Fattelal, **dates** | **not found** | No en.wikipedia page exists under Sheikh Fattelal, Fattelal, Fatehlal, Sheikh Fatelal or Fatelal. en.wikipedia Prabhat Film Company and V. Shantaram write "S. Fatelal" / "Sheikh Fatelal" with no dates; mr.wikipedia (searched for फत्तेलाल) gives "शेख फत्तेलाल" with no dates. Dropped, see below. |

### A2. Rows 17 to 20 of the plan

| # | Title | Year | Creator, dates | Premise | Page and the words relied on |
|---|---|---|---|---|---|
| 17 | Vyakti ani Valli (book) | 1966 | P. L. Deshpande, 8 Nov 1919 to 12 Jun 2000 | a collection of character sketches, written from 1944 to 1961 | mr.wikipedia व्यक्ती आणि वल्ली: "व्यक्ती आणि वल्ली (१९६६) हा मराठी भाषेतील पु.ल. देशपांडे यांचा कथासंग्रह आहे. मौज प्रकाशनाकडून तो प्रसिद्ध करण्यात आला"; "इ.स. १९४४ मध्ये ... 'अण्णा वडगावकर' नावाचे काल्पनिक व्यक्तिचित्र लिहिले. तेव्हापासून इ.स. १९६१ पर्यंत लिहिलेल्या व्यक्तिचित्रांचा या संग्रहात समावेश"; "पहिल्या ४ आवृत्यांत १८ व्यक्तिचित्रांचा". Lifespan: en.wikipedia Pu. La. Deshpande "(alternatively written as Pu La Deshpande; 8 November 1919 – 12 June 2000)"; "Sahitya Akademi Award (Marathi for Vyakti Ani Valli) – 1965" (the award year is as the page states it, in conflict with a 1966 book year, so **no question rests on the award year**). |
| 18 | Batatyachi Chal (book) | 1962 | P. L. Deshpande | a humorous story collection | mr.wikipedia बटाट्याची चाळ (पुस्तक): "बटाट्याची चाळ (१९६२) हा मराठी भाषेतील पु.ल. देशपांडे यांचा विनोदी कथासंग्रह आहे ... १९६२ साली या पुस्तकाची पहिली आवृत्ती प्रकाशित झाली होती." |
| 19 | Mrityunjay (novel) | **year not found** (the page says only Hindi translation 1974, English 1989) | Shivaji Sawant, 31 Aug 1940 to 18 Sep 2002 | based on Karna of the Mahabharata | mr.wikipedia मृत्युंजय (कादंबरी): "महाभारतातील 'कर्ण' या व्यक्तिरेखेवर आधारित शिवाजी सावंत यांनी लिहिलेली कादंबरी." en.wikipedia Shivaji Sawant: "based on Karna, one of the leading characters of the epic Mahabharat ... translated into Hindi (1974), English (1989)". The two pages **disagree on the Moortidevi Award year** (en: 1994; mr: "सप्टेंबर २४ १९९५"), so no question rests on it. Used with "year" omitted or written as "by 1974". |
| 20 | Shyamchi Aai (book) | written from 9 Feb 1933; publication year not stated | Sane Guruji, 24 Dec 1899 to 11 Jun 1950 | the author's memories of his mother, told to children night after night | mr.wikipedia श्यामची आई: "नाशिकच्या कारागृहात असताना फेब्रुवारी ९, इ.स. १९३३ रोजी त्यांनी या पुस्तकाच्या लिखाणास प्रारंभ केला"; "इ.स. १९५३ साली ... चित्रपट". en.wikipedia Shyamchi Aai: "Sane Guruji (now an adult), fondly called Shyam during his childhood, narrates his memories to a group of children in a nightly sitting"; "The book starts with Shyam's mother marrying into a wealthy family ... ends with the illness and death of his mother"; the film "was directed and produced by Acharya Atre. It won the President's Medal as Best Feature Film at the 1st National Film Awards". en.wikipedia Sane Guruji: "24 December 1899 – 11 June 1950". |

### A3. The existing rows 1 to 16, with creator dates and a premise (so questions can be written)

Each premise is a page statement; the builder writes the briefing in its own words. Year as in the plan.

| Work | Creator, dates as the page gives them | Premise (words relied on) | Page |
|---|---|---|---|
| Sairat, 2016 | Nagraj Manjule, "born 24 August 1978" | "two young college students from different castes who fall in love, sparking conflict between their families" | en.wikipedia Sairat; Nagraj Manjule |
| Natarang, 2010 (from the 1978 novel by Anand Yadav, 30 Nov 1935 to 27 Nov 2016) | Ravi Jadhav, "born 22 September 1971" | "Gunvantrao Kagalkar aka Guna, a poor village labourer, nurtures an obsession for Tamasha"; he plays the effeminate "Nachya" role | en.wikipedia Natarang; Ravi Jadhav; Anand Yadav |
| Court, 2014 | Chaitanya Tamhane, "born 1 March 1987" | "the Mumbai Sessions Court trial of an aging protest singer, Narayan Kamble ... accused of encouraging a manhole worker to commit suicide through one of his folk songs" | en.wikipedia Court (2014 film); Chaitanya Tamhane |
| Harishchandrachi Factory, 2009 | Paresh Mokashi, "born 6 February 1969" | "about Dadasaheb Phalke, who made the first Indian feature film Raja Harishchandra (1913)"; India's official Oscar entry, "the second film, after Shwaas (2004)" | en.wikipedia Harishchandrachi Factory; Paresh Mokashi |
| Fandry, 2013 | Nagraj Manjule | "a teenager from a Dalit family who lives at the village fringe, and falls in love with an upper-caste girl" | en.wikipedia Fandry |
| Killa, 2015 release | Avinash Arun, "born 20 November 1985" | "an 11-year-old seventh grade Indian boy who has just lost his father is forced to adapt to a new school in a small village in Konkan" | en.wikipedia Killa (film); Avinash Arun |
| Deool, 2011 | Umesh Vinayak Kulkarni, **no dates on his page** | "making a hue and cry in the village saying God Dattatreya made an appearance for him" (Keshya, a village youth); won the 59th National Film Award for Best Feature Film | en.wikipedia Deool |
| Duniyadari, 2013 (novel by Suhas Shirvalkar, 15 Nov 1948 to 11 Jul 2003) | Sanjay Jadhav, "born 18 July 1970" | "a youngster in his early 20s from Mumbai" is sent to S. P. College in Pune and meets a gang of friends | en.wikipedia Duniyadari; Suhas Shirvalkar; Sanjay Jadhav |
| Natsamrat, film 2016 | Mahesh Manjrekar, "born 16 August 1958" | see A1 | en.wikipedia Natsamrat; Mahesh Manjrekar |
| Ghashiram Kotwal, first staged 16 Dec 1972 | Vijay Tendulkar, "6 January 1928 – 19 May 2008" | "based on the life of Nana Phadnavis (1741–1800)" and "Ghashiram Kotwal, the police chief of the city"; "political satire" | en.wikipedia Ghashiram Kotwal; Vijay Tendulkar |
| Yayati, 1959 | V. S. Khandekar, "11 January 1898 – 2 September 1976" | "a modern retelling of the story of the Hindu king ... from the Mahabharata" | en.wikipedia Yayati (novel); Vishnu Sakharam Khandekar |

## A4. Ten more works, verified

Each has a year, a creator and a premise on a named public page. The list of facts a question may rest on is in the last column; any other fact is out.

| # | Medium | Title and year | Creator, dates | Premise (words relied on) | Facts a quiz question may rest on |
|---|---|---|---|---|---|
| 21 | film | Samna, 1974 | Jabbar Patel, "born 23 June 1942"; written by Vijay Tendulkar | "A middle-aged penniless drunkard arrives at a sleepy village by bus" and the sugar baron Hindurao is worried (en.wikipedia Samna (film)) | director; writer; year; it won the National Film Award for Best Marathi Feature Film (23rd) |
| 22 | film | Jait Re Jait, 1977 | Jabbar Patel; based on a book by G. N. Dandekar ("8 July 1916 – 1 June 1998") | "a story that revolves around Nagya, a thakar tribal drummer" (en.wikipedia Jait Re Jait) | director; year; book author; "musical film" |
| 23 | film | Umbartha, 1982 | Jabbar Patel | "a woman's dream to step outside her four walled home and bring change in the society"; "shot in Marathi and Hindi, the latter titled Subah"; based on the novel Beghar (en.wikipedia Umbartha) | year; director; title meaning "The Doorstep"; Smita Patil lead (17 Oct 1955 to 13 Dec 1986) |
| 24 | film | Pinjara, 1972 | V. Shantaram, "18 November 1901 – 30 October 1990" | "a morally righteous school teacher ... who wants to reform a Tamasha performer ... but ends up falling in love with her" (en.wikipedia Pinjara (film)) | director; year; setting is Tamasha; title means "Cage" |
| 25 | film | Ek Hota Vidushak, 1992 | Jabbar Patel | "Aburao (Laxmikant Berde), a famous film star in Maharashtra", life of a folk theatre artist (en.wikipedia Ek Hota Vidushak) | director; year; lead actor; title means "Once There Was A Clown" |
| 26 | film | Lai Bhaari, 2014 | Nishikant Kamat, "17 June 1970 – 17 August 2020" | "marks the debut of Riteish Deshmukh in Marathi cinema", "highest grossing Marathi film during that time" (en.wikipedia Lai Bhaari) | director; year; debut fact; highest grossing at the time |
| 27 | film | Ventilator, 2016 | Rajesh Mapuskar (**no dates**), produced by Priyanka Chopra | "the Kamerkar family, whose oldest and most beloved member enters a coma and is put on a medical ventilator a few days before the Ganesh Chaturthi festival" (en.wikipedia Ventilator (2016 film)) | director; year; premise; festival |
| 28 | film | Sant Dnyaneshwar, 1940 | Vishnupant Govind Damle and Sheikh Fattelal | "based on the life of the 13th-century Marathi saint and poet Dnyaneshwar"; "released on 18 May 1940" (en.wikipedia Sant Dnyaneshwar (film)) | year; release date; studio Prabhat; subject |
| 29 | play | Shantata! Court Chalu Aahe, written 1963, first performed 1967 | Vijay Tendulkar | "A group of teachers plan to stage a play in a village ... a mock trial is staged to make the novice understand court procedures" (en.wikipedia Shantata! Court Chalu Aahe) | writer; written 1963; first performed 1967; title means "Silence! The Court Is in Session"; translated into 16 languages |
| 30 | play | Sakharam Binder, first performed 1972 | Vijay Tendulkar | "Sakharam, a bookbinder, picks up other men's discarded women ... and takes them in as domestic servants and sex partners"; "banned in India in 1974" (en.wikipedia Sakharam Binder). **Adult theme: a quiz uses only the year, writer, the ban and "bookbinder".** | writer; year; ban 1974; occupation |

Songs, series and podcasts: see "Dropped and why". The one series page read, en.wikipedia Chala Hawa Yeu Dya, gives "a TV reality show which aired on Zee Marathi", "premiered from 18 August 2014"; it has no single creator, so it is not a recommendation row, only an optional quiz fact.

## B. Multi-word verbs

The plan's count (3 pages on en.wiktionary) was too low: CirrusSearch with `incategory:Marathi_lemmas` finds many more noun-plus-verb pages. mr.wiktionary answered after the 429 period, and it holds entries copied from the Saraswati Shabdakosh of Vidyadhar Vaman Bhide (the pages say so). Each row: phrase, meaning, URL, words relied on. en.wiktionary URLs are `https://en.wiktionary.org/wiki/<phrase>`; mr.wikipedia and mr.wiktionary likewise.

### B1. Conjunct verbs, noun plus verb (MR-030): 30 entries

| # | Phrase | Meaning | Page | Words relied on |
|---|---|---|---|---|
| 1 | मदत करणे | to help | en.wiktionary | "to help" |
| 2 | विचार करणे | to think | en.wiktionary | "to think" |
| 3 | नमस्कार करणे | to pay obeisance | en.wiktionary | "to pay obeisance; to seek blessings from God or elders by bowing down or by touching their feet" |
| 4 | आंघोळ करणे | to bathe | en.wiktionary | "to bathe, to take a bath"; usage "गरम पाण्याने आंघोळ केल्यावर तिला बरे वाटले." |
| 5 | उपवास करणे | to fast | en.wiktionary | "to fast, abstain from food"; synonym उपास करणे |
| 6 | उपास करणे | to fast | en.wiktionary | "to fast, abstain from food" |
| 7 | कल्पना करणे | to imagine | en.wiktionary | "to imagine, conceive, or suppose mentally" |
| 8 | काळजी करणे | to worry | en.wiktionary | "to worry" |
| 9 | काळजी घेणे | to take care of | en.wiktionary | "to take care of" |
| 10 | कृत्य करणे | to perform an act | en.wiktionary | "to perform an act or action" |
| 11 | खेळ करणे | to act carelessly | en.wiktionary | "to act carelessly, irresponsibly, or without taking something seriously"; usage "आगीजवळ असा खेळ करू नकोस." |
| 12 | गोळा करणे | to collect | en.wiktionary | "to collect, gather" |
| 13 | गोळा होणे | to gather | en.wiktionary | "to assemble, gather" |
| 14 | गैरसमज होणे | to misunderstand | en.wiktionary | "to misunderstand"; usage "या भूमिकेसाठी त्यांचा सर्व बाजूंनी गैरसमज झाला." |
| 15 | बाऊ करणे | to make a fuss | en.wiktionary | "to exaggerate, make a fuss about" |
| 16 | कडी करणे | to outdo | en.wiktionary | "to best" |
| 17 | उडी मारणे | to jump | en.wiktionary | "to jump; leap into the air"; "to dive or jump into (water, etc.)" |
| 18 | गोळी मारणे | to shoot | en.wiktionary | "to shoot"; synonym गोळी झाडणे |
| 19 | टोमणा मारणे | to taunt | en.wiktionary | "to taunt, mock, or make a pointed remark at someone" |
| 20 | थारा घेणे | to take shelter | en.wiktionary | "to take shelter; seek or obtain refuge or lodging."; usage "पावसापासून वाचण्यासाठी त्यांनी देवळात थारा घेतला." |
| 21 | थारा देणे | to give shelter | en.wiktionary | "to give shelter to; provide refuge, lodging, or a place to stay."; usage "वादळाच्या रात्री गावकऱ्यांनी प्रवाशांना थारा दिला." |
| 22 | हमी घेणे | to take responsibility | en.wiktionary | "to assume responsibility" |
| 23 | हमी देणे | to guarantee | en.wiktionary | "to (give a) guarantee" |
| 24 | श्वास घेणे | to breathe | en.wiktionary | "to breathe, take a breath" |
| 25 | श्वास लागणे | to pant | en.wiktionary | "to pant, gasp; breathe in a quick or labored manner." |
| 26 | आभाळ येणे | the sky clouds over | en.wiktionary | "for the sky to become overcast" |
| 27 | काम करणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | "मराठीत काम करणे, प्रेम करणे, उडी मारणे, निर्माण करणे इ. रचनांना संयुक्त क्रियापद असे म्हणण्यात येते." The page gives **no meaning**; the course card gives it. |
| 28 | प्रेम करणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | "प्रेम करणे, उडी मारणे अशा नाम + धातू मिळून संयुक्त क्रियापद होते"; "संयुक्त क्रियापदात दोन शब्द मिळून एक साधी संकल्पना व्यक्त करतात. उदा. प्रेम करणे". No meaning gloss. |
| 29 | निर्माण करणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | same sentence as row 27. No meaning gloss. |
| 30 | गप्पा मारणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | "संयुक्त क्रियापदातल्या घटक शब्दांचे अर्थपरिवर्तन होते. उदा. गप्पा मारणे (तुळा : गुद्दा मारणे)". No meaning gloss. |

Rows 27 to 30 are verified as members of the family but their meanings come from the course or the builder's own knowledge of the course cards, so a builder uses them only where the course already teaches the meaning.

### B2. Compound or vector verbs, participle plus verb (MR-031): 19 entries

| # | Phrase | Meaning | Page | Words relied on |
|---|---|---|---|---|
| 1 | खाऊन टाकणे | (structure only) | mr.wikipedia क्रियापद | "बाळ एवढा लाडू खाऊन टाक (खाऊन=धातुसाधीत, टाक=सहाय्यक क्रियापद)". No meaning gloss. |
| 2 | खेळू लागणे | (structure only) | mr.wikipedia क्रियापद | "क्रिडांगणावर मुले खेळू लागली. (खेळू=धातुसाधीत, लागली=सहाय्यक क्रियापद)". No meaning gloss. |
| 3 | वाचत बसणे | one action | mr.wikipedia क्रियापद | "तो वाचत बसला." यात वाचणे आणि बसणे अशी दोन क्रियापदे असली तरी एकाच कृतीचा बोध होतो." |
| 4 | जाऊ देणे | (structure only) | mr.wikipedia क्रियापद | "क्रियापद दाखविणारे हे एकाहून अधिक शब्द सुटेसुटे लिहायचे असतात. उदा० जिंकू या, जाऊ दे, करू पाहतो." |
| 5 | करू पाहणे | (structure only) | mr.wikipedia क्रियापद | same sentence |
| 6 | जिंकू या | (structure only) | mr.wikipedia क्रियापद | same sentence |
| 7 | करून टाकणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | "करून टाकणे, लिहून काढणे ह्या रचनांत धातू (धातूसाधित/ कृदन्त) + धातू (आख्यातप्रत्यययुक्त) मिळून संयुक्त क्रियापद होते." |
| 8 | लिहून काढणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | same sentence |
| 9 | लिहून टाकणे | (structure only) | mr.wikipedia संयुक्त क्रियापद | "हे पुस्तक लिहून टाक. ह्यात लिह हा धातू मुख्य, टाक हा धातू गौण." |
| 10 | करून देणे | to do for (someone) | en.wiktionary देणे | "following a completive verb to do for"; usage "माझ्यासाठी करून दे।" |
| 11 | सोडून देणे | to give up, quit | en.wiktionary सोडणे | "to quit, give up"; usage "नितीनने त्याची नोकरी सोडून दिली." |
| 12 | सोडून जाणे | to leave | en.wiktionary सोडणे | "to leave"; usage "नितीन भारत सोडून गेला." |
| 13 | ओळख करून घेणे | to get acquainted | en.wiktionary | "to get acquainted" |
| 14 | ओळख करून देणे | to introduce | en.wiktionary | "to introduce" |
| 15 | गैरसमज करून घेणे | to misunderstand | en.wiktionary गैरसमज होणे | usage "गोष्टींचा गैरसमज करून घेण्याची त्याची प्रवृत्ती आहे." (He has a tendency to misunderstand things) |
| 16 | खाल्ला जाणे | passive with जाणे | mr.wikipedia क्रियापद | "आंबा (राम/सीता/पाखरू ह्यातल्या एका किंवा अनेकांकडून) खाल्ला ( जातो/गेला/जाईल)" |
| 17 | करून दाखवणे | to show by doing | mr.wikiquote म्हणी | "करून दाखवावें, बोलून दाखवू नये" with "नुसते बोलण्यापेक्षा ती गोष्टं प्रत्यक्ष करून दाखवावी." |
| 18 | बोलून दाखवणे | to say aloud | mr.wikiquote म्हणी | same proverb, "बोलून दाखवू नये" |
| 19 | ऐकून घेणे | to hear (someone) out | mr.wikiquote म्हणी | "ऐकून घेत नाही, त्याला सांगू नये काही" with "एखादी व्यक्ती जर काही ऐकून घेण्यास तयार नसेल तर त्याला काही सांगायला जाऊ नये." |

**19 of the 20 aimed for.** Rows 1, 2, 4 to 9 are verified as examples of the pattern; the pages give no gloss, so each deck card needs its meaning from the verb pages (टाकणे and लागणे on en.wiktionary give "to throw away" and "to commence (a particular activity)" respectively) and the course.

### B3. Idiomatic verbal phrases, वाक्प्रचार (MR-032): 22 entries

| # | Phrase | Meaning (the page's words) | Page |
|---|---|---|---|
| 1 | अग्निदिव्य करणे | "कठीण कसोटीला उतरणे." | mr.wikipedia मराठी वाक्प्रचार |
| 2 | अटकेपार झेंडा लावणे | "फार मोठा पराक्रम गाजवणे." | mr.wikipedia मराठी वाक्प्रचार |
| 3 | अठरा विश्वे दारिद्र्य असणे | "पराकोटीचे दारिद्र्य असणे." | mr.wikipedia मराठी वाक्प्रचार |
| 4 | सर्वस्व पणाला लावणे | "सर्व शक्य मार्गांचा अवलंब करणे." | mr.wikipedia मराठी वाक्प्रचार |
| 5 | साखर पेरणे | "गोड गोड बोलून आपलेसे करणे." | mr.wikipedia मराठी वाक्प्रचार |
| 6 | सामोरे जाणे | "निधड्या छातीने संकटास तोंड देणे." | mr.wikipedia मराठी वाक्प्रचार |
| 7 | अंधारात अत्तराचे दिवे लावणे | "अति श्रीमंतीचा बडेजाव मिरवण्याच्या नादात मूळ गरजेकडे दुर्लक्ष होणे" | mr.wikiquote म्हणी |
| 8 | अर्ध्या हळकुंडाने पिवळे होणे | "छोट्याश्या हुशारीचा गर्व होऊन त्याचा बडेजाव मिरवणे ." | mr.wikiquote म्हणी |
| 9 | आग लागल्यावर विहीर खणणे | explained as digging a well only when the fire has started; "लगेच पाणी मिळेल का" | mr.wikiquote म्हणी |
| 10 | उंटावरून शेळ्या हाकणे | "कामात हलगर्जीपणा असल्यास काम नीट होत नाही." | mr.wikiquote म्हणी |
| 11 | चालत्या गाडीला खीळ घालणे | "सुरळीत चाललेल्या कार्यात विघ्न आणणे." | mr.wikiquote म्हणी |
| 12 | तकटून खाणे | "आकंठ खाणे." | mr.wiktionary (source line: सरस्वती शब्दकोश, कोशकार - कै.विद्याधर वामन भिडे) |
| 13 | तकटून बांधणे | "घट्ट बांधणे." | mr.wiktionary |
| 14 | तटका तोडणे | "मागे पुढे न पाहता किं.भीड मुरवत न धरता साप आणि स्पष्टपणे आपले मत सांगून टाकणे." and "निकालात काढणे." | mr.wiktionary |
| 15 | तटका तुटणे | "निकलांत निघने." (as printed) | mr.wiktionary |
| 16 | तटास लागणे | "अटीस पडणे किं.पेटणे" (as printed) | mr.wiktionary |
| 17 | घिसाडघाई करणे | "कसेतरी काम करणे." | mr.wiktionary घिसाडी, section वाक्प्रचार |
| 18 | मुंग्या येणे | "शरीराचा काही भाग बधिर होणे" | mr.wiktionary मुंगी |
| 19 | पदरी पडणे | "to fall into one's lap; to come into one's possession or responsibility"; usage "त्याच्या पदरी दोन मुलांची जबाबदारी पडली." | en.wiktionary |
| 20 | डल्ला मारणे | "to loot, sack" | en.wiktionary |
| 21 | वेड लागणे | "to go mad; to become insane", figurative "to become intensely obsessed or infatuated" | en.wiktionary |
| 22 | गृहीत धरणे | "to take for granted"; usage "कुणाच्याही मेहनतीला गृहीत धरणे योग्य नवे." | en.wiktionary |

Rows 7 to 11 are rows of the proverbs decks (the plan says each is used in one deck only). Rows 12 to 16 are Bhide dictionary entries with older or Hindi-mixed wording; the builder uses them with the meaning as printed and flags the doubt on 15 and 16.

### B4. Dative-subject constructions, मला plus a verb of feeling (MR-033): 20 entries

| # | Phrase or sentence | Meaning | Page | Words relied on |
|---|---|---|---|---|
| 1 | मला मराठी येते | I can speak Marathi (lit. "Marathi comes to me") | en.wiktionary येणे | "to be able to do something"; "मला मराठी येते."; lit. "Marathi comes to me" |
| 2 | मला वाईट वाटले | I felt bad | en.wiktionary वाटणे | "to feel, think"; "काल मला खूप वाईट वाटले." |
| 3 | तिला बरे वाटले | she felt better | en.wiktionary आंघोळ करणे | "गरम पाण्याने आंघोळ केल्यावर तिला बरे वाटले." |
| 4 | मला अगोचर वाटते | it seems incomprehensible to me | en.wiktionary अगोचर | "त्याचे वागणे मला अगोचर वाटते." |
| 5 | मला राग (आणि कीव) वाटतो | I feel anger | en.wiktionary राग | "मला त्याच्याबद्दल राग आणि कीव दोन्ही वाटतात." |
| 6 | मला गाडी लागते | I get motion sick | en.wiktionary गाडी लागणे | "मला गाडी लागते, म्हणून मी प्रवासात खिडकीजवळ बसतो." |
| 7 | मुलांना कंटाळा आला | the children got bored | en.wiktionary कंटाळा | "दवाखान्यात वाट पाहत असताना मुलांना प्रचंड कंटाळा आला." |
| 8 | मला कॉफी पाहिजे | I want coffee | mr.wikipedia क्रियापद | "मला कॉफी पाहिजे." (listed under अनियमित/गौण क्रियापद) |
| 9 | तिला मळमळते | she feels nauseous | mr.wikipedia क्रियापद | "पित्त झाल्यामुळे तिला आज मळमळते." (भावकर्तृक क्रियापद) |
| 10 | मला काम करवते | I am able to work | mr.wikipedia क्रियापद | "मला आता काम करवते." (शक्य क्रियापद, "कर्त्याकडून ती क्रिया करण्याची शक्यता") |
| 11 | मला चालविते | I can walk (20 km) | mr.wikipedia क्रियापद | "मला दररोज 20 कि.मी. चालविते." |
| 12 | बाईंना आणवत नाही | the teacher cannot carry them | mr.wikipedia क्रियापद | "बाईंना वह्या वर्गात आणवत नाही." |
| 13 | आजारी माणसाला बसवते | the sick man can sit | mr.wikipedia क्रियापद | "त्या आजारी माणसाला आता थोडे बसवते." |
| 14 | माणसाला शहाणपण येते | a person gains sense | mr.wikiquote म्हणी (आधी जाते अक्कल मग सुचते शहाणपण) | "माणसाला शहाणपण येते"; also "आपल्याला खूप सुचत असते" |
| 15 | त्याला हौस आली | he took a fancy | mr.wikiquote म्हणी (अडाण्याचा गेला गाडा) | "त्याला गाडी फिरवायची हौस आली" |
| 16 | आवडणे | to be liked | en.wiktionary आवडणे | "to be liked, loved"; "to be pleasing, delightful". **Gloss only, no example.** |
| 17 | सुचणे | to occur to one | en.wiktionary सुचणे | "to come to mind, occur (as a thought or idea)". **Gloss only.** |
| 18 | दिसणे | to seem | en.wiktionary दिसणे | "to seem, appear". **Gloss only.** |
| 19 | येणे (befall) | to befall, be affected by | en.wiktionary येणे | "to befall, be affected by". **Gloss only.** |
| 20 | वेड लागणे / सवय लागणे | to go mad; to develop a habit | en.wiktionary | "to develop a habit" (लागणे, usage "सवय लागणे"). **Gloss only.** |

Rows 1 to 15 show the oblique pronoun or noun as the experiencer in a stated sentence; rows 16 to 20 are verbs the page glosses without a subject example, so the builder needs a stated sentence from the course or a page before building a card. No page in this search calls the pattern "dative subject": en.wikipedia "Dative subject" was read and has no Marathi, and en.wikipedia "Marathi grammar" has no section (it only discusses the dative case marker -ला). The grouping is the plan's.

Totals: 30 + 19 + 22 + 20 = **91 entries** (60 asked), each with a page and quoted words; 10 of them are gloss-only or structure-only and flagged.

## Dropped and why

- **Sandeep Sawant's birth year.** en.wikipedia, mr.wikipedia and Wikidata give none; a web search found none; IMDb is blocked. The builder omits `born` or uses another creator.
- **Sheikh Fattelal's dates.** No page with dates on en.wikipedia or mr.wikipedia; the Prabhat page lists him without dates. The film stays a recommendation with Damle's dates and a note.
- **Umesh Vinayak Kulkarni and Rajesh Mapuskar.** Their pages give no birth year; the rows keep the work, not the director's dates.
- **Mrityunjay publication year.** No page read states it; only the translations years.
- **Moortidevi Award year (Sawant) and the Sahitya Akademi year (Deshpande, 1965 vs a 1966 book).** The pages conflict; no question rests on these.
- **Songs and podcasts.** The only song page tried (en.wikipedia "Zing Zing Zingaat") does not exist, the "Katyar" soundtrack appears only as a disambiguation line, and no podcast page was reached. None dropped in without a page.
- **Sinhasan (1979 film), Swami (novel), Shyamchi Aai (film) as separate rows.** en.wikipedia titles tried (Sinhasan (film), Sinhasan (1979 film), Swami (novel)) do not exist; the Shyamchi Aai film page is a stub (1,082 characters) with no year beyond 1953 from mr.wikipedia.
- **Molesworth, Wikibooks, Balbharati and NCERT as sources of verbs.** Blocked hosts (see top); the Wikisource searches for Molesworth returned 0 hits. The phrase source is instead Bhide's dictionary on mr.wiktionary.
- **mr.wiktionary full harvest.** 160 of 2,628 pages were read (to bound requests); phrase entries with "वाक्प्रचार" sections beyond those named above were not found there. More may exist.
- **A "Compound verb" and "Conjunct verb" article on en.wikipedia.** Read; the compound-verb page covers Hindi-Urdu only, and the "Conjunct verb" title returned a 21-character stub with no content. Not used.
- **B2 row 20.** 19 vector entries were found against 20 asked; none is invented.

## Review-queue rule

Everything here is `unreviewed`. Doubts (Bhide's older wording, the conflicting award years, the structure-only rows) go to `docs/review-queue/mr.md` through the builder's report.
