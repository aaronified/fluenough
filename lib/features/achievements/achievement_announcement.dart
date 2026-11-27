import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/achievements/achievement.dart';
import '../../core/achievements/achievement_news.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'achievement_texts.dart';
import 'badge_glyph.dart';
import 'badge_view.dart';

/// What the summary of a finished session says about badges (the approved
/// mockup `achievements`, "How an earned badge is announced"): once, at the
/// end of the session that earned them, a tonal card "New badge" that fades in
/// over 0.2 s, two at most and then "and N more", and, the first time, one
/// small card for the badges past reviews already earned (decision 4).
///
/// No confetti, no sound, no vibration, no pop-up over a lesson, no
/// notification, no reminder, and never a word about a streak that is at
/// risk or was lost. A badge is shown once: it is marked seen as the summary
/// first shows it, and a later summary does not show it again.
///
/// The badges are worked out here, at the end of a session, and not after
/// every answer (see `AchievementsHolder`): until the report that counts this
/// session's answers is back, nothing shows.
class AchievementAnnouncement extends StatefulWidget {
  const AchievementAnnouncement({
    super.key,
    required this.language,
    required this.since,
  });

  /// The language of the session that ended.
  final String language;

  /// When the session began: a badge earned at or after it is this
  /// session's.
  final DateTime since;

  @override
  State<AchievementAnnouncement> createState() =>
      _AchievementAnnouncementState();
}

class _AchievementAnnouncementState extends State<AchievementAnnouncement> {
  /// What was found once the report was back; kept, so that marking the
  /// badges seen does not take them off the screen.
  AchievementNews? _news;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.achievements,
      builder: (context, _) {
        if (_news == null) {
          final news = state.achievements.newsFor(
            widget.language,
            since: widget.since,
          );
          if (news != null) {
            _news = news;
            // Marked seen once it is on screen, not while building.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) state.achievements.markSeen(widget.language, news);
            });
          }
        }
        final news = _news;
        if (news == null || news.isEmpty) return const SizedBox.shrink();
        return _Cards(news: news, language: widget.language);
      },
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.news, required this.language});

  final AchievementNews news;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = news.shown;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 24),
      child: _FadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            if (news.past.isNotEmpty) _PastCard(news: news, language: language),
            for (final result in shown)
              _NewBadgeCard(result: result, language: language),
            if (news.more > 0)
              TextButton(
                style: AppButtonStyles.secondary(context),
                onPressed: () =>
                    AppNavigator.openAchievements(context, language: language),
                child: Text(l10n.achvMore('${news.more}')),
              ),
            if (shown.isNotEmpty)
              TextButton(
                style: AppButtonStyles.secondary(context),
                onPressed: () =>
                    AppNavigator.openAchievements(context, language: language),
                child: Text(l10n.achvSeeOnProgress),
              ),
          ],
        ),
      ),
    );
  }
}

/// A badge earned this session: "New badge", its name and what it says.
class _NewBadgeCard extends StatelessWidget {
  const _NewBadgeCard({required this.result, required this.language});

  final AchievementResult result;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = result.def.fullName(l10n);
    final line = result.def.done(l10n, cards: result.need);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.achvNewSemantics(name, line),
      child: Container(
        padding: const EdgeInsetsDirectional.all(14),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          spacing: 12,
          children: <Widget>[
            BadgeGlyph(view: BadgeView(result, BadgeShown.earned)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.achvNewBadge.toUpperCase(),
                    style: theme.textTheme.labelSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    name,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    line,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one quiet card for what past reviews already earned: a row of the
/// badges, what was found, and a button to look through them.
class _PastCard extends StatelessWidget {
  const _PastCard({required this.news, required this.language});

  final AchievementNews news;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: <Widget>[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final result in news.past.take(kPastShown))
                BadgeGlyph(
                  view: BadgeView(result, BadgeShown.earned),
                  size: BadgeSize.small,
                ),
            ],
          ),
          Text(
            l10n.achvPastFound(news.past.length),
            style: theme.textTheme.bodyLarge,
          ),
          FilledButton.tonal(
            style: AppButtonStyles.secondary(context),
            onPressed: () =>
                AppNavigator.openAchievements(context, language: language),
            child: Text(l10n.achvSeeThem),
          ),
        ],
      ),
    );
  }
}

/// How many badges the past-reviews card draws in its row.
const int kPastShown = 6;

/// Fades its child in over 0.2 s; nothing moves under reduced motion.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}
