import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/recommendation_feed.dart';
import '../../app/routes.dart';
import '../../app/situations.dart';
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'recommendations_page.dart';

/// The works the learner completed, on Today (approved mockup
/// `culture-recommendations`, screen 3, variant A: the cover strip): the title,
/// how many works and how many of them have questions, a cover for each with
/// its tick, and "See all and recommendations". A cover opens that work in the
/// list. With nothing completed yet it says so and still offers the list; with
/// no recommended work for the language it is not drawn.
class CompletedWorksCard extends StatelessWidget {
  const CompletedWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final language = state.situationsLanguage;
    if (language == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.recommendationProgress,
        state.settings,
        state.progress,
      ]),
      builder: (context, _) {
        try {
          return _build(context, state, language);
        } on Object catch (error, stack) {
          state.log.error('Completed works could not be shown: $error\n$stack');
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _build(BuildContext context, AppState state, String language) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final offered = state.recommendationsFor(language);
    final progress = state.recommendationProgress;
    final byId = <String, Recommendation>{for (final w in offered) w.id: w};
    final done = <Recommendation>[
      for (final mark in progress.completed)
        ?byId[mark.recommendationId],
    ];
    if (offered.isEmpty && done.isEmpty) return const SizedBox.shrink();
    final withQuestions = done.where((w) => w.questions.isNotEmpty).length;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.recHomeTitle,
                style: theme.textTheme.sectionTitle,
              ),
            ),
            Text(
              done.isEmpty
                  ? l10n.recHomeNone
                  : l10n.recHomeCount(done.length, withQuestions),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (done.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final work in done)
                      _Cover(work: work, language: language),
                  ],
                ),
              ),
            ],
            TextButton(
              style: AppButtonStyles.inline(context),
              onPressed: () =>
                  AppNavigator.openRecommendations(context, language),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: Text(l10n.recHomeSeeAll)),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One completed work: its cover, a tick, and its title under it.
class _Cover extends StatelessWidget {
  const _Cover({required this.work, required this.language});

  final Recommendation work;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: l10n.recCoverLabel(work.title),
      excludeSemantics: true,
      onTap: () =>
          AppNavigator.openRecommendations(context, language, openId: work.id),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.field),
        onTap: () => AppNavigator.openRecommendations(
          context,
          language,
          openId: work.id,
        ),
        child: SizedBox(
          width: 84,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 6),
            child: Column(
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 76,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Icon(
                        recommendationIcon(work.medium),
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    PositionedDirectional(
                      end: -6,
                      bottom: -6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  work.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
