# Telugu ASR spike (issue #1004): WIP files

**WIP files, to be moved into the tools/ harness PR next week and this README deleted (owner 2026-11-04).**

## What this is

The 2026-11-04 Telugu IndicConformer export spike for issue #1004. It exports
the Telugu CTC head of AI4Bharat's IndicConformer hybrid model to ONNX and
measures size and speed. The scripts here were saved from the session scratch
folder so they survive the session. The model files did not come with them.

## Findings

- The CTC path exports to ONNX at opset 17.
- Size: fp32 482 MB; int8 dynamic quantization 137.6 MB.
- The numpy log-mel front end (`np_features.py`) matches NeMo's preprocessor
  to 5e-5 (`check_features.py`).
- Latency on 4 threads, CPU: 0.04 to 0.05 s per audio-second fp32; 0.07 to
  0.08 s per audio-second int8. `bench.py` uses synthetic audio.
- WER was NOT measured, because the FLEURS audio was blocked.

## Environment needed

- Python with conda-forge CPU PyTorch, installed via micromamba. Exact package
  list not recorded; it needs torch, onnx, onnxruntime, numpy, omegaconf,
  sentencepiece and the NeMo dependencies.
- AI4Bharat's NeMo fork, `nemo-v2` branch, patched for HF ModelFilter and
  PyTorch Lightning compatibility. Placed at `<spike>/nemo-src/`.
- Heavy imports that the model does not need are stubbed, not installed:
  `transformers`, `inflect`, and the modules listed in `stubs/autostub.py`
  (pyannote, sox, matplotlib, wandb and others). The stubs live in
  `<spike>/stubs/` (`autostub.py`, `transformers/`, `inflect/`). They are not
  copied here.

## Where the large files lived

Session-local, lost when the session ends:

- Scratch folder: `/tmp/claude-0/-home-user-fluenough/36df90c5-87d5-5cb6-91b9-a673477cc6e4/scratchpad/asr-spike/`
- `out/te_ctc_fp32.onnx` (482 MB), `out/te_ctc_int8.onnx` (138 MB)
- The `.nemo` checkpoint, from
  https://objectstore.e2enetworks.net/indicconformer/models/indicconformer_stt_te_hybrid_rnnt_large.nemo
  The scripts expect it unpacked into `<spike>/x/` (`model_config.yaml`,
  `model_weights.ckpt`). That folder was not present in the scratch copy.

To rebuild, get the `.nemo`, unpack it, and run the commands below.

## Files here

- `scripts/`: `np_features.py`, `loadmodel.py`, `export_onnx.py`,
  `quantize.py`, `bench.py`, `parity.py`, `check_features.py`
- `te_vocab.json`: the Telugu SentencePiece pieces and CTC columns, written by
  `export_onnx.py`

Layout the scripts assume: `<spike>/scripts/`, `<spike>/out/`, `<spike>/x/`,
`<spike>/stubs/`, `<spike>/nemo-src/`. Each script sets its root to the
folder above `scripts/`.

## Commands, in order (reconstructed from the script headers, not a recorded log)

```sh
# 0. Unpack the .nemo into <spike>/x/ (model_config.yaml, model_weights.ckpt)
tar -xf indicconformer_stt_te_hybrid_rnnt_large.nemo -C <spike>/x

# 1. Load the model and print parameter counts (sanity check)
python scripts/loadmodel.py

# 2. Check the numpy front end against NeMo's preprocessor
python scripts/check_features.py

# 3. Export the Telugu CTC head to ONNX (writes out/te_ctc_fp32.onnx and out/te_vocab.json)
python scripts/export_onnx.py

# 4. Int8 dynamic quantization (writes out/te_ctc_int8.onnx)
python scripts/quantize.py

# 5. Parity: NeMo vs ONNX fp32 vs int8 log-probs
python scripts/parity.py

# 6. Latency and peak RSS, synthetic audio
python scripts/bench.py fp32
python scripts/bench.py int8
```
