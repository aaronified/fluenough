import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptic.dart';

/// [HapticEngine] on Flutter's own `HapticFeedback`: no plugin, no native
/// code (AGENTS.md rule 6).
///
/// **The one table that says how anything feels.** Changing a feel is a
/// one-line change in [play]. Seven feels, from the built-in calls:
/// tick `selectionClick`, tap `lightImpact`, press `mediumImpact`, thud
/// `heavyImpact`, buzz `vibrate`, and two sequences: rise (light, 70 ms,
/// medium) for success and knock (medium, 160 ms, medium) for no.
///
/// Only Android and iOS: elsewhere [available] is false and nothing plays.
class SystemHapticEngine implements HapticEngine {
  const SystemHapticEngine();

  @override
  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void play(Haptic haptic, {bool Function()? stillOn}) {
    if (!available) return;
    switch (haptic) {
      case Haptic.none:
        break;
      case Haptic.select || Haptic.pillLeave:
        HapticFeedback.selectionClick();
      case Haptic.tap ||
          Haptic.toggleOff ||
          Haptic.correct ||
          Haptic.drop ||
          Haptic.pillLearn:
        HapticFeedback.lightImpact();
      case Haptic.confirm ||
          Haptic.toggleOn ||
          Haptic.warning ||
          Haptic.dragStart ||
          Haptic.pillKnow:
        HapticFeedback.mediumImpact();
      case Haptic.danger:
        HapticFeedback.heavyImpact();
      case Haptic.longPress:
        HapticFeedback.vibrate();
      case Haptic.success || Haptic.pillLearnt:
        _double(
          HapticFeedback.lightImpact,
          const Duration(milliseconds: 70),
          HapticFeedback.mediumImpact,
          stillOn,
        );
      case Haptic.error || Haptic.wrong:
        _double(
          HapticFeedback.mediumImpact,
          const Duration(milliseconds: 160),
          HapticFeedback.mediumImpact,
          stillOn,
        );
    }
  }

  void _double(
    Future<void> Function() first,
    Duration gap,
    Future<void> Function() second,
    bool Function()? stillOn,
  ) {
    first();
    Future<void>.delayed(gap, () {
      if (stillOn == null || stillOn()) second();
    });
  }
}
