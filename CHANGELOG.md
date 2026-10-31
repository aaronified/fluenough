# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Fact languages in Settings.** Settings, under Your languages, has a Fact languages row that opens the same choice as the button on Today's fact card, so the two stay in sync. Its second line names the languages the fact is shown in, or says All known languages while nothing was chosen. It is there even when only one language is known.
- **A "What's new" sheet after an update.** The first launch after an update shows the headline of each change in the new version as a bullet, once per version and never on a fresh install; Settings > Updates > What's new keeps the full notes (#944). From now on each CHANGELOG line starts with a bold headline, as this one does (AGENTS.md, "Changelog entries"); `CHANGELOG.md` is bundled in the app so the sheet reads it offline.

### Changed

- **App log range.** The App log has three choices above its lines: Last 10 minutes, Since the app started (everything after the latest start) and All, as before. Copy and Export take only the chosen lines, so a bug report carries just those (#713). A Since the profile was opened choice follows with profiles (#204).
- **Deck search opens the course.** Tapping Add the course in a deck search now opens Add a language with the course's name already in its search, instead of the plain Languages list (#918).
- Natural Bengali and Hindi daily facts: the daily fact now reads naturally in the fact language you choose, with the Bengali and Hindi fact texts re-translated.
- **Faster start (#857).** The app shows its first screen without waiting for your review history to be read: it is read while the decks load, and Today waits for both. Listening and Say stay in Today's counts while the phone's voices are still being asked, so the tiles no longer appear late or jump, and the voices are asked all at once. Opening also rewrites only the saved card states that changed. Timing marks for the start go to the app log.
- **Less rework at start (#857).** Checking the phone's voices or the speech recogniser no longer throws away the counts worked out for every language when it finds nothing new, and the Decks and Progress tabs are not built until you first open them.

## [0.7.0] - 2026-10-31

### Added

- A minimal-pair button on cards (#423): a word with a pair note shows Compare with its partner in its "Sounds like another word" block, on the teach card and, once a question is answered, under the answer. It opens a popup over the whole screen, in a rounded border with a cross at its top right, with the two words side by side (stacked only when a script, reading or meaning would wrap), each with Play and Slow; Say one, which shows what the phone heard and which of the two it matched, never right or wrong; and Which did you hear, which plays one at random for you to tap. Practice only: nothing is recorded
- Picture choice (#91): a word that has a picture is asked, on alternate Recognition reviews of a card, unless the card is taken into a match-pairs group, as the word shown (or played, where the phone has a voice) and its picture to pick from four of the same deck's, two by two, in place of the meaning choice. It is a form of Recognition: recorded as Recognition, no schedule of its own. The pictures are never twins, near-twins or words that mean the same, a deck with fewer than four pictures never asks it, and a screen reader hears "Picture 1 of 4" until the answer is in.
- Typed notes show one at a time (#421): the teach card and the answer reveal show one of a card's notes, chosen at random, and every note of the card shows once before any repeats (a new round never opens with the last note shown); the word sheet still lists them all. A card with one note, or the old text, shows as before. `tools/propose_pairs.py` lists proposed `pair` notes, words whose IPA differs by one segment between very close sounds (length, aspiration, dental and retroflex); it changes no file.
- A Wiktionary link on a word's sheet (#422), for the word and its base words where the deck marks that Wiktionary has an entry; it opens in the browser and nothing is fetched until it is tapped
- Situations on Today (#724): six buttons, each in a colour of its own, open sheets of key phrases and words for everyday moments, with unlearned cards marked, Practise this sheet, and an inspect view of each card. A situations file per language lists real card ids (`kind: situations`, checked by the validator); Telugu has a first taxi sheet, and courses without sheets show the buttons dimmed with an Upcoming pill. A sheet's session teaches at most nine new cards at once, and Practise is off, with the reason beneath it, when nothing on the sheet can be taught or revised. The index lists the file under its own `situations` key, so the released app never sees it.
- `not_synonyms` (ADR-0050, #924): a card's native side (a single-file card, a ref or a layer's entry) may list typed English answers the synonym sets must not accept for it, the escape for a set partner of the wrong sense; the card's own answers and `alt_native` are never blocked. The validator checks its shape and `tools/validate_synonyms.py` checks it against the sets. Released apps reject the key, so no deck uses it until a release after this one.
- Reviewer proposals `alt_native_add` and `not_synonyms_add` (ADR-0050, #924): a proposal can add one accepted English answer or one refused synonym to a card's native side. The validator checks their shape, the review bot appends an agreed one to the card's list (leaving for the owner a refused word that is one of the card's own answers or that no set would accept), and `tools/synonym_candidates.py` lists the pairs several cards share as candidate sets. The app's reviewer mode does not offer them yet.

### Changed

- Deck and unit pages learn by a card-by-card walkthrough (#694, ADR-0024): Learn, or Relearn once every card is taught, walks every card on the teach card in place of the drilled lesson, taught or not (the deck page's cards in view; the unit page's every deck in order, each card showing its deck), and a sentence still waiting is walked and logged too. The unit page's Continue bar is now this one control, with "N new · M due" under it. The first view of an untaught card appends one review-log row (graded 0, in recognition, `asked: teach`) so FSRS starts it at the lowest window; a repeat view writes nothing, and accuracy, lapses, the FSRS fit, study hours and streaks skip the row. Today's lesson is unchanged.
- Validator: an English card meaning with a sentence break and no `;` is an error, since the typed-meaning grader accepts alternatives only across `;` (#924). Four cards whose sentences must all be said are listed in `MEANING_ALL_REQUIRED`.
- English is known by default, in Speak, Hear, Read and Write, for every learner, and the Latin script is known for everyone (#926): an existing install gets it at the next app open, a new one after setup; a choice made on the Languages page is kept. Learn stays Learn, so the diacritics of Spanish or French are still taught.
- Today's fact card has a small button at its top left that opens the languages the fact is shown in (#926): a box for each language you know, at least one always checked, kept for each profile; a fact missing a text in a checked language leaves it out, and English stands in when nothing else is left.
- Languages is one page for the languages you know and the ones you learn (#907): each language has four skills, Speak, Hear, Read and Write (Read and Write per script), and one pill per skill cycles Leave, Know, Learn. One Learn skill downloads the language's full decks; a skill changed to Learn is checked (a sound test, or the script showing on the phone) from the sheet's Check button; a language with every skill Leave goes back to the pool and its decks go at the next app open. The list shows icon chips, filter pills and the minutes a day for each language (a stepper, 5 to 60); Find my level, Placed words, a deck update check and a details panel are on the sheet, and a Review switch in Settings (off by default) turns on the fit-your-level prompts. Settings has one Languages row in place of Languages I know and Languages I'm learning; current learners' lists read as skills until they edit.
- Languages: a language's decks are kept while any profile still learns it, a profile whose own list disagrees reads its own, an unreadable stored entry is no longer taken for Leave, and the search field uses the field corner radius (#907).

- The day's session runs on a clock, not on a fixed set of cards (#886): the time is the minutes a day, the header shows a ticking countdown of the time left in place of the card count, and the clock pauses while one screen has been showing for more than 30 seconds. It builds a round at a time, reviews and new words in the ratio the time left asks for; with nothing due it teaches up to 15 new words, asks each twice with older reviews mixed in, and fills the rest of the time with the cards closest to due. Teach cards now record their time, which counts toward the day's minutes and the hours.

### Added

- Reviewer daily questions (#519): a reviewer can answer a few short questions a day that the app writes from the cards, about the weakest data first (a meaning, an example, a confusable, a recording; unverified data before Wiktionary's). Yes or No with fixed reasons and an optional line for the mail; a recording can only be flagged. The number a day is chosen in a new step of How reviewing works and in Settings > Reviewing (default 10; what is not answered waits). The answers go in the same mail as the reviews that wait: one mail, a file for each deck and each language of answers, sent from either Send answers or Send review. The mail job files one issue with counts only, and the review bot tallies the answers in `review-answers/`: two agreeing Yes settle a data point right, and a new optional card field `verified` lists the settled points so the app stops asking (validator, parser and `content_sha256` know it; the bot writes it only once a released app reads it, `WRITE_VERIFIED`). The first No opens a pull request for the data point and the next answer decides it: the same answer merges it, a Yes closes it for good; a flagged recording that is merged is taken off its card (and its file), which then uses text-to-speech, and any other point is a flag note for the owner. Picture proposals have a question type and a pinned-file answer, waiting for a source that keeps them; the open contribution form comes later.
- Typed English meanings accept a word that means the same as the card's answer (#924, ADR-0050): the app reads sets of absolute synonyms from a bundled file (`assets/synonyms/en.yaml`, CC BY-SA 4.0, empty until the first sets are added), and a typed word of the card's set is right, with a hint under the answer ("Also: take care", or "Also right" for a longer one). It takes an optional article (and "to" on a verb card) before the word and nothing after it, finds regular endings by rule (-s, -ed, -ing, -er, -est; -elled and -eled are one spelling), and forgives a typo of a synonym as it does of the answer itself. A missing or broken file means no synonyms. The Sources screen credits Wiktionary and Open English WordNet for the sets, and CI checks the file with `tools/validate_synonyms.py`.
- English synonym sets: batch 0, 201 regional spelling variants (#924)
- Reviewers see and correct every card field (#508): Suggest a change is grouped (the word, meaning, examples, base words, related words, notes, picture and sound, facts and sets, place) and shows every field a card carries, with a pencil on each item of a list (other senses, examples, synonyms, antonyms, confusables, minimal pairs, forms, collocations, facts), **Add** at the end and **Flag as missing** on a field with no data. Each item has **Looks right**, with a count of what is left to check beside the field's name, and a checked item moves below the rest; Wiktionary's items are marked semi-verified and come last. The narrow IPA, the frequency, the image, the recording and the set card are flag-only, and a **Teach-card warning** box opens a picker of the card's own warnings (no automatic choice). The review file carries the new suggestions (`flag`, an item's `word` and `action`) and `items_right`; the review bot leaves the list items, the facts and the flags for the owner, as it does an example or a picture, but applies a gender, a register, a `hears` mark and a teach-card warning like a reading, each only with a value the field may have: other reviewers see them with Accept, Edit and Reject.
- A long press on a button without text shows a small hint, one word where one word is enough (#913): the icon buttons, the skill pills, the practise and microphone buttons. It is one themed `Tooltip` behind a shared `Hint` widget, and a test fails for a new `IconButton` without `tooltip:` or an icon-only control without a hint.
- The hints follow-up (#913): the Languages page and sheet icons (Add, Update, Info, Delete) and the bug icon on every screen show one word on a long press, and a skill pill shows only its skill and state ("Read: Know"); the pills still cycle on a tap.
- The Sources screen credits Wiktionary for the narrow IPA: "Pronunciations in [ ] adapted from Wiktionary, licensed CC BY-SA 4.0." Tapping it opens Wiktionary, and the decks' licence row opens the CC BY-SA 4.0 text. The deck docs carry the same line.

- The app removes its own junk, at most once a day a few seconds after it starts and again after an update (#493): update APKs other than the one waiting to install, half-written `.part` download files and copies of a backup made for a restore older than a day, and report attachments older than three days. Your backups, decks, progress and settings are never touched, and each run that removes something says so in the app log.
- The Decks search forgives typos and takes tokens (#527): "travl" finds Travel and "numbrs" the numbers units, looked for only when nothing matches exactly and then marked "Close matches for ..."; `kind:` (words, grammar, script, reading), `status:` (not learnt, learning, learnt, forgetting, struggling, set aside) and `theme:` (this course's themes) become chips inside the bar, with a menu of their values; each result shows its kind as a chip that narrows the search when tapped; the tokens are offered when the search is opened, with the path dimmed behind it, and the first tap on ✕ clears while the next closes; a theme may carry search tags (`travel` on transport); a query in a script the course does not read offers to switch course, add a course or add the language to the ones you know; the card list has no cap and is built as it scrolls. Finishing it: it searches through a SQLite FTS5 trigram index (a pure-Dart matcher stands in on the web or where SQLite lacks FTS5, ADR-0049); the chips share the bar's lines with the text; a tap on the dimmed path closes the search; a swipe on the bar runs the same search in the next course; "Add the course" opens the language picker at that course; a grammar table's rows are found as words by lemma, reading and gloss; and a word taught in several decks is one row that says "In Family and 1 more deck".
- The daily reminder (#90): Settings > Reminders has a switch and a time. It shows one notification a day, at the time you pick, on days with cards due, saying only how many are due; tapping it opens Today. Android 13 and later ask to allow notifications when you switch it on, never at launch, and a refusal leaves it off and says how to allow them. It never fires while the app is open, and is scheduled inexactly, so it needs no exact-alarm permission. It adds the `flutter_local_notifications` plugin (agreed with the owner, 2026-10-30).
- `tools/import_phonetic.py` writes each card's narrow `[ ]` IPA from Wiktionary (the language's kaikki.org dump, downloaded once into the git-ignored `.cache/phonetic/`) into `phonetic`, with `phonetic_source: "wiktionary"`, and `tools/derive_phonetic.py` derives it by the rules in `decks/<lang>/<lang>-phonetics.yaml` (Bengali, Hindustani, Spanish; kind `phonetics`, checked by the validator, not in the index) for the cards Wiktionary lacks, with `phonetic_source: "rules"`; both patch the deck text and report coverage per deck. No deck has been changed yet.

- Suggest a change has a Place box, last among the boxes: its pencil opens Move this card, which offers only the units of the course's B1 plan that have a deck (a planned one is shown greyed), never free text, and says that a new theme or unit goes by pull request. The review bot applies an agreed move by moving the card, with its layers' entries, to the end of the other deck's files with its id kept, and refuses a unit the path does not list. Editing the Meaning shows the rule that it never changes, and How reviewing works gains a step with the five reviewer rules, in `docs/REVIEWING.md` too (#477).

### Changed

- Opening the app is faster after the first launch: the decks' YAML is kept as one compact JSON file and read again only for a deck file that changed, so a cold start no longer parses every downloaded deck's YAML (#875, ADR-0048). Nothing a learner sees changes but the wait.
- Corners are consistent across the app: one radius scale (4, 8, 12, 16, 24, 32, 40 and a stadium for shapes that follow their size) with a token for each role, every hand-written radius in the interface is now a token, and the theme's buttons, chips, text fields, dialogs, bottom sheets, snack bars, cards and list tiles take their shape from the same tokens (#878). Corners move by 2 to 4 px at most.

### Fixed

- An app update whose install was cancelled is no longer downloaded again (#487): the row says "{version} is downloaded" with Install, which opens Android's installer on the kept file with no download and no second backup, and Delete download. The kept file is reused only if its size (and the release's SHA-256, when GitHub gives one) still matches; otherwise it is deleted and downloaded again. The junk cleanup still deletes it after a day with nothing waiting on it.
- The session result shows how each skill did, one pill per skill answered in its icon and colour with "3 right of 4" beside it (#486); a session with no graded answer shows no pills and says so. The minutes, card count and percentage are gone, since the countdown already tells the time.
- Opening the app replays the review log once, not twice, and reads it from the database once, not three times, so it opens sooner for a learner with a long history (#857). The numbers shown do not change.
- Opening the app no longer freezes the first screens while every downloaded deck's YAML is read: the decks are parsed on a background isolate (#875). Nothing a learner sees changes but the wait.

## [0.6.8] - 2026-10-30

### Changed

- The teach card is redrawn like the review's answer screen: a New word or New phrase pill beside the deck name, one card as tall as its content with the word, its speaker and IPA on one row, the meaning with a dictionary icon and part of speech, the picture, every note in full, up to three examples and a short table of forms, scrolling when it is long. Review's answer page shows Again, Hard, Good and Easy in one row at every text size, and a swipe on the card (or the chevron) records Good.

### Added

- `wiki/Roadmap.md` is now generated by `tools/generate_roadmap.py` and the Roadmap workflow, from the GitHub releases, milestones, approved issues and the plans (#484).
- When the speaking drill fails for want of a network, the app now says why: it asks `raw.githubusercontent.com` and `connectivitycheck.gstatic.com` once, with no body, cookies or headers of ours, and tells offline, GitHub blocked, Google unreachable and a failed recognition service apart.

### Fixed

- The deck validator no longer asks for a transliteration beside the Greek-script letters (β, θ, χ) that IPA uses in a card's `phonetic` field.
- The teach card's swipe chevrons no longer flicker on every touch: a tap, a scroll or the speaker button shows nothing, and they show for 1 s when the card first appears, then only when a swipe begins, and go 1 s after it ends.
- Reports mailed from the app are filed as issues within about 15 minutes, not hours (GitHub may still delay scheduled runs; the workflow can be run by hand), and the public issue no longer carries the sender's mail address or signature.

## [0.6.7] - 2026-10-26

### Fixed

- A Today skill tile that showed 1 due no longer opens "Nothing due": a skill's own review now samples a deck's known cards by what the deck had today in every skill, as Today's does.

### Changed

- Layout follow-ups from the 1.4x screenshot review: the script guide puts a letter tile above its text at large text; each source on Sources is its own line; the onboarding languages list has a divider above its button; the speaking test buttons are two equal halves; trailing controls in Settings rows share one right edge; Today's skill tile names share a baseline; the mastery star keeps 16 px above and below instead of about 60.
- Progress is redrawn: two count tiles on top (words and rules) with an icon and a bar, the level tile filled before A1, icons on the hours tiles, a check when there are no leeches, and a larger mastery star whose skill names are each always in their own colour, the same in light and dark and on every theme.
- All tags is two lines and a thin bar a row, with a round play button inline, "Nothing taught yet" for a tag with no taught word, and a sort menu (weakest first, A to Z, most words).
- A wrong spoken answer now shows what was heard and, when the word is in a deck, its IPA on a second line; it no longer repeats the answer shown on the card.
- Today's skill tiles put the number on the icon row with the pace arrow, in two lines; the arrow is hidden above 99 cards.
- The course card on Decks has a sync button that looks for deck updates and downloads them, with the download shown on the bar and a toast when there is nothing to download; the hours left are one line under the bar.
- Your decks moved from the Settings list into Your languages.

## [0.6.6] - 2026-10-26

### Added

- The app runs in a browser, at https://aaronified.github.io/fluenough/ once Pages is on: progress stays in the browser, and decks download on each visit (wiki: Plan-Web-Pwa).
- In the browser the app is drawn phone-shaped and centred, not across the whole window.

### Fixed

- The app's text looked wide, with large gaps between words, on phones whose system answers the request for Roboto with another font: Roboto is now bundled and used for all interface text.

### Changed

- Decks may carry a narrow IPA form for a word, with its source (`phonetic` and `phonetic_source`, from Wiktionary or from rules). The app reads them and does not show them yet; the decks will use them from the release after this one.
- A release's notes, which "What's new" shows, are now this changelog's section for that version and nothing else: GitHub's list of merged pull requests, which named every deck pull request, is no longer added.

## [0.6.5] - 2026-10-26

### Changed

- A language's sheet names the scripts being learnt in one line, such as "Devanagari (1/2)", above the Change scripts button, and no longer has a button for each script (#859).

### Fixed

- Set in stone did not stop reviews of words you had already reviewed before placing their deck: a placed deck now follows the course's placed-review choice for every card in it, whatever its history (#860).

## [0.6.4] - 2026-10-26

### Fixed

- The app froze for about a second after answers and taps: hidden tabs no longer rebuild, and sessions, progress and themes are kept per language and worked out once per change, so one language's answer leaves the others alone, even with dozens of languages and years of reviews.

## [0.6.3] - 2026-10-25

### Fixed

- Speaking Hindustani on a Samsung phone always said "Didn't catch that": the recogniser's final result came after Android's done signal, and the app had already given up. The app now waits a moment for the final result and uses the last partial one if none comes, and the app log says whether the listen ended with done before a result or with an empty result.
- Fixed alignment and spacing across the app at large text: one large-text check (the old checks read a 1 px probe or thresholds above the 1.4x cap), one text inset, even chip rows, cards of one width on deck and unit pages, and steady columns in unit, leech and review rows.
- The placement match question centres its labels, fits three-line labels in a rounded box, and lines the two columns up row by row.

### Added

- The script test's read-aloud question has "Can't speak now": it skips the question without counting it as a miss, and asks a word to write in Latin letters instead.

## [0.6.2] - 2026-10-25

### Added

- Braille is drawn with shadow dots: every cell shows all six positions, raised dots solid and unraised ones as thin rings, so that a lone dot's column and row can be read on a phone. The app carries its own small braille font (OFL, built by `tools/make_braille_font.py`), used for braille on cards, notes, the typed answer and the braille keyboard, never the phone's font (#835).
- Settings has a "Support with a cup of tea" row, which opens a page saying that a tip is simply a show of support, brings no preferential treatment or access to anything extra, and that reviewing decks and sending bug reports help just as much, if not more. "Open my UPI app" opens a `upi://pay` link to das.arani@pingpay with no amount, and says so if no app can open it; "Copy UPI ID" copies the ID for a phone with no UPI app. The release's manifest gets a query for `upi` links.
- A language's sheet, seen when the language is picked and on Languages I'm learning, can suggest up to three other ways to learn it, in a card above the course with a short line and a "Visit" button that opens the site in the browser; the learner can hide a suggestion for good on Languages I'm learning. A language's suggestions are its `decks/<lang>/<lang>-resources.yaml`, listed in the index apart from the decks so the released app is unaffected, and Japanese suggests the game Wagotabi (#832).

### Changed

- Today's skill tiles are thinner, three to a row, each showing only the skill's icon, an arrow up or down when its pace is adjusted, and the number due, with the skill's name in small type under them; the words "More reviews" and "Fewer reviews" are gone, the arrow keeping them for a screen reader. A new Script tile, in a course with script decks, holds script reading and writing together (the script decks' Recognition and Write), and tapping it drills those; they no longer count in Recognition's and Write's tiles or pace.

- Japanese's Chinese-character script is named "Kanji", and Mandarin's two are "Simplified Hanzi" and "Traditional Hanzi", wherever the app and the README name a script; they were "Han", "Simplified Han" and "Traditional Han". Only the names shown change, never the script codes.

## [0.6.1] - 2026-10-24

### Added

- `tools/deck_similarity.py` lists, for a reviewer, the words of a language that sound alike (IPA one segment apart, only between very close sounds: short and long, unaspirated and aspirated, dental and retroflex), the same spelling with another sound, and spellings a nukta, or a chandrabindu and an anusvara, apart, marking each pair a `pair`, `homograph` or `lookalike` note already explains; it only warns and changes no deck (#692).
- A deck of offensive words no native speaker has rated is reviewer-only: tagged `offensive` and not yet `rated`, it is in no learner's lessons, Today, review or deck list, with Adult content on or off, and only the language's Offensive words review lists it, where its words are rated; once its raters' median has set each band the deck gains the tag `rated` and follows the adult gate. The tag is an ordinary deck tag, so no app needs to be updated to read decks that use it, and the validator rejects `rated` on a deck not tagged `offensive` (#630).
- The Offensive words review lists a deck of offensive words no native speaker has rated only when Adult content is on, as it lists a rated one; with it off, the unrated deck is not there either (#630).
- `tools/offensive_alikes.py` lists the words of a language that sound (IPA, at most one segment apart) or look (script or ISO 15919-based reading, at most one letter or mark apart) like one of its offensive words, for a reviewer to keep or reject; the deck validator warns of a close pair no `pair` note (sound) or `lookalike` or `homograph` note (writing) explains (#629).
- A reviewer who rejects a sound-alike or look-alike pair of an offensive word records it on the card with the new core-card keys `not_sounds_like` and `not_looks_like`, a list of the offensive words' ids; the app reads the keys, `tools/offensive_alikes.py` lists the pair as explained and the validator no longer warns of it. Released apps reject a card key they do not know, so no deck uses the keys until a release carrying this one is out (#808).
- The README states the app's main features (FSRS scheduling, the Indian courses, the Progress stats, several scripts, Hear, Say, Read and Write, community reviews), and its list of languages, with their scripts and the highest level written, is filled from `decks/index.json` by `tools/readme_languages.py` each time the decks change.
- The font check (#611): a course asks, once for each script it is read in, whether you can read a sample line, and downloads the script's font only if you say it shows boxes, then shows the sample again in it; Settings, Look and language, Script fonts, lists each script with where it stands and checks again. Fonts a course brought before stay. Noto Sans SC (Chinese), JP (Japanese kana and kanji) and KR (Korean) join the fonts a course can download, 17.8, 9.6 and 10.4 MB.
- Noto Sans TC (Traditional Chinese, 11.9 MB) joins the fonts a course can download, and Japanese's kanji (`han`) draw in Noto Sans JP, 9.6 MB, as its kana do; the font check asks about each script with a sample line (#611).
- The transcriber reads Japanese kana (Hepburn and IPA), Korean Hangul (Revised Romanization with its sound changes between syllables), Mandarin (Wiktionary's pinyin as the hint) and Toki Pona (IPA); the Wiktionary importer uses them, takes only a Mandarin IPA for Chinese, and leaves Maithili and the other Devanagari languages with their own rules unread instead of reading them by Hindi's (#612). Tamil, Malayalam, Odia, Gurmukhi, Urdu and the sign tables are not done.
- The deck validator rejects a unit whose planned theme comes with a grammar list beside `planned`, as the app already does, and a planned grammar unit may give its grammar beside `planned` (#622).
- A path may set its own words per level with `levels:` (for example `{ A1: 120, A2: 60, B1: 80 }`), which the deck validator and the app both read; a planned theme unit may plan 0 words, and phrases count toward no level's words (#615).
- Progress shows hours spent (each answer at most a minute) and about how many hours are left to the end of B1, in a tile row under the mastery star; tapping it opens a popup with each language's hours (#227).

### Changed

- A grammar pattern's `prompt` is optional and retired: without one, the app asks a cell as the lemma, its meaning and the slot, "hablar (to speak) — nosotros", and a deck that gives one is read as written; the deck validator accepts a pattern or a layer without one and warns of one given. Shipped decks keep theirs until the apps that require it are out of use (#522, ADR-0039).
- A word or rule is known as Progress counts known, in the unit page and the unlock gate too: your last review in each skill was right and the app gave you at least 85% recall then, in place of 9 of your last 10 answers right; a word reviewed once is not known yet (#416).
- Progress shows three tiles, Words, Rules and Sentences, in place of the Words tile, counted against what is taught so far with words counted by base word; the Level tile sits alone below them. The end of a lesson says how many words and rules it made known and how many sentences it opened (#418).
- A rule is taught on its own card before its first question: its name, what it means and its forms on words you know. A grammar question asks you to choose among the forms of one word first, then to type; after an answer the word's forms in the rule are shown with the one asked marked. A rule's table on the unit page shows only words you know or have been asked, each form marked known, learning or not asked yet (#417).
- A lesson takes the next items in the path's order instead of three of each difficulty, fewer new ones while the words and rules you were taught are not yet known, and a sentence waits until every word and rule in it is known. A rules table's cell is taught only for a word you know. The unit page counts sentences open by that rule, lists the phrasebook on its own, and greys a closed sentence with what it waits for; a tap says why (#416).
- The IPA course is one entry in the list of languages, the whole chart: "IPA: my languages" is gone, with its setting, and the card tags that picked the symbols of your languages stay for focusing. Progress is shared by card, so nothing is lost; "The sounds of this word" is unchanged (#735).
- Languages you know lists the living and constructed languages the course paths teach: French, Spanish, German, Mandarin Chinese, Japanese, Korean, Esperanto, Toki Pona, Lojban and Interslavic, in new families (Romance, Sinitic, Koreanic, Japonic, Constructed) with names for the Han (simplified and traditional), Kana, Hangul and Cyrillic scripts. Ancient languages nobody speaks (Sumerian, Egyptian, Mycenaean Greek, Proto-Indo-European) stay off the list (#613).
- The word-order drill lays its tiles out in the deck's direction: an Urdu sentence is built from the right in an English app. Where the interface quotes right-to-left deck text, as in "Answer: …", the quote is isolated from the words around it (#619). Checking an Urdu deck on a device, and the interface itself laid out right to left, are not done.
- With Adult content off (the default), a deck of offensive words and any rude card (tagged or registered `offensive`) are hidden everywhere: not listed, not taught in lessons, and not in Today, reviews or practice; they come back when Adult content is turned on. The warning on a word that sounds like a rude one still shows, without the rude word (#628).

### Fixed

- The deck validator reads an apostrophe inside an Assamese word in a note, as in ক'লা or ম'হ, as part of the word, so one reading beside it is enough; a quote around a word still ends it.
- A typed answer no longer loses transliteration letters: pinyin's caron vowels (ǎ ǐ ǒ ǔ ǚ), Egyptian ꜣ ꜥ ḫ ẖ ṯ ḏ ḳ (typed 3, a, kh, ch, th, dh, q, so that ḫrw and hrw stay different words), Proto-Indo-European ḱ ǵ ḗ ṓ, subscript digits (du₃, h₂) and ʰ ʷ are folded to what a keyboard types, so `lu` is right for lǔ and `h2owis` for h₂ówis (#616). Arabic-script, Lojban and Mycenaean typing are not done.
- The language bar is expanded at launch, not only after the first drag; its glyphs sit evenly a detent apart on both sides of the expanded name; the further a glyph is from the centre the smaller and fainter it is, at rest as well as while dragged; and nothing is drawn under the bug button (#774).

## [0.6.0] - 2026-10-23

### Added

- After placement, choose per course how the placed words are reviewed: Set in stone (kept out of Today and counted as known; from a deck page the words can still be revised or practised, without writing reviews), Spot-check (the default: sampled, a miss widens coverage) or Keep reviewing; changeable from a Placed words row in Languages I'm learning, and switching away from Set in stone returns the words to reviews. A placement taken before this release has no saved placement time, so the choice does not apply to it (#761).
- Progress shows the words mastered, the course's level (bronze, silver or gold) with its start date, a 7-day calendar with the streak as a line, and a six-skill mastery star that opens charts over time, in place of the stat tiles and the 12-week grid (#678).
- Today has one button for the day (#521, #485): a ring that fills toward your minutes a day, with "12 of 15 min" under it and the split of reviews and new words, which mixes both in one session, the reviews you are most likely to have forgotten first; when the minutes are done it reads "Done for today", with a smaller "Keep going" for five more. When reviews have piled up beyond three days of your minutes, Today says so with how long they take and how soon you will catch up, and a "+ 5 min" button adds five minutes each tap (a long press takes five away). Quick revision is now a separate minus, start and plus: 5 minutes to begin with, in steps of 5, reviewing only. Each language you are learning has a Minutes a day setting in Languages I'm learning, 15 to begin with, from 5 to 60. A Situations card for cheatsheets of everyday phrases (#724) waits below, marked as incoming.
- A lesson asks each skill as the first question type the card's data allows (the registry, not a switch on difficulty), and reads a card's single-base siblings, so a card with sibling forms, or a pattern cell with siblings, is also asked its grammar skills (form questions); lessons of cards without siblings are unchanged (#522).
- `letter` and `digit` are parts of speech of a card, and a card may be marked `hears: form`; Hear asks for the form of such a card, and of a generated number, by the card's own data, not by whether its deck is on the alphabet list (#522, step 7).
- `modes` on a card is now an opt-out: the skills it is excluded from, so a card with none is asked every skill its data allows, including the grammar skills where it has single-base siblings; `tools/convert_modes.py` converts the shipped lists, merged with the release that reads them this way (#522, step 6).
- A generated number is an ordinary card whose data says it is practice only (never logged) and heard as its form, no longer a special class; reading passages are unchanged (#522, step 9a).
- Rearranging is eligible by the card's data (three or more words in the target, or two in a phrase) through the question-type registry, which never rearranges a reading question, with the same questions as before (#522, step 5).
- The two grammar question types are now eligible by whether the card's word has other forms (`Card.hasOtherForms`) or has sibling cards (`formSiblings`: each has exactly one base, the same card), and a rules cell's lesson questions come from the registry, with the same questions as before (#522, step 4).
- Wrong options in a choice question are now taken first from cards that share the answer's word family, part of speech or tags (`lib/core/scheduling/distractors.dart`), with the same pool as before (#522, step 3).
- A question-type registry in `lib/core/scheduling/question_type.dart`: how a review asks each item is now chosen by one list of types, each with its skill and when it is eligible, with the same questions as before (#522, step 2).
- Progress: Weakest tags has an "All tags ›" button to a page of every tag with its bar and share remembered in the chosen range, and a Practise button on each: a random set of up to 20 taught words with that tag, in the language chosen at the top, with every answer recorded (#499).
- The `wiki/` folder is published to the GitHub wiki by a workflow whenever it changes on main.
- A card can set `picture_ask: true`: its `picture` is drawn with a small "?" badge, for question words (#707).

### Changed

- Progress: Weakest tags and All tags rank by what you know now, not by the share of right answers all time: a tag's weakness is the share of its taught words and forms that are not known now (the star's rule), ties going to the lower recall now, then the name; the bars show the share known. The Over time page ends with a How you learn entry that opens that page (#678).
- The language bar is a centred, looping wheel with the selection fixed at the centre (All moves to the left on Progress): it follows the finger 1:1, ticks at each language, coasts to a detent on a fling and settles on a spring, a touch stops it, and the pill then grows over 0.3 s to the language's name (#703, #682).
- The four tabs slide: the pages follow the finger and settle on a tab with a spring (stiffness 400, damping ratio 0.75, no bounce on a slow release), a tap on the bar slides in 0.3 s, a touch catches the pages mid-way, and the pages rubber-band at Today and Settings (#683).
- The deck validator ends a failing run with an `Errors:` section repeating every error (cross-file ones, and each file's with its file), so CI's log shows them at its tail; a passing run is unchanged.
- A word is taught on one screen with no scrolling (#691): the word large with its reading, speaker and IPA, the picture beside it, the meaning across the full width, a note and one warning. Tap the IPA for each sound of the word, from the IPA course, with its practice; tap the meaning for the dictionary, with its etymology and examples. There is no Continue button: swipe the card, which follows your finger and settles on a spring, or tap the chevron that shows while you touch the screen.
- A deck's card can say which warning its teach card shows, with a `warning` key (#691): the id of one of its sound-alike, homograph or look-alike notes, "senses" for its other meanings, or "none". Without it the teach card keeps the order it had; the word sheet still shows every warning. The validator checks the key, and `tools/pick_warning.py` picks it for existing decks (a rude word only when it is very close and very rude).
- A deck's page lists every word with its meaning and where you stand with it, and its tag chips filter the words as you tap them. At the foot, Practice asks which skills and drills the words in view in them, due or not, and + Learn, with a badge counting the words in view not taught yet, teaches them; once every word of the deck is taught it becomes Relearn, which walks through the words in view (all of them with no filter, only the filtered ones with one) on the teach card, swiping or with the chevrons, and writes nothing (#694). The per-skill buttons and Inspect are gone: a word's sheet now shows everything its card has, unfolded, including how it is said symbol by symbol, its dictionary entry, every example and warning with its title, and how hard you have found it in each skill (#693).
- Words you know come up a few at a time (#680). A word is known when FSRS gave it an 85% or better chance of being remembered at its last review. When a deck's known words come due, Today asks two of them a day, the ones you reviewed longest ago; once they are right, the deck's other due known words wait for another day, so each has its turn within a few days and none is left out. If one is wrong, three to five more are asked, and if those go wrong too, all of the deck's due known words come up.
- A finished deck's Revise now records its answers and moves the schedule, like quick revision; only number practice is unrecorded (#499, ADR-0033).

### Fixed

- Perso-Arabic letters, such as the three dots of پ, no longer overlap the reading under them in the word sheet and sit centred in their rows: a script that runs right to left (Hindustani's Perso-Arabic as well as Urdu) gets the tall line height with its extra space shared evenly above and below, wherever it is drawn (#762).
- CI: the deck tools' tests no longer fail on every deck pull request for a stale `decks/index.json`; the test that validates the real decks skips the index check, which is regenerated on main after merge and still tested on its own.
- A read-aloud question in the placement check no longer ends the moment the phone's recogniser hears nothing: it says it did not hear, and lets the learner speak again or say they don't know, as the speaking drill does.
- A one-word label on a number tile, such as "Remembered" on Progress, shrinks to fit at large text instead of breaking mid-word (#492).
- The session result counts the time spent answering, each answer capped at 60 seconds, instead of the time the app was open, so a short lesson no longer reads 31 minutes (#486, minutes only; the card count is still open).

## [0.5.4] - 2026-10-21

0.5.3 was never published: its build failed, so its changes ship here.

### Added

- The Decks tab search finds cards (#527): a word, its spelling in another script, its reading or its meaning, ignoring case and accents, one row for each card, listed after the units and decks. Tapping a row opens the word.
- The deck reader accepts the `homograph` and `lookalike` note kinds and a layer's `dictionary` entry (#692). Nothing shows them yet.

### Changed

- A sideways swipe on Home, Decks, Progress or Settings moves to the next or previous tab, stopping at the ends (#683). An upright drag still scrolls the page, and the language bar keeps its own swipe.
- The language bar scrolls with momentum (#682): a drag or fling across its width passes at least five languages, each highlighted with a light tick as it goes by, and it settles on the nearest one, switching the screen once, at the end. A short flick still moves one, and it stops at the ends.
- Find my level is shorter and checks each script (#481). It asks "Do you read Devanagari?" for each of a course's scripts, saying so when you read it through a language you know; No starts its script decks from the first letters with no questions, and Yes asks up to five questions, from a letter to a word read aloud, with one more try at each. Then it walks the word decks one question each, skipping ahead and jumping to the end while you know them, says where you start and why, and lets you try again from there.
- Find my level credits what it found (#677). A script you read is credited Read and Write on Progress; one it stopped part-way in is credited Read for its letters and joined letters only. The cards of the decks it placed are recorded as Easy answers today, as if mastered, so they come up rarely. A card you have already reviewed keeps its own.

### Fixed

- Find my level shows each word as drills do: in the scripts you learn, such as Perso-Arabic for Hindustani, with the other beneath when you learn both, and never the reading first when you already read one of the language's scripts through a language you know. A question about a word's form names the word once and offers only its forms, of which one alone is right.
- The Inspect screen no longer cuts off a row at large text (#671).

## [0.5.2] - 2026-10-20

The app's database moves to version 9: each answer now records the script it was shown or typed in, and how it was asked. A backup made by this version can still be restored by 0.5.1, which passes the two new fields by. Going back to an older version after updating is not supported. Your progress is kept by card id, and no card id changed.

### Added

- Read and Write are tracked for each script a course is learned in, such as Devanagari and Perso-Arabic for Hindustani, and Progress shows each (#656). Script decks count in full; outside them, reading a word shown in the script, choosing among options written in it, or typing a Write answer in it counts as half a review. Past script practice counts for the course's main script.
- Learn a language in the scripts you choose (#650): Hindustani in Devanagari, Perso-Arabic or both. Cards show your script first, with the other beneath when you learn both, and a typed answer counts in either script you learn.
- Each script has its own guide: the Perso-Arabic decks show the Perso-Arabic guide, not the Devanagari one (#645).
- Script fonts download with each course, and the app says while a font is downloading (#652).
- Voices lists every voice a course uses, such as Hindi and Urdu for Hindustani. When one is missing, the other says the card in its own script. The page also links voice apps you can install instead (#648).
- The IPA quiz offers hand-picked wrong options for every symbol (#649).
- English Braille can be learned as a course of its own, like the IPA: chosen only when you add it, with no level to find and no voice, and Complete once its path is written. Its answers are typed on the app's own braille keyboard, six dots in the Perkins layout with Enter cell, Space and Backspace, in place of the phone's keyboard (ADR-0043).

### Changed

- Hindustani's Perso-Arabic script is drawn in Nastaliq (#646).
- Meaning answers are graded by rule (#654): case, punctuation, contractions, text in brackets, a leading "to", "please", and ok, okay or o.k. no longer make a right answer wrong, and any one of a card's meanings is accepted.
- A long drag or a hard fling on the language bar passes several languages (#647).
- The IPA course is tagged Complete once its path is written, instead of Alpha: it has no CEFR levels to measure it by (#658).

### Fixed

- A deck download no longer stops at the first dropped connection: a file that fails as offline is tried again up to three more times, after 1, 3 and 9 seconds, and a course's files share one connection. Files also download in parallel, six at a time shared fairly between the languages downloading together, instead of one after another. The log names the cause, such as SocketException.
- A notation's course, the IPA's or braille's, shows Complete in the language list before its decks are downloaded too, not Alpha.

## [0.5.1] - 2026-10-19

### Added

- Languages I'm learning, redone in line with Languages I know (#626): short rows grouped as Learning, Popular and by language family, with search pinned at the top; each row shows your progress and the course's Alpha, Beta or Complete tag, with Update only when an update is waiting and Remove as a red ×. One button checks for deck updates and then becomes Update all. Tapping a language opens its sheet with the course's A1–A2–B1–culture line, what it is taught from, its size and units, Find my level (also on Progress) and Change scripts; Learn this language asks, on screens of their own with Back, which of its scripts to learn and where to start.

### Changed

- Hindi and Urdu are one course, Hindustani (#623): the `hi` course and its card ids stay, and it is named Hindustani wherever the app shows a language. Languages I know offers its two scripts, Devanagari and Perso-Arabic, as it does for Punjabi; knowing Hindustani never hides it from Languages I'm learning, so you can learn it for a script you don't read.
- Languages I know asks about a language's script in that language's own script, with the English under it, for every language that has the sentences, checked by a speaker or not (#621). Those not yet checked have a bug icon to report a mistake.

### Fixed

- A language whose course has a path but no deck yet is no longer listed as an empty course (#620, #624).

## [0.5.0] - 2026-10-18

The app's database moves to version 8 (a log of restores). A backup made by 0.5.0 that holds a fitted script skill cannot be restored by 0.4.4 or older, and going back to an older version after updating is not supported. Your progress is kept by card id, and no card id changed.

### Added

- Backup and restore (#470): Your data → Back up now saves a backup file where you choose and keeps a copy; Recent backups lists the copies, each with Download and Restore; Restore from a file reads a backup, shows what it holds, and replaces your progress only after you confirm. A copy of what is replaced is always kept first, and each restore is logged. A backup from a newer Fluenough is refused, naming its version.
- Read script and Write script (#556): two skills of their own for each language with its own script, from your answers to the script lessons, each with its own schedule, a row on Progress and a line in How you learn. Past answers count: the skills are worked out from your review log.
- Facts on cards (#546): a word's sheet, and its card in a unit, ends with the facts that name it. The daily fact prefers one about a word you are studying.
- Waiting for review (#471): your reviews first, those not sent and those sent with their state, then each language folded with its unreviewed counts.
- Suggest a change (#476): change, add and remove a card's base words; a new word goes as one review.
- Telugu: the adverbs unit, 50 words (how well, how often, when, how much, where), with a listening and a reading passage.
- Your data: the review log shows the last 10 answers, and up to 50.

### Changed

- Every course's path is rebuilt (#562): a phrasebook, the first words, the script after the first units, a core of about 200 common words, then rules, then sentences.
- Scripts have their own names (#551, #559): Eastern Nagari, not "Bengali script", and a language can have several. Languages I know asks whether you read a script in that script (#552, #563) and names the language it is about (#553, #560); Languages I'm learning has a switch to learn each language's script, by its name (#555, #561). A script you read for one language counts for every language written in it, and a short test skips the script lessons (#554).
- The language bar's selection follows your swipe, with rounded glyphs and a one-line label (#550).

### Fixed

- Today: the skill tiles stack when a name will not fit, so "Recognition" is no longer cut (#478, #564).

## [0.4.4] - 2026-10-17

The decks on GitHub are now split further, their script guides and sounds files included, and carry new card data, which 0.4.3 cannot read, so 0.4.3 gets no more deck updates: update to 0.4.4. Your progress is kept by card id, and no card id changed.

### Added

- The language bar on Today, Decks and Progress (#528): one top bar holding the languages you learn and the bug report button. The language shown is a chip; every other language is its own glyph. Swipe sideways on the bar to change language, or tap it for the menu of every language. Progress alone has All, fixed beside the bug button, so the bar does not shift between the three screens.
- Set cards (#515): a closed group, such as a verb's forms or the pronouns, is shown whole once before its members, with the ones you know marked. Then only the new members are taught and asked, in cards of at most four. The Full list is a button on these cards, during lessons and in reviews once you have answered.
- Card data in the decks, from decks-next: gender classes, root words, synonyms and antonyms, confusables, frequency, register and senses where a deck has them, and the tools that check them (#512, #513, #514, #516, #517, #518, #523; partly done).
- IPA pronunciations (#533): each word's IPA under it on drill cards, the teach card, passages, Inspect, grammar questions and the pair drill. A switch in Settings, "IPA pronunciations", turns it off; it is on by default. A word's own sheet always shows its IPA.
- The IPA course (#534): one card for each IPA symbol and diacritic, 179 in all, with examples from real languages, both what a symbol sounds like and what it does not, and confusable symbols side by side. It is asked by choosing, never by typing. The language picker offers it twice, as the whole chart or only the sounds of your languages, and the two share one progress. "The sounds of this word", on a word's card, practises the symbols in that word's IPA. A learner not learning the IPA is first asked whether to add it. The decks are CC BY-SA 4.0.
- Languages I know (#490): a screen of its own with 35 languages, searchable, with top picks and language families folded until opened. Choosing a language asks whether you read its script, in that script where a speaker has written the question.
- Settings is redrawn (#496): the tab is your profile card and one row per section, each saying what is set, and each section is a page of its own. The sections are Your languages, Activities and memory, Look and language, Reviewing, Your decks, Reminders, Your data, App log and Updates. Your data holds backup and restore with the review log, fully expanded. Profiles and privacy opens from the profile card. What the app does not do yet (reminders, the app's language, local and cloud backup, profiles, the PIN lock, deck templates, sending a deck) is drawn and marked "Feature incoming".

### Changed

- Activities that are always asked have no switch any more: Seen words, Grammar, Matching pairs, Choosing answers and Phonemic contrasts. A learner who had switched any of them off finds it on again. The Sound switch is gone. The phone's volume mutes the app, and Heard words off skips listening; a learner who had Sound off finds Heard words off.
- Review is offered for a course only when you speak both its language and the language it is taught from (#525).
- A deck's page, a unit's page and Inspect have no language switcher, as each belongs to one deck (#526).
- Lesson and review cards fit the screen without scrolling (#482).
- The review bot writes Wiktionary's IPA in each deck's own style, Hindi first (#479).

### Fixed

- Progress: "No leeches" is a plain card, no longer in the error colour (#500).
- Progress's range control, and the drill's choice between the script and Latin letters, are 48 dp tap targets at every text size (#491).

## [0.4.0] to [0.4.3] - 2026-10-10 to 2026-10-11

### Added

- The README shows the app: four short GIFs, each a slow scroll through one screen of a Bengali learner's phone (the deck path, Today, Progress, and reviewing a unit), in `docs/screenshots/`. `test/tools/readme_gifs_test.dart`, skipped unless `README_GIFS=1`, captures them with real fonts, and `tools/make_gif.py` assembles them; `tools/README.md` has the commands.
- Inspect shows how hard a card has been for you in each skill you have answered it in (#208, #253): open a card and "How hard, for you" lists, for example, "Hear: 7 of 10, harder" and "Write: 2 of 10, easier", grammar understood and produced apart. The value is FSRS's difficulty for that card and skill, learned from your own answers, so a miss by ear raises Hear and leaves the others as they were, and a right answer in Hear, Say or Write, which counts in part for another skill, leaves that skill's difficulty alone. A skill you have not answered shows nothing. Reviews stay in due order, quick revision stays random, and new words are still chosen by length (docs/plans/difficulty-by-skill.md).
- A guide for people invited to review decks, `docs/REVIEWING.md`: what reviewing is, how to start, what is public and what is private, and how changes reach learners. The README links to it.
- The reviewer guide is now the reviewer onboarding in the app (#409). Turning on Review decks walks you through it once, one step per screen, with Back, Next, Skip and progress dots: what reviewing is, your code and languages, "To review", checking and signing off, suggesting and answering proposals, offensive words, which have their own review that explains first and asks whether you are 18 or over each time, and sound-alikes, which are checked there, sending several decks in one mail without changing its subject or files, what is public and private, how agreement reaches learners, and thanks. How reviewing works in Settings shows the same steps at any time. `docs/REVIEWING.md` has one section per step, and a test keeps the two in step.
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
- Each card records who checked it (#449). When a reviewer marks a card "Looks right" and sends the review, the review bot adds their rater code to the card's `checked_by`, never twice, and once every card of a deck is checked tags it `reviewed` in place of `unreviewed`; a core and its layer are each tagged on their own, and the deck reads as reviewed once both are. A word's card, and its row and card in review, say "Checked by 2 speakers", and the thanks on a unit come from `checked_by`. A sign-off alone offers learners no deck update: `content_sha256` leaves `checked_by` out. A deck becoming reviewed does. For deck writers: the validator checks `checked_by` as a list of rater codes, written where the bot writes it; ADR-0038 is amended.
- What waits for review, for reviewers: choose the languages you review in Settings, under Review decks (at first, those you speak that the app teaches), and Waiting for review lists, per language, the units and decks no native speaker has signed off with the cards each has left, the offensive words not yet rated, the sound-alike pairs not yet confirmed, and what you reviewed but have not sent. Each unit of the path waiting for review is marked "To review". The regions a rating offers, and a rude word's region note, come from the language's path.
- The Decks tab is now a path (#436). Chips pick the course; each unit is a node marked done, up next, not started or Coming; the path shows its levels (A1, A2, B1) and milestones (words learned, rules known, first passage read, script learned); Where I am, + Add deck, and a search across every course you learn sit on the same screen. Units still to come, planned or not yet written in your language, show greyed as "Coming", with about how many words, and cannot be started; lessons skip them.
- A unit has a screen of its own (#436): its level, number and description, a notice while no speaker has checked its deck, tiles for words, rules and sentences, each word marked Known, Learning n% or New, a rules deck drawn as its table, Continue, and Review for reviewers. Tapping a word opens its card sheet: the word with its reading, meaning and notes, a speaker, and the warning on a word that sounds like a rude one. The rude word itself stays hidden unless adult content (18+) is on.
- Telugu and Bengali are the first courses in the B1 format (#438). Each has a plan to B1 in its path, 97 units for Telugu and 103 for Bengali, with A1, A2 and B1 marks, and every A1 unit written: 30 units, about 630 words for Telugu and 750 for Bengali, 27 and 28 new decks with an English layer each, a 20-phrase phrasebook, and rule tables for noun forms, pronouns and present-tense verbs. The A2 and B1 units are planned and show as "Coming". All the new decks are marked unreviewed. A rules deck now counts as rules, not as words, so Telugu's A1 no longer reads 3,318 words.
- Hindi, Marathi, Gujarati, Kannada, Assamese and Spanish are arranged in the B1 format too (#445), with no new content and no card id changed. Each deck is a core and an English layer, each language has a phrasebook gathered from its cards and a B1 plan in its path with A1, A2 and B1 marks, and derived words name their dictionary form, such as गया → जाना. The units up to B1 that are not written yet show as "Coming". The words and notes learners see are unchanged.
- A word's base words show on its card (#410): on its card in a unit, on a drill card once the word is taught or answered, and on a card in review, one line such as "Base: जाना (jānā) · to go", the base's reading following Latin-letter readings. A base taken from another card shows that card's word and meaning. In review, Suggest a change offers each base written in full on the card, named by its word too where two words share a base, so a native speaker can correct the meanings agents wrote in #445; the review file names the base by its word (`"part": "base"`, `"word"`), and the review bot leaves these suggestions for the owner.
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
- Adult content (18+), in Settings, off by default. Switching it on asks once whether you are 18 or over. With it on, a warning on a word that sounds like a rude one names the rude word, and Off again hides it at once (#96). Reviewers rate offensive words in their own Offensive words review, which asks for 18+ each time whatever this switch says (#428).
- Settings > Voices has one card per language, the languages you learn first, for hearing it and for speaking it. Choose which of the phone's voices speaks it, where it has several, marked where one needs a connection, and Play it. Say something tests the phone's speech recognition: say a word from the course, shown with its reading, or anything, and see what the phone heard and whether it is the word. A failed test says why, with the recogniser's own error code in small print, and every speech and voice error goes to the app log by its type and code, never what you said. Where a language is heard only online, the card holds its switch, and the test asks first, as a drill does (#123).
- Try a pronunciation again (#231). In a speaking drill, after a wrong or almost-right answer, or Don't know, Try again lets you say the word again, as often as you like: each try is heard and graded as the first was, naming the sound where one changed the word, but only your first answer is recorded: after a wrong first answer the word comes back sooner, and the banner says so only then, and "Almost" for a try that is almost right. Hear yourself, on any answered speaking card, records you saying the word for three seconds, plays it back, then plays the voice. The recording stays in memory and is never saved, and Continue cuts it short, as it stops a Try again still listening.

### Changed

- A change reviewers propose to a deck no longer offers learners a deck update, as they never see proposals: `decks/index.json` gives each file a `content_sha256`, its hash with the proposals left out, and the phone, which keeps it beside each file, asks only when that changes. Files whose proposals alone changed come along with the next real update. With Review decks on, a proposal is an update, as before. Every file is still checked against its size and SHA-256 (#444).
- The app no longer bundles the language folders, only the theme list and the spoken languages. Updating from an earlier version downloads the languages you learn before the app opens; your progress is kept. Tests read the repository's `decks/` through its index (#271, ADR-0037).
- The app goes online to download decks too, and once a day to look for deck updates unless you turn that off. Like the update check, this tells GitHub the phone's IP address and which files it asked for, and nothing else. The welcome screen and the Settings footer now say the app works offline once its decks are downloaded (#272).
- Every switch in Settings now says what happens in its state, and its line changes the moment you flip it: "Nothing is spoken; listening questions are skipped", "Words play only when you tap the speaker". The skills are named as you meet them: Seen words, Written words, Heard words and Spoken words, with Grammar covering forms understood and used. Show romanisation is now Latin-letter readings. Rows that open a page show what is set, and Languages I speak lists your languages.
- The app now reads an unquoted value in a deck as the validator does, by YAML 1.2, so a bare `no` is the text "no" in both. Quote it all the same, for other YAML tools (#434).
- The bug icon on every screen now offers three things: Get support, Report a bug and Give feedback, in place of Bug, Feature and Suggestion. Feature requests are feedback. You still write a title and details first; then your mail app opens to fluenough@gmail.com with a subject and questions of the kind's own filled in, which you can change before you send. Bug reports and feedback become public GitHub issues, without your email address. Support mails stay private in the Fluenough inbox, and are never made issues (#160).
- The Telugu grammar notes on gender now describe grammar classes, a masculine ending (-డు, -ḍu) and a non-masculine one (-ది, -di) shared by "she" and "it", in place of saying a woman "takes the same form as a thing"; they add the respectful ఆవిడ వచ్చారు (āviḍa vaccāru). The same framing is fixed in the Kannada differences note and the Marathi present-tense rule. Prose only: no card id, reading or tag changed (#456).
- Progress no longer has "Your strengths"; "Correct, by skill" and "How you learn" say the same, better.
- ख़ is now written k͟h in the Latin readings, as ISO 15919 writes it, in place of ḵ: the decks' readings, the romanisation files, the README table, the transcriber and the validator. Typing kh is still right, with its mark flagged (#339).
- The release workflow now fails in its first steps, before building anything, when the pushed tag `vX.Y.Z` differs from `pubspec.yaml`'s version (without its `+build`), and says to bump `pubspec.yaml` and `AppInfo.version` first. Before, such a tag published an APK that reported the older version and kept offering itself as an update. The comparison is `tools/check_release_version.py`, with tests (#141).
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
