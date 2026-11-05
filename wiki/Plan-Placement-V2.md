# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.

## Find my level: verify, then fit, and how a run samples questions (plan, owner, 2026-11-05)

Status: a plan only, revised on 2026-11-05 after the owner rejected the walk-back design. Nothing here is built; the owner will be consulted before it is. Open questions are at the end (Part 3); each has a default the plan assumes.

Owner, 2026-11-05: "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." / "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." / "Verification will only be given after the language has all planned decks and verification run has used all of them." / "I mean full B1 completion level as per the path. Bengali already has that." / "Keep placement question count within 25 questions." / "Ask the last deck. If known, sample around that till you find serious flaws. If not known at all (2 questions min), go to 1st deck and keep sampling from there. Build a strategy around this kind."

Owner, 2026-11-05, rejecting "around": "Last deck known ('around'): go backward from it, one question per deck, at growing steps. The first deck is always the final stop. A path of 20 decks or fewer is sampled deck by deck. That would be quite frustrating for native speakers. Just cover the major grammatical concepts and harder recognition and complex words, test also on minimal pairs more. If someone answers the last two questions perfectly, the assumption is that he knows his shit. We just need to test if he truly knows everything. That covers the native speakers. Now from that start planning for deviations."

What changed, in one paragraph. The first plan walked back through the decks, one question each. That tested whether a learner had met the vocabulary of every deck, which a native finds tedious and which says little about the things only a real expert gets right. The new baseline is the native or expert path: two hard questions at the last deck, and if both are perfect a short battery of the hardest material (major grammar concepts, harder recognition, complex words, and minimal pairs weighted most). Every other kind of learner is a deviation from that baseline and has its own route (Part 2). "Expert" here means "knows the whole path to B1", so a strong B1 learner is not turned away: the bar is the path's end, not a native's.

### 1. Definitions

- **Deck order.** The language's word decks in path order, from the first A1 deck to the unit marked B1 (`CoursePath`, `walkDecks`). Index 0 is the first, N-1 the last (B1's end). **Level marks** are the path's own A1, A2 and B1 end units. Script decks are checked by the script check, not here.
- **Complete to B1.** The path marks B1 and no unit up to it is still to be written. Today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona. Only these can be verified; the others only fit (row k).
- **Verified (a skill).** The run met the pass rule of section 3 for that skill, and the preconditions hold: the path is complete to B1 and every indexed deck of the language is downloaded. A run never changes a skill's state (Learn, Know, Leave); only the credit and the verified mark change. Verified is a state of one skill, kept per language.
- **Concept family.** A group of units that teach one grammar topic (cases or postpositions, tense, aspect, negation, politeness, relative clauses, conditionals, the like), read from the grammar units along the path (decks named `<lang>-grammar-*` and the path's grammar units; Bengali has them) and their `tags`. A family's *hardest form* is the form in its latest unit with the most complex shape (an inflected form, a card with `bases`, a stem-change note).
- **Contrast.** An entry of the language's `<lang>-sounds.yaml` (ADR-0015): an id such as `aspiration`, `dental-retroflex`, `nasal`, `flap`, and the letter pairs that make it.
- **Pair question.** Hear one of two words that differ by one contrast pair; pick which was said. Two options, so a guess is right half the time; see the guard in section 3.
- **Twin.** The second question after a miss: the same skill and concept family or contrast, a different item, equally hard. A miss followed by a right twin is a **slip**; a miss followed by a wrong twin is a **gap**. "I don't know" is a miss (open question 4, kept), and is never followed by a hint.
- **Placed level.** The first deck from which the learner should learn; every deck before it is credited as known (the existing `placedDeckIds`).

### 2. Part 1: the native and expert path (the baseline)

**2.1 The probe: at least two questions at the last deck.** Start at deck N-1. Ask two questions drawn from the hardest material of the last deck (section 2.3): Q1 a harder recognition or complex word (the first known skill of the learner, in the order Recognise, Hear, Say, Write), and Q2 a pair question in Hear (or, if Hear is not available, a complex word in another skill; row i). There is no "I don't know"-free path: the two questions are the same for a native and anyone else, which is the point.

**2.2 The presumption.** If both answers are right, the learner is presumed expert and the run goes straight to the battery. If either is wrong, the run leaves the baseline for a deviation (Part 2, row a for one wrong, rows c to e for two).

**2.3 The battery: "does he truly know everything".** The target is about 10 to 14 questions in all, the probe included; the hard cap of the run is 25. For a learner with one known word skill the 12 slots below are filled; each extra known skill adds three (section 2.6).

| Part | Questions | What | Weight |
|---|---|---|---|
| Probe | 2 | hardest of the last deck: Q1 recognition or complex word, Q2 pair | 2 |
| G: grammar | up to 4 | one per concept family, hardest form, spread over the path (always the family of the last grammar unit, then the families with most units, then a random one) | 4 |
| M: minimal pairs | 3 | three different contrasts of the language, each from words in the path's decks; weighted most (a quarter of the run) | 3 |
| C: complex words | 2 | the longest and most inflected words of the last quarter of the path | 2 |
| R: harder recognition | 1 to 2 | a close-distractor recognition item from a late unit (not the last) | 1 to 2 |
| S: sentinel | 1 | one easy item (deck 0 to 4, a core item); see "guess guard" | 1 |

That is 2 + 4 + 3 + 2 + 2 + 1 = 14 at most; the floor is 10 (fewer grammar families, or no contrast data; section 2.7 and rows j, k). Order: probe, then the questions mixed so that no two of the same kind come in a row; the sentinel is placed in the middle third, never first or last.

**2.4 How an item is chosen ("hard"), per skill.** The pool for a slot is the cards of the decks it draws from (the last deck for the probe, the last quarter for C, the family's units for G, the late units for R, any deck for M). Every candidate gets a hardness score `H` from three parts, each 0 to 1:

| Part | Meaning | Source (exists today) |
|---|---|---|
| depth `d` | the card's deck index divided by N-1 | path order |
| form `f` | 1 for an inflected form (has `bases`), a compound, an idiom or a sentence of a grammar unit; else the card's length (characters or syllables) as a percentile within its deck; plus 0.2 if its notes mention a stem change | card fields: `bases`, `pos`, `tags`, `notes`, `target` |
| closeness `c` | how close the nearest wrong option is (below) | distractor generator (`distractors.dart`: base, pos, tag sources) and `<lang>-sounds.yaml` |

`H = 0.35 d + 0.30 f + 0.35 c`. The top five candidates by `H` are the shortlist; the item asked is picked at random from the shortlist with the run's seed. Why a shortlist: so that a learner cannot memorise the same five items by running the check twice, and so two runs differ. **Card difficulty and review stats:** the app is offline and has no population data, so `H` has no "how often learners miss this card" term (missing; see Part 3). The learner's own history is used in one way only: a card the learner already reviews with high stability is skipped, because a stable card says "learned in the app", not "known before". If history exists for the language (a restore, a re-install), it counts as the learner's evidence and shortens the run: a skill with 30+ reviews at a good rate is asked only the probe and the sentinel (open question 12).

**Closeness `c`** of a wrong option `o` to the right card `a`: 1.0 if `o` is `a` with one pair of a sounds-file contrast swapped (a real minimal pair); otherwise the larger of (1 minus the normalised edit distance of their readings), plus 0.2 if one is a base of the other, 0.1 for the same part of speech, 0.1 for a tag in common (capped at 1). The three closest options (one for a pair question) are used. Options never repeat a meaning, and never a card already asked or an option twice.

**Per skill:**

| Skill | Question | Hardest candidates | Wrong options | Notes |
|---|---|---|---|---|
| Recognise (Read) | a word or sentence, pick its meaning (or the meaning, pick the word) | inflected forms, compounds, idioms, grammar-unit sentences with a close wrong form | three closest by `c` | the text is shown in the learner's chosen script or reading |
| Hear | audio, pick the word or meaning; pair question: one of two words, pick which | words with a contrast neighbour; the longest words | three closest by sound (contrast swaps first), one for a pair | needs a voice and sound |
| Say | shown the meaning, say the word or sentence; graded by the recogniser with the sounds-file feedback | words that carry a contrast (an aspirate, a retroflex), the longest words, one grammar sentence | none | the recogniser is not trusted for pairs: pairs are only tested in Hear and Write; "unheard" is never a miss |
| Write | build or type the word from its meaning | words with a conjunct or a contrast letter; tiles include the contrast-swapped letter | tile distractors, with the swap tile first | the grader's tolerance is unchanged |
| Script (Read, Write) | the existing five-level script check; an expert asks only the top two levels (rarest signs, conjuncts or joined forms), 2 questions each | the rarest signs | | both right: the script is presumed known; a miss goes down the levels as the check does today, at most 10 |

**2.5 No repeats.** Never the same card twice in a run; never two cards of one word family (same base) in a run; never a card as both the question and an option; one concept family or contrast at most once as a first question (a twin is the only repeat of a family).

**2.6 One run for all known skills.** The learner marks which skills are known; the run tests only those (the earlier default, question 8). Each known word skill must collect at least three questions of its own, so it can be judged: with `k` known word skills the target is `10 + 2k` questions (12 for one, 18 for four) and each skill gets the probe or battery slots of its own kind (Hear gets the pair questions, Write the letter-contrast tiles, Say the complex words and one grammar sentence, Recognise the rest; grammar questions alternate between Recognise and Write). Each known script adds up to 4 questions for an expert (2 per top level), up to 10 otherwise. If the total would pass 25, scripts are cut to the top level, then the skill with the lowest weight (Write, then Say) is left for a second run, which is offered and not run silently; the sheet says which skill was left out.

**2.7 Guess guard.** At four options a guess is right a quarter of the time, at a pair question half. The battery's size is what rules out luck: a pure guesser passes the 14-question battery with at most one miss about once in five million (and the 12-question floor about once in half a million); six questions would let one in 200 through, so the floor is not lowered below 10 and the probe alone (6 in 100 for a guesser at four options) never verifies anything. A half-knowing learner (right 62% of the time, a guess where he does not know) passes 12 questions about 3 times in 100, 14 about once in 100. Two further guards: the sentinel (a hard question right and the easy one wrong is the mark of a guess, or of a careless tap, and sends the run to row h), and the twin rule (a lucky miss is judged twice). A pair question is always asked for three different contrasts, so one lucky pair cannot carry the Hear verdict.

**2.8 The pass rule for verified, per skill.**

1. The preconditions hold (path complete to B1, every indexed deck downloaded).
2. The probe's two answers are right, or the tie-break of row a was passed (the single allowed slip then already used up).
3. The skill collected at least 3 questions, and has no miss, or one miss whose twin was right (a slip). Two misses in one skill, or a miss followed by a wrong twin, is a gap and the skill is not verified.
4. The sentinel is right (or its twin).
5. The whole run has at most two misses; a third stops the run at once, not verified.
6. A script is verified when its check passes at its top levels, or all five.

A skill that passes is marked verified even if another skill did not. Every deck is credited (the learner is placed above the last deck) when at least the skill-independent part passes (the Recognise skill, or if it is not marked known, any one skill's questions) and no gap is recorded; recorded gaps are credited by row b.

**2.9 What the first design kept and what it lost.**

| Earlier rule | Now | Why |
|---|---|---|
| A first miss always gets a second question | kept as the twin | one slip is noise (a tap, a mis-hear); two in one place is a gap |
| Two misses in one deck is a serious flaw | kept as "two misses in one skill or concept family is a gap" | the unit of a gap is now a concept or a contrast, since the questions no longer visit every deck |
| Three misses in a run stops it | kept (section 2.8, rule 5) | a sustained miss rate is a miss rate whatever the items |
| A miss on an easy item is a serious flaw | replaced by the sentinel, which only flags a possible guess (row h) | the old rule made sense when every deck was visited; an expert's single careless miss on a first-unit word should not fail a run that is otherwise perfect |
| AROUND: one question per deck backward at growing steps; FIRST forward at growing steps | replaced by the probe and battery (expert) and a bisection (others, rows d and e) | the walk tested the vocabulary of every deck, which is tedious for a native and weak evidence for an expert; the new tests are the items only a real speaker gets right |
| "Known deck = right, or second right" | kept for bisection steps only, with a strict confirmation (section 3, row d) | a second-chance pass at four options is right 44% of the time by guessing, so a step alone cannot place anybody |

### 3. Part 2: deviations, planned from the baseline

**The common machine.** Every deviation is one of five phases, chained by the table below. **PROBE** is section 2.1. **TIE** is three more hard questions (two at the last deck, one at a deck 90% of the way along the path), each of a *different kind* from the missed one, so the next answer tells what kind of thing the learner misses. **FLOOR** is two questions of the first deck (its core items, the easiest). **BISECT** finds the highest deck the learner knows between a known low end (deck 0 after FLOOR, or a level mark) and a failed high end: first the level marks in order (A1 end, A2 end, then B1) one question each, a second after a miss, then halving the bracket; at most 5 halvings after the marks, so at most about 7 steps and 14 questions; the learner is placed at the lower end of the last bracket (never above what was seen right). Every bisection step is soft (a miss then a right twin passes), so it ends with **CONFIRM**: two fresh questions at the found deck, both right, strictly; a miss moves the placement one deck down and asks two again, once. **LOCALISE** is the step down inside one concept family or one contrast, section row b.

| Row | Trigger | Next steps | Question budget (cap 25) | Outcome written |
|---|---|---|---|---|
| **a. Native or expert fails early** | one of the first two wrong | TIE: 3 questions of other kinds. All three right: a slip, so on to the battery with the slip already used, and any further miss in the battery stops the run (a pass is then not given). A further miss: leave the baseline, BISECT between FLOOR-free deck 0 (not asked: presumed) and a high end of deck N-1 | 2 + 3 + battery 9 = 14 to 16; or 2 + 3 + BISECT 10 + CONFIRM 2 = 17 | slip + battery clean: verified as the baseline; otherwise not verified, placed at the confirmed deck, learn from the next |
| **b. Expert with a gap** (passes hard items, fails one concept family or contrast) | a battery miss, then a wrong twin | LOCALISE: in a family, list its units along the path, ask the family's hardest form in the unit halfway down, and bisect down (at most 3 questions); in a contrast, ask the other letter pairs of the contrast (2 more pairs, then a Write tile question). Record the gap and carry on with the battery; at most two gaps are localised, a third miss stops the run | +3 per gap, 14 + 6 = 20 | not verified for the failing skill (Hear for a pair gap, Recognise or Write for grammar); other skills judged on their own questions; every deck credited except the gap's first failing unit (grammar), or none for a contrast; a gap record `{kind: grammar or contrast, id, deck}`, the contrast id being the tag of the sound-differences deck (ADR-0015); the app offers that unit or the pair drill |
| **c. Advanced non-native** (B1 level, weak on minimal pairs) | probe: Q1 right, Q2 (a pair) wrong, or the pair questions of the TIE wrong | TIE with 2 non-pair kinds and 1 pair of another contrast. Non-pair right, pairs wrong: a contrast gap in Hear; skip the heavy pair weighting, test two more contrasts (2 questions), and run the grammar, complex word and recognition parts of the battery as usual | 2 + 3 + 2 + 9 = 16 | Recognise (and Write if known) verified; every deck credited; Hear not verified; Say not verified if it carried a contrast; the sound-differences deck offered |
| **d. Intermediate (A2)** | probe both wrong, then the floor right | FLOOR right, then BISECT by the marks: A1 end right, A2 end wrong (or right), then halve inside the bracket (at most 5), CONFIRM | 2 + 2 + 2 + 2 + up to 10 + 2 = 20 at the most, usually 14 to 16 | not verified; placed at the confirmed deck; learn from the next |
| **e. Beginner (A1 or none; knows the script only)** | probe both wrong, FLOOR both wrong | stop: nothing is known. FLOOR one right (knows a few words): BISECT from deck 0 as row d | 2 + 2 = 4 (plus the script check, up to 10) | not verified; placed at none; learn from deck 0; the script credited by its own check |
| **f. Script not known or partly known** (Hindustani: Devanagari known, Perso-Arabic not) | the learner marks a script as not read, or its check fails | each script is its own check, before the word run: not read, no question, learn from the script's first deck; a known one, the expert top-two-levels check (2 to 4 questions) or the full five levels (at most 10). The word questions are shown only in a script the learner reads (or in reading); word decks are shared by both scripts, so word placement does not change | script 0 to 10 per script; the word run is unaffected | per script: verified, or learn from its first deck; Hindustani: Devanagari verified with the words, Perso-Arabic learn from its first deck, as the owner described |
| **g. Heritage speaker** (speaks and hears natively, cannot read or write) | Q1 (written) wrong, Q2 (heard) right, or the learner marks Hear and Say known and Read and Write not | decoupled skills: the run asks only the known skills, with spoken and heard items (no written text in the options; the grammar question is "which sentence is right" by audio, or "say it"); then a sheet *proposes* Read and Write as Learn, from the script's first deck, and asks the learner to confirm (a run never changes a skill's state) | script 0 (not read); Hear and Say battery 12 to 14, pairs weighted most | Hear and Say verified; Read and Write not verified; the words are credited for Hear and Say; the script is learn from its first deck; written cards of the credited decks start as Learn once the script is learned (open question 6: per-skill credit) |
| **h. Flaky or guessing learner** | two battery misses with wrong twins, or the sentinel missed with the hard items right, or answers right at depth and wrong at the floor | stop the battery; run the **consistency block**: 4 questions, two easy (deck 0 to 4) and two hard (the last quarter), different kinds. Accuracy falling with depth is knowledge, so BISECT with strict steps (2 in a row at each deck); accuracy about the same at both depths and under 70% is guessing | 6 + 4 = about 10 (a guesser is stopped by two misses after about 3 questions on average, 6 at 99.5%); with BISECT strict: at most 22 | not verified; placed below the deepest deck passed twice in a row, or none; a line asks him to use "I don't know" (nothing is held against him for it) |
| **i. No mic or recogniser, noisy room, "I can't speak now"** | no recogniser; two "unheard" in a row; the Speak button used | Say is not asked (or skipped): left unverified with the reason on the sheet; a noisy room's "unheard" is never a miss: after two the question is dropped and a written one of the same kind replaces it; no voice or sound: Hear left unverified, the pair questions go to Write tiles. The run continues with the other skills; Say can be run alone later | the skipped slots are replaced by written ones, so the run stays at 12 to 14 | the other skills verified or not on their own questions; Say or Hear "not verified: not tested", never "failed"; question 7 default kept |
| **j. Few decks or no grammar decks** | N under 12, or the language has no grammar family | N of 12 or fewer: every deck is asked once with its hardest item (at most N), then M and C as available. No grammar family: the 4 G slots are filled with grammar-in-context items (sentence cards with a close wrong form; Toki Pona's particles are such a family), then complex words. Never fewer than 10 questions in all; a language with fewer distinct hard items asks them all | 10 to 14 | verified as the baseline if the rule is met; a line says how the family or the pairs were missing |
| **k. Not complete to B1** | the path is short of the B1 mark | no battery (that is what verification is): the probe and the TIE run over the decks that exist; expert-like answers place the learner at the end of the available decks (everything credited, "more decks are coming"); other deviations as rows d and e | 2 to 17 | never verified; placed; the sheet says known skills cannot be verified until the course is complete |
| **l. Tired or abandoned mid-run** | the learner leaves, or two misses after question 18 in an otherwise clean run | the run is saved after every answer; on return it resumes at the next question, within 7 days and while the deck set and app version are unchanged; otherwise it is discarded and starts over (no answer carried). A fatigue pause is offered at the trigger ("take a break and continue") instead of a fail: the questions since the trigger are not counted | a pause costs nothing and spends no questions; the 25 count only asked questions | nothing is written until the run finishes; an abandoned or discarded run writes nothing |

**Why bisection and level marks replace the forward walk.** The old FIRST forward walk visited decks 0, 1, 3, 6, 11 ..., which is cheap at the floor but spends questions where a beginner is obviously weak. The level marks are where the path itself says "this is A2", so three questions bound the learner; halving then costs about five more. The assumption is that knowledge is roughly monotone along the path; where it is not (a heritage speaker, a script gap) the decoupled-skill rows apply, not a longer search.

### 4. Worked examples (N = 100, Bengali, B1 complete)

Skills known: Recognise and Hear (one run). `P` probe, `G` grammar, `M` pair, `C` complex word, `R` recognition, `S` sentinel. `ok` is right.

**Example 1: a native, baseline.**

| # | Part | Item | Result |
|---|---|---|---|
| 1 | P Recognise | deck 99, an inflected compound verb form, close wrong form | ok |
| 2 | P Hear pair | deck 99, aspirated against unaspirated (খাল or কাল) | ok |
| 3 | G | case endings, hardest form (deck 94) | ok |
| 4 | M | dental against retroflex (তাল or টাল) | ok |
| 5 | G | tense and aspect, hardest compound tense | ok |
| 6 | C | a four-syllable word of deck 96 | ok |
| 7 | M | nasalised against plain vowel | ok |
| 8 | G | politeness forms | ok |
| 9 | S | deck 2, "water" | ok |
| 10 | R | deck 88, close distractor | ok |
| 11 | M | flap (ড় against র) | ok |
| 12 | G | conditional clauses | ok |
| 13 | C | a long idiom of deck 91 | ok |
| 14 | G | relative clauses | ok |

Result: 14 questions, no miss. Recognise and Hear verified; every deck credited. A native would see this in about two minutes and no deck is listed.

**Example 2: an expert with a gap (a minimal pair).**

| # | Part | Item | Result |
|---|---|---|---|
| 1 to 2 | P | recognition, pair (aspiration) | ok, ok |
| 3 to 6 | G, M, G, C | case, dental or retroflex, tense, complex word | ok x4 |
| 7 | M | flap (ড় against র) | miss |
| 8 | twin M | flap, a different word pair | miss (gap) |
| 9 to 10 | LOCALISE | flap pair 3; a Write tile question with the swapped letter | miss, ok |
| 11 to 15 | G, S, R, C, M | politeness, deck 3, recognition, complex word, nasal | ok x5 |

Result: 15 questions, one gap (contrast `flap`). Recognise verified and every deck credited; Hear not verified; the sound-differences deck is offered for `flap`.

**Example 3: a heritage speaker (Hindustani-like, speaks and hears, cannot read).**

| # | Part | Item | Result |
|---|---|---|---|
| 0 | Script | learner says "I do not read it" | no question; script: learn from its first deck |
| 1 | P Hear | an audio sentence, pick the matching meaning (no written text) | ok |
| 2 | P Say | say the complex word of the last deck | ok |
| 3 to 12 | G, M, C, S, R by audio and speech | grammar by "which sentence sounds right", three pairs, two complex words to say, a sentinel, a heard recognition | ok x10 |

Result: 12 questions. Hear and Say verified; Read and Write not verified; the sheet proposes Read and Write as Learn from the script's first deck and the learner confirms. The words are credited for Hear and Say.

**Example 4: a guesser (right a quarter of the time at four options).**

| # | Part | Item | Result |
|---|---|---|---|
| 1 | P Recognise | hard item | ok (lucky) |
| 2 | P Hear pair | pair | miss |
| 3 to 5 | TIE | 3 hard items of other kinds | miss, ok, miss |
| 6 | stop | two misses with wrong twins | run goes to the consistency block |
| 7 to 8 | easy | deck 1 and deck 3 items | miss, ok |
| 9 to 10 | hard | two last-quarter items | miss, miss |

Result: 10 questions; accuracy is the same at both depths and under 70%, so this is guessing. Not verified, nothing credited above deck 0; a line asks him to press "I don't know" instead of guessing. The probe's 6% chance of a lucky pass never reached a verified mark because the battery was never earned.

### 5. Short and long paths

- **N of 12 or fewer.** Every deck is asked once with its hardest item, then M and C: at most N plus 4, under 25.
- **N from 13 up (every complete language today; Bengali about 169 units).** The battery of section 2.3 is used; the cap of 25 is never near.
- **N under 2.** One deck is asked twice.

### 6. Minimal-pair data today, and what is missing

What the app has: a `<lang>-sounds.yaml` for ten languages (as, bn, gu, hi, ja, kn, ko, mr, te, zh: 4 to 9 contrasts each, as letter pairs, with `within_word` for a sign added at the end of a word). The speaking drill's feedback uses it (ADR-0015). Each contrast id is the tag of a language's sound-differences deck. A minimal-pairs drill, `PairDrill`, exists but is built on fixture data and shown disabled until #31 gives it an ADR, deck data and a device check; nothing in a live session builds it. `alike_warning.dart` already finds sound-alike and look-alike cards for a review.

What is missing:

1. **Spanish and Toki Pona have no sounds file** (both are complete to B1 and so verifiable). Spanish has few contrasts that matter (r against rr, for example); Toki Pona almost none.
2. **A pair list of actual words.** The file gives letter pairs, not word pairs. A pair question needs two real words of the language's decks that differ by exactly one swap; they have to be found by swapping letters in the decks' words (a one-off tool over the decks, by the plan's rule of tools written by the tools, not by hand) and kept as a derived list, or computed on the device from the deck's cards.
3. **Tone, length and stress.** Chinese and Japanese contrasts include tone and vowel or consonant length, which are not a letter swap; the file's form cannot say them.
4. **Audio.** The pair needs the two words to sound different. The system voice (ADR-0002) may flatten an aspirated or retroflex contrast on some phones, in which case a native would fail a correct answer. A check on a device, and a fallback to Write tiles when a pair's audio is not trusted, are needed.
5. **A difficulty per pair** (a pair of two common words against two rare ones); today a pair's difficulty can only come from the closeness `c` and the deck depth.

### 7. Part 3: open questions for the owner

Each has the default this plan assumes, in brackets, and the main downside of the options.

1. **Is "last two perfect" enough to presume expert, as the plan reads it, with the two questions of different kinds (one recognition or complex word, one pair)?** [yes] Downside: a learner who studied only the hardest items passes the probe; the battery is what catches him. The other option (two questions of one kind) is quicker but weaker.
2. **How many misses may a verified run have?** [one slip per skill, repaired by a right twin; a third miss in the run stops it] Downside: lenient for a perfectionist; zero misses would fail a native for a single careless tap.
3. **Battery size: about 10 to 14, hard cap 25, with `10 + 2k` for `k` known skills.** [yes] Downside: more known skills mean a longer run (18 for four skills); fewer questions per skill would be quicker but let a half-guesser through (3 in 100).
4. **Is "I don't know" a miss?** [yes, as before] Downside: a polite learner is penalised for honesty; the alternative invites guessing.
5. **Minimal pairs for languages without a sounds file (Spanish, Toki Pona), and for tone (Chinese, Japanese).** [use letter-swap pairs from the decks for Spanish; replace the M slots with complex words for Toki Pona; leave tone pairs out until a pair list exists] Downside: weaker evidence of hearing for those languages. Writing the sounds data is deck-adjacent work that the deck-work rules put last.
6. **Non-prefix credit and per-skill credit.** Gaps and a heritage speaker need "every deck credited except these", and "credited for Hear and Say, not for Read". `placedDeckIds` is a set, so the first looks possible; per-skill credit is not in the model. [allow gaps as exceptions; credit per skill for a heritage speaker by the proposal sheet] Downside: more states for the schedule and the Today count to handle; the alternative is to place a gap learner at the gap deck, which makes them re-study decks they know.
7. **Pair audio.** If the system voice does not render a contrast, do pairs go to Write tiles, or are they dropped for that language? [Write tiles; a device check per language first] Downside: Write tests spelling, not hearing.
8. **Level-mark ladder before halving (rows d and e), or plain halving?** [the ladder] Downside: three extra questions for a learner who is at one end.
9. **Does a self-declared level seed the search** ("I think I am A2")? [no; the probe alone decides] Downside: a plain A2 learner spends 2 extra probe questions failing.
10. **Resume window and fatigue pause.** [7 days; a pause after two late misses in a clean run] Downside: a stale run resumed after a week mixes old and new knowledge; a pause may be gamed to retry a question.
11. **Answer-speed guess detector** (very fast answers on long text are flagged)? [off] Downside: a fast reader is not a guesser, and a detector would punish natives; its benefit is only on guessers, who the battery already stops.
12. **Learner's own review history shortens the run.** [yes, only for cards with high stability, skipped as evidence] Downside: history means "learned in the app" and not "knew it before", so it is never taken as proof; sizing the shortcut needs the owner's view.
13. **One verified mark for a native and for a B1 learner alike.** [yes, "verified to B1"] Downside: the label hides that a native is far beyond B1; an "expert" label would need a harder battery and a policy.
14. **Weights of hardness (0.35 depth, 0.30 form, 0.35 closeness) and the 10, 12, 14 sizes.** [as written] Downside: there is no population data to tune them; they will be set by feel and then by logging how often each item type is missed (which would need a log the app does not keep).

**Earlier open questions (1 to 8):**

| # | Earlier question | Now |
|---|---|---|
| 1 | "Serious flaw" as two misses in a deck, an easy miss, three in a run | changed: two misses in one skill or concept, and three in a run, are kept; the easy-item rule becomes the sentinel (section 2.9) |
| 2 | Verified in part, up to the deck passed | answered: no deck-prefix verification; verification is per skill, and a skill with a gap is simply not verified (rows b, c) |
| 3 | One verified mark per skill or per language | kept as the default, per skill; a gap is also recorded, per concept or contrast; still to confirm |
| 4 | "I don't know" counts as a miss | unchanged, still open (now question 4) |
| 5 | When the 25 run out | changed: a battery cannot reach 25 in the baseline; a bisection that does stops and places below the deepest deck confirmed, never extended |
| 6 | Verifiable short of B1 | answered by the owner's 2026-11-05 rule: no (row k) |
| 7 | No voice or recogniser: unverified or the written fallback | changed in detail: unverified and "not tested" (row i), with the slot replaced by a written question so the run is not shortened; Write tiles replace pairs only if the owner agrees (question 7 above) |
| 8 | One run for all known skills, or one per skill | taken as answered by the owner's earlier default (one run, section 2.6); confirm |

### 8. Risks

- **A native fails a correct answer because of the system voice** (a flattened contrast). Downside: a failed verification feels like an insult; mitigated by the Write fallback and the twin.
- **Hard items are hard for the wrong reason** (a rare word that is not hard grammar). Downside: a native can miss a word he never met; mitigated by weighting form and closeness, and by the twin.
- **Hardness is a guess without population data.** Downside: the early runs may be too easy or too hard.
- **The battery tests grammar through the deck's own sentences.** Downside: a language with thin grammar decks gets a weaker battery (row j).
- **A run over several skills splits the questions thinly** (3 per skill). Downside: each skill rests on few questions; the pass rule needs all of them.
