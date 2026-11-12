import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../app/situations.dart';
import '../../core/decks/weave.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../settings/settings_controls.dart';
import '../settings/settings_section_page.dart';

/// Settings' Culture page (approved mockup `culture-in-course`, screen 6): the
/// switch for culture items, what to do with an item above the learner's level
/// (not shown, or shown with support), how many to weave into each unit, whether
/// they count toward path progress or are a bonus, and whether to show the
/// creator and what still lives today.
class CultureSettingsPage extends StatelessWidget {
  const CultureSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return SettingsSectionPage(
      title: l10n.settingsRowCulture,
      listenable: state.settings,
      builder: (context) {
        final settings = state.settings;
        final language = state.situationsLanguage;
        return <Widget>[
          GroupedList.settings(
            children: <Widget>[
              GroupedTile.toggle(
                title: l10n.cultureSettingShow,
                subtitleOn: l10n.cultureSettingShowOn,
                subtitleOff: l10n.cultureSettingShowOff,
                value: settings.cultureItems,
                onChanged: (on) => settings.cultureItems = on,
              ),
            ],
          ),
          GroupedList.settings(
            header: l10n.cultureSettingAboveHeading,
            children: <Widget>[
              RadioGroup<bool>(
                groupValue: settings.cultureAboveSupport,
                onChanged: (value) =>
                    settings.cultureAboveSupport = value ?? false,
                child: Column(
                  children: <Widget>[
                    RadioListTile<bool>(
                      value: false,
                      title: Text(l10n.cultureSettingAboveHide),
                      subtitle: Text(l10n.cultureSettingAboveHideBody),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      title: Text(l10n.cultureSettingAboveSupport),
                      subtitle: Text(l10n.cultureSettingAboveSupportBody),
                    ),
                  ],
                ),
              ),
            ],
          ),
          GroupedList.settings(
            header: l10n.cultureSettingHowMany,
            children: <Widget>[
              GroupedTile(
                title: l10n.cultureSettingPerUnit,
                subtitle: l10n.cultureSettingPerUnitValue(
                  settings.culturePerUnit,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _askPerUnit(context, settings),
              ),
              GroupedTile.toggle(
                title: l10n.cultureSettingCounts,
                subtitleOn: l10n.cultureSettingCountsOn,
                subtitleOff: l10n.cultureSettingCountsOff,
                value: settings.cultureCounts,
                onChanged: (on) => settings.cultureCounts = on,
              ),
              GroupedTile.toggle(
                title: l10n.cultureSettingCreators,
                subtitleOn: l10n.cultureSettingCreatorsOn,
                subtitleOff: l10n.cultureSettingCreatorsOff,
                value: settings.cultureCreators,
                onChanged: (on) => settings.cultureCreators = on,
              ),
            ],
          ),
          if (language != null)
            GroupedList.settings(
              children: <Widget>[
                GroupedTile(
                  leading: const Icon(Icons.format_quote),
                  title: l10n.cultureSettingOpenDeck,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AppNavigator.openCulture(context, language),
                ),
                GroupedTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: l10n.recTitle,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      AppNavigator.openRecommendations(context, language),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              l10n.cultureSettingNote,
              style: settingsHelpStyle(Theme.of(context)),
            ),
          ),
        ];
      },
    );
  }

  /// A dialog with the numbers of items a unit may be given, one to
  /// [maxCulturePerUnit].
  Future<void> _askPerUnit(
    BuildContext context,
    SettingsNotifier settings,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.cultureSettingPerUnit),
        children: <Widget>[
          RadioGroup<int>(
            groupValue: settings.culturePerUnit,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var n = 1; n <= maxCulturePerUnit; n++)
                  RadioListTile<int>(
                    value: n,
                    title: Text(l10n.cultureSettingPerUnitValue(n)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen != null) settings.culturePerUnit = chosen;
  }
}
