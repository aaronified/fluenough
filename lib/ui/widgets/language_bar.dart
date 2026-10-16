import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/language_choice.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import 'language_glyph.dart';
import 'report_button.dart';

/// The three screens the language bar is on (#528).
enum LanguageBarScreen { today, decks, progress }

/// The bar's language bar at the top of [child], and the thin line under it
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
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
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
/// `docs/mockups/language-bar.html`): always folded, 56 high. The language
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

class _LanguageBarState extends State<LanguageBar> {
  final ScrollController _row = ScrollController();
  final GlobalKey _scrollKey = GlobalKey();
  final GlobalKey _rowKey = GlobalKey();
  final GlobalKey _chipKey = GlobalKey();
  final MenuController _menu = MenuController();
  final OverlayPortalController _labelPortal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  bool _fadeStart = false;
  bool _fadeEnd = false;

  /// The language the row was last scrolled to keep clear.
  String? _centredOn;

  bool _dragging = false;
  double _drag = 0;
  double _zoneWidth = 0;

  /// While dragging, the language the swipe would show.
  String? _target;

  /// How far the row gives at an end, where there is no language to go to.
  double _give = 0;

  /// The language the label under the bar names, and whether it shows.
  String? _labelCode;
  bool _labelOn = false;
  Timer? _labelTimer;

  @override
  void dispose() {
    _labelTimer?.cancel();
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
    setState(() {
      _target = target;
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

  void _dragEnd(DragEndDetails details, AppState state) {
    final velocity = details.primaryVelocity ?? 0;
    final flick = velocity.abs() > 300 && (velocity < 0) == (_drag < 0);
    final target = _target;
    final far = _drag.abs() > _zoneWidth / 3;
    setState(() {
      _dragging = false;
      _drag = 0;
      _target = null;
      _give = 0;
    });
    final language = state.languageChoices
        .where((l) => l.code == target)
        .firstOrNull;
    if (language != null && (far || flick)) {
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
      _give = 0;
    });
    _hideLabel();
  }

  /// After layout: scrolls the row to keep the chip centred where the ends
  /// allow, and sets which ends fade.
  void _afterLayout(String? shown) {
    if (!mounted || !_row.hasClients || _dragging) return;
    final position = _row.position;
    if (!position.hasContentDimensions) return;
    final chip = _chipKey.currentContext?.findRenderObject() as RenderBox?;
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
      if ((target - position.pixels).abs() > 0.5) {
        if (_centredOn != null && _centredOn != shown) {
          _row.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _row.jumpTo(target);
        }
      }
    }
    _centredOn = shown;
    _setFades();
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
      final items = <Widget>[
        for (final language in choices)
          if (language.code == shown)
            LanguageBarChip(
              key: _chipKey,
              language: language,
              glyph: languageGlyph(language, state.decks),
              selected: !allOn,
            )
          else
            _BareGlyph(
              glyph: languageGlyph(language, state.decks),
              language: language,
              full: language.code == _target,
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
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_give, 0, 0),
            child: Row(key: _rowKey, children: items),
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
              CustomSemanticsAction(label: l10n.languageBarNext(next.name)):
                  () => _choose(state, next),
            if (previous != null)
              CustomSemanticsAction(
                label: l10n.languageBarPrevious(previous.name),
              ): () =>
                  _choose(state, previous),
          },
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _zoneWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _dragging = true;
                  _drag = 0;
                },
                onHorizontalDragUpdate: (d) => _dragUpdate(d, codes, shown),
                onHorizontalDragEnd: (d) => _dragEnd(d, state),
                onHorizontalDragCancel: _dragCancel,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _toggleMenu,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 4,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: row,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final bar = Container(
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
  });

  final LanguageInfo language;
  final String glyph;
  final bool selected;

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
        color: selected ? scheme.secondaryContainer : null,
        border: Border.all(
          color: selected ? scheme.secondaryContainer : scheme.outline,
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
