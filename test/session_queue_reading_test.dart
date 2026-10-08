import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

/// Reading questions in a session (#98, ADR-0019): each scheduled like a
/// card, and a passage's questions kept together.

final now = DateTime(2026, 9, 28, 19);

/// [questions] questions about passage [id], as the parser makes them.
List<QuestionCard> passage(String id, int questions) {
  final p = Passage(
    id: id,
    title: 'Passage $id',
    sentences: const <PassageSentence>[PassageSentence(text: 'বাক্য।')],
    questions: <ReadingQuestion>[
      for (var i = 1; i <= questions; i++)
        ReadingQuestion(id: '$id-q$i', prompt: {'en': 'Q$i'}, answer: 0),
    ],
  );
  return <QuestionCard>[
    for (final q in p.questions)
      QuestionCard(deckId: 'reading', passage: p, question: q),
  ];
}

Card word(String id) =>
    Card(id: id, deckId: 'words', target: 'target $id', native: 'native $id');

FsrsState dueDaysAgo(int daysAgo) => FsrsState(
  stability: 6,
  difficulty: 5,
  repetitions: 2,
  intervalDays: 6,
  dueAt: now.subtract(Duration(days: daysAgo)),
  lastReviewAt: now.subtract(Duration(days: daysAgo + 6)),
);

SessionQueue build(
  List<Card> cards, {
  Map<(String, DrillMode), FsrsState> states = const {},
  bool voice = true,
  int newCardLimit = 20,
}) => SessionQueue.build(
  cards: cards,
  stateOf: (c, m) => states[(c.id, m)],
  hasVoice: (_) => voice,
  now: now,
  newCardLimit: newCardLimit,
);

List<String> ids(List<SessionItem> items) => [
  for (final i in items) '${i.card.id}:${i.mode.name}',
];

void main() {
  test('a new question is read before it is heard', () {
    final queue = build(passage('p', 2));
    expect(ids(queue.items), ['p-q1:reading', 'p-q2:reading']);
  });

  test('a question read already is heard next, and only with a voice', () {
    final cards = passage('p', 1);
    final read = {('p-q1', DrillMode.reading): dueDaysAgo(-3)};
    expect(ids(build(cards, states: read).items), ['p-q1:listening']);
    expect(build(cards, states: read, voice: false).items, isEmpty);
  });

  test('a passage\'s new questions come together, past the cap if need be', () {
    final queue = build(<Card>[
      word('a'),
      ...passage('p', 3),
      word('b'),
    ], newCardLimit: 2);
    // The passage's first question fits under the cap, so all three come.
    expect(ids(queue.fresh), [
      'a:production',
      'p-q1:reading',
      'p-q2:reading',
      'p-q3:reading',
    ]);
    // With no room for its first, none comes.
    expect(
      ids(build(<Card>[word('a'), ...passage('p', 3)], newCardLimit: 1).fresh),
      ['a:production'],
    );
  });

  test('a passage\'s due and new questions come together, where its first '
      'was, heard before read', () {
    final p = passage('p', 3);
    final queue = build(
      <Card>[word('a'), word('b'), ...p],
      states: {
        ('a', DrillMode.production): dueDaysAgo(5),
        ('b', DrillMode.production): dueDaysAgo(1),
        // q1 is due to be read, q2 to be heard; q3 is new.
        ('p-q1', DrillMode.reading): dueDaysAgo(3),
        ('p-q2', DrillMode.reading): dueDaysAgo(-2),
        ('p-q2', DrillMode.listening): dueDaysAgo(2),
      },
    );
    expect(ids(queue.due), [
      'a:production',
      'p-q1:reading',
      'p-q2:listening',
      'b:production',
    ]);
    // Heard first, so that the text is not seen before it is heard.
    expect(ids(queue.items), [
      'a:production',
      'p-q2:listening',
      'p-q1:reading',
      'p-q3:reading',
      'b:production',
    ]);
  });

  test('two passages stay apart, each in one piece', () {
    final queue = build(<Card>[...passage('p', 2), ...passage('r', 2)]);
    expect(ids(queue.items), [
      'p-q1:reading',
      'p-q2:reading',
      'r-q1:reading',
      'r-q2:reading',
    ]);
  });

  test('a share of the day\'s new cards runs to the end of a passage', () {
    SessionItem fresh(Card c) =>
        SessionItem(card: c, mode: DrillMode.reading, state: null);
    final shared = SessionQueue.fairShares(<List<SessionItem>>[
      <SessionItem>[for (final c in passage('p', 3)) fresh(c)],
      <SessionItem>[
        for (final c in <Card>[word('a'), word('b')])
          SessionItem(card: c, mode: DrillMode.production, state: null),
      ],
    ], 2);
    expect(ids(shared), [
      'p-q1:reading',
      'p-q2:reading',
      'p-q3:reading',
      'a:production',
    ]);
  });
}
