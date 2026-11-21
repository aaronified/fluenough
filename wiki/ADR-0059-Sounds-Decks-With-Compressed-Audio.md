# ADR-0059: Sounds decks with compressed audio, fetched and never synthesised

Source of truth: this wiki page.

- **Status:** Proposed (owner requests, 2026-10-23 and 2026-11-21, #734). The choices below are the author's defaults for the owner to confirm. The full reasoning, the source survey and the work packages are in [Plan-Sounds-Decks](Plan-Sounds-Decks).
- **Date:** 2026-11-21

## Context

Every language needs a sounds deck: each prevalent sound explained, and how it differs from the learner's native sounds (owner, 2026-10-23). Telugu's (#736) showed that a sounds file (the contrasts of [ADR-0015](ADR-0015-Sound-Contrasts)) has no per-sound card, IPA or example. The owner then asked for audio: "Use a sound format that can compress the sounds to save space (16bit, max 128kbps ogg format)", and described the pipeline: "This will simply be a loop of fetch requests, whatever is fetched, gets packaged in decks-live with their cards. Whatever cannot be fetched, remain as is (phone tts)." Synthesised audio (eSpeak NG, Piper) is "kept aside as possible future features".

A card can already carry its own recording (`audio`, `audio_credit`, #518); Morse ([ADR-0057](ADR-0057-Morse-Code-Course)) and `tools/import_wiktionary.py --audio` ship Ogg Opus `.opus` files; decks are CC BY-SA 4.0 ([ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa); ADR-0003 is superseded), so only CC0, public-domain, CC BY and CC BY-SA recordings can ship.

## Decision

1. **A sounds deck is ordinary cards**, one per sound, in a core and English layer named `<lang>-sound-inventory`, using fields that exist: `target` (the letter), `reading`, `ipa`, `phonetic`, `examples` (the example word), `tags` (the contrast id), the layer's `native` and a layer note that starts `Same as English:`, `Close to English:` or `New to English:`, then `audio` and `audio_credit` where a recording was fetched. No new card field, so no `min_app` gate and no wait for a release. The contrasts file `<lang>-sounds` stays as it is.
2. **Audio is Ogg Opus in `.opus` files**, the extension the validator, `deck_index.dart` and the app already accept, mono, decoded from 16-bit PCM, 24 kHz, about 32 kbps variable bitrate, peak-normalised, trimmed. **128 kbps is a hard cap** that the tool and the validator enforce; the working target is a quarter of it. Budget: at most 16 kB a sound, about 0.4 MB a deck if every card had audio, a ceiling for all sounds audio in `decks-live` (owner decision 9).
3. **Audio is fetched, never made.** A tool, `tools/fetch_sound_audio.py`, loops over the sound cards: for each it asks Wikimedia Commons (IPA-symbol recordings, then letter recordings) and, for example words, Wiktionary's recordings (the existing importer), accepts only a CC0, public-domain, CC BY or CC BY-SA file with a named author, converts it, names it by card id, writes `audio` and `audio_credit` (Commons page, licence, author), and the files ship with the deck on `decks-live`. A card whose audio cannot be fetched has **no** `audio` field and the phone's text-to-speech says it, as today. The tool is polite (cache, rate limit, back-off, batches), resumable, idempotent and deterministic, reports fetched and missing per language and the total size, and cards never wait for it.
4. **No synthesised audio ships.** eSpeak NG, Piper and similar are recorded as possible future features, with the conditions for enabling them (a written licence finding for engine and voice, a quality bar, the same size budget, and a visible "synthetic" marker), not as rejected.
5. **Attribution is strict**: author, licence, link per file in `audio_credit`, shown where the app shows credits, and one deck-wide line that the recordings were trimmed, normalised and converted. A file with no author or a GFDL-only, NC or ND licence is skipped and reported.
6. **Pilot with Telugu** (upgrading its existing deck, no card renumbered), then the first list, the second list, the rest.

## Consequences

- No app release is needed for the cards; the audio files need only the validator checks (Ogg Opus, bitrate, size) and a Sources-screen line.
- Coverage is partial and uneven: plain IPA symbols well, tones, length, aspiration and gemination mostly not. A learner on a card without audio hears the phone's voice, as now; the phone's voice may be poor at an isolated sound or absent for the language.
- The IPA-symbol clip is the symbol, not the language's own sound. Reviewers judge every recording and a bad one is removed with its file.
- Wikimedia rate-limits the shared proxy address: runs are slow and several sessions per group. The owner may need to allow `commons.wikimedia.org`, `upload.wikimedia.org`, `en.wiktionary.org`, `en.wikipedia.org` and `kaikki.org` (reachable now) and, if limits persist, give a Wikimedia API account.
- Audio in git grows the repository for good; the ceiling and the 16 kB budget limit it.
- Ogg Opus on iOS and web is unverified; a play error already falls back to TTS.

## Alternatives

- **Ogg Vorbis, `.ogg`.** Worse at low bitrates (about twice the size for the same speech), not played by iOS's media stack, and needs three code changes (validator `MEDIA`, `deck_index.dart` regex, loader). Rejected for the extension; Commons's Vorbis sources are converted.
- **A new `vs_native` layer field and per-sound `ipa` and `examples` fields on the sounds file** (the #736 proposal). Cleaner to read than a note lead-in, but gated behind a release and a parser change, and it duplicates fields cards have. Kept as a later option if the note lead-in proves too weak.
- **Streaming audio** instead of shipping it. Rejected earlier (#518: "No stream, download and ship with deck").
- **Recording the sounds ourselves.** Builders are agents and cannot record; a human recording drive per language is not planned.
- **NC sources** (Forvo, university phonetics charts, MMS-TTS). Not allowed in a CC BY-SA deck, and most are not reachable from the sessions.

## Possible future features

Synthesised audio from eSpeak NG (GPL-3.0-or-later software: whether its generated waveform is free of the GPL is not settled here), Piper (voice licences vary by dataset) or others, **not shipped now and not rejected** (owner, 2026-11-21: "kept aside as possible future features"). To enable: a written licence finding for the engine and the voice compatible with CC BY-SA 4.0; a native reviewer's approval of each clip; the same Ogg Opus size budget; an additive `audio_credit.synthetic` marker (validator rule, a release that reads it, a visible badge). MMS-TTS is CC-BY-NC 4.0 and is out. Details and sources: [Plan-Sounds-Decks](Plan-Sounds-Decks#possible-future-features).

## Owner decisions needed

1. **Container: Ogg Opus in `.opus`** (recommended) or Ogg Vorbis `.ogg`. Downside of Opus: iOS and Safari playback unverified (falls back to TTS on error). Vorbis needs code changes and plays worse still on iOS.
2. **Bitrate: target about 32 kbps mono, 128 kbps a hard cap** (recommended) or encode near the cap. Downside: Commons's Vorbis sources are encoded twice (lossy to lossy), a small quality loss; the cap would waste space for no gain.
3. **What the audio of a sound card is: the Commons IPA-symbol recording when the card's `ipa` is that symbol** (recommended) or only a recording of the language's own letter. Downside: the symbol is not the language's exact sound; far fewer cards get audio under the strict option.
4. **Format: no new fields, notes carry same/close/new** (recommended) or an additive `vs_native` field now. Downside: the verdict is text, not a badge; the field needs a release before any deck uses it.
5. **Naming and scope: one `<lang>-sound-inventory` deck per language, the old `<lang>-sounds` and sound-differences decks kept** (recommended) or fold them in. Downside: three sound-related files per language; folding would renumber nothing but breaks the drills' links.
6. **Pilot: Telugu, upgrading the existing deck** (recommended). Downside: Telugu has thin Wiktionary audio, so it may show the worst coverage; the survey run tells that early, which is the point.
7. **Wikimedia access: allow the five hosts and accept slow runs** (recommended) or add a Wikimedia API account or bot password. Downside: slow, several sessions per group; an account is a secret to look after.
8. **A file with no machine-readable author: skip it** (recommended, strict) or credit the uploader named on the description page. Downside: skipping loses many old IPA clips; crediting the uploader risks a wrong attribution.
9. **A ceiling for sounds audio in git** (recommended 50 MB in `decks-live`, 16 kB a clip) or none, or release assets instead of git. Downside: a ceiling may cut the tail languages; git history never shrinks.
10. **Synthesised audio stays in "possible future features"** (as ordered); the owner says when to revisit. Downside: languages with no recordings stay on the phone's voice, or on none.
11. **Lift "Deck work waits for the rest" for the sounds decks**, or keep the code packages (validator, fetch tool, credit line) first and the decks after (recommended). Downside: the decks are late; lifting competes with the coding queue.

See also: [Plan-Sounds-Decks](Plan-Sounds-Decks) · [ADR-0015](ADR-0015-Sound-Contrasts) · [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa) · [ADR-0057](ADR-0057-Morse-Code-Course) · [ADR-Index](ADR-Index) · [Home](Home)
