// Sessions are kept per language (#852): two identical requests share one
// queue, an answer rebuilds only its own language's, and any other change
// rebuilds all. Counts of builds, never time.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';

/// Forty synthetic languages, thirty words each, taught from English.
final List<String> _codes = <String>[
  for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) 'x$c',
  for (final c in 'abcdefghijklmn'.split('')) 'y$c',
];

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
${[for (var i = 1; i <= 30; i++) '  - { id: $code-en-words-${i.toString().padLeft(4, '0')}, target: "t$i", native: "n$i", reading: "r$i" }'].join('\n')}
''',
};

/// About two years of answers: every word of every language reviewed on
/// five days spread over 700.
MemoryProgress _twoYears([MemoryProgress? into]) {
  final progress = into ?? MemoryProgress();
  final start = DateTime(2024, 6, 1, 9);
  for (var round = 0; round < 5; round++) {
    for (final code in _codes) {
      for (var i = 1; i <= 30; i++) {
        progress.record(
          deckId: '$code-en-words',
          cardId: '$code-en-words-${i.toString().padLeft(4, '0')}',
          mode: DrillMode.recognition,
          grade: 4,
          now: start.add(Duration(days: round * 140 + i)),
        );
      }
    }
  }
  return progress;
}

/// Touches every language while an answer is being recorded, as a change
/// of the baseline parameters does (it replays every state).
class _TouchingProgress extends MemoryProgress {
  bool touchOnRecord = false;

  @override
  ReviewEvent record({
    required String deckId,
    required String cardId,
    required DrillMode mode,
    required int grade,
    required DateTime now,
    Duration elapsed = Duration.zero,
    String? answerGiven,
    String? script,
    Ask? asked,
  }) {
    final event = super.record(
      deckId: deckId,
      cardId: cardId,
      mode: mode,
      grade: grade,
      now: now,
      elapsed: elapsed,
      answerGiven: answerGiven,
      script: script,
      asked: asked,
    );
    if (touchOnRecord) {
      actOnLeech(
        (cardId: 'xb-en-words-0001', mode: DrillMode.recognition),
        LeechActionKind.reset,
        now: now,
      );
    }
    return event;
  }
}

/// A phone whose voices can be installed while the app runs.
class _SwitchTts extends NullTtsEngine {
  _SwitchTts();

  bool available = false;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async => available;
}

void main() {
  late AppState state;

  setUp(() async {
    state = AppState.test(
      decks: MemoryDeckSource(_course()),
      progress: _twoYears(),
      speech: FixedSpeechEngine(onDevice: const <String>{}),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: _codes,
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    await state.load();
    state.lazyOff = true;
  });

  DrillRequest today(String code) => DrillRequest.today(language: code);

  test('identical requests between changes share one queue', () {
    final first = state.buildSession(today('xa'));
    final built = state.sessionBuilds['xa'];
    expect(state.buildSession(today('xa')), same(first));
    expect(state.sessionBuilds['xa'], built);
  });

  test('an answer rebuilds only its own language', () async {
    for (final code in _codes) {
      state.buildSession(today(code));
    }
    final before = Map<String, int>.of(state.sessionBuilds);
    expect(before.length, _codes.length);

    final item = state.buildSession(today('xa')).items.first;
    state.record(item, 4);
    for (final code in _codes) {
      state.buildSession(today(code));
    }

    for (final code in _codes) {
      expect(
        state.sessionBuilds[code],
        code == 'xa' ? before[code]! + 1 : before[code],
        reason: code == 'xa' ? 'rebuilt once' : '$code stays cached',
      );
    }
  });

  test(
    'a change to every language rebuilds the others, not just the answered',
    () async {
      final touching = _TouchingProgress();
      final other = AppState.test(
        decks: MemoryDeckSource(_course()),
        progress: _twoYears(touching),
        speech: FixedSpeechEngine(onDevice: const <String>{}),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: _codes,
          learningChosen: true,
        ),
      );
      addTearDown(other.dispose);
      await other.load();
      other.lazyOff = true;
      for (final code in _codes) {
        other.buildSession(today(code));
      }
      final before = Map<String, int>.of(other.sessionBuilds);

      touching.touchOnRecord = true;
      final item = other.buildSession(today('xa')).items.first;
      other.record(item, 4);
      other.buildSession(today('xb'));

      expect(
        other.sessionBuilds['xb'],
        before['xb']! + 1,
        reason: 'a replay of every language invalidates xb\'s cached queue',
      );
    },
  );

  test('a voice that appears rebuilds every language; the same answers keep '
      'them', () async {
    final tts = _SwitchTts();
    final other = AppState.test(
      decks: MemoryDeckSource(_course()),
      progress: _twoYears(),
      tts: tts,
      speech: FixedSpeechEngine(onDevice: const <String>{}),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: _codes,
        learningChosen: true,
      ),
    );
    addTearDown(other.dispose);
    await other.load();
    other.lazyOff = true;
    for (final code in _codes) {
      other.buildSession(today(code));
    }
    final before = Map<String, int>.of(other.sessionBuilds);

    // The phone answers as before: the queues are kept (#857).
    await other.refreshVoices();
    for (final code in _codes) {
      other.buildSession(today(code));
    }
    for (final code in _codes) {
      expect(other.sessionBuilds[code], before[code], reason: '$code kept');
    }

    // A voice is installed: what Listening needs has changed.
    tts.available = true;
    await other.refreshVoices();
    for (final code in _codes) {
      other.buildSession(today(code));
    }
    for (final code in _codes) {
      expect(other.sessionBuilds[code], before[code]! + 1, reason: code);
    }
  });

  test('the first languages\' days are worked out at once, the rest later', () {
    state.lazyOff = false;
    // Without a scheduler in the test, the queue is worked out at once; with
    // one, only the first few are. Either way the first are there.
    expect(AppState.firstLanguage(0), isTrue);
    expect(AppState.firstLanguage(39), isFalse);
  });
}
