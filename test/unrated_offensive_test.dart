// A deck of offensive words no native speaker has rated is merged but seen
// by the Offensive words review alone (#630; owner, 2026-10-24: "Merge,
// reviewer-only until rated"): never by a learner, with Adult content on or
// off. Once it carries the `rated` tag it follows the adult gate (#628).
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/review/review_waiting.dart';
import 'package:fluenough/features/review/review_words.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/review_fixture.dart';

void main() {
  group('a deck of offensive words no native speaker has rated', () {
    for (final adult in <bool>[true, false]) {
      test(
        'is never a learner\'s, with Adult content ${adult ? 'on' : 'off'}',
        () async {
          final state = await reviewState(rudeRated: false, adult: adult);
          expect(state.deckById(rudeDeck), isNull);
          expect(state.decks.map((d) => d.id), isNot(contains(rudeDeck)));
          expect(
            state.untaughtCards('te').map((c) => c.id),
            isNot(contains(rudeCard)),
          );
        },
      );
    }

    test(
      'is listed by the Offensive words review, which rates its words',
      () async {
        final state = await reviewState(rudeRated: false, reviewing: true);
        final language = state.deckById(wordsDeck)!.language;
        final listed = offensiveDecksIn(state, language.code);
        expect(listed.map((d) => d.deck.id), <String>[rudeDeck]);
        expect(listed.single.words.map((c) => c.id), <String>[rudeCard]);

        final waiting = waitingIn(state, language);
        expect(waiting.unrated.map((c) => c.card.id), <String>[rudeCard]);
        expect(waiting.offensive, 1);

        // A rating is kept and sent like any other.
        final rude = state.reviewDeckById(rudeDeck)!;
        state.reviewing.rate(
          rude,
          rude.cards.single,
          const WordRating(score: 8),
        );
        expect(
          state.reviewing.reviewOf(rude, rude.cards.single)?.rating?.score,
          8,
        );
        expect(waitingIn(state, language).unrated, isEmpty);
      },
    );

    test('is listed by the review only with Adult content on', () async {
      final state = await reviewState(rudeRated: false, adult: false);
      expect(state.reviewDeckById(rudeDeck), isNull);
      expect(offensiveDecksIn(state, 'te'), isEmpty);
      expect(state.reviewDecks.map((d) => d.id), isNot(contains(rudeDeck)));

      state.settings.adultContent = true;
      expect(state.reviewDeckById(rudeDeck), isNotNull);
      expect(
        offensiveDecksIn(state, 'te').map((d) => d.deck.id),
        contains(rudeDeck),
      );
    });

    test(
      'still warns of the words that sound like its words, unnamed',
      () async {
        final state = await reviewState(rudeRated: false);
        final alike = state.deckById(wordsDeck)!.cards.first;
        expect(rudeAlikesOf(state, alike).map((p) => p.partner.id), <String>[
          rudeCard,
        ]);
      },
    );
  });

  group('a rated deck of offensive words', () {
    test(
      'follows the adult gate: seen with Adult content on, hidden off',
      () async {
        final state = await reviewState(adult: true);
        expect(state.deckById(rudeDeck), isNotNull);
        expect(state.decks.map((d) => d.id), contains(rudeDeck));

        state.settings.adultContent = false;
        expect(state.deckById(rudeDeck), isNull);
        expect(state.reviewDeckById(rudeDeck), isNull);
        expect(offensiveDecksIn(state, 'te'), isEmpty);
      },
    );
  });
}
