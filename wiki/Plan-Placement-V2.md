# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.

## Find my level: verify, then fit, and how a run samples questions (plan, owner, 2026-11-05)

Status: a plan only. Nothing here is built; the owner will be consulted before it is. Open questions are at the end; each has a default the plan assumes.

Owner, 2026-11-05: "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." / "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." / "Verification will only be given after the language has all planned decks and verification run has used all of them." / "I mean full B1 completion level as per the path. Bengali already has that." / "Keep placement question count within 25 questions." / "Ask the last deck. If known, sample around that till you find serious flaws. If not known at all (2 questions min), go to 1st deck and keep sampling from there. Build a strategy around this kind."

### 1. Definitions

- **Deck order.** The language's word decks in path order, from the first A1 deck to the unit marked B1 (`CoursePath`, `walkDecks`). Index 0 is the first, N-1 the last (B1's end). Script decks are checked by the script check, not here.
- **Complete to B1.** The path marks B1 and no unit up to it is still to be written. Today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona. Only these can be verified; the others only fit.
- **Known (a deck).** A question from it is answered right, or its second question is after one miss. "I don't know" counts as a miss.
- **Serious flaw.** Any of: (a) two misses in the same deck (a first miss always gets a second question from the same deck, with a different item); (b) a miss on an item marked easy (a first-level word, a deck's core item); (c) three misses in any run. Why: one slip is noise (a tap, a mis-hear); two in one place is a gap; a miss on an easy item says the level below it is unsafe; three over a run is a sustained rate (about 12% of 25) whatever the decks.
- **Verified (a skill).** The run ended without a serious flaw across the decks it sampled, started from a known last deck, and the preconditions hold (path complete to B1, every indexed deck downloaded). It does not require touching every deck. Verified is a state of one skill, kept per language.
- **Placed level.** The first deck from which the learner should learn: every deck before it is credited as known (the existing `placedDeckIds`).

### 2. The state machine

| State | Asks | On right | On miss | On "I don't know" |
|---|---|---|---|---|
| LAST | 2 questions of the last deck (N-1) | after 2: at least one right goes to AROUND | after 2 with none right goes to FIRST | a miss |
| AROUND | one question per deck, going backward from N-1 | next deck in the schedule | ask the deck again; second miss is a serious flaw: stop, flaw deck = that deck | a miss |
| FIRST | the first deck (0), then forward | next deck in the schedule | ask again; second miss is a serious flaw: stop at that deck | a miss; two in deck 0 stop: nothing known, learn from 0 |
| DONE | nothing | | | |

- **AROUND schedule.** Backward from the last deck at growing steps, each step the last two together (1, 1, 2, 3, 5, 8, ...), so the offsets from the last deck are 1, 2, 4, 7, 12, 20, 33, ...; a seed nudges each pick by less than its step so two runs differ; the first deck is always the final stop. A path of 20 decks or fewer is sampled in every deck instead. Why growing steps: the last decks matter most for B1 and a flaw there is cheap to find; far decks are probed more sparsely since a learner who knows B1 words nearly always knows A1 ones. The run ends verified when the schedule is exhausted without a serious flaw.
- **FIRST schedule.** Deck 0, then forward at the same growing steps (0, 1, 3, 6, 11, ...) up to the deck before the last. It stops at the first serious flaw, which is where the learner lands. If the schedule ends without one the learner is placed at N-1 (everything but the last deck known) and is not verified, as the last deck was missed.
- **Flaky learner.** Misses that are forgiven (right on the second question) still count toward the three-miss rule. A run in AROUND with 3 misses stops at the last deck sampled, not verified, placed at the deepest deck before the flaw.
- **"I don't know".** A button on every question, counted as a miss and never followed by a hint. It exists so that nobody guesses on a skill they do not have.

### 3. The 25-question budget

| Part | Questions | Notes |
|---|---|---|
| LAST | 2 | always |
| AROUND for a known last deck | about 10 to 14 for a 100+ deck path, the path's length for 20 decks or fewer | the schedule is logarithmic in the path |
| Second questions after a miss | up to 2 more (a third miss stops the run) | |
| FIRST after a missed last deck | about 10 to 14 | |
| Reserve | the rest | the hard stop is 25 |

If the 25 run out mid-search the run stops where it is and is **not verified**: it places the learner below the deepest deck sampled right and records nothing as verified. It is never extended. A per-skill split (one run per skill, section 5) shares the 25: Verify spends up to 25 over all its skills together, in the order spoken, then each script.

### 4. Per-question rules

- **Item within a deck.** The deck's core item (the first card of the unit's theme) for the first question; a random not-yet-asked item for a second; never the same card twice in a run. Only the skill under test is asked: Hear asks a heard word; Speak a word to say aloud; Read a word in its script to choose or transliterate; Write a word to build or type.
- **Distractors.** Options from the same deck first, then neighbouring decks, of the same kind (all words, or all forms), never the same meaning, never a card already asked. Two to four options as the existing questions have them.
- **Spoken.** Hear needs a voice and sound on; Speak needs the recogniser. Without either, the skill is asked as the written fallback the script check already uses (a harder word to choose in the script). If neither the written fallback nor the skill is possible, the skill is left unverified, not failed, and the sheet says why.
- **Scripts.** A script's Read and Write are checked together by the existing five-level script check (at most 10 questions), before the word sampling of that run, and count in the 25.

### 5. Outcomes

| Result | Verified | Placed level | Learn from |
|---|---|---|---|
| Run ends verified (AROUND exhausted) | the skills in the run | every deck | nothing; review only |
| Flaw found in AROUND at deck X | none | decks before X | X |
| LAST missed, FIRST ends at flaw deck Y | none | decks before Y | Y |
| Nothing known (deck 0 missed twice) | none | none | deck 0 |
| Budget runs out | none | below the deepest deck sampled right | that deck |

A run never changes a skill's state (Learn, Know, Leave); only the credit and the verified mark change. **Hindustani:** Speak, Hear and Devanagari are known and not verified, so the button reads "Verify what you know" and runs only those; when they are verified (or no known skill is left unverified) it reads "Fit my level" and runs the placement for the Perso-Arabic script, which is not known, over its own decks. A language not complete to B1 shows "Fit my level" with a line saying known skills cannot be verified until its course is complete.

### 6. Short and long paths

- **N of 20 or fewer.** Every deck is sampled once (one question each, a second after a miss): at most N plus 2, under 25.
- **N between 21 and 25.** The growing-step schedule is used, which asks fewer than N decks.
- **N over 25 (every complete language today, Bengali about 169 units).** About 10 to 14 decks are sampled; all stay inside 25.
- **N under 2.** One deck is asked twice.

### 7. Worked examples (N = 100, B1 complete)

| Learner | Questions and path | Result |
|---|---|---|
| Native speaker | deck 99 twice (right, right); AROUND at 98, 97, 95, 92, 87, 80, 68, 49, 20, 0, each right: 12 questions | Verified, placed above deck 99 |
| Beginner | deck 99 twice wrong; FIRST: deck 0 right, 1 right, 3 miss then miss: 7 questions | Not verified; placed at deck 3; learn from 3 |
| A2-level (knows to deck 40) | deck 99 twice wrong; FIRST: 0, 1, 3, 6, 11, 19, 31 right, 52 miss, 52 miss: 12 questions | Not verified; placed at deck 52 (the flaw deck; may be refined by the existing walk); learn from there |
| Flaky (right 60% of the time) | deck 99 right, miss; AROUND: 98 right, 97 miss then right, 95 miss, a third miss: stops, about 8 questions | Not verified; placed at the deepest deck before the flaw |
| Partial script (Hindustani, Devanagari known, Perso-Arabic not) | Verify: Devanagari check, then speaking and hearing; Fit: Perso-Arabic script check asks nothing (the learner says they do not read it) and places it at its first deck | Devanagari, Speak and Hear verified; Perso-Arabic learn from its first deck |

### 8. Risks and open questions

Risks, with the main downside of each:

- **Sampling misses a weak deck between two sampled ones.** Verified is then a spot check, not proof. Downside: a learner can hold "verified" with a hole.
- **"Last deck first" favours the end of the path.** A learner who only learned B1 vocabulary by heart passes. Downside: the A1 spot check in AROUND is one question.
- **A strict flaw rule fails good learners on a bad day.** Downside: a failed verification feels like a demotion; mitigated by a retry in a later run.
- **No speech recogniser or voice.** Downside: Speak and Hear may never be verified on such a phone.
- **A run over several skills splits 25 questions thinly.** Downside: each skill is sampled by fewer decks.

Open questions for the owner (defaults assumed above):

1. Is "serious flaw" right as two misses in one deck, a miss on an easy item, or three misses in a run? (default: yes, all three)
2. Should a learner whose last deck is not known ever be verified in part, for example up to the deck they pass? (default: no, only placed)
3. Is one verified mark per skill right, or one per language? (default: per skill)
4. Should "I don't know" count as a miss? (default: yes)
5. When the 25 run out mid-search, place below the deepest deck sampled right (default) or ask for a second run?
6. Should a language short of B1 be verifiable up to the units it has (for example Telugu's A1 once built)? (default: no, per the 2026-11-05 rule)
7. When Speak or Hear cannot be tested (no voice or recogniser), leave the skill unverified (default) or fall back to the written question and mark it verified?
8. Does Verify run all known skills in one 25-question run (default) or each skill with its own 25?
