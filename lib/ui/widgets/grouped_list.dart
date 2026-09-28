import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
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
/// Give it a [feature] and it handles the incoming state itself, exactly as
/// the design lays it out: leading, text and trailing dimmed to 38%, the
/// badge at full contrast between the text and the trailing control, taps
/// showing the SnackBar, and one screen-reader node, "[title], feature
/// incoming". When the feature is available, the row is live.
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
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 20,
      vertical: 14,
    ),
  }) : _toggle = null;

  /// A row with a [Switch] at its end.
  const GroupedTile.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.feature,
    this.titleColor,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 20,
      vertical: 14,
    ),
  }) : trailing = null,
       onTap = null,
       _toggle = (value: value, onChanged: onChanged);

  final String title;
  final String? subtitle;

  /// Usually an [Icon]; drawn in `onSurfaceVariant` unless it sets a colour.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = feature;
    final incoming = f != null && isIncoming(context, f);
    final dim = incoming ? kIncomingOpacity : 1.0;

    final toggle = _toggle;
    final Widget? end = toggle != null
        ? Switch(
            value: toggle.value,
            onChanged: incoming ? null : toggle.onChanged,
          )
        : trailing;
    final VoidCallback? tap = incoming
        ? () => showIncomingSnackBar(context)
        : toggle != null
        ? (toggle.onChanged == null
              ? null
              : () => toggle.onChanged!(!toggle.value))
        : onTap;

    final row = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            Opacity(
              opacity: dim,
              child: IconTheme.merge(
                data: IconThemeData(color: scheme.onSurfaceVariant),
                child: leading!,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Opacity(
              opacity: dim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (incoming) ...<Widget>[
            const SizedBox(width: 12),
            const IncomingBadge(),
          ],
          if (end != null) ...<Widget>[
            const SizedBox(width: 16),
            Opacity(
              opacity: dim,
              child: IgnorePointer(ignoring: incoming, child: end),
            ),
          ],
        ],
      ),
    );

    final ink = InkWell(onTap: tap, child: row);
    if (!incoming) return MergeSemantics(child: ink);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: l10n.incomingSemanticsLabel(title),
      hint: l10n.incomingSemanticsHint,
      excludeSemantics: true,
      onTap: tap,
      child: ink,
    );
  }
}
