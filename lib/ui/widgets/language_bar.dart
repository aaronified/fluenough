import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/language_choice.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import 'language_glyph.dart';
import 'report_button.dart';

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

/// The language bar at the top of Today, Decks and Progress (#528,
/// its approved mockup, in git history): always folded, 56 high. The language
/// shown is its chip, glyph and name; every other language the learner
/// learns is its bare glyph, faded to 64%, in the learner's order, the chip
/// in its own place. Then a 48 wide slot, which on Progress holds the All
/// button and elsewhere stays empty so that nothing moves between the
/// tabs, and the bug report button.
///
/// A sideways swipe on the bar shows the next or previous language, and a
/// tap opens the menu of every language with its chip. Where the row does
/// not fit, it scrolls to keep the chip clear, and each end with more
/// beyond it fades out over 16. For a screen reader the languages are one
/// button, with the swipe as two actions.
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

  /// How wide each fading end is.
  static const double fade = 16;

  /// The faded languages' alpha (owner, 2026-10-16: "64% is right").
  static const double fadedAlpha = 0.64;

  @override
  State<LanguageBar> createState() => _LanguageBarState();
}

class _LanguageBarState extends State<LanguageBar>
    with SingleTickerProviderStateMixin {
  final ScrollController _row = ScrollController();
  final GlobalKey _scrollKey = GlobalKey();
  final GlobalKey _rowKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  final MenuController _menu = MenuController();
  final OverlayPortalController _labelPortal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  bool _fadeStart = false;
  bool _fadeEnd = false;

  /// The language the row was last scrolled to keep clear.
  String? _centredOn;

  bool _dragging = false;
  double _drag = 0;

  /// The scroll offset the row is animating to, while it is.
  double? _animatingTo;

  /// While dragging, the language the swipe would show.
  String? _target;

  /// How far the row gives at an end, where there is no language to go to.
  double _give = 0;

  /// Each language's place in the row, measured after layout, for the
  /// selection to slide between.
  Map<String, Rect> _rects = const <String, Rect>{};

  /// How far a swipe has taken the selection toward [_target], 0 to 1: it
  /// follows the finger, and a swipe past a third of the bar commits.
  double _progress = 0;

  /// The momentum after a fling: it runs from 0 to 1 while the selection
  /// passes through [_flingSteps] languages from [_flingFrom] (#682).
  late final AnimationController _fling = AnimationController(vsync: this)
    ..addListener(_flingTick)
    ..addStatusListener(_flingStatus);
  List<String> _flingCodes = const <String>[];
  int _flingFrom = 0;
  int _flingSteps = 0;
  int _flingLast = 0;
  AppState? _flingState;

  /// Where the selection is while the momentum runs.
  Rect? _flingRect;

  bool get _flinging => _fling.isAnimating;

  /// Whether the bar follows its animation with no easing of its own.
  bool get _instant => _dragging || _flinging || _flingRect != null;

  GlobalKey _keyFor(String code) => _itemKeys.putIfAbsent(code, GlobalKey.new);

  /// The language the label under the bar names, and whether it shows.
  String? _labelCode;
  bool _labelOn = false;
  Timer? _labelTimer;

  @override
  void dispose() {
    _labelTimer?.cancel();
    _fling.dispose();
    _row.dispose();
    super.dispose();
  }

  bool get _onProgress => widget.screen == LanguageBarScreen.progress;

  void _toggleMenu() => _menu.isOpen ? _menu.close() : _menu.open();

  void _choose(AppState state, LanguageInfo language) {
    _menu.close();
    final changed = language.code != state.shownLanguage;
    state.showLanguage(language.code, allOff: _onProgress);
    if (!changed) return;
    _showLabel(language.code, fadeAfter: true);
    final l10n = AppLocalizations.of(context)!;
    SemanticsService.sendAnnouncement(
      View.of(context),
      l10n.languageMenuLabel(language.name),
      Directionality.of(context),
    );
  }

  void _showLabel(String code, {required bool fadeAfter}) {
    _labelTimer?.cancel();
    setState(() {
      _labelCode = code;
      _labelOn = true;
    });
    _labelPortal.show();
    if (fadeAfter) {
      _labelTimer = Timer(const Duration(seconds: 1), _hideLabel);
    }
  }

  void _hideLabel() {
    _labelTimer?.cancel();
    if (mounted && _labelOn) setState(() => _labelOn = false);
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _dragUpdate(DragUpdateDetails details, List<String> codes, String? at) {
    _drag += details.delta.dx;
    final forward = (_drag < 0) != _rtl;
    final next = LanguageChoice.step(at, codes, forward ? 1 : -1);
    final target = _drag.abs() >= 8 ? next : null;
    final commitAt = (context.size?.width ?? 300) / 3;
    setState(() {
      _target = target;
      _progress = target == null ? 0 : (_drag.abs() / commitAt).clamp(0.0, 1.0);
      _give = next == null ? (_drag * 0.25).clamp(-12.0, 12.0) : 0;
    });
    if (target != null) {
      if (_labelCode != target || !_labelOn) {
        _showLabel(target, fadeAfter: false);
      }
    } else if (_labelOn) {
      _hideLabel();
    }
  }

  /// How many languages a drag and a fling carry the selection past: one
  /// for a short flick, and five for the whole bar's width. The fling's
  /// speed adds the distance it would still travel.
  static int _stepsFor(double drag, double velocity, double width) {
    if (width <= 0) return 1;
    final carried = drag + velocity * 0.2;
    final fraction = carried.abs() / width;
    final steps = (5 * fraction * fraction).floor();
    return steps < 1 ? 1 : steps;
  }

  void _dragEnd(DragEndDetails details, AppState state) {
    final velocity = details.primaryVelocity ?? 0;
    final flick = velocity.abs() > 300 && (velocity < 0) == (_drag < 0);
    final target = _target;
    final width = context.size?.width ?? 0;
    // Past a third of the whole bar's width, as the mockup says (#528).
    final far = _drag.abs() > width / 3;
    final forward = (_drag < 0) != _rtl;
    final steps = _stepsFor(_drag, flick ? velocity : 0, width);
    setState(() {
      _dragging = false;
      _drag = 0;
      _target = null;
      _progress = 0;
      _give = 0;
    });
    if (target != null && (far || flick)) {
      final codes = <String>[for (final l in state.languageChoices) l.code];
      final from = codes.indexOf(state.shownLanguage ?? '');
      final to = (from + (forward ? steps : -steps)).clamp(0, codes.length - 1);
      if (from >= 0 && to != from) {
        _startFling(state, codes, from, to - from);
        return;
      }
    }
    _hideLabel();
  }

  /// Carries the selection [delta] languages on from [from], slowing as a
  /// list does, ticking at each language it passes, and then settles.
  void _startFling(AppState state, List<String> codes, int from, int delta) {
    _flingState = state;
    _flingCodes = codes;
    _flingFrom = from;
    _flingSteps = delta;
    _flingLast = from;
    final ms = (300 + 110 * delta.abs()).clamp(300, 1400);
    _fling
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  /// Where the selection is, in languages, as the momentum slows.
  double get _flingAt =>
      _flingFrom + _flingSteps * Curves.easeOutCubic.transform(_fling.value);

  void _flingTick() {
    if (!mounted || _flingCodes.isEmpty) return;
    final at = _flingAt.clamp(0.0, _flingCodes.length - 1.0);
    final low = at.floor();
    final high = at.ceil();
    final a = _rects[_flingCodes[low]];
    final b = _rects[_flingCodes[high]];
    final nearest = at.round();
    final passed = nearest != _flingLast;
    _flingLast = nearest;
    setState(() {
      _flingRect = a == null || b == null ? null : Rect.lerp(a, b, at - low);
      _target = _flingCodes[nearest];
    });
    if (passed) {
      HapticFeedback.selectionClick();
      _showLabel(_flingCodes[nearest], fadeAfter: false);
    }
    _keepClear(_flingRect);
  }

  /// Scrolls the row so the moving selection stays in view.
  void _keepClear(Rect? rect) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (rect == null || stack == null || !_row.hasClients) return;
    final position = _row.position;
    if (!position.hasContentDimensions) return;
    final centre = rect.center.dx;
    final fromStart = _rtl ? stack.size.width - centre : centre;
    _row.jumpTo(
      (fromStart - position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _flingStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _settle();
  }

  /// The momentum has stopped: the screen switches, once.
  void _settle() {
    final state = _flingState;
    final code = _flingCodes.isEmpty ? null : _flingCodes[_flingLast];
    _flingState = null;
    setState(() {
      _flingRect = null;
      _target = null;
    });
    final language = state?.languageChoices
        .where((l) => l.code == code)
        .firstOrNull;
    if (state != null && language != null) {
      _choose(state, language);
    } else {
      _hideLabel();
    }
  }

  void _dragCancel() {
    setState(() {
      _dragging = false;
      _drag = 0;
      _target = null;
      _progress = 0;
      _give = 0;
    });
    _hideLabel();
  }

  /// After layout: scrolls the row to keep the chip centred where the ends
  /// allow, and sets which ends fade.
  void _afterLayout(String? shown) {
    if (!mounted) return;
    _measure();
    if (!_row.hasClients || _dragging || _flinging) return;
    final position = _row.position;
    if (!position.hasContentDimensions) return;
    final chip =
        _itemKeys[shown]?.currentContext?.findRenderObject() as RenderBox?;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (chip != null && row != null && chip.attached && row.attached) {
      final centre = chip
          .localToGlobal(chip.size.center(Offset.zero), ancestor: row)
          .dx;
      final fromStart = _rtl ? row.size.width - centre : centre;
      final viewport = position.viewportDimension;
      final target = (fromStart - viewport / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      final animating = _animatingTo;
      if (animating != null && (animating - target).abs() <= 0.5) {
        // Already on its way there: a rebuild meanwhile does not cut the
        // animation short with a jump.
      } else if ((target - position.pixels).abs() > 0.5) {
        if (_centredOn != null && _centredOn != shown) {
          _animatingTo = target;
          _row
              .animateTo(
                target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              )
              .whenComplete(() {
                if (_animatingTo == target) _animatingTo = null;
              });
        } else {
          _animatingTo = null;
          _row.jumpTo(target);
        }
      }
    }
    _centredOn = shown;
    _setFades();
  }

  /// Measures where each language sits in the row, for the selection.
  void _measure() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.attached || !stack.hasSize) return;
    final rects = <String, Rect>{};
    for (final MapEntry(:key, :value) in _itemKeys.entries) {
      final box = value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      rects[key] = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    }
    bool same(Rect? a, Rect? b) =>
        a != null &&
        b != null &&
        (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
    final changed =
        rects.length != _rects.length ||
        rects.entries.any((e) => !same(e.value, _rects[e.key]));
    if (changed) setState(() => _rects = rects);
  }

  void _setFades() {
    if (!mounted || !_row.hasClients) return;
    final position = _row.position;
    if (!position.hasContentDimensions) return;
    final start = position.pixels > position.minScrollExtent + 0.5;
    final end = position.pixels < position.maxScrollExtent - 0.5;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
  }

  bool _onRowScroll(Notification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is ScrollMetricsNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setFades());
    }
    return false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterLayout(shown));

    Widget zone = const SizedBox.shrink();
    if (choices.isNotEmpty && at >= 0) {
      final next = at + 1 < choices.length ? choices[at + 1] : null;
      final previous = at > 0 ? choices[at - 1] : null;
      // The selection is drawn behind the row, so it can slide with the
      // finger toward the language a swipe would show (owner, 2026-10-17:
      // "The selection rectangle should move with my gesture in real
      // time"), as a Material tab indicator follows a swipe.
      final from = _rects[shown];
      final to = _target == null ? null : _rects[_target];
      final selection =
          _flingRect ??
          (from == null
              ? null
              : (to == null ? from : Rect.lerp(from, to, _progress)!));
      final slides = !allOn && selection != null;
      final items = <Widget>[
        for (final language in choices)
          if (language.code == shown)
            LanguageBarChip(
              key: _keyFor(language.code),
              language: language,
              glyph: languageGlyph(language, state.decks),
              selected: !allOn,
              filled: !slides,
            )
          else
            KeyedSubtree(
              key: _keyFor(language.code),
              child: _BareGlyph(
                glyph: languageGlyph(language, state.decks),
                language: language,
                full: language.code == _target,
              ),
            ),
      ];
      Widget row = NotificationListener<Notification>(
        onNotification: _onRowScroll,
        child: SingleChildScrollView(
          key: _scrollKey,
          controller: _row,
          scrollDirection: Axis.horizontal,
          // The swipe changes the language; a finger does not scroll the
          // row freely (#528).
          physics: const NeverScrollableScrollPhysics(),
          child: AnimatedContainer(
            duration: _instant
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_give, 0, 0),
            child: Stack(
              key: _stackKey,
              children: <Widget>[
                if (slides)
                  AnimatedPositioned.fromRect(
                    key: const ValueKey<String>('language-bar-selection'),
                    rect: selection,
                    duration: _instant
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                Row(key: _rowKey, children: items),
              ],
            ),
          ),
        ),
      );
      if (_fadeStart || _fadeEnd) {
        final rtl = _rtl;
        final left = rtl ? _fadeEnd : _fadeStart;
        final right = rtl ? _fadeStart : _fadeEnd;
        row = ShaderMask(
          key: const ValueKey<String>('language-bar-mask'),
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final f = rect.width <= 0
                ? 0.0
                : (LanguageBar.fade / rect.width).clamp(0.0, 0.5);
            return LinearGradient(
              colors: <Color>[
                left ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                right ? Colors.transparent : Colors.black,
              ],
              stops: <double>[0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: row,
        );
      }
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
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _toggleMenu,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: row,
                ),
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
          Expanded(child: zone),
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
          ReportButton(detail: widget.reportDetail),
        ],
      ),
    );

    // The swipe works the same wherever it starts on the bar: on a glyph,
    // the chip, the space between, the edges or the buttons (owner,
    // 2026-10-17: "It should be consistent").
    if (choices.length > 1 && at >= 0) {
      bar = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          if (_flinging) {
            // A touch while it is still carrying on takes it where it is.
            _fling.stop();
            _settle();
          }
          _dragging = true;
          _drag = 0;
        },
        onHorizontalDragUpdate: (d) => _dragUpdate(d, codes, shown),
        onHorizontalDragEnd: (d) => _dragEnd(d, state),
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

  /// Under the bar, while dragging and for a second after a change: the
  /// language's glyph and name.
  Widget _buildLabel(BuildContext context, AppState state) {
    final language = state.languageChoices
        .where((l) => l.code == _labelCode)
        .firstOrNull;
    if (language == null) return const SizedBox.shrink();
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
            child: AnimatedOpacity(
              opacity: _labelOn ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              onEnd: () {
                if (!_labelOn) _labelPortal.hide();
              },
              child: Material(
                key: const ValueKey<String>('language-bar-label'),
                color: scheme.inverseSurface,
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
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

  /// Whether the chip draws its own fill while [selected]. On the bar the
  /// sliding selection behind the row draws it instead.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
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
        borderRadius: BorderRadius.circular(10),
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

/// A language that is not shown: its glyph alone, faded, or at full alpha
/// while a swipe would show it ([full]). Its size does not follow the text
/// size.
class _BareGlyph extends StatelessWidget {
  const _BareGlyph({
    required this.glyph,
    required this.language,
    required this.full,
  });

  final String glyph;
  final LanguageInfo language;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minWidth: 23, minHeight: 32),
      alignment: Alignment.center,
      child: Text(
        glyph,
        locale: Locale(language.code),
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.titleMedium!.copyWith(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          color: full
              ? onSurface
              : onSurface.withValues(alpha: LanguageBar.fadedAlpha),
        ),
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
              borderRadius: BorderRadius.circular(10),
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
