// Keep going (#1010): the day's session after its minutes are done serves the
// cards closest to due, never pulled forward past a couple of days nor while
// still too fresh, and some new words, within the day's taught total and a
// small allowance; reviews first while a backlog waits. All on a fixed clock.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/daily_plan.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/today/today_numbers.dart';

/// The clock of every fixture, which AppState.test also starts at.
final DateTime _now = DateTime(2026, 9, 28, 19);

const List<DrillMode> _modes = <DrillMode>[
  DrillMode.recognition,
  DrillMode.production,
];

String _id(String deck, int n) => 'hi-en-$deck-${n.toString().padLeft(4, '0')}';

/// A deck of [count] Hindustani words with unique spellings.
String _deck(String deck, int count, int offset) {
  const letters = <String>['क', 'ख', 'ग', 'घ', 'च', 'छ', 'ज', 'झ', 'ट', 'ठ'];
  const sounds = <String>[
    'ka',
    'kha',
    'ga',
    'gha',
    'ca',
    'cha',
    'ja',
    'jha',
    'ta',
    'tha',
  ];
  // The words of two decks never share a spelling.
  final mark = offset == 0 ? '' : 'ळ';
  final say = offset == 0 ? '' : 'la';
  final cards = <String>[
    for (var i = 0; i < count; i++)
      '  - { id: ${_id(deck, i + 1)}, '
          'target: "$mark${letters[(i + offset) ~/ 10 % 10]}${letters[(i + offset) % 10]}${letters[(i * 3 + offset) % 10]}", '
          'native: "$deck ${i + 1}", '
          'reading: "$say${sounds[(i + offset) ~/ 10 % 10]}${sounds[(i + offset) % 10]}${sounds[(i * 3 + offset) % 10]}" }',
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

/// A course of [seen] words the learner has met and [fresh] they have not,
/// in one unit of the path.
Map<String, String> _course({required int seen, required int fresh}) =>
    <String, String>{
      'decks/hi/hi-en-seen.yaml': _deck('seen', seen, 0),
      'decks/hi/hi-en-fresh.yaml': _deck('fresh', fresh, 500),
      'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
units:
  - [hi-seen, hi-fresh]
''',
    };

/// The learner's history, recorded card by card: [ripe] seen words reviewed
/// a day and a half ago (due in half a day, and no longer fresh), [fresh]
/// seen words reviewed a day ago (due tomorrow, but still too fresh to be
/// worth an early review), [far] words reviewed on schedule since 40 days
/// ago and early once at the end, so that they are due in weeks, [overdue]
/// words long overdue, and [taughtToday] words of the path taught earlier
/// today. Seen words are numbered in that order.
MemoryProgress _history({
  int ripe = 0,
  int fresh = 0,
  int far = 0,
  int overdue = 0,
  int taughtToday = 0,
}) {
  final progress = MemoryProgress();
  void review(String deck, int n, DrillMode mode, int grade, DateTime at) =>
      progress.record(
        deckId: 'hi-en-$deck',
        cardId: _id(deck, n),
        mode: mode,
        grade: grade,
        now: at,
      );
  var n = 0;
  for (var i = 0; i < ripe; i++) {
    n++;
    for (final mode in _modes) {
      review('seen', n, mode, 4, _now.subtract(const Duration(hours: 36)));
    }
  }
  for (var i = 0; i < fresh; i++) {
    n++;
    for (final mode in _modes) {
      review('seen', n, mode, 4, _now.subtract(const Duration(days: 1)));
    }
  }
  for (var i = 0; i < far; i++) {
    n++;
    for (final mode in _modes) {
      // Reviewed each time it came due, from a different start for each
      // word, until the next is after the day before yesterday.
      var at = _now.subtract(Duration(days: 40 + i));
      review('seen', n, mode, 4, at);
      final yesterday = _now.subtract(const Duration(days: 1));
      while (!progress
          .stateOf(_id('seen', n), mode)!
          .dueAt
          .isAfter(yesterday)) {
        at = progress.stateOf(_id('seen', n), mode)!.dueAt;
        review('seen', n, mode, 4, at);
      }
      if (!progress.stateOf(_id('seen', n), mode)!.dueAt.isAfter(_now)) {
        // Still due: one review early, yesterday, puts it weeks away.
        review('seen', n, mode, 4, yesterday);
      }
    }
  }
  for (var i = 0; i < overdue; i++) {
    n++;
    for (final mode in _modes) {
      review('seen', n, mode, 4, _now.subtract(const Duration(days: 60)));
    }
  }
  for (var i = 1; i <= taughtToday; i++) {
    for (final mode in _modes) {
      review('fresh', i, mode, 4, _now.subtract(const Duration(hours: 1)));
    }
  }
  return progress;
}

/// A learner of Hindustani with the day's minutes spent, so that the next
/// session is a Keep going stretch.
Future<AppState> _learner({
  required int seen,
  int fresh = 40,
  MemoryProgress? progress,
  int minutes = 15,
}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(_course(seen: seen, fresh: fresh)),
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
  state.settings.setDailyMinutes('hi', minutes);
  state.settings.addClockTime('hi', _now, Duration(minutes: minutes));
  return state;
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

/// Every round of the stretch, until it has nothing more (at most [most]).
List<SessionItem> _stretch(AppState state, DailyRun run, {int most = 8}) {
  final all = <SessionItem>[];
  for (var i = 0; i < most; i++) {
    final round = state.nextDailyRound(run);
    if (round.isEmpty) break;
    all.addAll(_members(round));
  }
  return all;
}

/// The reviews of [items]: pairs with a history. New pairs have none.
List<SessionItem> _reviews(List<SessionItem> items) => <SessionItem>[
  for (final item in items)
    if (item.state != null && !item.ask.onlyShows) item,
];

Set<String> _newIds(List<SessionItem> items) => <String>{
  for (final item in items)
    if (item.state == null) item.card.id,
};

void main() {
  group('Keep going', () {
    test('with nothing due it serves the cards closest to due, none past the '
        'cap, and some new words', () async {
      final state = await _learner(
        seen: 24,
        progress: _history(ripe: 6, fresh: 6, far: 6),
      );
      final run = state.startDaily('hi', keepGoing: true)!;
      expect(run.keepGoing, isTrue);
      expect(run.clock.countsUp, isTrue);

      // What is within reach, and what is far off, as the log leaves them.
      final pool = state.buildSession(
        const DrillRequest(revise: true, language: 'hi'),
      );
      final reach = <String>{
        for (final i in pool.items)
          if (!i.state!.isDue(_now) &&
              i.state!.dueAt.difference(_now) <=
                  const Duration(days: DailyBudget.keepGoingDays) &&
              Fsrs.retrievability(i.state, _now) <=
                  DailyBudget.keepGoingMaxRecall)
            i.card.id,
      };
      final farOff = <String>{
        for (final i in pool.items)
          if (i.state!.dueAt.difference(_now) >
              const Duration(days: DailyBudget.keepGoingDays))
            i.card.id,
      };
      expect(
        state.buildSession(const DrillRequest.today(language: 'hi')).due,
        isEmpty,
        reason: 'nothing is due',
      );
      expect(reach, isNotEmpty, reason: 'some cards are within reach');
      expect(farOff, isNotEmpty, reason: 'some are far off');

      final served = _stretch(state, run);
      final reviews = _reviews(served);
      expect(reviews, isNotEmpty, reason: 'the closest to due are reviewed');
      for (final item in reviews) {
        expect(reach, contains(item.card.id), reason: item.card.id);
        expect(farOff, isNot(contains(item.card.id)));
        expect(
          item.state!.dueAt.difference(_now),
          lessThanOrEqualTo(const Duration(days: DailyBudget.keepGoingDays)),
        );
        expect(
          Fsrs.retrievability(item.state, _now),
          lessThanOrEqualTo(DailyBudget.keepGoingMaxRecall),
        );
      }
      // The closest to due: no card left out is due sooner than one served.
      final dueOf = <String, DateTime>{
        for (final i in pool.items) i.card.id: i.state!.dueAt,
      };
      final servedIds = <String>{for (final i in reviews) i.card.id};
      final latest = servedIds
          .map((id) => dueOf[id]!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      for (final id in reach.difference(servedIds)) {
        expect(dueOf[id]!.isBefore(latest), isFalse, reason: id);
      }
      // And new words from the path.
      final fresh = _newIds(served);
      expect(fresh, isNotEmpty);
      expect(fresh.every((id) => id.startsWith('hi-en-fresh-')), isTrue);
    });

    test('a stretch teaches no more than the day\'s total and the extra '
        'allowance, counting what was taught today', () async {
      final cap = DailyBudget.keepGoingNewCap(due: 0, dayCards: 51);
      expect(cap, DailyPlanner.newCap + DailyBudget.keepGoingNewExtra);

      // Nothing taught yet today: the stretch may teach up to the cap.
      final none = await _learner(seen: 8, progress: _history(ripe: 8));
      final run0 = none.startDaily('hi', keepGoing: true)!;
      _stretch(none, run0);
      expect(run0.taught, lessThanOrEqualTo(cap));
      expect(run0.taught, greaterThan(0));

      // Eighteen taught today already: only what is left under the cap.
      final room = cap - 18;
      final most = await _learner(
        seen: 8,
        progress: _history(ripe: 8, taughtToday: 18),
      );
      expect(most.newWordsToday(_now), 18);
      final run = most.startDaily('hi', keepGoing: true)!;
      final served = _stretch(most, run);
      expect(run.taught, lessThanOrEqualTo(room));
      expect(_newIds(served).length, lessThanOrEqualTo(room));

      // The cap reached: no new word at all, the closest are reviewed.
      final full = await _learner(
        seen: 8,
        progress: _history(ripe: 8, taughtToday: cap),
      );
      expect(full.newWordsToday(_now), cap);
      final runFull = full.startDaily('hi', keepGoing: true)!;
      final servedFull = _stretch(full, runFull);
      expect(runFull.taught, 0);
      expect(_newIds(servedFull), isEmpty);
      expect(_reviews(servedFull), isNotEmpty);
    });

    test('the allowance shrinks as the backlog grows, and goes at the '
        'catching-up line', () {
      const day = 51;
      expect(
        DailyBudget.keepGoingNewCap(due: 0, dayCards: day),
        DailyPlanner.newCap + DailyBudget.keepGoingNewExtra,
      );
      expect(
        DailyBudget.keepGoingNewCap(due: day + 1, dayCards: day),
        DailyPlanner.newCap + DailyBudget.keepGoingNewExtraBusy,
      );
      expect(
        DailyBudget.keepGoingNewCap(
          due: DailyBudget.backlogDays * day + 1,
          dayCards: day,
        ),
        DailyPlanner.newCap,
      );
      expect(
        DailyBudget.keepGoingNewExtraBusy,
        lessThan(DailyBudget.keepGoingNewExtra),
      );
    });

    test('with a heavy backlog it serves reviews, most overdue first, and '
        'teaches nothing while catching up', () async {
      // A 5 minute day buys 17 cards, so 60 due is past three days' worth.
      final state = await _learner(
        seen: 60,
        minutes: 5,
        progress: _history(overdue: 60),
      );
      expect(
        state.buildSession(const DrillRequest.today(language: 'hi')).due,
        hasLength(60),
      );
      final run = state.startDaily('hi', keepGoing: true)!;
      final first = state.nextDailyRound(run);
      final members = _members(first).toList();
      expect(members, isNotEmpty);
      expect(_newIds(members), isEmpty, reason: 'catching up teaches nothing');
      expect(members.every((i) => i.state != null), isTrue);
      expect(run.taught, 0);
    });

    test('with a backlog under the catching-up line, reviews outnumber the '
        'new words', () async {
      // 5 minute day: 17 cards a day; 30 due is more than a day's worth.
      final state = await _learner(
        seen: 30,
        minutes: 5,
        progress: _history(overdue: 30),
      );
      final run = state.startDaily('hi', keepGoing: true)!;
      final first = _members(state.nextDailyRound(run)).toList();
      final reviews = _reviews(first);
      final fresh = _newIds(first);
      expect(reviews, isNotEmpty);
      expect(reviews.length, greaterThan(fresh.length));
      expect(
        run.taught,
        lessThanOrEqualTo(
          DailyBudget.keepGoingNewExtraBusy + DailyPlanner.newCap,
        ),
      );
    });

    test('it moves neither the tiles nor the day\'s numbers', () async {
      final state = await _learner(
        seen: 24,
        progress: _history(ripe: 6, fresh: 6, far: 6),
      );
      final hindi = state.deckById('hi-en-seen')!.language;
      final tiles = TodayNumbers.of(state).bySkill;
      final plan = state.dailyPlanFor(hindi);
      _stretch(state, state.startDaily('hi', keepGoing: true)!);
      expect(TodayNumbers.of(state).bySkill, tiles);
      final after = state.dailyPlanFor(hindi);
      expect(after.split.reviews, plan.split.reviews);
      expect(after.split.newWords, plan.split.newWords);
      expect(tiles[Skill.recognition], isNotNull);
    });

    test('the summary asks for a stretch with the request\'s flag', () {
      expect(
        const DrillRequest.daily(language: 'hi', keepGoing: true).keepGoing,
        isTrue,
      );
      expect(const DrillRequest.daily(language: 'hi').keepGoing, isFalse);
    });
  });
}
