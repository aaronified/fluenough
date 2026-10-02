import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/placement.dart';

/// Placement (#117, ADR-0013) on the bundled Hindi course.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<DeckEntry>> hindi;
  setUpAll(() async {
    final state = AppState.test();
    await state.load();
    hindi = state.courseUnits('hi');
  });

  Placement placement() => Placement(hindi, random: Random(7));

  Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
    for (final unit in units)
      for (final entry in unit) entry.id,
  };

  /// Answers [placement]'s questions rightly until it reaches unit [stop].
  void knowUpTo(Placement placement, int stop) {
    while (!placement.isFinished && placement.unit < stop) {
      placement.answer(placement.question!.card.native);
    }
  }

  test('each question is a card of the unit, its meaning one of two to four '
      'different options', () {
    final p = placement();
    for (var unit = 0; unit < 3; unit++) {
      for (var i = 0; i < p.questionsPerUnit; i++) {
        final q = p.question!;
        expect(p.unit, unit);
        expect(decksOf([hindi[unit]]), contains(q.card.deckId));
        expect(q.options.where((o) => o == q.card.native), hasLength(1));
        expect(q.options.toSet(), hasLength(q.options.length));
        expect(q.options.length, inInclusiveRange(2, 4));
        p.answer(q.card.native);
      }
    }
    expect(p.placedDeckIds, decksOf(hindi.take(3)));
  });

  test('a unit takes its questions from each of its decks in turn', () {
    final p = placement();
    final decks = <String>[];
    for (var i = 0; i < p.questionsPerUnit; i++) {
      final q = p.question!;
      decks.add(q.card.deckId);
      p.answer(q.card.native);
    }
    expect(decks.toSet(), decksOf([hindi.first]));
  });

  test('two wrong in a unit ends placement there; the units before are '
      'placed', () {
    final p = placement();
    knowUpTo(p, 2);
    expect(p.unit, 2);
    p.answer(null);
    expect(p.isFinished, isFalse, reason: 'one wrong in four is allowed');
    p.answer('not a meaning');
    expect(p.isFinished, isTrue);
    expect(p.question, isNull);
    expect(p.placedDeckIds, decksOf(hindi.take(2)));
    expect(p.startUnit, hindi[2]);
  });

  test('a beginner is placed nowhere, and starts at the first unit', () {
    final p = placement()
      ..answer(null)
      ..answer(null);
    expect(p.isFinished, isTrue);
    expect(p.placedDeckIds, isEmpty);
    expect(p.startUnit, hindi.first);
  });

  test('stopping keeps the units already known', () {
    final p = placement();
    knowUpTo(p, 1);
    p
      ..answer(p.question!.card.native)
      ..stop();
    expect(p.isFinished, isTrue);
    expect(p.placedDeckIds, decksOf(hindi.take(1)));
  });

  test('knowing every unit places the whole course', () {
    final p = placement();
    knowUpTo(p, hindi.length);
    expect(p.isFinished, isTrue);
    expect(p.startUnit, isNull);
    expect(p.placedDeckIds, decksOf(hindi));
  });

  test('a unit with fewer than four meanings asks them all, and needs them '
      'all', () async {
    final state = AppState.test(
      decks: MemoryDeckSource(<String, String>{
        'decks/hi/hi-en-two.yaml': '''
schema: 1
id: hi-en-two
name: Two
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-two-0001, target: "घर", native: "house" }
  - { id: hi-en-two-0002, target: "पानी", native: "water" }
''',
      }),
    );
    addTearDown(state.dispose);
    await state.load();
    final p = Placement(state.courseUnits('hi'), random: Random(1));
    p.answer(p.question!.card.native);
    expect(p.isFinished, isFalse);
    p.answer(null);
    expect(p.isFinished, isTrue);
    expect(p.placedDeckIds, isEmpty, reason: 'one wrong of two is too many');
  });

  test('no question offers a second right answer, where forms are spelled '
      'alike, in any unit of the Indic courses', () async {
    final state = AppState.test();
    addTearDown(state.dispose);
    await state.load();
    for (final code in <String>['hi', 'bn', 'te']) {
      final units = state.courseUnits(code);
      final meanings = <String, Set<String>>{};
      for (final unit in units) {
        for (final entry in unit) {
          for (final card in entry.cards) {
            (meanings[card.target] ??= <String>{}).add(card.native);
          }
        }
      }
      for (var seed = 0; seed < 30; seed++) {
        final p = Placement(units, random: Random(seed));
        while (!p.isFinished) {
          final q = p.question!;
          final right = meanings[q.card.target]!;
          expect(q.options.where(right.contains), <String>[
            q.card.native,
          ], reason: '$code seed $seed: ${q.card.target} offers ${q.options}');
          p.answer(q.card.native);
        }
      }
    }
  });
}
