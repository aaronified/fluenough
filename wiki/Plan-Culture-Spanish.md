# Plan: Spanish genre decks, sourcing list (culture, proverbs, multi-word verbs, recommendations)

Task ES-012 of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md), written 2026-11-14 under rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md). It is the "plan before build" list that [Plan-Language-Completeness](Plan-Language-Completeness.md) asks for, in the shape of [Plan-Culture-Japanese](Plan-Culture-Japanese.md), for the tasks ES-014 to ES-024, ES-027 and ES-028. The data model is [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md).

**Nothing on this page is a checked fact.** Every work below is a *candidate*. No date, lifespan, text or rights status has been read or verified by the author of this page. The column "Rights basis" is **to be read** in every row: the Haiku builder reads the work's or author's Wikipedia page (es.wikipedia first), fills the column in its report, and drops any candidate whose dates or text it could not read, replacing it from the reserve. Nothing is filled in from memory. If this page and a task row of the plan differ, this page wins.

## Rules applied

- **Rights floor.** An author's death year must be 1955 or earlier (the validator's floor, as in the Japanese batch). For a Spanish author (`jurisdiction: "ES"`, a term of life plus 80 years for deaths before 1987, per the plan) the builder's floor is 1945 or earlier. An anonymous work needs a first publication before 1900. A work between those years goes to the reserve with a review-queue row. The floor catches typos; the reviewer owns the legal opinion. For an author from another country the builder records that country's `jurisdiction` and still applies the 1955 floor.
- **Basis `public-domain` only, no `quotation` items.** The `source` block is as in batch 1 of the Japanese culture deck: `author`, `work`, `date`, `edition`, `basis`, `author_died`, `jurisdiction`, `rights_checked`.
- **One excerpt per card**: one verse, one sentence or one line, at most 25 words. Where the cited edition's spelling is archaic the text is shown in modern spelling and the `edition` field says so.
- **18 items per deck, short items first**, each A2 or B1. The first 18 candidates that pass are the deck; the rest are the reserve. Fewer than 18 may pass: the report says so, the deck is never padded.
- **Dates are never guessed.** `date` takes a shape the validator's `parse_years` accepts (a year, `c. YEAR` or `A-B`); explanations go in notes. An uncertain year is `circa`. Every unread or uncertain item goes to `docs/review-queue/es.md`.
- **Translations** are the builder's own plain renderings, never a quotation of anyone's translation.
- **Creators** (file `decks/creators/es.yaml`, created by ES-014): a short A2-level English bio, `born` and `died` (`circa` if uncertain; a living creator has `born` and no `died`), era, one legacy line with a checkable item and a source link, no image.
- **Order of work.** ES-014 to ES-017 run one after another because they share `creators/es.yaml`; ES-027 and ES-028 come after them on the same file. Proverbs and multi-word decks are independent of that lane.
- **Spanish conventions.** Latin script, no `reading`; `ipa` from `python3 tools/transcribe.py es "<text>"`; no `phonetic` (ES-041 writes it); header `language: { code: "es", iso639_3: "spa", name: "Spanish", script: "latin", tts: "es-ES", icon: "Es" }`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`.

## Culture decks (ES-014 to ES-017, 4 x 18 plus reserves)

Columns: order in the deck, work, creator, and what the builder must read. "Rights basis, dates and text: to be read" applies to every row and is not repeated.

### ES-014, `es-culture-1`: medieval and Golden Age (ids es-4000 to 4049)

| # | Candidate work | Creator |
|---|---|---|
| 1 | Cantar de mio Cid | anonymous |
| 2 | Coplas por la muerte de su padre | Jorge Manrique |
| 3 | Lazarillo de Tormes | anonymous |
| 4 | Don Quijote, opening | Miguel de Cervantes |
| 5 | Soneto XXIII, "En tanto que de rosa y azucena" | Garcilaso de la Vega |
| 6 | Vida retirada | Fray Luis de León |
| 7 | Nada te turbe | Santa Teresa de Jesús |
| 8 | Noche oscura | San Juan de la Cruz |
| 9 | A sonnet, "Un soneto me manda hacer Violante" | Lope de Vega |
| 10 | Amor constante más allá de la muerte | Francisco de Quevedo |
| 11 | Mientras por competir con tu cabello | Luis de Góngora |
| 12 | La vida es sueño, Segismundo's monologue | Calderón de la Barca |
| 13 | Hombres necios | Sor Juana Inés de la Cruz |
| 14 | La Celestina | Fernando de Rojas |
| 15 | Libro de buen amor | Arcipreste de Hita |
| 16 | El conde Lucanor | Don Juan Manuel |
| 17 | El burlador de Sevilla | Tirso de Molina |
| 18 | A romance, Romance del conde Arnaldos | anonymous |

Reserve: Cervantes (Novelas ejemplares), Góngora (Soledades), Lope de Vega (Fuenteovejuna), Fray Luis de León (a second ode). This task creates `decks/creators/es.yaml` (`kind: "creators"`, `id: "creators-es"`, `language: "es"`) with eras (Edad Media, Siglo de Oro, Ilustración, siglo XIX, siglo XX), each with `from` and `to` read from the builder's sources, and the 18 creators.

### ES-015, `es-culture-2`: the nineteenth century, Spain and the Americas (es-4050 to 4099)

| # | Candidate work | Creator |
|---|---|---|
| 1 | Rima LIII, "Volverán las oscuras golondrinas" | Gustavo Adolfo Bécquer |
| 2 | Rima XXI, "¿Qué es poesía?" | Gustavo Adolfo Bécquer |
| 3 | En las orillas del Sar | Rosalía de Castro |
| 4 | Canción del pirata | José de Espronceda |
| 5 | Don Juan Tenorio | José Zorrilla |
| 6 | Vuelva usted mañana | Mariano José de Larra |
| 7 | Fortunata y Jacinta | Benito Pérez Galdós |
| 8 | La Regenta | Leopoldo Alas "Clarín" |
| 9 | Versos sencillos I, "Yo soy un hombre sincero" | José Martí |
| 10 | Sonatina | Rubén Darío |
| 11 | Canción de otoño en primavera | Rubén Darío |
| 12 | Silva a la agricultura de la zona tórrida | Andrés Bello |
| 13 | Martín Fierro | José Hernández |
| 14 | Tradiciones peruanas | Ricardo Palma |
| 15 | María | Jorge Isaacs |
| 16 | Nocturno III | José Asunción Silva |
| 17 | El matadero | Esteban Echeverría |
| 18 | Pepita Jiménez | Juan Valera |

Reserve: Gertrudis Gómez de Avellaneda, Emilia Pardo Bazán, Amado Nervo, Domingo F. Sarmiento (Facundo). Adds only creators and eras not yet in the file.

### ES-016, `es-culture-3`: the early twentieth century (es-4100 to 4149)

Only authors who pass the floor (Spanish authors: died 1945 or earlier; others: 1955 or earlier). The builder reads each death year and drops what fails.

| # | Candidate work | Creator |
|---|---|---|
| 1 | Proverbios y cantares XXIX, "Caminante, no hay camino" | Antonio Machado |
| 2 | Retrato | Antonio Machado |
| 3 | Niebla | Miguel de Unamuno |
| 4 | Romance de la luna, luna | Federico García Lorca |
| 5 | Romance sonámbulo | Federico García Lorca |
| 6 | Nanas de la cebolla | Miguel Hernández |
| 7 | El niño yuntero | Miguel Hernández |
| 8 | Luces de bohemia | Ramón del Valle-Inclán |
| 9 | Los heraldos negros | César Vallejo |
| 10 | A la deriva | Horacio Quiroga |
| 11 | El almohadón de plumas | Horacio Quiroga |
| 12 | Tú me quieres blanca | Alfonsina Storni |
| 13 | A poem | Delmira Agustini |
| 14 | A poem | Leopoldo Lugones |
| 15 | Don Segundo Sombra | Ricardo Güiraldes |
| 16 | Los de abajo | Mariano Azuela |
| 17 | La barraca | Vicente Blasco Ibáñez |
| 18 | A poem, only if the builder clears his rights | Juan Ramón Jiménez (the plan expects this one to be dropped) |

Reserve: José Ortega y Gasset (the plan expects it to fail the Spanish floor, so a reserve item with a review-queue row), Amado Nervo. Pío Baroja is named in the plan as not eligible; he is not a candidate.

### ES-017, `es-culture-4`: anonymous and traditional works before 1900 (es-4150 to 4199)

A song or text whose author or first printing the builder cannot show goes to the reserve. The plan expects fewer than 18 to pass; the report says so.

| # | Candidate work | Creator |
|---|---|---|
| 1 | Romance de Abenámar | anonymous |
| 2 | Romance del prisionero | anonymous |
| 3 | Romance de la loba parda | anonymous |
| 4 | Arroz con leche | traditional |
| 5 | Los pollitos dicen | traditional |
| 6 | De colores | traditional |
| 7 | La Llorona, only if the builder can show a record from before 1900 | traditional |
| 8 | Las mañanitas | traditional |
| 9 | A la víbora de la mar | traditional |
| 10 | Duérmete, niño | traditional |
| 11 | Calila e Dimna | anonymous |
| 12 | Libro del caballero Zifar | anonymous |
| 13 | Poema de Fernán González | anonymous |
| 14 | Amadís de Gaula | Garci Rodríguez de Montalvo |
| 15 | Cantar de los siete infantes de Lara | anonymous |
| 16 | Milagros de Nuestra Señora | Gonzalo de Berceo |
| 17 | Coplas de Mingo Revulgo | anonymous |
| 18 | Romance del rey moro que perdió Alhama | anonymous |

## Proverbs (ES-018 to ES-020, 3 x 20)

Genre `proverbs`, `basis: "oral-tradition"`, the shape of `ja-proverbs-1`. The `source` block has `collection`, `date` (the collection's own), `edition`, `jurisdiction`, `rights_checked`. Each card carries a `literal` note and a meaning; level A2 or B1. Sources the builder cites with page and date: es.wikiquote "Refranero español" and es.wikipedia "Refrán". **A refrán whose text the builder did not read on the cited page is dropped.** No refrán is listed here: the page names themes only, and the builder chooses short, well-known refranes it can read.

| Task | Deck | Themes, in order | Ids |
|---|---|---|---|
| ES-018 | `es-proverbs-1` | weather and seasons, months, food and drink, money, friends, family, work, animals | es-4200 to 4249 |
| ES-019 | `es-proverbs-2` | health, time and patience, luck, language and speech, learning, the home, the countryside, justice | es-4250 to 4299 |
| ES-020 | `es-proverbs-3` | love, age, neighbours, travel, honesty, effort, appearances, sayings with a saint or place | es-4300 to 4349 |

ES-019 and ES-020 list the earlier decks' targets first and use none of them again.

## Multi-word verbs (ES-021 to ES-024, 4 x 20)

Genre `multiword`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part; parts already taught are written by `ref`, a part not yet a card gets a card. The shape is `ja-multiword-te-auxiliaries`. These lists are the plan's candidate selections; a pattern the builder cannot support is reported, not replaced from memory.

| Task | Deck and `pattern_family` | Candidates | Ids |
|---|---|---|---|
| ES-021 | `es-multiword-periphrases`, `verbal-periphrasis` | ir a, acabar de, tener que, haber que, deber de, estar + gerundio, seguir + gerundio, llevar + gerundio, volver a, ponerse a, empezar a, echar a, dejar de, soler, poder (obligation), estar a punto de, tardar en, andar + gerundio, venir + gerundio, quedar en | es-4350 to 4399 |
| ES-022 | `es-multiword-prepositional`, `verb-preposition` | pensar en, soñar con, depender de, acordarse de, casarse con, enamorarse de, quejarse de, confiar en, insistir en, fijarse en, contar con, tratar de, tratarse de, acabar con, carecer de, dudar de, ayudar a, aprender a, negarse a, atreverse a | es-4400 to 4449 |
| ES-023 | `es-multiword-pronominal`, `pronominal-verb` | irse, quedarse, llevarse bien/mal, darse cuenta, ponerse + adjective, hacerse + noun, volverse, sentirse, parecerse a, portarse bien/mal, acostumbrarse a, olvidarse de, perderse, divertirse, enterarse de, ocurrírsele, caerse, marcharse, levantarse temprano | es-4450 to 4499 |
| ES-024 | `es-multiword-light-verbs`, `light-verb-idiom` | hacer caso, hacer falta, hacer cola, dar un paseo, dar las gracias, dar la mano, tener ganas de, tener razón, tener miedo, tener prisa, tomar el pelo, echar de menos, caer bien, llevar a cabo, poner la mesa, prestar atención, cambiar de idea, pegar un grito, salir adelante, quedarse con | es-4500 to 4549 |

ES-021 writes one card per periphrasis with a verb the unit teaches, as `ir a comer`, the pattern's two parts as `words`.

## Recommendations (ES-027 and ES-028, 10 + 10)

File `decks/recommendations/es.yaml`, in the shape of the nine entries of `recommendations/ja.yaml`: `id: "es-rec-<name>"`, `medium`, `title { text }`, `creator`, `year`, `level`, `briefing { en }` in the builder's own words, three questions each that only someone who watched, read or heard the work could answer, `tags: ["unreviewed"]`. No quotation and no link. These are works the learner sources themselves, so rights are not a gate here; year and creator are **to be read** from the work's es.wikipedia page, and a work whose facts the builder could not read is replaced from the reserve. Creators are added to `creators/es.yaml` where missing, with the same bio shape.

| Task | Medium | Candidates |
|---|---|---|
| ES-027 | films and television | El laberinto del fauno (2006), Volver (2006), Todo sobre mi madre (1999), Roma (2018), Amores perros (2000), El secreto de sus ojos (2009), Y tu mamá también (2001), La historia oficial (1985), Los lunes al sol (2002), La casa de papel (2017). Reserve: Campeones (2018), El Ministerio del Tiempo (2015), Cuéntame cómo pasó (2001), Ocho apellidos vascos (2014) |
| ES-028 | books, comics, songs, a podcast | Cien años de soledad, La sombra del viento, La casa de los espíritus, Rayuela, Mafalda (comic strips, Quino), Condorito, Gracias a la vida (Violeta Parra), Radio Ambulante (podcast), Pedro Páramo, La ciudad y los perros |

The years in parentheses are the plan's, not checked by this page. ES-028's `medium` is one of book, comic, song or podcast.

## Review-queue rule

Everything is `unreviewed`. Each unread, uncertain or dropped item is a row in the builder's report, in the table shape of `docs/review-queue/es.md`; the tasks ES-042 to ES-044 collect the rows into that file, one batch at a time.

## Not planned, and open questions for the owner

1. **Professional decks.** `professions` in `decks/sections.yaml` is empty; the owner supplies the list first.
2. **A Latin American pronunciation variety.** The course is Castilian (`θ`); no deck for a Latin American variety is planned. Wanted?
3. **A resources file** (`es-resources.yaml`, as `ja-resources.yaml`). Not on the checklist, so not planned; added only if the owner asks.
4. **Spanish term of copyright.** The floor for a Spanish author is the plan's rule (died 1945 or earlier). A reviewer should confirm the legal term before the decks ship.
