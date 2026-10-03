# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/aaronified/fluenough/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/aaronified/fluenough/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/aaronified/fluenough/releases/tag/v0.1.0
