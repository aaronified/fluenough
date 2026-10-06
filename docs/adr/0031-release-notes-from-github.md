# ADR-0031: What's new shows GitHub's release notes, fetched when the page opens

- **Status:** Accepted
- **Date:** 2026-10-06

## Context

The owner: "Add a changelog in updates section." Asked whether to bundle the
changelog in the app or to show GitHub's release notes, they chose release
notes from GitHub.

[ADR-0017](0017-update-check.md) put the Updates group in Settings, and with
it a rule: the app asks GitHub for nothing unless the learner taps or switches
automatic checks on. The footer still says "Works fully offline". A list of
releases is another request to GitHub, so the same rule has to cover it.

## Decision

- **The row.** Settings' Updates group gains "What's new", under "Check
  automatically". Its line says that opening it asks GitHub. It opens a page
  of the releases, newest first, each with its tag, its date and its notes.
  The release whose tag is `AppInfo.version` is marked "Installed".
- **The request.** `GET https://api.github.com/repos/aaronified/fluenough/releases?per_page=20`,
  made as ADR-0017's check is: dart:io's `HttpClient`, `User-Agent:
  fluenough/<version>`, `Accept: application/vnd.github+json`, a 15-second
  timeout, no account. It sits behind `ReleaseNotesEngine` in `lib/core/updates`
  with no Flutter import. Only `main.dart` names `GitHubReleaseNotes`; tests
  and the gallery use `FixedReleaseNotes` and `NullReleaseNotes`, so no test
  reaches the network. `AppState.test(releaseNotes: ...)` injects it.
- **Only on demand.** The page asks once when it opens, and again on Try
  again. Not at launch, not in the background, and nothing is kept: leaving
  the page forgets the answer. Failures are ADR-0017's three: offline, rate
  limited and a reply that cannot be read, each with its own message.
- **What is listed.** Drafts and pre-releases are left out, and the order is
  GitHub's. Twenty is all it asks for; a button at the foot, "See all
  releases on GitHub", opens `https://github.com/aaronified/fluenough/releases`
  in the browser for the rest, and for when the page cannot be reached.
- **Rendering.** A release body is GitHub-flavoured Markdown. The app reads a
  small subset itself, in `lib/core/updates/markdown_subset.dart`: `#`, `##`
  and `###` headings (deeper ones as `###`), `*` and `-` bullets, `**bold**`,
  and links, `[text](url)`, as their text. Everything else shows as written,
  bare URLs and `@user` mentions included. The two lines the release workflow
  writes at the top of every body, the licence and the source, are removed
  when they are whole lines at the very top and nowhere else.

## Consequences

- **What GitHub learns.** Each opening tells it the phone's address, that it
  asked, and the app's version, as a check does. Nothing is asked until the
  learner opens the page.
- **The notes are GitHub's, not ours.** They are the generated list of pull
  request titles with their authors, "What's Changed", and the link to the
  full comparison, not the prose of `CHANGELOG.md`. They show in English, as
  written, like deck content; the words around them are interface tokens.
- **Not offline.** With no network the page says so and offers Try again.
  There is no copy to fall back on.
- **A shared limit.** The 60 requests an hour GitHub allows one address
  without an account are shared with the update check.
- **The top lines depend on their wording.** If `release.yml` changes the two
  lines, they show in the notes until `withoutReleaseBoilerplate` in
  `release_notes.dart` is changed to match. Nothing breaks.
- **A subset.** Italics, code, numbered lists and tables show with their
  marks. A link's address is dropped, so it cannot be followed.

## Alternatives considered

- **Bundling `CHANGELOG.md`.** Works offline, and its prose is written for
  learners where the generated notes are pull request titles. But it has to
  be kept in the asset bundle and in step with every release, and the owner
  chose GitHub's.
- **A Markdown package.** Renders everything, for a dependency (AGENTS.md
  rule 6) that this page would use for a handful of constructs.
- **Fetching at launch, or keeping a copy.** Asks a third party before the
  learner chose to, which ADR-0017 refused for the update check. A kept copy
  would also go stale between releases.
- **A row that only opens the releases page.** Costs no request, but sends the
  learner out of the app for what the owner asked to read in Updates.
- **`releases/latest` for each version, or paging through every release.**
  More requests against the hourly limit, for notes few will scroll to.
