// The automatic correction of Find my level is off: recording signals again
// and again never changes a language's carefulness (wiki/Plan-Placement-V3.md,
// "Step 8b").
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement_outcomes.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/placement/outcome_log.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _Plan implements PlacementRunPlan {
  @override
  List<DeckEntry> get decks => const <DeckEntry>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'refreshing the signals again and again never moves the carefulness',
    () {
      expect(kAutoCorrectPlacement, isFalse);
      final app = AppState(
        catalog: DeckCatalog(MemoryDeckSource(const <String, String>{})),
        progress: MemoryProgress(),
        tts: const NullTtsEngine(),
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      app.settings.setPlacementOutcomes('es', <PlacementOutcome>[
        for (var i = 0; i < 300; i++)
          PlacementOutcome(
            language: 'es',
            day: i,
            profileVersion: 1,
            band: 'A1',
            skills: const <String, SkillOutcome>{
              'read': SkillOutcome(
                start: 14,
                low: 11,
                high: 17,
                label: 'fairlySure',
              ),
            },
            signals: const <String, String>{'read': 'tooHigh'},
          ),
      ]);
      final before = app.settings.placementCorrectionOf('es');
      for (var i = 0; i < 5; i++) {
        app.refreshPlacementSignals('es', _Plan());
      }
      expect(app.settings.placementCorrectionOf('es'), before);
    },
  );
}
