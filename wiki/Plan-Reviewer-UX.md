# Plan: reviewer UX, gating and checking

Source of truth: this wiki page.

Status: brainstorm settled with the owner on 2026-11-20/21, not built; an ADR and approved mockups ([mockups README](https://github.com/aaronified/fluenough/blob/main/docs/mockups/README.md)) come before any code.

Goal (owner): ease of use, gated to actual speakers as much as possible, and comprehensive reviews that a second speaker can check easily.

Each decision below has its main downside. Decisions marked "assumed, confirm" or "reading, confirm if wrong" were not decided by the owner; they are defaults or readings for the owner to confirm or change. Nothing here changes the app-facing [Reviewing Guide](Reviewing-Guide) until it is built.

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
- **Fallback:** thin courses (too few items) and languages without placement fall back to signed reviewer keys (decision 8).
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
- **Bootstrapping:** the first Verified reviewers of a language come from owner-minted signed reviewer keys.
- Pilot misses also reveal deck errors.
- **Strict-zero alternative:** only wrong-by-construction items. It is a narrower, easier test; it was offered and not chosen.

Main downside: a narrower item set than placement, and pilot slots need Verified reviewers who do not exist until the owner issues keys.

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

Amended by the owner, 2026-11-21, then reversed the same day: "on second thought on the verified reviewer, it is weird to ask them to change their codes or map those codes in. Rather, we should do the signed keys..." This replaces the "FL codes only, owner mapping" amendment. Signed reviewer keys are the design.

- **Minting:** the owner mints a signed reviewer key per Verified reviewer with a small script. The payload is the key id, the assigned courses or languages, the tier and the issue date, signed with the owner's private key (Ed25519 suggested). The public key is versioned and ships in the app and the mail bot.
- **Entry:** the reviewer pastes the key in Settings > Reviewing > "I have a reviewer key". The app verifies the signature offline and unlocks only the assigned courses.
- **No exchange of FL codes:** reviewers keep their self-created `FL-XXXX-XXXX-C` rater codes (`lib/core/review/rater_code.dart`) and never send them to the owner. No mapping file exists, so there is no question of where a mapping lives.
- **Binding:** the first review mail carrying the key binds the key id to that reviewer's FL code. Each review mail carries the key as a secret proof. The bot (`tools/mail_to_issues.py`) verifies the signature, the denylist and that the bound code matches. It strips the key before anything is published and never echoes it into issues, PRs or decks. A copied public FL code alone proves nothing, which fixes the spoofing problem of FL-only. A mail with the key but a different FL code, or from an unexpected address, is held for the owner. The bot also rate-limits per key.
- **Already reviewing or not** (owner, 2026-11-21: "That way no matter whether they are already reviewing or not, they can easily become verified."): a reviewer who already reviews keeps their FL code, and the first review carrying the key binds the key to it. A new reviewer pastes the key, and the app turns reviewing on and makes their code.
- **Earlier reviews** (owner, 2026-11-21, on the orchestrator's proposal: "3. Yes."): when a signed key binds to an existing FL code, that code's earlier reviews are upgraded to Verified weight. Downside: it trusts the earlier work as much as the later.
- **Without a key:** self-created FL codes stay Provisional (held until a Verified reviewer agrees). The reviewer check (decision 1) also yields Provisional only.

Tiers:

| Tier | How earned | Effect |
|---|---|---|
| Provisional | Reviewer-check pass, or an `FL-...` code with no key | Counted only alongside a Verified reviewer. |
| Verified | A signed reviewer key for the course, or calibration cards | Counts fully. |
| Trusted | Sustained agreement with Verified reviewers | Breaks ties on contested cards. |

A Provisional review is held in the queue and applied only when a Verified reviewer agrees (owner: "1. Ok.").

Signed keys also serve as the fallback for thin courses and languages without placement, and for the first Verified reviewers of a new language.

**Revocation** (owner: "I revoke. And it does revoke past work."): only the owner revokes, by adding the key id to a denylist in the repo (ids only). The app also checks the denylist. All work bound to that key id is removed:

- their code is removed from `checked_by`;
- cards that fall below the quorum return to unchecked or flagged;
- changes that applied only because of that reviewer are queued for a revert PR on `decks-live`.

Main downsides:

- The owner's private signing key must stay secret. Keep it offline and rotate with versioned public keys; a leaked key lets anyone mint keys.
- Minting is manual (a one-command script).
- A shared key cannot be used with a second FL code (the mail is held).
- The mail carries a secret, so the bot must never log or echo it, and mail archives keep it (revocation covers that).
- A new app release is needed to ship the public key and the key entry screen.
- Revocation causes churn on `decks-live`, and file-level reviewed tags may flip back.

### 9. Review queue

Owner (2026-11-21): "least-checked first, grouped by unit within a session. So a session takes one unit's least-checked cards, and the flagged queue is a separate tab. Yes. But give them 1 more option to check the flagged and contested queue only."

- A session takes one unit's least-checked cards, in path order within the unit.
- The flagged queue is a separate tab.
- A second mode lets a reviewer check only the flagged and contested queue.
- Progress is saved and resumable.
- **Session size** (owner, 2026-11-21: "Ok. But reviewers get to continue beyond that (this continue pool will have all cards and they can stop when they want by closing the review)."): a session is 20 cards, one unit's least-checked (as above). After 20 the reviewer may continue through a pool of all the course's cards, least-checked first and still grouped by unit, and stops whenever they close the review. Nothing is lost on closing: answers are saved as they go.

Main downside: jumping between units loses context.

### 9a. Same shell as today's review

Owner (2026-11-21): "Also, the review questions should be similar to the existing shell."

Orchestrator's reading (**reading, confirm if wrong**): the new facet questions and pointer tags are built on the existing review screens and the daily-questions flow in `lib/features/review/` (`review_page.dart`, `daily_questions_page.dart`, `review_sheets.dart`: weakest data first, "put off today", the sent and not sent pages), not a new separate screen family. The queue logic is `lib/core/review/review_queue.dart`.

### 9b. Review from the deck view

Owner (2026-11-21): "Also, reviewers can go into the deck view and review specific units or cards from there manually too. That will use something like the current existing review screen with all the card details."

From the deck view (`lib/features/decks/`: `deck_detail_page.dart`, `unit_page.dart`, `word_sheet.dart`) a reviewer can review a chosen unit or a single card, on a review screen showing every card detail (all facets). It uses the same facet answers, tags and receipts as the queue.

### 9c. Quorum: each card detail is reviewed twice

Owner (2026-11-21): "Each card detail will need to be reviewed twice (save the number somewhere as a constant) for the card to be considered reviewed."

- Each facet (card detail) needs 2 reviews by two distinct reviewers. A card is reviewed only when all its applicable facets have 2.
- Combined with the tier rule of decision 8, at least one of the two must be Verified; a Provisional review counts only alongside a Verified reviewer. This combination is the **orchestrator's reading, confirm**.
- The number lives in ONE constant: a new Dart constant in `lib/core/review/` (for example `kReviewQuorum = 2`) and a matching constant on the tools side (the bot and validator code, `tools/mail_to_issues.py` and the deck tools). A test keeps the two equal.
- This supersedes the GitHub secret of [ADR-0038](ADR-0038-Review-Proposals) ("This number can be a github secret so that I can update it easily"): changing the number is now a code change.
- The number is never shown in the app (decision 4).

Consequence: the file-level reviewed tag logic of ADR-0038 (a file is tagged `reviewed` when every card entry lists a code) must change to the facet-level two-check rule above, in the bot and in the validator and index tools that read the tag.

### 10. Not decided: defaults assumed, confirm

| # | Default | Status |
|---|---|---|
| A3 | One-tap agree with another reviewer's proposal. | covered by decision 7 (open pass for proposals: accept, reject or offer another); no separate decision needed |
| A4 | Typing in the learner's script, with an IME hint and the card's existing reading shown. | decided (owner, 2026-11-21: "Script writing: b, fallback on a"; see the A4 note) |
| Submit | In-app submit instead of mail is **not** planned; mail stays. | assumed, confirm |

**A4 note.** Decided (owner, 2026-11-21: "Script writing: b, fallback on a"): level (b), falling back to (a) where a script or device gives no help. That is a prefilled field plus candidate chips, the card's reading beside it, paste allowed and a keyboard hint, falling back to a plain phone-keyboard field. The three levels were:

- **(a) Phone keyboard only.** Cheapest; typing in an unfamiliar script is hard for some reviewers.
- **(b) Phone keyboard plus helpers.** The field is prefilled with the current text, so most fixes are 1 to 2 character edits. Candidate chips (engine candidates, lexicon variants), the card's reading beside the field, paste allowed, and a one-line hint to enable the script's keyboard in system settings.
- **(c) A custom in-app transliteration keyboard.** Type in Latin, get the script. A big per-script build.

Level (c) was not chosen.

## Open and next, in dependency order

1. An ADR recording decisions 1 to 9 (including 9a to 9c): written, [ADR-0058](ADR-0058-Reviewer-UX), Proposed (Sonnet).
2. Mockups (Sonnet), following the [mockups README](https://github.com/aaronified/fluenough/blob/main/docs/mockups/README.md): 1.4x text, light and dark.
3. Issues, with dependencies marked as "blocked by" and the `blocked` label, never assumed.
4. Code, only after the owner approves the mockups.

Still open: only the three readings marked "confirm" (9a, the Provisional-plus-Verified quorum in 9c, and the hidden file-level notice in decision 4), which wait for the owner. A4 and the session size are decided.

Also open: the persona replay and adversarial retest of the stricter placement mode (decision 1) must pass before the reviewer check ships.

See also: [Reviewing Guide](Reviewing-Guide) · [ADR-0058](ADR-0058-Reviewer-UX) · [ADR-0038](ADR-0038-Review-Proposals) · [Review Staging](Plan-Review-Staging) · [Reviewing Scope](Plan-Reviewing-Scope) · [Placement V3](Plan-Placement-V3) · [Plans Index](Plans-Index)
