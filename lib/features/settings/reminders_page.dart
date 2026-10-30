import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/reminder_service.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/theme.dart';
import 'settings_controls.dart';
import 'settings_section_page.dart';

/// Settings' Reminders page (#90): the one daily reminder, its time, and
/// the languages it counts. Switching it on asks the phone to allow
/// notifications and, if it does not, leaves it off and says how to allow
/// them (`ReminderService.setOn`). It counts every language the learner
/// learns, so the languages row only says so.
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
                  onChanged: state.reminders.supported
                      ? (on) => _setReminder(context, state.reminders, on)
                      : null,
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
                // Which learned languages the reminder counts: all of them.
                GroupedTile(
                  leading: const Icon(Icons.translate),
                  title: l10n.settingsRemindersLanguages,
                  subtitle: l10n.settingsRemindersLanguagesDesc,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
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

  /// Switches the reminder on or off. Switching on asks the phone to allow
  /// notifications, here and not at launch (#90); when it does not, the
  /// switch stays off and a dialog says how to allow them.
  Future<void> _setReminder(
    BuildContext context,
    ReminderService reminders,
    bool on,
  ) async {
    final setup = await reminders.setOn(on);
    if (setup != ReminderSetup.refused || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reminderRefusedTitle),
        content: Text(l10n.reminderRefusedBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonClose),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reminderOpenSettings),
          ),
        ],
      ),
    );
    if (open ?? false) await reminders.openNotificationSettings();
  }
}
