import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  final code = RaterCode.tryParse(
    'FL-7K3M-Q9TD-${RaterCode.checkSymbol('7K3MQ9TD')}',
  )!;

  Reviews marked() => const Reviews()
      .withCard(
        'te-family',
        'te',
        'te-0001',
        monday,
        (_) => CardReview(at: monday, right: true),
      )
      .withCard(
        'te-family',
        'te',
        'te-0384',
        monday,
        (_) => CardReview(
          at: monday,
          suggestion: const Suggestion(
            part: CardPart.notes,
            now: 'Formally కుమార్తె (kumārte).',
            text: 'In speech also అమ్మాయి (ammāyi).',
            why: 'As common',
          ),
        ),
      );

  test('a card is marked right or suggested, never both', () {
    final reviews = marked();
    expect(reviews.card('te-family', 'te-0001')!.marked, isTrue);
    expect(reviews.card('te-family', 'te-0384')!.suggestion, isNotNull);
    expect(reviews.of('te-family')!.markedCount, 2);
    // Read back, a stored card with both keeps the suggestion.
    final both = CardReview.fromJson(<String, Object?>{
      'at': monday.toIso8601String(),
      'looks_right': true,
      'suggestion': <String, Object?>{'part': 'word', 'now': 'a', 'text': 'b'},
    })!;
    expect(both.right, isFalse);
    expect(both.suggestion!.text, 'b');
  });

  test('a change that leaves nothing removes the card', () {
    final reviews = marked().withCard(
      'te-family',
      'te',
      'te-0001',
      monday,
      (_) => CardReview(at: monday),
    );
    expect(reviews.card('te-family', 'te-0001'), isNull);
  });

  test('a change after a sign-off takes the sign-off back', () {
    var reviews = marked().signOff('te-family', 'te', monday);
    expect(reviews.of('te-family')!.signedOff, monday);
    reviews = reviews.withCard(
      'te-family',
      'te',
      'te-0001',
      monday,
      (old) => CardReview(at: monday, right: true),
    );
    expect(reviews.of('te-family')!.signedOff, isNull);
  });

  test('sent reviews stay, but only later changes are unsent', () {
    final later = monday.add(const Duration(hours: 1));
    var reviews = marked().sentAt(<String>['te-family'], monday);
    expect(reviews.unsent, isEmpty);
    expect(reviews.of('te-family')!.markedCount, 2);
    reviews = reviews.withCard(
      'te-family',
      'te',
      'te-0002',
      later,
      (_) => CardReview(at: later, right: true),
    );
    expect(reviews.unsent.single.unsentCards.keys, <String>['te-0002']);
    reviews = reviews.signOff('te-family', 'te', later);
    expect(reviews.unsent.single.unsentSignOff, isTrue);
  });

  test('stored and read back whole', () {
    final reviews = marked()
        .withCard(
          'te-rude',
          'te',
          'te-0900',
          monday,
          (_) => CardReview(
            at: monday,
            rating: const WordRating(
              score: 4,
              region: 'coastal-andhra',
              friendly: Friendly.yes,
            ),
          ),
        )
        .withCard(
          'te-family',
          'te',
          'te-0450',
          monday,
          (_) => CardReview(
            at: monday,
            alike: const AlikeCheck(
              partner: 'te-0900',
              kind: AlikeKind.sound,
              real: true,
              care: 'Keep the short i at the start.',
            ),
          ),
        )
        .signOff('te-rude', 'te', monday);
    final back = Reviews.fromJson(reviews.toJson())!;
    expect(back.toJson(), reviews.toJson());
    expect(back.card('te-rude', 'te-0900')!.rating!.score, 4);
    expect(back.card('te-family', 'te-0450')!.alike!.care, startsWith('Keep'));
    expect(back.of('te-rude')!.signedOff, monday);
  });

  test('a broken store reads as nothing, a broken card is left out', () {
    expect(Reviews.fromJson('not json'), isNull);
    expect(Reviews.fromJson('[]'), isNull);
    final back = Reviews.fromJson(
      jsonEncode(<String, Object?>{
        'te-family': <String, Object?>{
          'language': 'te',
          'cards': <String, Object?>{
            'te-0001': <String, Object?>{
              'at': monday.toIso8601String(),
              'looks_right': true,
            },
            'te-0002': <String, Object?>{'at': 'never'},
          },
        },
      }),
    )!;
    expect(back.of('te-family')!.cards.keys, <String>['te-0001']);
  });

  test('a rating is 1 to 9', () {
    expect(WordRating.fromJson(<String, Object?>{'score': 0}), isNull);
    expect(WordRating.fromJson(<String, Object?>{'score': 10}), isNull);
    expect(WordRating.fromJson(<String, Object?>{'score': 9})!.score, 9);
  });

  test('the file carries code, language, deck, app version and time, and '
      'the unsent cards in deck order', () {
    final deck = marked().of('te-family')!;
    final text = ReviewFile.encode(
      deck,
      code: code,
      appVersion: '0.3.4',
      made: monday,
      order: <String>['te-0384', 'te-0001'],
    );
    final json = jsonDecode(text) as Map<String, Object?>;
    expect(json['format'], 'fluenough-review');
    expect(json['version'], 1);
    expect(json['rater_code'], '$code');
    expect(json['language'], 'te');
    expect(json['deck'], 'te-family');
    expect(json['app_version'], '0.3.4');
    expect(json['made'], '2026-10-12T09:00:00.000Z');
    expect(json['signed_off'], isFalse);
    final cards = json['cards']! as List<Object?>;
    expect(
      <Object?>[for (final c in cards) (c! as Map)['card']],
      <String>['te-0384', 'te-0001'],
    );
    expect((cards.last! as Map)['looks_right'], isTrue);
    expect(ReviewFile.name('te-family'), 'fluenough-review-te-family.json');
  });

  test('the subject has the code and every language once', () {
    final reviews = marked().withCard(
      'bn-family',
      'bn',
      'bn-0001',
      monday,
      (_) => CardReview(at: monday, right: true),
    );
    expect(
      ReviewMail.subject(code, reviews.decks.values),
      '[Fluenough review] $code (te, bn)',
    );
  });
}
