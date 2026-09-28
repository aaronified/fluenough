import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'incoming.dart';

/// The interface-language picker (#46): every translation that ships, from
/// `AppLocalizations.supportedLocales`, each by its own name and ISO 639-3
/// code (`localeOwnName`, `localeOwnIso639_3`). Nothing is hard-coded, so a
/// new ARB file adds itself.
///
/// Settings' App language row and the new-profile screen's "I speak" are
/// this one list. It is disabled while `Feature.uiLanguage` is incoming;
/// wrap it in the incoming layout its screen uses.
class AppLanguagePicker extends StatelessWidget {
  const AppLanguagePicker({
    super.key,
    this.value,
    required this.onChanged,
    this.decoration,
  });

  /// The locale shown as chosen. Null shows the interface language in use,
  /// as [current] finds it.
  final Locale? value;

  /// Called with the locale picked. Null, or `Feature.uiLanguage` incoming,
  /// disables the picker.
  final ValueChanged<Locale>? onChanged;

  /// Null draws the compact outlined box at the end of a Settings row, 45%
  /// of the screen wide. Otherwise a form field as wide as it is given, with
  /// this decoration: its label, border and help.
  final InputDecoration? decoration;

  /// The translation that ships closest to the interface language in use:
  /// the same language, or else the first supported locale.
  static Locale current(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    const all = AppLocalizations.supportedLocales;
    return all.firstWhere(
      (l) => l.languageCode == language,
      orElse: () => all.first,
    );
  }

  /// [locale]'s name for itself, such as "English".
  static String ownName(Locale locale) =>
      lookupAppLocalizations(locale).localeOwnName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = value ?? current(context);
    final change = onChanged;
    final ValueChanged<Locale?>? picked =
        change == null || isIncoming(context, Feature.uiLanguage)
        ? null
        : (locale) {
            if (locale != null) change(locale);
          };
    final items = <DropdownMenuItem<Locale>>[
      for (final locale in AppLocalizations.supportedLocales)
        DropdownMenuItem<Locale>(
          value: locale,
          child: Text(
            l10n.settingsAppLanguageOption(
              lookupAppLocalizations(locale).localeOwnName,
              lookupAppLocalizations(locale).localeOwnIso639_3,
            ),
            locale: locale,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final field = decoration;
    if (field != null) {
      return DropdownButtonFormField<Locale>(
        initialValue: chosen,
        isExpanded: true,
        decoration: field,
        borderRadius: BorderRadius.circular(AppRadii.small),
        onChanged: picked,
        items: items,
      );
    }

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.45,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.compactButton),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Locale>(
            value: chosen,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            onChanged: picked,
            items: items,
          ),
        ),
      ),
    );
  }
}
