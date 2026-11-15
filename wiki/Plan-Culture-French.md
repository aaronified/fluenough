# Plan: French genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations, situations)

Task FR-001 of [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md), written 2026-11-15 in the shape of [Plan-Culture-Spanish](Plan-Culture-Spanish.md) and [Plan-Culture-Japanese](Plan-Culture-Japanese.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, for the tasks FR-060 to FR-063 (culture), FR-070 to FR-072 (proverbs), FR-080 to FR-083 (multi-word verbs), FR-090 and FR-091 (situations), FR-100 and FR-101 (recommendations). The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md); the shapes are in [Deck-Format](Deck-Format.md), "Deck kinds, levels, hidden decks, sources, creators and topics" and "Situations files".

French runs in its own session by the owner's instruction of 2026-11-15, which overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md) for French.

**Nothing on this page is a checked fact.** Every work below is a *candidate*. No date, lifespan, text or rights status has been read or verified by the author of this page; the names come from general knowledge and are there to be read, not trusted. The column "Rights basis, dates and text" is **to be read** in every row: the Haiku builder reads the work's or author's Wikipedia page (fr.wikipedia first, en.wikipedia second) and, for a text, the Wikisource edition it cites (fr.wikisource), fills the column in its report, and drops any candidate whose dates or text it could not read, replacing it from the reserve. Nothing is filled in from memory. If this page and a task row of the queue differ, this page wins.

## Rights rule for France

What the validator enforces (read from `tools/validate_decks.py` on main, 2026-11-15; nothing was run):

| Rule | Value in the code |
|---|---|
| Table | `PD_TERMS = {"IN": 60, "BD": 60, "ES": 70, "FR": 70, "JP": 70, "CN": 50}`; `PD_DEFAULT_TERM = 70` (any other jurisdiction) |
| Named author | `public_domain_problem` fails a source when `author_died + term >= this year`. For `jurisdiction: "FR"` (term 70) in 2026 the author must have died in **1955 or earlier** (1955 + 70 = 2025 < 2026; 1956 + 70 = 2026 fails). The year is read from the clock, so in 2027 a death in 1956 passes; builders use the year the task runs in |
| Anonymous work | `author: "anonymous"` needs `date` (a year, `c. YEAR` or `A-B` that `parse_years` accepts) with its first year **before 1900**, and its last year + 70 before this year |
| Anything else | `public-domain` with neither `author_died` nor anonymous authorship is an error |
| Jurisdiction | `jurisdiction` is an ISO 3166-1 alpha-2 code: `"FR"` for a French author, `"BE"`, `"CH"`, `"CA"` for others; a code missing from the table takes the default 70 |
| Quotation | `basis: "quotation"` is limited to 25 words and 5 cards a deck. This queue uses no `quotation` items |

What French law says, **as the plan understands it and not as legal advice** (the reviewer owns the legal opinion, the validator floor only catches typos): the term is the author's life plus 70 years. French law also adds extra years in some cases: a wartime prolongation for works published before 1948, and a further 30 years for an author recognised as "mort pour la France". The validator does not know about either. So the mechanical floor can pass a work that French law still protects. The builder's rule is therefore stricter than the validator:

1. The author must have died in 1955 or earlier (this year's floor), **and** the builder must have read nothing on the author's or work's page (fr.wikipedia, fr.wikisource licence note) that says the work is still protected, or that the author is "mort pour la France" or died in a war, a camp or a deportation. If it says so, the item goes to the reserve with a review-queue row.
2. An anonymous work needs a first publication before 1900 (validator rule) read from a cited page.
3. A work between the floor and a doubt goes to the reserve with a row, never into a deck.
4. Authors who died in 1951 to 1955 are near the line: the builder reads the exact year and writes it in `author_died`; a year it could not read drops the item.
5. A work that is not public domain is never a culture card. It may be a recommendation (source-yourself, below), where nothing of it is shipped.

Authors the plan names as needing a particular care (all **to be read**, none asserted): Saint-Exupéry (died 1944, killed in the war: the validator would accept the number, French law very probably does not, so he is **not** a culture candidate; *Le Petit Prince* is a recommendation); Apollinaire, Péguy and Alain-Fournier (died during the First World War: the "mort pour la France" question applies, so each is a reserve item unless the page settles it); Proust (died 1922, well inside the floor, a normal candidate); Colette (died 1954), Éluard (died 1952), Gide and Alain (died 1951) are near the line.

## Rules applied

- **Basis `public-domain` only, no `quotation` items.** The `source` block is as in the Spanish and Japanese batches: `author`, `work`, `date`, `edition`, `url`, `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **One excerpt per card**: one verse, one sentence or one line, at most 25 words. The validator enforces 25 words only for `quotation`; for a public-domain card the 25-word cap is this plan's rule (a discrepancy recorded in [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md), section 5). Where the cited edition's spelling is archaic (Old French, sixteenth-century spelling) the text is shown in modern spelling and the `edition` field says so; for a work in Old or Middle French the item is dropped unless the builder can cite a modern-French edition it read.
- **18 items per deck, short items first**, level A2 or B1 per item. The first 18 candidates that pass are the deck; the rest are the reserve. Fewer than 18 may pass: the report says so, the deck is never padded.
- **Dates are never guessed.** `date` takes a shape `parse_years` accepts; an uncertain year is `circa` on a creator; explanations go in notes. Every unread or uncertain item goes to `docs/review-queue/fr.md` (through the builder's report and task FR-130 to FR-132).
- **Translations** are the builder's own plain renderings, never a quotation of anyone's translation.
- **Creators** (file `decks/creators/fr.yaml`, created by FR-060): `born` and `died` a plain year or `{ year, circa: true }` (never `circa: false`); `source.author` of a card equals the creator's exact `name.en.text`; a short A2-level English bio; an `era` of the file's own `eras`; `legacy` with 1 to 6 items, each with a `kind` (one of `curriculum`, `festival`, `film`, `music`, `saying`, `commemoration`, `adaptation`, `place`, `other`), `text` and a `source`; no image; a living creator has `born` and no `died` (or `living: true`).
- **Order of work.** FR-060 to FR-063 run one after another on one shared branch because they share `creators/fr.yaml`; the recommendations (FR-100, FR-101) come after them on the same file. Proverbs, multi-word decks, situations and topics are independent of that lane.
- **French conventions.** Latin script, no `reading`; broad `ipa` as the existing French decks write it; no `phonetic` (FR-123 writes it); header `language: { code: "fr", iso639_3: "fra", name: "French", script: "latin", tts: "fr-FR", icon: "Fr" }`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`. The full convention list is [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md), section 3.
- **Politeness to the sources (HTTP 429).** In earlier Telugu and Spanish runs en.wikipedia, te.wikipedia and te.wikisource answered 429 and whole decks were dropped unverified. A French builder reads with `curl` only, **one request every 15 to 20 seconds**, honours any `Retry-After` header, never retries in a tight loop, and never runs reads in parallel with another worker. It reads each page once and keeps the text it needs in its scratch notes. What it cannot verify after a polite retry is **dropped**, never guessed and never padded; the deck ships short and the report says so.
- **Review-queue rule.** Everything is `unreviewed`. Each unread, uncertain or dropped item is a row in the builder's report, in the table shape of `docs/review-queue/fr.md` (`card id | unit | question for the reviewer | raised by | date`); only the FR-130 to FR-132 tasks write that file. No bilingual reviewer is named (owner, 2026-11-13: decks ship unreviewed and are reviewed through the app).

## Culture decks (FR-060 to FR-063, 4 x 18 plus reserves)

Columns: order in the deck, candidate work, creator. "Rights basis, dates and text: to be read" applies to every row and is not repeated.

### FR-060, `fr-culture-1`: the Middle Ages and the Renaissance (ids fr-4100 to 4149)

Old French texts are dropped unless a modern-French edition was read; Renaissance texts are shown in modern spelling where the edition says so.

| # | Candidate work | Creator |
|---|---|---|
| 1 | Chanson de Roland, opening laisse, in a modern-French rendering the builder can cite | anonymous |
| 2 | Ballade des dames du temps jadis ("Mais où sont les neiges d'antan ?") | François Villon |
| 3 | Ballade des pendus ("Frères humains qui après nous vivez") | François Villon |
| 4 | Gargantua, a short line from chapter 1 or the Abbaye de Thélème motto "Fais ce que voudras" | François Rabelais |
| 5 | Heureux qui, comme Ulysse (Les Regrets) | Joachim du Bellay |
| 6 | Mignonne, allons voir si la rose | Pierre de Ronsard |
| 7 | Sonnet, "Je vis, je meurs" | Louise Labé |
| 8 | A rondeau or an epigram, in modern spelling | Clément Marot |
| 9 | Essais, "Que philosopher, c'est apprendre à mourir" or "Parce que c'était lui, parce que c'était moi" | Michel de Montaigne |
| 10 | Le temps a laissié son manteau (rondeau) | Charles d'Orléans |
| 11 | Seulete sui (ballade) | Christine de Pizan |
| 12 | La complainte Rutebeuf | Rutebeuf |
| 13 | Lais, a short line | Marie de France |
| 14 | Perceval or Yvain, a short line in a modern edition | Chrétien de Troyes |
| 15 | Le Roman de la Rose, a short line in a modern edition | Guillaume de Lorris |
| 16 | Aucassin et Nicolette, a short line in a modern edition | anonymous |
| 17 | La Farce de maître Pathelin, a short line in a modern edition | anonymous |
| 18 | Sonnets pour Hélène, "Quand vous serez bien vieille" | Pierre de Ronsard |

Reserve: Du Bellay (Les Antiquités de Rome), Maurice Scève (Délie), Agrippa d'Aubigné (Les Tragiques), Roman de Renart, Tristan et Iseut. This task creates `decks/creators/fr.yaml` (`kind: "creators"`, `id: "creators-fr"`, `language: "fr"`, `license: "CC-BY-SA-4.0"`) with its eras (Moyen Âge, Renaissance, Grand Siècle and Lumières, XIXe siècle, XXe siècle, XXIe siècle, each with `name` in `fr` and `en`, `from` and `to` as the Spanish file does) and the creators of its 18 items. `name` per creator has `fr: { text, ipa }` and `en: { text }` with the same text.

### FR-061, `fr-culture-2`: the seventeenth and eighteenth centuries (fr-4150 to 4199)

| # | Candidate work | Creator |
|---|---|---|
| 1 | Le Corbeau et le Renard, opening (Fables) | Jean de La Fontaine |
| 2 | La Cigale et la Fourmi, opening | Jean de La Fontaine |
| 3 | Le Lièvre et la Tortue, "Rien ne sert de courir" | Jean de La Fontaine |
| 4 | Le Loup et l'Agneau, "La raison du plus fort est toujours la meilleure" | Jean de La Fontaine |
| 5 | Le Bourgeois gentilhomme, "Il y a plus de quarante ans que je dis de la prose" | Molière |
| 6 | Le Malade imaginaire or Tartuffe, one line | Molière |
| 7 | Phèdre, "C'est Vénus tout entière à sa proie attachée" | Jean Racine |
| 8 | Le Cid, "Va, je ne te hais point" or "À vaincre sans péril, on triomphe sans gloire" | Pierre Corneille |
| 9 | Pensées, "Le cœur a ses raisons que la raison ne connaît point" | Blaise Pascal |
| 10 | Pensées, "Le silence éternel de ces espaces infinis m'effraie" | Blaise Pascal |
| 11 | Maximes, one maxim | La Rochefoucauld |
| 12 | A letter, one sentence | Madame de Sévigné |
| 13 | Candide, "Il faut cultiver notre jardin" | Voltaire |
| 14 | Du contrat social, "L'homme est né libre, et partout il est dans les fers" | Jean-Jacques Rousseau |
| 15 | Art poétique, "Ce qui se conçoit bien s'énonce clairement" | Nicolas Boileau |
| 16 | Les Caractères, one remark | La Bruyère |
| 17 | Le Mariage de Figaro, one line | Beaumarchais |
| 18 | Le Jeu de l'amour et du hasard, one line | Marivaux |

Reserve: Diderot (Jacques le fataliste, Le Neveu de Rameau), Montesquieu (Lettres persanes, De l'esprit des lois), La Princesse de Clèves (Madame de La Fayette), André Chénier (La Jeune Captive), Vauvenargues. Adds only creators and eras not yet in the file.

### FR-062, `fr-culture-3`: the nineteenth century (fr-4200 to 4249)

| # | Candidate work | Creator |
|---|---|---|
| 1 | Demain, dès l'aube | Victor Hugo |
| 2 | Les Misérables, one sentence | Victor Hugo |
| 3 | Le Lac, "Ainsi, toujours poussés vers de nouveaux rivages" | Alphonse de Lamartine |
| 4 | Ballade à la lune or La Nuit de mai, one line | Alfred de Musset |
| 5 | El Desdichado, "Je suis le ténébreux, le veuf, l'inconsolé" | Gérard de Nerval |
| 6 | L'Albatros | Charles Baudelaire |
| 7 | Invitation au voyage, "Là, tout n'est qu'ordre et beauté" | Charles Baudelaire |
| 8 | Chanson d'automne, "Les sanglots longs des violons de l'automne" | Paul Verlaine |
| 9 | Le Dormeur du val | Arthur Rimbaud |
| 10 | Brise marine, "La chair est triste, hélas ! et j'ai lu tous les livres" | Stéphane Mallarmé |
| 11 | Madame Bovary, one sentence | Gustave Flaubert |
| 12 | La Parure, one sentence | Guy de Maupassant |
| 13 | J'accuse, "J'accuse" line | Émile Zola |
| 14 | Le Père Goriot, one sentence | Honoré de Balzac |
| 15 | Le Rouge et le Noir, one sentence | Stendhal |
| 16 | Le Comte de Monte-Cristo, "Attendre et espérer" | Alexandre Dumas |
| 17 | Vingt mille lieues sous les mers, one sentence | Jules Verne |
| 18 | La Mort du loup, one line | Alfred de Vigny |

Reserve: Théophile Gautier, Leconte de Lisle, José-Maria de Heredia, Jules Renard (Poil de Carotte), George Sand, Victor Hugo (a second poem), Alphonse Daudet (Lettres de mon moulin).

### FR-063, `fr-culture-4`: traditional songs and tales before 1900, and the early twentieth century (fr-4250 to 4299)

A song or text whose author or first printing the builder cannot show goes to the reserve. A traditional piece with no named author uses `author: "anonymous"`, which needs a date before 1900 read from a cited page. The plan expects fewer than 18 to pass; the report says so.

| # | Candidate work | Creator |
|---|---|---|
| 1 | Frère Jacques | traditional |
| 2 | Au clair de la lune | traditional |
| 3 | Sur le pont d'Avignon | traditional |
| 4 | À la claire fontaine | traditional |
| 5 | Alouette, gentille alouette | traditional |
| 6 | Il était un petit navire | traditional |
| 7 | Il pleut, il pleut, bergère | Fabre d'Églantine |
| 8 | La Marseillaise, first couplet | Claude Joseph Rouget de Lisle |
| 9 | Le Temps des cerises | Jean-Baptiste Clément |
| 10 | Le Petit Chaperon rouge, opening (Contes) | Charles Perrault |
| 11 | Cendrillon, opening | Charles Perrault |
| 12 | La Belle au bois dormant, opening | Charles Perrault |
| 13 | Le Chat botté, opening | Charles Perrault |
| 14 | Le Pont Mirabeau, "Sous le pont Mirabeau coule la Seine" (rights: war-death question, to be read) | Guillaume Apollinaire |
| 15 | À la recherche du temps perdu, the madeleine sentence | Marcel Proust |
| 16 | Le Crime de Sylvestre Bonnard, one sentence | Anatole France |
| 17 | A passage of prose or verse (rights: war-death question, to be read) | Charles Péguy |
| 18 | Sido or La Maison de Claudine, one sentence (died 1954, near the line) | Colette |

Reserve: Une souris verte, Ah ! vous dirai-je, maman, Alain-Fournier (Le Grand Meaulnes), André Gide, Paul Valéry, Paul Éluard, Romain Rolland. Excluded by this page: Saint-Exupéry (see the rights rule).

## Proverbs (FR-070 to FR-072, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1` and `es-proverbs-1`. The `source` block has `author` (`"anonymous"`), `collection`, `date` (the collection's own), `edition`, `url`, `basis`, `jurisdiction: "FR"`, `rights_checked`. Each card carries a note (`id: "literal"`, `kind: "note"`) with the literal meaning and the plain meaning, a card `register` (one of `formal`, `neutral`, `informal`, `slang`, `offensive`), `modes: ["recognition", "listening"]`, level A2 or B1. Sources the builder cites with page and date: fr.wiktionary "Annexe:Proverbes français" or "Proverbes en français", fr.wikiquote "Proverbes français" and fr.wikipedia "Proverbe", or a Wikisource collection it can read. **A proverb whose text the builder did not read on the cited page is dropped.** No proverb is listed here: the page names themes only, and the builder chooses short, well-known proverbs it can read.

| Task | Deck | Themes, in order | Ids |
|---|---|---|---|
| FR-070 | `fr-proverbs-1` | weather and seasons, food and drink, money, friends, family, work, animals, time | fr-4300 to 4349 |
| FR-071 | `fr-proverbs-2` | health, patience, luck, speech and silence, learning, the home, the countryside, justice | fr-4350 to 4399 |
| FR-072 | `fr-proverbs-3` | love, age, neighbours, travel, honesty, effort, appearances, sayings with a place or a saint | fr-4400 to 4449 |

FR-071 and FR-072 list the earlier decks' targets first and use none of them again.

## Multi-word verbs (FR-080 to FR-083, 4 x 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part; parts already taught are written by `ref`, a part not yet a card gets a card. The shape is `es-multiword-pronominal` and `ja-multiword-te-auxiliaries`. These lists are the plan's candidate selections; a pattern the builder cannot support on a page it read is reported, not replaced from memory.

| Task | Deck and `pattern_family` | Candidates | Ids |
|---|---|---|---|
| FR-080 | `fr-multiword-pronominal`, `pronominal-verb` | se lever, se coucher, se réveiller, s'habiller, se laver, se promener, se dépêcher, se souvenir de, s'asseoir, se tromper, s'appeler, se rappeler, se sentir, se fâcher, se reposer, s'amuser, s'inquiéter, se marier, s'occuper de, s'en aller | fr-4450 to 4499 |
| FR-081 | `fr-multiword-verb-preposition`, `verb-preposition` | penser à, parler de, rêver de, dépendre de, avoir besoin de, avoir envie de, avoir peur de, se servir de, jouer à, jouer de, croire à, croire en, compter sur, s'intéresser à, réussir à, commencer à, commencer par, finir par, essayer de, apprendre à | fr-4500 to 4549 |
| FR-082 | `fr-multiword-idioms`, `idiomatic-expression` | avoir le cafard, poser un lapin, coûter les yeux de la tête, tomber dans les pommes, avoir la main verte, casser les pieds, mettre les pieds dans le plat, il pleut des cordes, avoir un chat dans la gorge, faire la grasse matinée, avoir le coup de foudre, donner sa langue au chat, prendre ses jambes à son cou, revenir à ses moutons, appeler un chat un chat, en avoir marre, tourner autour du pot, chercher midi à quatorze heures, se mettre sur son trente et un, ça marche | fr-4550 to 4599 |
| FR-083 | `fr-multiword-light-verbs`, `light-verb-idiom` | faire attention, faire la queue, faire connaissance, faire la cuisine, faire une promenade, avoir faim, avoir raison, avoir tort, avoir mal à, avoir l'air, prendre un bain, prendre rendez-vous, prendre une décision, prendre soin de, mettre la table, mettre du temps, donner rendez-vous, donner envie, tenir compte de, rendre visite à | fr-4600 to 4649 |

FR-082: an idiom's literal reading and its real meaning both go in the note (`usage`), the register is `informal` unless the page says otherwise, and an idiom the builder cannot find with its meaning on fr.wiktionary is dropped.

## Recommendations (FR-100 and FR-101, 10 + 10)

File `decks/recommendations/fr.yaml`, in the shape of `recommendations/es.yaml` and `recommendations/ja.yaml`: `kind: "recommendations"`, `id: "recommendations-fr"`, `language: "fr"`, each entry `id: "fr-rec-<name>"`, `medium`, `title { text }`, `creator` (ids of `creators/fr.yaml`), `year`, `level`, `briefing { en }` in the builder's own words, 3 questions each that only someone who watched, read or heard the work could answer (`{ id: "q1", prompt: { en }, options: { en: [...] }, answer: <1-based number> }`), `tags: ["unreviewed"]`. A book names `script: "latin"` (the validator requires a script on a book). No quotation and no link. These are works the learner sources themselves (`basis: source-yourself` of [Plan-Language-Completeness](Plan-Language-Completeness.md)), so rights are not a gate here; year and creator are **to be read** from the work's fr.wikipedia page, and a work whose facts the builder could not read is replaced from the reserve. Creators are added to `creators/fr.yaml` where missing, with the same bio shape. A question may not be answerable without the work.

| Task | Medium | Candidates |
|---|---|---|
| FR-100 | films and television | Le Fabuleux Destin d'Amélie Poulain (2001), Intouchables (2011), La Haine (1995), Les Quatre Cents Coups (1959), Au revoir les enfants (1987), Bienvenue chez les Ch'tis (2008), Le Dîner de cons (1998), Les Choristes (2004), Dix pour cent (series, 2015), Lupin (series, 2021). Reserve: Le Bureau des légendes (2015), Un prophète (2009), Les Visiteurs (1993), Persepolis (film, 2007) |
| FR-101 | books, comics, songs, a podcast | L'Étranger (Camus), Le Petit Prince (Saint-Exupéry), La Vie devant soi (Romain Gary as Émile Ajar), Bonjour tristesse (Françoise Sagan), Le Petit Nicolas (Goscinny and Sempé), Astérix le Gaulois (Goscinny and Uderzo, comic), Tintin: Le Lotus bleu (Hergé, comic), La Vie en rose (Édith Piaf, song), Ne me quitte pas (Jacques Brel, song), innerFrench (podcast). Reserve: Alors on danse (Stromae), Persepolis (Marjane Satrapi, comic), L'Écume des jours (Boris Vian), Radio France podcasts the builder can name |

The years are the plan's guesses, not checked by this page. FR-101's `medium` is one of `book`, `comic`, `song` or `podcast`. Deck-Format says books are recommended "only when the course includes script learning"; the validator instead requires a `script` on every book and `recommendations/es.yaml` has six, so French follows the validator and Spanish (recorded in the queue, section 5).

## Situations (FR-090 and FR-091, 10 sheets)

File `decks/fr/fr-situations.yaml` (Deck-Format "Situations files"): the header of `es-situations.yaml` with `language: { code: fr, iso639_3: fra, name: French, script: latin, tts: fr-FR, icon: "Fr" }`, `kind: situations`, `id: fr-situations`. It holds **no card text**: each sheet lists ids of real French cards in `phrases` and `words`. Each icon key is used once per file; the Spanish and Telugu files name them as in the table. Owner rule of 2026-11-12: only very widely used words and phrases, one natural phrase per idea, the common register only, a handful of phrases per scene (8 to 12 phrases and at most 12 words per sheet).

| Sheet id | `icon` | `title` (`en`, `fr`) | Task |
|---|---|---|---|
| `taxi` | `taxi` | Taxi, Taxi | FR-090 |
| `shops` | `shops` | Shops, Magasins | FR-090 |
| `eat` | `eat` | Eating out, Au restaurant | FR-090 |
| `doctor` | `doctor` | The doctor, Chez le médecin | FR-090 |
| `traffic` | `traffic` | Directions and traffic, Circulation | FR-090 |
| `rail` | `rail` | Trains, Le train | FR-090 |
| `hotel` | `hotel` | Hotel, À l'hôtel | FR-091 |
| `post-bank` | `post` | Post office and bank, La poste et la banque | FR-091 |
| `greetings` | `greeting` | Greetings and apologies, Salutations et excuses | FR-091 |
| `emergency` | `emergency` | Emergencies, Urgences | FR-091 |

`post` and `bank` are separate icon keys; the sheet takes one (as `es-situations.yaml` does with `post`). The four icons after the first six are drawn by app 0.10.3 and later (released); the validator and `tools/deck_index.py` mark the file for it. A needed phrase with no card is added as a new card at the end of the best-fit deck and its layer (at most 20 in all, ids fr-4650 to fr-4699, broad `ipa` as the French conventions say, no `phonetic`).

## Topics and facts

- **Topics** (FR-095, FR-096): `decks/fr/fr-topics.yaml`, `kind: topics`, no card text; 12 topics over the path decks (grammar, words, verbs) and 8 over the genre decks once they exist. The lists are in the queue.
- **Facts**: `decks/fr/fr-facts.yaml` already has 36 facts, so no facts task is planned.

## Not planned, and open questions for the owner

1. **Professional decks.** `professions` in `decks/sections.yaml` is empty; the owner supplies the list first.
2. **Other varieties.** The course is the French of France (owner, 2026-10-30, in the path header). No Belgian, Swiss, Québécois or African variety deck is planned. Wanted?
3. **A resources file** (`fr-resources.yaml`, as `ja-resources.yaml`) and the script and sounds files the path header mentions (`fr-script.yaml`, `fr-sounds.yaml`): not on the checklist, so not planned; added only if the owner asks.
4. **French term of copyright.** The floor for a French author is the validator's (died 1955 or earlier this year) plus the builder's stricter check above. A reviewer should confirm the legal term, in particular the wartime and "mort pour la France" extensions, before the decks ship.
