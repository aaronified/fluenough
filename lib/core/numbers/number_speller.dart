import 'dart:math';

import '../models/number_rules.dart';

/// Every accepted spelling of [n], from 1 to 9,999, the usual one first. Empty
/// when [rules] cannot spell it from the words the decks teach, as Hindi
/// cannot spell 2026, whose 26 is a word of its own the beta does not teach.
List<String> spellNumber(NumberRules rules, int n) {
  if (n < 1 || n > 9999) return const <String>[];
  final thousands = n ~/ 1000;
  final hundreds = n ~/ 100 % 10;
  final rest = n % 100;
  final parts = <List<String>>[];
  if (thousands > 0) {
    final table = hundreds > 0 || rest > 0
        ? _orElse(rules.thousandsBefore, rules.thousands)
        : rules.thousands;
    final part = table[thousands];
    if (part == null) return const <String>[];
    parts.add(part);
  }
  if (hundreds > 0) {
    final table = rest > 0
        ? _orElse(rules.hundredsBefore, rules.hundreds)
        : rules.hundreds;
    final part = table[hundreds];
    if (part == null) return const <String>[];
    parts.add(part);
  }
  if (rest > 0) {
    final part = _belowHundred(rules, rest);
    if (part == null) return const <String>[];
    parts.add(part);
  }
  return _joined(parts, rules.join);
}

/// The numbers from [min] to [max] that [rules] can spell, in order.
List<int> spellableNumbers(
  NumberRules rules, {
  int min = 1000,
  int max = 9999,
}) => <int>[
  for (var n = min; n <= max; n++)
    if (spellNumber(rules, n).isNotEmpty) n,
];

/// A number from [min] to [max] that [rules] can spell, picked by [random].
/// Null if there is none.
int? randomNumber(
  NumberRules rules,
  Random random, {
  int min = 1000,
  int max = 9999,
}) {
  final pool = spellableNumbers(rules, min: min, max: max);
  return pool.isEmpty ? null : pool[random.nextInt(pool.length)];
}

List<String>? _belowHundred(NumberRules rules, int n) {
  final word = rules.words[n];
  if (word != null) return word;
  if (!rules.tensAndUnits || n < 21) return null;
  final tens = rules.words[n - n % 10];
  final units = rules.words[n % 10];
  if (tens == null || units == null) return null;
  return _joined(<List<String>>[tens, units], rules.join);
}

Map<int, List<String>> _orElse(
  Map<int, List<String>> table,
  Map<int, List<String>> fallback,
) => table.isEmpty ? fallback : table;

/// Every combination of [parts], the usual spellings first, with no repeats.
List<String> _joined(List<List<String>> parts, String join) {
  var spellings = <String>[''];
  for (final part in parts) {
    spellings = <String>[
      for (final head in spellings)
        for (final word in part) head.isEmpty ? word : '$head$join$word',
    ];
  }
  return spellings.toSet().toList();
}
