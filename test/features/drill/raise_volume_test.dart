import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/volume_monitor.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';

import '../../support/harness.dart';

/// A phone at zero volume (ADR-0026): a question that needs sound is greyed
/// out and asks, on the card, for the volume to be raised.

const String hindi = 'hi-en-first-words';

Future<AppState> pumpHeard(
  WidgetTester tester,
  FixedVolumeMonitor volume, {
  Ask ask = Ask.hearAndChoose,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(hindi, skill: Skill.listening),
    preset: DrillPreset(target: 'नमस्कार', ask: ask),
  ),
  state: AppState.test(tts: FixedTtsEngine(<String>{'hi'}), volume: volume),
);

Future<AppState> pumpPassage(
  WidgetTester tester,
  Skill skill,
  FixedVolumeMonitor volume,
) => pumpScreen(
  tester,
  DrillPage(request: DrillRequest.untaught(readingFixtureDeckId, skill: skill)),
  state: AppState.test(
    decks: readingFixtureDecks(),
    tts: FixedTtsEngine(<String>{'bn'}),
    volume: volume,
  ),
);

void main() {
  testWidgets('a heard question asks for the volume while the phone is at '
      'zero, and is asked as usual once it is raised', (tester) async {
    usePhone(tester);
    final volume = FixedVolumeMonitor(muted: true);
    await pumpHeard(tester, volume);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillRaiseVolume), findsOneWidget);
    expect(find.text(l10n.drillChooseHeard), findsOneWidget);

    volume.muted = false;
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillRaiseVolume), findsNothing);
    expect(find.text(l10n.drillChooseHeard), findsOneWidget);
  });

  testWidgets('a typed listening card asks for it too', (tester) async {
    usePhone(tester);
    await pumpHeard(tester, FixedVolumeMonitor(muted: true), ask: Ask.own);
    expect(find.text(l10nOf(tester).drillRaiseVolume), findsOneWidget);
  });

  testWidgets('a heard passage asks for it', (tester) async {
    usePhone(tester);
    final volume = FixedVolumeMonitor(muted: true);
    await pumpPassage(tester, Skill.listening, volume);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillRaiseVolume), findsOneWidget);
    volume.muted = false;
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillRaiseVolume), findsNothing);
  });

  testWidgets('a read passage does not', (tester) async {
    usePhone(tester);
    await pumpPassage(tester, Skill.reading, FixedVolumeMonitor(muted: true));
    expect(find.text(l10nOf(tester).drillRaiseVolume), findsNothing);
  });

  testWidgets('a minimal pair asks for it until a sound is picked', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const PairDrill(),
      state: AppState.test(
        features: FeatureRegistry.all(),
        tts: FixedTtsEngine(const <String>{'hi'}),
        volume: FixedVolumeMonitor(muted: true),
      ),
    );
    expect(find.text(l10nOf(tester).drillRaiseVolume), findsOneWidget);
  });

  testWidgets('with the volume up, nothing is asked', (tester) async {
    usePhone(tester);
    await pumpHeard(tester, FixedVolumeMonitor());
    expect(find.text(l10nOf(tester).drillRaiseVolume), findsNothing);
  });

  test('with sound off in the app, a muted phone asks for nothing: the '
      'questions are skipped instead', () async {
    final state = AppState.test(
      tts: FixedTtsEngine(<String>{'hi'}),
      volume: FixedVolumeMonitor(muted: true),
    );
    await state.load();
    expect(state.needsVolume, isTrue);
    state.settings.soundOn = false;
    expect(state.needsVolume, isFalse);
  });
}
