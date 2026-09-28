import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../../ui/widgets/snack.dart';
import '../gallery/gallery_link.dart';
import 'appearance_page.dart';
import 'settings_row.dart';

/// The version the footer shows. There is no package to read it from the
/// build (AGENTS.md rule 6), so it is kept in step with `pubspec.yaml` by
/// hand, and `test/features/settings/settings_page_test.dart` checks it.
const String appVersion = '0.1.0';

/// The Settings tab: the profile card, learning, sound, look and language,
/// reminder and privacy, your data, and the footer.
///
/// Design screen `settings`. Live, in memory until #15 stores them: new cards
/// per day, the skill switches, romanisation, speech rate, and the Voices row.
/// Everything else is built and shown disabled behind its [Feature]: switching
/// profile, Appearance, the app language, the reminder, the PIN lock, the
/// review log's export and import, and deleting the profile.
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
                      child: Text(
                        l10n.settingsFooter(appVersion),
                        style: settingsHelpStyle(Theme.of(context)),
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
    return GroupedList.settings(
      header: l10n.settingsSectionLearning,
      children: <Widget>[
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
        for (final skill in Skill.values)
          SettingsRow.toggle(
            title: skill.label(l10n),
            subtitle: skill.settingsDescription(l10n),
            feature: skill.feature,
            // Shown off while incoming, as the design draws it.
            value:
                state.features.isAvailable(skill.feature) &&
                settings.isEnabled(skill),
            onChanged: (on) => settings.setSkillEnabled(skill, on),
          ),
        SettingsRow.toggle(
          title: l10n.settingsRomanisation,
          subtitle: l10n.settingsRomanisationDesc,
          value: settings.showRomanisation,
          onChanged: (on) => settings.showRomanisation = on,
        ),
      ],
    );
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
        SettingsRow(
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
        SettingsRow(
          leading: const Icon(Icons.palette_outlined),
          title: l10n.settingsAppearance,
          subtitle: appearanceSummary(l10n, settings),
          trailing: const Icon(Icons.chevron_right),
          feature: Feature.appearance,
          onTap: () => AppNavigator.openAppearance(context),
        ),
        SettingsRow(
          leading: const Icon(Icons.translate),
          title: l10n.settingsAppLanguage,
          feature: Feature.uiLanguage,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          trailing: const AppLanguagePicker(),
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
        SettingsRow.toggle(
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
          SettingsRow(
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
        SettingsRow.toggle(
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
    // Export, import and delete wait for the review log to be stored (#5,
    // #20) and for profiles to be decided, so they have no action yet even
    // when their feature is on.
    return GroupedList.settings(
      header: l10n.settingsSectionData,
      children: <Widget>[
        SettingsRow(
          leading: const Icon(Icons.file_download_outlined),
          title: l10n.settingsExport,
          subtitle: l10n.settingsExportDesc(state.progress.log.length),
          feature: Feature.logExport,
          padding: _tallRow,
        ),
        SettingsRow(
          leading: const Icon(Icons.file_upload_outlined),
          title: l10n.settingsImport,
          subtitle: l10n.settingsImportDesc,
          feature: Feature.logImport,
          padding: _tallRow,
        ),
        SettingsRow(
          leading: const Icon(Icons.delete_outline),
          title: l10n.settingsDeleteProfile,
          titleColor: Theme.of(context).colorScheme.error,
          feature: Feature.deleteProfile,
          padding: _tallRow,
        ),
      ],
    );
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

/// The one interface-language picker (#46): every translation that ships,
/// from `AppLocalizations.supportedLocales`, each by its own name and ISO
/// 639-3 code (`localeOwnName`, `localeOwnIso639_3`). Nothing is hard-coded,
/// so a new ARB file adds itself.
///
/// Disabled behind `Feature.uiLanguage`. The new-profile screen's "I speak"
/// is the same list.
class AppLanguagePicker extends StatelessWidget {
  const AppLanguagePicker({super.key});

  /// Each supported locale, with how the picker names it.
  static List<({Locale locale, String name, String option})> options(
    AppLocalizations l10n,
  ) => <({Locale locale, String name, String option})>[
    for (final locale in AppLocalizations.supportedLocales)
      () {
        final own = lookupAppLocalizations(locale);
        return (
          locale: locale,
          name: own.localeOwnName,
          option: l10n.settingsAppLanguageOption(
            own.localeOwnName,
            own.localeOwnIso639_3,
          ),
        );
      }(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final all = options(l10n);
    final current = Localizations.localeOf(context);
    final selected = all
        .map((o) => o.locale)
        .firstWhere(
          (l) => l.languageCode == current.languageCode,
          orElse: () => all.first.locale,
        );
    final incoming = isIncoming(context, Feature.uiLanguage);

    // Until #46 there is only English, and no setting to hold another
    // choice; FluenoughApp would read one from SettingsNotifier.
    void chosen(Locale? locale) {
      if (locale == null) return;
      final name = all.firstWhere((o) => o.locale == locale).name;
      showAppSnackBar(context, l10n.settingsAppLanguageChanged(name));
    }

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.45,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.compactButton),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Locale>(
            value: selected,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            onChanged: incoming ? null : chosen,
            items: <DropdownMenuItem<Locale>>[
              for (final o in all)
                DropdownMenuItem<Locale>(
                  value: o.locale,
                  child: Text(
                    o.option,
                    locale: o.locale,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
