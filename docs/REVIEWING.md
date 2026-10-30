# Reviewing Fluenough decks

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

<!-- This guide is also the app's reviewer onboarding, "How reviewing works"
(lib/features/review/how_reviewing_works.dart, strings reviewGuide* in
lib/l10n/app_en.arb). Each `## ` section but Help is one step there, in this
order; change a fact here and change it there too.
test/features/review/how_reviewing_works_test.dart checks the headings. -->

Thank you for considering this. You do not need to know anything about
programming. You need an Android phone with the Fluenough app and a mail app,
and for each course you review, such as Bengali from English, you must know
both languages well, the one taught and the one it is taught from, and read
both their scripts.

## What reviewing is

Fluenough teaches languages from decks of cards: a word, how it is read, what
it means, examples. Many decks were written without a native speaker and are
marked "unreviewed" in the app. You are the check. You tell us which cards are
right, which are wrong and what they should say, and how rude a word really
sounds to native speakers. A review by a native speaker is the most useful
thing anyone can give these decks.

## The rules

1. **Be bilingual.** Review a course only if you know both its languages, the
   one taught and the one it is taught from, and read both scripts.
2. **The meaning never changes.** You may say a card better: a more common
   word, another register, a correct spelling. You may not make it say
   something else: "Good morning" never becomes "goodbye". If the card is in
   the wrong place, move it (rule 4) or say so in Why; do not rewrite it.
3. **Review the content and the logic.** That is each card's word, reading,
   IPA, meaning, notes, example and base words, and also whether a card
   belongs in its unit, whether the units come in a sensible order, and
   whether a grammar note is right.
4. **Suggest where a card belongs.** Under **Place** in Suggest a change, move
   it to another unit or theme the course's B1 plan already has.
5. **New themes go by pull request.** A theme, or a unit the plan does not
   have, is added to the deck on GitHub, not in the app.

## Your code and languages

1. Open **Settings**, find the **Reviewing** group and turn on **Review decks**.
2. The app asks first, then makes your **rater code** on your phone, like
   `FL-XXXX-XXXX-C`. Nothing is sent when you turn reviewing on. You can copy
   the code from Settings.
3. **How reviewing works** then walks you through this guide once, one step
   per screen. Skip it whenever you like, and read it again any time from
   **How reviewing works** in Settings.
4. Under **Languages you review**, tick the courses you review, such as
   *Bengali from English*. Every course the app offers is listed, downloaded
   or not. You can tick a course only if you know both languages and read
   both scripts; the others are greyed, with the reason. Say which languages
   you know, and whether you read each one's script, in **Languages you
   know** (the button on the same screen opens it). Until you have said which
   scripts you read, no course can be ticked.
5. A course whose decks are not on your phone asks to download them. They are
   for reviewing only: the language is not added to the languages you learn,
   and stays out of Today, the language bar and your lessons. Each course on
   your phone shows its size, whether an update is waiting, **Update** and
   **Remove**.

You can turn reviewing off whenever you like. Your code is kept.

## What "To review" shows

- Units on the learning path are marked **To review** when their deck is not
  yet signed off by a native speaker, in your languages.
- **Waiting for review** in Settings has three parts. **Reviewed, not sent**
  opens your cards and suggestions, by deck. **Reviewed and sent** opens each
  suggestion's state: Accepted, Rejected or Waiting for a second review, with
  a count such as "1 more acceptance needed" and never a rater code. Then each
  language you review, folded until you tap it, with the decks and cards left
  to check in its header; unfolded, it lists the units and decks still
  waiting, the offensive words not yet rated and the sound-alike pairs not yet
  confirmed. What you unfold is remembered.

## Check cards, then sign off

Open a unit and tap **Review**. Mark each card that is right (**Looks right**).

Where a base word changes its stem in the card's form, such as Telugu రావడం
(rāvaḍam), "to come", in వచ్చింది (vaccindi), "she came", the notes should
say so. If they don't, suggest a change to the notes.

When every card is checked, **Sign off** becomes available. It says you
checked the whole unit.

## Suggest, and answer proposals

- **Suggest a change.** If something is wrong, tap the card, choose **Suggest
  a change**, tap the pencil on a part (word, reading, IPA, meaning, notes),
  write your version and say why. Edit as many parts as you like, then tap
  the tick to save them all. A card keeps one suggestion of yours per part.
- **Base words.** Each base word has its own box. Its pencil changes the
  base's form, reading and meaning; its delete button removes it, with
  **Undo** until you tap the tick. **Add a base** adds one for a word of the
  card that has none. When the base's form is the word of another card,
  you can link that card instead. Each base change has its own why.
- **A new word.** You may replace a card's word with a better or more common
  one. The card keeps its id and its meaning, so learners keep their
  progress. The sheet then lists what hung on the old word: **Replace the
  bases** removes the old bases and opens one for the new word, the old
  word stays an accepted answer unless you untick it, and the notes and
  example are marked **Check**. All of it is sent as one review, and goes
  into the deck together once the new word is agreed.
- **Where a card belongs.** **Place** is the last box of the sheet: the
  card's unit, as the course's B1 plan lists it. Its pencil opens **Move this
  card**, which offers the units of that plan with a deck, and nothing else:
  it is never free text, and a unit the plan has but no deck is written for
  is greyed, "Planned: no deck yet". Pick the unit and say why. A theme or
  unit the plan does not have is a pull request on GitHub, not a move. If
  agreed, the card goes to the other unit with its id kept, so learners keep
  their progress.
- **The meaning.** Editing the Meaning shows rule 2 above the field.
- **Every field.** The sheet shows every field the card carries, in groups:
  the word (reading, IPA, narrow IPA, gender, register, frequency), meaning
  and other senses, examples, base words, related words (synonyms, antonyms,
  confusables with why, minimal pairs, forms, collocations), notes and the
  teach-card warning, picture, image and recording, facts, the dictionary
  entry and the set card, and place. A list field has a pencil on each item
  and **Add** at the end; a field with no data says "not set" and offers
  **Flag as missing**. Each item has **Looks right**, a count of what is
  left to check beside the field's name, and a checked item moves below the
  rest. Items from Wiktionary are marked semi-verified and come after the
  others, so you see what Claude wrote first. The narrow IPA and the
  frequency are written by tools, so you can only flag them; a recording,
  an image and the set card can only be flagged too, and a flagged
  recording is dropped for text-to-speech.
- **The teach-card warning.** The teach card has room for one warning. Its
  pencil opens a list of the warnings the card has (a sound-alike,
  spelling-alike or look-alike note, other meanings, or no warning) and
  nothing else: there is no "automatic" choice, and a pick is never taken
  back by the bot. Say why.
- **What the bot applies** (owner, 2026-10-30, #508: "Scalars + warning").
  A change to the gender, the register, the `hears` mark or the teach-card
  warning is proposed like a reading, shown to other reviewers with
  **Accept**, **Edit** and **Reject**, and written into the deck once enough
  of them accept it, but only with a value the field may have: a gender is
  one of the language's classes, a register is formal, neutral, informal,
  slang or offensive, `hears` is only `form`, and a warning is one of the
  card's own (a sound-alike, spelling-alike or look-alike note, other
  meanings, or no warning). Any other text is left for the owner. The items
  of a list, the facts and a flag are always the owner's to read: the bot
  does not write them.
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

## Daily questions

Besides whole decks, you can answer a few short questions a day. The app
writes them from the cards, about the data nobody has checked yet: is this
the right meaning of a word, is this example natural, is this a real
confusable, is this recording correct and by a native speaker. Data written
without a source comes before data taken from Wiktionary or Tatoeba.

- **Yes or No.** A No asks why, with a few fixed reasons and an optional
  line. The line goes in the mail for people to read and nowhere else.
- **Recordings.** There is no recording option yet. A recording can only be
  flagged when it is bad, and the card then uses text-to-speech.
- **How many a day** is yours to choose, in this guide's step and later in
  Settings under **Reviewing**, **Questions a day**. The default is 10. What
  you do not answer waits for the next day.
- **Sending.** Answers wait on your phone until you send them, and they go in
  **the same mail as your reviews that wait** (owner, 2026-10-30: "Send all
  pending review in that same mail"). Tap **Send answers** here, or **Send
  review** in Settings under **Reviewing**: either way one mail opens in your
  mail app with Fluenough's address, a file for each deck and a file for each
  language of answers. The subject is the review mail's,
  `[Fluenough review] CODE (languages)`. Do not change the files.
- **Settled by two.** A data point is settled right when two reviewers
  answer Yes: the other reviewers needed plus the first
  (`REVIEW_AGREEMENTS_NEEDED`, 1 by default, so two). The point is then
  recorded on the card as `verified` and the app stops asking about it (the
  bot writes that only once a released app reads the field; until then it
  only tallies the answers in `review-answers/` in the repository, as rater
  codes and answers only).
- **A No opens a pull request; the next answer decides it** (owner,
  2026-10-30: "1st review opens PR. Second review either merges or closes
  it."). The first reviewer to answer No, or to flag a recording, makes the
  review bot open a pull request for that data point, and it stays open. The
  next reviewer's answer decides: the same No (or flag) merges it, and a Yes
  closes it for good; a disagreement is not sent to a third reviewer. A
  flagged recording that is merged is taken off the card, which then uses
  text-to-speech. For any other point the answer carries no replacement text,
  and the proposals of a review change a field only to a new text, so the
  pull request is a flag note: merging it only records that two reviewers
  agree the point is wrong, and the owner changes the card.
- **Open questions** that ask you for something new, such as a regional
  variation, come in a later version.

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
