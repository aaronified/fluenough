# Plan: reviewer UX, gating and checking

Source of truth: this wiki page.

Status: built, not yet released; see the [Release checklist](#release-checklist). Work packages W1 to W9 are merged to main (#1662 to #1670); the reviewer UX is not live until the owner has done the checklist. The decisions below were settled with the owner on 2026-11-20/21; an ADR and approved mockups ([mockups README](https://github.com/aaronified/fluenough/blob/main/docs/mockups/README.md)) came before the code.

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

1. An ADR recording decisions 1 to 9 (including 9a to 9c): written, [ADR-0058](ADR-0058-Reviewer-UX), Proposed (Sonnet). Done.
2. Mockups (Sonnet): approved (`docs/mockups/reviewer-ux.html`). Done.
3. Issues W1 to W10: made, with dependencies marked.
4. Code W1 to W9: built and merged to main (#1662 to #1670), with W6 and the facet writing shipped off.
5. The [Release checklist](#release-checklist) below: the owner's steps, in order.

Still open (the owner's, none built until answered):

- The three readings marked "confirm": 9a (the existing shell), the Provisional-plus-Verified quorum in 9c, and the hidden file-level notice in decision 4.
- The persona replay and adversarial retest of the stricter placement mode must pass on real banks before the reviewer check ships (checklist step 5).
- The open questions listed in checklist step 9.
A4 and the session size are decided.

## Release checklist

Built, not yet released. Everything below is for the owner, in order. The order matters: some steps must be in a release before the next step is safe. "Owner's machine" means a machine only the owner controls; code changes still go through a pull request to main (never docs, which go straight to main).

### 1. Make the owner's signing key (owner, own machine; why: nothing else works without it)

1. Run `python3 tools/reviewer_keys.py keygen --private <path>` on your own machine. Keep the private key offline; never put it in the repo, a workflow or an agent's hands. A leaked private key lets anyone mint reviewer keys.
2. It prints a public key entry. Commit it into `assets/reviewer/public_keys.json`, replacing the placeholder row (`PLACEHOLDER-NOT-A-REAL-KEY-RUN-KEYGEN`). This is a code change: a pull request to main with a green CI.
3. Release an app that carries it (Actions > Release, from main). Until the real public key ships, the "I have a reviewer key" row is hidden in the app and the bot ignores keys.
4. The CHANGELOG line "Unlock courses with a reviewer key" must not ship before this release carries the public key (see step 8).

### 2. Mint a key per Verified reviewer (owner, own machine; why: Verified status and course unlock)

Run `python3 tools/reviewer_keys.py mint ...` for each Verified reviewer, naming their courses. Send the key to the reviewer (the reviewer pastes it in Settings > Reviewing). Keep every key id in a private list: you need the id to revoke. No FL code is exchanged: the first review mail carrying the key binds its id to the reviewer's FL code, in the private `fluenough/keys` Gmail label (nothing to set up, nothing public). `verify` reads a key from `--file` or standard input, not from an argument.

### 3. Revoking (owner, on main; why: the only way to remove a reviewer)

1. Add the key id (id only) to `assets/reviewer/denylist.txt` on main (a pull request, not a docs push: the app bundles this file).
2. The app refuses the key from its next release; the bot from its next run.
3. The workflow `.github/workflows/reviewer-revocation.yml` (on a denylist change, every six hours, or by hand from Actions, main only) then opens PRs to `decks-live`, never merged by the bot: one removal PR and one revert PR per revoked key. The owner reviews and merges them.
4. The workflow needs what [Review-Bot-Setup](Review-Bot-Setup) lists: the GitHub App (`fluenough-review-bot`, Repository permissions Contents and Pull requests, Read and write), the two secrets `FLUENOUGH_BOT_APP_ID` and `FLUENOUGH_BOT_PRIVATE_KEY`, and the Gmail secrets the bot already uses (to read `fluenough/keys`). Check the "Revocation removes past work (W8)" section of that page before the first revocation. If the key store is unreadable, the bot applies nothing.

### 4. Writing `facet_checks` to the decks: `WRITE_FACET_CHECKS` (owner decides, a coder builds; why: an app that does not know a card key rejects the file)

`WRITE_FACET_CHECKS` in `tools/proposals.py` is `False`. While it is off the bot still reads facet answers (stale ones are dropped, fixes become proposals, a reviewer right on every facet signs the card off in `checked_by`), but it does not write the `facet_checks` key, so a flag cannot make a facet unsettled in the published decks. Do NOT flip it before an app that reads the key has been released: a phone keeps the decks it has rather than take a file that fails, and CI's "Released app reads the decks" would fail.

How `min_app` works here (read from `decks/min_app.json`, `tools/deck_index.py` and `tools/validate_decks.py`):

- `decks/min_app.json` has `languages {code: version}` and `files {path: version}`. The index copies each as `min_app`. An app that knows the key does not download what needs a newer app and says "Needs app X, Update"; an older app ignores `min_app` and so would still try the file.
- It is only for NEW languages and NEW files. `check_released` in `tools/deck_index.py` reads the latest `v*` tag and refuses a `min_app.json` line for a language in that release's `assets/languages.yaml` or a file already in its `decks/` (an error in CI, a warning without tags). So `min_app.json` cannot gate the existing deck files that will gain `facet_checks`.
- For a new card FIELD, the gate is automatic and per file: `CARD_FIELD_MIN_APP` in `tools/validate_decks.py` (today `character` 0.10.2 and `situation_icons` 0.10.3) and `Report.new_fields`; `_gate_fields` in `tools/deck_index.py` then raises that file's `min_app` to the release that reads the field, with no line in `min_app.json`. `facet_checks` is NOT in `CARD_FIELD_MIN_APP` today (the validator only checks its shape and the index strips it from the content hash), so nothing gates it yet.
- The "Released app reads the decks" check (`.github/workflows/ci.yml`, job `release-reader`; decks-live's CI does the same for the real decks) reads the sample deck with the latest release's own code. A key the latest release rejects fails it: that is the backstop.

Exact steps:

1. Cut a release that includes W9's reader (`lib/core/review/published_facets.dart` and the deck parser change, merged in #1665). Confirm it is the latest `v*` tag.
2. In a pull request to main (code, with one review and green CI): add `"facet_checks": "<that release>"` to `CARD_FIELD_MIN_APP` in `tools/validate_decks.py`, add `r.new_fields.add("facet_checks")` where the validator accepts a card's `facet_checks`, and add a sample card carrying `facet_checks` to the sample deck so the "Released app reads the decks" check proves the release reads it. Then a deck file that carries the key is indexed with `min_app` of that release, and an app older than it keeps its old copy ("Needs app X"). Tell the owner this also stops those older apps getting other changes to the same file until they update.
3. In the same or the next pull request, set `WRITE_FACET_CHECKS = True` in `tools/proposals.py` (and read the comment in `tools/review_bot.py` that mentions it). Tools reach decks-live by the CI overlay; the lib files they read need the sync of step 7.
4. Merge, then watch the first bot run on decks-live: "Released app reads the decks" and "Validate decks" must stay green. If a file fails, set the flag back to `False` (an entry that already carries the key is kept up to date whatever the flag says).

Not verified here: step 2's code change has not been built or run; check that `facet_checks` is parsed in a card path the validator's `new_fields` hook reaches.

### 5. The reviewer check: `kReviewerCheckEnabled` (owner decides; why: it grants eligibility on an unverifiable self-test)

`kReviewerCheckEnabled` in `lib/core/placement/reviewer_check_rules.dart` stays `false`. No row, offer or screen exists while it is. The launch gate (W6, #1657, PR #1670):

1. Re-run the persona replay (`test/reviewer_check_replay_test.dart`) and the adversarial retest on the REAL banks that will ship, not the made-up fixture. Read the "reviewer check replay: ..." CI log lines (the PR's author had not read the final head's). The bars: a true speaker at the top band at least 95%; a guesser, an always-first-option answerer, A1 and A2 learners and the V3 adversary at most 1%. 600 seeded runs cannot certify a 1% bar; the exact tail argument in the ADR note does.
2. Check each course that will offer it has about 95 distinct top-band cards that are twice-checked (the item rule needs a key card checked twice on the facets it depends on). Thin courses fall back to signed keys.
3. Flip the constant in one commit with a release and a CHANGELOG line (the W6 PR deliberately has none). Placement V3's own launch gate (adversarial retest) applies too.

### 6. `QUORUM_NEEDS_VERIFIED` / `kQuorumNeedsVerified` stay off (owner decides; why: open design points)

`kQuorumNeedsVerified` (`lib/core/review/review_quorum.dart`) and `QUORUM_NEEDS_VERIFIED` (`tools/review_quorum.py`) stay `false` until the W7 PR body's points are answered:

- The decks-live validator cannot know tiers (they are private), so only the bot's own decisions use them; the published reviewed tag cannot be checked against tiers.
- The public "held for the owner" label shows that a code sent a key.
- A second key for the same code is held, not added (a reviewer with a lost key has no path).
- The `fluenough/keys` label grows without bound (one `use` record per mail); it may need pruning.
Turning it on is also the owner's reading in 9c (Provisional counts only alongside a Verified reviewer), which is unconfirmed.

### 7. Syncing lib files to decks-live (a coder; why: tools tests read Dart files by path)

CI lays main's tools over decks-live but not `lib/`. `tools/test_review_facets.py` reads Dart files from the repo, so decks-live needs byte-identical copies from main (done in PR #1666): `lib/core/review/fix_text.dart` (white-space rule), `nfc_data.dart` (NFC tables), `facets.dart` (facet and pointer-tag enums), `review_receipt.dart` (`receiptHashLength`), and `review_problems.dart` (only because `facets.dart` imports it). Not copied: `lib/l10n/app_en.arb` (decks-live holds strings main no longer has, so copying main's file would drop them; no tools test needs main's new strings), `review_quorum.dart` (no tools test reads it) and `crypto` in decks-live's `pubspec.yaml` (decks-live's CI does not build the app). Repeat the sync whenever a tools test starts reading another lib file or one of these changes (the comparison folds are checked against `test/support/comparison_fold_cases.json`, so check that file too).

### 8. CHANGELOG lines now in [Unreleased] that mention hidden features (owner/coder, before the next release)

Two lines, both under `## [Unreleased]` in `CHANGELOG.md`:

- "**Unlock courses with a reviewer key.**" The key row is hidden until step 1's public key ships. Drop it from a release that does not carry the real public key; keep it for the release that does.
- "**Review a card one detail at a time.**" Built from W3 and live as soon as the release ships (reviewers see the screens, the deck-view entries and the flagged-only mode); it does not depend on the key or the facet flag. Keep it, but note that other reviewers' facet answers only arrive after step 4, so until then the second-speaker views run on checked-by data only.

W6 added no line (add one when step 5 flips). The facet-level bot work (W5, W8, W9) added none by design.

### 9. Open owner questions (none built until answered)

- **Pashto kaf.** The fold treating Arabic kaf (U+0643) as Persian kaf (U+06A9) for Pashto (`ps`) is applied on the strength of orthography guides; a Pashto speaker should confirm it. If wrong, change `tools/review_facets.py` (`COMPARISON_FOLDS`) and `lib/core/review/script_folds.dart` together (the shared vectors in `test/support/comparison_fold_cases.json` keep them equal).
- **Culture and proverbs decks.** The strict-quorum rule for these decks (reviewed by facet) is a guess in W9; confirm it.
- **A durable ledger for applied changes.** Applying a proposal removes it with its `accepted` list, so who agreed is only in the merged agreement PR's body (editable, deletable, and missing for old PRs and for who accepted a reading or IPA applied with a word). A durable record in the repo would make reverts reliable.
- **Widened `PointerTag.facets`.** The mockup showed all eleven tags for every facet; the sheet shows only the tags valid for the facet, because the model drops a tag outside its facets when read back. Widening is the owner's call and a separate pull request (W4, #1663).
- **Revocation and other files.** The revocation job reports a persistent failure when a creators, recommendations or topics file carries a revoked code (it cannot clean them), and does not clean `review-answers/` or `verified:` points. Decide how those files are cleaned.
- **The older unit review.** Keep or retire the older unit review (the app bar button on a unit) beside "Review this unit" (W3 kept it).
- **The facet-flag un-flag follow-up.** How a reviewer withdraws a flag they made.
- Also still open from the PR bodies: W3's guesses (a "Done" button on the unit digest, "All good" also answers note, unit placement and offence rating right) and W9's data-format proposal for `facet_checks`, both owner-confirm.

See also: [Reviewing Guide](Reviewing-Guide) · [ADR-0058](ADR-0058-Reviewer-UX) · [ADR-0038](ADR-0038-Review-Proposals) · [Review Staging](Plan-Review-Staging) · [Reviewing Scope](Plan-Reviewing-Scope) · [Placement V3](Plan-Placement-V3) · [Plans Index](Plans-Index)
