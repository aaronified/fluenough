import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'sound_check.dart';

/// The phone's microphone, through `record`, and its speaker, through
/// `audioplayers` (#89). The recording stays in memory: it streams as PCM,
/// is wrapped as WAV, played back, and dropped. Nothing is saved.
class SystemSoundCheck implements SoundCheckEngine {
  SystemSoundCheck();

  static const int _sampleRate = 16000;

  /// Below this peak a recording counts as silence: a muted or covered
  /// microphone still picks up a little noise.
  static const double silence = 0.01;

  @override
  Future<bool> hasPermission() async {
    final recorder = AudioRecorder();
    try {
      return await recorder.hasPermission(request: false);
    } catch (_) {
      return false;
    } finally {
      unawaited(recorder.dispose());
    }
  }

  @override
  Future<Recording> record(Duration duration) async {
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        return const Recording.failed(RecordFailure.refused);
      }
      final bytes = BytesBuilder(copy: false);
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      final listening = stream.listen(bytes.add);
      await Future<void>.delayed(duration);
      await recorder.stop();
      await listening.cancel();
      final pcm = bytes.takeBytes();
      if (pcm.isEmpty) return const Recording.failed(RecordFailure.failed);
      if (peakOfPcm16(pcm) < silence) {
        return const Recording.failed(RecordFailure.silent);
      }
      return Recording(wavFromPcm16(pcm, sampleRate: _sampleRate));
    } catch (_) {
      return const Recording.failed(RecordFailure.failed);
    } finally {
      unawaited(recorder.dispose());
    }
  }

  @override
  Future<bool> play(Recording recording) async {
    final wav = recording.wav;
    if (wav == null) return false;
    final player = AudioPlayer();
    try {
      final done = player.onPlayerComplete.first;
      await player.play(BytesSource(wav, mimeType: 'audio/wav'));
      // The recording's own length, and a little more for the player to
      // start; a player that never reports is given up on.
      final seconds = (wav.length - 44) / (_sampleRate * 2);
      await done.timeout(
        Duration(milliseconds: (seconds * 1000).round() + 3000),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      unawaited(player.dispose());
    }
  }
}
