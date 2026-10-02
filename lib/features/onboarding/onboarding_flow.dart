import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/wave_progress.dart';
import '../profiles/spoken_languages_picker.dart';
import 'onboarding_step.dart';
import 'spoken_step.dart';
import 'tour_step.dart';
import 'welcome_step.dart';

/// The first launch, in order (#118). #117 adds its questions here.
final List<OnboardingStep> onboardingSteps = <OnboardingStep>[
  welcomeStep,
  tourStep,
  spokenStep,
];

/// The first launch: the app's home while no spoken language is saved
/// (`lib/app.dart`).
///
/// One widget, never a pushed route: saving the answers swaps the home for
/// the shell, and nothing may be left on the navigator above it. It draws
/// the frame once — Back and Skip at the top, the button at the bottom —
/// and only the content between them changes.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    this.steps,
    this.startAt,
    this.page = 0,
    this.spoken = const <String>[],
    this.choices,
  });

  /// For tests. Null: [onboardingSteps].
  final List<OnboardingStep>? steps;

  /// A step's id, for the gallery and tests. Null: the first step.
  final String? startAt;

  /// The page of [startAt] to open on.
  final int page;

  /// Languages ticked from the start, for the gallery and tests.
  final List<String> spoken;

  /// For tests. Null reads `assets/languages.yaml` once, as the flow starts,
  /// so the question never waits for it.
  final List<SpokenLanguage>? choices;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final List<OnboardingStep> _steps = widget.steps ?? onboardingSteps;
  late int _step = math.max(
    0,
    _steps.indexWhere((s) => s.id == widget.startAt),
  );
  late int _page = widget.page;
  late final OnboardingAnswers _answers = OnboardingAnswers(
    spoken: widget.spoken,
  );
  late List<SpokenLanguage>? _choices = widget.choices;

  /// Which way the last step change went, for the transition.
  bool _forward = true;

  /// Fading out after the last button, before the answers are saved.
  bool _leaving = false;

  /// The page each step was left on, so that Back returns to it.
  final Map<String, int> _leftOn = <String, int>{};

  final Set<String> _visited = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_choices != null) return;
    DefaultAssetBundle.of(context)
        .loadString(SpokenLanguagesPicker.asset)
        .then(parseSpokenLanguages)
        .then((choices) {
          if (mounted) setState(() => _choices = choices);
        });
  }

  @override
  void dispose() {
    _answers.dispose();
    super.dispose();
  }

  OnboardingStep get _current => _steps[_step];
  bool get _atStart => _step == 0 && _page == 0;

  void _go(int step, int page, {required bool forward}) => setState(() {
    _visited.add(_current.id);
    _leftOn[_current.id] = _page;
    _forward = forward;
    _step = step;
    _page = page;
  });

  /// [from] is where the button was drawn, so a second tap in the same frame
  /// cannot also skip the next page or step.
  void _next((int, int) from) {
    if (_leaving || from != (_step, _page)) return;
    if (_page < _current.pages - 1) return setState(() => _page++);
    if (_step < _steps.length - 1) return _go(_step + 1, 0, forward: true);
    if (MediaQuery.disableAnimationsOf(context)) return _save();
    setState(() => _leaving = true); // the fade's end saves
  }

  void _back() {
    if (_leaving) return;
    if (_page > 0) return setState(() => _page--);
    if (_step == 0) return;
    final previous = _steps[_step - 1];
    _go(_step - 1, _leftOn[previous.id] ?? previous.pages - 1, forward: false);
  }

  /// [from] as for [_next]: a second tap before the next frame is ignored,
  /// rather than skipping past the last step.
  void _skip((int, int) from) {
    if (_leaving || from != (_step, _page) || _step >= _steps.length - 1) {
      return;
    }
    _go(_step + 1, 0, forward: true);
  }

  void _save() {
    _answers.saveTo(AppScope.read(context));
    // The app replaces this home with the shell on its next frame. Where
    // nothing replaces it — the gallery, a test — fade back in.
    if (mounted) setState(() => _leaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: _atStart && !_leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: still ? Duration.zero : Durations.short4,
          curve: Easing.emphasizedAccelerate,
          onEnd: () {
            if (_leaving) _save();
          },
          child: IgnorePointer(
            ignoring: _leaving,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _topBar(context),
                  Expanded(child: _content(context, still)),
                  _bottomBar(context, still),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final step = _current;
    final questions = [
      for (final s in _steps)
        if (s.asks) s,
    ];
    final question = questions.indexOf(step);
    final from = (_step, _page);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      // 8 + the button's 12 px inset puts the arrow's stroke on the 24 px
      // line; 12 + Skip's own 12 puts its label's end on it too.
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
        child: Row(
          children: <Widget>[
            if (_atStart)
              const SizedBox(width: AppSizes.iconButton)
            else
              BackButton(onPressed: _back),
            Expanded(
              child: question >= 0 && questions.length > 1
                  ? Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      child: WaveProgress(
                        value: (question + 1) / questions.length,
                        semanticsLabel: l10n.onboardingQuestionPosition(
                          question + 1,
                          questions.length,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (step.skippable && _page < step.pages - 1)
              TextButton(
                onPressed: () => _skip(from),
                child: Text(l10n.onboardingSkip),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool still) {
    final step = _current;
    final drawnFor = _step;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedSwitcher(
      duration: still ? Duration.zero : Durations.medium2,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Easing.emphasizedAccelerate,
      // A step on its way out takes no taps, focus or screen-reader
      // attention. Same wrapper either way, so the arriving step keeps its
      // state.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final child in previous) _Inert(key: child.key, child: child),
          if (current != null)
            _Inert(key: current.key, live: true, child: current),
        ],
      ),
      // M3's shared axis: the new step slides in from the side it lies on.
      transitionBuilder: (child, animation) {
        final arriving = child.key == ValueKey<String>(step.id);
        final side = (_forward == arriving ? 1.0 : -1.0) * (rtl ? -1 : 1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.08 * side, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(step.id),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: step.content(
            context,
            OnboardingPosition(
              page: _page,
              // A step on its way out may still be settling a swipe; its
              // page is no longer the flow's.
              onPage: (page) {
                if (_step == drawnFor && !_leaving) {
                  setState(() => _page = page);
                }
              },
              answers: _answers,
              choices: _choices,
              firstVisit: !_visited.contains(step.id),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, bool still) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final step = _current;
    final from = (_step, _page);
    final label =
        step.action?.call(l10n) ??
        (_step == _steps.length - 1
            ? l10n.onboardingFinish
            : l10n.onboardingNext);
    return ListenableBuilder(
      listenable: _answers,
      builder: (context, _) {
        final waiting = step.blocked?.call(_answers, l10n);
        final ready = waiting == null;
        final Widget slot = switch ((step.marker, waiting)) {
          (final marker?, _) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            child: marker(context, _page),
          ),
          (_, final text?) => Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, bottom: 12),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _ => const SizedBox(width: double.infinity, height: 8),
        };
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Not AnimatedSize at Duration.zero: it asserts.
              if (still)
                slot
              else
                AnimatedSize(
                  duration: Durations.medium1,
                  curve: Easing.standard,
                  alignment: AlignmentDirectional.bottomStart,
                  child: slot,
                ),
              FilledButton(
                style: AppButtonStyles.tall(context),
                onPressed: ready ? () => _next(from) : null,
                child: AnimatedSwitcher(
                  duration: still ? Duration.zero : Durations.short3,
                  child: Text(
                    label,
                    key: ValueKey<String>(label),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A child of the step switcher. Only the [live] one takes taps, focus and
/// the screen reader's attention.
class _Inert extends StatelessWidget {
  const _Inert({super.key, required this.child, this.live = false});

  final Widget child;
  final bool live;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !live,
    child: ExcludeFocus(
      excluding: !live,
      child: ExcludeSemantics(excluding: !live, child: child),
    ),
  );
}
