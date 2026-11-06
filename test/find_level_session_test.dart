// Find my level's run, step 3 and 4 of wiki/Plan-Placement-V2.md: the options
// the declaration offers by built level, the skills a tap checks, a paused
// run saved and resumed, and the session that drives the run controller and
// the question builder together.
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/declaration_options.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/core/placement/saved_run.dart';
import 'package:fluenough/core/placement/skills_in_play.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';

/// Answers every question with [oracle] until the session is done or at a
/// checkpoint the learner stops at, or [cap] answers.
void play(
  PlacementSession session,
  bool Function(GeneratedQuestion) oracle, {
  int cap = 150,
}) {
  var guard = 0;
  while (!session.isDone && guard++ < cap) {
    if (session.atCheckpoint) {
      session.keepGoing();
      continue;
    }
    session.answer(oracle(session.question!));
  }
}

void main() {
  group('the declaration offers what the built path supports', () {
    test('nothing below A1', () {
      expect(declarationOptionsFor(builtBelowA1), isEmpty);
    });

    test('A1 only: Beginner and Amateur', () {
      expect(declarationOptionsFor(builtA1), <PlacementDeclaration>[
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ]);
    });

    test('A2 adds Advanced', () {
      expect(declarationOptionsFor(builtA2), <PlacementDeclaration>[
        PlacementDeclaration.advanced,
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ]);
    });

    test('B1 complete adds Expert', () {
      expect(declarationOptionsFor(builtB1), <PlacementDeclaration>[
        PlacementDeclaration.expert,
        PlacementDeclaration.advanced,
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ]);
    });

    B1Progress progress(List<B1Unit> units) => B1Progress.of(units);
    B1Unit written(Milestone? m) => B1Unit(words: 10, milestone: m, has: 10);
    B1Unit coming(Milestone? m) =>
        B1Unit(planned: true, words: 10, milestone: m);

    test(
      'a course is built to a level when no unit up to it is to be written',
      () {
        expect(
          progress(<B1Unit>[coming(Milestone.a1)]).builtLevel,
          builtBelowA1,
        );
        expect(
          progress(<B1Unit>[written(Milestone.a1), coming(Milestone.a2)])
              .builtLevel,
          builtA1,
        );
        expect(
          progress(<B1Unit>[
            written(Milestone.a1),
            written(Milestone.a2),
            coming(Milestone.b1),
          ]).builtLevel,
          builtA2,
        );
        expect(
          progress(<B1Unit>[
            written(Milestone.a1),
            written(null),
            written(Milestone.a2),
            written(Milestone.b1),
          ]).builtLevel,
          builtB1,
        );
        // A unit still to be written before A1 keeps A1 from counting.
        expect(
          progress(<B1Unit>[coming(null), written(Milestone.a1)]).builtLevel,
          builtBelowA1,
        );
      },
    );

    test('a path that skips a level mark is built to the highest level '
        'it marks, written to its end', () {
      // A1 and B1 marked, no A2: B1 written is built to B1, so Expert is
      // offered, and B1 not yet written is built to A1.
      expect(
        progress(<B1Unit>[written(Milestone.a1), written(Milestone.b1)])
            .builtLevel,
        builtB1,
      );
      expect(
        progress(<B1Unit>[written(Milestone.a1), coming(Milestone.b1)])
            .builtLevel,
        builtA1,
      );
    });

    test('a path with no level marks is below A1', () {
      expect(progress(<B1Unit>[written(null)]).builtLevel, builtBelowA1);
    });
  });

  group('the skills a tap of Find my level checks', () {
    const speak = SkillKey(SkillKind.speak);
    const hear = SkillKey(SkillKind.hear);
    const readLatin = SkillKey(SkillKind.read, 'latin');
    const writeLatin = SkillKey(SkillKind.write, 'latin');
    final shape = <SkillKey>[speak, hear, readLatin, writeLatin];

    FindLevelSkills pick(
      Map<SkillKey, SkillState> states, {
      Set<String> verified = const <String>{},
      List<String> scripts = const <String>[],
    }) => selectFindLevelSkills(
      (key) => states[key] ?? SkillState.leave,
      shape,
      verified: verified,
      scripts: scripts,
    );

    test('known skills first: "Verify what you know"', () {
      final found = pick(<SkillKey, SkillState>{
        hear: SkillState.know,
        readLatin: SkillState.know,
        speak: SkillState.learn,
      });
      expect(found.verifying, isTrue);
      expect(found.skills, <PlacementSkill>{
        PlacementSkill.hear,
        PlacementSkill.read,
      });
    });

    test('a known skill that is verified is not asked again', () {
      final found = pick(
        <SkillKey, SkillState>{
          hear: SkillState.know,
          readLatin: SkillState.know,
          speak: SkillState.learn,
        },
        verified: <String>{'hear'},
      );
      expect(found.skills, <PlacementSkill>{PlacementSkill.read});
    });

    test('once every known skill is verified: "Fit my level" for the rest', () {
      final found = pick(
        <SkillKey, SkillState>{
          hear: SkillState.know,
          speak: SkillState.learn,
          writeLatin: SkillState.learn,
        },
        verified: <String>{'hear'},
      );
      expect(found.verifying, isFalse);
      expect(found.skills, <PlacementSkill>{
        PlacementSkill.say,
        PlacementSkill.write,
      });
    });

    test('Leave is never checked, and nothing marked gives nothing to '
        'verify', () {
      final found = pick(const <SkillKey, SkillState>{});
      expect(found.skills, isEmpty);
      expect(found.verifying, isFalse);
    });

    test('Hear is left out when there is no voice, and nothing is left when '
        'it was the only skill', () {
      const both = <PlacementSkill>{PlacementSkill.hear, PlacementSkill.read};
      expect(placementSkillsForDevice(both, voice: true), both);
      expect(placementSkillsForDevice(both, voice: false), <PlacementSkill>{
        PlacementSkill.read,
      });
      expect(
        placementSkillsForDevice(<PlacementSkill>{
          PlacementSkill.hear,
        }, voice: false),
        isEmpty,
      );
    });

    test('the read of a script of its own is that script\'s skill too', () {
      final found = selectFindLevelSkills(
        (key) =>
            key.kind == SkillKind.read ? SkillState.know : SkillState.leave,
        const <SkillKey>[
          SkillKey(SkillKind.read, 'devanagari'),
          SkillKey(SkillKind.read, 'perso_arabic'),
        ],
        verified: const <String>{},
        scripts: const <String>['devanagari', 'perso_arabic'],
      );
      expect(found.skills, <PlacementSkill>{
        PlacementSkill.read,
        PlacementSkill.script,
        PlacementSkill.secondScript,
      });
    });
  });

  group('a paused run', () {
    SavedPlacementRun saved({int at = 1000}) => SavedPlacementRun(
      language: 'xx',
      declaration: PlacementDeclaration.advanced,
      skills: const <PlacementSkill>{PlacementSkill.read, PlacementSkill.hear},
      seed: 7,
      microphone: true,
      deckSet: findLevelData().decks.length.toString(),
      appVersion: '0.8.6',
      savedAt: at,
      events: const <String>['a1', 'a0', 'm', 'k'],
    );

    test('is saved as JSON and read back as it was', () {
      final back = SavedPlacementRun.fromJson(saved().toJson())!;
      expect(back.language, 'xx');
      expect(back.declaration, PlacementDeclaration.advanced);
      expect(back.skills, saved().skills);
      expect(back.seed, 7);
      expect(back.microphone, isTrue);
      expect(back.events, <String>['a1', 'a0', 'm', 'k']);
    });

    test('anything that is not a saved run reads as none', () {
      expect(SavedPlacementRun.fromJson('nope'), isNull);
      expect(
        SavedPlacementRun.fromJson(<String, Object?>{'language': 'xx'}),
        isNull,
      );
    });

    test('is resumed within 7 days with the same decks and app version', () {
      final run = saved();
      const week = 7 * 24 * 3600;
      bool fresh(int now, {String? decks, String? version}) => run.isFresh(
        nowSeconds: now,
        deckSet: decks ?? run.deckSet,
        appVersion: version ?? run.appVersion,
      );
      expect(fresh(1000 + week), isTrue);
      expect(fresh(1000 + week + 1), isFalse);
      expect(fresh(1000, decks: 'other'), isFalse);
      expect(fresh(1000, version: '0.9.0'), isFalse);
    });

    test('a corrupt or unknown event is dropped on reading', () {
      final back = SavedPlacementRun.fromJson(<String, Object?>{
        ...saved().toJson(),
        'events': <Object?>['a1', 7, 'zz', 'u', null, 'k'],
      })!;
      expect(back.events, <String>['a1', 'u', 'k']);
      expect(
        SavedPlacementRun.fromJson(<String, Object?>{
          ...saved().toJson(),
          'saved_at': 'yesterday',
        }),
        isNull,
      );
      expect(
        SavedPlacementRun.fromJson(<String, Object?>{
          ...saved().toJson(),
          'declaration': 'master',
        }),
        isNull,
      );
    });

    test('is dropped when the voice or the recogniser it began with is '
        'gone', () {
      final run = saved();
      expect(run.fitsDevice(voice: true, microphone: true), isTrue);
      expect(run.fitsDevice(voice: false, microphone: true), isFalse);
      expect(run.fitsDevice(voice: true, microphone: false), isFalse);
      // A run that did not ask Hear, or used no recogniser, does not need
      // them.
      final quiet = SavedPlacementRun(
        language: 'xx',
        declaration: PlacementDeclaration.advanced,
        skills: const <PlacementSkill>{PlacementSkill.read},
        seed: 7,
        microphone: false,
        deckSet: run.deckSet,
        appVersion: run.appVersion,
        savedAt: 1000,
        events: const <String>[],
      );
      expect(quiet.fitsDevice(voice: false, microphone: false), isTrue);
    });

    test('the deck set changes when a deck, or a known card, does', () {
      final one = placementDeckSetKey(findLevelData());
      expect(placementDeckSetKey(findLevelData()), one);
      expect(
        placementDeckSetKey(findLevelData(stable: <String>{'w-5-0'})),
        isNot(one),
      );
    });
  });

  group('the session drives the run and the question builder', () {
    test('a small course cannot be Verified: a clean run ends below the top '
        'class or at it, never above', () {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      play(session, (_) => true);
      for (final found in session.readout.values) {
        if (found.label == AssuranceLabel.notTested) continue;
        expect(found.isVerified, isFalse);
        expect(found.placedLevel, lessThanOrEqualTo(5));
      }
    });

    test('asks a question first, and a right-answering run ends Verified', () {
      final session = PlacementSession(
        findLevelConfig(decks: 24),
        findLevelData(decks: 24, words: 40),
      );
      expect(session.question, isNotNull);
      expect(session.atCheckpoint, isFalse);
      expect(session.isDone, isFalse);
      play(session, (_) => true);
      expect(session.isDone, isTrue);
      final readout = session.readout;
      for (final skill in <PlacementSkill>[
        PlacementSkill.read,
        PlacementSkill.hear,
        PlacementSkill.write,
      ]) {
        expect(
          readout[skill]!.label.index,
          greaterThanOrEqualTo(AssuranceLabel.verySure.index),
          reason: skill.name,
        );
      }
    });

    test('a language short of B1 is never Verified', () {
      final session = PlacementSession(
        findLevelConfig(verifiable: false),
        findLevelData(),
      );
      play(session, (_) => true);
      expect(session.isDone, isTrue);
      expect(
        session.readout.values.any((a) => a.label == AssuranceLabel.verified),
        isFalse,
      );
    });

    test('"I don\'t know" everywhere never loops, and stops at a checkpoint '
        'when it gets to 25', () {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      var guard = 0;
      while (!session.isDone && guard++ < 300) {
        if (session.atCheckpoint) {
          expect(session.asked % 25, 0);
          expect(session.question, isNull);
          session.keepGoing();
          continue;
        }
        expect(session.question, isNotNull);
        session.answer(false);
      }
      expect(session.isDone, isTrue);
    });

    test('the same events rebuild the same session', () {
      final one = PlacementSession(findLevelConfig(), findLevelData());
      var n = 0;
      play(one, (_) => ++n % 4 != 0, cap: 30);
      final two = PlacementSession.replay(
        findLevelConfig(),
        findLevelData(),
        one.events,
      );
      expect(two.asked, one.asked);
      expect(two.isDone, one.isDone);
      expect(two.question?.cardId, one.question?.cardId);
      expect(
        two.question?.request.toString(),
        one.question?.request.toString(),
      );
      for (final skill in PlacementSkill.values) {
        expect(
          two.readout[skill]?.placedLevel,
          one.readout[skill]?.placedLevel,
          reason: skill.name,
        );
        expect(two.readout[skill]?.label, one.readout[skill]?.label);
      }
    });

    test('giving up the microphone before saying anything turns every '
        'say question into a pick', () {
      final session = PlacementSession(
        findLevelConfig(
          skills: const <PlacementSkill>{
            PlacementSkill.read,
            PlacementSkill.say,
          },
          microphone: true,
        ),
        findLevelData(),
      );
      expect(session.microphone, isTrue);
      expect(session.question!.mode, PlacementAnswerMode.sayEnglish);
      session.dropMicrophone();
      expect(session.microphone, isFalse);
      expect(session.question!.mode, isNot(PlacementAnswerMode.sayEnglish));
      expect(session.asked, 0, reason: 'the question was not answered');
      var guard = 0;
      while (!session.isDone && guard++ < 150) {
        if (session.atCheckpoint) {
          session.keepGoing();
          continue;
        }
        final mode = session.question!.mode;
        expect(mode, isNot(PlacementAnswerMode.say));
        expect(mode, isNot(PlacementAnswerMode.sayEnglish));
        session.answer(true);
      }
      // Say was not asked: it is not tested, never failed.
      expect(
        session.readout[PlacementSkill.say]!.label,
        AssuranceLabel.notTested,
      );
    });

    test('giving up the microphone after an English question was said '
        'skips the rest of the saying instead of rebuilding the run', () {
      final config = findLevelConfig(
        skills: const <PlacementSkill>{PlacementSkill.read, PlacementSkill.say},
        microphone: true,
      );
      final session = PlacementSession(config, findLevelData());
      expect(session.question!.mode, PlacementAnswerMode.sayEnglish);
      session.answer(true);
      session.dropMicrophone();
      expect(session.microphone, isFalse);
      // Not rebuilt without it, which would read the spoken answer again as
      // a pick: the run still begins with the microphone, and later saying
      // is skipped.
      expect(session.config.microphone, isTrue);
      var guard = 0;
      while (!session.isDone && guard++ < 150) {
        if (session.atCheckpoint) {
          session.keepGoing();
          continue;
        }
        final mode = session.question!.mode;
        expect(mode, isNot(PlacementAnswerMode.say));
        expect(mode, isNot(PlacementAnswerMode.sayEnglish));
        session.answer(true);
      }
      final again = PlacementSession.replay(
        config,
        findLevelData(),
        session.events,
      );
      expect(again.asked, session.asked);
      expect(again.isDone, isTrue);
    });

    test('a question whose sound would not play is left out, never a miss, '
        'and is replayed the same', () {
      final config = findLevelConfig(
        skills: const <PlacementSkill>{PlacementSkill.hear},
      );
      final session = PlacementSession(config, findLevelData());
      expect(session.question!.audio, isNotNull);
      session.skipUnplayable();
      expect(session.asked, 0, reason: 'a skipped question is not answered');
      expect(session.events, <String>['u']);
      final again = PlacementSession.replay(
        config,
        findLevelData(),
        session.events,
      );
      expect(again.asked, 0);
      expect(again.isDone, session.isDone);
      expect(again.question?.cardId, session.question?.cardId);
      // Skipping everything never proves Hear, and never fails it.
      var guard = 0;
      while (!session.isDone && guard++ < 150) {
        session.skipUnplayable();
      }
      expect(session.isDone, isTrue);
      expect(session.asked, 0);
      expect(
        session.readout[PlacementSkill.hear]!.label,
        isNot(AssuranceLabel.verified),
      );
    });

    test('giving up the microphone after a word was said skips the rest of '
        'the saying, and is replayed the same', () {
      final config = findLevelConfig(
        skills: const <PlacementSkill>{PlacementSkill.say},
        microphone: true,
        declaration: PlacementDeclaration.expert,
      );
      final session = PlacementSession(config, findLevelData());
      expect(session.question!.mode, PlacementAnswerMode.say);
      session.answer(true);
      expect(session.question!.mode, PlacementAnswerMode.say);
      session.dropMicrophone();
      expect(session.isDone, isTrue, reason: 'only Say was in play');
      expect(session.asked, 1);
      final again = PlacementSession.replay(
        config,
        findLevelData(),
        session.events,
      );
      expect(again.isDone, isTrue);
      expect(again.asked, 1);
      expect(
        session.readout[PlacementSkill.say]!.label,
        isNot(AssuranceLabel.verified),
      );
    });
  });
}
