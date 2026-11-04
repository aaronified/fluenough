import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loadmodel import load, ROOT
import numpy as np, torch
m = load()
LANG = 'te'
cols = [i for i, l in m.tokenizer.langs_by_token_id.items() if l == LANG]
assert cols == list(range(cols[0], cols[0] + len(cols))), 'non contiguous'
print('te token cols', cols[0], cols[-1], len(cols), 'blank col', m.ctc_decoder._num_classes - 1)
sel = cols + [m.ctc_decoder._num_classes - 1]  # blank is last -> index 256 after slicing
# vocabulary for the language (id -> piece), blank = len
tok = m.tokenizer.tokenizers_dict[LANG]
vocab = [tok.tokenizer.id_to_piece(i) for i in range(tok.tokenizer.get_piece_size())]
print('te sp vocab', len(vocab), vocab[:12])
json.dump({'lang': LANG, 'pieces': vocab, 'blank_id': len(sel) - 1, 'ctc_cols': sel[:1] + sel[-2:]}, open(ROOT + '/out/te_vocab.json', 'w'), ensure_ascii=False)

class CtcTe(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.enc = m.encoder
        conv = m.ctc_decoder.decoder_layers[0]
        self.w = torch.nn.Parameter(conv.weight[sel].detach().clone(), requires_grad=False)
        self.b = torch.nn.Parameter(conv.bias[sel].detach().clone(), requires_grad=False)
    def forward(self, feats, length):  # feats [B,80,T] normalised log-mel, length [B] int64
        enc, enc_len = self.enc(audio_signal=feats, length=length)
        logits = torch.nn.functional.conv1d(enc, self.w, self.b).transpose(1, 2)  # [B,T/4,257]
        return logits, enc_len
w = CtcTe().eval()
x = torch.randn(1, 80, 400); l = torch.tensor([400])
with torch.no_grad():
    ref, rl = w(x, l)
    print('out', ref.shape, rl)
    torch.onnx.export(w, (x, l), ROOT + '/out/te_ctc_fp32.onnx', input_names=['feats', 'length'],
        output_names=['logits', 'enc_len'], dynamic_axes={'feats': {0: 'B', 2: 'T'}, 'length': {0: 'B'}, 'logits': {0: 'B', 1: 'T'}, 'enc_len': {0: 'B'}},
        opset_version=17, dynamo=False)
print('exported')
