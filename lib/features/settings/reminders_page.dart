import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import 'settings_controls.dart';
import 'settings_section_page.dart';

/// Settings' Reminders page (#90): the one daily reminder, its time, and
/// the languages it counts. Opened from the tab's Reminders row, which is
/// incoming until #90 lands, so everything here is behind
/// `Feature.reminder`; the languages row has no action until then.
///
/// Quiet hours are gone (owner, 2026-10-12): the learner sets the time.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final settings = state.settings;
    final reminderOn = state.features.isAvailable(Feature.reminder);
    final materials = MaterialLocalizations.of(context);
    final alwaysUse24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    String timeText() => materials.formatTimeOfDay(
      settings.reminderTime,
      alwaysUse24HourFormat: alwaysUse24Hour,
    );
    return SettingsSectionPage(
      title: l10n.settingsRowReminders,
      listenable: settings,
      builder: (context) => <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GroupedList.settings(
              children: <Widget>[
                GroupedTile.toggle(
                  leading: const Icon(Icons.notifications_outlined),
                  title: l10n.settingsReminder,
                  subtitleOn: l10n.settingsReminderOn(timeText()),
                  subtitleOff: l10n.settingsReminderOff,
                  feature: Feature.reminder,
                  value: reminderOn && settings.reminder,
                  onChanged: (on) => settings.reminder = on,
                ),
                // The design puts the time beside the switch. On a row of
                // its own it keeps its own screen-reader node and fits at
                // any text size.
                if (reminderOn && settings.reminder)
                  GroupedTile(
                    leading: const Icon(Icons.schedule),
                    title: l10n.settingsReminderTime,
                    trailing: Text(
                      timeText(),
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: settings.reminderTime,
                      );
                      if (picked != null) settings.reminderTime = picked;
                    },
                  ),
                // Which learned languages the reminder counts. Drawn, with
                // no choice behind it until #90.
                GroupedTile(
                  leading: const Icon(Icons.translate),
                  title: l10n.settingsRemindersLanguages,
                  subtitle: l10n.settingsRemindersLanguagesDesc,
                  trailing: const Icon(Icons.chevron_right),
                  feature: Feature.reminder,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Text(
                l10n.settingsRemindersAbout,
                style: settingsHelpStyle(Theme.of(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
