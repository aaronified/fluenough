import sys, os
from onnxruntime.quantization import quantize_dynamic, QuantType
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/out/'
quantize_dynamic(R + 'te_ctc_fp32.onnx', R + 'te_ctc_int8.onnx', weight_type=QuantType.QInt8, per_channel=False)
for f in ('te_ctc_fp32.onnx', 'te_ctc_int8.onnx'): print(f, os.path.getsize(R + f) / 1e6, 'MB')
