# ADR-0021: Reports go from a bug icon on every screen, by the reporter's mail, into GitHub issues

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

The owner asked for "a way to record suggestions, features and bugs and
report them directly on github", with "every screen will have a bug report
icon", and a way to "add screenshot (which will add the screenshot of the
screen on which the button was pressed)". The Marathi, Kannada, Gujarati
and Telugu decks are unchecked and "will be verified by users", so reports
about cards matter most.

Set aside, with the owner:

- **A GitHub token in the app.** It would be in the public APK, and the
  narrowest token can still edit and close every issue.
- **A relay** holding the token: the owner did not want another service.
- **Google and Microsoft Forms.** Neither takes a file without the reporter
  signing in.

The owner chose mail: "users mail stuff there from the app itself (will be
routed via their mail application, but prefilled and all screenshots
attached)", into a Fluenough Gmail, with "a bot" turning mails into issues.
Mail stays incoming until that inbox exists (#160).

## Decision

- **A bug icon on every screen.**
  - Where it is: `ReportButton` is in every app bar, the tabs' `TabHeader`
    and every drill's frame. Screens with no bar get it through
    `WithReportButton`: Today, onboarding, the summary and profiles.
  - The same report is also behind an unchecked deck's "Report a mistake",
    and behind each card's Report in Inspect.
  - `test/gallery_test.dart` fails for any screen in the gallery without
    the icon.
- **Until mail is on (`Feature.feedbackMail`, #160), every report button
  opens GitHub's new-issue form.** The form is pre-filled with the screen,
  what it showed (a card's or deck's id), the app's version, the system,
  and the languages being learned. The reporter needs a GitHub account.
- **Once mail is on:**
  - The button takes a picture of its screen (`ReportCapture`, a
    `RepaintBoundary` around the app) and opens the report: Bug, Feature or
    Suggestion, a title and details.
  - "Add screenshot of this screen" is off until tapped, and shows the
    picture once added.
  - Sending opens the reporter's own mail app through `flutter_email_sender`,
    a dependency agreed with the owner. The mail is addressed to the Fluenough
    Gmail, its subject is `[Fluenough] Bug: …`, and the screenshot is attached.
    The reporter sends it; the app sends nothing itself.
- **An hourly Action files the mails as issues** (`tools/mail_to_issues.py`,
  stdlib only).
  - It reads the inbox over IMAP with an app password held in repository
    secrets.
  - It takes only mails whose subject starts with `[Fluenough]`.
  - The issue is text only: the screenshot stays in the mail, and the issue
    says one came.
  - The sender's address is never written to the public issue, and
    `@mentions` are broken.
  - A filed mail gets the Gmail label `fluenough-filed`, never a read mark,
    so it is never filed twice.

## Consequences

- One new app dependency, `flutter_email_sender`. CI's Android setup
  declares the mail-app query it needs on Android 11+.
- Turning mail on needs:
  - the Gmail address in `AppLinks.feedbackEmail`;
  - the repository secrets `FEEDBACK_GMAIL_ADDRESS` and
    `FEEDBACK_GMAIL_APP_PASSWORD`;
  - `Feature.feedbackMail` in `Feature.available`.
- A reporter without a mail app gets told so; one without a GitHub account
  cannot report until mail is on.
