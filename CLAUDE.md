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
