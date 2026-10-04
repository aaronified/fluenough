import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/today/today_numbers.dart';

/// Sound for the whole app, playing words automatically and the speaker
/// tap count: stored like every setting; and what sound off does
/// to what is spoken and drilled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stored', () {
    test('sound on, words not played automatically and no taps, by '
        'default', () {
      final s = SettingsNotifier();
      expect(s.soundOn, isTrue);
      expect(s.autoplay, isFalse);
      expect(s.speakerTaps, 0);
      final stored = s.toStored();
      expect(stored['sound_on'], 'true');
      expect(stored['autoplay'], 'false');
      expect(stored['speaker_taps'], '0');
    });

    test('each survives toStored and restore', () {
      final changed = SettingsNotifier()
        ..soundOn = false
        ..autoplay = true;
      for (var i = 0; i < 7; i++) {
        changed.countSpeakerTap();
      }
      final restored = SettingsNotifier()..restore(changed.toStored());
      expect(restored.soundOn, isFalse);
      expect(restored.autoplay, isTrue);
      expect(restored.speakerTaps, 7);
      expect(restored.toStored(), changed.toStored());
    });

    test('an unreadable value keeps its setting', () {
      final s = SettingsNotifier()
        ..restore(const <String, String>{
          'sound_on': 'loud',
          'autoplay': '',
          'speaker_taps': '-3',
        });
      expect(s.soundOn, isTrue);
      expect(s.autoplay, isFalse);
      expect(s.speakerTaps, 0);
    });

    test('a tap is counted, and notified so that it is saved', () {
      final s = SettingsNotifier();
      var notified = 0;
      s.addListener(() => notified++);
      expect(s.countSpeakerTap(), 1);
      expect(s.countSpeakerTap(), 2);
      expect(notified, 2);
    });
  });

  group('sound off', () {
    Future<AppState> loaded(
      FixedTtsEngine tts, {
      MemoryProgress? progress,
    }) async {
      final state = AppState.test(tts: tts, progress: progress);
      await state.load();
      return state;
    }

    test('nothing is spoken, and the phone\'s voices still read as they '
        'are', () async {
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await loaded(tts);
      final spanish = state.deckById('es-en-core-100')!.language;
      state.settings.soundOn = false;
      await state.speak('la casa', spanish);
      expect(tts.spoken, isEmpty);
      expect(state.voiceStatus(spanish), VoiceStatus.available);
      expect(state.hasVoice(spanish), isTrue);
      expect(state.canSpeak(spanish), isFalse);

      state.settings.soundOn = true;
      await state.speak('la casa', spanish);
      expect(tts.spoken.single.text, 'la casa');
      expect(state.canSpeak(spanish), isTrue);
    });

    test('listening is skipped in a deck\'s session, a lesson, Today\'s '
        'reviews and counts, and number practice, as with no voice', () async {
      // Words taught by ear three days ago, so that listening is due.
      final base = await loaded(FixedTtsEngine(const <String>{'es', 'hi'}));
      final progress = MemoryProgress();
      for (final card in base.untaughtCards('es').take(4)) {
        progress.record(
          deckId: card.deckId,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: base.now().subtract(const Duration(days: 3)),
        );
      }
      final state = await loaded(
        FixedTtsEngine(const <String>{'es', 'hi'}),
        progress: progress,
      );

      bool listens(Iterable<SessionItem> items) =>
          items.any((i) => i.mode == DrillMode.listening);
      final deck = DrillRequest.untaught(
        'es-en-core-100',
        skill: Skill.listening,
      );
      final lesson = DrillRequest.lesson(language: 'es');
      const today = DrillRequest.today();
      final numbers = state.deckById('hi-en-numbers-big')!;

      // Sound on: each has listening.
      expect(state.buildSession(deck).isNotEmpty, isTrue);
      expect(listens(state.lessonFor(lesson)), isTrue);
      expect(listens(state.buildSession(today).items), isTrue);
      expect(TodayNumbers.of(state).bySkill[Skill.listening], greaterThan(0));
      expect(listens(state.numberPracticeFor(numbers)), isTrue);

      state.settings.soundOn = false;
      expect(state.buildSession(deck).isEmpty, isTrue);
      expect(listens(state.lessonFor(lesson)), isFalse);
      expect(state.lessonFor(lesson), isNotEmpty, reason: 'the rest stays');
      expect(listens(state.buildSession(today).items), isFalse);
      expect(state.buildSession(today).items, isNotEmpty);
      expect(TodayNumbers.of(state).bySkill[Skill.listening] ?? 0, 0);
      expect(listens(state.numberPracticeFor(numbers)), isFalse);
    });
  });
}
