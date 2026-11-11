"""Load an IndicConformer .nemo into NeMo (needs torch and AI4Bharat's NeMo fork).

Only the encoder export, parity.py and check_features.py need this; everything else in
tools/asr works without torch. Where NeMo lives is given by environment variables:

  ASR_NEMO_SRC   folder of AI4Bharat's NeMo fork, branch nemo-v2 (added to sys.path)
  ASR_STUBS      optional folder of stub modules for heavy imports the model does not need
                 (transformers, inflect, pyannote, ...); added first and `autostub` imported

Usage: python3 loadmodel.py <file.nemo> <workdir>   (prints parameter counts)
"""
import logging
import os
import sys
import tarfile

log = logging.getLogger("asr.loadmodel")


def _setup_path():
    for var in ("ASR_NEMO_SRC", "ASR_STUBS"):
        p = os.environ.get(var)
        if p:
            sys.path.insert(0, p)
    if os.environ.get("ASR_STUBS"):
        import autostub  # noqa: F401


def load(nemo_path, workdir):
    """Unpack nemo_path into workdir and return the model in eval mode."""
    _setup_path()
    import torch
    from omegaconf import OmegaConf
    from nemo.collections.asr.models import EncDecHybridRNNTCTCBPEModel

    os.makedirs(workdir, exist_ok=True)
    with tarfile.open(nemo_path) as tf:
        tf.extractall(workdir, filter="data")
    cfg = OmegaConf.load(os.path.join(workdir, "model_config.yaml"))

    def walk(o):
        if isinstance(o, dict):
            return {k: walk(v) for k, v in o.items()}
        if isinstance(o, list):
            return [walk(v) for v in o]
        if isinstance(o, str) and o.startswith("nemo:"):
            return os.path.join(workdir, o[5:])
        return o

    cfg = OmegaConf.create(walk(OmegaConf.to_container(cfg, resolve=False)))
    cfg.train_ds = None
    cfg.validation_ds = None
    cfg.test_ds = None
    model = EncDecHybridRNNTCTCBPEModel(cfg=cfg.model if "model" in cfg else cfg, trainer=None)
    sd = torch.load(os.path.join(workdir, "model_weights.ckpt"), map_location="cpu")
    log.info("load_state_dict: %s", model.load_state_dict(sd, strict=False))
    return model.eval()


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        m = load(argv[1], argv[2])
        enc = sum(p.numel() for p in m.encoder.parameters()) / 1e6
        log.info("%s, encoder %.1f M params", type(m.preprocessor).__name__, enc)
        return 0
    except Exception:
        log.exception("could not load %s", argv[1])
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv))
