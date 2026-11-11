"""Latency and peak memory of a pack's encoder on synthetic audio (no speech needed).

Usage: python3 -I bench.py <pack dir> [int8|fp32] [--threads 4]

Prints, for 3, 10 and 20 s of audio, the median features and encoder times and the real
time factor (seconds of work per second of audio), then the peak RSS. Needs numpy and
onnxruntime.
"""
import argparse
import logging
import os
import resource
import sys
import time

import numpy as np

log = logging.getLogger("asr.bench")

if __package__:
    from . import np_features, transcribe
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import np_features
    import transcribe


def synthetic(sec):
    n = int(sec * 16000)
    t = np.arange(n) / 16000
    rng = np.random.default_rng(1)
    return (0.2 * np.sin(2 * np.pi * 150 * t) * (1 + np.sin(2 * np.pi * 4 * t))
            + 0.05 * rng.standard_normal(n)).astype(np.float32)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pack")
    ap.add_argument("kind", nargs="?", default="int8", choices=["int8", "fp32"])
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args(argv)
    try:
        s = transcribe.open_session(args.pack, args.kind, args.threads)
        for sec in (3, 10, 20):
            w = synthetic(sec)
            t0 = time.perf_counter()
            f, seq = np_features.log_mel(w)
            tf = time.perf_counter() - t0
            feed = {"features": f[None, :, :seq], "length": np.array([seq], dtype=np.int64)}
            s.run(None, feed)  # warm up
            ts = []
            for _ in range(3):
                t0 = time.perf_counter()
                s.run(None, feed)
                ts.append(time.perf_counter() - t0)
            m = float(np.median(ts))
            log.info("%s %2ds audio: features %.0f ms, encoder %.0f ms, RTF %.3f", args.kind,
                     sec, tf * 1e3, m * 1e3, (m + tf) / sec)
        log.info("%s peak RSS %.0f MB", args.kind,
                 resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
        return 0
    except Exception:
        log.exception("bench failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main())
