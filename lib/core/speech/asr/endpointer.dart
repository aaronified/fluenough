/// Energy end-of-speech detector for the on-device listener (#1004).
///
/// Takes little-endian int16 mono PCM in chunks of any size (an odd byte is
/// carried to the next chunk) and cuts it into 20 ms frames. A frame is loud
/// when its RMS, as a fraction of full scale, reaches [threshold]. Speech
/// starts at the first loud frame. The listen is done when speech has been
/// followed by [quietFor] seconds without a loud frame, when [maxSeconds] of
/// audio has been fed, or when [neverSpeechSeconds] have passed with no speech.
///
/// The threshold is fixed, not adaptive: simple and easy to test. Tune it on
/// a phone (the timing logs of task 15 show the real levels).
library;

import 'dart:math' as math;
import 'dart:typed_data';

const double _frameSeconds = 0.02;
const double _fullScale = 32768.0;

/// Default RMS threshold, as a fraction of full scale (about -40 dBFS).
const double defaultEndpointThreshold = 0.01;

/// Detects when a learner has finished speaking, from PCM chunks.
class Endpointer {
  /// [maxSeconds] and [neverSpeechSeconds] have no defaults: the caller
  /// chooses them for its drill. [quietFor] is the silence that ends a
  /// take once speech has started. Invalid arguments throw an
  /// [ArgumentError]; [log] receives every caught error.
  Endpointer(
    int sampleRate, {
    required double maxSeconds,
    required double neverSpeechSeconds,
    this.quietFor = 1.0,
    this.threshold = defaultEndpointThreshold,
    this.log,
  }) : _frameSamples = (sampleRate * _frameSeconds).round(),
       _maxSamples = (maxSeconds * sampleRate).round(),
       _neverSamples = (neverSpeechSeconds * sampleRate).round(),
       _quietSamplesNeeded = (quietFor * sampleRate).round() {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'must be positive');
    }
    if (maxSeconds <= 0) {
      throw ArgumentError.value(maxSeconds, 'maxSeconds', 'must be positive');
    }
    if (neverSpeechSeconds <= 0) {
      throw ArgumentError.value(
        neverSpeechSeconds,
        'neverSpeechSeconds',
        'must be positive',
      );
    }
    if (quietFor < 0) {
      throw ArgumentError.value(quietFor, 'quietFor', 'must not be negative');
    }
    if (threshold < 0) {
      throw ArgumentError.value(threshold, 'threshold', 'must not be negative');
    }
  }

  /// Silence, in seconds, that ends the take once speech has started.
  final double quietFor;

  /// RMS level, as a fraction of full scale, that counts as speech.
  final double threshold;

  /// Receives every caught error. Null when nobody is listening.
  final void Function(String)? log;

  final int _frameSamples;
  final int _maxSamples;
  final int _neverSamples;
  final int _quietSamplesNeeded;

  int _totalSamples = 0;
  int _frameFill = 0;
  double _frameSumSquares = 0;
  int _quietSamples = 0;
  bool _speechStarted = false;
  bool _done = false;
  int? _pendingByte;

  /// True once a frame has been loud.
  bool get speechStarted => _speechStarted;

  /// True when the take is over: speech then [quietFor] of silence, the
  /// [maxSeconds] limit, or [neverSpeechSeconds] without speech.
  bool get done => _done;

  /// Feeds one chunk of little-endian int16 mono PCM. An empty chunk does
  /// nothing. Once [done] is true, further chunks are ignored. An unexpected
  /// error is logged, ends the take (so the listen cannot hang), and is
  /// rethrown.
  void feed(Uint8List chunk) {
    if (_done || chunk.isEmpty) return;
    _guard('Endpointer.feed', () {
      var i = 0;
      final pending = _pendingByte;
      if (pending != null) {
        _pendingByte = null;
        _addSample(_sampleFrom(pending, chunk[0]));
        i = 1;
      }
      while (i + 1 < chunk.length && !_done) {
        _addSample(_sampleFrom(chunk[i], chunk[i + 1]));
        i += 2;
      }
      if (!_done && i < chunk.length) _pendingByte = chunk[i];
    });
  }

  void _addSample(int sample) {
    _totalSamples++;
    _frameSumSquares += sample * sample.toDouble();
    _frameFill++;
    if (_frameFill == _frameSamples) {
      final rms = math.sqrt(_frameSumSquares / _frameSamples) / _fullScale;
      _frameFill = 0;
      _frameSumSquares = 0;
      if (rms >= threshold) {
        _speechStarted = true;
        _quietSamples = 0;
      } else if (_speechStarted) {
        _quietSamples += _frameSamples;
      }
    }
    if (_speechStarted && _quietSamples >= _quietSamplesNeeded) {
      _done = true;
    } else if (_totalSamples >= _maxSamples) {
      _done = true;
    } else if (!_speechStarted && _totalSamples >= _neverSamples) {
      _done = true;
    }
  }

  /// Runs [body]; any error is reported to [log] and rethrown, after the
  /// take is ended so that nothing waits for it.
  void _guard(String where, void Function() body) {
    try {
      body();
    } catch (e, st) {
      _done = true;
      log?.call('$where failed: $e\n$st');
      rethrow;
    }
  }
}

/// Little-endian signed 16-bit sample from its two bytes.
int _sampleFrom(int low, int high) {
  final unsigned = low | (high << 8);
  return unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
}
