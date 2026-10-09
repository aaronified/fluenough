import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ability.dart';

typedef R = ({String cardId, DrillMode mode, int grade});

R r(String cardId, int grade, [DrillMode mode = DrillMode.listening]) =>
    (cardId: cardId, mode: mode, grade: grade);

void main() {
  test('starts even: ability 0, strength one half', () {
    final a = Abilities.replay(const <R>[]);
    expect(a.of('te', DrillMode.listening), 0);
    expect(a.strength('te', DrillMode.listening), 0.5);
  });

  test('a right answer raises the ability, a miss lowers it', () {
    final right = Abilities.replay([r('te-0001', 4)]);
    final wrong = Abilities.replay([r('te-0001', 1)]);
    expect(right.of('te', DrillMode.listening), closeTo(0.5, 1e-9));
    expect(wrong.of('te', DrillMode.listening), closeTo(-0.5, 1e-9));
  });

  test('is kept per language and schedule, from the card id', () {
    final a = Abilities.replay([
      r('te-0001', 4),
      r('te-0002', 4, DrillMode.speaking),
      r('hi-0001', 1),
    ]);
    expect(a.of('te', DrillMode.listening), greaterThan(0));
    expect(a.of('te', DrillMode.speaking), greaterThan(0));
    expect(a.of('hi', DrillMode.listening), lessThan(0));
    expect(a.of('ta', DrillMode.listening), 0);
    expect(a.answersIn('te', DrillMode.listening), 1);
    expect(a.answersIn('te', DrillMode.production), 0);
  });

  test('recognition is a skill of its own', () {
    final a = Abilities.replay([r('te-0001', 4, DrillMode.recognition)]);
    expect(a.keys, [(language: 'te', mode: DrillMode.recognition)]);
    expect(a.of('te', DrillMode.recognition), closeTo(0.5, 1e-9));
  });

  test('an answer moves a skill research relates to it, by as much', () {
    final a = Abilities.replay([r('te-0001', 4)]);
    expect(a.of('te', DrillMode.recognition), closeTo(0.5 * 0.68, 1e-9));
    expect(a.keys, [(language: 'te', mode: DrillMode.listening)]);
    final b = Abilities.replay([r('te-0001', 4, DrillMode.recognition)]);
    expect(b.of('te', DrillMode.listening), closeTo(0.5 * 0.68, 1e-9));
  });

  test('and moves no skill research has not related to it', () {
    final a = Abilities.replay([r('te-0001', 4)]);
    expect(a.of('te', DrillMode.production), 0);
    expect(a.of('te', DrillMode.speaking), 0);
    expect(a.of('te', DrillMode.grammar), 0);
  });

  test('grammar moves only grammar', () {
    final a = Abilities.replay([r('te-0001', 4, DrillMode.grammar)]);
    expect(a.of('te', DrillMode.grammar), closeTo(0.5, 1e-9));
    expect(a.of('te', DrillMode.listening), 0);
  });

  test('moves less as answers add up', () {
    expect(Abilities.k(0), 1);
    expect(Abilities.k(20), 0.5);
    final early = Abilities.replay([r('te-0001', 4)]);
    final late = Abilities.replay([
      for (var i = 0; i < 40; i++) r('te-${1000 + i}', i.isEven ? 4 : 1),
    ]);
    final before = late.of('te', DrillMode.listening);
    late.add(cardId: 'te-2000', mode: DrillMode.listening, grade: 4);
    expect(
      late.of('te', DrillMode.listening) - before,
      lessThan(early.of('te', DrillMode.listening)),
    );
  });

  test('a pair answered right again and again comes to look easy, so '
      'another right answer there says less', () {
    final a = Abilities.replay([for (var i = 0; i < 10; i++) r('te-0001', 4)]);
    final b = Abilities.replay([
      for (var i = 0; i < 10; i++) r('te-${i + 1}', 4),
    ]);
    expect(
      a.of('te', DrillMode.listening),
      lessThan(b.of('te', DrillMode.listening)),
    );
  });

  test('the language of a card id', () {
    expect(Abilities.languageOf('te-0053'), 'te');
    expect(Abilities.languageOf('yue-0001'), 'yue');
  });
}
