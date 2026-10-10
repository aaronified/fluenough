import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/skill_difficulty.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';

void main() {
  final monday = DateTime(2026, 10, 5, 19);

  void answer(
    MemoryProgress progress,
    String card,
    DrillMode mode,
    int grade, {
    int day = 0,
  }) => progress.record(
    deckId: 'te-en-food',
    cardId: card,
    mode: mode,
    grade: grade,
    now: monday.add(Duration(days: day)),
    answerGiven: 'typed',
  );

  List<SkillDifficulty> of(MemoryProgress progress, String card) =>
      SkillDifficulty.of(card, progress.stateOf);

  test('a card never answered has no difficulty in any skill', () {
    expect(of(MemoryProgress(), 'te-0001'), isEmpty);
  });

  test('D is FSRS\'s, read per card and skill from the pair state, '
      'and only for the skills answered', () {
    final progress = MemoryProgress();
    answer(progress, 'te-0001', DrillMode.listening, 1);
    answer(progress, 'te-0001', DrillMode.production, 4);
    final ds = of(progress, 'te-0001');
    expect(ds.map((d) => d.mode), <DrillMode>[
      DrillMode.production,
      DrillMode.listening,
    ]);
    for (final d in ds) {
      expect(d.difficulty, progress.stateOf('te-0001', d.mode)!.difficulty);
    }
    // Another card's answers are not this card's.
    expect(of(progress, 'te-0002'), isEmpty);
  });

  test('a miss in one skill leaves the others\' D alone', () {
    final progress = MemoryProgress()
      // Write and Say imply Recognition, as the app sets them.
      ..skills = const SkillMap();
    for (final mode in <DrillMode>[
      DrillMode.recognition,
      DrillMode.production,
      DrillMode.listening,
      DrillMode.speaking,
    ]) {
      answer(progress, 'te-0001', mode, 4);
    }
    final before = {
      for (final d in of(progress, 'te-0001')) d.mode: d.difficulty,
    };
    expect(before, hasLength(4));

    // Missed by ear, twice.
    answer(progress, 'te-0001', DrillMode.listening, 1, day: 3);
    answer(progress, 'te-0001', DrillMode.listening, 0, day: 4);
    final after = {
      for (final d in of(progress, 'te-0001')) d.mode: d.difficulty,
    };
    expect(
      after[DrillMode.listening]!,
      greaterThan(before[DrillMode.listening]!),
    );
    for (final mode in <DrillMode>[
      DrillMode.recognition,
      DrillMode.production,
      DrillMode.speaking,
    ]) {
      expect(after[mode], before[mode], reason: '${mode.name} kept its D');
    }
  });

  test('a right answer that implies another skill leaves that skill\'s D '
      'alone', () {
    final progress = MemoryProgress()..skills = const SkillMap();
    answer(progress, 'te-0001', DrillMode.recognition, 1);
    final d = progress.stateOf('te-0001', DrillMode.recognition)!.difficulty;
    // Write right implies Recognition: its stability may grow, its D not.
    answer(progress, 'te-0001', DrillMode.production, 4, day: 2);
    expect(progress.stateOf('te-0001', DrillMode.recognition)!.difficulty, d);
  });

  test('a right answer by ear or by voice leaves the skill it implies '
      'alone in D', () {
    final progress = MemoryProgress()
      // Alphabet decks: hearing a form implies writing it.
      ..skills = const SkillMap(formHeardIn: <String>{'te-script'});
    answer(progress, 'te-0001', DrillMode.recognition, 1);
    final d = progress.stateOf('te-0001', DrillMode.recognition)!.difficulty;
    final stability = progress
        .stateOf('te-0001', DrillMode.recognition)!
        .stability;

    // Hear right implies Recognition.
    answer(progress, 'te-0001', DrillMode.listening, 4, day: 2);
    final afterHear = progress.stateOf('te-0001', DrillMode.recognition)!;
    expect(afterHear.difficulty, d, reason: 'Hear right kept Recognition D');
    // The implied review did reach Recognition, so the D held for a reason.
    expect(afterHear.stability, isNot(stability));

    // Say right implies Recognition too.
    answer(progress, 'te-0001', DrillMode.speaking, 4, day: 5);
    final afterSay = progress.stateOf('te-0001', DrillMode.recognition)!;
    expect(afterSay.difficulty, d, reason: 'Say right kept Recognition D');
    expect(afterSay.stability, isNot(afterHear.stability));

    // In an alphabet deck, Hear right implies Write: its D is kept as well.
    void heard(DrillMode mode, int grade, int day) => progress.record(
      deckId: 'te-script',
      cardId: 'te-a',
      mode: mode,
      grade: grade,
      now: monday.add(Duration(days: day)),
      answerGiven: 'typed',
    );
    heard(DrillMode.production, 1, 0);
    final write = progress.stateOf('te-a', DrillMode.production)!;
    heard(DrillMode.listening, 4, 2);
    final afterHeard = progress.stateOf('te-a', DrillMode.production)!;
    expect(afterHeard.difficulty, write.difficulty);
    expect(afterHeard.stability, isNot(write.stability));
  });

  test('grammar understood and produced keep their own D', () {
    final progress = MemoryProgress();
    answer(progress, 'te-0100', DrillMode.grammarUnderstood, 4);
    answer(progress, 'te-0100', DrillMode.grammar, 4);
    final understood = of(progress, 'te-0100').first.difficulty;
    answer(progress, 'te-0100', DrillMode.grammar, 1, day: 2);
    final ds = of(progress, 'te-0100');
    expect(ds.map((d) => d.mode), <DrillMode>[
      DrillMode.grammarUnderstood,
      DrillMode.grammar,
    ]);
    expect(ds.first.difficulty, understood);
    expect(ds.last.difficulty, greaterThan(understood));
  });

  test('shown is D rounded into 1 to 10, and leans easier, middling or '
      'harder', () {
    SkillDifficulty d(double v) => SkillDifficulty(DrillMode.listening, v);
    expect(d(1).shown, 1);
    expect(d(0.4).shown, 1);
    expect(d(10).shown, 10);
    expect(d(10.3).shown, 10);
    expect(d(4.4).shown, 4);
    expect(d(4.4).lean, DifficultyLean.easier);
    expect(d(4.6).lean, DifficultyLean.middling);
    expect(d(6.4).lean, DifficultyLean.middling);
    expect(d(6.6).lean, DifficultyLean.harder);
    expect(d(10).lean, DifficultyLean.harder);

    // A first Good leans easier; a first miss does not lean harder yet.
    final good = Fsrs.next(null, 4, now: monday);
    final miss = Fsrs.next(null, 1, now: monday);
    expect(d(good.difficulty).lean, DifficultyLean.easier);
    expect(d(miss.difficulty).lean, DifficultyLean.middling);
  });
}
