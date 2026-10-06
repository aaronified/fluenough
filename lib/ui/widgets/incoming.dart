import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'snack.dart';

/// M3's disabled-content opacity, which dims a feature that is incoming.
const double kIncomingOpacity = 0.38;

/// Whether [feature] is built but not switched on, read from `AppState`.
/// Subscribes [context] to the state, like `AppScope.of`.
bool isIncoming(BuildContext context, Feature feature) =>
    AppScope.of(context).features.isIncoming(feature);

/// Says "Feature incoming. Not in this version yet." in the app's toast,
/// which TalkBack and VoiceOver announce.
void showIncomingSnackBar(BuildContext context) =>
    showAppSnackBar(context, AppLocalizations.of(context)!.incomingSnackBar);

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

/// The most of a row's width the badge may take beside the row's text. Any
/// wider, at a large text scale or in a long translation, and it goes under
/// the text instead, so the row never overflows or squeezes its text.
const double _badgeBesideShare = 0.4;

/// The badge's side padding, 10 each side.
const double _badgePadding = 20;

/// Whether an [IncomingBadge] fits beside the text of a row [width] wide at
/// the current text scale: it may take at most 40% of the row.
///
/// [GroupedTile] and `IncomingFeature(badge: end)` apply this for you. Use it
/// where a layout places the badge itself.
bool incomingBadgeFitsBeside(BuildContext context, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: AppLocalizations.of(context)!.incomingBadge,
      style: Theme.of(context).textTheme.badge,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final badge = painter.width + _badgePadding;
  painter.dispose();
  return _fitsBeside(badge, width);
}

bool _fitsBeside(double badgeWidth, double rowWidth) =>
    !rowWidth.isFinite || badgeWidth <= rowWidth * _badgeBesideShare;

/// One incoming control for screen readers and touch, without dimming or a
/// badge: a disabled button named "[label], feature incoming", with the hint
/// "Not in this version yet", replacing [child]'s own semantics; and a
/// SnackBar on a tap anywhere on it.
///
/// [IncomingFeature] and [GroupedTile] use it. Use it directly only for a
/// layout that dims its parts and places the [IncomingBadge] itself, such as
/// a slider whose badge sits beside its heading.
class IncomingNode extends StatelessWidget {
  const IncomingNode({super.key, required this.label, required this.child});

  /// The control's visible name, which screen readers hear.
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

/// Where [IncomingFeature] puts its badge.
enum IncomingBadgePlacement {
  /// After the child, on the same line, when the badge takes at most 40% of
  /// the width; under it otherwise: rows and buttons.
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
/// With [IncomingBadgePlacement.end] the badge goes after the child when it
/// takes at most 40% of the width this is given, and under the child
/// otherwise, so it fits at a 2.0 text scale. That layout reports intrinsic
/// sizes, so it is safe inside `DrillFrame`.
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

    final dimmed = IgnorePointer(
      child: Opacity(opacity: kIncomingOpacity, child: child),
    );
    final Widget content = switch (badge) {
      IncomingBadgePlacement.end => _BesideOrBelow(
        content: dimmed,
        badge: const IncomingBadge(),
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
    return IncomingNode(label: label, child: content);
  }
}

/// [content] with [badge] after it on the same line, vertically centred,
/// when the badge takes at most 40% of the width; otherwise [badge] under
/// [content] at the start edge. A render object rather than a
/// `LayoutBuilder` so that it can report intrinsic sizes.
class _BesideOrBelow extends MultiChildRenderObjectWidget {
  _BesideOrBelow({required Widget content, required Widget badge})
    : super(children: <Widget>[content, badge]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBesideOrBelow(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBesideOrBelow renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _BesideOrBelowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBesideOrBelow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BesideOrBelowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BesideOrBelowParentData> {
  _RenderBesideOrBelow({required this._textDirection});

  /// Between the content and the badge beside it.
  static const double _gap = 12;

  /// Between the content and the badge under it.
  static const double _runGap = 8;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _content => firstChild!;
  RenderBox get _badge => lastChild!;

  double get _badgeWidth => _badge.getMaxIntrinsicWidth(double.infinity);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BesideOrBelowParentData) {
      child.parentData = _BesideOrBelowParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _content.getMinIntrinsicWidth(height),
    _badge.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _content.getMaxIntrinsicWidth(height) +
      _gap +
      _badge.getMaxIntrinsicWidth(height);

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) height,
  ) {
    final badgeWidth = _badgeWidth;
    if (_fitsBeside(badgeWidth, width)) {
      return math.max(
        height(_content, math.max(0, width - _gap - badgeWidth)),
        height(_badge, badgeWidth),
      );
    }
    return height(_content, width) + _runGap + height(_badge, width);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    Size lay(RenderBox child, BoxConstraints c) {
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      return child.size;
    }

    final maxWidth = constraints.maxWidth;
    if (_fitsBeside(_badgeWidth, maxWidth)) {
      final badge = lay(
        _badge,
        BoxConstraints(maxWidth: maxWidth, maxHeight: constraints.maxHeight),
      );
      final content = lay(
        _content,
        BoxConstraints(
          maxWidth: math.max(0, maxWidth - _gap - badge.width),
          maxHeight: constraints.maxHeight,
        ),
      );
      final size = constraints.constrain(
        Size(
          content.width + _gap + badge.width,
          math.max(content.height, badge.height),
        ),
      );
      if (!dry) {
        _place(_content, content, size, 0, (size.height - content.height) / 2);
        _place(
          _badge,
          badge,
          size,
          content.width + _gap,
          (size.height - badge.height) / 2,
        );
      }
      return size;
    }

    final content = lay(_content, BoxConstraints(maxWidth: maxWidth));
    final badge = lay(_badge, BoxConstraints(maxWidth: maxWidth));
    final size = constraints.constrain(
      Size(
        math.max(content.width, badge.width),
        content.height + _runGap + badge.height,
      ),
    );
    if (!dry) {
      _place(_content, content, size, 0, 0);
      _place(_badge, badge, size, 0, content.height + _runGap);
    }
    return size;
  }

  /// Puts [child], [childSize] big, [start] from the start edge of a box
  /// [size] big and [top] from its top.
  void _place(
    RenderBox child,
    Size childSize,
    Size size,
    double start,
    double top,
  ) {
    final x = textDirection == TextDirection.rtl
        ? size.width - start - childSize.width
        : start;
    (child.parentData! as _BesideOrBelowParentData).offset = Offset(x, top);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
