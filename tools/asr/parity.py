"""Parity of the pack (ONNX encoder + numpy head) against NeMo's own model
(needs torch, NeMo and onnxruntime).

Usage: python3 parity.py <file.nemo> <workdir> <pack dir> <code>

Compares NeMo's masked CTC log-probs for the language with the pack's fp32 and int8
encoders plus the head file, on a synthetic 6 s signal. The pack must have been written
with --keep-fp32. Synthetic audio says nothing about word error rate: use eval_wer.py.
"""
import logging
import os
import sys

import numpy as np

log = logging.getLogger("asr.parity")

if __package__:
    from . import ctc, loadmodel, np_features as nf, transcribe
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ctc
    import loadmodel
    import np_features as nf
    import transcribe


def log_softmax(x):
    x = x - x.max(axis=-1, keepdims=True)
    return x - np.log(np.exp(x).sum(axis=-1, keepdims=True))


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    try:
        import torch
        nemo, workdir, pack, code = argv[1:]
        m = loadmodel.load(nemo, workdir)
        rng = np.random.default_rng(3)
        n = 16000 * 6
        t = np.arange(n) / 16000
        wav = (0.2 * np.sin(2 * np.pi * (120 + 40 * np.sin(2 * np.pi * 0.7 * t)) * t)
               * (1 + np.sin(2 * np.pi * 4 * t)) + 0.05 * rng.standard_normal(n)).astype(np.float32)
        f, seq = nf.log_mel(wav)
        with torch.no_grad():
            enc, _ = m.encoder(audio_signal=torch.from_numpy(f)[None], length=torch.tensor([seq]))
            ref = m.ctc_decoder(encoder_output=enc, language_ids=[code])[0].numpy()
        head = ctc.Head.load(*transcribe.find_pack(pack, code))
        out = {}
        for kind in ("fp32", "int8"):
            s = transcribe.open_session(pack, kind)
            e, el = s.run(None, {"features": f[None, :, :seq], "length": np.array([seq], dtype=np.int64)})
            out[kind] = log_softmax(head.logits(e[0])[: int(el[0])])
        for kind, lp in out.items():
            log.info("%s vs NeMo: max abs log-prob diff %g, argmax agree %.3f", kind,
                     np.abs(lp - ref[: len(lp)]).max(),
                     (lp.argmax(-1) == ref[: len(lp)].argmax(-1)).mean())
        log.info("int8 vs fp32: max abs %g, mean abs %g, argmax agree %.3f",
                 np.abs(out["int8"] - out["fp32"]).max(), np.abs(out["int8"] - out["fp32"]).mean(),
                 (out["int8"].argmax(-1) == out["fp32"].argmax(-1)).mean())
        return 0
    except Exception:
        log.exception("parity failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv))
