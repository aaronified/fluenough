# Setting up the review bot

Source of truth: this wiki page.


For the owner. The review bot ([ADR-0038](ADR-0038-Review-Proposals),
#441) turns review mails into proposals in the decks and merges a change
to learners once enough other reviewers accept it. It runs inside the
mail workflow, `.github/workflows/feedback-mail.yml`, and does
nothing until the steps below are done: until then reviews are filed as
issues, as now, and the workflow's log says the bot is not set up.

Until it is set up, a review mail is still read: the workflow files it as an
issue (`Review: CODE (languages)`, no mail address, no suggestion text) and
the log says `No review bot: N review mail(s) filed as issues are left for
the bot`. Nothing is proposed or merged without the App. Once the App is set
up, the mails already filed are proposed by the next run (step 6).

If a review mail was sent and no issue appears, the bot is not the cause:
read the run's log. `Inbox OK: N mail(s), M Fluenough mail(s) not filed yet`
says what the search found, and a `::warning::` line names a mail that sits
in All Mail or Spam instead of the inbox.

You need: admin on `aaronified/fluenough`, and about ten minutes.

## 0. First, release an app that reads proposals

An app released before ADR-0038 refuses a deck file that holds a proposal,
and keeps its old decks instead of updating. So set the bot up only once a
release with "Proposed changes" in reviewer mode is out, and most phones
have it.

## 1. Create the App

1. On GitHub, open your picture > **Settings** > **Developer settings** >
   **GitHub Apps** > **New GitHub App**.
2. **GitHub App name:** `fluenough-review-bot` (any free name).
3. **Homepage URL:** `https://github.com/aaronified/fluenough`.
4. **Webhook:** untick **Active**. The bot needs no webhook.
5. **Repository permissions**, and nothing else:
   - **Contents:** Read and write
   - **Pull requests:** Read and write
   - Metadata stays Read-only, as GitHub sets it.
6. **Where can this GitHub App be installed?** Only on this account.
7. **Create GitHub App.**
8. On the page that opens, note the **App ID** (a number, near the top).
9. Further down, under **Private keys**, click **Generate a private key**.
   A `.pem` file downloads. Keep it until step 4, then delete it.

## 2. Install it on the repository

1. On the App's page, **Install App** > **Install** beside your account.
2. Choose **Only select repositories**, pick `aaronified/fluenough`, and
   **Install**.

## 3. Let it past the approval rule, and only that

Since 2026-11-06 the bot works on the `decks-live` branch, where the decks
live: it branches from it and opens its PRs against it, so every rule below
is set on `decks-live`, not `main` (main's `decks/` is frozen). The App may
merge without an approving review. It must still wait for the two required
checks of `decks-live`, which the bot waits for too: `Validate decks` and
`Released app reads the decks` (#524), by name. Other checks on a commit do
not hold a bot PR back. If neither has started on a bot PR an hour after it
was last pushed, the log says so each run. The workflow itself stays on
`main`, which holds the tools; the bot lays them over its `decks-live`
worktrees as Deck CI does.

**With a classic branch protection rule** (Settings > Branches):

1. **Edit** the rule for `decks-live`.
2. Under **Require a pull request before merging**, tick **Allow
   specified actors to bypass required pull requests**, and add
   `fluenough-review-bot`.
3. Under **Require status checks to pass before merging**, keep
   `Validate decks` and `Released app reads the decks` (#524). Leave **Do not allow bypassing the above settings**
   unticked: ticked, it overrides the bypass list.
4. **Save changes.**

**With rulesets instead** (Settings > Rules > Rulesets): a bypass actor
skips a whole ruleset, checks included. Keep the required status checks in
a ruleset of their own with no bypass, and add the App to the bypass list
of the ruleset that requires a pull request and its approval only, set to
**Always allow**.

## 4. The two secrets

Settings > **Secrets and variables** > **Actions** > **Secrets** >
**New repository secret**, twice:

| Name | Value |
|---|---|
| `FLUENOUGH_BOT_APP_ID` | The App ID from step 1.8. |
| `FLUENOUGH_BOT_PRIVATE_KEY` | The whole `.pem` file, from `-----BEGIN` to the last `-----`, line breaks included. |

Then delete the `.pem` file. If it is lost, generate another key on the
App's page and replace the secret.

## 5. The number of agreements

Same page, **Variables** tab > **New repository variable**:

| Name | Value |
|---|---|
| `REVIEW_AGREEMENTS_NEEDED` | `1` |

It is how many reviewers other than the proposer must accept a change,
each with a different rater code, before it goes to learners. Change it at
any time, to `2` once there are more reviewers; the next run uses it. Left
unset, or set to anything but a whole number of at least 1, it counts as
1. A secret of the same name works too, if you would rather, but a secret
cannot be read back and GitHub hides its value everywhere in the logs; a
variable wins over it.

## 6. Old review mails

Once set up, the bot proposes every review mail already filed, oldest
first, and leaves out as outdated any suggestion whose card has changed
since. To skip the mails from before, give them the Gmail label
`fluenough-proposed` first.

## 7. Check it

From a terminal with `gh` logged in as the owner:

```
gh workflow run feedback-mail.yml -R aaronified/fluenough
gh run list -R aaronified/fluenough --workflow feedback-mail.yml --limit 1
gh run view <run id> -R aaronified/fluenough --log
```

or on GitHub: Actions > **Feedback mail to issues** > **Run workflow** on
`main`. In the log of the job "File report mails as issues", expect, in
this order:

- Not the line `FLUENOUGH_BOT_APP_ID and FLUENOUGH_BOT_PRIVATE_KEY are not
  set`. If it is still there, a secret name is misspelled or the secret was
  made under Environments or Dependabot instead of **Actions**.
- The step **Make the review bot's token** is green. A red step says the
  App ID or the key is wrong, or the App is not installed on the repository.
- `Review bot: 1 other reviewer(s) must accept a proposal.`
- `Inbox OK: N mail(s), M Fluenough mail(s) not filed yet.` and
  `Filed M report(s); …`
- `Review mails proposed: …` and `Question mails counted: …` (for example
  `1 merged`, or `1 closed`; `none waiting` when there is nothing new).
- `Agreed proposals: …` and `Flagged question points: …`
- `Review issues: N closed, N waiting for their PRs, N left to the owner.`

The issue of a review or questions mail is closed by the workflow itself, as
completed, with the comment "Closed by the review pipeline: all of this
mail's pull requests are merged or closed." (owner, 2026-11-26). Nothing to
set up: it uses the workflow's own token, which already has `issues: write`
and `pull-requests: read`. The issue's last line is a hidden comment naming
the mail's key (`<!-- fluenough-mail: KEY -->`), the same key as the bot's
branches `review-bot/review/KEY` and `review-bot/questions/KEY`. It closes
when each of the mail's PRs is merged or closed (or there was nothing to
propose, or the change did not validate) and none is open or waiting. An
issue marked "check the files", "sender does not match", "held for the owner"
or "sender not checked" is left open for the owner. Issues filed before the
key existed are matched by the rater code in their title: closed when every
bot PR of that code is done and the newest was opened after the issue. See
`tools/close_review_issues.py`.

The bot's PRs are labelled `review-bot`, with `proposals`, `agreement` or
`proposal outdated`, and target `decks-live`.

## Signed reviewer keys (ADR-0058, W7)

Nothing to set up in GitHub: the bot keeps the private bindings of key ids to
rater codes in a Gmail label of the Fluenough inbox, `fluenough/keys`, which it
creates, the same way it keeps `fluenough/raters`. Never in a repo file, a
variable or an issue.

The owner, once, on their own machine (never in a session or a workflow):

1. `python3 tools/reviewer_keys.py keygen --private ~/fluenough-owner.key`
   writes the private key (keep it offline, never commit it) and prints the
   public key entry.
2. Put that entry in `assets/reviewer/public_keys.json` (replace the
   placeholder) and merge it. Until then keys are off: no row in the app, keys
   ignored by the bot. A new app release carries the public key.
3. `python3 tools/reviewer_keys.py mint --private ~/fluenough-owner.key
   --courses te/en,bn --tier verified --note "Asha"` prints a key to send to a
   reviewer, and the key id to keep.
4. To revoke, add the key id on a line of `assets/reviewer/denylist.txt` and
   merge it to main. The mail bot reads it on its next run; the app on its next
   release; and the **Reviewer revocation** workflow (below) takes the work
   already done out of the decks.

### Revocation removes past work (W8)

Nothing new to set up: the workflow `.github/workflows/reviewer-revocation.yml`
uses the secrets above (the Gmail ones to read `fluenough/keys`, and the
GitHub App, which needs to read and write pull requests and contents as it does
for the review bot, and to read issues and pull requests to find its own
agreement PRs; labelling its PRs also needs issues write, as for the review bot). It runs every six hours, and from **Actions > Reviewer
revocation > Run workflow** (only from main; there is no run on a push to the
denylist, so the minute an id is added does not show which code it belongs to,
and you can run it by hand to hurry it). Until the removal PR merges, the review
bot itself ignores revoked codes: nothing reaches an agreement or the quorum
through them, their review mails make no PR (an open one is closed), and with
the key store unreadable the bot applies nothing. A keyless mail from a code
whose key was revoked is held for you, so a revoked reviewer cannot come back
as Provisional under the same code. For the rater codes
bound to revoked key ids it opens **pull requests to `decks-live`, never
merged by the bot**:

- one **removal** PR (`review-bot/revoke/clean-<n>`): their code leaves every
  `checked_by`, every facet's `by` and `flags`, the `accepted` list of every
  proposal not yet applied, and the proposals they made are withdrawn. A card or
  facet that is then below the quorum is unchecked again, and a deck file tagged
  `reviewed` whose facets are no longer all at the quorum is tagged
  `unreviewed` again, in the same PR;
- one **revert** PR for each revoked key (`review-bot/revoke/revert-<hash>-<n>`)
  for applied changes that only had the quorum because of them: one commit per
  change, restoring the text it replaced. Drop a commit to keep a change; closing
  the PR keeps all of them and they are not proposed again.

You merge them like any bot PR (Deck CI must pass). A rerun rebuilds an open PR
from `decks-live` and changes nothing when it is already clean. The PRs, the
branch names, the commits and the log never hold a key id, and no PR names a
reviewer; the log says counts only. A code leaving the decks on the day an id
joins the denylist can still be seen from outside, so revoke several keys in one
commit when you can. If the key store cannot be read the run fails and
revokes nothing, and the run also **fails** (an error in its log, not a quiet
success) when a revoked code is still in the decks that it cannot take out: an
entry the bot cannot edit one line at a time, a reviewed deck whose `tags` line
it cannot rewrite (Deck CI would fail the PR), or a branch that does not
validate.

**Not covered:** other files that list reviewers (creators, recommendations,
topics), the daily-question answers (`review-answers/`) and `verified` points.
Withdrawing a revoked proposer's unapplied proposals also discards other
reviewers' acceptances of them. A change with two revoked codes is queued under
only one of their revert PRs, and may move if another key is revoked later.

**What the revert PR can know.** An applied change drops the proposal from the
deck, so the decks keep no record of who agreed. The job reads the merged
agreement PR's body ("Proposed by", "Accepted by"), and, from now on, a hidden
line the bot adds to it with the same codes and those who accepted a reading or
IPA applied with a word. An agreement PR from before that line names only the
proposer of such a reading or IPA, so a revoked code there is counted in the log
as "no record of who accepted" and left for you. Edited or deleted agreement PRs
are not recoverable; the ADR's W8 note says what would make the record durable.

A mail the bot holds for a key (forged, revoked, bound to another code, used
more than 30 times a day) is labelled `fluenough-proposed` and filed with the
mark "held for the owner"; the owner reads the mail.

## Overriding it, and turning it off

- **Any later commit wins:** revert a bot PR, edit the card, or delete a
  proposal's line from the deck. A bot PR is built again from `decks-live`
  before it merges whenever `decks-live` has moved, and an open agreement PR
  whose proposal you deleted is closed. A bot PR you close is never
  opened again.
- **What a review left for you:** suggestions on an example or a
  picture, on a field the bot cannot write, or outdated, are counted in
  the log as `Review by FL-…: n suggestion(s) left for the owner, n
  outdated`; the text is in the mail.
- **A bot PR whose checks fail** stays open, labelled `review-bot: checks
  failed`, for you to fix or close.
- **To stop the bot,** delete either secret, or uninstall the App. Reviews
  are then filed as issues only, as before.

See also: [Reviewing-Guide](Reviewing-Guide) · [Home](Home)
