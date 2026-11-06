/// What a touch means, never how it feels (Plan-Haptics): code says
/// [Haptic.confirm], and one table, `SystemHapticEngine`, says how that is
/// felt.
enum Haptic {
  /// A finger touched something that does something: the default for a
  /// button, a row, a chip.
  tap,

  /// One of several was picked: a segment, a tab, a wheel detent, a slider
  /// step. Lighter than a press: nothing is committed.
  select,

  /// A switch, checkbox or star turned on. Firmer than turning off.
  toggleOn,

  /// The same, turned off.
  toggleOff,

  /// A button that completes the task: Start, Check, Done, a rating.
  confirm,

  /// A destructive action was confirmed: the heaviest single pulse.
  danger,

  /// A caution appeared, or a tap was refused.
  warning,

  /// Something the learner was waiting for finished: a quick double that
  /// climbs.
  success,

  /// Something failed or was refused: a slow level double.
  error,

  /// The drill graded an answer right. Quiet when right.
  correct,

  /// The drill graded an answer wrong: the same knock as [error].
  wrong,

  /// A long press was recognised: a tooltip, slow speech.
  longPress,

  /// A drag picked something up.
  dragStart,

  /// A drag put something down.
  drop,

  /// A skill pill landed on Leave: the lightest touch, a let-go.
  pillLeave,

  /// A skill pill landed on Learn.
  pillLearn,

  /// A skill pill landed on Know, at either level.
  pillKnow,

  /// A skill pill landed on Learnt: earned, so the same rise as [success].
  pillLearnt,

  /// A control whose outcome has its own haptic is silent itself
  /// (principle 4); this says so.
  none,
}

/// Whether a screen reader, which vibrates for activation itself, should be
/// left to it: the touch feels of [Haptic.tap], [Haptic.select], the two
/// toggles and [Haptic.confirm] are dropped, and so are the long press and
/// the drag. What carries a meaning the reader does not say is kept.
bool silentWithScreenReader(Haptic haptic) => switch (haptic) {
  Haptic.tap ||
  Haptic.select ||
  Haptic.toggleOn ||
  Haptic.toggleOff ||
  Haptic.confirm ||
  Haptic.longPress ||
  Haptic.dragStart ||
  Haptic.drop => true,
  _ => false,
};

/// How long a haptic plays, for the throttle: a single pulse is instant, the
/// two doubles take their gap.
Duration playTimeOf(Haptic haptic) => switch (haptic) {
  Haptic.success || Haptic.pillLearnt => const Duration(milliseconds: 100),
  Haptic.error || Haptic.wrong => const Duration(milliseconds: 200),
  _ => Duration.zero,
};

/// The phone's vibration motor, behind an interface so that tests need no
/// platform.
abstract interface class HapticEngine {
  /// Whether this device can vibrate at all. The Settings row is not drawn
  /// where it cannot: the web and desktop.
  bool get available;

  /// Plays [haptic]. A sequence asks [stillOn] before its second pulse and
  /// drops it when the answer is no (the learner switched haptics off in
  /// the gap). Never throws.
  void play(Haptic haptic, {bool Function()? stillOn});
}

/// An engine that does nothing and says it is not available: the web,
/// desktop and the tests' default.
class NullHapticEngine implements HapticEngine {
  const NullHapticEngine();

  @override
  bool get available => false;

  @override
  void play(Haptic haptic, {bool Function()? stillOn}) {}
}
