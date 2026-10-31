import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/language_bar.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../../ui/widgets/visible_listenable_builder.dart';
import '../placement/native_choice.dart';
import 'daily_card.dart';
import 'fact_languages_sheet.dart';
import 'due_card.dart';
import 'quick_revision.dart';
import 'situations_card.dart';
import 'streak_card.dart';
import 'today_numbers.dart';

/// Today: each language's one button for the day (#521), cards due by
/// skill, the streak and week, quick revision (ADR-0029), the Situations
/// card, and the fact of the day.
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
      CatalogStatus.loading => _loading(context, state, l10n),
      CatalogStatus.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(state: state),
          Expanded(
            child: EmptyState(
              icon: Icons.error_outline,
              title: l10n.commonDecksFailed,
              body: l10n.commonDecksFailedBody,
              action: FilledButton(
                onPressed: state.reload,
                child: Text(l10n.commonRetry),
              ),
            ),
          ),
        ],
      ),
      CatalogStatus.ready => VisibleListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          state.progress,
          state.settings,
          state.pacing,
        ]),
        // Today stays built behind the other tabs and under a drill; there
        // it works nothing out for the answers recorded.
        builder: (context, _) {
          final onScreen =
              Visibility.of(context) && TickerMode.valuesOf(context).enabled;
          final numbers = TodayNumbers.of(state, onScreen: onScreen);
          // Kept for the next launch, which draws the tiles from it while
          // the catalog loads (#875).
          if (onScreen) state.rememberToday(numbers.summary);
          return _TodayContent(state: state, numbers: numbers);
        },
      ),
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LanguageBarFrame(
          screen: LanguageBarScreen.today,
          reportDetail: 'Today',
          child: body,
        ),
      ),
    );
  }
}

/// While the catalog loads: the tiles as Today last drew them, if a summary
/// of them was saved for these languages and has something to show (#875),
/// else the spinner. The tiles are not live: a tap does nothing until the
/// numbers are, a moment later, worked out for real.
Widget _loading(BuildContext context, AppState state, AppLocalizations l10n) {
  final saved = state.savedToday;
  final Widget body = saved == null || !saved.hasDecks || saved.due == 0
      ? Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.commonLoadingDecks,
          ),
        )
      : SingleChildScrollView(
          padding: const EdgeInsetsDirectional.only(
            start: AppSizes.gutter,
            end: AppSizes.gutter,
            bottom: 24,
          ),
          child: IgnorePointer(
            child: DueCard(numbers: TodayNumbers.fromSummary(saved)),
          ),
        );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _Header(state: state),
      Expanded(child: body),
    ],
  );
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.state, required this.numbers});

  final AppState state;
  final TodayNumbers numbers;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(state: state),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.gutter,
            ),
            child: _sections(context),
          ),
        ],
      ),
    );
  }

  Widget _sections(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!state.progressIsSaved) ...<Widget>[
          const _NotSavedBanner(),
          const SizedBox(height: 16),
        ],
        // Which language to learn a course from, once one the learner
        // speaks starts teaching it (ADR-0036).
        const NativeChoiceCards(),
        if (numbers.hasDecks) ...<Widget>[
          DailyCard(plans: numbers.daily),
          const SizedBox(height: 24),
          DueCard(numbers: numbers),
        ] else ...<Widget>[const _NoDecks(), const SizedBox(height: 16)],
        StreakCard(numbers: numbers),
        if (numbers.hasDecks) ...<Widget>[
          const SizedBox(height: 24),
          const QuickRevision(),
        ],
        const SizedBox(height: 16),
        const SituationsCard(),
        if (state.features.isIncoming(Feature.dailyFacts)) ...<Widget>[
          const SizedBox(height: 16),
          const _FactCard(),
        ] else
          for (final fact in state.todaysFacts()) ...<Widget>[
            const SizedBox(height: 16),
            _TodayFactCard(fact: fact),
          ],
      ],
    );
  }
}

/// The date, the greeting, and the profile's avatar, which will switch
/// profiles once they ship: the top of Today's content, under the language
/// bar, scrolling away with it (#528).
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
    // As the #528 mockup drew it: 24 from the start edge,
    // 16 from the end, 8 above and 12 below.
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 16, 12),
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
          const SizedBox(width: 8),
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
          borderRadius: BorderRadius.circular(AppRadii.field),
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

/// Today's fact about one language the profile learns (#48), in each
/// language the learner speaks that it is written in, best known first.
/// The fact is deck content, shown as written, in its own language.
class _TodayFactCard extends StatelessWidget {
  const _TodayFactCard({required this.fact});

  final TodayFact fact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final choices = AppScope.of(context).factLanguageChoices.length > 1;
    return Container(
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // At the top left: the languages the fact is shown in (#926); with
          // one language known there is nothing to choose.
          if (choices)
            const FactLanguagesButton()
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.field),
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
                  l10n.todayFactFor(fact.language.name),
                  style: theme.textTheme.sectionTitle,
                ),
                for (final (i, text) in fact.texts.indexed) ...<Widget>[
                  SizedBox(height: i == 0 ? 4 : 10),
                  Text(
                    text.text,
                    locale: Locale(text.code),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A fact a day about a language the profile learns (#48), while the
/// feature is incoming.
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
                borderRadius: BorderRadius.circular(AppRadii.field),
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
