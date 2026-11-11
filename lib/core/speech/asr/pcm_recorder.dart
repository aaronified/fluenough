import 'dart:async';
import 'dart:typed_data';

/// A microphone that gives raw PCM, for the on-device listener (#1004).
///
/// Call [hasPermission] first; [start] assumes permission was granted. The
/// stream carries little-endian int16 mono PCM at the requested rate, in
/// chunks of any size, and ends after [stop].
abstract interface class PcmRecorder {
  /// True when the app may record. Never asks the learner from here.
  Future<bool> hasPermission();

  /// Starts recording and returns the PCM stream.
  Stream<Uint8List> start(int sampleRate);

  /// Stops recording, ends the stream and lets go of the microphone.
  Future<void> stop();
}

/// A [PcmRecorder] for tests. The test pushes chunks with [add].
class FakePcmRecorder implements PcmRecorder {
  FakePcmRecorder({this.permitted = true});

  /// What [hasPermission] answers.
  final bool permitted;

  /// The sample rate of the last [start], or null before any start.
  int? startedRate;

  /// How many times [start] was called.
  int startCount = 0;

  /// How many times [stop] was called.
  int stopCount = 0;

  final StreamController<Uint8List> _controller = StreamController<Uint8List>();

  /// Pushes one chunk into the stream a [start] returned.
  void add(Uint8List chunk) => _controller.add(chunk);

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Stream<Uint8List> start(int sampleRate) {
    startedRate = sampleRate;
    startCount++;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (!_controller.isClosed) await _controller.close();
  }
}
