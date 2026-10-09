import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/data/log_jsonl.dart';
import '../../core/logs/log_entry.dart';
import '../../core/models/deck.dart';
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
import '../downloads/deck_downloads_section.dart';
import '../gallery/gallery_link.dart';
import '../review/review_section.dart';
import '../placement/native_choice.dart';
import 'adjust_section.dart';
import 'appearance_page.dart';
import 'backup_section.dart';
import 'settings_controls.dart';
import 'sources_page.dart';
import 'update_section.dart';

/// The Settings tab: the profile card, learning, "Adjust to me" (FSRS fitted
/// to the learner, [AdjustSection]), sound, look and language,
/// reminder and privacy, your data, reviewing ([ReviewSection]), logs, a
/// row to the sources the decks name, cloud backup, updates, and the
/// footer.
///
/// Design screen `settings`. Live: the skill switches, Latin-letter
/// readings, adult content (18+, #96), sound, playing words automatically,
/// speech rate, and the Voices row. Every switch's line says what happens
/// in its state (docs/plans/settings-wording.md).
/// Export and import save the review log as a file and merge one back
/// (#20). Logs shows, copies, exports and clears the app's own log (#162).
/// Updates, which the design does not draw, checks GitHub for a newer
/// version, beside the version line, and installs it (ADR-0017). Everything
/// else is built and shown disabled behind its [Feature]: switching profile,
/// the app language, the reminder, the PIN lock, deleting the profile, and
/// cloud backup (#112).
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
                    const AdjustSection(),
                    const SizedBox(height: 20),
                    _sound(context, state),
                    const SizedBox(height: 20),
                    _look(context, state.settings),
                    const SizedBox(height: 20),
                    _reminder(context, state),
                    const SizedBox(height: 20),
                    _data(context, state),
                    const SizedBox(height: 20),
                    // Reviewer mode (docs/plans/deck-browser.md).
                    const ReviewSection(),
                    const SizedBox(height: 20),
                    _logs(context, state),
                    // Where the decks' texts come from (#98), on a page of
                    // its own; no row when no deck names a source.
                    ..._sources(context, state),
                    const SizedBox(height: 20),
                    const BackupSection(),
                    const SizedBox(height: 20),
                    // Deck downloads (#210), with its own gap below it.
                    const DeckDownloadsSection(),
                    const UpdateSection(),
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
          leading: const Icon(Icons.record_voice_over_outlined),
          title: l10n.settingsSpoken,
          subtitle: _spokenLine(l10n, state),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openSpokenLanguages(context),
        ),
        GroupedTile(
          leading: const Icon(Icons.school_outlined),
          title: l10n.settingsLearn,
          subtitle: learning,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.openLearnLanguages(context),
        ),
        for (final skill in Skill.values) ...<Widget>[
          GroupedTile.toggle(
            title: skill.settingsLabel(l10n),
            subtitleOn: _skillLine(l10n, state, skill, on: true),
            subtitleOff: _skillLine(l10n, state, skill, on: false),
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
              )
            else
              GroupedTile(
                leading: const Icon(Icons.timer_outlined),
                title: l10n.cantNowPause,
                onTap: () => settings.pause(
                  skill,
                  until: state.now().add(const Duration(hours: 1)),
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
          subtitleOn: l10n.settingsRomanisationOn,
          subtitleOff: l10n.settingsRomanisationOff,
          value: settings.showRomanisation,
          onChanged: (on) => settings.showRomanisation = on,
        ),
        GroupedTile.toggle(
          title: l10n.settingsAdult,
          subtitleOn: l10n.settingsAdultOn,
          subtitleOff: l10n.settingsAdultOff,
          value: settings.adultContent,
          onChanged: (on) => _setAdult(context, settings, on),
        ),
        if (_withAlphabet(state).isNotEmpty)
          GroupedTile(
            leading: const Icon(Icons.abc),
            title: l10n.settingsAlphabet,
            subtitle: _alphabetLine(l10n, state),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseAlphabets(context, state),
          ),
        // "Learn Telugu from", for each course more than one of the
        // languages the learner speaks teaches (ADR-0036).
        for (final language in _withNatives(state))
          GroupedTile(
            leading: const Icon(Icons.translate),
            title: l10n.nativeChoiceTitle(language.name),
            subtitle: _nativeName(state, language.code),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => NativeChoicePage.open(context, language),
          ),
      ],
    );
  }

  /// The languages the profile learns that more than one of the languages
  /// the learner speaks teaches.
  static List<LanguageInfo> _withNatives(AppState state) => <LanguageInfo>[
    for (final language in state.languages)
      if (state.currentProfile.learns(language.code) &&
          state.offersNativeChoice(language.code))
        language,
  ];

  /// The name of the language [language] is learned from.
  static String? _nativeName(AppState state, String language) {
    final code = state.courseNative(language);
    return state
        .nativeOptions(language)
        .where((o) => o.native.code == code)
        .firstOrNull
        ?.native
        .name;
  }

  /// The languages the learner speaks, best known first, by the names the
  /// decks give them, or their codes where no deck names them.
  static String _spokenLine(AppLocalizations l10n, AppState state) {
    final names = <String, String>{
      for (final deck in state.decks)
        deck.deck.native.code: deck.deck.native.name,
      for (final language in state.languages) language.code: language.name,
    };
    return <String>[
      for (final code in state.settings.spokenLanguages) names[code] ?? code,
    ].join(l10n.commonListSeparator);
  }

  /// A skill switch's line for [on] (docs/plans/settings-wording.md): what
  /// is asked, or not, or that it is skipped while sound is off, then what
  /// the phone lacks for the languages the profile learns: a voice for a
  /// skill that needs one, a recogniser for speaking.
  static String _skillLine(
    AppLocalizations l10n,
    AppState state,
    Skill skill, {
    required bool on,
  }) {
    final line = !on
        ? skill.settingsOff(l10n)
        : skill.needsVoice && !state.settings.soundOn
        ? l10n.settingsSkillSoundOff
        : skill.settingsOn(l10n);
    if (!state.features.isAvailable(skill.feature)) return line;
    final learned = <LanguageInfo>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language,
    ];
    String names(bool Function(LanguageInfo) lacks) => <String>[
      for (final language in learned)
        if (lacks(language)) language.name,
    ].join(l10n.commonListSeparator);
    if (skill.needsVoice) {
      final missing = names((l) => state.voiceStatus(l) == VoiceStatus.missing);
      if (missing.isNotEmpty) return l10n.settingsSkillNoVoice(line, missing);
    }
    if (skill.needsMicrophone) {
      final missing = names(
        (l) => state.speechStatus(l) == SpeechStatus.missing,
      );
      if (missing.isNotEmpty) {
        return l10n.settingsSkillNoRecogniser(line, missing);
      }
    }
    return line;
  }

  /// A switch's row in a dialog: no room at the sides, the dialog has it.
  static const EdgeInsetsGeometry _dialogRow = EdgeInsetsDirectional.symmetric(
    vertical: 10,
  );

  /// The languages the profile learns whose course has decks that need the
  /// alphabet.
  static List<LanguageInfo> _withAlphabet(AppState state) => <LanguageInfo>[
    for (final language in state.languages)
      if (state.currentProfile.learns(language.code) &&
          state.hasAlphabet(language.code))
        language,
  ];

  /// "Learning every alphabet", or the languages learned in Latin letters.
  String _alphabetLine(AppLocalizations l10n, AppState state) {
    final latin = <String>[
      for (final language in _withAlphabet(state))
        if (!state.settings.learnsAlphabet(language.code)) language.name,
    ];
    return latin.isEmpty
        ? l10n.settingsAlphabetAll
        : l10n.settingsAlphabetLatin(latin.join(l10n.commonListSeparator));
  }

  /// A switch per language: its alphabet, or Latin letters only.
  Future<void> _chooseAlphabets(BuildContext context, AppState state) =>
      showDialog<void>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final settings = state.settings;
          return AlertDialog(
            title: Text(l10n.settingsAlphabetTitle),
            content: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final language in _withAlphabet(state))
                      GroupedTile.toggle(
                        title: language.name,
                        subtitleOn: l10n.settingsAlphabetOn(
                          language.script,
                          language.name,
                        ),
                        subtitleOff: state.courseUnits(language.code).isEmpty
                            ? l10n.settingsAlphabetOffEmpty
                            : l10n.settingsAlphabetOff,
                        padding: _dialogRow,
                        value: settings.learnsAlphabet(language.code),
                        onChanged: (on) =>
                            settings.setLearnsAlphabet(language.code, on),
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
        title: Text(
          l10n.settingsSkillLanguagesTitle(skill.settingsLabel(l10n)),
        ),
        content: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final language in languages)
                  GroupedTile.toggle(
                    title: language.name,
                    subtitleOn: l10n.settingsSkillAskedIn(language.name),
                    subtitleOff: l10n.settingsSkillNotAskedIn(language.name),
                    padding: _dialogRow,
                    value: !settings.isOffFor(skill, language.code),
                    onChanged: (on) =>
                        settings.setOffFor(skill, language.code, !on),
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

  /// Adult content asks the learner to confirm their age as it is switched
  /// on (#96), and is off again at once, hiding every rude word.
  static Future<void> _setAdult(
    BuildContext context,
    SettingsNotifier settings,
    bool on,
  ) async {
    if (!on) {
      settings.adultContent = false;
      return;
    }
    final adult = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.settingsAdultConfirmTitle),
          content: SingleChildScrollView(
            child: Text(l10n.settingsAdultConfirmBody),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.settingsAdultConfirm),
            ),
          ],
        );
      },
    );
    if (adult == true) settings.adultContent = true;
  }

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
        GroupedTile.toggle(
          title: l10n.settingsSound,
          subtitleOn: l10n.settingsSoundOn,
          subtitleOff: l10n.settingsSoundOff,
          value: settings.soundOn,
          onChanged: (on) {
            settings.soundOn = on;
            if (!on) showAppSnackBar(context, l10n.settingsSoundOffSkipped);
          },
        ),
        // Shown as it is set, but cannot be changed while nothing plays,
        // and its line says so.
        GroupedTile.toggle(
          title: l10n.settingsAutoplay,
          subtitleOn: settings.soundOn
              ? l10n.settingsAutoplayOn
              : l10n.settingsAutoplayOnSoundOff,
          subtitleOff: settings.soundOn
              ? l10n.settingsAutoplayOff
              : l10n.settingsAutoplayOffSoundOff,
          value: settings.autoplay,
          titleColor: settings.soundOn
              ? null
              : Theme.of(context).colorScheme.onSurfaceVariant,
          onChanged: settings.soundOn ? (on) => settings.autoplay = on : null,
        ),
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
          subtitleOn: l10n.settingsReminderOn(
            MaterialLocalizations.of(context).formatTimeOfDay(
              settings.reminderTime,
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
          ),
          subtitleOff: l10n.settingsReminderOff,
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
          subtitleOn: l10n.settingsPinLockOn,
          subtitleOff: l10n.settingsPinLockOff,
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

  /// The app's own log, for reports (#162): view it, copy it, export it as
  /// a file, or clear it.
  Widget _logs(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final log = state.log;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final empty = log.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GroupedList.settings(
              header: l10n.settingsSectionLogs,
              children: <Widget>[
                GroupedTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: l10n.settingsLogView,
                  subtitle: l10n.settingsLogViewDesc(log.entries.length),
                  trailing: const Icon(Icons.chevron_right),
                  feature: Feature.logs,
                  onTap: () => AppNavigator.openAppLog(context),
                ),
                GroupedTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: l10n.settingsLogCopy,
                  feature: Feature.logs,
                  onTap: empty ? null : () => _copyLog(context, state),
                ),
                GroupedTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: l10n.settingsLogExport,
                  subtitle: l10n.settingsLogExportDesc,
                  feature: Feature.logs,
                  onTap: empty ? null : () => _exportLog(context, state),
                ),
                GroupedTile(
                  leading: const Icon(Icons.delete_outline),
                  title: l10n.settingsLogClear,
                  feature: Feature.logs,
                  onTap: empty ? null : () => _clearLog(context, state),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                l10n.settingsLogAbout,
                style: settingsHelpStyle(Theme.of(context)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: state.log.text));
    if (context.mounted) showAppSnackBar(context, l10n.settingsLogCopied);
  }

  /// Saves the app log as [appLogFileName], where the learner picks.
  Future<void> _exportLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final bool saved;
    try {
      saved = await state.logFiles.save(
        appLogFileName,
        state.log.text,
        mimeType: 'text/plain',
      );
    } on Exception catch (e) {
      state.log.warning('App log not exported: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsLogExportFailed);
      }
      return;
    }
    if (!saved) return;
    state.log.event('App log exported');
    if (context.mounted) {
      showAppSnackBar(context, l10n.settingsExported(appLogFileName));
    }
  }

  /// Asks, then clears the app log.
  Future<void> _clearLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsLogClearTitle),
        content: Text(l10n.settingsLogClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsLogClearConfirm),
          ),
        ],
      ),
    );
    if (clear != true) return;
    await state.log.clear();
    if (context.mounted) showAppSnackBar(context, l10n.settingsLogCleared);
  }

  /// The way to the sources the decks name (#98), with a gap above it, or
  /// nothing when no deck names one.
  List<Widget> _sources(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final sources = sourcesOf(state.decks);
    if (sources.isEmpty) return const <Widget>[];
    final count = sources.fold(0, (n, source) => n + source.lines.length);
    return <Widget>[
      const SizedBox(height: 20),
      GroupedList.settings(
        children: <Widget>[
          GroupedTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: l10n.settingsSources,
            subtitle: l10n.settingsSourcesSummary(count),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppNavigator.openSources(context),
          ),
        ],
      ),
    ];
  }

  /// Saves the review log as `fluenough-<profile>-reviews.jsonl`, where the
  /// learner picks.
  Future<void> _export(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final name = 'fluenough-${state.currentProfile.id}-reviews.jsonl';
    final bool saved;
    try {
      saved = await state.logFiles.save(name, state.progress.exportJsonl());
    } on Exception catch (e) {
      state.log.warning('Review log not exported: ${e.runtimeType}');
      if (context.mounted) showAppSnackBar(context, l10n.settingsExportFailed);
      return;
    }
    if (!saved) return;
    state.log.event('Review log exported');
    if (context.mounted) showAppSnackBar(context, l10n.settingsExported(name));
  }

  /// Merges a picked backup into this profile's log and says how many
  /// reviews were new, or what is wrong with the file.
  Future<void> _import(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final String? text;
    try {
      text = await state.logFiles.open(title: l10n.settingsImportPick);
    } on Exception catch (e) {
      state.log.warning('Review log not imported: ${e.runtimeType}');
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
        fitted: backup.fitted,
      );
    } on FormatException catch (e) {
      state.log.warning('Review log not imported: not a backup');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsImportFailed(e.message));
      }
      return;
    }
    state.log.event('Review log imported: $added new');
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
