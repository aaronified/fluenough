# Plan: settings that say what they do, on and off

Written 2026-10-06. **Part of the settings redesign,** with
`language-picker.md`, `settings-wording.md` and `voices-per-language.md`:
last in the owner's order, after the skill model (done), `b1-plans.md` and
deck downloads (`decks-from-github.md`).

## What the owner asked

> There are other settings options which are not very intuitive. All
> settings options should be intuitive and change as per the toggle status.

## What exists

- Settings has about 25 rows. Each switch has a title and one fixed line
  under it, the same whether it is on or off.
- Some lines describe a requirement or a source, not what the switch does:
  - Listening: "Needs a voice for the language";
  - Grammar: "From pattern-table decks".
- Some read as one state only:
  - Sound: "Off, nothing is spoken and listening is skipped" stays while it
    is on.
- Some titles use jargon: "Show romanisation".
- A few rows already follow the state:
  - a skill's Languages row ("On for every language", "Off for Telugu");
  - the alphabet row;
  - the update check;
  - the reminder time.

## The rule

1. **A switch's line says what happens now**, in its current state, and
   changes the moment it is flipped. Off, it says what is skipped or missing
   and, where something is asked for on switching on (the microphone), says
   so.
2. **A title names the thing in plain words**, not the mechanism.
3. **A row that opens a page shows its current value** as its line.

## Proposed wording, to approve

| Setting | On | Off |
|---|---|---|
| Recognition | See the word, recall its meaning | No see-the-word questions |
| Production | See the meaning, type the word | No typed answers |
| Listening | Hear the word, type what you heard | No listening questions |
| Speaking | Say the word, your phone listens | No speaking questions. Switching on asks for the microphone |
| Grammar | Type the right form of a word | No grammar questions |
| Reading | Read a short passage, answer questions | No passages |
| Phonemic contrasts | Practise the sounds the languages you speak don't have | No practice with sounds your languages lack |
| Show romanisation → **Latin-letter readings** | A Latin-letter reading under words in other scripts | Only the script, no reading |
| Sound | Words are spoken; listening questions are asked | Nothing is spoken; listening questions are skipped |
| Play words automatically | Words play by themselves, as a card shows or once you answer | Words play only when you tap the speaker |
| Daily reminder | A reminder at {time} on days with cards due | No reminders |
| PIN lock | This profile asks for its PIN when it opens | This profile opens without a PIN |
| Check automatically | Checks GitHub once a day, when the app opens | Only when you tap Check for updates |
| Pure black | Dark mode uses black backgrounds | Dark mode uses dark grey backgrounds |
| Wallpaper colours | Colours follow your wallpaper | Fluenough's own colours |
| A skill, by language | Asked in {language} | Not asked in {language} |
| An alphabet, by language | Learning the {script} script | Latin letters only; script decks skipped |

The skill rows change with the skill model, which is done (ADR-0034): one
switch per activity, and Listening becomes "Hear the word, give its meaning".

Lines that depend on the phone stay, added after the state: Listening with
no voice reads "No voice for {language} on this phone".

## What it takes

1. ARB strings in pairs (`…On`, `…Off`), with descriptions for translators.
2. `GroupedTile.toggle` gets its line from the switch's value: a
   `subtitleOn`/`subtitleOff` pair, or the caller passing the line for the
   value.
3. Every switch in Settings, Appearance, the per-language pages and Updates
   moves to it.
4. **Tests:** for each switch, its line before and after one tap. A test
   that no switch in Settings keeps the same line in both states, so a new
   switch cannot skip the rule.

## To decide

- The wording above, row by row.
- Whether "Show romanisation" is renamed.

## Estimate

About 3–4 hours. Confidence: medium.
