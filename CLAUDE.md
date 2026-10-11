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

At most **two Opus agents run at the same time** (owner, 2026-10-09). The
quota is shared: each Opus slot left unused buys 1.5 Sonnet agents, and each
Sonnet slot 1.5 Haiku agents (so one Opus slot = 1.5 Sonnet = 2.25 Haiku).
Pause and queue Opus work rather than run a third; prefer the cheaper model
wherever the table above allows it.

## How the owner works (owner, 2026-10-11)

- **Push straight to main.** Documentation, plans and the 0.5.0 work go
  directly to main, with no pull request. Push only after the checks pass:
  analyze, the full test suite (read its "All tests passed" line, not just
  the last line of output), the deck validator and the tools' tests, and
  after one Sonnet review finds nothing blocking.
- **Releases.** Bump `pubspec.yaml` and `lib/app/app_info.dart`, check with
  `tools/check_release_version.py`, and push to main. The owner tags the
  release and writes the CHANGELOG; never edit CHANGELOG.md for a release.
- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to.
- **Readings.** Readings are *based on* ISO 15919. Never say they strictly
  follow it.
- **Milestone 0.5.0** holds the high-priority features and fixes. Tag new
  ones to it when the owner calls them a priority.
- **Budget.** Tokens are limited: one review per change, no extra
  verification passes, and no new work unless the owner asks for it.
