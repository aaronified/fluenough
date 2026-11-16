/// Chooses between the on-device AI listener and the system recogniser
/// (#1004).
///
/// When the language's pack is installed the on-device engine listens and
/// nothing else does: an empty transcript is a no-match, not a reason to ask
/// the system recogniser (second-guessing a silent take is what is broken
/// today). Only a runtime or load error ([AsrSpeechCode.runtimeError]) falls
/// back, once, to the system engine, and the fall back is logged. With no
/// pack the system engine listens as before. The online path stays the
/// system engine's: it is the default until a pack is installed.
library;

import '../speech_engine.dart';
import 'asr_pack.dart';
import 'on_device_speech_engine.dart';

class PreferOnDeviceSpeechEngine implements SpeechEngine {
  PreferOnDeviceSpeechEngine({
    required this.aiListener,
    required this.system,
    required this.packs,
    required this.log,
  });

  /// The on-device AI listener.
  final SpeechEngine aiListener;

  /// The system recogniser.
  final SpeechEngine system;
  final AsrPackLocator packs;
  final void Function(String) log;

  /// Which engine the running listen uses, so [stop] reaches it.
  SpeechEngine? _active;

  /// Both engines read the same microphone permission; the system engine's
  /// answer is the one the app has always used.
  @override
  Future<bool> hasPermission() => system.hasPermission();

  @override
  Future<bool> start() => system.start();

  /// The system's languages plus the installed packs'. A failure of the
  /// system engine is logged and thrown on, as its own contract says.
  @override
  Future<Set<String>> languages() async {
    final all = <String>{};
    try {
      all.addAll(await system.languages());
    } catch (e, st) {
      log('PreferOnDeviceSpeechEngine: system languages failed: $e\n$st');
      rethrow;
    }
    try {
      all.addAll(await packs.installed());
    } catch (e, st) {
      log('PreferOnDeviceSpeechEngine: installed packs failed: $e\n$st');
    }
    return all;
  }

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    final code = bcp47.split(RegExp('[-_]')).first.toLowerCase();
    var installed = false;
    try {
      installed = await packs.find(code) != null;
    } catch (e, st) {
      log(
        'PreferOnDeviceSpeechEngine: checking the $code pack failed: $e\n$st',
      );
    }
    if (installed) {
      _active = aiListener;
      SpeechHeard heard;
      try {
        heard = await aiListener.listen(
          bcp47: bcp47,
          onDevice: true,
          listenFor: listenFor,
        );
      } catch (e, st) {
        log('PreferOnDeviceSpeechEngine: on-device listen threw: $e\n$st');
        heard = const SpeechHeard.failed(
          SpeechFailure.other,
          code: AsrSpeechCode.runtimeError,
        );
      }
      if (heard.failure != SpeechFailure.other ||
          heard.code != AsrSpeechCode.runtimeError) {
        _active = null;
        return heard;
      }
      log(
        'PreferOnDeviceSpeechEngine: the on-device listener failed for $code '
        '(${heard.code}); using the system recogniser this once',
      );
    }
    _active = system;
    try {
      return await system.listen(
        bcp47: bcp47,
        onDevice: onDevice,
        listenFor: listenFor,
      );
    } finally {
      _active = null;
    }
  }

  @override
  Future<void> stop() async {
    await (_active ?? system).stop();
  }
}
