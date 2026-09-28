import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';

/// Whether the "Feature incoming" badge fits beside a row's text: it may
/// take at most 40% of a row [width] wide, at the current text scale.
///
/// The same rule as the decks feature's `OptionRow`. `GroupedTile` always
/// puts the badge inline, which overflows at a 2.0 text scale; these rows
/// move it under the text instead.
bool badgeFitsInline(BuildContext context, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: AppLocalizations.of(context)!.incomingBadge,
      style: Theme.of(context).textTheme.badge,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  // The badge's side padding, 10 each side.
  final badge = painter.width + 20;
  painter.dispose();
  return badge <= width * 0.4;
}

/// The design's 13 px help and footer lines, in `onSurfaceVariant`.
TextStyle settingsHelpStyle(ThemeData theme) =>
    theme.textTheme.bodySmall!.copyWith(
      fontSize: 13,
      height: 18 / 13,
      color: theme.colorScheme.onSurfaceVariant,
    );

/// Wraps [child] as one incoming control: a single screen-reader node,
/// "[label], feature incoming", and a SnackBar on a tap. The caller dims the
/// content and places the badge itself.
class _IncomingNode extends StatelessWidget {
  const _IncomingNode({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void tapped() => showIncomingSnackBar(context);
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: l10n.incomingSemanticsLabel(label),
      hint: l10n.incomingSemanticsHint,
      excludeSemantics: true,
      onTap: tapped,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tapped,
        child: child,
      ),
    );
  }
}

/// One row in a Settings or Appearance group: optional leading icon, a title
/// and subtitle, and a trailing control. Put it in a `GroupedList`, which
/// gives it its background and corners.
///
/// Like `GroupedTile`, a row whose [feature] is incoming is dimmed to 38%
/// with a full-contrast badge, shows the SnackBar on a tap, and is one
/// screen-reader node. Unlike it, the badge moves under the text when it
/// would take more than 40% of the row, so a large text scale never pushes
/// the row wider than the screen.
///
/// [SettingsRow.toggle] is a switch row: the whole row toggles, and it reads
/// as one switch. A row with [onTap] reads as one button. A row with neither
/// keeps its [trailing] control's semantics separate, as a picker needs.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.feature,
    this.titleColor,
    this.padding = defaultPadding,
  }) : _toggle = null;

  /// A row with a [Switch] at its end. Pass null [onChanged] for a switch
  /// that cannot change.
  const SettingsRow.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.feature,
    this.padding = defaultPadding,
  }) : trailing = null,
       onTap = null,
       titleColor = null,
       _toggle = (value: value, onChanged: onChanged);

  /// The design's settings rows: 20 at the sides, 14 above and below.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14);

  final String title;
  final String? subtitle;

  /// Usually an [Icon]; drawn in `onSurfaceVariant`.
  final Widget? leading;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// The feature this row belongs to, or null for a row that is always live.
  final Feature? feature;

  /// The title's colour, such as `error` for "Delete this profile".
  final Color? titleColor;

  final EdgeInsetsGeometry padding;

  final ({bool value, ValueChanged<bool>? onChanged})? _toggle;

  @override
  Widget build(BuildContext context) {
    final f = feature;
    if (f == null || !isIncoming(context, f)) return _live(context);
    return LayoutBuilder(
      builder: (context, constraints) => _IncomingNode(
        label: title,
        child: _row(
          context,
          incoming: true,
          badgeInline: badgeFitsInline(context, constraints.maxWidth),
        ),
      ),
    );
  }

  Widget _live(BuildContext context) {
    final toggle = _toggle;
    if (toggle != null) {
      final change = toggle.onChanged;
      return MergeSemantics(
        child: InkWell(
          onTap: change == null ? null : () => change(!toggle.value),
          child: _row(context, incoming: false),
        ),
      );
    }
    if (onTap != null) {
      return MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(onTap: onTap, child: _row(context, incoming: false)),
        ),
      );
    }
    return _row(context, incoming: false);
  }

  Widget _row(
    BuildContext context, {
    required bool incoming,
    bool badgeInline = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget dimmed(Widget child) =>
        incoming ? Opacity(opacity: kIncomingOpacity, child: child) : child;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium!.copyWith(color: titleColor),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    final toggle = _toggle;
    final Widget? end = toggle != null
        ? Switch(
            value: toggle.value,
            onChanged: incoming ? null : toggle.onChanged,
          )
        : trailing;

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            dimmed(
              IconTheme.merge(
                data: IconThemeData(
                  color: titleColor ?? scheme.onSurfaceVariant,
                ),
                child: leading!,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: incoming && !badgeInline
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      dimmed(text),
                      const SizedBox(height: 8),
                      const IncomingBadge(),
                    ],
                  )
                : dimmed(text),
          ),
          if (incoming && badgeInline) ...<Widget>[
            const SizedBox(width: 12),
            const IncomingBadge(),
          ],
          if (end != null) ...<Widget>[
            const SizedBox(width: 16),
            dimmed(IgnorePointer(ignoring: incoming, child: end)),
          ],
        ],
      ),
    );
  }
}

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

    if (incoming) return _IncomingNode(label: title, child: body);
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
    return _IncomingNode(label: heading, child: section);
  }
}
