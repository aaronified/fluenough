import '../core/haptics/haptic.dart';
import '../core/languages/language_skills.dart';

/// Every haptic the app plays, by meaning (Plan-Haptics). Reached through
/// `AppScope.read(context).haptics`, like every service (ADR-0007); never
/// call `HapticFeedback` anywhere else.
///
/// Every method is [play] of one [Haptic]. [play] is the only place that
/// reads the "Vibrate on touch" setting ([enabled]), the screen reader flag
/// and the throttle:
///
/// - nothing plays while [enabled] is false, checked at call time, so a
///   switch flipped in the middle of a double silences its second pulse;
/// - with a screen reader on, the touches it already vibrates for are
///   dropped ([silentWithScreenReader]) and the meaningful ones stay;
/// - a call less than [throttle] after the previous one, or while a double
///   is still playing, is dropped, which covers a fast fling of the language
///   wheel and a pop that follows a button press in the same frame.
class Haptics {
  Haptics({
    required this._engine,
    required this._enabled,
    this._clock = DateTime.now,
  });

  /// At most 20 haptics a second.
  static const Duration throttle = Duration(milliseconds: 50);

  final HapticEngine _engine;
  final bool Function() _enabled;
  final DateTime Function() _clock;

  DateTime? _last;
  DateTime? _busyUntil;

  /// Whether the phone can vibrate: the Settings row is not drawn when not.
  bool get available => _engine.available;

  /// Whether a screen reader is on, from the root widget's `MediaQuery`.
  bool screenReader = false;

  void tap() => play(Haptic.tap);
  void select() => play(Haptic.select);
  void toggle(bool on) => play(on ? Haptic.toggleOn : Haptic.toggleOff);
  void confirm() => play(Haptic.confirm);
  void danger() => play(Haptic.danger);
  void warning() => play(Haptic.warning);
  void success() => play(Haptic.success);
  void error() => play(Haptic.error);
  void correct() => play(Haptic.correct);
  void wrong() => play(Haptic.wrong);
  void longPress() => play(Haptic.longPress);
  void dragStart() => play(Haptic.dragStart);
  void drop() => play(Haptic.drop);

  /// A skill pill landed on [mark]: the feel is the mark it now draws, the
  /// two covered marks (a Know the placement level covers) being Learnt.
  void pill(SkillMark mark) => play(switch (mark) {
    SkillMark.leave => Haptic.pillLeave,
    SkillMark.learn => Haptic.pillLearn,
    SkillMark.know || SkillMark.knowBoth => Haptic.pillKnow,
    SkillMark.knowCovered || SkillMark.knowBothCovered => Haptic.pillLearnt,
  });

  /// Plays [haptic], if the setting, the screen reader rule and the throttle
  /// allow.
  void play(Haptic haptic) {
    if (haptic == Haptic.none || !_enabled()) return;
    if (screenReader && silentWithScreenReader(haptic)) return;
    final now = _clock();
    final busy = _busyUntil;
    if (busy != null && now.isBefore(busy)) return;
    final last = _last;
    if (last != null && now.difference(last) < throttle) return;
    _last = now;
    final length = playTimeOf(haptic);
    if (length > Duration.zero) _busyUntil = now.add(length);
    _engine.play(haptic, stillOn: _enabled);
  }
}

/// A clock that moves one second on each time it is read, so that a test's
/// haptics are never thrown away as too close together. `AppState.test`
/// uses it; a test of the throttle itself gives its own.
DateTime Function() steppingClock() {
  var now = DateTime(2026, 11, 6);
  return () => now = now.add(const Duration(seconds: 1));
}
