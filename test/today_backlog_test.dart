// Today's backlog after placement (wiki, Plan-Today-Backlog): only pairs that
// are really due are a backlog; the new skills of a taught word are paced
// through the day's new share; and a script the learner has yet to read is
// still taught while catching up. All on a fixed clock.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/daily_plan.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

final DateTime _now = DateTime(2026, 11, 22, 9);

/// The cards a day of 15 minutes holds at the default 17.5 s a card.
const int _dayCards = 51;

const List<String> _dev = <String>['क', 'ख', 'ग', 'घ', 'च', 'छ', 'ज', 'झ'];
const List<String> _urdu = <String>['ک', 'خ', 'گ', 'غ', 'چ', 'ج', 'ز', 'ژ'];
const List<String> _say = <String>[
  'ka',
  'kha',
  'ga',
  'gha',
  'ca',
  'cha',
  'ja',
  'jha',
];

String _id(String deck, int n) => 'hi-en-$deck-${n.toString().padLeft(4, '0')}';

String _letters(String deck, List<String> targets, String script, bool rtl) {
  final cards = <String>[
    for (var i = 0; i < targets.length; i++)
      '  - { id: ${_id(deck, i + 1)}, target: "${targets[i]}", '
          'native: "${_say[i]} $deck", reading: "${_say[i]}" }',
  ];
  return '''
schema: 1
id: hi-en-$deck
name: "$deck"
language: { code: hi, iso639_3: hin, name: Hindustani, script: $script, scripts: [$script]${rtl ? ', rtl: true' : ''} }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
${cards.join('\n')}
''';
}

String _words(String deck, int count) {
  final cards = <String>[
    for (var i = 0; i < count; i++)
      '  - { id: ${_id(deck, i + 1)}, '
          'target: "${_dev[i % 8]}${_dev[i ~/ 8 % 8]}${_dev[i ~/ 64 % 8]}", '
          'native: "$deck ${i + 1}", '
          'reading: "${_say[i % 8]}${_say[i ~/ 8 % 8]}${_say[i ~/ 64 % 8]}" }',
  ];
  return '''
schema: 1
id: hi-en-$deck
name: "$deck"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${cards.join('\n')}
''';
}

/// Hindustani in two scripts: Devanagari and Urdu letters (eight each), a
/// deck of [big] words, and five words nobody has met.
Map<String, String> _course(int big) => <String, String>{
  'decks/hi/hi-en-letters.yaml': _letters('letters', _dev, 'devanagari', false),
  'decks/hi/hi-en-urdu-letters.yaml': _letters(
    'urdu-letters',
    _urdu,
    'perso_arabic',
    true,
  ),
  'decks/hi/hi-en-big.yaml': _words('big', big),
  'decks/hi/hi-en-fresh.yaml': _words('fresh', 5),
  'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
alphabet:
  - hi-letters
  - hi-urdu-letters
units:
  - [hi-letters]
  - [hi-urdu-letters]
  - [hi-big, hi-fresh]
''',
};

/// The Devanagari letters credited in both skills, and the [big] words
/// reviewed once: in Recognition only, now (as placement credits them, so
/// that none is due), or in both skills [daysAgo] days ago (so that all are
/// due).
MemoryProgress _history({required int big, int? daysAgo}) {
  final progress = MemoryProgress();
  void review(String deck, int n, DrillMode mode, DateTime at) =>
      progress.record(
        deckId: 'hi-en-$deck',
        cardId: _id(deck, n),
        mode: mode,
        grade: daysAgo == null ? 5 : 4,
        now: at,
      );
  for (var n = 1; n <= 8; n++) {
    for (final mode in const <DrillMode>[
      DrillMode.recognition,
      DrillMode.production,
    ]) {
      review('letters', n, mode, _now.subtract(const Duration(days: 1)));
    }
  }
  for (var n = 1; n <= big; n++) {
    final at = daysAgo == null ? _now : _now.subtract(Duration(days: daysAgo));
    review('big', n, DrillMode.recognition, at);
    if (daysAgo != null) review('big', n, DrillMode.production, at);
  }
  return progress;
}

Future<AppState> _learner({
  required int big,
  int? daysAgo,
  Set<String> scripts = const <String>{'devanagari', 'perso_arabic'},
}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(_course(big)),
    progress: _history(big: big, daysAgo: daysAgo),
    now: _now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'hi': scripts},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

/// A one-script course of word decks in the path's own order, which is not
/// the order of their names: [path] lists deck ids (`hi-zeta`, ...), one
/// unit each, of [sizes] words.
Future<AppState> _words2({
  required Map<String, int> sizes,
  required List<String> path,
  required void Function(MemoryProgress progress) credit,
}) async {
  final progress = MemoryProgress();
  credit(progress);
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      for (final MapEntry(:key, :value) in sizes.entries)
        'decks/hi/hi-en-$key.yaml': _words(key, value),
      'decks/hi/hi-path.yaml':
          '''
schema: 1
kind: path
id: hi-path
language: hi
units:
${path.map((id) => '  - [$id]').join('\n')}
''',
    }),
    progress: progress,
    now: _now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

void _record(
  MemoryProgress progress,
  String deck,
  int count,
  DateTime at, {
  List<DrillMode> modes = const <DrillMode>[DrillMode.recognition],
  int grade = 5,
}) {
  for (var n = 1; n <= count; n++) {
    for (final mode in modes) {
      progress.record(
        deckId: 'hi-en-$deck',
        cardId: _id(deck, n),
        mode: mode,
        grade: grade,
        now: at,
      );
    }
  }
}

Iterable<SessionItem> _members(List<SessionItem> items) sync* {
  for (final item in items) {
    if (item.group.isEmpty) {
      yield item;
    } else {
      yield* item.group;
    }
  }
}

List<SessionItem> _stretch(AppState state, DailyRun run, {int most = 8}) {
  final all = <SessionItem>[];
  for (var i = 0; i < most; i++) {
    final round = state.nextDailyRound(run);
    if (round.isEmpty) break;
    all.addAll(_members(round));
  }
  return all;
}

void main() {
  group('the budget rules', () {
    test('a backlog is more than three days of cards', () {
      expect(DailyBudget.isCatchingUp(3 * _dayCards, _dayCards), isFalse);
      expect(DailyBudget.isCatchingUp(3 * _dayCards + 1, _dayCards), isTrue);
    });

    test('a day introduces a fifth of its cards as new skills, at least '
        'three', () {
      expect(DailyBudget.newPairsPerDay(_dayCards), 10);
      expect(DailyBudget.newPairsPerDay(5), DailyBudget.newSlots);
    });

    test('catching up teaches no words, but up to the script words '
        'allowed', () {
      DailyRound day(int script) => DailyPlanner.whole(
        left: const Duration(minutes: 15),
        due: 200,
        newAvailable: 20,
        closest: 0,
        secondsPerReview: 17.5,
        secondsPerTeach: 12,
        catchingUp: true,
        catchUpNew: script,
      );
      expect(day(0).newWords, 0);
      expect(day(3).newWords, 3);
    });
  });

  group('after placement', () {
    test('the other skills of taught words are not a backlog', () async {
      // 300 words credited in one skill: their other skills are new pairs,
      // more than three days of cards, and none of them is due.
      final state = await _learner(big: 300);
      final queue = state.buildSession(
        const DrillRequest.today(language: 'hi'),
      );
      expect(queue.due, isEmpty);
      expect(queue.fresh.length, greaterThan(3 * _dayCards));

      final plan = state.dailyPlanFor(state.decks.first.language);
      expect(plan.due, 0);
      expect(plan.split.catchingUp, isFalse);
      expect(plan.split.newWords, greaterThan(0));
      expect(plan.split.reviews, greaterThan(0));
    });

    test('they are introduced a few a day, in path order, not all at '
        'once', () async {
      final state = await _learner(big: 300);
      final run = state.startDaily('hi')!;
      final served = _stretch(state, run);
      final pairs = <(String, DrillMode)>{
        for (final item in served)
          if (item.state == null && item.card.id.startsWith('hi-en-big-'))
            (item.card.id, item.mode),
      };
      expect(pairs, isNotEmpty, reason: 'some are introduced today');
      expect(
        pairs.length,
        lessThanOrEqualTo(DailyBudget.newPairsPerDay(_dayCards)),
      );
      expect(
        run.pairs,
        lessThanOrEqualTo(DailyBudget.newPairsPerDay(_dayCards)),
      );
    });

    test('a real backlog is still a backlog', () async {
      final state = await _learner(big: 200, daysAgo: 60);
      final queue = state.buildSession(
        const DrillRequest.today(language: 'hi'),
      );
      expect(queue.due.length, 200);
      final plan = state.dailyPlanFor(state.decks.first.language);
      expect(plan.due, 200);
      expect(plan.split.catchingUp, isTrue);
    });
  });

  group('script lessons while catching up', () {
    test('a script not read yet is still taught', () async {
      // 300 due words stay over three days of cards through every round.
      final state = await _learner(big: 300, daysAgo: 60);
      final plan = state.dailyPlanFor(state.decks.first.language);
      expect(plan.split.catchingUp, isTrue);
      expect(plan.split.newWords, greaterThan(0));

      final served = _stretch(state, state.startDaily('hi')!, most: 4);
      final script = <String>{
        for (final item in served)
          if (item.card.id.startsWith('hi-en-urdu-letters-')) item.card.id,
      };
      expect(script, isNotEmpty, reason: 'the Urdu letters are taught');
      expect(
        served.any((i) => i.card.id.startsWith('hi-en-fresh-')),
        isFalse,
        reason: 'words wait for the backlog',
      );
    });

    test('a script already read changes nothing: no new words', () async {
      final state = await _learner(
        big: 300,
        daysAgo: 60,
        scripts: const <String>{'devanagari'},
      );
      final plan = state.dailyPlanFor(state.decks.first.language);
      expect(plan.split.catchingUp, isTrue);
      expect(plan.split.newWords, 0);

      final served = _stretch(state, state.startDaily('hi')!, most: 4);
      expect(
        served.where((i) => i.state == null),
        isEmpty,
        reason: 'only reviews while catching up',
      );
    });

    test('two sessions in a day teach five script words in all', () async {
      final state = await _learner(big: 300, daysAgo: 60);
      final first = _stretch(state, state.startDaily('hi')!, most: 4);
      final ids = <String>{
        for (final item in first)
          if (item.card.id.startsWith('hi-en-urdu-letters-')) item.card.id,
      };
      expect(ids, isNotEmpty);
      // They are answered, so the log holds them for the next session.
      for (final id in ids) {
        state.progress.record(
          deckId: 'hi-en-urdu-letters',
          cardId: id,
          mode: DrillMode.recognition,
          grade: 4,
          now: _now,
        );
      }
      expect(state.scriptWordsToday(_now), ids.length);
      final second = _stretch(state, state.startDaily('hi')!, most: 4);
      for (final item in second) {
        if (item.card.id.startsWith('hi-en-urdu-letters-')) {
          ids.add(item.card.id);
        }
      }
      expect(ids.length, lessThanOrEqualTo(DailyBudget.catchUpScriptWords));
    });
  });

  group('pacing the new skills', () {
    test('they follow the path, not the order of the decks', () async {
      // `alpha` sorts first but its unit is second in the path.
      final state = await _words2(
        sizes: <String, int>{'alpha': 30, 'zeta': 30},
        path: <String>['hi-zeta', 'hi-alpha'],
        credit: (progress) {
          _record(progress, 'alpha', 30, _now);
          _record(progress, 'zeta', 30, _now);
        },
      );
      final served = _stretch(state, state.startDaily('hi')!, most: 1);
      final fresh = served.where((i) => i.state == null).toList();
      expect(fresh, isNotEmpty);
      expect(fresh.every((i) => i.card.id.startsWith('hi-en-zeta-')), isTrue);
    });

    test('they keep a place when due reviews would fill the round', () async {
      // 120 words due (under three days of cards), 50 placed ones.
      final state = await _words2(
        sizes: <String, int>{'old': 120, 'placed': 50},
        path: <String>['hi-old', 'hi-placed'],
        credit: (progress) {
          _record(
            progress,
            'old',
            120,
            _now.subtract(const Duration(days: 60)),
            modes: const <DrillMode>[
              DrillMode.recognition,
              DrillMode.production,
            ],
            grade: 4,
          );
          _record(
            progress,
            'placed',
            50,
            _now.subtract(const Duration(days: 1)),
          );
        },
      );
      final queue = state.buildSession(
        const DrillRequest.today(language: 'hi'),
      );
      expect(queue.due.length, 120);
      final round = _members(state.nextDailyRound(state.startDaily('hi')!));
      expect(
        round.where((i) => i.card.id.startsWith('hi-en-placed-')),
        isNotEmpty,
        reason: 'new skills are not starved by the reviews',
      );
      expect(
        round.where((i) => i.card.id.startsWith('hi-en-old-')),
        isNotEmpty,
      );
    });

    test('on the day of placement none is offered', () async {
      final state = await _learner(big: 300);
      expect(state.newPairsToday(_now, 'hi'), 0);
      state.settings.addPlacedAt('hi', _now.millisecondsSinceEpoch ~/ 1000);
      expect(state.newPairsToday(_now, 'hi'), greaterThanOrEqualTo(300));
      final served = _stretch(state, state.startDaily('hi')!, most: 3);
      expect(
        served.where(
          (i) => i.state == null && i.card.id.startsWith('hi-en-big-'),
        ),
        isEmpty,
      );
    });
  });
}
