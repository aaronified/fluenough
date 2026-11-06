import 'package:fluenough/core/haptics/haptic.dart';

/// A [HapticEngine] that writes down what it is asked to play, so that a test
/// says what a learner feels, in meaning, and no test reaches a platform
/// channel.
class RecordingHapticEngine implements HapticEngine {
  RecordingHapticEngine({this.available = true});

  @override
  bool available;

  /// Everything played, in order.
  final List<Haptic> played = <Haptic>[];

  @override
  void play(Haptic haptic, {bool Function()? stillOn}) => played.add(haptic);
}
