import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'hint.dart';
import 'language_glyph.dart';
import 'report_button.dart';
import '../card_text_scale.dart';

/// The three screens the language bar is on (#528).
enum LanguageBarScreen { today, decks, progress }

/// The language bar at the top of [child], and the thin line under it
/// once [child] scrolls under it (#528). [below] sits between the two and
/// does not scroll, such as Progress's range.
class LanguageBarFrame extends StatefulWidget {
  const LanguageBarFrame({
    super.key,
    required this.screen,
    required this.reportDetail,
    required this.child,
    this.below,
  });

  final LanguageBarScreen screen;

  /// As [ReportButton.detail]: the tab's name.
  final String reportDetail;
  final Widget child;
  final Widget? below;

  @override
  State<LanguageBarFrame> createState() => _LanguageBarFrameState();
}

class _LanguageBarFrameState extends State<LanguageBarFrame> {
  bool _scrolledUnder = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final under =
        notification.metrics.pixels > notification.metrics.minScrollExtent;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
    return false;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LanguageBar(
        screen: widget.screen,
        reportDetail: widget.reportDetail,
        scrolledUnder: _scrolledUnder,
      ),
      ?widget.below,
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ),
    ],
  );
}

/// The language bar at the top of Today, Decks and Progress: a wheel of the
/// languages the learner learns, turning under a fixed selection at its
/// centre (#703, #682; `docs/mockups/language-wheel.html`, approved by the
/// owner, 2026-10-21: "Works. Approved.", removed once built).
///
/// * The wheel is centred between two 48 wide slots: on Progress the left
///   one holds the All button, elsewhere it stays empty so that nothing
///   moves between the tabs; the bug report button is the right one.
/// * The selection is a pill fixed at the centre and the languages' glyphs
///   pass it, one every [detent] dp, each smaller and fainter the further
///   it is from the centre, whether the wheel moves or rests. Both ends
///   fade out, and nothing is drawn past the wheel's own width, so that
///   nothing reaches the bug button. There are no ends to the wheel: past
///   the last language comes the first, and a few languages repeat round
///   it. At launch the pill is already grown to the name.
/// * A finger moves the wheel 1:1, a long drag passes many languages. Each
///   language is a detent, with a tick (`HapticFeedback.selectionClick`),
///   in a drag and in a fling.
/// * On release the wheel keeps the finger's speed and coasts to the
///   detent that plain friction ([friction] per second) would stop at,
///   carried there by a spring (damping ratio [dampingRatio], stiffness
///   [stiffness], mass 1). The same fling goes the same distance. A touch
///   stops it where it is; lifting without dragging settles it on the
///   nearest detent.
/// * The language at the centre when it rests is the one shown. As soon as
///   it rests, the pill grows over [expansion] to the glyph and full name,
///   and the neighbours are pushed out the same gap from its edge; the
///   label under the bar, which names the language at the centre while the
///   wheel moves, fades out as it does. A touch collapses it.
///
/// A tap opens the menu of every language with its chip. Where the phone
/// asks for reduced motion, the wheel lands on its detent at once and the
/// pill grows without animation. For a screen reader the languages are one
/// button, with the swipe as two actions; the arrow keys move one detent.
class LanguageBar extends StatefulWidget {
  const LanguageBar({
    super.key,
    required this.screen,
    required this.reportDetail,
    this.scrolledUnder = false,
  });

  final LanguageBarScreen screen;

  /// As [ReportButton.detail].
  final String reportDetail;

  /// Whether the screen has scrolled under the bar: a thin line parts them.
  final bool scrolledUnder;

  /// The distance between two languages on the wheel, in dp.
  static const double detent = 44;

  /// How far from the centre, in detents, a glyph has fallen to its
  /// smallest and faintest (owner, 2026-10-23: "The further the glyphs are
  /// the fader and smaller they should have been").
  static const double falloff = 3;

  /// A glyph at [falloff] detents or more is this much of its size, and of
  /// its opacity.
  static const double farScale = 0.55;
  static const double farOpacity = 0.2;

  /// The settle spring (owner, 2026-10-21).
  static const double dampingRatio = 0.4;
  static const double stiffness = 800;

  /// The fling's friction, per second (owner, 2026-10-21): a fling of speed
  /// `v` detents per second stops `v / friction` detents on.
  static const double friction = 8;

  /// How long the pill takes to grow to the name (owner, 2026-10-21).
  static const Duration expansion = Duration(milliseconds: 300);

  /// The pill's width folded, in dp: wide enough for "हि" and "Es".
  static const double pillWidth = 52;

  /// The faded languages' alpha (owner, 2026-10-16: "64% is right").
  static const double fadedAlpha = 0.64;

  @override
  State<LanguageBar> createState() => _LanguageBarState();
}

class _LanguageBarState extends State<LanguageBar>
    with TickerProviderStateMixin {
  final MenuController _menu = MenuController();
  final OverlayPortalController _labelPortal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// The settle and the coast: a spring on the wheel's position.
  late final AnimationController _run =
      AnimationController.unbounded(vsync: this)
        ..addListener(_runTick)
        ..addStatusListener(_runStatus);

  /// The pill growing to the name, 0 to 1.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: LanguageBar.expansion,
  )..addListener(_repaint);

  /// The pill's pulse at a detent.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  )..addListener(_repaint);

  /// Where the wheel is, in detents: language `i` is at the centre at
  /// `i + n * k`. Null until the first build.
  double? _pos;
  int _count = 0;
  int _lastDetent = 0;
  double _target = 0;

  bool _dragging = false;
  double _from = 0;
  double _dx = 0;

  /// A touch stopped the coast, so its tap does not open the menu.
  bool _caught = false;

  /// The label under the bar shows, while the wheel moves: it fades in and
  /// out, and the overlay goes once it is out. Driven by hand, as a fade
  /// that never ran (shown and hidden between two frames) has no end to
  /// hide the overlay by.
  late final AnimationController _labelFade =
      AnimationController(vsync: this, duration: LanguageBar.expansion)
        ..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && _labelPortal.isShowing) {
            _labelPortal.hide();
          }
        });

  /// The pill shows the name and the centre glyph is hidden.
  bool _expanded = false;
  double _fullWidth = LanguageBar.pillWidth;
  double _push = 0;

  bool _focused = false;

  /// This bar's own menu or screen-reader action chose the language, so the
  /// wheel turns to it; the bar on another tab just moves there.
  bool _chosenHere = false;
  bool _building = false;

  void _repaint() {
    if (mounted && !_building) setState(() {});
  }

  @override
  void dispose() {
    _run.dispose();
    _grow.dispose();
    _pulse.dispose();
    _labelFade.dispose();
    super.dispose();
  }

  bool get _onProgress => widget.screen == LanguageBarScreen.progress;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// 1, or -1 where the next language is to the left.
  double get _dir => _rtl ? -1 : 1;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  bool get _busy => _dragging || _run.isAnimating || _caught;

  int _mod(int i) => _count <= 0 ? 0 : ((i % _count) + _count) % _count;

  void _toggleMenu() => _menu.isOpen ? _menu.close() : _menu.open();

  void _choose(AppState state, LanguageInfo language) {
    _menu.close();
    final changed = language.code != state.shownLanguage;
    _chosenHere = changed;
    state.showLanguage(language.code, allOff: _onProgress);
    if (!changed) return;
    final l10n = AppLocalizations.of(context)!;
    SemanticsService.sendAnnouncement(
      View.of(context),
      l10n.languageMenuLabel(language.name),
      Directionality.of(context),
    );
  }

  // ---- the wheel's motion ----

  /// Moves the wheel to [x] detents, with a tick for a detent crossed.
  void _setPos(double x) {
    _pos = x;
    final detent = x.round();
    if (detent != _lastDetent) {
      _lastDetent = detent;
      HapticFeedback.selectionClick();
      if (!_still) _pulse.forward(from: 0);
    }
    _repaint();
  }

  void _showLabel() {
    if (!_labelPortal.isShowing) _labelPortal.show();
    _labelFade.forward();
    _repaint();
  }

  void _hideLabel() {
    if (_still) {
      _labelFade.value = 0;
      if (_labelPortal.isShowing) _labelPortal.hide();
    } else {
      _labelFade.reverse();
    }
  }

  /// A touch or a move: the pill folds and the label names the language.
  void _collapse() {
    _expanded = false;
    _grow.stop();
    if (_still) {
      _grow.value = 0;
    } else {
      _grow.reverse();
    }
    _repaint();
  }

  void _runTo(double target, double velocity) {
    _target = target;
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: LanguageBar.stiffness,
      ratio: LanguageBar.dampingRatio,
    );
    _run.animateWith(
      SpringSimulation(
        spring,
        _pos!,
        target,
        velocity,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.002, velocity: 0.02),
      ),
    );
  }

  void _runTick() {
    if (_dragging) return;
    _setPos(_run.value);
  }

  void _runStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_dragging) _arrive();
  }

  /// The wheel is at rest on [_target]: the language there is the one
  /// shown, and the pill grows to its name.
  void _arrive() {
    final detent = _target.round();
    final i = _mod(detent);
    _lastDetent = i;
    _pos = i.toDouble();
    _target = _pos!;
    _dragging = false;
    _caught = false;
    final state = AppScope.read(context);
    final choices = state.languageChoices;
    if (i < choices.length && choices[i].code != state.shownLanguage) {
      _choose(state, choices[i]);
      _chosenHere = false;
    }
    _grownTo(choices, i);
    _repaint();
  }

  /// Starts the pill growing to the name of the language at [i].
  void _grownTo(List<LanguageInfo> choices, int i, {bool animate = true}) {
    if (i >= choices.length) return;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final language = choices[i];
    final glyph = languageGlyph(language, AppScope.read(context).decks);
    double width(String text, TextStyle style) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      locale: Locale(language.code),
      maxLines: 1,
    )..layout()).width;
    final label = theme.textTheme.labelLarge!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final wanted =
        16 +
        width(glyph, label.copyWith(fontWeight: FontWeight.w400)) +
        10 +
        width(language.name, label) +
        16;
    // The wheel is between the two slots and the bar's own padding.
    final room = (context.size?.width ?? 390) - 104;
    _fullWidth = math.min(
      math.max(wanted, LanguageBar.pillWidth),
      math.max(room, LanguageBar.pillWidth),
    );
    // The neighbours keep the gap they have from the folded pill's edge.
    _push = (_fullWidth - LanguageBar.pillWidth) / 2;
    _expanded = true;
    _hideLabel();
    if (_still || !animate) {
      _grow.value = 1;
    } else {
      _grow.forward();
    }
  }

  /// A touch on the wheel: it folds, and a coast stops where it is.
  void _touch() {
    _caught = _run.isAnimating;
    if (_caught) {
      _run.stop();
      _showLabel();
    }
    _collapse();
  }

  void _tap() {
    if (_caught) {
      _caught = false;
      _release(0);
      return;
    }
    _toggleMenu();
    _regrow();
  }

  void _tapCancel() => Future<void>.microtask(() {
    if (!mounted || _dragging || _run.isAnimating) return;
    if (_caught) {
      // Caught mid-coast: settle on the detent first; arriving regrows.
      _caught = false;
      _release(0);
      return;
    }
    _regrow();
  });

  /// The wheel is at rest, and its pill grows to the name again.
  void _regrow({bool animate = true}) {
    if (_pos == null || _busy) return;
    final choices = AppScope.read(context).languageChoices;
    _grownTo(choices, _mod(_pos!.round()), animate: animate);
  }

  /// At launch, and when the languages change, the pill is already grown.
  void _growAtLaunch() {
    if (!mounted || _busy || _expanded) return;
    _regrow(animate: false);
  }

  void _dragStart(DragStartDetails _) {
    // A touch while it is still carrying on takes it where it is.
    _run.stop();
    _caught = false;
    _dragging = true;
    _dx = 0;
    _from = _pos ?? 0;
    _collapse();
    _showLabel();
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    // One dp of finger is one dp of wheel at the centre; a drag to the left
    // brings the next language.
    _dx += details.primaryDelta ?? 0;
    _setPos(_from - _dx * _dir / LanguageBar.detent);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _release(-(details.primaryVelocity ?? 0) * _dir / LanguageBar.detent);
  }

  void _dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _release(0);
  }

  /// Lets go at [velocity] detents per second: coasts to the detent plain
  /// friction would stop at, or settles on the nearest one.
  void _release(double velocity) {
    final x0 = _pos ?? 0;
    var target = (x0 + velocity / LanguageBar.friction).roundToDouble();
    var d = target - x0;
    if (velocity.abs() < 1.5 || d * velocity <= 0 || d.abs() < 0.02) {
      // Too slow to coast, or it would have to turn back: settle.
      target = x0.roundToDouble();
      d = target - x0;
      velocity = 0;
    }
    _showLabel();
    if (_still || (d.abs() < 0.004 && velocity == 0)) {
      _setPos(target);
      _target = target;
      _arrive();
      return;
    }
    _runTo(target, velocity);
  }

  /// Moves one detent, for a key.
  void _step(int by) {
    if (_pos == null || _count < 2) return;
    // A second press while the wheel still turns adds to where it is going.
    final from = (_run.isAnimating ? _target : _pos!).round();
    _run.stop();
    _dragging = false;
    _caught = false;
    _collapse();
    _showLabel();
    final target = from + by;
    if (_still) {
      _setPos(target.toDouble());
      _target = target.toDouble();
      _arrive();
      return;
    }
    _runTo(target.toDouble(), 0);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final by = event.logicalKey == LogicalKeyboardKey.arrowRight
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowLeft
        ? -1
        : 0;
    if (by == 0) return KeyEventResult.ignored;
    _step(by * _dir.round());
    return KeyEventResult.handled;
  }

  /// The language shown changed from outside the wheel, such as in the
  /// menu: the wheel turns to it by the shorter way round.
  void _follow(int at, int count) {
    if (!mounted || _busy || _pos == null || count != _count) return;
    final here = _mod(_pos!.round());
    final animate = _chosenHere;
    _chosenHere = false;
    if (here == at) return;
    var d = at - here;
    if (d > count / 2) d -= count;
    if (d < -count / 2) d += count;
    final target = (_pos!.round() + d).toDouble();
    if (!animate) {
      // Another tab's bar changed the language: this one moves there with
      // no tick, already showing its name.
      _pos = target;
      _target = target;
      _arrive();
      return;
    }
    _collapse();
    _showLabel();
    if (_still) {
      _setPos(target);
      _target = target;
      _arrive();
      return;
    }
    _runTo(target, 0);
  }

  // ---- drawing ----

  /// The wheel's glyphs, each at its place round the wheel.
  List<Widget> _glyphs(
    List<LanguageInfo> choices,
    List<DeckEntry> decks,
    ColorScheme scheme,
    TextTheme text,
    double half,
  ) {
    final pos = _pos!;
    final centre = pos.round();
    final dir = _dir;
    final out = <Widget>[];
    for (var k = centre - 8; k <= centre + 8; k++) {
      final d = k - pos;
      if (_count == 1 && k != centre) continue;
      final language = choices[_mod(k)];
      final pushed = d.abs() > 0.5 ? d.sign * _push * _growAmount : 0.0;
      // An even grid: a detent apart, the pill's growth pushing both sides
      // out alike.
      final offset = d * LanguageBar.detent + pushed;
      final t = math.min(1.0, d.abs() / LanguageBar.falloff);
      final scale = 1 - (1 - LanguageBar.farScale) * t;
      // Nothing is drawn past the wheel's own width.
      if (offset.abs() + LanguageBar.detent / 2 * scale > half) continue;
      final x = offset * dir;
      final opacity = 1 - (1 - LanguageBar.farOpacity) * t;
      final hidden = _expanded && k == centre;
      out.add(
        Align(
          key: ValueKey<int>(k),
          child: Transform.translate(
            offset: Offset(x, 0),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: hidden ? 0 : opacity,
                child: SizedBox(
                  key: ValueKey<String>('language-bar-glyph-$k'),
                  width: LanguageBar.detent,
                  height: 32,
                  child: Center(
                    child: Text(
                      languageGlyph(language, decks),
                      locale: Locale(language.code),
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                      softWrap: false,
                      style: text.titleMedium!.copyWith(
                        fontSize: 18,
                        height: 24 / 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  /// How far the pill has grown, 0 to 1, as the neighbours follow it.
  double get _growAmount => _expansionCurve.transform(_grow.value);

  static const Curve _expansionCurve = Cubic(0.2, 0.8, 0.2, 1);

  /// The name fades in over the last two thirds of the growth.
  static const Curve _nameFade = Interval(1 / 3, 1);

  /// The selection: a pill at the centre, with the name once it has grown.
  Widget _pill(
    ThemeData theme,
    LanguageInfo language,
    String glyph,
    bool allOn,
  ) {
    final scheme = theme.colorScheme;
    final scale = phoneTextScaleOf(context);
    final grow = _growAmount;
    final width =
        LanguageBar.pillWidth + (_fullWidth - LanguageBar.pillWidth) * grow;
    final shown = _nameFade.transform(_grow.value);
    final label = theme.textTheme.labelLarge!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: scheme.onSecondaryContainer,
    );
    return Transform.scale(
      scale: 1 + 0.14 * math.sin(math.pi * _pulse.value),
      child: Container(
        key: const ValueKey<String>('language-bar-selection'),
        width: width,
        height: 32 + 12 * (scale - 1),
        decoration: BoxDecoration(
          color: allOn ? null : scheme.secondaryContainer,
          border: allOn ? Border.all(color: scheme.outline) : null,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: _grow.value == 0
              ? null
              : OverflowBox(
                  minWidth: 0,
                  maxWidth: _fullWidth,
                  child: Opacity(
                    opacity: shown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            glyph,
                            locale: Locale(language.code),
                            maxLines: 1,
                            style: label.copyWith(fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              language.name,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final choices = state.languageChoices;
    final shown = state.shownLanguage;
    final codes = <String>[for (final l in choices) l.code];
    final at = codes.indexOf(shown ?? '');
    final allOn = _onProgress && state.progressShowsAll;

    _building = true;
    if (choices.isNotEmpty && at >= 0) {
      if (_pos == null || choices.length != _count) {
        // First build, or languages added or removed: no turning.
        _run.stop();
        _count = choices.length;
        _pos = at.toDouble();
        _target = _pos!;
        _lastDetent = at;
        _dragging = false;
        _caught = false;
        _expanded = false;
        _grow.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) => _growAtLaunch());
      } else if (!_busy && _mod(_pos!.round()) != at) {
        final count = _count;
        WidgetsBinding.instance.addPostFrameCallback((_) => _follow(at, count));
      }
    }
    _building = false;

    Widget zone = const SizedBox.shrink();
    if (choices.isNotEmpty && at >= 0) {
      // The wheel loops, so there is always a next and a previous.
      final n = choices.length;
      final next = n > 1 ? choices[(at + 1) % n] : null;
      final previous = n > 1 ? choices[(at - 1 + n) % n] : null;
      final here = choices[_mod(_pos!.round())];
      final glyph = languageGlyph(here, state.decks);
      Widget wheel = LayoutBuilder(
        builder: (context, box) => SizedBox(
          height: 48,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                _pill(theme, here, glyph, allOn),
                ..._glyphs(
                  choices,
                  state.decks,
                  scheme,
                  theme.textTheme,
                  box.maxWidth / 2,
                ),
              ],
            ),
          ),
        ),
      );
      // Both ends fade out, as if the wheel turned away out of sight.
      wheel = ShaderMask(
        key: const ValueKey<String>('language-bar-mask'),
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: <double>[0, 0.3, 0.7, 1],
        ).createShader(rect),
        child: wheel,
      );
      zone = MenuAnchor(
        controller: _menu,
        menuChildren: <Widget>[
          for (final language in choices)
            MenuItemButton(
              leadingIcon: SizedBox.square(
                dimension: 24,
                child: language.code == shown ? const Icon(Icons.check) : null,
              ),
              onPressed: () => _choose(state, language),
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: language.code == shown,
                child: LanguageBarChip(
                  language: language,
                  glyph: languageGlyph(language, state.decks),
                  selected: language.code == shown,
                ),
              ),
            ),
        ],
        builder: (context, _, _) => Semantics(
          container: true,
          button: true,
          label: l10n.languageBarLabel(
            choices[at].name,
            at + 1,
            choices.length,
          ),
          onTap: _toggleMenu,
          onTapHint: l10n.languageBarHint,
          customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
            if (next != null)
              CustomSemanticsAction(
                label: l10n.languageBarNext(next.name),
              ): () =>
                  _choose(state, next),
            if (previous != null)
              CustomSemanticsAction(
                label: l10n.languageBarPrevious(previous.name),
              ): () =>
                  _choose(state, previous),
          },
          excludeSemantics: true,
          child: Focus(
            onKeyEvent: _key,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _touch(),
              onTap: _tap,
              onTapCancel: _tapCancel,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: _focused
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: wheel,
              ),
            ),
          ),
        ),
      );
    }

    Widget bar = Container(
      height: 56,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.scrolledUnder
                ? scheme.outlineVariant
                : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            key: const ValueKey<String>('language-bar-all-slot'),
            width: 48,
            height: 48,
            child: _onProgress && choices.length > 1
                ? _AllButton(
                    on: allOn,
                    onPressed: () => state.settings.progressAll = !allOn,
                  )
                : null,
          ),
          Expanded(
            child: Hint(message: l10n.hintLanguage, child: zone),
          ),
          ReportButton(detail: widget.reportDetail),
        ],
      ),
    );

    // The turn works the same wherever it starts on the bar: on the wheel,
    // the slots or the buttons (owner, 2026-10-17: "It should be
    // consistent"). The drag is tracked from where the finger went down.
    if (choices.length > 1 && at >= 0) {
      bar = GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _dragStart,
        onHorizontalDragUpdate: _dragUpdate,
        onHorizontalDragEnd: _dragEnd,
        onHorizontalDragCancel: _dragCancel,
        child: bar,
      );
    }

    return OverlayPortal(
      controller: _labelPortal,
      overlayChildBuilder: (context) => _buildLabel(context, state),
      child: CompositedTransformTarget(link: _link, child: bar),
    );
  }

  /// Under the bar, while the wheel moves: the glyph and name of the
  /// language at the centre. It fades out as the pill grows to the name.
  Widget _buildLabel(BuildContext context, AppState state) {
    final choices = state.languageChoices;
    if (_pos == null || choices.isEmpty || _count != choices.length) {
      return const SizedBox.shrink();
    }
    final language = choices[_mod(_pos!.round())];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomCenter,
        followerAnchor: Alignment.topCenter,
        offset: const Offset(0, 4),
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: FadeTransition(
              opacity: _labelFade,
              child: Material(
                key: const ValueKey<String>('language-bar-label'),
                color: scheme.inverseSurface,
                elevation: 3,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LanguageGlyphTile(
                        glyph: languageGlyph(language, state.decks),
                        language: language,
                        background: scheme.onInverseSurface,
                        foreground: scheme.inverseSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        language.name,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ],
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

/// A language as its chip, glyph and name, as on the bar and in its menu:
/// filled while [selected], else its outline only.
class LanguageBarChip extends StatelessWidget {
  const LanguageBarChip({
    super.key,
    required this.language,
    required this.glyph,
    required this.selected,
    this.filled = true,
  });

  final LanguageInfo language;
  final String glyph;
  final bool selected;

  /// Whether the chip draws its own fill while [selected]. False leaves it
  /// transparent, as where the fill is drawn behind it.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = phoneTextScaleOf(context);
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      constraints: BoxConstraints(minHeight: 32 + 12 * (scale - 1)),
      padding: const EdgeInsetsDirectional.fromSTEB(7, 4, 11, 4),
      decoration: BoxDecoration(
        color: selected && filled ? scheme.secondaryContainer : null,
        border: Border.all(
          color: selected
              ? (filled ? scheme.secondaryContainer : Colors.transparent)
              : scheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LanguageGlyphTile(
            glyph: glyph,
            language: language,
            background: selected
                ? scheme.surfaceContainerLowest
                : scheme.secondaryContainer,
            foreground: selected
                ? scheme.onSurface
                : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            language.name,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.labelLarge!.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Progress's All: the word, faded while off, filled while on. A toggle.
class _AllButton extends StatelessWidget {
  const _AllButton({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: l10n.languageBarAllLabel,
      onTap: onPressed,
      onTapHint: l10n.languageBarAllHint,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? scheme.secondaryContainer : null,
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              l10n.languageBarAll,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.labelLarge!.copyWith(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: on
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface.withValues(
                        alpha: LanguageBar.fadedAlpha,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
