# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.


## Find my level: verify, then fit, and how a run samples questions (plan, owner, 2026-11-05)

Status: plan agreed by the owner 2026-11-05. Step 1 (the pure model in `lib/core/placement/`, PR #1032, merged 2026-11-05) is built and not wired into any screen; steps 2 to 5 are built (step 5, the confidence display, in `feat/placement-confidence-display`). The build order is below, and the step 1 note follows it. The owner's answers of 2026-11-05 are in section 9 (answered table); the questions still open are there too. The numbers of sections 4.5 to 7 come from a model and a simulation written for this plan (a Python script of about 150 lines, kept in the session scratch folder), **not run in CI**; the implementation's tests must reproduce them (section 5.3).

**Proposed build order**

- **Built (step 1, PR #1032).** Pure model in `lib/core` first, with unit tests: the twelve-class posterior update (4.1), the question parameters (4.2), the run state of this run's answers, and the mastery-topic order (2.1).
- **Built, not wired (step 2, `feat/placement-question-generators`).** Then the question generators in `lib/core`, one mastery topic at a time (2.1, topics 1 to 7). Section 11 holds the data audit, the gaps and their fallbacks.
- **Built (step 3, `feat/placement-run-flow`).** Then the run flow and the checkpoint UI (5.1, 5.4). Section 12 holds how it was built and the choices the plan was silent on.
- **Built (step 4, `feat/placement-run-flow`).** Then the declaration screen (4.5).
  - offer options by built level (4.5).
- **Built (step 5, `feat/placement-confidence-display`).** Then the confidence display (4.3, 5.5): the result screen and the labels under the skill rows of the Languages sheet; section 12, point 9 and the step 5 note below say how.
- Rule for every step: `lib/core` has no Flutter imports (AGENTS.md); Flutter code lives in `lib/features`.

**Step 1 as built.** Files: `lib/core/placement/assurance_model.dart`, `assurance_readout.dart`, `placement_questions.dart` and `placement_run.dart`. The third script question is off by default (`extraScriptQuestion`). A gap in any part blocks Verified. Duplicate levels are merged on paths of 10 decks or fewer. Four deviations from the plan's figures:

- Amateur declared plus an advanced learner: 12 and 11 questions, instead of 13 and 12.
- Closed pair topic: 21 questions, instead of about 23.
- Example 3: "Write falls to 35%" occurs after the next question; 3% is right after the split.
- The two track-cost cells are not simulated.

Not modelled yet: item hardness scoring, no-repeat rules, pause and resume, and the script's own five levels.

**Owner quotes, 2026-11-05, in the order they came.**

- Placement count. "Keep placement question count within 25 questions." **Superseded on 2026-11-05 by the owner's later message below: 25 is now a checkpoint, not a cap.**
- Verified, fit and dialect. "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." / "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." / "Verification will only be given after the language has all planned decks and verification run has used all of them." / "I mean full B1 completion level as per the path. Bengali already has that." / "Verified mark: per skill". / "Dialect: only the dialect taught. Mostly every bengali understands the standard dialect (same for almost all languages). Speak is a problem, true."
- Failed check. "Failed check: one fail = check 2 more. If both fail, case closed."
- Native path, first reply (history). "Ask the last deck. If known, sample around that till you find serious flaws. If not known at all (2 questions min), go to 1st deck and keep sampling from there." Then, rejecting the walk back: "That would be quite frustrating for native speakers. Just cover the major grammatical concepts and harder recognition and complex words, test also on minimal pairs more."
- **Newest design (1).** "Presume expert after the last two answers are perfect. No. That is basically 2 questions. Keep asking the hard ones, and when user has covered all the mastery topics (long sentence recognition and reproduction, late stage grammar qs, minimal pairs, etc) without failing 2 in a row in any topic. If he fails in the beginning (the last deck), sample around in the mid section of the app (vocab check only now). if that fails, go back to 25%ile decks; if passes, then to 75%ile decks. Once they keep passing and the vocab level is somewhat fixed, check grammar level. That's it."
- **Newest design (2).** "Check multiple skills together, and on fails, split the skills. Like ask the meaning of a long sentence written only in the script. Or ask to say it in english."
- **Newest design (3).** "Ask them to say the meaning of some words."
- **Confidence.** "Once placement is done, show the confidence level for each skill. It is okay to have low confidence. Learner can fit again later to give the algo more data and fit better." **The "fit again later" part is dropped by the next quote.**
- **Assurance and the checkpoint.** "Verified opens when there is 95% assurance. Better yet, ignore my last 'fit again' message and prolong the fit as needed to get to the 80% level. Instead, after 25 questions, tell the user that they are positioned as lets say x, y, z on 3 skills and if they think they are better than that, they can keep going or stop." **The 80% level is superseded by the next quote.**
- **Per skill, target 95% (owner, 2026-11-05).** Asked "Do 80% and 95% apply per skill or to all skills together?", the owner answered: "Per skill. Target is 95%". So each skill has its own assurance, and the target of the fit is 95% for every skill: the run goes on until each tested skill reaches 95% or the learner stops at a checkpoint. **80% is no longer a stop target.** It stays only as the lower edge of the label "Sure" (section 4.3), which a learner sees when he stops early.
- **The declaration (owner, 2026-11-05).** "Also, ask whether the user is fluent, advanced, or amateur first (beginner is the third option that skips placement and instead starts from the beginning). That will help determining the starting level. These declarations will be overridden by the determined placement." The owner lists fluent, advanced and amateur and calls beginner "the third option"; this plan reads it as one first question with **four** answers, Expert, Advanced, Amateur and Beginner (answered 2026-11-05: the four answers and their wording are in the labels bullet below and in section 9).
- **The labels, decided (owner, 2026-11-05).** "All okay, but the skip is for what? It starts from the beginning. Just the 4 options." So the first question has exactly four answers, and no Skip: **Expert** "I use it easily"; **Advanced** "I follow most of it and can say what I need"; **Amateur** "I know some words and phrases"; **Beginner** "I am starting from nothing".

**What the newest design replaces, and what it keeps.**

| Earlier rule (this page, earlier today) | Now | Why |
|---|---|---|
| "Last two perfect presumes expert"; probe of 2, then a 10 to 14 question battery | no presumption: hard questions across all seven mastery topics (section 2); the run goes on until every topic is covered and each skill has reached 95% assurance | the owner: two answers "is basically 2 questions" |
| Sentinel question, consistency block | dropped; assurance is computed from every answer, so inconsistency shows as low assurance (section 4) | one mechanism instead of three |
| Twin or "TIE" checks; recheck rule | **kept**: a miss gets checks (section 1); a composite miss is checked by splitting it (section 3) | owner: "one fail = check 2 more" and "split the skills" |
| Level-mark ladder, bisection with CONFIRM | replaced by positioning (section 5.3): the next question is asked at the deck where the evidence is most undecided, which is the owner's mid section, then 25th or 75th percentile | owner: "sample around in the mid section ... 25%ile ... 75%ile" |
| Hard cap of 25 questions | **a checkpoint**: at 25 (and every 25 more) the learner sees where they stand and chooses Keep going or Stop here (section 5.4) | owner, newest message |
| Verified = pass rule of 3 questions per skill and at most two closed cases | Verified = 95% assurance for the skill, plus the preconditions, plus every mastery topic covered, plus no closed case in the skill (section 4.3) | owner: "Verified opens when there is 95% assurance" |
| Confidence level and cross-run stored evidence (the confidence message) | confidence is the assurance number (section 4); evidence is **not** kept across runs (section 4.4) | the model needs only this run's answers; the owner dropped "fit again" |
| Stop target 80% for a skill that cannot be Verified (a gap, a language short of B1) | **95% for every skill**; 80% is the lower edge of the label "Sure" only (section 4.3) | owner: "Per skill. Target is 95%" |
| "Does a self-declared level seed the search?" (earlier open question: no) | **yes**: a first question (Expert, Advanced, Amateur, Beginner) seeds where the questions start (section 4.5); Beginner skips the run | owner: "ask whether the user is fluent, advanced, or amateur first" |
| Kept unchanged | verified needs the path complete to B1 and every deck downloaded; a run never changes a skill's Learn, Know or Leave state; verified is per skill; only the dialect taught; "know" = hear, say, and read plus write in at least one script | not contradicted |

### 1. Definitions

- **Deck order.** The language's word decks in path order, from the first A1 deck to the unit marked B1 (`CoursePath`, `walkDecks`). Index 0 is the first, N-1 the last (B1's end). **Unit** on screen is the deck index plus 1. Script decks are checked by the script check (section 3.1, topic 7), not here.
- **Complete to B1.** The path marks B1 and no unit up to it is still to be written. Today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona. Only these can be verified; the others are positioned only (row m).
- **Declaration.** The learner's first answer in a run: Expert, Advanced, Amateur or Beginner, once per language (section 4.5). It chooses the **asking prior** (what the next question is aimed at) and nothing else: it is never the result, never shown back as one, and never evidence for a level or for Verified. The placement the answers determine always overrides it.
- **Skill.** The four app skills Read, Hear, Say, Write, and **Script** where the language has its own script (a script is read and written; Hindustani has two). A learner "knows" a language when he can hear, say, and read plus write in at least one script. A run tests only the skills the learner marks as known.
- **Mastery topic.** One of the seven topics of section 2.1. A topic is covered when it has had its minimum of 2 questions.
- **Composite question.** One question that needs several parts at once (reading the script, the meaning, hearing, spelling) and so evidences every skill it needs (section 3).
- **Recheck, split, slip, closed case.** Owner: "Failed check: one fail = check 2 more. If both fail, case closed." After a miss on a single-skill question, ask one more of the same kind (same topic, a different item); if it is right the miss is a **slip**, forgiven; if wrong, ask a second; if that is right it is a slip; if both are wrong the case is **closed** (a serious flaw): no more questions on it, and a closed case in a skill means that skill cannot be Verified in this run. After a miss on a **composite** question the two checks are its **split** (section 3.2): single-part questions that say which part failed. Read as sequential for single-skill questions (a slip costs one question, a closed case two) and always two for a composite; if the owner means that both checks are always asked, every miss costs two; the owner accepted one and two on 2026-11-05 (section 9). "I don't know" is a miss and is never followed by a hint. Under the model of section 4 the checks are ordinary questions; the rule only says when to ask them.
- **Topic fail ("failing 2 in a row").** Read as a closed case: a miss and both checks wrong (for a composite, both split questions wrong). Section 9, question 6 asks whether the owner means a stricter reading (a miss and one wrong check).
- **Assurance, placed level, window.** Section 4.
- **Percentile (in decks).** The p-th percentile deck is deck `round(p/100 x (N-1))`. After the first failure at the last deck the next probe is the middle (50th); a failure there goes to the 25th, a pass to the 75th; thereafter each probe is the midpoint of what is still undecided (section 5.3), which is the same rule.
- **Placed level.** The first deck from which the learner should learn; every deck before it is credited as known (the existing `placedDeckIds`). With assurance it is set per skill (section 5.5).

### 2. Mastery topics (A)

**2.1 The list (a proposal; section 9, question 4).** The expert path asks hard questions at the last deck (the last two decks when one deck lacks enough cards; section 4.2 explains why two) until every topic below has had its minimum of 2 questions. A recheck or split comes only after a miss and is not part of the minimum.

| # | Topic | Question kinds (hardest first) | Min | Skills each question covers | What the evidence counts as |
|---|---|---|---|---|---|
| 1 | Long-sentence recognition | K1: a long sentence (8 words or more) of the last deck, written only in the script, no audio, no reading aid: say its meaning in English (the recogniser for English is reliable), or, with no mic, pick its meaning from four. K2: the same by audio only, say the meaning in English (no mic: pick) | 2 | K1: Read, Script. K2: Hear | right = the learner read (K1) or heard (K2) a long sentence of the last deck and understood it; production answers are the strongest evidence in the plan because a guess is almost never right |
| 2 | Long-sentence reproduction | R1: hear a long sentence, build it with tiles or type it in the script (dictation). R2: shown the English meaning of a long sentence, build it in the language with tiles (grammar and word order) | 2 | R1: Hear, Write. R2: Write | right = he can spell and order a long sentence; tiles include close wrong tiles. Reproduction by speech is not used here, because of dialect and the recogniser (section 2.4); Say has its own topic |
| 3 | Late-stage grammar | G1: pick the correct form for a blank in a sentence (hardest form of a late concept family). G2: reorder tiles into a correct late-grammar sentence. Two different families (the last grammar unit's first, then the family with most units) | 2 | G1: Read. G2: Write, Read | right = the hardest form of that family is known in a sentence |
| 4 | Minimal pairs | hear one of two words that differ by one contrast of the language's `<lang>-sounds.yaml`; pick which was said. Two different contrasts | 2 | Hear | right = the contrast is heard; a pair is a coin toss for a guesser, so the topic is cheap but weak per question (section 6.2) |
| 5 | Complex words | W1: the longest or most inflected word of the last deck(s), written, pick its meaning. W2: another, heard, pick its meaning | 2 | W1: Read. W2: Hear | right = an inflected or compound word is understood |
| 6 | Say, by the meaning of a word | shown an English meaning (a short word, one or two syllables, of the late decks), say the word in the language; graded by the recogniser against the taught word and its listed synonyms. Shorter items reduce dialect risk | 3 | Say | right = he can retrieve and say a late word; Say is the one skill that cannot be tested by a composite, so it takes 3 questions (see 4.2) |
| 7 | Script read and write (only where the language has its own script) | read a word with the rarest sign or conjunct and pick its meaning; build by tiles a word with a conjunct or contrast letter | 2 (1 read, 1 write) | Script, and Read or Write | right = the top two levels of the script check; a closed case goes down the script's levels (the script check keeps its own five levels; section 5.3) |

Topics 1, 5, 3, 2, 4, 6, 7 are asked in that order, so the meaning-bearing topics (the ones that show an unknown vocabulary) come first. Minimum clean run: 2 + 2 + 2 + 2 + 2 + 3 + 2 = **15 questions** for Bengali (13 for a language with no script topic, Spanish; 17 for a learner who reads two scripts). A skill the learner did not mark as known is not asked, and the composite takes the audio, the written or the English variant that fits the known skills (row g).

**2.2 How an item is chosen ("hard"), per skill.** The pool for a question is the cards of the last deck (extended to the last two decks, then the last quarter, when the deck lacks cards of the kind). Every candidate gets a hardness score `H` from three parts, each 0 to 1:

| Part | Meaning | Source (exists today) |
|---|---|---|
| depth `d` | the card's deck index divided by N-1 | path order |
| form `f` | 1 for an inflected form (has `bases`), a compound, an idiom or a sentence of a grammar unit; else the card's length (characters or syllables) as a percentile within its deck; plus 0.2 if its notes mention a stem change | card fields: `bases`, `pos`, `tags`, `notes`, `target` |
| closeness `c` | how close the nearest wrong option is | distractor generator (`distractors.dart`: base, pos, tag sources) and `<lang>-sounds.yaml` |

`H = 0.35 d + 0.30 f + 0.35 c`. The top five candidates by `H` are the shortlist; the item asked is picked at random from the shortlist with the run's seed, so running twice does not repeat the same five. The app is offline and has no population data, so `H` has no "how often learners miss this card" term (section 9, question 8). A card the learner already reviews with high stability is skipped, because a stable card says "learned in the app", not "known before". **Closeness `c`** of a wrong option `o` to the right card `a`: 1.0 if `o` is `a` with one pair of a sounds-file contrast swapped; otherwise the larger of (1 minus the normalised edit distance of their readings), plus 0.2 if one is a base of the other, 0.1 for the same part of speech, 0.1 for a tag in common (capped at 1). Options never repeat a meaning, and never a card already asked.

**2.3 No repeats.** Never the same card twice in a run; never two cards of one word family in a run; never a card as both the question and an option; one concept family or contrast at most once as a first question (a recheck or split is the only repeat of a topic).

**2.4 Dialect: only the dialect taught.** Owner: "Dialect: only the dialect taught ... Speak is a problem, true." Questions use only the taught dialect and no dialect variant is accepted as right. Hear and Read are safe. Say is the risk: a fluent speaker of another dialect may say a word his way and be failed by the recogniser. Short items (topic 6) and the English-meaning answers of topic 1 (the English recogniser is reliable) reduce the risk; the rest is as the owner accepted it on 2026-11-05 (section 9).

### 3. Composite questions and the split (B)

"Check multiple skills together, and on fails, split the skills." A **part** is one thing a question needs: *script* (reading the writing), *meaning* (vocabulary and grammar understood), *sound* (hearing), *spelling* (building the word), *speech* (saying it).

**3.1 The composite questions, their evidence and the split ladder.** On a miss ask the two split questions S1 and S2 in turn, each a **different** item of the same topic that removes parts; both are asked (one reading of the owner's "check 2 more").

| Q | Question | Parts | Skills it evidences (right) | Split S1 | Split S2 |
|---|---|---|---|---|---|
| K1 | long sentence in the script only, say its meaning in English | script, meaning, English speech | Read, Script | another long sentence by audio only, pick its meaning (removes script and speech: tests meaning) | a short last-deck word in the script, pick its meaning (removes length: tests script) |
| K2 | long sentence by audio only, say its meaning in English | sound, meaning, English speech | Hear | another by audio, pick the meaning (removes English speech) | a short word heard, pick its meaning (removes length) |
| R1 | hear a long sentence, build it with tiles | sound, spelling, meaning | Hear, Write | a short word heard, pick its meaning (Hear only) | its English meaning given, build a short word with tiles (Write only) |
| R2 | English meaning of a long sentence, build it with tiles | meaning, spelling, word order | Write | build a short word with tiles (Write only) | which of two sentences is correctly ordered (grammar only) |
| G1 | pick the correct form for a blank | grammar, meaning, script | Read | the same family's hardest form in a short two-word phrase (removes sentence load) | the family's form of the first unit that teaches it (tells late forms from the whole family) |
| G2 | reorder tiles into a late-grammar sentence | grammar, spelling | Write, Read | a G1-style pick (grammar without spelling) | build a short word with tiles (spelling without grammar) |
| W1 | written complex word, pick its meaning | script, form, meaning | Read | its base form written, pick the meaning (removes inflection) | the complex word heard, pick the meaning (removes script) |
| W2 | heard complex word, pick its meaning | sound, form, meaning | Hear | its base form heard, pick the meaning | the same word written, pick the meaning |

Without Hear marked as known, any "by audio" part is shown as the word or sentence in the learner's reading (transliteration) instead.

**3.2 What the split decides.** Both split answers right: the miss was a **slip**, forgiven, and the composite is treated as right for assurance (section 4.1 also keeps the miss as evidence). Exactly one wrong: a **gap** in the part that question isolates, recorded with its topic and deck (grammar: the family and the unit; script: the sign class; sound: the contrast); a gap in a skill-isolating part (Hear only, Write only, script) marks that skill "not Verified" until a later run; a gap in the meaning, grammar or vocabulary part is recorded and credited around (every deck credited except the gap's first failing unit), without un-verifying a skill. Both wrong: the topic is **closed**: no more questions on it (its second base question is skipped), the skills it needs are not Verified, and the run leaves the expert path for those skills when the closed topic is 1 or 5 (they show the learner does not have the last deck's vocabulary), or when two topics are closed (section 5.1). Single-skill questions (pairs, Say, script) use the sequential recheck of section 1, and after a closed single-skill case one isolating question is asked (not rechecked, it closes nothing): a pair case gets a Write tile with the swapped letter (hearing against spelling); a Say case gets the same word heard, pick its meaning (pronunciation against vocabulary).

**3.3 Evidence per skill.** The earlier "at least three passing questions per skill" is replaced by assurance (section 4): a question counts for every skill it needs, a right composite in full, a miss at half strength until the split says which part failed. The fixed order of section 2.1 gives these clean-run counts (right answers, Bengali): Read 4 (K1, W1, G1, G2) plus 1 script read; Hear 5 (K2, W2, R1, two pairs); Write 4 (R1, R2, G2, script write); Say 3; Script 3 (K1, script read, script write). The floor of 3 questions per skill for Verified is accepted (owner, 2026-11-05; section 9).

### 4. Assurance: the model

**4.1 The model, in one sentence.** *Assurance in a skill is the probability, given every answer so far, that the learner's true level in that skill is the level we place him at; the levels are the end of the path and ten equal tenths of it below, plus "none".*

It is a Bayesian update over a short list of hypotheses, small enough for one pure Dart function (`Posterior update(Posterior, Answer)` over twelve numbers, no state but this run's answers):

1. **Hypotheses (classes).** `none`, and the levels `l_k = round(k x (N-1) / 10)` for k = 0 to 10 (for N = 100: 0, 10, 20, 30, 40, 50, 59, 69, 79, 89, 99). A class says "the learner knows every deck up to `l_k` and none above". The top class `l_10` is "the whole path, the last deck included". For N of 20 or fewer the classes are min(10, N) equal parts, at least one deck each.
2. **Two posteriors, one prior each.** The **reporting posterior** starts equal for the twelve classes (1/12 each): "no opinion". It alone sets the placed level, the assurance, the names, the 95% target and Verified, so the owner's own words ("the 25%ile and the 75%ile") need no other prior and a declaration can never add to a learner's assurance. The **asking posterior** starts from the prior of his declaration (section 4.5) and is used for one thing only, picking the deck of the next question (5.3, point 2). Both multiply the same likelihoods.
3. **A question** at deck `d` has a slip rate `s` (a learner who knows deck `d` still misses it) and a guess rate `g` (a learner who does not know it still gets it right). For a class with `l_k` at least `d`, P(right) = 1 - s; otherwise P(right) = g. The likelihood of the answer is that, or 1 minus it for a miss. A question of the last two decks counts as asked at deck N-1.
4. **Composite questions.** A composite is right only if every skill it needs worked, so a right answer updates each skill it covers in full. A miss may be the fault of one skill, so it updates each skill at half strength (the likelihood to the power one half) until the split says which part failed; the split answers update their single skill in full (section 3.2).
5. **Rechecks, splits and slips need no special case.** They are ordinary questions, and a slip is a miss next to two rights: the posterior handles it.
6. **Posterior** (the reporting one, unless said otherwise) = prior times the product of the likelihoods, normalised. The **placed level** of a skill is the leading class's level (never above it); its **assurance** is that class's posterior mass. The "window" is therefore one tenth of the path, which is what "the vocabulary level is somewhat fixed" means (section 5.3).
7. **Verified** needs the leading class to be the top class with mass of at least 0.95, plus the conditions of 4.3.

**4.2 Parameters (defaults; open question 1).**

| Question kind | Slip `s` | Guess `g` | Right answer multiplies the odds by `(1-s)/g` |
|---|---|---|---|
| four-option pick, single skill | 0.05 | 0.25 | 3.8 |
| four-option pick, composite | 0.10 | 0.25 | 3.6 |
| pair (two options) | 0.05 | 0.50 | 1.9 |
| say it in English (K1, K2; the English recogniser) | 0.10 | 0.03 | 30 |
| tiles, a sentence (composite) | 0.10 | 0.05 | 18 |
| tiles, a short word | 0.05 | 0.10 | 9.5 |
| Say the taught word (topic 6) | 0.15 | 0.03 | 28 |

The higher slip for composites and for Say is the extra ways to slip (a recogniser error, a long sentence). Production answers carry the most evidence because a guesser almost never produces the right words; that is why topic 6 asks 3 Say questions (three right answers lift Say from 8% to 99.9%) and why K1 and K2 ask for the meaning in English whenever a mic works. A question of the last two decks is treated as deck N-1, so that a pool of two decks gives the 15 questions their no-repeat room (section 2.3).

**4.3 Names, and how they relate to Verified.** The learner sees words, not a score out of 100 (section 9, question 3):

| Name | Assurance of the leading class | Meaning for the learner |
|---|---|---|
| Not tested | skill not marked, not asked, no mic, "can't speak now" | "we did not test this" (never a fail) |
| Not sure yet | under 50% | "too few answers to say; this is a first guess" |
| Fairly sure | 50% to 79% | |
| Sure | 80% to 94% | a good placement, a little short of the target; what a learner who stops early usually sees. **80% only draws this line; it is not a stop target any more** |
| Very sure | 95% or more | the fit target for every skill; the run ends for this skill (the placement is as good as the run can make it) |
| Verified | 95% or more, at the top class, and the conditions below | the language is marked Verified for this skill (a "Very sure" that also meets the conditions) |

**Verified** is the highest name, not a separate test (a skill at the top class that is "Very sure" but misses a condition below stays "Very sure"): for each skill it needs (a) the path complete to B1 and every deck of the language downloaded; (b) the top class with assurance 0.95 or more; (c) every mastery topic that skill takes part in covered (the owner: "covered all the mastery topics"); (d) no closed case and no gap in that skill in this run. A run that does not meet them still gives an assurance and a placement: a low name is acceptable and is never called a failure. Verified is per skill, as before.

**4.4 No evidence is kept across runs.** The model reads only this run's answers, so nothing from an earlier run is stored: no per-deck record, no decay, no carried assurance. Reasons: storing it adds state, a decay rule, a conflict rule and a privacy surface for no benefit to the model, and the owner dropped "fit again later" (a carried evidence would only have served that). If the owner wants it later, earlier evidence enters as the prior of section 4.1 and nothing else changes (section 9, question 7). **When a later run disagrees with an earlier one:** for each skill the later run tested, its placement replaces the earlier one; a skill it did not test keeps its old placement. If the new placement credits fewer decks, the sheet shows both and asks before it removes any credit; if more, it credits at once (and, as always, a run never changes a skill's Learn, Know or Leave state; it only adds credit and the Verified mark).

**4.5 The declaration: a prior for asking, never evidence (owner, 2026-11-05).** The first question of a run, once per language, in simple words (labels decided 2026-11-05): **Expert** ("I use it easily"), **Advanced** ("I follow most of it and can say what I need"), **Amateur** ("I know some words and phrases"), **Beginner** ("I am starting from nothing"). The learner must answer it: there is no skip (owner, 2026-11-05). It is asked once per language and not per skill: the skills the learner marks as known already say which skills to test (rows g, i), so a per-skill declaration would add a second screen for a gain the marks already give (answered 2026-11-05).

**Options by built level (owner, 2026-11-05).** Owner, 2026-11-05: "For decks with just A1, the app will only offer know nothing and amateur. For A2, it will also offer advanced. That way there is no need to define the levels with sparse data." Owner, 2026-11-05: "For below A1, no placement will be offered." Owner, 2026-11-05: "B1 - should be termed expert. Not fluent. The app cannot really check fluency". The screen offers only the options the language's built path supports. "Built to" is read as the path's level marks (A1 end, A2 end, B1 end), each counted as built when the path marks it and no unit up to it is still to be written: the same test as "complete to B1". The owner's "know nothing" is the label Beginner ("I am starting from nothing").

| Path built to | Options offered at the declaration screen |
|---|---|
| below A1 (no completed A1 level) | none: no declaration, no run, no placement (deviation row p) |
| A1 only | Beginner, Amateur |
| A2 | Beginner, Amateur, Advanced |
| B1 (complete, see Definitions) | Beginner, Amateur, Advanced, Expert |

Expert is offered only for a path built to B1. The label never claims fluency, since the app cannot check it: Expert names the B1 level, and "expert track" keeps its name. For a language short of B1, Fit only places (positioned, never Verified), as already agreed (row m).

Consequences for the model:

- An option that is not offered has no prior and no probe; its branch is never entered.
- The expert track never starts for a language short of B1, because Expert is not offered there. Row m's mention of the expert track is therefore limited to a skill positioned at the top class (step 0); open question 11.
- Below A1, no Find my level action, no declaration question and no run is offered: the learner starts at deck 0, and the screen shows no placement button (open question 10).
- The cost table and the worked examples use B1-complete paths, where all four options are offered, so they stay valid. On an A1-only path the Expert and Advanced columns of the cost table do not apply. No other table declares an option.

| Answer | What it does | Asking prior over the twelve classes (none, l0 to l10), and where the first question lands |
|---|---|---|
| Beginner | **skips the run**: no question, no credit, no placement. The learner starts from deck 0 with the skills as he marked them (Learn, the default); a script he cannot read starts from the script's first deck, because the Script skill is Learn like the others, and the existing script test (a learner who reads the script through another language may skip the script lessons) is offered as it is today, as a separate feature, not as placement (section 9, answered 2026-11-05) | none |
| Expert | the expert track of 5.1 (hard questions at the last deck), the asking prior leaning to the top | l10 0.55, l9 0.15, l8 0.08, l7 0.05, the eight lower classes 0.02125 each; first question at deck N-1 (unit 100) |
| Advanced | no expert track at first: positioning (5.3) starts high | a triangle of three classes either side of l7.5 on a floor of 0.02, normalised: 0.006 (none to l4), 0.058 (l5), 0.16 (l6), 0.263 (l7), 0.263 (l8), 0.16 (l9), 0.058 (l10); first probe at deck 79 (unit 80, the class nearest the 75th percentile; deck 74 lies between l7 and l8) |
| Amateur | positioning starts in the lower middle | the same triangle around l3.5: 0.006 (none), 0.006 (l0), 0.058 (l1), 0.16 (l2), 0.263 (l3), 0.263 (l4), 0.16 (l5), 0.058 (l6), 0.006 (l7 to l10); first probe at deck 40 (unit 41, the 40th percentile, inside the owner's 25th to 50th band) |

**How it is used.** The reporting posterior is flat (4.1, point 2), so **a declaration is never evidence**: an Expert learner whose answers show Hear at the top gets the same 95% as one who declared another level, and the declared level is not shown on the result sheet or stored (it lives for the run only). Only the asking posterior has the prior: the next question is asked at the deck where the asking posterior is closest to one half (5.3, point 2). Expert keeps the expert track, whose questions are fixed by the topics of section 2.1, so the prior changes nothing until the learner leaves the track. **A learner who proves the top class while positioning** (an Advanced or Amateur declarer who passes at deck 79, 89 and 99) is then moved to the expert track for the topics of 2.1 that the positioning has not covered (up to the 15 of section 2.1 in all; his passes at the last decks count as evidence); that cost is not simulated.

**What a right and a wrong declaration cost.** Questions per skill to 95% on a clean learner (hard single-skill pick questions, the recheck rule, then model-only; model of 4.1 and 4.2; an Expert run includes the 3 questions of the closed topic 1 that every non-expert asks first; a learner at the top class of an Expert run is on the expert track, 15 in all). The column "No prior" is the flat baseline, for comparison only; it is not an answer the learner can give:

| True level of the skill | No prior (flat, comparison only) | Expert | Advanced | Amateur | Beginner |
|---|---|---|---|---|---|
| none (knows nothing) | 14 / 8 | 17 / 9 | 20 / 8 | 14 / 6 | **0** (no run) |
| about 30% of the path (A2) | 13 / 10 | 13 / 11 | 19 / 10 | **7 / 6** | 0 |
| about 80% of the path (advanced) | 11 / 10 | 10 / 9 | **7 / 6** | 13 / 12 | 0 |
| the whole path (native) | 15 / 15 (expert track) | **15 / 15** | 6 / 6 positioning, then the track, at most 21 | 11 / 11 positioning, then the track, at most 26 | 0 |

Read the diagonal as the gain (an Advanced declarer who is advanced: 7 against 11, a saving of 4; an Amateur declarer who is A2: 7 against 13, a saving of 6) and the corners as the cost (an Expert declarer who knows nothing: 17 against 14, **3 more**; an Advanced declarer who knows nothing: 20 against 14, **6 more**; an Advanced declarer who is A2: 19 against 13, 6 more; an Amateur declarer who is advanced: 13 against 11, 2 more). The wrong declaration costs a few questions and never a wrong placement, because the reporting posterior is flat. The Beginner answer is the one that saves a whole run, and so the one that can be wrong in a way that costs the learner: a native who presses it is not tested (section 9, answered 2026-11-05). Declared and guessing, the cost rises further (section 5.3, point 8).

### 5. The run: the expert track, then positioning

**5.1 The run in order.**

0. **The declaration** (4.5). Expert, Advanced, Amateur or Beginner. The learner must answer it: there is no skip (owner, 2026-11-05). **Beginner ends here**: nothing is asked and nothing credited; the learner starts from deck 0. Expert goes to step 2, the expert track. Advanced and Amateur go to positioning (5.3) at once, with the asking prior of 4.5; a skill that positioning proves to be at the top class goes on to step 2 for the topics not yet covered.
1. **Preconditions.** If the path is complete to B1 and every deck is downloaded, Verified is possible (section 4.3). Otherwise the run only positions (row m).
2. **The expert track.** Ask the mastery topics in the order of section 2.1, hard questions at the last deck, with checks after a miss. A skill stays on the track while its assurance in the top class stays at 20% or more. It **leaves** when it falls below 20% (for instance after a closed topic 1 or 5, section 3.2) or when two topics are closed; it is then positioned (5.3). A closed topic that is not about meaning (pairs, Say, script, grammar) is a gap and the skill stays.
3. **Target: 95% for every tested skill** (owner, 2026-11-05: "Per skill. Target is 95%"). Each skill is judged alone, on its own assurance. The run **ends** when every tested skill is at 95% or more in its leading class ("Very sure", or Verified where 4.3 is met), and shows the result (5.5). A skill with a closed case or a gap cannot be Verified but has the same target: it needs one more question or so (row c). 80% plays no part in ending a run.
4. **No fixed cap.** The run prolongs itself, as asked, until the targets are met or the learner stops. Every 25 questions it pauses at a checkpoint (5.4).

**5.2 The expert track: cost on a Bengali run (15-question floor).** Each row is from the model of section 4 on the fixed order of section 2.1 (simulated, clean answers apart from the stated miss). The column is the question at which **every tested skill is at 95% or more** (the target of 5.1, step 3), which is also where Verified opens for a skill that meets 4.3. With the 80% stop gone, only this column is left (the old "to 80%" column ran from 12 to 18 and is dropped; the 95% numbers are unchanged except where a row says so).

| Case | To 95% (every skill) | Note |
|---|---|---|
| Clean | 15 | per skill: Read 95% at question 5; Hear 7; Write 7; Say 12; Script 15. The fixed topic order, not the model, sets the 15: the model alone would reach 95% in 9 questions, but Verified needs every topic covered |
| One single-skill slip (a pair with a right recheck) | 16 (18 if the first check is wrong and the second right) | one or two more questions; after a miss, a wrong first check and a right second one, Hear is at 87%, so **one more Hear question** is asked to reach 95% (17 questions then, 18 with that one) |
| One composite slip (both splits right) | 17 | Hear 95% at 12; Script last |
| One gap (one split wrong, e.g. Write) | 18 | the other skills are at 95% by 17; the gapped skill is at 83% after 17 and reaches 98% with **one more Write question** (a tiles item); it is "Very sure" but not Verified (a gap). Under the old 80% stop the run ended at 17 |
| One closed topic of one skill (pairs, Say, script) | about 23 | the skill falls under 20% on the track (a closed pair topic leaves Hear at 16%), so it is positioned (5.3): base 17 for the closed case and its isolating question, then about 6 more for that skill |
| Language with no script topic (Spanish) | 13 | 13 questions in all |
| Reads two scripts (Hindustani) | 17 | a second script topic |
| No mic (Say not tested; K1, K2 become picks) | 13 | Script is at 92% after 12 and needs one more script question |
| At the checkpoint | 25 | about three composite slips, a closed topic and one more slip; the learner then chooses Keep going or Stop here |

**Expert verification fits in 25 questions in every case above except a closed topic, and takes more than 25 only after about five or more composite slips or gaps in one run.** The main downside of the design is on the other side: a learner who is not an expert (section 5.3) spends far more questions than the old fixed battery did.

**5.3 Positioning (D): the fallback for a skill that leaves the expert track.** This path places and never verifies.

1. **Vocabulary only.** Owner: "sample around in the mid section of the app (vocab check only now)". A skill has its own stream of single-skill vocabulary questions: Read (a word in the learner's script or reading, pick its meaning), Hear (an audio word, pick its meaning), Say (the English meaning given, say the word), Write (the meaning given, build or type the word), and for a script its own five levels (the classes of a script are `none` and its five levels, the same model).
2. **Next question: where the evidence is most undecided.** Ask at the deck where P(level at or above that deck) is closest to one half, **in the asking posterior** (4.1, point 2; flat only in the comparison baseline, shaped by the declaration otherwise). In the flat baseline (comparison only), after the last deck has failed this is the middle of the path (the 50th percentile deck); a failure there moves the next probe to the 25th, a pass to the 75th; then the midpoint of what is left, which is the owner's "go back to 25%ile ... if passes, then to 75%ile" and "once they keep passing", as a single rule. With a declaration the first probe is where its prior is split in half (deck 79 for Advanced, deck 40 for Amateur, section 4.5) and the same rule goes on from there; the evidence soon outweighs the prior.
3. **Checks.** Every miss gets the recheck rule of section 1: two more questions at the same deck, other items. Section 9, question 5 asks whether the checks are needed in positioning, because the model uses the next probe as a check anyway (numbers below).
4. **Stop for the skill** when the leading class reaches **95%** (the owner's target), that is when the model is 95% sure the vocabulary level lies in one tenth of the path. It stops as soon as 95% is reached, even inside a recheck (a second miss at deck 0 after the first is not asked when the first already gave 95%). The per-skill cost, from the model on a clean learner (deterministic answers, no slips; single-skill four-option questions, flat start, the 3 questions of the closed topic 1 not counted; the numbers must be reproduced by the implementation's test). The old 80% columns are dropped; the 95% columns are the earlier ones, unchanged:

| True level of the skill | To 95% with the recheck rule | To 95% model-only (no checks) |
|---|---|---|
| none (knows nothing) | 11 | 5 |
| about 30% of the path (A2) | 10 | 7 |
| about 80% of the path (advanced) | 8 | 7 |
| the whole path (a native who left the track) | 6 | 6 |

   Formula: the odds of the leading class after `k` right answers at its edge are `(1/11) x LR^k` with `LR = (1-s)/g`; for 95% they must reach 19 (for the "Sure" line of 80%, 4), so `k = ceil(ln(11 x O) / ln LR)` with O = 19: for a four-option single question (LR 3.8) 5 right answers give 95% (3 would give 80%); for a pair (LR 1.9) 9 (6 for 80%); for a production answer (LR 28 to 30) 2 (2 for 80%). A miss costs 15 times more evidence than a right answer, which is why the first miss at a deck moves the next probe at once and why the checks add more than they need to when the learner is clean.
5. **Percentile and short paths.** The p-th percentile deck is `round(p/100 x (N-1))`; the classes of section 4.1 are the percentile steps. For N of 20 or fewer the classes are min(10, N) equal parts; N of 9 or fewer gives one deck per class; N under 2 asks the one deck twice.
6. **Grammar, once the vocabulary level is fixed.** Owner: "check grammar level". Take the skill the learner reads with (Read, else Hear). `G0` is the last grammar unit at or before its placed deck. Ask one grammar question (type G1) at `G0`: if right, ask one at the grammar unit halfway up between `G0` and the last grammar unit; if wrong (after its checks), one at the unit halfway down between the first grammar unit and `G0`. The grammar level is the highest probe answered right (`G0` if the up probe fails; the first grammar unit if the down probe fails too). That is the two bisections, "once each way", and then stop; at most 2 questions plus their checks (about 2 to 4). Grammar is placed, not given an assurance (two questions cannot reach 80%). A language with no grammar units skips this (row l).
7. **The fixed cost.** The 3 questions already asked on the expert track before the skill left (a closed topic 1: K1, S1, S2) count as evidence. For `k` positioned skills the run costs about `3 + c x k`, with `c` from the table (rule), plus 2 to 4 for grammar: for an advanced learner on four skills 3 + 8 x 4 = 35 (3 + 7 x 4 = 31 model-only); for an A2 learner 43 (31); for a beginner 47 (23); with the 80% stop these were 31, 39 and 51 (the numbers moved with the table: 80% needed fewer questions in some rows and the earlier beginner row used 12 per skill). With a declaration that fits, the 3 are not asked (Advanced or Amateur skip the expert track) and `c` is 7 for an advanced learner who declared Advanced: 4 x 7 = 28. **These exceed 25 for three or more positioned skills; the checkpoint then comes before the end.** The main downside is fatigue. Mitigations (proposals, labelled as such, not simulated for the composites): (a) **floor first:** after a skill's mid probe is closed, probe deck 0 next; two misses there give "none" at 95% (97.8% after a closed mid probe and two floor misses; a closed deck-40 probe and two floor misses give 98.3%): a learner who knows nothing then costs 3 + 5 + 5 = 13 for two skills (an Amateur declarer: 5 each, 10); (b) **pair skills in positioning:** a dictation (Hear plus Write at the same deck) serves two skills at once, up to about 40% fewer questions for those two (not re-simulated for the 95% target); (c) **model-only checks in positioning,** section 9, question 5; (d) at the second checkpoint (50 questions) any skill still under 50% is stated "Not sure yet" and the run offers Stop here first.
8. **Worst case.** Unbounded in principle: answers that contradict each other keep the assurance flat. The model run on a pure guesser (four options, one skill, flat start, positioning only, 4,000 runs per row, the 95% target, answers right a quarter of the time at every deck) takes a median of 14 questions (the guesser is placed at none in 94% of runs), 23 or fewer in 90% of runs, 34 or fewer in 99%, more than 25 in 7% of runs and more than 50 in none of 4,000; model-only: median 7, 99% within 20. With a declaration the same guesser costs more, because the prior sends him to decks where he fails slowly: Amateur median 18 (90%: 25, 99%: 33, over 25: 8%), Expert 21 (30, 40, 25%), Advanced 25 (33, 42, 46%). The old 80% stop gave a median of 11 and 19 at 90% (flat). That is the case the checkpoint is for.

**5.4 The checkpoint (replaces the cap).** After 25 questions asked, and again after every 25 more (rechecks and splits count), the run pauses and shows where the learner is positioned, per skill. Draft wording (section 9, question 2):

> You have answered 25 questions. This is where you stand now. Read: unit 80, very sure. Hear: unit 80, sure. Say: unit 22, not sure yet. Script: known, very sure. If you think you are better than this, keep going. Or stop here and we will place you at these levels.
> [Keep going] [Stop here]

"Positioned at unit N" means the leading class's level plus one: the learner knows up to unit N and learns from N + 1. A skill that has already reached its target (95%, "Very sure") is listed as it will be placed and is not asked any more; the others are still being asked. The learner's declaration is not shown (4.5). Keep going continues the same run (the same posterior, the same questions) to the next checkpoint, and a run that reaches all its targets before 25 never shows one. "Fit again later" is dropped, as the owner asked.

**5.5 What the end of a run, or Stop, writes and shows.** For each tested skill: the placed level (the leading class's level; decks up to it are credited), its assurance name (4.3) with the percentage in the detail line ("about 85% sure"; "Sure" is 80 to 94%, "Very sure" 95% and over), and the Verified mark where 4.3 is met; a skill not tested says "Not tested". Nothing is written until the run ends or the learner stops (a pause saves the run for 7 days under the same deck set and app version, then discards it). A low assurance is shown plainly and kindly ("Not sure yet: this is a first guess"), never as a fail and never as a score out of 100; the sheet shows the same name on the language's skill row. Stop here writes the placement at the assurance it has, and nothing is held against a learner who stops early.

### 6. Deviations (E), planned from the model

Each route is the declaration (4.5), the expert track of section 5.1, positioning (5.3) or both. "To 95%" counts questions until every stated skill is at 95% (the target of 5.1; 80% is no longer a target); "Checkpoint" says whether 25 is passed. Budgets use the recheck rule; the model-only numbers are in 5.3 and 4.5. A row that says "declared" assumes the declaration fits (right); row o is the wrong declaration.

| Row | Trigger | Route | To 95% | Checkpoint | Outcome written |
|---|---|---|---|---|---|
| **a. Native or expert, clean** | all topics right | expert track | 15 (Spanish 13); declared Expert | no | every skill Verified; every deck credited |
| **b. Expert with a slip** | a composite miss with both splits right, or a single-skill miss with a right check | continue | 17 for a composite; 16 for a single (18 if the first check is wrong and the second right) | no | Verified; the slip is only part of the evidence |
| **c. Expert with a gap** (one split wrong, or a closed pair, Say or script topic) | the split names the part | record the gap, ask the isolating question, continue | 18 (the other skills are at 95% by 17); a closed single-skill topic about 23 | no | the gapped skill "Very sure" (98% after one more question; 83% before it) but not Verified; the others Verified; a gap record `{kind: grammar, contrast or script, id, deck}`; the app offers that unit or the pair drill; every deck credited except the gap's first failing unit |
| **d. Native fails early** (a voice, script or recogniser problem makes the first topic close) | a skill falls under 20% on the track | the skill is positioned; a native at the end of the path takes about 6 more questions (to 95%); grammar 2 to 4 | 3 + about 6 per skill | for four or more skills | not Verified; placed near the end with a "Very sure" name; a line says why; a new run starts from the last deck as always |
| **e. Advanced non-native** (about 80% of the path) | topic 1 or 5 closed (both splits wrong) | positioning; declared Advanced starts at deck 79 and skips the track | 7 per skill if declared Advanced (14 for two skills; 18 with grammar; 28 for four); 3 + 8 per skill otherwise (19 for two; 23 with grammar; 35 for four) | for four skills declared, for three or more otherwise | not Verified; placed at the leading tenth (unit 80 in the example) at 95% or more |
| **f. Intermediate (A2)** | same | positioning; declared Amateur starts at deck 40 | 7 per skill if declared Amateur (14 for two; 28 for four); 3 + 10 per skill otherwise (23 for two; 43 for four) | for four skills declared, for three or more otherwise | placed at about a third; learn from the next |
| **g. Heritage speaker** (hears and speaks, cannot read) | the learner marks Read and Write as not known, or K1 closes with K2 right | expert track on audio variants: topic 1 as two K2 questions, topic 3 as "which sentence sounds right", topic 5 as W2 twice, topics 2 and 7 not asked (they need Write); Say as usual | 11 | no | Hear and Say Verified; Read, Write and Script "Not tested"; the sheet proposes them as Learn from the script's first deck and the learner confirms (a run never changes a skill's state); the words are credited for Hear and Say |
| **h. Beginner (A1 or none)** | declared Beginner; or topic 1 closed and the mid probes closed | declared Beginner: **no run**. Otherwise positioning | declared Beginner 0; otherwise 3 + 11 per skill (25 for two skills); with floor first (5.3, proposal) 13 for two; declared Amateur and knows nothing 14 per skill (5 with floor first) | for two or more skills | no placement is written for a declared Beginner: learn from deck 0, nothing credited, the script lessons from the script's first deck with the script test offered as today (4.5). Otherwise not Verified; placed at none ("Very sure"); the script by its own check |
| **i. Partial script** (Hindustani: Devanagari known, Perso-Arabic not) | the learner marks a script as not read | each script is its own skill row with its own questions; the unread one is asked at its floor only (two misses give "none" at 95%; with the rule 3 questions); the word questions use the script he reads | 18 (15 + 3) | no | Devanagari Verified with the words; Perso-Arabic: learn from its first script deck, as the owner described |
| **j. No mic, noisy room, "I can't speak now"** | no recogniser; two "unheard" in a row; the Speak button used | Say is not asked; K1 and K2 become picks (4.3: "Not tested", never a fail) | 13 | no | Say "Not tested"; the others Verified or placed on their own evidence; Say can be run alone later; with no sound, Hear is also "Not tested" and the pair questions become Write tiles (section 9, question 8) |
| **k. Guesser** | answers about as good at depth as at the floor; closed topics in a row; the skills leave the track | positioning (section 5.3) with "I don't know" invited | 37 for two skills in the example below (a median of 14 per skill; declared Expert 21) | yes, at 25 | not Verified; placed at none or at a low class, whatever the lucky answers; a line asks him to use "I don't know" |
| **l. Few decks or no grammar decks** | N under 12, or no grammar family | classes of min(10, N) equal parts; N of 9 or fewer: one deck per class; no grammar family: G1 and G2 use sentence cards with a close wrong form (Toki Pona's particles); no sounds file: pair letters from the decks (section 8) or complex words instead | about as above, minus the grammar step | no | Verified as the baseline if 4.3 is met; a line says what was missing |
| **m. Not complete to B1** | the path is short of the B1 mark | no Verified (that is what verification is); the expert track and positioning run over the decks that exist, the top class being the last deck that exists | as rows a to h | as above | never Verified; placed; the sheet says known skills cannot be Verified until the course is complete |
| **n. Pause or abandoned** | the learner leaves; fatigue after two late misses in an otherwise clean run | the run is saved after every answer; resumed within 7 days with the same deck set and app version, else discarded with no answer carried; a pause is offered, not a fail | a pause costs nothing; the checkpoint counts asked questions | n/a | nothing is written until the run ends or the learner stops |
| **o. Wrong declaration** | the first answers contradict it (an Expert or Advanced declarer fails the first questions; an Amateur or Advanced declarer passes everything) | nothing special: the asking prior is soon outweighed and the run goes on by 5.3; the placement is the reporting posterior's, never the declaration | Expert and none: 17 against 14; Advanced and none: 20 against 14; Advanced and A2: 19 against 13; Amateur and advanced: 13 against 11; Amateur and native: 11, then the track, at most 26 (4.5) | depends on the number of skills | the placement the answers determine; the declaration is never shown nor held against him. The cost is a few questions, not a wrong result |
| **p. Below A1** (the path marks no completed A1 level) | the declaration screen is not shown and no run starts (4.5, options by built level) | none; the learner starts at deck 0 | 0 | nothing written; no Find my level action, no placement button |

**6.2 The guesser guard.** The earlier plan computed that a pure guesser passes a 14-question battery about 1 in 400 (0.578^10 x 0.875^4). Under the new design a guesser can pass a question by luck or by two lucky split questions, and must also lift every skill to 95%, which the model treats as strongly as any other evidence. Simulated with the parameters of 4.2 (60,000 runs, answers independent, four-option guesses right a quarter of the time, a pair a half, production answers 3%, one skill at a time, the fixed order of 2.1, checks and splits as in 3.1, no extra questions):

| Skill | Chance a pure guesser reaches 95% (the fit target and the Verified level) after the 15-question list | Chance he reaches 80% (the "Sure" line) |
|---|---|---|
| Read | 0.05% (about 1 in 1,900) | 0.19% |
| Hear | 0.06% (about 1 in 1,700) | 0.12% |
| Write | 0.04% (about 1 in 2,600) | 0.10% |
| Say | 0.02% (about 1 in 4,300) | 0.04% |
| Script | 0.19% (about 1 in 540) | 0.9% |
| every skill together | effectively never (none in 60,000) | |
| no mic: Read / Hear / Write | 0.13% / 0.12% / 0.03% (about 1 in 790, 830, 3,300); Script cannot reach 95% on the list alone | |

The 95% target does not change these figures (the 95% column was already the Verified level; the 80% column now only draws the "Sure" line). A declaration does not change them either: the reporting posterior is flat (4.5), so a guesser who declares Expert is as unlikely to be Verified as one who declares another level. These are lower than the old 1 in 400 for every skill except Script, because composites need several parts at once and production answers (K1, K2, Say) are almost impossible to guess. The assumptions are the weakest part: the independence of answers, and a pure guesser (a half-knower is not computed). Also, a run that reaches 95% only through slips reaches a lower number than a clean one (a K1 miss and two right splits leave Script at 94%, under 95%), so the model asks more before it verifies. **Proposals to bring it down, with the main downside:**

- **A third script question** (a rarest-sign read at a different sign class): divides the Script figure by about 2 to 4; costs 1 question on a clean run (16 in all). Downside: a longer run for scripts only.
- **More pairs** (a third pair question): Hear 1 in 1,700 becomes about 1 in 1,900; weak per question because a pair is a coin toss, and it does nothing for Read. Downside: a pair is a poor use of a question.
- **A sentinel block** (two easy deck-0 to 4 items): does not lower a pure guesser's odds (he guesses easy items at the same rate); it only helps against a learner who memorised the hard items. Downside: it costs 2 questions and adds little. Not recommended.
- **A second pass on suspicious runs** (any pass reached by a slip): already built into the model, since a slip lowers the posterior and the run asks more; no separate rule is needed.

Accepted by the owner on 2026-11-05 (section 9): keep the model as it is and take the third script question; the rest of the table is already below 1 in 500.

### 7. Worked examples (F) (N = 100, Bengali, B1 complete)

Assurance figures are from the model of section 4 (simulated). Skills in examples 1 to 3: Read, Hear, Say, Write and Script. `ok` is right. "Name" is the word of 4.3. Every run opens with the declaration (4.5), shown as question 0 and not counted. The target of every skill is 95% (5.1).

**Example 1: a native, clean.** Declaration: **Expert** (right). Asking prior leans to the top; the expert track starts at deck 99.

| # | Topic | Item | Skills | Result |
|---|---|---|---|---|
| 1 | 1 K1 | a nine-word sentence of deck 99 in Bengali script only; say its meaning in English | Read, Script | ok |
| 2 | 1 K2 | another long sentence by audio only; say its meaning in English | Hear | ok |
| 3 | 5 W1 | the longest inflected word of deck 99, written; pick its meaning | Read | ok |
| 4 | 5 W2 | another, heard; pick its meaning | Hear | ok |
| 5 | 3 G1 | case endings, hardest form (deck 94): pick the form for the blank | Read | ok |
| 6 | 3 G2 | conditional clause: reorder the tiles | Write, Read | ok |
| 7 | 2 R1 | hear a long sentence, build it with tiles | Hear, Write | ok |
| 8 | 2 R2 | English meaning of a long sentence, build it with tiles | Write | ok |
| 9 | 4 | pair: aspirated against unaspirated (খাল or কাল) | Hear | ok |
| 10 | 4 | pair: dental against retroflex (তাল or টাল) | Hear | ok |
| 11 to 13 | 6 | three English meanings of short late words; say each | Say | ok x3 |
| 14 | 7 | read a word with a rare conjunct; pick its meaning | Script, Read | ok |
| 15 | 7 | build a conjunct word with tiles | Script, Write | ok |

Result: 15 questions, no miss. The 95% target was met at question 15 (every topic covered). End: Read 100%, Hear 100%, Say 100%, Write 100%, Script 99%: every skill **Verified**; every deck credited. The run ended on its own, with no checkpoint. By skill, the question at which 95% was reached: Read 5, Hear 7, Write 7, Say 12, Script 15. The declaration was not shown and was not part of the 99%: a learner who declared another level gets the same run.

**Example 2: a native with one slip.** Declaration: **Expert**. The same as Example 1, except that the recogniser misheard the English answer at question 2.

| # | Item | Result |
|---|---|---|
| 1 | K1 (Read, Script) | ok |
| 2 | K2 (Hear): say a heard sentence's meaning in English | miss (the recogniser wrote a different English word) |
| 3 | split S1: another long sentence by audio, pick its meaning | ok |
| 4 | split S2: a short word heard, pick its meaning | ok: slip, forgiven |
| 5 to 17 | W1, W2, G1, G2, R1, R2, two pairs, three Say, script read, script write (Example 1, rows 3 to 15) | ok x13 |

Result: 17 questions (15 plus the 2 splits); 95% at question 17. Hear was 12% after question 4 and reached 95% at 12. End: Read 100%, Hear 97%, Say 100%, Write 100%, Script 99%: every skill **Verified**. The miss is part of the evidence and is not shown.

**Example 3: an expert failing one topic (composite split).** Declaration: **Expert**. Hear and Write were asked together in R1.

| # | Item | Result |
|---|---|---|
| 1 to 6 | K1, K2, W1, W2, G1, G2 | ok x6 |
| 7 | R1 (Hear, Write): hear a long sentence, build it with tiles | miss |
| 8 | split S1: a short word heard, pick its meaning (Hear only) | ok |
| 9 | split S2: its English meaning given, build a short word with tiles (Write only) | miss: a gap in Write (spelling); Write falls to 35% |
| 10 | R2 (Write): English meaning of a long sentence, build it with tiles | ok |
| 11 to 12 | two pairs | ok x2 |
| 13 to 15 | three Say | ok x3 |
| 16 | script read | ok |
| 17 | script write | ok |
| 18 | one more Write question, a tiles item (the 95% target for the gapped skill) | ok: Write 98% |

Result: 18 questions. Hear 97%, Read 100%, Say 100%, Script 99%: **Verified**. Write 98%: **Very sure**, but not Verified, because a gap in the Write part was found (the sign class of the miss, recorded as `{kind: script, id, deck}`); the app offers the unit. The gap does not remove Verified from the other skills (the owner's rule: verified is per skill). Write was at 83% ("Sure") after question 17; under the 95% target the run asks the one more Write question (under the old 80% stop it ended at 17).

**Example 4: an advanced non-native, placed by positioning (Read and Hear known).** True level: about deck 80. Declaration: **Advanced** (right). No expert track: positioning starts at deck 79 (unit 80), where the asking prior is split in half; each skill has its own stream.

| # | Probe | Result |
|---|---|---|
| 1 | Hear, deck 79 (unit 80) | ok |
| 2 to 4 | Hear, deck 89 | miss, miss, miss (the recheck rule): case closed |
| 5 to 7 | Hear, deck 79 | ok x3: Hear at deck 79 and 96% (the 95% target) |
| 8 | Read, deck 79 | ok |
| 9 to 11 | Read, deck 89 | miss x3 |
| 12 to 14 | Read, deck 79 | ok x3: Read at deck 79 and 96% |
| 15 | grammar: the last grammar unit at or before deck 79 (deck 77) | ok |
| 16 to 18 | grammar: the unit halfway up (deck 87) | miss x3: grammar level stays at deck 77 |

Result: 18 questions, no checkpoint (under 25). Read: unit 80 (deck 79), **Very sure** (96%); Hear: unit 80, **Very sure** (96%); grammar placed from the unit after deck 77 (not assured); not Verified; the learner is placed at 79 and learns from deck 80. Without a declaration (the flat baseline, for comparison only) the run is the expert track first: 3 + 8 + 8 + grammar 4 = 23, against 18 here (model-only: 3 + 7 + 7 + 2 = 19 against 6 + 6 + 2 = 14).

**Example 5: a learner who knows nothing and declares Amateur (Read and Hear known).** Declaration: **Amateur** (wrong: he knows nothing). The asking prior is centred on deck 35, so the first probe is deck 40.

| # | Probe | Result |
|---|---|---|
| 1 to 3 | Hear, deck 40, with its two checks | "I don't know" x3 |
| 4 to 6 | Hear, deck 30 | x3 |
| 7 to 9 | Hear, deck 20 | x3 |
| 10 to 12 | Hear, deck 10 | x3 |
| 13 to 14 | Hear, deck 0 | x2: none at 99.6% (the third question is not asked: 95% is already reached) |
| 15 to 25 | Read, the same probes: decks 40, 30, 20 (three each), deck 10 (two) | x11: **checkpoint** at 25 (Hear none, very sure; Read none, not sure yet, 49.9%) |
| 26 to 28 | Read, deck 10 (one more), deck 0 (two) | x3: Read none at 99.6% |

Result: 28 questions, one checkpoint at 25 (a learner who chose Stop here is placed at none, Hear very sure and Read not sure yet). Placed at none: learn from deck 0; the script by its own check. Not Verified. A learner who had **declared Beginner** would have had no run and the same start. Without a declaration (the flat baseline, for comparison only) the closed topic 1 is asked first: 3 + 11 + 11 = 25. With floor first (5.3): 3 + 5 + 5 = 13, or 10 declared Amateur.

**Example 5b: declared Beginner.** Declaration: **Beginner**. The run does not start: no question, no credit, no placement written. The language is added with the skills as the learner marked them (Learn by default); the script lessons start from the script's first deck, and the script test is offered as it is today if he reads the script through another language. The sheet says nothing about a level. He can open Find my level again later (section 9, answered 2026-11-05).

**Example 6: a heritage speaker (Hear and Say known; Read, Write and Script not marked).** Declaration: **Expert** (right for his speech).

| # | Item | Result |
|---|---|---|
| 1 to 2 | topic 1: two K2 questions (audio, say the meaning in English) | ok x2: Hear 99% |
| 3 to 4 | topic 5: W2 twice (heard complex words, pick the meaning) | ok x2 |
| 5 to 6 | topic 3: "which of two sentences sounds right", two families | ok x2 |
| 7 to 8 | topic 4: two pairs | ok x2 |
| 9 to 11 | topic 6: three Say | ok x3: Say 72% after the first, 99% after the second |

Topics 2 and 7 are not asked (they need Write). Result: 11 questions. Hear 100%, Say 100%: **Verified**; Read, Write and Script: **Not tested**; the sheet proposes them as Learn from the script's first deck and the learner confirms.

**Example 7: a guesser (Read and Hear known; right a quarter of the time at four options).** Declaration: **Expert** (wrong: he knows nothing; the prior sends the first probes high).

| # | Probe | Result |
|---|---|---|
| 1 to 3 | K1 (says nothing), S1, S2 | miss x3: topic 1 closed; both skills leave |
| 4 to 6 | Hear, deck 79 (the asking prior's first probe) | miss, miss, ok (lucky) |
| 7 to 8 | Hear, deck 40 | miss, ok (lucky) |
| 9 to 11 | Hear, deck 20 | miss x3 |
| 12 to 14 | Hear, deck 10 | miss x3 |
| 15 to 20 | Hear, deck 0 | miss, ok, ok, ok (three lucky in a row, weak evidence at the floor), miss, miss: Hear none at 98% |
| 21 to 23 | Read, deck 79 | miss x3 |
| 24 to 25 | Read, deck 40 | miss, miss: **checkpoint** at 25: Hear none, very sure (98%); Read none, not sure yet (20%) |
| 26 | Read, deck 40 | miss |
| 27 to 29 | Read, decks 20 and 30 | ok (lucky), miss, ok (lucky) |
| 30 to 32 | Read, deck 20 | miss x3 |
| 33 to 35 | Read, deck 10 | miss x3 |
| 36 to 37 | Read, deck 0 | miss x2: Read none at 99.6% |

Result: 37 questions (3 + 17 for Hear + 17 for Read; a median of 14 per skill is typical, 21 declared Expert). Not Verified; placed at none on both, "Very sure" only because the answers support it; a line asks him to press "I don't know" instead of guessing. Lucky answers cost him questions, not credit, and the declaration gave him none: it cost him about 7 more questions per skill than the flat baseline (21 against 14, 4.5).

### 8. Minimal-pair data today, and what is missing

What the app has: a `<lang>-sounds.yaml` for ten languages (as, bn, gu, hi, ja, kn, ko, mr, te, zh: 4 to 9 contrasts each, as letter pairs, with `within_word` for a sign added at the end of a word). The speaking drill's feedback uses it (ADR-0015). Each contrast id is the tag of a language's sound-differences deck. A minimal-pairs drill, `PairDrill`, exists but is built on fixture data and shown disabled until #31 gives it an ADR, deck data and a device check; nothing in a live session builds it. `alike_warning.dart` already finds sound-alike and look-alike cards for a review.

What is missing:

1. **Spanish and Toki Pona have no sounds file** (both are complete to B1 and so verifiable). Spanish has few contrasts that matter (r against rr, for example); Toki Pona almost none.
2. **A pair list of actual words.** The file gives letter pairs, not word pairs. A pair question needs two real words of the language's decks that differ by exactly one swap; they have to be found by swapping letters in the decks' words (a one-off tool over the decks, by the plan's rule of tools written by the tools, not by hand) and kept as a derived list, or computed on the device from the deck's cards.
3. **Tone, length and stress.** Chinese and Japanese contrasts include tone and vowel or consonant length, which are not a letter swap; the file's form cannot say them.
4. **Audio.** The pair needs the two words to sound different. The system voice (ADR-0002) may flatten an aspirated or retroflex contrast on some phones, in which case a native would fail a correct answer. A check on a device, and a fallback to Write tiles when a pair's audio is not trusted, are needed.
5. **A difficulty per pair** (a pair of two common words against two rare ones); today a pair's difficulty can only come from the closeness `c` and the deck depth.

### 9. Part 3: open questions for the owner

Each open question has the default this plan assumes, in brackets, and the main downside. The owner's answers of 2026-11-05 are in the first table; the questions still open are renumbered from 1 (the old number is in brackets).

**Answered 2026-11-05 (owner: "All okay").** The sections above carry each answer.

| Question (old number) | Answer, decided 2026-11-05 | Where it lives |
|---|---|---|
| The declaration: four answers and their wording (2) | Owner: "All okay, but the skip is for what? It starts from the beginning. Just the 4 options." Four answers, no Skip, and the question must be answered: Expert "I use it easily"; Advanced "I follow most of it and can say what I need"; Amateur "I know some words and phrases"; Beginner "I am starting from nothing". | 4.5; 5.1 step 0; row p of section 6 removed |
| One declaration per language (17) | Owner: "All okay." Once per language, not per skill. | 4.5 |
| Beginner: what it skips, and the script (18) | Owner: "All okay." Beginner skips the run and writes nothing; the skills stay as marked; Find my level can be opened again later, and the script test is offered as it is today. | 4.5; example 5b; row h |
| The starting priors (16) | Owner: "All okay." The priors of 4.5 as written. | 4.5 |
| Three-question floor per skill for Verified (7) | Owner: "All okay." | 3.3; 4.3 |
| Say by the meaning of a word (8) | Owner: "All okay." Leave Say unverified on a clearly fluent rejected attempt, graded by the taught form plus listed synonyms. | 2.1 topic 6; 2.4 |
| A third script question (6.2 proposal) | Owner: "All okay." Taken. | 6.2 |
| Slip cost (5) | Owner: "All okay." A single-skill slip costs 1 question (2 if the first check is wrong); a composite costs 2. | 1; 3.2 |
| Floor first for a beginner (11) | Owner: "All okay." Probe deck 0 after the mid probe is closed. | 5.3 point 7 |
| Stopping with low assurance (12) | Owner: "All okay." Place at the leading class's level, whatever its assurance, and show the name. | 5.5 |
| Two runs that disagree (13) | Owner: "All okay." For the skills the later run tested, its placement replaces the earlier one; the sheet asks before a lower placement drops credit. | 4.4 |

**Open questions (renumbered 2026-11-05; old number in brackets):**

1. [was 1] **The model's parameters and prior (4.1, 4.2).** [flat prior over twelve classes; slip 0.05 for a single pick, 0.10 for a composite or an English production, 0.15 for Say; guess 0.25 at four options, 0.5 at a pair, 0.03 for a production, 0.05 and 0.10 for tiles; a composite miss at half weight] Downside: there is no population data, so these are set by feel; wrong values make the run too trusting (a low slip rate makes one miss costly) or too slow. They can be tuned later if the app records, on the device, how often each question kind is missed.
2. [was 3] **Checkpoint wording and repeats (5.4).** [the draft of 5.4; every 25 questions, repeated] Downside: a learner who keeps going to 75 questions is tired; the plan does not stop him ("they can keep going or stop"). With the 95% target on every skill the checkpoint is now reached more often: three or more positioned skills cross 25 (5.3, point 7).
3. [was 4] **What "positioned" shows per skill.** [the unit and a name (Not sure yet, Fairly sure, Sure, Verified), with the percentage only in the detail line] Downside: a name hides precision; the percentage invites "should I be at 95?". Showing only the percentage reads like a score, which the owner earlier did not want (never shaming a low result).
4. [was 6] **The mastery topic list (2.1):** long-sentence recognition, long-sentence reproduction, late grammar, minimal pairs, complex words, Say by word meaning, script read and write, 2 questions each, Say 3. [as listed] Downside: seven topics set a floor of 15 (13 without a script) however good the learner is; a shorter list would be quicker but let a real gap through.
5. [was 9] **The recheck rule in positioning (5.3).** [apply it everywhere: two more questions at the same deck after a miss] Downside: it costs about 2 questions per miss, and a clean beginner pays 11 per skill instead of 5 (an advanced learner 8 instead of 7) to reach 95%. Model-only checks are about 40% shorter but let one slip move the next probe.
6. [was 10] **What "failing 2 in a row" means in a topic.** [a closed case: a miss and both checks wrong] Downside: a stricter reading (a miss and one wrong check) fails honest slips more often.
7. [was 14] **Evidence carried across runs.** [dropped, 4.4] Downside: a second run starts from a flat prior and repeats questions the first already answered; the owner dropped "fit again later" so this is not a cost the design needs. If wanted, earlier evidence enters as the prior and nothing else changes.
8. [was 15] **Questions kept from the earlier list, still open.** (a) Is "I don't know" a miss? [yes] (b) Minimal pairs for languages without a sounds file (Spanish, Toki Pona) and for tone: [letter-swap pairs from the decks for Spanish; complex words for Toki Pona; leave tone out] (c) Non-prefix and per-skill credit (gaps as exceptions; credit for a heritage speaker per skill by a proposal sheet; `placedDeckIds` is a set so the first looks possible, per-skill credit is not in the model). (d) Pair audio: if the system voice flattens a contrast, pairs go to Write tiles [after a device check per language]. (e) Does a self-declared level seed the search? **Answered 2026-11-05: yes** (4.5; seeds the asking only, never evidence) (f) Resume window of 7 days. (g) The learner's own review history shortens the run, only for cards with high stability and only as skipped evidence [yes]. (h) One Verified label for a native and a B1 learner alike ("Verified to B1") [yes]. (i) The weights of the hardness score `H` (0.35, 0.30, 0.35) [as written]. (j) One run for all known skills [yes; with a checkpoint every 25 the run is as long as it needs]. Downside of each: as in the page's earlier text (history: `git show 16dc8d22:wiki/Plan-Placement-V2.md`).
9. **Wording of the Expert label.** "I use it easily" was decided for Fluent; it is kept for Expert as the owner decided the names, but it may read as a claim of fluency. [keep the wording] Downside: a learner who takes "use it easily" as fluency chooses Expert for the wrong reason; the alternative is a new line of wording the owner must approve.
10. **What a path below A1 shows.** [nothing: no declaration, no run, no button] Downside: a learner may think the feature is missing; a plain line that placement comes once A1 is built is the alternative, and its wording would need approval.
11. **The expert track in row m.** Expert is offered only for a path built to B1, so a language short of B1 starts the expert track only through a top-class position (step 0). [yes] Downside: a strong learner of a half-built path reaches fewer decks than row m's wording suggests; the alternative is to offer Expert earlier, which the owner's rule does not allow.

**Earlier open questions, now answered or changed.**

| # | Earlier question | Now |
|---|---|---|
| 1 | "Last two perfect" presumes expert; two questions of different kinds | changed by the owner: no presumption; every mastery topic is covered (section 2) |
| 2 | Battery size 10 to 14 and cap 25, `10 + 2k` for `k` skills | changed: a floor of 15 for a clean expert (13 without a script topic) and an adaptive length; composites cover several skills, so `k` no longer adds questions; 25 is a checkpoint |
| 3 | Is "I don't know" a miss | unchanged (8a) |
| 4 | Pairs without a sounds file | unchanged (8b) |
| 5 | Non-prefix credit, per-skill credit | unchanged (8c) |
| 6 | Pair audio | unchanged (8d) |
| 7 | Level-mark ladder before halving | replaced by positioning (5.3): halving by the evidence, no ladder |
| 8 | A self-declared level seeds the search | **answered 2026-11-05: yes**, as a first question that seeds only the asking prior, never evidence (4.5; answered in section 9) |
| 2, this section | 80% and 95% per skill, or for all skills together | **answered 2026-11-05: per skill, target 95%** (5.1); 80% is the lower edge of the label "Sure" only |
| 9 to 14 | resume window, answer-speed detector (off), history, one Verified label, weights, one run per skill | unchanged except that the cap in them is now the checkpoint (8f to 8j) |
| 15 | Speak and other dialects | now answered in section 9 (Say by word meaning) |
| earlier 1 to 8 (the first walk-back plan) | serious flaw as two misses, 3 misses stop the run, verified in part, 25 runs out | superseded by the recheck rule (section 1), assurance (section 4) and the checkpoint (5.4); "three closed cases stop the battery" is dropped, because the model and the 20% leaving rule do the same job |

### 10. Risks

- **A native fails a correct answer because of the system voice** (a flattened contrast) or because the recogniser rejects a good English or Say answer. Downside: a failed verification feels like an insult; mitigated by the Write fallback, the split (a recogniser miss followed by two right splits is a slip), and the isolating question after a closed case.
- **Hard items are hard for the wrong reason** (a rare word that is not hard grammar). Downside: a native can miss a word he never met; mitigated by weighting form and closeness, and by the checks.
- **Hardness is a guess without population data,** and so are the model's parameters (question 1). Downside: early runs may be too easy, too hard, too trusting or too slow.
- **A positioning run is long.** Downside: three or more skills at 8 or more questions each (95% target) cross 25 and are tiring (5.3, point 7); mitigated by the declaration (Advanced and Amateur skip the expert track), the checkpoint, the floor-first proposal and model-only checks; the learner can always stop.
- **A wrong declaration costs questions.** Downside: Expert and knows nothing costs 3 more per skill, Advanced and knows nothing 6 more (4.5); never a wrong placement, because the reporting posterior is flat. The costliest wrong answer is Beginner by an expert, which skips the run.
- **No evidence is stored across runs.** Downside: a second run repeats the work of the first; accepted because the owner dropped "fit again later".
- **A run that stops at the checkpoint has low assurance for some skills.** Downside: the placement can be off by a tenth of the path; shown honestly as "Not sure yet" or "Fairly sure", never as a fail.
- **The model assumes knowledge is roughly monotone along the path** (what is known at deck d is known below it). Downside: a heritage speaker or a script gap breaks it; the decoupled-skill rows (g, i) handle those, not a longer search.
- **The battery tests grammar through the deck's own sentences.** Downside: a language with thin grammar decks gets weaker grammar evidence (row l).
- **Say fails a fluent speaker of another dialect.** Downside: a correct answer is failed by the recogniser; section 9 (answered 2026-11-05) fixes how Say is graded.

### 11. Step 2: the question generators, the data audit and the gaps (built 2026-11-05, not wired)

Status: built in `lib/core/placement/`, no screen uses it and `lib/app/placement*.dart` is unchanged. Not run locally; CI runs the tests (`test/placement_question_builder_test.dart`).

**What it does.** `QuestionBuilder.build(request, asked:, failed:)` takes a `PlacementQuestionRequest` of the run controller, the learner's language as plain data (`PlacementLanguageData`: the word decks in path order, each with the path unit's grammar families, the script check's letters, joined forms and words, the sounds file, the level marks, the cards with high stability) and the ids already asked, and returns a `QuestionOutcome`: `QuestionBuilt(GeneratedQuestion)` or `QuestionUnavailable(reason)`. It is pure and deterministic: the request's `shortlistPick` and the builder's seed fix every choice (a stable string hash, not `String.hashCode`).

- **A question** (`GeneratedQuestion`): the prompt kind and text (never a reading for K1), the audio (the system voice's text, or the card's recording; `trusted: false` for pair audio), the options and the right index or the accepted answers or the tiles, the two split requests of a miss, the item ids for the no-repeat set (the cards used, `family:<id>` for each word family, `concept:<grammar family or sound contrast>`), and the difficulty fields (deck, depth, form, closeness, score, level A1 to B1, "short of long"). Named `GeneratedQuestion` because `PlacementQuestion` is already the existing flow's class in `lib/app/placement.dart`.
- **Hardness** (`item_picker.dart`): `H = 0.35 d + 0.30 f + 0.35 c` as 2.2 says; the 80 candidates of highest depth and form get their closeness measured (a bound on cost); the five hardest are the shortlist and the request's pick chooses among them. Form: 1 for an inflected form (a base whose text differs from the word), a compound, an idiom or a sentence of a grammar unit; else the length as a share of the shorter items of the deck; plus 0.2 for a note that names a stem. Closeness: 1 for a sounds-file swap, else one minus the edit distance of the readings plus 0.2 base, 0.1 part of speech, 0.1 tag, capped at 1.
- **Distractors** (reusing `rankDistractors`): the same deck first, then the neighbouring decks nearest first, only cards of the same kind (a sentence is never offered for a word), never a card that shares a meaning, a synonym's meaning or a spelling with the answer, never a card already asked (relaxed only if the pool is too small), and within a deck the cards that share most with the answer first.
- **Pool**: the request's deck, then the last two decks, then the last quarter, then the path up to the deck (2.2); a probe widens on both sides instead.
- **Topics built**: 1 (K1 written only in the script, K2 heard, English or a pick), 5 (W1, W2), 3 (G1 blank, G2 tiles, G3 for a learner who only hears), 2 (R1, R2), 4 (P1, P2 and the Write tiles of the same contrast), 6 (Say, with the accepted answers), 7 (script read, script write, the extra script question), the splits S1 and S2 of K1, K2, W1, W2, G1, G2, R1, R2, the isolating questions, and the positioning probe, top-up and grammar probe.

**The audit: what data exists today for each topic.**

| Topic, kinds | Data used (exists today) | Reuse | What is missing (gap number) |
|---|---|---|---|
| 1. K1, K2 | sentence cards (`pos: phrase`, `rearranges`), `native` and `alt_native` for the English answer, `audio` or the system voice | `Card.rearranges`, `Card.meanings`, `rankDistractors` | a long-sentence flag (6); a sentence of 8 words in most languages |
| 2. R1, R2 | the same sentences, `Card.tilesOfSpelling` (the drills' own tiles), `words` for unspaced scripts, `confusables` for close wrong tiles | the review's rearrange tiles, `TileQuestion` logic | 6 |
| 3. G1, G2 | the path's `grammar:` topics per unit (every path has them), the unit's decks, sentence `bases`, `confusables` | `CoursePath`'s `PlanUnit.grammar` | the form a sentence tests is not tagged (8) |
| 4. P1, P2 | `<lang>-sounds.yaml` letter pairs for 10 languages, `SoundContrasts.between`, the deck's words | the speaking drill's contrast check (ADR-0015) | 1, 2, 3, 4 |
| 5. W1, W2 | `bases` (every card of es has them, so "inflected" needs a base that differs from the word), length, tags, notes | `distractors.dart` sources | no compound or idiom tag (9) |
| 6. Say | `target`, `alt_target`, `target_scripts`, `synonyms` (a card-data field, #513), `ipa` for the syllable count | `Card.acceptedAnswers` ideas, the speaking grader | 5 |
| 7. Script | the script check's letters, joined forms and words (`scriptDeckKind`, `scriptWordsOf`, `aksharasOf`) | the script check's data | 10 |
| Probes, top-ups | the same cards at one deck | as above | none |

**The data gaps, the fallback built for each, and the data change that would remove it** (no deck content is changed in this PR).

1. **No sounds file for Spanish and Toki Pona** (and for every language but the ten). Fallback: with `pairsFromDecks` (Spanish) a pair is two words of the decks that differ in one letter, each such swap being a contrast of its own (`sound:swap:x-y`), **and only where that swap is in the language's explicit list of letter swaps that are two sounds** (`deckPairSwapsByLanguage`; Spanish has p/b, t/d, m/n, n/ñ, l/r and the vowels): an accent (`si`/`sí`, `el`/`él`), a silent letter (`ola`/`hola`), `b`/`v` and `ll`/`y` are never a pair, because either word could be the one heard; with it off (Toki Pona) the builder says `noSoundsFile` and the run asks a heard complex word instead (8b). Change: a sounds file for each (Spanish has few contrasts the spelling shows), or a derived pair list (2).
2. **No list of real word pairs, only letter pairs.** Fallback: the pairs are computed on the device from the deck words by swapping each sounds-file pair (a word is a pair when the swapped spelling is another word of the decks up to the asked deck); one partner per card, the first by id. Change: a tool-generated `<lang>-pairs.yaml` of word pairs with the contrast id and a difficulty per pair (5).
3. **Pair audio is not trusted** (the system voice may flatten a contrast). Fallback: every pair carries `audio.trusted = false` and a `tilesFallback` (the English meaning, the letters of one word and the other word's letter among them); with `requireTrustedPairAudio` the builder says `pairAudioUntrusted` and the controller asks the Write tiles. Change: a device check per language that sets `pairAudioTrusted`.
4. **Tone, length and stress are not letter swaps** (Chinese, Japanese, Korean). Fallback: left out, as 8b says; vowel length is a letter swap and works. Change: a pair form that names two pronunciations, not two spellings.
5. **No synonym list worth the name on the cards.** `synonyms` exists on a card but the English layers fill it for a handful (about 1 in Bengali, 26 in Hindustani, 47 in Telugu, none in Spanish or Toki Pona). Fallback: accepted answers are the taught form, its alternatives and spellings, the listed synonyms, and the taught form of every other card of the course whose first meaning is the same. Change: fill `synonyms` for the short words of the late decks.
6. **No long-sentence items flagged, and few sentences of 8 words** (counted in words of the target: Bengali 2 of 3,882 cards, Hindustani 14, Telugu 0, Spanish 116, Toki Pona 17; an unspaced script without `words` counts one word and is not a sentence). Fallback: 8 words or more if the window has them; else the longest sentences of at least 4 words, scored by their length over 8, and the question is flagged `shortOfLong`; with none, `noSentences`. Change: a `long` flag or a length in syllables or aksharas on sentence cards, and `words` on every unspaced sentence.
7. **No per-card hardness.** Fallback: computed on the spot from depth, form and closeness (no miss-rate term, as 2.2 says). Change: a miss rate recorded on the device, or a `difficulty` field.
8. **Grammar concept families are not tagged on cards**; they exist as the path's `grammar:` topics per unit. Fallback: the family is the path topic, the sentence is a card of the family's unit, the blanked form is a word the sentence lists as a base whose text differs from it, the wrong forms are the card's `confusables` words, then forms of the family's other sentences; fewer than three wrong forms drops the card. Change: tag each grammar sentence with `family`, the form tested and its wrong forms.
9. **No compound or idiom tag**, and every card of some languages has identity bases. Fallback: the `compound` and `idiom` tags and `pos: idiom` are read where they exist; else length. Change: tag them.
10. **The script check's data lives in `lib/app`** (it needs `DeckEntry`). Fallback: the builder takes plain `PlacementScriptData` (letters, joined forms, words with their spelling); step 3 maps `scriptDeckKind` and `scriptWordsOf` to it. The rarest sign is the least frequent akshara among the script's words, a conjunct counting most. Change: none needed, except a flag for the rare signs in the script guide.
11. **G3 for a learner who only hears** has no real grammar error to offer. Fallback: the wrong sentence is the right one with its words out of order. Change: a wrong form per grammar sentence (8).

**The run controller's hook.** `PlacementRun.markUnavailable(reason)` records that the next question could not be built (the state is the answers and these notes, so a run is still rebuilt from them). The plan's fallbacks: a minimal pair with `noSoundsFile` or `noPairFound` becomes a heard complex word (`W2b`); with `pairAudioUntrusted` or `noAudio` it becomes Write tiles (Hear is then not covered); any other base question is left out, its skills are not covered and so not Verified (4.3 c); a split or a recheck that cannot be built is dropped and the miss stays as evidence, **unresolved** (the plan was silent; decided in review of the step-2 pull request): the skills of that question cannot be Verified in this run (`PlacementRun.unresolvedSkills`), because a miss that no check settled is not proof; a probe or a top-up that cannot be built leaves its skill out of the run; the grammar bisection ends (a later probe that cannot be built keeps the level the earlier probes found). `PlacementQuestionRequest` gained `originVariant` (set on a split and on an isolating question: the base question it checks); the caller hands that question back to `build(failed:)`, and a split or an isolating question that needs its word, family or contrast is unavailable (`noOrigin`) without it, never asked about some other item. Both options of a sentence-order pair (G3, R2's second split) are written the same way, from the sentence's tiles, so that nothing but the order shows the right one.

**Not done in step 2.** Loading the learner's decks, the path, the script check's data and the review history into `PlacementLanguageData`, and showing and grading a question, are step 3. The existing `lib/app/placement*.dart` flow is unchanged and the CHANGELOG has no line, because nothing the learner sees has changed.

### 12. Steps 3 and 4: the declaration and the run, as built (2026-11-06)

Status: built and wired into the skills sheet's Find my level row (`LanguageSkillsSheet._findLevel`). The old `PlacementPage` is unchanged and still serves the first launch and the language picker. Not run locally; CI runs the tests (`test/find_level_*_test.dart`).

**What a learner sees.** The row reads "Verify what you know" while a skill marked Know is not Verified yet, then "Fit my level" (or "Find my level" before a level was found). A tap downloads every deck of the language if any is missing, then asks the declaration, then runs. Below A1 the row is not shown at all (open question 10: nothing).

**Where it lives.** `lib/core/placement/`: `declaration_options.dart` (the options by built level), `skills_in_play.dart` (which skills a tap checks), `placement_session.dart` (the run controller and the question builder together; its state is its events, so a paused run is replayed), `saved_run.dart` (the paused run, 7 days, the deck-set key). `lib/app/placement_run_setup.dart` reads a course into `PlacementLanguageData` and writes the outcome. `lib/features/placement/find_level_*.dart` are the screens. `B1Progress.builtLevel` says how many levels are written to their end (0 to 3).

**Choices the plan was silent on** (the simplest option was taken):

1. *Built level* is read from the catalog's `B1Progress` (a level counts when the path marks it and no unit up to it is still to be written), so it is known before the decks are downloaded.
2. *Skills in play.* Know skills that are not Verified; when every known skill is Verified, the Learn skills; else the known skills again. Speak is Say, Read and Write as marked, and the Read of a script the course has its own decks for is also that script's skill (Hindustani's two are `script` and `secondScript`). Hear is left out of a run when there is no voice (so a skill that cannot be heard is not failed).
3. *Microphone.* The run uses it only when the recogniser works for the language and for the learner's own language (long sentences are said back in it). "I can't speak now", or two listens in a row that heard nothing, gives it up for the rest of the run: before any Say answer the run goes on as if there had been none from the start (K1 and K2 become picks); after one, each later Say question is skipped, never counted as a miss.
4. *No feedback* is shown after an answer (a run that told the answers could not place a learner by them).
5. *Pair audio* is asked as audio with `pairAudioTrusted` left false (nothing checks it yet); the plan's Write fallback applies only after a device check exists.
6. *The third script question* is on (owner, 2026-11-05).
7. *Stable cards* (never asked, section 2.2) are those reviewed in any drill with a stability of 30 days or more.
8. *What a run writes.* Each skill's decks up to its placed level are credited in that skill's drills (Read: recognition, reading, understood grammar; Write: production, produced grammar; Hear: listening; Say: speaking) through the existing `creditPlacement` (new `only` argument). The course's placed decks (`placedDecks`) are those up to the lowest placed level of the word skills, so no skill is denied a lesson it still needs. A script placed at its top class is credited as read; below it the script lessons stay. A run only adds credit: the plan's section 4.4 (ask before a lower placement drops credit) is not built. The learner's choice of how placed words are reviewed is left as it is.
9. *Verified marks* are kept per language in the settings (`verified_skills`, by skill name), set for the skills a run tested and left alone for the others. How sure each tested skill was is kept per language as its name (`skill_labels`: skill name to `notSureYet`, `fairlySure`, `sure`, `verySure` or `verified`, never a number); a run replaces the label of each skill it tested and drops the label of a skill it covered but could not test (no microphone, a sound that would not play), so an older run's name is never shown as the latest; a skill the run did not cover keeps its label. The sheet shows a stored `verified` as Verified only while the skill's Verified mark is set. The labels are not tied to the deck set they were found with (that key lives only on the paused run), so they stay until a later run covers the skill. A paused run is kept in the settings too (`placement_runs`), dropped when the run ends.
10. *The checkpoint's lines* are "Read: unit 80 · Very sure"; a script reads "Script: known" or "not yet"; a skill not in play is not listed.

**Where step 5 plugs in.** `FindLevelSummary` (`find_level_summary.dart`) is the whole result screen, shown by `FindLevelRunPage` once the outcome is written; replace it (it gets the finished `PlacementRun`, whose `readout` has each skill's name, assurance and placed level, and calls `onDone`). `findLevelStandings` builds the per-skill lines for it and for the checkpoint. The sheet's skill row should read the Verified marks with `Settings.verifiedSkillsOf`.

**Step 5 as built.** `FindLevelSummary` lists each skill in play with its unit in plain words, its name, a calm note under a low name, a Verified mark, and the percentage in a tap-open detail; a skill that was not tested says why (no microphone or the microphone given up, a question that could not be built such as a sound that would not play, or not asked). `skill_labels_line.dart` reads the labels for the Languages sheet; Script and Second script labels sit under the script row they were found for (by script name, following `placementScripts`, not by row index), and Read and Write under the first script row.

## Simulated learners

These fixtures test the placement logic ("Find my level") against simulated
learners. Each simulated learner answers a multiple-choice question with a
decision rule. The rules below are precise enough for another agent to
implement them in Dart.

Files in this folder:

- `es-amateur-100.json`: the known-word sets for the Spanish AMATEUR-100 learner
  (source, rules, known card ids, list words without a card, path position).
- `README.md`: this file, the simulated-learner profiles P1 to P9.

### The sources, and what they do and do not say

**Lexodle (primary).** The owner's word-list source is the Spanish list in
`aaronified/lexodle`, `app/assets/words/es.txt`, at commit `e0b6111`
(Version 0.7.3), retrieved 2026-11-06. The licence is CC BY-SA 4.0
(`app/assets/words/LICENSE.md`), so storing the words is allowed with
attribution. The list is built from wordfreq and filtered to 4 to 8 letters.
**It is not the literal top 100 Spanish words.** Short function words are
missing: de, la, que, el, en, y, a, o, los, se, un, por, con, no, una. The
AMATEUR-100 uses the first 100 entries of the file as "the 100 most common
words", as the owner specified, and records the gap.

**Wiktionary top 100 (sensitivity variant).** The OpenSubtitles-based list on
`en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Spanish1000` (revision
68654381, retrieved 2026-11-06) gives the true top 100, function words
included. The fetched page did not state a licence. Wiktionary content is
normally CC BY-SA, which must be verified before any wider publication. It is
stored under `variant_wiktionary_top100` in the fixture, for comparison only.

### Matching rules (how the known sets were made)

The rules are implemented in a scratch script, not in the repo. They read
`decks/es/es-*.yaml`, skip the sentence and reading decks (their cards are
whole sentences), and use only cards with `kind: vocab`.

- **STRICT.** A card is known when its target, with the articles el, la, los,
  las, un, una, unos, unas, lo removed, is one word exactly equal (accents
  included) to a list word. Example: `la casa` matches `casa`.
- **GENEROUS.** A card is known when the first content word of its target
  equals a list word, or the lemma of that word equals the lemma of a list
  word. A lemma is the `base` in the deck's `bases` field for that surface
  word. A list word with no deck entry is its own lemma. Strict matches are
  always generous matches. Example: `el año` is generous via `años`.

Limits, stated plainly:

- **Lemmas come from the decks only.** The deck does not teach `está` or
  `estoy` as vocab cards, so `está` has no lemma `estar` in the data. A
  learner who knows `está` would also be credited with `estar`. The fixture
  does not credit that. It understates generous knowledge for forms such as
  está, dice, hizo and es.
- **Determiners lemmatise to their masculine form.** `esta` maps to `este`
  through the deck's bases, so `esta casa` counts as generous.
- **Accents matter in the strict rule.** `esta` and `está` are different words.

### Results (2026-11-06)

Lexodle list: 40 strict, 43 generous known cards. 57 list words have no vocab
card, for example `como`, `está`, `esta`, `todo`. Wiktionary list: 40 strict,
57 generous known cards; 45 list words have no card.

The known cards sit mostly in path units 1 to 11 (phrasebook through
`es-quantities`): 26 of the 43 generous cards for the Lexodle list, and 49 of
57 for the Wiktionary list. A sparse tail of matches reaches unit 100. The
amateur's **true position is path unit 11** (`es-quantities`), where the
known words are used up. The tail is noise to check, not a position.

### Simulated learners: decision rules

Each profile answers one question at a time. A question is:

- `prompt`: a Spanish string, for example `estoy durmiendo`;
- `options`: 2 to 4 items, each with a `label` (the text shown, for example
  `dormir (to sleep) — yo`) and its parts: `es` (the Spanish headword),
  `gloss` (the English gloss in parentheses), `cue` (the suffix after the
  dash, here `yo` or `él/ella`);
- `correct`: the index of the correct option.

The profiles use only the question data, the profile's known set, and a seeded
random generator (seed = the learner's draw number). A profile never reads the
correct answer.

- **P1 RANDOM.** Choose one option uniformly at random.
- **P2 FIRST.** Always choose option 0.
- **P3 SIMILAR.** Choose the option whose full label has the highest
  normalised similarity to the prompt, `1 − levenshtein(prompt, label) /
  max(len)`. Ties go to the lower index. (Variant P3-H uses only the headword
  `es`.)
- **P4 ODD-ONE-OUT.** Compare the `cue` fields. If three options share one cue
  and one option differs, choose uniformly among the three. If all cues are
  equal, behave as P1. Rationale (an assumption, not yet checked against the
  bank): if the distractors are built from the same conjugation, the odd cue
  is the decoy and the majority group holds the answer. Verify this on the
  bank before trusting P4's accuracy.
- **P5 LONGEST.** Choose the option with the longest label. Ties go to the lower
  index.
- **P6 COGNATE.** Score each option by the multiset of letters shared between
  its English `gloss` and the Spanish `prompt`, ignoring spaces. Choose the
  highest score. Ties are broken at random.
- **P7 ELIMINATION.** For each option, its `es` headword is ruled out if it
  is a known word for this learner and it is not the prompt's word. Choose
  uniformly among the options not ruled out. If every option is ruled out, or
  none is, choose uniformly among all options. For the AMATEUR-100 this rarely
  rules anything out, because the distractors are rarely on the list.
- **P8 AMATEUR-100.** Uses the known set `known_generous` of
  `es-amateur-100.json` (and `known_strict` for the strict variant). Rules:
  1. If the prompt word, or a word of the correct option's headword, is in the
     known set, answer the correct option. This is the only place P8 uses the
     answer key, and it is restricted to known words. It models knowing the
     word.
  2. Otherwise, play the combined guess. Each of P3, P4, P6 and P7 casts one
     vote: P3 gives 1 to its top option, P6 gives 1 split over its tied top
     options, P4 gives 1/3 to each option in the majority cue group (0 to the
     odd one out), P7 gives 1/k to each of its k surviving options. Choose the
     option with the highest total; ties are broken at random.
  Rule 2 never uses the key. An amateur who does not know a word must be
  near chance on those questions. The check for that is in the report, not
  assumed.
- **P9 MIXTURE.** For each question, pick one of P1 to P8 uniformly at random
  (seeded), then use its rule.

### Worked example: `estoy durmiendo`

The question the owner saw:

```
What does this word mean?  estoy durmiendo
  0  dormir (to sleep) — yo
  1  comer (to eat) — yo
  2  vivir (to live) — yo
  3  escribir (to write) — él/ella
correct = 0 (dormir: "estoy durmiendo" = "I am sleeping", yo form)
```

Scores computed from these rules (the script that computed them is not in the
repo; the numbers can be reproduced from the definitions above):

| Profile | Choice | Correct? | Why |
|---|---|---|---|
| P1 random | any | 25% | uniform |
| P2 first | 0 | yes | by position, a coincidence |
| P3 similar (whole label) | 1 `comer` | no | similarity 0.211 for comer, against 0.136 for dormir (the longer label dilutes it) |
| P3-H (headword only) | tie 0 `dormir` / 3 `escribir` | 50% | both 0.267 |
| P4 odd-one-out | 0, 1 or 2 | 1/3 | cue `él/ella` is the odd one out, so the majority group is picked at random |
| P5 longest | 3 `escribir` | no | 29 characters, longest label |
| P6 cognate | tie 0 `dormir` / 3 `escribir` | 50% | 5 shared letters each ("to sleep", "to write") |
| P7 elimination | any | 25% | none of the four headwords is in the AMATEUR-100 known set, so nothing is ruled out |
| P8 amateur | 1 `comer` | no | totals: comer 1 (P3) + 1/3 (P4) + 1/4 (P7) = 1.58; dormir 1/3 + 1/2 + 1/4 = 1.08; escribir 1/2 + 1/4 = 0.75; vivir 1/3 + 1/4 = 0.58; comer wins |
| P9 mixture | depends on draw | | |

**Which one wins?** On this single question the simplest cues do not beat
chance reliably. P2 wins only by position. P3 and P5 get it wrong, and P8, the
AMATEUR-100 that combines the heuristics, gets it wrong too. The lesson for the
placement test is that a question like this measures the learner's known set,
not guessing skill. The amateur's answers on items outside its known set must
be close to 25% in the report.

### Fidelity checks (to run on the answers)

Per profile and per answer draw, report:

- accuracy by level and unit band (unit ranges 1 to 11, 12 to 40, 41 and up);
- accuracy by question type;
- accuracy on questions about words OUTSIDE the profile's known set. For P1, P7
  and the beginner and amateur personas, this must be within a few points of
  chance (1/number of options). Anything above that is leakage, and it must be
  flagged.
