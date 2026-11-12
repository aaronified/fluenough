# On-device listener reference tools (#1004)

Python reference for the on-device AI listener (AI4Bharat IndicConformer, Telugu first).
The plan is `wiki/Plan-Speech-Offline-Alert.md`, Part 1. These tools make the pack the app
downloads, and `transcribe.py` is **the exact algorithm the Dart code ports** (log-mel,
encoder, head matrix multiply, greedy CTC). No model file is ever committed.

Every script logs every problem with the `logging` module and exits non-zero; none fails
silently. Run any script that reads a downloaded model or audio file as `python3 -I`.

## Dependencies

| Needed for | Packages |
|---|---|
| everything except the encoder export (head, hashes, features, golden fixtures, tests) | `numpy`, `PyYAML` |
| `transcribe.py`, `eval_wer.py`, `bench.py` | plus `onnxruntime` |
| the encoder export (`export_onnx.py`, `quantize.py`, `parity.py`, `check_features.py`) | plus `torch` (CPU), `onnx`, `omegaconf`, `sentencepiece` and AI4Bharat's NeMo fork (branch `nemo-v2`, patched for the HF ModelFilter and PyTorch Lightning), see `loadmodel.py` for `ASR_NEMO_SRC` and `ASR_STUBS` |

The head and the encoder-tensor hashes are read from the `.nemo` **without torch or NeMo**
(`nemo_ckpt.py`: a restricted unpickler that only rebuilds tensors).

## Files

| File | What it is |
|---|---|
| `np_features.py` | numpy log-mel front end, matches NeMo's preprocessor (max diff 5e-5 in the spike; its filterbank and window match the checkpoint's own to 2e-7) |
| `ctc.py` | head slice index, head file I/O, `Head.apply`, `ctc_decode` |
| `nemo_ckpt.py` | torch-free `.nemo` reader and encoder hash |
| `export_pack.py` | `.nemo` to pack (below) |
| `publish_manifest.py` | pack dirs to `asr-manifest.json` (sizes, sha256, `models` release URLs); `--stage DIR` copies the files under their release asset names for the owner to upload |
| `loadmodel.py`, `export_onnx.py`, `quantize.py` | the encoder-only ONNX export and int8 quantisation (spike scripts, generalised) |
| `transcribe.py`, `eval_wer.py` | reference transcriber and the WER/CER scorer |
| `fetch_wiktionary_audio.py` | downloads about 40 Telugu word recordings from Wikimedia Commons (paced, one request at a time, User-Agent, `maxlag`, backoff, request cap) into `name.wav` + `name.txt` pairs and `manifest.json` (author and licence per file); the accuracy test set, so nobody has to record words |
| `golden.py` | writes `test/fixtures/asr/golden_mel.json` and `golden_ctc.json` for the Dart tests |
| `bench.py`, `parity.py`, `check_features.py` | speed, parity against NeMo, front-end check |
| `test_asr_tools.py` | unit tests (CI only): head-slice index on a toy tensor, the `.nemo` reader on a hand-made checkpoint, CTC, golden files, pipeline with a fake encoder |

## Making a pack

```sh
curl -C - -O https://objectstore.e2enetworks.net/indicconformer/models/indicconformer_stt_te_hybrid_rnnt_large.nemo
python3 -I tools/asr/export_pack.py indicconformer_stt_te_hybrid_rnnt_large.nemo out/te \
    --compare indicconformer_stt_bn_hybrid_rnnt_large.nemo --keep-fp32
```

writes `head_te.f32`, `head_te.json`, `encoder.int8.onnx` (and `encoder.fp32.onnx`) and
`pack-report.json` (sizes, sha256, encoder hash and the comparison). The encoder graph takes
`features` `[1,80,T]` and `length`, and gives `encoded` `[1,512,T']` and `encoded_len`
(T' = T/4). `--skip-encoder` writes only the head (exit code 3: torch and NeMo not needed).

Head file: little-endian float32, weights `[257 x 512]` row-major, then bias `[257]`. The
JSON holds `pieces` (256), `blank` (256, the last class), `dim`, `vocab`. Telugu is rows
5120 to 5375 of the model's 5633-class CTC layer plus the blank (row 5632); the languages
are 256 classes each, in the config's `tokenizer.langs` order.

## Using it

```sh
python3 -I tools/asr/transcribe.py out/te sample.wav            # prints the text
python3 -I tools/asr/eval_wer.py recordings/ --pack out/te      # WER and CER, int8 and fp32
python3 -I tools/asr/bench.py out/te int8
python3 tools/asr/golden.py                                     # rewrite the fixtures
```

`recordings/` holds `name.wav` (16-bit PCM) and `name.txt` (the reference) pairs.

## Finding: the encoder is NOT shared between languages

Measured 2026-11-11: the Telugu and Bengali `.nemo` files have the same structure (22
language heads, 686 encoder tensors) but **no tensor is equal** (all 686 encoder tensors,
the CTC layer, the decoder and the joint differ; only the preprocessor matches). Each
`.nemo` is a separately fine-tuned model, so the plan's "one shared encoder plus a 1 MB
head per language" does not hold for these checkpoints: each language needs its own
encoder (about 135 MB int8). Only the log-mel front end is common. The 22-language
HF repository model may differ; it is gated and not used here.

## Accuracy test set from Wikimedia Commons

`fetch_wiktionary_audio.py <folder> --limit 40` makes the folder `eval_wer.py` scores. The
recordings are CC BY-SA (credit in `manifest.json`): **never commit them**; the
`asr-export` workflow only puts them in its `asr-eval-<lang>` artifact and prints WER, CER
and the ten worst words in the job summary. Files whose title has no Telugu-script word are
skipped and logged. The default categories (`Category:Telugu pronunciation`,
`Category:Lingua Libre pronunciation-tel`) and the title patterns (`Te-<word>.ogg`,
`LL-Q8097 (tel)-<speaker>-<word>.wav`) are from memory, not yet confirmed against the API
(the session's IP was rate limited); the first run logs what each category returns, and
`--category` overrides them. Needs `ffmpeg`.
