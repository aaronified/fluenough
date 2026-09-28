import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// M3's disabled-content opacity, which dims a feature that is incoming.
const double kIncomingOpacity = 0.38;

/// Whether [feature] is built but not switched on, read from `AppState`.
/// Subscribes [context] to the state, like `AppScope.of`.
bool isIncoming(BuildContext context, Feature feature) =>
    AppScope.of(context).features.isIncoming(feature);

/// Says "Feature incoming. Not in this version yet." in a SnackBar, which
/// TalkBack and VoiceOver announce.
void showIncomingSnackBar(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.incomingSnackBar)),
    );
}

/// The "Feature incoming" badge: full contrast, beside a dimmed control, so
/// the state is never shown by colour alone.
///
/// [IncomingFeature] and [GroupedTile] place it for you. Use it directly only
/// where a layout needs the badge somewhere they do not put it, and give the
/// surrounding control the incoming semantics yourself.
class IncomingBadge extends StatelessWidget {
  const IncomingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocalizations.of(context)!.incomingBadge,
        style: Theme.of(context).textTheme.badge
            .copyWith(color: scheme.onSurfaceVariant),
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

/// Where [IncomingFeature] puts its badge.
enum IncomingBadgePlacement {
  /// After the child, on the same line: rows and buttons.
  end,

  /// Under the child: tiles, cards and anything tall.
  below,

  /// Over the child's top end corner: the Progress tab's content, previews.
  overlay,

  /// No badge: for when the badge is already visible nearby, such as on a
  /// row whose section heading carries one.
  none,
}

/// Shows [child] as a feature that is built but not switched on yet, when
/// the registry says [feature] is incoming (docs/adr/0008). When the feature
/// is available it returns [child] untouched, so wrapping costs nothing once
/// the backend lands.
///
/// While incoming:
///
/// - [child] is drawn at 38% opacity (M3's disabled content) and receives no
///   touches. Give its controls M3's own disabled styling too — `onChanged:
///   null`, `onPressed: null` — using [isIncoming].
/// - A full-contrast [IncomingBadge] is placed per [badge].
/// - A tap anywhere shows [showIncomingSnackBar].
/// - Screen readers get one node: a disabled button named "[label], feature
///   incoming", with the hint "Not in this version yet", replacing the
///   child's own semantics. So [label] should be the control's visible name.
///
/// Three kinds of absence are kept apart: *incoming* is this widget; *missing
/// on this phone* (no voice) is a runtime check with a reason and a fix; *no
/// content* is an empty state. Do not use this widget for the other two.
///
/// With [IncomingBadgePlacement.end] the child sits in a [Flexible], so this
/// needs a bounded width, as any row does.
class IncomingFeature extends StatelessWidget {
  const IncomingFeature({
    super.key,
    required this.feature,
    required this.label,
    required this.child,
    this.badge = IncomingBadgePlacement.end,
  });

  final Feature feature;

  /// The control's visible name, which screen readers hear.
  final String label;

  final Widget child;

  final IncomingBadgePlacement badge;

  @override
  Widget build(BuildContext context) {
    if (!isIncoming(context, feature)) return child;
    final l10n = AppLocalizations.of(context)!;

    final dimmed = IgnorePointer(
      child: Opacity(opacity: kIncomingOpacity, child: child),
    );
    final Widget content = switch (badge) {
      IncomingBadgePlacement.end => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(child: dimmed),
          const SizedBox(width: 12),
          const IncomingBadge(),
        ],
      ),
      IncomingBadgePlacement.below => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          dimmed,
          const SizedBox(height: 8),
          const IncomingBadge(),
        ],
      ),
      IncomingBadgePlacement.overlay => Stack(
        children: <Widget>[
          dimmed,
          const PositionedDirectional(top: 8, end: 8, child: IncomingBadge()),
        ],
      ),
      IncomingBadgePlacement.none => dimmed,
    };

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
        child: content,
      ),
    );
  }
}
