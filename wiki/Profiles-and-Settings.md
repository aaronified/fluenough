# Profiles and settings

## Profiles

Profiles let several people use one phone, each with their own languages and progress. A PIN can lock one. Profiles stay on the phone, and nothing is uploaded. They are not switched on yet: the screens are built and shown as "Feature incoming", and they come in 0.6.0 ([#204](https://github.com/aaronified/fluenough/issues/204), [Plan: Profiles](Plan-Profiles)). For now the phone has one learner. A PIN cannot be recovered, because nothing leaves the phone.

## The Settings tab

Settings is a list of pages.

| Page | What it holds |
|---|---|
| Your languages | Languages, one list for the languages you know and the ones you learn (see below). Switches for Latin-letter readings, IPA and Adult content. Which language to learn a course from, where a course has more than one. Sources. |
| Activities and memory | Switches for Written words, Heard words, Spoken words and Reading, and for playing words automatically. Pause hearing or speaking for an hour, or turn them off per language. Speech rate and Voices. Adjust to me and Adjust automatically fit your reviews to how you remember. |
| Look and language | Theme, pure black, colour, contrast, card text size and the app language. |
| Reviewing | Reviewer mode for speakers who check decks. See the [Reviewing guide](Reviewing-Guide). |
| Your decks | Upload a deck file, get a template, send a deck to the project, remove a deck you added. |
| Reminders | One reminder a day, only on days with cards due. See [The daily reminder](#the-daily-reminder). |
| Your data | Backup and restore, the review log. See [Backup and restore](Backup-and-Restore). |
| App log | What the app did, kept 7 days. See [Reporting a problem](Reporting-a-Problem). |
| Updates | Check for a new app version, check automatically (off until you switch it on), and release notes. |
| Profiles and privacy | See above. The profile card at the top of Settings opens it. |

## The daily reminder

Settings > Reminders has one switch, off until you turn it on, and a time (7:30 PM at first). When it is on, the phone shows one notification a day at that time, on days that have cards due. It says only how many ("12 cards are due for review"): no word, no language, as it shows on the lock screen. It counts every language you learn. Tapping it opens Today.

- **Permission.** Android 13 and later ask to allow notifications when you switch the reminder on, never when the app starts. If you refuse, the switch stays off and a message says how to allow notifications in the phone's settings, with a button that opens them. If you take the permission back later, the reminder is switched off the next time you open the app.
- **What counts as due.** The cards due by the end of each of the next seven days, in every language you learn and every skill that is on, not set aside as leeches. A day with nothing due gets no reminder. A time that has passed today is skipped.
- **Inexact.** The reminder is scheduled inexactly, so it may arrive a little after the time, and the app needs no exact-alarm permission. It never fires while the app is open: today's reminder waits while you are in the app, and comes back when you leave it.
- **When it is planned again.** When you switch it on, off or change the time, when the app opens and when it is left, so it follows what you answered. After a reboot the phone puts back what was scheduled. If you change time zone while the app is closed, the reminder keeps its old moment until you next open the app.
- **Where it works.** On Android. In the web version the switch is shown and cannot be changed.

## Look and language

- **Theme:** System, Light or Dark. System follows your phone's dark theme.
- **Pure black:** dark mode uses black backgrounds instead of dark grey.
- **Colour:** Forest, Ocean, Clay or Iris. A wallpaper-colours switch is shown as "Feature incoming".
- **Contrast:** Standard or High.
- **Card text size:** makes card text larger, for scripts with small marks, like matras and dots. Menus follow your phone's font size. The app goes up to 1.4 times the normal size, and no further ([#505](https://github.com/aaronified/fluenough/issues/505)). If your phone is already at that size, cards cannot be made bigger.
- **App language:** the app's menus are in English only for now.

## Placed words

On the Languages page (below), a course with decks has a "Placed words" row under Find my level. It opens a sheet with the three choices: Set in stone, Spot-check (the default) and Keep reviewing. Tapping one applies it at once.

- **Set in stone:** the words placement found you know stay out of Today and count as known. You can still revise or practise them from the deck's page; those answers are not logged as reviews, and the deck shows the words as learnt.
- **Spot-check:** a few of them are tested each day, and a miss brings more of that deck back, then all of it.
- **Keep reviewing:** they are reviewed like any other word.

Switching away from Set in stone returns the placed words to reviews. Words you learn after placement are always reviewed as usual. The choice is kept for each course. A placement taken before this release has no saved placement time, so the choice does not apply to it.

## Readings, IPA and adult content

These three switches are on the Your languages page.

- **Latin-letter readings:** a reading under words in other scripts. See [Scripts and readings](Scripts-and-Readings).
- **IPA:** how each word is pronounced, under the word.
- **Adult content (18+):** off by default. Off, a deck of offensive words, and any rude card in another deck, is hidden everywhere: not listed, not taught, and not in Today, reviews or practice. On, they come back, so you know one when you hear it. It asks if you are 18 or over. A word that sounds almost like a rude word always carries a "Careful when speaking" warning. With Adult content off, the warning does not name the rude word. With it on, the word is named. Rude words are never said in a speaking test.

The app's menus are in English only. Translation is explained in the [Translation guide](Translation-Guide).

## Playing words

"Play words automatically" is under Activities and memory, beside Speech rate and Voices. A long press on a speaker button also turns it on or off. See [Speaking and listening](Speaking-and-Listening).

## Privacy

Your learning stays on the phone. The app goes online only to download decks, to check for updates, and to send a report you choose to send. The daily deck check can be turned off, with the switch at the top of the Languages page.

The app contacts `raw.githubusercontent.com` for decks and `api.github.com` for updates. After a speaking drill fails for want of a network, it also contacts `connectivitycheck.gstatic.com` (and `raw.githubusercontent.com`) once, to tell you why. That is the only time it contacts `connectivitycheck.gstatic.com`; it sends only your IP address and the time, and no data of yours.

## Updates

Settings > Updates checks GitHub for a new app version when you tap Check for updates. "Check automatically" is off until you switch it on. Then it checks once a day, when the app opens. A backup is made as it downloads. Then Android asks you to install it. If Android says Fluenough is not allowed to install apps, open Settings, Apps, Special app access, Install unknown apps, and allow Fluenough.

See also: [Learner guide](Learner-Guide), [Home](Home).

## Languages (Settings > Your languages > Languages)

One page for the languages you know and the ones you are learning (owner, 2026-10-30, #907). Each language has four skills: **Speak** and **Hear**, which belong to the one dialect the app teaches (named above Speak, such as Khari Boli for Hindustani), and **Read** and **Write**, which belong to a script: a language written in two scripts has a Read and a Write for each (Eastern Nagari for Bengali, Devanagari and Perso-Arabic for Hindustani).

Each skill is one pill. Tap it to cycle **Leave**, **Know**, **Learn**:

- **Know** is instant: no download and no test. You say what you know.
- **Learn** downloads the language's full decks (a dialog names the size first). One Learn skill, in any script, is enough. A skill changed to Learn leaves the sheet's bottom button reading **Check**: Speak and Hear play a sample in the language's voice, Read and Write check that the phone draws the script. If a check fails the skill stays Learn, a toast says what to install, and Check stays for another try.
- **Leave** is out. A language with every skill on Leave goes back to the pool: it leaves the list (with Undo) and Add a language finds it again. Decks nothing needs are removed the next time the app opens. **Delete data now**, the bin on the sheet, removes the decks at once.

The list shows each language's skills as read-only icon chips (a tick for Know, a double tick once the language's level covers it, a cap for Learn, a dashed minus for Leave), Learning first, then Know, with filter pills (Learning, Know, Speak, Hear, Read, Write) in a row that scrolls sideways. Tapping a language opens its sheet: the pills, Find my level (Fit my level once a level is found) and Placed words, and for a language with a Learn skill the **minutes a day** stepper (5 to 60 in steps of 5, 15 until you choose). Reading and writing a script you already know from another language start as Know when you add a new language that uses it. At the top of the sheet are the update check for that language's decks, the **i** panel (course size, decks on this phone, the last update check, units built, words) and the cross.

For a learner signed up to review (Review decks in Settings), a Know skill whose level has not been found says "Fit your level to be able to review". Review decks for known scripts are not built yet.

**English is fixed, and the Latin script is known** (owner, 2026-10-30, #926; 2026-10-31). English is Know in Speak, Hear, Read and Write with the level found (the double tick), for every learner: a new install after setup, and an existing one at the next app open (it is added after your own languages). It is locked: its pills cannot be changed, a line on its sheet says so, and it is never tested, downloaded or offered to learn. The Latin script is known by everyone who knows English, so Read and Write of the Latin script are Know in any language written in it, Spanish included; only Speak and Hear are Learn there. A Learn of the Latin script saved before this became Know once, at the next app open; you can still set Learn on it by hand afterwards.

What it keeps: the skills are stored per language in Settings (`language_skills`), and kept in step with the older lists (languages learned, scripts learned, languages spoken, scripts read) that the rest of the app reads. Until you edit a language, its skills are read from those lists, so a current learner sees no change.
