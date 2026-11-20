import 'ipa_course.dart';

/// The code of the English Braille course's language block (ADR-0043). It
/// is in ISO 639's range for local use, `qaa`–`qtz`, so that it can never
/// be a real language's code.
const String brailleLanguageCode = 'qbe';

/// The code of the Morse code course's language block, also in the local-use
/// range (`qmo`). Morse writes letters of any language, so its ISO 639-3 code
/// is `zxx`, as the IPA's is.
const String morseLanguageCode = 'qmo';

/// The codes of the notations taught like languages: the IPA (ADR-0041)
/// and English Braille (ADR-0043). Each is learned only when chosen and
/// placed by nothing.
const Set<String> notationLanguageCodes = <String>{
  ipaLanguageCode,
  brailleLanguageCode,
  morseLanguageCode,
};

/// Whether [code] is a notation's, such as the IPA's: see
/// [notationLanguageCodes].
bool isNotationCode(String code) => notationLanguageCodes.contains(code);

/// The scripts of the notations: what a language block names them by, and
/// what `LanguageInfo.isNotation` reads.
const Set<String> notationScripts = <String>{'ipa', 'braille', 'morse'};
