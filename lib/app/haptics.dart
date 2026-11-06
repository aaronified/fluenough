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
///   is still playing, is dropped (success, error and danger are not thinned
///   by the throttle, only by a double still playing), which covers a fast fling of the language
///   wheel and a pop that follows a button press in the same frame.
class Haptics {
  Haptics({
    required this._engine,
    required this._enabled,
    Duration Function()? clock,
  }) : _clock = clock ?? _monotonic();

  /// At most 20 haptics a second.
  static const Duration throttle = Duration(milliseconds: 50);

  final HapticEngine _engine;
  final bool Function() _enabled;
  final Duration Function() _clock;

  Duration? _last;
  Duration? _busyUntil;

  /// Time since the service began, from a [Stopwatch]: a step of the phone's
  /// clock cannot silence haptics.
  static Duration Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// Whether the phone can vibrate: the Settings row is not drawn when not.
  bool get available => _engine.available;

  /// Whether the service is the one that buzzes now: the phone can vibrate
  /// and Vibrate on touch is on. Only then do the app's widgets turn
  /// Flutter's own feedback (the Android click sound, the long-press buzz)
  /// off; otherwise the platform's default stays.
  bool get takesOverFeedback => available && _enabled();

  /// The value for a widget's `enableFeedback`: false while the service
  /// takes over, null (the platform default) otherwise.
  bool? get ownFeedback => takesOverFeedback ? false : null;

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

  static bool _bypassesThrottle(Haptic haptic) =>
      haptic == Haptic.success ||
      haptic == Haptic.error ||
      haptic == Haptic.danger;

  /// Plays [haptic], if the setting, the screen reader rule and the throttle
  /// allow.
  void play(Haptic haptic) {
    if (haptic == Haptic.none || !_enabled()) return;
    if (screenReader && silentWithScreenReader(haptic)) return;
    final now = _clock();
    final busy = _busyUntil;
    if (busy != null && now < busy) return;
    // What carries a result is never thinned by a touch just before it: a
    // last card's rating, then the summary's success.
    final last = _last;
    if (!_bypassesThrottle(haptic) && last != null && now - last < throttle) {
      return;
    }
    _last = now;
    final length = playTimeOf(haptic);
    if (length > Duration.zero) _busyUntil = now + length;
    _engine.play(haptic, stillOn: _enabled);
  }
}

/// A clock that moves one second on each time it is read, so that a test's
/// haptics are never thrown away as too close together. `AppState.test`
/// uses it; a test of the throttle itself gives its own.
Duration Function() steppingClock() {
  var now = Duration.zero;
  return () => now += const Duration(seconds: 1);
}
