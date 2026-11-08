// Moving from the placement of 0.9.2 to V3: credit of the model before V3 and
// unstamped credit are unconfirmed (a check again is offered), an earlier
// version's Verified mark reads as an earlier check, the per-skill range is
// kept and read back tolerantly, and the Languages sheet line shows it.
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/placement_check.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/features/placement/skill_labels_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  group('which credit is unconfirmed', () {
    test('V3 and the older placement test are confirmed; the model before V3 '
        'and no stamp are not', () {
      expect(kPlacementModel, 3);
      expect(isConfirmedModel(kPlacementModel), isTrue);
      expect(isConfirmedModel(kOlderPlacementModel), isTrue);
      expect(isConfirmedModel(kV2PlacementModel), isFalse);
      expect(isConfirmedModel(0), isFalse);
    });

    test('a moment stamped with the model before V3 is flagged like an '
        'unstamped one', () {
      const t = kPlacementCheckFrom + 1000;
      final settings = SettingsNotifier()
        ..addPlacedAt('es', t)
        ..addPlacedAt('es', t + 1)
        ..addPlacedAt('es', t + 2)
        ..stampPlacedBy('es', t, kV2PlacementModel)
        ..stampPlacedBy('es', t + 1, kPlacementModel);
      final confirmed = <int>{
        for (final e in settings.placedModelsOf('es').entries)
          if (isConfirmedModel(e.value)) e.key,
      };
      final flagged = unconfirmedMoments(
        placedAt: settings.placedAtOf('es'),
        stamped: confirmed,
        kept: const <int>{},
        live: settings.placedAtOf('es'),
      );
      expect(flagged, <int>{t, t + 2});
    });
  });

  group('the range of each skill', () {
    test('is kept and read back, and what is not a range is skipped', () {
      final settings = SettingsNotifier()
        ..setPlacementRanges('hi', const <String, PlacementRange>{
          'read': PlacementRange(
            start: 14,
            low: 11,
            high: 17,
            label: 'fairlySure',
          ),
        });
      final stored = settings.toStored();
      final again = SettingsNotifier()..restore(stored);
      expect(again.placementRangesOf('hi')['read']!.start, 14);
      expect(again.placementRangesOf('hi')['read']!.high, 17);
      final tolerant = SettingsNotifier()
        ..restore(const <String, String>{
          'skill_ranges':
              '{"hi":{"read":{"start":3,"low":2,"high":5,"label":"sure"},'
              '"hear":{"start":"x"},"say":{"start":1,"low":4,"high":2,'
              '"label":"sure"}},"bad":1}',
        });
      expect(tolerant.placementRangesOf('hi').keys, <String>['read']);
      // A settings map from before ranges existed has none.
      expect(
        (SettingsNotifier()..restore(const <String, String>{}))
            .placementRangesOf('hi'),
        isEmpty,
      );
    });

    test('is dropped with the placement', () {
      final settings = SettingsNotifier()
        ..setPlacementRanges('hi', const <String, PlacementRange>{
          'read': PlacementRange(start: 1, low: 1, high: 1, label: 'sure'),
        })
        ..clearPlacement('hi');
      expect(settings.placementRangesOf('hi'), isEmpty);
    });
  });

  group('the line under a skill row', () {
    testWidgets('shows the unit, the range and the word; an earlier Verified '
        'mark reads as an earlier check', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        const Scaffold(
          body: SkillLabelsLine(
            labels: <PlacementSkill, AssuranceLabel>{
              PlacementSkill.read: AssuranceLabel.fairlySure,
              PlacementSkill.write: AssuranceLabel.verified,
              PlacementSkill.hear: AssuranceLabel.sure,
            },
            ranges: <String, PlacementRange>{
              'read': PlacementRange(
                start: 14,
                low: 11,
                high: 17,
                label: 'fairlySure',
              ),
              'write': PlacementRange(start: 5, low: 3, high: 7, label: 'sure'),
            },
          ),
        ),
      );
      expect(
        find.text('Read: unit 14, likely 11 to 17 · Fairly sure'),
        findsOneWidget,
      );
      expect(find.text('Write: Earlier check (not verified)'), findsOneWidget);
      // An older run's skill has no range: its word alone.
      expect(find.text('Hear: Sure'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);
    });
  });
}
