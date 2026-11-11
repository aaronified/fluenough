"""Tests for the on-device listener reference tools (#1004): the head-slice index on a
toy tensor, the torch-free .nemo reader on a hand-made checkpoint, the head file, the CTC
decode, the golden fixtures and the pipeline with a fake encoder. They need numpy and
PyYAML only (no torch, NeMo or onnxruntime, no model files).

The scripts run as `python3 -I` below, as they do on downloaded data.
"""

import base64
import collections
import io
import json
import os
import pickle
import subprocess
import sys
import tarfile
import tempfile
import types
import unittest
import wave
import zipfile

try:
    import numpy as np
except ImportError:  # CI installs it; a contributor machine may not have it
    np = None

from . import ctc, eval_wer, export_pack, fetch_wiktionary_audio, golden, nemo_ckpt, np_features, transcribe

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))


def script(name, *args):
    return subprocess.run([sys.executable, "-I", os.path.join(HERE, name), *args],
                          capture_output=True, text=True, timeout=120)


def make_nemo(path, langs, per, dim, enc_value, seed):
    """A tiny .nemo with the structure of IndicConformer's: config yaml + torch-format ckpt.

    The ctc layer has len(langs)*per + 1 classes, row r filled with r + seed; the encoder
    has one tensor of enc_value (and a transposed-view tensor, to test strides)."""
    import types as _t

    # Fake torch modules so the stdlib pickler can write the same globals torch does.
    def rebuild(*a):  # never called
        raise AssertionError

    rebuild.__module__, rebuild.__name__, rebuild.__qualname__ = "torch._utils", "_rebuild_tensor_v2", "_rebuild_tensor_v2"
    storage_cls = type("FloatStorage", (), {"__module__": "torch"})
    torch_mod, utils_mod = _t.ModuleType("torch"), _t.ModuleType("torch._utils")
    torch_mod.FloatStorage = storage_cls
    utils_mod._rebuild_tensor_v2 = rebuild
    saved = {k: sys.modules.get(k) for k in ("torch", "torch._utils")}
    sys.modules["torch"], sys.modules["torch._utils"] = torch_mod, utils_mod
    try:
        storages = []

        class Tensor:
            def __init__(self, data, size, stride):
                self.key = str(len(storages))
                storages.append(np.asarray(data, dtype="<f4").tobytes())
                self.size, self.stride, self.numel = size, stride, len(data)

        classes = len(langs) * per + 1
        w = [float(r + seed) for r in range(classes) for _ in range(dim)]
        sd = collections.OrderedDict()
        sd["encoder.layers.0.w"] = Tensor([enc_value] * 6, (2, 3), (3, 1))
        sd["encoder.t"] = Tensor([0, 1, 2, 3, 4, 5], (2, 3), (1, 2))  # a transposed 3x2
        sd["ctc_decoder.decoder_layers.0.weight"] = Tensor(w, (classes, dim, 1), (dim, 1, 1))
        sd["ctc_decoder.decoder_layers.0.bias"] = Tensor([0.5 * r for r in range(classes)], (classes,), (1,))

        buf = io.BytesIO()

        # Tensors persist their storage by id, as torch does: wrap it in a marker.
        class Marker:
            def __init__(self, t):
                self.t = t

        class Pk(pickle.Pickler):
            def persistent_id(self, obj):
                if isinstance(obj, Marker):
                    return ("storage", storage_cls, obj.t.key, "cpu", obj.t.numel)
                return None

        def tensor_reduce(self):
            return rebuild, (Marker(self), 0, self.size, self.stride, False, collections.OrderedDict())

        Tensor.__reduce__ = tensor_reduce
        Pk(buf, protocol=2).dump(sd)
        pkl = buf.getvalue()
    finally:
        for k, v in saved.items():
            if v is None:
                sys.modules.pop(k, None)
            else:
                sys.modules[k] = v
    zbuf = io.BytesIO()
    with zipfile.ZipFile(zbuf, "w") as z:
        z.writestr("model_weights/data.pkl", pkl)
        z.writestr("model_weights/byteorder", "little")
        for i, s in enumerate(storages):
            z.writestr(f"model_weights/data/{i}", s)
    vocabulary = [f"{lang}{i}" for lang in langs for i in range(per)]
    cfg = ("tokenizer:\n  langs:\n" + "".join(f"    {l}:\n      type: bpe\n" for l in langs)
           + "aux_ctc:\n  decoder:\n    vocabulary:\n" + "".join(f"    - {v}\n" for v in vocabulary))
    with tarfile.open(path, "w") as tf:
        for name, data in (("./model_config.yaml", cfg.encode()), ("./model_weights.ckpt", zbuf.getvalue())):
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))


@unittest.skipIf(np is None, "numpy not installed")
class HeadSliceTest(unittest.TestCase):
    def test_index_picks_the_language_range_then_blank(self):
        rows, blank = ctc.head_slice_index(["a", "b", "c"], "b", 2, 7)
        self.assertEqual(rows, [2, 3, 6])
        self.assertEqual(blank, 6)
        self.assertEqual(ctc.head_slice_index(["a", "b", "c"], "a", 2, 7)[0], [0, 1, 6])
        self.assertEqual(ctc.head_slice_index(["a", "b", "c"], "c", 2, 7)[0], [4, 5, 6])

    def test_index_on_a_toy_tensor(self):
        full = np.arange(7 * 3, dtype=np.float32).reshape(7, 3)  # row r = [3r, 3r+1, 3r+2]
        rows, _ = ctc.head_slice_index(["a", "b", "c"], "c", 2, 7)
        sliced = full[rows]
        self.assertEqual(sliced.shape, (3, 3))
        self.assertEqual(sliced[0].tolist(), [12.0, 13.0, 14.0])  # first class of c
        self.assertEqual(sliced[-1].tolist(), [18.0, 19.0, 20.0])  # blank is last

    def test_bad_input_is_refused(self):
        with self.assertRaises(ValueError):
            ctc.head_slice_index(["a", "b"], "zz", 2, 5)
        with self.assertRaises(ValueError):
            ctc.head_slice_index(["a", "b"], "a", 2, 6)  # not langs*per+1

    def test_telugu_numbers_of_the_real_model(self):
        langs = ["as", "bn", "brx", "doi", "kok", "gu", "hi", "kn", "ks", "mai", "ml", "mr",
                 "mni", "ne", "or", "pa", "sa", "sat", "sd", "ta", "te", "ur"]
        rows, blank = ctc.head_slice_index(langs, "te", 256, 5633)
        self.assertEqual((rows[0], rows[-2], blank, len(rows)), (5120, 5375, 5632, 257))

    def test_head_file_roundtrip_and_layout(self):
        with tempfile.TemporaryDirectory() as d:
            w = np.arange(12, dtype=np.float32).reshape(4, 3)
            b = np.array([10, 11, 12, 13], dtype=np.float32)
            f32, js = ctc.write_head(os.path.join(d, "head_xx"), w, b, ["<unk>", "▁a", "b"], "xx")
            raw = np.fromfile(f32, dtype="<f4")
            self.assertEqual(raw.tolist(), list(range(12)) + [10, 11, 12, 13])
            h = ctc.Head.load(f32, js)
            self.assertEqual((h.blank, h.pieces[1], h.language), (3, "▁a", "xx"))
            self.assertEqual(h.weights.tolist(), w.tolist())
            with open(f32, "ab") as f:
                f.write(b"\0\0\0\0")
            with self.assertRaises(ValueError):
                ctc.Head.load(f32, js)


@unittest.skipIf(np is None, "numpy not installed")
class CtcTest(unittest.TestCase):
    pieces = ["<unk>", "▁te", "lu", "gu", "▁x"]

    def test_collapse_blank_unk_and_space_mark(self):
        d = ctc.ctc_decode
        self.assertEqual(d([1, 1, 5, 1, 2, 2, 5, 5, 3], self.pieces, 5), "te telugu")
        self.assertEqual(d([5, 5], self.pieces, 5), "")
        self.assertEqual(d([], self.pieces, 5), "")
        self.assertEqual(d([0, 1, 0, 2], self.pieces, 5), "telu")  # unk dropped, not a separator

    def test_apply_confidence_and_valid_length(self):
        w = np.eye(3, dtype=np.float32) * 10
        h = ctc.Head(w, np.zeros(3), ["a", "b"], 2)
        enc = np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1]], dtype=np.float32)  # [dim, frames]
        ids, conf = h.apply(enc)
        self.assertEqual(ids, [0, 1, 2])
        self.assertGreater(conf, 0.99)
        ids, _ = h.apply(enc, 2)
        self.assertEqual(ids, [0, 1])
        self.assertEqual(h.apply(enc, 0), ([], 0.0))

    def test_the_golden_fixtures_hold(self):
        with open(os.path.join(REPO, "test", "fixtures", "asr", "golden_ctc.json"), encoding="utf-8") as f:
            g = json.load(f)
        w = np.array(g["weights"], dtype=np.float32).reshape(g["vocab"], g["dim"])
        head = ctc.Head(w, g["bias"], g["pieces"], g["blank"])
        enc = np.array(g["encoderOutput"], dtype=np.float32)
        ids, conf = head.apply(enc, g["validFrames"])
        self.assertEqual(ids, g["ids"])
        self.assertAlmostEqual(conf, g["meanConfidence"], places=5)
        self.assertEqual(ctc.ctc_decode(ids, g["pieces"], g["blank"]), g["text"])
        self.assertGreater(len(g["text"]), 0)
        for c in g["decodeCases"]:
            self.assertEqual(ctc.ctc_decode(c["ids"], g["pieces"], g["blank"]), c["text"])

    def test_golden_files_are_current(self):
        self.assertEqual(golden.main(["--check"]), 0)


@unittest.skipIf(np is None, "numpy not installed")
class FeaturesTest(unittest.TestCase):
    def test_shape_and_normalisation(self):
        pcm = golden.synthetic_pcm()
        self.assertEqual(len(pcm), 16000)
        feats, seq = np_features.log_mel(np_features.pcm16_to_float(pcm))
        self.assertEqual(feats.shape, (80, 101))
        self.assertEqual(seq, 101)
        self.assertTrue(np.isfinite(feats).all())
        self.assertLess(abs(float(feats.mean(axis=1).max())), 1e-3)

    def test_golden_mel_matches_its_pcm(self):
        with open(os.path.join(REPO, "test", "fixtures", "asr", "golden_mel.json"), encoding="utf-8") as f:
            g = json.load(f)
        pcm = np.frombuffer(base64.b64decode(g["pcm16leBase64"]), dtype="<i2")
        self.assertEqual(len(pcm), g["samples"])
        feats, seq = np_features.log_mel(np_features.pcm16_to_float(pcm))
        for i, row in zip(g["frameIndexes"], g["values"]):
            self.assertLess(float(np.abs(feats[:, i] - np.array(row)).max()), 1e-4)

    def test_short_audio_does_not_crash(self):
        feats, seq = np_features.log_mel(np.zeros(100, dtype=np.float32))
        self.assertEqual(feats.shape[0], 80)


@unittest.skipIf(np is None, "numpy not installed")
class NemoReaderTest(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.TemporaryDirectory()
        self.addCleanup(self.d.cleanup)
        self.a = os.path.join(self.d.name, "indicconformer_stt_bb_hybrid_rnnt_large.nemo")
        self.b = os.path.join(self.d.name, "indicconformer_stt_cc_hybrid_rnnt_large.nemo")
        make_nemo(self.a, ["aa", "bb", "cc"], 4, 2, 1.0, 100)
        make_nemo(self.b, ["aa", "bb", "cc"], 4, 2, 1.0, 200)  # same encoder, other head

    def test_reads_tensors_including_strided_views(self):
        t = nemo_ckpt.read_tensors(self.a, ["encoder.t", "encoder.layers.0.w"])
        self.assertEqual(t["encoder.t"].tolist(), [[0, 2, 4], [1, 3, 5]])
        self.assertEqual(t["encoder.layers.0.w"].shape, (2, 3))
        with self.assertRaises(KeyError):
            nemo_ckpt.read_tensors(self.a, ["nope"])

    def test_encoder_hash_equal_for_a_shared_encoder_and_not_otherwise(self):
        ha, na = nemo_ckpt.encoder_hash(self.a)
        hb, nb = nemo_ckpt.encoder_hash(self.b)
        self.assertEqual((ha, na), (hb, nb))
        c = os.path.join(self.d.name, "c.nemo")
        make_nemo(c, ["aa", "bb", "cc"], 4, 2, 2.0, 100)  # a different encoder
        self.assertNotEqual(nemo_ckpt.encoder_hash(c)[0], ha)

    def test_unknown_pickle_globals_are_refused(self):
        class Evil:
            def __reduce__(self):
                return os.system, ("true",)
        with self.assertRaises(pickle.UnpicklingError):
            nemo_ckpt._Unpickler(io.BytesIO(pickle.dumps(Evil()))).load()

    def test_export_head_slices_the_language(self):
        out = os.path.join(self.d.name, "out")
        os.makedirs(out)
        info = export_pack.export_head(self.a, out, "bb")
        self.assertEqual(info["rows"], [4, 7, 12])
        h = ctc.Head.load(os.path.join(out, "head_bb.f32"), os.path.join(out, "head_bb.json"))
        self.assertEqual(h.weights.shape, (5, 2))
        self.assertEqual(h.weights[:, 0].tolist(), [104.0, 105.0, 106.0, 107.0, 112.0])
        self.assertEqual(h.bias.tolist(), [2.0, 2.5, 3.0, 3.5, 6.0])
        self.assertEqual((h.pieces, h.blank), (["bb0", "bb1", "bb2", "bb3"], 4))

    def test_script_writes_head_and_reports_the_encoder_hash(self):
        out = os.path.join(self.d.name, "pack")
        r = script("export_pack.py", self.a, out, "--compare", self.b, "--skip-encoder")
        self.assertEqual(r.returncode, 3, r.stderr)  # head written, encoder skipped
        self.assertIn("EQUAL", r.stderr)
        with open(os.path.join(out, "pack-report.json"), encoding="utf-8") as f:
            rep = json.load(f)
        self.assertTrue(rep["compare"]["equal"])
        self.assertEqual(rep["language"], "bb")
        self.assertIn("head_bb.f32", rep["files"])

    def test_script_logs_a_bad_file_and_fails(self):
        bad = os.path.join(self.d.name, "indicconformer_stt_zz_x.nemo")
        with open(bad, "wb") as f:
            f.write(b"not a tar")
        r = script("export_pack.py", bad, os.path.join(self.d.name, "o"), "--skip-encoder")
        self.assertEqual(r.returncode, 1)
        self.assertIn("head export failed", r.stderr)


@unittest.skipIf(np is None, "numpy not installed")
class PipelineTest(unittest.TestCase):
    class FakeSession:
        """Stands in for the ONNX encoder: 4 times fewer frames, a fixed one-hot output."""

        def __init__(self, dim):
            self.dim = dim

        def run(self, _names, feed):
            t = feed["features"].shape[2] // 4
            enc = np.zeros((1, self.dim, t), dtype=np.float32)
            for i in range(t):
                enc[0, i % self.dim, i] = 5.0
            return [enc, np.array([t], dtype=np.int64)]

    def test_transcribe_samples_end_to_end_with_a_fake_encoder(self):
        w = np.eye(4, dtype=np.float32)  # classes 0..2 are pieces, 3 is blank
        head = ctc.Head(w, np.zeros(4), ["▁a", "b", "c"], 3)
        r = transcribe.transcribe_samples(self.FakeSession(4), head,
                                          np.zeros(16000, dtype=np.float32) + 0.01)
        self.assertEqual(r["ids"][:5], [0, 1, 2, 3, 0])
        self.assertTrue(r["text"].startswith("abc"))
        self.assertGreater(r["rtf"], 0)

    def test_read_wav_mono_16k_and_resampling(self):
        with tempfile.TemporaryDirectory() as d:
            for rate, n in ((16000, 1600), (8000, 800)):
                p = os.path.join(d, f"{rate}.wav")
                with wave.open(p, "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(rate)
                    w.writeframes((np.arange(n) % 100 * 100).astype("<i2").tobytes())
                x = transcribe.read_wav(p)
                self.assertEqual(len(x), 1600)
                self.assertEqual(x.dtype, np.float32)

    def test_find_pack_wants_one_head(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FileNotFoundError):
                transcribe.find_pack(d)
            for c in ("te", "bn"):
                open(os.path.join(d, f"head_{c}.json"), "w").close()
            with self.assertRaises(FileNotFoundError):
                transcribe.find_pack(d)
            self.assertTrue(transcribe.find_pack(d, "te")[0].endswith("head_te.f32"))


class ScoreTest(unittest.TestCase):
    def test_edit_distance_and_score(self):
        self.assertEqual(eval_wer.edit_distance("kitten", "sitting"), 3)
        self.assertEqual(eval_wer.edit_distance([], ["a"]), 1)
        we, wn, ce, cn = eval_wer.score("one two three", "one too three")
        self.assertEqual((we, wn), (1, 3))
        self.assertEqual(ce, 1)
        self.assertEqual(cn, len("one two three"))

    def test_normalise_drops_punctuation_and_case(self):
        self.assertEqual(eval_wer.normalise("Hello,  World!"), "hello world")
        self.assertEqual(eval_wer.normalise("పాలు।"), "పాలు")

    def test_all_wrong_is_a_hundred_percent(self):
        we, wn, _, _ = eval_wer.score("a b", "")
        self.assertEqual((we, wn), (2, 2))


class FetchWiktionaryAudioTest(unittest.TestCase):
    F = fetch_wiktionary_audio

    def test_title_to_word(self):
        w = self.F.word_from_title
        self.assertEqual(w("File:Te-తెలుగు.ogg"), "తెలుగు")
        self.assertEqual(w("File:LL-Q8097 (tel)-Speaker One-నీరు.wav"), "నీరు")
        self.assertEqual(w("File:Te-water.ogg"), None)
        self.assertEqual(w("File:Telugu 12.ogg"), None)
        self.assertEqual(w("File:Te-అమ్మ_నాన్న.ogg"), "అమ్మ నాన్న")

    def page(self, title, url="https://upload.wikimedia.org/x"):
        return {"title": title, "imageinfo": [{"url": url, "user": "u", "descriptionurl": "d",
                "extmetadata": {"Artist": {"value": "<a href='x'>Ann &amp; Bob</a>"},
                                "LicenseShortName": {"value": "CC BY-SA 4.0"},
                                "LicenseUrl": {"value": "https://cc"}}}]}

    def test_select_filters_and_dedupes(self):
        pages = [self.page("File:Te-నీరు.ogg"), self.page("File:LL-Q8097 (tel)-S-నీరు.wav"),
                 self.page("File:Te-water.ogg"), self.page("File:Te-అమ్మ.png"),
                 self.page("File:Te-ఇల్లు.ogg", url=""), self.page("File:Te-ఇల్లు.ogg"),
                 self.page("File:Te-కారు.ogg")]
        with self.assertLogs("asr.fetch_wiktionary_audio", level="INFO"):
            got = self.F.select(pages, 10)
        self.assertEqual(sorted(w for _, w in got), ["ఇల్లు", "కారు", "నీరు"])
        self.assertEqual(len(self.F.select(pages, 1)), 1)

    def test_manifest_entry(self):
        e = self.F.manifest_entry(self.page("File:Te-నీరు.ogg"), "నీరు", "w001.wav")
        self.assertEqual(e["author"], "Ann & Bob")
        self.assertEqual((e["license"], e["file"], e["word"]), ("CC BY-SA 4.0", "w001.wav", "నీరు"))

    def test_client_backs_off_and_respects_budget(self):
        sleeps, calls = [], []

        class Resp:
            def __enter__(s): return s
            def __exit__(s, *a): return False
            def read(s): return b"ok"

        def opener(req, timeout):
            calls.append(req.get_header("User-agent"))
            if len(calls) < 3:
                raise self.F.urllib.error.HTTPError(req.full_url, 429, "slow", {}, None)
            return Resp()

        c = self.F.Client(max_requests=10, pause=0.1, opener=opener, sleep=sleeps.append)
        with self.assertLogs("asr.fetch_wiktionary_audio", level="WARNING"):
            self.assertEqual(c.fetch("https://x/y"), b"ok")
        self.assertIn("fluenough-asr-eval", calls[0])
        self.assertEqual(sleeps[:2], [2.0, 4.0])
        self.assertGreaterEqual(sleeps[-1], 1.0)
        c2 = self.F.Client(max_requests=1, opener=opener, sleep=lambda s: None)
        c2.requests = 1
        with self.assertLogs("asr.fetch_wiktionary_audio", level="ERROR"):
            self.assertIsNone(c2.fetch("https://x/y"))

    def test_run_writes_pairs_and_manifest(self):
        pages = [self.page("File:Te-నీరు.ogg"), self.page("File:Te-water.ogg")]
        answers = {}

        class Stub(self.F.Client):
            def api(s, params):
                if params.get("list") == "categorymembers":
                    return {"query": {"categorymembers": []}}
                return {"query": {"pages": pages}}

            def fetch(s, url, timeout=60, attempts=5):
                s.requests += 1
                return b"audio"

        def fake_convert(src, dst):
            with open(dst, "wb") as f:
                f.write(b"wav")
            return True

        with tempfile.TemporaryDirectory() as d:
            with self.assertLogs("asr.fetch_wiktionary_audio", level="INFO"):
                entries = self.F.run(d, 5, ["Category:Test"], Stub(), fake_convert)
            self.assertEqual(len(entries), 1)
            with open(os.path.join(d, "w001.txt"), encoding="utf-8") as f:
                self.assertEqual(f.read().strip(), "నీరు")
            with open(os.path.join(d, "manifest.json"), encoding="utf-8") as f:
                self.assertEqual(json.load(f)["files"][0]["license"], "CC BY-SA 4.0")
            self.assertFalse(os.path.exists(os.path.join(d, "w001.src")))


if __name__ == "__main__":
    unittest.main()
