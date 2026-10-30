/// Writes the daily questions from card data (#519), the weakest data
/// first. Pure Dart: no Flutter, no clock, nothing random, so every
/// reviewer is asked the same questions in the same order and two of them
/// can agree on a data point.
library;

import '../models/card.dart';
import '../models/deck.dart';
import 'card_fields.dart' show fromWiktionary;
import 'review_question.dart';

/// How many reviewers' sign-offs settle a card: with this many codes in its
/// `checked_by` the card is not asked about at all.
const int _signedOffEnough = 2;

/// How many of a card's examples are asked about, the first ones: a card
/// with many does not fill the day.
const int maxExamplesAsked = 2;

/// A picture proposed for a card, with the exact file (#523). The Wiktionary
/// import lists these in its report, and nothing keeps them in the decks yet,
/// so the generator takes them as input: whatever later persists them hands
/// them here, and the image question works end to end without another change.
class ImageProposal {
  const ImageProposal({
    required this.language,
    required this.card,
    required this.file,
    this.credit,
    this.license,
  });

  final String language;
  final String card;

  /// The Commons file name, such as `Cat.jpg`: the answer pins it.
  final String file;
  final String? credit;
  final String? license;
}

/// The questions for [decks], the weakest data first. Decks are taken in
/// order, and a card in several decks is asked about once. Left out:
/// decks of offensive words (reviewed apart), generated and grammar cards,
/// letters and digits, cards at least two reviewers signed off, and every
/// id in [skip] (what this reviewer answered, or put off today).
List<ReviewQuestion> generateQuestions(
  Iterable<Deck> decks, {
  Set<String> skip = const <String>{},
  Iterable<ImageProposal> images = const <ImageProposal>[],
}) {
  final out = <ReviewQuestion>[];
  final seen = <String>{};
  // A confusable may name another card: its word is that card's.
  final cards = <String, Card>{
    for (final deck in decks)
      for (final card in deck.cards) card.id: card,
  };
  final imagesOf = <String, List<ImageProposal>>{};
  for (final proposal in images) {
    (imagesOf['${proposal.language}|${proposal.card}'] ??= <ImageProposal>[])
        .add(proposal);
  }
  for (final deck in decks) {
    if (deck.tags.contains('offensive')) continue;
    for (final card in deck.cards) {
      if (card.practiceOnly ||
          card.rule != null ||
          card.isLetterOrDigit ||
          card.target.trim().isEmpty ||
          !seen.add(card.id)) {
        continue;
      }
      final signed = deck.checkedBy[card.id]?.length ?? 0;
      if (signed >= _signedOffEnough) continue;
      final language = deck.language.code;
      // One reviewer's sign-off makes every point of the card semi-verified.
      final floor = signed > 0 ? 1 : 0;

      ReviewQuestion make(
        QuestionKind kind,
        String point,
        int weakness, {
        String? shown,
        String? shownReading,
        String? shownMeaning,
      }) => ReviewQuestion(
        language: language,
        card: card.id,
        kind: kind,
        point: point,
        word: card.target,
        reading: card.reading,
        meaning: card.native.trim().isEmpty ? null : card.native,
        shown: shown,
        shownReading: shownReading,
        shownMeaning: shownMeaning,
        weakness: weakness > floor ? weakness : floor,
        deckId: deck.id,
      );

      if (card.native.trim().isNotEmpty) {
        out.add(make(QuestionKind.meaning, 'meaning', 0));
      }
      var asked = 0;
      for (final example in card.examples) {
        if (asked >= maxExamplesAsked) break;
        if (example.target.trim().isEmpty || example.native.trim().isEmpty) {
          continue;
        }
        asked++;
        out.add(
          make(
            QuestionKind.example,
            'example:${pointHash(example.target)}',
            _semiVerified(example.source) ? 1 : 0,
            shown: example.target,
            shownReading: example.reading,
            shownMeaning: example.native,
          ),
        );
      }
      for (final item in card.confusables) {
        final named = item.ref == null ? null : cards[item.ref];
        final word = item.word ?? named?.target;
        if (word == null || word.trim().isEmpty) continue;
        out.add(
          make(
            QuestionKind.confusable,
            'confusable:${item.id}',
            _semiVerified(item.source) ? 1 : 0,
            shown: word,
            shownReading: item.reading ?? named?.reading,
            shownMeaning: item.text ?? named?.native,
          ),
        );
      }
      if (card.audio != null && card.audio!.trim().isNotEmpty) {
        final source = card.audioCredit?.source.toLowerCase() ?? '';
        out.add(
          make(
            QuestionKind.sound,
            'sound',
            source.contains('wikimedia') || source.contains('commons') ? 1 : 0,
          ),
        );
      }
      for (final proposal
          in imagesOf['$language|${card.id}'] ?? const <ImageProposal>[]) {
        out.add(
          make(
            QuestionKind.image,
            'image:${proposal.file}',
            // A proposal is new data from outside, no sign-off behind it.
            1,
            shown: proposal.file,
            shownMeaning: <String>[
              ?proposal.credit,
              ?proposal.license,
            ].join(' · '),
          ),
        );
      }
    }
  }
  final ranked =
      <(int, ReviewQuestion)>[
        for (final (i, q) in out.indexed)
          if (!skip.contains(q.id)) (i, q),
      ]..sort((a, b) {
        final byWeakness = a.$2.weakness.compareTo(b.$2.weakness);
        return byWeakness != 0 ? byWeakness : a.$1.compareTo(b.$1);
      });
  return <ReviewQuestion>[for (final (_, q) in ranked) q];
}

/// Whether [source] names a place whose data is checked by many readers and
/// not by one writer: Wiktionary or Tatoeba. Those come after what nobody
/// has checked (owner, 2026-10-13, #518).
bool _semiVerified(String? source) =>
    fromWiktionary(source) ||
    (source != null && source.toLowerCase().contains('tatoeba'));
