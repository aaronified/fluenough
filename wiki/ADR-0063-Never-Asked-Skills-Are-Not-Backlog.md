# ADR-0063: A skill never asked is not a backlog; a script not read yet is never held back

Source of truth: this wiki page.

- **Status:** Accepted (owner order, 2026-11-22). The plan is [Plan-Today-Backlog](Plan-Today-Backlog).
- **Date:** 2026-11-22

## Context

After Find my level, Today counted the unasked skills of placed words as reviews due. A learner with 3,000 words credited in one skill and 16,000 grammar cells saw 19,810 reviews and a year of "Catching up", with no new words and no way to start the script they had to learn.

## Decision

- The backlog, "Catching up", the reviews-waiting number and the days to catch up count only pairs whose state is due now.
- The new skills of taught words enter through the day's new share, paced (a fifth of the day's cards, at least three, a day), in path order; none while really catching up.
- While catching up, up to five cards of the script decks of a script the learner is learning are still taught each day.

## Consequences

- Right after placement nothing is due, Today does not say Catching up, and new words and a few new skills are planned.
- A learner with a real backlog is still told so, and still gets reviews first.
- The unasked skills of a placed word come over days, not at once.
- Skill tiles keep counting what a tap serves; they never feed the backlog.

## Alternatives considered

- **Count new pairs at a lower weight.** Still lets thousands of them push a learner into catching up.
- **Mark placed words' other skills as reviewed at placement.** Changes placement credit, which would hide skills the learner may not know.
- **Let every lesson run while catching up.** Defeats the reason for catching up; only a script nobody can read without has no other way in.
