import 'dart:async';

import 'speech_engine.dart';
import 'web_speech_browser.dart';

/// The browser's speech recogniser, the Web Speech API (`SpeechRecognition`,
/// `webkitSpeechRecognition` in Chrome, Edge and Safari), as a
/// [SpeechEngine] (wiki: Plan-Web-Pwa, ADR-0014). Firefox has none: there
/// every listen fails as [SpeechFailure.noRecogniser], the path a phone
/// without a recogniser takes, so Find my level and the drills carry on as
/// they do without a microphone.
///
/// Why it is not `SystemSpeechEngine`: `speech_to_text`'s web code reports
/// every result as partial and keeps listening until stopped, so a listen
/// would end only by its deadline. This one asks for one utterance and its
/// final readings.
///
/// A browser recognises online only (Chrome sends the audio to Google, Safari
/// to Apple), so a listen that asks to stay [onDevice] is answered
/// [SpeechFailure.notOnDevice] at once, and the app asks the learner whether
/// to listen online, as it does for a language an Android phone lacks.
///
/// By default no recorder runs beside the recogniser (#1107): it keeps no
/// audio ([SpeechHeard.ownAudio] is null) and "Hear yourself" records a
/// second take instead. With [recordWhileRecognising] on, the browser's
/// recorder (`MediaRecorder`) starts with the recogniser and stops with it,
/// and the take is kept in memory as [SpeechHeard.ownAudio] (ADR-0054); a
/// browser that cannot record beside the recogniser gives none, and a
/// cancelled or failed listen keeps nothing.
class WebSpeechEngine implements OnlineOnlySpeech {
  WebSpeechEngine([SpeechBrowser? browser, this.recordWhileRecognising = false])
    : _browser = browser ?? openSpeechBrowser();

  /// Whether the browser's recorder runs while the recogniser listens. Off
  /// by default (#1107); the one switch for the web path.
  final bool recordWhileRecognising;

  final SpeechBrowser _browser;

  /// How long past `listenFor` a listen may take to report before it is
  /// given up as no match.
  static const Duration _grace = Duration(seconds: 4);

  bool _started = false;

  @override
  Future<bool> hasPermission() async {
    // A browser with no recogniser has nothing to refuse: true, so that a
    // failed [start] is told apart as "no recogniser", not "refused".
    if (!_browser.hasRecognition) return true;
    try {
      return await _browser.microphone() == BrowserMicrophone.granted;
    } catch (e) {
      throw SpeechError(codeOf(e));
    }
  }

  @override
  Future<bool> start() async {
    if (!_browser.hasRecognition) return false;
    if (_started) return true;
    try {
      _started = await _browser.askMicrophone();
    } on SpeechError {
      _started = false;
      rethrow;
    } catch (e) {
      _started = false;
      throw SpeechError(codeOf(e));
    }
    return _started;
  }

  /// A browser lists no languages: the app tries each one and remembers what
  /// the first listen found.
  @override
  Future<Set<String>> languages() async => const <String>{};

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    if (!_browser.hasRecognition) {
      return const SpeechHeard.failed(SpeechFailure.noRecogniser);
    }
    if (onDevice) {
      return const SpeechHeard.failed(
        SpeechFailure.notOnDevice,
        code: 'error_language_unavailable',
      );
    }
    try {
      if (!_started && !await start()) {
        return const SpeechHeard.failed(
          SpeechFailure.permissionDenied,
          code: 'error_permission',
        );
      }
      final session = _browser.recognise(bcp47, record: recordWhileRecognising);
      final heard = await session.result.timeout(
        listenFor + _grace,
        onTimeout: () {
          session.cancel();
          return const BrowserHeard.error('timeout');
        },
      );
      return heardFrom(heard);
    } on SpeechError catch (e) {
      // Without a microphone nothing can be heard.
      return SpeechHeard.failed(SpeechFailure.noRecogniser, code: e.code);
    } catch (e) {
      return SpeechHeard.failed(SpeechFailure.other, code: codeOf(e));
    }
  }

  @override
  Future<void> stop() async {
    try {
      _browser.stop();
    } catch (e) {
      throw SpeechError(codeOf(e));
    }
  }

  /// An error's code for the app log: its type, never what was said.
  static String codeOf(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    SpeechError(:final code) => code,
    _ => '${error.runtimeType}',
  };

  /// What a finished session gives the app: its readings, or why not.
  static SpeechHeard heardFrom(BrowserHeard heard) {
    final error = heard.error;
    if (error != null) {
      return SpeechHeard.failed(failureOf(error), code: error);
    }
    final readings = <SpeechAlternative>[
      for (final reading in heard.alternatives)
        if (reading.text.trim().isNotEmpty) reading,
    ];
    if (readings.isEmpty) {
      return const SpeechHeard.failed(
        SpeechFailure.noMatch,
        code: 'empty-result',
      );
    }
    return SpeechHeard(readings, ownAudio: heard.ownAudio);
  }

  /// The Web Speech API's error codes, as the reasons the app tells apart.
  static SpeechFailure failureOf(String code) => switch (code) {
    'no-speech' || 'nomatch' || 'timeout' => SpeechFailure.noMatch,
    'not-allowed' || 'service-not-allowed' => SpeechFailure.permissionDenied,
    'network' => SpeechFailure.network,
    'language-not-supported' => SpeechFailure.unsupported,
    _ => SpeechFailure.other,
  };
}
