# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-10-04

### Added

- Quick revision on Today: revise 5, 10, 15 or 20 words you know, picked at random from every language you learn. A word you get wrong comes back sooner; one you get right keeps its date. The fact of the day follows it (#183).
- A speaker on every card, reviews included; match pairs has none. Long-press it to play words automatically, also in Settings > Sound; words don't play by themselves until you turn that on (#182).
- A Sound switch in Settings. With sound off, every speaker is greyed out, and lessons and reviews skip the questions that need sound until it is back on; turning it off says so. With the phone's volume at zero, a listening card is greyed out and asks you to raise the volume (#182).
- Every word now carries how it is said in the IPA (/paːlu/), ready for the screens to show (#180).

### Changed

- Readings now use the letters of ISO 15919, written as the word is said, so words that differ only by a long vowel or a curled-back consonant read differently: పాలు, milk, is *pālu* and పలు, many, is *palu*. The README has the table. Typed answers don't need the marks: *palu*, *paalu* and *pālu* are all right (#180).
- While you type an answer, the Script / Latin letters switch hides and the card gets smaller, so it stays in view above the keyboard (#178).
- Today no longer lists your decks; the Decks tab does (#183).
- Each language's chip shows the first letter of its own name, so they no longer all show न, ন or న: हि Hindi, বা Bengali, తె Telugu, and so on (#179).

## [0.3.1] - 2026-10-04

### Fixed

- No sound played on Android 11 and later, in lessons, listening cards or anywhere else: the app could not find the phone's text-to-speech engine (#176).

## [0.3.0] - 2026-10-04

### Added

- A daily lesson for each language you learn: nine new words, three easy, three medium and three hard. Each word is taught, then checked at once, then asked again in another skill, so you hear and say words from the first lesson. Once today's lesson is done, Today offers another (#174).
- New kinds of question: choose a word's meaning, choose the word, or choose the word you heard; match four words with their meanings by dragging or tapping; and put a sentence's words in order. Reviews use them instead of rating yourself, and phrases are now practised by putting their words in order (#173).
- Assamese, taught from English: a full course like Telugu's, with its script, 18 themes, 24 grammar decks, a reading deck written for it, facts and number rules. No Assamese speaker has checked it yet, and every deck says so (#165).
- Marathi, Kannada and Gujarati, taught from English, each a full course like Telugu's. No speaker has checked them yet (#155).
- Learn a language without its alphabet: asked for each language as you choose it, and switchable in Settings > Alphabets. Its script, spelling and reading decks are left out, words show their romanisation first, and you answer in Latin letters for full credit (#167).
- Answer in Latin letters: production, listening and grammar drills offer Script or Latin letters. Common spellings such as `ee` for `i` count as the same answer (#47, #166).
- Report a bug, a feature or a suggestion from the bug icon on every screen, from Report a mistake on unchecked decks, or from a card in Inspect. Reports are text only, and your device's details are added only if you tick the box. Until mail reports are set up, reports open GitHub's new-issue form (#157).
- Inspect a deck: every card in one scrolling list, two or three lines each with its id, opening in place to show the rest (#159).
- A Pure black switch in Appearance, for OLED screens: black backgrounds whenever the app is dark (#163).
- Add your own deck from a file, placed in its course by the path's wildcards (#156).
- Search decks word by word, by language, theme and kind (#154).
- Review several languages one at a time, with a break between (#153).
- Settings shows a Logs section, marked "Feature incoming" (#162).

### Changed

- Every course now opens with a few words and basic sentences, then the sounds English lacks and how the grammar differs, then five more themes; the script comes after those six themes. Until you reach it, typed answers start in Latin letters and count in full; after it, a right answer in Latin letters counts as a hard recall (#168).
- New words come only in lessons. Start review is your due reviews and the other skills of words you have been taught, and the new-cards-per-day setting is gone. A deck with nothing due offers a lesson of its words (#174).
- Every reading now follows one scheme per language, the way it is typed in chat: lowercase, with no length or retroflex marks, spelled as said (`pani`, not `paanii`). Hindi writes ड़ as `r` (`larka`) (#164).
- Japanese is no longer in the app; for foreign languages there is Spanish for now. Its decks stay in the repository (#171).
- The keyboard tip under a typed answer is now one line: "No Hindi keyboard? Try HeliBoard." (#158).
- Telugu and Kannada answers accept `f` for `ph` (#172).

### Fixed

- The colour swatches in Appearance were invisible except for the one chosen (#161).
- In Inspect, a card's Report button sits beside its id, and a deck that can't be found still has the bug icon (#172).
- A report from placement didn't name its screen (#172).

## [0.2.0] - 2026-10-03

### Added

- Reading comprehension, a new drill with short passages and questions (multiple choice or true/false), a glossary of older words, and a chip to show or hide romanisation on the passage. Bengali reads Tagore's *Sahaj Path*, Hindi reads Premchand's *Panch Parmeshwar*, Telugu reads Gurajada's *Diddubatu*, each credited in Settings > Sources (#147, #149, #150).
- Bengali, Hindi and Telugu now cover the same ground: family, work, home and daily-life themes; a shared set of grammar; every number from 21 to 99 for Bengali and Hindi (Telugu already builds numbers from parts); a primer of formal and everyday words side by side; and a slang deck with an advanced spelling deck (#145, #146, #149, #150).
- Every course now opens with a script run-through, sounds to tell apart, and a short tour of how the grammar differs from English, before its first theme (#132, #133, #135).
- A script guide for Bengali, Hindi and Telugu, shown once before that script's first letters or any time from Tips, each with a short "first words to read" deck (#136, #137, #138, #140).
- Speaking: say an answer aloud and have your phone's own speech recognition grade it, with pause and per-language/global off switches, a first-launch microphone and speaker check, and sound-difference feedback on a close wrong answer (#127, #128, #129, #134).
- Course paths: Today teaches new cards unit by unit along each course's path, giving every language an equal share of the day; first launch opens with a welcome tour and asks what to learn, offering a level check or a fresh start per language (#122, #124, #125, #126).
- Progress now shows one language at a time, with a chip to switch between them (#121).
- Appearance: the four colour seeds, high-contrast drill colours, and the card text-size slider now work (#116).
- Settings can check GitHub for a newer Fluenough, download it and start the install, with a cloud-backup section marked "Feature incoming" (#142).

### Changed

- A word's id now names only its language, not the deck or course it's taught in, so the same word taught in two decks shares one schedule; progress recorded by 0.1.0 does not carry over to 0.2.0 (#145).

### Fixed

- Every deck used to read "Done" after its first session and couldn't be studied again; decks now read "Not done" until something in them is learned, with separate "Learn anyway" and "Revise" buttons once they are (#120).
- On a day with reviews due, a deck could count as finished while one of its skills was still new, so Today moved on to the next unit of the path too early (#151).
- A typed answer of one or two letters allowed a typo, so any single wrong letter was treated as a near miss; a short answer now has to match exactly (#151).
- A near miss that was word for word another card's correct answer (such as the wrong person of a verb in a grammar drill) was offered as a slip to accept; it's now marked wrong (#151).
- A spoken or typed sentence ending in । or ॥ was marked wrong because the mark wasn't dropped before grading (#131).
- Leech actions (Reset, Set aside, Bring back) could double up or lose track of a card's state; Undo now only undoes the latest reset (#151).
- The "next due tomorrow" count on a session summary didn't follow the same rules as Today itself (#151).
- Importing a backup with a bad line crashed instead of showing an error (#151).

## [0.1.0] - 2026-10-02

Initial release. For changes before this point, see the commit history.

[Unreleased]: https://github.com/aaronified/fluenough/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/aaronified/fluenough/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/aaronified/fluenough/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/aaronified/fluenough/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/aaronified/fluenough/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/aaronified/fluenough/releases/tag/v0.1.0
