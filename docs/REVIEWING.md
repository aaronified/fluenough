# Reviewing Fluenough decks

<!-- This guide is also the app's reviewer onboarding, "How reviewing works"
(lib/features/review/how_reviewing_works.dart, strings reviewGuide* in
lib/l10n/app_en.arb). Each `## ` section but Help is one step there, in this
order; change a fact here and change it there too.
test/features/review/how_reviewing_works_test.dart checks the headings. -->

Thank you for considering this. You do not need to know anything about
programming. You need to speak the language well and have an Android phone
with the Fluenough app and a mail app.

## What reviewing is

Fluenough teaches languages from decks of cards: a word, how it is read, what
it means, examples. Many decks were written without a native speaker and are
marked "unreviewed" in the app. You are the check. You tell us which cards are
right, which are wrong and what they should say, and how rude a word really
sounds to native speakers. A review by a native speaker is the most useful
thing anyone can give these decks.

## Your code and languages

1. Open **Settings**, find the **Reviewing** group and turn on **Review decks**.
2. The app asks first, then makes your **rater code** on your phone, like
   `FL-XXXX-XXXX-C`. Nothing is sent when you turn reviewing on. You can copy
   the code from Settings.
3. **How reviewing works** then walks you through this guide once, one step
   per screen. Skip it whenever you like, and read it again any time from
   **How reviewing works** in Settings.
4. Under **Languages you review**, pick your languages. At first these are the
   languages you speak that the app teaches.

You can turn reviewing off whenever you like. Your code is kept.

## What "To review" shows

- Units on the learning path are marked **To review** when their deck is not
  yet signed off by a native speaker, in your languages.
- **Waiting for review** in Settings lists, per language, the units and decks
  still waiting, how many cards are left in each, the offensive words not yet
  rated, the sound-alike pairs not yet confirmed, and what you have reviewed
  but not sent.

## Check cards, then sign off

Open a unit and tap **Review**. Mark each card that is right (**Looks right**).

When every card is checked, **Sign off** becomes available. It says you
checked the whole unit.

## Suggest, and answer proposals

- **Suggest a change.** If something is wrong, tap the card, choose **Suggest
  a change**, pick the part (word, reading, IPA, meaning, notes), write your
  version and say why. A card keeps one suggestion of yours per part.
- **Others' proposals.** Suggestions from other reviewers of your language show
  on the card with **Accept**, **Edit** and **Reject**. Accept it as written,
  Edit it into your own proposal, or Reject it. A rejection does not stop a
  change by itself; it tells the Fluenough team.

## Offensive words and sound-alikes

- **Offensive words (18+).** These are never in a unit's ordinary review.
  Each language has its own **Offensive words** review, under Waiting for
  review, which you open only if you choose to. Before showing any word it
  explains why they are in the app: some are deeply offensive, some mild,
  some fine between friends; learners should understand abuse, not use it
  without knowing; and a word's strength differs across languages and
  cultures. Then it asks if you are 18 or over, each time. Rate how
  offensive a word is to native speakers in general, from 1 to 9, not how
  it feels to you, and say where you speak the language.
- **Sound-alike checks.** A word may sound or look like a rude one. These
  pairs are checked in the same Offensive words review: confirm or reject
  each, and for a confirmed pair write a short care note (at most 40
  letters) that learners will see.

## Send several decks in one mail

Reviews stay on your phone until you send them. You can review several decks and
send them **together in one mail**: tap **Send review**, leave the decks you want
ticked, and your mail app opens with Fluenough's address and one file per deck
ready. Read the mail and send it yourself.

- **Do not change the mail's subject or the files.** The files carry your code,
  language and deck, and the team reads those. Please send without editing them.
- **Send from the same mail address each time.** Your first mail ties your code
  to that address. A later mail from another address is flagged for the team to
  check. If you change address, say so in the mail.
- The phone cannot tell whether you pressed send. If the mail did not go, use
  **Send the last mail again** in Settings.

## What is public, what is private

Public:

- your rater code;
- the languages you reviewed (the public issue list shows code and languages);
- your suggestions in the decks, which are public, with your code.

Private: your **mail address**. It is never written to the public issues.

## How changes reach learners

- Your suggestions are put into the decks as proposed changes soon after your
  mail arrives, for other reviewers of the language to see. Learners never see
  a proposal.
- When enough **other** reviewers accept a change exactly as written, it goes
  to learners, usually within an hour or two of the agreeing mail (after the
  automatic checks pass). The number is
  `REVIEW_AGREEMENTS_NEEDED`, set by the owner, and is 1 by default: one other
  reviewer is enough. It may be raised later.
- If several proposals concern the same part of a card, the first to be agreed
  wins and the others are closed.
- The owner can undo any change.
- This runs only once the owner has set up the review bot; until then your
  reviews are filed for the owner to read ([setup](review-bot-setup.md)).

## Thank you

When a deck you checked is updated, it lists your code, and a unit
says "Checked by <your code> and N others". Settings lists **Decks you helped build**.

## Help

Write to fluenough@gmail.com. Send the mail from the address you review with.
