// Taking back placement credit (wiki/Plan-Placement-V2.md, point 17): the
// replay leaves out exactly the credit a withdrawal names and nothing else,
// the snapshot and the export agree with it, an unconfirmed placement is
// worked out each time, and letters known from another language are not
// words known.
import 'dart:convert';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/data/replay_snapshot.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/placement/placement_check.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/skills_in_play.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// The credit's moment: a whole second, with 250 ms in it, as the app's
/// clock gives.
final DateTime _t = DateTime.utc(2026, 11, 7, 12, 0, 0, 250);

LoggedReview _credit(
  String deck,
  String card, {
  DrillMode mode = DrillMode.recognition,
  DateTime? at,
}) => (
  key: (cardId: card, mode: mode),
  deckId: deck,
  at: at ?? _t,
  grade: 5,
  elapsed: Duration.zero,
  answerGiven: null,
  script: null,
  asked: Ask.own,
);

LoggedReview _real(
  String deck,
  String card, {
  required DateTime at,
  int grade = 3,
  DrillMode mode = DrillMode.recognition,
  String? answer,
}) => (
  key: (cardId: card, mode: mode),
  deckId: deck,
  at: at,
  grade: grade,
  elapsed: const Duration(seconds: 4),
  answerGiven: answer,
  script: null,
  asked: Ask.own,
);

PlacementWithdrawal _withdrawal(
  Set<String> decks, {
  DateTime? at,
  Set<DrillMode> modes = const <DrillMode>{DrillMode.recognition},
  String? script,
  String language = 'es',
}) => PlacementWithdrawal(
  at: at ?? _t.add(const Duration(days: 3)),
  language: language,
  creditAt: momentOf(_t),
  modes: modes,
  script: script,
  deckIds: decks,
);

List<Object?> _state(FsrsState? s) => s == null
    ? <Object?>[null]
    : <Object?>[
        s.stability,
        s.difficulty,
        s.intervalDays,
        s.dueAt,
        s.lastReviewAt,
        s.repetitions,
        s.lapses,
        s.recallAtReview,
      ];

List<Object?> _event(ReviewEvent e) => <Object?>[
  e.at,
  e.deckId,
  e.cardId,
  e.mode,
  e.grade,
  e.elapsed,
  e.answerGiven,
  e.script,
  e.asked,
  e.share,
  ..._state(e.before),
  ..._state(e.after),
];

List<Object?> _states<K>(Map<K, FsrsState> states) => <Object?>[
  for (final MapEntry(:key, :value) in states.entries)
    <Object?>['$key', ..._state(value)],
];

/// Everything a replay holds, as lists, so that `equals` compares it.
List<Object?> _held(Replayed r) => <Object?>[
  r.events.map(_event).toList(),
  _states(r.states),
  r.scriptEvents.map(_event).toList(),
  _states(r.scriptStates),
];

Replayed _replay(Iterable<LoggedReview> reviews) =>
    replayReviews(inTimeOrder(reviews), skills: const SkillMap());

void main() {
  // Credit on decks A, B and C (a card of each), a real review of a B card
  // two days later and one of a D card.
  final a = _credit('es-en-a', 'es-0001');
  final b = _credit('es-en-b', 'es-0002');
  final c = _credit('es-en-c', 'es-0003');
  final realB = _real(
    'es-en-b',
    'es-0002',
    at: _t.add(const Duration(days: 2)),
    grade: 4,
  );
  final realD = _real(
    'es-en-d',
    'es-0004',
    at: _t.add(const Duration(days: 2, hours: 1)),
  );
  final log = <LoggedReview>[a, b, c, realB, realD];
  final w = _withdrawal(<String>{'es-en-b', 'es-en-c'});

  group('the replay without withdrawn credit', () {
    test('equals the replay of the log with that credit removed: states, '
        'events, script states and implied states', () {
      final filtered = withoutWithdrawnCredit(log, <PlacementWithdrawal>[w]);
      expect(filtered.withdrawn, <LoggedReview>[b, c]);
      final withWithdrawal = _replay(filtered.kept);
      final removed = _replay(<LoggedReview>[a, realB, realD]);
      expect(_held(withWithdrawal), equals(_held(removed)));
      // The B card's real review is its first review now.
      final state = withWithdrawal
          .states[(cardId: 'es-0002', mode: DrillMode.recognition)]!;
      expect(state.repetitions, 1);
      expect(withWithdrawal.events.where((e) => e.cardId == 'es-0002'), [
        isA<ReviewEvent>().having((e) => e.before, 'before', isNull),
      ]);
      // The C card has no state, as if never placed.
      expect(
        withWithdrawal.states.containsKey((
          cardId: 'es-0003',
          mode: DrillMode.recognition,
        )),
        isFalse,
      );
    });

    test('is the same through the snapshot: encoded, decoded, compared', () {
      final job = OpenJob(
        reviews: log,
        leechActions: const <LeechAction>[],
        fitted: const {},
        encode: true,
        withdrawals: <PlacementWithdrawal>[w],
      );
      final opened = openLog(job);
      final reference = openLog(
        OpenJob(
          reviews: <LoggedReview>[a, realB, realD],
          leechActions: const <LeechAction>[],
          fitted: const {},
        ),
      );
      expect(_held(opened.memory), equals(_held(reference.memory)));
      expect(
        _states(opened.cacheStates),
        equals(_states(reference.cacheStates)),
      );
      final back = openFromSnapshot(
        SnapshotJob(
          bytes: opened.snapshot!,
          leechActions: const <LeechAction>[],
          reviewCount: log.length,
          withdrawals: <PlacementWithdrawal>[w],
        ),
      )!;
      expect(_held(back.memory), equals(_held(reference.memory)));
      expect(_states(back.cacheStates), equals(_states(reference.cacheStates)));
    });

    test('the stamp of a log with a withdrawal is not the stamp of one '
        'without', () {
      LogStamp stamp(List<PlacementWithdrawal> withdrawals) => LogStamp(
        app: 'x',
        reviews: 5,
        firstId: 1,
        lastId: 5,
        sumIds: 15,
        latest: 9,
        sumTimes: 9,
        sumGrades: 9,
        sumElapsed: 9,
        leechActions: const <LeechAction>[],
        fitted: const {},
        withdrawals: withdrawals,
      );
      expect(stamp(const []), equals(stamp(const [])));
      expect(stamp(<PlacementWithdrawal>[w]), isNot(equals(stamp(const []))));
      expect(
        stamp(<PlacementWithdrawal>[w]),
        equals(stamp(<PlacementWithdrawal>[w])),
      );
    });
  });

  group('only placement credit is withdrawn', () {
    final credit = _credit('es-en-a', 'es-0001');
    final wide = _withdrawal(<String>{'es-en-a'});

    bool taken(LoggedReview r, [PlacementWithdrawal? only]) =>
        isWithdrawnCredit(r, <PlacementWithdrawal>[only ?? wide]);

    test('the credit itself is', () {
      expect(taken(credit), isTrue);
      expect(
        taken((
          key: credit.key,
          deckId: credit.deckId,
          at: credit.at,
          grade: 5,
          elapsed: Duration.zero,
          answerGiven: null,
          script: null,
          asked: null,
        )),
        isTrue,
        reason: 'credit from before schema 9 has no way of asking',
      );
    });

    test('a grade 5 in the same second with an answer or an elapsed time '
        'is not', () {
      expect(
        taken((
          key: credit.key,
          deckId: credit.deckId,
          at: credit.at,
          grade: 5,
          elapsed: Duration.zero,
          answerGiven: 'agua',
          script: null,
          asked: Ask.own,
        )),
        isFalse,
      );
      expect(
        taken((
          key: credit.key,
          deckId: credit.deckId,
          at: credit.at,
          grade: 5,
          elapsed: const Duration(milliseconds: 1),
          answerGiven: null,
          script: null,
          asked: Ask.own,
        )),
        isFalse,
      );
    });

    test('the same card at another second, in another language, in another '
        'mode or deck, or asked another way is not', () {
      expect(
        taken(
          _credit('es-en-a', 'es-0001', at: _t.add(const Duration(seconds: 1))),
        ),
        isFalse,
      );
      expect(
        taken(
          _credit(
            'es-en-a',
            'es-0001',
            at: _t.subtract(const Duration(seconds: 1)),
          ),
        ),
        isFalse,
      );
      expect(taken(_credit('hi-en-a', 'hi-0001')), isFalse);
      expect(
        taken(_credit('es-en-a', 'es-0001', mode: DrillMode.production)),
        isFalse,
      );
      expect(taken(_credit('es-en-z', 'es-0001')), isFalse);
      expect(
        taken((
          key: credit.key,
          deckId: credit.deckId,
          at: credit.at,
          grade: 5,
          elapsed: Duration.zero,
          answerGiven: null,
          script: null,
          asked: Ask.chooseMeaning,
        )),
        isFalse,
      );
      expect(
        taken((
          key: credit.key,
          deckId: credit.deckId,
          at: credit.at,
          grade: 5,
          elapsed: Duration.zero,
          answerGiven: null,
          script: 'devanagari',
          asked: Ask.own,
        )),
        isFalse,
        reason: 'the withdrawal is of the word skills, not a script',
      );
    });

    test('a review after the withdrawal is not', () {
      final early = _withdrawal(<String>{
        'es-en-a',
      }, at: _t.add(const Duration(milliseconds: 500)));
      expect(taken(credit, early), isTrue);
      expect(
        taken(
          _credit(
            'es-en-a',
            'es-0001',
            at: _t.add(const Duration(milliseconds: 600)),
          ),
          early,
        ),
        isFalse,
      );
    });

    test('a credited card missed for real has exactly the state of a log '
        'holding only that miss', () {
      final miss = _real(
        'es-en-a',
        'es-0001',
        at: _t.add(const Duration(days: 2)),
        grade: 0,
      );
      final filtered = withoutWithdrawnCredit(
        <LoggedReview>[credit, miss],
        <PlacementWithdrawal>[wide],
      );
      expect(filtered.kept, <LoggedReview>[miss]);
      expect(
        _held(_replay(filtered.kept)),
        equals(_held(_replay(<LoggedReview>[miss]))),
      );
    });

    test('each moment of a language is withdrawn on its own', () {
      final later = _credit(
        'es-en-a',
        'es-0009',
        at: _t.add(const Duration(minutes: 5)),
      );
      final found = withdrawalsAbove(
        language: 'es',
        reviews: <LoggedReview>[credit, later, _credit('hi-en-a', 'hi-0001')],
        moments: <int>{momentOf(_t), momentOf(later.at)},
        modes: const <DrillMode>{DrillMode.recognition},
        script: null,
        above: (_) => true,
        at: _t.add(const Duration(days: 1)),
      );
      expect(found.map((x) => x.creditAt), <int>[
        momentOf(_t),
        momentOf(later.at),
      ]);
      expect(found.every((x) => x.deckIds.contains('es-en-a')), isTrue);
    });
  });

  group('the export', () {
    test('writes and reads the withdrawals, and skips a line of a type it '
        'does not know', () {
      final text = LogJsonl.encode(
        <LoggedReview>[a, b],
        const <LeechAction>[],
        withdrawals: <PlacementWithdrawal>[w],
      );
      final extra =
          '${text.trimRight()}\n'
          '${jsonEncode(<String, Object?>{'type': 'mystery', 'x': 1})}\n';
      final back = LogJsonl.decode(extra);
      expect(back.reviews, hasLength(2));
      expect(back.withdrawals, hasLength(1));
      final got = back.withdrawals.single;
      expect(withdrawalIdentity(got), withdrawalIdentity(w));
      expect(got.language, 'es');
      expect(got.creditAt, momentOf(_t));
      expect(got.modes, <DrillMode>{DrillMode.recognition});
      expect(got.script, isNull);
      expect(got.deckIds, <String>{'es-en-b', 'es-en-c'});
    });

    test('keeps the log format version, so an older app reads the rest', () {
      final text = LogJsonl.encode(
        <LoggedReview>[a],
        const <LeechAction>[],
        withdrawals: <PlacementWithdrawal>[w],
      );
      final header = jsonDecode(text.split('\n').first) as Map<String, Object?>;
      expect(header['version'], 1);
      expect(LogJsonl.version, 1);
    });

    test('a withdrawal that does not read is skipped, not a failed restore', () {
      final text = LogJsonl.encode(<LoggedReview>[a], const <LeechAction>[]);
      final broken =
          '$text'
          '${jsonEncode(<String, Object?>{'type': 'withdrawal', 'language': 'es'})}\n';
      final back = LogJsonl.decode(broken);
      expect(back.reviews, hasLength(1));
      expect(back.withdrawals, isEmpty);
    });
  });

  group('unconfirmed moments', () {
    final t0 = kPlacementCheckFrom - 3600;
    final t1 = kPlacementCheckFrom + 3600;
    final t2 = kPlacementCheckFrom + 7200;

    test('are those from 0.9.0 on with no model, not kept, with credit '
        'left, and evaluating twice gives the same', () {
      Set<int> flagged({
        Set<int> stamped = const <int>{},
        Set<int> kept = const <int>{},
        Set<int>? live,
      }) => unconfirmedMoments(
        placedAt: <int>{t0, t1},
        stamped: stamped,
        kept: kept,
        live: live ?? <int>{t0, t1},
      );
      expect(flagged(), <int>{t1});
      expect(flagged(), <int>{t1});
      expect(flagged(kept: <int>{t1}), isEmpty, reason: 'after Keep');
      expect(flagged(stamped: <int>{t1}), isEmpty);
      expect(flagged(live: <int>{t0}), isEmpty, reason: 'all withdrawn');
      expect(
        unconfirmedMoments(
          placedAt: <int>{t0, t1, t2},
          stamped: <int>{t2},
          kept: const <int>{},
          live: <int>{t0, t1, t2},
        ),
        <int>{t1},
        reason: 'a new stamped moment is never unconfirmed',
      );
    });

    test('settings kept and restored: a map without placed_by or '
        'placement_kept flags the moment again', () {
      final settings = SettingsNotifier()
        ..addPlacedAt('es', t0)
        ..addPlacedAt('es', t1);
      Set<int> flagged(SettingsNotifier s) => flaggableMoments(
        placedAt: s.placedAtOf('es'),
        stamped: s.placedByOf('es'),
        kept: s.placementKeptOf('es'),
      );
      expect(flagged(settings), <int>{t1});
      settings.keepPlacementMoments('es', <int>{t1});
      expect(flagged(settings), isEmpty);
      settings.addPlacedAt('es', t2);
      settings.stampPlacedBy('es', t2, kPlacementModel);
      expect(flagged(settings), isEmpty);

      final again = SettingsNotifier()..restore(settings.toStored());
      expect(again.placementKeptOf('es'), <int>{t1});
      expect(again.placedByOf('es'), <int>{t2});
      expect(flagged(again), isEmpty);

      final stored = <String, String>{...settings.toStored()}
        ..remove('placed_by')
        ..remove('placement_kept');
      final old = SettingsNotifier()..restore(stored);
      expect(old.placedAtOf('es'), <int>{t0, t1, t2});
      expect(flagged(old), <int>{t1, t2});
    });
  });

  group('letters known from another language are not words known', () {
    const speak = SkillKey(SkillKind.speak);
    const hear = SkillKey(SkillKind.hear);
    const readLatin = SkillKey(SkillKind.read, 'latin');
    const writeLatin = SkillKey(SkillKind.write, 'latin');
    const readDeva = SkillKey(SkillKind.read, 'devanagari');

    test('Spanish with Read and Write in Latin known from English is '
        'Find my level, not Verify', () {
      final shape = <SkillKey>[speak, hear, readLatin, writeLatin];
      final states = <SkillKey, SkillState>{
        speak: SkillState.learn,
        hear: SkillState.learn,
        readLatin: SkillState.know,
        writeLatin: SkillState.know,
      };
      final found = selectFindLevelSkills(
        (key) => states[key] ?? SkillState.leave,
        shape,
        verified: const <String>{},
        autoKnown: <SkillKey>{readLatin, writeLatin},
      );
      expect(found.verifying, isFalse);
      expect(
        found.skills,
        containsAll(<PlacementSkill>[
          PlacementSkill.read,
          PlacementSkill.write,
        ]),
      );
    });

    test('Marathi with Devanagari Read known from Hindi verifies the script '
        'and the words of Read are learning', () {
      final shape = <SkillKey>[speak, hear, readDeva];
      final states = <SkillKey, SkillState>{
        speak: SkillState.learn,
        readDeva: SkillState.know,
      };
      final found = selectFindLevelSkills(
        (key) => states[key] ?? SkillState.leave,
        shape,
        verified: const <String>{},
        scripts: const <String>['devanagari'],
        autoKnown: <SkillKey>{readDeva},
      );
      expect(found.verifying, isTrue);
      expect(found.skills, <PlacementSkill>{PlacementSkill.script});
      final after = selectFindLevelSkills(
        (key) => states[key] ?? SkillState.leave,
        shape,
        verified: const <String>{'script'},
        scripts: const <String>['devanagari'],
        autoKnown: <SkillKey>{readDeva},
      );
      expect(after.verifying, isFalse);
      expect(
        after.skills,
        containsAll(<PlacementSkill>[PlacementSkill.read, PlacementSkill.say]),
      );
    });

    test('a Read the learner marked Know, with no source in another '
        'language, still verifies', () {
      final found = selectFindLevelSkills(
        (key) => key == readLatin ? SkillState.know : SkillState.leave,
        <SkillKey>[speak, hear, readLatin, writeLatin],
        verified: const <String>{},
        autoKnown: const <SkillKey>{},
      );
      expect(found.verifying, isTrue);
      expect(found.skills, <PlacementSkill>{PlacementSkill.read});
    });
  });
}
