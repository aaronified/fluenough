import '../models/card.dart';
import '../models/drill_mode.dart';
import 'session_queue.dart';

/// How hard a new item is to learn, by the item itself (ADR-0024). A lesson
/// teaches some of each, easy first.
enum Difficulty {
  easy,
  medium,
  hard;

  /// Hard: a phrase, a sentence of three words or more, or a grammar cell.
  /// Medium: two words, or one of seven letters or more, counted in its
  /// reading where it has one, so that scripts compare alike. Easy: the
  /// rest.
  static Difficulty of(Card card) {
    final words = wordsOf(card.target).length;
    if (card.pos == 'phrase' ||
        words >= 3 ||
        card.modes.contains(DrillMode.grammar)) {
      return hard;
    }
    final letters = _letter.allMatches(card.reading ?? card.target).length;
    return words == 2 || letters >= 7 ? medium : easy;
  }
}

/// The new items of one lesson, from [cards] in the order given: the first
/// [each] of each [Difficulty], and, when a difficulty has fewer, the next
/// cards of the others in order, up to `3 × each` in all. Easy ones first,
/// then medium, then hard, each in the order given.
///
/// A card given twice, as in two decks of a unit, is taken once.
List<Card> lessonItems(Iterable<Card> cards, {int each = 3}) {
  final seen = <String>{};
  final all = <Card>[
    for (final card in cards)
      if (seen.add(card.id)) card,
  ];
  final taken = <Card>{};
  final counts = <Difficulty, int>{};
  for (final card in all) {
    final difficulty = Difficulty.of(card);
    if ((counts[difficulty] ?? 0) < each) {
      taken.add(card);
      counts[difficulty] = (counts[difficulty] ?? 0) + 1;
    }
  }
  final size = each * Difficulty.values.length;
  for (final card in all) {
    if (taken.length >= size) break;
    taken.add(card);
  }
  return <Card>[
    for (final difficulty in Difficulty.values)
      ...all.where((c) => taken.contains(c) && Difficulty.of(c) == difficulty),
  ];
}

/// One way to ask a card in a lesson: the mode it records, and how.
typedef LessonQuestion = ({DrillMode mode, Ask ask});

/// The questions a lesson can ask [card], best first (ADR-0024): the first
/// it can is its check, straight after it is taught, and the next in
/// another mode its question in the exercise.
List<LessonQuestion> lessonQuestions(Card card) {
  if (card.modes.contains(DrillMode.grammar)) {
    return const <LessonQuestion>[(mode: DrillMode.grammar, ask: Ask.own)];
  }
  return switch (Difficulty.of(card)) {
    Difficulty.easy => const <LessonQuestion>[
      (mode: DrillMode.recognition, ask: Ask.chooseMeaning),
      (mode: DrillMode.speaking, ask: Ask.own),
      (mode: DrillMode.listening, ask: Ask.hearAndChoose),
      (mode: DrillMode.production, ask: Ask.chooseWord),
    ],
    Difficulty.medium => const <LessonQuestion>[
      (mode: DrillMode.listening, ask: Ask.hearAndChoose),
      (mode: DrillMode.recognition, ask: Ask.matchPairs),
      (mode: DrillMode.production, ask: Ask.chooseWord),
      (mode: DrillMode.speaking, ask: Ask.own),
    ],
    Difficulty.hard => <LessonQuestion>[
      (
        mode: DrillMode.production,
        ask: card.rearranges ? Ask.rearrange : Ask.own,
      ),
      (mode: DrillMode.speaking, ask: Ask.own),
      (mode: DrillMode.listening, ask: Ask.hearAndChoose),
      (mode: DrillMode.recognition, ask: Ask.chooseMeaning),
    ],
  };
}

/// A lesson of [cards], as [lessonItems] picks them (ADR-0024): each card
/// taught, then checked at once; then the exercise, each card asked once
/// more in another mode, in a mixed order, the ones to be matched together
/// in pairs.
///
/// [modesOf] says which modes a card can be drilled in now, and [canChoose]
/// whether a choice question about it has enough options; one that has not
/// is asked its mode's own way. A card no question can be asked of is left
/// out, and one with a single mode is not in the exercise.
List<SessionItem> lessonPlan(
  List<Card> cards, {
  required Set<DrillMode> Function(Card card) modesOf,
  required bool Function(Card card, Ask ask) canChoose,
}) {
  final taught = <SessionItem>[];
  final exercise = <Difficulty, List<SessionItem>>{
    for (final d in Difficulty.values) d: <SessionItem>[],
  };
  for (final card in cards) {
    final modes = modesOf(card);
    final questions = <LessonQuestion>[
      for (final q in lessonQuestions(card))
        if (modes.contains(q.mode)) q,
    ];
    if (questions.isEmpty) continue;
    SessionItem asked(DrillMode mode, Ask ask) => SessionItem(
      card: card,
      mode: mode,
      state: null,
      ask: ask.chooses && !canChoose(card, ask) ? Ask.own : ask,
    );
    // A check is asked of one card, so not by matching, unless that is
    // all there is, and then a match is chosen instead.
    final check = questions.firstWhere(
      (q) => q.ask != Ask.matchPairs,
      orElse: () => questions.first,
    );
    final checkAsk = check.ask == Ask.matchPairs
        ? Ask.chooseMeaning
        : check.ask;
    taught
      ..add(
        SessionItem(card: card, mode: check.mode, state: null, ask: Ask.teach),
      )
      ..add(asked(check.mode, checkAsk));
    for (final q in questions) {
      if (q.mode == check.mode) continue;
      exercise[Difficulty.of(card)]!.add(
        q.ask == Ask.matchPairs
            ? SessionItem(card: card, mode: q.mode, state: null, ask: q.ask)
            : asked(q.mode, q.ask),
      );
      break;
    }
  }
  final lists = <List<SessionItem>>[
    for (final d in <Difficulty>[
      Difficulty.easy,
      Difficulty.medium,
      Difficulty.hard,
    ])
      _matched(exercise[d]!, canChoose),
  ];
  // Mixed: one of each difficulty in turn.
  final mixed = <SessionItem>[];
  for (var i = 0; lists.any((list) => i < list.length); i++) {
    for (final list in lists) {
      if (i < list.length) mixed.add(list[i]);
    }
  }
  return <SessionItem>[...taught, ...mixed];
}

/// [items] with those to be matched in pairs put together, in groups of up
/// to [matchSize] at the place of the first. Fewer than two, or a group in
/// which two share a meaning or a target, are asked by multiple choice
/// instead.
List<SessionItem> _matched(
  List<SessionItem> items,
  bool Function(Card card, Ask ask) canChoose,
) {
  final matching = <SessionItem>[
    for (final item in items)
      if (item.ask == Ask.matchPairs) item,
  ];
  if (matching.isEmpty) return items;
  final groups = (matching.length / matchSize).ceil();
  final size = (matching.length / groups).ceil();
  final first = <SessionItem, SessionItem>{};
  final taken = <SessionItem>{};
  for (var start = 0; start < matching.length; start += size) {
    final group = matching.skip(start).take(size).toList();
    final natives = <String>{for (final g in group) g.card.native};
    final targets = <String>{for (final g in group) g.card.target};
    if (group.length < 2 ||
        natives.length < group.length ||
        targets.length < group.length) {
      continue;
    }
    first[group.first] = group.first.askedAs(Ask.matchPairs, group: group);
    taken.addAll(group.skip(1));
  }
  SessionItem chosen(SessionItem item) => item.askedAs(
    canChoose(item.card, Ask.chooseMeaning) ? Ask.chooseMeaning : Ask.own,
  );
  return <SessionItem>[
    for (final item in items)
      if (!taken.contains(item))
        first[item] ?? (item.ask == Ask.matchPairs ? chosen(item) : item),
  ];
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
