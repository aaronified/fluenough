import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/theme.dart';
import 'settings_controls.dart';
import 'settings_section_page.dart';

/// Settings' Profiles and privacy page, opened from the profile card:
/// Profiles (You, Switch profile, Add profile), Privacy (the PIN lock), and
/// Delete this profile in the error colour.
///
/// Every row waits for profiles (#204), so each is behind its [Feature] and
/// has no action of its own yet: You will open Edit profile, the design's
/// New profile screen with its shape and name.
class ProfilesPrivacyPage extends StatelessWidget {
  const ProfilesPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final learning = <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.name,
    ].join(l10n.commonListSeparator);
    final pinOn = state.features.isAvailable(Feature.pinLock);
    return SettingsSectionPage(
      title: l10n.settingsRowProfiles,
      listenable: state.settings,
      builder: (context) => <Widget>[
        GroupedList.settings(
          header: l10n.settingsProfilesHeading,
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.person_outline),
              title: state.currentProfile.name ?? l10n.commonUnnamedProfile,
              subtitle: l10n.settingsProfilesYou(learning),
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.profiles,
            ),
            GroupedTile(
              leading: const Icon(Icons.switch_account_outlined),
              title: l10n.settingsProfilesSwitch,
              subtitle: l10n.settingsProfilesSwitchDesc,
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.profiles,
              onTap: () => AppNavigator.openProfiles(context),
            ),
            GroupedTile(
              leading: const Icon(Icons.person_add_outlined),
              title: l10n.settingsProfilesAdd,
              subtitle: l10n.settingsProfilesAddDesc,
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.profiles,
              onTap: () => AppNavigator.openNewProfile(context),
            ),
          ],
        ),
        GroupedList.settings(
          header: l10n.settingsProfilesPrivacy,
          children: <Widget>[
            // No way to set or clear a PIN exists yet, so even with the
            // feature on the switch only shows whether this profile has one.
            GroupedTile.toggle(
              leading: const Icon(Icons.lock_outline),
              title: l10n.settingsPinLock,
              subtitleOn: l10n.settingsPinLockOn,
              subtitleOff: l10n.settingsPinLockOff,
              feature: Feature.pinLock,
              value: pinOn && state.currentProfile.isLocked,
              onChanged: null,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Delete waits for profiles to be decided, so it has no action
            // yet even when its feature is on.
            GroupedList.settings(
              children: <Widget>[
                GroupedTile(
                  leading: const Icon(Icons.delete_outline),
                  title: l10n.settingsDeleteProfile,
                  subtitle: l10n.settingsDeleteWarning(
                    state.currentProfile.name ?? l10n.commonUnnamedProfile,
                  ),
                  titleColor: scheme.error,
                  feature: Feature.deleteProfile,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Text(
                l10n.settingsProfilesAbout,
                style: settingsHelpStyle(Theme.of(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
