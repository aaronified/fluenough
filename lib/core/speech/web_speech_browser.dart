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

/// Whether a browser, by its [userAgent], may run a recorder beside the
/// recogniser (ADR-0054). Safari and every browser on iOS (all WebKit) give
/// the recogniser `webkitSpeechRecognition` alone and abort it when a second
/// reader takes the microphone, so there the recorder is skipped: a failed
/// listen costs the learner more than a missing take, which "Hear yourself"
/// records instead. Chrome and Edge (also `webkitSpeechRecognition`, but
/// Chromium) and Firefox's `MediaRecorder` share the microphone.
bool recorderBesideRecognition(String userAgent) {
  final ua = userAgent.toLowerCase();
  final ios =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  if (ios) return false;
  final chromium =
      ua.contains('chrome') ||
      ua.contains('chromium') ||
      ua.contains('crios') ||
      ua.contains('edg/') ||
      ua.contains('opr/') ||
      ua.contains('android');
  return !(ua.contains('safari') && !chromium);
}

/// One finished browser listen: its readings, best first, or the Web Speech
/// API's error code (`no-speech`, `not-allowed`, `network` and so on).
class BrowserHeard {
  const BrowserHeard(this.alternatives, {this.ownAudio}) : error = null;

  const BrowserHeard.error(String this.error)
    : alternatives = const <SpeechAlternative>[],
      ownAudio = null;

  final List<SpeechAlternative> alternatives;
  final String? error;

  /// The learner's voice as the browser's recorder kept it while the
  /// recogniser listened (a `MediaRecorder` on the microphone), decoded to
  /// PCM; null when the browser could not record beside the recogniser, or
  /// the listen was cancelled or failed. In memory only (ADR-0054).
  final OwnAudio? ownAudio;

  /// This reading with [audio] kept.
  BrowserHeard withAudio(OwnAudio? audio) =>
      error != null ? this : BrowserHeard(alternatives, ownAudio: audio);
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
  /// time. True when it is allowed, false when refused. Throws a
  /// [SpeechError] (`no-microphone`) when the device has no microphone.
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
    this.noDevice = false,
    this.audio,
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

  /// A device with no microphone: [askMicrophone] throws.
  final bool noDevice;

  /// The audio the browser's recorder kept for each listen that hears
  /// something, or null for a browser that cannot record beside the
  /// recogniser.
  final OwnAudio? audio;

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
    if (noDevice) throw const SpeechError('no-microphone');
    if (allows) state = BrowserMicrophone.granted;
    return allows;
  }

  @override
  BrowserSession recognise(String lang) {
    listens.add(lang);
    return BrowserSession(
      never
          ? Completer<BrowserHeard>().future
          : Future.value(heard.withAudio(audio)),
      () => cancels++,
    );
  }

  @override
  void stop() => stops++;
}
