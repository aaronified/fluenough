import 'dart:math';

import '../core/models/card.dart';
import '../core/models/deck.dart';
import 'deck_catalog.dart';

/// One placement question: [card]'s target, and [options] to say what it
/// means, its own `native` among them.
class PlacementQuestion {
  const PlacementQuestion({required this.card, required this.options});

  final Card card;

  /// Two to four meanings, in the order shown. One is [card]'s.
  final List<String> options;

  bool isRight(String? chosen) => chosen == card.native;
}

/// A placement drill over one course's units (#117, ADR-0013): a few
/// questions per unit, in path order, until a unit is not known. Every unit
/// before that one is placed. Nothing here is recorded as a review.
///
/// Each question shows a card's target alone, with no reading, so knowing a
/// unit means reading its script too. A unit is known when at most one in
/// four answers is wrong: three of its four questions, or all of them in a
/// unit with fewer than four meanings to ask.
///
/// A reading deck asks nothing here: its questions need their passage. A
/// unit of nothing but reading is known when it is reached, as a unit with
/// nothing to ask always is (ADR-0019).
class Placement {
  Placement(this.units, {Random? random, this.questionsPerUnit = 4})
    : _random = random ?? Random() {
    _startUnit();
  }

  /// The course's units, in teaching order.
  final List<List<DeckEntry>> units;
  final int questionsPerUnit;
  final Random _random;

  int _unit = 0;
  List<PlacementQuestion> _questions = const <PlacementQuestion>[];
  int _asked = 0;
  int _wrong = 0;
  bool _stopped = false;

  /// The unit being checked, from 0, or [units]' length once every unit is
  /// known.
  int get unit => _unit;

  /// Whether placement is over: a unit was not known, every unit was, or
  /// the learner stopped.
  bool get isFinished => _stopped || _unit >= units.length;

  /// The question to answer, or null once [isFinished].
  PlacementQuestion? get question => isFinished ? null : _questions[_asked];

  /// The decks of every unit before [unit]: those placed as known.
  Set<String> get placedDeckIds => <String>{
    for (final unit in units.take(_unit))
      for (final entry in unit) entry.id,
  };

  /// The unit teaching starts at, or null if every unit is known.
  List<DeckEntry>? get startUnit => _unit < units.length ? units[_unit] : null;

  /// Answers the current [question] with [chosen], or null for "I don't
  /// know", and moves on: to the unit's next question, to the next unit
  /// once this one is known, or to the end once it cannot be.
  void answer(String? chosen) {
    final q = question;
    if (q == null) return;
    if (!q.isRight(chosen)) _wrong++;
    _asked++;
    if (_wrong > _allowedWrong) {
      _stopped = true;
    } else if (_asked == _questions.length) {
      _unit++;
      _startUnit();
    }
  }

  /// Ends placement where it is: the units already known stay placed.
  void stop() => _stopped = true;

  /// Wrong answers a unit may have and still be known: one in four.
  int get _allowedWrong => _questions.length ~/ 4;

  void _startUnit() {
    _asked = 0;
    _wrong = 0;
    while (_unit < units.length) {
      _questions = _questionsFor(units[_unit]);
      if (_questions.isNotEmpty) return;
      // Nothing to ask, so nothing to learn first: known.
      _unit++;
    }
    _questions = const <PlacementQuestion>[];
  }

  /// Up to [questionsPerUnit] of [unit]'s cards, taken from its decks in
  /// turn, each with up to three wrong meanings from its own deck, or the
  /// rest of the course where the deck has too few.
  List<PlacementQuestion> _questionsFor(List<DeckEntry> unit) {
    final pools = <List<Card>>[
      for (final entry in unit)
        if (_distinctByMeaning(_askable(entry)) case final cards
            when cards.isNotEmpty)
          cards..shuffle(_random),
    ];
    final picked = <Card>[];
    for (var i = 0; picked.length < questionsPerUnit; i++) {
      final before = picked.length;
      for (final pool in pools) {
        if (i < pool.length && picked.length < questionsPerUnit) {
          picked.add(pool[i]);
        }
      }
      if (picked.length == before) break;
    }
    final everyMeaning = <String>{
      for (final unit in units)
        for (final entry in unit)
          for (final card in _askable(entry)) card.native,
    };
    return <PlacementQuestion>[
      for (final card in picked) _question(card, unit, everyMeaning),
    ];
  }

  PlacementQuestion _question(
    Card card,
    List<DeckEntry> unit,
    Set<String> everyMeaning,
  ) {
    // Forms coincide, in grammar above all: आप and वे both take हैं. A
    // meaning of another card spelled like this one would be right too, so
    // it is never offered as wrong.
    final alsoRight = <String>{
      for (final unit in units)
        for (final entry in unit)
          for (final c in _askable(entry))
            if (c.target == card.target) c.native,
    };
    final deck = unit.firstWhere((e) => e.id == card.deckId);
    final near = <String>{for (final c in deck.cards) c.native}
      ..removeAll(alsoRight);
    final far = Set<String>.of(everyMeaning)
      ..removeAll(near)
      ..removeAll(alsoRight);
    final wrong = <String>[
      ...(near.toList()..shuffle(_random)),
      ...(far.toList()..shuffle(_random)),
    ].take(3);
    final options = <String>[card.native, ...wrong]..shuffle(_random);
    return PlacementQuestion(card: card, options: options);
  }

  /// The cards of [entry] placement can ask about: none of a reading deck's.
  static List<Card> _askable(DeckEntry entry) =>
      entry.deck.kind == DeckKind.reading ? const <Card>[] : entry.cards;

  /// [cards] with one card per meaning, so that a unit never asks the same
  /// meaning twice.
  static List<Card> _distinctByMeaning(List<Card> cards) {
    final seen = <String>{};
    return <Card>[
      for (final card in cards)
        if (seen.add(card.native)) card,
    ];
  }
}
