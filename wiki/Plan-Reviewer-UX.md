# Plan: reviewer UX, gating and checking

Source of truth: this wiki page.

Status: brainstorm settled with the owner on 2026-11-20/21, not built; an ADR and approved mockups ([mockups README](https://github.com/aaronified/fluenough/blob/main/docs/mockups/README.md)) come before any code.

Goal (owner): ease of use, gated to actual speakers as much as possible, and comprehensive reviews that a second speaker can check easily.

Each decision below has its main downside. Decisions marked "assumed, confirm" were not decided by the owner; they are defaults for the owner to confirm or change. Nothing here changes the app-facing [Reviewing Guide](Reviewing-Guide) until it is built.

## Decisions

### 1. Gating moves into placement: the reviewer check

Owner: "The B group should mostly go into placements. Right, when the user seems to be aceing the tests."

Option P3 was chosen:

- After a normal placement reaches the top band, the app shows a quiet nudge. It shows once per course and never again after "No thanks".
- The nudge leads to a dedicated **reviewer check** (Settings > Reviewing > Take the check). It is the placement engine ([Plan-Placement-V3](Plan-Placement-V3)) in a stricter mode: a tighter confidence target, no guessable formats, and per-facet results.
- The outcome is **Provisional** status only.
- Anyone who reaches the top band qualifies, native or strong second-language speaker.
- **Top band** means the credible range's lower bound is at B1 on Read and Write, plus Hear for the reading, IPA and audio facets. Self-rated Say never counts, because only Telugu has a scoring recogniser.
- **Retake:** a 7-day cooldown, with fresh items. No expiry.
- **Privacy:** nothing leaves the phone except a coarse "passed facets" flag in the first review mail. It is used for triage only, because the bot cannot verify it.
- **Fallback:** thin courses (too few items) and languages without placement fall back to codes the owner maps to Verified (decision 8).
- **Launch gate:** a persona replay and an adversarial retest of the stricter mode, as Plan-Placement-V3 required, and a release with a `min_app` gate if data changes.

Facet eligibility from the check:

| Passed | Eligible facets |
|---|---|
| Read and Write | word, meaning, example, notes |
| Hear | reading, IPA, audio |
| Read, plus grammar items | unit placement and grammar notes |

Main downside: the check is an unverifiable self-test run on the phone, so it can only ever grant Provisional status, and a strong second-language speaker passes the same as a native one.

### 2. Reviewer-check item rule

Owner: "Do not use any question type where a right answer can be marked wrong, even a 1% chance is too bad."

- Only **pick, match and yes/no** items. No typed answers and no tile sentences.
- Keys come only from cards with at least two checks.
- Distractors must be provably wrong: checked against the card's `alt_native` and `not_synonyms`, drawn from the same unit or word class as near misses, and never a synonym of the key.
- Residual risk is made harmless, not impossible:
  - no per-item feedback;
  - an "this is also right" tap that suspends the item and removes it from the score;
  - no single miss decides;
  - failing only means "not yet eligible".
- **Pilot slot:** a new item runs unscored. It is promoted after about 8 Verified responses with 90% or more agreeing with the key. A split (about 60/40) retires it as dialect-sensitive.
- Fix history (the old form against the agreed fix) becomes gold items.
- **Bootstrapping:** the first Verified reviewers of a language come from codes the owner maps to Verified.
- Pilot misses also reveal deck errors.
- **Strict-zero alternative:** only wrong-by-construction items. It is a narrower, easier test; it was offered and not chosen.

Main downside: a narrower item set than placement, and pilot slots need Verified reviewers who do not exist until the owner issues codes.

### 3. Taught-from language

Owner: "Both languages must be review gated (this will happen separately). English is assumed to be review ready for everyone. So no deck today will need any double check. Later decks may need individual takes."

Main downside: every deck taught from a language other than English will need its own review gate, which is separate work not planned here.

### 4. Counts are hidden

Owner: the number of reviewers is a card-level number only, small and not prominent in card detail; no course-level tag. The quorum of 2 "will not reflect anywhere in the app, not even hinted at" (owner: "We are now happy at 2 because we may not have abundant reviewers").

- Reviewer screens say "needs another speaker's check", with no number.
- The file-level "reviewed / unreviewed" notice is hidden for the same reason. This is the orchestrator's reading of the owner's "Ok": **assumed, confirm if wrong**.

Main downside: learners lose the at-a-glance signal of how well a course is checked, and reviewers cannot see how close a card is to done.

### 5. Pointer tags

Owner: "let reviewers simply tag the card pointers too (like the meaning is wrong, pronounciation is wrong, etc)".

- One-tap, per-facet tags, combinable, with a replacement optional: meaning wrong, reading wrong, IPA wrong, spelling wrong, unnatural/rare, wrong register, offensive, example wrong, note wrong, wrong unit, audio wrong.
- A tag without a fix puts the card in a **flagged** queue that any speaker can resolve.

Main downside: tags without fixes can pile up in the flagged queue faster than speakers clear it.

### 6. Facets and the "everything looks right" shortcut

- Facets: word, reading, IPA, meaning, example, note, unit placement, offence rating, audio.
- A card counts as reviewed only when every applicable facet has an answer.
- A one-tap "everything looks right" shortcut covers the plain facets only (word, meaning, example). Reading, IPA and audio are confirmed separately. Owner: "Shortcut for plain facets only".

Main downside: more taps per card than today's single "Looks right".

### 7. Blind pass and free text

Owner: "For C blind pass, we need to figure out how to handle card features where reviewers have put free text."

- **Verdicts are blind:** the second reviewer does not see the first verdict.
- **Proposed fixes are open:** the original and the proposal are shown, and the second speaker accepts, rejects, or offers another.
- **Rival fixes** go to a third speaker as a pick-one list.
- A fix identical after normalisation (Unicode NFC, whitespace, stray joiners, per-script variants) is agreement, with no human step.

Per facet:

| Facet | How a fix is made and checked |
|---|---|
| Reading, IPA | Fixes are picked from engine-generated candidates; free entry only as an override. |
| Spelling | Lexicon variant chips. |
| Meaning | "Both fine" adds the second meaning to the accepted alternatives. |
| Note, example | A second speaker accepts or rejects a rewrite whole. |
| "Why" text | Advisory only; shown after the second reviewer's own verdict. |

A second speaker checks through a **per-unit digest** of only what changed or is contested, with receipts (card, facet, hash of the text seen, decision). The owner gets a coverage dashboard (facets with at least two independent checks).

Main downsides: per-facet taps add work, and the normalisation rules per script can show a false "different".

### 8. Codes and tiers

Owner: "I like the trust based reviewer and distributed reviewer codes. I will assign the languages associated with the reviewer codes".

Amended by the owner, 2026-11-21: no signed codes and no signing key. "In 1, i was thinking of using the FL codes only. Just that I will create a mapping myself".

- Reviewers keep the self-created `FL-XXXX-XXXX-C` rater codes only (`lib/core/review/rater_code.dart`).
- The owner creates the mapping himself: code to assigned languages or courses, and tier.
- The mail bot (`tools/mail_to_issues.py`) enforces the mapping, and rate-limits per code. A code with no mapping for a course stays Provisional: its review is held until a Verified reviewer agrees.
- Where the mapping lives is **open for the owner** (see below).
- Where the mapping is public, the app can offer a reviewer only the assigned courses.

Tiers:

| Tier | How earned | Effect |
|---|---|---|
| Provisional | Reviewer-check pass, or an unmapped `FL-...` code | Counted only alongside a Verified reviewer. |
| Verified | Mapped by the owner for the course, or calibration cards | Counts fully. |
| Trusted | Sustained agreement with Verified reviewers | Breaks ties on contested cards. |

A Provisional review is held in the queue and applied only when a Verified reviewer agrees (owner: "1. Ok.").

**Rater codes are public** (issues and decks name them), so a code alone does not prove who sent a review. The mapping should bind each code to the sender mail address its first review came from (already planned in `rater_code.dart`, **not built yet**). A review from another address is held for the owner.

**Where the mapping lives (open, owner to decide):**

The owner asked: "Then anyone can see it?" about a public mapping file on `decks-live`. Answer: yes. It would be public, including the tiers, so Verified codes would be easy to pick out. Rater codes are already public, so a copied code only fails if the sender-address binding (not built) exists.

| Option | Effect |
|---|---|
| Private (bot-only, read by `tools/mail_to_issues.py` only) | The app cannot grey out unassigned courses. A reviewer learns their status when the owner tells them. |
| Public shared file on `decks-live`, keyed by code | The app can unlock the assigned courses; it reveals which languages and tiers a pseudonymous code holds, and makes Verified codes easy to pick out. |

The orchestrator's lean is now **private** (bot-only), for the reasons above. The owner decides.

**Revocation** (owner: "I revoke. And it does revoke past work."): only the owner revokes, by removing the code from the mapping. That removes the reviewer's past contributions:

- their code is removed from `checked_by`;
- cards that fall below the quorum return to unchecked or flagged;
- changes that applied only because of that reviewer are queued for a revert PR on `decks-live`.

Main downsides: the owner's manual mapping work; spoofing of a public code until the address binding is built; revocation causes churn on `decks-live`, and file-level reviewed tags may flip back.

### 9. Review queue

Owner (2026-11-21): "least-checked first, grouped by unit within a session. So a session takes one unit's least-checked cards, and the flagged queue is a separate tab. Yes. But give them 1 more option to check the flagged and contested queue only."

- A session takes one unit's least-checked cards, in path order within the unit.
- The flagged queue is a separate tab.
- A second mode lets a reviewer check only the flagged and contested queue.
- Progress is saved and resumable.
- Session size of 20 cards, with a continue option: **assumed, confirm** (not discussed).

Main downside: jumping between units loses context.

### 10. Not decided: defaults assumed, confirm

| # | Default | Status |
|---|---|---|
| A3 | One-tap agree with another reviewer's proposal. | covered by decision 7 (open pass for proposals: accept, reject or offer another); no separate decision needed |
| A4 | Typing in the learner's script, with an IME hint and the card's existing reading shown. | open, confirm |
| Submit | In-app submit instead of mail is **not** planned; mail stays. | assumed, confirm |

**A4 note.** The IME hint question was not discussed with the owner and is still open. The orchestrator's recommendation: no custom keyboard. Use the phone's keyboard, show the card's current reading, and offer candidate chips (engine candidates, lexicon variants) so typing is rare. This follows the owner's preference for YAGNI.

## Open and next, in dependency order

1. An ADR recording decisions 1 to 8 (Sonnet).
2. Mockups (Sonnet), following the [mockups README](https://github.com/aaronified/fluenough/blob/main/docs/mockups/README.md): 1.4x text, light and dark.
3. Issues, with dependencies marked as "blocked by" and the `blocked` label, never assumed.
4. Code, only after the owner approves the mockups.

Also open: the persona replay and adversarial retest of the stricter placement mode (decision 1) must pass before the reviewer check ships.

See also: [Reviewing Guide](Reviewing-Guide) · [ADR-0038](ADR-0038-Review-Proposals) · [Review Staging](Plan-Review-Staging) · [Reviewing Scope](Plan-Reviewing-Scope) · [Placement V3](Plan-Placement-V3) · [Plans Index](Plans-Index)
