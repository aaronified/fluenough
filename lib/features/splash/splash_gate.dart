import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/expressive_shape.dart';
import '../../ui/widgets/fluenough_mark.dart';
import 'splash_progress.dart';

/// Shows [child] under a splash screen with a loading bar on a cold start.
///
/// The splash covers [child], which is built and running underneath so that
/// its warm-up work goes on, for at least [minimum] and until every stage of
/// [progress] has finished, whichever is later. Then the bar is full, and the
/// splash fades out over [fade] (not at all while the phone has animations
/// off) and leaves the tree. It is never shown again by this gate: a resume
/// from the background does not rebuild it.
///
/// The bar fills as stages finish ([SplashStage.weight]) and eases toward
/// that, never back; the last [SplashProgress.minimumWeight] of it is the
/// minimum time, so it is full only when both are done. While a stage is
/// still under way the bar creeps a little into that stage's share, and it
/// stays under 95% until all are done.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.progress,
    required this.child,
    this.minimum = const Duration(seconds: 2),
    this.fade = const Duration(milliseconds: 250),
  });

  final SplashProgress progress;

  /// The app, kept mounted whether or not the splash shows.
  final Widget child;

  /// The least time the splash stays, as the frames' clock counts it.
  final Duration minimum;

  /// How long the splash takes to fade out.
  final Duration fade;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashFrame {
  const _SplashFrame(this.value, this.opacity);

  final double value;
  final double opacity;
}

enum _Phase { running, finishing, fading, gone }

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  /// How long the bar takes to run its last stretch to full.
  static const Duration _finishing = Duration(milliseconds: 150);

  /// The most the bar shows while a stage is unfinished.
  static const double _waitingCap = 0.95;

  /// The most a running bar shows: 1 is reached only by finishing.
  static const double _runningCap = 0.99;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<_SplashFrame> _frame = ValueNotifier<_SplashFrame>(
    const _SplashFrame(0, 1),
  );
  _Phase _phase = _Phase.running;
  Duration _last = Duration.zero;
  Duration _phaseStart = Duration.zero;
  double _value = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phase == _Phase.gone) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context)!.splashLoading,
        Directionality.of(context),
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final progress = widget.progress;
    switch (_phase) {
      case _Phase.running:
        if (progress.allDone && elapsed >= widget.minimum) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _ticker.stop();
            setState(() => _phase = _Phase.gone);
            return;
          }
          _phase = _Phase.finishing;
          _phaseStart = elapsed;
          _from = _value;
          return;
        }
        final minimumMicros = widget.minimum.inMicroseconds;
        final timeShare =
            SplashProgress.minimumWeight *
            (elapsed.inMicroseconds / (minimumMicros == 0 ? 1 : minimumMicros))
                .clamp(0.0, 1.0);
        var target = progress.completedWeight + timeShare;
        final current = progress.current;
        if (current != null) {
          // Under way: creep into the stage's share, slowing, never to it.
          target +=
              current.weight *
              0.5 *
              (1 - math.exp(-elapsed.inMicroseconds / 3e6));
          target = math.min(target, _waitingCap);
        }
        // Eases to the target, and never back.
        final eased = _value + (target - _value) * (1 - math.exp(-dt / 0.25));
        _value = math.min(math.max(_value, eased), _runningCap);
        _frame.value = _SplashFrame(_value, 1);
      case _Phase.finishing:
        final t =
            ((elapsed - _phaseStart).inMicroseconds / _finishing.inMicroseconds)
                .clamp(0.0, 1.0);
        _value = _from + (1 - _from) * t;
        _frame.value = _SplashFrame(_value, 1);
        if (t >= 1) {
          _phaseStart = elapsed;
          if (widget.fade == Duration.zero) {
            _end();
          } else {
            setState(() => _phase = _Phase.fading);
          }
        }
      case _Phase.fading:
        final t =
            ((elapsed - _phaseStart).inMicroseconds /
                    widget.fade.inMicroseconds)
                .clamp(0.0, 1.0);
        _frame.value = _SplashFrame(1, 1 - Curves.easeOut.transform(t));
        if (t >= 1) _end();
      case _Phase.gone:
        break;
    }
  }

  void _end() {
    _ticker.stop();
    setState(() => _phase = _Phase.gone);
  }

  @override
  Widget build(BuildContext context) {
    final showing = _phase != _Phase.gone;
    // The child is first in the stack and wrapped the same way whether or
    // not the splash shows, so that it is never rebuilt from scratch.
    return Stack(
      textDirection: Directionality.of(context),
      fit: StackFit.passthrough,
      children: <Widget>[
        ExcludeSemantics(excluding: showing, child: widget.child),
        if (showing)
          Positioned.fill(
            // Taps never reach the app under the splash, and pass through
            // while it fades.
            child: AbsorbPointer(
              absorbing: _phase != _Phase.fading,
              // The app's text cap (as capTextScale in app.dart, which this
              // file cannot import without a cycle), so the splash reads at
              // no more than 1.4x too.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: AppSizes.maxTextScale,
                child: _SplashScreen(progress: widget.progress, frame: _frame),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({required this.progress, required this.frame});

  final SplashProgress progress;
  final ValueListenable<_SplashFrame> frame;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<_SplashFrame>(
      valueListenable: frame,
      builder: (context, now, bar) => Opacity(opacity: now.opacity, child: bar),
      child: Material(
        color: scheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.gutter * 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: const ExpressiveShapeBorder(
                        ExpressiveShape.cookie,
                      ),
                    ),
                    child: const FluenoughMark(size: 56),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.appTitle,
                        style: theme.textTheme.displaySmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.25,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ValueListenableBuilder<_SplashFrame>(
                    valueListenable: frame,
                    builder: (context, now, _) => SplashBar(
                      value: now.value,
                      label: l10n.splashLoading,
                      percentLabel: l10n.splashPercent(
                        (now.value * 10).floor() * 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: progress,
                    builder: (context, _) => Text(
                      switch (progress.current) {
                        SplashStage.history => l10n.splashOpeningHistory,
                        SplashStage.catalog => l10n.splashLoadingCourses,
                        SplashStage.today => l10n.splashGettingToday,
                        null => l10n.splashReady,
                      },
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin determinate bar with rounded ends: [value] of 1 filled, in the
/// theme's primary on its quiet surface. A screen reader hears [label] and
/// [percentLabel], which the caller steps in tens so that it is not read at
/// every frame.
class SplashBar extends StatelessWidget {
  const SplashBar({
    super.key,
    required this.value,
    required this.label,
    required this.percentLabel,
  });

  final double value;
  final String label;
  final String percentLabel;

  static const double height = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(AppRadii.mark));
    return Semantics(
      label: label,
      value: percentLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            height: height,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: radius,
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
}
