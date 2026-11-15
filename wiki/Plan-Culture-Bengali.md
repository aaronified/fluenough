# Plan: Bengali genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task BN-001 of [Deck-Work-Queue-BN](Deck-Work-Queue-BN.md), written 2026-11-15 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Spanish](Plan-Culture-Spanish.md) and [Plan-Culture-Telugu](Plan-Culture-Telugu.md), for the tasks BN-017 to BN-020 (culture), BN-021 to BN-023 (proverbs), BN-024 to BN-027 (multi-word verbs), BN-028 and BN-029 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md). If this page and a task row of the plan differ, this page wins.

**Almost nothing on this page is a checked fact.** Every work below is a *candidate*. The only things checked are the **author lifespans marked "verified"**, each read on the author's en.wikipedia page (opening sentence only) on 2026-11-15, and a few page facts quoted where they change a candidate. Everything else, every text, every work's date, every first-publication date and every rights status, is **to be read** by the builder on a cited page (bn.wikisource first for texts, bn.wikipedia and en.wikipedia for dates). A candidate the builder cannot read is dropped and replaced from the reserve. Nothing is filled in from memory. Three Wikipedia titles were not found (Baru Chandidas, Bijay Gupta, Dasarathi Ray under the spellings tried): the builder tries other spellings on bn.wikipedia, or drops them.

## Rules applied

- **Rights floor.** An author's death year must be **1955 or earlier** (the validator's floor). India's term is life plus 60 years from the year after death (the plan's reading), so for `jurisdiction: "IN"` the floor is also the legal line; Bangladesh's is also life plus 60 as the builder reads it. The builder records `IN` or `BD` and writes any doubt to the review queue with "to be read". An anonymous or traditional work needs a first publication before 1900. The floor catches typos; the reviewer owns the legal opinion.
- **Ineligible authors (verified on en.wikipedia 2026-11-15).** Kazi Nazrul Islam died 1976, Tarashankar Bandyopadhyay died 1971, Manik Bandyopadhyay died 3 Dec 1956: none can be a culture candidate. They may appear in recommendations only, as works the learner sources themselves.
- **Basis `public-domain` only, no `quotation` items.** The `source` block: `author`, `work`, `date` (a year, `c. YEAR` or `A-B`), `edition`, `url` (the page read), `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **One excerpt per card**: one verse, one sentence or one line, at most 25 words, shown **as on the cited edition** in Bengali script. The 1936 Calcutta University spelling reform changed many older spellings: the text is not silently modernised, and the `edition` field says where the spelling was modernised.
- **18 items per deck, short first**, each A2 or B1. The first 18 that pass are the deck, the rest the reserve; fewer may pass: the report says so, the deck is never padded. Tagore is capped at 12 of the 18 in BN-019.
- **Dates are never guessed.** An uncertain year is `circa`. Every unread, uncertain or dropped item is a row in the builder's report and later in `docs/review-queue/bn.md`.
- **Translations** are the builder's own plain renderings.
- **Creators** (file `decks/creators/bn.yaml`, created by BN-017): short A2-level English bio, `born`/`died` (`circa` if uncertain; a living creator has `born` and no `died`), era, one `legacy` line with a checkable item and a source link, no image; `name: { bn: { text, ipa }, en: { text } }`.
- **Order of work.** BN-017 to BN-020 run one after another (they share `creators/bn.yaml`), then BN-028 and BN-029. Proverbs and multi-word decks are independent of that lane.
- **Bengali conventions.** Bengali script with `reading` and `ipa` from the tools (`tools/transcribe.py`), `phonetic` by the IPA task, never by hand; course standard is Kolkata (cholito).
- **Reading order.** For a text: bn.wikisource edition page, then bn.wikipedia, then en.wikipedia. For dates and lifespans: en.wikipedia or bn.wikipedia. Pace the requests: Wikimedia returns 429 under load, and a page the builder could not read is dropped, not recalled.

## Culture decks (BN-017 to BN-020, 4 x 18 plus reserves)

In the tables, "verified" means the lifespan was read on en.wikipedia on 2026-11-15 and only that; the work's own date, text and first publication stay to be read in every row.

### BN-017, `bn-culture-1`: early and medieval Bengali (ids bn-5700 to 5749)

| # | Candidate work | Creator | Author's death year and rights |
|---|---|---|---|
| 1 | Charyapada (Charyagiti) | anonymous, several siddhas | to be read (first publication before 1900?). en.wikipedia "Charyapada" read: a collection of mystical poems; dates not read here |
| 2 | Shrikrishnakirtana | Baru Chandidas | to be read. attribution and identity of Chandidas disputed on en.wikipedia ("possibly more than one"); no page for Baru Chandidas found |
| 3 | A Vaishnava pada ("Sai keba sunaila shyam naam") | Chandidas | verified: 1339–1399, "or possibly more than one" poet (en.wikipedia); Baru Chandidas has no en.wikipedia page found |
| 4 | A Vaishnava pada | Govindadas | verified: 1535–1613 (en.wikipedia, "Govindadasa") |
| 5 | Krittivasi Ramayan | Krittibas Ojha | verified: c. 1381 – c. 1461 (en.wikipedia) |
| 6 | Mahabharat | Kashiram Das | verified: born 16th century, death not given in the lead (en.wikipedia). a 16th-century poet by en.wikipedia; death year not given |
| 7 | Chandimangal | Mukundaram Chakrabarti | verified: 1547 – early 1600s (en.wikipedia) |
| 8 | Manasamangal | Bijay Gupta | verified: no en.wikipedia page found under the titles tried |
| 9 | Annadamangal | Bharatchandra Ray | verified: 1712–1760 (en.wikipedia) |
| 10 | Padmavati | Alaol | verified: 1607–1680 (en.wikipedia, "Syed Alaol") |
| 11 | Chaitanya Charitamrita | Krishnadas Kaviraj | verified: c. 1528 – c. 1615/1620 (en.wikipedia, "Krishnadasa Kaviraja") |
| 12 | Shyama sangeet ("Mon re krishikaj jano na") | Ramprasad Sen | verified: page found, lifespan not read (extract cut at "c.") |
| 13 | A Baul song ("Khanchar bhitor ochin pakhi") | Lalon Fakir | verified: 1774 – 17 Oct 1890 (en.wikipedia, "Lalon"). the song's attribution to be read |
| 14 | A folk song | Hason Raja | verified: 1854 – 6 Dec 1922 (en.wikipedia) |
| 15 | Khanar Bachan | anonymous, attributed to Khana | to be read (first publication before 1900?). en.wikipedia "Khana (poet)" read: a legendary figure said to have lived between the 8th and 12th centuries, "also known as Dak or Lilavati"; whether Khanar Bachan and Dakar Bachan are one or two collections is to be read |
| 16 | Dakar Bachan | anonymous, attributed to Dak | to be read (first publication before 1900?). see Khanar Bachan: the same en.wikipedia page treats Dak as another name of Khana; the builder reads which edition he cites and counts them once if they are the same |
| 17 | A ballad from Maymansingha Gitika (such as Mahua) | anonymous | to be read (first publication before 1900?). en.wikipedia "Maimansingha Gitika" exists (Mymensingh ballads); the collection's first publication date to be read |
| 18 | A nursery rhyme or lullaby ("Khoka ghumalo para juralo") | anonymous, traditional | to be read (first publication before 1900?) |

Reserve: Dasarathi Ray (Panchali), Nidhu Babu (tappa; lifespan verified: 1741 – 6 Apr 1839), a Bhatiyali song, Gopal Bhar anecdotes (oral). This task creates `decks/creators/bn.yaml` (`kind: "creators"`, `id: "creators-bn"`, `language: "bn"`) with eras (charyapada period, medieval, Bengal Renaissance, Tagore's age, the twentieth century), each with `from` and `to` read from the builder's sources, and the creators of the deck.

### BN-018, `bn-culture-2`: the nineteenth century (bn-5750 to 5799)

| # | Candidate work | Creator | Author's death year and rights |
|---|---|---|---|
| 1 | Barnaparichay | Ishwar Chandra Vidyasagar | verified: 1820 – 29 Jul 1891 (en.wikipedia) |
| 2 | Betal Panchavimshati | Ishwar Chandra Vidyasagar | verified: 1820 – 29 Jul 1891 (en.wikipedia) |
| 3 | Sitar Banabas | Ishwar Chandra Vidyasagar | verified: 1820 – 29 Jul 1891 (en.wikipedia) |
| 4 | Meghnad Badh Kavya | Michael Madhusudan Dutt | verified: 1824 – 29 Jun 1873 (en.wikipedia) |
| 5 | Kapotaksha Nad (sonnet) | Michael Madhusudan Dutt | verified: 1824 – 29 Jun 1873 (en.wikipedia) |
| 6 | Bangabhasha (sonnet) | Michael Madhusudan Dutt | verified: 1824 – 29 Jun 1873 (en.wikipedia) |
| 7 | Anandamath, including Vande Mataram | Bankim Chandra Chattopadhyay | verified: 1838 – 8 Apr 1894 (en.wikipedia) |
| 8 | Durgeshnandini | Bankim Chandra Chattopadhyay | verified: 1838 – 8 Apr 1894 (en.wikipedia) |
| 9 | Kapalkundala | Bankim Chandra Chattopadhyay | verified: 1838 – 8 Apr 1894 (en.wikipedia) |
| 10 | Kamalakanter Daptar | Bankim Chandra Chattopadhyay | verified: 1838 – 8 Apr 1894 (en.wikipedia) |
| 11 | Alaler Gharer Dulal | Peary Chand Mitra | verified: 1814 – 23 Nov 1883 (en.wikipedia) |
| 12 | Hutom Pyanchar Naksha | Kaliprasanna Singha | verified: 1840 – 24 Jul 1870 (en.wikipedia) |
| 13 | Nil Darpan | Dinabandhu Mitra | verified: 1829 – 1 Nov 1873 (en.wikipedia) |
| 14 | Bishad Sindhu | Mir Mosharraf Hossain | verified: 1847 – 19 Dec 1911 (en.wikipedia) |
| 15 | Palashir Yuddha | Nabinchandra Sen | verified: 1847 – 23 Jan 1909 (en.wikipedia) |
| 16 | Padmini Upakhyan | Rangalal Bandyopadhyay | verified: 1827 – 13 May 1887 (en.wikipedia) |
| 17 | Alo o Chhaya | Kamini Roy | verified: 1864 – 27 Sep 1933 (en.wikipedia) |
| 18 | Parivrajak | Swami Vivekananda | verified: 1863 – 4 Jul 1902 (en.wikipedia) |

Reserve: Kulin Kulasarbaswa (Ramnarayan Tarkaratna), Swarnalata (Tarakanath Gangopadhyay), a play by Girish Chandra Ghosh (lifespan verified: 1844 – 8 Feb 1912), Rameshchandra Dutt (verified: 1848 – 30 Nov 1909). Adds only creators and eras not yet in the file.

### BN-019, `bn-culture-3`: Tagore, his circle and children's classics (bn-5800 to 5849)

| # | Candidate work | Creator | Author's death year and rights |
|---|---|---|---|
| 1 | Amar Sonar Bangla | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 2 | Ekla Cholo Re | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 3 | Jana Gana Mana, the original Bengali words | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 4 | Chitto Jetha Bhayshunyo | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 5 | Sonar Tari | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 6 | Dui Bigha Jomi | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 7 | Birpurush | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 8 | Kabuliwala | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 9 | Postmaster | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 10 | Chhuti | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 11 | Shesher Kobita | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 12 | Gora | Rabindranath Tagore | verified: 1861 – 7 Aug 1941 (en.wikipedia) |
| 13 | Dhana Dhanya Pushpa Bhara | Dwijendralal Roy | verified: 1863 – 17 May 1913 (en.wikipedia, "Dwijendralal Ray") |
| 14 | Moder Gorob Moder Asha | Atulprasad Sen | verified: 1871 – 26 Aug 1934 (en.wikipedia, "Atul Prasad Sen") |
| 15 | Abol Tabol | Sukumar Ray | verified: 1887 – 10 Sep 1923 (en.wikipedia). first publication date to be read (posthumous?) |
| 16 | Hajabarala | Sukumar Ray | verified: 1887 – 10 Sep 1923 (en.wikipedia). first publication date to be read |
| 17 | Tuntunir Boi | Upendrakishore Ray Chowdhury | verified: 1863 – 20 Dec 1915 (en.wikipedia) |
| 18 | Kheerer Putul | Abanindranath Tagore | verified: 1871 – 5 Dec 1951 (en.wikipedia) |

Reserve: Rajanikanta Sen, a song (verified: 1865 – 13 Sep 1910); Satyendranath Dutta, Jharna (verified: 1882 – 25 Jun 1922); Jagadish Chandra Bose, Abyakta (see BN-020); a second Tagore song or story. Tagore is capped at 12 of the 18.

### BN-020, `bn-culture-4`: twentieth-century fiction and poetry, authors who died by 1955 (bn-5850 to 5899)

| # | Candidate work | Creator | Author's death year and rights |
|---|---|---|---|
| 1 | Pather Panchali (the novel) | Bibhutibhushan Bandyopadhyay | verified: 1894 – 1 Nov 1950 (en.wikipedia) |
| 2 | Aparajito | Bibhutibhushan Bandyopadhyay | verified: 1894 – 1 Nov 1950 (en.wikipedia) |
| 3 | Aranyak | Bibhutibhushan Bandyopadhyay | verified: 1894 – 1 Nov 1950 (en.wikipedia) |
| 4 | Chander Pahar | Bibhutibhushan Bandyopadhyay | verified: 1894 – 1 Nov 1950 (en.wikipedia) |
| 5 | Ichhamati | Bibhutibhushan Bandyopadhyay | verified: 1894 – 1 Nov 1950 (en.wikipedia). the date of first publication to be read closely |
| 6 | Devdas | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 7 | Srikanta | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 8 | Pather Dabi | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 9 | Mahesh | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 10 | Parineeta | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 11 | Ramer Sumati | Sarat Chandra Chattopadhyay | verified: 1876 – 16 Jan 1938 (en.wikipedia) |
| 12 | Banalata Sen | Jibanananda Das | verified: 1899 – 22 Oct 1954 (en.wikipedia). died 1954, so the floor is met, but the poem's first publication and the edition to be read |
| 13 | Abar Asibo Phire | Jibanananda Das | verified: 1899 – 22 Oct 1954 (en.wikipedia). same: edition and first publication to be read |
| 14 | Runner (Ranar) | Sukanta Bhattacharya | verified: 1926 – 13 May 1947 (en.wikipedia). title to be read; the poem's own page decides |
| 15 | Abarodhbasini | Begum Rokeya | verified: 1880 – 9 Dec 1932 (en.wikipedia, "Rokeya Sakhawat Hossain") |
| 16 | Abyakta | Jagadish Chandra Bose | verified: 1858 – 23 Nov 1937 (en.wikipedia, "Jagadish Chandra Bose") |
| 17 | Char-iyari Katha | Pramatha Chaudhuri | verified: 1868 – 2 Sep 1946 (en.wikipedia) |
| 18 | Ruposhi Bangla | Jibanananda Das | verified: 1899 – 22 Oct 1954 (en.wikipedia). the collection may have been first published only after his death: expect it to be dropped; the builder reads the first-publication date |

Reserve: none beyond dropped candidates; a second Bibhutibhushan or Sarat Chandra work whose first-publication date the builder reads. Not eligible: Nazrul, Tarashankar and Manik Bandyopadhyay. The Jibanananda Das rows are the rights cases to read closely: he died in 1954, which meets the floor, but a posthumous first publication needs the review-queue row.

## Proverbs (BN-021 to BN-023, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`. The `source` block has `collection`, `date` (the collection's own), `edition`, `jurisdiction`, `rights_checked`. Each card has a `literal` note (word for word) and a meaning, level A2 or B1, in standard colloquial spelling with no archaic or dialect form unless the source gives it and the note says so. Sources the builder tries in order and cites by page and date: bn.wikiquote's proverb pages, bn.wikisource's proverb collections, en.wikipedia (no page titled "Bengali proverbs" was found on 2026-11-15), the sayings attributed to Khana and Dak as anonymous oral tradition (see the culture note: en.wikipedia treats them as possibly one tradition). A collection whose compiler died after 1955 is used only to check that a proverb is attested. **A proverb whose text the builder did not read on the cited page is dropped.**

Seeds, none read on a page yet (the builder keeps only what it reads): অতি লোভে তাঁতি নষ্ট; অতি দর্পে হত লঙ্কা; এক হাতে তালি বাজে না; যত গর্জে তত বর্ষে না; চোরের মায়ের বড় গলা; নাচতে না জানলে উঠান বাঁকা; যেমন কুকুর তেমন মুগুর; অল্প বিদ্যা ভয়ংকরী; ঢেঁকি স্বর্গে গেলেও ধান ভানে; দশের লাঠি একের বোঝা; যার শেষ ভালো তার সব ভালো; কাক কাকের মাংস খায় না; গাছে কাঁঠাল গোঁফে তেল; রাখে হরি মারে কে; দুধ কলা দিয়ে কালসাপ পোষা; পরের ধনে পোদ্দারি.

| Task | Deck | Themes, in order | Ids |
|---|---|---|---|
| BN-021 | `bn-proverbs-1` | animals, food and drink, money, work and effort, family, friends and neighbours, weather and seasons | bn-5900 to 5949 |
| BN-022 | `bn-proverbs-2` | pride and greed, patience and time, luck and fate, speech and silence, learning, the home, justice | bn-5950 to 5999 |
| BN-023 | `bn-proverbs-3` | love, age, honesty, appearances, cleverness, neighbours, travel, the fields (Khana's sayings on farming and weather) | bn-6000 to 6049 |

BN-022 and BN-023 list the earlier decks' targets first and use none of them again.

## Multi-word verbs (BN-024 to BN-027, 4 x 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part; parts already taught are written by `ref`, a part not yet a card gets a card. The citation form is the verbal noun (`করা`, `খেয়ে ফেলা`), and `words` join exactly to `target`. A pattern is kept only if attested on bn.wiktionary, en.wiktionary or a cited dictionary page; fewer than 20 found: report the count, do not fill. The seeds below are not read on any page.

| Task | Deck and `pattern_family` | Seeds | Ids |
|---|---|---|---|
| BN-024 | `bn-multiword-conjunct-kora`, `conjunct-verb` | সাহায্য করা, কাজ করা, চেষ্টা করা, ফোন করা, স্নান করা, রান্না করা, শুরু করা, ব্যবহার করা, বিশ্বাস করা, অপেক্ষা করা, চিন্তা করা, পছন্দ করা, যোগাযোগ করা, প্রশংসা করা, ক্ষমা করা | bn-6050 to 6099 |
| BN-025 | `bn-multiword-conjunct-other`, `conjunct-verb-other` | ভয় পাওয়া, ঘুম পাওয়া, খিদে পাওয়া, কষ্ট পাওয়া, ঠান্ডা লাগা, জ্বর হওয়া, রাগ হওয়া, দেরি হওয়া, মনে হওয়া, ঘুম আসা | bn-6100 to 6149 |
| BN-026 | `bn-multiword-aspectual`, `aspectual-compound` | খেয়ে ফেলা, করে ফেলা, হারিয়ে ফেলা, পড়ে যাওয়া, ভুলে যাওয়া, উঠে পড়া, ঘুমিয়ে পড়া, বসে পড়া, জেগে ওঠা, বলে দেওয়া, দিয়ে দেওয়া, রেখে দেওয়া, ধরে রাখা, দেখে নেওয়া, লিখে নেওয়া, নিয়ে আসা, বেরিয়ে যাওয়া | bn-6150 to 6199 |
| BN-027 | `bn-multiword-idiomatic`, `idiomatic-verb-phrase` | মনে পড়া, মনে রাখা, মন দেওয়া, ধরা পড়া, মাথা ঘামানো, চুপ করা, কান পাতা, পা বাড়ানো | bn-6200 to 6249 |

BN-024 scans the cores `bn-grammar-conjunct-verbs`, `bn-work`, `bn-school`, `bn-health`, `bn-hobbies`, `bn-phone`, `bn-workplace` in that order and does not repeat the cards of `bn-grammar-conjunct-verbs`. BN-026 skips the 9 compounds the rules deck `bn-grammar-compound-verbs` already teaches. BN-027 has only 8 seeds: the builder finds the rest on the cited pages or reports fewer.

## Recommendations (BN-028 and BN-029, 10 + 10)

File `decks/recommendations/bn.yaml`, in the shape of `recommendations/es.yaml` and `ja.yaml`: `id: "bn-rec-<name>"`, `medium` (film, series, book, comic, song, podcast, radio or play), `title { text }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each answerable only by someone who watched, read or heard the work, `tags: ["unreviewed"]`. No quotation and no link. These are works the learner sources themselves, so rights are not a gate; **year and creator are to be read** from the work's Wikipedia page, and a work whose facts could not be read is replaced from the reserve. A living creator has `born` and no `died`.

Page facts read on en.wikipedia 2026-11-15 (lead sentence only): Pather Panchali is a 1955 film by Satyajit Ray; Charulata a 1964 film by Ray; Jalsaghar a 1958 film by Ray; Goopy Gyne Bagha Byne a 1969 film by Ray; Matir Moina a 2002 film by Tareque Masud; Autograph a 2010 film by Srijit Mukherji; Chokher Bali a 2003 film by Rituparno Ghosh (opening sentence says co-written and directed). Corrections to the plan: **en.wikipedia "Sonar Kella" is the 1971 novel by Satyajit Ray, so the builder must read the film's own page (it is a separate title) before citing a year**; **"Meghe Dhaka Tara" is a disambiguation page**, so the builder reads the Ritwik Ghatak film's page; **"Hawa" is a disambiguation page**, so the builder reads the 2022 Bangladeshi film's page and drops it if it is not clear.

| Task | Medium | Candidates (year and creator to be read unless noted above) |
|---|---|---|
| BN-028 | films | Pather Panchali (Ray), Charulata (Ray), Sonar Kella (the film, Ray), Goopy Gyne Bagha Byne (Ray), Meghe Dhaka Tara (Ritwik Ghatak), Jalsaghar (Ray), Matir Moina (Tareque Masud), Autograph (Srijit Mukherji), Chokher Bali (Rituparno Ghosh), Hawa (Mejbaur Rahman Sumon). Reserve: Apur Sansar, Ghare Baire, Bhooter Bhabishyat |
| BN-029 | books, comics, songs, radio | Shei Samay (Sunil Gangopadhyay), Hajar Churashir Maa (Mahasweta Devi), Debi (Humayun Ahmed), Himu stories (Humayun Ahmed), Ganadevata (Tarashankar Bandyopadhyay), Padma Nadir Majhi (Manik Bandyopadhyay), Nonte Phonte (comic strip, Narayan Debnath), Bantul the Great (comic strip, Narayan Debnath), Ami Banglay Gaan Gai (song), Mahishasuramardini (radio programme, Birendra Krishna Bhadra). Reserve: a Feluda story (Ray), Byomkesh stories (Saradindu Bandyopadhyay) |

## Review-queue rule

Everything is `unreviewed`. Each unread, uncertain or dropped item is a row in the builder's report, in the table shape of `docs/review-queue/bn.md`; BN-066 to BN-068 collect the rows into that file, one batch at a time.

## Rights problems found while writing this page

- Nazrul (d. 1976), Tarashankar (d. 1971) and Manik Bandyopadhyay (d. 1956) fail the floor; they are recommendations only.
- Jibanananda Das (d. 1954) meets the floor but Ruposhi Bangla, and possibly other collections, may have been first published after his death: read the first-publication date.
- Khanar Bachan and Dakar Bachan may be one tradition (en.wikipedia lists Dak as another name of Khana) and the figure is legendary; count them once if so.
- Chandidas is "possibly more than one" poet on en.wikipedia; "Baru Chandidas" and the Shrikrishnakirtana attribution are to be read.

## Not planned, and open questions for the owner

1. **Professional decks.** Not planned; the owner supplies the list first.
2. **Bangladeshi pronunciation** is not planned; the course is the Kolkata standard.
3. **A resources file** (`bn-resources.yaml`): not on the checklist, not planned unless the owner asks.
4. **Term of copyright.** The floor is the plan's rule (1955 or earlier); a reviewer confirms the legal term before the decks ship.

