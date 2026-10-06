# ADR-0032: A word in match pairs says itself when tapped, by a switch of its own that is on by default

- **Status:** Accepted. Amends [ADR-0026](0026-sound-on-every-card.md), which
  left match pairs without a speaker, its word tiles speaking only while Play
  words automatically was on. The rest of ADR-0026 stands.
- **Date:** 2026-10-06

## Context

ADR-0026 gave every card a speaker but one: "Match pairs has no speaker. Its
words are tiles, not one card's word." A tile tapped said its word only while
Play words automatically was on, which it is not for a new learner, so a match
was silent. It left the question with the owner, who answered: "sound is
needed for the match pairs. there are lots of minimal pairs and script/ISO
are not enough for early learners."

Asked how, they chose "a single button to enable tap to hear". Asked its
default and scope, they chose **on by default**, and **its own setting**,
remembered between sessions: not Play words automatically, and not per
session.

## Decision

- **A setting of its own**, `SettingsNotifier.matchTapToHear`, stored as
  `match_tap_to_hear` like the other switches, **on by default**. Settings
  stored before it existed read as on. It is independent of Play words
  automatically: neither changes the other.
- **One speaker button** on the match-pairs card, at the end of the prompt's
  line, switches it. Its icon is a speaker with waves while on and a crossed
  speaker while off, drawn as `SpeakerIcon` is, on a tonal circle while on.
  It is 48 dp square, has a tooltip, and tells screen readers what it does
  and its state ("Hear words when tapped, on"), and says the new state as it
  changes.
- **While it is on**, tapping a word tile, the language learned, says its
  word through `DrillSession.playCard`, whatever Play words automatically
  says. While it is off, a word tile says nothing. A meaning tile never
  speaks, and dragging a word does not.
- **Sound in Settings still wins.** With it off nothing plays, the button is
  greyed out and crossed out, and a tap on it says sound is off for the whole
  app, as a speaker's does, and changes nothing. Where the phone has no voice
  for the language there is no button, as there is no speaker.

## Consequences

- A new learner now hears a word each time they tap one in a match, which is
  what the owner asked for. A learner who liked matches silent has to switch
  the button off once, and it stays off.
- The setting has no row in Settings > Sound: the button is its only switch.
- Taps on a word tile are not counted toward ADR-0026's tip about
  long-pressing a speaker; the button has no long press.
- Hearing a word in a match gives nothing away: the meanings are already on
  the screen beside it.
- The note in ADR-0026 that a match is silent with Play words automatically
  off is out of date; this ADR is where to look.

## Alternatives considered

- **Play words automatically for match pairs, as before**: off for a new
  learner, which left a match silent. The owner chose a setting of its own.
- **Off by default**: a learner would have to find a button to hear anything.
  The owner chose on.
- **Per session**: the choice would be asked again at every match. The owner
  chose to remember it.
- **A speaker on each tile**: the owner asked for a single button.
