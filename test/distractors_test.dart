// Wrong options for a choice question are ranked by what they share with the
// card, read from its data (ADR-0039, #522 step 3).
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/distractors.dart';
import 'package:flutter_test/flutter_test.dart';

Card card(
  String id, {
  String? pos,
  List<String> tags = const <String>[],
  List<CardBase> bases = const <CardBase>[],
}) => Card(
  id: id,
  deckId: 'zz-en-test',
  target: 'word $id',
  native: 'meaning $id',
  pos: pos,
  tags: tags,
  bases: bases,
);

void main() {
  test('wrong options come family first, then part of speech and tag, then '
      'the rest, and the pool keeps every card', () {
    final answer = card(
      'zz-1',
      pos: 'verb',
      tags: <String>['food'],
      bases: const <CardBase>[CardBase(word: 'ate', ref: 'zz-2')],
    );
    final family = card('zz-2', pos: 'noun');
    final verbAndTag = card('zz-3', pos: 'verb', tags: <String>['food']);
    final verb = card('zz-4', pos: 'verb');
    final tag = card('zz-5', pos: 'noun', tags: <String>['food', 'home']);
    final unrelated = card('zz-6', pos: 'noun');
    final pool = <Card>[unrelated, tag, verb, verbAndTag, family];

    final groups = rankDistractors(answer, pool);

    expect(groups, <List<Card>>[
      <Card>[family],
      <Card>[verbAndTag],
      <Card>[verb],
      <Card>[tag],
      <Card>[unrelated],
    ]);
    expect(groups.expand((g) => g).toSet(), pool.toSet());
  });

  test('a card with no data to share still gets every card of the pool', () {
    final bare = card('zz-1');
    final pool = <Card>[card('zz-2'), card('zz-3'), card('zz-4')];
    final groups = rankDistractors(bare, pool);
    expect(groups, hasLength(1));
    expect(groups.single, pool);
  });
}
