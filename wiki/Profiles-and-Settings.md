# Profiles and settings

## Profiles

Profiles let several people use one phone, each with their own languages and progress. A PIN can lock one. Profiles stay on the phone, and nothing is uploaded. They are not switched on yet: the screens are built and shown as "Feature incoming", and they come in 0.6.0 ([#204](https://github.com/aaronified/fluenough/issues/204), [Plan: Profiles](Plan-Profiles)). For now the phone has one learner. A PIN cannot be recovered, because nothing leaves the phone.

## The Settings tab

Settings is a list of pages.

| Page | What it holds |
|---|---|
| Your languages | Languages I know (they decide your facts and which decks you can review) and Languages I'm learning, where decks are checked for updates and updated. Switches for Latin-letter readings, IPA and Adult content. Which language to learn a course from, where a course has more than one. Sources. |
| Activities and memory | Switches for Written words, Heard words, Spoken words and Reading, and for playing words automatically. Pause hearing or speaking for an hour, or turn them off per language. Speech rate and Voices. Adjust to me and Adjust automatically fit your reviews to how you remember. |
| Look and language | Theme, pure black, colour, contrast, card text size and the app language. |
| Reviewing | Reviewer mode for speakers who check decks. See the [Reviewing guide](Reviewing-Guide). |
| Your decks | Upload a deck file, get a template, send a deck to the project, remove a deck you added. |
| Reminders | One reminder a day, only on days with cards due. Shown as "Feature incoming". |
| Your data | Backup and restore, the review log. See [Backup and restore](Backup-and-Restore). |
| App log | What the app did, kept 7 days. See [Reporting a problem](Reporting-a-Problem). |
| Updates | Check for a new app version, check automatically (off until you switch it on), and release notes. |
| Profiles and privacy | See above. The profile card at the top of Settings opens it. |

## Look and language

- **Theme:** System, Light or Dark. System follows your phone's dark theme.
- **Pure black:** dark mode uses black backgrounds instead of dark grey.
- **Colour:** Forest, Ocean, Clay or Iris. A wallpaper-colours switch is shown as "Feature incoming".
- **Contrast:** Standard or High.
- **Card text size:** makes card text larger, for scripts with small marks, like matras and dots. Menus follow your phone's font size. The app goes up to 1.4 times the normal size, and no further ([#505](https://github.com/aaronified/fluenough/issues/505)). If your phone is already at that size, cards cannot be made bigger.
- **App language:** the app's menus are in English only for now.

## Placed words

In Languages I'm learning, a course you have been placed in has a "Placed words" row under Find my level. It opens a sheet with the three choices: Set in stone, Spot-check (the default) and Keep reviewing. Tapping one applies it at once.

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

Your learning stays on the phone. The app goes online only to download decks, to check for updates, and to send a report you choose to send. The daily deck check can be turned off, on the Languages I'm learning page.

The app contacts `raw.githubusercontent.com` for decks and `api.github.com` for updates. After a speaking drill fails for want of a network, it also contacts `connectivitycheck.gstatic.com` (and `raw.githubusercontent.com`) once, to tell you why. That is the only time it contacts `connectivitycheck.gstatic.com`; it sends only your IP address and the time, and no data of yours.

## Updates

Settings > Updates checks GitHub for a new app version when you tap Check for updates. "Check automatically" is off until you switch it on. Then it checks once a day, when the app opens. A backup is made as it downloads. Then Android asks you to install it. If Android says Fluenough is not allowed to install apps, open Settings, Apps, Special app access, Install unknown apps, and allow Fluenough.

See also: [Learner guide](Learner-Guide), [Home](Home).
