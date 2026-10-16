import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/ipa_course.dart';
import 'package:fluenough/core/models/card.dart';

Card symbol(String id, String target, {List<String> tags = const []}) => Card(
  id: id,
  deckId: 'ipa-en-basics',
  target: target,
  native: 'the sound $target',
  tags: tags,
);

void main() {
  group('the cards of a scope', () {
    final core = symbol('a', 'ˈ', tags: ['core']);
    final hindi = symbol('b', 'ʈ', tags: ['hi']);
    final both = symbol('c', 'pʰ', tags: ['hi', 'es']);
    final zulu = symbol('d', 'ǃ', tags: ['zu']);
    final untagged = symbol('e', 'ɸ');

    test('the whole chart has every card', () {
      for (final card in [core, hindi, both, zulu, untagged]) {
        expect(ipaCardInScope(card, IpaScope.whole, {}), isTrue);
      }
    });

    test(
      'my languages have the core cards and those of a language learned',
      () {
        final learned = {'hi'};
        expect(ipaCardInScope(core, IpaScope.mine, learned), isTrue);
        expect(ipaCardInScope(hindi, IpaScope.mine, learned), isTrue);
        expect(ipaCardInScope(both, IpaScope.mine, learned), isTrue);
        expect(ipaCardInScope(zulu, IpaScope.mine, learned), isFalse);
        expect(ipaCardInScope(untagged, IpaScope.mine, learned), isFalse);
        expect(ipaCardInScope(hindi, IpaScope.mine, {'es'}), isFalse);
      },
    );

    test('a card kept, as one answered, is always in', () {
      expect(ipaCardInScope(zulu, IpaScope.mine, {}, kept: {'d'}), isTrue);
    });

    test('a scope is found by its name', () {
      expect(IpaScope.tryParse('whole'), IpaScope.whole);
      expect(IpaScope.tryParse('mine'), IpaScope.mine);
      expect(IpaScope.tryParse('everything'), isNull);
      expect(IpaScope.tryParse(null), isNull);
    });
  });

  group('the sounds of a word', () {
    final course = <Card>[
      symbol('0', '/ /'),
      symbol('1', 'ˈ'),
      symbol('2', 'ː'),
      symbol('3', 'pʰ'),
      symbol('4', 'p'),
      symbol('5', 'ɳ'),
      symbol('6', 'ɒ'),
      symbol('7', '.'),
    ];

    List<String> sounds(String ipa) => <String>[
      for (final card in ipaCardsFor(ipa, course)) card.id,
    ];

    test('are the symbols that occur in it, in the course\'s order', () {
      expect(sounds('pʰəɳ'), ['3', '4', '5']);
      expect(sounds('ɒ'), ['6']);
    });

    test('include the marks that occur, and never the slashes, brackets '
        'or the full stop', () {
      expect(sounds('/ˈpɒː/'), ['1', '2', '4', '6']);
      expect(sounds('[p.ɒ]'), ['4', '6']);
    });

    test('are none for an empty transcription or one with no symbol', () {
      expect(sounds(''), isEmpty);
      expect(sounds(' / / '), isEmpty);
      expect(sounds('kəl'), isEmpty);
    });
  });
}
