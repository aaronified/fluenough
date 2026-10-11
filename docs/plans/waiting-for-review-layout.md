# Plan: Waiting for review, reviewed decks first and languages folded

Written 2026-10-11. Plan only; not built yet.

## What the owner asked

> The reviewed decks should sit at the top of this screen, with 2 options:
> Reviewed and sent (which will in turn have details on appectance,
> rejections, and waiting for second review, but without any user code),
> reviewed and not sent (this in turn will have details on the deck and
> cards).
>
> The languages should be foldable (and folded by default with a count of
> unreviewed decks and cards on it).
>
> This is to be a plan, not a build right now.

## What exists

Waiting for review lists each reviewed language, then its units with the
cards left to check. A row near the end of a language reads
"1 deck reviewed, not sent". Sent reviews are not shown.

## The screen, top to bottom

1. **Reviewed, not sent.** One row with a count, such as "2 decks, 31 cards,
   not sent". It opens a page grouped by deck, which lists:
   - each card marked "Looks right";
   - each suggestion, with its part, the current value, your text and your
     "Why".

   From there you can Send the review, or open a card to change or drop a
   suggestion.
2. **Reviewed and sent.** One row with a count, such as "5 decks sent". It
   opens a page grouped by deck, which shows each of your suggestions in one
   of three states:
   - **Accepted:** agreed and merged into the deck;
   - **Rejected:** the field changed another way, or the owner closed it;
   - **Waiting for a second review:** still short of
     `REVIEW_AGREEMENTS_NEEDED` acceptances.

   It shows **no rater codes**, neither yours nor anyone else's, only counts
   such as "1 more acceptance needed".
3. **One section per language, folded by default.** The header shows the
   language and its counts, such as "Bengali · 12 decks, 418 cards to
   check", with an arrow and a screen-reader state. Tapping the header
   unfolds the language's units as they are now. What is unfolded is
   remembered, like the Decks path's levels (#465).

The per-language "N decks reviewed, not sent" row goes, since section 1
covers it.

## Where the states come from

- **Not sent:** the reviews kept on the phone, which the app already
  stores.
- **Sent:** the app keeps the proposal ids it sent, without the mail. Their
  state is read from the downloaded decks:
  - **Waiting:** the proposal is still in the deck file. Its acceptance
    count gives "N more needed".
  - **Accepted:** the proposal is gone and the field now holds its text.
  - **Rejected:** the proposal is gone and the field holds something else.

  A deck update refreshes the states. Nothing needs the network beyond the
  deck download.

## Tests

- Both reviewed rows sit above the languages and open their pages.
- Not sent: grouped by deck, showing the cards and the suggestion detail.
- Sent:
  - all three states are worked out from deck files;
  - no rater code appears anywhere on the page or in its semantics.
- Languages:
  - folded by default, with the counts in the header;
  - the header unfolds a language, and that is remembered;
  - accessibility at 2x text, in light and dark.

## Estimate

About 1.5 to 2.5 days. Confidence is medium; the "Sent" states depend on
the review bot's proposal format.
