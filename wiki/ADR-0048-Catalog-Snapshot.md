# ADR-0048: The catalog snapshot: the decks' YAML kept as JSON, keyed by SHA-256

Source of truth: this wiki page.

- **Status:** Accepted.
- **Date:** 2026-10-30

## Context

A cold start read and parsed every downloaded deck file as YAML with the
pure-Dart `yaml` package before the first screen had its data: 345 ms for
Telugu alone on a desktop, several times that on a phone, more with every
language downloaded (#875). Parsing moved off the UI isolate (#895), but the
work was still done on every launch. The same data as JSON decodes about 8.6
times faster. The owner's answer, 2026-10-30: "Yes, compact JSON snapshot".

## Decision

- **What is kept.** One file, `catalog-snapshot.json`, in the app's storage
  beside `downloaded/`. For each deck file it holds the tree the file's YAML
  parses to (maps, lists, scalars) and the SHA-256 of the file's text. It
  does **not** hold the parsed catalog: the parsers still run on every
  launch, on the kept tree instead of on YAML (`loadYamlTree`).
- **Keys.** A file's tree is used only if its SHA-256 matches. The
  downloads' manifest already has the SHA-256 of every downloaded file, so
  none is hashed at launch; the few files it does not know (the bundled
  theme list, decks the learner added) are hashed. The snapshot also carries
  its format version and the app version, and a snapshot of another of
  either is not used at all.
- **Invalidation.** A changed file is read from YAML again; an added one is
  too; a removed one is left out of the next snapshot. The snapshot is
  rewritten (to a temporary file, then renamed) whenever its list of files
  and SHA-256s would change, off the first screens' path.
- **Never wrong, never a crash.** A missing, unreadable, damaged or foreign
  snapshot is no snapshot: the YAML is parsed and the snapshot rewritten. A
  file that is broken is never kept. If a file that used a kept tree then
  fails to parse, the whole load is parsed again from YAML, so that its
  error names the right line (a kept tree has no positions).
- **Native only.** The store is a file (`dart:io`); the web build passes no
  store and parses as before. `lib/core` has no Flutter import.
- **Off the UI isolate.** Reading the snapshot's JSON runs in the same
  isolate as the parse (`runJobInIsolate`).

## Consequences

- A warm start reads one file instead of about 300 YAML files. What remains
  is JSON decoding and the parsers' own mapping and merging.
- Because the kept trees are the YAML's own, a change to a parser needs no
  snapshot version bump; only a change to how trees are kept does
  (`CatalogSnapshot.format`).
- Disk: about the size of the decks as JSON, again, in the app's storage.
- A learner's first launch after an app update, a download that changes
  many files, or a damaged snapshot pays one full YAML parse.
- Parsing the trees into models still takes time that a snapshot of the
  models themselves would save. That is a larger change (every model needs a
  codec that must be kept in step with it) and is not made here.

## Alternatives considered

- **Snapshot the parsed models.** Fastest start, but it needs a JSON codec
  for every model class and a version bump with each change to any of them;
  a missed one serves stale data. Rejected for now.
- **A binary format.** Smaller and faster than JSON, but harder to inspect
  and `dart:convert` is already built in. The owner chose JSON.
- **Hash every file at launch.** Needs no manifest, but the pure-Dart
  SHA-256 over megabytes costs about what it saves.
