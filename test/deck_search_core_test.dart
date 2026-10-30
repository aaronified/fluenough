import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart' show DeckParseException;
import 'package:fluenough/core/data/themes.dart';
import 'package:fluenough/core/search/fuzzy.dart';
import 'package:fluenough/core/search/query.dart';
import 'package:fluenough/core/search/script_of.dart';

void main() {
  group('typo-tolerant matching (#527)', () {
    test('travl and numbrs still find the travel and numbers decks', () {
      expect(matchWord('travl', <String>['travel']), MatchQuality.close);
      expect(matchWord('numbrs', <String>['numbers 1–20']), MatchQuality.close);
    });

    test('a swapped pair of letters is one typo: yuo finds you', () {
      expect(editDistance('yuo', 'you'), 1);
      expect(matchWord('yuo', <String>['you']), MatchQuality.close);
    });

    test('an exact word ranks above a start, above inside, above a typo', () {
      expect(
        matchWord('you', <String>['you (respectful)']),
        MatchQuality.whole,
      );
      expect(matchWord('you', <String>['your']), MatchQuality.start);
      expect(matchWord('you', <String>['thank you']), MatchQuality.whole);
      expect(matchWord('ank', <String>['thank']), MatchQuality.inside);
      expect(MatchQuality.whole.index < MatchQuality.close.index, isTrue);
    });

    test(
      'a word with nothing close finds nothing, and a short one is exact',
      () {
        expect(matchWord('helicoptr', <String>['bus, auto, cab']), isNull);
        expect(matchWord('xq', <String>['ab']), isNull);
        // Two letters are not corrected: "ye" is not "you".
        expect(matchWord('yo', <String>['you']), MatchQuality.start);
        expect(matchWord('ya', <String>['you']), isNull);
      },
    );

    test('a word in another script is matched exactly, never corrected', () {
      expect(matchWord('पानी', <String>['पानी']), MatchQuality.whole);
      expect(matchWord('पाना', <String>['पानी']), isNull);
    });

    test('the closest known word is offered for a typo', () {
      expect(closestWord('yuo', <String>['yes', 'you']), 'you');
      expect(closestWord('you', <String>['you']), isNull);
    });
  });

  group('the tokens', () {
    test('kind:grammar with text is a chip and the text', () {
      final p = parseSearch('kind:grammar you');
      expect(p.kind, SearchKind.grammar);
      expect(p.text, 'you');
      expect(p.pending, isNull);
    });

    test('a token being typed opens its values and makes no chip yet', () {
      final p = parseSearch('kind:gr');
      expect(p.chips, isEmpty);
      expect(p.pending, SearchToken.kind);
      expect(p.pendingPrefix, 'gr');
    });

    test('a space after a whole value makes the chip, and a theme must be '
        'one the course teaches', () {
      final p = parseSearch(
        'status:not-learnt theme:market ',
        themes: <String>['market'],
      );
      expect(p.status, CardStatus.notLearnt);
      expect(p.theme, 'market');
      expect(parseSearch('theme:market ').chips, isEmpty);
    });

    test('writing a search back puts the chips first, in token order', () {
      expect(
        writeSearch(<SearchToken, String>{
          SearchToken.theme: 'market',
          SearchToken.kind: 'words',
        }, 'tea'),
        'kind:words theme:market tea',
      );
    });
  });

  group('a card status', () {
    CardStatus of(List<SkillState> skills, {bool setAside = false}) =>
        cardStatusOf(setAside: setAside, skills: skills);

    test('no schedule is not learnt; every skill 21 days out is learnt', () {
      expect(
        of(const <SkillState>[SkillState(scheduled: false)]),
        CardStatus.notLearnt,
      );
      expect(
        of(const <SkillState>[
          SkillState(scheduled: true, intervalDays: 21),
          SkillState(scheduled: true, intervalDays: 40),
        ]),
        CardStatus.learnt,
      );
    });

    test('a skill short of 21 days or unscheduled leaves a card learning', () {
      expect(
        of(const <SkillState>[
          SkillState(scheduled: true, intervalDays: 40),
          SkillState(scheduled: true, intervalDays: 20),
        ]),
        CardStatus.learning,
      );
      expect(
        of(const <SkillState>[
          SkillState(scheduled: true, intervalDays: 40),
          SkillState(scheduled: false),
        ]),
        CardStatus.learning,
      );
    });

    test('forgetting wins over learning, struggling over forgetting, and '
        'set aside over all', () {
      const due = SkillState(scheduled: true, intervalDays: 3, due: true);
      expect(of(const <SkillState>[due]), CardStatus.forgetting);
      expect(
        of(const <SkillState>[
          SkillState(scheduled: true, due: true, lapses: 5),
        ]),
        CardStatus.struggling,
      );
      expect(of(const <SkillState>[due], setAside: true), CardStatus.setAside);
    });
  });

  group('the script of a query', () {
    test('every letter has a script, and the most common one wins', () {
      expect(scriptOf('पानी'), 'devanagari');
      expect(scriptOf('জল'), 'bengali');
      expect(scriptOf('ఎందుకు'), 'telugu');
      expect(scriptOf('water 2'), 'latin');
      expect(scriptOf('123 ?'), isNull);
    });

    test('a Chinese variant reads Han', () {
      expect(scriptBelongsTo('han', <String>['han_simplified']), isTrue);
      expect(scriptBelongsTo('latin', <String>['devanagari']), isFalse);
    });
  });

  group('theme tags', () {
    test('the transport theme carries the travel tag, others none', () {
      final themes = parseThemes(File('decks/themes.yaml').readAsStringSync());
      expect(themes.firstWhere((t) => t.id == 'transport').tags, <String>[
        'travel',
      ]);
      expect(themes.firstWhere((t) => t.id == 'first-words').tags, isEmpty);
    });

    test('tags must be a list of words', () {
      const bad =
          'schema: 1\nkind: themes\nthemes:\n'
          '  - { id: a, name: "A", tags: "x" }\n';
      expect(() => parseThemes(bad), throwsA(isA<DeckParseException>()));
    });
  });
}
