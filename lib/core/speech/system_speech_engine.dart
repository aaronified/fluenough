import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_engine.dart';

/// The operating system's speech recogniser, through the `speech_to_text`
/// plugin (ADR-0014). On Android it prefers the on-device recogniser
/// (`createOnDeviceSpeechRecognizer`, Android 12 and later; offline mode
/// before), so audio stays on the phone unless a caller asks otherwise.
///
/// The plugin calls back rather than returning, so [listen] collects its
/// callbacks into one result, with a deadline: a recogniser that never
/// answers yields no match rather than a session that waits for ever.
class SystemSpeechEngine implements SpeechEngine {
  SystemSpeechEngine([SpeechToText? plugin])
    : _plugin = plugin ?? SpeechToText();

  final SpeechToText _plugin;
  Completer<SpeechHeard>? _listening;
  bool _started = false;

  /// How long past `listenFor` a listen may take to report before it is
  /// given up as no match.
  static const Duration _grace = Duration(seconds: 4);

  /// How long the languages may take: on some phones Android's support check
  /// never answers.
  static const Duration _languagesDeadline = Duration(seconds: 5);

  @override
  Future<bool> hasPermission() async {
    try {
      return await _plugin.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> start() async {
    if (_started) return true;
    try {
      _started = await _plugin.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } catch (_) {
      _started = false;
    }
    return _started;
  }

  @override
  Future<Set<String>> languages() async {
    if (!_started) return const <String>{};
    try {
      final locales = await _plugin.locales().timeout(_languagesDeadline);
      return <String>{
        for (final locale in locales)
          locale.localeId.split(RegExp('[-_]')).first.toLowerCase(),
      };
    } catch (_) {
      return const <String>{};
    }
  }

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    if (!_started && !await start()) {
      return SpeechHeard.failed(
        await hasPermission()
            ? SpeechFailure.noRecogniser
            : SpeechFailure.permissionDenied,
      );
    }
    _listening?.complete(const SpeechHeard.failed(SpeechFailure.other));
    final done = _listening = Completer<SpeechHeard>();
    try {
      await _plugin.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: bcp47,
          onDevice: onDevice,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 3),
          listenMode: ListenMode.confirmation,
          partialResults: false,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      _finish(const SpeechHeard.failed(SpeechFailure.other));
    }
    return done.future.timeout(
      listenFor + _grace,
      onTimeout: () {
        _plugin.cancel();
        _listening = null;
        return const SpeechHeard.failed(SpeechFailure.noMatch);
      },
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _plugin.stop();
    } catch (_) {}
  }

  void _finish(SpeechHeard heard) {
    final done = _listening;
    _listening = null;
    if (done != null && !done.isCompleted) done.complete(heard);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    final alternatives = <SpeechAlternative>[
      for (final words in result.alternates)
        if (words.recognizedWords.trim().isNotEmpty)
          SpeechAlternative(
            words.recognizedWords,
            // Android reports 0, or -1, when it gives no confidence.
            confidence: words.confidence > 0 ? words.confidence : null,
          ),
    ];
    _finish(
      alternatives.isEmpty
          ? const SpeechHeard.failed(SpeechFailure.noMatch)
          : SpeechHeard(alternatives),
    );
  }

  void _onError(SpeechRecognitionError error) =>
      _finish(SpeechHeard.failed(failureOf(error.errorMsg)));

  void _onStatus(String status) {
    // Done with no final result: nothing was heard.
    if (status == SpeechToText.doneStatus) {
      _finish(const SpeechHeard.failed(SpeechFailure.noMatch));
    }
  }

  /// The plugin's error codes, as the reasons the app tells apart.
  static SpeechFailure failureOf(String code) => switch (code) {
    'error_language_not_supported' ||
    'error_language_unavailable' => SpeechFailure.notOnDevice,
    'error_no_match' || 'error_speech_timeout' => SpeechFailure.noMatch,
    'error_permission' => SpeechFailure.permissionDenied,
    'error_network' ||
    'error_network_timeout' ||
    'error_server' ||
    'error_server_disconnected' => SpeechFailure.network,
    _ => SpeechFailure.other,
  };
}
