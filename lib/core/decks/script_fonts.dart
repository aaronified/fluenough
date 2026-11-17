/// The family name the downloaded font of [script] is loaded under
/// (ADR-0042): one per script, such as `FluenoughScript-telugu`, never the
/// Noto font's own name, so that a text names the script it needs and not
/// the file that draws it.
String scriptFontFamily(String script) => 'FluenoughScript-$script';

/// The scripts a language draws in another font than the script's own
/// (owner, 2026-11-02): Persian, Pashto, Sindhi and Kashmiri are set in Naskh,
/// which has the Sindhi kaf (U+06AA) that Nastaliq lacks, while the
/// `perso_arabic` font stays Nastaliq for Hindustani's Urdu and the others.
/// The key is `<language>:<script>`, the value the font's script key, as the
/// deck index lists it (`LANGUAGE_FONTS` in tools/deck_index.py).
const Map<String, String> languageFontScripts = <String, String>{
  'fa:perso_arabic': 'perso_arabic_naskh',
  'ps:perso_arabic': 'perso_arabic_naskh',
  'sd:perso_arabic': 'perso_arabic_naskh',
  'ks:perso_arabic': 'perso_arabic_naskh',
};

/// The scripts that have no font file of their own and are drawn in
/// another script's (`FONT_ALIASES` in tools/deck_index.py, which a test
/// keeps equal): Arabic is set in Naskh, Punjabi's Shahmukhi in the Urdu
/// Nastaliq, and the IPA in the Latin font.
const Map<String, String> scriptFontAliases = <String, String>{
  'arabic': 'perso_arabic_naskh',
  'shahmukhi': 'perso_arabic',
  'ipa': 'latin',
};

/// The scripts whose fonts are the content fonts (owner, 2026-11-16: "I
/// don't want to depend on system fonts for content"): one Noto Sans subset
/// each, shared by every language in the script. They always download with
/// a course and are always drawn with, never asked about, and they are the
/// fallback behind every other script's font and the interface's, so that
/// no deck character falls to the phone's font (`CONTENT_FONTS` in
/// tools/deck_index.py).
const List<String> contentFontScripts = <String>['latin', 'cyrillic', 'greek'];

/// The scripts written in the Unicode private-use area, which no phone has a
/// font for: sitelen pona's (U+F1900 to U+F19FF). Drawn before their font is
/// on the phone they are boxes, so text in them shows its other spelling, or a
/// mark, until the font is downloaded (ADR-0055).
const Set<String> privateUseScripts = <String>{'sitelen_pona'};

/// The font key to draw [language]'s text in [script] with: [script] itself
/// unless [languageFontScripts] names another, or it shares another's font
/// ([scriptFontAliases]).
String fontScriptFor(String language, String script) =>
    languageFontScripts['$language:$script'] ??
    scriptFontAliases[script] ??
    script;

/// The script a font key stands for: the one [fontScript] is a language's
/// font for, else [fontScript] itself (`perso_arabic_naskh` is the font of
/// `perso_arabic`).
String readingScriptOf(String fontScript) {
  for (final entry in languageFontScripts.entries) {
    if (entry.value == fontScript) return entry.key.split(':').last;
  }
  return fontScript;
}

/// The family of braille's shadow-dot font (#835, ADR-0043), which ships
/// inside the app rather than downloading: every braille cell is drawn with
/// all its dot positions, the raised dots solid and the unraised ones faint
/// rings, so that a lone dot's column and row can be read. Braille text is
/// drawn in it everywhere, and never in the phone's own font.
const String brailleFontFamily = 'FluenoughBraille';
