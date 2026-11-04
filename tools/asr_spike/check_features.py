import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loadmodel import load
import numpy as np, torch
import np_features as nf
m = load()
pre = m.preprocessor
print('fb max abs diff vs NeMo:', np.abs(pre.featurizer.fb[0].numpy() - nf._FB).max())
print('window diff:', np.abs(pre.featurizer.window.numpy() - nf._WINDOW[56:456]).max())
rng = np.random.default_rng(0)
for n in (16000, 47000, 80000):
    t = np.arange(n) / 16000
    wav = (0.3*np.sin(2*np.pi*220*t)*(1+np.sin(2*np.pi*3*t)) + 0.05*rng.standard_normal(n)).astype(np.float32)
    f_ref, l_ref = pre(input_signal=torch.from_numpy(wav)[None], length=torch.tensor([n]))
    f_np, seq = nf.log_mel(wav)
    f_ref = f_ref[0].numpy()
    print(n, f_ref.shape, f_np.shape, 'len', int(l_ref[0]), seq, 'max abs diff (valid frames)', np.abs(f_ref[:, :seq]-f_np[:, :seq]).max(), 'mean abs', np.abs(f_ref[:, :seq]-f_np[:, :seq]).mean())
