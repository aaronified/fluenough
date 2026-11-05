# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.

## Find my level: verify, then fit (owner, 2026-11-05)

The owner, 2026-11-05: "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." and "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." and "Verification will only be given after the language has all planned decks and verification run has used all of them."

- The button never changes a skill's state. If the language's decks are not all on the phone it downloads them first.
- While a skill is marked known and not verified, it reads "Verify what you know" and checks only the known skills: the script check of each known script, and the word walk when Speak or Hear is known.
- Otherwise it reads "Fit my level" and places the skills not known (Hindustani: Perso-Arabic script when the rest is known and verified).
- Preconditions of verified: the language's path is complete to B1 (below) and every deck the index lists for it is on the phone (`AppState.levelVerified`).
- "All planned decks" means the whole path to B1 (owner, 2026-11-05: "I mean full B1 completion level as per the path. Bengali already has that."): the path marks B1 and no unit up to it is still to be written (`AppState.pathCompleteToB1`). A language short of that cannot verify; its button reads "Fit my level" and says so. Complete today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona.
- Question count (owner, 2026-11-05: "Keep placement question count within 25 questions."). A verification run asks at most 25 questions.
- Sampling (owner, 2026-11-05: "Ask the last deck. If known, sample around that till you find serious flaws. If not known at all (2 questions min), go to 1st deck and keep sampling from there. Build a strategy around this kind."), `lib/core/placement/verify_sampler.dart`:

| State | Asks | Next |
|---|---|---|
| last | 2 questions of the last deck | one or two right: around; none right: first |
| around | one question per deck, backward from the last at growing steps (every deck on a path of 20 or fewer), then the first deck | a miss asks the deck again; a serious flaw ends the run; the end of the schedule ends it verified |
| first | the first deck, then forward at growing steps | a serious flaw ends the run at that deck; the end of the schedule ends it, not verified |

- A serious flaw is two misses in one deck, or three misses over the run. A run cut short by the 25 limit is not verified.
- Verified means the run ended without a serious flaw across the decks it sampled; it no longer requires touching every deck. A run that began in the first state (the last deck not known) is never verified: it only places.
- Main downside: a sample can miss a weak deck between two sampled ones, so verified is a spot check, not proof, and a path of 100+ decks is sampled in about 10 to 15.
- Status: the sampler and its tests are built; drawing the real questions from its decks and recording verified from its result is the next step, until which the word walk places and verified follows the existing credit rule.
