import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/theme.dart';
import 'adjust_section.dart';
import 'settings_controls.dart';
import 'settings_section_page.dart';

/// Settings' Activities and memory page (#243): a switch for each activity a
/// learner may skip, in the order the mockup draws them, with what belongs
/// to each beside it, then "Adjust to me" (ADR-0035).
///
/// Written words; Heard words, with Play words automatically and pausing;
/// Spoken words, with pausing, Speech rate and Voices, which hearing and
/// speaking share; Reading. Seen words, grammar, matching pairs, choosing
/// answers and phonemic contrasts have no switch: they are always asked, so
/// a lesson always has questions, and a line says so.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return SettingsSectionPage(
      title: l10n.settingsRowActivities,
      listenable: Listenable.merge(<Listenable>[
        state.settings,
        state.progress,
      ]),
      builder: (context) => <Widget>[
        _activities(context, state),
        const AdjustSection(),
      ],
    );
  }

  Widget _activities(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    final languages = state.languages;
    final voiced = languages.where(state.hasVoice).length;
    // Rounded to the slider's step, so 0.7 is 0.7 and not 0.7000000000000001.
    double step(double v) => (v * 10).round() / 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GroupedList.settings(
          children: <Widget>[
            _skill(context, state, Skill.production),
            _skill(context, state, Skill.listening),
            ..._pause(context, state, Skill.listening),
            // From the old Sound section: governs every word the app says,
            // so it stays whatever Heard words is set to.
            GroupedTile.toggle(
              leading: GroupedTile.noIcon,
              title: l10n.settingsAutoplay,
              subtitleOn: l10n.settingsAutoplayOn,
              subtitleOff: l10n.settingsAutoplayOff,
              value: settings.autoplay,
              onChanged: (on) => settings.autoplay = on,
            ),
            _skill(context, state, Skill.speaking),
            ..._pause(context, state, Skill.speaking),
            // Shared by hearing and speaking, so below Spoken words.
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
              leading: GroupedTile.noIcon,
              title: l10n.settingsVoices,
              subtitle: l10n.settingsVoicesSummary(voiced, languages.length),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppNavigator.openVoices(context),
            ),
            _skill(context, state, Skill.reading),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Text(
            l10n.settingsActivitiesAlwaysAsked,
            style: settingsHelpStyle(Theme.of(context)),
          ),
        ),
      ],
    );
  }

  /// [skill]'s switch. Shown off while its feature is incoming, as the
  /// design draws it.
  Widget _skill(BuildContext context, AppState state, Skill skill) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    return GroupedTile.toggle(
      leading: GroupedTile.noIcon,
      title: skill.settingsLabel(l10n),
      subtitleOn: _skillLine(l10n, state, skill, on: true),
      subtitleOff: _skillLine(l10n, state, skill, on: false),
      feature: skill.feature,
      value:
          state.features.isAvailable(skill.feature) &&
          settings.isEnabled(skill),
      onChanged: skill.needsMicrophone
          ? (on) => _setSpeaking(context, state, on)
          : (on) => settings.setSkillEnabled(skill, on),
    );
  }

  /// What a pausable skill adds while it is on: the pause, and the
  /// languages it is asked in.
  List<Widget> _pause(BuildContext context, AppState state, Skill skill) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings;
    if (!skill.pausable ||
        !state.features.isAvailable(skill.feature) ||
        !settings.isEnabled(skill)) {
      return const <Widget>[];
    }
    return <Widget>[
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
    ];
  }

  /// A skill switch's line for [on] (docs/plans/settings-wording.md): what
  /// is asked, or not, then what the phone lacks for the languages the
  /// profile learns: a voice for a skill that needs one, a recogniser for
  /// speaking.
  static String _skillLine(
    AppLocalizations l10n,
    AppState state,
    Skill skill, {
    required bool on,
  }) {
    final line = on ? skill.settingsOn(l10n) : skill.settingsOff(l10n);
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
}
