# Plan: a sounds deck for every language, with fetched, compressed audio

Source of truth: this wiki page.

Written 2026-11-21 for #734 (a sounds deck for every language), with #31 (phonemic contrasts), #736 (the Telugu sounds deck, the model) and #1221 (the IPA keyboard follow-ups; its `typed` flag stays off, so sound cards are chosen, never typed). Builds on [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology), [ADR-0015](ADR-0015-Sound-Contrasts), [ADR-0057](ADR-0057-Morse-Code-Course) (the audio-per-card mechanism) and [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa). The decision record is [ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio) (Proposed). Nothing here is built. Everything marked **Proposed** is the author's, not a decision.

## What the owner asked

> all languages need a better sounds deck, where all the prevalent sounds in the language will be explained and how they are different from the native language sounds. (2026-10-23, #734)

> They need to be built as well. Use a sound format that can compress the sounds to save space (16bit, max 128kbps ogg format) (2026-11-21)

> This will simply be a loop of fetch requests, whatever is fetched, gets packaged in decks-live with their cards. Whatever cannot be fetched, remain as is (phone tts). (2026-11-21)

> No, they are kept aside as possible future features. (2026-11-21, on eSpeak NG, Piper and other synthesised audio)

So: sound cards for every language that has a language entry and a path; audio only where a licence-compatible recording can be **fetched**; Ogg at most 128 kbps from 16-bit sources; everything else is spoken by the phone's text-to-speech as today. No synthesised audio is shipped now (see [Possible future features](#possible-future-features)).

## What exists (verified 2026-11-21 on `main` and `decks-live`)

- **A sounds file** (`decks/<lang>/<lang>-sounds.yaml`, `kind: sounds`, ten languages) lists *contrasts*: pairs of letters or signs and a name, for the speaking drill and the minimal-pair drill. It has no per-sound card, no IPA and no examples. Telugu's core is eight contrasts; its English layer has the contrast names and one long `description` string (the format gap #736 reported).
- **A sound-differences deck** (`<lang>-sound-differences`, a normal vocab deck, in 25 or so languages) holds minimal-pair words tagged with the contrast id, with `pair` notes.
- **`audio` and `audio_credit`** exist on a card (#518). The file is `decks/<lang>/audio/<card id>.opus`; the validator (`MEDIA` in `tools/validate_decks.py`) requires exactly that name and the ending `.opus`, a file for every `audio`, no unnamed file in the folder, and a credit `{ source, license, credit }` whose licence matches `MEDIA_LICENSE_RE` (CC0-1.0, public-domain, CC-BY or CC-BY-SA 2.0 to 4.0; never GFDL alone, NC or ND). The app side: `lib/core/decks/deck_index.dart` accepts only `decks/<lang>/audio/<lang>-NNNN.opus` as a media path; `AppState.speakCard` plays `card.audio` through `audioplayers` (`SystemClipPlayer`, from a file on the phone), and on any failure or no file speaks the text with TTS. The index lists each file with its size and SHA-256 and counts it in the language's size.
- **`tools/import_wiktionary.py --audio` already is a fetch loop** for word recordings: it reads the recording Wiktionary links for exactly the card's text, asks Commons for the file's licence and artist (`commons_file`, `licence_id`), skips a licence that cannot ship or a file with no named speaker, downloads, and converts with `ffmpeg` to mono Opus at 24 kbps, writing `audio` and `audio_credit`. The new tool reuses these functions rather than starting again.
- **Morse (ADR-0057)** ships 656 to 948 byte `.opus` files per card (generated tones), so the Opus-in-`.opus` path is exercised end to end on `decks-live`.
- `ffmpeg` with `libopus` and `libvorbis` is installed in this session; the CI workflow `asr-export.yml` installs it with `apt-get`; `ci.yml` has the "Validate decks" and "Released app reads the decks" checks.

## 1. The card: one card per sound

### Shape

A sounds deck for a language is a **core and an English layer** (more native layers later), named `<lang>-sound-inventory`, a normal `vocab` deck. (`<lang>-sounds` is taken by the contrasts file; Deck-Format reserves it.) One card per prevalent sound: every vowel and consonant in the inventory and, where the language has them, each tone, length mark, aspiration, retroflexion, nasalisation, gemination or other contrast sound. Card ids come from the language's ordinary `<lang>-NNNN` pool and are permanent.

| What the card says | Existing field | Notes |
|---|---|---|
| The sound's spelling | `target` | The letter, sign or letter pair that writes it (క, ఖ, ా). A sound written several ways gets one card, the others in `alt_target`. A tone is the tone mark or a syllable carrying it. |
| Reading in the course's romanisation | `reading` | `ka`, `kha`. |
| The sound's IPA | `ipa` (broad, no brackets) and `phonetic` (narrow, `[ ]`, written only by the tools) | The unit being taught: `kʰ`, `ɖ`, `aː`. The validator already checks IPA letters. |
| Example word with reading and meaning | `examples`: `{ target, reading, ipa }`, its meaning in the layer | At least one, ideally the word already a card of the course, so the learner meets it again. A sentence example is spoken by TTS, as today. |
| How the sound differs from the native sound | the **layer's `native`** (the sound's description, "the tongue curled back") and a layer **note** of kind `note` | The note starts with a fixed lead-in so a reviewer, the validator and a later UI can tell the verdict: `Same as English:`, `Close to English:` or `New to English:`, then what is the same or different, with an English word where one helps. |
| The contrast it belongs to | `tags`: the contrast id of `<lang>-sounds` (`aspiration`, `dental-retroflex`) | Links the card to the minimal-pair drill and the sound-differences deck. |
| Audio | `audio` and `audio_credit` | Only if a recording was fetched (section 3). Otherwise no field. |
| Drill modes | `modes: ["production", "speaking"]` | Recognition (see the letter, pick its description) and Listening (hear the sound, pick the letter) stay. Typing IPA is off (`typed: false`, #1221); an isolated sound cannot be graded from speech-to-text. |

A Telugu card would read, in the core: `{ id: te-NNNN, target: "ట", reading: "ṭa", ipa: "ʈa", tags: ["dental-retroflex"], examples: [{ target: "టపా", reading: "ṭapā", ipa: "ʈapaː" }], notes: [{ id: "n1", kind: "note" }], modes: [...] }`, and in the English layer the `native` "the t with the tongue curled back" and `n1`: "New to English: English t touches the ridge behind the teeth, so both Telugu t's (త on the teeth, ట curled back) sound like English t to a beginner. Hear the lower, hollower ట."

### The format gap, and how it is closed

#736 said a sounds file has no per-sound IPA or example fields and proposed `ipa`, `examples` and `vs_native` on each contrast. **Proposed: no format change.** A card already has `ipa`, `phonetic`, `examples`, `tags`, `native`, notes, `audio` and `audio_credit`, so the sounds deck is ordinary cards, and the contrasts file stays the lean list of pairs ADR-0015 made it. The only thing without a field is the same/close/new verdict, and it is carried by the note's lead-in, which a tool can check on cards tagged `sounds` (a small, optional validator lint, no app change).

**`min_app`.** `_gate_fields` in `tools/deck_index.py` gates a file behind `CARD_FIELD_MIN_APP` (today `character` at 0.10.2 and `situation_icons` at 0.10.3) or a line in `decks/min_app.json`, because the released app's parser rejects an unknown field. With the fields above, nothing is gated: the files use only fields the released app reads, the audio paths match `deck_index.dart`'s `.opus` pattern, and "Released app reads the decks" passes. The cards can therefore ship before any release.

**Option B (not recommended now):** an additive layer field `vs_native: same|close|new`, gated with `CARD_FIELD_MIN_APP["vs_native"]`, to let the app draw a badge. It waits for a release, a parser change and a UI. Take it later, if the note lead-in proves too weak.

**What a recording may be.** The existing rule is that a recording is exactly the card's text (owner: "If the phrase itself exists then the sound can be used"). For a sound card the text is the sound, so the recording is a recording **of that sound**: Wikimedia Commons's recordings of the IPA symbols (one clip per symbol) when the card's `ipa` is that single symbol, or a recording of the letter itself. A recording of the example word belongs to the word's own card (Wiktionary audio, fetched by the existing `import_wiktionary.py --audio`), not to the sound card. The credit's `source` names the Commons page, which says what the clip is. The symbol recording is the IPA symbol, not the language's allophone (Telugu ɖ is not exactly the IPA's): see the risks in section 2.

## 2. Audio: container, codec, size

### Container and codec: Ogg Opus, kept in `.opus` files

| Option | Android (`audioplayers`, `MediaPlayer`) | Web | iOS | In this repo |
|---|---|---|---|---|
| **Ogg Opus, `.opus`** | plays (Android 5.0 and later) | Chrome and Firefox play it; Safari's Ogg Opus support is recent and I did not verify it | Apple's players have no long history with Ogg; Opus plays in some containers on newer iOS, and I did not verify Ogg Opus on a device | **Already shipped** (Morse, Wiktionary audio); the validator, `deck_index.dart` and `SystemClipPlayer` accept it |
| Ogg Vorbis, `.ogg` | plays | Chrome and Firefox play it; Safari does not natively | iOS has no Vorbis support in its media stack | Not accepted: needs the validator's `MEDIA` ending, `deck_index.dart`'s regex and the app's loader changed |

Recommendation: **Ogg Opus in a `.opus` file.** It is "an ogg format" as the owner asked, it is the better codec for speech at low bitrates (a Vorbis clip needs more than twice the bits for the same speech quality), it needs **no code change** for the extension, and the iOS and web question is the same for the Morse files that ship now. iOS is not built or tested by anyone yet (AGENTS.md: "nobody has built it on macOS or Windows"), so before iOS ships, an Ogg Opus clip must be tried on a device; the fallback if iOS cannot play it is already in `speakCard` (any play error falls back to TTS), so a deck is never broken by it. Commons's IPA recordings are mostly Ogg **Vorbis**; they are decoded and encoded again as Opus (lossy to lossy: use a bitrate at or above the source's, see below, and do not go below it).

### Format details (Proposed)

- **16-bit**: every source is decoded to 16-bit signed PCM, mono (`-ac 1 -sample_fmt s16`), before any processing, so processing is not done on a lossy float chain and the loudness stays in range.
- **Sample rate 24 kHz** (12 kHz bandwidth): enough for the fricatives (s, ʃ, ɕ, x) that learners must tell apart; 16 kHz would clip them. Opus stores the input rate and decoders play at 48 kHz.
- **Bitrate**: the owner's 128 kbps is a **cap**. Recommended target for isolated sounds and words is **32 kbps, variable bitrate, mono**, with the tool refusing any file whose average exceeds 128 kbps and warning above 48 kbps. Opus speech is transparent to most ears at 24 to 48 kbps; the Wiktionary tool uses 24 kbps. 32 kbps is chosen over 24 because a short clip of a consonant is the case where artefacts hurt the lesson. 128 kbps would be four times the size for nothing audible.
- **Loudness**: trim leading and trailing silence to about 50 ms, then **peak-normalise to about -3 dBFS** (measure with `volumedetect`, apply the gain). Not EBU R128 `loudnorm`: it is meant for programmes of many seconds and misreads one-second clips. Keeps sounds of one deck at the same level.
- **Length**: at most 4 seconds for a sound, 6 for a word; a longer source is trimmed or skipped and reported.
- **Name**: `decks/<lang>/audio/<card id>.opus`, the validator's rule; deterministic.

### Size budget

A 1.5 second clip at 32 kbps is about 6 kB, plus about 1 kB of Ogg overhead. Budget per sound: **at most 16 kB** (the validator rejects a clip larger than 64 kB as an error; 16 kB is the tool's warning). A deck has 30 to 80 sounds (Telugu about 50, tonal and click languages more, Toki Pona about 14): about 0.4 MB if every card had audio. For about 90 languages with about 45 sounds each, 4,050 cards at 8 kB is **about 32 MB if every card got a clip, which will not happen** (see coverage); expect 5 to 15 MB in total, and set a ceiling of 50 MB for sounds audio in `decks-live` (owner decision 9), because git history cannot shrink. The index already lists each file's size and SHA-256 and counts it in the language's download size.

### Tool plan: `tools/fetch_sound_audio.py` (Proposed, code, Sonnet)

A fetch loop, as the owner described: for each sound card of a language that has no `audio`, ask the licence-compatible sources, convert what is fetched, write `audio` and `audio_credit`, leave the rest alone. Requirements:

- **Sources in order** (section 3): Commons IPA-symbol recordings, Commons letter recordings; never a synthesised file, never an NC or ND or GFDL-only file.
- **Strict credit**: per file, `audio_credit.source` is the Commons file page, `license` the SPDX-like id from `licence_id`, `credit` the author as Commons's `Artist` metadata gives it. A file with no named author is **skipped and reported** (Wikimedia requires attribution; "Files with no machine-readable author" is a real Commons category, and the first IPA file I checked is in it, so the tool must also try the description page's `|author=` before skipping). Changes are indicated once, deck-wide, by a line on the app's Sources screen and in the deck credits ("Recordings from Wikimedia Commons, trimmed, normalised and converted to Ogg Opus"), as the Wiktionary line is; CC BY-SA 3.0 and 4.0 require the change to be indicated.
- **Polite**: a `User-Agent` naming the project, one request at a time, a default pause of 1 second, `Retry-After` and exponential backoff on 429 and 5xx, batches of up to 50 titles per `imageinfo` request, a cache folder (`.cache/sound-audio/`, git-ignored) holding every API answer and every downloaded original so a rerun costs nothing, and a negative cache (a card with nothing found is not asked again for 30 days, `--retry-missing` overrides).
- **Resumable and idempotent**: skips a card that already has `audio`; a killed run loses nothing; two runs on the same cache write the same bytes. `--lang`, `--limit N` (cards per run), `--dry-run` and `--survey` (counts what is available per language and writes nothing).
- **Deterministic**: where several recordings match, the one chosen is the first by a fixed order (a native speaker's category first, then file title), so a rerun picks the same.
- **Writes text, like `import_phonetic.py`**: adds the two lines after the card's `audio` position and touches nothing else.
- **Checks its own output**: `ffprobe` that the file is Opus, mono, at most 128 kbps and at most the length limit, before writing.
- **A per-run report** per language: cards asked, fetched, skipped (licence, no author, too long), missing, bytes per language and in total, and the cards' ids.
- **Cards never wait for audio**: sound cards are built and merged without it, and gain `audio` on a later fetch run; a card without the field is spoken by the phone as today.
- **No Flutter and no new dependency**: `urllib` and PyYAML, `ffmpeg` on the path (installed on CI by `apt-get install ffmpeg`, as `asr-export.yml` does; it is in these sessions; tests mock `http_get` and `convert` as `test_import_wiktionary.py` does).

The validator (`tools/validate_decks.py`) checks (built, work package 1): a shipped audio file is an Ogg Opus stream (starts `OggS`, `OpusHead`), mono, its average bitrate (file size over the duration from the last Ogg page's granule position) is at most 128 kbps, its size at most 16 kB (an error, not the 64 kB first proposed), the credit's licence is on the allow-list, and all the decks' audio stays under 50 MB (`--audio-report` lists it per language).

## 3. Sources: what can be fetched, and what cannot

Tested from this session on 2026-11-21 through the agent proxy (the fetch loop will run in a session with the same limits).

| Source | Reachable from here | Licence | Use |
|---|---|---|---|
| **Wikimedia Commons API** (`commons.wikimedia.org/w/api.php`): `imageinfo` with `extmetadata` (licence, artist), `categorymembers`, `search` | **Yes** (HTTP 200). **Rate limited**: after about ten requests in a minute the shared proxy address got "You are making too many requests" (HTTP 429) for a minute or more, while a later call got through | per file: the API says it (`LicenseShortName`, `Artist`) | The licence and credit of every file, and listing a category: `Category:Telugu pronunciation` exists and lists files. |
| **`upload.wikimedia.org`** (the files) | **Yes** (HTTP 200 for `Voiceless_bilabial_plosive.ogg`, 20 kB Ogg Vorbis, 1.5 s); the first request got 429, a retry got through | per file | The downloads. |
| **Commons IPA symbol recordings** ("Audio files of phonetic samples", `File:Voiceless bilabial plosive.ogg`, one clip per IPA symbol; the file I checked is CC BY-SA 3.0, migrated from GFDL, and has no machine-readable author) | Yes | CC BY-SA 3.0 or 4.0 mostly, some GFDL-only, some public domain | **First choice** for a sound card whose `ipa` is one IPA symbol. Covers the pulmonic consonants and the cardinal vowels, not language-specific sounds, tones or length. |
| **Wiktionary pronunciation audio** (Commons files linked from an entry; `en.wiktionary.org` API) | Yes (200 with the title URL-encoded; also 429 under a burst) | CC BY-SA, CC BY, CC0, per file | Recordings of **words**, for the example word's own card, by the existing `import_wiktionary.py --audio`. Telugu, for instance, has some native recordings (`Antamu-Te.ogg`, `Bharta-Te.ogg`); the coverage is not measured. |
| **kaikki.org** (Wiktextract dumps, JSONL, per language) | Yes (200) | The data is Wiktionary's (CC BY-SA); each audio file is licensed on Commons | **Use instead of the live API to find which Commons files an entry has** (`sounds[].audio`, `ogg_url`): one download per language, no per-word request. The phonetic tool already uses it. |
| **Wikipedia** (`en.wikipedia.org`, for example `Help:IPA/Telugu`, "X phonology") | Yes (200) | CC BY-SA | The **phonology source** for cards (inventory, examples). Few pages carry audio, so a source of facts, not of files. |
| **Wikidata** | Yes | CC0 | Not needed for audio. |
| `archive.org` search | Yes | per item | Not relied on; items vary and many are NC or unclear. |
| **UCLA Phonetics Lab, Seeing Speech, Forvo, ipachart.com** (recordings of sounds and words) | **No** (connection refused by the proxy) | Not checked (none could be reached); Forvo and several university charts are NC or all rights reserved, to my knowledge | Not usable: unreachable, and the licences are likely NC. Do not add them without a written licence. |
| **Common Voice, OpenSLR, freesound.org** | **No** | Common Voice is CC0, but is sentences, not isolated sounds; others vary | Not usable from here. |
| **eSpeak NG, Piper, MMS-TTS** (synthesis) | `raw.githubusercontent.com` yes (the GPL text), `github.com` pages no (403), Hugging Face yes | see [Possible future features](#possible-future-features) | **Not shipped.** |

**What the owner must allow, or accept.** The fetch loop needs these hosts, which are reachable now: `commons.wikimedia.org`, `upload.wikimedia.org`, `en.wiktionary.org`, `en.wikipedia.org`, `kaikki.org`. It needs no other. The real constraint is Wikimedia's rate limit on the shared proxy address, not a block: a run must stay slow (1 request a second at most, batches of 50 titles), use the cache, and may need several sessions per language group. If runs still meet 429 for long stretches, the fix on the owner's side is a Wikimedia API account or bot password (the tool would take it from an environment variable) or an allowance for the project's `User-Agent`; Wikimedia's rate-limits page, which the 429 itself cites, explains the options.

### Per-language source order, and who ends with what

For each sound card, in order, stop at the first hit:

1. The Commons recording of the IPA symbol the card's `ipa` is (language-neutral clip; the credit says it is the symbol).
2. A Commons recording of the letter itself in that language (found by the language's pronunciation category, when one exists).
3. Nothing: no `audio`, the phone's TTS says the card, as today.

A card's example word takes its own card's audio by the existing Wiktionary path.

Likely outcomes (the first job of the loop is `--survey`, to replace these guesses with counts):

- **Real recordings, partly:** every language's sounds that are a plain IPA symbol (p, b, t, d, k, ɡ, m, n, s, ʃ, a, i, u, the cardinal vowels, and so on): about 40 to 60% of a typical inventory, and more for Romance and Germanic languages.
- **Often none:** language-specific sounds with no symbol clip of their own: tones, vowel length as a contrast, gemination, aspirated and breathy pairs (kʰ, ɡʱ have clips only if the IPA set has them), nasalised vowels, clicks, ejectives. These stay on phone TTS, or have no sound at all in a language the phone has no voice for.
- **Words:** coverage depends on Wiktionary: strong for Spanish, French, German, Russian; thin for Telugu, Assamese, Kannada and Marathi (the narrow-IPA coverage table of the phonology plan is the nearest proxy: Telugu 5%).

### Quality and licence risks, plainly

- **The IPA symbol clip is not the language's sound.** It is a phonetician's recording of the symbol. Telugu retroflex ɖ, Spanish approximant ð and Hindustani breathy ɡʱ are near it, not equal to it. A learner imitating it learns the IPA's sound. Mitigations: `Close to` notes name this; reviewers judge every recording, as the audio rule already says ("Reviewers judge every recording"); a bad one is removed with its file.
- **Old Commons files have thin metadata**: no author, GFDL-only, or a licence line in the description rather than the template. The tool skips what it cannot credit; coverage will be lower than the file count suggests.
- **Recording quality varies** (noise, clipped, a spoken word before the sound). The tool trims and normalises; it cannot judge. Reviewers do.
- **Attribution is a legal duty, not a courtesy**: author, licence, a link, and a note of changes. A missing or wrong credit is a licence breach on a CC BY-SA deck. The tool is strict and the app shows each `audio_credit` where it already does.
- **GFDL** (no CC) is not allowed by the validator and is skipped. **NC and ND** are never allowed (ADR-0040, which superseded ADR-0003: the deck is CC BY-SA 4.0).
- **Wikimedia may rate limit or block a careless bot**; the tool is built to be slow and to obey `Retry-After`.
- **iOS and web playback of Ogg Opus is unverified** here.

## Possible future features

Owner, 2026-11-21: synthesised audio is "kept aside as possible future features", not rejected. Nothing below is shipped, planned or built; it records what was found so a later decision starts from facts.

**Facts gathered (2026-11-21):**

- **eSpeak NG** is GPL-3.0-or-later: the project's `COPYING` is the GPL version 3 text (read here). Is its audio output redistributable under CC BY-SA 4.0? The FSF's position (GPL FAQ, which I could not reach from here, so quoted from memory and unverified) is that the output of a program is not covered by the program's licence unless the output contains part of the program; synthesised waveforms are generated, not copied. Against that: eSpeak NG's voices rest on phoneme data and dictionaries that are part of the GPL package, some phonemes are built from recorded samples, and some voices use MBROLA data with their own non-free-for-redistribution terms. So the likely position is "the generated waveform is not a GPL work", with **real doubt that no one here has resolved**. Do not rely on it without a lawyer's or the maintainers' written answer.
- **Piper**: the engine's licence has changed between releases (MIT in the original `rhasspy/piper`; a later fork that uses eSpeak's phonemizer is GPL-3.0, to my knowledge, not verified), and **each voice has its own licence**, set by the dataset it was trained on; many datasets are CC BY-NC or unclear. `voices.json` (252 kB, reachable here) lists the voices; I did not audit one licence.
- **MMS-TTS** (Meta, covers Telugu and about 1,100 languages): the model card for `facebook/mms-tts-tel` says **CC-BY-NC 4.0** (read here): not allowed in a CC BY-SA deck.

**What would have to be true before it is enabled:**

1. A written licence finding for the engine **and** the specific voice: the output is compatible with CC BY-SA 4.0 (CC0, CC BY or CC BY-SA model and dataset, no NC, no GPL claim on output).
2. A quality bar: a native-speaker reviewer approves each clip for each language; isolated retroflex, aspirated and tonal sounds from eSpeak are known to be poor.
3. The same size budget and the same Ogg Opus pipeline (so no new format).
4. A **clear "synthetic" marker** on the card: today `audio_credit` accepts only `source`, `license` and `credit`, and the validator refuses any other key, so a marker needs an additive `audio_credit.synthetic: true` (or a `credit` convention), a validator rule, a release that reads it (`CARD_FIELD_MIN_APP`) and a badge or line where the app shows the credit, so learners can tell a machine from a person.
5. The owner's decision.

## 4. Work packages and order

Cards do not wait for audio, and audio does not wait for cards: the order is cards first, the fetch loop later, per language group.

| # | Package | Where | Who | Depends on |
|---|---|---|---|---|
| 0 | Owner decisions (list in ADR-0059) | issue #734 | owner | none |
| 1 | **Validator**: Ogg Opus magic, bitrate cap 128 kbps, size cap, tests; the optional lint of the `New to English:` lead-in on `sounds`-tagged cards | code, PR to `main` | Sonnet coder; one Sonnet review | 0 (1, 2) |
| 2 | **`tools/fetch_sound_audio.py`** and tests (mocked network and `ffmpeg`), `tools/README.md` and `Deck-Tools` lines, `.cache/sound-audio/` in `.gitignore` | code, PR to `main` | Sonnet coder; review | 0 (3, 8, 9); reuses `import_wiktionary.py` |
| 3 | **App credit line** for sounds audio: the Sources screen line "Recordings from Wikimedia Commons, trimmed, normalised, converted to Ogg Opus" (if not already shown for Wiktionary audio); a check of Ogg Opus on Android and, once iOS is built, on iOS and web | code, PR to `main` | Sonnet coder | 0 (6) |
| 4 | **Pilot: Telugu.** Build `te-sound-inventory` (about 50 cards: 10 vowels short and long, the consonants by place, aspirated and retroflex ones, ṁ, ḥ, ṟ) and its English layer from the existing `te-sounds` contrasts, the Telugu section of the phonology plan and Wikipedia's Telugu phonology; **upgrade the existing deck, never renumber** its cards; move the #736 overview into card notes. Open for a native speaker: శ, ష, స (#736) | `decks-live`, PR | Haiku deck builder; one Sonnet review | none (cards need no audio) |
| 5 | **First fetch run, Telugu**, with `--survey` first; then the real run; PR with the `.opus` files and credits | `decks-live`, PR | Haiku runs the tool; one Sonnet review | 2 |
| 6 | **Group A, the first list (to B1):** Bengali, Hindustani, Marathi, Kannada, Assamese, Spanish, Chinese, Japanese, French; cards, then fetch runs | `decks-live`, one PR per language | Haiku builders; one Sonnet review per PR | 4 pattern accepted; 2 for audio |
| 7 | **Group B, the second list (to A1)** Tamil, Malayalam, Santali, Korean, Afrikaans, Italian, German, Russian, Classical Sanskrit, Greek, Polish; **Group C**: Indonesian, Persian, Pashto, Dutch, Ukrainian and the rest, then the ancient and constructed ones | same | same | 6 |
| 8 | **Phonology source per language**: the language's Wikipedia "X phonology" and `Help:IPA/X` key (CC BY-SA, facts and examples), the language's wiki phonology section where one exists (Telugu's in the phonology plan; the others are the Haiku's first read), and the IPA Association's "Illustration of the IPA" as a cross-check of facts only (the text is copyrighted, never copied). Reviewers are bilingual speakers | part of 4, 6 and 7 | builders | none |
| 9 | **Fetch runs for each group** in a session where the five hosts are allowed and the run is slow; repeated until the report shows nothing new | `decks-live` PRs | Haiku | 2, 6, 7 |
| 10 | Revisit synthesised audio, if the owner asks | later | owner | none |

Repo rules that apply (CLAUDE.md): this plan and the ADR are Markdown, straight to `main`; packages 1, 2, 3 are code and go through a pull request with CI green and one Sonnet review; decks go through a PR to `decks-live`, with "Validate decks" and "Released app reads the decks" green; one Haiku deck builder and one Sonnet coder at a time; no agent runs the tests or the validator locally; no git tags; a new CHANGELOG line only for what a learner can see (the sound cards in an app release, not the audio files). Deck work still yields to coding work, and "Deck work waits for the rest" (2026-10-30) holds until the owner lifts it for the sounds decks (owner decision 11); packages 1 to 3 are coding work and can go first.

### Open questions this plan does not settle

- Whether a language with no phone TTS voice at all (Vedic, Sumerian, Egyptian) gets the sound cards: yes (cards work without audio), but its Listening drill has nothing to play unless a recording was fetched, so Listening is left out of those cards' modes.
- Tone languages: one card per tone, with the tone's contour in the note; the audio, where there is any, comes from the word recordings, not from symbol clips.
- How the English layer is later joined by other native languages: a layer per native language (the format already allows it), the comparison text rewritten for each.

See also: [ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio) · [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology) · [Deck-Format](Deck-Format) · [Plans-Index](Plans-Index) · [Home](Home)
