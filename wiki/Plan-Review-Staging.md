# Plan: a staging branch for review mails

Source of truth: this wiki page.

Status: Brainstorm, not built (2026-11-06). Nothing here is decided beyond the
"Decisions recorded" table. The owner's release 0.9.0 landed on 2026-11-06
without this.

Owner's first proposal, quoted: "1. Deck PRs merge at deck-live. 2. Review mails
land in main, on confirmation (2 or whatever is set at the moment) it goes live
in decks-live and gets removed from main." After the issues below, the owner
settled on: "we can get a decks-staging branch (with the same delete
protection, but no force push or those protections), where the review mails
land their stuff. Then they get confirmed and land on decks main." (decks main
is `decks-live`, see [Decks Branch](Plan-Decks-Branch).)

## Issues found with the first proposal (staging on main)

| # | Issue | Why it matters | Severity |
|---|---|---|---|
| 1 | Staged mail as commits on protected main | Every push needs a PR, 3 checks and the full CI (about 15 minutes); under strict up-to-date it also makes every open PR "behind". | High |
| 2 | "Removed from main" is not removed | Git history is permanent and public: reviewer emails or names stay forever. | High (privacy) |
| 3 | Apply and delete are two steps on two branches | Needs an order (open PR, merge, delete from staging) and an idempotency id per item. | High |
| 4 | A failed `decks-live` PR (validator rejects, conflict, flaky check, bot access) | The item is stuck. Needs states pending, confirmed, PR open, merged, cleaned or failed with a reason, limited retries, then parked and raised as an issue. | Medium |
| 5 | Mail is untrusted input that edits decks | The quorum needs a real sender identity and no double counting. | High |
| 6 | Stale reviews | A card may change between the review and the apply. A review stores card id, field and a hash of the field text as the reviewer saw it; only reviews with the same hash and the same proposed text count toward the quorum; at apply time compare with the current `decks-live` text, else mark stale and re-review. | Medium |
| 7 | Two sources of truth for the queue | The app downloads `review-queue.json` from `decks-live`; old apps read main's frozen copy. | Medium |
| 8 | Releases and rules | Staged files must live outside anything the app bundles; CLAUDE.md has no rule for mail commits. | Medium |
| 9 | Concurrency on `decks-live` | Under the strict rule the bot must update or rebase its own PRs. | Low to medium |
| 10 | Spam and volume | Needs rate limits and a cap. | Low |

## Decisions recorded (owner, 2026-11-06)

| Topic | Decision |
|---|---|
| Branch | `decks-staging`, with deletion protection only: no PR rule, no required checks, force push allowed so history can be purged. |
| Apply and delete (#3) | "so a separate workflow cleans staging daily by comparing it with decks-live". "Solved." Staging is compared with `decks-live`; items already applied are removed. No two-branch atomic step is needed. |
| Malignant mails (#5) | "a CI runs in staging to catch malignant mails". See the assistant's note below. |
| Privacy (#2) | "so build it like that": no plain reviewer emails in the repo. Hash or names only, and on the final `decks-live` commit a trailer. |
| App (#7) | "app shows decks from live. And review pending from staging. Simple." |
| Stale reviews (#6) | The hash rule in the table above. |
| Failed apply (#4) | The state machine in the table above. |

### Assistant's note on the staging CI

It can check format, size, allowed fields, existing card ids, and obvious abuse
or injection. It treats mail text purely as data, and the job holds no secrets.
It cannot prove who sent a mail, or that two confirmations come from two
people. That needs a hashed allowlist of reviewer addresses plus
sender-signature checks, or app-signed submissions. The Deck CI on the
`decks-live` pull request is the second gate.

### Costs of the app decision

- The app needs a new fetch (pending items from staging), so a release: 0.9.1 at the earliest.
- Raw files are cached for a few minutes, so a pending list can lag.
- Anyone can read pending items on `decks-staging`.

## Flow, as it stands

1. `feedback-mail.yml` receives a review mail and writes a pending item to `decks-staging` with the bot App token.
2. The staging CI checks the item (format and abuse checks only).
3. When the quorum is met (2, or whatever is set at the time), the bot opens a `decks-live` pull request that applies the change.
4. Deck CI runs on that pull request; on merge the item is applied.
5. The daily cleanup workflow compares staging with `decks-live` and removes applied items, so the history of staging can also be purged by force push.

## Other design facts

- `feedback-mail.yml` and the scheduled workflows stay on main: scheduled runs work only from the default branch. They write to staging with the bot App token.
- A push made with `GITHUB_TOKEN` does not trigger other workflows, so the token choice decides what runs.
- A workflow with a plain `on: push` would run on every staging push. Those need branch filters, and a check that `decks-staging` cannot trigger Deck CI or main's CI.
- The review bot (`tools/review_bot.py`, PR #1053) already targets `decks-live`.
- The bot App needs a pull-request bypass on `decks-live`'s ruleset, and the required checks split into a ruleset that does not include the bot (see [Review Bot Setup](Review-Bot-Setup)).

## Open questions for the owner

| # | Question |
|---|---|
| 1 | Do the mails contain reviewer emails or names? |
| 2 | Is the quorum per card, per language or per reviewer? |
| 3 | How is the sender identity checked: a hashed allowlist plus signature, or app-signed submissions? |
| 4 | Should staged items be visible to reviewers in the app, or only the confirmed queue? |

See also: [Decks Branch](Plan-Decks-Branch) · [Deck Browser](Plan-Deck-Browser) · [Reviewing Scope](Plan-Reviewing-Scope) · [Review Bot Setup](Review-Bot-Setup) · [Plans Index](Plans-Index)
