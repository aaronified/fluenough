import 'package:flutter/material.dart';

import '../../app/links.dart';
import '../../app/reviewing.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/segmented.dart';

/// Opens "How reviewing works" (docs/plans/deck-browser.md, "The reviewer
/// guide is the onboarding, in the app"): by itself once, the first time
/// reviewing is turned on, and from Settings at any time, with reviewing on
/// or off. It always starts at the first step.
Future<void> showHowReviewingWorks(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: 'how-reviewing-works'),
        builder: (_) => const HowReviewingWorks(),
      ),
    );

/// One step of the walkthrough: a title and its paragraphs.
@immutable
class ReviewGuideStep {
  const ReviewGuideStep({
    required this.id,
    required this.guideHeading,
    required this.icon,
    required this.title,
    required this.paragraphs,
  });

  /// For tests.
  final String id;

  /// The section of docs/REVIEWING.md that says the same, word for word in
  /// its facts. A test holds the two in step: every step names a heading
  /// the guide has, and every heading but Help has a step.
  final String guideHeading;

  final IconData icon;
  final String Function(AppLocalizations l10n) title;
  final List<String> Function(AppLocalizations l10n) paragraphs;
}

/// The reviewer guide's steps, in the guide's order.
final List<ReviewGuideStep> reviewGuideSteps = <ReviewGuideStep>[
  ReviewGuideStep(
    id: 'what',
    guideHeading: 'What reviewing is',
    icon: Icons.rate_review_outlined,
    title: (l10n) => l10n.reviewGuideWhatTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideWhatBody,
      l10n.reviewGuideWhatYou,
    ],
  ),
  ReviewGuideStep(
    id: 'code',
    guideHeading: 'Your code and languages',
    icon: Icons.key_outlined,
    title: (l10n) => l10n.reviewGuideCodeTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideCodeBody,
      l10n.reviewGuideCodeLanguages,
    ],
  ),
  ReviewGuideStep(
    id: 'to-review',
    guideHeading: 'What "To review" shows',
    icon: Icons.pending_actions_outlined,
    title: (l10n) => l10n.reviewGuideToReviewTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideToReviewBody,
      l10n.reviewGuideToReviewWaiting,
    ],
  ),
  ReviewGuideStep(
    id: 'check',
    guideHeading: 'Check cards, then sign off',
    icon: Icons.task_alt,
    title: (l10n) => l10n.reviewGuideCheckTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideCheckBody,
      l10n.reviewGuideCheckSignOff,
    ],
  ),
  ReviewGuideStep(
    id: 'suggest',
    guideHeading: 'Suggest, and answer proposals',
    icon: Icons.edit_note,
    title: (l10n) => l10n.reviewGuideSuggestTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideSuggestBody,
      l10n.reviewGuideSuggestOthers,
    ],
  ),
  ReviewGuideStep(
    id: 'adult',
    guideHeading: 'Offensive words and sound-alikes',
    icon: Icons.warning_amber_rounded,
    title: (l10n) => l10n.reviewGuideAdultTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideAdultBody,
      l10n.reviewGuideAdultAlike,
    ],
  ),
  ReviewGuideStep(
    id: 'send',
    guideHeading: 'Send several decks in one mail',
    icon: Icons.outbox_outlined,
    title: (l10n) => l10n.reviewGuideSendTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideSendBody,
      l10n.reviewGuideSendKeep,
      l10n.reviewGuideSendSame,
    ],
  ),
  ReviewGuideStep(
    id: 'public',
    guideHeading: 'What is public, what is private',
    icon: Icons.visibility_outlined,
    title: (l10n) => l10n.reviewGuidePublicTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuidePublicBody,
      l10n.reviewGuidePublicPrivate,
    ],
  ),
  ReviewGuideStep(
    id: 'agree',
    guideHeading: 'How changes reach learners',
    icon: Icons.groups_outlined,
    title: (l10n) => l10n.reviewGuideAgreeTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideAgreeBody,
      l10n.reviewGuideAgreeCount(Reviewing.agreementsNeeded),
      l10n.reviewGuideAgreeMore,
    ],
  ),
  ReviewGuideStep(
    id: 'thanks',
    guideHeading: 'Thank you',
    icon: Icons.favorite_outline,
    title: (l10n) => l10n.reviewGuideThanksTitle,
    paragraphs: (l10n) => <String>[
      l10n.reviewGuideThanksBody,
      l10n.reviewGuideThanksHelp(AppLinks.feedbackEmail),
    ],
  ),
];

/// The reviewer guide (docs/REVIEWING.md) as a short walkthrough, one step
/// per screen: Skip closes it at any step, Back and Next move a step, a
/// swipe does too, and the dots say where the reader is. The last step
/// closes with Got it. Android back goes back a step, and closes it from
/// the first.
class HowReviewingWorks extends StatefulWidget {
  const HowReviewingWorks({super.key, this.initialStep = 0});

  /// For tests: the step it opens on.
  final int initialStep;

  @override
  State<HowReviewingWorks> createState() => _HowReviewingWorksState();
}

class _HowReviewingWorksState extends State<HowReviewingWorks> {
  late int _step = widget.initialStep;
  late final PageController _pages = PageController(
    initialPage: widget.initialStep,
  );

  bool get _last => _step == reviewGuideSteps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    if (step < 0 || step >= reviewGuideSteps.length || !_pages.hasClients) {
      return;
    }
    setState(() => _step = step);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: Durations.medium4,
        curve: Easing.emphasizedDecelerate,
      );
    }
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Semantics(header: true, child: Text(l10n.reviewSettingsHow)),
          actions: <Widget>[
            if (!_last)
              TextButton(onPressed: _close, child: Text(l10n.onboardingSkip)),
            const ReportButton(detail: 'how reviewing works'),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) {
                    if (page != _step) setState(() => _step = page);
                  },
                  children: <Widget>[
                    for (final (i, step) in reviewGuideSteps.indexed)
                      _StepView(step: step, shown: i == _step),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
                child: ReviewGuideDots(step: _step),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _step == 0
                          ? const SizedBox.shrink()
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(
                                  AppSizes.primaryButton,
                                ),
                              ),
                              onPressed: () => _goTo(_step - 1),
                              child: Text(l10n.commonBack),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppSizes.primaryButton,
                          ),
                        ),
                        onPressed: _last ? _close : () => _goTo(_step + 1),
                        child: Text(
                          _last ? l10n.reviewHowGotIt : l10n.onboardingNext,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One step: its picture, title and paragraphs, scrolling when the text is
/// large. A step off screen is kept from the screen reader.
class _StepView extends StatelessWidget {
  const _StepView({required this.step, required this.shown});

  final ReviewGuideStep step;
  final bool shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExcludeSemantics(
      excluding: !shown,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Icon(step.icon, size: 32),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  step.title(l10n),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              for (final paragraph in step.paragraphs(l10n)) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  paragraph,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The progress dots: read out as "Step 2 of 10: <title>", announced
/// whenever the step changes.
class ReviewGuideDots extends StatelessWidget {
  const ReviewGuideDots({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.reviewGuidePosition(
        step + 1,
        reviewGuideSteps.length,
        reviewGuideSteps[step].title(l10n),
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < reviewGuideSteps.length; i++)
              AnimatedContainer(
                duration: still ? Duration.zero : Durations.medium1,
                curve: Segmented.morph,
                margin: const EdgeInsetsDirectional.symmetric(horizontal: 3),
                width: i == step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  // `outline` is 3:1 on the surface, as a mark must be.
                  color: i == step ? scheme.primary : scheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
