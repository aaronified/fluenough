# Plan: a deck browser for reviewers, on GitHub Pages

Written 2026-10-06. **After the native layers** (`native-layers.md`), the
owner's order, so that it shows cores and layers as they will be.

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
