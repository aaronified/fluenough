# Plan: reviewing decks in the app, sent by mail

It began on 2026-10-06 as a deck browser on GitHub Pages with a Google Form
and a Sheet. On 2026-10-09 the owner moved the review into the app, sent by
mail, and dropped the Sheet. **What stands is "Review in the app, by mail"
below** (tracker #403; the app side merged in #436, the mail sender check in #439, and proposals in #444). The sections
about the Pages site, the form and the Sheet are kept for what they decided,
and each says where it is superseded.

**What the mail design is, in short:** the reviewer turns reviewer mode on in
Settings and the phone makes their rater code; they review on the screens
that already show decks and cards; one mail carries a review file per deck,
with the code and the languages, to the Fluenough address; the hourly mail
job opens one issue per mail with only the code and languages; the owner
reads the mail and the decks are updated with him. No Form, no Sheet.
Whether a public deck browser on Pages survives at all is for the owner to
decide (#404, #405). **Since 2026-10-09 (#441, ADR-0038)** the decks are no
longer updated by hand from the mail: a review's suggestions become
proposals in the decks at once, and agreement merges them to learners; see
"Reviewers change the decks, with no wait" below.

Written 2026-10-06. **Moved ahead, 2026-10-09:** built now, on today's
deck format, before the native layers (`native-layers.md`), so that
reviewers can check the Bengali and Telugu B1 decks as they arrive; layer
support is added when #392 lands (owner).

## What the owner asked

*Superseded 2026-10-09: the page, the form and the weekly canary. See "Review in the app, by mail".*

> Another plan: deck browser via github pages, which language reviewers can
> use to check the decks and suggest changes in the page itself (which will
> capture the suggestions via google forms (link added via github secrets
> should remain private, right)).

Decided with the owner:

- **Sent from the page itself,** with no Google screen, plus a weekly canary
  that opens an issue if submissions stop reaching the Sheet.
- **No sign-in;** a name is optional.
- **Suggestions go to the Sheet, then become GitHub issues,** labelled
  `priority: highest` and `deck:<deck-id>`, plus the language's label.

## Widened, 2026-10-09 (owner)

> We will also have to build a review pipeline via a github page and
> linked google sheet

Beyond per-card suggestions, the pages handle:

- **Sign-off per card and deck.** A reviewer marks each card checked or
  not; once a native speaker has signed off every card of a deck, its
  `unreviewed` tag can be removed. B1 and offensive decks ship only then.
- **A separate screen for offensive words,** "so that the reviewer knows
  what he/she is getting into": it states what it holds before showing
  anything, and asks for a rater code and an 18+ confirmation.
- **Offensive-word ratings:** each rater scores each offensive word 1 to 9
  ("How offensive is this word to native speakers in general?") and gives their
  region; the Sheet takes the median band and flags a disagreement of a
  band or more as a region note (`offensive-words.md`).
- **Similarity confirmations:** reviewers confirm or reject the tool's
  sound-alike and look-alike pairs and write the care note.
- **Level suggestions** through the ordinary suggestion box as well.
- **Rater codes:** the owner gives each reviewer a short private code,
  kept in the Sheet, not the repository; the page asks for it once and
  keeps it in the browser. Ratings and sign-offs count per code, so one
  person cannot stack votes. Plain suggestions still need no code.

### The owner's Sheet, 2026-10-09

*Superseded the same day by "No Sheet" below: the mail has all the data, and the rater code is made by the app. Kept for the reasoning about private data.*

> you will generate an unique rater-code generation function (for the
> google sheet). and i will use that to generate the codes and hand them
> out. this will be a google sheet that only I will have access to, it will
> have the email id of the participant and their details. the same sheet
> will have the reviewer results.
>
> since the sheet can only be accessed by me directly, and by my github,
> the security risk looks small, unless the secret spills out.

So:

- **One private Sheet,** shared with the owner and the workflow's service
  account only. A **Raters** tab holds each participant: email, name,
  languages, region, adult content confirmed, their code, when it was
  made, and whether it is active. The **responses** (suggestions,
  sign-offs, ratings, similarity checks) land in the same Sheet.
- **Codes are made in the Sheet** by an Apps Script function the
  repository provides: random and unguessable (the Form is public, so a
  guessed code is the risk), unique in the Sheet, with a check character
  that catches a mistyped code, and revocable.
- **What keeps the emails private,** since the repository and its
  workflow logs are public:
  - the workflow reads only the columns it needs (code, languages, adult
    confirmed, active), never email, name or other details;
  - it writes no row to a log, an issue or the repository, only counts and
    ids; an issue carries no code, email or name unless the reviewer typed
    a name into the suggestion themselves;
  - the service-account key is a secret available only to the scheduled
    workflow on `main`, never to pull requests from forks.

### Review in the app, by mail (owner, 2026-10-09)

> no, only the emails will be allowed to participate in the review.

> no. the reviewer reviews in the app itself. no extra screen. they share
> their reviewed file via email to a fluenough email ID. this mail will
> include their reviewer code. think along this line. for maximum
> automation and seamless review

This replaces the web page and the Google Form above for reviewing: the
reviewer reviews inside the app, on the screens that already show decks
and cards, and sends a review file by mail, with their code, to the
Fluenough address, where the hourly workflow that already reads that
mailbox (`tools/mail_to_issues.py`) takes it in. Only enrolled emails take
part: a review is accepted only from the email its code was made for.
Settled with the owner, 2026-10-09:

- **The rater code is made by the app** when the reviewer turns reviewer
  mode on: random, from the phone's secure random source (about 50 bits),
  written `FL-XXXX-XXXX-C` in Crockford base32 (no I, L, O or U) with a
  check character that catches a single typo or two swapped neighbours.
  **No join mail:** the owner first hears of a reviewer with their first
  review (owner, 2026-10-09).
- **Sending:** the app's own Android share, no new dependency: an
  ACTION_SEND intent with the review file shared through a FileProvider,
  the Fluenough address and the subject (with the rater code) filled in,
  opening the reviewer's mail app; the reviewer sends it (owner,
  2026-10-09). iOS needs its own later. The share is built, for reports
  with the app log: `shareFiles` on the `app.fluenough/system` channel,
  through `MailShare` in `lib/app/mail_share.dart`, which takes a list of
  files (ADR-0021, amended 2026-10-09).
- **Several decks in one mail** (owner, 2026-10-09: "the reviewer should
  be able to send multiple decks for review at the same time as well. and
  this needs to be communicated at every important juncture as well (when
  signing up, or when sending the mail)"). Reviews of every deck stay on
  the phone until sent. "Send review", on any deck or from Settings'
  "Reviews to send" row, opens one send sheet listing every deck with
  unsent reviews, all ticked; the reviewer can untick any. One mail goes
  out (ACTION_SEND_MULTIPLE) with one file per deck; its subject carries
  the rater code and the languages, its body lists each deck and its
  count. The workflow opens one issue per mail, with the code and the
  languages. Said at each step: the turn-on dialog ("review as many decks
  as you like, and send them together in one mail"), "How reviewing
  works", the deck's foot ("3 decks waiting to send"), the send sheet, and
  the mail's body.
- **The files are the record, not the mail** (owner, 2026-10-09: "the
  rater code and languages in the subject (and also in the json files).
  the reviewer may accidentally delete or change the body / title of the
  mail"). Every review file carries the rater code, the language, the
  deck id, the app version and when it was made, so the files stand on
  their own. The subject also carries the code and the languages, and the
  body is for people only. The workflow reads the code and languages from
  the files; when the subject is missing or disagrees with them it goes by
  the files and marks the issue "subject changed"; files in one mail with
  different codes, or none, mark it "check the files", for the owner.
- **What is waiting for review, in the reviewer's languages** (owner,
  2026-10-09: "any reviewer should also know what all is pending
  unreviewed in their chosen languages"). The reviewer chooses the
  languages they review (by default the languages they speak that the
  app teaches). Reviewer mode then shows, per language, what still needs
  a native speaker: the units and decks not yet signed off, with how many
  cards each has left, the offensive words not yet rated and the
  sound-alike and look-alike pairs not yet confirmed, and what the
  reviewer has already reviewed but not sent. It shows in Settings under
  "Review decks" and as a "To review" mark on each unit of the path.
- **The sender check lives in the Fluenough Gmail** (owner, 2026-10-09,
  replacing the keyed hash in the repository; see the next bullet): the hourly mail job
  keeps one private record per rater code in a Gmail label
  (`fluenough/raters`), holding the address its first review came from.
  Addresses are matched with case ignored, and for Gmail with dots and
  `+…` ignored. A later review from another address gets a "sender does
  not match" issue; the owner decides. No new secret, nothing written to
  the repository, and the job logs only counts. **Built** (2026-10-09) in
  `tools/mail_to_issues.py`: the tool creates the label and writes a record
  with IMAP APPEND (no mail is sent), its subject the code and its body
  the address. Records are read afresh each run, so one the owner deletes
  is tied again by the code's next mail, and a sender matching any record
  of its code passes, so the owner can allow a second address by adding
  one, its body's first line the address, bare or as `Name <address>`.
  When the label cannot be read or a record cannot be written, or the
  mail has no single sender, the mail is still filed, marked "sender not
  checked". When the connection drops while a record is written, the run
  stops before filing that mail, and the next run files it, so it is not
  filed twice.
- **The first mail binds the code to its sender** (owner, 2026-10-09; *the
  keyed hash in the repository was replaced the same day by the Gmail
  record above, and is not built*): the
  first review mail with a new code ties that code to the sender's
  address. The workflow keeps, in a file in the repository, the code with
  a keyed hash of the address (the key a GitHub secret), never the address
  itself. A later mail with the same code from another address gets an
  issue marked "sender does not match", for the owner to decide.
- **The deck screen in reviewer mode comes from the owner** (2026-10-09:
  "deck in reviewer mode will be handed to you. drop that part"), with
  the decks redesign mockup; the reviewer-mode mockup drops it. The card
  in reviewer mode (the sheet with "Looks right" and "Suggest a change")
  is approved as mocked.
- **"How reviewing works"** is explained in a popup the reviewer can open
  again from Settings at any time (owner, 2026-10-09).
- **Joining is automatic, with no join mail** (owner, 2026-10-09, over an
  earlier plan in which a join mail made the sender a reviewer): turning
  reviewer mode on is the whole of joining, and a reviewer's first review
  mail is how the owner first hears of them; the sender check above binds
  the code to that mail's address in the Fluenough Gmail record. "I will
  also ask the people to either share their email or rater_id to me in
  person to filter, if needed. We need maximum participation. I do not see
  a huge risk of ghost reviews."
- **No Sheet:** "no sheet needed anymore. the mail will have all the data.
  i then open the mail myself and consult with you on updating the decks."
  The workflow only opens the issue (rater code, language); the owner
  reads the mail and the decks are updated with him. This supersedes the
  Sheet and the automatic PR below.
- **Results reach the decks through a PR the owner merges:** one per
  language, with sign-offs (unreviewed tags removed), offensiveness levels
  and confirmed similarity notes; suggestions stay as issues.
- **No reply mail; thanks in the app:** issues and mails carry the rater
  code; an updated deck lists the rater codes that helped build it, and a
  reviewer whose code is among them sees "thank you" in the app. So rater
  codes are public; that is safe because a review is accepted only from
  the email its code belongs to.
- **Issues say who sent something, not what:** "the public issues can
  contain the rater id and language, the data may be skipped in the
  tickets. so i know that a reviewer has sent something and then consult
  the mail." One issue per review mail received: the rater code, the
  language and decks reviewed, counts at most; no suggestion text.
- **Reviewers change the decks, with no wait** (**built**, 2026-10-09, on
  `feat/review-proposals`: ADR-0038, the `proposed` format, reviewer mode's
  Accept, Edit and Reject, the bot in `tools/review_bot.py`, and the owner's
  guide, `docs/review-bot-setup.md`; it waits for the App's secrets) (owner, 2026-10-09:
  "Make it totally automated then. The first review auto merges the PR
  and shows all changes to all applicable reviewers. If anyone agrees,
  that gets an instant merge to learner decks. This number can be a
  github secret so that I can update it easily. Like maybe once the app
  gains traction, i change it to two reviewers"). This supersedes the
  owner's provisional acceptance and the three-day wait, decided earlier
  the same day.
  - **A review becomes proposals at once:** the mail bot opens a PR that
    adds each suggested change as a `proposed` block on its card, and
    merges it as soon as the required checks pass. Proposals reach every
    reviewer of that language through deck downloads; learners never see
    them. This is a deck-format change and needs its ADR.
  - **Agreement merges it to learners at once:** when enough other
    reviewers accept a proposal verbatim, the bot opens a PR applying it
    and merges it once the checks pass. "Enough" is the repository
    variable `REVIEW_AGREEMENTS_NEEDED` (default 1), a variable rather
    than a secret so the owner can read it back. Each agreement must come
    from a different rater code from the proposer's and each other's.
  - **Accept, edit or reject:** a reviewer who edits a proposal makes a
    new proposal of their own, which goes in the same way; the old one
    keeps waiting. The first proposal on a field to reach enough
    agreements wins; the others on that field are closed as outdated.
    "First" is the one whose agreement PR opened first: while it is open,
    no other proposal on the field is applied. Several that reach it
    before any PR opens go in the order they were proposed, which is
    their order in the file. A rejection only flags the change to the
    owner.
  - **The owner's override** is any later commit: reverting the change,
    editing the card, or deleting a proposal. The bot builds a PR again
    from `main` before merging it whenever `main` has moved, and closes
    an agreement PR whose proposal is no longer there. Every bot PR names the rater codes involved.
  - **Past the branch rules:** a dedicated GitHub App merges these PRs.
    It is the only actor allowed to skip the approval rule; the three
    required checks still apply to it. The owner creates and installs the
    App, adds it to the protection's bypass list and stores its id and key
    as the secrets `FLUENOUGH_BOT_APP_ID` and `FLUENOUGH_BOT_PRIVATE_KEY`.
  - **No merge conflicts:** the bot never stores a diff. A proposal is a
    fact about one card: its id, the field, the text the proposer saw and
    the new text. Each bot PR starts a fresh branch from `main`, finds the
    card by id (ids are permanent, so a moved card is still found), and
    writes only if the field still holds the text the proposer saw. It
    rebuilds `decks/index.json` with the tool. A proposal whose field has
    changed, or whose card is gone, is closed as outdated, not merged.
- **Reviewer mode is hidden until a code is set;** everyone sees only
  "Become a reviewer" in Settings.

## The form's link is not private

*Superseded 2026-10-09: there is no form.*

A GitHub secret keeps a value out of the repository and the logs, but the
site is public. Whatever the build writes into a page can be read with View
Source, and that includes the form's link. That is fine: the link only lets
people submit. The responses stay private in the owner's Google account and
Sheet. So:

- **The form's address and field ids** are a repository *variable*, not a
  secret, so changing the form needs no code change.
- **The key that reads the Sheet** (a Google service account) is a *secret*.
  Only the workflow uses it, and it never reaches the site.

## The site

*Not part of the mail design. Whether a public site survives is for the owner (#404, #405); the Pages workflow is also needed by `web-pwa.md` (#306).*

- **Built by a workflow** from `decks/` on every push to `main`, into Pages.
  It shares the Pages setup with `web-pwa.md`.
- **One page per language,** listing its decks; **one page per deck**, with
  every card:
  - the target, its reading and IPA;
  - each native layer's meaning and notes;
  - the examples;
  - a speaker that uses the browser's own voice where it has one.
- **Grammar decks** as their tables; **reading decks** as passages with
  their questions; **facts, sounds and script guides** too.
- **Unreviewed decks** are marked, as in the app.
- No build tools beyond Python and the standard library, like the other deck
  tools.

## Suggesting a change

*Superseded 2026-10-09: a suggestion is made in the app, on the card sheet, and sent in the review mail. The page and the form are not built (#406 closed).*

- **"Suggest a change"** on each card, and on a deck's name and description:
  - the field (target, reading, IPA, meaning, a note, an example), its
    current text, the suggestion, why, and an optional name;
  - the deck id and card id are filled in by the page.
- **Sent from the page** to the form's `formResponse` address.
- **The page cannot read Google's reply,** since browsers do not let it read
  replies from another site. So it cannot tell whether a submission arrived:
  it says "Sent" either way. The canary below is what catches a failure.

## From the Sheet to issues

*Superseded 2026-10-09: there is no Sheet. The hourly mail job opens one issue per review mail (#407). The canary tested the form and is not carried over.*

- **A scheduled workflow** reads new rows with the service account. Each
  becomes an issue:
  - its title names the deck, the card and the field;
  - its body has the current text, the suggestion and the reason, and the
    reviewer's name if given;
  - it is labelled `priority: highest`, `deck:<deck-id>` (created the first
    time), and the language's label.
- It never writes an email address. Rows already turned into issues are
  marked, so none is filed twice.
- **The canary:**
  - once a week, the workflow submits a test suggestion through the same
    address and field ids the page uses;
  - on its next run, it checks that the suggestion reached the Sheet;
  - if not, it opens an issue saying submissions have stopped, likely
    because the form's fields changed.

## What it takes

*As first planned, for the Pages and form design. Under the mail design none of 1 to 5 stands; what replaces them is the mail job (#407) and the in-app review (#427 to #430), in PR #436. The docs (6.) remain.*

1. **The site generator,** `tools/deck_site.py`, and its tests.
2. **The Pages workflow,** shared with `web-pwa.md`.
3. **The suggestion box and its send.**
4. **The Sheet-to-issues workflow,** its labels, and the canary.
5. **The owner's setup:**
   - the form, with its fields;
   - the repository variable holding its address and field ids;
   - the service account, as a secret;
   - Pages switched on.
6. **Docs:** a page for reviewers on how to suggest, and the README.

## To decide

- Whether a public deck browser on Pages is built at all (#404, #405).
- Whether a deck's page also shows the cards' history: when a card last
  changed, and by which issue.
- Whether reviewers can filter to unreviewed decks only.

## Estimate

| Part | Hours |
|---|---|
| Site generator and Pages workflow | 4–6 |
| Suggestion box and send | 2–3 |
| Sheet-to-issues workflow and canary | 3–4 |

Confidence: medium. The owner's setup of the form, the variable and the
service account is outside these hours.
