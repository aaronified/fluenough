import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_language_picker.dart';
import '../../ui/widgets/fluenough_mark.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../gallery/gallery_link.dart';
import 'appearance_page.dart';
import 'settings_controls.dart';
import 'your_decks_page.dart';

/// The Settings tab: the profile card, then one row per section, each with
/// a line on what is set, in two groups (docs/mockups/settings.html, owner
/// 2026-10-12: "the settings is too long now").
///
/// The first group is Your languages, Activities and memory, Look and
/// language, Reviewing and Your decks; the second Reminders, Your data, App
/// log and Updates. Each row opens a page that holds what the section held
/// on this tab: [LanguagesSettingsPage], [ActivitiesPage], [AppearancePage]
/// (with the app language), `ReviewSection`, `YourDecksPage`,
/// [RemindersPage], [YourDataPage], [AppLogPage] and [UpdatesPage]. The
/// profile card is one target that opens [ProfilesPrivacyPage].
///
/// Reminders is incoming until #90 (`Feature.reminder`), so its row shows
/// the badge and does not open its page yet.
///
/// Keeps a [GalleryLink] at the foot, which draws nothing in a release build.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            state.settings,
            state.progress,
            state.log,
          ]),
          builder: (context, _) => ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 24),
            children: <Widget>[
              TabHeader(title: l10n.settingsTitle),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _ProfileCard(),
                    const SizedBox(height: 20),
                    GroupedList.settings(children: _firstGroup(context, state)),
                    const SizedBox(height: 20),
                    GroupedList.settings(
                      children: _secondGroup(context, state),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      child: Row(
                        children: <Widget>[
                          const FluenoughMark(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.settingsFooter(AppInfo.version),
                              style: settingsHelpStyle(Theme.of(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const GalleryLink(),
            ],
          ),
        ),
      ),
    );
  }

  /// A row that opens the page at [route], with [line] under its title.
  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String line,
    required String route,
    Feature? feature,
  }) => GroupedTile(
    leading: Icon(icon),
    title: title,
    subtitle: line,
    trailing: const Icon(Icons.chevron_right),
    feature: feature,
    onTap: () => AppNavigator.openSettingsPage(context, route),
  );

  List<Widget> _firstGroup(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final learning = <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.name,
    ].join(l10n.commonListSeparator);
    final off = <bool>[
      for (final skill in Skill.values)
        if (skill.hasSwitch)
          !(state.features.isAvailable(skill.feature) &&
              settings.isEnabled(skill)),
    ].where((off) => off).length;
    final reviewing = state.reviewing.on && state.reviewing.code != null;
    return <Widget>[
      _row(
        context,
        icon: Icons.school_outlined,
        title: l10n.settingsRowLanguages,
        line: learning,
        route: AppRoutes.settingsLanguages,
      ),
      _row(
        context,
        icon: Icons.checklist,
        title: l10n.settingsRowActivities,
        line: off == 0
            ? l10n.settingsSumActivitiesAllOn
            : l10n.settingsSumActivitiesSomeOff(off),
        route: AppRoutes.settingsActivities,
      ),
      GroupedTile(
        leading: const Icon(Icons.palette_outlined),
        title: l10n.settingsRowLook,
        subtitle: l10n.settingsSumLook(
          appearanceSummary(l10n, settings),
          AppLanguagePicker.ownName(AppLanguagePicker.current(context)),
        ),
        trailing: const Icon(Icons.chevron_right),
        feature: Feature.appearance,
        onTap: () => AppNavigator.openAppearance(context),
      ),
      _row(
        context,
        icon: Icons.rate_review_outlined,
        title: l10n.settingsRowReviewing,
        line: reviewing
            ? l10n.settingsSumReviewingOn
            : l10n.settingsSumReviewingOff,
        route: AppRoutes.settingsReviewing,
      ),
      _row(
        context,
        icon: Icons.style_outlined,
        title: l10n.settingsRowDecks,
        line: l10n.settingsSumDecks(YourDecksPage.ownDecks(state.decks).length),
        route: AppRoutes.settingsDecks,
      ),
    ];
  }

  List<Widget> _secondGroup(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final remindersOn =
        state.features.isAvailable(Feature.reminder) && settings.reminder;
    return <Widget>[
      _row(
        context,
        icon: Icons.notifications_outlined,
        title: l10n.settingsRowReminders,
        line: remindersOn
            ? l10n.settingsSumRemindersOn(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  settings.reminderTime,
                  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                    context,
                  ),
                ),
              )
            : l10n.settingsReminderOff,
        route: AppRoutes.settingsReminders,
        feature: Feature.reminder,
      ),
      _row(
        context,
        icon: Icons.folder_outlined,
        title: l10n.settingsRowData,
        line: l10n.settingsSumData(state.progress.log.length),
        route: AppRoutes.settingsData,
      ),
      GroupedTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: l10n.settingsRowLog,
        subtitle: l10n.settingsSumLog(state.log.entries.length),
        trailing: const Icon(Icons.chevron_right),
        feature: Feature.logs,
        onTap: () => AppNavigator.openAppLog(context),
      ),
      _row(
        context,
        icon: Icons.system_update_outlined,
        title: l10n.settingsRowUpdates,
        line: l10n.settingsUpdateCurrent(AppInfo.version),
        route: AppRoutes.settingsUpdates,
      ),
    ];
  }
}

/// The current profile and the languages it learns, and "Switch", which
/// opens the profile picker once `Feature.profiles` is on.
///
/// The whole card is one target with a chevron, and opens Profiles and
/// privacy (owner, 2026-10-12); screen readers hear "You, Learning Bengali,
/// Hindi. Opens Profiles and privacy". Its Switch button stays its own
/// target, under the name at every text size so the chevron has room.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final profile = state.currentProfile;
    final learning = <String>[
      for (final language in state.languages)
        if (profile.learns(language.code)) language.name,
    ].join(l10n.commonListSeparator);
    final incoming = isIncoming(context, Feature.profiles);
    final name = profile.name ?? l10n.commonUnnamedProfile;
    final learningLine = learning.isEmpty
        ? null
        : l10n.settingsLearningLanguages(learning);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(name, style: theme.textTheme.sectionTitle),
        if (learningLine != null)
          Text(
            learningLine,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final button = IncomingFeature(
      feature: Feature.profiles,
      label: l10n.settingsSwitchProfile,
      // The badge goes beside the button instead, so the name keeps room.
      badge: IncomingBadgePlacement.none,
      child: FilledButton.tonalIcon(
        style: AppButtonStyles.compact(context),
        onPressed: incoming ? null : () => AppNavigator.openProfiles(context),
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: Text(l10n.settingsSwitchProfile),
      ),
    );
    void open() =>
        AppNavigator.openSettingsPage(context, AppRoutes.settingsProfiles);

    return Semantics(
      container: true,
      button: true,
      label: l10n.settingsProfileCardLabel(
        learningLine == null
            ? name
            : '$name${l10n.commonListSeparator}$learningLine',
      ),
      onTap: open,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.group),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Row(
                    children: <Widget>[
                      ProfileAvatar(profile: profile, size: 56),
                      const SizedBox(width: 14),
                      Expanded(child: text),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    button,
                    if (incoming)
                      const ExcludeSemantics(child: IncomingBadge()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
