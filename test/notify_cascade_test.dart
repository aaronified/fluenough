// Notifications that change nothing a queue reads must not drop the queues
// kept for every language (#857): a voice check that finds the voices as
// they were, and a second speech check, rebuild nothing, while a real change
// still rebuilds everything and gives the same answers as a cold build.
// Counts of builds, never time.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';

// The queue stamps its values with the clock in 30 s steps: a fixed clock
// keeps the stamp from changing in the middle of a test.
final DateTime _now = DateTime(2026, 10, 31, 9);

const List<String> _codes = <String>['xa', 'xb', 'xc'];

Map<String, String> _course() => <String, String>{
  for (final code in _codes)
    'decks/$code/$code-en-words.yaml':
        '''
schema: 1
id: $code-en-words
name: "Words"
language: { code: $code, iso639_3: ${code}x, name: "Language $code", script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 1; i <= 8; i++) '  - { id: $code-en-words-${i.toString().padLeft(4, '0')}, target: "t$i", native: "n$i", reading: "r$i" }'].join('\n')}
''',
};

/// A text-to-speech engine whose voices can be taken away.
class _Voices extends FixedTtsEngine {
  _Voices() : super(const <String>{});

  bool present = true;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async => present;
}

void main() {
  late AppState state;
  late _Voices voices;

  setUp(() async {
    voices = _Voices();
    state = AppState.test(
      now: _now,
      decks: MemoryDeckSource(_course()),
      progress: MemoryProgress(),
      tts: voices,
      speech: FixedSpeechEngine(granted: true),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: _codes,
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    await state.load();
    state.lazyOff = true;
    await state.refreshVoices();
    await state.startSpeech();
  });

  DrillRequest today(String code) => DrillRequest.today(language: code);

  List<String> idsOf(String code) => <String>[
    for (final item in state.buildSession(today(code)).items)
      '${item.card.id}/${item.mode.name}',
  ];

  Map<String, int> buildAll() {
    for (final code in _codes) {
      state.buildSession(today(code));
    }
    return Map<String, int>.of(state.sessionBuilds);
  }

  test(
    'a voice check that finds the voices as they were keeps the queues',
    () async {
      final before = buildAll();
      final ids = {for (final code in _codes) code: idsOf(code)};
      final first = state.buildSession(today('xa'));

      var notified = 0;
      state.addListener(() => notified++);
      await state.refreshVoices();

      expect(notified, 1, reason: 'the screens are still told');
      expect(buildAll(), before);
      expect(state.buildSession(today('xa')), same(first));
      for (final code in _codes) {
        expect(idsOf(code), ids[code]);
      }
    },
  );

  test('checking the recogniser again keeps the queues', () async {
    // A phone with a recogniser, as nearly all have: one without has Say off,
    // and a check that is under way counts it as on (#857), so the counts
    // move there and back.
    state = AppState.test(
      now: _now,
      decks: MemoryDeckSource(_course()),
      progress: MemoryProgress(),
      tts: voices,
      speech: FixedSpeechEngine(granted: true, onDevice: _codes.toSet()),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: _codes,
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    await state.load();
    state.lazyOff = true;
    await state.refreshVoices();
    await state.startSpeech();
    final before = buildAll();
    await state.startSpeech();
    expect(buildAll(), before);
  });

  test(
    'a voice that goes missing rebuilds every language, as it must',
    () async {
      final before = buildAll();
      voices.present = false;
      await state.refreshVoices();
      final after = buildAll();
      for (final code in _codes) {
        expect(after[code], before[code]! + 1);
      }
      // Without a voice nothing is listened to; the queues after the change
      // equal ones built from scratch with the voice already missing.
      final fresh = AppState.test(
        now: _now,
        decks: MemoryDeckSource(_course()),
        progress: MemoryProgress(),
        tts: voices,
        speech: FixedSpeechEngine(granted: true),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: _codes,
          learningChosen: true,
        ),
      );
      addTearDown(fresh.dispose);
      await fresh.load();
      fresh.lazyOff = true;
      await fresh.refreshVoices();
      for (final code in _codes) {
        expect([
          for (final i in fresh.buildSession(today(code)).items)
            '${i.card.id}/${i.mode.name}',
        ], idsOf(code));
      }
    },
  );
}
