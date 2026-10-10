import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/reviewing.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';

import '../support/review_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('turning on makes a code once, from the secure source; How reviewing '
      'works opens by itself the first time only', () async {
    final state = await reviewState();
    addTearDown(state.dispose);
    final reviewing = state.reviewing;
    expect(reviewing.on, isFalse);
    expect(reviewing.code, isNull);

    expect(reviewing.turnOn(), isTrue);
    final code = reviewing.code!;
    expect(RaterCode.tryParse('$code'), code);
    expect(reviewing.on, isTrue);

    reviewing.turnOff();
    expect(reviewing.on, isFalse);
    expect(reviewing.code, code, reason: 'turning off keeps the code');

    expect(reviewing.turnOn(), isFalse);
    expect(reviewing.code, code);
  });

  test('reviews outlive a restart, as the settings do', () async {
    final state = await reviewState(reviewing: true);
    addTearDown(state.dispose);
    final words = state.deckById(wordsDeck)!;
    final card = words.cards.first;
    state.reviewing.markRight(words, card);
    state.reviewing.suggest(
      words,
      words.cards.last,
      const Suggestion(part: CardPart.meaning, now: 'mother', text: 'mum'),
    );

    final restored = SettingsNotifier()..restore(state.settings.toStored());
    expect(restored.reviewDecks, isTrue);
    expect(restored.raterCode, '${state.reviewing.code}');
    expect(restored.reviewIntroShown, isTrue);
    expect(restored.reviews.toJson(), state.settings.reviews.toJson());
    expect(restored.reviews.card(wordsDeck, card.id)!.right, isTrue);
  });

  test('a stored code that fails its check is not restored', () {
    final restored = SettingsNotifier()
      ..restore(<String, String>{'rater_code': 'FL-7K3M-Q9TD-7'});
    expect(restored.raterCode, isNull);
  });

  test('Looks right and a suggestion take each other\'s place; a rating and '
      'a pair check stay', () async {
    final state = await reviewState(reviewing: true);
    addTearDown(state.dispose);
    final reviewing = state.reviewing;
    final words = state.deckById(wordsDeck)!;
    final card = words.cards.first;
    reviewing.checkAlike(
      words,
      card,
      const AlikeCheck(
        partner: rudeCard,
        kind: AlikeKind.sound,
        real: true,
        care: 'Keep the short i.',
      ),
    );
    reviewing.markRight(words, card);
    expect(reviewing.reviewOf(words, card)!.right, isTrue);
    reviewing.suggest(
      words,
      card,
      const Suggestion(part: CardPart.notes, now: '', text: 'Formal word'),
    );
    final review = reviewing.reviewOf(words, card)!;
    expect(review.right, isFalse);
    expect(review.suggestion!.text, 'Formal word');
    expect(review.alike!.care, 'Keep the short i.');
    reviewing.markRight(words, card);
    expect(reviewing.reviewOf(words, card)!.suggestion, isNull);
  });

  test('several decks go in one mail, a file each, to Fluenough; then they '
      'are sent, and only later changes wait', () async {
    final share = FixedMailShare();
    final state = await reviewState(share: share, reviewing: true);
    addTearDown(state.dispose);
    final reviewing = state.reviewing;
    final words = state.deckById(wordsDeck)!;
    final rude = state.deckById(rudeDeck)!;
    for (final card in words.cards) {
      reviewing.markRight(words, card);
    }
    reviewing.rate(
      rude,
      rude.cards.single,
      const WordRating(score: 4, region: 'coastal-andhra'),
    );
    reviewing.signOff(words);
    expect(reviewing.unsent.map((d) => d.deckId), <String>[
      wordsDeck,
      rudeDeck,
    ]);

    final outcome = await reviewing.send(reviewing.unsent, body: 'For you');
    expect(outcome, ReviewSendOutcome.inMailApp);
    final mail = share.shared.single;
    expect(mail.to, <String>[AppLinks.feedbackEmail]);
    expect(mail.subject, '[Fluenough review] ${reviewing.code} (te)');
    expect(mail.body, 'For you');
    expect(mail.files.map((f) => f.name), <String>[
      'fluenough-review-$wordsDeck.json',
      'fluenough-review-$rudeDeck.json',
    ]);
    final file = jsonDecode(mail.files.first.text) as Map<String, Object?>;
    expect(file['rater_code'], '${reviewing.code}');
    expect(file['language'], 'te');
    expect(file['deck'], wordsDeck);
    expect(file['app_version'], AppInfo.version);
    expect(file['made'], state.now().toUtc().toIso8601String());
    expect(file['signed_off'], isTrue);
    expect((file['cards']! as List).length, 2);

    expect(reviewing.unsent, isEmpty);
    // What was done still shows.
    expect(reviewing.reviews.of(wordsDeck)!.markedCount, 2);
  });

  test('Send the last mail again puts back what the last mail carried, '
      'once', () async {
    final share = FixedMailShare();
    final state = await reviewState(share: share, reviewing: true);
    addTearDown(state.dispose);
    final reviewing = state.reviewing;
    final words = state.deckById(wordsDeck)!;
    expect(reviewing.lastSent, isEmpty);
    reviewing.markRight(words, words.cards.first);
    await reviewing.send(reviewing.unsent, body: '');
    expect(reviewing.unsent, isEmpty);
    expect(reviewing.lastSent.map((d) => d.deckId), <String>[wordsDeck]);

    reviewing.sendAgain();
    expect(reviewing.unsent.map((d) => d.deckId), <String>[wordsDeck]);
    expect(reviewing.lastSent, isEmpty);
    reviewing.sendAgain();
    expect(reviewing.unsent, hasLength(1));
    // And it goes again, whole.
    await reviewing.send(reviewing.unsent, body: '');
    expect(share.shared, hasLength(2));
    expect(
      share.shared.last.files.single.text,
      share.shared.first.files.single.text,
    );
  });

  test('nothing is marked sent when no mail app takes it, or the share '
      'fails', () async {
    final share = FixedMailShare(shares: false);
    final state = await reviewState(share: share, reviewing: true);
    addTearDown(state.dispose);
    final reviewing = state.reviewing;
    final words = state.deckById(wordsDeck)!;
    reviewing.markRight(words, words.cards.first);
    expect(
      await reviewing.send(reviewing.unsent, body: ''),
      ReviewSendOutcome.noMailApp,
    );
    expect(reviewing.unsent, hasLength(1));
    share.error = Exception('no channel');
    expect(
      await reviewing.send(reviewing.unsent, body: ''),
      ReviewSendOutcome.failed,
    );
    expect(reviewing.unsent, hasLength(1));
    expect(
      await reviewing.send(const <DeckReview>[], body: ''),
      ReviewSendOutcome.nothingToSend,
    );
  });

  test('a deck listing the reviewer\'s code is one they helped build; a '
      'person\'s name is never read as a code', () async {
    final state = await reviewState(
      authors: const <String>[reviewerCode, otherCode, 'Asha'],
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
      )..raterCode = reviewerCode,
    );
    addTearDown(state.dispose);
    final words = state.deckById(wordsDeck)!;
    expect(state.reviewing.helpedBuild(words), isTrue);
    expect(state.reviewing.reviewerCount(words), 2);
    expect(state.reviewing.helpedBuild(state.deckById(rudeDeck)!), isFalse);
  });

  test('a deck whose cards list the reviewer\'s code in checked_by is one '
      'they helped build; each code counts once', () async {
    final state = await reviewState(
      checkedBy: const <String>[reviewerCode, otherCode],
      authors: const <String>[otherCode],
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
      )..raterCode = reviewerCode,
    );
    addTearDown(state.dispose);
    final words = state.deckById(wordsDeck)!;
    expect(words.deck.checkedBy[plainCard], <String>[reviewerCode, otherCode]);
    expect(state.reviewing.helpedBuild(words), isTrue);
    expect(state.reviewing.reviewerCount(words), 2);
    expect(state.reviewing.helpedBuild(state.deckById(rudeDeck)!), isFalse);
  });
}
