import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/incoming.dart';

/// A row in a deck's "Practise one skill" group or the import sources:
/// leading, title and subtitle, and a trailing control. Put it in a
/// `GroupedList`, which gives it its background and corners.
///
/// Like `GroupedTile(feature:)`, a row whose [feature] is incoming is drawn
/// dimmed with a full-contrast badge, shows the SnackBar on a tap, and is one
/// screen-reader node, "[title], feature incoming". The difference is where
/// the badge goes at large text sizes: between the text and the trailing
/// control, as the design draws it, until the text is scaled past
/// [_badgeInlineUpTo]; then under the text, so a long badge never pushes the
/// row wider than the screen.
///
/// A live row keeps its trailing control's semantics separate, so a "Start"
/// button is read with its own label.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.feature,
    this.titleColor,
    this.selected = false,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    this.gap = 16,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// The feature this row belongs to, or null for a row that is always live.
  final Feature? feature;

  /// The title's colour; `onSurfaceVariant` for a skill the phone cannot do.
  final Color? titleColor;

  /// Draws the row in `secondaryContainer`: the chosen import source.
  final bool selected;

  final EdgeInsetsGeometry padding;

  /// Between the leading widget and the text.
  final double gap;

  /// The text scale beyond which the badge moves under the text.
  static const double _badgeInlineUpTo = 1.3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = feature;
    final incoming = f != null && isIncoming(context, f);
    final dim = incoming ? kIncomingOpacity : 1.0;
    final badgeInline =
        MediaQuery.textScalerOf(context).scale(1) <= _badgeInlineUpTo;
    final foreground = selected ? scheme.onSecondaryContainer : null;

    Widget dimmed(Widget child) =>
        incoming ? Opacity(opacity: dim, child: child) : child;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium!.copyWith(
            color: titleColor ?? foreground,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: foreground ?? scheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    final row = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            dimmed(
              IconTheme.merge(
                data: IconThemeData(
                  color: foreground ?? scheme.onSurfaceVariant,
                ),
                child: leading!,
              ),
            ),
            SizedBox(width: gap),
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
                : incoming
                ? dimmed(text)
                : MergeSemantics(child: text),
          ),
          if (incoming && badgeInline) ...<Widget>[
            const SizedBox(width: 12),
            const IncomingBadge(),
          ],
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            dimmed(IgnorePointer(ignoring: incoming, child: trailing)),
          ],
        ],
      ),
    );

    final Widget body = selected
        ? Ink(color: scheme.secondaryContainer, child: row)
        : row;
    if (!incoming) return InkWell(onTap: onTap, child: body);

    void tapped() => showIncomingSnackBar(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: l10n.incomingSemanticsLabel(title),
      hint: l10n.incomingSemanticsHint,
      excludeSemantics: true,
      onTap: tapped,
      child: InkWell(onTap: tapped, child: body),
    );
  }
}
