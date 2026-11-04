import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from loadmodel import load, ROOT
import numpy as np, torch, onnxruntime as ort
import np_features as nf
m = load()
sel = [i for i, l in m.tokenizer.langs_by_token_id.items() if l == 'te'] + [m.ctc_decoder._num_classes - 1]
rng = np.random.default_rng(3)
n = 16000 * 6; t = np.arange(n) / 16000
wav = (0.2*np.sin(2*np.pi*(120+40*np.sin(2*np.pi*0.7*t))*t)*(1+np.sin(2*np.pi*4*t)) + 0.05*rng.standard_normal(n)).astype(np.float32)
f, L = nf.log_mel(wav)
with torch.no_grad():
    enc, el = m.encoder(audio_signal=torch.from_numpy(f)[None], length=torch.tensor([L]))
    full = m.ctc_decoder(encoder_output=enc, language_ids=['te'])  # NeMo's own masked log-softmax
    ref = torch.log_softmax(torch.nn.functional.conv1d(enc, m.ctc_decoder.decoder_layers[0].weight[sel], m.ctc_decoder.decoder_layers[0].bias[sel]).transpose(1,2), -1)
print('NeMo masked path vs my sliced conv: max diff', (full - ref).abs().max().item())
def run(k):
    so = ort.SessionOptions(); so.intra_op_num_threads = 4
    s = ort.InferenceSession(f'{ROOT}/out/te_ctc_{k}.onnx', so, providers=['CPUExecutionProvider'])
    lg = s.run(None, {'feats': f[None], 'length': np.array([L], dtype=np.int64)})[0]
    lg = torch.log_softmax(torch.from_numpy(lg), -1)
    return lg
a = run('fp32'); b = run('int8')
print('onnx fp32 vs NeMo torch: max abs logprob diff', (a - full).abs().max().item(), 'argmax agree', (a.argmax(-1) == full.argmax(-1)).float().mean().item())
print('int8 vs fp32: max abs logprob diff', (b - a).abs().max().item(), 'mean', (b - a).abs().mean().item(), 'argmax agree', (a.argmax(-1) == b.argmax(-1)).float().mean().item())
