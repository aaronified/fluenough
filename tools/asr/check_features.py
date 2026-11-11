"""Check np_features.py against NeMo's own preprocessor (needs torch and NeMo, loadmodel.py).

Usage: python3 check_features.py <file.nemo> <workdir>

Spike result (2026-11-04): max difference 5e-5 on the valid frames.
"""
import logging
import os
import sys

import numpy as np

log = logging.getLogger("asr.check_features")

if __package__:
    from . import loadmodel, np_features as nf
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import loadmodel
    import np_features as nf


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        import torch
        pre = loadmodel.load(argv[1], argv[2]).preprocessor
        log.info("fb max abs diff vs NeMo: %g",
                 np.abs(pre.featurizer.fb[0].numpy() - nf._FB).max())
        log.info("window diff: %g", np.abs(pre.featurizer.window.numpy() - nf._WINDOW[56:456]).max())
        rng = np.random.default_rng(0)
        for n in (16000, 47000, 80000):
            t = np.arange(n) / 16000
            wav = (0.3 * np.sin(2 * np.pi * 220 * t) * (1 + np.sin(2 * np.pi * 3 * t))
                   + 0.05 * rng.standard_normal(n)).astype(np.float32)
            ref, ref_len = pre(input_signal=torch.from_numpy(wav)[None], length=torch.tensor([n]))
            mine, seq = nf.log_mel(wav)
            d = np.abs(ref[0].numpy()[:, :seq] - mine[:, :seq])
            log.info("%d samples: NeMo %s, mine %s, valid %d/%d, max diff %g, mean %g", n,
                     tuple(ref.shape), mine.shape, int(ref_len[0]), seq, d.max(), d.mean())
        return 0
    except Exception:
        log.exception("check_features failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv))
