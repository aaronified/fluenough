"""Export the shared encoder of an IndicConformer .nemo to ONNX (needs torch and NeMo).

The graph is the encoder alone: `features` [B,80,T] (normalised log-mel, np_features.py)
and `length` [B] int64 in; `encoded` [B,D,T'] and `encoded_len` [B] out (T' = T/4, D = 512).
The per-language head is not in the graph (export_pack.py writes it as a file).

Usage: python3 export_onnx.py <file.nemo> <out.onnx> <workdir>
"""
import logging
import sys

log = logging.getLogger("asr.export_onnx")

if __package__:
    from . import loadmodel
else:
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import loadmodel


def export_encoder(nemo_path, out_path, workdir):
    import torch
    model = loadmodel.load(nemo_path, workdir)

    class EncoderOnly(torch.nn.Module):
        def __init__(self, enc):
            super().__init__()
            self.enc = enc

        def forward(self, features, length):
            return self.enc(audio_signal=features, length=length)

    wrapper = EncoderOnly(model.encoder).eval()
    x = torch.randn(1, 80, 400)
    n = torch.tensor([400])
    with torch.no_grad():
        ref, ref_len = wrapper(x, n)
        log.info("encoder output %s, length %s", tuple(ref.shape), ref_len.tolist())
        torch.onnx.export(
            wrapper, (x, n), out_path,
            input_names=["features", "length"], output_names=["encoded", "encoded_len"],
            dynamic_axes={"features": {0: "B", 2: "T"}, "length": {0: "B"},
                          "encoded": {0: "B", 2: "T"}, "encoded_len": {0: "B"}},
            opset_version=17, dynamo=False)
    log.info("exported %s", out_path)


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    try:
        export_encoder(argv[1], argv[2], argv[3])
        return 0
    except Exception:
        log.exception("encoder export failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv))
