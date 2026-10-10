# Roadmap

The detail lives in the plans (`docs/plans/`) and on GitHub. Every plan has a
tracking issue labelled `plan`; its parts are sub-issues; the
[milestones](https://github.com/aaronified/fluenough/milestones) give the
order, and "Blocked by" links say what waits for what. A plan is done when its
sub-issues are closed; its tracker is then closed and the plan deleted from
`docs/plans/`.

## Shipped

Up to 0.3.4; the [CHANGELOG](../CHANGELOG.md) has each change. In brief:

- Courses taught from English: Assamese, Bengali, Gujarati, Hindi, Kannada,
  Marathi and Telugu, each with its script decks and guide, themes, grammar,
  facts and reading; Spanish started. Only Hindi and Bengali are partly
  reviewed by a speaker.
- Daily lessons, reviews by skill, quick revision; recognition, production,
  listening, speaking, grammar and reading drills; match pairs, multiple
  choice and word order.
- Answers in Latin letters, readings based on ISO 15919, and every word's IPA.
- Saved progress, stats, leeches, the review log's export and import, adding
  a deck from a file, and signed releases.

Merged since 0.3.4, not yet released (#432 to #445):

- FSRS-6 in place of SM-2, and four schedules per word: seen, heard, spoken
  and written words, plus two grammar schedules, understood and produced. A
  right answer counts in part for the skills it implies (#432, ADR-0033,
  ADR-0034, ADR-0036).
- FSRS fitted to each learner on the phone, per language and skill, by
  "Adjust to me" or after 10% more reviews; shown in Settings, Progress
  ("How you learn") and Today (ADR-0035).
- Pictures on 330 cards (Noto Emoji), and minimal-pair partners in Hear.
- Support, bug and feedback mails to fluenough@gmail.com, with the app log
  attached only with consent; the app log in Settings (#433, #160, #162).
- The B1 deck format: a core and a layer per native language, one path per
  language learnt, regions, phrasebooks, rule decks, typed notes and base
  words, and the learner choosing which native language teaches a course
  (#434, ADR-0036).
- New Decks path and Unit screens, and reviewing decks in the app, sent by
  mail (#436, #403).
- Settings wording that says what each switch does now, voices per language,
  and the 18+ setting (#437, #96).
- B1 plans for Telugu and Bengali, and their A1 decks (#438).
- Hindi, Marathi, Gujarati, Kannada, Assamese and Spanish arranged in the B1
  format, with a B1 plan in each path and no new content: a core and an
  English layer per deck, a phrasebook, base words, planned units up to B1.
  Every language but Japanese now has a B1 plan (#445).
- The mail bot checks the sender of a review (#439, part of #403).
- Decks downloaded from GitHub, not bundled: the index, the download
  source, first launch, updates and removing a language (#440, ADR-0037,
  closes #210).
- Tests for the FSRS fitter against every mutation that could change a fit
  (#442).
- The language picker: search, Learning and Available, a card per language
  with its course's progress toward B1 and its Alpha or Beta stage, the
  script switch, the language taught from, and the download with its
  progress on the card (#443, closes #211).
- Reviews become proposals in the decks at once, and agreement between
  reviewers merges them to learners (#444, ADR-0038, closes #441).

The next release (0.4.0, not yet tagged) ships deck downloads together with
the language picker.

## Being built

Nothing is in progress. The next work is in "In order" below.

## In order

| Milestone | Tracker | Plan |
|---|---|---|
| 1 · Skill model + FSRS | #207, #113 (done, #432) | What is left of them: a switch for the other activities (#243), the phonemic contrasts drill (#31), pictures beyond Noto Emoji (#91), grammar exercises (#93) and the script TTS fallback (#32). #249 (quick revision, rating-button interval previews, leeches) is done in #432 and can be closed |
| 2 · B1 plans | #209, #392, #413 | A B1 plan in every path (`b1-plans.md`; all but Japanese done, Telugu and Bengali in #438, the other six in #445, with their decks arranged in the B1 format, no new content); base words shown on cards (#410); the A2 and B1 units, which are planned and show as "Coming"; decks split into a core and a layer per native language (`native-layers.md`); a phrasebook, then words, then rules, then sentences (`words-rules-sentences.md`); then the Bengali and Telugu B1 decks |
| 3 · Deck downloads (done, #440) | #210 | Decks downloaded from GitHub, not bundled ([ADR-0037](adr/0037-decks-download-from-main.md)) |
| 4 · Settings redesign (done) | #211, #212, #213 | Settings wording and voices per language (#437) and the language picker (#443) are done, and their trackers are closed |

The skill model and FSRS (#207, #113) are done, in #432; milestone 1 stays
open until its few leftovers are done or moved.

## Any order

Each can start once what it waits for is done.

| Tracker | Plan | Waits for |
|---|---|---|
| #208 | Difficulty by skill and by word | |
| #214 | A Research and standards page | #209 |
| #215 | Books, films and songs you bring | #209, #210 |
| #222 | Building sentences, and cloze | |
| #216 | A path for every language, by family | #392, #413 (the parts that write or reorder courses) |
| #350 | New languages, one full course each | #210, #217, #392, #413 |
| #403 | Reviewing in the app, sent by mail (`deck-browser.md`): merged in #436, the sender check in #439, proposals and agreement in #444. Left: a screen of its own for offensive words (#428), and the deck browser site and Pages workflow, for the owner to decide (#404, #405) | |
| | Offensive words: levels, and sound-alike and look-alike warnings (`offensive-words.md`) | #403 for the ratings |
| #217 | IPA from Wiktionary | |
| #218 | Fluenough on the web | |
| #220 | Read your own text, and make cards from it | |
| #221 | Readings made in the app | |
| #223 | Achievements (level badges wait for #209) | |
| #224 | Hands-free audio drills | |
| #225 | Explain a grammar mistake | |
| #226 | Writing the script by hand (`handwriting.md`; KanjiVG and Hanzi Writer for stroke order) | |
| #227 | Hours spent and hours left | |
| #228 | An IPA course | |
| #229 | An ISO 15919 letters deck | |
| #230 | A listening tier in context | |
| #231 | Try a pronunciation again | |
| #232 | Play Protect and developer verification | |
| #233 | Say when speech works only online | |
| #234 | Extra word-order tiles (the giveaways are gone, #347) | |
| #219 | Conversation practice with an AI (long-term) | |
| #99 | Culture decks | #210 |

Issues outside the plans, in any order: #25 F-Droid, #26 TalkBack pass, #46
interface language, #90 daily reminder, #204 profiles and PIN, then #97 parental supervision
(`profiles.md`), #108 home-screen widget, #111 native-speaker audio, #112 backup to a
folder, #141 release tag check, #425 the analyzer bound, #411 shareable
progress. After #392 and #413: #92 sample deck pack, #110 dialogue decks.

## Later

- An iOS build, which needs an Apple Developer account
  ([ADR-0001](adr/0001-flutter.md)).
- An optional Kokoro TTS backend, if its Flutter bindings mature
  ([ADR-0002](adr/0002-system-tts.md)).
