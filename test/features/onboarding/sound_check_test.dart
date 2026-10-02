import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/onboarding/sound_check_step.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';

import '../../support/harness.dart';

/// The first launch's microphone and sound check (#89): record two seconds,
/// play them back, and keep speaking or listening off where either failed.

void main() {
  setUp(rootBundle.clear);

  final choices = parseSpokenLanguages(
    File(SpokenLanguagesPage.asset).readAsStringSync(),
  );

  /// A first launch at the sound check, on [sound] and a recogniser that
  /// hears Spanish (or none, with [recogniser] false).
  Future<AppState> atSoundCheck(
    WidgetTester tester,
    FixedSoundCheck sound, {
    bool recogniser = true,
  }) async {
    usePhone(tester);
    final settings = SettingsNotifier();
    addTearDown(settings.dispose);
    final state = AppState.test(
      settings: settings,
      soundCheck: sound,
      speech: recogniser
          ? FixedSpeechEngine(onDevice: <String>{'es'})
          : FixedSpeechEngine(),
    );
    await pumpScreen(
      tester,
      OnboardingFlow(startAt: 'sound', choices: choices),
      state: state,
    );
    return state;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // At a large text size the check starts below the fold.
    final check = find.descendant(
      of: find.byType(SoundCheckContent),
      matching: find.byType(Scrollable),
    );
    if (finder.evaluate().isEmpty && check.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(finder, 120, scrollable: check.first);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> record(WidgetTester tester) =>
      tap(tester, find.bySemanticsLabel(l10nOf(tester).onboardingSoundRecord));

  /// Goes on to the languages question, picks English and saves.
  Future<void> finish(WidgetTester tester) async {
    final l10n = l10nOf(tester);
    await tap(tester, find.text(l10n.onboardingNext));
    await tap(tester, find.text(l10n.spokenOption('English', 'English')));
    await tap(tester, find.text(l10n.commonContinue));
  }

  group('the recording', () {
    test('is wrapped as WAV, and silence is told from sound', () {
      final pcm = Uint8List(8);
      ByteData.sublistView(pcm).setInt16(2, 16384, Endian.little);
      final wav = wavFromPcm16(pcm, sampleRate: 16000);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final header = ByteData.sublistView(wav);
      expect(header.getUint32(4, Endian.little), 36 + 8);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(28, Endian.little), 32000);
      expect(header.getUint32(40, Endian.little), 8);
      expect(wav.length, 44 + 8);
      expect(peakOfPcm16(pcm), 0.5);
      expect(peakOfPcm16(Uint8List(8)), 0);
    });

    test('a beep stands in when there is nothing to play back', () {
      final tone = tonePcm16(
        duration: const Duration(milliseconds: 500),
        sampleRate: 16000,
      );
      expect(tone.length, 16000);
      expect(peakOfPcm16(tone), closeTo(0.3, 0.01));
      expect(beep().ok, isTrue);
    });
  });

  testWidgets('it asks for the microphone only when Record is tapped', (
    tester,
  ) async {
    final sound = FixedSoundCheck();
    await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.onboardingSoundTitle), findsOneWidget);
    expect(sound.recordings, 0);
    await record(tester);
    expect(sound.recordings, 1);
  });

  testWidgets('heard: speaking and listening are both switched on', (
    tester,
  ) async {
    final sound = FixedSoundCheck();
    final state = await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    expect(sound.playbacks, 1);
    expect(find.text(l10n.onboardingSoundHeardYou), findsOneWidget);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    expect(find.text(l10n.onboardingSoundSpeakingOn), findsOneWidget);
    expect(find.text(l10n.onboardingSoundListeningOn), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
    expect(
      state.settings.isEnabled(Skill.speaking),
      isFalse,
      reason: 'nothing is saved before the last step',
    );
    await finish(tester);
    expect(state.settings.isEnabled(Skill.speaking), isTrue);
    expect(state.settings.isEnabled(Skill.listening), isTrue);
  });

  testWidgets('refused: speaking stays off, and Try again asks once more', (
    tester,
  ) async {
    final sound = FixedSoundCheck(grants: false);
    final state = await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    // Nothing recorded, so a beep tests the sound.
    expect(find.text(l10n.onboardingSoundHeardBeep), findsOneWidget);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    expect(find.text(l10n.onboardingSoundRefused), findsOneWidget);
    expect(find.text(l10n.onboardingSoundListeningOn), findsOneWidget);

    sound.grants = true;
    await tap(tester, find.text(l10n.commonRetry));
    expect(sound.recordings, 2, reason: 'asked again');
    expect(find.text(l10n.onboardingSoundHeardYou), findsOneWidget);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    expect(find.text(l10n.onboardingSoundSpeakingOn), findsOneWidget);
    await finish(tester);
    expect(state.settings.isEnabled(Skill.speaking), isTrue);
  });

  testWidgets('refused for good: speaking is saved off', (tester) async {
    final sound = FixedSoundCheck(grants: false);
    final state = await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    await finish(tester);
    expect(state.settings.isEnabled(Skill.speaking), isFalse);
    expect(state.settings.isEnabled(Skill.listening), isTrue);
  });

  testWidgets('silence: speaking stays off, and says why', (tester) async {
    final sound = FixedSoundCheck(records: RecordFailure.silent);
    await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    expect(find.text(l10n.onboardingSoundSilent), findsOneWidget);
  });

  testWidgets('no recogniser: speaking stays off though the microphone works', (
    tester,
  ) async {
    final sound = FixedSoundCheck();
    final state = await atSoundCheck(tester, sound, recogniser: false);
    final l10n = l10nOf(tester);
    await record(tester);
    await tap(tester, find.text(l10n.onboardingSoundYes));
    expect(find.text(l10n.onboardingSoundNoRecogniser), findsOneWidget);
    await finish(tester);
    expect(state.settings.isEnabled(Skill.speaking), isFalse);
  });

  testWidgets('not heard: listening is saved off', (tester) async {
    final sound = FixedSoundCheck();
    final state = await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    await tap(tester, find.text(l10n.onboardingSoundNo));
    expect(find.text(l10n.onboardingSoundListeningOff), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
    await finish(tester);
    expect(state.settings.isEnabled(Skill.listening), isFalse);
    expect(state.settings.isEnabled(Skill.speaking), isTrue);
  });

  testWidgets('playback failing: listening stays off without asking', (
    tester,
  ) async {
    final sound = FixedSoundCheck(plays: false);
    await atSoundCheck(tester, sound);
    final l10n = l10nOf(tester);
    await record(tester);
    expect(find.text(l10n.onboardingSoundHeardYou), findsNothing);
    expect(find.text(l10n.onboardingSoundListeningOff), findsOneWidget);
  });

  testWidgets('passed without a check: both switches stay as they are', (
    tester,
  ) async {
    final sound = FixedSoundCheck();
    final state = await atSoundCheck(tester, sound);
    await finish(tester);
    expect(sound.recordings, 0);
    expect(state.settings.isEnabled(Skill.listening), isTrue);
    expect(state.settings.isEnabled(Skill.speaking), isFalse);
  });

  testWidgets('every state fits at twice the text size and meets the '
      'tap-target, label and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> check(String what) async {
      expect(tester.takeException(), isNull, reason: what);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    for (final scale in <double>[1.0, 2.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final sound = FixedSoundCheck();
      await atSoundCheck(tester, sound);
      usePhone(tester, textScale: scale);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      await check('ready $scale');
      await record(tester);
      await check('asking $scale');
      await tap(tester, find.text(l10n.onboardingSoundNo));
      await check('done $scale');
    }
    handle.dispose();
  });
}
