# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.


## Find my level: verify, then fit, and how a run samples questions (plan, owner, 2026-11-05)

Status: a plan only, rewritten on 2026-11-05 to the owner's newest design (hard questions at the last deck across the mastery topics; composite questions that split on a fail; assurance as a number per skill; a checkpoint every 25 questions instead of a cap). Nothing here is built; the owner will be consulted before it is. Open questions are in section 9; each has a default the plan assumes.

**Owner quotes, 2026-11-05, in the order they came.**

- Placement count. "Keep placement question count within 25 questions." **Superseded on 2026-11-05 by the owner's later message below: 25 is now a checkpoint, not a cap.**
- Verified, fit and dialect. "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." / "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." / "Verification will only be given after the language has all planned decks and verification run has used all of them." / "I mean full B1 completion level as per the path. Bengali already has that." / "Verified mark: per skill". / "Dialect: only the dialect taught. Mostly every bengali understands the standard dialect (same for almost all languages). Speak is a problem, true."
- Failed check. "Failed check: one fail = check 2 more. If both fail, case closed."
- Native path, first reply (history). "Ask the last deck. If known, sample around that till you find serious flaws. If not known at all (2 questions min), go to 1st deck and keep sampling from there." Then, rejecting the walk back: "That would be quite frustrating for native speakers. Just cover the major grammatical concepts and harder recognition and complex words, test also on minimal pairs more."
- **Newest design (1).** "Presume expert after the last two answers are perfect. No. That is basically 2 questions. Keep asking the hard ones, and when user has covered all the mastery topics (long sentence recognition and reproduction, late stage grammar qs, minimal pairs, etc) without failing 2 in a row in any topic. If he fails in the beginning (the last deck), sample around in the mid section of the app (vocab check only now). if that fails, go back to 25%ile decks; if passes, then to 75%ile decks. Once they keep passing and the vocab level is somewhat fixed, check grammar level. That's it."
- **Newest design (2).** "Check multiple skills together, and on fails, split the skills. Like ask the meaning of a long sentence written only in the script. Or ask to say it in english."
- **Newest design (3).** "Ask them to say the meaning of some words."
- **Confidence.** "Once placement is done, show the confidence level for each skill. It is okay to have low confidence. Learner can fit again later to give the algo more data and fit better." **The "fit again later" part is dropped by the next quote.**
- **Assurance and the checkpoint (newest).** "Verified opens when there is 95% assurance. Better yet, ignore my last 'fit again' message and prolong the fit as needed to get to the 80% level. Instead, after 25 questions, tell the user that they are positioned as lets say x, y, z on 3 skills and if they think they are better than that, they can keep going or stop."

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
| Kept unchanged | verified needs the path complete to B1 and every deck downloaded; a run never changes a skill's Learn, Know or Leave state; verified is per skill; only the dialect taught; "know" = hear, say, and read plus write in at least one script | not contradicted |

### 1. Definitions

- **Deck order.** The language's word decks in path order, from the first A1 deck to the unit marked B1 (`CoursePath`, `walkDecks`). Index 0 is the first, N-1 the last (B1's end). **Unit** on screen is the deck index plus 1. Script decks are checked by the script check (section 3.1, topic 7), not here.
- **Complete to B1.** The path marks B1 and no unit up to it is still to be written. Today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona. Only these can be verified; the others are positioned only (row m).
- **Skill.** The four app skills Read, Hear, Say, Write, and **Script** where the language has its own script (a script is read and written; Hindustani has two). A learner "knows" a language when he can hear, say, and read plus write in at least one script. A run tests only the skills the learner marks as known.
- **Mastery topic.** One of the seven topics of section 2.1. A topic is covered when it has had its minimum of 2 questions.
- **Composite question.** One question that needs several parts at once (reading the script, the meaning, hearing, spelling) and so evidences every skill it needs (section 3).
- **Recheck, split, slip, closed case.** Owner: "Failed check: one fail = check 2 more. If both fail, case closed." After a miss on a single-skill question, ask one more of the same kind (same topic, a different item); if it is right the miss is a **slip**, forgiven; if wrong, ask a second; if that is right it is a slip; if both are wrong the case is **closed** (a serious flaw): no more questions on it, and a closed case in a skill means that skill cannot be Verified in this run. After a miss on a **composite** question the two checks are its **split** (section 3.2): single-part questions that say which part failed. Read as sequential for single-skill questions (a slip costs one question, a closed case two) and always two for a composite; if the owner means that both checks are always asked, every miss costs two (open question 5). "I don't know" is a miss and is never followed by a hint. Under the model of section 4 the checks are ordinary questions; the rule only says when to ask them.
- **Topic fail ("failing 2 in a row").** Read as a closed case: a miss and both checks wrong (for a composite, both split questions wrong). Open question 10 asks whether the owner means a stricter reading (a miss and one wrong check).
- **Assurance, placed level, window.** Section 4.
- **Percentile (in decks).** The p-th percentile deck is deck `round(p/100 x (N-1))`. After the first failure at the last deck the next probe is the middle (50th); a failure there goes to the 25th, a pass to the 75th; thereafter each probe is the midpoint of what is still undecided (section 5.3), which is the same rule.
- **Placed level.** The first deck from which the learner should learn; every deck before it is credited as known (the existing `placedDeckIds`). With assurance it is set per skill (section 5.5).

### 2. Mastery topics (A)

**2.1 The list (a proposal; open question 6).** The expert path asks hard questions at the last deck (the last two decks when one deck lacks enough cards; section 4.2 explains why two) until every topic below has had its minimum of 2 questions. A recheck or split comes only after a miss and is not part of the minimum.

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

`H = 0.35 d + 0.30 f + 0.35 c`. The top five candidates by `H` are the shortlist; the item asked is picked at random from the shortlist with the run's seed, so running twice does not repeat the same five. The app is offline and has no population data, so `H` has no "how often learners miss this card" term (open question 15). A card the learner already reviews with high stability is skipped, because a stable card says "learned in the app", not "known before". **Closeness `c`** of a wrong option `o` to the right card `a`: 1.0 if `o` is `a` with one pair of a sounds-file contrast swapped; otherwise the larger of (1 minus the normalised edit distance of their readings), plus 0.2 if one is a base of the other, 0.1 for the same part of speech, 0.1 for a tag in common (capped at 1). Options never repeat a meaning, and never a card already asked.

**2.3 No repeats.** Never the same card twice in a run; never two cards of one word family in a run; never a card as both the question and an option; one concept family or contrast at most once as a first question (a recheck or split is the only repeat of a topic).

**2.4 Dialect: only the dialect taught.** Owner: "Dialect: only the dialect taught ... Speak is a problem, true." Questions use only the taught dialect and no dialect variant is accepted as right. Hear and Read are safe. Say is the risk: a fluent speaker of another dialect may say a word his way and be failed by the recogniser. Short items (topic 6) and the English-meaning answers of topic 1 (the English recogniser is reliable) reduce the risk; the rest is open question 8.

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

**3.3 Evidence per skill.** The earlier "at least three passing questions per skill" is replaced by assurance (section 4): a question counts for every skill it needs, a right composite in full, a miss at half strength until the split says which part failed. The fixed order of section 2.1 gives these clean-run counts (right answers, Bengali): Read 4 (K1, W1, G1, G2) plus 1 script read; Hear 5 (K2, W2, R1, two pairs); Write 4 (R1, R2, G2, script write); Say 3; Script 3 (K1, script read, script write). Whether 3 is also a floor for Verified is open question 7.

### 4. Assurance: the model

**4.1 The model, in one sentence.** *Assurance in a skill is the probability, given every answer so far, that the learner's true level in that skill is the level we place him at; the levels are the end of the path and ten equal tenths of it below, plus "none".*

It is a Bayesian update over a short list of hypotheses, small enough for one pure Dart function (`Posterior update(Posterior, Answer)` over twelve numbers, no state but this run's answers):

1. **Hypotheses (classes).** `none`, and the levels `l_k = round(k x (N-1) / 10)` for k = 0 to 10 (for N = 100: 0, 10, 20, 30, 40, 50, 59, 69, 79, 89, 99). A class says "the learner knows every deck up to `l_k` and none above". The top class `l_10` is "the whole path, the last deck included". For N of 20 or fewer the classes are min(10, N) equal parts, at least one deck each.
2. **Prior.** Equal for the twelve classes (1/12 each): "no opinion". The owner's own words ("the 25%ile and the 75%ile") need no other prior.
3. **A question** at deck `d` has a slip rate `s` (a learner who knows deck `d` still misses it) and a guess rate `g` (a learner who does not know it still gets it right). For a class with `l_k` at least `d`, P(right) = 1 - s; otherwise P(right) = g. The likelihood of the answer is that, or 1 minus it for a miss. A question of the last two decks counts as asked at deck N-1.
4. **Composite questions.** A composite is right only if every skill it needs worked, so a right answer updates each skill it covers in full. A miss may be the fault of one skill, so it updates each skill at half strength (the likelihood to the power one half) until the split says which part failed; the split answers update their single skill in full (section 3.2).
5. **Rechecks, splits and slips need no special case.** They are ordinary questions, and a slip is a miss next to two rights: the posterior handles it.
6. **Posterior** = prior times the product of the likelihoods, normalised. The **placed level** of a skill is the leading class's level (never above it); its **assurance** is that class's posterior mass. The "window" is therefore one tenth of the path, which is what "the vocabulary level is somewhat fixed" means (section 5.3).
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

**4.3 Names, and how they relate to Verified.** The learner sees words, not a score out of 100 (open question 4):

| Name | Assurance of the leading class | Meaning for the learner |
|---|---|---|
| Not tested | skill not marked, not asked, no mic, "can't speak now" | "we did not test this" (never a fail) |
| Not sure yet | under 50% | "too few answers to say; this is a first guess" |
| Fairly sure | 50% to 79% | |
| Sure | 80% or more | the fit target; the placement is good |
| Verified | 95% or more, at the top class, and the conditions below | the language is marked Verified for this skill |

**Verified** is the highest name, not a separate test: for each skill it needs (a) the path complete to B1 and every deck of the language downloaded; (b) the top class with assurance 0.95 or more; (c) every mastery topic that skill takes part in covered (the owner: "covered all the mastery topics"); (d) no closed case and no gap in that skill in this run. A run that does not meet them still gives an assurance and a placement: a low name is acceptable and is never called a failure. Verified is per skill, as before.

**4.4 No evidence is kept across runs.** The model reads only this run's answers, so nothing from an earlier run is stored: no per-deck record, no decay, no carried assurance. Reasons: storing it adds state, a decay rule, a conflict rule and a privacy surface for no benefit to the model, and the owner dropped "fit again later" (a carried evidence would only have served that). If the owner wants it later, earlier evidence enters as the prior of section 4.1 and nothing else changes (open question 14). **When a later run disagrees with an earlier one:** for each skill the later run tested, its placement replaces the earlier one; a skill it did not test keeps its old placement. If the new placement credits fewer decks, the sheet shows both and asks before it removes any credit; if more, it credits at once (and, as always, a run never changes a skill's Learn, Know or Leave state; it only adds credit and the Verified mark).

### 5. The run: the expert track, then positioning

**5.1 The run in order.**

1. **Preconditions.** If the path is complete to B1 and every deck is downloaded, Verified is possible (section 4.3). Otherwise the run only positions (row m).
2. **The expert track.** Ask the mastery topics in the order of section 2.1, hard questions at the last deck, with checks after a miss. A skill stays on the track while its assurance in the top class stays at 20% or more. It **leaves** when it falls below 20% (for instance after a closed topic 1 or 5, section 3.2) or when two topics are closed; it is then positioned (5.3). A closed topic that is not about meaning (pairs, Say, script, grammar) is a gap and the skill stays.
3. **Targets.** A skill on the expert track with the preconditions met has the target 95% (Verified); every other skill has the target 80% (Sure). The run **ends** when every tested skill has met its target, and shows the result (5.5). A skill with a closed case or a gap cannot be Verified, so its target is 80%.
4. **No fixed cap.** The run prolongs itself, as asked, until the targets are met or the learner stops. Every 25 questions it pauses at a checkpoint (5.4).

**5.2 The expert track: cost on a Bengali run (15-question floor).** Each row is from the model of section 4 on the fixed order of section 2.1 (simulated, clean answers apart from the stated miss). "80%" is the question at which every tested skill is at 80% or more; "95%" is the question at which every skill that can be Verified is at 95% or more (and all topics are covered, which on a clean run is also question 15).

| Case | To 80% | To 95% (Verified) | Note |
|---|---|---|---|
| Clean | 14 | 15 | per skill: Read 80% at question 3 and 95% at 5; Hear 4 and 7; Write 7 and 7; Say 12 and 12; Script 14 and 15. The fixed topic order, not the model, sets the 15: the model alone would reach 80% in 8 and 95% in 9 questions, but Verified needs every topic covered |
| One single-skill slip (a pair with a right recheck) | 15 | 16 (17 if the first check is wrong and the second right) | one or two more questions |
| One composite slip (both splits right) | 16 | 17 | Hear 80% at 9, 95% at 12; Script last |
| One gap (one split wrong, e.g. Write) | 17 | 17 for the other skills | the gapped skill reaches 83% ("Sure") and is not Verified |
| One closed topic that is not about meaning | up to 18 | up to 18 | base 15, minus the skipped second question, plus 3 or 4 for the closed case, plus 1 isolating question |
| Language with no script topic (Spanish) | 12 | 13 | 13 questions in all |
| Reads two scripts (Hindustani) | 16 | 17 | a second script topic |
| No mic (Say not tested; K1, K2 become picks) | 12 | 13 to 14 | Script needs one or two more questions to reach 95% |
| At the checkpoint | | 25 | about three composite slips, a closed topic and one more slip; the learner then chooses Keep going or Stop here |

**Expert verification fits in 25 questions in every case above and takes more than 25 only after about five or more composite slips or gaps in one run.** The main downside of the design is on the other side: a learner who is not an expert (section 5.3) spends far more questions than the old fixed battery did.

**5.3 Positioning (D): the fallback for a skill that leaves the expert track.** This path places and never verifies.

1. **Vocabulary only.** Owner: "sample around in the mid section of the app (vocab check only now)". A skill has its own stream of single-skill vocabulary questions: Read (a word in the learner's script or reading, pick its meaning), Hear (an audio word, pick its meaning), Say (the English meaning given, say the word), Write (the meaning given, build or type the word), and for a script its own five levels (the classes of a script are `none` and its five levels, the same model).
2. **Next question: where the evidence is most undecided.** Ask at the deck where P(level at or above that deck) is closest to one half. After the last deck has failed this is the middle of the path (the 50th percentile deck); a failure there moves the next probe to the 25th, a pass to the 75th; then the midpoint of what is left, which is the owner's "go back to 25%ile ... if passes, then to 75%ile" and "once they keep passing", as a single rule.
3. **Checks.** Every miss gets the recheck rule of section 1: two more questions at the same deck, other items. Open question 9 asks whether the checks are needed in positioning, because the model uses the next probe as a check anyway (numbers below).
4. **Stop for the skill** when the leading class reaches 80%, that is when the model is 80% sure the vocabulary level lies in one tenth of the path. The per-skill cost, from the model on a clean learner (deterministic answers, no slips; single-skill four-option questions; the numbers must be reproduced by the implementation's test):

| True level of the skill | To 80% with the recheck rule | To 80% model-only (no checks) | To 95% with the rule | To 95% model-only |
|---|---|---|---|---|
| none (knows nothing) | 11 | 4 | 11 | 5 |
| about 30% of the path (A2) | 9 | 5 | 10 | 7 |
| about 80% of the path (advanced) | 7 | 6 | 8 | 7 |
| the whole path (a native who left the track) | 5 | 5 | 6 | 6 |

   Formula: the odds of the leading class after `k` right answers at its edge are `(1/11) x LR^k` with `LR = (1-s)/g`; for 80% they must reach 4 and for 95% they must reach 19, so `k = ceil(ln(11 x O) / ln LR)` with O = 4 or 19: for a four-option single question (LR 3.8) 3 right answers give 80% and 5 give 95%; for a pair (LR 1.9) 6 and 9; for a production answer (LR 28 to 30) 2 and 2. A miss costs 15 times more evidence than a right answer, which is why the first miss at a deck moves the next probe at once and why the checks add more than they need to when the learner is clean.
5. **Percentile and short paths.** The p-th percentile deck is `round(p/100 x (N-1))`; the classes of section 4.1 are the percentile steps. For N of 20 or fewer the classes are min(10, N) equal parts; N of 9 or fewer gives one deck per class; N under 2 asks the one deck twice.
6. **Grammar, once the vocabulary level is fixed.** Owner: "check grammar level". Take the skill the learner reads with (Read, else Hear). `G0` is the last grammar unit at or before its placed deck. Ask one grammar question (type G1) at `G0`: if right, ask one at the grammar unit halfway up between `G0` and the last grammar unit; if wrong (after its checks), one at the unit halfway down between the first grammar unit and `G0`. The grammar level is the highest probe answered right (`G0` if the up probe fails; the first grammar unit if the down probe fails too). That is the two bisections, "once each way", and then stop; at most 2 questions plus their checks (about 2 to 4). Grammar is placed, not given an assurance (two questions cannot reach 80%). A language with no grammar units skips this (row l).
7. **The fixed cost.** The 3 questions already asked on the expert track before the skill left (a closed topic 1: K1, S1, S2) count as evidence. For `k` positioned skills the run costs about `3 + c x k`, with `c` from the table, plus 2 to 4 for grammar: for an advanced learner on four skills 3 + 7 x 4 = 31 (3 + 6 x 4 = 27 model-only); for an A2 learner 39 (23); for a beginner 51 (19). **These exceed 25 for three or more positioned skills; the checkpoint then comes before the end.** The main downside is fatigue. Mitigations (proposals, labelled as such, not simulated for the composites): (a) **floor first:** after a skill's mid probe is closed, probe deck 0 next; two misses there give "none" at 95% (a beginner then costs about 12 for two skills); (b) **pair skills in positioning:** a dictation (Hear plus Write at the same deck) serves two skills at once, up to about 40% fewer questions for those two; (c) **model-only checks in positioning,** open question 9; (d) at the second checkpoint (50 questions) any skill still under 50% is stated "Not sure yet" and the run offers Stop here first.
8. **Worst case.** Unbounded in principle: answers that contradict each other keep the assurance flat. The model run on a pure guesser (four options, one skill, with the recheck rule) takes a median of 12 questions to 80% (the guesser is placed at none), 21 or fewer in 90% of runs, 30 or fewer in 99%, more than 25 in 3% of runs and more than 50 in none of 4,000; model-only: median 6, 99% within 15. That is the case the checkpoint is for.

**5.4 The checkpoint (replaces the cap).** After 25 questions asked, and again after every 25 more (rechecks and splits count), the run pauses and shows where the learner is positioned, per skill. Draft wording (open question 3):

> You have answered 25 questions. This is where you stand now. Read: unit 80, sure. Hear: unit 80, fairly sure. Say: unit 22, not sure yet. Script: known, sure. If you think you are better than this, keep going. Or stop here and we will place you at these levels.
> [Keep going] [Stop here]

"Positioned at unit N" means the leading class's level plus one: the learner knows up to unit N and learns from N + 1. A skill that has already reached its target is listed as it will be placed. Keep going continues the same run (the same posterior, the same questions) to the next checkpoint, and a run that reaches all its targets before 25 never shows one. "Fit again later" is dropped, as the owner asked.

**5.5 What the end of a run, or Stop, writes and shows.** For each tested skill: the placed level (the leading class's level; decks up to it are credited), its assurance name (4.3) with the percentage in the detail line ("about 85% sure"), and the Verified mark where 4.3 is met; a skill not tested says "Not tested". Nothing is written until the run ends or the learner stops (a pause saves the run for 7 days under the same deck set and app version, then discards it). A low assurance is shown plainly and kindly ("Not sure yet: this is a first guess"), never as a fail and never as a score out of 100; the sheet shows the same name on the language's skill row. Stop here writes the placement at the assurance it has, and nothing is held against a learner who stops early.

### 6. Deviations (E), planned from the model

Each route is the expert track of section 5.1, positioning (5.3) or both. "To 80%" and "To 95%" count questions for the stated skills; "Checkpoint" says whether 25 is passed. Budgets use the recheck rule; the model-only numbers are in 5.3.

| Row | Trigger | Route | To 80% / To 95% | Checkpoint | Outcome written |
|---|---|---|---|---|---|
| **a. Native or expert, clean** | all topics right | expert track | 14 / 15 (Spanish 12 / 13) | no | every skill Verified; every deck credited |
| **b. Expert with a slip** | a composite miss with both splits right, or a single-skill miss with a right check | continue | 16 / 17 for a composite; 15 / 16 for a single (17 if the first check is wrong) | no | Verified; the slip is only part of the evidence |
| **c. Expert with a gap** (one split wrong, or a closed pair, Say or script topic) | the split names the part | record the gap, ask the isolating question, continue | 17 / 17 for the other skills; up to 18 if a topic closed | no | the gapped skill "Sure" (about 83%) but not Verified; the others Verified; a gap record `{kind: grammar, contrast or script, id, deck}`; the app offers that unit or the pair drill; every deck credited except the gap's first failing unit |
| **d. Native fails early** (a voice, script or recogniser problem makes the first topic close) | a skill falls under 20% on the track | the skill is positioned; a native at the end of the path takes about 5 to 7 more questions; grammar 2 to 4 | 3 + about 5 to 7 per skill | for three or more skills | not Verified; placed near the end with a "Sure" name; a line says why; a new run starts from the last deck as always |
| **e. Advanced non-native** (about 80% of the path) | topic 1 or 5 closed (both splits wrong) | positioning | 3 + 7 per skill (17 for two skills; 21 with grammar; 31 for four) | for three or more skills | not Verified; placed at the leading tenth (unit 80 in the example) at 80% or more |
| **f. Intermediate (A2)** | same | positioning | 3 + 9 per skill (21 for two; 39 for four) | for three or more | placed at about a third; learn from the next |
| **g. Heritage speaker** (hears and speaks, cannot read) | the learner marks Read and Write as not known, or K1 closes with K2 right | expert track on audio variants: topic 1 as two K2 questions, topic 3 as "which sentence sounds right", topic 5 as W2 twice, topics 2 and 7 not asked (they need Write); Say as usual | 11 / 11 | no | Hear and Say Verified; Read, Write and Script "Not tested"; the sheet proposes them as Learn from the script's first deck and the learner confirms (a run never changes a skill's state); the words are credited for Hear and Say |
| **h. Beginner (A1 or none)** | topic 1 closed and the mid probes closed | positioning | 3 + about 12 per skill (27 for two skills); with floor first (5.3, proposal) about 12 | for two or more skills | not Verified; placed at none ("Sure"); learn from deck 0; the script by its own check |
| **i. Partial script** (Hindustani: Devanagari known, Perso-Arabic not) | the learner marks a script as not read | each script is its own skill row with its own questions; the unread one is asked at its floor only (two misses give "none" at 95%; with the rule 3 questions); the word questions use the script he reads | expert 15 / 15 + 3 | no | Devanagari Verified with the words; Perso-Arabic: learn from its first script deck, as the owner described |
| **j. No mic, noisy room, "I can't speak now"** | no recogniser; two "unheard" in a row; the Speak button used | Say is not asked; K1 and K2 become picks (4.3: "Not tested", never a fail) | 12 / 13 to 14 | no | Say "Not tested"; the others Verified or placed on their own evidence; Say can be run alone later; with no sound, Hear is also "Not tested" and the pair questions become Write tiles (open question 15) |
| **k. Guesser** | answers about as good at depth as at the floor; closed topics in a row; the skills leave the track | positioning (section 5.3) with "I don't know" invited | 35 for two skills in the example below (a median of 12 per skill) | yes, at 25 | not Verified; placed at none or at a low class, whatever the lucky answers; a line asks him to use "I don't know" |
| **l. Few decks or no grammar decks** | N under 12, or no grammar family | classes of min(10, N) equal parts; N of 9 or fewer: one deck per class; no grammar family: G1 and G2 use sentence cards with a close wrong form (Toki Pona's particles); no sounds file: pair letters from the decks (section 8) or complex words instead | about as above, minus the grammar step | no | Verified as the baseline if 4.3 is met; a line says what was missing |
| **m. Not complete to B1** | the path is short of the B1 mark | no Verified (that is what verification is); the expert track and positioning run over the decks that exist, the top class being the last deck that exists | as rows a to h | as above | never Verified; placed; the sheet says known skills cannot be Verified until the course is complete |
| **n. Pause or abandoned** | the learner leaves; fatigue after two late misses in an otherwise clean run | the run is saved after every answer; resumed within 7 days with the same deck set and app version, else discarded with no answer carried; a pause is offered, not a fail | a pause costs nothing; the checkpoint counts asked questions | n/a | nothing is written until the run ends or the learner stops |

**6.2 The guesser guard.** The earlier plan computed that a pure guesser passes a 14-question battery about 1 in 400 (0.578^10 x 0.875^4). Under the new design a guesser can pass a question by luck or by two lucky split questions, and must also lift every skill to 95%, which the model treats as strongly as any other evidence. Simulated with the parameters of 4.2 (60,000 runs, answers independent, four-option guesses right a quarter of the time, a pair a half, production answers 3%, one skill at a time, the fixed order of 2.1, checks and splits as in 3.1, no extra questions):

| Skill | Chance a pure guesser reaches 95% (Verified level) after the 15-question list | Chance he reaches 80% |
|---|---|---|
| Read | 0.05% (about 1 in 1,900) | 0.19% |
| Hear | 0.06% (about 1 in 1,700) | 0.12% |
| Write | 0.04% (about 1 in 2,600) | 0.10% |
| Say | 0.02% (about 1 in 4,300) | 0.04% |
| Script | 0.19% (about 1 in 540) | 0.9% |
| every skill together | effectively never (none in 60,000) | |
| no mic: Read / Hear / Write | 0.13% / 0.12% / 0.03% (about 1 in 790, 830, 3,300); Script cannot reach 95% on the list alone | |

These are lower than the old 1 in 400 for every skill except Script, because composites need several parts at once and production answers (K1, K2, Say) are almost impossible to guess. The assumptions are the weakest part: the independence of answers, and a pure guesser (a half-knower is not computed). Also, a run that reaches 95% only through slips reaches a lower number than a clean one (a K1 miss and two right splits leave Script at 94%, under 95%), so the model asks more before it verifies. **Proposals to bring it down, with the main downside:**

- **A third script question** (a rarest-sign read at a different sign class): divides the Script figure by about 2 to 4; costs 1 question on a clean run (16, 14 to 80%, 15 to 95%+1). Downside: a longer run for scripts only.
- **More pairs** (a third pair question): Hear 1 in 1,700 becomes about 1 in 1,900; weak per question because a pair is a coin toss, and it does nothing for Read. Downside: a pair is a poor use of a question.
- **A sentinel block** (two easy deck-0 to 4 items): does not lower a pure guesser's odds (he guesses easy items at the same rate); it only helps against a learner who memorised the hard items. Downside: it costs 2 questions and adds little. Not recommended.
- **A second pass on suspicious runs** (any pass reached by a slip): already built into the model, since a slip lowers the posterior and the run asks more; no separate rule is needed.

Recommendation, not a decision: keep the model as it is and take the third script question; the rest of the table is already below 1 in 500.

### 7. Worked examples (F) (N = 100, Bengali, B1 complete)

Assurance figures are from the model of section 4 (simulated). Skills in examples 1 to 3: Read, Hear, Say, Write and Script. `ok` is right. "Name" is the word of 4.3.

**Example 1: a native, clean.**

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

Result: 15 questions, no miss. The 80% mark was met at question 14 and the 95% mark at 15. End: Read 100%, Hear 100%, Say 100%, Write 100%, Script 99%: every skill **Verified**; every deck credited. The run ended on its own, with no checkpoint. By skill, 80% / 95%: Read 3 / 5, Hear 4 / 7, Write 7 / 7, Say 12 / 12, Script 14 / 15.

**Example 2: a native with one slip.** The same as Example 1, except that the recogniser misheard the English answer at question 2.

| # | Item | Result |
|---|---|---|
| 1 | K1 (Read, Script) | ok |
| 2 | K2 (Hear): say a heard sentence's meaning in English | miss (the recogniser wrote a different English word) |
| 3 | split S1: another long sentence by audio, pick its meaning | ok |
| 4 | split S2: a short word heard, pick its meaning | ok: slip, forgiven |
| 5 to 17 | W1, W2, G1, G2, R1, R2, two pairs, three Say, script read, script write (Example 1, rows 3 to 15) | ok x13 |

Result: 17 questions (15 plus the 2 splits). 80% at question 16, 95% at 17. Hear was 12% after question 4 and reached 80% at 9 and 95% at 12. End: Read 100%, Hear 97%, Say 100%, Write 100%, Script 99%: every skill **Verified**. The miss is part of the evidence and is not shown.

**Example 3: an expert failing one topic (composite split).** Hear and Write were asked together in R1.

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

Result: 17 questions. Hear 97%, Read 100%, Say 100%, Script 99%: **Verified**. Write 83%: **Sure**, but not Verified, because a gap in the Write part was found (the sign class of the miss, recorded as `{kind: script, id, deck}`); the app offers the unit. The gap does not remove Verified from the other skills (the owner's rule: verified is per skill). The run ended at 17 because the Write target is 80% once a gap exists.

**Example 4: an advanced non-native, placed by positioning (Read and Hear known).** True level: about deck 80.

| # | Probe | Result |
|---|---|---|
| 1 | K1 (Read): a long sentence of deck 99 in the script; say its meaning in English | miss |
| 2 | split S1: another by audio, pick its meaning (Hear) | miss |
| 3 | split S2: a short last-deck word in the script, pick its meaning (Read) | miss: topic 1 closed; both skills fall under 20% at the top and leave the track |
| 4 | Hear, the middle (deck 50) | ok |
| 5 | Read, deck 50 | ok |
| 6 | Hear, deck 69 | ok |
| 7 | Read, deck 69 | ok |
| 8 to 9 | Hear, Read, deck 79 | ok x2 |
| 10 to 12 | Hear, deck 89 | miss, miss, miss (the recheck rule): case closed |
| 13 to 15 | Read, deck 89 | miss x3 |
| 16 | Hear, deck 79 | ok: 88% |
| 17 | Read, deck 79 | ok: 88% |
| 18 | grammar: the last grammar unit at or before deck 79 (deck 77) | ok |
| 19 to 21 | grammar: the unit halfway up (deck 87) | miss x3: grammar level stays at deck 77 |

Result: 21 questions, no checkpoint (under 25). Read: unit 80 (deck 79), **Sure** (about 88%); Hear: unit 80, **Sure** (about 88%); grammar placed from the unit after deck 77 (not assured); not Verified; the learner is placed at 79 and learns from deck 80. Model-only (no checks) it would be 3 + 6 + 6 + 2 = 17.

**Example 5: a beginner (Read and Hear known).**

| # | Probe | Result |
|---|---|---|
| 1 to 3 | K1, then S1 and S2 | "I don't know" x3: topic 1 closed; both skills leave |
| 4 to 6 | Hear, deck 50, with its two checks | "I don't know" x3 |
| 7 to 9 | Read, deck 50 | x3 |
| 10 to 15 | Hear then Read, deck 20 | x3 each |
| 16 to 21 | Hear then Read, deck 10 | x3 each |
| 22 to 24 | Hear, deck 0 | x3: none at 100% |
| 25 | Read, deck 0 | first miss: **checkpoint** (Read none at 94%, Hear none at 100%, both Sure) |
| 26 to 27 | Read, deck 0, two checks | x2: Read none at 100% |

Result: 27 questions, one checkpoint at 25 (a learner who chose Stop here at the checkpoint is placed at none with Sure on both). Placed at none: learn from deck 0; the script by its own check. Not Verified. Proposed floor first (5.3): after the mid probe closes, probe deck 0: 12 questions.

**Example 6: a heritage speaker (Hear and Say known; Read, Write and Script not marked).**

| # | Item | Result |
|---|---|---|
| 1 to 2 | topic 1: two K2 questions (audio, say the meaning in English) | ok x2: Hear 99% |
| 3 to 4 | topic 5: W2 twice (heard complex words, pick the meaning) | ok x2 |
| 5 to 6 | topic 3: "which of two sentences sounds right", two families | ok x2 |
| 7 to 8 | topic 4: two pairs | ok x2 |
| 9 to 11 | topic 6: three Say | ok x3: Say 72% after the first, 99% after the second |

Topics 2 and 7 are not asked (they need Write). Result: 11 questions. Hear 100%, Say 100%: **Verified**; Read, Write and Script: **Not tested**; the sheet proposes them as Learn from the script's first deck and the learner confirms.

**Example 7: a guesser (Read and Hear known; right a quarter of the time at four options).**

| # | Probe | Result |
|---|---|---|
| 1 to 3 | K1 (says nothing), S1, S2 | miss x3: topic 1 closed; both skills leave |
| 4 | Hear, deck 50 | ok (lucky) |
| 5 to 7 | Read, deck 50, two checks | miss x3 |
| 8 to 10 | Hear, deck 69 | miss, ok, ok |
| 11 to 13 | Hear, deck 69 again | miss, miss, ok |
| 14 to 16 | Read, deck 20 | miss x3 |
| 17 to 19 | Hear, deck 50 | miss, miss, ok |
| 20 to 22 | Hear, deck 20 | miss x3 |
| 23 to 25 | Hear, deck 10 | miss, miss, ok: **checkpoint**: both skills at none, "Fairly sure" (about 50%) |
| 26 to 28 | Read, deck 10 | miss x3 |
| 29 | Hear, deck 0 | ok (lucky) |
| 30 to 32 | Read, deck 0 | miss x3: Read none at 100% |
| 33 to 35 | Hear, deck 0 | miss x3: Hear none at 100% |

Result: 35 questions (a median of 12 per skill is typical). Not Verified; placed at none on both; a line asks him to press "I don't know" instead of guessing. Lucky answers cost him questions, not credit.
### 8. Minimal-pair data today, and what is missing

What the app has: a `<lang>-sounds.yaml` for ten languages (as, bn, gu, hi, ja, kn, ko, mr, te, zh: 4 to 9 contrasts each, as letter pairs, with `within_word` for a sign added at the end of a word). The speaking drill's feedback uses it (ADR-0015). Each contrast id is the tag of a language's sound-differences deck. A minimal-pairs drill, `PairDrill`, exists but is built on fixture data and shown disabled until #31 gives it an ADR, deck data and a device check; nothing in a live session builds it. `alike_warning.dart` already finds sound-alike and look-alike cards for a review.

What is missing:

1. **Spanish and Toki Pona have no sounds file** (both are complete to B1 and so verifiable). Spanish has few contrasts that matter (r against rr, for example); Toki Pona almost none.
2. **A pair list of actual words.** The file gives letter pairs, not word pairs. A pair question needs two real words of the language's decks that differ by exactly one swap; they have to be found by swapping letters in the decks' words (a one-off tool over the decks, by the plan's rule of tools written by the tools, not by hand) and kept as a derived list, or computed on the device from the deck's cards.
3. **Tone, length and stress.** Chinese and Japanese contrasts include tone and vowel or consonant length, which are not a letter swap; the file's form cannot say them.
4. **Audio.** The pair needs the two words to sound different. The system voice (ADR-0002) may flatten an aspirated or retroflex contrast on some phones, in which case a native would fail a correct answer. A check on a device, and a fallback to Write tiles when a pair's audio is not trusted, are needed.
5. **A difficulty per pair** (a pair of two common words against two rare ones); today a pair's difficulty can only come from the closeness `c` and the deck depth.

### 9. Part 3: open questions for the owner

Each has the default this plan assumes, in brackets, and the main downside. Answered 2026-11-05 and removed: the verified mark (per skill), the failed-check rule (section 1), the dialect policy (2.4), the hard cap of 25 (superseded: a checkpoint, 5.4), "fit again later" (dropped, 5.4), assurance and its 80% and 95% targets (section 4).

1. **The model's parameters and prior (4.1, 4.2).** [flat prior over twelve classes; slip 0.05 for a single pick, 0.10 for a composite or an English production, 0.15 for Say; guess 0.25 at four options, 0.5 at a pair, 0.03 for a production, 0.05 and 0.10 for tiles; a composite miss at half weight] Downside: there is no population data, so these are set by feel; wrong values make the run too trusting (a low slip rate makes one miss costly) or too slow. They can be tuned later if the app records, on the device, how often each question kind is missed.
2. **80% and 95% per skill, or for all skills together?** [per skill: the run ends when every tested skill has met its own target, and Verified is per skill] Downside: the run is as long as its slowest skill (Say, Script). All skills together would be simpler to explain and slower.
3. **Checkpoint wording and repeats (5.4).** [the draft of 5.4; every 25 questions, repeated] Downside: a learner who keeps going to 75 questions is tired; the plan does not stop him ("they can keep going or stop").
4. **What "positioned" shows per skill.** [the unit and a name (Not sure yet, Fairly sure, Sure, Verified), with the percentage only in the detail line] Downside: a name hides precision; the percentage invites "should I be at 95?". Showing only the percentage reads like a score, which the owner earlier did not want (never shaming a low result).
5. **Slip cost.** [a single-skill slip costs 1 question (2 if the first check is wrong); a composite always costs 2 (both splits)] Downside: if the owner means that both checks are always asked, every miss costs 2 and each row above rises by one per single-skill slip.
6. **The mastery topic list (2.1):** long-sentence recognition, long-sentence reproduction, late grammar, minimal pairs, complex words, Say by word meaning, script read and write, 2 questions each, Say 3. [as listed] Downside: seven topics set a floor of 15 (13 without a script) however good the learner is; a shorter list would be quicker but let a real gap through.
7. **A floor of 3 questions per skill for Verified, on top of 95%?** [yes, kept only because Say needs 3 and the list gives every skill 3 or more; no separate rule] Downside: the model could reach 95% in 2 production answers; the floor is the owner's "covered all the topics", not a statistical need.
8. **Say by the meaning of a word, and the recogniser for bn-IN.** The recogniser is graded against the taught word and its listed synonyms (a synonym list is needed on the cards; Hindustani already has Sanskrit and Persian-leaning synonyms, other languages have none), and shorter items reduce dialect risk. The earlier finding is that the bn-IN recogniser is uneven. Options: (a) judge against the taught form and listed synonyms only (simplest; a fluent speaker of another dialect can be failed, which closes a Say case); (b) lenient matching on the taught word's sounds (accepts near sounds; a weaker check, and a guess passes more easily); (c) when the recogniser rejects a clearly fluent attempt, leave Say unverified rather than failing it (no false fail; the sheet says why; open: how the app judges "clearly fluent"). **Recommendation, not a decision:** (c) with (a) as the grading, because it avoids a false fail without loosening the check a guess has to pass. Downside of (c): a fluent learner may not get Say Verified in that run, and the synonym list is deck work that the deck-work rules put last.
9. **The recheck rule in positioning (5.3).** [apply it everywhere: two more questions at the same deck after a miss] Downside: it costs about 2 questions per miss, and a clean beginner pays 11 per skill instead of 4 (an advanced learner 7 instead of 6). Model-only checks are about 40% shorter but let one slip move the next probe.
10. **What "failing 2 in a row" means in a topic.** [a closed case: a miss and both checks wrong] Downside: a stricter reading (a miss and one wrong check) fails honest slips more often.
11. **Floor first for a beginner (5.3, proposal).** [yes] Downside: a learner with a few words and no mid-path knowledge is placed at none after two floor misses only if the floor misses; one lucky floor answer sends him back to the median probe.
12. **At Stop with low assurance.** [place at the leading class's level, whatever its assurance, and show the name] Downside: a learner stopped at 40% may be placed too high; the alternative (place at the highest level he is 80% sure of, which can be none) never overshoots but under-credits.
13. **Disagreement between runs (4.4).** [a later run replaces the placement of the skills it tested; a lower placement asks before credit is dropped] Downside: a bad later run (tired, guessing) could lower a good earlier placement; the sheet asks, so the learner can decline.
14. **Evidence carried across runs.** [dropped, 4.4] Downside: a second run starts from a flat prior and repeats questions the first already answered; the owner dropped "fit again later" so this is not a cost the design needs. If wanted, earlier evidence enters as the prior and nothing else changes.
15. **Questions kept from the earlier list, still open.** (a) Is "I don't know" a miss? [yes] (b) Minimal pairs for languages without a sounds file (Spanish, Toki Pona) and for tone: [letter-swap pairs from the decks for Spanish; complex words for Toki Pona; leave tone out] (c) Non-prefix and per-skill credit (gaps as exceptions; credit for a heritage speaker per skill by a proposal sheet; `placedDeckIds` is a set so the first looks possible, per-skill credit is not in the model). (d) Pair audio: if the system voice flattens a contrast, pairs go to Write tiles [after a device check per language]. (e) Does a self-declared level seed the search? [no] (f) Resume window of 7 days. (g) The learner's own review history shortens the run, only for cards with high stability and only as skipped evidence [yes]. (h) One Verified label for a native and a B1 learner alike ("Verified to B1") [yes]. (i) The weights of the hardness score `H` (0.35, 0.30, 0.35) [as written]. (j) One run for all known skills [yes; with a checkpoint every 25 the run is as long as it needs]. Downside of each: as in the page's earlier text (history: `git show 16dc8d22:wiki/Plan-Placement-V2.md`).

**Earlier open questions, now answered or changed.**

| # | Earlier question | Now |
|---|---|---|
| 1 | "Last two perfect" presumes expert; two questions of different kinds | changed by the owner: no presumption; every mastery topic is covered (section 2) |
| 2 | Battery size 10 to 14 and cap 25, `10 + 2k` for `k` skills | changed: a floor of 15 for a clean expert (13 without a script topic) and an adaptive length; composites cover several skills, so `k` no longer adds questions; 25 is a checkpoint |
| 3 | Is "I don't know" a miss | unchanged (15a) |
| 4 | Pairs without a sounds file | unchanged (15b) |
| 5 | Non-prefix credit, per-skill credit | unchanged (15c) |
| 6 | Pair audio | unchanged (15d) |
| 7 | Level-mark ladder before halving | replaced by positioning (5.3): halving by the evidence, no ladder |
| 8 | A self-declared level seeds the search | unchanged (15e) |
| 9 to 14 | resume window, answer-speed detector (off), history, one Verified label, weights, one run per skill | unchanged except that the cap in them is now the checkpoint (15f to 15j) |
| 15 | Speak and other dialects | now question 8 above (Say by word meaning, with the options and the recommendation) |
| earlier 1 to 8 (the first walk-back plan) | serious flaw as two misses, 3 misses stop the run, verified in part, 25 runs out | superseded by the recheck rule (section 1), assurance (section 4) and the checkpoint (5.4); "three closed cases stop the battery" is dropped, because the model and the 20% leaving rule do the same job |

### 10. Risks

- **A native fails a correct answer because of the system voice** (a flattened contrast) or because the recogniser rejects a good English or Say answer. Downside: a failed verification feels like an insult; mitigated by the Write fallback, the split (a recogniser miss followed by two right splits is a slip), and the isolating question after a closed case.
- **Hard items are hard for the wrong reason** (a rare word that is not hard grammar). Downside: a native can miss a word he never met; mitigated by weighting form and closeness, and by the checks.
- **Hardness is a guess without population data,** and so are the model's parameters (question 1). Downside: early runs may be too easy, too hard, too trusting or too slow.
- **A positioning run is long.** Downside: three or more skills at 7 or more questions each cross 25 and are tiring (5.3, point 7); mitigated by the checkpoint, the floor-first proposal and model-only checks; the learner can always stop.
- **No evidence is stored across runs.** Downside: a second run repeats the work of the first; accepted because the owner dropped "fit again later".
- **A run that stops at the checkpoint has low assurance for some skills.** Downside: the placement can be off by a tenth of the path; shown honestly as "Not sure yet" or "Fairly sure", never as a fail.
- **The model assumes knowledge is roughly monotone along the path** (what is known at deck d is known below it). Downside: a heritage speaker or a script gap breaks it; the decoupled-skill rows (g, i) handle those, not a longer search.
- **The battery tests grammar through the deck's own sentences.** Downside: a language with thin grammar decks gets weaker grammar evidence (row l).
- **Say fails a fluent speaker of another dialect.** Downside: a correct answer is failed by the recogniser; question 8 decides how Say is graded.
