/// The family name the downloaded font of [script] is loaded under
/// (ADR-0042): one per script, such as `FluenoughScript-telugu`, never the
/// Noto font's own name, so that a text names the script it needs and not
/// the file that draws it.
String scriptFontFamily(String script) => 'FluenoughScript-$script';

/// The scripts a language draws in another font than the script's own
/// (owner, 2026-11-02): Persian and Pashto are set in Naskh, while the
/// `perso_arabic` font stays Nastaliq for Hindustani's Urdu and the others.
/// The key is `<language>:<script>`, the value the font's script key, as the
/// deck index lists it (`LANGUAGE_FONTS` in tools/deck_index.py).
const Map<String, String> languageFontScripts = <String, String>{
  'fa:perso_arabic': 'perso_arabic_naskh',
  'ps:perso_arabic': 'perso_arabic_naskh',
};

/// The font key to draw [language]'s text in [script] with: [script] itself
/// unless [languageFontScripts] names another.
String fontScriptFor(String language, String script) =>
    languageFontScripts['$language:$script'] ?? script;

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
