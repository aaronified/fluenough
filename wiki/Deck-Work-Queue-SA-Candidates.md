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


