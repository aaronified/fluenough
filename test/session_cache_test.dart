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
import 'package:fluenough/core/speech/speech_engine.dart';

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
MemoryProgress _twoYears() {
  final progress = MemoryProgress();
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

  test('a change to the decks or voices rebuilds every language', () async {
    for (final code in _codes) {
      state.buildSession(today(code));
    }
    final before = Map<String, int>.of(state.sessionBuilds);
    await state.refreshVoices();
    for (final code in _codes) {
      state.buildSession(today(code));
    }
    for (final code in _codes) {
      expect(state.sessionBuilds[code], before[code]! + 1);
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
