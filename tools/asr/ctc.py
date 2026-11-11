"""Per-language CTC head and greedy CTC decode: the exact algorithm the Dart port
(lib/core/speech/asr/ctc_head.dart, ctc_decode.dart) repeats.

Head file layout (little-endian float32, no header): weights [vocab x dim] row-major,
then bias [vocab]. The json beside it holds the pieces, the blank index (always the last
class), dim and vocab. The head is a 1x1 convolution of the encoder output, i.e. one
matrix multiply per frame.
"""
import json
import logging

import numpy as np

log = logging.getLogger("asr.ctc")

UNK = "<unk>"
SPACE_MARK = "▁"  # SentencePiece word-start mark


def head_slice_index(languages, language, per_language, num_classes):
    """Rows of the full CTC layer that belong to one language, then the blank.

    The multilingual layer has `per_language` classes for each language in the order of
    `languages` (the config's tokenizer.langs order), then one blank as the last class.
    Returns (rows, blank_row): rows is the language's contiguous range followed by the
    blank row, so the sliced head has len(rows) == per_language + 1 classes and its blank
    is its last index. Raises ValueError on an unknown language or a size mismatch.
    """
    languages = list(languages)
    if language not in languages:
        raise ValueError(f"language {language!r} not in {languages}")
    if per_language * len(languages) + 1 != num_classes:
        raise ValueError(
            f"{len(languages)} languages x {per_language} + blank != {num_classes} classes")
    k = languages.index(language)
    start = k * per_language
    blank_row = num_classes - 1
    rows = list(range(start, start + per_language)) + [blank_row]
    return rows, blank_row


def write_head(path_prefix, weights, bias, pieces, language):
    """Write <prefix>.f32 and <prefix>.json; returns (f32 path, json path)."""
    weights = np.ascontiguousarray(weights, dtype="<f4")
    bias = np.ascontiguousarray(bias, dtype="<f4")
    vocab, dim = weights.shape
    if bias.shape != (vocab,):
        raise ValueError(f"bias shape {bias.shape} != ({vocab},)")
    if len(pieces) != vocab - 1:
        raise ValueError(f"{len(pieces)} pieces for {vocab} classes (blank is extra)")
    f32, js = f"{path_prefix}.f32", f"{path_prefix}.json"
    with open(f32, "wb") as f:
        f.write(weights.tobytes())
        f.write(bias.tobytes())
    meta = {"language": language, "pieces": list(pieces), "blank": vocab - 1,
            "dim": int(dim), "vocab": int(vocab)}
    with open(js, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    return f32, js


class Head:
    def __init__(self, weights, bias, pieces, blank, language=""):
        self.weights = np.asarray(weights, dtype=np.float32)  # [vocab, dim]
        self.bias = np.asarray(bias, dtype=np.float32)
        self.pieces = list(pieces)
        self.blank = int(blank)
        self.language = language

    @classmethod
    def load(cls, f32_path, json_path):
        with open(json_path, encoding="utf-8") as f:
            meta = json.load(f)
        vocab, dim = int(meta["vocab"]), int(meta["dim"])
        raw = np.fromfile(f32_path, dtype="<f4")
        if raw.size != vocab * dim + vocab:
            raise ValueError(f"{f32_path}: {raw.size} floats, want {vocab * dim + vocab}")
        w = raw[: vocab * dim].reshape(vocab, dim)
        b = raw[vocab * dim:]
        return cls(w, b, meta["pieces"], meta["blank"], meta.get("language", ""))

    def logits(self, enc):
        """enc: [dim, frames] (the encoder output without the batch axis) -> [frames, vocab]."""
        return enc.astype(np.float32).T @ self.weights.T + self.bias

    def apply(self, enc, length=None):
        """Greedy ids per frame and the mean max-probability over those frames.

        length: valid frame count (the encoder's second output); None means all frames.
        """
        lg = self.logits(enc)
        if length is not None:
            lg = lg[: int(length)]
        if lg.shape[0] == 0:
            return [], 0.0
        m = lg.max(axis=1, keepdims=True)
        e = np.exp(lg - m)
        # max softmax probability = exp(max - max) / sum = 1 / sum
        conf = float((1.0 / e.sum(axis=1)).mean())
        return [int(i) for i in lg.argmax(axis=1)], conf


def ctc_decode(ids, pieces, blank):
    """Collapse repeats, drop blanks (and <unk>), join pieces, word-start mark to a space."""
    out = []
    prev = None
    for i in ids:
        if i != prev and i != blank:
            if 0 <= i < len(pieces) and pieces[i] != UNK:
                out.append(pieces[i])
        prev = i
    return " ".join("".join(out).replace(SPACE_MARK, " ").split())
