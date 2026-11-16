import '../models/card.dart';
import '../models/drill_mode.dart';
import 'learn_sequence.dart';
import 'question_type.dart';
import 'session_queue.dart';

/// How hard a new item is to learn, by the item itself (ADR-0024). A lesson
/// teaches its items easy first; no quota of each (ADR-0046).
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

/// A lesson of [cards], as [lessonItems] picks them (ADR-0024, ADR-0046; owner,
/// 2026-11-16): each card is a learn attempt, laid out by [learnSequence]:
/// shown, asked at once, then asked again in another type after exactly two
/// other questions. Only when both answers are right is the card learned.
///
/// [modesOf] says which modes a card can be drilled in now, and [canChoose]
/// whether a choice question about it has enough options; one that has not
/// is asked its mode's own way, which for Recognition is rated by the
/// learner and proves nothing. A card with no two different questions
/// ([learnPair]) cannot be learned yet and is left out. [fillers] are reviews
/// that space a last group of fewer than three new cards.
///
/// A card [straightToQuestion] says so of has no teaching card: a rules
/// table's cell is shown by its rule card.
///
/// A card [typed] says is not typed is never asked for a typed answer: its
/// production is chosen. [siblingsOf] gives a card's other forms by its base
/// ([formSiblings]), which a lesson asks as the review does. A card [tracked]
/// says is not tracked is one already learned, asked again as practice, and
/// its answers are recorded as they come.
List<SessionItem> lessonPlan(
  List<Card> cards, {
  required Set<DrillMode> Function(Card card) modesOf,
  required bool Function(Card card, Ask ask) canChoose,
  bool Function(Card card)? straightToQuestion,
  bool Function(Card card)? typed,
  List<Card> Function(Card card)? siblingsOf,
  bool Function(Card card)? tracked,
  List<SessionItem> fillers = const <SessionItem>[],
}) {
  final attempts = <LearnAttempt>[
    for (final card in cards)
      ?lessonAttempt(
        card,
        modesOf: modesOf,
        canChoose: canChoose,
        straightToQuestion: straightToQuestion,
        typed: typed,
        siblingsOf: siblingsOf,
        tracked: tracked,
      ),
  ];
  return learnSequence(attempts, fillers: fillers).items;
}

/// The learn attempt of [card] as [lessonPlan] lays it out, or null when it
/// cannot be learned yet: it has not two different questions ([learnPair]).
/// A card [tracked] says is not tracked is one already learned, practised
/// again: it is never left out, and with one question only it is asked once.
LearnAttempt? lessonAttempt(
  Card card, {
  required Set<DrillMode> Function(Card card) modesOf,
  required bool Function(Card card, Ask ask) canChoose,
  bool Function(Card card)? straightToQuestion,
  bool Function(Card card)? typed,
  List<Card> Function(Card card)? siblingsOf,
  bool Function(Card card)? tracked,
}) {
  final modes = modesOf(card);
  SessionItem asked(DrillMode mode, Ask ask) => SessionItem(
    card: card,
    mode: mode,
    state: null,
    ask: ask.chooses && !canChoose(card, ask) ? Ask.own : ask,
  );
  final questions = <SessionItem>[
    for (final q in lessonQuestions(
      card,
      typed: typed?.call(card) ?? true,
      siblings: siblingsOf?.call(card) ?? const <Card>[],
    ))
      // A match is a group of items: a learn question is of one.
      if (modes.contains(q.mode))
        asked(q.mode, q.ask == Ask.matchPairs ? Ask.chooseMeaning : q.ask),
  ];
  // A word with only one skill of its own, as a phrase of one word has no
  // Write, is also asked by choosing its word.
  final fallback =
      card.rule == null &&
          !card.isGrammarCell &&
          modes.contains(DrillMode.recognition) &&
          canChoose(card, Ask.chooseWord)
      ? SessionItem(
          card: card,
          mode: DrillMode.recognition,
          state: null,
          ask: Ask.chooseWord,
        )
      : null;
  final isTracked = tracked?.call(card) ?? true;
  final pair = learnPair(questions, fallback: fallback);
  final SessionItem first;
  final SessionItem? second;
  if (pair != null) {
    first = pair.first;
    second = pair.second;
  } else if (!isTracked && questions.isNotEmpty) {
    first = questions.first;
    second = null;
  } else {
    return null;
  }
  final straight = straightToQuestion?.call(card) ?? false;
  final SessionItem? show;
  if (straight) {
    show = card.rule != null
        ? SessionItem(
            card: card,
            mode: DrillMode.grammar,
            state: null,
            ask: Ask.teachRule,
          )
        : null;
  } else {
    show = SessionItem(
      card: card,
      mode: first.mode,
      state: null,
      ask: Ask.teach,
    );
  }
  return LearnAttempt(
    card: card,
    shows: <SessionItem>[?show],
    first: first,
    second: second,
    tracked: isTracked,
  );
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
