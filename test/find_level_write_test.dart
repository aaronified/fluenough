// What a Find my level run writes at its end (wiki/Plan-Placement-V2.md,
// section 5.5): each skill credited up to its own placed level through the
// existing placement credit, the Verified mark kept per skill, and a skill
// that was not tested left alone.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/placement_credit.dart';
import 'package:fluenough/app/placement_run_setup.dart';
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
      var credited = 0;
      for (final MapEntry(:key, :value) in modes.entries) {
        final found = readout[key]!;
        if (found.label == AssuranceLabel.notTested || found.placedLevel < 0) {
          continue;
        }
        credited++;
        final first = plan.decks.first;
        expect(
          first.cards.any((c) => state.progress.stateOf(c.id, value) != null),
          isTrue,
          reason: '${key.name} credits the first deck',
        );
      }
      expect(credited, greaterThan(0), reason: 'a clean run places a skill');
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

    test('never changes a skill\'s Leave, Know or Learn', () {
      final before = state.settings.languageSkillsOf('hi');
      final session = finishedRun(<PlacementSkill>{PlacementSkill.read}, true);
      state.writePlacementRun('hi', plan, session.run);
      expect(state.settings.languageSkillsOf('hi'), before);
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
