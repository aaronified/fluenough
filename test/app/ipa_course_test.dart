import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/ipa_course.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

import '../support/ipa_course.dart';

List<String> ids(Iterable<dynamic> cards) => <String>[
  for (final c in cards) c.id as String,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the IPA course for the languages learned', () {
    test('keeps the core cards and those of a language learned, in one '
        'list for every screen', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      final basics = state.deckById('ipa-en-basics')!;
      expect(ids(basics.cards), ['ipa-0001', 'ipa-0002', 'ipa-0003']);
      expect(basics.itemCount, 3);
      expect(ids(state.deckById('ipa-en-places')!.cards), [
        'ipa-0005',
        'ipa-0007',
      ]);
      // Every deck read through the app is the same one.
      expect(
        ids(
          state.decks
              .expand((e) => e.cards)
              .where((c) => c.deckId.startsWith('ipa')),
        ),
        ['ipa-0001', 'ipa-0002', 'ipa-0003', 'ipa-0005', 'ipa-0007'],
      );
      expect(state.deckOf(basics.cards.first), same(basics));
    });

    test('a deck with none left is not on offer', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.deckById('ipa-en-rare'), isNull);
      expect(state.decks.map((e) => e.id), isNot(contains('ipa-en-rare')));
    });

    test('the whole chart has every card', () async {
      final state = ipaApp(<String>['hi', 'ipa'], scope: IpaScope.whole);
      addTearDown(state.dispose);
      await state.load();
      expect(state.deckById('ipa-en-basics')!.cards, hasLength(4));
      expect(state.deckById('ipa-en-rare')!.cards, hasLength(2));
    });

    test('changing the scope, or the languages, changes it at once', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.deckById('ipa-en-rare'), isNull);
      state.settings.ipaScope = IpaScope.whole;
      expect(state.deckById('ipa-en-rare'), isNotNull);
      state.settings.ipaScope = IpaScope.mine;
      state.setLearningLanguages(<String>['hi', 'es', 'ipa']);
      expect(ids(state.deckById('ipa-en-basics')!.cards), [
        'ipa-0001',
        'ipa-0002',
        'ipa-0003',
        'ipa-0004',
      ]);
      expect(ids(state.deckById('ipa-en-places')!.cards), [
        'ipa-0005',
        'ipa-0006',
        'ipa-0007',
      ]);
    });

    test('a lesson teaches only the cards in scope', () async {
      final state = ipaApp(<String>['ipa', 'es']);
      addTearDown(state.dispose);
      await state.load();
      final taught = <String>{
        for (final item in state.lessonFor(
          DrillRequest.lesson(language: 'ipa'),
        ))
          item.card.id,
      };
      expect(taught, isNotEmpty);
      expect(
        taught,
        everyElement(
          isIn(['ipa-0001', 'ipa-0002', 'ipa-0004', 'ipa-0006', 'ipa-0007']),
        ),
      );
    });
  });

  group('who learns the IPA', () {
    test('a profile learning every language does not', () {
      expect(Profile.defaultProfile.learns('ipa'), isFalse);
      expect(Profile.defaultProfile.learns('hi'), isTrue);
    });

    test('a language chosen is learned, and the IPA only when chosen', () {
      const profile = Profile(id: 'p', languages: {'hi'});
      expect(profile.learns('ipa'), isFalse);
      expect(
        const Profile(id: 'p', languages: {'hi', 'ipa'}).learns('ipa'),
        isTrue,
      );
    });

    test('the scope is kept in the settings', () {
      final settings = SettingsNotifier()..ipaScope = IpaScope.whole;
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.ipaScope, IpaScope.whole);
      expect(SettingsNotifier().ipaScope, IpaScope.mine);
    });
  });

  group('production is chosen, not typed', () {
    test('in a review, and in a lesson', () async {
      final state = ipaApp(<String>['ipa'], scope: IpaScope.whole);
      addTearDown(state.dispose);
      await state.load();
      expect(
        state.isTyped(state.deckById('ipa-en-basics')!.cards.first),
        isFalse,
      );
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'ipa'));
      expect(
        lesson.where((i) => i.mode == DrillMode.production),
        everyElement(
          predicate<SessionItem>((i) => i.ask.chooses || i.ask.onlyShows),
        ),
      );
      // Once a symbol is taught, its production joins the reviews, chosen.
      final check = lesson.firstWhere((i) => i.ask != Ask.teach);
      state.record(check, 4);
      final today = state.sessionItems(const DrillRequest.today());
      final production = today.where((i) => i.mode == DrillMode.production);
      expect(production, isNotEmpty);
      expect(production.map((i) => i.ask), everyElement(Ask.chooseWord));
    });

    test('a language with a keyboard is still typed', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.isTyped(state.deckById('hi-en-words')!.cards.first), isTrue);
    });
  });

  group('the sounds of a word', () {
    test('are the IPA cards whose symbols occur in its IPA, of the whole '
        'chart whatever the scope', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      final word = state.deckById('hi-en-words')!.cards.first;
      expect(ids(state.soundsOfWord(word)), ['ipa-0005', 'ipa-0007']);
      // A symbol of Spanish, which this learner does not learn.
      final bud = state.deckById('hi-en-words')!.cards.last;
      expect(ids(state.soundsOfWord(bud)), ['ipa-0006']);
      expect(state.deckById('ipa-en-places')!.cards.map((c) => c.id), [
        'ipa-0005',
        'ipa-0007',
      ]);
    });

    test('a card without an IPA has none', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      final basics = state.deckById('ipa-en-basics')!.cards.first;
      expect(state.soundsOfWord(basics), isEmpty);
      expect(state.soundsOfWordRequest(basics), isNull);
    });

    test('are practised as a lesson, and the cards are the learner\'s while '
        'they are, and once answered', () async {
      final state = ipaApp(<String>['hi', 'ipa']);
      addTearDown(state.dispose);
      await state.load();
      final bud = state.deckById('hi-en-words')!.cards.last;
      final request = state.soundsOfWordRequest(bud)!;
      expect(request.cardIds, {'ipa-0006'});
      final items = state.soundsItems(request);
      expect(items.map((i) => i.card.id), everyElement('ipa-0006'));
      expect(items.first.ask, Ask.teach);
      // Out of the scope's tags, in the course while it is practised.
      expect(
        state.deckById('ipa-en-places')!.cards.map((c) => c.id),
        contains('ipa-0006'),
      );
      state.record(items[1], 4);
      state.unpinIpaCards();
      // Answered: recorded, scheduled, and so still in the course.
      expect(
        state.deckById('ipa-en-places')!.cards.map((c) => c.id),
        contains('ipa-0006'),
      );
      expect(state.isTaught(items[1].card), isTrue);
    });

    test(
      'a card not answered leaves the course when the session ends',
      () async {
        final state = ipaApp(<String>['hi', 'ipa']);
        addTearDown(state.dispose);
        await state.load();
        final bud = state.deckById('hi-en-words')!.cards.last;
        state.soundsItems(state.soundsOfWordRequest(bud)!);
        state.unpinIpaCards();
        expect(
          state.deckById('ipa-en-places')!.cards.map((c) => c.id),
          isNot(contains('ipa-0006')),
        );
      },
    );

    test('adding the course keeps what is learned, and a learner who chose '
        'nothing keeps learning every language', () async {
      final state = ipaApp(<String>['hi']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.learnsIpa, isFalse);
      state.addIpaCourse();
      expect(state.learnsIpa, isTrue);
      expect(state.learningCodes, {'hi', 'ipa'});

      final unchosen = ipaApp(<String>[]);
      addTearDown(unchosen.dispose);
      await unchosen.load();
      unchosen.addIpaCourse();
      expect(unchosen.learningCodes, {'hi', 'ipa'});
    });
  });
}
