import 'package:flutter/material.dart';

/// A small hint that a long press (and, on web and desktop, a hover) shows
/// over [child]: one word where one word is enough (#913). Wrap every
/// tappable control that shows no text of its own in it, so a learner can
/// find out what it does. `test/hint_test.dart` fails for an icon-only
/// control that skips it.
///
/// It is a [Tooltip] whose look is set once, in the app theme
/// (`TooltipThemeData` in `AppTheme`), and the [message] doubles as the
/// control's label for a screen reader, so a control with no label of its
/// own gets one for free. The message comes from `lib/l10n/app_en.arb`: a
/// word or two, never a sentence, no full stop.
///
/// An `IconButton` takes `tooltip:` instead, which is the same hint.
class Hint extends StatelessWidget {
  const Hint({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.longPress,
    child: child,
  );
}
