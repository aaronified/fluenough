import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/data/log_jsonl.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_language_picker.dart';
import '../../ui/widgets/fluenough_mark.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../../ui/widgets/snack.dart';
import '../gallery/gallery_link.dart';
import 'appearance_page.dart';
import 'settings_controls.dart';

/// The Settings tab: the profile card, learning, sound, look and language,
/// reminder and privacy, your data, and the footer.
///
/// Design screen `settings`. Live, in memory until #15 stores them: new cards
/// per day, the skill switches, romanisation, speech rate, and the Voices row.
/// Export and import save the review log as a file and merge one back
/// (#20). Everything else is built and shown disabled behind its [Feature]:
/// switching profile, the app language, the reminder, the PIN lock, and
/// deleting the profile.
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
                    _learning(context, state),
                    const SizedBox(height: 20),
                    _sound(context, state),
                    const SizedBox(height: 20),
                    _look(context, state.settings),
                    const SizedBox(height: 20),
                    _reminder(context, state),
                    const SizedBox(height: 20),
                    _data(context, state),
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

  Widget _learning(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final learning = <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.name,
    ].join(l10n.commonListSeparator);
    return GroupedList.settings(
      header: l10n.settingsSectionLearning,
      children: <Widget>[
        GroupedTile(
          leading: const Icon(Icons.school_outlined),
          title: l10n.settingsLearn,
          subtitle: learning,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openLearnLanguages(context),
        ),
        SettingsSlider(
          title: l10n.settingsNewCardsPerDay,
          valueLabel: '${settings.newCardsPerDay}',
          value: settings.newCardsPerDay.toDouble(),
          min: 0,
          max: SettingsNotifier.maxNewCardsPerDay.toDouble(),
          divisions:
              SettingsNotifier.maxNewCardsPerDay ~/
              SettingsNotifier.newCardsStep,
          semanticValue: (v) => '${v.round()}',
          onChanged: (v) => settings.newCardsPerDay = v.round(),
        ),
        for (final skill in Skill.values) ...<Widget>[
          GroupedTile.toggle(
            title: skill.label(l10n),
            subtitle: skill.settingsDescription(l10n),
            feature: skill.feature,
            // Shown off while incoming, as the design draws it.
            value:
                state.features.isAvailable(skill.feature) &&
                settings.isEnabled(skill),
            onChanged: skill.needsMicrophone
                ? (on) => _setSpeaking(context, state, on)
                : (on) => settings.setSkillEnabled(skill, on),
          ),
          if (skill.pausable &&
              state.features.isAvailable(skill.feature) &&
              settings.isEnabled(skill)) ...<Widget>[
            if (settings.pausedUntil(skill) case final until?
                when until.isAfter(state.now()))
              GroupedTile(
                leading: const Icon(Icons.timer_outlined),
                title: l10n.settingsPausedUntil(
                  MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay.fromDateTime(until)),
                ),
                trailing: TextButton(
                  onPressed: () => settings.resume(skill),
                  child: Text(l10n.settingsResume),
                ),
              ),
            GroupedTile(
              leading: const Icon(Icons.translate),
              title: l10n.settingsSkillLanguages,
              subtitle: _offForLine(l10n, state, skill),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseLanguages(context, state, skill),
            ),
          ],
        ],
        GroupedTile.toggle(
          title: l10n.settingsRomanisation,
          subtitle: l10n.settingsRomanisationDesc,
          value: settings.showRomanisation,
          onChanged: (on) => settings.showRomanisation = on,
        ),
      ],
    );
  }

  /// "On for every language", or the ones [skill] is off for.
  String _offForLine(AppLocalizations l10n, AppState state, Skill skill) {
    final off = <String>[
      for (final language in state.languages)
        if (state.settings.isOffFor(skill, language.code)) language.name,
    ];
    return off.isEmpty
        ? l10n.settingsSkillOnForAll
        : l10n.settingsSkillOffFor(off.join(l10n.commonListSeparator));
  }

  /// [skill] on or off for each language the profile learns (#89).
  Future<void> _chooseLanguages(
    BuildContext context,
    AppState state,
    Skill skill,
  ) => showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final settings = state.settings;
      final languages = [
        for (final language in state.languages)
          if (state.currentProfile.learns(language.code)) language,
      ];
      return AlertDialog(
        title: Text(l10n.settingsSkillLanguagesTitle(skill.label(l10n))),
        content: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final language in languages)
                  CheckboxListTile(
                    title: Text(language.name),
                    value: !settings.isOffFor(skill, language.code),
                    onChanged: (on) =>
                        settings.setOffFor(skill, language.code, on != true),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      );
    },
  );

  /// Speaking asks for the microphone as it is switched on (ADR-0014), and
  /// stays off, saying why, when it cannot be had.
  Future<void> _setSpeaking(
    BuildContext context,
    AppState state,
    bool on,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final setup = await state.setSpeaking(on);
    final why = switch (setup) {
      SpeechSetup.ready => null,
      SpeechSetup.refused => l10n.settingsSpeakingRefused,
      SpeechSetup.noRecogniser => l10n.settingsSpeakingNoRecogniser,
    };
    if (why != null && context.mounted) showAppSnackBar(context, why);
  }

  Widget _sound(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final languages = state.languages;
    final voiced = languages.where(state.hasVoice).length;
    // Rounded to the slider's step, so 0.7 is 0.7 and not 0.7000000000000001.
    double step(double v) => (v * 10).round() / 10;
    return GroupedList.settings(
      header: l10n.settingsSectionSound,
      children: <Widget>[
        SettingsSlider(
          title: l10n.settingsSpeechRate,
          valueLabel: l10n.settingsSpeechRateValue(settings.speechRate),
          value: settings.speechRate,
          min: SettingsNotifier.minSpeechRate,
          max: SettingsNotifier.maxSpeechRate,
          divisions:
              ((SettingsNotifier.maxSpeechRate -
                          SettingsNotifier.minSpeechRate) /
                      SettingsNotifier.speechRateStep)
                  .round(),
          semanticValue: (v) => l10n.settingsSpeechRateValue(step(v)),
          onChanged: (v) => settings.speechRate = step(v),
        ),
        GroupedTile(
          title: l10n.settingsVoices,
          subtitle: l10n.settingsVoicesSummary(voiced, languages.length),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openVoices(context),
        ),
      ],
    );
  }

  Widget _look(BuildContext context, SettingsNotifier settings) {
    final l10n = AppLocalizations.of(context)!;
    return GroupedList.settings(
      header: l10n.settingsSectionLook,
      children: <Widget>[
        GroupedTile(
          leading: const Icon(Icons.palette_outlined),
          title: l10n.settingsAppearance,
          subtitle: appearanceSummary(l10n, settings),
          trailing: const Icon(Icons.chevron_right),
          feature: Feature.appearance,
          onTap: () => AppNavigator.openAppearance(context),
        ),
        GroupedTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: l10n.settingsSpoken,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openSpokenLanguages(context),
        ),
        GroupedTile(
          leading: const Icon(Icons.translate),
          title: l10n.settingsAppLanguage,
          feature: Feature.uiLanguage,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          // Until #46 there is only English, and no setting to hold another
          // choice; FluenoughApp would read one from SettingsNotifier.
          trailing: AppLanguagePicker(
            onChanged: (locale) => showAppSnackBar(
              context,
              l10n.settingsAppLanguageChanged(
                AppLanguagePicker.ownName(locale),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reminder(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final reminderOn = state.features.isAvailable(Feature.reminder);
    final pinOn = state.features.isAvailable(Feature.pinLock);
    return GroupedList.settings(
      header: l10n.settingsSectionReminder,
      children: <Widget>[
        GroupedTile.toggle(
          leading: const Icon(Icons.notifications_outlined),
          title: l10n.settingsReminder,
          subtitle: l10n.settingsReminderDesc,
          feature: Feature.reminder,
          value: reminderOn && settings.reminder,
          onChanged: (on) => settings.reminder = on,
        ),
        // The design puts the time beside the switch. On a row of its own it
        // keeps its own screen-reader node and fits at any text size.
        if (reminderOn && settings.reminder)
          GroupedTile(
            leading: const Icon(Icons.schedule),
            title: l10n.settingsReminderTime,
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                settings.reminderTime,
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
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
        // No way to set or clear a PIN exists yet, so even with the feature
        // on the switch only shows whether this profile has one.
        GroupedTile.toggle(
          leading: const Icon(Icons.lock_outline),
          title: l10n.settingsPinLock,
          subtitle: l10n.settingsPinLockDesc,
          feature: Feature.pinLock,
          value: pinOn && state.currentProfile.isLocked,
          onChanged: null,
        ),
      ],
    );
  }

  Widget _data(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    // Delete waits for profiles to be decided, so it has no action yet even
    // when its feature is on.
    return GroupedList.settings(
      header: l10n.settingsSectionData,
      children: <Widget>[
        GroupedTile(
          leading: const Icon(Icons.file_download_outlined),
          title: l10n.settingsExport,
          subtitle: l10n.settingsExportDesc(state.progress.log.length),
          feature: Feature.logExport,
          padding: _tallRow,
          onTap: () => _export(context, state),
        ),
        GroupedTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: l10n.settingsImport,
          subtitle: l10n.settingsImportDesc,
          feature: Feature.logImport,
          padding: _tallRow,
          onTap: () => _import(context, state),
        ),
        GroupedTile(
          leading: const Icon(Icons.delete_outline),
          title: l10n.settingsDeleteProfile,
          titleColor: Theme.of(context).colorScheme.error,
          feature: Feature.deleteProfile,
          padding: _tallRow,
        ),
      ],
    );
  }

  /// Saves the review log as `fluenough-<profile>-reviews.jsonl`, where the
  /// learner picks.
  Future<void> _export(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final name = 'fluenough-${state.currentProfile.id}-reviews.jsonl';
    final bool saved;
    try {
      saved = await state.logFiles.save(name, state.progress.exportJsonl());
    } on Exception {
      if (context.mounted) showAppSnackBar(context, l10n.settingsExportFailed);
      return;
    }
    if (saved && context.mounted) {
      showAppSnackBar(context, l10n.settingsExported(name));
    }
  }

  /// Merges a picked backup into this profile's log and says how many
  /// reviews were new, or what is wrong with the file.
  Future<void> _import(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final String? text;
    try {
      text = await state.logFiles.open(title: l10n.settingsImportPick);
    } on Exception catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsImportFailed('$e'));
      }
      return;
    }
    if (text == null) return;
    final int added;
    try {
      final backup = LogJsonl.decode(text);
      added = await state.progress.importLog(
        backup.reviews,
        backup.leechActions,
      );
    } on FormatException catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsImportFailed(e.message));
      }
      return;
    }
    if (context.mounted) showAppSnackBar(context, l10n.settingsImported(added));
  }

  /// The design's button rows: 16 above and below.
  static const EdgeInsetsGeometry _tallRow = EdgeInsetsDirectional.symmetric(
    horizontal: 20,
    vertical: 16,
  );
}

/// The current profile, the languages it learns, and "Switch", which opens
/// the profile picker once `Feature.profiles` is on.
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

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          profile.name ?? l10n.commonUnnamedProfile,
          style: theme.textTheme.sectionTitle,
        ),
        if (learning.isNotEmpty)
          Text(
            l10n.settingsLearningLanguages(learning),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final button = IncomingFeature(
      feature: Feature.profiles,
      label: l10n.settingsSwitchProfile,
      // The badge goes under the card's row instead, so the name keeps room.
      badge: IncomingBadgePlacement.none,
      child: FilledButton.tonalIcon(
        style: AppButtonStyles.compact(context),
        onPressed: incoming ? null : () => AppNavigator.openProfiles(context),
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: Text(l10n.settingsSwitchProfile),
      ),
    );
    // Beside the name at normal sizes; under it when the text is large.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    const badge = ExcludeSemantics(child: IncomingBadge());

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProfileAvatar(profile: profile, size: 56),
              const SizedBox(width: 14),
              Expanded(child: text),
              if (!stacked) ...<Widget>[const SizedBox(width: 12), button],
            ],
          ),
          if (stacked || incoming) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[if (stacked) button, if (incoming) badge],
            ),
          ],
        ],
      ),
    );
  }
}
