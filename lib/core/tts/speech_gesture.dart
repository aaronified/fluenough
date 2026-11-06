/// Whether words may be spoken without the learner having asked, free of
/// Flutter and of `dart:html`.
///
/// iOS Safari speaks nothing, with no error, until `speechSynthesis.speak`
/// has been called once from inside a tap (a user activation); a word spoken
/// as a card appears, after a frame, is outside one. So on the web a card's
/// automatic play, and a listening card's play on appearing, wait until the
/// learner has tapped a speaker once; that tap speaks and unlocks the rest.
/// Until then they are skipped quietly, and the speaker button still plays.
/// Elsewhere nothing waits (#1012).
class SpeechGesture {
  SpeechGesture({bool? needed}) : _open = !(needed ?? _onWeb);

  /// True when compiled for the web (dart2js or wasm), where `dart:js_interop`
  /// exists; false on the VM and on the phones.
  static const bool _onWeb = bool.fromEnvironment('dart.library.js_interop');

  bool _open;

  /// The one the app uses. Tests that need another build their own.
  static final SpeechGesture app = SpeechGesture();

  /// Whether a word may be played with no tap behind it.
  bool get allowsAutomatic => _open;

  /// The learner tapped a speaker: from now on words may play unasked.
  void tapped() => _open = true;
}
