# Plan: Assamese genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task AS-001 of [Deck-Work-Queue-AS](Deck-Work-Queue-AS.md), written 2026-11-15 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md), in the shape of [Plan-Culture-Hindustani](Plan-Culture-Hindustani.md), [Plan-Culture-Bengali](Plan-Culture-Bengali.md) and [Plan-Culture-Spanish](Plan-Culture-Spanish.md). It feeds AS-010 to AS-013 (culture), AS-020 to AS-022 (proverbs), AS-030 to AS-033 (multi-word) and AS-060 and AS-061 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md). If this page and a task row differ, this page wins.

## What "verified" means on this page

Every row below was read on a page fetched on 2026-11-15 (the page is named in the row's group). **Verified** means: the title, the creator's exact English name, the years and the rights fact in the row were stated on that page. It does **not** mean the work's text was read: the builder still reads the text itself (as.wikisource first, then the cited edition), keeps an excerpt of at most 25 words, and drops any candidate whose text it cannot read. Nothing is written from memory. Where a page gave two dates, both are shown and the row says so. Counts are in the table at the end; where fewer than the target passed, the deck is smaller, never padded.

Pages fetched (all 2026-11-15): en.wikipedia pages for Srimanta Sankardev, Madhavdev, Madhava Kandali, Hema Saraswati, Ananta Kandali, Borgeet, Lakshminath Bezbaroa, Burhi Aair Sadhu, Hemchandra Barua, Anandaram Dhekial Phukan, Gunabhiram Barua, Padmanath Gohain Baruah, Chandra Kumar Agarwala, Rajanikanta Bordoloi, Jyoti Prasad Agarwala, Assamese literature, Assamese grammar, Orunodoi, Ojapali, Bihu, Lachit Borphukan, Sukaphaa, Rang Ghar, Kamakhya Temple, Majuli, Indira Goswami, Bhupen Hazarika, Birendra Kumar Bhattacharya, Zubeen Garg, Jahnu Barua, Xagoroloi Bohudoor, Village Rockstars; as.wikisource main page; as.wikiquote pages ফকৰা যোজনা, জতুৱা ঠাঁচ, ডাকৰ বচন, বিহুনাম and the main page; en.wiktionary "Category:Assamese verbs" (three result pages), its transitive and intransitive subcategories, "Category:Assamese phrases", and the entries আৰম্ভ কৰা, আত্মহত্যা কৰা, কথা পতা, ধৰা পেলোৱা, ভাল লগা, হৈ যোৱা.

## Rules applied

- **Rights floor.** The author died in **1955 or earlier**, or an anonymous or traditional work was first published before **1900**. Basis `public-domain` for authored works, `oral-tradition` for proverbs. Jurisdiction `IN`; any doubt goes to the review queue as "to be read". A page that gives conflicting dates is flagged in the row, and the builder reads a second source before building.
- **Ineligible and excluded.** Indira Goswami (died 2011), Bhupen Hazarika (died 2011), Birendra Kumar Bhattacharya (died 1997) and Zubeen Garg (died 2025) cannot be culture candidates: they are recommendations only (works the learner sources). Chandra Kumar Agarwala's *Chandramrit* (1967, posthumous) is first published after his death and is not used.
- **One excerpt per card**, at most 25 words, shown as on the cited edition in Assamese script. No quotation items.
- **Creators** (`decks/creators/as.yaml`): `name.en.text` equals `source.author`; `born` and `died` are a plain year or `circa`. A day of the month is not stored.
- **Reading and IPA** by the tools, never by hand ([Deck-Work-Queue-AS](Deck-Work-Queue-AS.md) section 2).
- **Order.** AS-010 to AS-013 run one after another (shared `creators/as.yaml`); proverbs and multi-word decks are independent of that lane.

## Culture 1, `as-culture-1`: medieval and Vaishnava (AS-010, ids as-4100 to 4149)

Sources: en.wikipedia pages named in each row. Where a lifespan is given by the page only as an era, the row says "era only"; such rows need a second source for dates before the creator record is written.

| # | Candidate work | Creator (exact name on the page) | Verified facts |
|---|---|---|---|
| 1 | Prahlada Charita | Hema Saraswati | en.wikipedia "Hema Saraswati": court poet under King Durlabh Narayan of Kamata, the earliest known Assamese poetic work; no birth or death date given (13th-century category). Era only |
| 2 | Saptakanda Ramayana | Madhava Kandali | en.wikipedia "Madhava Kandali": 14th century (infobox: mid-1300s); earliest Ramayana translation into an Indo-Aryan language. Era only |
| 3 | Kirtan Ghosha (Kirtana-ghosha) | Srimanta Sankardev | en.wikipedia: 1449 to 1568; the page calls it his magnum opus |
| 4 | Gunamala | Srimanta Sankardev | en.wikipedia: 1449 to 1568 |
| 5 | Borgeet "mana meri rama-caranahi lagu" | Srimanta Sankardev | en.wikipedia "Borgeet": said to be the first borgeet, composed at Badrikashrama; 15th to 16th century; 240 composed, about 34 recovered |
| 6 | Parijata-harana (Ankia Nat) | Srimanta Sankardev | en.wikipedia: 1449 to 1568 |
| 7 | Rukmini-harana (Ankia Nat) | Srimanta Sankardev | en.wikipedia: 1449 to 1568 |
| 8 | Kali-damana (Ankia Nat) | Srimanta Sankardev | en.wikipedia: 1449 to 1568 |
| 9 | Naam Ghosa (Hazari Ghosa) | Madhavdev | en.wikipedia "Madhavdev": May 1489 to 1596 (only the death year is given) |
| 10 | Bhakti Ratnavali | Madhavdev | en.wikipedia: 1489 to 1596 |
| 11 | Borgeet "Alu moi ki kohobu dukho" (raga Bhatiyali) | Madhavdev | en.wikipedia "Borgeet": named there as his; the composer count is "more than 200" |
| 12 | Arjun Bhanjan (Dadhimathan) | Madhavdev | en.wikipedia: 1489 to 1596; the only drama not called a Jhumura |
| 13 | Chordhara (Jhumura) | Madhavdev | en.wikipedia: 1489 to 1596 |
| 14 | Pimpara Guchowa (Jhumura) | Madhavdev | en.wikipedia: 1489 to 1596 |
| 15 | Bhojan Bihar (Jhumura) | Madhavdev | en.wikipedia: 1489 to 1596 |
| 16 | Mahiravana Vadha | Ananta Kandali | en.wikipedia: January 1540 to 1580; the page gives no date for the work |
| 17 | Bhatima (Deva bhatima) | Srimanta Sankardev | en.wikipedia: songs of praise named Deva, Naat and Raja bhatima; 1449 to 1568 |
| 18 | Harishchandra-upakhyana | Srimanta Sankardev | en.wikipedia: his first work; 1449 to 1568 |

Reserve (verified the same way): Anadi-patana, Bhakti-pradipa and Nimi-navasiddha-samvada (Sankardev); Bhumi Letowa and Janma Rahasya (Madhavdev); Harihara Yuddha and Kumara Harana (Ananta Kandali); Hara Gauri Samvada (Hema Saraswati, en.wikipedia "Assamese literature"). Dates: Sankardev's page gives 1449 to 1568; the builder notes that Madhavdev's page gives only a death year.

This task creates `decks/creators/as.yaml` (`kind: "creators"`, `id: "creators-as"`, `language: "as"`) with eras taken from en.wikipedia "Assamese literature": the Charyapada period (8th to 10th century as stated), pre-Shankari (1300 to 1490), Shankari (1490 to 1700), then the eras added by AS-011 and AS-013.

## Culture 2, `as-culture-2`: Orunodoi, Jonaki and the modern writers to 1955 (AS-011, as-4150 to 4199)

Sources: en.wikipedia pages named in each row. Conflicts are the pages' own.

| # | Candidate work | Creator | Verified facts |
|---|---|---|---|
| 1 | Asomiya Lorar Mitra | Anandaram Dhekial Phukan | en.wikipedia: 22 Sep 1829 to 16 Jun 1859; 1849, two volumes, "a milestone in Assamese literature" |
| 2 | Englandor Biwaran | Anandaram Dhekial Phukan | en.wikipedia: published in Orunodoi, 1847 |
| 3 | A Few Remarks on the Assamese Language | Anandaram Dhekial Phukan | en.wikipedia: 1855, in English |
| 4 | Ramnabami-Natak | Gunabhiram Barua | en.wikipedia: born 1834 (categories say 1837), died 1894; written 1857, published 1870 |
| 5 | Assam Buranji | Gunabhiram Barua | en.wikipedia: published 1887; later a school textbook |
| 6 | Ôxômiya Byakôrôn (Assamese grammar) | Hemchandra Barua | en.wikipedia: 10 Dec 1835 (categories say 1836) to 1897; 1859 |
| 7 | Kaniyar Kirttôn | Hemchandra Barua | en.wikipedia: 1861 |
| 8 | Pathmala | Hemchandra Barua | en.wikipedia: 1882 |
| 9 | Hemkosh (dictionary) | Hemchandra Barua | en.wikipedia: published 1900, after his death in 1897 (first publication posthumous: a review row) |
| 10 | Kripabar Barbaruar Kakatar Tupi | Lakshminath Bezbaroa | en.wikipedia: 14 Oct 1864 (the infobox 1868, invented by Bezbaroa) to 26 Mar 1938; 1904 |
| 11 | O Mur Apunar Dex | Lakshminath Bezbaroa | en.wikipedia: in Kodomkoli (1913 in the text, 1915 in the bibliography); later Assam's state anthem; the poem's own year is not given |
| 12 | Padumkunwari | Lakshminath Bezbaroa | en.wikipedia: written 1891, book form 1905, serialised in Jonaki |
| 13 | Kodomkoli (poems) | Lakshminath Bezbaroa | en.wikipedia: 1913 (text) or 1915 (bibliography) |
| 14 | Miri Jiyori | Rajanikanta Bordoloi | en.wikipedia: 24 Nov 1867 to 25 Mar 1940 (a cited source says 1869 to 1939); 1894 |
| 15 | Manomoti | Rajanikanta Bordoloi | en.wikipedia: 1900 |
| 16 | Pratima | Chandra Kumar Agarwala | en.wikipedia: 28 Nov 1867 (the body says 28 Oct) to 2 Mar 1938; 1914 |
| 17 | Bhanumati | Padmanath Gohain Baruah | en.wikipedia: 24 Nov 1871 to 21 Apr 1946; 1890, called the first Assamese novel |
| 18 | Joymati (film) | Jyoti Prasad Agarwala | en.wikipedia: 17 Jun 1903 to 17 Jan 1951; 1935, filming began around the end of 1933 |

Reserve: Bin-boragi (1923) by Chandra Kumar Agarwala; Rangilee (1925), Radha aru Rukminir Ron (1925) and Nirmal Bhakat (1927) by Rajanikanta Bordoloi; Lahori (1892) by Padmanath Gohain Baruah; Sonit Kunwori (play, 1925), Karengar Ligiri (play, 1930), Rupalim (play, 1938), Indramalati (film, 1939), Lobhita (play, 1945) by Jyoti Prasad Agarwala; Xurobhi (1909), Litikai (1890 or 1894), Joymoti Kũwori (1915) by Lakshminath Bezbaroa; the Jonaki magazine (1889, en.wikipedia "Assamese literature" and "Lakshminath Bezbaroa", an institution, no single creator). Not used: Orunodoi (1846, en.wikipedia: founded by Nathan Brown, publisher Oliver Thomas Cutter): its founders' death years were not read. Bezbaroa's and Jyoti Prasad's works need the first-publication year read for the review queue only where the page gives two years.

## Culture 3, `as-culture-3`: folk and oral traditions before 1900 (AS-012, as-4200 to 4249)

Source: en.wikipedia "Burhi Aair Sadhu" (first published 1911, October to November; about 30 folk tales that Bezbaroa wrote and compiled; Bezbaroa died 1938) and "Lakshminath Bezbaroa". Each row is a tale named on the page; its text is read from the edition the builder cites. The rights floor is met by Bezbaroa's 1938 death; the tales' own origin is oral and traditional.

| # | Candidate | Verified facts |
|---|---|---|
| 1 | Bandor aru Xial (The Monkey and the Fox) | named on the page |
| 2 | Bagh aru Kekura (The Tiger and the Crab) | named on the page |
| 3 | Tejimola | named on the page |
| 4 | Burha-Buri aru Xial (The Old Man, the Old Woman and the Fox) | named on the page |
| 5 | Gangatup (The Globefish) | named on the page |
| 6 | Kukurikona (Purblind) | named on the page |
| 7 | Tula aru Teja (Toola and Teja) | named on the page |
| 8 | Ou Kuwori (The Ow-Princess) | named on the page |
| 9 | Champavati | named on the page |
| 10 | Juwair Xadhu (Tale of a son-in-law) | named on the page |

Only 10 rows pass. The deck is built at 10 and the report says so; the 8 further places are not padded. See "Unverified" for the folk material that did not pass (Bihu songs, lullabies, Ojapali texts, the charit puthi).

## Culture 4, `as-culture-4`: history and places (AS-013, as-4250 to 4299)

Basis: facts and places, no authored text beyond an excerpt of at most 25 words from a cited page. Facts are the page's own words.

| # | Candidate | Source page and verified facts |
|---|---|---|
| 1 | Lachit Borphukan | en.wikipedia: 24 Nov 1622 to 25 Apr 1672 |
| 2 | Battle of Saraighat | en.wikipedia "Lachit Borphukan": 1671, naval battle, Ahom forces defeated the Mughal fleet of Ram Singh I |
| 3 | Sukaphaa | en.wikipedia: reign 1228 to 1268; reached Namrup in 1228, the kingdom's founding year |
| 4 | Charaideo | en.wikipedia "Sukaphaa": capital built 1253, near present-day Sibsagar, the symbolic centre of Ahom rule |
| 5 | Rang Ghar | en.wikipedia: Sivasagar; first bamboo and wood under Rudra Singha, rebuilt in brick under Pramatta Singha between 1744 and 1751 (infobox: 1746) |
| 6 | Kamakhya Temple | en.wikipedia: Nilachal Hill, Guwahati; main temple rebuilt 1565 under Nara Narayan (1540 to 1587) |
| 7 | Ambubachi Mela | en.wikipedia "Kamakhya Temple": annual festival |
| 8 | Majuli | en.wikipedia: a river island in the Brahmaputra; Guinness record holder (Britannica disputes it); about 880 km2 in 2024 |
| 9 | The satras of Majuli | en.wikipedia "Majuli": Sankardev set up the first satra at Belguri; about 65 founded, 23 active; Dakhinpat, Auniati, Kamalabari, Narashingha (1746) |
| 10 | Majuli, India's first island district | en.wikipedia: 2016 |
| 11 | Molai Forest | en.wikipedia "Majuli": planted by Jadav Payeng, 550 hectares |
| 12 | Rongali (Bohag) Bihu | en.wikipedia "Bihu": April, the Assamese New Year and spring |
| 13 | Bhogali (Magh) Bihu | en.wikipedia "Bihu": January, harvest festival |
| 14 | Kongali (Kati) Bihu | en.wikipedia "Bihu": October or November |
| 15 | Ojapali | en.wikipedia "Ojapali": oja (lead singer) and pali (chorus), khutitaal cymbals; King Dharmanarayana (1615 to 1637) a patron; four types: Byah, Sukananni, Ramayani and Sattriya |
| 16 | Orunodoi | en.wikipedia: first Assamese monthly, January 1846, Sibsagar, Baptist Missionary Printing Press; ended 1883 (infobox) or about 1879 to 1880 (body) |
| 17 | Jonaki | en.wikipedia "Assamese literature" and "Lakshminath Bezbaroa": journal first published 1889 |
| 18 | The Buranjis | en.wikipedia "Assamese literature": Ahom court prose chronicles, written in large numbers from the early 17th century |

## Proverbs (AS-020 to AS-022, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, `source` with `collection`, `date`, `edition`, `jurisdiction: "IN"`, `rights_checked`, and a `literal` note per card. Source for all three decks: as.wikiquote pages **ফকৰা যোজনা** (alphabetical, about 183,000 characters; the pages cover the sections অ to হ; the lead says the list is not exhaustive; some entries carry footnote numbers, many have none) and **ডাকৰ বচন** (footnotes cite *Dak Charit* by Shivnath Bhattacharya, Gurdon's *Some Assamese Proverbs* "1903", Lila Gogoi's *Asamiya Lok-Sahityar Ruprekha* (2007), Hemchandra Goswami's *Asamiya Sahityar Chaneki* (1929), a panjika and xahitya.org; the texts are not footnoted one by one). The text is CC BY-SA 4.0 on the wiki. Gurdon's collection is dated 1896 by one source and 1903 by another: the `date` field of each card is the wiki page and the access year until the builder reads the book's own title page. The English meanings here are paraphrases of the page and are not copied; the builder writes its own.

### AS-020, `as-proverbs-1` (as-4400 to 4449): the first 20 on ফকৰা যোজনা

1 অতিথিও ৰওক, চাউলো সিজক; 2 অচিন আলহীক নিদিবা ঠাই ল’ৰা-ছোৱালীক নিদিবা লাই; 3 অধিক ভোজন মৃত্যুক আহ্বান; 4 অভাৱত স্বভাৱ নষ্ট; 5 অহঙ্কাৰেই পতনৰ মূল; 6 অলপ কথন জ্ঞানীৰ লক্ষণ; 7 আপোন ভালেই জগত ভাল; 8 আগৰ গৰু বাঘে খায়; 9 আঁঠুৱা চাই ঠেং মেলিবা; 10 আনলৈ হুল পুতি নিজে মৰে ফুটি; 11 আছে কপালত নিব কোনে, নাই কপালত দিব কোনে; 12 অতি দৰ্পে হত লংকা; 13 এবাৰ সাপে খালে লেজুলৈকো ভয়; 14 এখন হাতেৰে চাপৰি নাবাজে; 15 একে গছৰ পাণ, সি নো হ’ব কি আন; 16 উপদেশতকৈ আৰ্হি ভাল; 17 ঘহোঁতে ঘহোঁতে শিলো ক্ষয় যায়; 18 কান্দিলে ধাৰ শুজ নেযায়; 19 কুকুৰৰ নেজ কেতিয়াও পোন নহয়; 20 অতি টান হ’লে গাঁঠি ছিগি যায়. The page gives a meaning for each. Themes: food and guests, money and effort, pride and fate, animals.

### AS-021, `as-proverbs-2` (as-4450 to 4499): the next 10 on the first page, then the second page

1 দহো আঙুলিয়ে খায়, বুঢ়াই হেঁচুকিলেহে যায়; 2 নিচয়ে পাৰ চয়ে সংসাৰ; 3 অগ্নি ব্যাধি ঋণ এই তিনিৰ নেৰাখিবা চিন; 4 ওচৰৰ আলহী নকৰে কাণ, নৰিয়াত পৰিলে আহে কাম; 5 জয় কালত ভয় নাই, মৰণ কালত ঔষধ নাই; 6 অভ্যাসৰ নৰ, কৰ্ণপথে কৰে শৰ; 7 পলৰীয়া গৰুৰ বাটে বাটে ঘাঁহ; 8 পৰ্বতত কাছৰ কণী বিচৰা; 9 ফুটা কলহত পানী ঢলা; 10 বিনা মেঘে বজ্ৰপাত; 11 বন্ধু চিনিবা বিপদৰ বেলা; 12 বান্দৰে কি বুজে নাৰিকলৰ মোল; 13 বাঢৈৰ ঘৰত পীৰা নাই; 14 ভাতৰ লগত পানী খোৱা কথা; 15 ভালে পায় ভাল, জাবৰে পায় খাল; 16 মূৰ্খই ঠেকি শিকে, জ্ঞানীয়ে দেখি শিকে; 17 মিছা কথাৰ ঠেং চুটি; 18 লোভে পাপ, পাপে মৃত্যু; 19 লাগি থাকিলে মাগি নাখায়; 20 ৰাইজে নখ জোকাৰিলে নৈ বয়. Each decks lists the earlier deck's targets first and uses none of them again.

### AS-022, `as-proverbs-3` (as-4500 to 4549): sayings from ডাকৰ বচন and the rest of ফকৰা যোজনা

Ten from ডাকৰ বচন, read verbatim in the page's older spelling (the card's note says so and does not modernise): ৰাজাক চিনিবা দানত। ঘোঁৰাক চিনিবা কাণত।; যদি বৰষে জলৰ কণা। ৰঙ্গ কৰি নাচে কৃষক জনা॥; মেঘক দেখি হালক বাই। জানা শস্যৰ লাভক পাই॥; এহাত এমুঠন কলৰ পোত। তেহে চাবা কলৰ গোট॥; চৈত্ৰত কেন্দু ফল নিৰন্তৰ। বৈসাগ মাহত পৰে পাথৰ॥; বাৰিষা কালত বেঙ্গৰ ৰাৱ। হাল গৰু লৈ পথাৰক যাৱ॥; পৌষ মাসে যদি মেঘ গৰ্জন। মাঘ মাহতে মেঘ সোসন॥; যিজনে দিৱয় অন্নৰ সাৰি। সিজন নাযাই যমৰ নগৰী।; কথা ক'লে চিনিবা মুৰ্খ নে পণ্ডিত। সাধুক চিনিবা কৰি লেন-দেন বিত।; পুত্ৰক চিনিবা বিবাহৰ পৰে। বিপদে চিনি মিত্ৰে কেনে কৰে।. Ten from the second page of ফকৰা যোজনা not used above: শুনা কথাত নিদিবা কাণ, দেখিলেও ল’বা তিনিটা প্ৰমাণ; সহিলে সম্পদ নসহিলে বিপদ; সময়ৰ শৰ সময়ত মাৰিবা; সাপে খায় লেখি, বাঘে খায় দেখি; হাতৰটো এৰি বাটৰটোক ধৰা; যাৰ নাই ধান, তাৰ নাই মান; পাগলে নকয় কি, ছাগলে নাখায় কি; পেটত গৰল, মুখত অমৃত/মৌ; পূবৰ বেলি পশ্চিমত ওলোৱা; বহ্বাড়ম্ভে লঘু ক্ৰিয়া.

Further reserve, all read on the same pages: Dak sayings on farming and weather (যদি বৰিসে জল ধাৰে..., তিথি বৃদ্ধিয়ে শষ্যক নাশে... and 20 more from the 40 read), and the rest of the 70 read on ফকৰা যোজনা (পাপৰ ধন পৰাচিতত যোৱা, বয়সত বান্দৰৰো সুন্দৰ, ভুতৰ মুখত ৰাম নাম, মৌনতাই সন্মতিৰ লক্ষণ, লোহাৰেহে লোহা কাটিব পাৰি, বামুণৰো এদিন, শূদিৰৰো এদিন, বান্দৰে কি বুজে..., ফটা বাঁহ জোৰা নালাগে, ফাট মেলা বসুমতী পাতালে লুকাও). Cautions: the sections ক to ন of ফকৰা যোজনা were read only for the first 30 entries; a few proverbs carry caste or gendered wording (the page itself has a "sensitive" list): the builder reads that list and drops anything on it. The Dak sayings are attributed to a legendary figure with no date on the page: `date` is "traditional, collected by 1903" only after the builder reads the edition.

## Multi-word verbs (AS-030 to AS-033, 4 x 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note per card, parts already taught by `ref`. The citation form is the verbal noun in -া (কৰা, হোৱা), `words` join exactly to `target`. Source: en.wiktionary "Category:Assamese verbs" and its transitive and intransitive subcategories (snapshot dated 14 August 2017, 608 pages; the three listing pages read cover the multiword entries in roughly the first 200 pages of each listing, so the list is **not exhaustive**). The headword is verified by presence in the category; the builder reads the entry page for the sense and example before building. Entries read in full: আৰম্ভ কৰা ("to cause something to start"; example আমি কালিৰ পৰা কামটো আৰম্ভ কৰিছোঁ), আত্মহত্যা কৰা, কথা পতা ("to talk"), ধৰা পেলোৱা ("to detect"), ভাল লগা ("to like", with -অৰ; example মোৰ আইচ‌্ক্ৰিম বৰ ভাল লাগে), হৈ যোৱা ("to become"; "to occur": examples মোৰ ভাইটি ডাঙৰ উকিল হৈ গৈছে, কেতিয়াবা ভুল হৈ যায়). Background read on the terms: en.wikipedia "Assamese grammar" does not discuss compound verbs. The search result for compound verbs named Morey's chapter on explicator compounds and Borkotoky's four light verbs (give, come, get, raise); neither was opened, so they are not cited as sources here.

**Family counts in the pages read:**

### AS-030, `as-multiword-conjunct-kora` (as-4550 to 4599), `conjunct-verb`: noun or adjective plus কৰা: 28 verified headwords

অনুবাদ কৰা; আত্মহত্যা কৰা; আৰম্ভ কৰা; কাম কৰা; কাতি কৰা; চফা কৰা (also চাফা কৰা); চহী কৰা; চিকাৰ কৰা; চুটি কৰা; চেষ্টা কৰা; চোকা কৰা; দীঘল কৰা; থিয় কৰা; ধাৰ কৰা; নকল কৰা; পচন্দ কৰা (also পছন্দ কৰা); তৰ্জমা কৰা; বন্ধ কৰা; বমি কৰা; বিচাৰ কৰা; বিয়া কৰা; বেলেগ কৰা; মৰম কৰা; লাভ কৰা; সহায় কৰা; হজম কৰা; পঢ়া-শুনা কৰা; ভাঙনি কৰা. The first 20 that pass the entry read form the deck; the rest are reserve. Spelling variants (পচন্দ and পছন্দ, চফা and চাফা) count once.

### AS-031, `as-multiword-conjunct-other` (as-4600 to 4649), `conjunct-verb-other`: noun or adjective plus হোৱা, পোৱা, খোৱা, যোৱা, কোৱা: 22 verified headwords

কাতি হোৱা; চুটি হোৱা; দীঘল হোৱা; থিয় হোৱা; হজম হোৱা; ৰঙা হোৱা; কথা কোৱা; কথা পতা; ভয় খোৱা; গোট খোৱা; মন যোৱা; গম পোৱা; যোগান ধৰা; খোজ কঢ়া (also খোজ কাঢ়া); নাম কঢ়া (also নাম কাঢ়া); থু পেলোৱা; পিক পেলোৱা; হাল বোৱা; কবৰ দিয়া; আঁকোৱালি ধৰা (page form আঁকোৱালি ধৰ); উগাৰ মাৰা (also উগাৰ মৰা); ভাপত দিয়া (page form ভাপত দে). Spelling variants count once.

### AS-032, `as-multiword-compound` (as-4650 to 4699), `compound-verb`: verb plus verb (explicator): only 8 verified headwords, the deck will be short

ধৰা পেলোৱা; ধৰা পৰা; হৈ যোৱা; সুমাই দিয়া; আঙুলিয়াই দিয়া (page also lists আঙুলিয়াই দে); বুজি পোৱা; চিনি পোৱা; গৈ পা (page form). The listing pages read did not show more V plus V entries; the shortfall is 12. The builder may find more by reading the unread parts of the category and the verb entries themselves (for example the light verbs দিয়া, ল’, পেলোৱা, পোৱা, যোৱা, আহা on their own entry pages); each addition must be read on an entry page before it is added, and the deck stays below 20 if not.

### AS-033, `as-multiword-idiom` and experiencer (as-4700 to 4749)

AS-033 holds two sub-families, written as two decks if the builder prefers (`as-multiword-idiom`, `as-multiword-experiencer`), 20 plus the verified experiencer rows.

**Idioms, `idiomatic-expression`: 20 verified.** Source: as.wikiquote জতুৱা ঠাঁচ (60 idioms read, from the sections অ to উ only; the page gives no source for individual entries; CC BY-SA 4.0; meanings are page paraphrases): অকাজৰ কাজী; অথাই সাগৰ; অলপ পানীৰ মাছ; অচলা ভক্তি; অধিক মাছত বগলী কণা; অৱস্থা চাই ব্যৱস্থা; অকঁৰা মৈত উঠা; অৰণ্য-ৰোদন; আকাশ কুসুম; আঙুলিৰ মূৰত দিন গণা; আগত সাগৰ থাকি পিয়াহত মৰা; আঁঠুত সোণ বিচৰা; আশাত চেঁচা পানী ঢলা; আওবাটে যোৱা; আই ধৰ বাই ধৰ; আং বাং কথা; আপুতৰ পুত; উত্তম মধ্যম; উগাৰ মাৰা (also on the Wiktionary category); চকুত ধূলি মাৰা (en.wiktionary category). Reserve: the other 40 read on the same page. Idioms beginning with letters after উ were not read.

**Experiencer constructions, `experiencer-construction`: 9 verified.** ভাল লগা (page: "to like", takes -অৰ; variant ভাল লাগা, Central Standard; example মোৰ আইচ‌্ক্ৰিম বৰ ভাল লাগে); ভোক লগা; খং উঠা (page form খং উঠ); ভাল পোৱা; ভয় খোৱা; মন যোৱা; গম পোৱা; মই তোমাক ভাল পাওঁ; মই তোমাক বেয়া পাওঁ (the last two are on en.wiktionary "Category:Assamese phrases", which lists 18 pages; the pronoun-with-ক construction is for the builder to read on the entry). Shortfall: 11. The builder does not invent others; the queue asks the owner or a reviewer for the ক'ব/লাগে list.

## Recommendations (AS-060 and AS-061, 10 + 10)

File `decks/recommendations/as.yaml`, in the shape of `recommendations/es.yaml`: `id: "as-rec-<name>"`, `medium`, `title { text }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each answerable only by someone who watched, read or heard the work, `tags: ["unreviewed"]`. No quotation and no link. These are works the learner sources, so rights are not a gate. Years are as the named page states them; where a page gives two, both are shown.

| # | Medium | Work | Creator | Verified facts (page) |
|---|---|---|---|---|
| 1 | film | Xagoroloi Bohudoor (It's a Long Way to the Sea) | Jahnu Barua | en.wikipedia "Xagoroloi Bohudoor": 1995, Assamese; National Film Awards for Best Feature Film in Assamese and Best Direction; the Jahnu Barua page also writes the title Hkhagoroloi Bohu Door |
| 2 | film | Village Rockstars | Rima Das | en.wikipedia: 2017, Assamese; Best Feature Film at the 65th National Film Awards |
| 3 | film | Halodhia Choraye Baodhan Khai | Jahnu Barua | en.wikipedia "Jahnu Barua": 1987 (the film's own page was not found under the title tried) |
| 4 | film | Aparoopa | Jahnu Barua | en.wikipedia "Jahnu Barua": 1982 |
| 5 | film | Konikar Ramdhenu | Jahnu Barua | en.wikipedia "Jahnu Barua": 2003 |
| 6 | film | Baandhon | Jahnu Barua | en.wikipedia "Jahnu Barua": 2012 |
| 7 | film | Joymati | Jyoti Prasad Agarwala | en.wikipedia: 1935 |
| 8 | film | Indramalati | Jyoti Prasad Agarwala | en.wikipedia: 1939 |
| 9 | book | Datal Hatir Une Khowa Howda (The Moth Eaten Howdah of a Tusker) | Indira Goswami | en.wikipedia: 1988; Goswami 14 Nov 1942 to 29 Nov 2011; Jnanpith 2000 |
| 10 | book | Chinnamastar Manuhto (The Man from Chinnamasta) | Indira Goswami | en.wikipedia: 2005 |
| 11 | book | Neelkanthi Braja | Indira Goswami | en.wikipedia: 1976 |
| 12 | book | Tej Aru Dhulire Dhusarita Prishtha (Pages Stained With Blood) | Indira Goswami | en.wikipedia: 2001 |
| 13 | book | Iyaruingam | Birendra Kumar Bhattacharya | en.wikipedia: 1960; Sahitya Akademi Award (the page gives 1960 and 1961); 14 Oct 1924 to 6 Aug 1997 |
| 14 | book | Mrityunjay | Birendra Kumar Bhattacharya | en.wikipedia: 1979, the Jnanpith-winning novel; he was the first Assamese Jnanpith winner |
| 15 | book | Burhi Aair Sadhu | Lakshminath Bezbaroa | en.wikipedia: first published 1911 (October to November) |
| 16 | poems | Miri Jiyori | Rajanikanta Bordoloi | en.wikipedia: 1894 |
| 17 | album | Anamika | Zubeen Garg | en.wikipedia: 1992, his debut solo album; 18 Nov 1972 to 19 Sep 2025 |
| 18 | song | Mayabini Raatir Bukut | Zubeen Garg | en.wikipedia: no release year given; performed at his funeral |
| 19 | song | Oxom Dexor Bagisare | Bhupen Hazarika | en.wikipedia: 1975 (from the film Chameli Memsaab); 8 Sep 1926 to 5 Nov 2011 |
| 20 | song | Bistirno Parore | Bhupen Hazarika | en.wikipedia: among his famous Assamese songs; tune and theme based on Paul Robeson's "Ol' Man River"; no year given |

Reserve: Xagor Xoṅgomot (Hazarika; en.wikipedia: appears in the 1956 film Era Bator Sur), Manuhe Manuhor Babe (Hazarika), Meghor Boron (Garg, 1997, first Assamese music video from Mukti), Xopunor Xur (1992), Junaki Mon (1993), Maya (1994), Asha (1995), Tumi Mor Matho Mor (2000 film, Garg's acting and directing debut), Mission China (2017), Kanchanjangha (2019). The director of rows 3 to 6 is to be read on each film's own page; the Barua page lists them as his films. Rows 17 to 20 have no year or only a page's passing mention: row 18 and row 20 have no year and the builder reads one before writing the card or drops them.

## Counts

| Kind | Target | Verified rows | Reserve | Note |
|---|---|---|---|---|
| Culture 1 | 18 | 18 | 8 | three rows era only |
| Culture 2 | 18 | 18 | 15 | two rows with two page dates |
| Culture 3 | 18 | 10 | 0 | short, not padded |
| Culture 4 | 18 | 18 | 0 | facts and places |
| Proverbs 1, 2, 3 | 60 | 60 | about 50 | all texts read on as.wikiquote |
| Multiword conjunct kora | 20 | 28 | 8 | |
| Multiword conjunct other | 20 | 22 | 2 | |
| Multiword compound | 20 | 8 | 0 | short by 12 |
| Multiword idiom | 20 | 20 | 40 | experiencer 9 more, short by 11 |
| Recommendations | 20 | 20 | 10 | two without a year |

## Unverified, not to be built

These were asked for or expected and were **not** read on any fetched page, so they are not candidates until a builder reads them:

1. **Charit puthi** (Sankardev's biographies, Daityari Thakur, Bhusan Dwija and others) and Sankardev's disciples Bhattadev and Rama Saraswati: no page was read.
2. **Bihu songs (বিহুনাম) as texts.** The as.wikiquote page বিহুনাম was read, but its song lines were not taken (the page's sections are historical figures, hanchoti, rivers, birds, fish, looms, instruments, dhenki and miscellaneous; its sources include Dimbeshwar Neog's *Janakavya*, Rajanikanta Bordoloi's *Miri-Jiyori*, and a Wikisource *Bihugeet* PDF). First publication before 1900 is not established for any line.
3. **Lullabies, lokgeet, Bhaona and Ojapali texts**, **Jnanadabhiram Borooah's *Folk-Tales of Assam*** (1916) and **Mira Pakrasi** (1969), **Praphulladatta Goswami** (1980): named on en.wikipedia "Assamese literature" only as titles; the authors' death years were not read and the 1969 and 1980 books fail the floor unless the author died by 1955.
4. **Orunodoi founders** (Nathan Brown, A. H. Denforth, William Ward, Oliver Thomas Cutter): death years not read.
5. **Hemchandra Goswami, Ambikagiri Raichoudhury, Bishnu Prasad Rabha, Atul Chandra Hazarika, Sarat Chandra Goswami, Raghunath Choudhary, Bhattadev, Dwarkanath Bhattacharya:** no page read; do not use without a read. Ambikagiri Raichoudhury and Bishnu Prasad Rabha are expected to fail the floor by death year; this is not verified here.
6. **Sahitya Akademi, government and museum pages** were not fetched (no page fetched under those hosts); no claim here rests on them.
7. **Gurdon's *Some Assamese Proverbs*.** archive.org could not be reached from the session (the host did not resolve); the book itself was not read, only the web search result (dates 1896 or 1903, districts Sibsagar, Nowgong and Gauhati). The edition and date for the `source` block are to be read.
8. **Compound verbs beyond the 8 above, the ক'ব and লাগে experiencer list beyond the 9, and idioms from the letters after উ** in জতুৱা ঠাঁচ.
9. **Film pages:** the en.wikipedia page "Halodhia Choraye Baodhan Khaye" did not exist under that title; the film facts come from "Jahnu Barua" only.

## Review-queue rule

Everything is `unreviewed`. Every row that carries a page conflict (Hemchandra Barua's and Gunabhiram Barua's and Chandra Kumar Agarwala's birth dates, Bezbaroa's birth year and Kodomkoli's date, Rajanikanta Bordoloi's lifespan, Orunodoi's end year, Iyaruingam's award year), every era-only row (Hema Saraswati, Madhava Kandali), the posthumous Hemkosh and every proverb from the sensitive list is a row in the builder's report; AS-120 to AS-122 collect them into `docs/review-queue/as.md`.

## Open questions for the owner

1. **Professional decks** are not planned (the owner supplies the list first).
2. **Copyright term.** The floor (1955 or earlier) is the plan's rule; a reviewer confirms the legal term before the decks ship. Hemchandra Barua's *Hemkosh* (1900) and Bezbaroa's works (1938) meet it.
3. **Shortfalls.** Culture 3 (10 of 18), compound verbs (8 of 20) and experiencer constructions (9 of 20) are below target. The options are to ship the decks short (the plan's default, "fewer rather than padded"), or to ask the owner for an Assamese source list. No other action is taken without the owner.

## Second sourcing pass (2026-11-17)

Task AS-CULT-SRC2 for the Assamese stream. Goal: 42 more culture cards (as-culture-1 needs 11, as-culture-2 needs 10, as-culture-3 needs 8, as-culture-4 needs 13). Every excerpt below was extracted by a script from the **raw wikitext** of the named as.wikisource page fetched on 2026-11-17 (`index.php?action=raw`, namespace "পৃষ্ঠা" Page pages, and the tale pages for deck 3), with the page text stripped of `<noinclude>` headers; the script checked that the excerpt is a substring of the raw page and counted at most 25 words. No excerpt, date or lifespan was written from memory.

### The two-source date standard as applied here

A search of the wiki (and the repository docs) for "two-source", "two sources" and "date standard" found no page that states the owner's standard under that name; the nearest rules are the rights floor and the line in "Culture 1" of this plan ("such rows need a second source for dates before the creator record is written") and the conflict rule in "Rules applied". This pass therefore applies the strict reading: (1) **every creator's lifespan has two independent pages**, en.wikipedia and Wikidata (its own `P569`/`P570` statements with references), read in this run, and the **death year must agree** (it decides the 1955 floor); a birth-year conflict is flagged and stored as `circa`; (2) a **work date** comes from the page header or the cited edition, a second source (en.wikipedia works list) is given where one was read, and where only one source was read the row says "1 work-date source": such a row may still be built, with `source.date` written as the creator's life range or the edition year exactly as the existing cards do. Britannica (britannica.com) answered 403 (Cloudflare challenge) and was not used. If the owner's standard asks for a second source on every work date, the rows marked "1 work-date source" are the ones that fall under it.

### Creators for the new cards (two sources each)

| Key | Exact English name (`name.en.text` = `source.author`) | Life | Sources read (year level) | `author_died` |
|---|---|---|---|---|
| sankardev | Srimanta Sankardev | 1449 to 1568 | en.wikipedia "Sankardev": 1449 to 1568; Wikidata Q3116915: born 1449, died 1568 (a second died statement says 1569) | 1568 |
| durgabar | Durgabar Kayastha | 1515 to 1560 | en.wikipedia "Durgabar Kayastha": 1515 to 1560; Wikidata Q5316404: 1515 to 1560 | 1560 |
| bhattadeva | Bhattadeva | 1558 to 1638 | en.wikipedia "Bhattadeva": 23 Mar 1558 to 3 Jan 1638; Wikidata Q4901433: 1558 to 1638 | 1638 |
| phukan | Anandaram Dhekial Phukan | 1819 or 1829 to 1859 (birth conflict) | en.wikipedia: lead 1829 to 1859, but its death template counts from 1819; Wikidata Q4751350: 24 Aug 1819 to 16 Jun 1859; death year agrees, birth year conflicts, so `born` is `{ year: 1829, circa: true }` or the builder picks per review | 1859 |
| bordoloi | Rajanikanta Bordoloi | 1867 to 1940 | en.wikipedia: 24 Nov 1867 to 25 Mar 1940; Wikidata Q12015668: 24 Nov 1867 to 25 Mar 1940 | 1940 |
| padmanath | Padmanath Gohain Baruah | 1871 to 1946 | en.wikipedia: 24 Nov 1871 to 21 Apr 1946; Wikidata Q7123860: 24 Oct 1871 to 7 Apr 1946 (years agree, days differ) | 1946 |
| bezbaroa | Lakshminath Bezbaroa | 1864 or 1868 to 1938 (birth conflict) | en.wikipedia: lead 14 Oct 1864 to 26 Mar 1938, infobox birth 1868; Wikidata Q5756306: born 1868 (3 refs) and 1864-10-14 (no ref), died 1938 (two statements); death year agrees, birth conflicts, so `born` stays `{ year: 1864, circa: true }` as in creators-as | 1938 |
| gunabhiram | Gunabhiram Barua | 1834 or 1837 to 1894 (birth conflict) | en.wikipedia: 1834 to 1894; Wikidata Q5618471: 1837 to 1894; death year agrees, birth conflicts, so `born` stays `{ year: 1834, circa: true }` as in creators-as | 1894 |

New creator records are needed for **Durgabar Kayastha** and **Bhattadeva** (deck 1); the others already exist in `decks/creators/as.yaml`. Rights basis for every row: `public-domain`, jurisdiction `IN`; every creator died in 1938 or earlier (Bhattadeva 1638, Durgabar 1560, Sankardev 1568), so the 1955 floor holds on both sources.

### Deck 1: medieval and Vaishnava

Needed 11. Rows 1 to 11 are the build list; the rest are reserves. `Ex.` says how the excerpt matches the raw page.

| # | Title (Assamese, English; reading by `tools/transcribe.py` at build) | Creator and life | Work date and sources | Excerpt (exact) | Page (URL) and match | English meaning | Rights |
|---|---|---|---|---|---|---|---|
| 1 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | নাম বিনে নাহি কলিত গতি। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩০ ; exact substring of the raw page text (one line) | Without the Name there is no way in the Kali age. | public-domain; author_died 1568 |
| 2 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | অন্যত্ৰ ধৰ্ম্মে নাহি অধিকাৰ। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩০ ; exact substring of the raw page text (one line) | In other practices there is no claim to it. | public-domain; author_died 1568 |
| 3 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | জানিবা কলিত নামেসে সাৰ॥ | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩০ ; exact substring of the raw page text (one line) | Know that in the Kali age the Name alone is the essence. | public-domain; author_died 1568 |
| 4 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | কৃষ্ণৰ কিঙ্কৰে কহে শঙ্কৰে। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩১ ; exact substring of the raw page text (one line) | Sankar, the servant of Krishna, says. | public-domain; author_died 1568 |
| 5 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | আজি কালি কিবা মিলে মৰণ। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩১ ; exact substring of the raw page text (one line) | Death may come today or tomorrow. | public-domain; author_died 1568 |
| 6 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | হৰিৰ নামত লৈয়ো শৰণ॥ | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩১ ; exact substring of the raw page text (one line) | Take refuge in the Name of Hari. | public-domain; author_died 1568 |
| 7 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | নকৰিবা নিন্দা মোক মহন্তে। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩১ ; exact substring of the raw page text (one line) | Elders, do not blame me. | public-domain; author_died 1568 |
| 8 | Kirtan Ghosha (index name on Wikisource; Assamese title not read on the page) | Kirtan Ghosha | Srimanta Sankardev (1449 to 1568) | not given on the page; builder writes the poet's life 1449-1568 as the existing cards do; as.wikisource index "Kirtan Ghosha.pdf" gives no year; creator dates as above | তাৰ সাত কাৰ্য্য সাধিবে দেখা। | https://as.wikisource.org/wiki/পৃষ্ঠা:Kirtan_Ghosha.pdf/৩০ ; exact substring of the raw page text (one line) | Look: it will accomplish seven works for him. | public-domain; author_died 1568 |
| 9 | অজামিল উপাখ্যান | Ajamil Upakhyana, the tale of Ajamil | Srimanta Sankardev (1449 to 1568) | not given (header year blank); poet's life 1449-1568; as.wikisource page header (year field blank); creator dates as above | অজামিল উপাখ্যান কৰিবো বেকত॥ | https://as.wikisource.org/wiki/পৃষ্ঠা:অজামিল_উপাখ্যান.pdf/৬ ; exact substring of the raw page text (one line) | I will tell the story of Ajamil openly. | public-domain; author_died 1568 |
| 10 | অজামিল উপাখ্যান | Ajamil Upakhyana, the tale of Ajamil | Srimanta Sankardev (1449 to 1568) | not given (header year blank); poet's life 1449-1568; as.wikisource page header (year field blank); creator dates as above | ধৰ্ম্মসে কৰোক পাপ নকৰোক প্ৰাণী। | https://as.wikisource.org/wiki/পৃষ্ঠা:অজামিল_উপাখ্যান.pdf/৬ ; exact substring of the raw page text (one line) | Let beings do right and not do wrong. | public-domain; author_died 1568 |
| 11 | অজামিল উপাখ্যান | Ajamil Upakhyana, the tale of Ajamil | Srimanta Sankardev (1449 to 1568) | not given (header year blank); poet's life 1449-1568; as.wikisource page header (year field blank); creator dates as above | গুৰি কটা গছ যেন পৰি থাকে আতি। | https://as.wikisource.org/wiki/পৃষ্ঠা:অজামিল_উপাখ্যান.pdf/৭ ; exact substring of the raw page text (one line) | He lies fallen like a tree cut at the root. | public-domain; author_died 1568 |
| 12 (reserve) | অজামিল উপাখ্যান | Ajamil Upakhyana, the tale of Ajamil | Srimanta Sankardev (1449 to 1568) | not given (header year blank); poet's life 1449-1568; as.wikisource page header (year field blank); creator dates as above | কাক সম সিটো সৰ্ক ভক্ষ অনাচাৰ। | https://as.wikisource.org/wiki/পৃষ্ঠা:অজামিল_উপাখ্যান.pdf/৯ ; exact substring of the raw page text (one line) | Like a crow, he eats anything and lives badly. | public-domain; author_died 1568 |
| 13 (reserve) | দুৰ্গাবৰি গীতি ৰামায়ণ | Durgabari Giti Ramayana | Durgabar Kayastha (1515 to 1560) | edition 1915 on the page; the poem is of the 16th century; as.wikisource header year ১৯১৫ (1915); en.wikipedia "Durgabar Kayastha" places the poet in 1515-1560 | মনসুখে কৰা প্ৰভু মনোহৰ কেলি। | https://as.wikisource.org/wiki/পৃষ্ঠা:দুৰ্গাবৰি_গীতি_ৰামায়ণ.pdf/২৪ ; exact substring of the raw page text (one line) | Lord, enjoy lovely play as your heart wishes. | public-domain; author_died 1560 |
| 14 (reserve) | দুৰ্গাবৰি গীতি ৰামায়ণ | Durgabari Giti Ramayana | Durgabar Kayastha (1515 to 1560) | edition 1915 on the page; the poem is of the 16th century; as.wikisource header year ১৯১৫ (1915); en.wikipedia "Durgabar Kayastha" places the poet in 1515-1560 | সুৰভি সিতল বহে মলয়া পৱন। | https://as.wikisource.org/wiki/পৃষ্ঠা:দুৰ্গাবৰি_গীতি_ৰামায়ণ.pdf/২৪ ; exact substring of the raw page text (one line) | A fragrant, cool Malaya breeze blows. | public-domain; author_died 1560 |
| 15 (reserve) | সৎসম্প্ৰদায় কথা | Satsampradaya Katha | Bhattadeva (1558 to 1638) | not given (header year blank); poet's life 1558-1638; as.wikisource page header (year blank); creator dates as above | ইহাৰ ভেদ কহোঁ শুনা। | https://as.wikisource.org/wiki/পৃষ্ঠা:সৎসম্প্ৰদায়_কথা.djvu/৯ ; exact substring of the raw page text (one line) | Listen, I will tell the difference between these. | public-domain; author_died 1638 |

### Deck 2: modern prose and verse to 1955

Needed 10. Rows 1 to 10 are the build list; the rest are reserves. `Ex.` says how the excerpt matches the raw page.

| # | Title (Assamese, English; reading by `tools/transcribe.py` at build) | Creator and life | Work date and sources | Excerpt (exact) | Page (URL) and match | English meaning | Rights |
|---|---|---|---|---|---|---|---|
| 1 | অসমিয়া লৰাৰ মিত্ৰ | Asomiya Lorar Mitra (Friend of the Assamese child), volume 2 | Anandaram Dhekial Phukan (1819 or 1829 to 1859 (birth conflict)) | 1849; en.wikipedia "Anandaram Dhekial Phukan" (as in the first plan); the volume-2 header year of as.wikisource was not read **1 work-date source** | শ্ৰম কৰিলে নিশ্চয়কৈ বিদ্যা হয়, আৰু এই কথাৰ কেতিয়াও অন্যথা নহয়। | https://as.wikisource.org/wiki/পৃষ্ঠা:অসমিয়া_লৰাৰ_মিত্ৰ-২.djvu/১৬ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | If you work hard, you will surely gain learning. | public-domain; author_died 1859 |
| 2 | অসমিয়া লৰাৰ মিত্ৰ | Asomiya Lorar Mitra (Friend of the Assamese child), volume 2 | Anandaram Dhekial Phukan (1819 or 1829 to 1859 (birth conflict)) | 1849; en.wikipedia "Anandaram Dhekial Phukan" (as in the first plan); the volume-2 header year of as.wikisource was not read **1 work-date source** | সকল গুণত কৈ ও বঢ়া গুণ আচে। | https://as.wikisource.org/wiki/পৃষ্ঠা:অসমিয়া_লৰাৰ_মিত্ৰ-২.djvu/১৪ ; exact substring of the raw page text (one line) | There is a quality better than all other qualities. | public-domain; author_died 1859 |
| 3 | অসমিয়া লৰাৰ মিত্ৰ | Asomiya Lorar Mitra (Friend of the Assamese child), volume 2 | Anandaram Dhekial Phukan (1819 or 1829 to 1859 (birth conflict)) | 1849; en.wikipedia "Anandaram Dhekial Phukan" (as in the first plan); the volume-2 header year of as.wikisource was not read **1 work-date source** | কেনেকৈ পৰ কালত সুখী কৰিব তেন্তে ভাঙ্গি কঁও শুনা। | https://as.wikisource.org/wiki/পৃষ্ঠা:অসমিয়া_লৰাৰ_মিত্ৰ-২.djvu/১৫ ; exact substring of the raw page text (one line) | How it will make one happy in the life to come. | public-domain; author_died 1859 |
| 4 | ৰঙ্গিলী | Rangilee | Rajanikanta Bordoloi (1867 to 1940) | 1925; as.wikisource header year ১৯২৫ and en.wikipedia "Rajanikanta Bordoloi" works list "Rangilee (1925)": two sources agree | জুই জ্বলি উঠিলেই যেয়ে পাৰে সেয়ে এই মন্ত্ৰটো মাতি জুইলৈ ঘিউ ছটিয়াই দিয়ে। | https://as.wikisource.org/wiki/পৃষ্ঠা:ৰঙ্গিলী-ৰজনীকান্ত_বৰদলৈ.pdf/২০ ; exact substring of the raw page text (one line) | As soon as the fire blazes, whoever can says the mantra and pours ghee on it. | public-domain; author_died 1940 |
| 5 | ৰঙ্গিলী | Rangilee | Rajanikanta Bordoloi (1867 to 1940) | 1925; as.wikisource header year ১৯২৫ and en.wikipedia "Rajanikanta Bordoloi" works list "Rangilee (1925)": two sources agree | তাৰ পিছতহে সকলোৱে চিৰা পিঠা সান্দহ ইত্যাদিৰে জা-জলপান খায়। | https://as.wikisource.org/wiki/পৃষ্ঠা:ৰঙ্গিলী-ৰজনীকান্ত_বৰদলৈ.pdf/২০ ; exact substring of the raw page text (one line) | Only then does everyone eat chira, pitha and sandoh as a light meal. | public-domain; author_died 1940 |
| 6 | লাহৰী | Lahori | Padmanath Gohain Baruah (1871 to 1946) | 1892 first publication; edition 1933 on the page; en.wikipedia "Padmanath Gohain Baruah" ("Lahori (1892)") and as.wikisource header year ১৯৩৩ (edition): they differ because one is the first edition **date conflict, explain as in as-culture-3** | আমি পামপুৰ এৰি গৈ ৰংপুৰ নগৰত থকা আঠ মাহত সোমালহি। | https://as.wikisource.org/wiki/পৃষ্ঠা:লাহৰী.pdf/২০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | We left Pampur and went into the eighth month in Rangpur town. | public-domain; author_died 1946 |
| 7 | নিৰ্ম্মল ভকত | Nirmal Bhakat | Rajanikanta Bordoloi (1867 to 1940) | 1927 or 1910; en.wikipedia "Rajanikanta Bordoloi" works list 1927; as.wikisource header year ১৯১০ **date conflict: use only if the builder writes the poet's life range** | উপদ্ৰৱত হেনো অসম শ্মশানত পৰিণত হৈছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:নিৰ্ম্মল_ভকত.pdf/২০ ; exact substring of the raw page text (one line) | They say Assam had turned into a cremation ground through the troubles. | public-domain; author_died 1940 |
| 8 | নিৰ্ম্মল ভকত | Nirmal Bhakat | Rajanikanta Bordoloi (1867 to 1940) | 1927 or 1910; en.wikipedia "Rajanikanta Bordoloi" works list 1927; as.wikisource header year ১৯১০ **date conflict: use only if the builder writes the poet's life range** | আনকি তিনি চাৰিখন গাঁওও হৈছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:নিৰ্ম্মল_ভকত.pdf/২০ ; exact substring of the raw page text (one line) | There were even three or four villages. | public-domain; author_died 1940 |
| 9 | লীলা | Lila | Padmanath Gohain Baruah (1871 to 1946) | 1936; as.wikisource header year ১৯৩৬ only **1 work-date source** | শিয়ঁৰি উঠিল প্ৰাণ, —কিজানো কি ভাৱে— নীৰৱে বিনালে হাঁয়, নিফুঁট সুৰত। | https://as.wikisource.org/wiki/পৃষ্ঠা:লীলা.pdf/২০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | The heart shivered and sighed quietly in a faint tune. | public-domain; author_died 1946 |
| 10 | জোন-বিৰি | Jon-Biri | Lakshminath Bezbaroa (1864 or 1868 to 1938 (birth conflict)) | 1949 (edition on the page); as.wikisource header year ১৯৪৯ only **1 work-date source** | হাতত এটা বস্তু দি, কাণে কাণে অলপমান বেলি ফুচ্‌ফুচাই কিবা বুধি দি, গুচি গল। | https://as.wikisource.org/wiki/পৃষ্ঠা:জোন-বিৰি.pdf/১৫ ; exact substring of the raw page text (one line) | Giving something into the hand, whispering a little advice in the ear, he went away. | public-domain; author_died 1938 |
| 11 (reserve) | গদাধৰ | Gadadhar (play) | Padmanath Gohain Baruah (1871 to 1946) | 1932; as.wikisource header year ১৯৩২; en.wikipedia "Padmanath Gohain Baruah" names the play but gives no year **1 work-date source** | গৰখীয়া-মেল মাৰি, গৰু ৰাখি খাওঁ। | https://as.wikisource.org/wiki/পৃষ্ঠা:গদাধৰ.pdf/৪০ ; exact substring of the raw page text (one line) | Joining the herd-boys, I tend cows and eat. | public-domain; author_died 1946 |

### Deck 4: history and places

Needed 13. Rows 1 to 13 are the build list; the rest are reserves. `Ex.` says how the excerpt matches the raw page.

| # | Title (Assamese, English; reading by `tools/transcribe.py` at build) | Creator and life | Work date and sources | Excerpt (exact) | Page (URL) and match | English meaning | Rights |
|---|---|---|---|---|---|---|---|
| 1 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | নীলাম্বৰ ৰজাৰ ঘাই মন্ত্ৰী শচীপত্ৰৰ এজন পুতেক আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/২০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | King Nilambar's chief minister Sachipatra had a son. | public-domain; author_died 1946 |
| 2 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | তাৰ পাচত, ১৪৯৮ খ্ৰীষ্টাব্দত ভালেমান মছলমান ৰণুৱাৰে সৈতে শচীপাত্ৰই নীলাম্বৰৰ ৰাজধানী কমতাপুৰ আক্ৰমণ কৰিলেহি। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/২০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | Then in 1498 Sachipatra, with many Muslim soldiers, attacked Nilambar's capital Kamatapur. | public-domain; author_died 1946 |
| 3 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | ৰণত মূলা গাভৰু আৰু তুৰ্ব্বক দুয়ো পৰিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৩০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | In the battle both Mula Gabharu and Turbak fell. | public-domain; author_died 1946 |
| 4 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | সেই ৰণত মুছলমানৰ ভালেমান বন্দুক আহোমৰ হাতত ৰৈ যায়। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৩০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | In that battle many of the Muslims' guns stayed in Ahom hands. | public-domain; author_died 1946 |
| 5 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | তেওঁৰ দিনতে হিয়ণচাং নামে চীন দেশৰ প্ৰখ্যাত পৰিব্ৰাজক এজন এই দেশলৈ আহিছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/১৪ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | In his time the famous Chinese traveller Hiuen Tsang came to this country. | public-domain; author_died 1946 |
| 6 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | এই দেশলৈ বামুণ অহাৰ সেয়ে সূত্ৰপাত। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/১৪ ; exact substring of the raw page text (one line) | That was the beginning of Brahmins coming to this country. | public-domain; author_died 1946 |
| 7 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | ইবিলাকৰ ভিতৰত চুচেংফা স্বৰ্গদেৱ প্ৰখ্যাত আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৩৫ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | Among these, King Susenghphaa Swargadeo was famous. | public-domain; author_died 1946 |
| 8 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | একেবিধ অসমীয়া ৰণুৱাই মাটিয়ে, পানীয়ে আৰু ঘোঁৰাত উঠি ৰণ দিব পাৰে। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৪০ ; exact substring of the raw page text (one line) | The same Assamese soldier can fight on land, in water and on horseback. | public-domain; author_died 1946 |
| 9 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | তাৰ পাচত, ঘুৰি ঘুৰি ওচৰ চাপোঁতে জয়মতীয়ে কোৱঁৰক চিনি পালে। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৫০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | Then, as he came near again and again, Joymati recognised the prince. | public-domain; author_died 1946 |
| 10 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | গুৱাহাটীৰ নীলাচল পৰ্ব্বতত তেওঁৰ সত্ৰ আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৫৫ ; exact substring of the raw page text (one line) | His satra was on Nilachal hill in Guwahati. | public-domain; author_died 1946 |
| 11 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | তেওঁ ৰজা ভাগিলত তেওঁৰ ভাৰ্য্যা ফুলেশ্বৰী কুৱঁৰী মহাৰাণী হয়। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৫৫ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | When he stepped down as king, his wife Phuleswari Kunwari became the queen. | public-domain; author_died 1946 |
| 12 | বুৰঞ্জীবোধ | Buranji Bodh | Padmanath Gohain Baruah (1871 to 1946) | 1929; as.wikisource header year ১৯২৯ only **1 work-date source** | ৰজাই গোসাঁনী পূজা কৰে, গতিকে প্ৰজায়ে গোসাঁনী মানিব লাগে। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুৰঞ্জীবোধ.djvu/৬০ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | The king worships the goddess, so the people must honour the goddess. | public-domain; author_died 1946 |
| 13 | আসাম বুৰঞ্জী | Assam Buranji | Gunabhiram Barua (1834 or 1837 to 1894 (birth conflict)) | 1887 first publication; en.wikipedia "Gunabhiram Barua" (first plan); as.wikisource header year blank **1 work-date source** | ইয়াতে নৰক ৰজাৰ পুত্ৰ ভগদত্তৰ ৰাজধানী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:আসাম_বুৰঞ্জী.pdf/৯ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | Here was the capital of Bhagadatta, son of King Naraka. | public-domain; author_died 1894 |
| 14 (reserve) | আসাম বুৰঞ্জী | Assam Buranji | Gunabhiram Barua (1834 or 1837 to 1894 (birth conflict)) | 1887 first publication; en.wikipedia "Gunabhiram Barua" (first plan); as.wikisource header year blank **1 work-date source** | এইটি সেই নৰক আৰু ভগদত্ত ৰজাৰ থকা স্থান বুলি জনঘোষ আছে। | https://as.wikisource.org/wiki/পৃষ্ঠা:আসাম_বুৰঞ্জী.pdf/৯ ; exact substring after joining the page's line breaks with one space (the sentence runs over two raw lines) | There is a local tradition that this is the place of King Naraka and Bhagadatta. | public-domain; author_died 1894 |
| 15 (reserve) | আসাম বুৰঞ্জী | Assam Buranji | Gunabhiram Barua (1834 or 1837 to 1894 (birth conflict)) | 1887 first publication; en.wikipedia "Gunabhiram Barua" (first plan); as.wikisource header year blank **1 work-date source** | বাৰিষাৰ পূৰ্ব্বে কোনো কোনো দিন বিয়লি আৰু গধূলি বড় ধুমূহা হয়। | https://as.wikisource.org/wiki/পৃষ্ঠা:আসাম_বুৰঞ্জী.pdf/৭ ; exact substring of the raw page text (one line) | Before the rains, on some days there are big squalls in the afternoon and evening. | public-domain; author_died 1894 |
| 16 (reserve) | দন্দুৱা দ্ৰোহ | Dandua Droh | Rajanikanta Bordoloi (1867 to 1940) | 1928; as.wikisource header year ১৯২৮ only **1 work-date source** | ৰজাঘৰীয়া কৰ অতি সামান্য আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:দন্দুৱা_দ্ৰোহ.pdf/২১ ; exact substring of the raw page text (one line) | The royal tax was very small. | public-domain; author_died 1940 |

### Deck 3: folk and oral traditions before 1900 (tales of Burhi Aair Sadhu)

Needed 8. Rows 1 to 8 are the build list; the rest are reserves. All are the opening sentence of a tale not yet used in `as-culture-3` (the ten used are Bandor aru Xial, Bagh aru Kekura, Tejimola, Burha-Buri aru Xial, Gangatup, Kukurikona, Tula aru Teja, Ou Kuwori, Champavati, Juwair Xadhu). Creator: Lakshminath Bezbaroa (1864 or 1868 to 1938, two sources above), who wrote down and compiled traditional tales; work date: as.wikisource header year ১৯১২ (1912, the edition) against en.wikipedia "Burhi Aair Sadhu" 1911 (first publication): **the two sources differ by one year**, so the builder writes `date: "1912"` with the note the existing cards carry, or `1911-1912`. Basis `public-domain` (author died 1938; the tale is traditional), jurisdiction `IN`. The excerpt of each is on the first Page page of the tale; every excerpt is an exact substring of the raw page text (one line).

| # | Title (Assamese, English; reading by tool) | Creator | Excerpt (exact) | Page (URL) | English meaning | Rights |
|---|---|---|---|---|---|---|
| 1 | এজনী মালিনী আৰু এজোপা ফুল | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এক মালিনী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/২৮ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/এজনী_মালিনী_আৰু_এজোপা_ফুল) | There was a woman gardener. | public-domain; author_died 1938 |
| 2 | এটা শিঙৰা মাছৰ কথা | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এদিন এটা দুখীয়া মানুহে জকাই বাবলৈ গৈ দিনৰ দিনটো জকাই বালে, কিন্তু এটা শিঙৰা মাছৰ বাহিৰে সি একো নাপালে। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/৭৪ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/এটা_শিঙৰা_মাছৰ_কথা) | One day a poor man fished all day but caught only one singhi fish. | public-domain; author_died 1938 |
| 3 | কাঞ্চনী | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এক বুঢ়াৰ সাতোটা পুতেক আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৬৮ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/কাঞ্চনী) | An old man had seven sons. | public-domain; author_died 1938 |
| 4 | চিলনীৰ জীয়েকৰ সাধু | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এখন দেশত এটা কুমাৰ আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/৭৯ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/চিলনীৰ_জীয়েকৰ_সাধু) | In a country there was a potter. | public-domain; author_died 1938 |
| 5 | ঢোঁৰাকাউৰী আৰু টিপচীচৰাই | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এক বোলে ঢোঁৰাকাউৰী আৰু এটা টিপচীচৰাই আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/২২ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/ঢোঁৰাকাউৰী_আৰু_টিপচীচৰাই) | There was a crow and a tipchi bird. | public-domain; author_died 1938 |
| 6 | তাৱৈয়েকৰ সাধু | Lakshminath Bezbaroa (1864 or 1868 to 1938) | দুজন বৰ মৰমৰ সখি আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৫০ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/তাৱৈয়েকৰ_সাধু) | There were two very dear women friends. | public-domain; author_died 1938 |
| 7 | দীঘল ঠেঙীয়া | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এজনী বুঢ়ী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/৫৮ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/দীঘল_ঠেঙীয়া) | There was an old woman. | public-domain; author_died 1938 |
| 8 | পানেশৈ | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এখন গাঁৱত এজনী বুঢ়ী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৩৩ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/পানেশৈ) | In a village there was an old woman. | public-domain; author_died 1938 |
| 9 (reserve) | ভেকুলীৰ সাধু | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এখন গাঁৱত এটা বুঢ়া আৰু এজনী বুঢ়ী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৪৭ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/ভেকুলীৰ_সাধু) | In a village there was an old man and an old woman. | public-domain; author_died 1938 |
| 10 (reserve) | লট্‌কন | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এখন দেশত লট্‌কন নামেৰে এটা বৰ দুখীয়া বামুণ আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৫৪ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/লট্‌কন) | In a country there was a very poor Brahmin named Lotkon. | public-domain; author_died 1938 |
| 11 (reserve) | লখিমী তিৰুতা | Lakshminath Bezbaroa (1864 or 1868 to 1938) | সত্যযুগত দুটি বুঢ়া-বুঢ়ী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১৫৯ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/লখিমী_তিৰুতা) | In the Satya age there was an old couple. | public-domain; author_died 1938 |
| 12 (reserve) | তীখৰ আৰু চুটিবাই | Lakshminath Bezbaroa (1864 or 1868 to 1938) | এক গাঁৱত এহাল মাউৰা ল’ৰা-ছোৱালী আছিল। | https://as.wikisource.org/wiki/পৃষ্ঠা:বুঢ়ী_আইৰ_সাধু.pdf/১১৩ (tale page https://as.wikisource.org/wiki/বুঢ়ী_আইৰ_সাধু/তীখৰ_আৰু_চুটিবাই) | In a village there was a pair of orphans, a boy and a girl. | public-domain; author_died 1938 |

The English meanings are plain literal glosses written by the sourcing worker from the Assamese line; they carry no claim beyond the line and are a review row for a bilingual reviewer.

Dropped from this deck: নুমলীয়া পো (its opening sentence এহাল বুঢ়া-বুঢ়ী আছিল। is already the text of an existing card).

### Count and what is still short

| Deck | Needed | Candidates with excerpt extracted | Reserves |
|---|---|---|---|
| 1 medieval and Vaishnava | 11 | 15 | 4 |
| 2 modern prose and verse | 10 | 11 | 1 (rows 7, 9, 10 and 11 carry a date flag) |
| 3 folk and oral | 8 | 12 | 4 |
| 4 history and places | 13 | 16 | 3 |
| Total | 42 | 54 | 12 |

Deck 2 is the thinnest: its three Asomiya Lorar Mitra rows and the two Rangilee rows are the safe ones; Nirmal Bhakat (1927 against 1910), Lahori (1892 against edition 1933), Lila, Jon-Biri and Gadadhar have a date flag or one source, so a builder who wants the two-source rule on work dates should take the Rangilee and Asomiya Lorar Mitra rows first and look for more lines on the same pages (the Rangilee and Lorar Mitra pages hold many more sentences).

### Not buildable, and why (this pass)

- **Hema Saraswati, Madhava Kandali, Harivara Vipra, Rama Saraswati**: en.wikipedia gives no birth or death year (empty infobox, era only); only one source with an era exists, so the two-source lifespan cannot be met. Not built.
- **Ananta Kandali** (en.wikipedia 1540 to 1580; Wikidata Q4751444 1540 to 1580): the dates meet the standard, but no as.wikisource text by him was searched for beyond the earlier drop note in Deck-Work-Queue-AS 5.5 (the Wikisource Mahiravana Vadha is anonymous 1908); not built.
- **Madhavdev**: dates two-sourced (en.wikipedia May 1489 to 1596; Wikidata Q3633983 1489 to 1596) but the Naam Ghosa scan pages tried have page quality 1 (raw OCR with stray characters); the usable Madhavdev lines are already in deck 1. Not added.
- **Jyoti Prasad Agarwala** (Karengar Ligiri, Sonit Kuwari) and **Chandra Kumar Agarwala** (Bin-Baragi): the Page pages tried in this run (Karengar Ligiri page 20, Sonit Kuwari page 20, Bin-Baragi page 15) gave no sentence ending in । or ॥ (stage text, or an empty page), and a second try on page 25 failed on my own title quoting and was not repeated, so no excerpt was extracted; a builder can try other page numbers. Their lifespans were not re-checked here (Jyoti Prasad Agarwala and Chandra Kumar Agarwala already have creator records).
- **Hiteshwar Barbaruah** (Kamatapur Dhvansa Kavya, 1912 edition): Wikidata and en.wikipedia lookups found no item for the author in this run (no lifespan from two sources); not built. **Dutiram Hazarika**, **Haliram Dhekial Phukan**, **Dinanath Bezbaroa**: en.wikipedia raw text came back empty under those titles in this run, so no two-source lifespan; not built. **Satyanath Borah** (en.wikipedia 1860 to 1925, infobox dates empty; no Wikidata read): single source; not built.
- **Jnanadabhiram Barua** (en.wikipedia 1880 to 1955, died 1955): meets the floor on one source only (Wikidata was not read for him); no text of his was searched for on as.wikisource in this run; not built.
- **Chandradhar Barua** (Bhagya Parikhya, header year 1939) and **Banamali Barman** (Deshabhakta Tarunram Phukan, 1940): death years were not read; not built. **Banikanta Kakati** (Wikidata Q3633986: 15 Nov 1894 to 15 Nov 1952) edited Puroni Asomiya Sahitya (an anthology): dates on one source; not built in this pass.
- **Surya Kumar Bhuyan** (Kowar Bidroh) and **Hemchandra Goswami**: their lifespans were not read in this run; not built.
- **Tripura Buranji** (Ratna Kandali Sarma, edition 1937): Page 12, the only one read in this run, held no usable sentence; authorship and date of the original are not two-sourced. **Orunodoi** and **Kamrupar Buranji** indexes exist on as.wikisource but no page was read; the founders' death years are still unread.
- **Gurdon, Some Assamese Proverbs**: Philip Gurdon's Wikidata item gives 1800 to 1874 (unreferenced), which is not the author of the 1896 book; the identity is unresolved, so not built; archive.org answered 200 on a search query but the book scan was not read.

### Hosts and limits met

- britannica.com: 403 (Cloudflare "Just a moment" page). Not retried or evaded.
- as.wikisource.org and en.wikipedia.org: `api.php` and `index.php?action=raw` answered HTTP 429 (too many requests) in bursts all through the run (the egress address is shared); every fetch was retried with a pause until it succeeded; `index.php?action=raw` was the dependable route. archive.org, Wikidata (`Special:EntityData`, `Special:ItemByTitle`) and as.wikipedia answered 200 on test calls.
- as.wikisource Page pages use Assamese digits in the page number (for example `/৩০`); a request with Latin digits returns "missing".

### Notes for the builders

- The excerpt is the text between the stanza numeral and the line end: where the raw line ends with a stanza number (for example `॥ ৩৭`) the excerpt stops at the `॥`; the number is not part of it.
- Verse excerpts are single lines; prose excerpts marked "after joining" cross a raw line break, as the existing cards do ("the two lines are joined into one").
- Readings and IPA come from `tools/transcribe.py` at build (never by hand); the English meanings above are glosses for the layer, to be checked by a reviewer.
- Check each build against the existing decks for duplicates: the script found one duplicate (deck 3, নুমলীয়া পো) and removed it; no other excerpt equals an existing card.
