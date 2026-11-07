# ADR-0054: Replaying the learner's own last answer in Say drills

Source of truth: this wiki page.

- **Status:** Accepted, built in two routes (2026-11-07, owner: record at the same time as recognition). Option 2 is built for Android 13 and later and for browsers; the older best-effort capture of option 1 stays for the rest. Not yet verified on a device (see "What was built"). The "Your recording" replay is drawn in the approved shared shell (#509, 2026-11-02); the audio itself waits on on-device recognition (#1004, aimed at 0.9.0), which would supply the bytes.
- **Update (2026-11-05):** option 1 is built as a best-effort capture (`MicCapture`, started after the recogniser, self-disabling after two listens that hear nothing), as the owner asked for the first attempt to be recorded with recognition. Option 2 stays the robust route if a device shows the two cannot share the microphone.
- **Date:** 2026-11-02

- **Update (2026-11-07):** the owner saw "No recording yet. Replay records one." on a Telugu card: the recording was made only when Replay was tapped, because the best-effort capture of option 1 cannot share the microphone on his phone. Built now, as the decision below says: option 2 on Android 13 and later, and a recorder beside the recogniser in a browser. See "What was built".

## Context

In a Say (speaking) drill "Hear yourself" (`DrillSession.hearSelf`) asks the
learner to say the word again: the recogniser has let go of the microphone,
`SoundCheckEngine.record` takes a second recording, and it is played back, then
the voice. The learner hears a second try, not the answer that was graded.
Owner, 2026-11-02: replay the real audio of the last answer, not a
text-to-speech of the recogniser's text. The take stays in memory only, is
dropped on leaving the card, and the existing re-record stays as the fallback
when none was kept.

The question is whether the app can have those bytes. The recogniser
(`speech_to_text` ^7.5.0 through `SystemSpeechEngine`) takes the microphone
itself and returns text only; `record` ^7.1.1 is the recorder.

## What the research found

- **speech_to_text exposes no audio**, and has no option for it. Its
  README states: "It is not currently possible to record audio on Android
  while doing speech recognition", and suggests stopping the recorder while
  the recogniser runs. On iOS it says the plugin shares audio resources with
  other sound plugins "but there is always room for interactions".
- **Android `RecognizerIntent.EXTRA_AUDIO_SOURCE`** (API 33+): the caller
  supplies a `ParcelFileDescriptor` of audio it already captures, with
  `EXTRA_AUDIO_SOURCE_CHANNEL_COUNT`, `_ENCODING` and `_SAMPLING_RATE`. If the
  extra is absent, "or the recognizer does not support this feature", the
  recogniser opens the microphone itself. The session ends when the stream
  closes. Support is the recogniser service's choice; the speech_to_text
  plugin does not set the extra.
- **Android concurrent capture** (Android 10+) lets two apps capture at once
  only under privacy rules (a foreground app gets real audio, others can be
  silenced); two captures in one app on one source, with a recogniser service
  in another process, is not a documented guarantee, and the plugin's own
  warning says it fails in practice.
- **iOS** recognition works on an `AVAudioEngine` tap, so a second consumer of
  the same buffers is possible in a native engine, but the plugin does not
  offer it, and a separate `record` session competing for `AVAudioSession`
  category and activation is the interaction the README warns about.
- `record` 7.x can stream `pcm16bits` and write WAV, but says nothing about
  running beside a recogniser.

## Options

1. **Record alongside the recogniser** (`record` started at the same moment
   as `listen`). Cheap, no native code. Main downside: the plugin says it does
   not work on Android, and on iOS it risks the recogniser failing or silence
   in either; a broken Say drill is worse than no replay.
2. **Own the capture and feed the recogniser** (a thin native engine behind
   `SpeechEngine`: Android `EXTRA_AUDIO_SOURCE` from our PCM stream on API 33+;
   iOS `SFSpeechAudioBufferRecognitionRequest` fed by our `AVAudioEngine`
   tap, keeping a copy). The bytes are exactly what was graded. Main
   downside: replaces `speech_to_text` with our own platform code on two
   platforms, and Android below 33 or a recogniser that ignores the extra
   cannot do it (older phones, some OEM recognisers).
3. **Keep today's re-record** (status quo). Zero risk. Main downside: it is the
   second try, not the graded answer, which the owner rejected as the goal.
4. **TTS of the recogniser's text.** Rejected by the owner: it is not the
   learner's voice.

## Decision (recommended)

Option 2, behind the `SpeechEngine` seam, with option 3 as the fallback.

- `SpeechHeard` gains an optional `ownAudio` (PCM16 mono with its sample rate),
  null whenever the engine could not keep it. `SystemSpeechEngine` stays as the
  engine for everything that cannot capture (Android below 33, a recogniser
  that ignored the extra, any capture error), so those phones behave as today.
- `DrillSession` holds the take in a field cleared when the card changes,
  the drill ends or the session is disposed. `hearSelf` plays it when present,
  then the voice, and otherwise records as now. Nothing is written to the
  database, the backup, the log or the disk; no file is created.
- Build in two steps so the risk is measured first: a device spike for Android
  (option 2 with a throwaway engine) and for iOS, before the engine is
  replaced. If the spike fails on a platform, that platform keeps option 3
  and this ADR is amended.

## What was built (2026-11-07)

- **Android 13 and later (API 33):** `MainActivity.listenWithAudio` (written by `tools/brand_android.py`, read by `lib/core/speech/native_listen.dart`) captures the microphone itself with `AudioRecord` (16 kHz mono PCM, in memory) and hands the recogniser the same stream through `RecognizerIntent.EXTRA_AUDIO_SOURCE` (a pipe), with the channel count, encoding and sampling rate extras, so there is one reader of the microphone and the audio kept is what was recognised. The recogniser's readings and the PCM come back together. `SystemSpeechEngine` tries it first; `unsupported`, an error of this side (`error_audio`, `error_client`, `error_busy`, an exception, a timeout), or silence in the stream make it listen the plain way, and two such listens in a row stop it being tried. A recogniser service that ignores the extra opens the microphone itself; if our capture then hears only silence, no take is offered and the drill records a second take as before. Cancelling (`stop`) ends the listen and still delivers what was heard; a failed listen keeps nothing; the stream is closed, the recorder released and the recogniser destroyed at the end; no file is written.
- **Below Android 13:** unchanged: the best-effort capture of option 1 (started after the recogniser, self-disabling), else Replay records a take.
- **Browsers:** a `MediaRecorder` on its own microphone stream starts beside `SpeechRecognition` and stops with it; the take is decoded to PCM in memory. A browser that will not share the microphone, cannot decode, or hears silence gives no take; an error or a cancel drops it unread.
- **Not yet verified on a device.** The tests check the Dart side with fakes (the engine, the channel, the browser) and the Kotlin by shape; whether a given recogniser service takes `EXTRA_AUDIO_SOURCE` (the Google recogniser, an OEM one, the on-device pack) is the open question of "To test on a device" above, and the fallbacks make a phone that does not behave as it did.

## Privacy wording

For the settings page and store listing: "The sound of your last answer is
kept in memory on your phone only so you can hear it back. It is deleted when
you leave the card, is never saved to storage, never sent anywhere by the
app, and never included in backups." On devices that use online recognition
the recogniser still sends audio to the operating system's speech service as
today; the wording must not claim otherwise (the existing online-recognition
prompt stays).

## Confidence

**Medium-Low** that option 2 works across the phones we support: documented
on Android 13+ and iOS, but recogniser support for `EXTRA_AUDIO_SOURCE` is
unverified, and I could not run a device. **High** that option 1 fails on
Android (the plugin says so) and that nothing in speech_to_text exposes audio.

## To test on a device

- Android 13+ with the Google recogniser, one OEM recogniser, and the
  on-device pack: does recognition still return text when fed our descriptor,
  and is the kept audio audible and the right length?
- Android 12 and below: fallback path chosen, no regression.
- Recognition of Hindi, Bengali and Telugu unchanged in accuracy and latency
  against `SystemSpeechEngine`.
- iOS: tap shared between recogniser and copy; interruptions (a call, Bluetooth
  headset, route change) end cleanly; the start and stop sounds.
- Permission refusal, no speech, rapid card changes: the take is dropped, no
  stale playback, no leak (memory stays flat over 200 cards).
- Airplane mode (on-device) and online recognition both.

## Consequences

- Needs native code on both platforms; the plugin swap is the cost to weigh
  against the feature.
- AGENTS.md's `lib/core` rule holds: the interface and bytes type are pure
  Dart, the platform code lives outside it.

See also: [ADR-Index](ADR-Index) · [Home](Home)
