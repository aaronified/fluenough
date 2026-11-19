# Deck work queue: Sanskrit candidate lists

Status: harvest of 2026-11-18 for the Haiku builders of the Classical Sanskrit (`sa`) B1 units that ran short of verifiable lemmas. Each section lists at least 1.5 times the missing count of lemmas for one unit, so a builder only has to write cards. Rules of [Deck-Work-Queue](Deck-Work-Queue.md) and [Deck-Work-Queue-SA](Deck-Work-Queue-SA.md) apply.

## How the lists were made, and what to trust

- **Taught set excluded.** Every non-phrase card of `decks/sa/sa-*.yaml` on `origin/decks-live`, `origin/decks/sa-b1-words1`, `origin/decks/sa-b1-wave1` and `origin/decks/sa-b1-wave2` was read (target, stem in `bases`, and reading); a lemma whose stem or reading matches any of them is left out. Sentence and phrase cards, and words that appear only inside examples, do not count as taught.
- **Lemma source.** The Wiktionary Sanskrit extract at kaikki.org (nouns and adjectives with a declension table), which carries the head line, gender, stem class and glosses exactly as en.wiktionary prints them. Each lemma was then checked against its **live en.wiktionary page** (page exists, has a `==Sanskrit==` section). Lemmas whose live page had no Sanskrit section were dropped.
- **Corpus attestation.** A verse reference in the "Confirmed" column means a form of the lemma (or, marked "as compound member", its stem inside a longer compound) occurs in that verse as typed on sa.wikisource: Manusmṛti 2, 3, 7, 8, 9; Abhijñānaśākuntalam 1 to 7; Meghadūta; Ṛgveda 10.85; Yogasūtra with bhāṣya. Wikisource typing has errors: check a form on a second page before it goes on a card. The reference proves the word is used in that text, **not that the card's sense is the one used there**; pick the sense from the gloss and re-read the verse.
- **Not done.** Monier-Williams (1899) pages on archive.org were not read for these lists (Wiktionary glosses already cite MW). Arthaśāstra, Yājñavalkyasmṛti, Nāṭyaśāstra, Kāvyaprakāśa and the Gītā were not available as text on the reachable hosts in this run, so lemmas whose only support is those works rest on Wiktionary alone ("Wiktionary entry only").
- **Columns.** Lemma is the stem form (a card `target` is the nominative, the stem goes in `bases`). Head line is copied from en.wiktionary. Gloss is Wiktionary's, shortened. Table: yes means Wiktionary shows a declension table (the page uses `{{sa-noun}}` or `{{sa-adj}}` or `{{sa-decl-*}}`); no means none, so a rules-deck row cannot be taken from it.
- **Homonyms.** One row per lemma, with the sense named in the gloss. Several lemmas have other senses on Wiktionary (for example `मध्यम` "middle" or a musical note); the gloss shown is the sense the unit wants.

## sa-relationships (planned 70, 21 built, missing 49; list needs 74)

Candidates listed: 91

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | सुहृद् | suhṛd | noun stem, m or f | friend, ally | root-stem | yes | Wiktionary page + head line + table; Manu 8.17 (as compound member) | Manusmṛti |
| 2 | सखि | sakhi | noun stem, m | a friend, companion; assistant | i-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.5 | Śākuntalam |
| 3 | सखी | sakhī | noun stem, f | a female friend or companion | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.5 | Śākuntalam |
| 4 | अरि | ari | noun stem, m | enemy, stranger | i-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.5 | Śākuntalam |
| 5 | रिपु | ripu | noun stem, m | enemy, adversary, foe; deceiver, cheat, rogue | u-stem | yes | Wiktionary page + head line + table; Manu 7.90 | Manusmṛti |
| 6 | ज्ञाति | jñāti | noun stem, m | relative, kinsman (especially paternal) | i-stem | yes | Wiktionary page + head line + table; RV 10.85.28 | Ṛgveda 10.85 |
| 7 | सम्बन्ध | sambandha | noun stem, m | binding or joining together, close connection or union or association, | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.2 (as compound member) | Śākuntalam |
| 8 | उपाध्याय | upādhyāya | noun stem, m | teacher, preceptor, advisor, counselor | a-stem | yes | Wiktionary page + head line + table; Manu 2.141 | Manusmṛti |
| 9 | भृत्य | bhṛtya | noun stem, m | a servant, dependant, slave; a king's servant, minister; a subject | a-stem | yes | Wiktionary page + head line + table; Manu 7.123 | Manusmṛti |
| 10 | आतिथ्य | ātithya | adj stem | proper for a guest, hospitable | — | no | Wiktionary page + head line | (Wiktionary entry only; no corpus hit) |
| 11 | प्रजा | prajā | noun stem, f | procreation; offspring; race; posterity; man, mankind | ā-stem | yes | Wiktionary page + head line + table; Manu 3.42 | Manusmṛti |
| 12 | समाज | samāja | noun stem, m | society, assembly, conclave | a-stem | yes | Wiktionary page + head line + table; Manu 9.264 | Manusmṛti |
| 13 | गोत्र | gotra | noun stem, n | ‘family enclosed by the hurdle’, family, race, lineage, kin ChUp. Ṡāṅk | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.5 | Śākuntalam |
| 14 | पितामह | pitāmaha | noun stem, m | paternal grandfather | a-stem | yes | Wiktionary page + head line + table; Manu 3.284 | Manusmṛti |
| 15 | पितामही | pitāmahī | noun stem, f | a paternal grandmother | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 16 | प्रपितामह | prapitāmaha | noun stem, m | a paternal great grandfather | a-stem | yes | Wiktionary page + head line + table; Manu 3.221 (as compound member) | Manusmṛti |
| 17 | मातामह | mātāmaha | noun stem, m | a maternal grandfather; maternal grandparents (PārGṛ.) | a-stem | yes | Wiktionary page + head line + table; Manu 9.132 | Manusmṛti |
| 18 | पितृव्य | pitṛvya | noun stem, m | paternal uncle (the brother of one’s father); older male relative | a-stem | yes | Wiktionary page + head line + table; Manu 2.130 (as compound member) | Manusmṛti |
| 19 | श्वश्रू | śvaśrū | noun stem, f | a mother-in-law (either the wife's or the husband's mother) | ū-stem | yes | Wiktionary page + head line + table; Manu 2.131 (as compound member) | Manusmṛti |
| 20 | जामातृ | jāmātṛ | noun stem, m | a son-in-law | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 8.26.21 | Ṛgveda 8.26.21 |
| 21 | स्नुषा | snuṣā | noun stem, f | daughter-in-law | ā-stem | yes | Wiktionary page + head line + table; Manu 9.57 | Manusmṛti |
| 22 | नप्तृ | naptṛ | noun stem, m | descendant, offspring, son; grandson (son's son or daughter's son) | ṛ-stem | yes | Wiktionary page + head line + table; RV 10.85.42 (as compound member) | Ṛgveda 10.85 |
| 23 | भ्रातृव्य | bhrātṛvya | noun stem, m | father's brother's son; a paternal cousin; father's brother's son | a-stem | yes | Wiktionary page + head line + table; c. 1200 BCE – 1000 BCE, Atharvaveda 5.22 | Atharvaveda 5.22 |
| 24 | देवृ | devṛ | noun stem, m | woman's brother-in-law, husband's brother (especially his younger brot | ṛ-stem | yes | Wiktionary page + head line + table; Manu 3.80 | Manusmṛti |
| 25 | ननान्दृ | nanāndṛ | noun stem, f | sister-in-law (husband's sister) | ṛ-stem | yes | Wiktionary page + head line + table; RV 10.85.46 | Ṛgveda 10.85 |
| 26 | यातृ | yātṛ | noun stem, f | co-sister-in-law (husband's brother's wife) | ṛ-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 27 | सपत्नी | sapatnī | noun stem, f | a co-wife, rival wife; another wife of one’s polygamous husband | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.18 (as compound member) | Śākuntalam |
| 28 | सहोदर | sahodara | noun stem, m | sibling, brother | a-stem | yes | Wiktionary page + head line + table; Manu 9.192 | Manusmṛti |
| 29 | सपिण्ड | sapiṇḍa | noun stem, m | deceased relative who is connected to the greater body of ancestors by | a-stem | yes | Wiktionary page + head line + table; Manu 2.247 | Manusmṛti |
| 30 | ज्येष्ठ | jyeṣṭha | noun stem, m | the eldest brother | a-stem | yes | Wiktionary page + head line + table; Manu 9.105 | Manusmṛti |
| 31 | कनिष्ठ | kaniṣṭha or kaniṣṭha | adj stem | youngest, younger-born; smallest, lowest, least | a-stem | yes | Wiktionary page + head line + table; Manu 9.113 (as compound member) | Manusmṛti |
| 32 | अग्रज | agraja | noun stem, m | the firstborn, an elder brother | a-stem | yes | Wiktionary page + head line + table; Manu 9.114 | Manusmṛti |
| 33 | भगिनी | bhaginī | noun stem, f | sister; any woman; wife | ī-stem | yes | Wiktionary page + head line + table; YS 2.25 | Yoga Sūtra |
| 34 | कलत्र | kalatra | noun stem, n | wife, consort; the female of an animal; the hip and loins | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 35 | कान्त | kānta | noun stem, m | any one beloved, lover, husband; the Moon; the spring; iron; stone | a-stem | yes | Wiktionary page + head line + table; Manu 2.61 (as compound member) | Manusmṛti |
| 36 | द्रोह | droha | noun stem, m | injury, mischief, harm, perfidy, treachery, wrong, offence | a-stem | yes | Wiktionary page + head line + table; Manu 7.48 | Manusmṛti |
| 37 | कृतघ्न | kṛtaghna | adj stem | ungrateful | a-stem | yes | Wiktionary page + head line + table; Manu 8.89 | Manusmṛti |
| 38 | प्रतिकार | pratikāra | noun stem, m | requital, compensation; resistance, opposition, obstruction | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 39 | साहाय्य | sāhāyya | noun stem, n | help, succour; friendship, fellowship, alliance | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 40 | संगति | saṃgati | noun stem, f | coming together, meeting with; going or resorting to | i-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.20 | Śākuntalam |
| 41 | सङ्ग | saṅga | noun stem, m | sticking, clinging to, touch, contact with | a-stem | yes | Wiktionary page + head line + table; YS 3.52 | Yoga Sūtra |
| 42 | आलिङ्गन | āliṅgana | noun stem, n | the act of embracing; a hug, embrace | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 43 | आशिस् | āśis | noun stem, f | blessing, benediction; asking for, prayer, wish | root-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 44 | शरण | śaraṇa | noun stem, n | shelter, place of shelter or refuge or rest, hut, house, habitation, a | a-stem | yes | Wiktionary page + head line + table; YS 2.34 | Yoga Sūtra |
| 45 | शरणागत | śaraṇāgata | noun stem, m | supplicant for asylum, refugee | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 46 | आश्रय | āśraya | noun stem, m | refuge, shelter; attachment, support; assistance, help; dependence | a-stem | yes | Wiktionary page + head line + table; YS 1.33 (as compound member) | Yoga Sūtra |
| 47 | ऋत्विज् | ṛtvij | noun stem, m | seasonal-sacrificer | root-stem | yes | Wiktionary page + head line + table; Manu 8.388 (as compound member) | Manusmṛti |
| 48 | यजमान | yajamāna | noun stem, m | one who commissions a sacrifice | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.4 | Śākuntalam |
| 49 | पौत्र | pautra | noun stem, m | a son's son, grandson | — | no | Wiktionary page + head line; Manu 3.200 (as compound member) | Manusmṛti |
| 50 | दौहित्र | dauhitra | noun stem, m | daughter's son | a-stem | yes | Wiktionary page + head line + table; Manu 3.235 | Manusmṛti |
| 51 | विपक्ष | vipakṣa | noun stem, m | "being on a different side", an opponent, adversary, enemy; disputant | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 52 | शिक्षक | śikṣaka | noun stem, m | teacher, instructor | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 53 | नाथ | nātha | noun stem, n | refuge, help, resort | a-stem | yes | Wiktionary page + head line + table; c. 1200 BCE – 1000 BCE, Atharvaveda 9.2. | Atharvaveda 9.2. |
| 54 | कुटुम्ब | kuṭumba | noun stem, n | a household, members of a household, family | a-stem | yes | Wiktionary page + head line + table; Manu 3.80 (as compound member) | Manusmṛti |
| 55 | कुटुम्बक | kuṭumbaka | noun stem, n | a household, family; the duties and cares of a householder | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 56 | संतान | saṃtāna | noun stem, m or n | continuous succession, lineage, race, family, offspring, son or daught | a-stem | yes | Wiktionary page + head line + table; Manu 9.59 | Manusmṛti |
| 57 | छात्रा | chātrā | noun stem, f | female student, pupil; schoolgirl | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 58 | शिष्या | śiṣyā | noun stem, f | student, disciple (feminine) | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.9 | Śākuntalam |
| 59 | अम्बा | ambā | noun stem, f | a mother, good woman (as a title of respect) | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 60 | वश्य | vaśya | noun stem, m | a dependent, slave | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 61 | जनितृ | janitṛ | noun stem, m | father, parent; producer, progenitor, creator, originator | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 9.96.5 | Ṛgveda 9.96.5 |
| 62 | पितृव्या | pitṛvyā | noun stem, f | paternal aunt, the wife of one’s father’s brother | ā-stem | yes | Wiktionary page + head line + table; Manu 2.130 (as compound member) | Manusmṛti |
| 63 | मातुला | mātulā | noun stem, f | maternal aunt, mother’s brother’s wife | ā-stem | yes | Wiktionary page + head line + table; Manu 2.130 (as compound member) | Manusmṛti |
| 64 | स्याल | syāla | noun stem, m | a man's brother-in-law, wife's brother | a-stem | yes | Wiktionary page + head line + table; Manu 8.253 (as compound member) | Manusmṛti |
| 65 | स्याली | syālī | noun stem, f | man's sister-in-law, wife's sister | ī-stem | yes | Wiktionary page + head line + table; c. 700 CE, Kūrma Purāṇa 2.32.29 | Kūrma Purāṇa 2.32.29 |
| 66 | अपत्य | apatya | noun stem, n | offspring, child, descendant | a-stem | yes | Wiktionary page + head line + table; Manu 9.27 | Manusmṛti |
| 67 | कुलीन | kulīna | adj stem | belonging to the family of; of high or eminent descent, well-born | a-stem | yes | Wiktionary page + head line + table; Manu 7.210 (as compound member) | Manusmṛti |
| 68 | प्रतिवेश | prativeśa | noun stem, m | a neighbour | a-stem | yes | Wiktionary page + head line + table; Manu 8.392 (as compound member) | Manusmṛti |
| 69 | अतिथिदेव | atithideva | noun stem, m | someone who treats a guest as equivalent to a deva | a-stem | yes | Wiktionary page + head line + table; c. 600 BCE, Taittirīya Upaniṣad 1.11.2 | Taittirīya Upaniṣad 1.11.2 |
| 70 | आचार्यदेव | ācāryadeva | noun stem, m | someone who treats a teacher as equivalent to a deva | a-stem | yes | Wiktionary page + head line + table; c. 600 BCE, Taittirīya Upaniṣad 1.11.2 | Taittirīya Upaniṣad 1.11.2 |
| 71 | मातृष्वसेय | mātṛṣvaseya | noun stem, m | maternal cousin | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 72 | पितृष्वसेय | pitṛṣvaseya | noun stem, m | paternal cousin | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 73 | भगिनीपुत्र | bhaginīputra | noun stem, m | sister's son, nephew | a-stem | yes | Wiktionary page + head line + table; 1964, Rāmacandra Mumukṣu, Adinath Nemina | Adinath Nemina |
| 74 | भ्रातृवधू | bhrātṛvadhū | noun stem, f | a brother's wife; sister-in-law | ū-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 75 | मान्य | mānya | adj stem | to be respected or honored, worthy of honor, respectable, venerable | a-stem | yes | Wiktionary page + head line + table; Manu 2.139 | Manusmṛti |
| 76 | पूजार्ह | pūjārha | adj stem | worthy of reverence or honor, venerable, respectable | a-stem | yes | Wiktionary page + head line + table; Manu 9.26 | Manusmṛti |
| 77 | प्रेमन् | preman | noun stem, m or n | love, affection, fondness | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 78 | मित्र्य | mitrya | adj stem | friendly; coming from or relating to a friend | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 5.85.7 | Ṛgveda 5.85.7 |
| 79 | अमित्रता | amitratā | noun stem, f | enmity | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 80 | वल्लभ | vallabha | noun stem, m | lover; husband; favourite | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.24 (as compound member) | Śākuntalam |
| 81 | रमण | ramaṇa | noun stem, n | pleasure, joy; dalliance, amorous sport, sexual union, copulation | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 82 | वनिता | vanitā | noun stem, f | a loved wife, mistress, any woman (also applied to the female of an an | ā-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 83 | सेविका | sevikā | noun stem, f | a maid, female servant | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 84 | शिक्षिका | śikṣikā | noun stem, f | a female teacher | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 85 | भर्तृ | bhartṛ | noun stem, m | bearer; preserver; nourisher; master | ṛ-stem | yes | Wiktionary page + head line + table; Manu 3.60 | Manusmṛti |
| 86 | प्रतीति | pratīti | noun stem, f | trust, credit; respect; delight; fame, notoriety, reputation | i-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.31 (as compound member) | Śākuntalam |
| 87 | अश्रद्धा | aśraddhā | noun stem, f | want of trust, unbelief | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 88 | द्विष् | dviṣ | noun stem, f | hostility, hate | root-stem | yes | Wiktionary page + head line + table; Manu 2.57 (as compound member) | Manusmṛti |
| 89 | यादव | yādava | noun stem, m | a descendant of Yadu | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.12 (as compound member) | Śākuntalam |
| 90 | निज | nija | noun stem, m | a relative | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 91 | पितृष्वसृ | pitṛṣvasṛ | noun stem, f | a father's sister; an aunt | ṛ-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |

Dropped (not usable): सन्तान (no usable entry or taught)


## sa-history (planned 90, 48 built, missing 42; list needs 63)

Candidates listed: 97

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | सम्राज् | samrāj | noun stem, m | a supreme ruler, a universal king, a sovereign lord | root-stem | yes | Wiktionary page + head line + table; RV 10.85.46 (as compound member) | Ṛgveda 10.85 |
| 2 | चक्रवर्तिन् | cakravartin | noun stem, m | chakravartin, wheel-turner (in reference to the dharmachakra, world-ru | in-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.12 (as compound member) | Śākuntalam |
| 3 | साम्राज्य | sāmrājya | noun stem, n | empire | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 4 | दुर्ग | durga | noun stem, n or m | fortress; difficult or narrow passage; a place difficult to access | a-stem | yes | Wiktionary page + head line + table; Manu 3.98 (as compound member) | Manusmṛti |
| 5 | भट | bhaṭa | noun stem, m | a mercenary, hired soldier, warrior, combatant; a servant, slave | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 6 | चतुरङ्ग | caturaṅga | adj stem | comprising (4 parts, viz.) elephants, chariots, cavalry, and infantry | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 10.92.11 | Ṛgveda 10.92.11 |
| 7 | व्यूह | vyūha | noun stem, m | placing apart, distribution, arrangement | a-stem | yes | Wiktionary page + head line + table; Manu 7.188 | Manusmṛti |
| 8 | विग्रह | vigraha | noun stem, m | division; distribution (especially of fluids) | a-stem | yes | Wiktionary page + head line + table; Manu 7.164 | Manusmṛti |
| 9 | जय | jaya | noun stem, m | conquest, victory, triumph, winning, being victorious (in battle or in | a-stem | yes | Wiktionary page + head line + table; Manu 7.44 | Manusmṛti |
| 10 | प्रयाण | prayāṇa | noun stem, n | journey, motion onwards, progress, the act of moving forward | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 11 | चर | cara | noun stem, m | a spy | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 12 | भेद | bheda | noun stem, m | breaking, splitting, cleaving; cleft, chasm, fissure | a-stem | yes | Wiktionary page + head line + table; Manu 7.198 | Manusmṛti |
| 13 | राजनीति | rājanīti | noun stem, f | politics | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 14 | चन्द्रवंश | candravaṃśa | noun stem, m | Chandravamsha, one of the two principle Kshatriya dynasties. | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 15 | कुरु | kuru | noun stem, m | name of an Indian tribe and of their kingdom | u-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 16 | कुषाण | kuṣāṇa | noun stem, m | Kushan (person) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 17 | यवन | yavana | noun stem, m | a foreigner, an outsider not part of the four-tiers of varna | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 18 | दस्यु | dasyu | noun stem, m | impious man; barbarian | u-stem | yes | Wiktionary page + head line + table; Manu 7.143 | Manusmṛti |
| 19 | म्लेच्छ | mleccha | noun stem, m | mleccha, foreigner, barbarian | a-stem | yes | Wiktionary page + head line + table; Manu 2.23 (as compound member) | Manusmṛti |
| 20 | आर्य | ārya | noun stem, m | an Indo-Aryan, i.e. an Ārya, a self-designator of the peoples of Ancie | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.2 | Śākuntalam |
| 21 | सत्ययुग | satyayuga | noun stem, n | Satya Yuga, said to be the first and the best of the four yugas | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 22 | कल्प | kalpa | noun stem, m | a sacred precept, law, rule, ordinance, manner of acting, proceeding,  | a-stem | yes | Wiktionary page + head line + table; Manu 3.147 | Manusmṛti |
| 23 | चरित | carita | noun stem, n | acting, doing, practice, behavior, acts, deeds, adventures | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.16 | Śākuntalam |
| 24 | मगध | magadha | noun stem, m | the country of the मगधs, South Bihar; the people of that country | — | no | Wiktionary page + head line | (Wiktionary entry only; no corpus hit) |
| 25 | कलिङ्ग | kaliṅga | noun stem, m | name of a people and their country (the name is applied in the पुराणs  | — | no | Wiktionary page + head line | (Wiktionary entry only; no corpus hit) |
| 26 | अन्तःपुर | antaḥpura | noun stem, n | female apartments, gynaeceum; harem | — | no | Wiktionary page + head line; Manu 7.153 (as compound member) | Manusmṛti |
| 27 | अक्षौहिणी | akṣauhiṇī | noun stem, f | akshauhini | — | no | Wiktionary page + head line | (Wiktionary entry only; no corpus hit) |
| 28 | अनीक | anīka | noun stem, m or n | an army; military forces; the face; the appearance; splendor | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 29 | पृतना | pṛtanā | noun stem, f | battle, strife, war, combat; army; hostile armament or band | ā-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.85.8.1 | Ṛgveda 1.85.8.1 |
| 30 | चमू | camū | noun stem, f | an army or division of an army (129 elephants, as many cars, 2187 hors | ū-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 31 | अस्त्र | astra | noun stem, n | a missile weapon, bolt, arrow; a weapon in general; a sword; a bow | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 32 | बाण | bāṇa | noun stem, m | a shaft made of a reed, an arrow; the versed sine of an arc | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.10 | Śākuntalam |
| 33 | असि | asi | noun stem, m | sword, scimitar, knife (used for killing animals) | i-stem | yes | Wiktionary page + head line + table; Manu 2.122 | Manusmṛti |
| 34 | गदा | gadā | noun stem, f | a mace, club or a bludgeon | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 35 | कवच | kavaca | noun stem, m or n | coat of mail, armour | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 36 | वर्मन् | varman | noun stem, n | armor | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 37 | शत्रुता | śatrutā | noun stem, f | enmity, hostility | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 38 | बन्दिन् | bandin | adj stem | prisoner, captive, slave | in-stem | yes | Wiktionary page + head line + table; Manu 3.158 | Manusmṛti |
| 39 | कारा | kārā | noun stem, f | a prison; binding, confinement | ā-stem | yes | Wiktionary page + head line + table; Manu 2.66 (as compound member) | Manusmṛti |
| 40 | प्रतिष्ठा | pratiṣṭhā | noun stem, f | ground, base, pedestal, support | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.6 | Śākuntalam |
| 41 | उत्तराधिकारिन् | uttarādhikārin | noun stem, m | an heir or claimant subsequent to the death of the original owner, an  | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 42 | वसुधा | vasudhā | noun stem, f | earth; country, kingdom; ground, soil; anapaest | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.30 | Śākuntalam |
| 43 | क्षत्र | kṣatra | noun stem, n | dominion, supremacy, power, might; government, governing body | a-stem | yes | Wiktionary page + head line + table; Manu 3.23 | Manusmṛti |
| 44 | पार्थिव | pārthiva | adj stem | earthly, earthen; of the earth | a-stem | yes | Wiktionary page + head line + table; Manu 8.88 | Manusmṛti |
| 45 | पाण्डव | pāṇḍava | adj stem | relating to, belonging to, or coming from Pandu or his descendants | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 46 | कौरव | kaurava | adj stem | relating to or belonging to the Kurus | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 47 | कृपाण | kṛpāṇa | noun stem, m | sword, dagger | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 48 | राजासन | rājāsana | noun stem, n | a royal seat, throne | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 49 | राजर्षि | rājarṣi | noun stem, m | a royal rishi or saint, rishi of royal descent, that holy and superhum | i-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.2 | Śākuntalam |
| 50 | राजलक्ष्मी | rājalakṣmī | noun stem, f | the Fortune or Prosperity of a king (personified as a goddess), royal  | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.6 | Śākuntalam |
| 51 | शूरत्व | śūratva | noun stem, n | state or condition of a hero, heroism, valour, bravery | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 52 | कुञ्जर | kuñjara | noun stem, m | an elephant; anything pre-eminent in its kind | a-stem | yes | Wiktionary page + head line + table; Manu 3.274 | Manusmṛti |
| 53 | महावीर | mahāvīra | noun stem, m | a great hero | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 54 | नेतृ | netṛ | noun stem, m | leader, conductor, guide; leader, chief (of an army etc.); master | ṛ-stem | yes | Wiktionary page + head line + table; Manu 7.17 | Manusmṛti |
| 55 | पण | paṇa | noun stem, m | a compact stipulation, agreement, treaty | a-stem | yes | Wiktionary page + head line + table; Manu 8.224 | Manusmṛti |
| 56 | आसार | āsāra | noun stem, m | surrounding an enemy; incursion, attack; a hard shower | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 57 | युध् | yudh | noun stem, f | war, battle, fight, combat | root-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.91.21 | Ṛgveda 1.91.21 |
| 58 | पृत् | pṛt | noun stem, f | fight, battle, strife, combat | root-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 6.33.3 | Ṛgveda 6.33.3 |
| 59 | द्विष् | dviṣ | noun stem, f | hostility, hate | root-stem | yes | Wiktionary page + head line + table; Manu 2.57 (as compound member) | Manusmṛti |
| 60 | पत्ति | patti | noun stem, m | a foot soldier, an infantryman (a soldier who fights on foot) | i-stem | yes | Wiktionary page + head line + table; Manu 2.68 (as compound member) | Manusmṛti |
| 61 | सायक | sāyaka | noun stem, m or n | a missile, arrow | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.11 | Śākuntalam |
| 62 | करवाल | karavāla | noun stem, m | sword | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 63 | कोट | koṭa | noun stem, m | fort, castle | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 64 | नय | naya | noun stem, m | leading (of an army) | a-stem | yes | Wiktionary page + head line + table; Manu 7.180 | Manusmṛti |
| 65 | नराधिप | narādhipa | noun stem, m | king of men, lord of men; a title for a king; Cassia fistula | a-stem | yes | Wiktionary page + head line + table; Manu 8.73 | Manusmṛti |
| 66 | राष्ट्रपति | rāṣṭrapati | noun stem, m | lord of a kingdom, a sovereign | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 67 | भारतवर्ष | bhāratavarṣa | noun stem, n | realm of the descendants of King Bharata, the Indian subcontinent | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 68 | राजतरंगिणी | rājataraṃgiṇī | noun stem, f | “stream of kings” Rajatarangini, a celebrated history of the kings of  | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 69 | इन्द्रप्रस्थ | indraprastha | noun stem, m | Indraprastha, (an ancient city of India, mentioned in the Sanskrit epi | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 70 | राजमार्ग | rājamārga | noun stem, m | highway, royal or main road; principal street | a-stem | yes | Wiktionary page + head line + table; Manu 9.282 (as compound member) | Manusmṛti |
| 71 | महामात्र | mahāmātra | noun stem, m | a man of high rank, high official, prime minister | a-stem | yes | Wiktionary page + head line + table; Manu 9.259 (as compound member) | Manusmṛti |
| 72 | धर्मयुद्ध | dharmayuddha | noun stem, n | honest fight; religious war | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 73 | महायुद्ध | mahāyuddha | noun stem, n | a great fight | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 74 | युध्म | yudhma | noun stem, m | warrior, hero, combatant | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 6.18.2 | Ṛgveda 6.18.2 |
| 75 | संयुग | saṃyuga | noun stem, n | union, conjunction; fight, conflict, war | a-stem | yes | Wiktionary page + head line + table; c. 500 BCE – 100 BCE, Rāmāyaṇa 1.1.4 | Rāmāyaṇa 1.1.4 |
| 76 | समरण | samaraṇa | noun stem, n | battle, conflict, strife | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.170.2 | Ṛgveda 1.170.2 |
| 77 | यन्तृ | yantṛ | noun stem, m | a driver (of horses or elephants), charioteer | ṛ-stem | yes | Wiktionary page + head line + table; Manu 9.320 (as compound member) | Manusmṛti |
| 78 | प्रशास्तृ | praśāstṛ | noun stem, m | "Director"; the name of a post of a priest; a ruler, king | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.94.6 | Ṛgveda 1.94.6 |
| 79 | शास्तृ | śāstṛ | noun stem, m | a ruler, commander; a teacher, instructor; a punisher, chastiser | ṛ-stem | yes | Wiktionary page + head line + table; YS 2.29 | Yoga Sūtra |
| 80 | महाराजन् | mahārājan | noun stem, m | a great king. | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 81 | वैदेह | vaideha | noun stem, m | a king of the Vaidehas; a Vaideha man | a-stem | yes | Wiktionary page + head line + table; YS 1.16 (as compound member) | Yoga Sūtra |
| 82 | सैन्धव | saindhava | noun stem, m | a king of Sindh; an inhabitant of Sindh | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 83 | मिथिला | mithilā | noun stem, f | Mithila, a city said to have been founded by Mithi or Mithila (it was  | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 84 | यात्रिक | yātrika | noun stem, m | a traveller, pilgrim | a-stem | yes | Wiktionary page + head line + table; Manu 7.184 (as compound member) | Manusmṛti |
| 85 | रथस्थ | rathastha | adj stem | mounted on a chariot, standing on a chariot, chariot-borne | a-stem | yes | Wiktionary page + head line + table; c. 700 CE – 900 CE, Bhāgavata Purāṇa 10. | Bhāgavata Purāṇa 10. |
| 86 | द्विप | dvipa | noun stem, m | elephant | a-stem | yes | Wiktionary page + head line + table; Manu 2.44 (as compound member) | Manusmṛti |
| 87 | इभ | ibha | noun stem, m | an elephant | a-stem | yes | Wiktionary page + head line + table; c. 200 BCE – 200 CE, Manusmṛti 12.67 | Manusmṛti 12.67 |
| 88 | करिन् | karin | noun stem, m | "having a trunk", an elephant | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 89 | रणवीर | raṇavīra | adj stem | hero in a battle | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 90 | आवलि | āvali | noun stem, f | a row, range; a continuous line; a series; a dynasty, lineage | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 91 | संधान | saṃdhāna | noun stem, n | union, junction; an act of placing or joining together or uniting | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 92 | यामन् | yāman | noun stem, n | going, coming, motion, course, flight; march, expedition | an-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.7 (as compound member) | Śākuntalam |
| 93 | काश्मीर | kāśmīra | noun stem, m | a king of Kashmir; a tree of species Ficus elastica | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 94 | गौड | gauḍa | noun stem, m or n | a region in Bengal; the capital of that region | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 95 | युयुत्सु | yuyutsu | adj stem | eager for battle, pugnacious | u-stem | yes | Wiktionary page + head line + table; c. 400 BCE, Bhagavad Gītā 1.1 | Bhagavad Gītā 1.1 |
| 96 | राजभट | rājabhaṭa | noun stem, m | king's soldier; soldier of the royal army; messenger; envoy | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 97 | लक्ष्मी | lakṣmī | noun stem, f | mark, sign, token; a bad sign, impending misfortune | ī-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |

Dropped (not usable): सन्धि (no usable entry or taught), पृथ्वी (no usable entry or taught)


## sa-arts (planned 80, 25 built, missing 55; list needs 83)

Candidates listed: 92

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | नृत्त | nṛtta | noun stem, n | dancing, acting, gesticulation | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 2 | नाटिका | nāṭikā | noun stem, f | a style of drama which is composed of four acts and is a light-hearted | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 3 | वेणु | veṇu or veṇu | noun stem, m | a bamboo, reed, cane; a flute, fife, pipe | u-stem | yes | Wiktionary page + head line + table; Manu 8.299 (as compound member) | Manusmṛti |
| 4 | मुरली | muralī | noun stem, f | flute, pipe | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 5 | श्रुति | śruti | noun stem, f | a particular division of the octave, a quarter tone or interval (twent | i-stem | yes | Wiktionary page + head line + table; Manu 9.96 | Manusmṛti |
| 6 | ऋषभ | ṛṣabha | noun stem, m | a bull; a male animal of any kind | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 10.166.1 | Ṛgveda 10.166.1 |
| 7 | गान्धार | gāndhāra | noun stem, ? | third note in the musical scale; prince of the Gândhâris | — | no | Wiktionary page + head line | (Wiktionary entry only; no corpus hit) |
| 8 | मध्यम | madhyama | noun stem, m | the fourth or fifth note (Saṃgīt.) | a-stem | yes | Wiktionary page + head line + table; Manu 8.120 | Manusmṛti |
| 9 | ताण्डव | tāṇḍava | noun stem, m or n | frenzied, violent dancing, particularly that of Shiva; a tribrach | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 10 | लास्य | lāsya | noun stem, n | dancing, a dance (esp. accompanied with instrumental music and singing | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 11 | रेखा | rekhā | noun stem, f | a scratch, streak, stripe, line Gṛihyās. Yājñ. MBh. &c. | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.14 | Śākuntalam |
| 12 | वर्तिका | vartikā | noun stem, f | a stalk; the wick of a lamp; a paintbrush; color, paint | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.16 (as compound member) | Śākuntalam |
| 13 | शिल्पिन् | śilpin | noun stem, m | an artificer, artisan, craftsman, artist | in-stem | yes | Wiktionary page + head line + table; Manu 7.138 (as compound member) | Manusmṛti |
| 14 | प्रतिमा | pratimā | noun stem, f | a figure, image, likeness, model; idol, statue; sample | — | no | Wiktionary page + head line; Manu 9.285 (as compound member) | Manusmṛti |
| 15 | स्थापत्य | sthāpatya | noun stem, m or n | architecture, building | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 16 | वास्तु | vāstu | noun stem, n | the site or foundation of a house, site, ground, building or dwelling- | u-stem | yes | Wiktionary page + head line + table; Manu 3.89 (as compound member) | Manusmṛti |
| 17 | यवनिका | yavanikā | noun stem, f | a Greek woman; cloth screen, stage curtain, veil | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 18 | रसिक | rasika | noun stem, m | a man full of taste or feeling (cf. अ-र्°); a libertine W. | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.14 (as compound member) | Śākuntalam |
| 19 | तन्त्री | tantrī | noun stem, f | the wire or string of a lute; the wire or string of a lute | ī-stem | yes | Wiktionary page + head line + table; YS 2.4 (as compound member) | Yoga Sūtra |
| 20 | तार | tāra | adj stem | high (a note), loud, shrill, a high tone, loud or shrill note (TPrāt.) | a-stem | yes | Wiktionary page + head line + table; YS 3.27 | Yoga Sūtra |
| 21 | विदूषक | vidūṣaka | noun stem, m | jester, fool, particularly in drama; libertine, catamite | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.1 | Śākuntalam |
| 22 | प्रवेशक | praveśaka | noun stem, m | an entering, entrance | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.2 | Śākuntalam |
| 23 | विष्कम्भ | viṣkambha | noun stem, m | support prop; supporting beam of a building; door bolt; width | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.2 | Śākuntalam |
| 24 | भरत | bharata | noun stem, m | actor, dancer, tumbler | — | no | Wiktionary page + head line; Śāk. act 7, v.33 | Śākuntalam |
| 25 | मृद् | mṛd | noun stem, f | earth, soil, clay, loam; a piece of earth, lump of clay | root-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 26 | कुम्भकार | kumbhakāra | noun stem, m | potter | a-stem | yes | Wiktionary page + head line + table; c. 600 BCE – 200 BCE, Caraka, Caraka Saṃ | Caraka Saṃ |
| 27 | तक्षन् | takṣan | noun stem, m | a carpenter; a woodcutter | an-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 9.112.1 | Ṛgveda 9.112.1 |
| 28 | स्थपति | sthapati | noun stem, m | king, chief; architect, master builder, master craftsman; metal worker | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 29 | विश्वकर्मन् | viśvakarman | noun stem, n | every action | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 30 | अलंकार | alaṃkāra | noun stem, m | the act of decorating; ornament; decoration | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 31 | गद्य | gadya | noun stem, n | prose, composition not metrical yet framed in accordance with harmony | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 32 | गाथा | gāthā | noun stem, f | verse, stanza (especially one which is neither ऋच् (ṛc), nor सामन् (sā | ā-stem | yes | Wiktionary page + head line + table; Manu 9.42 | Manusmṛti |
| 33 | मञ्च | mañca | noun stem, m | platform on columns (for spectators), dais; couch; pedestal chair | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.15 (as compound member) | Śākuntalam |
| 34 | नेपथ्य | nepathya | noun stem, n or m | decoration, costume; backstage | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.10 | Śākuntalam |
| 35 | छन्दस् | chandas | noun stem, n | metre; desire, longing for, yearning, will; intention, purport | as-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.8 (as compound member) | Śākuntalam |
| 36 | गीता | gītā | noun stem, f | a song, sacred song or poem; clipping of भगवद्गीता (bhagavadgītā) | ā-stem | yes | Wiktionary page + head line + table; Manu 8.53 (as compound member) | Manusmṛti |
| 37 | तूलि | tūli | noun stem, f | painter's brush | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 38 | कविता | kavitā | noun stem, f | poetry, ornate style (whether of verse or prose); poem | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 39 | डमरु | ḍamaru | noun stem, m | a sacred drum, shaped like an hourglass, used by the god Shiva and by  | u-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 40 | कुशीलव | kuśīlava | noun stem, m | bard, actor, mime; gossiper; appellation of Valmiki | a-stem | yes | Wiktionary page + head line + table; Manu 3.155 (as compound member) | Manusmṛti |
| 41 | आदिकाव्य | ādikāvya | noun stem, n | first court poem, an appellation of the Ramayana | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 42 | महाकवि | mahākavi | noun stem, m | great poet, classical poet; name of Śukra (Cat.) | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 43 | महाकाव्य | mahākāvya | noun stem, n | great or classical court poem, particularly as applied to Kalidasa's R | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 44 | उपरूपक | uparūpaka | noun stem, n | a drama of one of the eighteen lesser classes (Sāh.) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 45 | संगीतशाला | saṃgītaśālā | noun stem, f | music hall (Mṛcch.) | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 46 | ध्वनि | dhvani | noun stem, m | sound, echo, noise, voice, tone, tune, thunder; the sound of a drum | i-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 47 | आदिकवि | ādikavi | noun stem, m | ‘the first poet’; name of ब्रह्मन् (brahman) | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 48 | वर्णन | varṇana | noun stem, n | the act of painting, colouring; delineation, description, explanation | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.14 (as compound member) | Śākuntalam |
| 49 | वाणी | vāṇī | noun stem, f | sound, voice, music; sound, voice, music | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.4 | Śākuntalam |
| 50 | परिमल | parimala | noun stem, m | fragrance, or a fragrant substance, perfume | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 51 | क्रीडा | krīḍā | noun stem, f | sport, play, pastime, amusement; amorous play | ā-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 52 | लीला | līlā | noun stem, f | play, sport, diversion; mere appearance, semblance | ā-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 53 | केलि | keli | noun stem, m or f | play, sport; amorous sport, sexual intercourse; pastime, amusement | i-stem | yes | Wiktionary page + head line + table; Manu 8.357 | Manusmṛti |
| 54 | कुलाल | kulāla | noun stem, m | a potter | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 55 | रङ्गिन् | raṅgin | adj stem | colouring, dyeing, painting; passionate, impassioned | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 56 | प्रतिबिम्ब | pratibimba | noun stem, n or m | reflected image; reflection; mirrored form | a-stem | yes | Wiktionary page + head line + table; YS 4.24 (as compound member) | Yoga Sūtra |
| 57 | स्थूणा | sthūṇā | noun stem, f | column, pillar | ā-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.59.1 | Ṛgveda 1.59.1 |
| 58 | अलंकरण | alaṃkaraṇa | noun stem, n | ornament, decoration; preparation | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 59 | स्तोतृ | stotṛ | noun stem, m | a praiser, eulogizer, singer of praise | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 6.54.9 | Ṛgveda 6.54.9 |
| 60 | चित्रकर | citrakara | noun stem, m | a painter | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.6 (as compound member) | Śākuntalam |
| 61 | ढक्का | ḍhakkā | noun stem, f | a large or double drum | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 62 | गातृ | gātṛ | noun stem, m | a singer | ṛ-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 63 | रङ्गकार | raṅgakāra | noun stem, m | painter; dyer | a-stem | yes | Wiktionary page + head line + table; c. 700 CE – 900 CE, Bhāgavata Purāṇa 10. | Bhāgavata Purāṇa 10. |
| 64 | पुत्तल | puttala | noun stem, m or n | puppet, doll, small statue; effigy, image, statue | a-stem | yes | Wiktionary page + head line + table; Lakṣmīnārāyaṇasaṃhitā 1.102.47 | Lakṣmīnārāyaṇasaṃhitā 1.102.47 |
| 65 | तूर्य | tūrya | noun stem, n | a musical instrument | a-stem | yes | Wiktionary page + head line + table; Manu 7.255 (as compound member) | Manusmṛti |
| 66 | तूणव | tūṇava | noun stem, m | a flute | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 67 | अञ्जलि | añjali | noun stem, m | Añjali Mudrā (the gesture with open hands placed side by side and slig | i-stem | yes | Wiktionary page + head line + table; Śivatāṇḍavastotra 13 | Śivatāṇḍavastotra 13 |
| 68 | सामन् | sāman | noun stem, n | any song or tune (sacred or profane, also the hum of bees) | an-stem | yes | Wiktionary page + head line + table; Manu 7.198 | Manusmṛti |
| 69 | ऋच् | ṛc | noun stem, f | praise | root-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 70 | गाथ | gātha | noun stem, m | song | a-stem | yes | Wiktionary page + head line + table; Manu 9.42 | Manusmṛti |
| 71 | कोण | koṇa | noun stem, m | a corner, angle; an intermediate point of the compass | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 72 | शाला | śālā | noun stem, f | a house, mansion, building, hall, large room, apartment, shed, worksho | ā-stem | yes | Wiktionary page + head line + table; Manu 9.264 (as compound member) | Manusmṛti |
| 73 | पट्ट | paṭṭa | noun stem, m | a slab, tablet (for painting or writing upon) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.7 (as compound member) | Śākuntalam |
| 74 | यन्त्र | yantra | noun stem, n | any instrument for holding or restraining or fastening, a prop, suppor | a-stem | yes | Wiktionary page + head line + table; Manu 2.118 (as compound member) | Manusmṛti |
| 75 | निष्क | niṣka | noun stem, m or n | a golden ornament for the neck or breast | a-stem | yes | Wiktionary page + head line + table; Manu 2.34 (as compound member) | Manusmṛti |
| 76 | स्वस्तिक | svastika | noun stem, m or n | a mansion or temple of a particular form | a-stem | yes | Wiktionary page + head line + table; YS 2.47 (as compound member) | Yoga Sūtra |
| 77 | दाक्षिण्य | dākṣiṇya | noun stem, n | dexterity, skill, officiousness, gallantry, kindness, consideration, p | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.5 | Śākuntalam |
| 78 | चक्रबन्ध | cakrabandha | noun stem, m | a stanza artificially arranged in a diagram (Pratāpar.) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 79 | जरितृ | jaritṛ | noun stem, m | a praiser, singer of hymns | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.2.2 | Ṛgveda 1.2.2 |
| 80 | गिर् | gir | noun stem, f | praise, hymn, song of praise, verse, invocation | root-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.23 | Śākuntalam |
| 81 | वाक्पटुत्व | vākpaṭutva | noun stem, n | skill in speech, eloquence, silver tongue | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 82 | ऋभु | ṛbhu | noun stem, m | artisan, metalworker, craftsman; a class of craftsmen gods | u-stem | yes | Wiktionary page + head line + table; YS 3.27 | Yoga Sūtra |
| 83 | व्यञ्जन | vyañjana | noun stem, n | decoration, ornament; manifestation, indication; allusion, suggestion | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 84 | दृश्य | dṛśya | noun stem, m or n | n a visible object; the visible world | a-stem | yes | Wiktionary page + head line + table; YS 2.24 | Yoga Sūtra |
| 85 | सोपान | sopāna | noun stem, n | stairs, steps, a staircase | a-stem | yes | Wiktionary page + head line + table; Manu 3.238 (as compound member) | Manusmṛti |
| 86 | जालक | jālaka | noun stem, n | net, woven texture, web; net, woven texture, web | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 87 | आयतन | āyatana | noun stem, n | house, home, seat, support, or resting place | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 88 | केयूर | keyūra | noun stem, n or m | a bracelet worn on the upper arm | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 89 | हर्म्य | harmya | noun stem, n | a large house, palace, mansion | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 90 | सौध | saudha | noun stem, n or m | a stuccoed house; mansion, palace | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 91 | वातायन | vātāyana | noun stem, n | window; portico; balcony; terrace on the roof of house; airhole | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.8 | Śākuntalam |
| 92 | लेखक | lekhaka | noun stem, m | writer; scribe; copyist; painter; clerk; secretary | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |

Dropped (not usable): मूर्च्छा (no usable entry or taught)


## sa-law (planned 80, 25 built, missing 55; list needs 83)

Candidates listed: 84

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | चौर | caura | noun stem, m | a thief, robber | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 2 | ऋणिन् | ṛṇin | noun stem, m | debtor | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 3 | अनृणिन् | anṛṇin | adj stem | free from debt; unindebted | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 4 | शास्ति | śāsti | noun stem, f | correction, punishment; order, command; governing, ruling; sceptre | i-stem | yes | Wiktionary page + head line + table; Manu 7.18 | Manusmṛti |
| 5 | आगस् | āgas | noun stem, n | transgression, offence, injury, sin, fault | as-stem | yes | Wiktionary page + head line + table; Manu 9.241 | Manusmṛti |
| 6 | अकार्य | akārya | noun stem, n | criminal action | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 7 | अदत्तादान | adattādāna | noun stem, n | stealing, theft | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 8 | अपराधिन् | aparādhin | adj stem | criminal, offender, guilty | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 9 | अपराधिनी | aparādhinī | noun stem, f | criminal, one who commits crime (feminine) | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 10 | रेक्णस् | rekṇas | noun stem, n | property left behind; legacy, inheritance; wealth, treasure | as-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 7.4.7 | Ṛgveda 7.4.7 |
| 11 | अघ | agha | noun stem, n | evil; mishap; sin | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 2.41.11 | Ṛgveda 2.41.11 |
| 12 | एनस् | enas | noun stem, n | sin, crime, offense; unhappiness, misfortune | as-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 10.63.8 | Ṛgveda 10.63.8 |
| 13 | कपट | kapaṭa | noun stem, m or n | fraud, deceit, cheating, circumvention | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 14 | वञ्चन | vañcana | noun stem, n | cheating; fraud; illusion; delusion | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 15 | अनृत | anṛta | noun stem, n | falsehood, lying, cheating | a-stem | yes | Wiktionary page + head line + table; YS 2.34 | Yoga Sūtra |
| 16 | शृङ्खल | śṛṅkhala | noun stem, m | chain, fetter, especially one made of iron; measuring chain; a belt | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 17 | पाश | pāśa | noun stem, m | a noose, cord, bond, chain or a fetter | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 7.88.7 | Ṛgveda 7.88.7 |
| 18 | बन्ध | bandha | noun stem, m | a binding, fetter, tie, bond; a bundle | a-stem | yes | Wiktionary page + head line + table; YS 3.39 | Yoga Sūtra |
| 19 | क्रेतृ | kretṛ | noun stem, m | buyer, purchaser | ṛ-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 20 | विक्रेतृ | vikretṛ | noun stem, m | seller, one who sells | ṛ-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 21 | साक्षिणी | sākṣiṇī | noun stem, f | spectator, witness (feminine) | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 22 | धनिन् | dhanin | noun stem, m | a rich man, owner, creditor; a name of Kubera | in-stem | yes | Wiktionary page + head line + table; Manu 8.61 | Manusmṛti |
| 23 | अधमर्ण | adhamarṇa | noun stem, m | one reduced to inferiority by incurring debt; a debtor | a-stem | yes | Wiktionary page + head line + table; Manu 8.47 (as compound member) | Manusmṛti |
| 24 | आधमर्ण्य | ādhamarṇya | noun stem, n | the state of being a debtor; debtorship; indebtedness | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 25 | अनृणता | anṛṇatā | noun stem, f | unindebtedness, freedom from debt | ā-stem | yes | Wiktionary page + head line + table; c. 500 BCE – 100 BCE, Rāmāyaṇa 2.94.17 | Rāmāyaṇa 2.94.17 |
| 26 | क्रय्य | krayya | adj stem | purchasable; exhibited for sale | a-stem | yes | Wiktionary page + head line + table; c. 700 BCE, Śatapatha Brāhmaṇa 3.3.3.1 | Śatapatha Brāhmaṇa 3.3.3.1 |
| 27 | परिग्रह | parigraha | noun stem, m | getting, attaining, acquisition, possession, property | a-stem | yes | Wiktionary page + head line + table; YS 2.34 | Yoga Sūtra |
| 28 | उपालम्भ | upālambha | noun stem, m | reproach, censure, abuse, finding fault with; prohibition, interdict | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 29 | सभापति | sabhā-pati | noun stem, m | the president or chairman of an assembly or council | i-stem | yes | Wiktionary page + head line + table; c. 1200 BCE – 800 BCE, Kṛṣṇa-Yajurveda ( | Kṛṣṇa-Yajurveda ( |
| 30 | सभ्य | sabhya | noun stem, m | an assistant at an assembly or council, esp. an assessor, judge | a-stem | yes | Wiktionary page + head line + table; Manu 8.10 (as compound member) | Manusmṛti |
| 31 | सभेय | sabheya | adj stem | fit for an assembly or council, civilized, clever, well-behaved, decen | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 32 | कुलिक | kulika | noun stem, m | judge, chief; kinsman; hunter; thorny plant; a type of poison | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 33 | धर्मिन् | dharmin | adj  | knowing or obeying the law, faithful to duty, virtuous, pious, just | in-stem | yes | Wiktionary page + head line + table; YS 4.34 | Yoga Sūtra |
| 34 | वैध | vaidha | adj stem | enjoined by rule or precept, prescribed, legal | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 35 | दुष्कृत | duṣkṛta | noun stem, n | an evil action; a sin; guilt | a-stem | yes | Wiktionary page + head line + table; Manu 3.191 (as compound member) | Manusmṛti |
| 36 | अभद्र | abhadra | noun stem, n | badness, wickedness, evilness; sin | a-stem | yes | Wiktionary page + head line + table; c. 700 CE – 900 CE, Bhāgavata Purāṇa 1.2 | Bhāgavata Purāṇa 1.2 |
| 37 | परुष | paruṣa | noun stem, n | harsh and contumelious speech, abuse, etc. | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 38 | खानक | khānaka | noun stem, m | a house-breaker, thief (VarBṛS.) | a-stem | yes | Wiktionary page + head line + table; Manu 8.260 (as compound member) | Manusmṛti |
| 39 | लट | laṭa | noun stem, m | thief; one who speaks like a child or like a fool | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 40 | लुप्त | lupta | noun stem, n | plunder, loot, stolen property; disappearance | a-stem | yes | Wiktionary page + head line + table; Manu 8.226 (as compound member) | Manusmṛti |
| 41 | लोप्त्र | loptra | noun stem, n | stolen property; loot; booty | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 42 | स्तेन | stena | noun stem, m | thief, robber; thieving, stealing | a-stem | yes | Wiktionary page + head line + table; Manu 7.83 | Manusmṛti |
| 43 | स्तायु | stāyu | noun stem, m | thief, robber | u-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 44 | अर्घ | argha | noun stem, m | worth, value, price | a-stem | yes | Wiktionary page + head line + table; Manu 8.402 (as compound member) | Manusmṛti |
| 45 | वस्न | vasna | noun stem, n | price, value | a-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 4.24.22 | Ṛgveda 4.24.22 |
| 46 | धरिमन् | dhariman | noun stem, m | a balance, weight; form, figure | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 47 | ढौकन | ḍhaukana | noun stem, n | offering, present, bribe; bringing near | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 48 | वाणिज | vāṇija | noun stem, m | merchant; trader | a-stem | yes | Wiktionary page + head line + table; Manu 3.181 (as compound member) | Manusmṛti |
| 49 | वणिज | vaṇija | noun stem, m | trader; name of Shiva; the zodiacal sign Libra | a-stem | yes | Wiktionary page + head line + table; Manu 7.127 (as compound member) | Manusmṛti |
| 50 | वाणिज्यक | vāṇijyaka | noun stem, m | a merchant, trader (Hcat.) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 51 | निश्चित | niścita | noun stem, n | certainty, decision, resolution, design | a-stem | yes | Wiktionary page + head line + table; Manu 7.59 (as compound member) | Manusmṛti |
| 52 | अप्रमाण | apramāṇa | noun stem, n | a rule which is no standard of action | a-stem | yes | Wiktionary page + head line + table; YS 1.9 | Yoga Sūtra |
| 53 | सीमन् | sīman | noun stem, f | boundary, border, limit, margin, frontier | an-stem | yes | Wiktionary page + head line + table; Manu 8.254 | Manusmṛti |
| 54 | पार | pāra | noun stem, n | the further bank or shore or boundary, any bank or shore, the opposite | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 55 | योगक्षेम | yogakṣema | noun stem, m | the secure possession of what has been acquired | a-stem | yes | Wiktionary page + head line + table; Manu 7.127 (as compound member) | Manusmṛti |
| 56 | भार | bhāra | noun stem, m | burden, load, weight; labor, toil; an onerous task | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 57 | ऋत | ṛta | noun stem, n | fixed or settled order, law, rule (especially in religion) | a-stem | yes | Wiktionary page + head line + table; RV 10.85.24 | Ṛgveda 10.85 |
| 58 | ऋतावन् | ṛtāvan | adj stem | keeping within the fixed order or rule, regular, proper (as inanimated | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 59 | अप्नस् | apnas | noun stem, n | wealth; possession; property | as-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 1.113.20 | Ṛgveda 1.113.20 |
| 60 | करस्थ | karastha | adj stem | lying in the hand; in possession | a-stem | yes | Wiktionary page + head line + table; Budhakauśika, Rāmarakṣāstotra 31 | Rāmarakṣāstotra 31 |
| 61 | दस्यु | dasyu | noun stem, m | impious man; barbarian | u-stem | yes | Wiktionary page + head line + table; Manu 7.143 | Manusmṛti |
| 62 | वादिन् | vādin | noun stem, m | speaker, asserter; disputant; plaintiff, accuser, prosecutor | in-stem | yes | Wiktionary page + head line + table; Manu 7.91 | Manusmṛti |
| 63 | भृति | bhṛti or bhṛti | noun stem, f | support, maintenance, nourishment, food RV. &c. | i-stem | yes | Wiktionary page + head line + table; Manu 8.231 | Manusmṛti |
| 64 | कूट | kūṭa | noun stem, m or n | illusion, fraud, trick, untruth, falsehood | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 65 | प्रग्रह | pragraha | noun stem, m | holding in front, stretching forth | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.15 | Śākuntalam |
| 66 | घात | ghāta | noun stem, m | a blow, bruise; devastation, destruction | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 67 | घातक | ghātaka | noun stem, m | killer, murderer, slayer | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 68 | हत्या | hatyā | noun stem, f | killing, slaying, slaughter, murder (particularly of the criminal vari | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 69 | हन्तृ | hantṛ | noun stem, m | a killer, slayer, murderer | ṛ-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 10.87.22 | Ṛgveda 10.87.22 |
| 70 | द्यूत | dyūta | noun stem, n | gambling, game of dice; play, gaming; contest; battle or fight for | a-stem | yes | Wiktionary page + head line + table; Manu 2.179 (as compound member) | Manusmṛti |
| 71 | श्रेष्ठिन् | śreṣṭhin | noun stem, m | the head or president of a mercantile or other guild | in-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.23 (as compound member) | Śākuntalam |
| 72 | निधि | nidhi | noun stem, m | a store, hoard, treasure; setting down or serving up (of food) | i-stem | yes | Wiktionary page + head line + table; Manu 8.37 | Manusmṛti |
| 73 | पण | paṇa | noun stem, m | play for a stake; a compact stipulation, agreement, treaty | a-stem | yes | Wiktionary page + head line + table; Manu 8.224 | Manusmṛti |
| 74 | अधिकारिन् | adhikārin | noun stem, m | official, one with authority; authoritative | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 75 | द्विगुण | dviguṇa | adj  | double; twofold (having two parts) | a-stem | yes | Wiktionary page + head line + table; YS 3.27 | Yoga Sūtra |
| 76 | चण्डाल | caṇḍāla | noun stem, m | outcast, one born from a shudra father and a brahmin mother | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 77 | शुद्धि | śuddhi | noun stem, f | cleansing, purification, purity, holiness, freedom from defilement, pu | i-stem | yes | Wiktionary page + head line + table; YS 1.3 | Yoga Sūtra |
| 78 | वचन | vacana | noun stem, n | speaking, utterance (Sāṃkhyak.); pronunciation | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.11 | Śākuntalam |
| 79 | वक्तृ | vaktṛ | noun stem, m | speaker, orator; teacher | ṛ-stem | yes | Wiktionary page + head line + table; Manu 8.272 | Manusmṛti |
| 80 | कृच्छ्र | kṛcchra | noun stem, n | trouble; pain; calamity; difficulty; hardship; affliction | a-stem | yes | Wiktionary page + head line + table; YS 2.33 (as compound member) | Yoga Sūtra |
| 81 | उद्धार | uddhāra | noun stem, m | the act of raising, elevating, lifting up; drawing out, pulling out | a-stem | yes | Wiktionary page + head line + table; Manu 9.112 | Manusmṛti |
| 82 | लब्ध | labdha | adj stem | taken, seized, caught, met with, found; got at, arrived (as a moment) | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 83 | दातृ | dātṛ or dātṛ | noun stem, m | giver, donor, liberal; one who gives a daughter (gen.) in marriage | ṛ-stem | yes | Wiktionary page + head line + table; Manu 3.242 | Manusmṛti |
| 84 | आपद् | āpad | noun stem, f | fall, accident; fall, accident | root-stem | yes | Wiktionary page + head line + table; Manu 9.56 | Manusmṛti |

## sa-weddings (planned 60, 21 built, missing 39; list needs 59)

Candidates listed: 62

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | आर्ष | ārṣa | noun stem, m | an old form of marriage, in which one or two pairs of cattle are given | a-stem | yes | Wiktionary page + head line + table; Manu 3.53 | Manusmṛti |
| 2 | राक्षस | rākṣasa | noun stem, m | a demon in general, an evil or malignant demon | a-stem | yes | Wiktionary page + head line + table; Manu 3.21 (as compound member) | Manusmṛti |
| 3 | दैव | daiva | noun stem, n | divine power or will, destiny, fate, chance | a-stem | yes | Wiktionary page + head line + table; Manu 3.125 | Manusmṛti |
| 4 | वेदि | vedi | noun stem, f | raised ground used for a sacrificial altar | i-stem | yes | Wiktionary page + head line + table; Manu 2.7 | Manusmṛti |
| 5 | वरयात्रा | varayātrā | noun stem, f | A procession that brings the bridegroom to the wedding venue. | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 6 | वैवाहिक | vaivāhika | noun stem, n | wedding preparations, pre-wedding festivities; wedding | a-stem | yes | Wiktionary page + head line + table; Manu 2.67 (as compound member) | Manusmṛti |
| 7 | पाणि | pāṇi | noun stem, m | the hand | i-stem | yes | Wiktionary page + head line + table; Manu 2.72 (as compound member) | Manusmṛti |
| 8 | गन्धर्व | gandharva | noun stem, m | a gandharva (one of a class of male heavenly beings, famed singers and | a-stem | yes | Wiktionary page + head line + table; Manu 3.196 (as compound member) | Manusmṛti |
| 9 | अर्यमन् | aryaman | noun stem, m | a friend who asks a woman in marriage for another | an-stem | yes | Wiktionary page + head line + table; RV 10.85.36 | Ṛgveda 10.85 |
| 10 | भग | bhaga | noun stem, m | Bhaga, one of the Adityas, a god of wealth and marriage in Hinduism. I | a-stem | yes | Wiktionary page + head line + table; Manu 9.237 | Manusmṛti |
| 11 | दम्पति | dampati | noun stem, m | husband and wife; the lord of the house | i-stem | yes | Wiktionary page + head line + table; Manu 3.116 | Manusmṛti |
| 12 | ऊढ | ūḍha | adj stem | carried, conveyed; borne; stolen; washed away by water | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 13 | प्रवर | pravara | adj stem | best, finest; excellent, noble | a-stem | yes | Wiktionary page + head line + table; Manu 2.200 (as compound member) | Manusmṛti |
| 14 | अनुलोम | anuloma | adj stem | regular; in order (following an appropriate sequence); successive | a-stem | yes | Wiktionary page + head line + table; c. 400 BCE, Mahābhārata 6.114.36 | Mahābhārata 6.114.36 |
| 15 | प्रतिलोम | pratiloma | adj stem | contrary to the regular order; inverted; against the grain | a-stem | yes | Wiktionary page + head line + table; c. 500 BCE – 100 BCE, Rāmāyaṇa 5.20.35 | Rāmāyaṇa 5.20.35 |
| 16 | ग्रन्थि | granthi | noun stem, m | knot | i-stem | yes | Wiktionary page + head line + table; Manu 2.43 (as compound member) | Manusmṛti |
| 17 | पर्यङ्क | paryaṅka | noun stem, m | furniture for lying down: a bed, a couch | a-stem | yes | Wiktionary page + head line + table; YS 2.47 (as compound member) | Yoga Sūtra |
| 18 | कन्यका | kanyakā | noun stem, f | girl, maiden, virgin; daughter; the sign of the zodiac Virgo | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.1 | Śākuntalam |
| 19 | मिथुन | mithuna | noun stem, m | a pair (male and female; but also "any couple or pair") | a-stem | yes | Wiktionary page + head line + table; Manu 3.29 (as compound member) | Manusmṛti |
| 20 | तरुण | taruṇa | noun stem, m | a youth | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.5 | Śākuntalam |
| 21 | यौवन | yauvana | noun stem, n | youth, youthfulness; adolescence, puberty | a-stem | yes | Wiktionary page + head line + table; Manu 9.3 | Manusmṛti |
| 22 | स्त्रीत्व | strītva | noun stem, n | womanhood, wifehood; feminineness | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 23 | अकन्या | akanyā | noun stem, f | not a virgin | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 24 | अक्षता | akṣatā | noun stem, f | virgin | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 25 | बाला | bālā | noun stem, f | female child, girl, young woman (especially one under 16 years) | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.2 | Śākuntalam |
| 26 | वनिता | vanitā | noun stem, f | a loved wife, mistress, any woman (also applied to the female of an an | ā-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 27 | कामुक | kāmuka | noun stem, m | a lover, gallant | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 28 | रमण | ramaṇa | noun stem, n | pleasure, joy; dalliance, amorous sport, sexual union, copulation | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 29 | कलत्र | kalatra | noun stem, n | wife, consort; the female of an animal; the hip and loins | a-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 30 | इष्ट | iṣṭa | noun stem, m | lover, husband; castor oil plant L. | a-stem | yes | Wiktionary page + head line + table; Manu 7.13 | Manusmṛti |
| 31 | प्रेष्ठ | preṣṭha | noun stem, m | a lover, husband | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 32 | ललना | lalanā | noun stem, f | a wanton woman, any woman, wife; the tongue | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 33 | भर्तृ | bhartṛ | noun stem, m | husband | ṛ-stem | yes | Wiktionary page + head line + table; Manu 3.174 | Manusmṛti |
| 34 | पतित्व | patitva | noun stem, n | matrimony, wedlock | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 35 | बालिका | bālikā | noun stem, f | girl | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 36 | कनीनिका | kanīnikā | noun stem, f | girl, maiden; pupil | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 37 | युग्म | yugma | noun stem, n | a pair, couple, brace; the sign of the zodiac Gemini | a-stem | yes | Wiktionary page + head line + table; Manu 3.48 (as compound member) | Manusmṛti |
| 38 | योषित् | yoṣit | noun stem, f | girl, young woman | root-stem | yes | Wiktionary page + head line + table; Manu 9.24 | Manusmṛti |
| 39 | युवति | yuvati | noun stem, f | a girl; a young woman | i-stem | yes | Wiktionary page + head line + table; Manu 2.212 (as compound member) | Manusmṛti |
| 40 | माङ्गलिक | māṅgalika | noun stem, n | any auspicious object (like an amulet) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 41 | परिणीत | pariṇīta | noun stem, n | the act of marrying; a marriage | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.21 (as compound member) | Śākuntalam |
| 42 | परिणीति | pariṇīti | noun stem, f | the act of marrying; marriage | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 43 | अग्रू | agrū | noun stem, f | a maiden, virgin; an unmarried girl | ū-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 7.2.5 | Ṛgveda 7.2.5 |
| 44 | सुभग | subhaga | adj stem | fortunate, lucky; blessed; happy; pleasant; beautiful; auspicious | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 45 | जान्य | jānya | noun stem, m | a friend of bridegroom | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.11 (as compound member) | Śākuntalam |
| 46 | वशगा | vaśagā | noun stem, f | obedient wife | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 47 | सभार्य | sabhārya | adj stem | with a wife, having a wife | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 48 | जानि | jāni | noun stem, f | wife; birth, descent | i-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.10 | Śākuntalam |
| 49 | जनी | janī̆ | noun stem, f | a woman, wife | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 50 | द्वय | dvaya | noun stem, n | pair, couple (set of two); duality, falsehood | a-stem | yes | Wiktionary page + head line + table; YS 3.16 | Yoga Sūtra |
| 51 | द्वंद्व | dvaṃdva | noun stem, n or m | pair, couple; male and female; pair, couple | a-stem | yes | Wiktionary page + head line + table; YS 2.33 (as compound member) | Yoga Sūtra |
| 52 | सुभद्र | subhadra | adj stem | very auspicious or fortunate; very glorious or splendid | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 53 | यूनि | yūni | noun stem, f | connection; union | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 54 | यौन | yauna | noun stem, n | matrimonial connection, conjugal alliance, relationship by marriage | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 55 | संगम | saṃgama | noun  | a coming together, meeting, union; intercourse or association with | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 56 | युवक | yuvaka | noun stem, m | a youth, young man | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 57 | मर्य | marya | noun stem, m | young man, suitor, lover; stallion | a-stem | yes | Wiktionary page + head line + table; Manu 8.309 (as compound member) | Manusmṛti |
| 58 | कनीन | kanīna | adj  | young, youthful | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 59 | तरुणिमन् | taruṇiman | noun stem, m | youth, youthfulness | an-stem | yes | Wiktionary page + head line + table; Prasannarāghava 2.11 | Prasannarāghava 2.11 |
| 60 | युवता | yuvatā | noun stem, f | youth; youthfulness; the state of being young | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 61 | रामा | rāmā | noun stem, f | a beautiful woman, any young and charming woman, mistress, wife, any w | ā-stem | yes | Wiktionary page + head line + table; Manu 2.8 (as compound member) | Manusmṛti |
| 62 | शकुन | śakuna | noun stem, m | bird (esp. large birds and such as give omens) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.14 (as compound member) | Śākuntalam |

Dropped (not usable): युवती (no usable entry or taught)


## sa-literature (planned 90, none built; list needs 135). Rows 1 to 43 are literary terms and texts; the rest is Kālidāsa's descriptive vocabulary (Śākuntalam, Meghadūta) for reading-led cards

Candidates listed: 141

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | अङ्क | aṅka | noun stem, m | hook; part of a chariot; curve | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.19 | Śākuntalam |
| 2 | अतिशयोक्ति | atiśayokti | noun stem, m | overexaggeration | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 3 | अध्याय | adhyāya | noun stem, m | lesson, lecture; chapter, reading; the time for a lesson or reading | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 4 | अनुप्रास | anuprāsa | noun stem, m | alliteration | a-stem | yes | Wiktionary page + head line + table; c. 700 CE, Daṇḍin, Kāvyādarśa 1.55 | Kāvyādarśa 1.55 |
| 5 | अनुवाक | anuvāka | noun stem, m | saying after, repeating; reading; section (especially of the Vedas) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 6 | अनुवाद | anuvāda | noun stem, m | interpretation; translation; recitation; repetition | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 7 | अनुष्टुभ् | anuṣṭubh | noun stem, f | the Anuṣṭubh (a category of poetic measures characterised by 32-syllab | root-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 10.130.4 | Ṛgveda 10.130.4 |
| 8 | उल्लास | ullāsa | noun stem, m | light, splendour; the coming forth, becoming visible, appearing | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 9 | ओजस् | ojas | noun stem, n | ability, strength; vigour | as-stem | yes | Wiktionary page + head line + table; c. 1500 BCE – 1000 BCE, Ṛgveda 6.18.15 | Ṛgveda 6.18.15 |
| 10 | कथानक | kathānaka | noun stem, n | a little tale | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 11 | कवि | kavi | noun stem, m | wise man, sage, seer, prophet; a singer, bard, poet | i-stem | yes | Wiktionary page + head line + table; Manu 2.151 | Manusmṛti |
| 12 | काण्ड | kāṇḍa or kāṇḍa | noun stem, m or n | a joint of the stalk of a cane or bamboo; section, portion, chapter | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.12 (as compound member) | Śākuntalam |
| 13 | गायत्री | gāyatrī | noun stem, f | an ancient metre of twenty-four syllables | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 14 | चरण | caraṇa | noun stem, m or n | foot (Gobh., Mn., Bādar. MBh., etc.); pillar, support; tree root | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.12 | Śākuntalam |
| 15 | जगती | jagatī | noun stem, f | the earth; people, mankind; a female animal, a cow | ī-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 16 | जातक | jātaka | noun stem, m | a newborn child (Kauś.); a mendicant | a-stem | yes | Wiktionary page + head line + table; Manu 2.27 (as compound member) | Manusmṛti |
| 17 | टीका | ṭīkā | noun stem, f | a commentary (esp. on another commentary), gloss | ā-stem | yes | Wiktionary page + head line + table; YS 1.1 (as compound member) | Yoga Sūtra |
| 18 | पठन | paṭhana | noun stem, n | study; reading; studying; reciting; recitation | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 19 | पर्वन् | parvan | noun stem, n | joint, limb; knot, particularly of reeds; division, section | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 20 | पिङ्गल | piṅgala | adj stem | reddish-brown, tawny; yellow, gold-colored | a-stem | yes | Wiktionary page + head line + table; Manu 3.8 | Manusmṛti |
| 21 | प्रबन्ध | prabandha | noun stem, m | continuous application or action, continuance, uninterruptedness | a-stem | yes | Wiktionary page + head line + table; YS 3.39 | Yoga Sūtra |
| 22 | प्रहसन | prahasana | noun stem, n | laughter, amusement, mockery (Uttara., Hit.); satire, sarcasm | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 23 | भास | bhāsa | noun stem, m | light; lustre; brightness | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 24 | महाभारत | mahābhārata | noun stem, n or m | Mahabharata | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 25 | मालिनी | mālinī | noun stem, f | the wife of a garland-maker or gardener; a female florist | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.17 | Śākuntalam |
| 26 | यति | yati | noun stem, m | an ascetic, devotee, one who has restrained his passions and abandoned | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 27 | रीति | rīti | noun stem, f | motion, course; stream, current; line, row, course of things | i-stem | yes | Wiktionary page + head line + table; Manu 2.246 (as compound member) | Manusmṛti |
| 28 | रूपक | rūpaka | noun stem, m | a certain coin (Var., Pañcat., etc.); a kind of measure (Saṃgīt.) | a-stem | yes | Wiktionary page + head line + table; YS 2.31 (as compound member) | Yoga Sūtra |
| 29 | वेताल | vetāla | noun stem, m | vetala, a kind of demon that takes possession of a dead body | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 30 | व्याख्या | vyākhyā | noun stem, f | explanation, exposition, gloss, comment, paraphrase | ā-stem | yes | Wiktionary page + head line + table; YS 1.44 (as compound member) | Yoga Sūtra |
| 31 | व्यास | vyāsa | noun stem, m | severing, separation, division | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.8 (as compound member) | Śākuntalam |
| 32 | श्रवण | śravaṇa | noun stem, m | ear; the hypotenuse of a triangle or the diagonal of a tetragon | a-stem | yes | Wiktionary page + head line + table; Manu 2.144 (as compound member) | Manusmṛti |
| 33 | श्रोतृ | śrotṛ | noun stem, m or f | one who hears, hearing, a hearer | ṛ-stem | yes | Wiktionary page + head line + table; Manu 8.272 | Manusmṛti |
| 34 | सरस्वती | sarasvatī | noun stem, f | any river; speech or the power of speech, eloquence, learning wisdom | ī-stem | yes | Wiktionary page + head line + table; Manu 8.105 | Manusmṛti |
| 35 | सर्ग | sarga | noun stem, m | discharging, voiding, letting go or getting rid of (any excrement) | a-stem | yes | Wiktionary page + head line + table; Manu 8.143 (as compound member) | Manusmṛti |
| 36 | सुभाषित | subhāṣita | noun stem, n | fine speech; witty saying, aphorism, maxim | a-stem | yes | Wiktionary page + head line + table; Manu 2.239 | Manusmṛti |
| 37 | सूक्त | sūkta | noun stem, n | good speech; wise saying; song of praise; a Vedic hymn | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 38 | स्कन्ध | skandha | noun stem, m | shoulder, torso; tree trunk; large branch or bough | a-stem | yes | Wiktionary page + head line + table; YS 4.22 | Yoga Sūtra |
| 39 | बिन्दु | bindu | noun stem, n | a detached particle, drop, globule, dot, spot; a pearl | u-stem | yes | Wiktionary page + head line + table; Manu 7.33 (as compound member) | Manusmṛti |
| 40 | प्रस्ताव | prastāva | noun stem, m | mention, offer, proposal, topic; introduction, commencement | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.13 | Śākuntalam |
| 41 | निदर्शन | nidarśana | noun stem, n | seeing, view, appearance, sight, vision | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.5 | Śākuntalam |
| 42 | रमणीय | ramaṇīya | adj stem | delightful, pleasing, pleasant, agreeable | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.13 | Śākuntalam |
| 43 | मुग्ध | mugdha | adj stem | perplexed, bewildered; gone astray, lost; foolish, ignorant, silly | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.3 | Śākuntalam |
| 44 | कान्ति | kānti | noun stem, f | desire, wish | i-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.26 | Śākuntalam |
| 45 | शोभा | śobhā | noun stem, f | splendour, brilliance, lustre, beauty, grace, loveliness | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.3 | Śākuntalam |
| 46 | वपुस् | vapus | noun stem, n | form, figure (especially a beautiful form or figure) | us-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.14 | Śākuntalam |
| 47 | कपोल | kapola | noun stem, m | cheek | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.13 | Śākuntalam |
| 48 | अधर | adhara | noun stem, m | the lower lip, the lip | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.22 | Śākuntalam |
| 49 | वदन | vadana | noun stem, n | mouth, face; speaking, saying | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.27 | Śākuntalam |
| 50 | बाष्प | bāṣpa | noun stem, m | a tear, tears; steam, vapour | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.23 | Śākuntalam |
| 51 | अश्रु | aśru | noun stem, n | tear | u-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.15 | Śākuntalam |
| 52 | केका | kekā | noun stem, f | cry of a peacock | ā-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 53 | कोलाहल | kolāhala | noun stem, m or n | a loud and confused sound, uproar, great and indistinct noise (of men, | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.1 | Śākuntalam |
| 54 | फेन | phena | noun stem, m or n | foam, froth, scum; moisture of the lips, saliva | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 55 | रश्मि | raśmi | noun stem, f | rope, string, cord; rein, bridle, leash; whip, goad; measuring cord | i-stem | yes | Wiktionary page + head line + table; Manu 9.305 | Manusmṛti |
| 56 | क्षपा | kṣapā | noun stem, f | night | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.5 | Śākuntalam |
| 57 | व्योमन् | vyoman | noun stem, m | heaven, sky, atmosphere, air; space | an-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 58 | नभस् | nabhas | noun stem, n | mist, fog, clouds, vapour | as-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 59 | सुकुमार | sukumāra | adj stem | very tender or delicate | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.12 | Śākuntalam |
| 60 | सलज्ज | salajja | adj stem | having shame, modest | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.17 | Śākuntalam |
| 61 | प्रमद | pramada | noun stem, m | pleasure, delight | a-stem | yes | Wiktionary page + head line + table; Manu 2.214 | Manusmṛti |
| 62 | मुक्ता | muktā | noun stem, f | pearl; unchaste woman; species of plant | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.23 | Śākuntalam |
| 63 | केतक | ketaka | noun stem, m | screw pine (Pandanus fascicularis or odoratissimus) | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 64 | कन्दर | kandara | noun stem, m | "great cliff", an artificial or natural cave, glen, defile, valley | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 65 | उटज | uṭaja | noun stem, m or n | a hut made of leaves (the residence of hermits or saints); a hut | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.17 | Śākuntalam |
| 66 | सुरा | surā | noun stem, f | wine, spirituous liquor | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.15 | Śākuntalam |
| 67 | स्वादु | svādu | noun stem, m | sweetness; pleasantness, charm, beauty; sugar, molasses | u-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 68 | पावन | pāvana | adj stem | purificatory, purifying, sanctifying, pure, holy | a-stem | yes | Wiktionary page + head line + table; Manu 2.26 | Manusmṛti |
| 69 | सुमनस् | sumanas | adj stem | good-minded, well-disposed, benevolent, gracious, favourable, pleasant | as-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.2 | Śākuntalam |
| 70 | श्लाघ्य | ślāghya | adj  | to be praised, praiseworthy; respectable, venerable | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.19 | Śākuntalam |
| 71 | गम्भीर | gambhīra | adj  | deep; serious | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 72 | उदार | udāra | adj stem | noble; liberal; honest; eloquent; bountiful; high; lofty | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.22 | Śākuntalam |
| 73 | सौम्य | saumya or saumya | adj stem | related or pertaining to Soma; cool and moist; northern | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 74 | तनु | tanu | noun stem, f or m | body, person, self; the body, person, self; form or manifestation | u-stem | yes | Wiktionary page + head line + table; Manu 2.28 | Manusmṛti |
| 75 | तन्वी | tanvī | noun stem, f | slender or delicate woman | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.18 | Śākuntalam |
| 76 | श्याम | śyāma | noun stem, m | a black bull; a particular राग (rāga) (Saṃgīt.) | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 77 | मृदु | mṛdu | noun stem, m | the planet Saturn (VarBṛS.) | u-stem | yes | Wiktionary page + head line + table; Manu 8.327 | Manusmṛti |
| 78 | पयस् | payas | noun stem, n | milk; milk; any fluid or juice; water or rain; milk | as-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 79 | पावक | pāvaka | noun stem, m | fire or the god of fire | a-stem | yes | Wiktionary page + head line + table; Manu 2.187 | Manusmṛti |
| 80 | तेजस् | tejas | noun stem, n | the sharp edge of a knife; the point or top of a flame or a ray | as-stem | yes | Wiktionary page + head line + table; Manu 7.5 | Manusmṛti |
| 81 | वीरुध् | vīrudh | noun stem, m | a plant, herb; especially a creeping plant | root-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.9 | Śākuntalam |
| 82 | शार्दूल | śārdūla | noun stem, m | tiger; lion; panther; leopard; doctorbush (Plumbago zeylanica) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.1 | Śākuntalam |
| 83 | पन्नग | pannaga | noun stem, m | a serpent or serpent-demon (Suparṇ., MBh., etc.) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.31 | Śākuntalam |
| 84 | चाप | cāpa | noun stem, m or n | bow; arc | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.26 | Śākuntalam |
| 85 | धनु | dhanu | noun stem, m or n | bow; the sign of Sagittarius | u-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.32 | Śākuntalam |
| 86 | शरु | śaru | noun stem, m or f | arrow, dart, missile | u-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.3 | Śākuntalam |
| 87 | महर्षि | maharṣi | noun stem, m | a Maharishi | i-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.2 | Śākuntalam |
| 88 | छवि | chavi | noun stem, f | skin, cuticle; colour of the skin, colour; beauty, splendour | i-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.8 | Śākuntalam |
| 89 | मणिबन्ध | maṇibandha | noun stem, m | the wrist; the fastening or putting on of jewel | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.21 | Śākuntalam |
| 90 | याच्ञा | yācñā | noun stem, f | begging, asking alms, mendicancy; asking for | ā-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 91 | उन्मत्त | unmatta | adj stem | drunk, intoxicated; frantic; insane, mad | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.13 | Śākuntalam |
| 92 | प्रमत्त | pramatta | adj stem | tipsy; drunk; intoxicated | a-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.1 | Śākuntalam |
| 93 | वक्तव्य | vaktavya | noun stem, n | speaking, speech | a-stem | yes | Wiktionary page + head line + table; YS 3.1 | Yoga Sūtra |
| 94 | परोक्ष | parokṣa | adj stem | beyond the range of sight, unknown, unintelligible, mysterious | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.26 | Śākuntalam |
| 95 | धृष्ट | dhṛṣṭa | adj  | bold, daring, confident, audacious, impudent; secured, obtained | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.19 | Śākuntalam |
| 96 | क्रूर | krūra | noun stem, n | wound, sore; blood-shedding, slaughter, cruelty, harshness | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.9 | Śākuntalam |
| 97 | उग्र | ugra | adj  | mighty, formidable, powerful; furious, terrible, wrathful, savage | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.23 | Śākuntalam |
| 98 | कटुक | kaṭuka | noun stem, m | name of several plants; name of a man | a-stem | yes | Wiktionary page + head line + table; RV 10.85.34 (as compound member) | Ṛgveda 10.85 |
| 99 | पटु | paṭu | adj  | sharp, pungent, acrid, harsh, shrill, keen, strong, intense, violent | u-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 100 | पृथु | pṛthu | adj stem | broad, wide, expansive, extensive, spacious, large; great, important | u-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.9 | Śākuntalam |
| 101 | रोहित | rohita | noun stem, m | red or a chestnut coloured horse; a kind of deer | a-stem | yes | Wiktionary page + head line + table; Manu 7.78 (as compound member) | Manusmṛti |
| 102 | माधव | mādhava | noun stem, m | a descendant of the Madhu race | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.5 (as compound member) | Śākuntalam |
| 103 | नयन | nayana | noun stem, n | conducting, guiding, directing; eye | a-stem | yes | Wiktionary page + head line + table; YS 3.40 | Yoga Sūtra |
| 104 | भुवन | bhuvana | noun stem, n | a being, living thing; existence, being; the world | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.26 | Śākuntalam |
| 105 | श्रेयस् | śreyas | noun stem, m or n | name of various things; n good, good state; happiness | as-stem | yes | Wiktionary page + head line + table; Manu 9.184 | Manusmṛti |
| 106 | चक्षुस् | cakṣus | noun stem, n | light; clearness; the faculty of seeing; sight; vision | us-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.13 | Śākuntalam |
| 107 | वचस् | vacas | noun stem, n | word, speech; voice | as-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.28 | Śākuntalam |
| 108 | यत्न | yatna | noun stem, m | activity of will, volition, aspiring after; performance, work | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.2 | Śākuntalam |
| 109 | स्मर | smara | noun stem, m | memory, remembrance, recollection | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.23 | Śākuntalam |
| 110 | अद्रि | adri | noun stem, m | rock, stone; mountain | i-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 111 | कैलास | kailāsa | noun stem, m | Mount Kailasa (fabulous residence of Shiva | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 112 | गौरी | gaurī | noun stem, f | a female Gaur | ī-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 113 | निवास | nivāsa | noun stem, m | clothing, dress; living, dwelling, residing | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.20 | Śākuntalam |
| 114 | भवन | bhavana | noun stem, m or n | building, edifice; house, dwelling, residence; mansion, palace | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.20 | Śākuntalam |
| 115 | तरु | taru | noun stem, m | tree | u-stem | yes | Wiktionary page + head line + table; Manu 8.406 | Manusmṛti |
| 116 | वज्र | vajra | noun stem, m | "the hard or mighty one", a thunderbolt | a-stem | yes | Wiktionary page + head line + table; Manu 7.191 | Manusmṛti |
| 117 | शक्ति | śakti or śakti | noun stem, f | strength, power, might; ability | i-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.26 | Śākuntalam |
| 118 | वेग | vega | noun stem, m | speed; velocity; rapidity; impetus; momentum; stream; current | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.8 | Śākuntalam |
| 119 | चित्रा | citrā | noun stem, f | the 12th or 13th asterism | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.14 | Śākuntalam |
| 120 | विशाखा | viśākhā | noun stem, f | the 14th (later 16th) lunar asterism (figured by a decorated arch and  | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.11 | Śākuntalam |
| 121 | रोहिणी | rohiṇī | noun stem, f | a red cow or (later) any cow; lightning | ī-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.22 | Śākuntalam |
| 122 | मालिन् | mālin | noun stem, m | gardener, florist | in-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.13 (as compound member) | Śākuntalam |
| 123 | स्नात | snāta | noun stem, m | one whose religious study has finished; an initiated householder | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.11 | Śākuntalam |
| 124 | निषण्ण | niṣaṇṇa | adj stem | sitting, seated; lying, resting, leaning upon | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 125 | सुप्त | supta | adj stem | asleep, fallen asleep; resting, inactive, dull, latent | a-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.11 | Śākuntalam |
| 126 | गात्र | gātra | noun stem, n | "instrument for movement", a limb or a part of the body; the body | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.19 | Śākuntalam |
| 127 | प्राणिन् | prāṇin | noun stem, m | a living or sentient being, living creature, animal or man | in-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.1 | Śākuntalam |
| 128 | जन्तु | jantu | noun stem, m | child, offspring; person, creature, living being | u-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.2 | Śākuntalam |
| 129 | तात | tāta | noun stem, m | daddy, papa | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.23 | Śākuntalam |
| 130 | आयुष्मत् | āyuṣmat | adj stem | possessed of vital power, healthy, long-lived; alive, living | mat-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.31 | Śākuntalam |
| 131 | भगवत् | bhagavat | adj  | fortunate; prosperous (possessing fortune); glorious; illustrious | vat-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.17 | Śākuntalam |
| 132 | वत्स | vatsa | noun stem, m or n | m a calf, the young of any animal, offspring, child | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.23 | Śākuntalam |
| 133 | दिष्टि | diṣṭi | noun stem, f | direction | i-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.4 | Śākuntalam |
| 134 | रहस् | rahas | noun stem, n | a lonely or deserted place, loneliness, solitude, privacy, secrecy, re | as-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.5 | Śākuntalam |
| 135 | श्रिया | śriyā | noun stem, f | happiness; glory; prosperity | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.12 | Śākuntalam |
| 136 | स्रोतस् | srotas | noun stem, n | river, stream, torrent, current | as-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 137 | सम्पद् | sampad | noun stem, f | success, fulfilment; condition or requisite of success | root-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.30 | Śākuntalam |
| 138 | प्रीत | prīta | adj stem | pleased, delighted, satisfied, joyful (also with locative or genitive  | a-stem | yes | Wiktionary page + head line + table; Manu 9.195 | Manusmṛti |
| 139 | त्यक्त | tyakta | adj  | abandoned | a-stem | yes | Wiktionary page + head line + table; YS 2.34 | Yoga Sūtra |
| 140 | तीर्ण | tīrṇa | adj  | one who has crossed, gone over, got through, escaped | a-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 141 | हारिण | hāriṇa | noun stem, n | venison; flesh of deer | a-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.5 | Śākuntalam |

## sa-abstract-words (planned 90, none built; list needs 135). Rows are philosophical and psychological terms (Yoga Sūtra, Sāṅkhya, Nyāya-Vaiśeṣika, Upaniṣadic)

Candidates listed: 136

| # | Lemma | IAST | Head line (en.wiktionary) | Gloss | Stem | Table | Confirmed | Usage |
|--|--|--|--|--|--|--|--|--|
| 1 | अक्षर | akṣara | noun stem, n | syllable; the syllable om; letter; vowel; sound; word | a-stem | yes | Wiktionary page + head line + table; Manu 2.84 (as compound member) | Manusmṛti |
| 2 | अद्वैत | advaita | noun stem, n | non-duality; Advaita, a non dualistic philosophy in Hinduism. | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 3 | अनन्त | ananta | noun stem, m | an epithet of Vishnu; an epithet of Shesha; an epithet of Shiva | a-stem | yes | Wiktionary page + head line + table; YS 1.37 | Yoga Sūtra |
| 4 | अनुभूति | anubhūti | noun stem, f | perception, experience, feeling, realization | i-stem | yes | Wiktionary page + head line + table; c. 700 CE – 900 CE, Bhāgavata Purāṇa 7.1 | Bhāgavata Purāṇa 7.1 |
| 5 | अपरिग्रह | aparigraha | noun stem, m | greedlessness | a-stem | yes | Wiktionary page + head line + table; YS 2.31 | Yoga Sūtra |
| 6 | अभाव | abhāva | noun stem, m | death; not being, non-existence, absence; want; failure; destruction | a-stem | yes | Wiktionary page + head line + table; Manu 8.259 | Manusmṛti |
| 7 | अविद्या | avidyā | noun stem, f | ignorance, particularly in spiritual or religious matters | ā-stem | yes | Wiktionary page + head line + table; YS 2.5 | Yoga Sūtra |
| 8 | असत् | asat | noun stem, n | non-existence; falsehood; evil | at-stem | yes | Wiktionary page + head line + table; YS 4.12 | Yoga Sūtra |
| 9 | इन्द्रिय | indriya | noun stem, n | power, force, the quality which belongs especially to the mighty इन्द् | a-stem | yes | Wiktionary page + head line + table; YS 3.48 | Yoga Sūtra |
| 10 | ईश | īśa | noun stem, m | lord, master, ruler; one who is a master of anything; a husband | a-stem | yes | Wiktionary page + head line + table; Manu 9.245 | Manusmṛti |
| 11 | उपेक्षा | upekṣā | noun stem, f | endurance, patience; neglect, negligence, indifference, disregard | ā-stem | yes | Wiktionary page + head line + table; YS 3.24 (as compound member) | Yoga Sūtra |
| 12 | औदार्य | audārya | noun stem, n | nobility, generosity, magnanimity | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 13 | कर्मन् | karman | noun stem, n | an act, action, performance, business; work, labour, activity | an-stem | yes | Wiktionary page + head line + table; Manu 2.142 | Manusmṛti |
| 14 | कारण | kāraṇa | noun stem, n | cause, reason, factor; instrument, means; motive, origin, principle | a-stem | yes | Wiktionary page + head line + table; YS 2.29 | Yoga Sūtra |
| 15 | कार्य | kārya | noun stem, n | function, act, deed; work, business, enterprise | a-stem | yes | Wiktionary page + head line + table; Manu 2.42 | Manusmṛti |
| 16 | कैवल्य | kaivalya | noun stem, n | absolute unity | a-stem | yes | Wiktionary page + head line + table; YS 1.17 | Yoga Sūtra |
| 17 | क्षर | kṣara | adj stem | melting away, perishable | a-stem | yes | Wiktionary page + head line + table; Manu 2.78 (as compound member) | Manusmṛti |
| 18 | चित् | cit | noun stem, f | thought, intellect, spirit, soul | root-stem | yes | Wiktionary page + head line + table; Manu 2.16 | Manusmṛti |
| 19 | चित्त | citta | noun stem, n | thinking; reflecting; imagining; thought; intention, aim, wish | a-stem | yes | Wiktionary page + head line + table; YS 1.5 | Yoga Sūtra |
| 20 | चैतन्य | caitanya | noun stem, n | consciousness, intellect | a-stem | yes | Wiktionary page + head line + table; YS 1.10 (as compound member) | Yoga Sūtra |
| 21 | जीव | jīva | noun stem, m or n | life, existence; any living being, anything living | a-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.4 | Śākuntalam |
| 22 | तमस् | tamas | noun stem, n | darkness, gloom (also in plural) | as-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.8 | Śākuntalam |
| 23 | तुरीय | turīya | adj stem | fourth | a-stem | yes | Wiktionary page + head line + table; Manu 9.112 (as compound member) | Manusmṛti |
| 24 | देह | deha | noun  | body; form, figure, shape; mass, bulk | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 25 | द्रव्य | dravya | noun stem, n | lac, gum, resin | a-stem | yes | Wiktionary page + head line + table; YS 3.14 | Yoga Sūtra |
| 26 | द्वैत | dvaita | noun stem, n | duality; Dvaita, a dualistic philosophy in Hinduism. | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.2 (as compound member) | Śākuntalam |
| 27 | धारणा | dhāraṇā | noun stem, f | holding, bearing; retaining, keeping, storing; dharana, concentration | ā-stem | yes | Wiktionary page + head line + table; Manu 8.184 | Manusmṛti |
| 28 | निर्वाण | nirvāṇa | noun stem, n | blowing out, extinction, cessation, setting, vanishing, disappearance | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.7 (as compound member) | Śākuntalam |
| 29 | पदार्थ | padārtha | noun stem, m | the meaning of a word | a-stem | yes | Wiktionary page + head line + table; YS 1.44 (as compound member) | Yoga Sūtra |
| 30 | परिणाम | pariṇāma | noun stem, m | change, alteration, transformation into (instr.), development, evoluti | a-stem | yes | Wiktionary page + head line + table; YS 3.14 | Yoga Sūtra |
| 31 | पुरुष | puruṣa | noun stem, m | man, male, human being | a-stem | yes | Wiktionary page + head line + table; Manu 9.2 | Manusmṛti |
| 32 | प्रकृति | prakṛti | noun stem, f | the original or natural form or condition of anything, original or pri | i-stem | yes | Wiktionary page + head line + table; Manu 3.257 | Manusmṛti |
| 33 | प्रत्याहार | pratyāhāra | noun stem, m | withdrawal (especially of the senses from external objects) | a-stem | yes | Wiktionary page + head line + table; YS 2.54 | Yoga Sūtra |
| 34 | प्रवृत्ति | pravṛtti | noun stem, f | moving forwards, advance, progress | i-stem | yes | Wiktionary page + head line + table; Śāk. act 5, v.30 | Śākuntalam |
| 35 | प्राणायाम | prāṇāyāma | noun stem, m | pranayama | a-stem | yes | Wiktionary page + head line + table; YS 2.53 | Yoga Sūtra |
| 36 | बहुत्व | bahutva | noun stem, n | muchness, abundance, multitude; plurality, majority | a-stem | yes | Wiktionary page + head line + table; YS 1.5 | Yoga Sūtra |
| 37 | ब्रह्मन् | brahman | noun stem, n | pious effusion or utterance, outpouring of the heart in worshipping th | an-stem | yes | Wiktionary page + head line + table; Manu 2.144 | Manusmṛti |
| 38 | भ्रम | bhrama | noun stem, m | wandering or roaming about, roving over or through (comp.) Kathās. | a-stem | yes | Wiktionary page + head line + table; Manu 7.24 (as compound member) | Manusmṛti |
| 39 | मनस् | manas | noun stem, n | mind (in its widest sense as applied to all the mental powers), intell | as-stem | yes | Wiktionary page + head line + table; Manu 7.6 | Manusmṛti |
| 40 | ममता | mamatā | noun stem, f | The meaning of this term is uncertain. Possibilities include | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 41 | मुक्ति | mukti | noun stem, f | setting or becoming free, release, liberation, deliverance from (in co | i-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.23 | Śākuntalam |
| 42 | यम | yama | noun stem, m | rein; driver, charioteer; suppression, restraint | a-stem | yes | Wiktionary page + head line + table; Manu 9.303 | Manusmṛti |
| 43 | युक्ति | yukti | noun stem, f | union, junction, connection, combination | i-stem | yes | Wiktionary page + head line + table; Manu 7.197 | Manusmṛti |
| 44 | रजस् | rajas | noun stem, n | atmosphere; space between heaven and earth | as-stem | yes | Wiktionary page + head line + table; YS 2.18 | Yoga Sūtra |
| 45 | विकल्प | vikalpa | noun stem, m | an intermediate kalpa, the interval between two kalpas | a-stem | yes | Wiktionary page + head line + table; YS 1.9 | Yoga Sūtra |
| 46 | विकृति | vikṛti | noun stem, f | transformation; alteration; change; modification; variation | i-stem | yes | Wiktionary page + head line + table; Śāk. act 2, v.5 (as compound member) | Śākuntalam |
| 47 | संसार | saṃsāra | noun stem, m | going or wandering through, undergoing transmigration; samsara | a-stem | yes | Wiktionary page + head line + table; YS 4.34 | Yoga Sūtra |
| 48 | सत् | sat | noun stem, m | a being; (in the plural) beings, creatures | at-stem | yes | Wiktionary page + head line + table; Meghadūta | Meghadūta |
| 49 | सत्त्व | sattva | noun stem, n | essence; goodness; spirit; existence; being, entity, creature; reality | a-stem | yes | Wiktionary page + head line + table; YS 2.6 | Yoga Sūtra |
| 50 | समवाय | samavāya | noun stem, m | coming together, contact, congress, crowd (GṛS., Gaut., Mn.) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 7, v.26 (as compound member) | Śākuntalam |
| 51 | समाधि | samādhi | noun stem, m | putting together, joining or combining with (+ instrumental) | i-stem | yes | Wiktionary page + head line + table; YS 1.18 | Yoga Sūtra |
| 52 | साधन | sādhana | noun stem, n | the act of mastering, overpowering, subduing | a-stem | yes | Wiktionary page + head line + table; YS 3.5 | Yoga Sūtra |
| 53 | साध्य | sādhya | noun stem, m | "they that are to be propitiated", i.e. Sādhyas, a class of celestial  | a-stem | yes | Wiktionary page + head line + table; Manu 3.195 (as compound member) | Manusmṛti |
| 54 | सिद्ध | siddha | adj stem | proven; accomplished; prepared (of food) | a-stem | yes | Wiktionary page + head line + table; Manu 3.84 | Manusmṛti |
| 55 | सिद्धि | siddhi | noun stem, f | success, perfection, attainment, determination, substantiation | i-stem | yes | Wiktionary page + head line + table; YS 2.28 | Yoga Sūtra |
| 56 | सुख | sukha | noun stem, m | name of a man; a kind of military array, compare दण्ड (daṇḍa) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.7 | Śākuntalam |
| 57 | सृष्टि | sṛṣṭi | noun stem, f | emission, distribution; creation (abstract and concrete) | i-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.1 | Śākuntalam |
| 58 | स्थिति | sthiti | noun stem, f | standing upright or firmly, not falling | i-stem | yes | Wiktionary page + head line + table; Manu 2.224 | Manusmṛti |
| 59 | स्मरण | smaraṇa | noun stem, n | remembrance, memory; tradition; recalling | a-stem | yes | Wiktionary page + head line + table; YS 3.15 | Yoga Sūtra |
| 60 | स्मृति | smṛti | noun stem, f | remembrance, reminiscence, thinking of or upon (+locative or compound) | i-stem | yes | Wiktionary page + head line + table; Manu 2.90 | Manusmṛti |
| 61 | स्वरूप | svarūpa | noun stem, n | own condition, peculiarity, character, nature | a-stem | yes | Wiktionary page + head line + table; YS 1.10 | Yoga Sūtra |
| 62 | हेतु | hetu | noun stem, m | "impulse", motive, cause, cause of, reason for (+locative, rarely dati | u-stem | yes | Wiktionary page + head line + table; Manu 8.3 | Manusmṛti |
| 63 | योगिन् | yogin | noun stem, m | Yogi, one who practises Yoga | in-stem | yes | Wiktionary page + head line + table; YS 1.28 | Yoga Sūtra |
| 64 | प्रज्ञ | prajña | adj stem | synonym of प्रज्ञू (prajñū); wise, prudent (MāṇḍUp.) | a-stem | yes | Wiktionary page + head line + table; Manu 2.99 | Manusmṛti |
| 65 | जन्मन् | janman | noun stem, n | birth, production, origin; existence, life; nativity (VarBṛS. 1, 10) | an-stem | yes | Wiktionary page + head line + table; Manu 2.150 | Manusmṛti |
| 66 | क्रम | krama | noun stem, m | a step; going, progress, proceeding; route, path, way; the foot | a-stem | yes | Wiktionary page + head line + table; YS 3.16 | Yoga Sūtra |
| 67 | सूक्ष्म | sūkṣma | adj  | acute, subtle, keen (understanding or mental operation) | a-stem | yes | Wiktionary page + head line + table; YS 2.10 | Yoga Sūtra |
| 68 | निरोध | nirodha | noun stem, m | confinement; control | a-stem | yes | Wiktionary page + head line + table; YS 3.14 | Yoga Sūtra |
| 69 | ध्रुव | dhruva | adj stem | fixed, immovable; firm, stable; certain, sure, wis | a-stem | yes | Wiktionary page + head line + table; Manu 3.60 | Manusmṛti |
| 70 | परमाणु | paramāṇu | noun stem, m | atom; an infinitesimal particle | u-stem | yes | Wiktionary page + head line + table; YS 3.45 | Yoga Sūtra |
| 71 | मरण | maraṇa | noun stem, n | the act of dying; death; dying by; passing away | a-stem | yes | Wiktionary page + head line + table; YS 2.14 | Yoga Sūtra |
| 72 | शुद्ध | śuddha | adj stem | pure; clear; clean; true; blameless; acquitted; right | a-stem | yes | Wiktionary page + head line + table; YS 1.30 | Yoga Sūtra |
| 73 | ऐश्वर्य | aiśvarya | noun stem, n | supremacy, power, sovereignty; the state of being a mighty lord | a-stem | yes | Wiktionary page + head line + table; YS 1.16 | Yoga Sūtra |
| 74 | लिङ्ग | liṅga | noun stem, n | mark, spot, sign, token, badge, form, emblem, characteristic, represen | a-stem | yes | Wiktionary page + head line + table; YS 3.14 | Yoga Sūtra |
| 75 | अवस्था | avasthā | noun stem, f | condition, state; female reproductive organs; an appearance in court | ā-stem | yes | Wiktionary page + head line + table; YS 3.14 | Yoga Sūtra |
| 76 | व्यक्ति | vyakti | noun stem, f | visible appearance or manifestation, becoming evident or known or publ | i-stem | yes | Wiktionary page + head line + table; YS 3.16 | Yoga Sūtra |
| 77 | अमल | amala | noun stem, m | crystal | a-stem | yes | Wiktionary page + head line + table; YS 2.28 | Yoga Sūtra |
| 78 | द्वेषस् | dveṣas | noun stem, n | hatred, dislike, hostility | as-stem | yes | Wiktionary page + head line + table; YS 2.8 | Yoga Sūtra |
| 79 | चेतना | cetanā | noun stem, f | consciousness, understanding, sense, intelligence | ā-stem | yes | Wiktionary page + head line + table; Meghadūta (as compound member) | Meghadūta |
| 80 | विशेषण | viśeṣaṇa | noun stem, n | the act of distinguishing, distinction, discrimination, particularisat | a-stem | yes | Wiktionary page + head line + table; YS 2.21 (as compound member) | Yoga Sūtra |
| 81 | बोधि | bodhi | noun stem, m | (Buddhism, Jainism) bodhi: perfect knowledge or wisdom (by which a man | i-stem | yes | Wiktionary page + head line + table; Śāk. act 1, v.5 (as compound member) | Śākuntalam |
| 82 | रहस्य | rahasya | noun stem, n | a secret, any secret doctrine or mystery, any subtle or recondite poin | a-stem | yes | Wiktionary page + head line + table; Manu 2.140 (as compound member) | Manusmṛti |
| 83 | ब्रह्मविद्या | brahmavidyā | noun stem, f | knowledge of Brahman, the all-spirit, sacred knowledge | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 84 | ज्ञानकाण्ड | jñānakāṇḍa | noun stem, n | department of Vedic knowledge which relates to understanding of the wo | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 85 | कर्मकाण्ड | karmakāṇḍa | noun stem, n | department of Vedic knowledge which relates to sacrifices and ceremoni | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 86 | अन्तर्यामिन् | antaryāmin | noun stem, m | inner guide, regulator; soul | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 87 | महात्मन् | mahātman | noun stem, m | the Supreme Spirit | an-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 88 | विद् | vid | noun stem, m | Mercury | root-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 89 | आस्तिक | āstika | adj stem | one who believes in the existence (of God, of another world, etc.) | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 90 | मनन | manana | noun stem, n | thinking , reflection , meditation , thought , intelligence | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 91 | अस्तित्व | astitva | noun stem, n | existence, reality | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 92 | ज्ञानिन् | jñānin | noun stem, m | a fortune-teller, astrologer; ‘possessing religious wisdom’, a sage | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 93 | साक्षात्कार | sākṣātkāra | noun stem, m | evident or intuitive perception; realization | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 94 | धर्मता | dharmatā | noun stem, f | essence, inherent nature; the being law or right | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 95 | संयमिन् | saṃyamin | adj stem | practicing self-control | in-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 96 | शुश्रूषा | śuśrūṣā | noun stem, f | desire or wish to hear; service, attendance; dutifulness, obedience | ā-stem | yes | Wiktionary page + head line + table; Manu 2.112 | Manusmṛti |
| 97 | ऊह | ūha | noun stem, m | removing, derangement, transposition, change, modification | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 98 | विसर्ग | visarga | noun stem, m | liberation, freedom, letting go; sending forth, emission, discharge | a-stem | yes | Wiktionary page + head line + table; Manu 9.46 (as compound member) | Manusmṛti |
| 99 | विमुक्ति | vimukti | noun stem, f | release, liberation | i-stem | yes | Wiktionary page + head line + table; YS 2.28 | Yoga Sūtra |
| 100 | मोचन | mocana | noun stem, n | release, liberation, freeing or delivering from | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 101 | आस्तिक्य | āstikya | noun stem, n | piousness, religiousness, faith in God; devotion to God | a-stem | yes | Wiktionary page + head line + table; c. 400 BCE, Bhagavad Gītā 18.42 | Bhagavad Gītā 18.42 |
| 102 | नैराश्य | nairāśya | noun stem, n | hopelessness, despair, sorrow | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 103 | तृषा | tṛṣā | noun stem, f | thirst, hunger, desire | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 104 | अनित्यता | anityatā | noun stem, f | transient or limited existence | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 105 | अकारण | akāraṇa | noun stem, n | absence of a cause | a-stem | yes | Wiktionary page + head line + table; Manu 3.157 | Manusmṛti |
| 106 | आत्मवत् | ātmavat | adj stem | having a soul, soulful; “having/possessing the self” | vat-stem | yes | Wiktionary page + head line + table; Manu 7.52 | Manusmṛti |
| 107 | अनुबन्ध | anubandha | noun stem, m | binding, connection, attachment | a-stem | yes | Wiktionary page + head line + table; Manu 8.126 (as compound member) | Manusmṛti |
| 108 | प्रसङ्ग | prasaṅga | noun stem, m | adherence, attachment, inclination or devotion to, indulgence in, fond | a-stem | yes | Wiktionary page + head line + table; Manu 9.5 | Manusmṛti |
| 109 | आकाङ्क्षा | ākāṅkṣā | noun stem, f | desire, wish | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 110 | विवक्षा | vivakṣā | noun stem, f | the desire to speak | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 111 | अवित्ति | avitti | noun stem, f | act of not finding; lack, poverty | i-stem | yes | Wiktionary page + head line + table; c. 1200 BCE – 1000 BCE, Atharvaveda 16.6 | Atharvaveda 16.6 |
| 112 | कृत्स्न | kṛtsna | noun stem, n | total fixation of the mind, leading to contemplation | a-stem | yes | Wiktionary page + head line + table; Manu 2.165 (as compound member) | Manusmṛti |
| 113 | वयुन | vayuna | noun stem, n | wisdom; knowledge | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 114 | सुनीत | sunīta | noun stem, n | good or wise conduct, wisdom, prudence | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 115 | मृड | mṛḍa | adj  | showing compassion or mercy, gracious | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 116 | ह्लाद | hlāda | noun stem, m | joy, gladness, pleasure | a-stem | yes | Wiktionary page + head line + table; YS 1.18 (as compound member) | Yoga Sūtra |
| 117 | नन्दि | nandi | noun stem, m | joy, pleasure, delight; an epithet of Shiva and Vishnu | i-stem | yes | Wiktionary page + head line + table; Śāk. act 3, v.11 (as compound member) | Śākuntalam |
| 118 | जिह्म | jihma | noun stem, n | falsehood, dishonesty | a-stem | yes | Wiktionary page + head line + table; Manu 3.246 (as compound member) | Manusmṛti |
| 119 | भवक्षय | bhavakṣaya | noun stem, m | end of existence | a-stem | yes | Wiktionary page + head line + table; 900-1100 AD; copied later, Arlo Griffith | Arlo Griffith |
| 120 | आत्मभाव | ātmabhāva | noun stem, m | existence of the soul; self-essence; the body | a-stem | yes | Wiktionary page + head line + table; YS 2.40 (as compound member) | Yoga Sūtra |
| 121 | उद्देश | uddeśa | noun stem, m | the act of pointing to or at, direction; ascertainment | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 122 | निमित्त | nimitta | noun stem, n | aim, mark; sign, token; omen; cause, occasion; motive, instrument | a-stem | yes | Wiktionary page + head line + table; YS 4.13 | Yoga Sūtra |
| 123 | अनिन्द्रिय | anindriya | noun stem, n | "that which is not a sense" the mind; the soul; reason | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 124 | मानस | mānasa | noun stem, n | the mental powers, mind, spirit; tacit or implied consent | a-stem | yes | Wiktionary page + head line + table; Manu 2.85 (as compound member) | Manusmṛti |
| 125 | वैज्ञानिक | vaijñānika | adj stem | rich in knowledge, proficient | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 126 | शङ्क | śaṅka | noun stem, m | doubt; fear; name of a king(Buddh.) | a-stem | yes | Wiktionary page + head line + table; Śāk. act 6, v.4 | Śākuntalam |
| 127 | सुमति | sumati | noun stem, f | good mind or disposition, benevolence, kindness, favour (acc. with √ क | i-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 128 | दुर्मनस् | durmanas | noun stem, n | bad disposition, perversity of mind | as-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 129 | चिच्छक्ति | cicchakti | noun stem, f | thinking capacity of the mind | i-stem | yes | Wiktionary page + head line + table; c. 700 CE – 900 CE, Bhāgavata Purāṇa 1.7 | Bhāgavata Purāṇa 1.7 |
| 130 | कृति | kṛti | noun stem, f | the act of doing, making, performing, manufacturing, composing | i-stem | yes | Wiktionary page + head line + table; Manu 9.69 | Manusmṛti |
| 131 | वर्तमान | vartamāna | adj stem | turning, moving, existing, living, abiding; present | a-stem | yes | Wiktionary page + head line + table; YS 3.53 | Yoga Sūtra |
| 132 | आवेश | āveśa | noun stem, m | joining one's self; entering, entrance, taking possession of | a-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 133 | षड्रिपु | ṣaḍripu | noun stem, m | The "Six Enemies", six harmful states of mind that stop people from at | u-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 134 | कर्तृवाद | kartṛvāda | noun stem, m | doctrine or ideology of belief in a creator | a-stem | yes | Wiktionary page + head line + table; Dharmakīrti, Pramāṇavārttika | Pramāṇavārttika |
| 135 | अक्षुण्णता | akṣuṇṇatā | noun stem, f | the state of being unbroken or continuous; continuity | ā-stem | yes | Wiktionary page + head line + table | (Wiktionary entry only; no corpus hit) |
| 136 | स्थिरता | sthiratā | noun stem, f | stability; firmness; tranquility; permanence; hardness | ā-stem | yes | Wiktionary page + head line + table; Śāk. act 4, v.15 | Śākuntalam |

