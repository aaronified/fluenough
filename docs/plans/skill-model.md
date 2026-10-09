# Plan: Hear, Say and Write, and what the app learns about you

Written 2026-10-06. **Before the B1 plans, and together with FSRS**
(`fsrs.md`), in one migration and one replay. The owner's order: this plan,
then `b1-plans.md`, then deck downloads (`decks-from-github.md`), then the
settings redesign (`language-picker.md`, `settings-wording.md`,
`voices-per-language.md`).

## What the owner asked

> in the listening test, we should ask users for the meaning and not the
> transliterated word (unless it is script practice). otherwise we cannot
> know whether the user understands pen and time in telugu separately

> choose for recognition, type for production.

> divide checked skills into matching, listening, typing, speaking, etc,
> that the user does. the app learns the user's strengths in terms of
> recognition-sound, recognition-text, recognition-picture,
> recognition-script, production-sound (speech), production-text (typing),
> production-script (using the script), understanding-grammar,
> understanding-accent, etc. discuss in detail. this will go into planning
> as well. before the deck grading (the B1 target plan).

Decided with the owner, after the research below:

- **Two layers.** *Activities* are what you do, and what Settings switches
  on: matching, choosing, listening, typing, speaking, grammar, reading,
  phonemic contrasts. *Strengths* are what the app learns about you from
  them.
- **Three schedules per word: Hear, Say, Write.** They were chosen as the
  grouping of review methods that covers the most strengths with the fewest
  reviews (below).
- **Hear asks for the meaning.** A transliteration is never asked for as
  dictation, except in script practice, where you say what a letter is
  written as.
- **Write asks for the word,** from its meaning or a picture, typed in the
  script or in ISO Latin letters. The Script / Latin letters switch stays
  for these questions, and ISO transliterations stay after the script.
- **Choosing and recalling are two grades of one schedule,** not two
  schedules. A right choice counts for less than a right recall.
- **Grammar has two schedules per item, understand and produce,** and the
  time an answer takes is recorded as a sign of how automatic it is.
- **The model:** FSRS keeps each word's memory in each schedule
  (`fsrs.md`); an Elo ability per skill sits on top. DAS3H is reconsidered
  later, once there are logs enough to compare the two.

## Terms

The owner's definitions, settled:

- **Minimal pairs:** "words in the same language that sound the same",
  such as కలం (pen) and కాలం (time).
- **Phonemic contrasts:** "sounds that do not exist in the native
  languages for the user but exist in the language being taught."

A minimal pair can be used to practise a phonemic contrast; the two terms
are not interchangeable.

## The research

The terms are the research's, so that the app's labels match it:

| Axis | Values | Source |
|---|---|---|
| Direction | Understand (the word → its meaning), produce (the meaning → the word) | Nation 2022 |
| Response | Choose (recognition), recall (type, say, write) | Laufer & Goldstein 2004 |
| Channel | Sound, Latin letters, script; a picture is another way to show the meaning | Nation 2022; Milton & Hopkins 2006 |

What decided the design:

- **Recalling is harder than choosing, and producing harder than
  understanding:** recall the word > recall the meaning > choose the word >
  choose the meaning, in every frequency band (Laufer & Goldstein 2004).
  Recognition is learnt before recall in every part of word knowledge
  (González-Fernández & Schmitt 2020).
- **Channels are related but separable.** Knowing words by ear and in
  writing correlate at about .68 (Milton & Hopkins 2006); knowing them by
  sound predicts listening, in writing reading (Cheng & Matthews 2018).
- **What you practise is what improves.** Learning to produce helps
  production most, learning to understand helps understanding most
  (Steinel et al. 2007; Webb 2009; DeKeyser 1997), as the match between
  practice and test predicts (Morris et al. 1977).
- **Hearing a contrast is not keeping two words apart.** Learners can hear
  or say a contrast and still not store it in their words (Hayes-Harb &
  Masuda 2008; Llompart 2021). A blurred form retrieves the wrong meaning
  (Cook et al. 2016), and questions on meaning catch near-homophones that
  questions on form miss (Ota et al. 2009). Hence Hear asks for the
  meaning. Writing down a heard word still tests its form (Matthews &
  Cheng 2015), which is why script practice keeps it.
- **Recall with feedback** gives the best long-term retention (Kang et al.
  2007), and retrieval beats repeating after the audio (Kang, Gollan &
  Pashler 2013).
- **Grammar:** understanding and producing practice build partly separate
  skills (DeKeyser 1997; Shintani et al. 2013). Timed and untimed tests
  measure different knowledge (Ellis 2005; Suzuki & DeKeyser 2015).
- **Learner models:** a model with several skills per item and forgetting
  per skill, DAS3H, did best in its comparison (Choffin et al. 2019); Elo
  estimates ability and difficulty after each answer with nothing to fit
  (Pelánek 2016; Pelánek et al. 2017). FSRS's peer-reviewed precursors are
  Ye et al. 2022 and Su et al. 2023.

The research was read from abstracts and summaries; full citations go in
the research-and-standards page (`research-and-standards.md`).

## From review methods to schedules

Each question has one cue and one response, so it tests one cell:

| Cell | Review methods | Grade |
|---|---|---|
| Understand · sound | Hear the word, choose or type its meaning | choose / recall |
| Understand · Latin letters | Choose the meaning; match pairs | choose |
| Understand · script | The same, shown in the script | choose |
| Produce · Latin letters | Choose the word; put words in order; fill a gap (cloze); type the word | choose / choose / recall / recall |
| Produce · script | The same in the script; write it by hand (`handwriting.md`) | recall |
| Produce · sound | See the meaning, say the word | recall |
| *Form only* | Dictation; read aloud | script practice only |

A cell can be taken from another where the research supports it:
producing a word in a channel implies understanding it in that channel,
since recognition comes first (medium confidence). Nothing is taken from
sound to writing, or from saying to hearing (Uchihara et al. 2024).

Ranked by **coverage = cells covered ÷ schedules per word** (four cells
before the script, six after):

| Schedules per word | Before the script | After |
|---|---|---|
| **Hear, Say, Write** (chosen) | 4/3 = 1.33 | 6/3 = 2.0 |
| Hear, Say, Write Latin, Write script | 1.33 | 1.5 |
| Hear, Say, Write, Read | 1.0 | 1.5 |
| Every cell | 1.0 | 1.0 |
| *Today:* recognition, production, listening (dictation), speaking | 0.75 | 0.75 |

## The three schedules

| Schedule | Asks | Choose grade | Recall grade |
|---|---|---|---|
| **Hear** | The word is played; what does it mean? | Choose the meaning | Type the meaning |
| **Say** | The meaning is shown; say the word | (none) | Said, and graded by the phone's recogniser |
| **Write** | The meaning, or a picture, is shown; give the word | Choose the word; put words in order | Type it, in the script or ISO Latin letters |

- **Understanding in writing** is taken from Write.
- **Handwriting** (`handwriting.md`) is one way to answer Write in the
  script, not a schedule of its own (owner's decision).
- **Cloze** (`sentence-building.md`) is a sentence's own item, produced in
  Write: the gap is any word the learner has learnt.
- **Proposed:** where a word has a minimal-pair partner, Hear's options
  include its meaning ("time" for కలం "pen", whose partner is కాలం), so
  that a learner who confuses the two is caught (Ota et al. 2009).
- **After the script,** Write expects the script; an answer in Latin letters
  counts as before (#168).
- **Picture** is a cue for Write and Hear's choices, for concrete words
  (Carpenter & Olson 2012; Lotto & de Groot 1998). Decks have no images yet.

## The ability layer

- **One ability per learner, language and skill:** Hear, Say, Write,
  grammar understood, grammar produced.
- **After each answer:** ability += K × (result − expected), where expected
  = 1 ÷ (1 + e^−(ability − difficulty)), and K shrinks as answers add up
  (Pelánek 2016). Derived from `reviews`, like `card_states`, so it can be
  rebuilt.
- **Used to:**
  - start a word in a schedule it has never been asked in from your ability
    there, not from scratch;
  - show your strengths on Progress.
- **Tracked for you, not per word:**
  - accent, from hearing several voices (Bradlow & Bent 2008; Baese-Berk et
    al. 2013); the CEFR's B1 assumes a familiar accent;
  - phonemic contrasts, per sound pair, as identification with feedback
    (Logan et al. 1991; Thomson 2018);
  - the script, letter by letter, from the script decks.

## Grammar

- Two schedules per grammar item: **understand** (choose what a form
  means) and **produce** (choose or type the form).
- The time each answer takes is recorded, as a nullable column added to
  `reviews` (append-only; AGENTS.md rule 9).

## What changes

| Today | After |
|---|---|
| Recognition: choose the meaning, match pairs | To decide, below |
| Production | Write |
| Listening: hear the word, type it | Hear: hear the word, give its meaning |
| Speaking | Say |
| Grammar | Grammar understood, grammar produced |
| Reading passages | Unchanged |
| Settings: one switch per mode | One switch per activity (with `settings-wording.md`) |

## What it takes

1. **Schedules,** with FSRS in the same migration: `card_states` keyed by word and schedule (Hear, Say,
   Write; grammar understood and produced), rebuilt by replaying `reviews`.
2. **Questions:** hear and choose the meaning, with the pair partner; hear
   and type the meaning; cloze; Write's choose grade.
3. **Typed meanings** graded against the card's meaning and its accepted
   alternatives.
4. **The ability layer** and its replay.
5. **Answer time** in `reviews`.
6. **Progress:** your strengths.
7. **Settings:** one switch per activity.
8. **An ADR,** amending ADR-0005's pairs and ADR-0024's ways of asking.
9. **Tests:** each schedule's questions and grades, the replay, the ability
   update, and that a Hear question never asks for a transliteration
   outside script practice.

## Decided

The owner's answers to #235, 2026-10-08:

- **The Today tiles:** Hear, Say, Write and Grammar (understood and
  produced share one tile); Reading stays.
- **Spill-over:** as the research says. Nothing is taken from sound to
  writing or from saying to hearing, so no schedule counts another's
  answers. A new schedule starts from the learner's ability there.
- **Match pairs and choose the meaning** are lesson steps, not scheduled.
- **The old log:** dictation replays into Hear, production into Write,
  speaking into Say, grammar into grammar produced. Recognition answers
  stay in the log and feed no schedule.
- **Typed meanings** are graded by the answer grader's folding and typo
  rules against each meaning: `native` split on `/`, `;` and `,`, and an
  optional `meanings:` list on the card.
- **Answer time** is recorded (`reviews.elapsed_ms` already holds it) and
  does not change a grade for now.
- **Pictures:** an open-licence set now, for concrete words: **Noto Emoji**
  (Apache-2.0), bundled PNGs named on a card as `picture:`, no new
  dependency (2026-10-08).
- **Cloze** is chosen as its easier grade and typed as its harder one.
- **The pair partner** is among Hear's options where a card names one.

### Decided, 2026-10-09

- **Recognition is a skill in its own right,** scheduled like the others:
  "Recognition is a skill on its own right. The research says it is
  important." This reverses "lesson steps, not scheduled" above. The
  recognition-only decks (the `-registers` and `-spelling` decks, and
  `bn-en-sadhu-cholito`) are reviewed again with it.
- **Shared ability:** "Our research said everything is interdependent."
  An answer in one skill moves the learner's ability and the word's
  difficulty in another **only where research has found the two related,
  and by as much as it found** (owner: "It should only be used where
  research has found correlation and with the strength that research has
  found"). So far: Recognition and Hear, .68 (Milton & Hopkins 2006,
  recognising words in writing and by ear). Due dates stay per skill.

- **One question, several skills; partial implication.** The owner:
  "Same questions can judge multiple skills. And one skill may partially
  imply other skills. These research based stuff is the backbone of the
  app." Which skills each question judges, and how much one skill implies
  another, are being taken from the research before they are built.

- **Reading is a skill of the script.** The owner: "Reading is a skill
  related to script." **Later,** recognition can be checked together with
  reading: "Recognition can later be checked along with read, e.g. when we
  bring in script only options for a picture" (a picture shown, the word
  chosen from options written in the script only).

- **SM-2 goes, all but its history** (owner, 2026-10-09): migration 6
  drops `reviews.ease_before` and `ease_after`, keeping every row; tests
  and plans no longer name it. ADRs keep it, as the record of what was
  decided.

- **The evidence for both** is in `docs/research/skill-evidence.md`, every
  claim checked against its source by a second agent (the checked claims:
  `docs/research/skill-evidence-claims.json`). Its options are put to the
  owner before anything is built from them.

- **Decided from the evidence** (owner, 2026-10-09):
  - **Ability:** a Q-matrix with multi-skill Elo. Each question lists the
    skills it judges, primary or secondary; one answer's update is shared
    over them, and a miss's blame split (Park et al. 2019; Koedinger et al.
    2011). The single .68 goes: it is a correlation of vocabulary sizes
    across learners, not of one word's skills.
  - **Scheduling:** a full review for each skill a question exercises; on
    a right answer only, a partial stability gain for the skills it
    implies, never moving their due date (Choffin et al. 2019; Pan &
    Rickard 2018).
  - **Order:** the skill model and FSRS are finished, rated and opened as
    a pull request first; then the B1 format; then the colours.

- **Grammar understood and produced** are built with the B1 format, not
  in the skill model's pull request (owner, 2026-10-09): "understood"
  chooses among forms of the same word, the rule cards' question
  (`words-rules-sentences.md`). Until then grammar keeps one schedule,
  typed.
- **Settings** already has one switch per skill, so one per activity;
  their wording waits for `settings-wording.md`.

- **FSRS fitted to the learner, per skill, in this pull request** (owner,
  2026-10-09: "Option 3 in this PR"). Asked to "progressively adjust to the
  user's aptitudes in terms of the skills ... if the user remembers all too
  easily then less reviews until he starts forgetting", the owner chose to
  fit FSRS's parameters from each learner's own reviews, separately for
  each skill, over seeding new words from the ability layer or one fit for
  all skills. This reverses "one set" above. Defaults hold until a skill
  has enough reviews to fit.

- **When fitting runs** (owner, 2026-10-09): "By a button, and when a
  skill increases by 10%. The button will have an automatic option for
  this. And this happens via a hook, do not crowd the opening." So: a
  button in Settings refits now; beside it, an automatic option refits a
  skill whenever its reviews have grown by 10% since its last fit, set off
  by recording a review, never at app start, and run off the main thread.
  The automatic option is on by default (owner, 2026-10-09).
- **Each fit starts from the last** (owner: "Absolutely"): a refit warm
  starts from the skill's previous parameters, so it needs fewer passes.
  Each skill's parameters are therefore kept, not recomputed: in the
  profile's database and in the JSONL backup, so a restored phone
  schedules exactly as before (owner, 2026-10-09).
- **What a fit learns from** (owner: "don't use fixed row count. Use last 3
  month's data, or last 1,000 rows, whichever is longer"): a skill's
  reviews from the last three months, or its last 1,000, whichever is more.
  Earlier reviews still build each word's memory state up to that window;
  only the window's answers are what the fit learns from.
- **Shown prominently** (owner: "Yes. Prominently. Figure out how"), on
  Progress under Your strengths and where the learner will see it; the
  design is put to the owner before it is built.
- **Nothing is gathered** (owner: "We do not gather any data at all").
  Every fit runs on the phone, from that learner's own review log; nothing
  leaves it. Where this plan or the research says a figure could be
  "fitted from the app's logs", it means the learner's own log, on the
  phone.

### How the work is run

The owner, 2026-10-09: commit and push everything as it goes; no raters
until a whole feature is built; once the skill model and FSRS are done,
rate them, then open a pull request.

## Estimate

About 15–25 hours, most of it the replay, the questions and their tests.
Confidence: low, until the questions above are settled.
