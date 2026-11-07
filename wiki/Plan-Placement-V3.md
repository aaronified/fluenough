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
| F16 | Dictation: hear a sentence, build it with tiles | Hear, Write | TTS | .05 / .10 | | sentence deck |
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
2. Replay harness and personas (`test/support/placement_v3_harness.dart`, fixture `test/fixtures/placement/adversary/leak_profile.json`, tests `test/placement_v3_gamers_test.dart`, `placement_v3_adversaries_test.dart`, `placement_v3_honest_test.dart`, `placement_v3_pending_gates_test.dart`): built. The harness runs any picker over a simulated bank (a stand-in for the item registry) with persona answer models (the adversary's measured leak rates, honest learners, yes-sayer, self-rater, cheater control). A stand-in picker (`BaselinePicker`) proves one band per skill with four clean items, climbs while the proof ceiling holds the start down, and stops at the caps. Enforced now: TOP100+RULES (weak and strong, Spanish and Hindi, legacy and fixed bank), COGNATE-ONLY, TESTWISE-ONLY, RANDOM, YES-SAYER, SELF-RATER, no honest learner more than 2/10 above the truth, four clean items per skill in every run, Read and Write fully placed without audio or a mic, no card asked twice.
3. Item registry and generators with the fixes above (`lib/core/placement/item_registry.dart`, `item_generators.dart`, `item_audit.dart`, `item_bank.dart`, `cognate_score.dart`; tests `test/placement_item_registry_test.dart`; tool `tool/placement_audit.dart`; fixture `test/fixtures/placement/adversary/audit_profile.json`): built. See "The item registry and its audit" below. The ANAGRAM-SOLVER, MATCHER, FAMILY-REPLAY and admission-audit gates are enabled and enforced.
4. picker, rotation and caps, 5. drill-down, 6. UI and result screen, 7. migration and retiring the V2 run policy, 8. real-learner re-fit hooks: next, one pull request each.

## Pending gates

These gates need a later build step and are listed, with the file that will signal their prerequisite, in `test/placement_v3_pending_gates_test.dart`. When the file lands, that test fails until the gate is enabled and its entry deleted.

| Id | Gate | Prerequisite file (any depth under `lib/core/placement/`) | Why it waits |
|---|---|---|---|
| `time-and-items` | Median at most 28 items and 200 s, 95th percentile at most 40 items and 300 s | name has `picker` (not `item_picker`) | The stand-in picker measures 22 to 30 items and 216 to 301 s medians |
| `experts-natives-within-a-tenth` | Experts and natives within 1/10 in at least 85% | `picker` | The stand-in places them safely but low |
| `honest-confidence` | 80% range holds the truth in 75 to 88% | `picker` | The stand-in gives 65 to 100%; re-fit at step 8 |
| `ear-only-placed-high-on-hear` | Ear-only placed high on Hear | `picker`, `drilldown` | The stand-in proves one band for all skills |
| `drill-down-identifies-the-failing-skill` | Drill-down finds the failing skill in 4 items | `drilldown` | No drill-down yet |
| `script-gate` | Script-literate-only with the script passed | `script_gate` | No script gate yet |

### Open for step 8: a held-out gamer

The adversary's leak rates are measured by one gamer on one bank, and the generators' fixes were calibrated against the same gamer, so the "fixed" bank's numbers are circular. Step 8 needs a held-out gamer: a different bank split; leaks correlated within a card family; leaks that depend on how many items the gamer has already seen (exposure); other languages; and per-run uncertainty in each leak rate. Until then the harness shows the model survives a gamer up to 0.07 better than measured (and fails at 0.45 better), not that the measured rates are the worst case.

### What the gates check, and the controls

The adversary gates are per skill (Read, Hear and Write each must pass), in every declaration and device variant. They have controls that show they can fail (Spanish): V3 as it was before the review (no calibration, no proof ceiling, a picker that asks every format and lets cognates in) is over by 1/10 in 24% of runs; calibration and the ceiling are each load-bearing in the setting where the other layers are removed; a gamer 0.45 better than measured fails in Spanish and Hindi. The model defends in layers, so removing one protection while the others stand still passes (measured: 0 to 3%).

## The item registry and its audit (step 3)

Everything is generated from a language's decks (`PlacementLanguageData`), with no per-language content: the cognate rules are a generic sound fold plus a small table of suffix correspondences per language (`cognateSuffixRules`), and a Hindi word is compared by its reading (its transliteration), which is how loanwords such as `skūl` are found. About 36% of the Spanish and 13% of the Hindi word cards are near-cognates (score 0.58); a word from 0.45 is also kept out of word-level formats, because a partial cognate still leaks to a similarity cue.

**The fixes, as built.** Word picks (F2, F13, F3) have two or three distractors of the same part of speech, article and length, near the item on the path, and chosen to look as much (or as little) like the prompt as the right answer does and to be about as long; none is one of the course's first 100 words (a gamer that knows them could eliminate it); a look-alike lure is in only 15% of the items, because an option that resembles the prompt is always wrong and a solver that drops it would otherwise gain. Sentence picks (F5, F17) change one noun, verb or adjective of the right translation. Word tiles (F4) carry decoy units (two, chosen by the audit; a syllable unit in an Indic script). Tile sentences (F8, F16) carry two decoy words. The word-order pair (S2) keeps its end marks fixed and swaps two adjacent words, choosing the most natural-looking swap. Cloze (F6) has no English hint; its options share the blank's ending, are about as long, and are the most plausible in the context. Gender items (`F6g`, Spanish only) are half exceptions to the ending's rule and half rule-followers. Yes/no pseudowords imitate a real word each: its length, how typical its letter patterns are (three measures, each without the word it came from) and how far the nearest other word is. A matching screen (F9) has four words of one part of speech, near each other. A card is never asked twice in a run (`ItemBank.available`: no item may share a card or a lemma with one already asked, and a card shown as an option counts as seen; drill-down included).

**The admission audit.** A class (a format and its cognate class) is attacked by solvers that never see the key, every one in both orientations (the option it scores highest, and lowest), and is admitted only if the **upper 95% confidence bound** of its best solver (Wilson for accuracies, Hanley and McNeil for the yes/no AUC) is within the guess plus 0.07 (0.32 for a four-option pick). A class with too few items cannot show that and is excluded; a class that was not attacked is not admitted. The solvers: longest and shortest option; similarity to the prompt, and dropping the most similar option; a gamer that knows the first 100 words (its own cards are left out of the measure); for a cloze, word-pair and ending-pair models of the course's sentences without the item's own sentence; an anagram solver (letter patterns of the whole course without the target; a search cut short counts as solved); a beam-search order solver for sentence tiles (word and ending pairs); spelling rules; a matcher and an anti-matcher; five pseudoword detectors (letter patterns, unit pairs, edges, nearest-word distance, length) each leaving the word out; the ending rule and its opposite for gender; chance. Result on the real decks:

| Class | Spanish: best solver, accuracy (upper bound) | Hindi | Bound | Admitted |
|---|---|---|---|---|
| F2 written word to meaning | drop-most-similar 0.257 (0.297) | length 0.265 (0.305) | 0.32 | both |
| F13 heard word to meaning | 0.256 (0.296) | 0.262 (0.302) | 0.32 | both |
| F3 meaning to written word | 0.263 (0.303) | 0.260 (0.300) | 0.32 | both |
| F4 word tiles (2 decoys) | 0.054 (0.078) | 0.025 (0.043) | 0.17 | both |
| F7, F18 typed or said | 0.008 (0.021) | 0.008 (0.021) | 0.10 | both |
| F8, F16 tile sentences | 0.021, 0.007 (0.037, 0.019) | 0.021, 0.012 (0.048, 0.035) | 0.12 | both |
| F9 matching, per pair | 0.306 (0.340) | 0.250 (0.278) | 0.35 | both |
| F1, F14 yes/no, AUC | 0.565 (0.593), 849 words | 0.606 (0.641), 326 words | 0.60 | Spanish only |
| F5, F17 sentence picks | 0.279, 0.292 (0.345, 0.359), 140 items | 17 items | 0.32 | neither: too few items to show it |
| F6 cloze | context 0.439 (0.512) | 19 items | 0.32 | neither: a context model reads it |
| F6g gender | opposite rule 0.529 (0.710), 17 items | none (no articles) | 0.57 | neither |
| S2 word order | word pairs 0.578 (0.621) | ending triples 0.534 (0.597) | 0.57 | neither |
| any cognate-class sentence item | 27 to 87 items | 3 to 38 items | | only the tile sentences |

**What is admitted, and the effect on the item mix.** Per skill, with no audio: Read has F2, F3, F9 and F8 (Spanish also F1), Write has F4, F7 and F8, so both are placeable without audio or a microphone, as the design requires. With audio, Hear has F13 and F16 (and F14 in Spanish); Say has F18 (with a recogniser). What is missing: **no admitted format reads a whole sentence for meaning (F5, F17) or tests grammar by choice (F6, F6g)**, and **no pairwise word-order item survives (S2 is excluded in both languages), so word order is covered only by the tile sentences F8 and F16**. The plan's call for sentence-level items in the rotation is therefore met by F8 and F16 alone (Read and Write, Hear and Write), and Read has no sentence item that is not also a Write item. Formats that need a new generator to come back: a sentence pick with enough items and a distractor method that a one-word-contrast solver cannot beat (Spanish has 140 sentences and Hindi 17 with usable translations; the course needs more, or the sentences of several units pooled into one class); a cloze whose distractors a context model cannot rank (for example plausible in context by a model other than the audit's); a gender item set with enough exceptions; a word-order swap that endings cannot reveal. F10 to F12 (script decks), F15 (minimal pairs), F19 and F20 (screens of step 6) are not generated here.

**What the audit does not show.** The solvers are mine, and three generators choose against solvers of the same kind (the cloze distractors and the word-order swap by word pairs, the pseudowords and matching by typicality), so those classes are measured partly against the cue they were built to defeat. Controls in the tests: word tiles without decoys fail in Spanish (0.333); a pick whose answer is the longest, or always the shortest, option fails (the second is caught only by the inverted orientation); a look-alike lure that is always wrong is caught by the drop-the-most-similar solver; twenty chance-level items do not pass on their confidence bound; a run that ignores the never-twice rule gives a replay gamer a lift above 0.4, and one that keeps it gives none.

**Harness.** The "fixed bank" leak rates of `leak_profile.json` were an assumption (about 0.30 for a clean pick); the harness now uses what the audit measured for each format that passes (`audit_profile.json`, floored at the design guess): about 0.26 for picks, 0.05 for word tiles, 0.02 for tile sentences and 0.01 for typing; the formats that no longer pass (F5, F6, F17) keep the old figure. The legacy tables are the adversary's own measurements and are untouched. Regenerate the fixture with `dart run tool/placement_audit.dart` when the decks change a lot; a test compares it with a fresh audit (the same classes pass and are excluded, accuracy within 0.02).

## Owner decisions for Progress (2026-11-07)

Accepted as the recommended defaults: a hatched placed layer under the solid fill; the outline earned-only; the level shown with a "Placed" mark before any earned review; a lapsed placed pair drops out of the placed layer into taught-not-known; the Words tile reads "N known of T taught (+M placed)"; unconfirmed 0.9.0 and 0.9.1 credit is treated like other placed credit on Progress and marked only on the Languages sheet; Progress shows only the lower-edge point; whether credit was set in stone or reviewed as usual does not matter for what Progress shows. The rules are in [Progress-and-Stats](Progress-and-Stats). The progress core is built (step A); the level and the placed mark (B) and the drawing (with step 7) follow.

The level PR (B) is built: `assurancesFromJoint` (lib/core/placement/placed_outcome.dart) carries a V3 readout to the placement write, `AppState.writePlacementJoint` writes it (each scored skill by its lower edge, never above the proven ceiling; Say self-rated and any skill not tested write nothing and never pull the placed decks down), the Level tile carries a "Placed" mark until a unit of its milestone has an earned review (`levelPlaced`), and the Words and Rules tiles read "+M placed". A script deck's credit is a placed script pair (placement placed the script); a word credit has no script and feeds none. `AppState.record` never writes a real answer in the shape of credit (`realElapsed`: a real grade 5 with no time and no answer is recorded with one whole millisecond, because every store keeps elapsed time in whole milliseconds, so credit stays 0 ms and a real flip stays 1 ms through the database, the JSONL backup and the replay snapshot). Rows stored before this, when a self-graded flip was stored as 0 ms, cannot be told from credit and are not reinterpreted. A skill proven below A1 (placed class `none`, placed level -1) writes no credit of its own and makes the course's shared placed decks start from the first deck, as V2 did, so that no skill is denied a lesson it still needs; the other skills are still credited each by its own level.
