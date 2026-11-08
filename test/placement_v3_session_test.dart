// The V3 run as the app drives it (build step 7): grading with Unicode
// normalisation, the gate and picker working together, the answers that are
// not evidence, and a paused run rebuilt from its events.
@Timeout(Duration(minutes: 10))
library;

import 'package:fluenough/core/placement/assurance_model.dart'
    show PlacementDeclaration, PlacementLevels;
import 'package:fluenough/core/placement/assurance_readout.dart'
    show AssuranceLabel;
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/saved_run.dart';
import 'package:fluenough/core/placement/saved_v3_run.dart';
import 'package:fluenough/core/placement/script_gate.dart';
import 'package:fluenough/core/placement/v3_grading.dart';
import 'package:fluenough/core/placement/v3_picker.dart'
    show PickerConfig, kUnaskableFormats;
import 'package:fluenough/core/placement/v3_result.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/v3_oracle.dart';
import 'support/v3_small_bank.dart';

RegItem _typed(String format, List<String> accepted, {List<String>? units}) =>
    RegItem(
      id: 'x:$format',
      format: format,
      cardId: 'x',
      deck: 0,
      prompt: 'meaning',
      accepted: accepted,
      answerTiles: units ?? const <String>[],
      gapIndex: format == 'F21' ? 1 : -1,
    );

void main() {
  group('grading', () {
    test(
      'a Devanagari letter typed with a nukta or as one code point is one',
      () {
        final item = _typed(
          'F21',
          <String>['क़'],
          units: <String>['क', 'क़', 'ा'],
        );
        expect(gradeTyped(item, 'क़').name, 'right');
        expect(gradeTyped(item, 'क़').name, 'right');
        // As in a review, a nukta left off is "right, but watch the nukta".
        expect(gradeTyped(item, 'क').name, 'right');
        expect(gradeTyped(item, 'ग').name, 'wrong');
      },
    );

    test(
      'a vowel sign and the zero-width joiner do not change the letters',
      () {
        final item = _typed('F7', <String>['क्षमा']);
        expect(gradeTyped(item, 'क्‍षमा').name, 'right');
        expect(gradeTyped(item, 'कशमा').name, 'wrong');
        // The matra is a letter: another matra is another word.
        expect(gradeTyped(_typed('F7', <String>['कि']), 'की').name, 'wrong');
      },
    );

    test('case, spaces and accents are not spelling mistakes in Latin', () {
      final item = _typed('F7', <String>['el niño']);
      expect(gradeTyped(item, '  El Nino ').name, 'right');
      expect(gradeTyped(item, 'niño').name, 'right');
      expect(gradeTyped(item, 'nina').name, 'wrong');
    });

    test('only a short article is forgiven, never a word of the answer', () {
      final item = _typed('F7', <String>['buenos días']);
      expect(gradeTyped(item, 'días').name, 'wrong');
      expect(gradeTyped(item, 'buenos').name, 'wrong');
      expect(gradeTyped(item, 'buenos dias').name, 'right');
      final bare = _typed('F7', <String>['lunes']);
      expect(gradeTyped(bare, 'el lunes').name, 'right');
      expect(gradeTyped(bare, 'domingo lunes').name, 'wrong');
    });

    test('a whole word typed in a gap item is right as well', () {
      final item = _typed('F21', <String>['ñ'], units: <String>['m', 'ñ', 'a']);
      expect(gradeTyped(item, 'ñ').name, 'right');
      expect(gradeTyped(item, 'N').name, 'right');
      expect(gradeTyped(item, 'maña').name, 'wrong');
      expect(gradeTyped(item, 'mña').name, 'right');
    });

    test('a said answer is right if any alternative is', () {
      final item = _typed('F18', <String>['hola']);
      expect(gradeSaid(item, <String>['ola', 'Hola']).name, 'right');
      expect(gradeSaid(item, <String>['ola']).name, 'wrong');
      expect(gradeSaid(item, const <String>[]).name, 'wrong');
    });
  });

  group('the configuration of a run', () {
    test('the values measured on the script cells apply only after a gate', () {
      final plain = PickerConfig.forRun(
        audio: true,
        mic: true,
        recogniser: false,
      );
      expect(plain.mixedBonus, 0.3);
      expect(plain.standApartItems, 14);
      expect(plain.sayRatingUntilItems, 40);
      expect(plain.maxItems, 40);
      expect(plain.softStopItems, 22);
      final gated = PickerConfig.forRun(
        audio: true,
        mic: true,
        recogniser: false,
        gateItems: 3,
        gateSeconds: 14,
      );
      expect(gated.mixedBonus, 0.4);
      expect(gated.standApartItems, 8);
      expect(gated.sayRatingUntilItems, 24);
      expect(gated.maxItems, 37);
      expect(gated.maxSeconds, 286);
      expect(gated.softStopItems, 19);
    });
  });

  group('a sound that will not play', () {
    test('offers to carry on without it after two in a row, and does', () {
      final run = V3Run(
        data: findLevelData(),
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.hear,
        },
        audio: true,
        recogniser: false,
        seed: 3,
        scriptStart: V3ScriptStart.skip,
        items: smallV3Bank(formats: <String>{'F13', 'F2'}),
      );
      var skips = 0;
      for (var i = 0; i < 100 && !run.finished; i++) {
        if (run.atCheckpoint) run.keepGoing();
        if (run.question!.isHeard) {
          run.skipUnplayable();
          skips++;
          // One failure is not yet an offer; the second in a row is.
          expect(run.offerNoSound, skips >= 2);
          if (run.offerNoSound) break;
        } else {
          run.dontKnow();
          skips = 0;
        }
      }
      expect(run.offerNoSound, isTrue);
      expect(skips, 2);
      var guard = 0;
      run.dropAudio();
      expect(run.audioDropped, isTrue);
      var heardAfter = 0;
      while (!run.finished && guard++ < 200) {
        if (run.atCheckpoint) run.keepGoing();
        if (run.question!.isHeard) heardAfter++;
        run.dontKnow();
      }
      expect(heardAfter, 0);
      expect(
        V3Result.of(run).of(PlacementSkill.hear)!.status,
        V3Status.notTested,
      );
      // And it is the same run when replayed.
      final again = V3Run.replay(
        data: findLevelData(),
        skills: run.wanted,
        audio: true,
        recogniser: false,
        seed: 3,
        scriptStart: V3ScriptStart.skip,
        items: smallV3Bank(formats: <String>{'F13', 'F2'}),
        events: run.events,
      );
      expect(again.events, run.events);
      expect(again.audioDropped, isTrue);
    });
  });

  group('the script credit', () {
    V3Result result(ScriptLevel level, {bool skipped = false}) => V3Result(
      skills: const <V3SkillResult>[],
      levels: PlacementLevels(30, maxParts: 20),
      readout: null,
      script: ScriptGateResult(
        level: level,
        items: 3,
        skipped: skipped,
        posterior: const <ScriptLevel, double>{},
      ),
      items: 3,
      seconds: 10,
      endReason: null,
    );

    test('a learner who passes the letters is credited as reading', () {
      final a = result(ScriptLevel.all).assurances(scripts: 2);
      expect(
        a[PlacementSkill.script]!.placedClass,
        a[PlacementSkill.script]!.leadingClass,
      );
      expect(
        a[PlacementSkill.script]!.placedClass,
        PlacementLevels(30, maxParts: 20).topClass,
      );
      expect(a.containsKey(PlacementSkill.secondScript), isTrue);
      expect(
        result(ScriptLevel.all)
            .assurances(scripts: 1)
            .containsKey(PlacementSkill.secondScript),
        isFalse,
      );
    });

    test('one who fails them is recorded as new to the script', () {
      final a = result(ScriptLevel.none).assurances(scripts: 1);
      expect(a[PlacementSkill.script]!.placedClass, 0);
    });

    test('a skipped or in-between check writes nothing about the script', () {
      expect(result(ScriptLevel.partly).assurances(scripts: 1), isEmpty);
      expect(
        result(ScriptLevel.all, skipped: true).assurances(scripts: 1),
        isEmpty,
      );
      expect(result(ScriptLevel.all).assurances(), isEmpty);
    });

    test('a start changed to the very beginning is still a placement', () {
      final a =
          V3Result(
            skills: const <V3SkillResult>[
              V3SkillResult(
                skill: PlacementSkill.read,
                status: V3Status.placed,
              ),
            ],
            levels: PlacementLevels(30, maxParts: 20),
            readout: null,
            script: null,
            items: 1,
            seconds: 1,
            endReason: null,
          ).assurances(
            overrides: const <PlacementSkill, int>{PlacementSkill.read: 0},
          );
      expect(a[PlacementSkill.read]!.label, isNot(AssuranceLabel.notTested));
      expect(a[PlacementSkill.read]!.placedLevel, -1);
    });
  });

  group('a run begun on the first formats only', () {
    V3Run begin({List<RegItem>? full, Iterable<String> events = const []}) {
      final items = smallV3Bank();
      return V3Run.replay(
        data: findLevelData(),
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
        },
        audio: false,
        recogniser: false,
        seed: 6,
        scriptStart: V3ScriptStart.skip,
        startedWithStarter: true,
        fullItems: full ?? items,
        items: ItemBank.starterOf(items),
        events: events,
      );
    }

    test('changes to the whole bank once, and a replay does the same at the '
        'same place', () {
      final run = begin();
      for (var i = 0; i < 3; i++) {
        run.dontKnow();
      }
      run.extendItems(smallV3Bank());
      run.extendItems(smallV3Bank());
      for (var i = 0; i < 3 && !run.finished; i++) {
        run.dontKnow();
      }
      expect(run.events.where((e) => e == 'x'), hasLength(1));
      expect(run.events.indexOf('x'), 3);
      final again = begin(events: run.events);
      expect(again.events, run.events);
      expect(again.question?.id, run.question?.id);
    });

    test('the starter is the clean items of the first formats', () {
      final all = smallV3Bank();
      final starter = ItemBank.starterOf(all);
      expect(starter.map((i) => i.format).toSet(), <String>{
        'F2',
        'F13',
        'F7',
        'F8',
      });
      expect(starter.length, lessThan(all.length));
    });
  });

  group('a paused run', () {
    SavedV3Run saved() => const SavedV3Run(
      language: 'es',
      declaration: PlacementDeclaration.amateur,
      skills: <PlacementSkill>{PlacementSkill.read, PlacementSkill.write},
      seed: 12,
      audio: true,
      recogniser: false,
      scriptStart: V3ScriptStart.skip,
      starter: true,
      deckSet: '4-abc',
      appVersion: '1.0.0',
      savedAt: 1000,
      events: <String>['r', 'w', 'd', 'k'],
    );

    test('is saved and read back', () {
      final again = SavedV3Run.fromJson(saved().toJson())!;
      expect(again.events, <String>['r', 'w', 'd', 'k']);
      expect(again.scriptStart, V3ScriptStart.skip);
      expect(again.starter, isTrue);
      expect(again.declaration, PlacementDeclaration.amateur);
      expect(again.skills, saved().skills);
    });

    test('is never misread as a V2 run, nor a V2 run as it', () {
      expect(SavedPlacementRun.fromJson(saved().toJson()), isNull);
      expect(
        SavedV3Run.fromJson(<String, Object?>{
          'language': 'es',
          'declaration': 'amateur',
          'skills': <String>['read'],
          'seed': 1,
          'microphone': false,
          'deck_set': 'x',
          'app_version': '1',
          'saved_at': 1,
          'events': <String>['a1'],
        }),
        isNull,
      );
      expect(SavedV3Run.fromJson('nonsense'), isNull);
    });

    test('is fresh for a week on the same decks and version only', () {
      final run = saved();
      bool fresh(
        int now, {
        String deckSet = '4-abc',
        String version = '1.0.0',
      }) => run.isFresh(nowSeconds: now, deckSet: deckSet, appVersion: version);
      expect(fresh(1000 + 6 * 86400), isTrue);
      expect(fresh(1000 + 8 * 86400), isFalse);
      expect(fresh(1000, deckSet: 'other'), isFalse);
      expect(fresh(1000, version: '1.0.1'), isFalse);
      expect(run.fitsDevice(audio: false, recogniser: false), isFalse);
      expect(run.fitsDevice(audio: true, recogniser: false), isTrue);
    });
  });

  group('a run over the Spanish bank', () {
    late PlacementLanguageData data;
    late ItemBank bank;
    setUpAll(() {
      data = loadData('es');
      bank = ItemBank.build(data);
    });

    V3Run begin({int seed = 7}) => V3Run(
      data: data,
      skills: const <PlacementSkill>{
        PlacementSkill.read,
        PlacementSkill.hear,
        PlacementSkill.say,
        PlacementSkill.write,
      },
      audio: true,
      recogniser: false,
      seed: seed,
      items: bank.items,
    );

    test('ends inside the caps, asks no unaskable format, and places', () {
      final run = begin();
      final formats = <String>{};
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.keepGoing();
          continue;
        }
        formats.add(run.question!.format);
        answerV3(run, 40);
      }
      expect(run.finished, isTrue);
      expect(run.answered, lessThanOrEqualTo(40));
      expect(formats.intersection(kUnaskableFormats), isEmpty);
      final result = V3Result.of(run);
      expect(result.of(PlacementSkill.read)!.placed, isTrue);
      expect(result.of(PlacementSkill.say)!.status, V3Status.selfRated);
      // A learner who knows 40 decks is not placed at the beginning.
      expect(result.of(PlacementSkill.read)!.startUnit, greaterThan(5));
    });

    test('a beginner is placed low', () {
      final run = begin(seed: 3);
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        answerV3(run, -1);
      }
      final read = V3Result.of(run).of(PlacementSkill.read)!;
      expect(read.startUnit, lessThanOrEqualTo(4));
    });

    test('a run rebuilt from its events is the same run', () {
      final run = begin(seed: 11);
      for (var i = 0; i < 9 && !run.finished; i++) {
        if (run.atCheckpoint) break;
        if (i == 4) {
          run.dontKnow();
        } else {
          answerV3(run, 15);
        }
      }
      final again = V3Run.replay(
        data: data,
        skills: run.wanted,
        audio: true,
        recogniser: false,
        seed: 11,
        events: run.events,
        items: bank.items,
      );
      expect(again.events, run.events);
      expect(again.question?.id, run.question?.id);
      expect(again.answered, run.answered);
    });

    test('an unplayable question is left out, never a miss', () {
      final run = begin(seed: 5);
      while (run.question!.audio == null) {
        answerV3(run, 15);
      }
      final before = run.model!.readout().skills[PlacementSkill.hear];
      final touches = run.model!.touchesOf(PlacementSkill.hear);
      run.skipUnplayable();
      expect(run.model!.touchesOf(PlacementSkill.hear), touches);
      expect(before, isNotNull);
    });

    test('giving the microphone up never ends the run', () {
      final run = V3Run(
        data: data,
        skills: const <PlacementSkill>{PlacementSkill.read, PlacementSkill.say},
        audio: true,
        recogniser: true,
        seed: 2,
        items: bank.items,
      );
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        if (run.question!.mode == V3Mode.say) {
          run.giveUpMicrophone();
        } else {
          answerV3(run, 20);
        }
      }
      expect(run.finished, isTrue);
      expect(run.microphoneGivenUp, isTrue);
    });
  });

  group('a run over the Hindustani bank, with its script gate', () {
    late PlacementLanguageData data;
    late ItemBank bank;
    setUpAll(() {
      data = hindustaniWithScript();
      bank = ItemBank.build(data);
    });

    V3Run begin(V3ScriptStart start, {int seed = 4}) => V3Run(
      data: data,
      skills: const <PlacementSkill>{
        PlacementSkill.read,
        PlacementSkill.hear,
        PlacementSkill.write,
      },
      audio: true,
      recogniser: false,
      seed: seed,
      scriptStart: start,
      items: bank.items,
    );

    test('a learner who cannot read the script needs it first', () {
      final run = begin(V3ScriptStart.ask);
      expect(run.question!.script, isTrue);
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        answerV3(run, 40, readsScript: false);
      }
      final result = V3Result.of(run);
      expect(result.script!.level, ScriptLevel.none);
      expect(result.of(PlacementSkill.read)!.status, V3Status.needsScript);
      expect(result.of(PlacementSkill.write)!.status, V3Status.needsScript);
      expect(result.of(PlacementSkill.hear)!.placed, isTrue);
      expect(result.needsScript, isTrue);
    });

    test('"I do read it" skips the gate and places Read', () {
      final run = begin(V3ScriptStart.skip);
      expect(run.question!.script, isFalse);
      var guard = 0;
      while (!run.finished && guard++ < 100) {
        if (run.atCheckpoint) {
          run.stop();
          continue;
        }
        answerV3(run, 40);
      }
      expect(V3Result.of(run).of(PlacementSkill.read)!.placed, isTrue);
    });
  });
}
