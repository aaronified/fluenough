# ADR-0002: Use the operating system's TTS, behind an interface

- **Status:** Accepted
- **Date:** 2026-09-19

## Context

Listening drills are a v1 feature, and Fluenough is language-agnostic. The TTS
backend therefore has to cover as many languages as the deck format allows,
which is to say: as many as possible.

Three options were evaluated.

### Operating system TTS

`android.speech.tts.TextToSpeech` and `AVSpeechSynthesizer`, reached through
the `flutter_tts` package (4.2.5, ~396k downloads, verified publisher — mature
and widely used).

Adds nothing to the download size, requires no network, and has by far the
widest language coverage available. On Android, voices are provided by Speech
Services by Google and installed by the user through system settings; quality
on modern devices is neural and good. Coverage and quality vary by device and
by installed engine, which is the main drawback.

### Kokoro-82M (neural, on-device)

An 82M-parameter Apache-2.0 model with unusually good quality for its size.
A new release landed on 2026-04-23.

Two things rule it out for v1:

1. **Coverage.** Kokoro supports roughly ten languages — English (US/UK),
   Spanish, French, Italian, Portuguese (BR), Hindi, Japanese, Korean and
   Mandarin. Fluenough is language-agnostic. Shipping Kokoro as the primary
   engine would mean *most* decks have no audio at all.
2. **Ecosystem maturity.** Flutter bindings now exist — `flutter_kokoro_tts`
   and `kokoro_tts_flutter` — which is a genuine change from the situation a
   year ago, when this would have meant hand-rolled NDK and G2P work. But
   `flutter_kokoro_tts` is at version 0.0.1 with 81 downloads, requires
   espeak-ng data files to be configured manually, and pulls a ~50 MB model
   from Hugging Face on first run. That is not a dependency to build a core
   feature on yet.

Worth noting that Kokoro is not an *alternative* to espeak-ng so much as a
consumer of it: espeak-ng acts as the grapheme-to-phoneme frontend inside the
Kokoro pipeline. They sit at different layers.

### Pre-recorded human audio

Best possible listening practice. Rejected for v1: it needs a network, per-clip
licensing diligence, and media files that cannot live comfortably in git.

## Decision

Use OS TTS as the sole v1 backend, behind a narrow `TtsEngine` interface
(`speak`, `stop`, `isLanguageAvailable`, `voicesFor`).

## Consequences

Listening drills ship in v1 for every language the user's device has a voice
for, at zero download cost.

The interface is the important half of this decision: a `KokoroTtsEngine` can
be added later as an optional download for the languages it covers, without
touching drill code. Should the bindings mature, re-evaluate.

Audio quality is outside our control and varies by device. Decks may override
per-card audio via the `audio` field for cases where this matters.
