/// The ids of a private language package (#1017, Plan-Private-Languages):
/// every package, deck and card id starts with `fnpd-<code>-`, so that a
/// private file can never reach a built-in id. Pure Dart, no Flutter.
library;

/// What every private id starts with.
const String privateIdMarker = 'fnpd-';

/// A language code in a private id: two or three lowercase letters.
final RegExp _codePattern = RegExp(r'^[a-z]{2,3}$');

/// The private-use codes `qaa` to `qtz` (ISO 639-3), which are never an
/// official language, so no built-in course can clash with them later.
final RegExp _localUseCode = RegExp(r'^q[a-t][a-z]$');

/// The codes in `qaa` to `qtz` that the app's own languages already use
/// (assets/languages.yaml): a package may not take them. A test keeps this
/// list equal to the q-codes of that file.
const Set<String> builtInPrivateUseCodes = <String>{
  'qap',
  'qbe',
  'qdo',
  'qgh',
  'qgk',
  'qhv',
  'qya',
};

/// Whether [id] starts with `fnpd-`.
bool isPrivateId(String id) => id.startsWith(privateIdMarker);

/// Whether [code] is a code a package may use: two or three lowercase
/// letters, and when it is three letters starting with `q`, one of `qaa` to
/// `qtz` that no built-in language uses.
bool isPrivateCode(String code) {
  if (!_codePattern.hasMatch(code)) return false;
  if (!code.startsWith('q') || code.length != 3) return true;
  return _localUseCode.hasMatch(code) && !builtInPrivateUseCodes.contains(code);
}

/// The package id for language [code]: `fnpd-qaa`.
String packageIdFor(String code) => '$privateIdMarker$code';

/// Whether [id] is a private id of language [code]: `fnpd-`, the code, a
/// hyphen and a name after it.
bool hasPrivatePrefix(String id, String code) {
  final prefix = '${packageIdFor(code)}-';
  return _codePattern.hasMatch(code) &&
      id.length > prefix.length &&
      id.startsWith(prefix);
}

/// The language code a private [id] names, `qaa` for `fnpd-qaa-0001`, or
/// null when [id] is not a private id or names no code.
String? packageCode(String id) {
  if (!isPrivateId(id)) return null;
  final rest = id.substring(privateIdMarker.length);
  final dash = rest.indexOf('-');
  if (dash < 0) return null;
  final code = rest.substring(0, dash);
  return _codePattern.hasMatch(code) ? code : null;
}

/// What an id of language [code] starts with, before the hyphen that ends
/// it: `te` for a built-in id, `fnpd-te` when [id] is private. A core id's
/// name is what follows it.
String idLanguagePrefix(String id, String code) =>
    isPrivateId(id) ? packageIdFor(code) : code;

/// The language an id belongs to: the code a private id names, else the id's
/// first segment, which is how a built-in id names its language.
String languageOfId(String id) => packageCode(id) ?? id.split('-').first;
