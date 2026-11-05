import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../sound/sound_check.dart' show peakOfPcm16;
import 'speech_engine.dart';

/// Keeps the sound of the microphone while the recogniser listens, so that
/// the learner can hear the first attempt back (ADR-0054, option 1).
///
/// Narrow enough that tests fake it. Both calls must never throw and never
/// delay the recogniser: a capture that cannot run gives no audio, and the
/// drill falls back to the second take of "Hear yourself".
abstract interface class MicCapture {
  /// Starts keeping audio. Called once the recogniser is already listening,
  /// so that it has the microphone first. Does nothing if the microphone
  /// cannot be shared.
  Future<void> start();

  /// Stops and gives what was kept, or null when nothing usable was (the
  /// capture could not start, or only silence came). Lets go of the
  /// microphone.
  Future<OwnAudio?> finish();
}

/// The microphone through `record`, as PCM in memory only: nothing is
/// written to disk, as with the sound check's recordings.
class RecordMicCapture implements MicCapture {
  static const int _sampleRate = 16000;

  /// Below this peak a take counts as silence, as in the sound check.
  static const double silence = 0.01;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _listening;
  BytesBuilder? _bytes;
  int _rate = _sampleRate;

  Future<void>? _starting;

  @override
  Future<void> start() => _starting = _start();

  Future<void> _start() async {
    await finish();
    final recorder = AudioRecorder();
    _recorder = recorder;
    try {
      // The recogniser asked for the permission already; never ask here.
      if (!await recorder.hasPermission()) {
        await finish();
        return;
      }
      await recorder.setOnConfigChanged((config) => _rate = config.sampleRate);
      final bytes = _bytes = BytesBuilder(copy: false);
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _listening = stream.listen(bytes.add, onError: (Object _) {});
    } catch (_) {
      await finish();
    }
  }

  @override
  Future<OwnAudio?> finish() async {
    // A finish that comes while the recorder is still starting waits for it.
    final starting = _starting;
    _starting = null;
    if (starting != null) await starting;
    final recorder = _recorder;
    final listening = _listening;
    final bytes = _bytes;
    final rate = _rate;
    _recorder = null;
    _listening = null;
    _bytes = null;
    _rate = _sampleRate;
    if (recorder == null) return null;
    try {
      await recorder.stop();
    } catch (_) {}
    try {
      await listening?.cancel();
    } catch (_) {}
    unawaited(recorder.dispose().catchError((Object _) {}));
    final pcm = bytes?.takeBytes();
    if (pcm == null || pcm.isEmpty || peakOfPcm16(pcm) < silence) return null;
    return OwnAudio(pcm, sampleRate: rate);
  }
}
