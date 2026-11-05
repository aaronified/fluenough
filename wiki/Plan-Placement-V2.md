# Plan: placement, script first, then a three-skill check

Source of truth: this wiki page.

Retired on 2026-11-04: fully built and merged. See [Plans Retired](Plans-Retired) for its status and the pull requests that built it.
The full text is in git history: `git show 98be3004:wiki/Plan-Placement-V2.md`.

## Find my level: verify, then fit (owner, 2026-11-05)

The owner, 2026-11-05: "when i pressed fit, it only made hear and say as learning. It shouldn't have done that and instead just downloaded the deck and check everything." and "Let it show verify knowledge first for known parts. And then after that or if all the known parts are verified, change it to fit my level. So that there is no confusion, even with Hindustani, where i know everything other than the perso arabic script." and "Verification will only be given after the language has all planned decks and verification run has used all of them."

- The button never changes a skill's state. If the language's decks are not all on the phone it downloads them first.
- While a skill is marked known and not verified, it reads "Verify what you know" and checks only the known skills: the script check of each known script, and the word walk when Speak or Hear is known.
- Otherwise it reads "Fit my level" and places the skills not known (Hindustani: Perso-Arabic script when the rest is known and verified).
- A skill is verified only when every deck the index lists for the language is on the phone and placement credited every word deck of the course (`AppState.levelVerified`). A run that stops earlier does not verify.
- "All planned decks" means the whole path to B1 (owner, 2026-11-05: "I mean full B1 completion level as per the path. Bengali already has that."): the path marks B1 and no unit up to it is still to be written (`AppState.pathCompleteToB1`). A language short of that cannot verify; its button reads "Fit my level" and says so. Complete today (index, 2026-11-05): Assamese, Bengali, Spanish, Hindustani, Kannada, Marathi, Telugu, Toki Pona.
- Open: the walk stops where the learner fails and asks a few questions per deck, so verifying over every deck of a long course can take far more questions than the owner's 2026-10-20 limit allows. See the pull request for the options.
