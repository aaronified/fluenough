/// Rule-based equality for English meaning answers (owner, 2026-10-19:
/// "This kind of grammar needs to be rule based").
///
/// Used for the learner's native-language answer ("Type what it means"),
/// never for target-language answers. Pure Dart; no Flutter imports.
///
/// Two meanings are equal when their [meaningKey]s are equal, and an expected
/// text is accepted through any of its [meaningKeys]. The rules, applied to
/// both sides:
///
/// 1. Case, outer and repeated whitespace, and punctuation are ignored.
/// 2. Contractions equal their expansions (there's / there is, can't /
///    cannot / can not, let's / let us), with straight or curly apostrophes.
/// 3. A bracketed qualifier is optional: "How are you? (respectful)" accepts
///    "how are you".
/// 4. Each `;`-separated meaning of the expected text is accepted alone.
/// 5. A leading "to " on a verb meaning is optional: "to say" = "say".
/// 6. ok, okay and o.k. are the same word.
/// 7. The word "please" is optional anywhere: "please excuse me" = "excuse me".
///
/// What no rule does: paraphrase. "Please say that again." is not "can you
/// repeat that"; that needs an `altNative` on the deck card.
library;

const Map<String, String> _irregular = {
  "can't": 'can not',
  'cannot': 'can not',
  "won't": 'will not',
  "shan't": 'shall not',
  "let's": 'let us',
  "i'm": 'i am',
  "ain't": 'is not',
};

const Map<String, String> _suffixes = {
  "'s": ' is',
  "'re": ' are',
  "'ll": ' will',
  "'ve": ' have',
  "'d": ' would',
};

final RegExp _brackets = RegExp(r'\([^)]*\)|\[[^\]]*\]');
final RegExp _punctuation = RegExp(r'''[.,!?;:"'()\[\]]''');
final RegExp _spaces = RegExp(r'\s+');

String _expandWord(String word) {
  final irregular = _irregular[word];
  if (irregular != null) return irregular;
  if (word.endsWith("n't") && word.length > 3) {
    return '${word.substring(0, word.length - 3)} not';
  }
  for (final entry in _suffixes.entries) {
    if (word.endsWith(entry.key) && word.length > entry.key.length) {
      return '${word.substring(0, word.length - entry.key.length)}'
          '${entry.value}';
    }
  }
  return word;
}

/// The comparison form of one meaning: rules 1, 2, 3, 5, 6 and 7. `;` is
/// handled by [meaningKeys]; here it is just punctuation.
String meaningKey(String meaning) {
  var text = meaning
      .toLowerCase()
      .replaceAll(RegExp('[‘’ʼ`´]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll(_brackets, ' ')
      // "o.k." is the word ok, before its stops become spaces.
      .replaceAll(RegExp(r'\bo\.k\b\.?'), 'ok');
  text = text.split(_spaces).map(_expandWord).join(' ');
  text = text.replaceAll(_punctuation, ' ').trim();
  final words = text
      .split(_spaces)
      .where((w) => w.isNotEmpty)
      .map((w) => w == 'okay' ? 'ok' : w)
      .toList();
  // Rule 7, unless it is all there is.
  if (words.length > 1) words.removeWhere((w) => w == 'please');
  if (words.length > 1 && words.first == 'to') words.removeAt(0);
  return words.join(' ');
}

/// Every form an expected [meaning] accepts: each `;`-separated part, with
/// bracketed qualifiers dropped. Never contains an empty key.
Set<String> meaningKeys(String meaning) {
  final unbracketed = meaning.replaceAll(_brackets, ' ');
  return {
    for (final part in unbracketed.split(';'))
      if (meaningKey(part).isNotEmpty) meaningKey(part),
  };
}

/// Whether [given] is right for [expected] outright under the rules above.
bool meaningsEqual(String given, String expected) {
  final key = meaningKey(given);
  return key.isNotEmpty && meaningKeys(expected).contains(key);
}

/// Whether [meaning] is written with a leading "to" and a word after it: a
/// verb, the one kind a typed "to" is free on for the synonym sets (ADR-0050).
bool meaningStartsWithTo(String meaning) {
  final words = meaning
      .replaceAll(_brackets, ' ')
      .toLowerCase()
      .split(_spaces)
      .where((w) => w.isNotEmpty)
      .toList();
  return words.length > 1 && words.first == 'to';
}

/// The forms an expected [meaning] accepts, as [meaningKeys] gives them, each
/// with whether that `;` part is written with a leading "to".
List<({String key, bool verb})> meaningParts(String meaning) {
  final unbracketed = meaning.replaceAll(_brackets, ' ');
  return [
    for (final part in unbracketed.split(';'))
      if (meaningKey(part).isNotEmpty)
        (key: meaningKey(part), verb: meaningStartsWithTo(part)),
  ];
}
