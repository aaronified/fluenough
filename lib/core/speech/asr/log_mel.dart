/// Pure-Dart log-mel front end for the on-device listener (#1004).
///
/// A port of tools/asr/np_features.py, the numpy reference the IndicConformer
/// hybrid models use (NeMo AudioToMelSpectrogramPreprocessor): 16 kHz mono,
/// 25 ms symmetric Hann window centred in a 512-point FFT, 10 ms hop,
/// pre-emphasis 0.97, 80 slaney mel bins, log(power + 2^-24), then per-feature
/// mean and std normalisation over time (std with ddof 1, plus 1e-5).
/// The golden frames are in test/fixtures/asr/golden_mel.json.
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 16000;
const int _nFft = 512;
const int _win = 400;
const int _hop = 160;
const int _nMels = 80;
const int _nBins = _nFft ~/ 2 + 1;
const double _preemph = 0.97;
const double _logGuard = 1.0 / 16777216.0; // 2^-24
const double _normEps = 1e-5;
final double _logStep = math.log(6.4) / 27.0;

/// Runs [body]; any error is reported to [log] (when given) and rethrown.
T _guard<T>(String where, void Function(String)? log, T Function() body) {
  try {
    return body();
  } catch (e, st) {
    log?.call('$where failed: $e\n$st');
    rethrow;
  }
}

/// Log-mel features of little-endian int16 mono PCM at 16 kHz.
///
/// Returns one Float32List of 80 normalised values per frame, in time order
/// (the same frames as np_features.log_mel, transposed). Returns an empty list
/// when the input has no samples or is shorter than one 400-sample window; both
/// cases are logged. A trailing odd byte is ignored and logged. Unexpected
/// errors are logged and rethrown.
List<Float32List> logMel(Uint8List pcm16le, {void Function(String)? log}) {
  return _guard('logMel', log, () {
    if (pcm16le.length.isOdd) {
      log?.call(
        'logMel: odd byte length ${pcm16le.length}, ignoring the last byte',
      );
    }
    final nSamples = pcm16le.length ~/ 2;
    if (nSamples == 0) {
      log?.call('logMel: empty input');
      return <Float32List>[];
    }
    if (nSamples < _win) {
      log?.call('logMel: $nSamples samples is shorter than one window ($_win)');
      return <Float32List>[];
    }
    final x = _toFloat(pcm16le, nSamples, log);
    final feat = _logMelFrames(x, log);
    return _normalise(feat, log);
  });
}

/// int16 little-endian samples to doubles in [-1, 1).
Float64List _toFloat(Uint8List pcm, int n, void Function(String)? log) {
  return _guard('pcm to float', log, () {
    final bd = ByteData.sublistView(pcm);
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(2 * i, Endian.little) / 32768.0;
    }
    return out;
  });
}

/// Un-normalised log-mel frames (frame-major, 80 values each).
List<Float64List> _logMelFrames(Float64List x, void Function(String)? log) {
  return _guard('log-mel frames', log, () {
    final n = x.length;
    final pad = _nFft ~/ 2;
    final y = Float64List(n);
    y[0] = x[0];
    for (var i = 1; i < n; i++) {
      y[i] = x[i] - _preemph * x[i - 1];
    }
    // numpy 'reflect' padding of the pre-emphasised signal (n >= 400 > pad).
    double at(int i) {
      var j = i - pad;
      if (j < 0) j = -j;
      if (j >= n) j = 2 * (n - 1) - j;
      return y[j];
    }

    final window = _window(log);
    final fb = _filterbank(log);
    final plan = _FftPlan(log);
    final re = Float64List(_nFft);
    final im = Float64List(_nFft);
    final power = Float64List(_nBins);
    final nFrames = 1 + n ~/ _hop; // equals NeMo's valid length
    final frames = <Float64List>[];
    for (var t = 0; t < nFrames; t++) {
      final base = t * _hop;
      for (var j = 0; j < _nFft; j++) {
        re[j] = at(base + j) * window[j];
        im[j] = 0.0;
      }
      plan.transform(re, im, log);
      for (var k = 0; k < _nBins; k++) {
        power[k] = re[k] * re[k] + im[k] * im[k];
      }
      final mel = Float64List(_nMels);
      for (var m = 0; m < _nMels; m++) {
        final row = fb[m];
        var acc = 0.0;
        for (var k = 0; k < _nBins; k++) {
          acc += row[k] * power[k];
        }
        mel[m] = math.log(acc + _logGuard);
      }
      frames.add(mel);
    }
    return frames;
  });
}

/// Per-feature mean/std normalisation over time; output is frame-major.
List<Float32List> _normalise(
  List<Float64List> feat,
  void Function(String)? log,
) {
  return _guard('normalise', log, () {
    final n = feat.length;
    final out = List<Float32List>.generate(n, (_) => Float32List(_nMels));
    for (var m = 0; m < _nMels; m++) {
      var sum = 0.0;
      for (final f in feat) {
        sum += f[m];
      }
      final mean = sum / n;
      var std = 0.0;
      if (n > 1) {
        var ss = 0.0;
        for (final f in feat) {
          final d = f[m] - mean;
          ss += d * d;
        }
        std = math.sqrt(ss / (n - 1));
      }
      final denom = std + _normEps;
      for (var t = 0; t < n; t++) {
        out[t][m] = (feat[t][m] - mean) / denom;
      }
    }
    return out;
  });
}

/// Symmetric Hann over 400 samples, centred in the 512-point frame.
Float64List _window(void Function(String)? log) {
  return _guard('window', log, () {
    final w = Float64List(_nFft);
    final off = (_nFft - _win) ~/ 2;
    for (var j = 0; j < _win; j++) {
      w[off + j] = 0.5 - 0.5 * math.cos(2 * math.pi * j / (_win - 1));
    }
    return w;
  });
}

double _hzToMel(double f) => f >= 1000.0
    ? 15.0 + math.log(math.max(f, 1e-9) / 1000.0) / _logStep
    : f / (200.0 / 3);

double _melToHz(double m) =>
    m >= 15.0 ? 1000.0 * math.exp(_logStep * (m - 15.0)) : (200.0 / 3) * m;

/// Slaney-scaled, area-normalised triangular filters (80 x 257).
List<Float64List> _filterbank(void Function(String)? log) {
  return _guard('filterbank', log, () {
    const fmax = _sampleRate / 2;
    final fftFreqs = List<double>.generate(
      _nBins,
      (k) => k * (_sampleRate / 2) / (_nBins - 1),
    );
    final lo = _hzToMel(0.0);
    final hi = _hzToMel(fmax);
    final melF = List<double>.generate(
      _nMels + 2,
      (i) => _melToHz(lo + i * (hi - lo) / (_nMels + 1)),
    );
    final fdiff = List<double>.generate(
      _nMels + 1,
      (i) => melF[i + 1] - melF[i],
    );
    final fb = <Float64List>[];
    for (var m = 0; m < _nMels; m++) {
      final row = Float64List(_nBins);
      final norm = 2.0 / (melF[m + 2] - melF[m]);
      for (var k = 0; k < _nBins; k++) {
        final f = fftFreqs[k];
        final lower = -(melF[m] - f) / fdiff[m];
        final upper = (melF[m + 2] - f) / fdiff[m + 1];
        final w = math.min(lower, upper);
        row[k] = (w > 0 ? w : 0.0) * norm;
      }
      fb.add(row);
    }
    return fb;
  });
}

/// Radix-2 forward FFT tables for the 512-point transform.
class _FftPlan {
  _FftPlan(void Function(String)? log) {
    _guard('fft plan', log, () {
      for (var k = 0; k < _nFft ~/ 2; k++) {
        cosT[k] = math.cos(2 * math.pi * k / _nFft);
        sinT[k] = math.sin(2 * math.pi * k / _nFft);
      }
      final bits = (math.log(_nFft) / math.ln2).round();
      for (var i = 0; i < _nFft; i++) {
        var r = 0;
        var v = i;
        for (var b = 0; b < bits; b++) {
          r = (r << 1) | (v & 1);
          v >>= 1;
        }
        rev[i] = r;
      }
    });
  }

  final Float64List cosT = Float64List(_nFft ~/ 2);
  final Float64List sinT = Float64List(_nFft ~/ 2);
  final Int32List rev = Int32List(_nFft);

  /// In-place forward transform of (re, im).
  void transform(Float64List re, Float64List im, void Function(String)? log) {
    _guard('fft', log, () {
      for (var i = 0; i < _nFft; i++) {
        final j = rev[i];
        if (j > i) {
          final tr = re[i];
          re[i] = re[j];
          re[j] = tr;
          final ti = im[i];
          im[i] = im[j];
          im[j] = ti;
        }
      }
      for (var len = 2; len <= _nFft; len <<= 1) {
        final half = len >> 1;
        final step = _nFft ~/ len;
        for (var start = 0; start < _nFft; start += len) {
          for (var k = 0; k < half; k++) {
            final wr = cosT[k * step];
            final wi = -sinT[k * step];
            final a = start + k;
            final b = a + half;
            final xr = re[b] * wr - im[b] * wi;
            final xi = re[b] * wi + im[b] * wr;
            re[b] = re[a] - xr;
            im[b] = im[a] - xi;
            re[a] += xr;
            im[a] += xi;
          }
        }
      }
    });
  }
}
