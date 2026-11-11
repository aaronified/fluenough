"""Build the on-device listener pack for one language from its IndicConformer .nemo.

Usage:
  python3 -I export_pack.py <file.nemo> <out dir> [--lang te] [--compare other.nemo]
      [--compare-lang bn] [--skip-encoder] [--keep-fp32] [--workdir DIR]

Writes into <out dir>:
  head_<code>.f32 + head_<code>.json   the language's CTC head (torch-free, see ctc.py)
  encoder.int8.onnx                    shared encoder, dynamic int8 (needs torch + NeMo)
  encoder.fp32.onnx                    with --keep-fp32 (for eval_wer.py's comparison)
  pack-report.json                     sizes, sha256 of every file, encoder tensor hash

--compare hashes the encoder tensors of a second language's .nemo and reports whether they
are equal (so one encoder serves both). The head and the hashes need only numpy and PyYAML;
the encoder export needs torch, onnx, onnxruntime and AI4Bharat's NeMo fork (loadmodel.py).
With --skip-encoder, or when that export fails, the head is still written and the exit
code is 3. Run it with `python3 -I`: the .nemo is downloaded data.
"""
import argparse
import hashlib
import json
import logging
import os
import re
import sys

import numpy as np

log = logging.getLogger("asr.export_pack")

if __package__:
    from . import ctc, nemo_ckpt
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ctc
    import nemo_ckpt

CTC_W, CTC_B = "ctc_decoder.decoder_layers.0.weight", "ctc_decoder.decoder_layers.0.bias"


def language_from_filename(path):
    m = re.search(r"indicconformer_stt_([a-z]+)_", os.path.basename(path))
    return m.group(1) if m else None


def export_head(nemo_path, out_dir, language):
    """Write head_<language>.f32/.json from the .nemo. Returns the report entry."""
    cfg = nemo_ckpt.read_config(nemo_path)
    langs = list(cfg["tokenizer"]["langs"])
    vocabulary = cfg["aux_ctc"]["decoder"]["vocabulary"]
    per = len(vocabulary) // len(langs)
    t = nemo_ckpt.read_tensors(nemo_path, [CTC_W, CTC_B])
    w, b = t[CTC_W][:, :, 0], t[CTC_B]  # 1x1 conv: [classes, D, 1] -> [classes, D]
    rows, blank_row = ctc.head_slice_index(langs, language, per, w.shape[0])
    pieces = vocabulary[rows[0]:rows[0] + per]
    prefix = os.path.join(out_dir, f"head_{language}")
    f32, js = ctc.write_head(prefix, w[rows], b[rows], pieces, language)
    log.info("head %s: %d classes x %d (rows %d..%d + blank %d)", language, len(rows),
             w.shape[1], rows[0], rows[-2], blank_row)
    return {"language": language, "rows": [rows[0], rows[-2], blank_row], "dim": int(w.shape[1]),
            "files": [os.path.basename(f32), os.path.basename(js)]}


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def export_encoder(nemo_path, out_dir, workdir, keep_fp32):
    """Encoder-only ONNX, then dynamic int8. Raises on failure (caller logs)."""
    if __package__:
        from . import export_onnx, quantize
    else:
        import export_onnx
        import quantize
    fp32 = os.path.join(out_dir, "encoder.fp32.onnx")
    int8 = os.path.join(out_dir, "encoder.int8.onnx")
    export_onnx.export_encoder(nemo_path, fp32, workdir)
    quantize.quantize(fp32, int8)
    if not keep_fp32:
        os.remove(fp32)
        data = fp32 + ".data"
        if os.path.exists(data):
            os.remove(data)


def build(args):
    code = args.lang or language_from_filename(args.nemo)
    if not code:
        log.error("cannot tell the language from %s: pass --lang", args.nemo)
        return 2
    os.makedirs(args.out, exist_ok=True)
    report = {"nemo": os.path.basename(args.nemo), "language": code}
    status = 0
    try:
        report["head"] = export_head(args.nemo, args.out, code)
    except Exception:
        log.exception("head export failed for %s", args.nemo)
        return 1
    try:
        h, n = nemo_ckpt.encoder_hash(args.nemo)
        report["encoder_sha256"], report["encoder_tensors"] = h, n
        log.info("encoder tensors: %d, sha256 %s", n, h)
        if args.compare:
            h2, n2 = nemo_ckpt.encoder_hash(args.compare)
            equal = h == h2 and n == n2
            report["compare"] = {"nemo": os.path.basename(args.compare), "encoder_sha256": h2,
                                 "tensors": n2, "equal": equal}
            log.info("encoder of %s vs %s: %s", os.path.basename(args.nemo),
                     os.path.basename(args.compare), "EQUAL" if equal else "DIFFERENT")
            if args.compare_lang:
                other = export_head(args.compare, args.out, args.compare_lang)
                report["compare"]["head"] = other
    except Exception:
        log.exception("encoder hash or comparison failed")
        status = 1
    if args.skip_encoder:
        log.warning("--skip-encoder: encoder.int8.onnx not written")
        status = status or 3
    else:
        try:
            export_encoder(args.nemo, args.out, args.workdir or os.path.join(args.out, "_work"),
                           args.keep_fp32)
        except Exception:
            log.exception("encoder export failed (needs torch, onnx, onnxruntime and NeMo; "
                          "see loadmodel.py): the head was still written")
            status = status or 3
    files = {}
    for name in sorted(os.listdir(args.out)):
        p = os.path.join(args.out, name)
        if os.path.isfile(p) and name != "pack-report.json":
            files[name] = {"bytes": os.path.getsize(p), "sha256": sha256_file(p)}
    report["files"] = files
    with open(os.path.join(args.out, "pack-report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    log.info("pack: %s", {k: v["bytes"] for k, v in files.items()})
    return status


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("nemo")
    ap.add_argument("out")
    ap.add_argument("--lang")
    ap.add_argument("--compare")
    ap.add_argument("--compare-lang")
    ap.add_argument("--skip-encoder", action="store_true")
    ap.add_argument("--keep-fp32", action="store_true")
    ap.add_argument("--workdir")
    args = ap.parse_args(argv)
    try:
        return build(args)
    except Exception:
        log.exception("export_pack failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main())
