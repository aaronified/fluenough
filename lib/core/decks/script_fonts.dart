/// The family name the downloaded font of [script] is loaded under
/// (ADR-0042): one per script, such as `FluenoughScript-telugu`, never the
/// Noto font's own name, so that a text names the script it needs and not
/// the file that draws it.
String scriptFontFamily(String script) => 'FluenoughScript-$script';
