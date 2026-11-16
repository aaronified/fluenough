import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/settings.dart';
import '../../core/data/spoken_languages.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/hint.dart';
import '../today/fact_languages_sheet.dart';

/// The three-dot menu at the top right of the Languages screen
/// (`docs/mockups/menu-and-report.html`, approved by the owner,
/// 2026-11-16): what Settings' Your languages page held besides the list.
///
/// Two groups. Show: five switches, each a box at the leading edge, empty
/// when off and ticked when on, with the line it had as a switch under its
/// label. Open: Fact languages, a chevron whose choices open from the row
/// (a choice list, so no sheet), and Sources, a link icon, since it opens
/// another screen. A chevron means more choices inside the menu, a link
/// icon another screen.
class LanguagesMenu extends StatelessWidget {
  const LanguagesMenu({super.key, this.spokenList});

  /// The languages of `assets/languages.yaml`, to name the fact languages;
  /// null names them from the courses.
  final List<SpokenLanguage>? spokenList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => MenuAnchor(
        menuChildren: _items(context, l10n, state),
        builder: (context, controller, _) => LabelledIconButton(
          label: l10n.languagesMenuMore,
          hint: l10n.languagesMenuMore,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }

  List<Widget> _items(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final settings = state.settings;
    final ipaOn = settings.showIpa;
    return <Widget>[
      _Heading(l10n.languagesMenuShow),
      _toggle(
        key: 'languages-menu-romanisation',
        title: l10n.settingsRomanisation,
        line: settings.showRomanisation
            ? l10n.settingsRomanisationOn
            : l10n.settingsRomanisationOff,
        value: settings.showRomanisation,
        onChanged: (on) => settings.showRomanisation = on,
      ),
      _toggle(
        key: 'languages-menu-ipa',
        title: l10n.settingsIpa,
        line: ipaOn ? l10n.settingsIpaOn : l10n.settingsIpaOff,
        value: ipaOn,
        onChanged: (on) => settings.showIpa = on,
      ),
      // Greyed out, and says why, while IPA is off (#697).
      _toggle(
        key: 'languages-menu-ipa-replaces',
        title: l10n.settingsIpaReplaces,
        line: !ipaOn
            ? l10n.settingsIpaReplacesNeedsIpa
            : settings.ipaReplacesReading
            ? l10n.settingsIpaReplacesOn
            : l10n.settingsIpaReplacesOff,
        value: ipaOn && settings.ipaReplacesReading,
        onChanged: ipaOn ? (on) => settings.ipaReplacesReading = on : null,
      ),
      _toggle(
        key: 'languages-menu-adult',
        title: l10n.settingsAdult,
        line: settings.adultContent
            ? l10n.settingsAdultOn
            : l10n.settingsAdultOff,
        value: settings.adultContent,
        onChanged: (on) => _setAdult(context, settings, on),
      ),
      _toggle(
        key: 'languages-menu-hide-above',
        title: l10n.settingsHideAbove,
        line: settings.hideAboveLevel
            ? l10n.settingsHideAboveOn
            : l10n.settingsHideAboveOff,
        value: settings.hideAboveLevel,
        onChanged: (on) => settings.hideAboveLevel = on,
      ),
      const Divider(height: 16),
      _Heading(l10n.languagesMenuOpen),
      _factLanguages(l10n, state),
      MenuItemButton(
        key: const ValueKey<String>('languages-menu-sources'),
        trailingIcon: const Icon(Icons.open_in_new),
        onPressed: () => AppNavigator.openSources(context),
        child: _Label(title: l10n.settingsSources),
      ),
    ];
  }

  /// A switch: its box at the leading edge in both states, the menu staying
  /// open as it flips. A null [onChanged] greys it out.
  Widget _toggle({
    required String key,
    required String title,
    required String line,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => CheckboxMenuButton(
    key: ValueKey<String>(key),
    value: value,
    closeOnActivate: false,
    onChanged: onChanged == null ? null : (on) => onChanged(on ?? false),
    child: _Label(title: title, line: line, enabled: onChanged != null),
  );

  /// The languages Today's fact is shown in (#926): the languages known,
  /// each a box in the row's own submenu. The last one checked stays.
  Widget _factLanguages(AppLocalizations l10n, AppState state) {
    final known = state.factLanguageChoices;
    final checked = state.factLanguagesChecked;
    return SubmenuButton(
      key: const ValueKey<String>('languages-menu-fact'),
      menuChildren: <Widget>[
        for (final code in known)
          CheckboxMenuButton(
            key: ValueKey<String>('fact-language-$code'),
            value: checked.contains(code),
            closeOnActivate: false,
            // The last checked box stays: the fact is always shown.
            onChanged: checked.length == 1 && checked.contains(code)
                ? null
                : (_) => state.toggleFactLanguage(code),
            child: _Label(
              title: factLanguageName(state, spokenList, code),
              line: checked.length == 1 && checked.contains(code)
                  ? l10n.factLanguagesLast
                  : null,
              enabled: !(checked.length == 1 && checked.contains(code)),
            ),
          ),
      ],
      child: _Label(
        title: l10n.settingsFactLanguages,
        line: factLanguagesLine(l10n, state, spokenList),
      ),
    );
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
}

/// A small heading over a group of the menu.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A menu row's label and, under it, its muted line. Held to a width that
/// wraps the line, so that a row is two or three lines at 1.4x text rather
/// than wider than the phone.
class _Label extends StatelessWidget {
  const _Label({required this.title, this.line, this.enabled = true});

  final String title;
  final String? line;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = this.line;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 232),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.bodyLarge),
            if (line != null)
              Text(
                line,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: enabled ? 1 : 0.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
