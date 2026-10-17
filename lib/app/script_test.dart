import 'dart:math';

import '../core/models/card.dart';
import 'deck_catalog.dart';
import 'placement.dart';

/// The card tag a script deck marks a language's own letters with: those it
/// adds to, or writes differently from, a script it shares (#554):
/// Assamese ৰ (rô) and ৱ (wô) in Eastern Nagari (`docs/DECK-FORMAT.md`).
const String ownLetterTag = 'own-letter';

/// "How well do you know the script" (#554): a short test, for a learner
/// who reads a course's script already through another language, that lets
/// them skip the course's script lessons.
///
/// It asks placement's question (ADR-0013): a letter or conjunct alone, and
/// what it is, from its script decks' own meanings. Every letter tagged
/// [ownLetterTag] is asked, first in no fixed order, then the decks' other
/// cards one deck at a time, so that vowels, consonants, vowel signs and
/// conjuncts each come up, until [size] questions in all. It is passed with
/// every own letter right and at most one other answer wrong. Nothing here
/// is recorded as a review.
class ScriptTest {
  ScriptTest(this.decks, {Random? random, this.size = 8})
    : _random = random ?? Random() {
    _questions = _build();
  }

  /// The course's script decks, in teaching order.
  final List<DeckEntry> decks;

  /// How many questions to ask, own letters included, where the decks have
  /// that many.
  final int size;

  final Random _random;
  late final List<PlacementQuestion> _questions;
  int _asked = 0;
  int _wrong = 0;
  bool _ownWrong = false;

  /// Every question, in the order asked.
  List<PlacementQuestion> get questions => _questions;

  /// How many questions have been answered.
  int get asked => _asked;

  /// How many of them were right.
  int get right => _asked - _wrong;

  bool get isFinished => _asked >= _questions.length;

  /// The question to answer, or null once [isFinished].
  PlacementQuestion? get question => isFinished ? null : _questions[_asked];

  /// Whether the test was passed: every own letter right, and at most one
  /// other answer wrong. Only meaningful once [isFinished].
  bool get passed => _questions.isNotEmpty && !_ownWrong && _wrong <= 1;

  /// Answers the current [question] with [chosen], or null for "I don't
  /// know", and moves on.
  void answer(String? chosen) {
    final q = question;
    if (q == null) return;
    if (!q.isRight(chosen)) {
      _wrong++;
      if (q.card.tags.contains(ownLetterTag)) _ownWrong = true;
    }
    _asked++;
  }

  List<PlacementQuestion> _build() {
    final seen = <String>{};
    bool fresh(Card card) => seen.add(card.native);
    final own = <Card>[
      for (final entry in decks)
        for (final card in entry.cards)
          if (card.tags.contains(ownLetterTag) && fresh(card)) card,
    ]..shuffle(_random);
    final pools = <List<Card>>[
      for (final entry in decks)
        <Card>[
          for (final card in entry.cards)
            if (!card.tags.contains(ownLetterTag)) card,
        ]..shuffle(_random),
    ];
    final picked = <Card>[...own];
    for (var i = 0; picked.length < size; i++) {
      var any = false;
      for (final pool in pools) {
        if (i >= pool.length) continue;
        any = true;
        if (picked.length < size && fresh(pool[i])) picked.add(pool[i]);
      }
      if (!any) break;
    }
    return <PlacementQuestion>[for (final card in picked) _question(card)];
  }

  PlacementQuestion _question(Card card) {
    // A meaning of another card written like this one would be right too,
    // so it is never offered as wrong.
    final alsoRight = <String>{
      for (final entry in decks)
        for (final c in entry.cards)
          if (c.target == card.target) c.native,
    };
    final deck = decks.firstWhere(
      (e) => e.id == card.deckId,
      orElse: () => decks.first,
    );
    final near = <String>{for (final c in deck.cards) c.native}
      ..removeAll(alsoRight);
    final far =
        <String>{
            for (final entry in decks)
              for (final c in entry.cards) c.native,
          }
          ..removeAll(near)
          ..removeAll(alsoRight);
    final wrong = <String>[
      ...(near.toList()..shuffle(_random)),
      ...(far.toList()..shuffle(_random)),
    ].take(3);
    final options = <String>[card.native, ...wrong]..shuffle(_random);
    return PlacementQuestion(card: card, options: options);
  }
}
