"""Score the listener on a folder of recordings: word and character error rate.

Usage: python3 -I eval_wer.py <folder> --pack <pack dir> [--fp32-pack <pack dir>] [--lang te]

The folder holds pairs `name.wav` + `name.txt` (the reference, UTF-8, one line). The
transcript is made exactly as transcribe.py makes it. Prints one line per file and the
totals for the int8 encoder (encoder.int8.onnx of --pack) and, when --fp32-pack (or
encoder.fp32.onnx in --pack) exists, for fp32 next to it. WER = word edits / reference
words; CER = character edits / reference characters (spaces kept, one space between words).
"""
import argparse
import glob
import logging
import os
import re
import sys
import unicodedata

log = logging.getLogger("asr.eval_wer")

if __package__:
    from . import ctc, transcribe
else:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import ctc
    import transcribe

_PUNCT = re.compile(r"[\.,?!;:\"'()\[\]।‘’“”-]")


def normalise(text):
    text = unicodedata.normalize("NFC", text)
    return " ".join(_PUNCT.sub(" ", text).lower().split())


def edit_distance(a, b):
    """Levenshtein distance between two sequences."""
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def score(reference, hypothesis):
    """(word edits, reference words, char edits, reference chars) after normalising."""
    r, h = normalise(reference), normalise(hypothesis)
    return (edit_distance(r.split(), h.split()), len(r.split()),
            edit_distance(r, h), len(r))


def pairs(folder):
    out = []
    for wav in sorted(glob.glob(os.path.join(folder, "*.wav"))):
        txt = wav[:-4] + ".txt"
        if not os.path.exists(txt):
            log.warning("no reference text for %s: skipped", wav)
            continue
        with open(txt, encoding="utf-8") as f:
            out.append((wav, f.read().strip()))
    return out


def run(folder, pack, encoder, language, label):
    f32, js = transcribe.find_pack(pack, language)
    head = ctc.Head.load(f32, js)
    session = transcribe.open_session(pack, encoder)
    we = wn = ce = cn = 0
    rtfs = []
    for wav, ref in pairs(folder):
        try:
            r = transcribe.transcribe_samples(session, head, transcribe.read_wav(wav))
        except Exception:
            log.exception("%s: transcription failed for %s", label, wav)
            continue
        a, b, c, d = score(ref, r["text"])
        we, wn, ce, cn = we + a, wn + b, ce + c, cn + d
        rtfs.append(r["rtf"])
        print(f"{label}\t{os.path.basename(wav)}\tref: {ref}\thyp: {r['text']}\t"
              f"word edits {a}/{b}")
    if not wn:
        log.error("%s: nothing scored (no wav+txt pairs in %s)", label, folder)
        return None
    res = {"label": label, "wer": we / wn, "cer": ce / max(cn, 1), "files": len(rtfs),
           "rtf": sum(rtfs) / len(rtfs)}
    print(f"{label}: WER {100 * res['wer']:.1f}%  CER {100 * res['cer']:.1f}%  "
          f"files {res['files']}  mean RTF {res['rtf']:.3f}")
    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("--pack", required=True)
    ap.add_argument("--fp32-pack")
    ap.add_argument("--lang")
    args = ap.parse_args(argv)
    try:
        results = []
        if os.path.exists(os.path.join(args.pack, "encoder.int8.onnx")):
            results.append(run(args.folder, args.pack, "int8", args.lang, "int8"))
        else:
            log.error("%s has no encoder.int8.onnx", args.pack)
        fp32_pack = args.fp32_pack or args.pack
        if os.path.exists(os.path.join(fp32_pack, "encoder.fp32.onnx")):
            results.append(run(args.folder, fp32_pack, "fp32", args.lang, "fp32"))
        else:
            log.warning("no encoder.fp32.onnx in %s: fp32 not scored (export_pack --keep-fp32)",
                        fp32_pack)
        return 0 if results and all(results) else 1
    except Exception:
        log.exception("eval_wer failed")
        return 1


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main())
