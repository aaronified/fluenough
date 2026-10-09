# ADR-0021: Reports go from a bug icon on every screen, by the reporter's mail, into GitHub issues

- **Status:** Accepted. Amended on 2026-10-09, in the section at the end:
  three kinds, support kept private, the app log, and Android's share.
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

Screenshots then went: the owner did not want them on public issues, and
then said "Forget screenshots then. Only text." Device details go only
with consent: "Attach a log and device information but only with explicit
consent from the user." The app keeps no log yet; that is #162.

## Decision

- **A bug icon on every screen.**
  - Where it is: `ReportButton` is in every app bar, the tabs' `TabHeader`
    and every drill's frame. Screens with no bar get it through
    `WithReportButton`: Today, onboarding, the summary and profiles.
  - The same report is also behind an unchecked deck's "Report a mistake",
    and behind each card's Report in Inspect.
  - `test/gallery_test.dart` fails for any screen in the gallery without
    the icon.
- **Text only.** No screenshot is taken or sent.
- **Device details only with consent.** Every report carries the screen and
  what it showed (a card's or deck's id). One box, "Include device
  information", unticked until the reporter ticks it, adds the app's
  version and language, the system's version (Android's, read with
  `getprop`, no package), the screen's size, the text scale and the
  languages being learned. The exact lines it adds are shown under it.
  The app log joins the same box once it exists (#162); Settings shows a
  Logs section as incoming until then.
- **Until mail is on (`Feature.feedbackMail`, #160), every report button
  opens GitHub's new-issue form**, after a sheet with that box. The form
  is pre-filled with what the report carries. The reporter needs a GitHub
  account.
- **Once mail is on:**
  - The button opens the report: Bug, Feature or Suggestion, a title,
    details, and the box.
  - Sending opens the reporter's own mail app through a `mailto` link
    (url_launcher, already a dependency). The mail is addressed to the
    Fluenough Gmail and its subject is `[Fluenough] Bug: …`. The reporter
    sends it; the app sends nothing itself.
- **An hourly Action files the mails as issues** (`tools/mail_to_issues.py`,
  stdlib only).
  - It reads the inbox over IMAP with an app password held in repository
    secrets.
  - It takes only mails whose subject starts with `[Fluenough]`.
  - The issue is text only: a picture the reporter attached by hand stays
    in the mail, and the issue says one came.
  - The sender's address is never written to the public issue, and
    `@mentions` are broken.
  - A filed mail gets the Gmail label `fluenough-filed`, never a read mark,
    so it is never filed twice.

## Consequences

- No new dependency.
- Turning mail on needs:
  - the Gmail address in `AppLinks.feedbackEmail`;
  - the repository secrets `FEEDBACK_GMAIL_ADDRESS` and
    `FEEDBACK_GMAIL_APP_PASSWORD`;
  - `Feature.feedbackMail` in `Feature.available`.
- A reporter without a mail app gets told so; one without a GitHub account
  cannot report until mail is on.

## Amendment, 2026-10-09: three kinds, private support, the app log, the share

### Context

The Fluenough Gmail exists: `fluenough@gmail.com`, in
`AppLinks.feedbackEmail`. The owner decided the rest on #160 and #162:

> use that mail for support mails as well. when users ask for support or
> report bugs, give feedback, they will again get open mails to this id,
> with different preset subject and body text (which they will edit as
> needed). logs will be added if the users wished.

And on the log: it records "errors and warnings, plus key events: screens
opened, decks loaded, fits run, imports and exports. It never records
answers typed or card contents", kept "capped at the last 7 days or 2,000
lines, whichever is smaller, so a crash's log survives a restart".

### Decision

- **Three kinds:** Get support, Report a bug and Give feedback. Feature
  requests and suggestions are feedback. `ReportKind` is `support`, `bug`
  and `feedback`.
- **The form stays first:** the kind, a title and details. Then the mail
  app opens to the Fluenough address with the kind's own subject,
  `[Fluenough] Support: …`, `Bug: …` or `Feedback: …`, and its own
  questions under the details, such as "What did you expect instead?".
  The reporter can change both before sending. The body's context starts
  with a `Kind:` line.
- **Public or private:**
  - Bug reports and feedback become public issues, as before.
  - Support mails stay private in the inbox. `tools/mail_to_issues.py`
    skips a mail, and leaves it as it came, when its subject's kind or its
    body's `Kind:` line says `Support`: either, as the reporter may edit
    one of them.
  - Mails from older versions, `Feature: …` and `Suggestion: …`, are filed
    as feedback, with the label `feedback`.
- **The app log (#162):**
  - The model is pure Dart, in `lib/core/logs/`: one line an entry, the
    time, the level (`ERROR`, `WARN`, `EVENT`) and the message, and the
    cap. `lib/app/app_log.dart` keeps it in a file in the app's own
    storage, `logs/app.log`, a line at a time.
  - It records Flutter's errors and errors nothing caught
    (`FlutterError.onError`, `PlatformDispatcher.onError`, passed on to
    where they went before), warnings, and key events: screens opened, by
    route name only, tabs, decks loaded, added and removed, fits run, by
    skill, imports and exports, and reports sent. An error keeps its first
    8 stack frames; an entry is cut at 2,000 characters.
  - Settings' Logs section is no longer incoming: View, Copy, Export
    (a text file, through the review log's file dialog) and Clear.
- **Attaching the log:** a second box, "Attach the app log", under the
  device box and unticked like it. It shows how many lines the log holds,
  what kinds of thing it records, its newest lines, and a way to see it
  all. Support mails get it too. The Action never puts it in an issue: the
  issue says a log came, and the log stays in the inbox.
- **The share:** a mailto link cannot carry a file.
  - A report with the log goes through `shareFiles`, a new method on the
    `app.fluenough/system` channel. It sends Android's share,
    `ACTION_SEND`, or `ACTION_SEND_MULTIPLE` for several files, with
    `EXTRA_EMAIL`, `EXTRA_SUBJECT`, `EXTRA_TEXT` and the files. It asks
    mail apps first, through a `mailto:` selector, then the share sheet.
  - The files are written to `shared/` in the app's cache, and lent through
    `ShareFileProvider`, a `FileProvider` of the app's own.
    `tools/brand_android.py` writes the method, the class, its manifest
    entry, its paths file and a query for mail apps, each once.
  - It takes a list of files, so that sending review files
    (`docs/plans/deck-browser.md`) can reuse it.
  - Without the log ticked, the report goes by `mailto` as before. If the
    share fails, it goes by `mailto` without the log, and the reporter is
    told the log was not attached.

### Consequences

- Still no new dependency.
- The Kotlin is checked by shape in `tools/test_brand_android.py`; only
  CI's debug build compiles it. `ShareFileProvider` needs
  `androidx.core` on the app's classpath, which the Flutter embedding
  brings.
- A reporter who changes both a support mail's subject and its `Kind:`
  line to something else makes it public. That is their edit to make; the
  app says plainly which kinds become public.
- The log is plain text on the phone. It holds route names, deck ids,
  skill names and error texts, never answers or cards, but an error's text
  can name what the app was doing. It leaves the phone only when the
  reporter ticks the box, or exports or copies it.
- On iOS, which has no share yet, a report goes without the log, and says
  so.
- Support mails are answered by hand from the inbox; nothing replies
  automatically.

### Alternatives considered

- **A share plugin:** a dependency, for one intent the channel sends
  without one.
- **The log in the mail's body:** a mailto link has a length limit, and
  the log would land in the public issue.
- **Labelling support mails in Gmail:** not needed; skipped, they stay as
  they came.
