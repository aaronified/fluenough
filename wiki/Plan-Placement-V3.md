# Plan: placement V3, find my level

Source of truth: this wiki page.

Status: approved by the owner on 2026-11-07 ("Ok, do it."). The owner's
decisions are recorded below as the accepted recommended defaults of the
design that follows. The design text is unchanged from the proposal.

## Owner decisions (2026-11-07)

Accepted as the recommended defaults:

1. Time cap: 5 minutes, with a keep-going button.
2. Say without a recogniser: half weight, labelled "Self-rated".
3. Start position: the lower edge of the credible range.
4. Old "Verified" marks: shown as "Earlier check (not verified)".
5. Cognates: near-cognates are excluded from yes/no, meaning-pick and
   heard-word items; they are half-weighted elsewhere.
6. Typing items are used; tiles are used where there is no keyboard.
7. "Verified" is removed from placement.

Requirements from the owner:

- Measure all skills together, and each skill in isolation.
- The test must not depend on Hear or Say.
- Mix the skills first, then drill into the skill that fails.
- Use every item format (multiple choice, cloze, one-word typing, matching, and the others in the inventory below).
- Hear and Say are tested, but they are never the only evidence for a skill.
- Re-check the design with an adversarial agent that tries to ace the test using only the first 100 words and basic suffix and form rules. Done 2026-11-07: V3 as written was found gameable; the result and the required amendments are in "Adversarial review and required amendments" at the end of this page, and they are mandatory.

---

# Find my level, V3: a mixed-then-isolating placement design

Status: proposal for the owner. Read-only inputs: the three research files, wiki/Plan-Placement-V2.md, lib/core/placement/*. Tags: **EVIDENCE** (research file and its level; nearly all levels are "abstract/snippet", research-2 could read no full text) and **INFERENCE** (my reasoning, to be tested by the validation plan). Note: the harness, personas and bank files named in the brief (test/fixtures/placement, tool/placement_bank.dart) are not on this checkout; V2's numbers came from a scratch Python script. Part (g) therefore builds the harness, reusing V2's persona idea.

## 0. Why V2/0.9.3 failed, in one paragraph
Skills ran one after another (Hear first) with no per-skill cap, one question kind was asked (heard word to English pick), Hear's 95% target was never reached, and the readout showed P(none) as "sure". V3 keeps V2's posterior maths but changes who asks what: skills are interleaved, every skill has a cap and a guaranteed minimum, and the readout reports a range.

## (a) Measurement model

**Latents.** One position per skill, p_Read, p_Hear, p_Say, p_Write, each over the same classes as V2 (`none`, then up to ten tenths of the A1 to B1 path; I propose 20 classes so a range is narrower than a tenth; V2's `PlacementLevels` already takes `parts`). Plus a **script gate** per script (none / letters partly / all letters), a separate small latent, as V2 had a Script skill.

**Joint, not four separate chains.** Hold the joint over the skills in play (at most 12^4 cells, cheap on a phone). The prior is a mixture: 70% "skills move together" (mass near the diagonal) and 30% "independent". This is what lets a mixed item inform several skills and still lets an ear-only or script-literate-only learner be found. INFERENCE (V2 treated skills as independent chains).

**Item likelihood.** Each item has a difficulty d (path unit of its word, sentence or letter), a set R of required skills, a slip s and guess g. A learner passes if every skill in R knows level d (noisy AND): P(right) = g + (1 - g - s) x Π_{k in R} P(p_k >= d). A right answer raises every skill in R; a wrong answer is *explained* by the joint posterior (which skill is probably short), not split evenly. V2's `PlacementQuestionKind` slip/guess table is reused as the starting values. INFERENCE for the conjunctive form; Staehr 2008 and Milton et al. 2010 (research 1, finding 4; research 2 rows 16, 17: secondary) support treating Read, Hear, Write as separable, with orthographic vocabulary tracking Read/Write and aural vocabulary tracking Hear, Say.

**What one answer updates** (the "requires" column of section b): tile sentence from English = Write+Read-of-tiles (the tiles are shown, so a light Read); reading-comprehension pick = Read; dictation tiles = Hear+Write; yes/no real vs pseudoword (written) = Read recognition; heard yes/no = Hear recognition; letter-to-sound = Script gate. Isolating items require exactly one skill.

## (b) Item inventory (every format)

Generated from decks: word cards (unit order, frequency rank), sentence decks with translations, letter/script decks, `<lang>-sounds.yaml` minimal pairs (V2 section 8 notes they are sparse), on-device TTS. Difficulty d = unit index of the card (INFERENCE; Settles et al. 2020, research 1 finding 1, makes difficulty-from-features the DET approach, abstract level). Guess and slip values below are starting priors, to be fitted from replay and later opt-in logs.

| # | Format | Requires | Audio/mic | Guess / slip | Leak risks | Generation |
|---|---|---|---|---|---|---|
| F1 | Written yes/no, real word vs matched pseudoword (about 25% pseudo) | Read | none | g from the learner's own false-alarm rate (floor 0.1), s 0.10 | cognates say "yes"; pseudoword must be a non-word | pseudoword by swapping letters within a deck word, kept by a n-gram check of the deck's own words |
| F2 | Written word, pick English meaning (4) | Read | none | .25 / .05 | cognates, odd one out by length or script | distractors: same-unit words of the same part of speech |
| F3 | Meaning (English), pick the written word (4) | Read, light Write | none | .25 / .05 | spelling cues | same distractor rule, one letter apart for later units |
| F4 | Meaning, build the word from letter tiles (short words) | Write | none | .10 / .05 | tile set hints | tiles = letters plus 2 decoys |
| F5 | Sentence in the language: pick its meaning (4) | Read | none | .25 / .10 | cognates, topic guessing | sentence deck, distractors from other sentences of the same unit band |
| F6 | Cloze by choice: blank in a sentence, pick the form (4) | Read, grammar | none | .25 / .10 | answer-by-agreement cues | blank one word of a sentence-deck line, distractors are other forms of that word |
| F7 | Cloze by typing / one-word typed answer (script keyboard or latin spelling) | Write | none | .03 / .15 (typing slips are real, accept near-misses by edit distance 1 for latin, shown as half credit) | none | same as F6, hint-free |
| F8 | Tile assembly: English meaning to a sentence in the language | Write, Read | none | .05 / .10 | tiles leak word order | tiles from sentence-deck line, decoys from the same unit |
| F9 | Matching: 4 word-meaning pairs on one screen | Read | none | per pair about .25 falling as pairs resolve; scored as 4 weak items | elimination makes it guessable | words of one unit band |
| F10 | Matching: letter-sound (pairs, sound by TTS or romanisation) | Script (audio optional) | optional | .25 | | letters deck |
| F11 | Matching: word-picture where the deck has a picture, else word-meaning | Read | none | .25 | | |
| F12 | Letter-to-sound: pick the romanisation/IPA of a letter or syllable | Script | none | .25 / .03 | Latin-script languages are trivial (gate says so) | letters deck |
| F13 | Heard word, pick meaning (4) | Hear | TTS | .25 / .05 | poor TTS | word card |
| F14 | Heard yes/no: real word vs pseudoword | Hear recognition | TTS | like F1 | | pseudoword spoken by TTS: skip if TTS cannot say it |
| F15 | Minimal pair: which of two was said | Hear | TTS | .50 / .05 | weak per item | sounds file, only where present |
| F16 | Removed (#1105): dictation, hear a sentence and build it, asks what was said, not the meaning | | | | | |
| F17 | Heard sentence, pick meaning | Hear | TTS | .25 / .10 | | sentence deck |
| F18 | Say: shown the meaning, say the word. **With a recogniser**: scored. **Without**: record, play back the model audio, self-rate "same / close / no" | Say | mic | recogniser .03 / .15; self-rated: g .30 / s .10, and counted as at most half an item | self-rating is generous | word card |
| F19 | Say-then-check: say it aloud (not scored), then pick which of 3 audios was what you meant to say | Say (recognition of own target) | TTS | .33 | | word card |
| F20 | Say, sentence: read the written sentence aloud, self-rate | Say, Read | mic | as F18 | | sentence deck |

Say is never the only evidence for any skill and a skill is never **placed** by self-rating alone: Say's range always carries the label "self-rated" unless a recogniser scored it (INFERENCE; V2 already decided no offline speech scoring; Kostromitina and Plonsky 2022, research 2 row 27, support elicited imitation as a proxy, snippet level, but it needs scoring we lack).

**Without audio/mic.** F1 to F12 cover Read, Write and Script fully; Hear and Say become "not tested". With TTS but no mic: F13 to F17, F19.

## (c) Adaptive policy

**Phase 0: the declaration (V2, kept).** The four-answer question seeds the prior location and widens it; never evidence (V2 section 1). Add one yes/no per skill "Can you hear or say it? Do you read this script?" that only sets which items are *eligible*, never the result. Script-less languages (Latin) skip the gate. Script gate: 3 to 4 letter items (F10/F12) when the script is non-Latin. Gate result = a prior shift: a no-script learner has p_Read, p_Write capped to 'none' until the gate is passed; she is still asked F4-type items in latin transliteration if the deck has it, so Read/Write are not left blank (INFERENCE).

**Phase 1: mixed rotation (about 14 to 18 items).**
1. The schedule rotates through the skills in play so every skill is *required by* at least 3 items in the first 12. A mixed item counts toward every skill it requires; the schedule picks the cheapest mix: F8 (Write+Read), F16 (Hear+Write), F5/F6 (Read), F13/F17 (Hear), F1/F14 (recognition), F18 (Say).
2. Formats are rotated: no more than 2 consecutive of the same format, so cloze, matching, tiles, typing, yes/no and MCQ all appear. A matching screen counts as one slot (four weak items).
3. Next item = the candidate with the greatest **expected information gain** on the joint posterior (mutual information between the answer and the position classes of the required skills), per second of expected time (a table: yes/no 3 s, MCQ 6 s, matching 15 s, tiles 15 s, typing 12 s, Say 10 s), with a **coverage floor**: any skill with fewer than 3 items, or whose items so far are all one format, is forced next (so "one skill never starves another"; V2's `item_picker.dart` already has a picker to extend). The first item of each skill is at the prior median (the middle of the declared range), then moves by information gain.
4. Ceiling controls: the first items are mixed because they are cheap per skill (research: DET and Linguaskill mix item types per skill, research 3 rows DET and Linguaskill; snippet-primary, not fetched).

**Phase 2: the isolating drill-down.** Trigger, per mixed item:
- a wrong answer on an item with |R| >= 2, or a right answer that conflicts hard with the posterior (a skill's marginal probability for the item's level < 0.2 yet it was answered right, i.e. a likely lucky guess), or
- a skill whose posterior after Phase 1 has an 80% interval wider than 6 classes of 20, or whose evidence is contradictory (two items at the same level, one right, one wrong, none isolating).
Then: for each implicated skill (those in R whose marginal puts the failure there with probability >= 0.25 after the update) ask 2 isolating items at that item's level, from the single-skill formats of that skill, chosen by information gain: Read: F2 then F5; Write: F7/F4 then F3; Hear: F13 then F15/F17; Say: F19 then F18; Script: F12. This is V2's "a miss gets two checks: slip forgiven, both wrong closes the case" (kept; the checks are ordinary items and the posterior does the forgiving), but the checks are **split by skill** (the owner's "split the skills"): the first isolating item goes to the skill most likely to have failed. Stop rule for a drill-down: stop when the failing skill is identified with posterior mass >= 0.8, or after 4 isolating items for that trigger, or when the skill hits its cap. A drill-down updates exactly like any item (isolating = |R| = 1, the plain Bayesian update; the joint then has no ambiguity left). Each trigger is processed at most once per skill-level.

**Caps and stopping.**
- Per skill: at most 14 items touching it (mixed items count to every skill), at most 10 in Phase 2; minimum 3.
- Global: at most 40 items and 300 s (hard); soft stop at about 22 items.
- A skill stops when its 80% interval spans at most 2 classes of 20 (about 1 tenth), or the per-skill cap, or the global cap. A stop on cap is reported as "low confidence", never hidden. The overall run stops when every skill in play has stopped. V2's per-skill "95% assurance, run until reached" is **retired**: it is why 0.9.3 went on and on (and 95% of a 12-class posterior on a single item type is not reachable at slip .05).
- "I don't know" is a first-class button, counted as wrong with guess 0 (it does not carry a guess), shortening runs (research 1 recommends it; INFERENCE).
- Time: the research supports about 3.5 to 5 min only for yes/no recognition with 60 items (LexTALE: 60 items, about 3.5 min; Lemhofer & Broersma 2012, research 2 row 31, abstract; Puig-Mayenco 2023 warns it is a weak stand-alone placement). Everything else (DET about 1 hour; Linguaskill 60 to 85 min; ALEKS up to 30 questions, research 3) is far longer than we can afford, so **3 to 5 minutes for 4 skills is an INFERENCE** and the validation plan's time budget below tests it. VST/Beglar 2010 found 5 items per band adequate for reliability (research 2 row 2), which is a reason to expect 3 to 6 items per skill give a coarse (one-tenth wide) position, not a fine one.

**A skill that cannot be tested** (no TTS for Hear, no mic for Say, no audio at all): it is dropped from the skills in play before the run, the run is not longer, and the result says "Not tested: Hear (no audio on this device)". A skill that is tested only by proxy (Say by self-rating) says "Self-rated". Read and Write never depend on either.

## (d) Guessing, cognates, script

- Pseudowords catch yes-saying. EVIDENCE: Huibregtse et al. 2002 (research 2 row 8; secondary), Zhang, Liu & Ai 2020: false alarms on matched pseudowords track real-word guessing at r over .80 (row 13; abstract). Mochida & Harrington 2006: the raw hit rate predicts about as well as any correction formula (row 9; snippet). So: use pseudowords as an **estimate of the learner's yes-bias** that sets g for F1/F14, not a complicated correction formula (INFERENCE from those two). A false-alarm rate above 0.35 triggers a "please answer honestly" nudge and widens the interval.
- Format-specific guess floors (F2 g=.25, F9 lower) follow V2's `guessability`-style floors (V2 section 4.2: defaults "chosen by feel"; INFERENCE) and are re-fitted from replay.
- Cognates inflate scores. EVIDENCE: Allen 2019 and Ferre & Brysbaert 2017 (research 2 row 34, abstract: non-cognate words have the highest discrimination; research 3: Allen 2019, snippet). Choice: items whose word looks like an English or a declared-known-language word (edit similarity on the romanisation above a threshold, or flagged in the decks) are *excluded* from F1, F2, F13 and weighted by 0.5 elsewhere (INFERENCE). Cognate-advantaged learners are found by the drop in accuracy once cognates are excluded: so the first two items of Read and Hear are kept non-cognate.
- Script: separate gate (letters), as V2 (EVIDENCE for separability: Milton et al.: orthographic vocab and aural vocab correlate .22 to .68 across sources, secondary; heritage learners' listening and writing barely correlate, Zyzik/Avant, research 2 row 51, snippet; INFERENCE for the exact gate). A learner who knows the script but not the words passes the gate and gets p_Read at 'none' honestly. An ear-only/heritage learner gets high p_Hear, p_Say and low p_Read, p_Write, through the mixture prior's independent component.
- Vocabulary-only tests top out at low-intermediate (Lam, research 3: snippet; Harrington & Carey 2009 also), so F5/F6/F8/F16 (sentence-level) are deliberately in the Phase 1 rotation, not only words.

## The result card (owner, 2026-11-09, #1097)

The "See my result" pause is gone: the result card shows when the run ends, and at the soft stop (about 22 questions) it carries **Keep going** for a sharper answer; Done ends the run with what it holds. Check again and "I do read it" sit on the card too, when Read and Write wait for the script. Per skill the card shows only a **level name** and the **range of the whole language path** the run is 80% sure of, drawn as a bar (the span of the interval; a point shows as a small mark): no deck-range text and no confidence wording. The progress star and level widgets keep their placed layer and mark.

The path is the whole language path (its units, `V3Result.totalUnits`); the range is the interval's low and high unit as a whole percent of it. The level name comes from the middle of the range:

| Level | Middle of the range |
|---|---|
| Beginner | under 20% |
| Amateur | 20% to under 45% |
| Fluent | 45% to under 75% |
| Expert | 75% and over |

The cut-offs are `v3LevelCutoffs` in `lib/core/placement/v3_result.dart`. The (e) section below is the earlier design.

## (e) Result screen

Per skill (Read, Hear, Say, Write, and Script where it exists) one row:
- **Start at unit 14**, with "likely between 11 and 17" (the 80% credible interval from the joint marginal, rounded to units), and a confidence word derived from **P(true level within the shown range)**, (high >= 0.8, medium 0.6 to 0.8, low below), **never P(none)**. The number shown, if any, is that probability, labelled "how sure we are of the range".
- Tested items: "6 questions", tested vs **Not tested** (reason) vs **Self-rated** (Say).
- A one-line reason ("You read sentences well but spell words from sound slowly").
- The start unit recommended per skill is the **10th percentile** (lower edge of the 80% interval, minus nothing): INFERENCE following research 1's "start one to two below the estimate"; the learner may move it up. It feeds the existing per-skill `placedDeckIds`, so a skill starts where its own position is, as V2 does.
- Override: edit any skill's start; the placement remains a seed, reviews keep refining (research 1: Elo/BKT-style updates, INFERENCE).
- The word **Verified** is removed from the placement result (see f).

## (f) Keep, change, delete, migration, build plan

**Keep:** `assurance_model.dart` levels and the Bayesian update (extend to joint), `PlacementQuestionKind` slip/guess table (extend by the formats above), `placement_data.dart`, `saved_run.dart` (pause and resume), `declaration_options.dart` (prior seed only), `question_outcome.dart`, the generators of `question_builder.dart` (F2, F3, F5, F8, F13 to F16 mostly exist) and the Languages-sheet skill rows. V2's rule "a run never changes a Learn, Know or Leave state" and "only the dialect taught".

**Change:** `placement_run.dart` (strictly sequential Hear to Read to Say to Write becomes the rotation and drill-down state machine), `item_picker.dart` (information gain per second, coverage floor, format rotation), `skills_in_play.dart` (adds availability: TTS/mic/script), `assurance_readout.dart` (credible interval and range probability instead of the lowest-class mass), `placement_session.dart` and `lib/features/placement/find_level_*` (screens for cloze, matching, typing, yes/no, self-rating).

**Delete or retire:** the expert track and the seven mastery topics as an *ordering* (some become item families only), "closed case" and 95% assurance as a stop and as Verified, the 25-question checkpoint (replaced by the caps; a "keep going" button may extend the global cap once), the "Verified" mark from placement, `extraScriptQuestion`, the heard-word-only builder path as the default. Item hardness scoring and the unbuilt "no-repeat" rule (V2 'not modelled yet') are built in step 3.

**Migration / withdrawal.** Placements from 0.9.0 to 0.9.3 stay as they are in the learner's data (never silently changed), but: (1) the Verified marks they carried are shown as "Earlier check (not verified)" and not counted anywhere; (2) any skill whose old run had fewer than 3 items, or whose confidence was shown as P(none), is marked "unconfirmed"; (3) on the Languages sheet an optional "Re-check (about 3 minutes)" offers V3, once per language; (4) if the learner has real reviews on the skill, the reviews win over any placement. Needs a data-version bump in `saved_run.dart`; I did not read the storage code, so the exact fields are to be confirmed in step 1.

**Build plan (small PRs, each with CI):**
1. Joint model and readout (`lib/core`), unit tests, no UI; the credible interval.
2. Persona replay harness (pure Dart, deterministic), personas, pass/fail gates as tests in CI.
3. Item registry: formats F1 to F20 with requires, slip, guess, time cost, cognate and pseudoword generators.
4. Picker: information gain, coverage floor, rotation, caps.
5. Phase 2 drill-down and stop rules.
6. UI: new formats (cloze, matching, typing, yes/no, self-rate), availability handling.
7. Result screen and migration.
8. Real-learner study (opt-in logging) and re-fit of slip/guess.

## (g) Validation

Personas, each simulated with per-skill true positions and the slip/guess of the table, over 3 languages (one Latin-script, one non-Latin script, one with weak TTS), 500 runs each: beginner, amateur, advanced, expert, native, script-literate-only (script yes, words none), ear-only (Hear, Say high; Read, Write none), cognate-advantaged (cognate items answered right regardless of position), plus no-audio and no-mic variants.

**Pass gates (CI):**
- Questions: median <= 22, 95th percentile <= 40 (global cap).
- Seconds (simulated from the time table): median <= 180, 95th percentile <= 300.
- Coverage: 100% of skills in play get >= 3 items that require them, in 100% of runs; Read and Write 100% placed in the no-audio variant; no skill uses more than 14 items.
- Misplacement: placed start within one tenth (2 classes of 20) of the true start for at least 85% of runs; start more than 2 tenths **above** the truth in at most 3% (overplacement is worse than underplacement); never above the true position by more than 3 tenths in 99%.
- Honest confidence: the shown 80% range contains the true position in 75% to 88% of runs, for every persona; and high-confidence rows are right (within one tenth) in at least 90% of those cases.
- Specific: script-literate-only gets Read/Write at 'none' to the first units with the script passed; ear-only is placed high on Hear/Say and low on Read/Write; cognate-advantaged is not placed more than one tenth above the truth.
- Drill-down: for a persona with exactly one failing skill, the right skill is identified in at least 90% of runs within 4 isolating items.

**Real-learner check:** about 30 opt-in learners (include heritage and script-literate-only), run V3, then compare with each skill's first 2 to 4 weeks of review accuracy: target rank correlation >= 0.6 per skill, with the owner reading the failures. Until this is done the numbers above are a model's, and the result screen says "estimate".

## (h) Decisions only the owner can make

1. **Time cap.** 5 min hard (my proposal) vs 3 min vs "a Keep going button". Main downside of shorter: wider ranges and lower-confidence labels for Hear and Say.
2. **Say without a recogniser.** Self-rating counted at half weight and labelled (my proposal), vs not counted at all (Say always "not tested"), vs counted fully. Downside: self-rating overplaces generous learners, but excluding it leaves Say with no placement.
3. **Start position: lower edge of the range** (proposal) vs the median. Downside of the lower edge: an expert re-does a few easy units; of the median: a weaker learner meets units that are too hard.
4. **Fate of old Verified marks.** Keep as "earlier check" (proposal), vs remove, vs keep until a re-check. Downside of removing: learners lose an earned mark.
5. **Cognate policy.** Exclude near-cognate items (proposal) vs count them half vs ask the learner's known languages. Downside of excluding: fewer usable items for related-language courses (Spanish, French) and extra data work.
6. **Typing items.** Include typing in non-Latin script (F7) when the keyboard is missing (needs tiles instead), vs tiles only. Downside of tiles: easier, so Write is overestimated.
7. **Whether 95% Verified stays at all**, under the model's honest range, or is replaced by the range display only (proposal).


---

# Adversarial review and required amendments (2026-11-07)

An adversarial agent tried to ace V3 using only the first 100 words of the path, top-100 function words, regular suffix and form rules, and test-wise tricks, never reading the answer key. Its scripts and raw results are kept by the orchestrator in the session scratch folder (`adv/`); the full numbers are summarised here.

**Verdict: V3 as written is gameable.** Its own cognate rule removes most of the problem under a flat prior, but it still fails its own gates. A random answerer that declares "advanced" is also placed more than 1/10 too high in about 5% of runs, so the stopping rule and the prior are weak, not only the item formats.

## What was found

Start more than +1/10 / +2/10 of the path too high, Spanish, per skill, strong anagram solver, 300 runs per cell (A = V3 literal, D1 = A plus the design's cognate exclusion, X1 = D1 plus calibrated guess rates, two decoy letters on word tiles and a 30% flat prior):

| Scenario | Read | Hear | Write |
|---|---|---|---|
| A, flat | 27 / 21% | 17 / 13% | 14 / 9% |
| A, amateur declared | 39 / 21% | 31 / 11% | 39 / 19% |
| A, advanced declared | 77 / 74% | 70 / 68% | 70 / 68% |
| D1, advanced declared | 37 / 35% | 35 / 32% | 38 / 37% |
| X1, flat or amateur or advanced | 0 to 1% | 0 to 1% | 0 to 1% |

- Hindi (weak solver): A flat 9/6%, A advanced about 38/34%, X1 2% or less.
- **Say**, always self-rated "same": start more than 1/10 too high in 86% of runs (Hindi 74%), and adding Say pushes runs to a median of 39 items. X1 does not fix it.
- Cognate-only (knows no words) is over by 1/10 in 28% of runs flat and 58% advanced under A; 3% and 15% under D1; 0% and 2% under X1.
- A random answerer declaring "advanced" is over by 1/10 in 6% (Read) and 5% (Write) of runs under A.
- Asking the same card twice in a drill-down makes Hear worse (35% over by 1/10 against 11%).
- Honest experts and natives are placed at 154 to 163 of 170 (Spanish) in 8 to 10 items under every scenario: the fixes cost no sensitivity.
- The 80% range contained the truth in 59 to 73% of runs under A flat, and 18 to 27% under A advanced (the gate is 75 to 88%).

Leaks by format (Spanish, items beyond unit 11; the design's guess rate in brackets): word-to-meaning pick F2/F13 57 to 60% Read, 47 to 50% Hear (.25), and 97% / 74% on cognates; meaning-to-word pick F3 60%, 99% on cognates; word tiles F4 36% with a strong solver (.10) because the bank's tiles are exact letters, 20% with two decoys; typed words F7 23% exact and 51% within edit distance 1 on cognates; sentence picks F5/F17 77 to 86% (Hindi 52 to 60%), because the distractors are topic-unrelated, and "longest option" is right 60% of the time; cloze F6 57% with the English hint, 98% from endings alone for a conjugation cloze, 87% for article gender from the noun ending; the word-order pair 98% (end marks left mid-sentence); matching F9 72% per pair and 54% for all four pairs (chance 4%); yes/no F1 plug-in false-alarm estimate fails for a yes-sayer in 49 to 73% of runs, but 12 to 16% when it is a joint latent; a write item on a card lifts a later pick on the same card from 40% to 66% (family leak). Held: tile-sentence ordering (exact success about 0%), pseudoword discrimination by phonotactics (AUC .53 to .57), the cognate exclusion (5 to 8 times fewer over-placements under a flat prior), the lower-edge start under a flat prior.

## Required amendments (mandatory)

**Item generation**

1. A cognate score at bank build (respelling plus similarity; for Hindi, by transliterating loanwords). Near-cognates are excluded from all word-level formats (yes/no, meaning picks, written-word picks, typed words, matching, tiles, and the first item of each skill). Sentence items are weighted 0.5, or require at least two non-cognate content words.
2. Word tiles need at least two plausible decoy letters, or syllable tiles. Admission test: a strong anagram solver's success is at most the guess rate plus 0.07.
3. Word-order pair: end marks stay fixed; one constituent is swapped.
4. Word-pick distractors: same part of speech and surface shape, with one cognate lure or false friend. Sentence-pick distractors: one-word contrasts of the correct translation, matched in length and cognate load.
5. Cloze: no English translation hint; options agree in person, number and gender and differ in stem or lexical choice, so endings cannot decide; exception nouns (la mano, el mapa, la flor) are included as gender items.
6. A card is never asked twice in a run, drill-down included.

**Estimator**

1. The guess rate is calibrated per format and cognate class from adversary replay with a 90% upper bound; items with a guess of 0.9 or more are dropped (they give no evidence). `GuessCalibration` in `lib/core/placement/joint_model.dart`.
2. The declaration prior carries at most 70%; at least 30% is flat.
3. **Proven level ceiling.** A skill is not placed above its highest band proven by 4 of 4 or 5 of 6 correct, non-leaky, non-cognate items (so at least four clean items per claimed band per skill, not three). A band is a tenth of the path. The rule is "the chance of a guesser doing as well is at most 1.25%", judged at the larger of 0.30 and the highest guess rate of the band's items. An item guessed more than 35% of the time may still move the posterior but is never a clean item.
4. **Say is never placed from self-rating alone.** Self-rated Say items never enter the joint (weight 0, because the joint would otherwise lift Hear and Read through the skills-move-together prior); without a recogniser-scored item Say is unplaced (start `none`, whatever Hear shows), is labelled "Self-rated", and does not count toward coverage or extend the run.
5. Yes/no: real-word answers update the posterior at once, but only after at least eight pseudowords do they count as clean items or toward a proof; the yes-bias (false-alarm rate) is a joint latent, not a plug-in; and a band proven by yes/no answers is judged at the upper bound of the learner's own false-alarm rate.
6. The likelihood is tempered (an exponent of 0.85, and a weight that falls by a fifth for each card, distractor or cue an item shares with earlier ones), and the range is shown only after the coverage gate passes (at least four clean items for the skill).

## Changes to the design this brings

- **Confidence word.** The 80% range always has at least 80% of the mass by construction, so the confidence word is derived from P(true level within one tenth of the middle), not from the range's own mass: high at 80% or more, medium 60 to 79%, low below.
- **Start.** The lower edge of the 80% range, never above the proven ceiling, and for Say `none` unless a recogniser scored it.
- **Twenty parts.** Classes are twentieths of the path (`PlacementLevels(deckCount, maxParts: 20)`), so a tenth is two classes.
- **Time.** The adversary showed that about 24 to 30 items are needed (four clean items per band per skill); the old gate of median 22 items is superseded. Do not loosen security to hit time.

## Revised validation gates (replace section (g)'s gates; these run in CI)

Personas, per skill, 300 runs per cell, with flat, amateur and advanced declarations, in Spanish and Hindi:

| Persona | Gate |
|---|---|
| TOP100+RULES (weak and strong solver) | start more than +1/10 too high in at most 3% of runs, more than +2/10 in at most 1% |
| COGNATE-ONLY | more than +1/10 too high in at most 2% |
| TESTWISE-ONLY and RANDOM | more than +1/10 too high in at most 2% |
| YES-SAYER (yes-rate 0.5 to 0.9) | p10 within T+1/10 in at least 97% |
| SELF-RATER (Say always "same") | Say start at most Hear start +1/10 in at least 98% (the model gives `none`, so this holds trivially; the gate guards the picker and UI) |
| ANAGRAM-SOLVER | per-item accuracy at most guess + 0.07 |
| MATCHER | per-pair accuracy at most 0.35 |
| FAMILY-REPLAY | lift at most 5 points |
| Honest: beginner, amateur, advanced, expert, native, script-literate-only, ear-only, cognate-advantaged, with and without audio and mic | experts and natives within 1/10 of the truth in at least 85% of runs |

Also: every adversary with an "advanced" or "expert" declaration meets the same gates; the 80% credible range contains the truth in 75 to 88% of runs; every skill in play gets at least four clean items in 100% of runs; Read and Write are fully placed in the no-audio and no-mic variant; every item class passes an admission audit (adversary accuracy at most the design guess plus 0.07, 0.32 for a four-option pick, else the item is excluded). **Time and length: median at most 28 items and 200 s, 95th percentile at most 40 items and 300 s.**

## Build progress

1. Joint posterior and readout (`lib/core/placement/joint_model.dart`, tests in `test/placement_joint_model_test.dart`): built. It holds the prior mix, noisy-AND update, yes-bias latent, calibration, tempering, proven ceiling, Say rule and the readout.
2. Replay harness and personas (`test/support/placement_v3_harness.dart`, fixture `test/fixtures/placement/adversary/leak_profile.json`, tests `test/placement_v3_gamers_test.dart`, `placement_v3_adversaries_test.dart`, `placement_v3_honest_es_test.dart`, `placement_v3_honest_hi_test.dart`, `placement_v3_pending_gates_test.dart`): built. The harness runs any picker over a simulated bank (a stand-in for the item registry) with persona answer models (the adversary's measured leak rates, honest learners, yes-sayer, self-rater, cheater control). A stand-in picker (`BaselinePicker`) proves one band per skill with four clean items, climbs while the proof ceiling holds the start down, and stops at the caps. Enforced now: TOP100+RULES (weak and strong, Spanish and Hindi, legacy and fixed bank), COGNATE-ONLY, TESTWISE-ONLY, RANDOM, YES-SAYER, SELF-RATER, no honest learner more than 2/10 above the truth, four clean items per skill in every run, Read and Write fully placed without audio or a mic, no card asked twice.
3. Item registry and generators with the fixes above (`lib/core/placement/item_registry.dart`, `item_generators.dart`, `item_audit.dart`, `item_bank.dart`, `cognate_score.dart`; tests `test/placement_item_registry_test.dart`; tool `tool/placement_audit.dart`; fixture `test/fixtures/placement/adversary/audit_profile.json`): built. See "The item registry and its audit" below. The ANAGRAM-SOLVER, MATCHER, FAMILY-REPLAY and admission-audit gates are enabled and enforced.
4. The picker (`lib/core/placement/v3_picker.dart`; tests `test/placement_v3_picker_test.dart`, `test/placement_v3_picker_bank_test.dart`): built. See "The picker" below. It replaces the stand-in `BaselinePicker` in the TOP100+RULES, COGNATE-ONLY, TESTWISE-ONLY, RANDOM, YES-SAYER, SELF-RATER and honest gates (the mutation controls keep the stand-in, as controls). The time and items gate is enabled and enforced. Three gates stay pending with measured reasons (below): experts and natives within 1/10, honest confidence, ear-only placed high on Hear.
4b. Restored formats and the cheap Write item (`lib/core/placement/item_solvers.dart`, `unit_model.dart`; generators in `item_generators.dart`; the audit fixture regenerated): built. See "Step 4b" below. F21 (gap spelling, a 6 s Write item), sentence picks (F5, F17) in both languages, word order (S2) in Spanish, matching (F9) with a wide margin. Cloze (F6) and gender (F6g) cannot pass and stay excluded, as do Hindi yes/no (F1, F14) and the cognate classes of sentence items. The experts and natives gate is still pending: the item cost is no longer what holds it back (see the pending table).
5. The isolating drill-down (`lib/core/placement/drill_down.dart`, integrated in `v3_picker.dart`; tests `test/placement_v3_drilldown_test.dart`): built. See "Step 5" below. The drill-down gate is enabled and enforced; ear-only placed high on Hear stays pending with new numbers.
6. The script gate (`lib/core/placement/script_gate.dart`; tests `test/placement_v3_script_test.dart`): built. See "Step 6" below. The script-gate pending gate is enabled and enforced.
7a. The run and the result screen (`lib/core/placement/v3_session.dart`, `v3_grading.dart`, `v3_result.dart`, `saved_v3_run.dart`; screens `lib/features/placement/v3_run_page.dart`, `v3_question_view.dart`, `v3_result_page.dart`; wiring in `find_level_flow.dart` and `lib/app/placement_run_setup.dart`; tests `test/placement_v3_session_test.dart`, `test/find_level_v3_test.dart`): built. See "Step 7a" below.
7b. The star, the migration and the retirement of V2 (`lib/features/stats/skill_star.dart`, `lib/core/placement/placement_check.dart`, `lib/app/settings.dart`; mockup `docs/mockups/progress-placement.html`; tests `test/progress_mastery_test.dart`, `test/placement_migration_test.dart`): built. See "Step 7b" below.
8a. The calibration profile (`lib/core/placement/placement_profile.dart`, `assets/placement_profiles.json`, `lib/app/placement_profiles.dart`; tests `test/placement_profile_test.dart`): built, with another valid word order for F8/F16 and the F4 decoy switch. See "Adapting placement to a language".
Next: PR 8b (the outcome log joined with real reviews, the bounded corrections, the opt-in export, `tool/placement_refit.dart` and the held-out gamer scaffolding).

**Carry-forward notes** (small non-blocking review notes, folded into the next PR and cleared as they are done): the five of step 5 were done in step 6; the two of step 6 (the script-run values apply only after a gate; "partly" is never modelled) were done in step 7a, as were the review blockers of #1090 (the question bank, the real-bank test) and, in the same PR, the script-deck credit, the offer to drop sound after two failures in a row, the stepper override to unit 0 and the truthful re-check toast, the live-region announcements, and `matchesAccepted` no longer dropping a word of the answer. Open:
- F3 (meaning to word) and F4 (word tiles) are admitted by the audit but never asked (calibrated guess 0.45): the decoy calibration for F4 is a profile switch, off by default (see "Adapting placement to a language"); F3 stays as it is until the re-fit.
- (7b done: see "Step 7b".)

## Step 7a

The run, as the app drives it (`V3Run`): the script gate first where the course has script letters (`ScriptGate`; a Latin course has none), then the joint model over the skills in play (`ScriptGate.skillsInPlay`) and the picker. Every answer is reported to the model and to `V3Picker.record` (`strictRecord` stays on). The state of a run is its events (`r` right or yes, `w` wrong or no, `d` "I don't know", `u` the question could not be shown, `m` the microphone was given up, `k` keep going), so a paused run is rebuilt by replaying them with the same seed (`SavedV3Run`, stored in the slot the V2 run used; each reader returns null for the other's JSON, so an old paused run is dropped, never misread).

- **Formats asked.** F2, F3, F13, F5, F17 (picks), F4 (word tiles), F8 and F16 (sentence tiles), F7 (typed), F21 (gap spelling), F18 (Say, scored by the recogniser, or rated by the learner when there is none: never evidence), F1 and F14 (yes/no, with "I don't know"), and the gate's F12 and F10. S2 and F9 stay unaskable.
- **Grading** (`v3_grading.dart`) brings typed, said and tiled answers to one spelling before comparing: the code points of one letter are one letter (a nukta letter as one code point or as a base and a nukta; the zero-width joiners dropped), case and the marks around a word are ignored, and accents are ignored as a review ignores them (a Latin accent, the Arabic vowel marks, a nukta left off). A vowel sign (matra) is never ignored: another matra is another word. A whole word typed in an F21 item is right too. "I don't know" is `AnswerOutcome.dontKnow`: a miss that hides no guess.
- **Budget.** Five minutes and 40 items in all, the gate's items and seconds included; at 22 items the run pauses once with "See my result" and "Keep going". The progress wave is the larger of the share of the time and of the items used.
- **Not shown, never a miss.** A question whose sound would not play is skipped (`V3Picker.skip`: no evidence, nothing for the drill-down to read, the card never asked again). "I can't speak now" (or two listens in a row that heard nothing) gives the microphone up (`V3Picker.giveUpMicrophone`): Say is no longer asked and what it already holds stays.
- **The result** (`V3Result`): per skill a start unit (the lower edge of the 80% range, never above the proven ceiling) with the range ("likely between unit 11 and unit 17"), a confidence word from the probability the true level is within a tenth of the middle (Sure, Fairly sure, Not sure yet; never a probability of "none", never "Verified"), or why it was not placed: Say without a recogniser is "self-rated, not placed", Hear without a voice and Say without a microphone are "not tested", and Read and Write while the script cannot be read yet "need the script first" with the reason and two ways on, "I do read it: check again" (a new run with no gate, the letters counted as known) and "Check the letters again" (a new run that asks the gate). The learner may change any placed start (a stepper over the path's units); the write is `AppState.writePlacementV3` (the readout's lower edge, the learner's changes, a skill left out writes nothing).
- **Gate runs only.** The values measured on the Devanagari cells in step 6 (`mixedBonus` 0.4, `standApartItems` 8, `sayRatingUntilItems` 24) apply only to a run that began with a gate (`PickerConfig.forRun`); a run with no gate keeps the defaults the other cells were measured with (0.3, 14, 40).
- **Known limit.** The script gate's "partly" level (some letters known) is never modelled: a learner who knows some letters is asked Read and Write as if they read the script, and one who knows three letters in five can be sent to "needs the script first". The result's re-check path is the answer to that, and the page says so ("You know some of the letters...").
- **Building the questions.** See "The question bank" below. The run takes the admitted items as a list, so the screen tests use a small hand-made bank.
- **The script credit.** A learner who passes the letter check ("all") is credited as reading the course's scripts (the `script` and `secondScript` assurances at the top class, which the write turns into placed script decks, as V2 did); one who fails it ("none") is recorded as new to them; a skipped check ("I do read it") or an in-between one ("partly") writes nothing about the script.
- **Sound that will not play.** A question whose sound fails is skipped. After two in a row the screen offers "Carry on without sound" (`V3Run.dropAudio`, event `a`): Hear and Say are no longer asked and the result says "not tested".
- **Re-check.** A re-check over unconfirmed credit that placed nothing keeps the old level and says so; a start changed to the very beginning is a placement (it takes back any credit above it).

### The question bank

**Before (step 7a).** The bank of Spanish took 41.5 s (AOT `dart compile exe`, two builds) on the development machine (one desktop core), Hindustani 38 s, and 54 s as JavaScript (`dart compile js -O2`, Node 22); with the 3 times slower phone assumed, about 2 minutes on a phone and 3 in a mobile browser. The time was in the generators, not the audit.

**Now (step 7c).** Measured the same way (JIT in the test VM; AOT was no faster before): the **first formats are ready in 0.8 s (Spanish) and 1.1 s (Hindustani)** and the **whole bank in 6.1 s and 7.1 s** (after the streams of #1092); as JavaScript the offline build, with every generator and the audit, takes **17.6 s** (the app's build skips the audit and the formats no screen shows, so it is shorter; it could not be timed in Node, whose event loop did not run the async build, and is estimated at about 11 s by the ratio of the native numbers). On the assumed 3 times slower phone: **the first question in about 2 to 3 s** from a cold start with no stored bank, and the whole bank in about 15 to 25 s in the background.

What changed, and what each saved (Spanish, JIT):
- **Algorithms, not caps.** The cognate scores recompiled their regular expressions and refolded both words at every call (now: each word's forms are made once and each pair compared once); `_byGlossLength` and `_matchAffinity` re-ranked inside the sort (now: ranked once, the same order, ties by position); the sentence picks recomputed per sentence what depends only on the option (the words, the held-out score, the gloss set); the pseudowords built a string key for every letter pattern of every try, 261,000 tries (now: integer keys). Word to meaning 4.3 s to 0.28 s, meaning to word 3.4 s to 0.16 s, pseudowords 3.6 s to 1.5 s, sentence picks 2.7 s to 1.3 s. These changes alone gave the same items (ties were already broken by position; Dart's sort is stable for lists this short, so an earlier note that the old sort was unstable was wrong).
- **Every generator has its own random stream (#1092).** The generators used to share one seeded stream (`GenContext.rng`) in the word to meaning, meaning to word, word tile, sentence tile, word order and gender generators, so an item depended on which generators ran before it and in what order; the app's build (fewer generators, the cheap ones first) therefore made different distractors, option orders, lures and decoys from the offline bank the audit ran on (this was the one Spanish F3 item that differed). Each generator now draws from `GenContext.stream(<name>)` (`w2m:F2`, `m2w`, `tiles:<decoys>`, `stiles:F8`, `S2`, `gender`, with the pseudowords, picks, cloze and matching streams as before), so the items of a generator are the same whichever others run. The real-bank test compares the app's bank with the offline bank item by item, every field. The audit was run on the app's own output (`ItemBank.auditRuntime`, `tool/placement_audit.dart`) and the leak-rate fixture regenerated. Before and after (Spanish): word to meaning 0.257 to 0.256 (upper 0.297 to 0.296), meaning to word 0.263 to 0.261, heard word 0.256 to 0.258, word tiles 0.048 to 0.068 (upper 0.094, bound 0.17), sentence tiles 0.012 to 0.016 and 0.010 to 0.023 heard, sentence picks 0.250 to 0.250; Hindustani within 0.005 except heard sentence tiles 0.014 to 0.024 and word tiles 0.020 to 0.021. No verdict changed; the moves are the sampling noise of other draws.
- **One generator for two formats.** The heard pseudowords (F14) and the heard sentence picks (F17) were the same draws as F1 and F5 (they share a seeded stream), so they are made once and relabelled (`RegItem.withFormat`): items identical to before.
- **Formats no screen shows are not made.** The picker never asks word order, matching, cloze or gender (no screen), and an item of a format without a screen is never offered to it (`kScreenFormats`), which also closes a way for an audit change to crash the run.
- **No audit at runtime for a language that has been audited.** `admission.dart` holds the audit's verdict on the app's own output (the excluded classes, only of formats the app makes, and the decoys of the word tiles) for Spanish and Hindustani, keyed by the decks it was made on (`admissionKey`: every card's id, word and meaning). The real-bank test fails when it differs from the real audit or the key. A language with no entry, or whose decks are not the audited ones (a deck update), is audited when its bank is made (about 3 s more) and its run begins on the whole bank. Adding a language, or changing its decks, means running `tool/placement_audit.dart` and storing the printed entry. Stored banks carry the schema of the generators (`kItemSchema` is 2 now): older ones are rebuilt.
- **Progressive.** The generators run the cheap, most asked first (word to meaning, heard word to meaning, typed, said, sentence tiles), and as soon as they are done the clean items of those formats are handed to the app (`ItemBank.starterOf`; 5,310 items for Spanish): a run begins on them and takes the whole bank once it is ready (`V3Run.extendItems`, the event `x`). The first formats cover Read, Hear, Write and Say. They are offered only under the stored verdict and only the classes it admits, so the starter is the same list however it is cut (from what the generators made or from the admitted bank): a paused run waits for the whole bank and rebuilds exactly the pool it began on (`starterOf`), and a run saved on the whole bank is never replayed on the starter pool.
- **Kept**, as before: the stored copy per language, deck set and schema, in the background from the moment Find my level opens.

**Limits.** A run that begins on the first formats only asks from them until the whole bank arrives (the gap items and sentence picks come with it); the per-cell time gate was measured on the whole bank. A language without a stored verdict gets no starter: it waits for the audited bank.

The real build is tested by `test/placement_bank_test.dart` (the stored form, the kept copy, invalidation by deck set, a damaged copy, storage that fails, a failed or cancelled build, the isolate path over a fixture too small to give items, the steps) and `test/find_level_v3_test.dart` (the preparing screen).

**What is asked.** `test/placement_v3_real_bank_test.dart` runs the V3 run over the real Spanish and Hindustani banks (24 runs each: audio on and off, four levels, three seeds) and fails if a skill in play has no askable admitted format, if a run ends short of coverage, if fewer than three runs in four end complete, or if an admitted format is never asked and is not on its list. The list, with the reasons: S2 and F9 (unaskable by design); **F3 and F4: the seed calibration gives them a guess of 0.45 (`F3:clean`, `F4:clean`), above the clean limit 0.35, so they never count for coverage or proof and the picker never chooses them** (the 0.30 of `F4decoys:clean` is not used by `PickerCandidate.fromItem`; to be settled by the re-fit); F1 and F14 (asked only in the optional yes/no block, off); and, for Hindustani only, F7, F5 and F17 (the 6 s gap items and the tiles place Write and Read at less cost). The sentence tiles F8 and F16 are asked. F8 was not chosen on the small hand-made bank of the screen tests (not investigated further: its few items may not meet the picker's rules); the real banks ask it.

## Step 7b

- **The star.** Placed pairs are a hatched layer under the solid fill (`SkillScore.placedFill`: known + placed over the B1 total), with a legend "Placed N%" while anything is placed, one screen-reader label that adds "N% with placed" per skill and says what the hatch is, and no animation under reduced motion (the star was already drawn at once). The outline stays earned only; real reviews override placement as before (a placed pair answered is earned from then on). The colours (`#8A5A00` light, `#E0A458` dark) are at least 5:1 on the card; the mockup and its self-check are `docs/mockups/progress-placement.html` and `.md`.
- **Migration.** `kPlacementModel` is 3 (V3). Credit stamped with the model before V3 (2, the 95% stop and the P(none) readout) and the unstamped credit of 0.9.0 and 0.9.1 are unconfirmed (`isConfirmedModel`): the Languages sheet offers "Check again" (about three minutes, once: Keep the old level confirms it), and a real review overrides any placement. The older placement test's credit (model 1) is never flagged. An earlier version's Verified mark reads "Earlier check (not verified)" with no tick and is cleared for any skill a new run places. Each placed skill's `{start, low, high, label}` is kept in the settings (`skill_ranges`, read tolerantly: a malformed entry is skipped, a map without the key has none) and shown on the sheet as "Read: unit 14, likely 11 to 17 · Fairly sure". The paused run's version (`v: 3`) and its tolerant reading were done in 7a.
- **Retirement.** Removed: the V2 run controller (`placement_run.dart`) and session (`placement_session.dart`), the question builder, bank, picker and replay (`question_builder.dart`, `question_bank.dart`, `item_picker.dart`, `replay.dart`, `generated_question.dart`, `question_outcome.dart`, `guessability.dart`), the V2 screens (run page, question view, summary, comparison; the labels and `FindLevelRecheck` are in `find_level_labels.dart`), `tool/placement_bank.dart` and `tool/placement_replay.dart`, the V2 fixtures `test/fixtures/placement/banks`, and the tests of all of these. Kept: the levels and the update (`assurance_model.dart`), the declaration prior, `placement_data.dart`, `placement_check.dart`, `saved_run.dart`'s `placementDeckSetKey`, and `SkillAssurance` (now in `assurance_readout.dart`), which the write reads. The write's tests use a finished V3 result (`test/support/v3_write.dart`).

## The picker

`V3Picker` (pure Dart, deterministic for a seeded generator) chooses the next item from the candidates of the admitted bank (`PickerCandidate.fromBank`; the audit decides what is admitted, the picker never asks anything else).

- **Rotation.** The skill with the fewest touches goes next. The skills in play are Read, Hear and Write, and Say only when a recogniser scores it. Hear and Say items are asked only when the device can play audio and record; Hear and Say are never the only evidence for another skill.
- **Locate, prove, climb.** Each skill is located by two items (the first at the 35th percentile band of the posterior, then a gallop up from a right answer, never above band 9, or a halving from a wrong one); an item that also locates another skill counts for it. Then a band is proven by four clean items (4 of 4 or 5 of 6). A band with two wrong answers (or one while the posterior already sits lower) is left for the 40th percentile band. A proven band is climbed from while the posterior's 12th percentile lies above the proven ceiling (`PickerConfig.climbQuantile`, `climbTolerance`). A skill at the start of the path (four clean items, 90% of the posterior on the first two classes) stops at once. When the joint prior still holds a proven skill down to the start, more clean items of the proven band are asked (an ear-only learner).
- **Item choice.** Among the admitted formats, the candidates near the band that have the most mutual information per second: (information + 0.2 + 0.3 for each other skill the item also proves, `PickerConfig.mixedBonus`) / seconds. An item whose other skill the learner probably fails (under 40% known at that deck) is not chosen for this skill. No more than two items of one format in a row. A card or lemma family is never asked twice (the bank's conflict keys).
- **Coverage floor and end reason.** A skill is finished only when it has no askable candidate at all. When the rules leave nothing to ask, the "another skill probably fails" rule and then the two-in-a-row rule are relaxed and the bank is searched in full, and an item that does not fit the time left is replaced by a cheaper one that does. The picker says why a run ended (`endReason`: complete, itemCap, timeCap, exhausted, or coverageShort with `shortSkills` and the underlying `endCause`); a run that ends before every tested skill has four clean items is never silent. Tested on the real Spanish and Hindi banks with one or two admitted formats, at tenths 0, 2, 5, 8 and 10. The yes/no block (14 items of one format, opened first) is the one exception to the two-in-a-row rule.
- **Say.** Without a recogniser Say is rated by the learner (one item, a self-rated candidate that is not clean and is never evidence); the rating is left out when the run is already past 180 s or has 24 items (it counts as an item against the median gate of 28), so it never lengthens a long run; a self-rated Say is therefore missing from most long runs, and the tests that want it set `sayRatingUntilSeconds` high.
- **Caps and the soft stop.** 40 items, 300 s (an item that would end after 300 s is not asked), 14 touches a skill. `softStop` becomes true at 22 items: the UI offers to stop there and lets the learner keep going to the caps.
- **Yes/no block.** When enabled, Read opens with the eight pseudowords and six real words.

Measured over the simulated banks (Spanish and Hindi, three declarations, three devices, 100 runs a cell): the time gate is enforced per cell (persona, device and declaration), the worst cell median is 190 s and 27 items (step 5, with the drill-down). The 95th percentile caps (40 items, 300 s) are true by construction, since the picker stops at them and never asks an item that would end after 300 s, so the medians are the real gates. No honest learner is placed more than 2/10 above the truth (at most 3%). The gamer and adversary gates also run from two further sets of seeds (`placement_v3_gamers_b_test.dart`, `_c_test.dart`, and the same for the adversaries; 3 times the runs in all, in shards of their own) so the re-tuned picker is judged on more than one draw. The honest tests are split by language (`placement_v3_honest_es_test.dart`, `placement_v3_honest_hi_test.dart`, suite in `test/support/placement_v3_honest_suite.dart`); their CI weights are in `test/shard_weights.json`.

### What the admitted formats could not do, and step 4b

With only the formats admitted at step 4 the experts and natives gate (within 1/10 in 85%) and the time gate pulled against each other: a top-band proof costs four clean items per skill, and Write had no cheap evidence (typing 12 s with a slip of 0.15, tiles 15 s, mixed items 15 s). Step 4b added the cheap Write item F21 (below). A Write proof stage now costs about 24 s instead of 50 to 60, and the per-cell medians fell (worst 178 s). Experts and natives are within 1/10 in 68 to 70% of runs under a flat declaration, 84% under an advanced one and 18 to 20% under an amateur one (Spanish; Hindi within 2 points). A stop rule that climbs further reaches 72 to 80% flat and about 70% under an amateur declaration but takes 225 to 230 s in the amateur-declared expert cell, over the 200 s gate. So the item cost is no longer the blocker: an expert who declared "amateur" starts with a prior that holds the lower edge of the posterior down, and only more proof stages move it. The prior and the declaration weight are re-fitted at step 8; the gate stays pending until then. No honest learner is placed more than 2/10 above the truth.

## Pending gates

These gates need a later build step and are listed, with the file that will signal their prerequisite, in `test/placement_v3_pending_gates_test.dart`. When the file lands, that test fails until the gate is enabled and its entry deleted.

| Id | Gate | Prerequisite file (any depth under `lib/core/placement/`) | Why it waits |
|---|---|---|---|
| `experts-natives-within-a-tenth` | Experts and natives within 1/10 in at least 85% | `refit`, or a fitted constant of the model moved (the declaration weight, the prior mix, the temper) | With the cheap Write item (step 4b) they are placed safely but low: 68 to 70% flat, 84% advanced, 18 to 20% under an amateur declaration; the declaration prior holds the lower edge down, so the prior and the declaration weight are re-fitted at step 8 |
| `honest-confidence` | 80% range holds the truth in 75 to 88% | `refit`, or a fitted constant moved | The real picker gives about 70 to 100% (too wide for most, too narrow for ear-only and natives under an amateur declaration); re-fit at step 8 |
| `ear-only-placed-high-on-hear` | Ear-only placed high on Hear | `refit`, or a fitted constant moved | The drill-down (step 5) lifted Hear from 0-8% to 55-64% within 2/10; the joint prior still holds its lower edge down until 13 or more Hear items are right, and more under an amateur declaration; re-fit at step 8 |

### Open for step 8: a held-out gamer

The adversary's leak rates are measured by one gamer on one bank, and the generators' fixes were calibrated against the same gamer, so the "fixed" bank's numbers are circular. Step 8 needs a held-out gamer: a different bank split; leaks correlated within a card family; leaks that depend on how many items the gamer has already seen (exposure); other languages; and per-run uncertainty in each leak rate. Until then the harness shows the model survives a gamer up to 0.07 better than measured (and fails at 0.45 better), not that the measured rates are the worst case.

### What the gates check, and the controls

The adversary gates are per skill (Read, Hear and Write each must pass), in every declaration and device variant. They have controls that show they can fail (Spanish): V3 as it was before the review (no calibration, no proof ceiling, a picker that asks every format and lets cognates in) is over by 1/10 in 24% of runs; calibration and the ceiling are each load-bearing in the setting where the other layers are removed; a gamer 0.45 better than measured fails in Spanish and Hindi. The model defends in layers, so removing one protection while the others stand still passes (measured: 0 to 3%).

## Step 5: the isolating drill-down

`DrillDown` (pure Dart) decides when a drill-down starts, whom it asks and when it stops; `V3Picker` chooses the item (single-skill items of the admitted formats only, the nearest deck to the level of the item that was missed, the most information per second, never a card twice) and reads every answer through `record(candidate, outcome)`, which the caller must call after each item it observes (the harness does it through `RunState.lastOutcome`). A caller that forgets is an error in a debug run (`PickerConfig.strictRecord`); otherwise the picker abandons the drill-down at the next item (`DrillEnd.unrecorded`, no other starts) and the run goes on with the rotation. Read and Write are isolated with no audio at all (F2, F3, F5; F21, F4, F7); Hear by F13 and F17 (F16 is Hear and Write, so it is not isolating); Say only with a recogniser (F18).

- **Triggers**, each at most once per skill and band, at most 2 drill-downs a run and none after 150 s: a wrong answer on an item of two skills or more (the skills whose chance of having failed the level is now 0.25 or more are implicated); a right answer a skill had under 0.2 of knowing (a likely lucky guess); a skill about to be finished whose 80% interval is wider than 8 classes (the plan says 6; 8 keeps the amateur-declared cells inside the time gate) or whose evidence contradicts itself (a band with a right and a wrong clean answer).
- **The opening.** Two mixed items (Read and Write tiles F8, Hear and Write dictation F16) open the run at the middle of the posterior, one per pair, so that the drill-down has a miss to read; the picker's own bonus for mixed items stays 0.3.
- **Asking.** Each implicated skill gets one isolating item, the likeliest failure first; then the next goes to the skill the answers settled the least; no skill gets more than 2 items unless it is the only one left. For several skills the decision reads only the isolating answers (a log-odds per skill, an item's slip and guess), not the joint posterior, because the joint ties the skills together (a learner is usually at one level in every skill), which is exactly what the isolating items are asked to see past; the joint posterior still takes every answer in, so the placement uses them.
- **Stopping.** The failing skill is named when it has 0.8 or more, no other implicated skill is over 0.5, and it was checked twice (a slip is forgiven); the case ends as "all failed" when every implicated skill has 0.9 or more after three isolating items; or after 4 isolating items. The verdict of a case is the named skill, else the likeliest (0.4 or more and 0.1 ahead), else none.
- **Stand-apart skills.** The picker also asks more clean items (up to 8 in a proven band, `PickerConfig.standApartItems`) of a proven band while the joint prior still holds the lower edge more than 6 classes under it, and climbs when the middle of the posterior is two tenths above the proven band: a skill that stands apart (an ear-only learner) must not be held down by the others.

**Gate (enforced, Spanish and Hindi, 100 runs a cell).** A learner with exactly one failing skill (the weak one at 2 tenths, the other two at 7 or 9): a drill-down starts in at least 90 of 100 runs (a mixed item opens each run), and in at least 90% of the runs in which it started, every drill-down names the weak skill when it was implicated within 4 isolating items, and clears all of them (no skill named) when it was not (a slip on a mixed item). It holds in all 12 cells (Read, Hear, Write weak by 2 strengths by 2 languages).

**Time and the other gates.** With the opening and the drill-down every cell median is at most 27 items and 190 s (the gate is 28 and 200); the first tuning (3 drill-downs, two mixed items, 6-class intervals) was over in the amateur-declared cells (29 items, 202 s) and was re-tuned: 2 drill-downs a run, wide intervals at 8 classes, none after 150 s, and the "all failed" stop. No honest learner is over-placed by more than 2/10 (0.000 in every honest cell). The security gates keep their bounds.

**Notes on the drill-down's decisions.** (a) `record()` reads a `dontKnow` on an isolating item as an ordinary wrong answer, with the item's guess: it understates the evidence (a guess that hid nothing is counted as a wrong answer that may hide one), which is safe. (b) The verdict of a case that ends on budget falls back to the likeliest skill at 0.4 or more and 0.1 ahead. Measured over the 12 gate cells (1,166 cases): cases that name a skill by the rules are right in 95.4% (922 of 966); the fallback names a skill in 15.6% of cases (182) and is right in 87% (158); that is the lenient part and it adds more right verdicts than wrong ones, so it stays. (c) Two lucky right answers on isolating items clear a skill in the case's own log-odds with a chance of about 1% for F21 (guess 0.10) and 6% for F2 (guess 0.25) per pair, and about 11% per skill over a case's two to four items in the worst mix; the 0.9 all-failed rule and the two-check rule keep a cleared skill from being named.

**Ear-only (still pending).** Hear is now placed within 2/10 below the truth in 55 to 64% of runs (it was 0 to 8% before the drill-down), within 1/10 in about 43% (flat declaration), 4% (amateur) and 64% (advanced); Read and Write stay at the start. What is left is the prior (see the pending table); it needs the step 8 re-fit.

## Step 6: the script gate

`ScriptGate` (pure Dart) is the check of two to five letter items (three on average) at the start of a run for a language in a non-Latin script; the harness runs it before the picker (`runOnce(scriptLetters: ...)`), and the caller builds the joint from what it decides (`ScriptGateResult.skillsInPlay`).

- **Items.** F12 (a letter, pick its romanisation; no audio needed) and F10 (a heard romanisation, pick its letter; only with audio, as the third item), from the script's letter decks: three plain letters from the early, middle and late third of the deck, then a joined form (a vowel sign or a conjunct), then two spare letters. The wrong options have the length of the right one (a letter's romanisation, or a glyph's code points), distinct readings after folding marks: no cue of length.
- **Decision.** A sequential test of "reads the script" (right with 0.95) against "cannot" (a guess, 0.25): stop after two items when the log-likelihood ratio is 3.5 either way, else after five; below even odds is `none`, from nine in ten `all`, in between (only when the items ran out) `partly`.
- **What it does.** `none`: Read and Write are not tested (placed at `none`, "needs the script first") and the other skills are tested on their own, so a learner who hears and speaks the language but cannot read it is not placed as knowing no language (the joint prior would otherwise hold Hear down: with the gate, Hear is placed within 2/10 below the truth in 74 to 95% of runs, without it 38 to 71%). With no audio nothing else is left to test, so Read and Write stay. `partly` and `all`: Read and Write are tested as usual; a learner who knows the script and no words gets Read and Write at `none`, which starts the vocabulary at A1 (tested: 97% or more of Read and Write starts are at the start). A Latin-script language has no gate (`ScriptGate.latin()`: nothing asked, `lettersKnown` true; Latin known from English counts as Learn for Read and Write, the 0.9.2 rule).
- **Validation.** F10 and F12 are not in the picker's bank and not under the item admission audit: a class of 75 letters cannot show a four-option pick within 0.32 by the Wilson bound. The gate is judged by what it decides (Devanagari, 600 runs each): a learner who cannot read is found in at least 95% (97.5% measured), one who can is read as `all` in at least 95% (97.9%) and as able to read in at least 97%, and a guesser is let through in at most 5% (2.5%); a learner with some letters is told apart less well (about three in five are read as unable): a known limit, to be fitted on real learners at the last step. A gamer is assumed to pass the gate (the security tests run Hindustani with the script known, the worst case).
- **The declaration.** The answer to "do you read this script?" moves where the test starts by 1 in log-odds (about three to one), never decides: a learner who says yes and reads is through in two items (at least 80% of runs), one who says no and cannot is found in 97% of runs; a guesser who says yes passes in at most one run in ten (6 to 9%, since two lucky answers then suffice). The harness has each persona answer truthfully and a gamer say yes.
- **Time.** The gate costs 2 to 3.3 items and about 10 to 13 s in a non-Latin run. To keep the per-cell medians at 28 items and 200 s the rating of Say is skipped at 24 items, the stand-apart extension is 8 clean items (it was 14), and a run that began with the gate uses a mixed-item bonus of 0.4 (`kScriptRunMixedBonus`; mixed items save items at a cost in seconds the cells can spare). Measured over every honest cell and device (Hindustani with the gate): worst median 28 items and 198 s (amateur under an advanced declaration, ear-only under an amateur or advanced one); the no-mic ear-only cell had 29 at a stand-apart extension of 12, which CI caught. **The headroom is thin** (198 s against 200 s): PR 7 and PR 8 must re-measure after every change to the picker, the formats or the screens, and a change that adds an item to a non-Latin run has to take one out.

## The item registry and its audit (step 3)

Everything is generated from a language's decks (`PlacementLanguageData`), with no per-language content: the cognate rules are a generic sound fold plus a small table of suffix correspondences per language (`cognateSuffixRules`), and a Hindi word is compared by its reading (its transliteration), which is how loanwords such as `skūl` are found. About 36% of the Spanish and 13% of the Hindi word cards are near-cognates (score 0.58); a word from 0.45 is also kept out of word-level formats, because a partial cognate still leaks to a similarity cue.

**The fixes, as built.** Word picks (F2, F13, F3) have two or three distractors of the same part of speech, article and length, near the item on the path, and chosen to look as much (or as little) like the prompt as the right answer does and to be about as long; none is one of the course's first 100 words (a gamer that knows them could eliminate it); a look-alike lure is in only 15% of the items, because an option that resembles the prompt is always wrong and a solver that drops it would otherwise gain. Sentence picks (F5, F17) take other sentences' translations as the wrong options, balanced against the solvers (step 4b). Word tiles (F4) carry decoy units (two, chosen by the audit; a syllable unit in an Indic script). Tile sentences (F8, F16) carry two decoy words. The word-order pair (S2) keeps its end marks fixed and swaps two words up to three places apart, keeping the swaps the context cues rate in the direction the class is short of (step 4b). Cloze (F6) has no English hint; its options share the blank's ending, are about as long, and are the most plausible in the context. Gender items (`F6g`, Spanish only) are half exceptions to the ending's rule and half rule-followers. Yes/no pseudowords imitate a real word each: its length, how typical its letter patterns are (three measures, each without the word it came from) and how far the nearest other word is. A matching screen (F9) has four words of one part of speech, near each other. A card is never asked twice in a run (`ItemBank.available`: no item may share a card or a lemma with one already asked, and a card shown as an option counts as seen; drill-down included).

**The admission audit.** A class (a format and its cognate class) is attacked by solvers that never see the key, every one in both orientations (the option it scores highest, and lowest), and is admitted only if the **upper 95% confidence bound** of its best solver (Wilson for accuracies, Hanley and McNeil for the yes/no AUC) is within the guess plus 0.07 (0.32 for a four-option pick). A class with too few items cannot show that and is excluded; a class that was not attacked is not admitted. The solvers: longest and shortest option; similarity to the prompt, and dropping the most similar option; a gamer that knows the first 100 words (its own cards are left out of the measure); for a cloze, word-pair and ending-pair models of the course's sentences without the item's own sentence; an anagram solver (letter patterns of the whole course without the target; a search cut short counts as solved); a beam-search order solver for sentence tiles (word and ending pairs); spelling rules; a matcher and an anti-matcher; five pseudoword detectors (letter patterns, unit pairs, edges, nearest-word distance, length) each leaving the word out; the ending rule and its opposite for gender; chance. Result on the real decks:

| Class | Spanish: best solver, accuracy (upper bound) | Hindi | Bound | Admitted |
|---|---|---|---|---|
| F2 written word to meaning | drop-most-similar 0.257 (0.297) | length 0.265 (0.305) | 0.32 | both |
| F13 heard word to meaning | 0.256 (0.296) | 0.262 (0.302) | 0.32 | both |
| F3 meaning to written word | 0.263 (0.303) | 0.260 (0.300) | 0.32 | both |
| F4 word tiles (2 decoys) | 0.066 (0.091) | 0.025 (0.043) | 0.17 | both |
| F7, F18 typed or said | 0.008 (0.021) | 0.008 (0.021) | 0.10 | both |
| F8, F16 tile sentences | 0.021, 0.007 (0.037, 0.019) | 0.021, 0.012 (0.048, 0.035) | 0.12 | both |
| F9 matching, per pair (step 4b: the six screens drawn, the worst for the matcher used) | 0.170 (0.198) | 0.209 (0.235) | 0.35 | both |
| F1, F14 yes/no, AUC | 0.568 (0.596), 849 words | 0.602 (0.637), 326 words | 0.60 | Spanish only |
| F5, F17 sentence picks (step 4b: other sentences' translations) | chance 0.25 (0.301), 216 items | chance 0.25 (0.319), 125 items | 0.32 | both (clean class) |
| F6 cloze (step 4b: exact-tie distractors) | 5 items | none | 0.32 | neither: too few sentences have three words every cue rates alike |
| F6g gender | 0.50 (0.681), 18 items | none (no articles) | 0.57 | neither |
| S2 word order (step 4b: balanced swaps) | chance 0.50 (0.559), 194 items | chance 0.50 (0.582), 98 items | 0.57 | Spanish (clean class) |
| F21 gap spelling (step 4b) | edges-lowest 0.019 (0.035) | 0.002 (0.016) | 0.17 | both |
| any cognate-class sentence item | 13 to 87 items | 19 to 38 items | | only the tile sentences |

**What is admitted, and the effect on the item mix.** Per skill, with no audio: Read has F2, F3, F5, F9 and F8 (Spanish also S2 and F1), Write has F4, F7, F21 and F8, so both are placeable without audio or a microphone, as the design requires. With audio, Hear has F13, F17 and F16 (and F14 in Spanish); Say has F18 (with a recogniser). Sentence meaning is measured by F5 and F17 (and F8 and F16 as tile assembly), word order by S2 (Spanish), F8 and F16. What stays missing is a grammar item that tests a rule by choice (F6 cloze, F6g gender, see step 4b). F10 to F12 (script decks), F15 (minimal pairs), F19 and F20 (screens of step 6) are not generated here.

**What the audit does not show.** The solvers are mine, and three generators choose against solvers of the same kind (the cloze distractors and the word-order swap by word pairs, the pseudowords and matching by typicality), so those classes are measured partly against the cue they were built to defeat. Controls in the tests: word tiles without decoys fail in Spanish (0.333); a pick whose answer is the longest, or always the shortest, option fails (the second is caught only by the inverted orientation); a look-alike lure that is always wrong is caught by the drop-the-most-similar solver; twenty chance-level items do not pass on their confidence bound; a run that ignores the never-twice rule gives a replay gamer a lift above 0.4, and one that keeps it gives none.

**Harness.** The "fixed bank" leak rates of `leak_profile.json` were an assumption (about 0.30 for a clean pick); the harness now uses what the audit measured for each format that passes (`audit_profile.json`, floored at the design guess): about 0.26 for picks, 0.25 for sentence picks, 0.07 for word tiles, 0.02 for tile sentences and 0.01 for typing and gap spelling; the formats that do not pass (F6) keep the old figure. The legacy tables are the adversary's own measurements and are untouched. Regenerate the fixture with `dart run tool/placement_audit.dart` when the decks change a lot; a test compares it with a fresh audit (the same classes pass and are excluded, accuracy within 0.02).

## Step 4b: the cheap Write item and the restored formats

Every new class passes the same confidence-aware audit (the UPPER bound of the best solver within the guess plus 0.07; no bound was loosened). The solver helpers are shared: `item_solvers.dart` holds the scoring (context word pairs and ending pairs and triples, similarity, known words, centrality, rank patterns) that both the audit and the generators use, and `unit_model.dart` the letter-pattern model. A generator chooses distractors against the audit's own solvers, so those classes are measured partly against the cue they were built to defeat. Two held-out families were therefore added to the audit for F21, S2 and the sentence picks: a character n-gram model of the course's text (each item's own text left out) and a logistic classifier on item features, fitted on one half of a class and tested on the other and the reverse. **First measured as pure held-out solvers, the character models failed three classes** (F21 Spanish 0.161, upper 0.199 against 0.17; S2 0.613 and 0.655 against 0.57; F5 and F17 Hindi 0.279, upper 0.348 against 0.32), so they became cues of the generators and are no longer held out; what stays held out of every generator is the classifier. Hindi S2 then no longer has enough items to show chance and is excluded. The solvers are listed below so the next adversary can add others.

- **F21 gap spelling (new, Write, 6 s, slip 0.08, guess 0.10).** The English meaning and the word with one unit left out (a letter, or a syllable unit in an Indic script); the learner types the unit. The gap is the position where none of the solvers below picks the right unit, and, among those, the one whose right unit stands nearest the middle of every cue's ranking: choosing the gap that the cues miss by the widest margin would put the right unit at the bottom of the rankings (a rare unit: ñ, k, x, or a rare Indic syllable unit), which a solver that types the rarest unit beats. Solvers (every one in every orientation): for each of five cues (letter patterns, unit triples, unit pairs, edges, unit frequency) the highest scoring fill, the lowest, and the second, third and fourth highest (a solver that has learned that the top pick is never right); spelling rules on the whole word. Held out (a family not used by the first five cues, in the audit): a character 4-gram model of the course's words and sentence words without the target word (highest, lowest, ranks 2 to 4; used as a cue in generation, so it is no longer held out), and a logistic classifier on the fills' cue scores fitted on one half of the items and tested on the other (and the reverse). Admitted: Spanish 353 audited items (371 generated), the best solver 0.019 (an edges tie among 40 fills, upper 0.035); Hindi 233 (238 generated), 0.002 (upper 0.016); against a bound of 0.17. Every tenth of the path has at least 10 items. Control in the tests: a gap that is always the only rare letter is caught by the unit-frequency "lowest" solver (accuracy 1.0) that the old, highest-only audit could not see.
- **F5, F17 sentence picks (restored).** The wrong options are the translations of other sentences of the course, because a one-word contrast of the right translation made the right option the centre of the four (a "centre of the options" solver is in the audit). They are chosen so that no cue separates the right one: the first words' English is in no option more than another, and, in similarity to the prompt, in length and in how typical of the course's English the option is (a character n-gram model, each option held out), a quarter of the items have the right option highest and a quarter lowest, so a solver that takes the highest, the lowest or drops the most similar gets exactly a quarter. Held out in the audit: the English character model in both orientations (also a cue in generation) and a logistic classifier on the options' features (length, similarity, centrality, model score, known words) fitted on one half and tested on the other. Admitted (clean class): Spanish 216 items, 0.25 (upper 0.301); Hindi 125 items, 0.25 (upper 0.319).
- **S2 word order (restored in Spanish only).** The right order and the same sentence with two words (up to three places apart) swapped, end marks fixed. The pair is kept only if the course's word pairs and ending pairs and triples, and the character model of the course's sentences (the right sentence held out), rate the two orders in the direction the class is short of, so each cue favours the right order exactly as often as the wrong one. Held out: a logistic classifier on the four cues' scores (0.39 cross-fitted). Admitted (clean class): Spanish 194 items (upper 0.559). **Hindi is excluded:** with the character model balanced as well only 98 sentences keep a pair, and a two-option class needs about 138 items to show 0.5 within the 0.57 bound.
- **F9 matching.** Six screens are drawn and the one the audit's matcher does worst on is used: Spanish 0.170 (upper 0.198), Hindi 0.209 (upper 0.235) against 0.35, where it was 0.306 (0.340) before. The generators now draw from their own seeded streams, so one format's items no longer depend on what another consumed.
- **F6 cloze (still excluded).** Distractors must be rated exactly like the right word by every context cue (word pairs, ending pairs and triples), by length and by the first-words cue; only 5 Spanish sentences have three such words (none in Hindi), and 5 items cannot show anything (the upper bound of chance is 0.61). A cloze that a context model cannot rank needs a larger corpus of sentences.
- **F6g gender (still excluded).** 18 items in Spanish (the course has that few exception nouns); the ending rule and its opposite give 0.5 (upper 0.68 against 0.57). Needs more nouns with articles.
- **Hindi F1, F14 (still excluded).** The pseudowords' letter patterns are detected with an AUC of 0.60 (upper 0.637 against 0.60) in Hindi, 849 Spanish words pass (0.568, upper 0.596). Tightening the match worsened both.
- **Cognate-class sentence items** (F5, F17, S2: 12 to 43 items) are too few to be admitted; only the tile sentences have enough.
- **Grammar.** Agreement and suffix-form probes for languages with articles or agreement cannot be built so that a rules gamer cannot solve them: the right form of a regular word IS the rule. What is measured instead: tile assembly of whole sentences (F8, F16: word order and the form of every word, 0.01 to 0.02), word order (S2), typed words and units (F7, F21), form from meaning (F3). Exceptions (gender) need more data than the courses hold (F6g).

**Before the UI or the picker asks F21 or S2.** F21 needs a grading rule: Unicode normalisation (NFC against NFD for a nukta or matra cluster typed on different keyboards), accents (an accented letter typed without its accent), case, and alternate spellings of the word (`accepted` holds the word's variants; a unit that completes a valid variant must count). S2 needs a grammaticality check for languages with free word order (the swapped sentence may be correct), so the right order is not the only one. Until both are built the picker cannot ask S2 or F9: `kUnaskableFormats` in `v3_picker.dart` makes the pool refuse a candidate of those formats (an assert in a debug run), `PickerCandidate.fromBank` leaves them out and `_available` rejects them; F21 stays askable by the picker only in the harness, and its grading is part of step 6, the screens.

The picker's format set is now F2, F3, F13, F5, F17, F4, F7, F21, F8, F16, F18, F1; S2 and F9 are admitted but the picker does not ask them (a two-option S2 has a guess of 0.5, over the 0.32 a clean item may have; F9 is a 15 s Read item the drill-down will use).

## Owner decisions for Progress (2026-11-07)

Accepted as the recommended defaults: a hatched placed layer under the solid fill; the outline earned-only; the level shown with a "Placed" mark before any earned review; a lapsed placed pair drops out of the placed layer into taught-not-known; the Words tile reads "N known of T taught (+M placed)"; unconfirmed 0.9.0 and 0.9.1 credit is treated like other placed credit on Progress and marked only on the Languages sheet; Progress shows only the lower-edge point; whether credit was set in stone or reviewed as usual does not matter for what Progress shows. The rules are in [Progress-and-Stats](Progress-and-Stats). The progress core is built (step A); the level and the placed mark (B) and the drawing (with step 7) follow.

The level PR (B) is built: `assurancesFromJoint` (lib/core/placement/placed_outcome.dart) carries a V3 readout to the placement write, `AppState.writePlacementJoint` writes it (each scored skill by its lower edge, never above the proven ceiling; Say self-rated and any skill not tested write nothing and never pull the placed decks down), the Level tile carries a "Placed" mark until a unit of its milestone has an earned review (`levelPlaced`), and the Words and Rules tiles read "+M placed". A script deck's credit is a placed script pair (placement placed the script); a word credit has no script and feeds none. `AppState.record` never writes a real answer in the shape of credit (`realElapsed`: a real grade 5 with no time and no answer is recorded with one whole millisecond, because every store keeps elapsed time in whole milliseconds, so credit stays 0 ms and a real flip stays 1 ms through the database, the JSONL backup and the replay snapshot). Rows stored before this, when a self-graded flip was stored as 0 ms, cannot be told from credit and are not reinterpreted. A skill proven below A1 (placed class `none`, placed level -1) writes no credit of its own and makes the course's shared placed decks start from the first deck, as V2 did, so that no skill is denied a lesson it still needs; the other skills are still credited each by its own level.


## Adapting placement to a language

Find my level V3 has constants that the gates could not fix without real learners: how much the learner's declaration counts, how much the skills move together, how hard the model tempers its evidence, how guessable and slippery each format is, how long it takes, and how the proof stage climbs. They are not in the code of the run: a run reads them from a **calibration profile** by language and level band, with the built-in default being exactly the constants the gates were measured with.

**The file.** `assets/placement_profiles.json` (`schema` 1):

```json
{
  "schema": 1,
  "killSwitch": false,
  "default": { "version": 1 },
  "languages": {
    "hi": { "version": 2, "temper": 0.8, "guessScale": { "F2": 1.1 },
            "bands": { "A1": { "declarationWeight": 0.5 } } }
  }
}
```

A value of a language overrides the default, and one of a band (`A1`, `A2`, `B1`: the levels the course is built to) overrides the language's. Anything left out is the default's.

**The ranges are one-sided, per language, and only as wide as the gates have been run.** A file may move a value only in the direction that makes placement more careful than the built-in default; a value that would make it bolder is brought back to the default, and one past the edge is held at the edge. A language may move a value only as far as `kGatedEdges` says for it. **Spanish** has an edge (the table below: each value was found by running the honest gates, the per-cell time gate included, with that value alone, then every edge together under `PlacementProfile.safestEdge` in the gamer, adversary and honest suites, `test/placement_v3_edge_*_test.dart`). **Hindustani has none, and neither does any other language: a file may not move any value from the default for them.** Hindustani's honest time gate has no headroom (its median is at the gate's 28 items): a slip of 1.2, a standing-apart count of 16, a guess raise on the cheap formats and the model edges (declaration weight 0, together share 0.5, temper 0.7) each took a cell to 29 items. The table is Spanish's:

| Key | Default | May be | Why that far |
|---|---|---|---|
| `version` | 1 | 1 and up | recorded with every placement and every paused run; a paused run is resumed only under the version it began with; changing a profile's values needs a higher version (a test compares the shipped file with `test/fixtures/placement/profile_snapshot.json`) |
| `declarationWeight` | 0.7 | 0 to 0.7 | leans less on the declaration |
| `togetherShare` | 0.7 | 0.5 to 0.7 | shares less evidence between skills |
| `temper` | 0.85 | 0.7 to 0.85 | softer likelihood |
| `guessScale` | none (1) | F7, F8, F16, F18, F21 up to 1.25; every other format 1 | the pick formats are calibrated at the clean limit (0.35): any raise makes them unclean and the honest median run reaches 291 s against 200 s |
| `slipScale` | none (1) | 1 to 1.2 | 1.5 took the median to 29 items against 28 |
| `secondsScale` | none (1) | 1 only | at 1.25 the median reaches the 300 s cap and two gates fail |
| `climbQuantile` | 0.12 | 0.12 only | 0.15 took the median to 29 items |
| `standApartItems` | 14 | 14 to 16 | 18 and 0.2 climb together failed; 16 passed |
| `mixedBonus` | 0.3 | 0.25 to 0.3 | a smaller reward for mixed items; 0.2 with the others failed, 0.25 passed |
| `cognateThreshold` | 0.58 | 0.58 only | part of the bank, not read at run start |
| `f4DecoyKey` | false | never from a file | adds clean items nobody has gated; code only |

Widening a range means running the edge suites at the new edge first; the time gate has about 2 s of headroom, so most widening will need a faster picker or a different gate first. In the gated-run values `mixedBonus` and `standApartItems` are offsets from the default (a default profile gives exactly the values of step 6).

**Where profiles come from.** Only from the asset bundled in the app: there is no network path and no deck-download path, so a new profile ships with an app update, and so does the kill switch. **Kill switch.** `"killSwitch": true` makes every run use the built-in default, whatever the file says; a missing, malformed or unreadable file does the same. **Version.** The profile's `version` is stored with each placement (`placement_profile` in the settings) and each paused run (`profile`), so a placement can be told from the constants that made it. **Roll back** by setting the language's entry to the earlier values with a higher `version`, or by the kill switch; nothing in the learner's data has to change.

**Not decided here.** F4 tiles with decoys are audited at 0.05 to 0.07 and calibrated at 0.45 under the format key, which keeps them out (never clean); `f4DecoyKey` would make them clean at 0.30 and change which items the picker chooses (they cost 15 s), so a file cannot switch it on until the gates have been run with it. F3 (meaning to word) is calibrated at 0.45 and stays out for the same reason. Another valid word order of a sentence is accepted by F8 and F16 only when the course gives that order to a sentence with the same translation, or the language is listed in `kFreeOrderLanguages` (empty until a native reviewer flags one: the same words in another order can reverse who does what, `dog bites man` and `man bites dog`); otherwise the other order is graded as a miss, which understates the learner (safe).

## Step 8b: the outcome log, the export and the re-fit

**The local log.** Each Find my level run that ends in a placement keeps, on the phone only, one small record per skill: the start, the range, the word for how sure we are, the profile version and the language. No answers, no words, no timings. The record is joined with what the learner later does for real: their first reviews of the placed words (`lib/core/placement/outcome_log.dart`, `signalOf`). Pairs at or below the start answered badly say the start was **too high**; pairs just above it answered right say **too low**, or **range too narrow** if they lie beyond the range; a start that is far below everything the learner answers right says the range was **too wide**. Under 30 reviews says nothing.

**Corrections on the phone (off).** `kAutoCorrectPlacement` is `false`: `refreshPlacementSignals` records the signals and never changes the carefulness, so a run's profile is always the file's (a test calls it repeatedly). `correctedCarefulness` stays, unit-tested as a pure function. Turning it on needs a fix first: step only on new decided signals since the last step, and tally only outcomes made at the current correction; as written the same evidence would be applied again on every run and signals made under different carefulness would be pooled. The join counts the first review of each pair, after the placement day. The rule once on: With enough signals (`correctedCarefulness`), a language that has a gated edge moves one step toward its edge when too many placements were too high, and one step back when too many were too low. The step is small, always inside the language's one-sided edge, and reversible (the same rule moves it back); a language with no edge (Hindustani and the others) is never moved. The corrected profile is recorded with the placement like any other version.

**The export.** Settings, Your data, "Share placement data" writes the records to a file the learner chooses to share. Nothing is sent by the app. The file holds the same fields as the log and the app version, and can be read back (`importOutcomes`); a malformed line is skipped.

**The re-fit.** `dart run tool/placement_refit.dart <export files...> [--assets assets/placement_profiles.json]` reads exports, and for each language with a gated edge fits a line of the too-high rate against carefulness and picks the carefulness whose rate is at the target. It refuses (and says why) with too little data, one carefulness only, no gated edge, or a rate that does not fall with carefulness (slope above -0.05). The written profile has a higher `version`, a `fitted` entry, stays inside the edge, and leaves other languages alone. The simulated-learner tests (`test/placement_outcome_test.dart`) recover the carefulness the data was made with.

**Open items, not built.** (1) The held-out gamer scaffolding above (a different bank split, family-correlated leaks, exposure, other languages, per-run uncertainty in the leak rates) is documented, not built. (2) **Hindustani finding.** Its honest time gate has no headroom (the median is at 28 items), so no value may move toward more care. Options for a later decision: cheaper locate and proof items for Hindustani (a Write item as cheap as F21 and a cheaper Hear proof), or a per-language time budget (a median gate of 30 items for Hindustani, at the cost of a longer check); until one is chosen the gate stays as it is and Hindustani runs on the default.

## Release-ready pending list

Three gates stay pending: `experts-natives-within-a-tenth`, `honest-confidence` and `ear-only-placed-high-on-hear`. They need a re-fit on real learners' exports, and none exists. The **safe fallback** is the one shipped: with no fitted profile every run uses the default, which places low and never high (no honest learner is placed more than 2/10 above the truth; experts and natives are within 1/10 in 68 to 70% of runs flat, 84% advanced, 18 to 20% under an amateur declaration; the ranges are too wide for most and too narrow for ear-only and natives under an amateur declaration). A learner placed too low can change any start. The pending-gates test fails the day a fitted profile ships in the asset, so the gates cannot be forgotten.

## Meaning only, and the reverse direction (#1105, #1106; owner, 2026-11-10)

- **No "what you heard".** F16 (dictation) is removed from the registry, generators, picker, bank and audit. Hear and Say items always ask the meaning: F13 and F17 (hear the language, give the meaning), F18 (say it from the English).
- **Reverse formats.** The English meaning is spoken by the phone's English voice (always available, so no `needsAudio`) and shown, and the learner answers in the language: F22 picks the written word (items of F3), F23 types it (F7), F24 builds a sentence from tiles (F8), F25 types the unit left out of a word (F21). They are the same items as the formats they reverse, so the audit, the calibration (`baseFormat`) and the grading are those of the base format. A card is never asked in both (shared conflict keys).
- **Hear with Read (owner, 2026-11-10).** F13 (hear a word, pick its meaning) credits Hear and Read together, a mixed item, so it opens the run and a miss starts a drill-down that isolates Hear with F17; this takes the place of dictation without transcribing. Hear alone is F17 and F14. The stored bank needs no new schema: skills come from the format, not from the stored item.
- **Skills credited.** Spoken English is not Hear of the language, so none credits Hear: F22 Read; F23 and F25 Write; F24 Write and Read (as F8).
- **Reviews.** Not in this change: the review shell has no spoken-English prompt on its choice, typing and tile formats yet; follow-up under #1096.

## Look-alike options (owner, 2026-11-12)

- **Meaning only.** Hear and Say items are only about meanings: F13, F17 and F18 (F14 asks whether a heard word exists, and stays for now). No tile, dictation, spelling or transcription task is a Hear or Say item.
- **Options that look alike.** The options of a sentence pick (F5, F17) share the right one's length band and about as many words (`inOneBand`, `lib/core/scheduling/look_alike.dart`), so no surface cue gives the right one away. The stored item schema is 5.
- **Legacy calibration.** The heard-sentence pick of the legacy bank, whose right option shape gave away 75% of the time, is calibrated as leaky (`F17legacy`, as `F5legacy`) and never asked; the gamer gates' legacy cells use it.
- **Grammar, "pick the wrong one".** A list of example sentences of which exactly one is wrong. Built for reviews only (`wrongOneItem`, `lib/core/scheduling/wrong_one.dart`) and made only from wrong examples a deck provides; no deck carries any yet, so nothing offers it. Not yet a placement format: it needs its audit solvers, its screen and an admission verdict.
- **Reviews.** The wrong options of a choice question come from the cards that look most like the right one (`rankLookAlikes`): one length band, word family, word class, shared tags, nearest spelling.
