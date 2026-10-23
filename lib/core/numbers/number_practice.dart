import 'dart:math';

import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/number_rules.dart';
import '../scheduling/session_queue.dart';
import 'number_speller.dart';

/// A generated number as an ordinary card with data: the words as its target,
/// the digits as its meaning (#54, ADR-0011). It is [Card.practiceOnly], so
/// nothing drilled from it is recorded and its id is never written to the
/// review log (rule 1 does not reach it); it is heard as its form
/// (`hears: form`) and typed as the digits ([Card.heardAs]). None of this is
/// a deck key: the card is generated, never in a deck file.
Card numberCard({
  required int number,
  required List<String> spellings,
  required String rulesId,
  required String deckId,
}) => Card(
  id: '$rulesId-$number',
  deckId: deckId,
  target: spellings.first,
  altTarget: spellings.sublist(1),
  native: '$number',
  hears: 'form',
  heardAs: '$number',
  practiceOnly: true,
);

/// The drills a number is practised in, in this order.
const List<DrillMode> numberPracticeModes = <DrillMode>[
  DrillMode.recognition,
  DrillMode.production,
  DrillMode.listening,
];

/// [count] different numbers from [min] to [max] that [rules] can spell,
/// picked by [random], each drilled in one of [modes] in turn.
///
/// [deckId] is the number deck the practice hangs off, which gives the
/// session its language. Only [numberPracticeModes] are used; the result is
/// empty when [modes] has none of them.
List<SessionItem> numberPractice(
  NumberRules rules, {
  required String deckId,
  required Set<DrillMode> modes,
  required Random random,
  int count = 10,
  int min = 1000,
  int max = 9999,
}) {
  final drills = <DrillMode>[
    for (final mode in numberPracticeModes)
      if (modes.contains(mode)) mode,
  ];
  if (drills.isEmpty) return const <SessionItem>[];
  final numbers = spellableNumbers(rules, min: min, max: max)..shuffle(random);
  return <SessionItem>[
    for (final (i, n) in numbers.take(count).indexed)
      SessionItem(
        card: numberCard(
          number: n,
          spellings: spellNumber(rules, n),
          rulesId: rules.id,
          deckId: deckId,
        ),
        mode: drills[i % drills.length],
        state: null,
      ),
  ];
}
