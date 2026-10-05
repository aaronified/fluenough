import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_engine.dart';

/// The operating system's speech recogniser, through the `speech_to_text`
/// plugin (ADR-0014). On Android an on-device listen uses the on-device
/// recogniser (`createOnDeviceSpeechRecognizer`, Android 12 and later), and
/// before that asks the default one to stay offline.
///
/// The plugin calls back rather than returning, so [listen] collects its
/// callbacks into one result, with a deadline: a recogniser that never
/// answers yields no match rather than a session that waits for ever.
class SystemSpeechEngine implements SpeechEngine {
  SystemSpeechEngine([SpeechToText? plugin])
    : _plugin = plugin ?? SpeechToText();

  final SpeechToText _plugin;
  Completer<SpeechHeard>? _listening;
  bool _listeningOnDevice = true;
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
    _listeningOnDevice = onDevice;
    try {
      await _plugin.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: bcp47,
          onDevice: onDevice,
          listenFor: listenFor,
          // No pauseFor. The plugin counts it from the tap and only a
          // partial result restarts it, and partial results are off, so a
          // 3 s pause cut every listen off 3 s in, mid-word or before the
          // learner had begun. Android ends a listen itself once speech
          // stops.
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
    final alternatives = alternativesOf(result);
    _finish(
      alternatives.isEmpty
          ? const SpeechHeard.failed(SpeechFailure.noMatch)
          : SpeechHeard(alternatives),
    );
  }

  /// A final result's readings, best first, without empty ones. The plugin
  /// gives -1 for no confidence; Android scores every reading after the
  /// best 0, which stays a low score.
  static List<SpeechAlternative> alternativesOf(
    SpeechRecognitionResult result,
  ) => <SpeechAlternative>[
    for (final words in result.alternates)
      if (words.recognizedWords.trim().isNotEmpty)
        SpeechAlternative(
          words.recognizedWords,
          confidence: words.hasConfidenceRating && words.confidence >= 0
              ? words.confidence
              : null,
        ),
  ];

  void _onError(SpeechRecognitionError error) => _finish(
    SpeechHeard.failed(failureOf(error.errorMsg, onDevice: _listeningOnDevice)),
  );

  void _onStatus(String status) {
    // Done with no final result: nothing was heard.
    if (status == SpeechToText.doneStatus) {
      _finish(const SpeechHeard.failed(SpeechFailure.noMatch));
    }
  }

  /// The plugin's error codes, as the reasons the app tells apart. A
  /// language the recogniser lacks means different things on the device and
  /// online.
  static SpeechFailure failureOf(String code, {required bool onDevice}) =>
      switch (code) {
        'error_language_not_supported' || 'error_language_unavailable' =>
          onDevice ? SpeechFailure.notOnDevice : SpeechFailure.unsupported,
        'error_no_match' || 'error_speech_timeout' => SpeechFailure.noMatch,
        'error_permission' => SpeechFailure.permissionDenied,
        'error_network' ||
        'error_network_timeout' ||
        'error_server' ||
        'error_server_disconnected' => SpeechFailure.network,
        _ => SpeechFailure.other,
      };
}
