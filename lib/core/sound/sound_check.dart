import 'dart:math' as math;
import 'dart:typed_data';

/// Why a recording produced nothing to play back (#89).
enum RecordFailure {
  /// The microphone permission was refused.
  refused,

  /// Something was recorded, but only silence: the microphone is muted,
  /// covered or broken.
  silent,

  /// The recorder failed, or the phone has no microphone.
  failed,
}

/// A short recording, ready to play back, or why there is none.
class Recording {
  const Recording(Uint8List this.wav) : failure = null;

  const Recording.failed(RecordFailure this.failure) : wav = null;

  /// The recording as a WAV file, in memory.
  final Uint8List? wav;
  final RecordFailure? failure;

  bool get ok => wav != null;
}

/// The microphone and the speaker, for the first launch's sound check
/// (#89): record a moment, play it back. Narrow enough that tests fake it;
/// nothing outside `lib/core/sound` refers to a concrete one.
abstract interface class SoundCheckEngine {
  /// Records for [duration], asking for the microphone permission if it has
  /// not been granted, and asking again each time it was refused before.
  Future<Recording> record(Duration duration);

  /// Plays [recording] back. False when it could not be played.
  Future<bool> play(Recording recording);

  /// Cuts short a recording or playback under way, and lets go of the
  /// microphone: a drill moving on from "Hear yourself" (#231). A recording
  /// cut short ends with what it has; playback ends at once. Nothing under
  /// way: does nothing.
  Future<void> stop();
}

/// No microphone and no speaker: tests, and the gallery.
class NullSoundCheck implements SoundCheckEngine {
  const NullSoundCheck();

  @override
  Future<Recording> record(Duration duration) async =>
      const Recording.failed(RecordFailure.failed);

  @override
  Future<bool> play(Recording recording) async => false;

  @override
  Future<void> stop() async {}
}

/// A sound check that records and plays what it is told to. For tests and
/// the gallery.
class FixedSoundCheck implements SoundCheckEngine {
  FixedSoundCheck({this.grants = true, this.records, this.plays = true});

  /// Whether asking grants the microphone. Can change between attempts.
  bool grants;

  /// What a granted recording gives: a recording by default, or a failure.
  RecordFailure? records;

  /// Whether playback works.
  bool plays;

  bool _granted = false;

  /// How many times [record] was called, each one asking if not granted.
  int recordings = 0;

  /// How many times [play] was called.
  int playbacks = 0;

  /// How many times [stop] was called.
  int stops = 0;

  @override
  Future<Recording> record(Duration duration) async {
    recordings++;
    if (!_granted && grants) _granted = true;
    if (!_granted) return const Recording.failed(RecordFailure.refused);
    final failure = records;
    if (failure != null) return Recording.failed(failure);
    return Recording(wavFromPcm16(Uint8List(32), sampleRate: 16000));
  }

  @override
  Future<bool> play(Recording recording) async {
    playbacks++;
    return plays && recording.ok;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

/// Wraps 16-bit little-endian PCM [pcm] in a WAV header, so that a player
/// can play it from memory.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
}) {
  const bits = 16;
  final byteRate = sampleRate * channels * bits ~/ 8;
  final header = ByteData(44);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // the fmt chunk's size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * bits ~/ 8, Endian.little);
  header.setUint16(34, bits, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList(<int>[...header.buffer.asUint8List(), ...pcm]);
}

/// The loudest sample in 16-bit little-endian PCM [pcm], from 0 (silence)
/// to 1 (full scale).
double peakOfPcm16(Uint8List pcm) {
  final samples = ByteData.sublistView(pcm);
  var peak = 0;
  for (var i = 0; i + 1 < pcm.length; i += 2) {
    final sample = samples.getInt16(i, Endian.little).abs();
    if (sample > peak) peak = sample;
  }
  return peak / 32768;
}

/// A [duration] beep at [hertz], as 16-bit PCM: what the sound check plays
/// when there is no recording to play back.
Uint8List tonePcm16({
  required Duration duration,
  required int sampleRate,
  double hertz = 660,
  double volume = 0.3,
}) {
  final count = sampleRate * duration.inMilliseconds ~/ 1000;
  final pcm = ByteData(count * 2);
  // A short fade at each end, so the beep doesn't click.
  final fade = sampleRate ~/ 100;
  for (var i = 0; i < count; i++) {
    final edge = i < fade
        ? i / fade
        : i > count - fade
        ? (count - i) / fade
        : 1.0;
    final value = math.sin(2 * math.pi * hertz * i / sampleRate);
    pcm.setInt16(i * 2, (value * volume * edge * 32767).round(), Endian.little);
  }
  return pcm.buffer.asUint8List();
}

/// A short beep, as a recording: what the sound check plays when the
/// microphone gave nothing to play back.
Recording beep() => Recording(
  wavFromPcm16(
    tonePcm16(duration: const Duration(milliseconds: 700), sampleRate: 16000),
    sampleRate: 16000,
  ),
);
