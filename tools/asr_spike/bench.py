"""usage: bench.py fp32|int8  -> latency per second of audio (4 threads) and peak RSS; synthetic audio (no speech available)."""
import sys, os, time, resource, json
import numpy as np, onnxruntime as ort
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import np_features as nf
R = os.path.dirname(HERE) + '/out/'
kind = sys.argv[1]
so = ort.SessionOptions(); so.intra_op_num_threads = 4
s = ort.InferenceSession(R + f'te_ctc_{kind}.onnx', so, providers=['CPUExecutionProvider'])
rng = np.random.default_rng(1)
def wav(sec):
    n = int(sec * 16000); t = np.arange(n) / 16000
    return (0.2 * np.sin(2*np.pi*150*t) * (1+np.sin(2*np.pi*4*t)) + 0.05 * rng.standard_normal(n)).astype(np.float32)
for sec in (3, 10, 20):
    w = wav(sec)
    t0 = time.perf_counter(); f, L = nf.log_mel(w); tf = time.perf_counter() - t0
    feats = f[None]; ln = np.array([L], dtype=np.int64)
    s.run(None, {'feats': feats, 'length': ln})  # warm
    ts = []
    for _ in range(3):
        t0 = time.perf_counter(); out = s.run(None, {'feats': feats, 'length': ln}); ts.append(time.perf_counter() - t0)
    print(f'{kind} {sec:>2}s audio: features {tf*1000:.0f} ms, model {np.median(ts)*1000:.0f} ms, RTF {(np.median(ts)+tf)/sec:.3f} ({(np.median(ts)+tf)/sec:.3f}s per audio-s)')
print(kind, 'peak RSS MB', resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
