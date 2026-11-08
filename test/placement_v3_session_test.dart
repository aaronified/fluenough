// The V3 run as the app drives it (build step 7): grading with Unicode
// normalisation, the gate and picker working together, the answers that are
// not evidence, and a paused run rebuilt from its events.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/assurance_model.dart'
    show PlacementDeclaration;
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
import 'package:yaml/yaml.dart';

PlacementLanguageData _data(String language) {
  final files = <String, String>{};
  for (final e in Directory('decks/$language').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.yaml')) {
      files[e.path.substring('decks/'.length)] = e.readAsStringSync();
    }
  }
  return loadPlacementCourse(files, language: language).data;
}

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

/// A learner who knows every item up to deck [known] and answers right on
/// those, wrong on the others.
void _answer(V3Run run, int known, {bool readsScript = true}) {
  final q = run.question!;
  final gate = q.gateItem;
  if (gate != null) {
    return readsScript
        ? run.answerPick(gate.correct)
        : run.answerPick((gate.correct + 1) % 4);
  }
  final item = q.item!;
  final right = item.deck <= known;
  switch (q.mode) {
    case V3Mode.pick:
      run.answerPick(
        right ? item.correct : (item.correct + 1) % item.options.length,
      );
    case V3Mode.tiles:
      final order = <int>[];
      final used = <int>{};
      for (final t in item.answerTiles) {
        final i = List<int>.generate(
          item.tiles.length,
          (i) => i,
        ).firstWhere((i) => !used.contains(i) && item.tiles[i] == t);
        used.add(i);
        order.add(i);
      }
      run.answerTiles(right ? order : order.reversed.toList());
    case V3Mode.type:
      run.answerTyped(right ? item.accepted.first : 'qqq');
    case V3Mode.gap:
      run.answerTyped(right ? item.accepted.first : 'qqq');
    case V3Mode.yesNo:
      run.answerYesNo(yes: !item.pseudo && right);
    case V3Mode.say:
      run.answerSaid(right ? <String>[item.accepted.first] : <String>['qqq']);
    case V3Mode.rateSay:
      run.answerRated(good: right);
  }
}

/// The Hindustani data with its Devanagari letters, as the app gives them
/// ([PlacementScriptData] is read from the script decks by the app).
PlacementLanguageData _hindustani() {
  final base = _data('hi');
  List<Card> read(String name) {
    final doc = loadYaml(File('decks/hi/$name.yaml').readAsStringSync());
    return <Card>[
      for (final (i, c) in ((doc as YamlMap)['cards'] as YamlList).indexed)
        Card(
          id: '$name-$i',
          deckId: name,
          target: (c as YamlMap)['target'] as String,
          native: '',
          reading: c['reading'] as String?,
        ),
    ];
  }

  return PlacementLanguageData(
    language: base.language,
    decks: base.decks,
    sounds: base.sounds,
    levelMarkDecks: base.levelMarkDecks,
    scripts: <PlacementScriptData>[
      PlacementScriptData(
        script: 'devanagari',
        letters: <Card>[
          ...read('hi-script-vowels'),
          ...read('hi-script-consonants'),
        ],
        joined: <Card>[
          ...read('hi-script-vowel-signs'),
          ...read('hi-script-conjuncts'),
        ],
      ),
    ],
  );
}

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

  group('a paused run', () {
    SavedV3Run saved() => const SavedV3Run(
      language: 'es',
      declaration: PlacementDeclaration.amateur,
      skills: <PlacementSkill>{PlacementSkill.read, PlacementSkill.write},
      seed: 12,
      audio: true,
      recogniser: false,
      scriptStart: V3ScriptStart.skip,
      deckSet: '4-abc',
      appVersion: '1.0.0',
      savedAt: 1000,
      events: <String>['r', 'w', 'd', 'k'],
    );

    test('is saved and read back', () {
      final again = SavedV3Run.fromJson(saved().toJson())!;
      expect(again.events, <String>['r', 'w', 'd', 'k']);
      expect(again.scriptStart, V3ScriptStart.skip);
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
      data = _data('es');
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
        _answer(run, 40);
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
        _answer(run, -1);
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
          _answer(run, 15);
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
        _answer(run, 15);
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
          _answer(run, 20);
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
      data = _hindustani();
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
        _answer(run, 40, readsScript: false);
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
        _answer(run, 40);
      }
      expect(V3Result.of(run).of(PlacementSkill.read)!.placed, isTrue);
    });
  });
}
