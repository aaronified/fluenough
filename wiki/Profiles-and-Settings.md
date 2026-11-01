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
- **IPA replaces transliteration:** a second switch, under IPA, off by default. With it on, a word that has an IPA shows it in the place of its transliteration (readings are based on ISO 15919), and the small IPA line goes; a word with no IPA keeps its transliteration. It only applies while IPA is on: with IPA off the row is greyed out and says so. It applies on the word sheet, the deck's word list, the recognition, choice, picture and pair drills, reading passages and example sentences; the teach card keeps its IPA button and does not repeat the IPA. The grammar drill's tables still show their IPA line as before. Typed answers still take the transliteration (#697).
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

One page for the languages you know and the ones you are learning (owner, 2026-10-30, #907). Each language has four skills: **Speak** and **Hear**, which belong to the one dialect the app teaches (named above Speak, such as Khari Boli for Hindustani), and **Read** and **Write**, which belong to a script: a language written in two scripts has a Read and a Write for each (Eastern Nagari for Bengali, Devanagari and Perso-Arabic for Hindustani). A language with no script has no Read or Write. A **sign language** (Indian and American Sign Language) has one skill, **Gestures**, in place of all four, with its own icon (a raised hand): it covers recognising a sign and making one, with one Know, Learn or Leave for both (owner, 2026-11-01: "It is one skill, tested both ways. One cannot write a script without being able to read it."). Its one pill cycles Leave, Know, Learn. Its drills wait for the sign deck format (#579), so it can be set to Know now and Learn is offered when a course exists. An answer saved as `ks:arabic` or `sd:arabic` is read as Kashmiri's or Sindhi's Perso-Arabic one.

**One pill for speaking, one pill for each script** (owner, 2026-11-01: "Scripts can actually have one pill, and cycle through read and write as levels of know." and "Same for other skills, if you can speak, you can hear as well."). Speak and Hear are one **Spoken** pill, and a script's Read and Write are one pill. Tap a pill to cycle:

- **Spoken:** Leave, Learn, **Hear**, **Hear and Speak**, Leave.
- **A script:** Leave, Learn, **Read**, **Read and Write**, Leave.

Hear and Hear and Speak are the two levels of **Know** (you cannot speak a language you cannot hear), and Read and Read and Write the two levels of Know for a script (you cannot write a script you cannot read). **The pills are icons only, with no word** (owner, 2026-11-01: "Icons only. Toast explains"), coloured by level and not by skill (owner, 2026-11-01: "The leave icon can be red, the learning and known be yellow, and the learnt can be dark green."): **Leave** is the block icon on red, **Learn** the cap inside a ring on pale yellow, **Know** a single small tick in an outlined circle on a stronger yellow, and **Learnt**, a Know level found by the placement test, a bold double tick on a filled capsule on dark green, so one tick and two ticks are never alike in shape or size, not by colour alone. A combined pill shows only the icons of the levels reached: Spoken is the ear (Hear) or the ear and the microphone (Hear and Speak), a script's pill the eye (Read) or the eye and the keyboard (Read and Write), and Learn shows the cap alone. A single skill shows its own icon (eye, keyboard, microphone, ear, raised hand for Gestures) and the mark. A touch and hold on a pill names it in a word or two (Not learning, Learning, Listening, Listening and speaking, Reading, Reading and writing, each with ", checked" for Learnt; a single skill says Reading, Writing, Speaking, Listening or Signing, and Learning to read, write, speak, listen or sign), and a screen reader reads the row's name and that. The colours are the theme's named tokens (`pillLeave`, `pillLearn`, `pillKnow`, `pillVerified` in `ModeColors`), light, dark and high contrast, each 4.5:1 or better under its icons. Where a language has no course, Learn is skipped.

- **Know** is instant: no download and no test. You say what you know.
- **Learn** downloads the language's full decks (a dialog names the size first). One Learn skill, in any script, is enough. A skill changed to Learn leaves the sheet's bottom button reading **Check**: the Spoken pill plays a sample in the language's voice, a script's pill checks that the phone draws the script. If a check fails the skill stays Learn, a toast says what to install, and Check stays for another try.
- **Toasts say it in plain words** (owner, 2026-11-01: "make the toasts sound natural, do not depend on our invented skill names"). A changed pill toasts a sentence, never the level names: "Hindustani: you’re learning speaking and listening", "you already know reading and writing Devanagari" or "not learning sign language now". The skill is named as speaking and listening (listening alone at Hear), reading and writing a script (reading alone at Read), or sign language. Removing a language says "removed" and points to Add a language.
- **Leave** is out. A language with every skill on Leave goes back to the pool: it leaves the list (with Undo) and Add a language finds it again. Decks nothing needs are removed the next time the app opens. **Delete data now**, the bin on the sheet, removes the decks at once.

The list shows each language's skills as read-only icon chips (the same pills as the sheet's, smaller: yellow with a single tick for Know, dark green with a double tick once the language's level covers it, the cap in a ring for Learn, the red block icon for Leave). On the list only, a Learn chip also shows its skills' icons beside the cap (ear and microphone for Spoken, eye and keyboard for a script) and every script chip starts with the script's own letter (अ for Devanagari, ا for Perso-Arabic, A for Latin), so a language in two scripts shows two chips told apart (owner, 2026-11-02); the sheet's pills are unchanged, Learning first, then Know, with filter pills (Learning, Know, Speak, Hear, Read, Write, and Gestures while a sign language is listed) in a row that scrolls sideways (Speak keeps the languages at Hear and Speak or Learn, Hear any Spoken level, Read any script level, Write Read and Write or Learn). Tapping a language opens its sheet: the pills, Find my level (Fit my level once a level is found) and Placed words, and for a language with a Learn skill the **minutes a day** stepper (5 to 60 in steps of 5, 15 until you choose). Reading and writing a script you already know from another language start as Know when you add a new language that uses it. At the top of the sheet are the update check for that language's decks, the **i** panel (a family tag such as Romance, Indo-Aryan or Dravidian beside the course badge, course size, decks on this phone, the last update check, units built, words) and the cross. The family tag is the same flat family Add a language groups by (owner, 2026-10-31, #698); a language with no family shows no tag.

For a learner signed up to review (Review decks in Settings), a Know skill whose level has not been found says "Fit your level to be able to review". Review decks for known scripts are not built yet.

**English is fixed, and the Latin script is known** (owner, 2026-10-30, #926; 2026-10-31). English is Know in Speak, Hear, Read and Write with the level found (the double tick), for every learner: a new install after setup, and an existing one at the next app open (it is added after your own languages). It is locked: its pills cannot be changed, a line on its sheet says so, and it is never tested, downloaded or offered to learn. The Latin script is known by everyone who knows English, so Read and Write of the Latin script are Know in any language written in it, Spanish included; only Speak and Hear are Learn there. A Learn of the Latin script saved before this became Know once, at the next app open; you can still set Learn on it by hand afterwards.

What it keeps: the skills are stored per language in Settings (`language_skills`) as the same four skills as before (`speak`, `hear`, `read:<script>`, `write:<script>`), so backups and older data are unchanged; the pills only derive a level from them. Learn is either skill Learn (a tap writes both); Hear is Hear Know and Speak Leave; Hear and Speak is Speak Know (Hear is written Know too); Read is Read Know and Write Leave; Read and Write is Write Know (Read is written Know too). A stored Speak Know with Hear Leave, or Write Know with Read Leave, shows as the higher level. The skills are kept in step with the older lists (languages learned, scripts learned, languages spoken, scripts read) that the rest of the app reads. Until you edit a language, its skills are read from those lists, so a current learner sees no change.


**The first launch asks the same question** (owner, 2026-11-01: "During onboarding, show the language screen and explain the options, and then let the users choose what they know and what they want to learn."). After the sound check an explanation screen says in plain words what Learn, Know and Not learning mean and what the icons and the double tick say. The next screen is the Languages page's own list (Learning and Know sections, English already known and fixed) with Add a language, which uses the same search and families as Add a language on the Languages page; a pick asks the Know sheet first where a language is written in more than one script or in a script of its own (not for Latin letters alone, a sign language or a script-only course), and its answers fill in the skills sheet that follows, the same sheet as on the Languages page, in draft mode ("Add Hindustani"). Left unanswered, the Know sheet goes on to an empty skills sheet, so a learner who knows nothing of the language still gets there. Next waits for one language besides English. Nothing reaches Settings before the last button: the answers are then saved as skills (`language_skills`) and the older lists follow (`applySkills`), so the review-languages, fact-languages and script-offers screens read the right lists, and an old backup or older lists still read as skills. A language set to Learn starts its download, and the Languages to learn step, which the first launch otherwise ends with, is skipped when something is set to Learn.

**The Know sheet** writes its question and every answer in the language's own script, marked with its language for a screen reader; the English translation is under the question only, never under an answer, and "I can only speak X" is English only (owner, 2026-11-01). An answer in a script other than the language's first is drawn and marked by its own script: Hindustani's Perso-Arabic answer is written in Perso-Arabic script (a draft by us, flagged by the bug icon as unchecked until an Urdu speaker verifies it), drawn right to left and marked Urdu (`SpokenLanguage.isRtlText`, `localeCodeFor`). It is drawn in the Perso-Arabic font the course downloaded, as the cards are (`font_check.dart`, `scriptSamples`, Nastaliq), else in the phone's own; whether to use Naskh instead of Nastaliq for a short line of interface text is an open font decision.