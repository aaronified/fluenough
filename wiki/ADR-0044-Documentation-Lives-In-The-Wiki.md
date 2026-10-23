# ADR-0044: Documentation lives in the wiki, mirrored from the repo by a workflow

Source of truth: this wiki page.


- **Status:** Accepted (owner, 2026-10-22: "mostly the wiki should be the
  ultimate source of truth. And it should hold all documentation"; "All
  pages should be interlinked and open within github only"; and, asked how
  the pages reach the wiki, "Use the workflow only")
- **Date:** 2026-10-22

## Context

Documentation sat in many places: `docs/`, the READMEs, plans and ADRs in
folders of their own. A learner, a deck author or a reviewer had no one
place to start.

The owner asked for one. The wiki is the source of truth, and it holds all
documentation. A few repeats in the repo are fine. The pages are linked to
each other and open within github.com only. The only outside links are the
official sources a guide must cite.

The pages needed a way to reach the wiki. A Claude session cannot push to
the `.wiki.git`. The session's git proxy signs pushes only for attached
repositories, and the wiki cannot be attached. An Actions secret is
readable only by workflows, so a session cannot use one either.

## Decision

- **The wiki is the source of truth.** It holds the learner guides (with
  feature onboarding), deck building, reviewing, translation, an iOS
  self-build guide, the roadmap, sources and attributions, and
  contribution and agentic coding. ADRs and plans are pages too, listed in
  [ADR-Index](ADR-Index) and [Plans-Index](Plans-Index).
- **Pages are interlinked.** A page links to other wiki pages by name. It
  links outside github.com only to an official source a guide must cite.
- **The pages live in the repo's flat `wiki/` folder.** An ADR is
  `wiki/ADR-NNNN-Title-With-Dashes.md`. No `docs/adr` file is added.
- **A workflow mirrors them.** `.github/workflows/wiki-sync.yml` (PR #709)
  copies `wiki/` to the wiki on every push to main that touches `wiki/`,
  and on a manual run. It uses the repository Actions secret `WIKI_TOKEN`,
  a fine-grained token with Contents: write, and falls back to
  `GITHUB_TOKEN`. The owner chose "Use the workflow only".
- **Repo docs (option A).** A moved doc became a one-line pointer to the
  wiki. These stay full files, because tools or agents read them from
  disk:
  - `CLAUDE.md` and `AGENTS.md`
  - `.claude/skills/**`
  - `docs/DECK-FORMAT.md`
  - `docs/REVIEWING.md` (`test/reviewing_test.dart` reads it; changing that
    test to read the wiki is planned)
  - `docs/mockups/**`
- **Four READMEs keep a short summary and wiki links.** The root README,
  `CONTRIBUTING.md`, `decks/README.md` and `tools/README.md` do this,
  because GitHub shows them on folder pages. The root README also keeps the
  languages badge that `tools/deck_index.py` rewrites, its screenshots and
  a Courses section.

## Consequences

- An edit made in the wiki's web editor is overwritten by the next sync.
  Edit `wiki/` in the repo.
- A page deleted from `wiki/` is deleted from the wiki.
- Only `.md` files are published.
- A docs-only push needs no CI.
- A doc has one place to read and one place to change. The repo keeps a
  few repeats, as the owner allowed.
- The files that tools read can drift from their wiki pages. Moving
  `docs/REVIEWING.md` to the wiki needs the test changed first.

## Open

How the [Agentic-Coding](Agentic-Coding) page relates to `CLAUDE.md` and
`AGENTS.md` is not decided. It could be an overview with links, a full
copy, or the wiki as the rules. The owner has not decided yet.

## Alternatives considered

- **A token in the cloud environment, so sessions push directly.** Only new
  sessions would see it, and the proxy may still refuse the push.
- **The owner pushing to the wiki by hand.** It works, but it adds a step
  for every change, and the wiki falls behind.

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
