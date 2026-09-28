import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/profile_avatar.dart';
import 'due_card.dart';
import 'streak_card.dart';
import 'today_numbers.dart';

/// How many of the profile's decks Today lists; "See all" opens the rest.
const int todayDeckCount = 3;

/// Today: cards due by skill, Start review, the streak and week, and the profile's decks.
///
/// Design screen `today`. Every number is computed ([TodayNumbers]); none is
/// the design's sample. Also here, beyond the design: the banner saying that
/// progress is not saved yet (until #5), and the daily fact card, built but
/// incoming (#48).
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final Widget body = switch (state.status) {
      CatalogStatus.loading => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(state: state),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.commonLoadingDecks,
              ),
            ),
          ),
        ],
      ),
      CatalogStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(state: state),
          Expanded(
            child: EmptyState(
              icon: Icons.error_outline,
              title: l10n.commonDecksFailed,
              body: l10n.commonDecksFailedBody,
            ),
          ),
        ],
      ),
      CatalogStatus.ready => ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          state.progress,
          state.settings,
        ]),
        builder: (context, _) =>
            _TodayContent(state: state, numbers: TodayNumbers.of(state)),
      ),
    };
    return Scaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.state, required this.numbers});

  final AppState state;
  final TodayNumbers numbers;

  /// A deck's badge, as the Decks tab draws it: what a session on the deck
  /// would drill now, due and new together, or Done. Today lists only decks
  /// the profile learns, so never Start.
  static DeckBadge _badgeFor(AppState state, DeckEntry entry) {
    final counts = state.countsFor(entry);
    final n = counts.due + counts.fresh;
    return n > 0
        ? DeckBadge(kind: DeckBadgeKind.due, count: n)
        : const DeckBadge(kind: DeckBadgeKind.done);
  }

  @override
  Widget build(BuildContext context) {
    final decks = state.profileDecks.take(todayDeckCount).toList();
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            // The design's header sits 24 from the start edge, 16 from the end.
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: _Header(state: state),
          ),
          const SizedBox(height: 8),
          if (!state.progressIsSaved) ...<Widget>[
            const _NotSavedBanner(),
            const SizedBox(height: 16),
          ],
          if (numbers.hasDecks) DueCard(numbers: numbers) else const _NoDecks(),
          const SizedBox(height: 16),
          StreakCard(numbers: numbers),
          if (decks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            _DecksHeading(
              onSeeAll: () => AppNavigator.selectTab(context, ShellTab.decks),
            ),
            const SizedBox(height: 8),
            GroupedList(
              outerRadius: AppRadii.group,
              innerRadius: 8,
              gap: 4,
              children: <Widget>[
                for (final entry in decks)
                  DeckTile(
                    entry: entry,
                    glyphSize: 52,
                    badge: _badgeFor(state, entry),
                    onTap: () => AppNavigator.openDeck(context, entry.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const _FactCard(),
        ],
      ),
    );
  }
}

/// The date, the greeting, and the profile's avatar, which will switch
/// profiles once they ship.
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final now = state.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final profile = state.currentProfile;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DateFormat.MMMMEEEEd(locale).format(now),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    greetingFor(l10n, now, profile.name),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IncomingFeature(
            feature: Feature.profiles,
            label: l10n.todaySwitchProfile,
            badge: IncomingBadgePlacement.none,
            child: IconButton(
              tooltip: l10n.todaySwitchProfile,
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: const Size.square(AppSizes.iconButton),
              ),
              onPressed: () => AppNavigator.openProfiles(context),
              icon: ProfileAvatar(profile: profile, size: 44),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Good morning", "Good afternoon" or "Good evening", with [name] if the
/// profile has one. Morning runs from 05:00 to noon, afternoon to 18:00, and
/// evening through the night.
String greetingFor(AppLocalizations l10n, DateTime now, String? name) {
  final hour = now.hour;
  final morning = hour >= 5 && hour < 12;
  final afternoon = hour >= 12 && hour < 18;
  if (name == null || name.isEmpty) {
    return morning
        ? l10n.todayGreetingMorning
        : afternoon
        ? l10n.todayGreetingAfternoon
        : l10n.todayGreetingEvening;
  }
  return morning
      ? l10n.todayGreetingMorningName(name)
      : afternoon
      ? l10n.todayGreetingAfternoonName(name)
      : l10n.todayGreetingEveningName(name);
}

/// "Progress isn't saved yet", while reviews live in memory (#5).
class _NotSavedBanner extends StatelessWidget {
  const _NotSavedBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.commonNotSavedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.commonNotSavedBody,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
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

/// In place of the due card, when no deck teaches a language the profile
/// learns.
class _NoDecks extends StatelessWidget {
  const _NoDecks();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(24),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.todayNoDecks,
            style: theme.textTheme.titleMedium!.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: () => AppNavigator.selectTab(context, ShellTab.decks),
            child: Text(l10n.todayBrowseDecks),
          ),
        ],
      ),
    );
  }
}

/// "Your decks" and "See all", which opens the Decks tab.
class _DecksHeading extends StatelessWidget {
  const _DecksHeading({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.todayYourDecks,
                style: theme.textTheme.sectionTitle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: AppButtonStyles.compact(context),
            onPressed: onSeeAll,
            child: Text(l10n.todaySeeAll),
          ),
        ],
      ),
    );
  }
}

/// A fact a day about a language the profile learns (#48). Built, incoming.
class _FactCard extends StatelessWidget {
  const _FactCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: IncomingFeature(
        feature: Feature.dailyFacts,
        label: l10n.todayFactTitle,
        badge: IncomingBadgePlacement.below,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.todayFactTitle,
                    style: theme.textTheme.sectionTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.todayFactBody,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
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
