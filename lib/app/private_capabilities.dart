import 'app_state.dart';

/// What the phone can do for a private language (Plan-Private-Languages,
/// task 14), checked when a package is added and when it is turned on: a voice
/// to say its cards, a recogniser to hear them, and a script that is drawn
/// rather than shown as boxes.
///
/// A language without a voice has its speaking and sound drills hidden; the
/// reading and writing drills stay (owner, 2026-11-06).
class PrivateCapabilities {
  const PrivateCapabilities({
    required this.voice,
    required this.recogniser,
    required this.fontBoxes,
  });

  /// Whether the phone has a voice for the language.
  final VoiceStatus voice;

  /// Whether the phone can recognise the language.
  final SpeechStatus recogniser;

  /// Whether the learner said the language's script shows as boxes.
  final bool fontBoxes;

  /// The phone has no voice (a phone still being asked is not yet no voice).
  bool get noVoice => voice == VoiceStatus.missing;

  /// The phone cannot recognise the language.
  bool get noRecogniser => recogniser == SpeechStatus.missing;

  /// Whether the sound drills (listening) are hidden.
  bool get hidesSound => noVoice;

  /// Whether the speaking drills are hidden: no voice to say the word, or no
  /// recogniser to hear the learner.
  bool get hidesSpeaking => noVoice || noRecogniser;
}
