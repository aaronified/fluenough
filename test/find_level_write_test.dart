// What a Find my level run writes at its end (wiki/Plan-Placement-V2.md,
// section 5.5): each skill credited up to its own placed level through the
// existing placement credit, the Verified mark kept per skill, and a skill
// that was not tested left alone.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/placement_credit.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppState state;
  late PlacementRunPlan plan;

  setUp(() async {
    state = AppState.test();
    await state.load();
    plan = state.placementRunPlan('hi')!;
  });
  tearDown(() => state.dispose());

  PlacementSession finishedRun(Set<PlacementSkill> skills, bool right) {
    final session = PlacementSession(
      PlacementRunConfig(
        deckCount: plan.data.deckCount,
        skills: skills,
        declaration: PlacementDeclaration.expert,
        pathCompleteToB1: true,
        allDecksDownloaded: true,
        microphone: false,
      ),
      plan.data,
    );
    var guard = 0;
    while (!session.isDone && guard++ < 200) {
      if (session.atCheckpoint) {
        session.keepGoing();
      } else {
        session.answer(right);
      }
    }
    expect(session.isDone, isTrue);
    return session;
  }

  group('the course a run reads', () {
    test('is the word decks up to the unit marked B1, in path order', () {
      final all = state.walkDecks('hi');
      expect(plan.decks, isNotEmpty);
      expect(plan.decks.length, lessThanOrEqualTo(all.length));
      expect(plan.decks.first.id, all.first.id);
      expect(plan.data.deckCount, plan.decks.length);
      expect(
        <String>[for (final d in plan.data.decks) d.id],
        <String>[for (final d in plan.decks) d.id],
      );
    });

    test('marks where A1, A2 and B1 end, ascending', () {
      final marks = plan.data.levelMarkDecks;
      expect(marks, isNotEmpty);
      expect(marks, orderedEquals(<int>[...marks]..sort()));
      // B1 ends the course the run reads.
      expect(marks.last, plan.data.deckCount - 1);
    });

    test('knows the grammar units of the path', () {
      expect(plan.data.decks.any((d) => d.isGrammar), isTrue);
    });
  });

  group('the end of a run', () {
    test('credits each skill up to its placed level, in its own drills, and '
        'marks the skills that were Verified', () {
      final session = finishedRun(<PlacementSkill>{
        PlacementSkill.read,
        PlacementSkill.write,
      }, true);
      final readout = session.run.readout;
      state.writePlacementRun('hi', plan, session.run);

      final modes = <PlacementSkill, DrillMode>{
        PlacementSkill.read: DrillMode.recognition,
        PlacementSkill.write: DrillMode.production,
      };
      for (final MapEntry(:key, :value) in modes.entries) {
        final found = readout[key]!;
        // A clean run tests each skill and places it past the first deck:
        // nothing here is skipped, so a write that credits nothing fails.
        expect(found.label, isNot(AssuranceLabel.notTested), reason: key.name);
        expect(found.placedLevel, greaterThanOrEqualTo(0), reason: key.name);
        final first = plan.decks.first;
        expect(
          first.cards.any((c) => state.progress.stateOf(c.id, value) != null),
          isTrue,
          reason: '${key.name} credits the first deck',
        );
      }
      expect(state.settings.verifiedSkillsOf('hi'), <String>{
        for (final skill in <PlacementSkill>[
          PlacementSkill.read,
          PlacementSkill.write,
        ])
          if (readout[skill]!.isVerified) skill.name,
      });
      expect(state.settings.placedDecks, contains(plan.decks.first.id));
      expect(state.levelFound('hi'), isTrue);
    });

    test('a skill is credited in its own drills only', () {
      final first = plan.decks.first;
      final written = state.creditPlacement(
        'hi',
        placed: <String>{first.id},
        only: const <DrillMode>{DrillMode.listening},
      );
      expect(written, greaterThan(0));
      for (final card in first.cards) {
        expect(
          state.progress.stateOf(card.id, DrillMode.recognition),
          isNull,
          reason: card.id,
        );
        expect(state.progress.stateOf(card.id, DrillMode.production), isNull);
      }
      expect(
        first.cards.any(
          (c) => state.progress.stateOf(c.id, DrillMode.listening) != null,
        ),
        isTrue,
      );
    });

    test('a skill placed at none is credited nothing, and one the run did not '
        'test keeps its mark', () {
      state.settings.setVerifiedSkills('hi', <String>{'say'});
      final session = finishedRun(<PlacementSkill>{PlacementSkill.read}, false);
      state.writePlacementRun('hi', plan, session.run);
      // Read was tested and not Verified; Say was not in the run.
      expect(state.settings.verifiedSkillsOf('hi'), <String>{'say'});
      expect(state.settings.placedDecks, isEmpty);
      // Its label is kept for the sheet's row, and Say has none.
      expect(state.settings.skillLabelsOf('hi').keys, <String>['read']);
    });

    test('credit an earlier run gave survives a later run that places the '
        'skill lower', () {
      final first = plan.decks.first;
      state.writePlacementRun(
        'hi',
        plan,
        finishedRun(<PlacementSkill>{PlacementSkill.read}, true).run,
      );
      bool credited() => first.cards.any(
        (c) => state.progress.stateOf(c.id, DrillMode.recognition) != null,
      );
      expect(credited(), isTrue, reason: 'the first run credits Read');
      expect(state.settings.placedDecks, contains(first.id));
      final reviews = <String, Object?>{
        for (final c in first.cards)
          c.id: state.progress.stateOf(c.id, DrillMode.recognition),
      };

      // Not one right answer: Read is now placed at the beginning.
      state.writePlacementRun(
        'hi',
        plan,
        finishedRun(<PlacementSkill>{PlacementSkill.read}, false).run,
      );
      expect(credited(), isTrue);
      expect(state.settings.placedDecks, contains(first.id));
      for (final c in first.cards) {
        expect(
          state.progress.stateOf(c.id, DrillMode.recognition),
          reviews[c.id],
          reason: '${c.id} keeps its review',
        );
      }
    });

    test('a learner who has not learned the alphabet keeps the script '
        'lessons and the placed-review choice as they were', () {
      state.settings.setLearnsAlphabet('hi', false);
      final review = state.settings.placedReviewOf('hi');
      final skipped = state.scriptLessonsSkipped('hi', native: 'en');
      state.writePlacementRun(
        'hi',
        plan,
        finishedRun(<PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
        }, true).run,
      );
      expect(state.settings.learnsAlphabet('hi'), isFalse);
      expect(state.settings.placedReviewOf('hi'), review);
      expect(state.scriptLessonsSkipped('hi', native: 'en'), skipped);
      final lessons = <String>{
        for (final entry in state.scriptLessons('hi', native: 'en')) entry.id,
      };
      expect(state.settings.placedDecks.intersection(lessons), isEmpty);
    });

    test('never changes a skill\'s Leave, Know or Learn', () {
      final before = state.settings.languageSkillsOf('hi');
      final session = finishedRun(<PlacementSkill>{PlacementSkill.read}, true);
      state.writePlacementRun('hi', plan, session.run);
      expect(state.settings.languageSkillsOf('hi'), before);
    });
  });

  group('the paused run', () {
    PlacementRunConfig config() => PlacementRunConfig(
      deckCount: plan.data.deckCount,
      skills: const <PlacementSkill>{PlacementSkill.read},
      declaration: PlacementDeclaration.expert,
      pathCompleteToB1: true,
      allDecksDownloaded: true,
      microphone: false,
    );

    test('is dropped once the outcome is written', () {
      state.settings.setPlacementRun('hi', '{"events":[]}');
      final session = finishedRun(<PlacementSkill>{PlacementSkill.read}, true);
      state.writePlacementRun('hi', plan, session.run);
      expect(state.settings.placementRunOf('hi'), isNull);
    });

    test('is kept when the write throws', () {
      state.settings.setPlacementRun('hi', '{"events":[]}');
      expect(
        () => state.writePlacementRun('hi', plan, _BrokenRun(config())),
        throwsStateError,
      );
      expect(state.settings.placementRunOf('hi'), '{"events":[]}');
    });
  });

  group('what is read back from the stored settings', () {
    Map<String, String> stored(String verified, String runs) =>
        <String, String>{'verified_skills': verified, 'placement_runs': runs};

    test('keeps what is well formed and ignores the rest', () {
      final settings = SettingsNotifier()
        ..restore(
          stored(
            '{"hi":["read",3,"bad name!","hear"],"HIN":["read"],'
                '"bn":"read","de":[]}',
            '{"hi":"{\\"events\\":[]}","bn":5,"BAD":"x"}',
          ),
        );
      expect(settings.verifiedSkillsOf('hi'), <String>{'read', 'hear'});
      expect(settings.verifiedSkillsOf('bn'), isEmpty);
      expect(settings.verifiedSkillsOf('de'), isEmpty);
      expect(settings.placementRunOf('hi'), '{"events":[]}');
      expect(settings.placementRunOf('bn'), isNull);
    });

    test('a value that is not a map, or not JSON, changes nothing', () {
      final settings = SettingsNotifier()
        ..setVerifiedSkills('hi', <String>{'read'})
        ..setPlacementRun('hi', 'run');
      settings.restore(stored('[1,2]', 'not json'));
      expect(settings.verifiedSkillsOf('hi'), <String>{'read'});
      expect(settings.placementRunOf('hi'), 'run');
      settings.restore(stored('"read"', '{'));
      expect(settings.verifiedSkillsOf('hi'), <String>{'read'});
      expect(settings.placementRunOf('hi'), 'run');
    });

    test('settings saved before Find my level had them restore without '
        'either', () {
      final settings = SettingsNotifier()..restore(const <String, String>{});
      expect(settings.verifiedSkillsOf('hi'), isEmpty);
      expect(settings.placementRunOf('hi'), isNull);
    });
  });

  group('what is kept', () {
    test('Verified marks and a paused run are in the stored settings', () {
      state.settings
        ..setVerifiedSkills('hi', <String>{'read', 'hear'})
        ..setPlacementRun('hi', '{"events":[]}');
      final stored = state.settings.toStored();
      expect(stored['verified_skills'], '{"hi":["hear","read"]}');
      expect(stored['placement_runs'], '{"hi":"{\\"events\\":[]}"}');
      state.settings
        ..setVerifiedSkills('hi', <String>{})
        ..setPlacementRun('hi', null);
      expect(state.settings.toStored()['verified_skills'], '{}');
      expect(state.settings.toStored()['placement_runs'], '{}');
    });
  });
}

/// A run whose outcome cannot be read, as a write that fails part-way.
class _BrokenRun extends PlacementRun {
  _BrokenRun(super.config);

  @override
  Map<PlacementSkill, SkillAssurance> get readout =>
      throw StateError('the outcome cannot be read');
}
