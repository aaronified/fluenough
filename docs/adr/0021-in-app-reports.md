# ADR-0021: Reports go from a bug icon on every screen, through a relay that holds the token

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

The owner asked for "a way to record suggestions, features and bugs and
report them directly on github", then: "User should be able to add
screenshots of their app screen from where they are raising a bug report,
and every screen will have a bug report icon." The Marathi, Kannada,
Gujarati and Telugu decks are unchecked and "will be verified by users", so
reports about cards matter most.

The owner first proposed a GitHub token added at build time from GitHub's
secrets. A value compiled into the app is in the APK, which is public on the
releases page, and a fine-grained token's narrowest permission (Issues:
write) also edits and closes every issue. A pre-filled GitHub link needs the
reporter to have an account and cannot carry a screenshot. Google Forms
cannot take a file without the reporter signing in. The owner set those
aside.

## Decision

- **A bug icon on every screen.** `ReportButton` is in every app bar, in the
  tabs' `TabHeader`, in every drill's frame, and in the screens with no bar
  (Today's header, onboarding's top bar, the summary and profiles, through
  `WithReportButton`). `test/gallery_test.dart` fails for any screen in the
  gallery without one. An unchecked deck's "Report a mistake" opens the same
  report, about that deck.
- **The screenshot is of the screen the icon is on.** `MaterialApp.builder`
  puts the whole app in a `RepaintBoundary` (`ReportCapture`); the icon
  takes the picture before the report opens, at no more than twice the
  screen's logical size. The report shows it, and the learner may leave it
  out.
- **The report says what it adds:** the app's version, the system's, the
  app language, the languages learned, the screen's route, and what the
  screen showed (a card's id and deck, a deck's id, a tab). Nothing else.
  It says reports are public.
- **The app sends to a relay, never to GitHub.** A Cloudflare Worker
  (`tools/report-relay`) holds a fine-grained token, limited to this
  repository with Issues and Contents write, as a Cloudflare secret. It
  checks each report, turns away an address sending more than five a
  minute, saves the screenshot on a `report-screenshots` branch with no
  history of `main`'s, and opens a labelled issue. It never edits, closes or
  comments, and breaks `@mentions` so a report notifies no one.
- **The relay's address is given at build time** (`--dart-define=REPORT_URL`,
  the repository variable `REPORT_URL` in the release workflow). It is not a
  secret. A build without it says reports cannot be sent.
- **No new dependency:** the picture is Flutter's own, the request dart:io's
  client, as the update check (ADR-0017). The Worker's tests use Node's own
  runner.

## Consequences

- The owner runs a Worker: a free Cloudflare account and a one-time deploy
  (`tools/report-relay/README.md`). If it is down, the app says it could not
  reach the report service.
- Anyone who finds the relay's address can open issues, rate-limited. They
  cannot change existing ones.
- Screenshots are public on the `report-screenshots` branch, like the
  issues. The branch grows with each one; it can be pruned without touching
  `main`.
- A screen added later needs the icon, or its gallery entry fails the test.
