import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';

/// A row in a deck's "Practise one skill" group or the import sources:
/// leading, title and subtitle, and a trailing control. Put it in a
/// `GroupedList`, which gives it its background and corners.
///
/// Like `GroupedTile(feature:)`, a row whose [feature] is incoming is drawn
/// dimmed with a full-contrast badge, shows the SnackBar on a tap, and is one
/// screen-reader node, "[title], feature incoming". The difference is where
/// the badge goes: between the text and the trailing control, as the design
/// draws it, when it takes at most [_badgeInlineShare] of the row; otherwise
/// under the text. So a large text scale, or a longer translation, never
/// pushes the row wider than the screen or squeezes its title to a sliver.
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

  /// The most of the row's width the badge may take beside the text.
  static const double _badgeInlineShare = 0.4;

  /// Whether the badge fits beside the text in a row [width] wide.
  static bool _badgeFitsInline(BuildContext context, double width) {
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
    return badge <= width * _badgeInlineShare;
  }

  @override
  Widget build(BuildContext context) {
    final f = feature;
    if (f == null || !isIncoming(context, f)) return _build(context, false);
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        true,
        badgeInline: _badgeFitsInline(context, constraints.maxWidth),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    bool incoming, {
    bool badgeInline = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dim = incoming ? kIncomingOpacity : 1.0;
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
