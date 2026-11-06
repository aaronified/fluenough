import 'dart:async';

import 'speech_engine.dart';
import 'web_speech_browser_stub.dart'
    if (dart.library.js_interop) 'web_speech_browser_web.dart'
    as impl;

/// What the browser says of the microphone, without asking.
enum BrowserMicrophone {
  /// Allowed to this site.
  granted,

  /// Refused to this site.
  denied,

  /// Not asked yet, or the browser cannot say.
  unknown,
}

/// One finished browser listen: its readings, best first, or the Web Speech
/// API's error code (`no-speech`, `not-allowed`, `network` and so on).
class BrowserHeard {
  const BrowserHeard(this.alternatives) : error = null;

  const BrowserHeard.error(String this.error)
    : alternatives = const <SpeechAlternative>[];

  final List<SpeechAlternative> alternatives;
  final String? error;
}

/// One listen under way: its [result], and [cancel] to end it early.
class BrowserSession {
  const BrowserSession(this.result, this.cancel);

  final Future<BrowserHeard> result;
  final void Function() cancel;
}

/// The browser's recogniser and microphone, narrow enough that tests fake
/// it. The web implementation is `web_speech_browser_web.dart`; anywhere
/// else (the Dart VM that runs the tests, Android) there is none.
abstract interface class SpeechBrowser {
  /// Whether the browser has `SpeechRecognition` (Firefox does not).
  bool get hasRecognition;

  /// The microphone's permission for this site. Never asks, never throws.
  Future<BrowserMicrophone> microphone();

  /// Asks for the microphone, which shows the browser's own prompt the first
  /// time. True when it is allowed. Never throws.
  Future<bool> askMicrophone();

  /// Listens once for one utterance in [lang] and reports its readings.
  /// Never throws: a failure is in the [BrowserHeard].
  BrowserSession recognise(String lang);

  /// Ends the listen under way and keeps what was heard.
  void stop();
}

/// The browser this code runs in, or one with no recogniser.
SpeechBrowser openSpeechBrowser() => impl.openSpeechBrowser();

/// A scripted browser, for tests and the gallery.
class FixedSpeechBrowser implements SpeechBrowser {
  FixedSpeechBrowser({
    this.hasRecognition = true,
    this.state = BrowserMicrophone.unknown,
    this.allows = true,
    this.heard = const BrowserHeard(<SpeechAlternative>[]),
    this.never = false,
  });

  @override
  final bool hasRecognition;

  BrowserMicrophone state;

  /// Whether [askMicrophone] is granted.
  final bool allows;

  /// What the next listens hear.
  BrowserHeard heard;

  /// A listen that never answers, to test the deadline.
  final bool never;

  /// How often the microphone was asked for, listens begun, and cancels.
  int asked = 0;
  final List<String> listens = <String>[];
  int cancels = 0;
  int stops = 0;

  @override
  Future<BrowserMicrophone> microphone() async => state;

  @override
  Future<bool> askMicrophone() async {
    asked++;
    if (allows) state = BrowserMicrophone.granted;
    return allows;
  }

  @override
  BrowserSession recognise(String lang) {
    listens.add(lang);
    return BrowserSession(
      never ? Completer<BrowserHeard>().future : Future.value(heard),
      () => cancels++,
    );
  }

  @override
  void stop() => stops++;
}
