/// What the font check shows and remembers (#611, ADR-0042): a sample of a
/// script, drawn in the phone's own font, that the learner says they can or
/// cannot read, and what they said.
library;

/// What a learner said about a script on their phone.
enum FontChoice {
  /// "Yes, I can read it": the phone's own font draws the script.
  phone,

  /// "No, it shows boxes": the script's font is downloaded.
  download,

  /// "No, it still shows boxes", after the download: not even the
  /// downloaded font draws the script, and the course goes on with
  /// readings.
  boxes;

  /// The name [FontChoice.parse] reads back.
  String get stored => name;

  /// The choice stored as [text], or null for anything else.
  static FontChoice? parse(String? text) {
    for (final choice in values) {
      if (choice.name == text) return choice;
    }
    return null;
  }
}

/// Where one script stands, as Settings lists it.
enum FontCheckState { notChecked, phoneFont, downloaded, downloading, boxes }

/// What [fontCheckState] needs to know of one script.
FontCheckState fontCheckState({
  required FontChoice? choice,
  required bool fontOnPhone,
  required bool downloading,
}) {
  if (downloading) return FontCheckState.downloading;
  if (choice == FontChoice.boxes) return FontCheckState.boxes;
  if (choice == FontChoice.phone) return FontCheckState.phoneFont;
  // A font a learner never asked for, brought by an earlier version of the
  // app (ADR-0042), is drawn with and counts as downloaded. A download that
  // failed leaves no font, and the script unchecked.
  return fontOnPhone ? FontCheckState.downloaded : FontCheckState.notChecked;
}

/// A line to draw in a script: [text] in it, its [reading] and a key for
/// its meaning, which the interface words in the learner's language.
class ScriptSample {
  const ScriptSample(this.text, this.reading, this.meaning);

  final String text;
  final String reading;

  /// `hello`, `thanks`, `house`, `name`, `god` or `vowels`.
  final String meaning;
}

/// A sample for each script that has a font to download (`FONTS` in
/// `tools/deck_index.py`). Each reading is the one the decks give, based on
/// ISO 15919 where it is an Indic script.
const Map<String, ScriptSample> scriptSamples = <String, ScriptSample>{
  'devanagari': ScriptSample('नमस्ते', 'namastē', 'hello'),
  'perso_arabic': ScriptSample('شکریہ', 'śukriyā', 'thanks'),
  'bengali': ScriptSample('ধন্যবাদ', 'dhan’yabād', 'thanks'),
  'telugu': ScriptSample('ధన్యవాదాలు', 'dhanyavādālu', 'thanks'),
  'kannada': ScriptSample('ಧನ್ಯವಾದ', 'dhanyavāda', 'thanks'),
  'gujarati': ScriptSample('આભાર', 'ābhār', 'thanks'),
  'gurmukhi': ScriptSample('ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ', 'sati srī akāl', 'hello'),
  'odia': ScriptSample('ଧନ୍ୟବାଦ', 'dhan’yabāda', 'thanks'),
  'tamil': ScriptSample('நன்றி', 'naṉṟi', 'thanks'),
  'malayalam': ScriptSample('നന്ദി', 'nanni', 'thanks'),
  'egyptian_hieroglyphs': ScriptSample('𓂋𓈖', 'rn', 'name'),
  'cuneiform': ScriptSample('𒀭', 'an, dingir', 'god'),
  'linear_b': ScriptSample('𐀀𐀁𐀂𐀃𐀄', 'a e i o u', 'vowels'),
  'han_simplified': ScriptSample('你好', 'nǐ hǎo', 'hello'),
  'han_traditional': ScriptSample('謝謝', 'xièxie', 'thanks'),
  'han': ScriptSample('今日は', 'konnichiwa', 'hello'),
  'kana': ScriptSample('ありがとう', 'arigatō', 'thanks'),
  'hangul': ScriptSample('감사합니다', 'gamsahamnida', 'thanks'),
};
