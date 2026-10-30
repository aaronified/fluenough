import 'package:flutter/widgets.dart';

import '../../app/app_state.dart';
import '../../app/language_offer.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/decks/font_check.dart';
import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';

/// One language as the Languages page shows it: its entry in
/// `assets/languages.yaml`, and its course where decks exist for it.
@immutable
class LanguageView {
  const LanguageView(this.language, this.course);

  final SpokenLanguage language;

  /// Null where there is no course: Know only.
  final CatalogLanguage? course;

  String get code => language.code;
  String get name => language.name;

  /// Whether Learn is offered: a course has decks to download.
  bool get canLearn => course != null;

  /// "Hindustani · हिन्दुस्तानी", or the name alone where both are the same.
  String get title => language.ownName.isEmpty || language.ownName == name
      ? name
      : '$name · ${language.ownName}';

  /// The glyph on the language's tile: the first letter of its own name.
  String get glyph {
    final own = language.ownName.isEmpty ? name : language.ownName;
    return own.characters.first;
  }
}

/// Every language of [all] with its course, in [all]'s order.
List<LanguageView> languageViews(AppState state, List<SpokenLanguage> all) {
  final courses = <String, CatalogLanguage>{
    for (final c in state.catalogLanguages(
      ownNames: <String, String>{for (final l in all) l.code: l.ownName},
    ))
      c.code: c,
  };
  // A language the decks teach has a course only where its decks are named
  // by the index or on the phone.
  return <LanguageView>[
    for (final language in all) LanguageView(language, courses[language.code]),
  ];
}

/// The dialect the app teaches for [language]: named in the list, else
/// "Standard" and its name.
String dialectOf(AppLocalizations l10n, SpokenLanguage language) =>
    language.dialect ?? l10n.languagesDialectStandard(language.name);

/// The glyph of a script's tile: the first letter of its sample, or of its
/// name for a script with no sample.
String scriptGlyph(String script, String name) {
  if (script == 'latin') return 'A';
  final sample = scriptSamples[script]?.text;
  final text = sample == null || sample.isEmpty ? name : sample;
  return text.isEmpty ? '' : text.characters.first;
}
