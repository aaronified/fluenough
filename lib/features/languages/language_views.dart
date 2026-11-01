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

  /// Whether Learn is offered: a course has decks to download, and this
  /// app is new enough to read them. The gate is language-level only: a
  /// language's own `min_app` greys the row, while a deck's or a file's
  /// `min_app` does not (the language stays learnable; ADR-0052).
  bool get canLearn => course != null && needsApp == null;

  /// The app version the course needs, when this app is older (ADR-0052).
  String? get needsApp => course?.needsApp;

  /// "Hindustani · हिन्दुस्तानी", or the name alone where both are the same.
  String get title => language.ownName.isEmpty || language.ownName == name
      ? name
      : '$name · ${language.ownName}';

  /// The glyph on the language's tile: the first letter of its own name, or
  /// for a notation its own mark (`ə` for the IPA, `⠃` for braille).
  String get glyph {
    final mark = language.isNotation ? notationGlyphs[language.script] : null;
    if (mark != null) return mark;
    final own = language.ownName.isEmpty ? name : language.ownName;
    return own.characters.first;
  }
}

/// The glyph a notation's script is shown by: the IPA's schwa, and the braille
/// cell of dot 1 and 2, as the courses' icons are (ADR-0041, ADR-0043).
const Map<String, String> notationGlyphs = <String, String>{
  'ipa': 'ə',
  'braille': '⠃',
};

/// The families the app names, in the order the Add a language page lists
/// them; a language with none, or an unknown one, goes last there and shows
/// no family tag in its details (#698).
const List<String> languageFamilies = <String>[
  'indo_aryan',
  'dravidian',
  'tibeto_burman',
  'austroasiatic',
  'germanic',
  'romance',
  'sinitic',
  'koreanic',
  'japonic',
  'constructed',
  'slavic',
  'hellenic',
  'italic',
  'celtic',
  'uralic',
  'turkic',
  'afroasiatic',
  'austronesian',
  'kra_dai',
  'niger_congo',
  'quechuan',
  'indo_european',
  'isolate',
  'sign',
];

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
  if (notationGlyphs[script] case final mark?) return mark;
  final sample = scriptSamples[script]?.text;
  final text = sample == null || sample.isEmpty ? name : sample;
  return text.isEmpty ? '' : text.characters.first;
}
