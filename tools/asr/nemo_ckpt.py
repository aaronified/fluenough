"""Read a NeMo .nemo checkpoint without torch or NeMo.

A .nemo file is a tar holding model_config.yaml and model_weights.ckpt, and the ckpt is a
torch zip archive (data.pkl plus one raw storage per tensor). The pickle is read with a
restricted unpickler that only rebuilds tensors into numpy arrays: nothing else may be
loaded from it. Run any script that calls this on a downloaded file with `python3 -I`.
"""
import collections
import hashlib
import logging
import pickle
import tarfile
import zipfile

import numpy as np

log = logging.getLogger("asr.nemo")

_DTYPES = {
    "FloatStorage": "<f4", "HalfStorage": "<f2", "DoubleStorage": "<f8",
    "LongStorage": "<i8", "IntStorage": "<i4", "ShortStorage": "<i2",
    "CharStorage": "i1", "ByteStorage": "u1", "BoolStorage": "?",
}


class _Storage:
    def __init__(self, kind, key):
        self.kind, self.key = kind, key


class _Unpickler(pickle.Unpickler):
    def find_class(self, module, name):
        if name == "_rebuild_tensor_v2":
            return _rebuild_tensor
        if module == "collections" and name == "OrderedDict":
            return collections.OrderedDict
        if module == "torch" and name in _DTYPES:
            return name
        raise pickle.UnpicklingError(f"refusing to load {module}.{name}")

    def persistent_load(self, pid):
        # ('storage', storage_type, key, location, numel)
        return _Storage(pid[1], pid[2])


def _rebuild_tensor(storage, offset, size, stride, *_rest):
    return ("tensor", storage, offset, tuple(size), tuple(stride))


def _open_member(nemo_path, suffix):
    tf = tarfile.open(nemo_path, "r:*")
    for m in tf:
        if m.name.split("/")[-1] == suffix:
            return tf, tf.extractfile(m)
    tf.close()
    raise FileNotFoundError(f"{suffix} not in {nemo_path}")


def read_config(nemo_path):
    import yaml
    tf, f = _open_member(nemo_path, "model_config.yaml")
    try:
        return yaml.safe_load(f)
    finally:
        tf.close()


def iter_tensors(nemo_path, prefix=""):
    """Yield (name, numpy array) for every tensor whose name starts with prefix."""
    tf, f = _open_member(nemo_path, "model_weights.ckpt")
    try:
        # A plain tar member is seekable, which zipfile needs.
        z = zipfile.ZipFile(f)
        root = z.namelist()[0].split("/")[0]
        sd = _Unpickler(z.open(f"{root}/data.pkl")).load()
        for name, t in sd.items():
            if not name.startswith(prefix):
                continue
            _, st, off, size, stride = t
            dt = np.dtype(_DTYPES[st.kind])
            flat = np.frombuffer(z.read(f"{root}/data/{st.key}"), dtype=dt)
            if size == ():
                arr = flat[off:off + 1].reshape(())
            else:
                arr = np.lib.stride_tricks.as_strided(
                    flat[off:], shape=size, strides=[s * dt.itemsize for s in stride])
            yield name, np.array(arr, copy=True)
    finally:
        tf.close()


def read_tensors(nemo_path, names):
    """Return {name: array} for exactly these names; KeyError if one is missing."""
    want, got = set(names), {}
    for name, arr in iter_tensors(nemo_path):
        if name in want:
            got[name] = arr
    missing = want - set(got)
    if missing:
        raise KeyError(f"missing in {nemo_path}: {sorted(missing)}")
    return got


def encoder_hash(nemo_path, prefix="encoder."):
    """sha256 over every encoder tensor (name, dtype, shape, bytes), in name order."""
    items = sorted(iter_tensors(nemo_path, prefix), key=lambda kv: kv[0])
    if not items:
        raise ValueError(f"no tensor starts with {prefix!r} in {nemo_path}")
    h = hashlib.sha256()
    for name, arr in items:
        h.update(name.encode())
        h.update(str(arr.dtype).encode())
        h.update(str(arr.shape).encode())
        h.update(np.ascontiguousarray(arr).tobytes())
    return h.hexdigest(), len(items)
