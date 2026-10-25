/// The family name the downloaded font of [script] is loaded under
/// (ADR-0042): one per script, such as `FluenoughScript-telugu`, never the
/// Noto font's own name, so that a text names the script it needs and not
/// the file that draws it.
String scriptFontFamily(String script) => 'FluenoughScript-$script';

/// The family of braille's shadow-dot font (#835, ADR-0043), which ships
/// inside the app rather than downloading: every braille cell is drawn with
/// all its dot positions, the raised dots solid and the unraised ones faint
/// rings, so that a lone dot's column and row can be read. Braille text is
/// drawn in it everywhere, and never in the phone's own font.
const String brailleFontFamily = 'FluenoughBraille';
