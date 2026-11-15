# Plan: say when speech can't be recognised offline

> **Update (owner, 2026-11-11):** the 2026-11-07 hold is lifted. Build the on-device AI listener with AI4Bharat's IndicConformer, for all the languages it covers, starting with Telugu (`te-IN`). It becomes the primary Say listener once it works; the system recogniser stays as the fallback (#1004; the system recogniser fails on the owner's phone with `error_no_match` on every Say since 0.9.4, #1107). The plan is in Part 1; the older "alert when the phone cannot recognise a language offline" plan is kept in Part 2.

Source of truth: this wiki page.

# Part 1: the on-device AI listener (#1004), plan of 2026-11-11

Research and design; slice 1 tools are in PR #1114. Sources were read on 2026-11-11; what could not be checked is marked **Unverified**.

## 1. Feasibility

| Question | Finding | Source |
|---|---|---|
| Model | AI4Bharat IndicConformer, a Conformer-based **hybrid CTC + RNNT** model, 22 Indian languages in one model ("IndicConformer-600M-Multi", 600M parameters). **Measured 2026-11-11 (PR #1114): the per-language `.nemo` checkpoints we can download are NOT that shared model**; see the finding below. | [HF model card](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) |
| Licence | Weights **MIT** (card: "released under the MIT license"; HF metadata `license: mit`). onnxruntime and onnxruntime-android: MIT. Training data IndicVoices: CC-BY-4.0, credit it. MIT permits bundling and downloading with the notice kept. Not verified: the licences of every training corpus. | [card](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual), [AI4Bharat/IndicConformerASR](https://github.com/AI4Bharat/IndicConformerASR) |
| Languages (22) | as, bn, brx, doi, gu, hi, kn, kok, ks, mai, ml, mni, mr, ne, or, pa, sa, sat, sd, ta, **te**, ur | card |
| HF copy | Gated (`gated: auto`). The card text is public but the files return **401** to an anonymous client (checked on `assets/vocab.json`). Its ONNX export is also unsuited: 2.5 GB fp32 in about 400 external-weight files. So the app cannot download from Hugging Face. | HF API tree and `curl`, 2026-11-11 |
| Source we use | The per-language `.nemo` checkpoints, no login: `https://objectstore.e2enetworks.net/indicconformer/models/indicconformer_stt_<code>_hybrid_rnnt_large.nemo`. Checked: HTTP 200, 523,192,320 bytes for `te`. | `curl -I` |
| Newer model | The card now says Indic-Transcribe (`bodhan-ai/indic-transcribe-core`) has "better transcription quality" and is recommended. Its licence is `other` (Indic Open Model License, gated form asking for the use case), so it is **not** MIT and is not used here. | [card](https://huggingface.co/bodhan-ai/indic-transcribe-core) |
| Input | 16 kHz mono. Log-mel front end (spike; our numpy port matches NeMo to 5e-5): 25 ms Hann window, 10 ms hop, n_fft 512, 80 slaney mels, preemphasis 0.97, `log(x + 2^-24)`, per-feature mean/std normalisation over the utterance. | #1004 comment, 2026-11-02 |
| Decoding | CTC greedy is enough for a word or short phrase. RNNT is more accurate but needs a greedy loop with prediction and joint networks (HF `rnnt_decoder.onnx` is 40.7 MB fp32, plus per-language joint nets): later. Vocab: 22 x 256 SentencePiece pieces plus a blank, so Telugu is a 257-way slice of a 5633-class layer. (HF's multilingual `ctc_decoder.onnx` is 23,095,918 bytes, which equals 5633 x 1024 x 4: that is the 600M multilingual model, width 1024, not these per-language 512-wide files.) | spike; HF tree |
| Size | Telugu CTC path: fp32 482 MB, **int8 dynamic 137.6 MB** (measured). **Each language has its own encoder, so every language costs about 135 MB int8** (to be measured per language by the `asr-export` workflow, PR #1115). Only the log-mel front end is common. | spike, #1114 |
| **Finding: no shared encoder** | Telugu and Bengali `.nemo` files have the same structure (22 language heads, 686 encoder tensors) but **share no tensors: 0 of 686 match**; the CTC layer, decoder and joint differ too, only the preprocessor matches. Encoder width is **512, not 1024**. The Telugu CTC head is **257 x 512**: rows 5120 to 5375 of the 5633-class layer plus the blank row 5632. Each `.nemo` is a separately fine-tuned model. | #1114 report, `tools/asr/README.md` |
| Speed and RAM | Measured on a desktop CPU, 4 threads, synthetic audio, features included: fp32 0.04 to 0.05 s per audio second, 1.06 GB peak; int8 0.07 to 0.08 s per audio second, 0.75 GB peak. A mid-range Android phone is **Unverified**; a guess is 3 to 5 times slower (a 3 s answer in 1 to 2 s) and 0.75 GB peak RAM, the main risk on 3 to 4 GB phones. | spike |
| Accuracy | **Unverified.** No WER or CER for fp32 or int8: FLEURS audio is behind `us.aws.cdn.hf.co`, which the session proxy answers with 403 (re-checked 2026-11-11). int8 versus fp32 argmax agreement on synthetic noise was 92.7 %, which says nothing about WER. The vowel-length check (#1001) is also not done. | |
| Network from the session | `huggingface.co` card and API: reachable (200). HF file CDN: 403. `objectstore.e2enetworks.net`, `pub.dev`, Maven Central: reachable. No big file was downloaded. | `curl -sI` |
| Our languages covered | Yes: te, bn, mr, kn, as, hi, ta, ml, sat, sa, ur (the Urdu script of Hindustani). **No:** es, fr, zh, ja, ko, it, de, ru, pl, el, af, fa, ps, nl, uk, id, en. "All languages" needs a second model family later (risk 3); the code must not assume IndicConformer only. | card |

## 2. Runtime choice

| Option | For | Against |
|---|---|---|
| **A. Kotlin platform channel on `onnxruntime-android` (recommended)** | The project already generates its Kotlin in `tools/brand_android.py` (a native listen channel exists there). One Maven line, `com.microsoft.onnxruntime:onnxruntime-android` (latest on Maven Central is 1.31.1); no new Dart dependency, no iOS or web baggage. Inference runs off the UI thread. Only floats cross the channel (80 x frames x 4 bytes, about 250 KB for 8 s). | `brand_android.py` must also add the Gradle dependency (it already edits `android/app/build.gradle.kts` for desugaring) and a `proguard-rules.pro` rule `-keep class ai.onnxruntime.** { *; }`. Android only; iOS later needs its own. |
| B. `flutter_onnxruntime` 1.9.0 (2026-10-06) | Dart API, no Kotlin. Android minSdk 21, bundles ORT 1.28.0. | Pulls in `path_provider`, `web`, `flutter_web_plugins`; iOS needs 16 and static linkage; we cannot choose the ORT version; larger surface to audit. |
| C. `onnxruntime` (gtbluesky, FFI) 1.4.1 | Dart API. | Old, not kept in step with ORT. |

**Decision: A.** The repo rule is built-ins first and few dependencies, and the Kotlin is already generated and tested (`tools/test_brand_android.py`). Impact: ORT's own minSdk (**Unverified**: read the AAR's `AndroidManifest.xml` in task 5; plugin B declares 21, recent ORT AARs may need 24), and an APK increase of roughly 15 to 20 MB per ABI (**Unverified**). Keep the Dart side behind an `AsrRuntime` interface so B or an iOS runtime can replace it without touching the engine.

## 3. Architecture

```
lib/core/speech/asr/              pure Dart, no Flutter imports
  asr_runtime.dart        interface AsrRuntime { load(modelPath, threads); run(feats, frames) -> encoder output; close() } + FakeAsrRuntime
  log_mel.dart            int16 PCM -> [frames x 80], own radix-2 FFT (n_fft 512), no dependency
  ctc_head.dart           per-language head: weights [vocab x D] + bias; apply -> ids + mean confidence
  ctc_decode.dart         collapse repeats, drop blank (last index), join SentencePiece pieces
  endpointer.dart         energy end-of-speech detector over PCM chunks
  pcm_recorder.dart       interface for a PCM stream
  asr_pack.dart           AsrManifest, AsrPackStatus, AsrPackStore (interface)
  on_device_speech_engine.dart   OnDeviceSpeechEngine implements SpeechEngine
  preferred_speech_engine.dart   PreferOnDeviceSpeechEngine(onDevice, system)
lib/app/                          may import Flutter and dart:io
  channel_asr_runtime.dart        MethodChannel 'app.fluenough/asr' to the Kotlin side
  asr_pack_downloader.dart        HTTP download, Range resume, sha256, delete
  file_asr_pack_store.dart        files dir layout
```

- **Pack layout (per language)**, under the app files dir `asr/<packVersion>/<code>/`: `encoder.int8.onnx` (that language's own encoder, about 135 MB), `head_<code>.f32` (little-endian float32: `[257 x 512]` weights, then bias `[257]`) and `head_<code>.json` (`pieces`, `blank`, `dim` 512). A language is installed when its encoder and head are present and their sha256 match the manifest. Nothing is shared between languages except the Dart front end.
- **Manifest** `asr-manifest.json` beside the assets: `{packVersion, languages: [{code, files: [{name, bytes, sha256, url, kind: encoder|head}]}]}`. The app reads it first and shows the sizes. Hosting: GitHub release assets of a `models` release (a file may be up to 2 GiB). It needs a tag, so **the owner creates the `models` release** (CLAUDE.md: no agent tags).
- **The head stays outside the ONNX graph.** The encoder is the only ORT session. The head (a 1x1 conv, 512 x 257) is a matrix multiply in Dart: about 13 M multiply-adds for 100 frames, trivial, and unit-testable in pure Dart. This no longer makes a language cheap: the encoder is per language (measured, 0 of 686 tensors shared between Telugu and Bengali). The 22-language model on Hugging Face may share one, but it is gated and 2.5 GB fp32, so it is not used here; see the owner question in section 5.
- **Listening.** `OnDeviceSpeechEngine.listen`: a `PcmRecorder` (interface; implemented with the existing `record` package, `startStream` pcm16 16 kHz mono as `RecordMicCapture` does) gives a stream; the `Endpointer` stops after speech began and about 1.0 s of quiet, or at `listenFor` (default 8 s); then `log_mel`, the runtime's `run`, the head and the CTC decode. It returns `SpeechHeard([SpeechAlternative(text, confidence: meanMaxProb)], ownAudio: OwnAudio(pcm))`, so **"Your recording" replay (ADR-0054, #881) works from the same take, with no second recorder**.
- **Failures** never throw out and every one goes to the app log with code, language, durations and pack version. No pack: `SpeechFailure.notOnDevice`, code `asr_no_pack`. Model fails to load or run: `SpeechFailure.other`, code `asr_runtime_error` (falls back). Empty transcript: `noMatch`, code `asr_empty` (no fallback: second-guessing a silent take with the system recogniser is what is broken today). Microphone refused: `permissionDenied`.
- **Engine order.** `PreferOnDeviceSpeechEngine`: `languages()` is the installed on-device languages plus the system's. `listen(bcp47)`: if a pack for the primary subtag is installed and the AI listener is on, use it; on `asr_runtime_error` only, fall back to the system engine; otherwise the system engine as today. For an installed language the app never asks about going online. `lib/main.dart` wraps `SystemSpeechEngine`; the web build keeps `WebSpeechEngine`. `AppState.speechStatus` already treats a language in `languages()` as on-device, so drill logic does not change.
- **Settings.** The Speaking part of each language card on the Voices page gets an "AI listener" row: "Not installed, about 135 MB" with **Install**, progress with **Cancel**, then "Installed" with **Remove**; every language shows its own size (no shared model) and the page shows the total installed. A switch "Use the AI listener first" (on once installed). A mockup per `docs/mockups/README.md` comes first; the owner said not to stop for confirmation, so the orchestrator picks the default and records it. Strings go through l10n (`tools/check_ui_strings.py`).
- **Offline.** After install it needs no network. Install needs one.
- **Tests (CI only).** Pure Dart: `log_mel` against a golden vector (first frames of a deterministic synthetic signal from the python reference in `tools/asr/`, tolerance 1e-3); `ctc_head` and `ctc_decode` on a tiny fixture (3 pieces, 6 frames, with repeats and blanks); `endpointer` on synthetic PCM; manifest parsing; checksum failure; the engine with `FakeAsrRuntime` and a fake `PcmRecorder` (success, empty, runtime error falls back, no pack); `tools/test_brand_android.py` string checks for the Kotlin.

## 4. Tasks, in dependency order

Haiku-suitable = **H**, Sonnet only = **S**. One PR each (CI is the only test run), no change outside the named files, `lib/core` stays Flutter-free. Model exports run in the manual `asr-export` workflow (PR #1115, `workflow_dispatch`, no secrets), because the sandbox cannot export; the pack is downloaded from the run's artifact.

**Slice 1: prove Telugu before any UI.**

| # | Task | Files | Behaviour and tests | Who |
|---|---|---|---|---|
| 1 | Move the spike into a harness; split the pack (done, #1114). | `tools/asr/` (from branch `wip/asr-spike-telugu`: `np_features.py`, `loadmodel.py`, `export_onnx.py`, `quantize.py`, `bench.py`, `parity.py`), new `tools/asr/export_pack.py`, `tools/asr/README.md` | `export_pack.py <nemo> <out>` writes `encoder.int8.onnx` (encoder only: features `[1,80,T]` and length in, `[1,D,T']` out) and `head_<code>.f32` and `.json`. Hashed the encoder tensors of two languages' `.nemo`: not equal (0 of 686), so the pack is per language. No model files committed. Python unit test of the head-slice index on a toy tensor. | S |
| 2 | Python reference transcriber and scorer: **the accuracy gate**. | `tools/asr/transcribe.py`, `eval_wer.py`, `golden.py`, `test/fixtures/asr/golden_mel.json`, `golden_ctc.json` | `transcribe.py <pack> <wav>` prints Telugu text using onnxruntime, numpy features, the head file and greedy CTC: the exact algorithm Dart ports. `eval_wer.py <folder of wav+txt>` prints WER and CER, int8 versus fp32. `golden.py` writes the two fixtures. The owner records about 20 Telugu words and runs it before any UI is built. | `transcribe.py` S; the others H |
| 3 | Pure-Dart front end. | `lib/core/speech/asr/log_mel.dart`, `test/core/speech/asr/log_mel_test.dart` | `List<Float32List> logMel(Uint8List pcm16le)`, constants as above, own radix-2 FFT, normalisation epsilon as in `np_features.py`. Test against `golden_mel.json`; empty and shorter than one window. | H (spec: `np_features.py`) |
| 4 | Pure-Dart head and CTC decode. | `lib/core/speech/asr/ctc_head.dart`, `ctc_decode.dart`, tests | `CtcHead.fromBytes(f32, json)`; `apply(encoderOut)` gives ids and `meanConfidence`; `decode(ids, pieces, blank)` collapses and joins (`▁` to space). Tests on `golden_ctc.json`, repeated ids, blank-separated repeats, empty. | H |

**Slice 2: the app runs it.**

| # | Task | Files | Behaviour and tests | Who |
|---|---|---|---|---|
| 5 | Kotlin ORT channel. | `tools/brand_android.py`, `tools/test_brand_android.py` | Gradle `implementation` line (version pinned), proguard rule, `AsrChannel` in the generated Kotlin: `load(path, threads)` (one OrtSession from file), `run(featuresBytes, frames)` on a background thread returning bytes and dims, `close()`. Reports the AAR's minSdk and raises the project's only if needed. Idempotent like the existing steps; tests assert strings and idempotence. | S |
| 6 | Runtime interface and client. | `lib/core/speech/asr/asr_runtime.dart`, `lib/app/channel_asr_runtime.dart`, tests | Interface and `FakeAsrRuntime` (H). Channel client mapping `PlatformException` to `AsrError(code)`, tested with a mock `MethodChannel` (S). | H and S |
| 7 | Endpointer and recorder. | `lib/core/speech/asr/endpointer.dart`, `pcm_recorder.dart`, `lib/core/speech/record_pcm_recorder.dart`, tests | `Endpointer(sampleRate, quietFor 1.0 s, maxLength)`: feed chunks, reports `speechStarted` and `done`; tests on silence, burst then silence, never-speech timeout. | H |
| 8 | `OnDeviceSpeechEngine`. | `lib/core/speech/asr/on_device_speech_engine.dart`, `asr_pack.dart`, tests | Listening and failures as in section 3; returns `ownAudio`; every outcome calls an injected `void Function(String)` logger. Tests with fakes: success text and audio, empty, runtime error code, no pack, permission refused, stop during listen. | S |
| 9 | `PreferOnDeviceSpeechEngine` and wiring. | `lib/core/speech/asr/preferred_speech_engine.dart`, `lib/main.dart`, tests | Order and fallback as above. Tests: installed pack uses on-device only; runtime error falls back once; no pack uses system; `start()` and `hasPermission()` delegate. | S |

**Slice 3: packs and settings.**

| # | Task | Files | Behaviour | Who |
|---|---|---|---|---|
| 10 | Pack store and downloader (per language, about 135 MB each). | `lib/app/file_asr_pack_store.dart`, `asr_pack_downloader.dart`, `pubspec.yaml` (add `crypto`, dart.dev, for sha256), tests with a local `HttpServer` | Fetch manifest; per language download encoder and head to `*.part` with `Range` resume; verify sha256; rename; delete a language (frees its 135 MB); free-space check against the language's size; cancel; progress stream; failures to the app log. | S |
| 11 | Manifest publisher. | `tools/asr/publish_manifest.py` | From one or more per-language pack dirs, writes `asr-manifest.json` (per language: sizes, sha256, release URLs). The owner creates the `models` release and uploads one encoder per language (about 135 MB each). | H |
| 12 | Voices page row and mockup. | `docs/mockups/ai-listener.html` and `.md`, `lib/features/settings/voices_page.dart`, `lib/l10n/*`, `AppState` pack getters and install and remove calls | States: not installed, downloading, installed, failed; the per-language size and total installed; the switch; 1.4x text; Telugu and Bengali examples. Widget tests for each state and the calls, with a fake store. | S |
| 13 | Licences and credit. | the licences screen data (`grep -rn "licen" lib/features/settings`) | Add onnxruntime (MIT), AI4Bharat IndicConformer (MIT), IndicVoices (CC-BY-4.0). | H |
| 14 | All other languages (each a full pack). | `tools/asr/languages.json` (our code to AI4Bharat code, and each `.nemo` URL), a test that every code in it is in `assets/languages.yaml` | Mapping te, bn, hi, ur, mr, kn, as, ta, ml, sat, sa, pa, gu, or, ne and the rest; `hi` uses `ur` for a learner who chose the Perso-Arabic script. Each language is exported by running the `asr-export` workflow with its `lang` and `nemo_url` (about 135 MB int8 each, measured by the run) and published as its own pack; there is no head-only language. Order by learner demand, not all 22 at once. Mapping and test (H); running the exports (S). | H and S |

**Slice 4: verify.**

| # | Task | Behaviour | Who |
|---|---|---|---|
| 15 | On-device timing. | The engine logs load, mel and encoder times, audio length and real-time factor of every listen to the app log; the owner pastes them in #1004. Decide int8 versus fp32 or static quantisation from slice 1's WER and this RTF. | H |
| 16 | Docs. | CHANGELOG line in each PR; an ADR "On-device AI listener" once task 2 shows accuracy. | H |

## 5. Risks and open questions for the owner

1. **Accuracy is unmeasured**, int8 and short versus long vowels especially. Slice 1 measures it before any UI. Set the bar (for example WER under 25 % on 20 words you record).
2. **Size and RAM:** about 135 MB download **per language** (no sharing: three languages is about 400 MB of storage) and 0.75 GB peak RAM (desktop numbers, one encoder loaded at a time). A 3 GB phone may kill the app. Mitigation: load on first listen, release after 60 s idle.
3. **"All languages":** IndicConformer covers 22 Indian languages only. es, fr, zh, ja, ko, it, de, ru, pl, el, af, fa, ps, nl, uk and id need another model family (Whisper-class or sherpa-onnx). Which first? The code takes a per-language model spec, so it is additive.
4. **Hosting needs a `models` release tag** from the owner; the assets are our own int8 conversion of MIT weights (MIT allows redistribution).
5. **Indic-Transcribe** (newer, better per its card) has a gated non-MIT licence: consider it?
6. **RNNT** later if CTC int8 is not good enough.
7. **Fallback rule:** an empty AI transcript is a no-match and is not retried with the system recogniser. Change it if you want the second opinion.
8. **#1107** (system recogniser `error_no_match`) stays a separate bug; this replaces that path for covered languages, it does not fix it.
9. **Unverified:** ORT minSdk and APK growth, phone RTF and RAM, the int8 size of each language other than Telugu (the `asr-export` workflow measures it), other training-data licences. ("All `.nemo` files share one encoder" is now disproved.)
10. **Question for the owner: per-language packs or the multilingual model?** Each per-language model is its own about 135 MB encoder, so a learner of three languages downloads about 400 MB. The alternative is the multilingual 600M model as **one** pack covering all 22 languages (shared encoder, width 1024, about 1 MB head per language). Its size is **to check**: the Hugging Face ONNX export is 2.5 GB fp32 in about 400 external-weight files, int8 of the whole model is likely several hundred MB, and its files are gated (401), so we would have to export it ourselves from the gated checkpoint (not possible without HF access). Options: (a) per-language packs only, about 135 MB each, simple and available now; downside, cost grows with each language. (b) the multilingual model as one pack, cheaper from the second language on; downside, a larger first download, a gated source we cannot fetch today, and unmeasured accuracy. (c) both. Default taken meanwhile: (a), the code keeps the pack layout per language so (b) can be added.

---

# Part 2: the alert when speech cannot be recognised offline (2026-10-05)

Written 2026-10-05.

See also (2026-11-04): on-device Telugu speech recognition (#1004, aimed at 0.9.0, opt-in) would recognise offline for Telugu without the system recogniser; the alert here still applies to every language it does not cover. (Update 2026-11-07: #1004 is not built; there is no on-device recogniser in the code yet, and the alert and the Today line planned here are not in the code either (tracker #233); what exists is the ask before audio goes online, `lib/features/placement/online_speech_ask.dart`, and the Voices page's "Only online" row.)

## What the owner asked

> also, the app doesnt outright tell me that my voice recognition is not
> working offline for my chosen language. there should be an alert that
> takes me to the settings page.

Asked whether to build it now or plan it, the owner chose to plan it.

## What exists

- `AppState.speechStatus(language)` already knows the answer. For a
  language the phone's recogniser does not list, Android 13 and later list
  only on-device languages, so the status is `onlineOnly`. Until the learner
  allows online recognition, `canHear` is false.
- Then every speaking question in that language is left out of lessons and
  reviews, without a word.
- Where it is said today:
  - the Voices page shows "Only online. Allow it to send what you say to
    your phone's speech service";
  - a deck's page shows its Speaking row greyed, with "Set up voice".

  A learner has to go looking for either.
- The drill asks about going online only when a listen finds that a
  *listed* language cannot be heard on the device. Never for one the
  recogniser did not list.

## What it takes

1. **The alert.** When speaking is on and a language being learnt is
   `onlineOnly` or `missing`, the app says so the first time a session would
   have asked it a speaking question:
   - "Your phone can't recognise Telugu offline, so speaking questions are
     skipped."
   - **Open settings** goes to the Voices page, at that language's row.
   - **Not now** closes it.
2. **Once per language**, until its status changes. A setting remembers
   when it was shown. Whether it comes back later is to decide.
3. **On Today, while it lasts:** a line under the session card says the
   same, with the same button.
4. **Missing**, where the phone can't recognise the language at all, even
   online, says so plainly, and points to Settings > Learning > Speaking to
   switch speaking off for that language.
5. **Tests** for each status, the once-per-language rule, the line on
   Today, and the button opening the right row.

## To decide

- The alert's place: when a session starts, or on Today at launch.
- How often it comes back: weekly, never, or each launch.

## Estimate

About 2–3 hours. Confidence: medium. It needs a check on a phone whose
recogniser lacks the language.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
