import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/expressive_shape.dart';
import '../../ui/widgets/fluenough_mark.dart';
import 'onboarding_step.dart';

/// The first screen of a new install: the mark, the name, what the app does.
final OnboardingStep welcomeStep = OnboardingStep(
  id: 'welcome',
  action: (l10n) => l10n.onboardingStart,
  content: (context, at) => WelcomeContent(entrance: at.firstVisit),
);

/// The brand's icon background (`fluenough-brand/README.md`), in light only:
/// the launcher icon's plate, carried into the app.
const Color _brandPlate = Color(0xFFAEF2C6);

class WelcomeContent extends StatelessWidget {
  const WelcomeContent({super.key, required this.entrance});

  /// Play the entrance: the plate turns in, the words rise. Once per flow,
  /// and never with animations off.
  final bool entrance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    final large = MediaQuery.textScalerOf(context).scale(16) > 21;
    final plays = entrance && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: plays ? 0 : 1, end: 1),
      duration: Durations.long4,
      builder: (context, t, _) {
        final turn = const Interval(
          0,
          0.7,
          curve: Easing.emphasizedDecelerate,
        ).transform(t);
        final rise = const Interval(
          0.3,
          1,
          curve: Easing.emphasizedDecelerate,
        ).transform(t);
        return CustomScrollView(
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Spacer(flex: 2),
                    Transform.scale(
                      scale: 0.8 + 0.2 * turn,
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: large ? 96 : 128,
                        height: large ? 96 : 128,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: dark
                              ? scheme.surfaceContainerHigh
                              : _brandPlate,
                          shape: ExpressiveShapeBorder(
                            ExpressiveShape.cookie,
                            turn: -0.6 * (1 - turn),
                          ),
                        ),
                        child: FluenoughMark(size: large ? 56 : 72),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: rise.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - rise)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Semantics(
                              header: true,
                              namesRoute: true,
                              // One word: it shrinks rather than breaks.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
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
                            const SizedBox(height: 4),
                            Text(
                              l10n.onboardingWelcomeTagline,
                              style: theme.textTheme.headlineSmall!.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.onboardingWelcomeBody,
                              style: theme.textTheme.bodyLarge!.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: rise.clamp(0.0, 1.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 20,
                            color: muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.onboardingWelcomeNote,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: muted,
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
          ],
        );
      },
    );
  }
}
