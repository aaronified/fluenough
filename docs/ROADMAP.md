# Roadmap

The detail lives in the plans (`docs/plans/`) and on GitHub. Every plan has a
tracking issue labelled `plan`; its parts are sub-issues; the
[milestones](https://github.com/aaronified/fluenough/milestones) give the
order, and "Blocked by" links say what waits for what. A plan is done when its
sub-issues are closed; its tracker is then closed and the plan deleted from
`docs/plans/`.

## Shipped

Up to 0.3.3; the [CHANGELOG](../CHANGELOG.md) has each change. In brief:

- Courses taught from English: Assamese, Bengali, Gujarati, Hindi, Kannada,
  Marathi and Telugu, each with its script decks and guide, themes, grammar,
  facts and reading; Spanish started. Only Hindi and Bengali are partly
  reviewed by a speaker.
- Daily lessons, reviews by skill, quick revision; recognition, production,
  listening, speaking, grammar and reading drills; match pairs, multiple
  choice and word order.
- Answers in Latin letters, readings in ISO 15919, and every word's IPA.
- Saved progress, stats, leeches, the review log's export and import, adding
  a deck from a file, and signed releases.

## In order

| Milestone | Tracker | Plan |
|---|---|---|
| 1 · Skill model + FSRS | #207, #113 | Hear, Say and Write per word, and FSRS, in one migration (`skill-model.md`, `fsrs.md`) |
| 2 · B1 plans | #209, #392 | A B1 plan in every path (`b1-plans.md`), and decks split into a core and a layer per native language (`native-layers.md`) |
| 3 · Deck downloads | #210 | Decks downloaded from GitHub, not bundled (`decks-from-github.md`) |
| 4 · Settings redesign | #211, #212, #213 | The language picker, settings wording, and voices per language |

## Any order

Each can start once what it waits for is done.

| Tracker | Plan | Waits for |
|---|---|---|
| #208 | Difficulty by skill and by word | #113 |
| #214 | A Research and standards page | #113, #207, #209 |
| #215 | Books, films and songs you bring | #209, #210 |
| #222 | Building sentences, and cloze | #207 |
| #216 | A path for every language, by family | |
| #350 | New languages, one full course each | #210, #217 |
| #403 | A deck browser for reviewers, on GitHub Pages | #392 |
| #217 | IPA from Wiktionary | |
| #218 | Fluenough on the web | |
| #220 | Read your own text, and make cards from it | |
| #221 | Readings made in the app | |
| #223 | Achievements (level badges wait for #209) | |
| #224 | Hands-free audio drills | |
| #225 | Explain a grammar mistake | |
| #226 | Writing the script by hand | |
| #227 | Hours spent and hours left | |
| #228 | An IPA course | |
| #229 | An ISO 15919 letters deck | |
| #230 | A listening tier in context | |
| #231 | Try a pronunciation again | |
| #232 | Play Protect and developer verification | |
| #233 | Say when speech works only online | |
| #234 | Word-order tiles without giveaways | |
| #219 | Conversation practice with an AI (long-term) | |
| #99 | Culture decks | #210 |

Issues outside the plans, in any order: #25 F-Droid, #26 TalkBack pass, #46 interface language, #90 daily reminder, #92 sample deck
pack, #204 profiles and PIN, then #97 child lock, #108 home-screen widget,
#110 dialogue decks, #111 native-speaker audio, #112 backup to a folder, #141
release tag check, #160 feedback by mail, #162 the app's log.

## Later

- An iOS build, which needs an Apple Developer account
  ([ADR-0001](adr/0001-flutter.md)).
- An optional Kokoro TTS backend, if its Flutter bindings mature
  ([ADR-0002](adr/0002-system-tts.md)).
