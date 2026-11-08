// The outcome log of Find my level V3, its join with the learner's real
// reviews, the bounded corrections, the export, and the re-fit with simulated
// learners.
import 'dart:convert';
import 'dart:math' as math;

import 'package:fluenough/core/placement/outcome_log.dart';
import 'package:fluenough/core/placement/placement_profile.dart';
import 'package:fluenough/core/placement/profile_refit.dart';
import 'package:flutter_test/flutter_test.dart';

const SkillOutcome _read = SkillOutcome(
  start: 14,
  low: 11,
  high: 17,
  label: 'fairlySure',
);

List<ReviewSample> _reviews(int unitsFromStart, int n, double right) => [
  for (var i = 0; i < n; i++)
    ReviewSample(
      skill: 'read',
      unitsFromStart: unitsFromStart,
      correct: i < n * right,
    ),
];

PlacementOutcome _outcome(
  double carefulness,
  Map<String, String> signals, {
  String language = 'es',
}) => PlacementOutcome(
  language: language,
  day: 20000,
  profileVersion: 1,
  band: 'b1',
  carefulness: carefulness,
  skills: const <String, SkillOutcome>{'read': _read},
  signals: signals,
);

void main() {
  group('the join with real reviews', () {
    test('too few reviews say nothing', () {
      expect(
        signalOf(_read, _reviews(0, 10, 0.1)),
        PlacementSignal.insufficient,
      );
    });

    test('credited pairs answered badly: placed too high', () {
      expect(signalOf(_read, _reviews(0, 40, 0.5)), PlacementSignal.tooHigh);
    });

    test('pairs just above the start answered right: placed too low', () {
      expect(
        signalOf(_read, <ReviewSample>[
          ..._reviews(0, 40, 0.9),
          ..._reviews(2, 40, 0.98),
        ]),
        PlacementSignal.tooLow,
      );
    });

    test('pairs beyond the range answered right: the range was too narrow', () {
      expect(
        signalOf(
          const SkillOutcome(start: 14, low: 13, high: 15, label: 'fairlySure'),
          <ReviewSample>[..._reviews(0, 40, 0.9), ..._reviews(2, 40, 0.98)],
        ),
        PlacementSignal.rangeTooNarrow,
      );
    });

    test('a consistent placement is ok', () {
      expect(
        signalOf(_read, <ReviewSample>[
          ..._reviews(0, 40, 0.9),
          ..._reviews(2, 40, 0.6),
        ]),
        PlacementSignal.ok,
      );
    });
  });

  group('the corrections', () {
    const tooHigh = SignalTally(tooHigh: 12, ok: 38);
    test('wait for enough evidence', () {
      expect(
        correctedCarefulness(
          tally: const SignalTally(tooHigh: 10, ok: 10),
          current: 0,
          hasEdge: true,
        ),
        0,
      );
    });

    test('move one step toward the edge when too many were too high, and '
        'back when too many were too low (reversible)', () {
      final up = correctedCarefulness(
        tally: tooHigh,
        current: 0,
        hasEdge: true,
      );
      expect(up, 0.25);
      final down = correctedCarefulness(
        tally: const SignalTally(tooLow: 25, ok: 25),
        current: up,
        hasEdge: true,
      );
      expect(down, 0);
    });

    test('never leave 0 to 1, and never move a language with no edge', () {
      expect(
        correctedCarefulness(tally: tooHigh, current: 0.9, hasEdge: true),
        1,
      );
      expect(
        correctedCarefulness(tally: tooHigh, current: 1, hasEdge: true),
        1,
      );
      expect(
        correctedCarefulness(tally: tooHigh, current: 0, hasEdge: false),
        0,
      );
    });

    test('the profile at any carefulness is inside the language edge', () {
      const edge = PlacementProfile.safestEdge;
      for (final c in <double>[-1, 0, 0.3, 0.75, 1, 5]) {
        final p = profileAt(c, edge);
        expect(p.declarationWeight, inInclusiveRange(0, 0.7));
        expect(p.temper, inInclusiveRange(edge.temper, 0.85));
        expect(p.togetherShare, inInclusiveRange(edge.togetherShare, 0.7));
        expect(p.standApartItems, inInclusiveRange(14, edge.standApartItems));
        expect(p.mixedBonus, inInclusiveRange(edge.mixedBonus, 0.3));
        expect(p.secondsScale, isEmpty);
        expect(carefulnessOf(p, edge), closeTo(c.clamp(0.0, 1.0), 0.05));
      }
    });
  });

  group('the record and the export', () {
    test('hold no personal content and read back', () {
      final text = exportOutcomes(<PlacementOutcome>[
        _outcome(0.5, <String, String>{'read': 'tooHigh'}),
      ], '1.0.0');
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json.keys, <String>['schema', 'kind', 'app', 'outcomes']);
      final record = (json['outcomes'] as List).single as Map<String, dynamic>;
      expect(record.keys.toSet(), <String>{
        'language',
        'day',
        'profile',
        'carefulness',
        'band',
        'skills',
        'items',
        'right',
        'wrong',
        'dontKnow',
        'drill',
        'signals',
      });
      final back = importOutcomes(text).single;
      expect(back.skills['read']!.high, 17);
      expect(back.signals['read'], 'tooHigh');
      expect(back.carefulness, 0.5);
    });

    test('a malformed record or file is skipped, never an error', () {
      expect(importOutcomes('not json'), isEmpty);
      expect(importOutcomes('{"schema": 9}'), isEmpty);
      expect(
        importOutcomes(
          '{"schema": 1, "outcomes": [1, {"language": "es"}, '
          '{"language": "ES", "day": 1, "profile": 1, "band": "a1", '
          '"skills": {}}]}',
        ),
        isEmpty,
      );
    });
  });

  group('the re-fit, with simulated learners', () {
    // A language whose placements are too high at a rate that falls with the
    // carefulness: rate = 0.30 - 0.30 c (so 5% at c = 0.8333).
    List<PlacementOutcome> simulate(
      int n,
      List<double> levels,
      math.Random rng, {
      double a = 0.30,
      double b = 0.30,
      String language = 'es',
    }) => <PlacementOutcome>[
      for (var i = 0; i < n; i++)
        () {
          final c = levels[i % levels.length];
          final high = rng.nextDouble() < a - b * c;
          return _outcome(c, <String, String>{
            'read': high ? 'tooHigh' : 'ok',
          }, language: language);
        }(),
    ];

    test('recovers the carefulness the data was made with', () {
      final outcomes = simulate(4000, <double>[
        0,
        0.25,
        0.5,
        0.75,
        1,
      ], math.Random(7));
      final r = refitLanguage('es', outcomes, current: 0);
      expect(r.moved, isTrue);
      expect(r.carefulness, closeTo(0.85, 0.1));
      expect(r.carefulness, inInclusiveRange(0, 1));
    });

    test('a language that is already safe stays at the default', () {
      final outcomes = simulate(
        4000,
        <double>[0, 0.5, 1],
        math.Random(3),
        a: 0.02,
        b: 0.02,
      );
      final r = refitLanguage('es', outcomes, current: 0);
      expect(r.carefulness, 0);
    });

    test('refuses without enough data, without variation, without an edge, '
        'and when more care does not help', () {
      final rng = math.Random(1);
      expect(
        refitLanguage(
          'es',
          simulate(50, <double>[0, 1], rng),
          current: 0,
        ).moved,
        isFalse,
      );
      final one = refitLanguage(
        'es',
        simulate(1000, <double>[0], rng),
        current: 0,
      );
      expect(one.moved, isFalse);
      expect(one.reason, contains('one carefulness'));
      final hi = refitLanguage(
        'hi',
        simulate(4000, <double>[0, 0.5, 1], rng, language: 'hi'),
        current: 0,
      );
      expect(hi.moved, isFalse);
      expect(hi.reason, contains('no gated edge'));
      final flat = refitLanguage(
        'es',
        simulate(4000, <double>[0, 0.5, 1], rng, b: 0),
        current: 0,
      );
      expect(flat.moved, isFalse);
    });

    test('writes a profile that stays inside the clamps, with a higher '
        'version, and leaves the other languages alone', () {
      final asset =
          '{"schema": 1, "killSwitch": false, '
          '"default": {"version": 1}, "languages": '
          '{"fr": {"version": 5, "temper": 0.8}}}';
      final r = refitLanguage(
        'es',
        simulate(4000, <double>[0, 0.5, 1], math.Random(5)),
        current: 0,
      );
      final text = applyRefit(asset, <RefitResult>[r]);
      final profiles = PlacementProfiles.parse(text);
      expect(profiles.isFitted('es'), isTrue);
      expect(profiles.isFitted('fr'), isFalse);
      final es = profiles.resolve('es', PlacementBand.b1);
      const edge = PlacementProfile.safestEdge;
      expect(es.version, 2);
      expect(es.temper, inInclusiveRange(edge.temper, 0.85));
      expect(es.declarationWeight, inInclusiveRange(0, 0.7));
      expect(es.standApartItems, inInclusiveRange(14, edge.standApartItems));
      expect(es.secondsScale, isEmpty);
      expect(es.climbQuantile, 0.12);
      // Another language is untouched.
      expect((jsonDecode(text) as Map)['languages']['fr'], <String, dynamic>{
        'version': 5,
        'temper': 0.8,
      });
      // A language that did not move is not written.
      final held = applyRefit(asset, <RefitResult>[
        refitLanguage('hi', const <PlacementOutcome>[], current: 0),
      ]);
      expect(PlacementProfiles.parse(held).isFitted('hi'), isFalse);
    });
  });
}
