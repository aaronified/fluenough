import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/review_pairs.dart';

/// Who can review a course, a language taught from another (#462): one who
/// knows both languages and reads both scripts.
void main() {
  const bnEn = ReviewPair('bn', 'en');
  const teEn = ReviewPair('te', 'en');
  const hiBn = ReviewPair('hi', 'bn');

  ReviewerLanguages reviewer(Map<String, bool> scripts, [Set<String>? known]) =>
      ReviewerLanguages(
        known: known ?? scripts.keys.toSet(),
        readsScript: scripts,
      );

  group('a pair', () {
    test('is kept as target/native and read back', () {
      expect(bnEn.key, 'bn/en');
      expect(ReviewPair.parse('bn/en'), bnEn);
      for (final bad in <String>['bn', 'bn/en/x', 'BN/en', '', 'bn/']) {
        expect(ReviewPair.parse(bad), isNull, reason: bad);
      }
    });
  });

  group('eligibility', () {
    test('both languages known and both scripts read', () {
      final r = reviewer(const <String, bool>{'bn': true, 'en': true});
      expect(r.canReview(bnEn), isTrue);
      expect(r.blockOf(bnEn), isNull);
    });

    test('a language not known blocks, the language reviewed first', () {
      final r = reviewer(const <String, bool>{'en': true});
      expect(r.blockOf(teEn), PairBlock.unknownTarget);
      final s = reviewer(const <String, bool>{'bn': true});
      expect(s.blockOf(bnEn), PairBlock.unknownNative);
    });

    test('a script not read blocks, as the language reviewed or as the '
        'one taught from', () {
      final r = reviewer(const <String, bool>{'bn': false, 'en': true});
      expect(r.blockOf(bnEn), PairBlock.targetScript);
      final s = reviewer(const <String, bool>{
        'hi': true,
        'bn': false,
        'en': true,
      });
      expect(s.blockOf(hiBn), PairBlock.nativeScript);
      expect(s.canReview(hiBn), isFalse);
    });

    test('until every known language\'s script is answered, nothing can '
        'be reviewed', () {
      final r = reviewer(
        const <String, bool>{'bn': true},
        const <String>{'bn', 'en'},
      );
      expect(r.scriptsAnswered, isFalse);
      expect(r.blockOf(bnEn), PairBlock.scriptsUnanswered);
      expect(
        reviewer(const <String, bool>{}, const <String>{}).scriptsAnswered,
        isFalse,
      );
    });
  });

  group('the pairs reviewed', () {
    final all = <ReviewPair>[bnEn, teEn, hiBn];
    final r = reviewer(const <String, bool>{
      'bn': true,
      'en': true,
      'hi': true,
    });

    test('chosen pairs, only those that can be reviewed', () {
      expect(
        reviewedPairs(
          chosenPairs: const <String>{'bn/en', 'te/en', 'junk'},
          chosenLanguages: const <String>{'hi'},
          offered: all,
          reviewer: r,
        ),
        <ReviewPair>{bnEn},
      );
    });

    test('languages chosen before pairs become their eligible pairs', () {
      expect(
        reviewedPairs(
          chosenPairs: null,
          chosenLanguages: const <String>{'bn', 'te'},
          offered: all,
          reviewer: r,
        ),
        <ReviewPair>{bnEn},
      );
    });

    test('before any choice, the pairs of the languages known', () {
      expect(
        reviewedPairs(
          chosenPairs: null,
          chosenLanguages: null,
          offered: all,
          reviewer: r,
        ),
        <ReviewPair>{bnEn, hiBn},
        reason: 'te is not known',
      );
    });
  });

  group('settings', () {
    test('keep the pairs and the script answers, and an older choice by '
        'language stays as it was', () {
      final stored =
          (SettingsNotifier(spokenLanguages: const <String>['en', 'bn'])
                ..reviewLanguages = const <String>{'bn'}
                ..reviewPairs = const <String>{'bn/en'}
                ..scriptsRead = const <String, bool>{'en': true, 'bn': false})
              .toStored();
      final back = SettingsNotifier()..restore(stored);
      expect(back.reviewPairs, <String>{'bn/en'});
      expect(back.reviewLanguages, <String>{'bn'});
      expect(back.scriptsRead, <String, bool>{'en': true, 'bn': false});

      final none = SettingsNotifier()..restore(SettingsNotifier().toStored());
      expect(none.reviewPairs, isNull);
      expect(none.scriptsRead, isEmpty);
    });
  });
}
