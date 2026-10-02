# ADR-0014: Speaking is drilled through the phone's own speech recogniser

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

Fluenough drilled recognition, typing, listening and grammar, but never
speaking (#89). The learner should be able to see a word's meaning, say the
word aloud, and be graded. That needs a speech recogniser, a microphone, and
a rule for what to say about pronunciation. The app works offline, adds few
dependencies, and is used for languages, such as Telugu, that recognisers
support unevenly.

The maintainer decided, on 2 October 2026:

- the `speech_to_text` plugin, rather than a plugin of our own;
- that each language's sound contrasts live in a file of their own,
  `decks/<lang>/<lang>-sounds.yaml`, shared with the minimal-pair drill
  (#31);
- that the app checks what each phone can recognise itself, for every
  learner, rather than anyone measuring it once;
- that the microphone is asked for only when speaking is switched on: in
  Settings, or by a microphone test in onboarding, never at launch;
- that speaking and listening can be switched off, everywhere or for one
  language, or paused for an hour, from Settings and as a drill starts.

## Decision

- **The recogniser is the operating system's,** reached through
  `speech_to_text` (BSD-3-Clause), behind `SpeechEngine` in
  `lib/core/speech`, so that tests use a fake and another engine is
  additive. The plugin's manifest declares nothing, so
  `tools/brand_android.py` adds the microphone permission and the query
  that lets Android 11 and later see a recogniser.
- **On the device first.** A language the recogniser lists, or any
  language when it lists none, is listened for on the device. Android 13
  and later list only the on-device languages, so one they leave out may
  still be recognised online. An unlisted language is not drilled until
  the learner allows it online, on the Voices page, which a deck's
  Speaking row opens. When a listen finds that a listed language cannot be
  recognised on the device, the drill asks the learner, for that language,
  whether to recognise it online, saying that what they say would leave
  the phone; "Not now" skips its speaking cards for the rest of the
  session. The answer is a setting (`speech_online`). Nothing goes online
  otherwise. What listens find, that a language is not on the
  device or not supported online either, is kept (`speech_not_on_device`,
  `speech_unsupported`), so a restart does not cost a spoken word to find
  it out again. Check again on the Voices page forgets it.
- **The first launch checks the microphone and the sound.** After the
  tour, a step records two seconds (`record`, BSD-3-Clause) and plays
  them back (`audioplayers`, MIT), from memory: nothing is saved. Then it
  asks whether the learner heard themselves. A recording refused, silent
  or failed, or a phone with no recogniser, leaves speaking off; a
  playback that failed or wasn't heard leaves listening off. With nothing
  recorded, a beep tests the sound. Try again asks for the microphone
  once more, as Android allows. Passing the step without checking changes
  nothing. The maintainer chose both packages and the Try again.
- **Otherwise the microphone is asked for once speaking is switched on.**
  Speaking starts off. Switching it on, in Settings or on the Voices page,
  asks for the permission and then which languages the recogniser knows.
  Android 13 and later answer that only with the permission granted, so
  before it the app does not know, and says so. A permission granted before
  lets the app check quietly at launch, without holding the launch up. It
  never asks there.
- **Speaking is a drill mode,** `speaking`, scheduled per `(card, mode)`
  like the others (ADR-0005). A vocabulary card gets it by default,
  phrases too, since the recogniser does the writing. A card is drilled by
  speaking only while the skill is on and its language is heard, on the
  device or online with leave. Otherwise a deck's Speaking row says why and
  opens Voices, as Listening does without a voice.
- **Grading is the typed answer's,** through `AnswerGrader` with the
  target and its alternates, but exact once normalised: in speech a near
  miss is a different word, not a typo. The recogniser returns several
  readings. The attempt counts if its best reading is right, or another it
  states a confidence of 0.5 or more for. Android scores every reading
  after the best 0, so in practice that is the best one. Nothing heard
  records nothing, and the learner can say it again.
- **Pronunciation is commented on only when it changes the word** (#89's
  rule). An accent that keeps the word is recognised as the target and
  passes without comment. When the word heard is the target's contrast
  partner in the language's sounds file, the feedback names the contrast.
  Contrast feedback comes in its own change.

## Consequences

- One more dependency, and the plugin's own Android behaviour: on some
  phones Android's support check never answers, so the app gives it five
  seconds. A listen that never reports ends as nothing heard.
- What "on this phone" means is learned at the first listen, not before:
  a language the recogniser lists may still turn out to need online
  recognition. The drill then asks, once per language.
- Recognisers lean towards common words, and may hear the target when it
  was said a little off. A missed slip then goes uncommented, which errs on
  the side the rule prefers.
- Speaking needs a microphone and a quiet moment, so it can be switched
  off or paused, as listening can.
- No audio is stored. Only what the recogniser heard goes into the review
  log's `answer`, as typed answers do.

## Alternatives considered

- **A plugin of our own,** about 200 lines of Kotlin in a local package. It
  would mean no third-party code, but more to write and maintain, and
  Android only. The maintainer chose `speech_to_text`.
- **Bundled offline models,** Whisper or Vosk. They are large, weak on
  low-resource languages, and against ADR-0002's reasoning for text to
  speech.
- **Measuring support once, on one phone.** Support differs by phone,
  Android version and downloaded packs, so each phone checks itself.
- **Self-assessed speaking,** as recognition is. It needs no recogniser, but
  the learner cannot judge their own pronunciation, which is the point.
