# Audit: tense, number and gender in the paths

Owner's question (2026-10-23): "Are we teaching tense, number, gender properly? In each of the courses?"

**Scope (owner, 2026-10-23).** Path files only: `decks/<lang>/<lang>-path.yaml`, read on main, with [Plan: Language Paths Scheme](Plan-Language-Paths-Scheme) and [Plan: Words, Rules, Sentences](Plan-Words-Rules-Sentences). No deck contents were read: no card counts, no table coverage, no note sampling. Correctness of notes stays with each batch's review, so no course is marked "wrong" here.

**Status words.** *Written*: the grammar unit lists decks that exist. *Planned*: the unit is `planned:` (marked * below). *Missing*: no unit names the topic. *Check*: the path does not show whether another unit covers it. "Order" is the path's order; a unit's level is not shown in the sequences.

## Courses with written grammar units

Only Telugu has written units through B1. Bengali, Hindustani, Marathi, Gujarati, Kannada and Assamese are written to about A2 and planned after. Spanish has two written units. Japanese, Korean and Chinese have paths and no grammar decks.

### Tense

| Course | Order of tense units (* = planned) | Status | Gaps against B1 |
|---|---|---|---|
| te | verb-present, continuous, future, negative, past, past-more, imperatives, verbal-participle, relative-participle, conditional, purpose, before-after, while, causative, concessive, passive | Full to B1, all written | No perfect or past-continuous unit; imperatives come after past |
| bn | present (+verb-present), continuous, future, past, perfect, past-negative, past-more; past-continuous*, habitual-past* | Written to A2, rest planned | No negative unit for present or future; imperatives*, past-continuous*, habitual-past* come late |
| hi | present, continuous, future, past, ne + perfect, past-more; imperatives*, past-continuous*, subjunctive*, habitual-past* | Written to A2, rest planned | Habitual past (karta tha) is last in the path, after B1 topics such as passive; subjunctive* is after can-must; no negative unit |
| mr | present, continuous, future, negative, past, past-more; perfect*, past-continuous*, subjunctive*, habitual-past* | Written to A2, rest planned | Perfect* is after past-more; habitual past last |
| gu | be, continuous, future, negative, past, past-more; perfect*, past-continuous*, subjunctive*, habitual-past* | Written to A2, rest planned | No `present` unit (check: continuous may cover it); perfect*, habitual past late |
| kn | be, continuous, future, negative, past, past-more; perfect*, past-continuous*, subjunctive*, habitual-past* | Written to A2, rest planned | No `present` unit (check); same late items |
| as | be, continuous, future, negative, past, past-more; perfect*, past-continuous*, subjunctive*, habitual-past* | Written to A2, rest planned | No `present` unit (check); same late items |
| es | present-ar; present-er-ir*, present-irregular*, ir-a*, estar-gerund*, preterite-regular*, preterite-irregular*, imperfect*, present-perfect*, future*, conditional*, subjunctive-present*, pluperfect*, imperfect-subjunctive* | 1 unit written, rest planned | No preterite-versus-imperfect unit (French has one); imperatives* after comparison |
| ja, ko, zh | ja: masu, masu-past, te-form, plain-present, plain-past\*; ko: haeyo-present, past, future, progressive\*; zh: le, guo, zhe\* (aspects, no tenses) | Planned only | Orders look sound; nothing written |

### Number (plurals and their agreement)

| Course | Status | Gaps |
|---|---|---|
| te | Full: noun-forms (plural first), gender-number | None at path level |
| bn | Written: noun-forms (plural first), gender-number | None at path level |
| hi | Written inside `nouns` and `adjectives` | No unit named for number; the Arabic plural -at and broken plurals are planned (arabic-words*); check that `nouns` teaches the oblique plural |
| mr, gu, kn, as | Written: nouns, gender-number | `as` has a gender-number unit but `genders: []`: the unit can only teach number, so rename it or confirm |
| es | Planned only inside articles-gender (written) and adjective-agreement* | No plural-of-nouns unit |
| de, fr, eo, isv | de: plural* (second unit); eo: article-plural*; isv: plural* (second); fr: none | fr has no plural unit; es and fr rely on the article unit |
| ja, ko, zh | Counters and measure words, no plural (right for the language) | None |
| pa, or, mai, ml, ta, ine, gmy, egy, sux | Planned: noun-forms or nouns; ta and ml have gender-number* | Nothing written |

### Gender (noun gender, then agreement)

| Course | `genders` | Agreement units | Status | Gaps |
|---|---|---|---|---|
| te | mahat, amahat | gender-number, adjectives (written) | Full | Verb agreement sits in the verb-present table, not its own unit |
| hi | m, f | adjectives (written); ne (written, ergative past); perfect (written) | Written to A2 | No gender-number unit; past-continuous* and habitual-past* (agreement forms) planned late |
| mr | m, f, n | gender-number, adjectives (written) | Written to A2 | No ergative-past unit for transitive verbs, which Marathi has; check inside past or past-more |
| gu | m, f, n | gender-number, adjectives (written) | Written to A2 | Same: no ergative unit, though Gujarati has an ergative past |
| kn | m, f, n | gender-number, adjectives (written) | Written to A2 | None at path level |
| bn, as | none | gender-number unit exists | Correct: no grammatical gender | `as` unit name implies gender (see Number) |
| es | m, f | articles-gender (written); adjective-agreement* planned after reflexives | Mostly planned | Adjective agreement comes after the present, preterite is not yet in; planned late for a feature needed in the first lessons |
| fr, de | m, f (+n) | articles-gender*, adjective-agreement* (fr), adjective-endings* (de) | Planned only | de adjective endings are after past-common: acceptable; fr passe-compose-etre* agreement is listed |
| pa | m, f | gender-agreement*, ne* | Planned only | Ergative ne planned, good |
| ta, ml, isv, gmy, ine | m, f, n | gender-number*, gender* | Planned only | Nothing written |
| ja, zh, ko, tok, jbo, eo, or, mai | none | n/a | Correct | None |
| egy, sux | m,f / human, non-human | nouns*, ergative* (sux) | Planned only | No explicit gender unit in egy |

## Ranked gap list

1. **Habitual past is last in every Indo-Aryan and Dravidian path** (hi, bn, mr, gu, kn, as): after passive and reported speech. A learner at A2 needs "I used to" far earlier. Move it next to past-more.
2. **Imperatives are planned after the past in every course with them** (hi, bn, mr, gu, kn, as, es, te). Commands are needed from the first lessons (kitchen-help passage); order them with the present.
3. **Spanish and French agreement and plurals are late or missing**: es has no plural unit and adjective-agreement* follows reflexives; es has no preterite-versus-imperfect unit. Only one Spanish grammar unit is written.
4. **Ergative past is not named in Marathi and Gujarati** (Hindi has ne; Punjabi plans ne*). Add a topic or confirm past or past-more covers it.
5. **Gujarati, Kannada and Assamese have no `present` unit** (Hindustani, Marathi, Bengali and Telugu do), and Hindustani has no number or gender-number unit; Assamese's gender-number unit has no genders to teach.

Smaller: Telugu has no perfect or past-continuous unit; Bengali has no present or future negative; perfect* sits after past-more in mr, gu, kn and as.
