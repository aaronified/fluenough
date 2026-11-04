import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path[:0] = [ROOT+'/stubs', ROOT+'/nemo-src']
import autostub  # noqa
import torch
from omegaconf import OmegaConf
from nemo.collections.asr.models import EncDecHybridRNNTCTCBPEModel
X = ROOT + '/x'

def load():
    cfg = OmegaConf.load(X + '/model_config.yaml')
    def fix(n):
        if isinstance(n, str) and n.startswith('nemo:'): return X + '/' + n[5:]
        return n
    cont = OmegaConf.to_container(cfg, resolve=False)
    def walk(o):
        if isinstance(o, dict): return {k: walk(v) for k, v in o.items()}
        if isinstance(o, list): return [walk(v) for v in o]
        return fix(o)
    cfg = OmegaConf.create(walk(cont))
    cfg.train_ds = None; cfg.validation_ds = None; cfg.test_ds = None
    m = EncDecHybridRNNTCTCBPEModel(cfg=cfg.model if 'model' in cfg else cfg, trainer=None)
    sd = torch.load(X + '/model_weights.ckpt', map_location='cpu')
    print(m.load_state_dict(sd, strict=False))
    return m.eval()
if __name__ == '__main__':
    m = load()
    print(type(m.preprocessor).__name__, sum(p.numel() for p in m.encoder.parameters())/1e6, 'M enc params')
    print('dec', sum(p.numel() for p in m.decoder.parameters())/1e6, 'joint', sum(p.numel() for p in m.joint.parameters())/1e6, 'ctc', sum(p.numel() for p in m.ctc_decoder.parameters())/1e6)
