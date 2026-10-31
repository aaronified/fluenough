import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/languages/language_skills.dart';

void main() {
  const speak = SkillKey(SkillKind.speak);
  const readDeva = SkillKey(SkillKind.read, 'devanagari');
  const writeDeva = SkillKey(SkillKind.write, 'devanagari');
  const readUrdu = SkillKey(SkillKind.read, 'perso_arabic');
  final shape = skillsOfLanguage(<String>['devanagari', 'perso_arabic']);

  test(
    'a tap cycles Leave, Know, Learn, Leave, and skips Learn without decks',
    () {
      var s = LanguageSkills();
      s = s.cycled(speak, canLearn: true);
      expect(s.stateOf(speak), SkillState.know);
      s = s.cycled(speak, canLearn: true);
      expect(s.stateOf(speak), SkillState.learn);
      s = s.cycled(speak, canLearn: true);
      expect(s.stateOf(speak), SkillState.leave);
      s = s.cycled(speak, canLearn: false).cycled(speak, canLearn: false);
      expect(s.stateOf(speak), SkillState.leave);
    },
  );

  test('a language with every skill Leave goes back to the pool', () {
    final s = LanguageSkills(<SkillKey, SkillState>{readDeva: SkillState.know});
    expect(s.isAllLeave, isFalse);
    expect(s.withState(readDeva, SkillState.leave).isAllLeave, isTrue);
  });

  test('counts read like 4/6 and a script has Read and Write each', () {
    expect(shape.length, 6);
    final s = LanguageSkills(<SkillKey, SkillState>{
      speak: SkillState.know,
      readDeva: SkillState.know,
      writeDeva: SkillState.know,
      readUrdu: SkillState.learn,
    });
    expect(s.count(SkillState.know, shape), 3);
    expect(s.count(SkillState.learn, shape), 1);
    expect(s.anyLearn, isTrue);
    expect(needsFullDecks(s), isTrue);
  });

  test('stored skills read back, and unreadable entries are dropped', () {
    final s = LanguageSkills(<SkillKey, SkillState>{
      speak: SkillState.learn,
      readDeva: SkillState.know,
    });
    expect(LanguageSkills.fromStored(s.toStored()), s);
    expect(
      LanguageSkills.fromStored(<String, Object?>{
        'speak': 'know',
        'read': 'know',
        'dance': 'learn',
        'write:x:y': 'know',
        'hear': 'maybe',
      }).toStored(),
      <String, String>{'speak': 'know'},
    );
  });

  test('the double tick needs a level that covers a Know skill', () {
    expect(
      markOf(
        SkillState.know,
        covered: levelCovers(levelFound: true, taught: true),
      ),
      SkillMark.knowCovered,
    );
    expect(
      markOf(
        SkillState.know,
        covered: levelCovers(levelFound: true, taught: false),
      ),
      SkillMark.know,
    );
    expect(
      markOf(
        SkillState.know,
        covered: levelCovers(levelFound: false, taught: true),
      ),
      SkillMark.know,
    );
    expect(markOf(SkillState.learn, covered: true), SkillMark.learn);
    // English has no course and is never tested, yet is always covered.
    expect(
      levelCovers(levelFound: false, taught: false, english: true),
      isTrue,
    );
  });

  test('the fit-your-level line shows only with review on', () {
    final s = LanguageSkills(<SkillKey, SkillState>{speak: SkillState.know});
    bool line(bool on, bool found) => needsLevelFit(
      reviewOn: on,
      skills: s,
      rows: <SkillKey>[speak],
      covered: (_) => found,
    );
    expect(line(true, false), isTrue);
    expect(line(false, false), isFalse);
    expect(line(true, true), isFalse);
  });

  test('a change to Learn owes one sound test and one check per script', () {
    final owed = checksOwed(<SkillKey>[
      speak,
      const SkillKey(SkillKind.hear),
      readUrdu,
      const SkillKey(SkillKind.write, 'perso_arabic'),
      readDeva,
    ]);
    expect(owed.length, 3);
    expect(owed[0], isA<SoundCheck>());
    expect((owed[1] as ScriptCheck).script, 'perso_arabic');
    expect((owed[2] as ScriptCheck).script, 'devanagari');
    expect(checksOwed(const <SkillKey>[]), isEmpty);
  });

  test('a known script starts as Know in a new language', () {
    final found = autoKnownFrom(
      scripts: <String>['devanagari'],
      others: <String, LanguageSkills>{
        'Hindustani': LanguageSkills(<SkillKey, SkillState>{
          readDeva: SkillState.know,
        }),
      },
    );
    expect(found, <SkillKey, String>{readDeva: 'Hindustani'});
  });

  test('the old lists read as skills until the learner edits', () {
    final learner = skillsFromLegacy(
      scripts: <String>['devanagari', 'perso_arabic'],
      learned: true,
      known: false,
      learnedScripts: <String>{'perso_arabic'},
      readsScript: (s) => s == 'devanagari',
    );
    expect(learner.stateOf(speak), SkillState.learn);
    expect(learner.stateOf(readUrdu), SkillState.learn);
    expect(learner.stateOf(readDeva), SkillState.know);
    final speaker = skillsFromLegacy(
      scripts: <String>['latin'],
      learned: false,
      known: true,
      learnedScripts: const <String>{},
      readsScript: (_) => false,
    );
    expect(speaker.stateOf(speak), SkillState.know);
    expect(speaker.anyLearn, isFalse);
  });

  test('minutes a day step by 5 and stop at 5 and 60', () {
    expect(stepMinutes(15, 1), 20);
    expect(stepMinutes(5, -1), 5);
    expect(stepMinutes(60, 1), 60);
    expect(minutesAtEnd(5, -1), isTrue);
    expect(minutesAtEnd(60, 1), isTrue);
    expect(minutesAtEnd(15, 1), isFalse);
  });
}
