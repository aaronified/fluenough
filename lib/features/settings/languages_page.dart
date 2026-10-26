import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../placement/native_choice.dart';
import 'settings_section_page.dart';
import 'sources_page.dart';
import 'your_decks_page.dart';
import '../../core/models/deck.dart';

/// Settings' Your languages page: the languages known and learned, the
/// readings, IPA and adult content switches, the language an
/// ambiguous course is learned from, the sources the decks name, and the
/// decks the learner added.
///
/// What the Learning section held before the Settings tab became a list of
/// pages (docs/mockups/settings.html).
class LanguagesSettingsPage extends StatelessWidget {
  const LanguagesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return SettingsSectionPage(
      title: l10n.settingsRowLanguages,
      listenable: state.settings,
      builder: (context) => <Widget>[_learning(context, state)],
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
        GroupedTile.toggle(
          leading: GroupedTile.noIcon,
          title: l10n.settingsRomanisation,
          subtitleOn: l10n.settingsRomanisationOn,
          subtitleOff: l10n.settingsRomanisationOff,
          value: settings.showRomanisation,
          onChanged: (on) => settings.showRomanisation = on,
        ),
        GroupedTile.toggle(
          leading: GroupedTile.noIcon,
          title: l10n.settingsIpa,
          subtitleOn: l10n.settingsIpaOn,
          subtitleOff: l10n.settingsIpaOff,
          value: settings.showIpa,
          onChanged: (on) => settings.showIpa = on,
        ),
        GroupedTile.toggle(
          leading: GroupedTile.noIcon,
          title: l10n.settingsAdult,
          subtitleOn: l10n.settingsAdultOn,
          subtitleOff: l10n.settingsAdultOff,
          value: settings.adultContent,
          onChanged: (on) => _setAdult(context, settings, on),
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
        // Where the decks' texts come from (#98), on a page of its own.
        _sources(context, state),
        // Decks the learner added (#475), moved here from the Settings list
        // (owner, 2026-10-26).
        GroupedTile(
          leading: const Icon(Icons.style_outlined),
          title: l10n.settingsRowDecks,
          subtitle: l10n.settingsSumDecks(
            YourDecksPage.ownDecks(state.decks).length,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              AppNavigator.openSettingsPage(context, AppRoutes.settingsDecks),
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

  /// The row to the decks' licence and the sources they name (#98,
  /// ADR-0040). It is always there, since the licence always applies; with
  /// no source named, its line names the licence.
  Widget _sources(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final sources = sourcesOf(state.decks);
    final count = sources.fold(0, (n, source) => n + source.lines.length);
    return GroupedTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: l10n.settingsSources,
      subtitle: count == 0
          ? l10n.sourcesLicence
          : l10n.settingsSourcesSummary(count),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => AppNavigator.openSources(context),
    );
  }
}
