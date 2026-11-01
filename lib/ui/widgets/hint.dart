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
  const Hint({
    super.key,
    required this.message,
    required this.child,
    this.excludeFromSemantics = false,
  });

  final String message;
  final Widget child;

  /// True where [child] already has its own screen-reader label, so the hint
  /// is not read a second time.
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.longPress,
    excludeFromSemantics: excludeFromSemantics,
    child: child,
  );
}

/// An [IconButton] whose long press shows [hint], one word (#913), and whose
/// screen-reader label is [label], the full words that the hint would
/// shorten: "Delete data now", not "Delete". The button's own semantics are
/// replaced by one node that carries the label and the tap.
class LabelledIconButton extends StatelessWidget {
  const LabelledIconButton({
    super.key,
    required this.label,
    required this.hint,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String label;
  final String hint;
  final VoidCallback? onPressed;
  final Widget icon;

  /// The icon's colour, when it is not the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    excludeSemantics: true,
    onTap: onPressed,
    child: IconButton(
      tooltip: hint,
      color: color,
      onPressed: onPressed,
      icon: icon,
    ),
  );
}
