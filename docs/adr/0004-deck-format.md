# ADR-0004: Decks are YAML files in git

- **Status:** Accepted
- **Date:** 2026-09-19

## Context

Content has to reach users somehow, and contributors have to be able to author
and review it. The app is distributed from GitHub, so the repository is already
the project's centre of gravity.

## Decision

Decks are YAML files committed under `decks/`, bundled as Flutter assets and
also importable at runtime from a file or URL. Importers convert CSV and Anki
exports into the format.

## Consequences

**Content is reviewable.** A pull request adding 200 Spanish words shows up as
a readable diff. Errors are caught in review; history is preserved; a bad edit
is revertible. A binary or database-backed format gives up all of this.

**Contribution needs no toolchain.** Authors edit text and run
`tools/validate_decks.py`, which requires only Python and PyYAML — not Flutter,
not Android. This is deliberate: the people best placed to write a good
Hungarian deck are not necessarily Flutter developers.

**YAML over JSON** for comments, multi-line strings and unquoted Unicode —
worth the dependency for a format humans hand-write. The `yaml` package is
maintained by the Dart team.

**Validation must be enforced in CI**, because YAML is easy to get subtly
wrong. See `.github/workflows/ci.yml`.

**User progress is not in git.** Review history lives in the on-device
database; decks are content, not state. Export/import of the review log is a
first-class feature precisely because the log cannot live in the repository.
