# Today and daily lessons

Today is the first tab. It shows what to do now.

## What you see

- **Your language bar.** Switch between the languages you learn, or see them all together.
- **The day's lesson**, for each language: new words, taught then practised, from easy to hard. For some courses it ends with a short passage to hear and read, with questions. When it is done, Today says the lesson is done. New words come only in lessons ([ADR-0024](ADR-0024-Daily-Lessons)).
- **Words due**, by skill: seen, written, heard, spoken and grammar. Each shows how many are due and about how many minutes they take. (Being changed, #1009 and PR #1011, not yet merged: a tile will show every card waiting in its skill, even beyond the day's time, and equal the cards a tap serves, counting only skills that can run now; the ring will show minutes for review and for new words, not card counts.) Tap one to start. A skill that needs sound shows that there is no voice on this phone if there is none.
- **Your streak**, and a week of dots showing which days you practised.
- **Quick revision.** Being removed (owner, 2026-11-04, #1010): see "Keep going" below.
- **Situations**: six buttons, each in a colour of its own (taxi, shops, eat, doctor, traffic, rail), under quick revision. A button opens a sheet of key phrases and words for that moment, all shown, with a dot on those you have not learnt yet; **Practise this sheet** teaches the new ones and revises the rest, and the info mark opens a card in full, one at a time, **swiped** from one to the next (numbered chips show where you are and jump to a card; there are no Previous and Next buttons, and Open in deck stays for now). Wherever a card shows its IPA (the word sheet, the teach card and the recognition, choice and picture drills) a small info dot beside it opens a popup with each sound of the IPA, an example, a speaker and Practise; the sounds are never a block under the card (owner, 2026-10-31). Sheets are lists of the decks' own cards, so progress is shared with the decks. Telugu has the taxi sheet first; a course without sheets shows the buttons dimmed with an Upcoming pill.
- **A fact of the day**: one short, true thing about a language you are learning. Facts follow the languages you said you know.
- **A fact of the day**: one short, true thing about a language you are learning. Facts follow the languages you said you know. A small button at the top left of the card (long press: Languages) opens a list of the languages you know, with a box each (owner, 2026-10-30, #926); the fact is shown in the checked ones, in your order. At least one stays checked, and a language the fact has no text in is left out; if nothing is left, the English text is shown. The choice is kept for each profile, and until you make one every language you know is shown. With only one language known there is nothing to choose, and the button is not shown.

## A lesson

A lesson teaches the next new items in your path's order: up to nine, fewer while words and rules you were taught are not yet known (last answer right, and 85% likely to be remembered), and at most three new forms of a rule's table. A sentence comes only once its words and rules are known ([ADR-0046](ADR-0046-Lessons-Take-The-Next-Eligible-Items)). A rule is shown once, on its own card, before you are asked about its forms. A word is shown on one screen with its reading and meaning, and you can hear it; swipe the card to go on. Then you are asked about it. A set of related words, such as days of the week, is shown together first, with a "Full list" button, then asked one at a time. Words you already know are skipped, and the lesson names them.

Your answers during a lesson are recorded. See [Drills and skills](Drills-and-Skills) for the kinds of question.

## The day's session

The day's button runs on a clock, not on a count of cards. The time is your minutes a day for the language (plus any "+ 5 min"), less what you have already spent today. The top of each screen shows a ticking countdown of the time left in place of "3/8". The clock stops while one screen has been showing for more than 30 seconds, so a phone left on a table does not use your time. The session ends when the time is up (after the card you are on) or when you end it.

It builds one round at a time, only when the last is done:

- **While reviews are due**, a round mixes reviews and new words, in a ratio set by the time left and what is due: many due reviews mean many reviews to each new word, and a few mean more new words. A backlog of more than three days of minutes means reviews only.
- **When nothing is due**, it teaches new words, as many as your path allows and the time holds, at most 15 in a session. Each is asked twice after it is taught, not straight away: older reviews are mixed in between. What time is left is filled with the cards closest to being due, never a card you have already answered today: an answer pushes a card at least a day away, and asking it again at once would teach nothing (#1008, merged 2026-11-04, in the next release).

A teach card is timed like an answer (at most a minute), counts toward the day's minutes and is included in the hours spent.

The day ends when no round can be built, and the clock then reads the full time. Today's ring is then full and greyed with "Done for today", and a tap on it opens the same summary, built from today's answers in the log, so it works after a restart too (#1008, merged 2026-11-04, in the next release). There is no blank end screen: the summary is the end screen.

## Keep going

After the day is done a smaller **Keep going** stays. Owner, 2026-11-04, #1010: "If user keeps going, let them review closest to due cards and teach them new cards. Change the ratio as needed to not teaching too much and not reviewing too far into the future." Not built yet. Keep going will serve a balanced mix of the cards closest to due (not cards already answered today, and not pulled further ahead than a couple of days) and new cards from the path, with a cap on new words so it cannot flood the learner, and it will prefer reviews while a backlog is large. The time it takes counts toward the day's minutes. It is built after #1009 (PR #1011).

## Reviews

A review is a word that has come back because it is due. Do your due words each day and they come back less often as you learn them. Words you miss return sooner.

When no reviews are due, Today says so. You can still learn new words in a lesson.

## Quick revision

**Being removed** (owner, 2026-11-04, #1010: Keep going stays, Quick revision goes). Until it is, Quick revision is for when nothing is due and you want more practice. Pick 5, 10, 15 or 20 words. They are words you have already been taught, picked at random, due or not. You can narrow it to all skills, the spoken ones (hearing and saying), or one skill. Every answer counts: a miss brings the word back sooner ([ADR-0029](ADR-0029-Quick-Revision), [ADR-0030](ADR-0030-Review-By-Skill)). It opens after your first lesson.

## At the end of a session

A summary shows how many cards you did, what the lesson unlocked (the words and rules that became known and the sentences that opened), how many you got right by skill, your streak and when the next cards are due. If you have another language to do today, it offers to start it.

You can end a session early. Answers so far are already saved.

See also: [Learner guide](Learner-Guide), [Home](Home).
