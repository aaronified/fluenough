# Learn flow: what "learned" means, and the new rule

Owner design, 2026-11-16 (verbatim, in order):

> (a) "Or, make everything learnable. We will need to make one change for that. Learned should mean that the content was shown and then immediately after that the user has answered two separate questions on it (must not be the same type of questions, but the types need not be fixed). Unless both are answered correctly, it remains unlearnt."
>
> (b) "There should not be a gap longer than 2 questions between the content shown and the first question, and same for the 2nd question. All 3 must happen in the same sitting as well. Otherwise it just becomes a fake fsrs schedule."

Settled by the owner afterwards: the first question comes immediately after the content is shown, and the second comes after exactly two other questions. The owner also said to skip the mockup and build, so this file is the spec: there is no `learn-flow.html`.

This replaces the earlier idea of a Learn gate for decks above the learner's level. Everything is viewable and learnable; the safety is the definition of "learned". An item not passed twice never enters FSRS, so it never pesters the learner.

## 1. Audit: what "learned" means today

Read from `origin/main` on 2026-11-16, and the decks on `origin/decks-live`.

### 1.1 Where an item becomes "taught" and enters FSRS

There is no separate "learned" flag. FSRS state is kept per `(card, mode)` pair, in `card_states`, written by `AppState.record` and rebuilt from the review log (`lib/core/scheduling/replay.dart`). The words are:

- `AppState.isTaught(card)` (`lib/app/app_state.dart`, around line 3725): true when **any** drill mode of the card has an FSRS state. That is the only definition of taught, and the one `Unlocks`, `lessonRoom`/`inProgressIn`, the mastery counts (`progress_mastery.dart`), the path and the culture `isTaught` checks read.
- A pair gets its state at its **first recorded answer, right or wrong**. `Fsrs.review(null, rating)` (`lib/core/scheduling/fsrs.dart`) starts a new state from the rating of the grade: `Fsrs.ratingOf`: below 3 is Again, 3 Hard, 4 Good, 5 Good (Easy only from the learner's own rating buttons). A wrong first answer is Again: the pair still enters FSRS, with the shortest window (a day for a new one).
- **Lesson (the path's "learn new", Today's new items, a unit's lesson).** `AppState` builds it at about line 3895 to 4060: `lessonItems` picks up to `lessonMaxNew` (9) new cards, at least `lessonMinNew` (2), fewer while words in progress are not known (`lessonRoom`, ADR-0046), at most 3 rule cells (`ruleCellsPerLesson`); then `lessonPlan` (`lib/core/scheduling/lesson.dart`) lays them out as: for every card, a **teach card** (`Ask.teach`, records nothing; a rules table's cell has a rule card instead, a set card a set card) immediately followed by its **check**, the card's best question by difficulty (`_lessonSkills`: easy cards start with Recognition, medium with Hear, hard with Write); then the **exercise**: each card asked once more in a **different mode**, easy, medium and hard mixed in turn, match-pairs grouped. So a lesson already has "show, question 1 immediately, question 2 later in another mode", but the second question comes after *every other card's check*, up to eight questions later, nothing is checked for both being right, and the check's first answer already creates the FSRS state.
- **The deck page's Learn button** (`deck_detail_page.dart`, `_ActionBar`, `learnEnabled: words.isNotEmpty`) opens the **walkthrough** (`walkthrough_page.dart`, #694): the teach cards one after another, nothing asked. `AppState.viewCard` appends **one review-log row graded 0** for the first view of a card not taught yet (`asked: Ask.teach`), which FSRS reads as Again, so **merely swiping to a card makes it "taught" and schedules it**, with no question answered. This is the "fake FSRS schedule" the owner means. Readers that count answers skip these rows (`ReviewEvent.isView`).
- **Reviews and Today** (`SessionQueue.build`, `lib/core/scheduling/session_queue.dart`): due pairs first, one mode per card per session, then new pairs up to the day's cap (a new pair is a `(card, mode)` with no state, so a taught card's other modes arrive later as new pairs, "Again is not re-queued").
- **Culture, proverbs, multi-word verbs, topics, situations**: the same cards and the same lesson (`lib/app/culture.dart`, `topics.dart`, `situations.dart` call `lessonPlan`/`isTaught`). A culture item is *taught* when all its cards are (`culture.dart:91`). Reading decks' `QuestionCard`s are exam items, never walked or taught. A recommended work (film, book, song) has no cards; it only gets "I've completed this".
- **"Learned" in the UI** is `isTaught` and the mastery bar on top of FSRS (`progress_mastery.dart`: words mastered of words taught). The progress number therefore already counts taught, not mastered, words.

### 1.2 Question types per card kind

A type is an `Ask` (`lib/core/scheduling/ask.dart`), registered in `questionTypes` (`question_type.dart`), each belonging to a skill (`DrillMode`). `Card.modesIn` (card.dart, about line 723) says which skills a card has: the four vocabulary skills (Recognition, Write, Hear, Say) for everything except a phrase of one word, which has no Write; grammar skills for rules cells and cells with siblings. Hear needs a TTS voice, Say a speech recogniser. Recognition's `own` way is **self-rated** (not machine graded).

| Card kind | Types a lesson can produce for a new card | Distinct machine-graded types |
|---|---|---|
| Word (one or two words) | Recognition choose meaning; Write typed (`own`) or choose word where the language is not typed; Hear choose meaning (needs a voice); Say (needs a recogniser); picture choice and match pairs (picture only after a review; match groups four items) | 2 always (choose meaning, typed/choose word); 3 with a voice; 4 with a recogniser |
| Sentence / phrase of 2+ words (`Card.rearranges`) | choose meaning; rearrange the words; Hear; Say | 2 always (choose meaning, rearrange) |
| One-word phrase (`pos: phrase`, 1 word) | choose meaning; Hear (voice); Say (recogniser); no Write | **1 without a voice or recogniser** |
| Kanji / hanzi / script letter or digit (`pos: letter`/`digit`, script decks) | choose meaning; Hear and choose the form (`hearAndChoose`, voice); typed Write | 2 always |
| Rules-table cell (`rule` set) | grammar understood: choose form meaning; grammar produced: choose form, or typed | 2 where the row has options (`choosesMeaning`), else 2 as choose form + typed |
| Pattern cell (kind `grammar`, all four vocabulary skills excluded) | grammar produced only: typed; choose form only if the cell has other forms or siblings | **1** unless it has other forms |
| Culture, proverb, multi-word verb, topic and situation cards | they are ordinary vocab-kind cards (verses, proverbs, sentences, phrasal verbs), so as the first four rows | as their rows |
| Sound pair (`pair`) | Hear adds the partner as a distractor; no type of its own | as the word |
| Reading passage question (`QuestionCard`) | one reading question, an exam item, never taught | not learnable; unchanged |
| Recommendation (work) | none: it has no card | view-only, "I've completed this" |

So most kinds already have two different machine-graded types. The exceptions that cannot satisfy "two different types" as the code stands are:

Counted on `origin/decks-live` (core files of vocab decks, 2,110 decks, 40,006 cards, 2026-11-16):

- **One-word phrases (`pos: phrase`, one word): 2,447 cards in 334 decks (6.1 % of the vocab cards).** Culture decks 58 of 341 cards, multi-word verbs 69 of 527, proverbs 52 of 475. With a voice they have Recognition and Hear, so two types; without a voice or recogniser, one.
- **Pattern cells (kind `grammar`)**: 314 decks. Their cells are expanded from patterns at load, so a card count is not in the files; they are the grammar-produced skill alone, so one type unless the cell has other forms. Estimate from the deck count only; the build should count them with the loader.
- Rules decks (64 decks) and the 2,082 script letters and digits have two types or more. Reading decks (319 core files) are exam items and unaffected.
- A voice is the common case for the big languages but not universal, so a Hear-dependent second type cannot be relied on: the second type must not need a voice.

Proposed per kind:
- **One-word phrase.** Add a second type, **choose the word** (`Ask.chooseWord`, shown the meaning, choose the target) for these cards, recorded as Recognition-skill evidence or kept out of the log as a learn attempt. It needs no new UI: the choice question exists. Until built, such a card is shown and viewable but its learn is held (view-only).
- **Pattern cell with no other forms.** Offer **choose the form among the deck's other cells of the same pattern** (as `chooseForm` does for a rules table) as the second type, or keep these cells view-only until a deck marks the cell's options. Counts below tell how many it affects; there are few.
- **No voice and no recogniser.** Hear and Say drop out, which is why the table counts the types that need neither. Self-rated Recognition (`own`) never counts as a learn question: the learner could just say "right". Only machine-graded questions or choices do.
- **Match pairs** is a group question of four items: not used for the learn rule (it would tie four sequences together).

### 1.3 How the level gate decides today

- `LevelGate.allows(itemLevel, learnerLevel)` (`lib/core/models/level.dart`): an item with no level is open to all; a language with no levels offers no levelled item; otherwise the learner's level must reach it. `AppState.levelIn(language)` gives the learner's level: the furthest path unit studied or placed past (`LearnerLevels.levels`, so a placement result counts), tops out at B1 because paths end there.
- It filters: `Deck.forLevel` and `Catalog.forLevels` drop an above-level deck from `state.decks`, which is why the path, the Decks list, reviews and Today never offer one (`deck_catalog.dart:355`); `weaveCulture` puts above-level culture items in `WovenCulture.above`, never woven, shown only as previews if "Items above my level" is Show; `topic_resolver.dart` leaves out hidden topics' decks and cards above the level; `timeline.dart` and `recommendationOffered` drop works above the level (the bug that emptied the recommendations page); search marks them with their level and, with the "Hide what is above my level" setting (`hideAboveLevel`), hides them.
- Where it is *not* applied: the deck page's own Learn button (a deck reached from search) has no level test; the walkthrough ignores it.
- Most ordinary vocabulary decks carry **no level**, so the gate never touched them; it only bound multi-word verbs, culture, proverbs and topics.

## 2. The rule

An item is **learned** when, in one sitting, it is **shown**, then **asked twice in two different question types**, and **both answers are right the first time**. Only then does it enter FSRS.

```
show  ->  Q1 (type A)  ->  other  ->  other  ->  Q2 (type B)
 1          2              3           4          5      = 5 steps of the session
```

1. **Show.** The teach card (`Ask.teach`, or the rule or set card) displays the content. It records nothing, as a view never does now. It is marked with a subtle "New" mark.
2. **Q1 immediately.** The first question about the item is the very next question: nothing between the show and Q1.
3. **Q2 after exactly two other questions.** Between Q1 and Q2 there are exactly two questions of other items (new items' Q1 or Q2, or reviews, in any mix). Not one, not three. If two cannot be found (nothing else to ask), the sequence is not started: the item is not shown at all.
4. **Different types.** Q1 and Q2 are of two different `Ask` types, chosen by the app when the sequence is scheduled, not fixed per item. Prefer two different skills (for example Recognition then Write); require at least two different types. Only machine-graded or chosen questions count: never the self-rated Recognition, never match pairs (a group), never a reading question.
5. **Correct on the first try.** A question is right when its recorded grade is at least `Fsrs.passingGrade` (3), first answer only. No "Try again", no near-miss retry, no second guess. A near miss the learner judges right through the existing near-miss prompt counts as the grade it records. A wrong answer at Q1 or Q2 ends the attempt on the spot: the item stays unlearnt, there is no FSRS entry, and the learner sees "Not yet". If the miss is at Q1, Q2 is cancelled and its slot is given to another question.
6. **Same sitting.** One continuous drill session. It ends when the learner leaves the drill, closes the app, or backgrounds it for more than **5 minutes** (idle limit), or when the session completes. A sequence not finished is dropped: the item stays unlearnt and no row is written to FSRS. The three steps never straddle two sittings, so there is no fake "come back tomorrow" schedule.
7. **Learned.** When Q2 is right (and Q1 was), the item is learned at that moment, and FSRS is handed its first review at that moment (below). The learner sees a small "Learned" confirmation on the Q2 feedback. A failed item stays in the new queue and may be tried again as a **new attempt**: in the same sitting at least four questions later and at most twice per sitting, or in a later sitting.
8. **Parallel sequences.** At most **3** sequences are open at once (shown, not yet learned or failed). With the fixed spacing, every Q2 sits exactly three positions after its own Q1. The scheduler therefore places Q1s in free positions and puts each Q2 at "Q1's position plus 3". Three open at once packs as Q1a Q1b Q1c Q2a Q2b Q2c: each Q2 has exactly two questions between it and its Q1 (Q2a: Q1b and Q1c; Q2b: Q1c and Q2a; Q2c: Q2a and Q2b). A fourth item may be shown only after one sequence ends, so that no Q2 is ever more than two others away or fewer. Other positions are filled by reviews. A fail frees its Q2 slot at once for a review or another Q1.

### FSRS handoff and rating

FSRS is per `(card, mode)`. Today a new pair's first `Fsrs.review(null, rating)` uses the rating from the grade: Good for a right choice of a meaning seen (grade 4, `choiceGrade`) and for a typed answer typed right (4 or 5), Hard (3) for the other right choices (choose word, hear meaning), never Easy. The new rule keeps the mapping and changes only the **moment and the gate**:

- Q1 and Q2 are logged to the review log as **learn attempts** (a new flag like `ReviewEvent.isView`, so replay and every reader skip them for scheduling) and write nothing to `card_states` while the attempt is open.
- When Q2 is right, for each mode of the two questions (Q1's and Q2's; one state if both were in the same skill), write one first review `Fsrs.review(null, rating, now: Q2's time)` with the rating of that mode's grade: **Good** for a typed or chosen-meaning answer, **Hard** where the grade was 3. The first due date is therefore from that moment, by FSRS's own first interval. No "rest for a day".
- The card's other modes (Say, Hear if not asked) stay new pairs, brought in by the daily new cap as today.
- A failed attempt writes no state and **no Again**. Today's habit of making a miss an Again at once goes away for new items, which is what keeps a too-hard deck from pestering the learner. Reviews of learned items are unchanged.

### What the learner sees

- A small "New" mark on the teach card and on its two questions (the sequence is visible, not announced).
- Q2's feedback adds a small "Learned" confirmation; a miss shows "Not yet" and says the item will come back.
- Deck page and progress: **everything is open and learnable**. A deck far above the learner has Learn enabled and one honest line: "This is well above your level: you may need a few tries." The progress number counts only learned items.
- The walkthrough (the deck page's Learn) stops writing a graded-0 row. It is a way to look, not a way to learn: it shows every card and records nothing to FSRS. The deck page's Learn button then runs a real learn session on the cards in view, which is the lesson built as below.

### How the session builder changes

`lessonPlan` today emits taught cards and checks first, then an exercise. It becomes a scheduler that takes the picked new cards and:

1. chooses for each card two different types, from `lessonQuestions` (the first by difficulty, the second the next skill with a different type), skipping those not machine-graded;
2. emits show + Q1 together, keeps up to 3 sequences open, and places each Q2 exactly three questions after its Q1, with reviews (or other sequences' questions) as fillers;
3. stops starting new sequences when it cannot guarantee the two fillers or when the day's minutes run out; never leaves a started sequence unfinished on purpose.

## 3. Code changes the build needs

1. `lib/core/scheduling/lesson.dart`: replace the "all checks, then exercise" layout in `lessonPlan` with the sequence scheduler (show, Q1, 2 others, Q2, at most 3 open); a pure function, tested; `lessonQuestions` returns two different `Ask`s per card or reports "view-only".
2. `lib/core/scheduling/question_type.dart`: allow `chooseWordType` for a one-word phrase and a type pair chooser (`learnTypesFor(card)`), excluding self-rated and group types.
3. Session state in `drill_session.dart`: track each sequence (item, step, Q1 type and result, open positions, last activity time), end an attempt on a wrong first answer, drop open sequences when the session ends or the app has been backgrounded over 5 minutes, show "New", "Learned", "Not yet".
4. `AppState.record` and `lib/core/data/review_log.dart` / `replay.dart`: a learn-attempt flag on log rows that does not touch `card_states` until a `learned` commit writes the first reviews together (one transaction) at Q2's time. Reading code that counts answers skips attempts as it skips views.
5. `AppState.isTaught` becomes `isLearned` in meaning (a pair with a state exists only after a pass); the name can stay in step one. `viewCard` and the walkthrough stop writing the graded-0 row; `newToWalk` and the Learn badge count unlearned items.
6. `deck_detail_page.dart`: Learn enabled for every deck with learnable items; the honest line for a deck above the learner; progress counts learned. No level test is added to Learn.
7. Remove the level gate from what Learn reaches: `topic_page.dart` (`startable`, `showAboveLevelSheet`), `culture_item_page.dart` (Practise replaced by a notice), `culture_deck_page.dart`; `Deck.forLevel` / `Catalog.forLevels` stop dropping above-level decks from drills (path, Decks list, search show them marked with their level). `LevelGate` stays for the marks and the "Items above my level" Show/Hide of the path and Today previews. `hideAboveLevel` is removed as in `culture-in-decks.md`.
8. Strings: `learnNewMark`, `learnLearned`, `learnNotYet`, `learnAboveHint`; remove `learnUnlocksAt` and any "Unlocks at" line tied to Learn.
9. Decks: give the cards counted in section 1.2 a second type or mark them view-only until they have two (see the proposal above).
10. Tests (CI only): sequence spacing for 1, 2 and 3 open items; a wrong answer at Q1 and at Q2 writes no state; an aborted sitting writes no state; both right writes first reviews with Good (Hard for grade 3); the same Ask twice is refused; the 5-minute idle drop.

### Migration

Items already taught (any `card_states` row) stay learned: nothing is rewritten and no state is removed. The rule applies from the next learn. Items taught only by a walkthrough view (a graded-0 row with `Ask.teach`, `isView`) are the one doubtful case: they are in FSRS as Again with no answer. Suggest leaving them, since they are already scheduled and reviews will sort them out, and not counting them as learned in the mastery numbers (they already do not count as mastered). The owner decides (open question 3).

### Effect on the culture-in-decks build

The Learn gate is dropped: one rule, everything learnable. `docs/mockups/culture-in-decks.md` is edited to match: its "Learn gate" section is replaced by "No Learn gate", and `AppState.deckLearnable`, the "Unlocks at B1. You are at A1." reason line, the lock icon, `learnUnlocksAt` and `recQuestionsHeld`, the gate in the work page and the "too far" deck page state are removed. What stays: the Culture button and the culture list on the Decks screen, the per-language culture options, "Items above my level" Show/Hide (path and Today previews), removing "How many" and "Hide what is above my level", and the Culture-off disabled Learn (about the switch). `culture-in-decks.html` still draws the locked Learn: build from the Markdown, with the "Too far" phone read as "Far above" (Learn enabled, honest hint).

## 4. Open questions

1. Idle limit 5 minutes: right, or longer for a learner who stops to look something up (a phone call)? The page proposes 5.
2. A wrong answer ends the attempt: should the learner see the right answer at once (as in any lesson)? The page proposes yes, as now, and then "Not yet".
3. The walkthrough's graded-0 rows already in FSRS: leave them (proposed), or retire them so those items are unlearnt again?
4. The cap of 3 open sequences: right? More than 3 only lengthens the packed Q1 block, since each Q2 stays three positions behind its Q1.
5. One-word phrases and pattern cells with a single type: build the second type (proposed) or keep them view-only until a deck has two?
6. Max two attempts per sitting for a failed item: is that right, or just one and then a later sitting?
