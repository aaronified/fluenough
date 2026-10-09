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
