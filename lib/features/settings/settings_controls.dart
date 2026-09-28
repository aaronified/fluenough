import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../ui/widgets/incoming.dart';

// Settings rows are `GroupedTile`s. These are the two controls Settings and
// Appearance draw that are not rows: a slider under its heading, and a
// heading over a picker. Each dims its parts and places the badge beside its
// heading itself, and is one `IncomingNode` while incoming.

/// The design's 13 px help and footer lines, in `onSurfaceVariant`.
TextStyle settingsHelpStyle(ThemeData theme) =>
    theme.textTheme.bodySmall!.copyWith(
      fontSize: 13,
      height: 18 / 13,
      color: theme.colorScheme.onSurfaceVariant,
    );

/// A slider with its name and value above it, and an optional help line:
/// "New cards per day", "Speech rate", "Card text size".
///
/// Live, it reads as one slider named [title], its value spoken through
/// [semanticValue]. Incoming, it is dimmed with a badge beside the title
/// (under it, when there is no room) and reads as one incoming control.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.semanticValue,
    this.help,
    this.feature,
  });

  final String title;

  /// The value as shown, in `primary` at the end of the title's line.
  final String valueLabel;

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  /// How a screen reader says a value, such as "1.0×".
  final String Function(double value) semanticValue;

  /// A line under the slider, such as the card size's explanation.
  final String? help;

  final Feature? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = feature;
    final incoming = f != null && isIncoming(context, f);
    Widget dimmed(Widget child) =>
        incoming ? Opacity(opacity: kIncomingOpacity, child: child) : child;

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              dimmed(Text(title, style: theme.textTheme.titleMedium)),
              if (incoming) const IncomingBadge(),
            ],
          ),
        ),
        const SizedBox(width: 12),
        dimmed(
          ExcludeSemantics(
            child: Text(
              valueLabel,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );

    final body = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          heading,
          const SizedBox(height: 8),
          dimmed(
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              padding: EdgeInsets.zero,
              semanticFormatterCallback: semanticValue,
              onChanged: incoming ? null : onChanged,
            ),
          ),
          if (help != null) ...<Widget>[
            const SizedBox(height: 8),
            dimmed(Text(help!, style: settingsHelpStyle(theme))),
          ],
        ],
      ),
    );

    if (incoming) return IncomingNode(label: title, child: body);
    return MergeSemantics(child: body);
  }
}

/// A heading, a control under it and an optional help line, as Appearance
/// draws its theme, colour and contrast choices.
///
/// While [feature] is incoming the heading and control are dimmed, the badge
/// sits beside the heading (wrapping under it when there is no room), and the
/// whole section is one incoming control named [heading]. [dimmed] dims the
/// control without the badge, for choices that do not apply right now, such
/// as the colour seeds while wallpaper colours are on.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.heading,
    required this.child,
    this.help,
    this.feature,
    this.dimmed = false,
  });

  final String heading;
  final Widget child;
  final String? help;
  final Feature? feature;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = feature;
    final incoming = f != null && isIncoming(context, f);
    Widget dim(Widget w, {bool also = false}) =>
        incoming || also ? Opacity(opacity: kIncomingOpacity, child: w) : w;

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              dim(
                Semantics(
                  header: true,
                  child: Text(
                    heading,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                also: dimmed,
              ),
              if (incoming) const IncomingBadge(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        dim(
          IgnorePointer(ignoring: incoming, child: child),
          also: dimmed,
        ),
        if (help != null) ...<Widget>[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: dim(Text(help!, style: settingsHelpStyle(theme))),
          ),
        ],
      ],
    );
    if (!incoming) return section;
    return IncomingNode(label: heading, child: section);
  }
}
