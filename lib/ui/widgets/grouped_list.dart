import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../theme.dart';
import 'incoming.dart';

/// How a [GroupedList]'s heading looks.
enum GroupHeaderStyle {
  /// 14 px bold in `primary`, indented 16: Settings' "Learning", "Sound".
  label,

  /// 16/24 semibold, indented 8: a deck's "Practise one skill", "Cards".
  title,
}

/// Rows in one rounded group, as the design draws every list: a small gap
/// between rows, large outer corners, small inner ones.
///
/// Each child gets its own [Material] in [color] with its corners, so an
/// [InkWell] inside ripples within its row. Children are usually
/// [GroupedTile]s, but anything works.
///
/// The defaults are the design's content groups (deck skills, cards, voices,
/// import sources, summary rows): 3 px gaps, 28 px outside, 6 px inside.
/// [GroupedList.settings] is the Settings variant: 2 px gaps, 24 px outside,
/// square inside.
class GroupedList extends StatelessWidget {
  const GroupedList({
    super.key,
    required this.children,
    this.header,
    this.headerStyle = GroupHeaderStyle.title,
    this.headerTrailing,
    this.outerRadius = AppRadii.group,
    this.innerRadius = AppRadii.innerRow,
    this.gap = 3,
    this.color,
  });

  /// The Settings look: a label heading, 2 px gaps, 24 px outer corners and
  /// square rows.
  const GroupedList.settings({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.color,
  }) : headerStyle = GroupHeaderStyle.label,
       outerRadius = AppRadii.card,
       innerRadius = 0,
       gap = 2;

  final List<Widget> children;

  /// A heading above the group, or null for none.
  final String? header;
  final GroupHeaderStyle headerStyle;

  /// Something at the end of the heading's line, like an [IncomingBadge].
  final Widget? headerTrailing;

  final double outerRadius;
  final double innerRadius;
  final double gap;

  /// The rows' colour. Defaults to `surfaceContainerLow`.
  final Color? color;

  BorderRadius _radiusFor(int i, int n) {
    final outer = Radius.circular(outerRadius);
    final inner = Radius.circular(innerRadius);
    return BorderRadius.vertical(
      top: i == 0 ? outer : inner,
      bottom: i == n - 1 ? outer : inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = color ?? theme.colorScheme.surfaceContainerLow;
    final n = children.length;

    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < n; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : gap),
            child: Material(
              color: fill,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: _radiusFor(i, n)),
              child: children[i],
            ),
          ),
      ],
    );

    final title = header;
    if (title == null) return group;
    final isLabel = headerStyle == GroupHeaderStyle.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: isLabel ? 16 : 8,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: isLabel
                        ? theme.textTheme.groupLabel.copyWith(
                            color: theme.colorScheme.primary,
                          )
                        : theme.textTheme.titleMedium,
                  ),
                ),
              ),
              ?headerTrailing,
            ],
          ),
        ),
        SizedBox(height: isLabel ? 8 : 10),
        group,
      ],
    );
  }
}

/// One row: optional leading icon, a title and subtitle, and an optional
/// trailing control. The design's settings, voice, import and skill rows.
///
/// Give it a [feature] and it handles the incoming state itself: leading,
/// text and trailing dimmed to 38%, the badge at full contrast, taps showing
/// the SnackBar, and one screen-reader node, "[title], feature incoming".
/// The badge sits between the text and the trailing control, as the design
/// draws it, when it takes at most 40% of the row; otherwise it goes under
/// the text, so a 2.0 text scale or a long translation never overflows the
/// row. Measuring the row needs a `LayoutBuilder` while incoming, so do not
/// put an incoming tile where intrinsic sizes are asked, such as in
/// `DrillFrame`'s card. When the feature is available, the row is live.
///
/// Live, a screen reader hears it as:
///
/// - with [onTap], or as [GroupedTile.toggle]: one node for the whole row, a
///   button or a switch, trailing included. So its [trailing] should be
///   decoration (a chevron, a value) or do what the row does (a radio);
/// - otherwise: the title and subtitle as one node, and [trailing] as its
///   own, so a "Start" or "Set up" button keeps its own label and action.
///
/// [GroupedTile.toggle] is the switch row: the whole row toggles, and the
/// switch is disabled M3-style while the feature is incoming.
class GroupedTile extends StatelessWidget {
  const GroupedTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.feature,
    this.titleColor,
    this.selected = false,
    this.padding = defaultPadding,
    this.leadingGap = 16,
    this.trailingGap = 16,
  }) : _toggle = null;

  /// A row with a [Switch] at its end. Pass null [onChanged] for a switch
  /// that cannot change.
  const GroupedTile.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.feature,
    this.titleColor,
    this.padding = defaultPadding,
    this.leadingGap = 16,
  }) : trailing = null,
       onTap = null,
       selected = false,
       trailingGap = 16,
       _toggle = (value: value, onChanged: onChanged);

  /// The design's rows: 20 at the sides, 14 above and below.
  static const EdgeInsetsGeometry defaultPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14);

  final String title;
  final String? subtitle;

  /// Usually an [Icon]; drawn in [titleColor], or `onSurfaceVariant`, unless
  /// it sets a colour.
  final Widget? leading;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// The feature this row belongs to, or null for a row that is always live.
  final Feature? feature;

  /// The title's colour, and the leading icon's, such as `error` for "Delete
  /// this profile", or `onSurfaceVariant` for a skill the phone cannot do.
  final Color? titleColor;

  /// Draws the row in `secondaryContainer`: the chosen import source.
  final bool selected;

  final EdgeInsetsGeometry padding;

  /// Between [leading] and the text.
  final double leadingGap;

  /// Between the text, or the badge, and [trailing].
  final double trailingGap;

  final ({bool value, ValueChanged<bool>? onChanged})? _toggle;

  @override
  Widget build(BuildContext context) {
    final f = feature;
    if (f != null && isIncoming(context, f)) {
      return IncomingNode(
        label: title,
        child: LayoutBuilder(
          builder: (context, constraints) => InkWell(
            onTap: () => showIncomingSnackBar(context),
            child: _row(
              context,
              incoming: true,
              badgeBeside: incomingBadgeFitsBeside(
                context,
                constraints.maxWidth,
              ),
            ),
          ),
        ),
      );
    }

    final toggle = _toggle;
    if (toggle != null) {
      final change = toggle.onChanged;
      return MergeSemantics(
        child: InkWell(
          onTap: change == null ? null : () => change(!toggle.value),
          child: _row(context),
        ),
      );
    }
    if (onTap != null) {
      return MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(onTap: onTap, child: _row(context)),
        ),
      );
    }
    return _row(context, mergeText: true);
  }

  Widget _row(
    BuildContext context, {
    bool incoming = false,
    bool badgeBeside = true,
    bool mergeText = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onSecondaryContainer : null;
    Widget dimmed(Widget child) =>
        incoming ? Opacity(opacity: kIncomingOpacity, child: child) : child;

    final Widget text = Column(
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

    final toggle = _toggle;
    final Widget? end = toggle != null
        ? Switch(
            value: toggle.value,
            onChanged: incoming ? null : toggle.onChanged,
          )
        : trailing;

    final row = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            dimmed(
              IconTheme.merge(
                data: IconThemeData(
                  color: titleColor ?? foreground ?? scheme.onSurfaceVariant,
                ),
                child: leading!,
              ),
            ),
            SizedBox(width: leadingGap),
          ],
          Expanded(
            child: incoming && !badgeBeside
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      dimmed(text),
                      const SizedBox(height: 8),
                      const IncomingBadge(),
                    ],
                  )
                : mergeText
                ? MergeSemantics(child: text)
                : dimmed(text),
          ),
          if (incoming && badgeBeside) ...<Widget>[
            const SizedBox(width: 12),
            const IncomingBadge(),
          ],
          if (end != null) ...<Widget>[
            SizedBox(width: trailingGap),
            dimmed(IgnorePointer(ignoring: incoming, child: end)),
          ],
        ],
      ),
    );
    return selected ? Ink(color: scheme.secondaryContainer, child: row) : row;
  }
}
