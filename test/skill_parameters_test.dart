import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/core/scheduling/skill_parameters.dart';

/// FSRS-6's defaults with the first Good stability set to [w2]: a set that
/// tells itself apart by a word's first interval.
FittedParameters fitWith(double w2, {DateTime? at, int reviews = 500}) =>
    FittedParameters(
      values: <double>[...Fsrs.w]..[2] = w2,
      fittedAt: at ?? DateTime(2026, 10, 1),
      reviewCount: reviews,
    );

void main() {
  const hear = DrillMode.listening;
  const write = DrillMode.production;
  final monday = DateTime(2026, 10, 5, 9);
  final tuesday = DateTime(2026, 10, 6, 9);
  final wednesday = DateTime(2026, 10, 7, 9);

  group('which set schedules a skill', () {
    test('with no fit anywhere, the defaults', () {
      expect(SkillParameters.none.of('hi', hear), Fsrs.w);
      expect(SkillParameters.none.sourceOf('hi', hear), isNull);
    });

    test('the skill\'s own fit in the language', () {
      final hi = fitWith(5);
      final p = SkillParameters(
        fitted: {(language: 'hi', mode: hear): hi},
        lastStudied: {'hi': monday},
      );
      expect(p.of('hi', hear), hi.values);
      expect(p.sourceOf('hi', hear), 'hi');
      expect(p.forPair((cardId: 'hi-0231', mode: hear)), hi.values);
      expect(p.of('hi', write), Fsrs.w, reason: 'another skill: defaults');
    });

    test('a language without one takes the skill\'s fit in the language '
        'most recently studied', () {
      final hi = fitWith(5);
      final bn = fitWith(7);
      final p = SkillParameters(
        fitted: {
          (language: 'hi', mode: hear): hi,
          (language: 'bn', mode: hear): bn,
        },
        lastStudied: {'hi': monday, 'bn': tuesday, 'te': wednesday},
      );
      // te is the latest studied, but has no Hear fit: bn's is next.
      expect(p.sourceOf('te', hear), 'bn');
      expect(p.of('te', hear), bn.values);
      expect(p.of('hi', hear), hi.values, reason: 'its own comes first');
      expect(p.of('te', write), Fsrs.w, reason: 'no Write fit anywhere');
    });

    test('a fit that lost and kept the defaults is no baseline', () {
      // bn, studied last, was fitted first, lost, and so stores FSRS-6's
      // defaults; hi was fitted after and kept a set of its own.
      final bnLost = FittedParameters(
        values: Fsrs.w,
        fittedAt: monday,
        reviewCount: 500,
        lossBefore: 0.30,
        lossAfter: 0.31,
      );
      final hi = fitWith(5, at: tuesday);
      final p = SkillParameters(
        fitted: {
          (language: 'bn', mode: hear): bnLost,
          (language: 'hi', mode: hear): hi,
        },
        lastStudied: {'hi': monday, 'bn': tuesday},
      );
      expect(p.sourceOf('te', hear), 'hi');
      expect(p.of('te', hear), hi.values);
      expect(p.of('bn', hear), Fsrs.w, reason: 'its own set comes first');
      // A lost fit that kept a real set is still a baseline.
      final bnCopy = p.withFit(
        (language: 'bn', mode: hear),
        FittedParameters(
          values: fitWith(7).values,
          fittedAt: wednesday,
          reviewCount: 600,
          lossBefore: 0.30,
          lossAfter: 0.31,
        ),
      );
      expect(bnCopy.sourceOf('te', hear), 'bn');
      expect(bnCopy.sameAs(p), isFalse);
    });

    test('studying another language moves the baseline, and says so', () {
      final p = SkillParameters(
        fitted: {
          (language: 'hi', mode: hear): fitWith(5),
          (language: 'bn', mode: hear): fitWith(7),
        },
        lastStudied: {'hi': monday, 'bn': tuesday},
      );
      expect(p.sourceOf('te', hear), 'bn');

      final hiAgain = p.studied('hi', wednesday);
      expect(hiAgain.sourceOf('te', hear), 'hi');
      expect(hiAgain.sameAs(p), isFalse);

      final bnAgain = p.studied('bn', wednesday);
      expect(bnAgain.sameAs(p), isTrue, reason: 'still the latest');
      final te = p.studied('te', wednesday);
      expect(te.sameAs(p), isTrue, reason: 'te has no fit to give');
      expect(identical(p.studied('bn', monday), p), isTrue, reason: 'earlier');
    });

    test('a tie in time goes by language code, whatever the map order', () {
      final fits = {
        (language: 'hi', mode: hear): fitWith(5),
        (language: 'bn', mode: hear): fitWith(7),
      };
      final a = SkillParameters(
        fitted: fits,
        lastStudied: {'hi': monday, 'bn': monday},
      );
      final b = SkillParameters(
        fitted: Map.fromEntries(fits.entries.toList().reversed),
        lastStudied: {'bn': monday, 'hi': monday},
      );
      expect(a.sourceOf('te', hear), 'bn');
      expect(b.sourceOf('te', hear), 'bn');
    });

    test('a new fit is a change; merging keeps the later fit of a skill', () {
      final key = (language: 'hi', mode: hear);
      final old = fitWith(5, at: monday);
      final newer = fitWith(6, at: tuesday);
      final p = SkillParameters(fitted: {key: old});
      expect(p.withFit(key, newer).sameAs(p), isFalse);
      expect(p.merged({key: newer}).fitted[key], newer);
      expect(p.withFit(key, newer).merged({key: old}).fitted[key], newer);
      expect(
        p.merged({(language: 'bn', mode: hear): old}).fitted,
        hasLength(2),
      );
    });

    test('last studied is each language\'s latest review', () {
      expect(
        SkillParameters.lastStudiedIn([
          (cardId: 'hi-0001', at: tuesday),
          (cardId: 'bn-0001', at: monday),
          (cardId: 'hi-0002', at: monday),
        ]),
        {'hi': tuesday, 'bn': monday},
      );
    });

    test('a set that is not 21 values is refused', () {
      expect(
        () => FittedParameters(
          values: Fsrs.w.sublist(1),
          fittedAt: monday,
          reviewCount: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('the replay schedules each pair with its skill\'s set', () {
    LoggedReview review(String card, DrillMode mode, DateTime at, int grade) =>
        (
          key: (cardId: card, mode: mode),
          deckId: 'd',
          at: at,
          grade: grade,
          elapsed: Duration.zero,
          answerGiven: 'typed',
        );

    final hi = fitWith(9);
    final parameters = SkillParameters(
      fitted: {(language: 'hi', mode: write): hi},
      lastStudied: {'hi': tuesday, 'bn': monday},
    );

    test('as Fsrs.next with that set gives', () {
      final replayed = replayReviews([
        review('hi-0001', write, monday, 4),
        review('bn-0001', write, monday, 4),
        review('hi-0001', write, wednesday, 4),
      ], parameters: parameters);
      final first = Fsrs.next(null, 4, now: monday, parameters: hi.values);
      expect(replayed.events.first.after.stability, 9);
      expect(
        replayed.states[(cardId: 'hi-0001', mode: write)]!.stability,
        Fsrs.next(first, 4, now: wednesday, parameters: hi.values).stability,
      );
      // bn has no Write fit of its own: it starts from hi's.
      expect(replayed.states[(cardId: 'bn-0001', mode: write)]!.stability, 9);
    });

    test('without a set, as before', () {
      final replayed = replayReviews([review('hi-0001', write, monday, 4)]);
      expect(replayed.events.single.after.stability, Fsrs.w[2]);
    });

    test('an implied skill moves with its own set', () {
      final recognition = fitWith(3);
      final both = parameters.withFit((
        language: 'hi',
        mode: DrillMode.recognition,
      ), recognition);
      final replayed = replayReviews(
        [
          review('hi-0001', DrillMode.recognition, monday, 4),
          review('hi-0001', write, tuesday, 4),
        ],
        skills: const SkillMap(),
        parameters: both,
      );
      final seen = Fsrs.next(
        null,
        4,
        now: monday,
        parameters: recognition.values,
      );
      expect(
        replayed
            .states[(cardId: 'hi-0001', mode: DrillMode.recognition)]!
            .stability,
        Fsrs.implied(
          seen,
          SkillMap.implied,
          now: tuesday,
          parameters: recognition.values,
        ).stability,
      );
    });
  });
}
