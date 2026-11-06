import 'web_speech_browser.dart';

/// Not a browser: no recogniser.
SpeechBrowser openSpeechBrowser() => _NoBrowser();

class _NoBrowser implements SpeechBrowser {
  @override
  bool get hasRecognition => false;

  @override
  Future<BrowserMicrophone> microphone() async => BrowserMicrophone.unknown;

  @override
  Future<bool> askMicrophone() async => false;

  @override
  BrowserSession recognise(String lang) => BrowserSession(
    Future<BrowserHeard>.value(const BrowserHeard.error('unsupported')),
    () {},
  );

  @override
  void stop() {}
}
