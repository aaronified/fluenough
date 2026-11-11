"""Dynamic int8 quantisation of an ONNX file (needs onnxruntime and onnx).

Usage: python3 quantize.py <in.onnx> <out.onnx>
"""
import logging
import os
import sys

log = logging.getLogger("asr.quantize")


def quantize(src, dst):
    from onnxruntime.quantization import QuantType, quantize_dynamic
    quantize_dynamic(src, dst, weight_type=QuantType.QInt8, per_channel=False)
    log.info("%s %.1f MB -> %s %.1f MB", src, os.path.getsize(src) / 1e6, dst,
             os.path.getsize(dst) / 1e6)


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        quantize(argv[1], argv[2])
        return 0
    except Exception:
        log.exception("quantisation failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv))
