import '../models/card.dart';
import '../models/drill_mode.dart';
import 'question_type.dart';
import 'session_queue.dart';

/// How hard a new item is to learn, by the item itself (ADR-0024). A lesson
/// teaches its items easy first; no quota of each (ADR-0045).
enum Difficulty {
  easy,
  medium,
  hard;

  /// Hard: a card that is rearranged ([Card.rearranges]: three words or
  /// more, or a phrase of two), a phrase, or a grammar cell.
  /// Medium: two words, or one of seven letters or more, counted in its
  /// reading where it has one, so that scripts compare alike. Easy: the
  /// rest.
  static Difficulty of(Card card) {
    final words = card.wordCount;
    if (card.rearranges || card.pos == 'phrase' || card.isGrammarCell) {
      return hard;
    }
    final letters = _letter.allMatches(card.reading ?? card.target).length;
    return words == 2 || letters >= 7 ? medium : easy;
  }
}

/// The most new items a lesson takes: nine, as a lesson always held at most.
const int lessonMaxNew = 9;

/// The fewest new items a lesson takes, however many are still in progress,
/// so that a lesson is never only reviews.
const int lessonMinNew = 2;

/// The most new cells of a rules table a lesson takes (owner, 2026-10-16:
/// "3 per lesson").
const int ruleCellsPerLesson = 3;

/// How many new items a lesson takes when [inProgress] words and rules have
/// been taught and are not known yet (owner, 2026-10-18: "Fewer, by the
/// mastery bar"): [lessonMaxNew] less those in progress, never fewer than
/// [lessonMinNew]. There is no fixed quota of each difficulty.
int lessonRoom(int inProgress) =>
    (lessonMaxNew - inProgress).clamp(lessonMinNew, lessonMaxNew);

/// The new items of one lesson, from [cards] in the order of the path: the
/// next [room] of them, at most [ruleCells] of them cells of a rules table,
/// each card once. [cards] are the ones a lesson may teach now, the closed
/// sentences and the cells of unknown words already left out (`Unlocks`).
/// They are taught easy first, then medium, then hard ([Difficulty]), each
/// in the order given.
List<Card> lessonItems(
  Iterable<Card> cards, {
  int room = lessonMaxNew,
  int ruleCells = ruleCellsPerLesson,
}) {
  final seen = <String>{};
  final taken = <Card>[];
  var cells = 0;
  for (final card in cards) {
    if (taken.length >= room) break;
    if (!seen.add(card.id)) continue;
    if (card.rule != null) {
      if (cells >= ruleCells) continue;
      cells++;
    }
    taken.add(card);
  }
  return <Card>[
    for (final difficulty in Difficulty.values)
      ...taken.where((c) => Difficulty.of(c) == difficulty),
  ];
}

/// One way to ask a card in a lesson: the mode it records, and how.
typedef LessonQuestion = ({DrillMode mode, Ask ask});

/// The skills a lesson asks of a card of each [Difficulty], best first: how
/// hard it is decides the order, never what kind of card it is.
const Map<Difficulty, List<DrillMode>> _lessonSkills =
    <Difficulty, List<DrillMode>>{
      Difficulty.easy: <DrillMode>[
        DrillMode.recognition,
        DrillMode.speaking,
        DrillMode.listening,
        DrillMode.production,
      ],
      Difficulty.medium: <DrillMode>[
        DrillMode.listening,
        DrillMode.recognition,
        DrillMode.production,
        DrillMode.speaking,
      ],
      Difficulty.hard: <DrillMode>[
        DrillMode.production,
        DrillMode.speaking,
        DrillMode.listening,
        DrillMode.recognition,
      ],
    };

/// The questions a lesson can ask [card], best first (ADR-0024): the first
/// it can is its check, straight after it is taught, and the next in
/// another mode its question in the exercise.
///
/// Each is the first type of the registry ([lessonTypeFor]) that the card's
/// data makes eligible for the skill; a skill no type claims is asked its
/// own way ([Ask.own]). A grammar cell (DECK-FORMAT.md, Rules decks) is
/// understood before it is produced, each where its row, or its [siblings],
/// have the options; with none, it is typed. A card with [siblings] is asked
/// its grammar skills after the word's own.
///
/// A card of a language that is not [typed], as the IPA's, is produced by
/// choosing the word, whatever its difficulty: nothing is typed. In a typed
/// language only a hard card is typed; an easier one is chosen first.
List<LessonQuestion> lessonQuestions(
  Card card, {
  bool typed = true,
  List<Card> siblings = const <Card>[],
}) {
  final forms = card.rule == null ? siblings : const <Card>[];
  if (card.isGrammarCell) {
    return grammarLessonQuestions(card, siblings: forms);
  }
  final difficulty = Difficulty.of(card);
  Ask askFor(DrillMode skill) {
    // A medium card's recognition is matched with others, where it can be.
    final grouped =
        difficulty == Difficulty.medium && skill == DrillMode.recognition;
    final type =
        (grouped ? lessonTypeFor(card, skill, grouped: true) : null) ??
        lessonTypeFor(
          card,
          skill,
          typed: difficulty == Difficulty.hard && typed,
        );
    return type?.ask ?? Ask.own;
  }

  return <LessonQuestion>[
    for (final skill in _lessonSkills[difficulty]!)
      (mode: skill, ask: askFor(skill)),
    ...grammarLessonQuestions(card, siblings: forms, typedFallback: false),
  ];
}

/// A lesson of [cards], as [lessonItems] picks them (ADR-0024, ADR-0045): each card
/// taught, then checked at once; then the exercise, each card asked once
/// more in another mode, in a mixed order, the ones to be matched together
/// in pairs.
///
/// [modesOf] says which modes a card can be drilled in now, and [canChoose]
/// whether a choice question about it has enough options; one that has not
/// is asked its mode's own way. A card no question can be asked of is left
/// out, and one with a single mode is not in the exercise.
///
/// A card [straightToQuestion] says so of has no teaching card: a rules
/// table's cell a set card taught (owner, 2026-10-16, #515: "Straight to
/// question"). It is checked at once all the same.
///
/// A card [typed] says is not typed is never asked for a typed answer: its
/// production is chosen. [siblingsOf] gives a card's other forms by its base
/// ([formSiblings]), which a lesson asks as the review does.
List<SessionItem> lessonPlan(
  List<Card> cards, {
  required Set<DrillMode> Function(Card card) modesOf,
  required bool Function(Card card, Ask ask) canChoose,
  bool Function(Card card)? straightToQuestion,
  bool Function(Card card)? typed,
  List<Card> Function(Card card)? siblingsOf,
}) {
  final taught = <SessionItem>[];
  final exercise = <Difficulty, List<SessionItem>>{
    for (final d in Difficulty.values) d: <SessionItem>[],
  };
  for (final card in cards) {
    final modes = modesOf(card);
    final questions = <LessonQuestion>[
      for (final q in lessonQuestions(
        card,
        typed: typed?.call(card) ?? true,
        siblings: siblingsOf?.call(card) ?? const <Card>[],
      ))
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
    if (!(straightToQuestion?.call(card) ?? false)) {
      taught.add(
        SessionItem(card: card, mode: check.mode, state: null, ask: Ask.teach),
      );
    }
    taught.add(asked(check.mode, checkAsk));
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

/// How many cards [items], a lesson, teaches: those it shows a teaching card
/// for, the members its set cards taught that go straight to their question
/// (#515), and the cells of a rules table, which a lesson asks straight away
/// after the rule card (#417).
int lessonCardCount(List<SessionItem> items) => <String>{
  for (final item in items)
    if (item.ask == Ask.teach) item.card.id,
  for (final item in items) ...?item.setPart?.newIds,
  for (final item in items)
    if (item.card.rule != null && item.state == null && !item.ask.onlyShows)
      item.card.id,
}.length;
