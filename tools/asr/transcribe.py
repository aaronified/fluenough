"""Reference transcriber: the exact algorithm the Dart listener ports.

Usage: python3 -I transcribe.py <pack dir> <file.wav> [--encoder int8|fp32] [--threads 4]

Steps (each is one Dart file): 16 kHz mono PCM -> log-mel features (np_features.py,
log_mel.dart) -> encoder ONNX (onnxruntime; the only ONNX session) -> the language head
as a matrix multiply -> greedy ids per frame -> collapse repeats, drop blank (the last
class) and <unk>, join pieces, word-start mark to a space (ctc.py, ctc_head.dart and
ctc_decode.dart). Needs numpy and onnxruntime. Prints the text on stdout; timings and
every problem go to the log (stderr).
"""
import argparse
import glob
import logging
import os
import sys
import time
import wave

import numpy as np

log = logging.getLogger("asr.transcribe")

if __package__:
    from . import ctc, np_features
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ctc
    import np_features


def read_wav(path):
    """Read a PCM wav as float32 mono at 16 kHz (linear resampling if needed)."""
    with wave.open(path, "rb") as w:
        n, ch, width, rate = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    if width != 2:
        raise ValueError(f"{path}: only 16-bit PCM wav is supported, got {8 * width}-bit")
    x = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if ch > 1:
        x = x[: len(x) // ch * ch].reshape(-1, ch).mean(axis=1)
    if rate != np_features.SR:
        log.warning("%s: resampling %d Hz to %d Hz (linear)", path, rate, np_features.SR)
        t_new = np.arange(int(len(x) * np_features.SR / rate)) * (rate / np_features.SR)
        x = np.interp(t_new, np.arange(len(x)), x).astype(np.float32)
    return x


def find_pack(pack, language=None):
    """The head's (f32, json) paths in a pack dir; the only head if language is None."""
    js = sorted(glob.glob(os.path.join(pack, "head_*.json")))
    if language:
        js = [p for p in js if os.path.basename(p) == f"head_{language}.json"]
    if len(js) != 1:
        raise FileNotFoundError(
            f"{pack}: want exactly one head_<code>.json{' for ' + language if language else ''}, "
            f"found {len(js)}")
    return js[0][:-5] + ".f32", js[0]


def open_session(pack, encoder="int8", threads=4):
    import onnxruntime as ort
    path = os.path.join(pack, f"encoder.{encoder}.onnx")
    so = ort.SessionOptions()
    so.intra_op_num_threads = threads
    return ort.InferenceSession(path, so, providers=["CPUExecutionProvider"])


def transcribe_samples(session, head, samples):
    """float32 mono 16 kHz samples -> dict(text, confidence, ids, timings)."""
    t0 = time.perf_counter()
    feats, seq = np_features.log_mel(samples)
    t1 = time.perf_counter()
    out = session.run(None, {"features": feats[None, :, :seq],
                             "length": np.array([seq], dtype=np.int64)})
    t2 = time.perf_counter()
    enc, enc_len = out[0][0], int(out[1][0])  # [D, T'], valid frames
    ids, conf = head.apply(enc, enc_len)
    text = ctc.ctc_decode(ids, head.pieces, head.blank)
    t3 = time.perf_counter()
    secs = len(samples) / np_features.SR
    return {"text": text, "confidence": conf, "ids": ids, "audio_s": secs,
            "mel_s": t1 - t0, "encoder_s": t2 - t1, "head_s": t3 - t2,
            "rtf": (t3 - t0) / secs if secs else 0.0}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("pack")
    ap.add_argument("wav")
    ap.add_argument("--encoder", default="int8", choices=["int8", "fp32"])
    ap.add_argument("--lang")
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args(argv)
    try:
        f32, js = find_pack(args.pack, args.lang)
        head = ctc.Head.load(f32, js)
        session = open_session(args.pack, args.encoder, args.threads)
        r = transcribe_samples(session, head, read_wav(args.wav))
        log.info("audio %.2fs, mel %.0f ms, encoder %.0f ms, head %.0f ms, RTF %.3f, "
                 "confidence %.3f", r["audio_s"], r["mel_s"] * 1e3, r["encoder_s"] * 1e3,
                 r["head_s"] * 1e3, r["rtf"], r["confidence"])
        if not r["text"]:
            log.warning("empty transcript for %s", args.wav)
        print(r["text"])
        return 0
    except Exception:
        log.exception("transcribe failed for %s", args.wav)
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main())
