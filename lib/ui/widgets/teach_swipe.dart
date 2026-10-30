import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// The teach card's way of going on (owner, 2026-10-22, #691): no Back and
/// Continue, but a swipe and two chevrons.
///
/// - **The card follows the finger** and settles on the tab-swipe spring
///   (damping ratio 0.75, stiffness 400, mass 1; the chevron tap uses it from
///   rest). A fling of at least 200 px/s, or a drag past half the width,
///   goes on; a slow release damps critically, and the damping ramps to 0.75
///   as the release speed rises to 1500 px/s. Toward a card that is not there
///   the card is held back, as on a rubber band.
/// - **Two chevrons**, one on either edge, hidden unless the card is being
///   swiped (owner, 2026-10-29): they show for 1 s when the card
///   first appears, to teach that they exist, and again as a horizontal drag
///   moves; stay while the card is dragged and settles, and go 1 s
///   after the drag ends. A tap, a vertical scroll or a press on the speaker
///   shows nothing. They can be tapped whether shown or not, and a quick tap
///   on a hidden one both moves the card and shows them for the same 1 s.
///
/// [onNext] runs once the card has settled on the next one; [onBack], when it
/// is given, on the previous one. With no [onBack] there is no back chevron.
/// Both are in the reading direction: a swipe toward the start edge goes on
/// in a left-to-right layout, and toward the end edge in a right-to-left one.
class TeachSwipe extends StatefulWidget {
  const TeachSwipe({
    super.key,
    required this.child,
    required this.onNext,
    this.onBack,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  /// Whether a swipe or the chevron goes on. Off, the child is drawn as it
  /// would be, but nothing moves it and no chevron shows: the review's
  /// answer page uses it so that its card keeps its state as the answer
  /// comes in.
  final bool enabled;

  @override
  State<TeachSwipe> createState() => _TeachSwipeState();
}

class _TeachSwipeState extends State<TeachSwipe> with TickerProviderStateMixin {
  /// Stiffness and mass of the tab-swipe spring; the damping comes from the
  /// ratio, `2 × ratio × √(stiffness × mass)`.
  static const double _stiffness = 400;
  static const double _mass = 1;
  static const double _chevronRatio = 0.75;

  /// The slowest release that is a fling, and the one at which the damping
  /// ratio has fallen to 0.75, in px/s.
  static const double _minFling = 200;
  static const double _fastFling = 1500;

  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  );

  /// How far the card is from rest, in px, positive toward the right.
  double _dx = 0;

  /// Where the finger has taken it, before the rubber band.
  double _raw = 0;

  bool _dragging = false;

  /// Whether a spring is carrying the card to a neighbour.
  bool _leaving = false;

  double _width = 0;
  bool _chevronsShown = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _spring.addListener(() => setState(() => _dx = _spring.value));
    if (widget.enabled) _intro();
  }

  /// The intro: shown for 1 s as the card first appears, or as swiping is
  /// first turned on, to teach that the chevrons exist.
  void _intro() {
    _chevronsShown = true;
    _holdChevrons();
  }

  @override
  void didUpdateWidget(TeachSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (widget.enabled) {
      _intro();
    } else {
      _hideTimer?.cancel();
      _chevronsShown = false;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _spring.dispose();
    super.dispose();
  }

  /// The sign of the offset that moves the card toward the next one.
  double get _nextSign =>
      Directionality.of(context) == TextDirection.rtl ? 1 : -1;

  double _rubber(double x) => 0.3 * x / (1 + x / (0.9 * _width));

  /// What the card shows for a finger [raw] px from rest: held back on a
  /// rubber band toward a card that is not there.
  double _shown(double raw) {
    final back = -_nextSign;
    if (widget.onBack == null && raw * back > 0) {
      return back * _rubber(raw.abs());
    }
    return raw;
  }

  void _go(double target, double velocity, int step, double ratio) {
    _leaving = step != 0;
    _spring.value = _dx;
    final simulation = SpringSimulation(
      SpringDescription(
        mass: _mass,
        stiffness: _stiffness,
        damping: 2 * ratio * math.sqrt(_stiffness * _mass),
      ),
      _dx,
      target,
      velocity,
      // As the card settles to within a third of a pixel, stop.
      tolerance: const Tolerance(distance: 0.3, velocity: 8),
    );
    _spring.animateWith(simulation).whenComplete(() => _settled(step));
  }

  void _settled(int step) {
    if (!mounted) return;
    _leaving = false;
    if (step == 1) {
      widget.onNext();
    } else if (step == -1) {
      widget.onBack?.call();
    }
    if (mounted && step != 0) {
      // The card is still here: show it at rest.
      _spring.value = 0;
    }
  }

  void _start(DragStartDetails details) {
    _spring.stop();
    _leaving = false;
    _dragging = true;
    _raw = _dx;
  }

  void _update(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // Not in [_start]: with no other gesture in the arena (a tap on bare
    // card) the drag wins at once and starts without a finger moving.
    if (delta != 0) _showChevrons(holding: false);
    _raw += delta;
    setState(() => _dx = _shown(_raw));
  }

  void _end(DragEndDetails details) {
    _dragging = false;
    _holdChevrons();
    final velocity = details.primaryVelocity ?? 0;
    final toward = velocity * _nextSign;
    var step = 0;
    if (toward.abs() >= _minFling) {
      step = toward > 0 ? 1 : -1;
    } else if (_width > 0 && _dx.abs() >= _width / 2) {
      step = _dx * _nextSign > 0 ? 1 : -1;
    }
    if (step == -1 && widget.onBack == null) step = 0;
    final ratio = 1 - 0.25 * (velocity.abs() / _fastFling).clamp(0.0, 1.0);
    _go(step * _nextSign * _width, velocity, step, ratio);
  }

  void _cancel() {
    _dragging = false;
    _holdChevrons();
    _go(0, 0, 0, 1);
  }

  /// A chevron's tap: the card moves a step from rest, on the spring.
  void _tapped(int step) {
    if (_dragging || _leaving) return;
    if (step == -1 && widget.onBack == null) return;
    _showChevrons(holding: true);
    _go(step * _nextSign * _width, 0, step, _chevronRatio);
  }

  /// Shows the chevrons, fading in unless they already are shown. While
  /// [holding] is false they stay until [_holdChevrons] is called.
  void _showChevrons({required bool holding}) {
    _hideTimer?.cancel();
    if (!_chevronsShown) {
      setState(() => _chevronsShown = true);
    }
    if (holding) _holdChevrons();
  }

  /// Hides the chevrons 1 s from now, restarting that wait.
  void _holdChevrons() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _chevronsShown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: widget.enabled ? _start : null,
                onHorizontalDragUpdate: widget.enabled ? _update : null,
                onHorizontalDragEnd: widget.enabled ? _end : null,
                onHorizontalDragCancel: widget.enabled ? _cancel : null,
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(_dx, 0),
                    child: widget.child,
                  ),
                ),
              ),
            ),
            if (widget.enabled && widget.onBack != null)
              _Chevron(
                next: false,
                shown: _chevronsShown,
                label: l10n.drillPreviousCard,
                onTap: () => _tapped(-1),
              ),
            if (widget.enabled)
              _Chevron(
                next: true,
                shown: _chevronsShown,
                label: l10n.drillNextCard,
                onTap: () => _tapped(1),
              ),
          ],
        );
      },
    );
  }
}

/// One chevron: a `secondaryContainer` tab on an edge of the card, vertically
/// centred, at 92 percent while shown and clear while hidden, but tappable
/// either way.
class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.next,
    required this.shown,
    required this.label,
    required this.onTap,
  });

  /// Whether it is the chevron to the next card, on the end edge.
  final bool next;
  final bool shown;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = Radius.circular(AppRadii.card);
    return PositionedDirectional(
      start: 0,
      end: 0,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: next
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: AnimatedOpacity(
          opacity: shown ? 0.92 : 0,
          duration: const Duration(milliseconds: 150),
          // Hidden is for the eye: a screen reader still has the chevron.
          alwaysIncludeSemantics: true,
          child: Material(
            color: scheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: next
                  ? const BorderRadiusDirectional.horizontal(start: radius)
                  : const BorderRadiusDirectional.horizontal(end: radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Tooltip(
              message: label,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    next ? Icons.chevron_right : Icons.chevron_left,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
