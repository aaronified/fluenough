import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../app/shell_tab.dart';

/// The four tabs side by side, which a sideways swipe moves between (#683).
///
/// Built from `docs/mockups/tab-swipe.html`, approved by the owner
/// (2026-10-21: "400, 0.75 approved for tab swipe"):
///
/// * The pages follow the finger 1:1. Past Today or Settings they follow at
///   a third, then less (a rubber band), and spring back.
/// * On release the pages settle on the next tab, or back on the same one,
///   with a spring of stiffness 400, mass 1 and damping ratio 0.75. A slow
///   release (under 300 px/s) is critically damped, so it does not bounce;
///   the ratio falls from 1 to 0.75 as the release speed rises to 1500 px/s.
///   A release at 200 px/s or more, or past half a page, commits; never more
///   than one page per swipe.
/// * A touch while the pages move catches them where they are.
/// * A tap on the bottom bar slides to the tab in 0.3 s (standard easing).
///   With the phone's reduce-motion setting on it switches at once; a drag
///   still tracks the finger.
/// * The bottom bar follows the page nearest the middle.
///
/// The tab is [tab]; a page pushed over the shell can change it too, and the
/// pages then slide there. Every page stays built while another shows, so it
/// keeps its scroll position.
class TabPager extends StatefulWidget {
  const TabPager({super.key, required this.tab, required this.children});

  final ValueNotifier<ShellTab> tab;

  /// One page per [ShellTab], in order.
  final List<Widget> children;

  /// The spring's stiffness and mass (owner, 2026-10-21).
  static const double stiffness = 400;
  static const double mass = 1;

  /// The damping ratio at a fast release (owner, 2026-10-21).
  static const double dampingRatio = 0.75;

  /// Release speeds, in px/s: the spring is critically damped up to
  /// [bounceFromSpeed] and reaches [dampingRatio] at [bounceFullSpeed]; at
  /// [minFlingSpeed] a release commits to the next page.
  static const double bounceFromSpeed = 300;
  static const double bounceFullSpeed = 1500;
  static const double minFlingSpeed = 200;

  /// A tap on the bottom bar slides in this long.
  static const Duration tapDuration = Duration(milliseconds: 300);
  static const Curve tapCurve = Cubic(0.2, 0, 0, 1);

  /// The damping ratio of a spring started at [speed] px/s.
  static double ratioFor(double speed) {
    final mix =
        ((speed.abs() - bounceFromSpeed) / (bounceFullSpeed - bounceFromSpeed))
            .clamp(0.0, 1.0);
    return 1 + (dampingRatio - 1) * mix;
  }

  @override
  State<TabPager> createState() => _TabPagerState();
}

class _TabPagerState extends State<TabPager>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
  );

  /// The width of a page, from the last layout.
  double _w = 0;

  /// The tab the pager is at or heading for.
  late int _at = widget.tab.value.index;

  /// The offset of the pages in px: page i is in view at i * [_w]. Only
  /// meaningful while [_moving].
  double _px = 0;

  /// The pages are away from rest: dragged, or animating.
  bool _moving = false;
  bool _dragging = false;

  /// A touch has caught moving pages, and no drag has started yet.
  bool _held = false;

  /// The controller is being set to where the pages are, not moved.
  bool _quiet = false;

  /// While this pager itself sets the tab, it does not react to it.
  bool _self = false;

  double _raw = 0;
  int _start = 0;
  int _target = 0;

  int get _last => widget.children.length - 1;

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_onTab);
    _c.addListener(() {
      if (!_quiet) _show(_c.value);
    });
    _c.addStatusListener((status) {
      if (!_quiet && status == AnimationStatus.completed) _rest();
    });
  }

  @override
  void didUpdateWidget(TabPager old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      old.tab.removeListener(_onTab);
      widget.tab.addListener(_onTab);
      _onTab();
    }
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    _c.dispose();
    super.dispose();
  }

  /// 1 in a left to right layout, -1 in a right to left one, where the next
  /// tab is to the left.
  double get _dir => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  /// Where the pages are, in px.
  double get _offset => _moving ? _px : _at * _w;

  /// Shows the pages at [px], and the bottom bar on the page nearest the
  /// middle.
  void _show(double px) {
    _px = px;
    if (_w > 0) {
      final nearest = (px / _w).round().clamp(0, _last);
      if (nearest != widget.tab.value.index) {
        _at = nearest;
        _self = true;
        widget.tab.value = ShellTab.values[nearest];
        _self = false;
      }
    }
    if (mounted) setState(() {});
  }

  /// The pages are at [_target]: at rest.
  void _rest() {
    if (_dragging) return;
    _moving = false;
    _at = _target;
    if (widget.tab.value.index != _target) {
      _self = true;
      widget.tab.value = ShellTab.values[_target];
      _self = false;
    }
    if (mounted) setState(() {});
  }

  /// The tab was changed from outside the pager: the bar, `selectTab`, or
  /// Back.
  void _onTab() {
    if (_self) return;
    final to = widget.tab.value.index;
    if (_dragging) return;
    final from = _offset;
    _at = to;
    _target = to;
    if (_w <= 0 || MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      setState(() => _moving = false);
      return;
    }
    if ((from - to * _w).abs() < 0.5) {
      setState(() => _moving = false);
      return;
    }
    _moving = true;
    _px = from;
    _jump(from);
    _c.animateTo(
      to * _w,
      duration: TabPager.tapDuration,
      curve: TabPager.tapCurve,
    );
  }

  void _jump(double px) {
    _quiet = true;
    _c.value = px;
    _quiet = false;
  }

  // A rubber band: the shown offset for [x] px past an end, about a third at
  // first and less the further it goes.
  double _rubber(double x) => (0.3 * x) / (1 + x / (0.9 * _w));

  double _withRubber(double raw) {
    final max = _last * _w;
    if (raw < 0) return -_rubber(-raw);
    if (raw > max) return max + _rubber(raw - max);
    return raw;
  }

  /// A touch catches pages that are still moving where they are.
  void _down(PointerDownEvent _) {
    if (!_moving || _dragging) return;
    _c.stop();
    _held = true;
  }

  /// A touch that caught the pages and did not drag them sets them down on
  /// the nearest page.
  void _up(PointerEvent _) {
    if (!_held || _dragging) return;
    _held = false;
    _spring((_px / _w).round().clamp(0, _last), 0);
  }

  void _dragStart(DragStartDetails _) {
    _c.stop();
    _held = false;
    _dragging = true;
    _start = (_offset / _w).round().clamp(0, _last);
    _raw = _offset;
    _px = _offset;
    _moving = true;
  }

  void _dragUpdate(DragUpdateDetails details) {
    // A drag to the left shows what is to the right.
    _raw -= (details.primaryDelta ?? 0) * _dir;
    _show(_withRubber(_raw));
  }

  void _dragEnd(DragEndDetails details) =>
      _release(-(details.primaryVelocity ?? 0) * _dir, cancelled: false);

  void _dragCancel() => _release(0, cancelled: true);

  void _release(double velocity, {required bool cancelled}) {
    if (!_dragging) return;
    _dragging = false;
    final dist = _raw - _start * _w;
    var target = _start;
    if (!cancelled) {
      if (velocity.abs() >= TabPager.minFlingSpeed) {
        target += velocity > 0 ? 1 : -1;
      } else if (dist.abs() > _w / 2) {
        target += dist > 0 ? 1 : -1;
      }
    }
    _spring(target.clamp(0, _last), velocity);
  }

  void _spring(int target, double velocity) {
    _target = target;
    _moving = true;
    final spring = SpringDescription.withDampingRatio(
      mass: TabPager.mass,
      stiffness: TabPager.stiffness,
      ratio: TabPager.ratioFor(velocity),
    );
    _jump(_px);
    _c.animateWith(
      SpringSimulation(
        spring,
        _px,
        target * _w,
        velocity,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.3, velocity: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return LayoutBuilder(
      builder: (context, box) {
        _w = box.maxWidth;
        final offset = _offset;
        final dir = _dir;
        return Listener(
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: GestureDetector(
            onHorizontalDragStart: _dragStart,
            onHorizontalDragUpdate: _dragUpdate,
            onHorizontalDragEnd: _dragEnd,
            onHorizontalDragCancel: _dragCancel,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  for (var i = 0; i < widget.children.length; i++)
                    _page(i, (i * _w - offset) * dir, background),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Page [i] [x] px from the middle; fully out of view it is not drawn or
  /// touched, but stays built.
  Widget _page(int i, double x, Color background) => Offstage(
    offstage: _w > 0 && x.abs() >= _w,
    child: Transform.translate(
      offset: Offset(x, 0),
      child: ColoredBox(color: background, child: widget.children[i]),
    ),
  );
}
