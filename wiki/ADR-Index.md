# ADR index

Source of truth: this wiki page.

Every architecture decision record in the repo's docs/adr folder. Each one has its own page.

- [ADR-0001](ADR-0001-Flutter): Build with Flutter
- [ADR-0002](ADR-0002-System-Tts): Use the operating system's TTS, behind an interface
- [ADR-0003](ADR-0003-Licence): GPL-3.0 with an App Store Distribution Exception
- [ADR-0004](ADR-0004-Deck-Format): Decks are YAML files in git
- [ADR-0005](ADR-0005-Scheduling): SM-2 scheduling over an append-only review log
- [ADR-0006](ADR-0006-Interface-Text-Is-Tokens): Every interface string is a token, from the first screen
- [ADR-0007](ADR-0007-State-Reaches-Widgets): State reaches widgets through AppScope, with no package
- [ADR-0008](ADR-0008-Unbuilt-Features-Are-Shown-Disabled): Features without a backend are built and shown disabled
- [ADR-0009](ADR-0009-Scripts-Are-Open): `script` is an open list, checked with a warning
- [ADR-0010](ADR-0010-Themes): Vocabulary is taught along a shared path of themes
- [ADR-0011](ADR-0011-Number-Generator): Generated numbers are spelled from each language's rules, and not logged
- [ADR-0012](ADR-0012-Revision-Is-Not-Logged): Revising a finished deck is not logged
- [ADR-0013](ADR-0013-Course-Paths): Each course is taught along a curated path, as data
- [ADR-0014](ADR-0014-Speaking): Speaking is drilled through the phone's own speech recogniser
- [ADR-0015](ADR-0015-Sound-Contrasts): A language's sound contrasts live in a file of their own
- [ADR-0016](ADR-0016-Script-Guides): Each script has a guide to its recurring features
- [ADR-0017](ADR-0017-Update-Check): The app checks GitHub for updates and installs them itself
- [ADR-0018](ADR-0018-Card-Ids-Name-The-Language): A card id names the language, and a word is one card
- [ADR-0019](ADR-0019-Reading-Comprehension): Reading comprehension is passages whose questions are scheduled like cards
- [ADR-0020](ADR-0020-Added-Decks): Decks a learner adds are kept apart, and paths place them by wildcard
- [ADR-0021](ADR-0021-In-App-Reports): Reports go from a bug icon on every screen, by the reporter's mail, into GitHub issues
- [ADR-0022](ADR-0022-Romanised-Answers): Answers typed in Latin letters are graded against the reading, in the language's scheme
- [ADR-0023](ADR-0023-Learning-Without-The-Alphabet): A language can be learned without its alphabet
- [ADR-0024](ADR-0024-Daily-Lessons): New words come in a daily lesson, and every drill has more kinds of question
- [ADR-0025](ADR-0025-Iso-15919-And-Ipa): Readings use ISO 15919 letters as the word is said, with the IPA beside them
- [ADR-0026](ADR-0026-Sound-On-Every-Card): Every card has a speaker, words can play by themselves, and sound can be switched off
- [ADR-0027](ADR-0027-Language-Icons): Each language's icon is the first letter of its own name
- [ADR-0029](ADR-0029-Quick-Revision): Quick revision revises known words, and records only the misses
- [ADR-0030](ADR-0030-Review-By-Skill): Today's skill tiles start a review of their skill, and quick revision can take one
- [ADR-0031](ADR-0031-Release-Notes-From-Github): What's new shows GitHub's release notes, fetched when the page opens
- [ADR-0032](ADR-0032-Match-Pairs-Tap-To-Hear): A word in match pairs says itself when tapped, by a switch of its own that is on by default
- [ADR-0033](ADR-0033-Fsrs): FSRS in place of SM-2
- [ADR-0034](ADR-0034-Hear-Say-Write): Recognition, Hear, Say and Write: four schedules per word
- [ADR-0035](ADR-0035-Fsrs-Fitted-Per-Skill): FSRS fitted to each learner, per language and skill
- [ADR-0036](ADR-0036-B1-Deck-Format): Decks are a core and layers, with rules, bases, typed notes and a B1 plan
- [ADR-0037](ADR-0037-Decks-Download-From-Main): Decks download from main, by an index, and update when asked
- [ADR-0038](ADR-0038-Review-Proposals): Reviews become proposals in the decks, and agreement merges them
- [ADR-0039](ADR-0039-Questions-Derived-From-Card-Data): Questions are derived from card data
- [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa): Decks are CC BY-SA 4.0; the app's code stays GPL-3.0
- [ADR-0041](ADR-0041-The-Ipa-Course): The IPA is taught as a language, as one course
- [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course): Script fonts are downloaded per course
- [ADR-0043](ADR-0043-English-Braille-Course): English Braille is a notation course, typed on the app's own keyboard
- [ADR-0044](ADR-0044-Documentation-Lives-In-The-Wiki): Documentation lives in the wiki, mirrored from the repo by a workflow
- [ADR-0045](ADR-0045-Path-Level-Sizes): A path sets its own level sizes, and a level counts roots only
- [ADR-0046](ADR-0046-Lessons-Take-The-Next-Eligible-Items): A lesson takes the next eligible items, and a sentence waits until its words and rules are known
- [ADR-0047](ADR-0047-Performance-Model): The performance model: per-language versions, incremental aggregates and batching
- [ADR-0048](ADR-0048-Catalog-Snapshot): The catalog snapshot: the decks' YAML kept as JSON, keyed by SHA-256
- [ADR-0049](ADR-0049-Deck-Search-Fts5): Deck search: FTS5 trigram to retrieve, edit distance to forgive, a pure-Dart matcher as fallback
- [ADR-0050](ADR-0050-English-Synonym-Sets): Typed English meanings accept words from a curated file of synonym sets
- [ADR-0052](ADR-0052-Minimum-App-Version-In-The-Deck-Index): The deck index says which app version a language or deck needs

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
