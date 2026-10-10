# ADR-0038: Reviews become proposals in the decks, and agreement merges them

- **Status:** Accepted
- **Date:** 2026-10-09
- **Amends:** ADR-0036 (a card may carry `proposed` changes), ADR-0037 (the
  index counts a file's proposals; `main` now also carries what reviewers
  propose).
- **Amended:** 2026-10-10 (#444): the index also gives each file's
  `content_sha256`, its hash with its proposals taken out. A learner's
  phone is offered an update only when that changes, and files whose
  proposals alone changed come along with the next real update; a phone in
  reviewer mode is offered one when `sha256` changes. Every download is
  still checked against `size` and `sha256`. This resolves the third
  consequence below. `content_sha256` drops a `proposed:` key's items
  whether they are indented under it, as the bot writes them, or at its
  own indent.

## Context

Reviewers review in the app and send their reviews by mail
(`docs/plans/deck-browser.md`, "Review in the app, by mail"). Until now a
suggested change reached the decks only when the owner read the mail and
the decks were edited with him. On 2026-10-09 the owner asked for it to be
automatic (#441, parent #403):

> Make it totally automated then. The first review auto merges the PR and
> shows all changes to all applicable reviewers. If anyone agrees, that
> gets an instant merge to learner decks. This number can be a github
> secret so that I can update it easily. Like maybe once the app gains
> traction, i change it to two reviewers.

This replaced, the same day, a design in which the owner accepted a change
provisionally and the bot waited three days. Three things constrain it.
`main` is protected: every change needs an approving review and three
green checks, and agents never merge their own PRs. `main` is what learners
download (ADR-0037), so a change merged there reaches phones the next day.
And many reviews can arrive about the same card, while the owner, or
another review, may change it first.

## Decision

- **A proposal is a fact, not a diff,** kept on its card in the deck file
  that holds the field: a `proposed` list, each item one line of YAML,
  `{ id, field, now, text, by, date, why?, accepted? }`. `field` is
  `target`, `reading`, `ipa`, `native` or `notes` (a plain-text note
  only); `now` is the text the proposer saw, "" for a field the card did
  not have; `text` the new text; `by` the proposer's rater code; `date`
  the review file's date; `why` the reason, if given; `accepted` the
  other rater codes that accepted it verbatim. `id` is the first ten hex
  digits of the SHA-256 of the card id, field, now, text and code, joined
  by U+001F, so the same proposal always has the same id and two never
  collide in practice. Suggestions on an example or a picture stay for
  the owner.
- **Learners never see a proposal.** The app reads `proposed` only in
  reviewer mode. The validator checks its shape and nothing else in it:
  a proposal is not deck content until it is applied, and then the field
  is checked as any field is.
- **A review mail becomes proposals at once.** The hourly mail job opens
  one PR per review mail that adds each suggestion as a proposal and
  records each acceptance in the proposal's `accepted`, then merges it as
  soon as the required checks pass. A suggestion whose field no longer
  holds what the reviewer saw, or whose card is gone, is left out as
  outdated. Only a mail whose sender passed the sender check, with one
  good rater code, is taken; the others stay with the owner.
- **Agreement merges the change to learners.** When
  `REVIEW_AGREEMENTS_NEEDED` rater codes other than the proposer's (a
  repository variable, default 1 when unset or not a whole number of at
  least 1) have accepted a proposal verbatim, the bot opens a PR that
  writes `text` into the field, removes that proposal and every other
  proposal on the same field of the card, and merges it once the checks
  pass. The first proposal on a field to reach the number wins; the
  others are closed as outdated with it. The bot does not record when an
  acceptance came, so "first" is the proposal whose agreement PR opened
  first: while it is open no other on that field is applied, and
  several that reach the number before any PR opens go in the order
  they were proposed, which is their order in the file.
- **Accept, edit or reject.** In reviewer mode a proposal shows Accept,
  Edit and Reject, and the review file records the answer. An edit is a
  suggestion of the reviewer's own, which becomes a new proposal; the old
  one keeps waiting. A rejection does not block anything: the mail's
  issue lists the rejected proposals, for the owner.
- **Every bot PR starts afresh.** A fresh branch from `main`; the card
  found by id across the language (ids are permanent, so a card that
  moved is still found); the field written only if it still holds `now`;
  `decks/index.json` rebuilt by `tools/deck_index.py`; the validator run
  before anything is pushed. A proposal whose field has changed is closed
  as outdated, by a bot PR that removes it, never written. A branch that
  falls behind `main` is rebuilt from `main` the same way, and a PR is
  never merged unless its branch holds all of `main`, so a change the
  owner made meanwhile is never merged over. An agreement or outdated PR
  that `main` no longer calls for is closed. Branch names come from the
  mail, or from the proposals' ids and dates, so an hourly rerun finds
  its own PR and never opens a second; a PR the owner closes is never
  reopened, while the same proposal made again on a later day is a new
  attempt with a branch of its own. Only the three checks branch
  protection requires gate a merge, named in `tools/review_bot.py` and
  tested against `.github/workflows/ci.yml`.
- **A GitHub App merges.** The bot's PRs are opened and merged with an
  App's installation token (`FLUENOUGH_BOT_APP_ID`,
  `FLUENOUGH_BOT_PRIVATE_KEY`), the one actor allowed to skip the approval
  rule; the three required checks still apply to it. Without the secrets
  the job files issues as before, says in its log that proposals wait for
  the App, and leaves review mails to be proposed once it is set up.
- **The owner's override is any later commit:** reverting a bot PR,
  editing the card, or deleting a proposal. Every bot PR names the rater
  codes involved.
- **The index counts proposals:** a file's entry in `decks/index.json`
  gives `proposed`, the number of proposals in it, when it has any.

## Consequences

- Native speakers change the decks learners download without the owner,
  within an hour or two of the agreeing mail: the time the checks take,
  twice. One agreeing reviewer is enough by default, so two people can
  change a card; raising the variable to 2 or more is how the owner
  tightens it.
- Every app released before this change refuses a deck file with a
  `proposed` field as an unknown field, and, as ADR-0037 has it, keeps the
  decks it has rather than use a batch with a file that fails. The
  owner's guide says to set the App up only once a release that reads
  `proposed` is out.
- ~~A proposal changes the file's hash, so learners of that language are
  offered a deck update when a proposal lands, though nothing they see
  has changed.~~ Resolved by the 2026-10-10 amendment (#444): the update
  check of a learner's phone compares `content_sha256`, the hash with
  proposals taken out, so a change to proposals only offers no update.
  Only reviewer mode is offered one.
- Rater codes, card ids and proposal ids appear in public PRs and issues,
  and the proposed text appears in the decks, which are public, as the
  plan allows. Mail addresses never do.
- The mail job now pushes branches and merges PRs. Its log says counts,
  rater codes, card ids and PR numbers, never an address or a
  suggestion's text.
- Proposals are one line each, written and removed by the bot without
  touching any other line of the file, so they never reformat a deck
  (AGENTS.md rule 8). A proposal on a field written over several lines,
  or on a card written in flow style, cannot be written by the bot, and
  stays for the owner.
- Review mails that came before the App was set up are proposed once it
  is, unless the owner gives them the Gmail label `fluenough-proposed`
  first.

## Alternatives considered

- **Proposals in files of their own,** `decks/<lang>/proposals/`: they
  would not change the decks' hashes, but a card's proposals would live
  apart from the card, and an older app would refuse an unknown file kind
  just the same. The owner's plan puts them on the card.
- **Storing a diff, or the reviewer's whole file, in the PR:** any edit to
  the deck in between would conflict. A fact about one field can be
  checked against `main` at any time.
- **Counting agreements from the mailbox each run:** no record in the
  repository, but every run would read every review mail ever sent, and
  the count would be invisible to reviewers. `accepted` in the deck is
  public and cheap to read.
- **GitHub's auto-merge:** needs a repository setting the bot cannot
  change; the bot merges when it sees the checks green, on its hourly run
  and when CI finishes on one of its branches.
- **The threshold as a secret,** as the owner first said: a secret cannot
  be read back, and GitHub hides its value everywhere in the logs, which
  for a value such as 1 hides every 1. The owner chose a variable; the
  workflow falls back to a secret of the same name if one is set.
- **The default `GITHUB_TOKEN`:** PRs it opens run no workflows, so the
  required checks would never run, and it cannot be allowed past the
  approval rule alone.
