import 'deck.dart';

/// How a language spells a number from the words its number decks teach
/// (#54, ADR-0011). A language is data: each gives its own rules file,
/// `decks/<code>/<code>-numbers.yaml`, and no language is spelled in code.
///
/// Every spelling is a list, the usual one first and the other accepted
/// ones after it: Bengali 2,000 is দু হাজার, and দুই হাজার is right too.
class NumberRules {
  const NumberRules({
    required this.id,
    required this.language,
    required this.words,
    required this.hundreds,
    required this.thousands,
    this.hundredsBefore = const <int, List<String>>{},
    this.thousandsBefore = const <int, List<String>>{},
    this.tensAndUnits = false,
    this.join = ' ',
  });

  /// `<code>-numbers`.
  final String id;

  final LanguageInfo language;

  /// The numbers from 1 to 99 the decks teach a word for.
  final Map<int, List<String>> words;

  /// Whether a number from 21 to 99 with no word of its own is its tens
  /// word, [join] and its units word, as Telugu's ఇరవై ఆరు is 26. When
  /// false, only the numbers in [words] can end a number.
  final bool tensAndUnits;

  /// 100 to 900 on their own, keyed 1 to 9.
  final Map<int, List<String>> hundreds;

  /// 100 to 900 with more after them, where the language changes the word,
  /// as Telugu's రెండు వందలు becomes రెండు వందల in 250. [hundreds] where empty.
  final Map<int, List<String>> hundredsBefore;

  /// 1,000 to 9,000 on their own, keyed 1 to 9.
  final Map<int, List<String>> thousands;

  /// 1,000 to 9,000 with more after them. [thousands] where empty.
  final Map<int, List<String>> thousandsBefore;

  /// What goes between the parts of a number.
  final String join;
}
