# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Languages I'm learning is redesigned, on first launch and in Settings. Search by a language's English name, its own name or its code, accents ignored. Languages you learn are under Learning, the rest under Available, those taught from a language you speak first. Each card shows both names, how much of the course is written toward B1, with its grammar topics, your own progress where you learn it, the languages it is taught from, yours highlighted, and whether it is on the phone. A course is tagged Alpha until its A1 units are written and Beta until its B1 units are. Choosing a new language opens its card: Learn the script, on to start with, which placement then no longer asks; which of your languages to learn it from, when more than one teaches it, side by side up to three and a list beyond; and its download, which starts as you choose it, with a bar, its decks counted, and Continue as soon as the first five are in. Cancel keeps what arrived, and Settings > Deck downloads fetches the rest. Taking off a language you learn asks first; its progress is kept. A language you already learn needs no placement (#211).
- Decks download from GitHub instead of coming with the app. Choosing a language downloads its decks from the repository's `main` branch, starting with its path's first five, and you can begin as soon as those are in; the rest follow while you learn. The list of languages comes from GitHub too, so a language added there appears without an app update. Where a language has no decks for a language you speak, its English ones are offered, and the list says "Taught from English". With no connection, or when GitHub limits requests, the app says so and offers Try again. Once the decks are on the phone the app works offline as before (#210, #265, #266, #267).
- Deck updates. Once a day at most, the app compares its decks with GitHub's and asks whether to fetch what changed (Check automatically, in Settings > Deck downloads, turns this off); "Not now" leaves the update in Settings > Deck downloads, which lists each language with its size and state, Update and Remove. Your progress is kept by card, so updating a deck keeps it, and so does removing a language: download it again and its progress is back. A deck removed from GitHub stays on your phone (#268, #269, #270).
- Every downloaded file is checked against the SHA-256 in `decks/index.json`, and must read as a deck, before it replaces anything; a download cut short, or a file that fails, leaves your decks as they were (#266).
- For deck writers: `tools/deck_index.py` writes `decks/index.json`, the list the app downloads decks by. Run it after changing a deck and commit it; `tools/validate_decks.py decks/` fails while it is out of date (#265).
- An app log, in Settings > Logs, for reports. It records what went wrong, errors and warnings, and key events: screens opened, decks loaded, fits run, imports and exports. It never records your answers or the cards. It is kept on the phone, so it survives a crash, for 7 days and at most 2,000 lines, whichever is fewer. You can view it, copy it, export it as a file, or clear it (#162).
- A report can carry the app log, as a file. Tick "Attach the app log", beside "Include device information" and unticked like it, which shows what the log holds and its newest lines. It goes with support mails too, and stays in the Fluenough inbox, never in a public issue. The mail goes through Android's share, as a mail link cannot carry a file; if the phone cannot share it, your mail app opens without the log and the app says so. No new dependency: `tools/brand_android.py` writes the share, and the FileProvider that lends the file, into the generated Android project (#160, #162).
- Reviewing decks, for native speakers who check cards before they ship. Turn on Review decks in Settings: the phone makes your rater code, FL-XXXX-XXXX-C, and How reviewing works explains the rest, once by itself and from Settings at any time. On a unit, Review lists its cards: mark each one right, or suggest a change to one part and say why. Rude words are rated 1 to 9, for how offensive they are to native speakers in general, by tapping one of nine numbers, with where you speak the language; a word that sounds like a rude one is confirmed or rejected, with a care note of at most 40 letters. Reviews stay on the phone until you send them. Send review sends every deck you have reviewed in one mail, a file for each, through your own mail app; each file carries your code, the language, the deck, the app version and the time. The phone cannot tell whether you then send the mail, so if it does not go, Send the last mail again in Settings puts its decks back to send. Your code is public, so send from the same mail address each time: the first review mail with a code ties it to the address it came from, in a private record in the Fluenough Gmail, and a later review from another address is filed marked "sender does not match", for the team to decide. Gmail addresses match with their dots and anything from "+" ignored. The address is never written to the issue or the workflow's log. A unit whose deck lists your code thanks you, and Settings lists the decks you helped build. The hourly mail workflow files each review mail as a public issue naming only the code and the languages.
- Offensive words are reviewed apart, and only on purpose (#428). They no longer appear in a unit's or deck's review, adult content on or off, nor count toward its sign-off; the review says how many it leaves out. Each language you review has its own Offensive words row in Waiting for review, with how many wait for a rating. Opened, it first says why the words are in the app: some are deeply offensive and unprintable, some mild, some fine between friends; learners should understand abuse rather than use it unknowingly; and a word's strength differs from one language and culture to another. Then it asks whether you are 18 or over, every time, and only then lists the words, each rated 1 to 9 with where you speak the language, as before. Ratings go in the deck's review file and mail as before, and a deck of offensive words only is signed off there.
- A word that sounds like an offensive one no longer names it in a unit's review, even with adult content on: the card shows the warning learners see, and its pair no longer holds up the unit's sign-off. The pair is confirmed or rejected in the language's Offensive words review instead, after the words, past the same explanation and 18+ question, and Waiting for review counts it under the Offensive words row (#428).
- Reviewers change the decks together, with no wait (ADR-0038, #441). Once the review bot is set up, what you suggest in a review goes into the decks as a proposed change as soon as your mail arrives, for the other reviewers of the language to see on that card, with Accept, Edit and Reject; learners never see it. When enough reviewers other than you accept a change exactly as written (one, to begin with; the owner sets the number), it goes to learners within the hour. Edit makes the change your own proposal, and the first change to a part of a card to be agreed wins. A rejection is passed to the team. Because suggestions now go into the public decks with your code, How reviewing works no longer says what you write stays private; your mail address still does.
- For deck writers: a card may carry `proposed` lines, written and removed by the review bot; the validator checks them and ignores their text, and `index.json` counts them. For the owner: `docs/review-bot-setup.md` sets up the GitHub App that merges the bot's PRs, and the repository variable `REVIEW_AGREEMENTS_NEEDED`. Until then reviews are filed as issues, as before.
- What waits for review, for reviewers: choose the languages you review in Settings, under Review decks (at first, those you speak that the app teaches), and Waiting for review lists, per language, the units and decks no native speaker has signed off with the cards each has left, the offensive words not yet rated, the sound-alike pairs not yet confirmed, and what you reviewed but have not sent. Each unit of the path waiting for review is marked "To review". The regions a rating offers, and a rude word's region note, come from the language's path.
- The Decks tab is now a path (#436). Chips pick the course; each unit is a node marked done, up next, not started or Coming; the path shows its levels (A1, A2, B1) and milestones (words learned, rules known, first passage read, script learned); Where I am, + Add deck, and a search across every course you learn sit on the same screen. Units still to come, planned or not yet written in your language, show greyed as "Coming", with about how many words, and cannot be started; lessons skip them.
- A unit has a screen of its own (#436): its level, number and description, a notice while no speaker has checked its deck, tiles for words, rules and sentences, each word marked Known, Learning n% or New, a rules deck drawn as its table, Continue, and Review for reviewers. Tapping a word opens its card sheet: the word with its reading, meaning and notes, a speaker, and the warning on a word that sounds like a rude one. The rude word itself stays hidden unless adult content (18+) is on.
- Telugu and Bengali are the first courses in the B1 format (#438). Each has a plan to B1 in its path, 97 units for Telugu and 103 for Bengali, with A1, A2 and B1 marks, and every A1 unit written: 30 units, about 630 words for Telugu and 750 for Bengali, 27 and 28 new decks with an English layer each, a 20-phrase phrasebook, and rule tables for noun forms, pronouns and present-tense verbs. The A2 and B1 units are planned and show as "Coming". All the new decks are marked unreviewed. A rules deck now counts as rules, not as words, so Telugu's A1 no longer reads 3,318 words.
- Hindi, Marathi, Gujarati, Kannada, Assamese and Spanish are arranged in the B1 format too (#445), with no new content and no card id changed. Each deck is a core and an English layer, each language has a phrasebook gathered from its cards and a B1 plan in its path with A1, A2 and B1 marks, and derived words name their dictionary form, such as गया → जाना. The units up to B1 that are not written yet show as "Coming". The words and notes learners see are unchanged.
- A word that sounds like a rude word now says so on its drill card once it is answered, and on its card in the unit: "Careful when speaking". The rude word itself stays hidden unless adult content (18+) is on (#96).
- A word's card in a unit now has a top line with its id, part of speech and where you stand with it. That card, and a card in review, has a speaker that says the word. The path no longer counts an alphabet's letters as words learned.
- FSRS is fitted to you on the phone, per language and skill, from your own answers: from "Adjust to me" in Settings, or by itself after 10% more answers. "How you learn" on Progress, and the marks on Today's skill tiles, show how fast you forget each skill against the start. Nothing is sent anywhere (#432).
- Pictures on 330 cards, from Noto Emoji, shown when you type a word and beside each meaning when you listen.
- Words are now scheduled by FSRS-6, in place of SM-2, and in four skills each: seen, heard, spoken and written words, plus two grammar schedules, understood and produced. Listening now asks what a word means, so a near homophone such as కలం (kalam, pen) and కాలం (kālam, time) is told apart by its meaning. A right answer also counts in part for the skills it implies. Your whole history is replayed once, so due dates move on the first launch (#113, #207).
- Grammar understood and produced are two schedules of their own, fitted separately, under the one Grammar switch. Understood shows you a form of a word and you choose what it means. Produced has you choose among forms of the same word, then type it (#434).
- Which language teaches a course. When more than one language you speak teaches a course you learn, the app asks which to learn from, showing how much of the course each covers; change it for a course in Settings, "Learn Telugu from". Every bundled course is taught from English, so nobody is asked yet (#434).
- Regions in the Telugu and Bengali paths: Telangana, Coastal Andhra and Rayalaseema for Telugu, six dialect groups for Bengali, which a native reviewer is still to check. This is data for now; no screen shows them yet (#434).
- For deck writers: the B1 deck format. A deck can be a core and a layer per native language, one path per language learnt (`decks/<lang>/<lang>-path.yaml`), and the format has phrasebooks, rule decks, base words, typed notes and Wiktionary links, and planned units with their sizes. `docs/DECK-FORMAT.md` and ADR-0036 describe it; no existing card or deck id changed (#434).
- Install voices in phone settings, in Settings > Voices, now opens the phone's text-to-speech settings, where a voice is installed, instead of only saying how to find them. On a phone without that page it opens the voice engine's own page for installing voices; where neither opens, it explains the way there as before. No new dependency: the app asks Android through a small channel of its own, which `tools/brand_android.py` writes into the generated Android project.
- Adult content (18+), in Settings, off by default. Switching it on asks once whether you are 18 or over. With it on, a warning on a word that sounds like a rude one names the rude word, and reviewers see offensive cards and rate them. Off again hides them at once (#96).
- Settings > Voices has one card per language, the languages you learn first, for hearing it and for speaking it. Choose which of the phone's voices speaks it, where it has several, marked where one needs a connection, and Play it. Say something tests the phone's speech recognition: say a word from the course, shown with its reading, or anything, and see what the phone heard and whether it is the word. A failed test says why, with the recogniser's own error code in small print, and every speech and voice error goes to the app log by its type and code, never what you said. Where a language is heard only online, the card holds its switch, and the test asks first, as a drill does (#123).

### Changed

- The app no longer bundles the language folders, only the theme list and the spoken languages. Updating from an earlier version downloads the languages you learn before the app opens; your progress is kept. Tests read the repository's `decks/` through its index (#271, ADR-0037).
- The app goes online to download decks too, and once a day to look for deck updates unless you turn that off. Like the update check, this tells GitHub the phone's IP address and which files it asked for, and nothing else. The welcome screen and the Settings footer now say the app works offline once its decks are downloaded (#272).
- Every switch in Settings now says what happens in its state, and its line changes the moment you flip it: "Nothing is spoken; listening questions are skipped", "Words play only when you tap the speaker". The skills are named as you meet them: Seen words, Written words, Heard words and Spoken words, with Grammar covering forms understood and used. Show romanisation is now Latin-letter readings. Rows that open a page show what is set, and Languages I speak lists your languages.
- The app now reads an unquoted value in a deck as the validator does, by YAML 1.2, so a bare `no` is the text "no" in both. Quote it all the same, for other YAML tools (#434).
- The bug icon on every screen now offers three things: Get support, Report a bug and Give feedback, in place of Bug, Feature and Suggestion. Feature requests are feedback. You still write a title and details first; then your mail app opens to fluenough@gmail.com with a subject and questions of the kind's own filled in, which you can change before you send. Bug reports and feedback become public GitHub issues, without your email address. Support mails stay private in the Fluenough inbox, and are never made issues (#160).
- Progress no longer has "Your strengths"; "Correct, by skill" and "How you learn" say the same, better.
- ख़ is now written k͟h in the Latin readings, as ISO 15919 writes it, in place of ḵ: the decks' readings, the romanisation files, the README table, the transcriber and the validator. Typing kh is still right, with its mark flagged (#339).
- Putting a sentence's words in order no longer gives the answer away: the tiles have no capitals, and each mark (। . ? , ! …) is a tile of its own, placed like a word. The card shown afterwards is unchanged (#347).

## [0.3.4] - 2026-10-06

### Added

- What's new, in Settings > Updates: each release's notes, newest first, fetched from GitHub when you open the page, with the version you have marked Installed. "See all releases on GitHub" opens the rest in your browser. Nothing is asked of GitHub until you open it (#198).
- A speaker button on match pairs that switches tap to hear: with it on, tapping a word says it, whether or not Play words automatically is on. It is on to begin with, and stays as you leave it. A meaning never speaks, and with sound off in Settings the button is greyed out. Early learners could not tell similar words apart by script or ISO letters alone, so a match was silent unless Play words automatically was on (#201).
- After you answer a review question about one word or phrase, the card shows what its lesson showed: the word with its reading, its meaning, its note and its first example, laid out as on the lesson's card. Typed, listening, multiple-choice, speaking and rearrange questions now do, as recognition already did; the reading follows Show romanisation. Match pairs, which asks several words at once, does not (#202).

### Changed

- In Settings, "Languages I speak" moves up to the top of the Learning section, above "Languages I’m learning", from Look and language (#195).
- Settings now calls the minimal-pairs switch Phonemic contrasts, and says what it lets you practise: the sounds the languages you speak don't have. It is still marked as incoming, and the skill is still Minimal pairs on decks and cards (#196).
- Where the decks' texts come from has a page of its own: Settings shows one Sources row that opens it, in place of the whole list, so Settings is less crowded. With no sources to show, there is no row (#197).
- Messages that pop up now show at the top, just under the title bar, instead of at the bottom, where they covered the buttons you press next. A tap goes through one to whatever is under it, and it goes by itself after four seconds (#199).
- Today now says how many words are due, not cards. Its review asks each word in one skill, so a word due in recognition and in speaking counts once. A skill's tile still reviews every word due in that skill, so it can hold more than the number on the tile (#200).
- Every word in a script that a note, a meaning, a description, a grammar label or a fact quotes now has its reading beside it: "లేదు (lēdu) is 'there is not', the opposite of ఉంది (undi)." A learner who could not read the script yet could not read those either. New decks must do the same: the deck validator rejects a word left without its reading (#402).

### Removed

- Add a deck no longer offers From Anki, which was shown as coming. Decks now carry paths, readings, IPA and grammar that an Anki deck has no place for, so it is not planned (#402).

## [0.3.3] - 2026-10-05

### Added

- Review by skill on Today. Tap a skill's tile to review what is due in it, in every language you learn. With nothing due, it offers to revise every word you know in that skill; as in quick revision, only the misses are recorded (#191).
- A Speaking tile on Today, while speaking is on (#191).
- Quick revision can take one skill, or Spoken (listening and speaking together), as well as all of them (#191).

### Changed

- While you type an answer in a language's own script, the "No keyboard? Try HeliBoard." line hides too, giving the card more room; it comes back when the keyboard closes (#185).

### Fixed

- Speaking cards no longer stop listening 3 seconds after you tap the microphone, whatever you are saying. They listen for up to 8 seconds, and stop once you stop talking. Being cut off mid-word, or before you had begun, gave "Didn't catch that" (#193).
- When a speaking card hears nothing, "Didn't catch that. Say it again." now shows in place of "Tap and say it", under the microphone, instead of below it, where the "Can't speak now" button covered it (#190).

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

[Unreleased]: https://github.com/aaronified/fluenough/compare/v0.3.4...HEAD
[0.3.4]: https://github.com/aaronified/fluenough/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/aaronified/fluenough/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/aaronified/fluenough/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/aaronified/fluenough/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/aaronified/fluenough/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/aaronified/fluenough/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/aaronified/fluenough/releases/tag/v0.1.0
