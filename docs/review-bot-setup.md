# Setting up the review bot

For the owner. The review bot ([ADR-0038](adr/0038-review-proposals.md),
#441) turns review mails into proposals in the decks and merges a change
to learners once enough other reviewers accept it. It runs inside the
hourly mail workflow, `.github/workflows/feedback-mail.yml`, and does
nothing until the steps below are done: until then reviews are filed as
issues, as now, and the workflow's log says the bot is not set up.

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

The App may merge without an approving review. It must still wait for the
three required checks, which the bot waits for too: `Validate decks`,
`Analyse and test` and `Build debug APK`, by name. Other checks on a
commit do not hold a bot PR back. If none of the three has started on a
bot PR an hour after it was last pushed, the log says so each run.

**With a classic branch protection rule** (Settings > Branches):

1. **Edit** the rule for `main`.
2. Under **Require a pull request before merging**, tick **Allow
   specified actors to bypass required pull requests**, and add
   `fluenough-review-bot`.
3. Leave **Require status checks to pass before merging** as it is, with
   the three checks. Leave **Do not allow bypassing the above settings**
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

Actions > **Feedback mail to issues** > **Run workflow**. Its log should
say `Review bot: 1 other reviewer(s) must accept a proposal.` and, at the
end, `Agreed proposals: …`. The bot's PRs are labelled `review-bot`, with
`proposals`, `agreement` or `proposal outdated`.

## Overriding it, and turning it off

- **Any later commit wins:** revert a bot PR, edit the card, or delete a
  proposal's line from the deck. A bot PR is built again from `main`
  before it merges whenever `main` has moved, and an open agreement PR
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
