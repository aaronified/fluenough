import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/expressive_shape.dart';
import '../../ui/widgets/fluenough_mark.dart';
import '../../ui/widgets/mode_pill.dart';
import '../../ui/widgets/segmented.dart';
import 'onboarding_step.dart';

/// One slide of the tour: a picture on a shape, a title, one sentence.
@immutable
class TourSlide {
  const TourSlide({
    required this.id,
    required this.shape,
    required this.tint,
    required this.title,
    required this.body,
    required this.hero,
  });

  /// The gallery's suffix: `onboarding-tour-<id>`.
  final String id;
  final ExpressiveShape shape;
  final Color Function(ColorScheme scheme) tint;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) body;
  final WidgetBuilder hero;
}

/// The skills slide 1 shows: the drills switched on, not minimal pairs.
const List<Skill> tourSkills = <Skill>[
  Skill.recognition,
  Skill.production,
  Skill.listening,
  Skill.grammar,
];

/// Everything the tour says the app does. It must all be switched on
/// (ADR-0008); `test/features/onboarding/onboarding_flow_test.dart` holds
/// [Feature.available] to it.
const Set<Feature> tourClaims = <Feature>{
  Feature.drillRecognition,
  Feature.drillProduction,
  Feature.drillListening,
  Feature.drillGrammar,
  Feature.persistence,
  Feature.logExport,
  Feature.dailyFacts,
};

/// The tour's slides, in order. The facts slide is last: it ends on "the
/// languages you speak", which the next screen asks for.
final List<TourSlide> tourSlides = <TourSlide>[
  TourSlide(
    id: 'skills',
    shape: ExpressiveShape.clover,
    tint: (s) => s.surfaceContainerHigh,
    title: (l10n) => l10n.onboardingTourSkillsTitle,
    body: (l10n) => l10n.onboardingTourSkillsBody,
    hero: (_) => const _SkillsHero(),
  ),
  TourSlide(
    id: 'reviews',
    shape: ExpressiveShape.pill,
    tint: (s) => s.secondaryContainer,
    title: (l10n) => l10n.onboardingTourReviewsTitle,
    body: (l10n) => l10n.onboardingTourReviewsBody,
    hero: (_) => const _ReviewsHero(),
  ),
  TourSlide(
    id: 'phone',
    shape: ExpressiveShape.sunny,
    tint: (s) => s.tertiaryContainer,
    title: (l10n) => l10n.onboardingTourPhoneTitle,
    body: (l10n) => l10n.onboardingTourPhoneBody,
    hero: (_) => const _PhoneHero(),
  ),
  TourSlide(
    id: 'facts',
    shape: ExpressiveShape.flower,
    tint: (s) => s.primaryContainer,
    title: (l10n) => l10n.onboardingTourFactsTitle,
    body: (l10n) => l10n.onboardingTourFactsBody,
    hero: (_) => const _FactHero(),
  ),
];

final OnboardingStep tourStep = OnboardingStep(
  id: 'tour',
  pages: tourSlides.length,
  skippable: true,
  marker: (context, page) => TourDots(page: page),
  content: (context, at) => TourContent(page: at.page, onPage: at.onPage),
);

/// The slides in a pager the flow controls: [page] is the flow's, a swipe
/// reports through [onPage], and Next, Back and Android back move [page].
class TourContent extends StatefulWidget {
  const TourContent({super.key, required this.page, required this.onPage});

  final int page;
  final ValueChanged<int> onPage;

  @override
  State<TourContent> createState() => _TourContentState();
}

class _TourContentState extends State<TourContent> {
  late final PageController _pages;

  /// The page shown or on its way. Set in initState: a lazy initialiser
  /// would first run in didUpdateWidget, read the new page, and the pager
  /// would never move.
  late int _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.page;
    _pages = PageController(initialPage: widget.page);
  }

  @override
  void didUpdateWidget(TourContent old) {
    super.didUpdateWidget(old);
    if (widget.page == _shown || !_pages.hasClients) return;
    // First: a jump reports its page at once, during this build, and that
    // report must not echo back to the flow.
    _shown = widget.page;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(widget.page);
    } else {
      _pages.animateToPage(
        widget.page,
        duration: Durations.medium4,
        curve: Easing.emphasizedDecelerate,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    controller: _pages,
    onPageChanged: (i) {
      if (i == _shown) return;
      _shown = i;
      widget.onPage(i);
    },
    children: <Widget>[
      for (final (i, slide) in tourSlides.indexed)
        _SlideView(slide: slide, index: i, pages: _pages),
    ],
  );
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.index,
    required this.pages,
  });

  final TourSlide slide;
  final int index;
  final PageController pages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    // Larger text gets the room: the picture gives it up first.
    final large = MediaQuery.textScalerOf(context).scale(16) > 21;
    return LayoutBuilder(
      builder: (context, box) {
        final size = large ? 160.0 : (box.maxHeight * 0.46).clamp(200.0, 300.0);
        return CustomScrollView(
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Spacer(),
                    ExcludeSemantics(
                      child: SizedBox(
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            // The shape rolls with the finger as the page
                            // is dragged.
                            AnimatedBuilder(
                              animation: pages,
                              builder: (context, _) {
                                final at = pages.hasClients
                                    ? pages.page ?? index.toDouble()
                                    : index.toDouble();
                                return SizedBox.square(
                                  dimension: size,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: slide.tint(scheme),
                                      shape: ExpressiveShapeBorder(
                                        slide.shape,
                                        turn: still ? 0 : (at - index) * 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(
                              width: size * 1.1,
                              height: size * 0.7,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: slide.hero(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        slide.title(l10n),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.body(l10n),
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The page dots: read out as "Slide 2 of 4: <title>", announced whenever
/// the slide changes.
class TourDots extends StatelessWidget {
  const TourDots({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.onboardingTourPosition(
        page + 1,
        tourSlides.length,
        tourSlides[page].title(l10n),
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < tourSlides.length; i++)
              AnimatedContainer(
                duration: still ? Duration.zero : Durations.medium1,
                curve: Segmented.morph,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                width: i == page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  // `outline` is 3:1 on the surface, as a mark must be.
                  color: i == page ? scheme.primary : scheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slide 1: the four drills' own pills, scattered like stickers.
class _SkillsHero extends StatelessWidget {
  const _SkillsHero();

  static const List<double> _tilt = <double>[-0.08, 0.06, 0.05, -0.07];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 12,
      children: <Widget>[
        for (final (i, skill) in tourSkills.indexed)
          Transform.rotate(
            angle: _tilt[i],
            child: ModePill(skill: skill),
          ),
      ],
    ),
  );
}

/// Slide 2: a card coming back after 1, 6 and 15 days — SM-2's gaps for an
/// answer rated Good (`Sm2.firstInterval`, `secondInterval`, then × 2.5).
class _ReviewsHero extends StatelessWidget {
  const _ReviewsHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget gap(int days, double width, {bool last = false}) {
      final fg = last ? scheme.onPrimary : scheme.onSurface;
      return Container(
        constraints: BoxConstraints(minWidth: width, minHeight: 40),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: last ? scheme.primary : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.style_outlined, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              l10n.rateInterval(days),
              style: theme.textTheme.labelLarge!.copyWith(color: fg),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        gap(1, 104),
        const SizedBox(height: 8),
        gap(6, 152),
        const SizedBox(height: 8),
        gap(15, 208, last: true),
      ],
    );
  }
}

/// Slide 3: a phone with the mark on its screen, and an offline badge.
class _PhoneHero extends StatelessWidget {
  const _PhoneHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 148,
      height: 176,
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            start: 0,
            top: 0,
            child: Container(
              width: 112,
              height: 176,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: scheme.onTertiaryContainer, width: 4),
              ),
              child: const FluenoughMark(size: 48),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 16,
            child: Container(
              width: 56,
              height: 56,
              decoration: ShapeDecoration(
                color: scheme.primary,
                shape: const ExpressiveShapeBorder(ExpressiveShape.cookie),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 24,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 4: Today's fact card (`_TodayFactCard`), with lines for its text.
class _FactHero extends StatelessWidget {
  const _FactHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget line(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
    return Container(
      width: 264,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                line(0.6),
                const SizedBox(height: 12),
                line(1),
                const SizedBox(height: 8),
                line(0.85),
                const SizedBox(height: 8),
                line(0.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
