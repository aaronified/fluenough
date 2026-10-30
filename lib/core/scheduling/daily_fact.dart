import '../models/fact.dart';

/// Whether [fact] can be shown to a learner who speaks [spoken]: it is
/// written in one of their languages, and a contrast fact contrasts with
/// one of them (#53).
bool factIsFor(Fact fact, List<String> spoken) =>
    fact.text.keys.any(spoken.contains) &&
    (fact.contrast == null || spoken.contains(fact.contrast));

/// Whether [fact] names a card in [cardIds] (#546).
bool factNamesAny(Fact fact, Set<String> cardIds) =>
    fact.cards.any(cardIds.contains);

/// The facts of [facts] that name the card [cardId] and can be shown to a
/// learner who speaks [spoken], in the file's order (#546): what a card's
/// Facts section lists.
List<Fact> factsNamingCard(
  List<Fact> facts,
  String cardId, {
  required List<String> spoken,
}) => <Fact>[
  for (final fact in facts)
    if (fact.cards.contains(cardId) && factIsFor(fact, spoken)) fact,
];

/// Today's fact from [facts], for a learner who speaks [spoken], given when
/// each fact was last shown ([shownAt], by fact id). Null if none is for
/// them.
///
/// - A fact already shown today stays today's fact.
/// - Otherwise the first eligible fact never shown, in the file's order,
///   but one that names a card in [studied] comes first (#546).
/// - Once every eligible fact has been shown, the one shown longest ago:
///   the cycle starts again.
///
/// [studied] is the ids of the cards being studied: those with a schedule
/// state that is not new, so answered at least once in some skill.
Fact? factForToday(
  List<Fact> facts, {
  required List<String> spoken,
  required Map<String, DateTime> shownAt,
  required DateTime now,
  Set<String> studied = const <String>{},
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

  final unseen = <Fact>[
    for (final fact in eligible)
      if (!shownAt.containsKey(fact.id)) fact,
  ];
  if (unseen.isNotEmpty) {
    return unseen.firstWhere(
      (fact) => factNamesAny(fact, studied),
      orElse: () => unseen.first,
    );
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

/// The languages of [known] whose box is checked on the fact card's menu
/// (#926): [chosen] among them, or all of [known] while nothing was chosen
/// (null) or none of the choice is known any more. Never empty if [known]
/// is not.
Set<String> checkedFactLanguages(List<String> known, Set<String>? chosen) {
  final checked = <String>{
    for (final code in known)
      if (chosen == null || chosen.contains(code)) code,
  };
  return checked.isEmpty ? known.toSet() : checked;
}

/// The choice after a tap on [code]'s box: null (every known language,
/// which follows a language learned later) when all are checked. The last
/// checked language cannot be unchecked: the choice is returned as it is.
Set<String>? toggledFactLanguages(
  List<String> known,
  Set<String>? chosen,
  String code,
) {
  if (!known.contains(code)) return chosen;
  final checked = checkedFactLanguages(known, chosen);
  final next = checked.contains(code)
      ? (checked.length == 1 ? checked : (checked.toSet()..remove(code)))
      : (checked.toSet()..add(code));
  return next.length == known.length ? null : next;
}

/// [fact]'s text for the fact card (#926): in each checked language of
/// [known] that it is written in, in the order of [known]. A fact with no
/// text in a checked language leaves it out; if that leaves nothing, the
/// English text, and failing that the text in every known language.
List<({String code, String text})> shownFactTexts(
  Fact fact,
  List<String> known,
  Set<String>? chosen,
) {
  final checked = checkedFactLanguages(known, chosen);
  final texts = factTexts(fact, <String>[
    for (final code in known)
      if (checked.contains(code)) code,
  ]);
  if (texts.isNotEmpty) return texts;
  if (fact.text['en'] case final english?) {
    return <({String code, String text})>[(code: 'en', text: english)];
  }
  return factTexts(fact, known);
}
