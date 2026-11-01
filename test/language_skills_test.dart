import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/languages/language_skills.dart';

void main() {
  const speak = SkillKey(SkillKind.speak);
  const readDeva = SkillKey(SkillKind.read, 'devanagari');
  const writeDeva = SkillKey(SkillKind.write, 'devanagari');
  const readUrdu = SkillKey(SkillKind.read, 'perso_arabic');
  final shape = skillsOfLanguage(<String>['devanagari', 'perso_arabic']);

  test('a script pill cycles Leave, Learn, Read, Read and Write, Leave, and '
      'skips Learn without decks', () {
    var s = LanguageSkills();
    final seen = <ScriptLevel>[];
    for (var i = 0; i < 5; i++) {
      s = s.cycledScript('devanagari', canLearn: true);
      seen.add(s.scriptLevelOf('devanagari'));
    }
    expect(seen, <ScriptLevel>[
      ScriptLevel.learn,
      ScriptLevel.read,
      ScriptLevel.readWrite,
      ScriptLevel.leave,
      ScriptLevel.learn,
    ]);
    s = LanguageSkills();
    s = s.cycledScript('devanagari', canLearn: false);
    expect(s.scriptLevelOf('devanagari'), ScriptLevel.read);
    s = s.cycledScript('devanagari', canLearn: false);
    s = s.cycledScript('devanagari', canLearn: false);
    expect(s.scriptLevelOf('devanagari'), ScriptLevel.leave);
  });

  test('a script level is written as the stored Read and Write, and read '
      'back from any stored combination', () {
    LanguageSkills at(ScriptLevel level) =>
        LanguageSkills().withScriptLevel('devanagari', level);
    expect(at(ScriptLevel.read).toStored(), <String, String>{
      'read:devanagari': 'know',
    });
    expect(at(ScriptLevel.readWrite).toStored(), <String, String>{
      'read:devanagari': 'know',
      'write:devanagari': 'know',
    });
    expect(at(ScriptLevel.learn).toStored(), <String, String>{
      'read:devanagari': 'learn',
      'write:devanagari': 'learn',
    });
    expect(at(ScriptLevel.leave).isAllLeave, isTrue);
    // Every stored combination of the two skills has a level, and the level
    // survives a round trip through the stored form.
    ScriptLevel level(SkillState read, SkillState write) =>
        LanguageSkills(<SkillKey, SkillState>{readDeva: read, writeDeva: write})
            .scriptLevelOf('devanagari');
    const l = SkillState.leave, k = SkillState.know, n = SkillState.learn;
    expect(level(l, l), ScriptLevel.leave);
    expect(level(k, l), ScriptLevel.read);
    expect(level(k, k), ScriptLevel.readWrite);
    // Write alone implies Read: shown as Read and Write.
    expect(level(l, k), ScriptLevel.readWrite);
    for (final (r, w) in [(n, l), (l, n), (n, n), (n, k), (k, n)]) {
      expect(level(r, w), ScriptLevel.learn, reason: '$r $w');
    }
    for (final lv in ScriptLevel.values) {
      expect(
        LanguageSkills.fromStored(at(lv).toStored())
            .scriptLevelOf('devanagari'),
        lv,
      );
    }
  });

  test('the Spoken pill cycles Leave, Learn, Hear, Hear and Speak, Leave and '
      'is stored as Speak and Hear', () {
    var s = LanguageSkills();
    final seen = <SpokenLevel>[];
    for (var i = 0; i < 4; i++) {
      s = s.cycledSpoken(canLearn: true);
      seen.add(s.spokenLevel);
      if (s.spokenLevel == SpokenLevel.hear) {
        expect(s.toStored(), <String, String>{'hear': 'know'});
      }
      if (s.spokenLevel == SpokenLevel.hearSpeak) {
        expect(s.toStored(), <String, String>{'speak': 'know', 'hear': 'know'});
      }
    }
    expect(seen, <SpokenLevel>[
      SpokenLevel.learn,
      SpokenLevel.hear,
      SpokenLevel.hearSpeak,
      SpokenLevel.leave,
    ]);
    expect(s.isAllLeave, isTrue);
    expect(
      LanguageSkills().cycledSpoken(canLearn: false).spokenLevel,
      SpokenLevel.hear,
    );
  });

  test('every stored combination of Speak and Hear has a Spoken level', () {
    SpokenLevel level(SkillState speakState, SkillState hearState) =>
        LanguageSkills(<SkillKey, SkillState>{
          speak: speakState,
          const SkillKey(SkillKind.hear): hearState,
        }).spokenLevel;
    const l = SkillState.leave, k = SkillState.know, n = SkillState.learn;
    expect(level(l, l), SpokenLevel.leave);
    expect(level(l, k), SpokenLevel.hear);
    expect(level(k, k), SpokenLevel.hearSpeak);
    // Speak alone implies Hear: shown as Hear and Speak.
    expect(level(k, l), SpokenLevel.hearSpeak);
    for (final (a, b) in [(n, l), (l, n), (n, n), (n, k), (k, n)]) {
      expect(level(a, b), SpokenLevel.learn, reason: '$a $b');
    }
  });

  test('the two Know levels of a pill are marked with a tick and the extra '
      'skill, and the found level doubles the tick', () {
    expect(scriptMarkOf(ScriptLevel.read, covered: false), SkillMark.know);
    expect(
      scriptMarkOf(ScriptLevel.readWrite, covered: false),
      SkillMark.knowBoth,
    );
    expect(
      scriptMarkOf(ScriptLevel.readWrite, covered: true),
      SkillMark.knowBothCovered,
    );
    expect(
      spokenMarkOf(SpokenLevel.hear, covered: true),
      SkillMark.knowCovered,
    );
    expect(
      spokenMarkOf(SpokenLevel.hearSpeak, covered: false),
      SkillMark.knowBoth,
    );
    expect(spokenMarkOf(SpokenLevel.learn, covered: true), SkillMark.learn);
    expect(scriptMarkOf(ScriptLevel.leave, covered: true), SkillMark.leave);
  });

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
