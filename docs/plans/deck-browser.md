# Plan: a deck browser for reviewers, on GitHub Pages

Written 2026-10-06. **Moved ahead, 2026-10-09:** built now, on today's
deck format, before the native layers (`native-layers.md`), so that
reviewers can check the Bengali and Telugu B1 decks as they arrive; layer
support is added when #392 lands (owner).

## What the owner asked

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
  ("How offensive is this word to people in general?") and gives their
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
  2026-10-09). iOS needs its own later.
- **The first mail binds the code to its sender** (owner, 2026-10-09): the
  first review mail with a new code ties that code to the sender's
  address. The workflow keeps, in a file in the repository, the code with
  a keyed hash of the address (the key a GitHub secret), never the address
  itself. A later mail with the same code from another address gets an
  issue marked "sender does not match", for the owner to decide.
- **The deck screen in reviewer mode comes from the owner** (2026-10-09:
  "deck in reviewer mode will be handed to you. drop that part"), with
  the decks redesign mockup; the reviewer-mode mockup drops it.
- **"How reviewing works"** is explained in a popup the reviewer can open
  again from Settings at any time (owner, 2026-10-09).
- **Joining is automatic:** a join mail makes the sender a reviewer at
  once. "I will also ask the people to either share their email or
  rater_id to me in person to filter, if needed. We need maximum
  participation. I do not see a huge risk of ghost reviews."
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
- **Reviewer mode is hidden until a code is set;** everyone sees only
  "Become a reviewer" in Settings.

## The form's link is not private

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

- **"Suggest a change"** on each card, and on a deck's name and description:
  - the field (target, reading, IPA, meaning, a note, an example), its
    current text, the suggestion, why, and an optional name;
  - the deck id and card id are filled in by the page.
- **Sent from the page** to the form's `formResponse` address.
- **The page cannot read Google's reply,** since browsers do not let it read
  replies from another site. So it cannot tell whether a submission arrived:
  it says "Sent" either way. The canary below is what catches a failure.

## From the Sheet to issues

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
