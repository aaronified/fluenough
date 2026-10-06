# Plan: Hear, Say and Write, and what the app learns about you

Written 2026-10-06. **Before the B1 plans.** The owner's order: this plan,
then `b1-plans.md`, then deck downloads (`decks-from-github.md`), then the
settings redesign.

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
| **Write** | The meaning, or a picture, is shown; give the word | Choose the word; put words in order | Type it, in the script or ISO Latin letters; fill the gap in a sentence (cloze) |

- **Understanding in writing** is taken from Write.
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

1. **Schedules:** `card_states` keyed by word and schedule (Hear, Say,
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

## To decide

- **The Today tiles,** after more discussion of the research.
- **Spill-over:** whether a right Write answer also counts toward Hear, or
  the reverse.
- **Match pairs and choose the meaning:** lesson steps only, or Write's
  first rung.
- **The old log:** how past listening answers (dictation, which shows no
  meaning) and recognition answers replay.
- **Typed meanings:** how close counts, and where alternatives come from.
- **Answer time:** how it changes a grammar grade.
- **FSRS:** before this plan, with it, or after.
- **Pictures:** where images come from.
- **Cloze:** which word is left out, typed or chosen, and whether it is a
  Write question for that word or a sentence's own (`sentence-building.md`).
- **The pair partner** among Hear's options, as proposed above.

## Estimate

About 15–25 hours, most of it the replay, the questions and their tests.
Confidence: low, until the questions above are settled.
