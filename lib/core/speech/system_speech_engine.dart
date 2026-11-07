import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../sound/sound_check.dart' show peakOfPcm16;
import 'mic_capture.dart';
import 'native_listen.dart';
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
  SystemSpeechEngine([
    SpeechToText? plugin,
    MicCapture? capture,
    NativeListener? native,
  ]) : _plugin = plugin ?? SpeechToText(),
       // In a browser two readers of the microphone are not safe, and the
       // web build uses `WebSpeechEngine`; a capture given here is ignored
       // rather than started (the same constant as Flutter's `kIsWeb`).
       _capture = _inBrowser ? null : capture,
       _native = _inBrowser ? null : native;

  static const bool _inBrowser = bool.fromEnvironment('dart.library.js_util');

  final SpeechToText _plugin;

  /// Keeps the learner's audio beside each listen, or null to keep none.
  /// `speech_to_text` exposes no audio itself, so the capture is a second
  /// reader of the microphone (ADR-0054, option 1). It is best effort: it
  /// starts after the recogniser has the microphone, never throws, and
  /// switches itself off if listens start failing to match while it runs,
  /// so that a phone that cannot share the microphone listens as before.
  final MicCapture? _capture;
  int _unmatchedWithCapture = 0;

  /// The listen that owns the microphone and feeds the recogniser from it
  /// (Android 13 and later, ADR-0054 option 2), so that the audio kept is
  /// exactly what was recognised and no second reader of the microphone is
  /// needed. Null where there is none. It is tried first; a phone, or a
  /// recogniser, that cannot do it listens the plain way, as before, and is
  /// not asked again after two listens in a row that failed on this side or
  /// heard nothing.
  final NativeListener? _native;
  int _nativeTrouble = 0;
  bool _nativeOpen() =>
      _native != null && _nativeTrouble < _captureGivesUpAfter;

  /// After this many listens in a row that heard nothing while the capture
  /// ran, the capture is given up for good.
  static const int _captureGivesUpAfter = 2;
  bool get _capturing =>
      _capture != null && _unmatchedWithCapture < _captureGivesUpAfter;
  Completer<SpeechHeard>? _listening;
  bool _listeningOnDevice = true;
  bool _started = false;

  /// The best reading of the latest partial result, kept as a fallback for
  /// a listen whose final result never comes (see [_onStatus]).
  List<SpeechAlternative> _partial = const <SpeechAlternative>[];
  Timer? _doneTimer;

  /// How long to wait for a final result after Android says it is done.
  /// Some recognisers (Samsung's offline one) end the listen on the
  /// plugin's one-second end-of-speech timer, before the final result.
  static const Duration _doneGrace = Duration(milliseconds: 2500);

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
    } catch (e) {
      throw SpeechError(codeOf(e));
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
    } catch (e) {
      _started = false;
      throw SpeechError(codeOf(e));
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
    } catch (e) {
      throw SpeechError(codeOf(e));
    }
  }

  /// An error's code for the app log: a platform error's own, `timeout`
  /// for a deadline passed, or else its type.
  static String codeOf(Object error) => switch (error) {
    PlatformException(:final code) => code,
    TimeoutException() => 'timeout',
    _ => '${error.runtimeType}',
  };

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    try {
      if (!_started && !await start()) {
        return SpeechHeard.failed(
          await hasPermission()
              ? SpeechFailure.noRecogniser
              : SpeechFailure.permissionDenied,
        );
      }
    } on SpeechError catch (e) {
      return SpeechHeard.failed(SpeechFailure.noRecogniser, code: e.code);
    }
    if (_nativeOpen()) {
      final heard = await _listenNative(bcp47, onDevice, listenFor);
      if (heard != null) return heard;
    }
    final capture = _capturing ? _capture : null;
    if (capture != null) await capture.finish();
    _listening?.complete(const SpeechHeard.failed(SpeechFailure.other));
    final done = _listening = Completer<SpeechHeard>();
    _partial = const <SpeechAlternative>[];
    _doneTimer?.cancel();
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
          // Partial results are on only as a fallback: a done status can
          // come before the final result, and then the last partial is
          // what was heard.
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      _finish(SpeechHeard.failed(SpeechFailure.other, code: codeOf(e)));
    }
    // After the recogniser has the microphone, so that it is not the one
    // that is shut out. Not awaited: it must not hold up the result.
    if (capture != null) unawaited(capture.start());
    final heard = await done.future.timeout(
      listenFor + _grace,
      onTimeout: () {
        _plugin.cancel();
        _doneTimer?.cancel();
        _listening = null;
        return _partial.isNotEmpty
            ? SpeechHeard(_partial)
            : const SpeechHeard.failed(SpeechFailure.noMatch, code: 'timeout');
      },
    );
    if (capture == null) return heard;
    final audio = await capture.finish();
    _unmatchedWithCapture = heard.failure == SpeechFailure.noMatch
        ? _unmatchedWithCapture + 1
        : 0;
    if (heard.failed || audio == null) return heard;
    return SpeechHeard(heard.alternatives, ownAudio: audio);
  }

  /// A listen through the native side, or null when the plain way should
  /// listen instead.
  Future<SpeechHeard?> _listenNative(
    String bcp47,
    bool onDevice,
    Duration listenFor,
  ) async {
    final native = _native!;
    try {
      if (!await native.available) {
        _nativeTrouble = _captureGivesUpAfter;
        return null;
      }
      final result = await native
          .listen(bcp47: bcp47, onDevice: onDevice, listenFor: listenFor)
          .timeout(
            listenFor + _grace + const Duration(seconds: 2),
            onTimeout: () {
              unawaited(native.cancel());
              return const NativeListenResult(error: 'exception');
            },
          );
      if (result.fallsBack) {
        _nativeTrouble++;
        return null;
      }
      final audio = result.audio;
      final voiced =
          audio != null && peakOfPcm16(audio.pcm16) >= RecordMicCapture.silence;
      final error = result.error;
      final nothingHeard = error == null
          ? result.alternatives.isEmpty
          : failureOf(error, onDevice: onDevice) == SpeechFailure.noMatch;
      if (nothingHeard && !voiced) {
        // Nothing recognised AND a silent stream: the phone shut the
        // microphone to our capture (or the recogniser ignored the stream),
        // so the recogniser had no voice to hear. Do not tell the learner
        // "no match" for that: listen again the plain way in this very
        // attempt, and do not try the native route again this session.
        _nativeTrouble = _captureGivesUpAfter;
        return null;
      }
      if (error != null) {
        final failure = failureOf(error, onDevice: onDevice);
        // A listen that heard a voice and still found no match is the
        // learner's, not the phone's: not trouble.
        _nativeTrouble = 0;
        return SpeechHeard.failed(failure, code: error);
      }
      if (result.alternatives.isEmpty) {
        return const SpeechHeard.failed(
          SpeechFailure.noMatch,
          code: 'empty-result',
        );
      }
      _nativeTrouble = 0;
      // A stream that is only silence was not the learner's voice (the phone
      // shut the microphone to us): the drill records a second take instead.
      return SpeechHeard(result.alternatives, ownAudio: voiced ? audio : null);
    } on Object {
      _nativeTrouble++;
      return null;
    }
  }

  @override
  Future<void> stop() async {
    unawaited(_native?.cancel());
    try {
      await _plugin.stop();
    } catch (e) {
      throw SpeechError(codeOf(e));
    }
  }

  void _finish(SpeechHeard heard) {
    _doneTimer?.cancel();
    _doneTimer = null;
    final done = _listening;
    _listening = null;
    if (done != null && !done.isCompleted) done.complete(heard);
  }

  void _onResult(SpeechRecognitionResult result) {
    final alternatives = alternativesOf(result);
    if (!result.finalResult) {
      if (alternatives.isNotEmpty) _partial = alternatives;
      return;
    }
    if (alternatives.isNotEmpty) {
      _finish(SpeechHeard(alternatives));
    } else if (_partial.isNotEmpty) {
      _finish(SpeechHeard(_partial));
    } else {
      _finish(
        const SpeechHeard.failed(SpeechFailure.noMatch, code: 'empty-result'),
      );
    }
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
    SpeechHeard.failed(
      failureOf(error.errorMsg, onDevice: _listeningOnDevice),
      code: error.errorMsg,
    ),
  );

  void _onStatus(String status) {
    if (status != SpeechToText.doneStatus || _listening == null) return;
    // Done: the final result may still be on its way, so give it a moment,
    // then fall back on the last partial, else nothing was heard.
    _doneTimer?.cancel();
    _doneTimer = Timer(_doneGrace, () {
      _finish(
        _partial.isNotEmpty
            ? SpeechHeard(_partial)
            : const SpeechHeard.failed(
                SpeechFailure.noMatch,
                code: 'done-before-result',
              ),
      );
    });
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
