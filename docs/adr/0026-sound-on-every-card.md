# ADR-0026: Every card has a speaker, words can play by themselves, and sound can be switched off

- **Status:** Accepted
- **Date:** 2026-10-04

## Context

Sound played only on listening cards, the teach card and passages. The
owner asked: "add optional sound in every card. User may choose to hear
from all cards, even for review. This is something duolingo does as well."
Asked how it should work, they decided:

> The autoplay option will be in settings, and the button on the cards will
> also have a toggle, via long press. On clicking it, it will sometimes (once
> every 10th press) say that long pressing will enable autoplay. Thus it will
> show up for people who use it a lot. Global sound off will also grey this
> out, and clicking on it will show the toast that sound is off globally.

They also decided that autoplay is off for a new learner, and that while
sound is off, the questions that need it are skipped. Later they added: "When
volume is muted, the sound based questions will be greyed with a 'please
raise the volume' message (not toasts, on the cards). On the global sounds
off settings, a toast will say that sound based questions will be skipped
while sound remains off." They approved a package to read the volume.

## Decision

- **A speaker on every card**, reviews included. Tapping it plays the
  card's word in the language's voice. Where hearing the word would give
  the answer away, the speaker appears once the answer is in. That is when
  the word is typed, chosen or put in order, a grammar cell, or a word to
  be said. On a card that shows the word, it is there from the start.
  Without a voice for the language there is no speaker, as before.
- **Long-press toggles "Play words automatically"**, which is also in
  Settings > Sound, off by default. A message says which way it went. Every
  tenth tap, while it is off, a message says that a long press turns it on.
  With it on, a word plays when its speaker first appears.
- **Sound** is a switch in Settings > Sound, on by default. Off, nothing is
  spoken, every speaker is greyed, and tapping one says sound is off for
  the whole app. Lessons, reviews and Today's counts leave out the
  questions that need sound, as for a phone with no voice. Turning it off
  says so. The Voices page still shows what the phone has.
- **A phone at zero volume** with sound on in the app: a question that needs
  sound, a listening card or a minimal pair, is greyed out, and its card
  says "Please raise the volume". It is not skipped, and the card comes back
  as the volume rises. `flutter_volume_controller` (MIT) reads the media
  volume, the one speech plays at, behind a `VolumeMonitor` that tests
  fake.

## Consequences

- One more message a learner may see, at most once in ten taps.
- A learner who turns sound off and forgets sees no listening questions
  until they turn it back on. The greyed speakers are the reminder.
- Autoplay off by default means a new learner hears words only where a
  card plays them itself (the teach card) or when they tap.
- **Match pairs has no speaker.** Its words are tiles, not one card's word.
  A tile tapped says its word only while autoplay is on, so with autoplay
  off a match is silent. Whether it should get a speaker is the owner's to
  decide.
- A heard reading passage, like a heard word, is greyed and asks for the
  volume while the phone is at zero.
- One more dependency, a small plugin for Android and iOS. Where it is
  missing, as in widget tests, the volume reads as up.

## Alternatives considered

- **Autoplay on by default**, as Duolingo does: the owner chose off.
- **Greyed listening questions while sound is off**: they could not be
  answered. The owner chose to skip them.
- **A speaker on the prompt everywhere**: on a production card it would
  read out the answer.
- **Our own Android code for the volume**, patched into the generated
  project by `tools/brand_android.py`: no dependency, but more fragile. The
  owner chose the package.
- **A toast for a muted phone**: the owner asked for the message on the
  card.
