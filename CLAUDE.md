See [AGENTS.md](AGENTS.md) for how to work in this repository.

Read it before making changes. It is short, and three of its rules — card ids
are permanent, YAML scalars must be quoted, and `lib/core` stays free of
Flutter imports — protect against mistakes that pass every test.

## Which model does what (owner, 2026-10-09)

When work is handed to subagents or workflows, pick the model by the job:

| Job | Model |
|---|---|
| Docs, reviews and audits | Sonnet |
| Writing decks | Sonnet |
| Fan-outs and large reads | Haiku |
| Fixing and coding | Opus |
| UI mockups | Opus (Sonnet was not enough, owner, 2026-10-12) |

At most **two Opus agents run at the same time** (owner, 2026-10-09). The
quota is shared: each Opus slot left unused buys 1.5 Sonnet agents, and each
Sonnet slot 1.5 Haiku agents (so one Opus slot = 1.5 Sonnet = 2.25 Haiku).
Pause and queue Opus work rather than run a third; prefer the cheaper model
wherever the table above allows it.

## How the owner works (owner, 2026-10-11)

- **Push straight to main.** The owner cannot merge for you ("You cannot
  merge. You will have to push to main directly"), so work done for the
  owner goes directly to main, with no pull request. Documentation goes
  straight away. Code goes after the checks pass: `flutter analyze` clean,
  the full `flutter test` (read its "All tests passed" line, never a
  truncated tail), the deck validator and the tools' tests, and after one
  Sonnet review finds nothing blocking. Rebase on `origin/main` if the push
  is rejected. Outside contributors still use pull requests
  ([CONTRIBUTING.md](CONTRIBUTING.md#pull-requests)).
- **Releases.** Bump `pubspec.yaml` and `lib/app/app_info.dart`, check with
  `tools/check_release_version.py`, and push to main. The owner tags the
  release and writes the CHANGELOG; never edit CHANGELOG.md for a release.
- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to.
- **Readings.** Readings are *based on* ISO 15919. Never say they strictly
  follow it.
- **Milestones are releases** (0.4.4, 0.5.0, 0.6.0, 0.7.0). The milestone's
  description holds its order. Until the roadmap is generated from them
  (#484), update `docs/ROADMAP.md` by hand to match. Tidy issues and plans
  after work lands, and close issues when done. Tag new issues to a
  milestone only as the owner says.
- **Mockups** follow `docs/mockups/README.md`: build the approved specs
  exactly, never rewrite one without approval, and adapt the older ones.
  Each uses the app's real theme, light and dark, 1.4x text (the app's
  cap, #505), a contrast self-check, and Hindi and Bengali examples, and
  is checked in Chromium.
- **Content.** Keep transliteration in deck prose, and say in a card's notes
  when its base word changes its stem (`docs/DECK-FORMAT.md`).
- **Reviewers** are bilingual and the meaning of a card never changes; new
  themes come only by pull request (`docs/plans/reviewing-scope.md`).
- **CI.** "Validate decks" is the only check a deck-only change needs.
- **Budget.** Tokens are limited: one review per change, no extra
  verification passes, and no new work unless the owner asks for it.

## Repositories off limits (owner, 2026-10-12)

`homelab-stacks` is not part of this work. Never clone or download it, never
modify it, and never push to it, even if it appears in a session's
repositories.

## Tags (owner, 2026-10-12)

Never create or push git tags. Only the owner tags releases.

## The `direct-code` label (owner, 2026-10-12)

Label an issue `direct-code` once every decision on it is made: the owner's
answers are in the issue, and any mockup it needs is approved. A
contributor can then build it as written, without asking anything. Remove
the label if a new question comes up, and add it when the last one is
answered.

## Dependencies are marked, never assumed (owner, 2026-10-12)

When one issue needs another done first, record it on GitHub: set "blocked
by" between the issues and add the `blocked` label. Never rely on both
landing in the same milestone, or on any other timing.

## Contributor DhyanendraSinghSikarwar (2026-10-13)

When the session's GitHub user is `DhyanendraSinghSikarwar`, these rules
replace "Push straight to main" above:

- **Author.** Before the first commit, run:
  `git config user.name "DhyanendraSinghSikarwar"` and
  `git config user.email "87273551+DhyanendraSinghSikarwar@users.noreply.github.com"`.
- **Trailer.** End each commit message with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No
  `Claude-Session` line.
- **Branches and PRs.** One branch and one PR per issue, named
  `issue-<n>-<slug>`. Work without an issue uses a branch name without a
  number. Never push to main.
- **Commits.** One commit per fix, even within a PR. Push each one as soon
  as it is made.
- **Skills.** Use the repo's skills in `.claude/skills/`.
- **Decisions.** Ask whenever in doubt. Never decide alone.
