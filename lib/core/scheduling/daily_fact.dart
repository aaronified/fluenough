import '../models/fact.dart';

/// Whether [fact] can be shown to a learner who speaks [spoken]: it is
/// written in one of their languages, and a contrast fact contrasts with
/// one of them (#53).
bool factIsFor(Fact fact, List<String> spoken) =>
    fact.text.keys.any(spoken.contains) &&
    (fact.contrast == null || spoken.contains(fact.contrast));

/// Today's fact from [facts], for a learner who speaks [spoken], given when
/// each fact was last shown ([shownAt], by fact id). Null if none is for
/// them.
///
/// - A fact already shown today stays today's fact.
/// - Otherwise the first eligible fact never shown, in the file's order.
/// - Once every eligible fact has been shown, the one shown longest ago:
///   the cycle starts again.
Fact? factForToday(
  List<Fact> facts, {
  required List<String> spoken,
  required Map<String, DateTime> shownAt,
  required DateTime now,
}) {
  final eligible = [
    for (final fact in facts)
      if (factIsFor(fact, spoken)) fact,
  ];
  if (eligible.isEmpty) return null;

  Fact? today;
  for (final fact in eligible) {
    final at = shownAt[fact.id];
    if (at != null && _sameDay(at, now)) {
      if (today == null || at.isAfter(shownAt[today.id]!)) today = fact;
    }
  }
  if (today != null) return today;

  for (final fact in eligible) {
    if (!shownAt.containsKey(fact.id)) return fact;
  }
  return eligible.reduce(
    (a, b) => shownAt[b.id]!.isBefore(shownAt[a.id]!) ? b : a,
  );
}

/// [fact]'s text in each of [spoken] it is written in, best known first.
List<({String code, String text})> factTexts(Fact fact, List<String> spoken) =>
    <({String code, String text})>[
      for (final code in spoken)
        if (fact.text[code] case final text?) (code: code, text: text),
    ];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
