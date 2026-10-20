import 'dart:math';

import '../core/data/pattern_expander.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import 'deck_catalog.dart';

/// The word a form question shows a form of: its [lemma], romanised as
/// [reading] where the deck gives one, and its [gloss].
typedef PlacementWord = ({String lemma, String? reading, String gloss});

/// One placement question: [card]'s target, and [options] to say what it
/// is, [answer] among them: its meaning, its own `native`; or, for a form
/// of a pattern table's word ([formOf]), the form's label alone, such as
/// "plural, before a postposition", the word being said once, in the
/// question.
class PlacementQuestion {
  PlacementQuestion({
    required this.card,
    required this.options,
    String? answer,
    this.formOf,
  }) : answer = answer ?? card.native;

  final Card card;

  /// Two to four options, in the order shown. One is [answer].
  final List<String> options;

  /// The right option.
  final String answer;

  /// For a question about which form [card] is, the word it is a form of;
  /// null for a question about what it means.
  final PlacementWord? formOf;

  bool isRight(String? chosen) => chosen == answer;
}

/// A placement drill over one course's units (#117, ADR-0013): a few
/// questions per unit, in path order, until a unit is not known. Every unit
/// before that one is placed. Nothing here is recorded as a review.
///
/// Each question shows a card's target alone, as drills show it to the
/// learner: in the scripts they learn, or read already, with no reading;
/// the reading first only where they read none (`AppState.readsFirst`).
/// A form of a word in a table asks which form it is, among the same
/// word's other forms ([PlacementQuestion.formOf]). A unit is known when at
/// most one in four answers is wrong: three of its four questions, or all
/// of them in a unit with fewer than four meanings to ask.
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

  /// Each pattern deck's cells by card id, found once.
  final Map<String, Map<String, _Cell>> _cells = <String, Map<String, _Cell>>{};

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
          for (final card in _askable(entry))
            if (!_isFormCell(card, entry)) card.native,
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
    final deck = unit.firstWhere((e) => e.id == card.deckId);
    if (_formQuestion(card, deck) case final question?) return question;
    // Forms coincide, in grammar above all: आप and वे both take हैं. A
    // meaning of another card spelled like this one would be right too, so
    // it is never offered as wrong.
    final alsoRight = <String>{
      for (final unit in units)
        for (final entry in unit)
          for (final c in _askable(entry))
            if (c.target == card.target) c.native,
    };
    final near = <String>{
      for (final c in deck.cards)
        if (!_isFormCell(c, deck)) c.native,
    }..removeAll(alsoRight);
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

  /// The cards of [entry] placement can ask about: none of a reading deck's,
  /// nor a pattern table's form that each other form of its word is spelled
  /// like, so that no option but its own could be offered.
  List<Card> _askable(DeckEntry entry) {
    if (entry.deck.kind == DeckKind.reading) return const <Card>[];
    if (entry.deck.pattern == null) return entry.cards;
    final cells = _cellsOf(entry);
    return <Card>[
      for (final card in entry.cards)
        if (cells[card.id]?.options.length != 1) card,
    ];
  }

  /// Whether [card] is a form of a word in a table, a pattern's or a rules
  /// deck's: its `native` names the form, not a meaning to set against
  /// other words'.
  bool _isFormCell(Card card, DeckEntry entry) =>
      card.rule != null || _cellsOf(entry).containsKey(card.id);

  /// Which form [card] is, for a form of a word in a table: asked among the
  /// same word's other forms alone, each different from the one shown, so
  /// that one option only is right. A pattern table's form is named by its
  /// slot alone, the word being in the question ([PlacementQuestion.formOf]);
  /// a rules table's by what it means ("with mother"), as the drill asks it
  /// (`Ask.chooseFormMeaning`). Null for any other card, or a rules table's
  /// form whose word has no other.
  PlacementQuestion? _formQuestion(Card card, DeckEntry entry) {
    if (_cellsOf(entry)[card.id] case final cell?) {
      final others = cell.options.where((o) => o != cell.slot).toList()
        ..shuffle(_random);
      return PlacementQuestion(
        card: card,
        options: <String>[cell.slot, ...others.take(3)]..shuffle(_random),
        answer: cell.slot,
        formOf: cell.word,
      );
    }
    final rule = card.rule;
    if (rule == null) return null;
    final others = <String>{
      for (final option in rule.options)
        if (option.form != card.target) option.prompt,
    }..remove(card.native);
    if (others.isEmpty) return null;
    return PlacementQuestion(
      card: card,
      options: <String>[
        card.native,
        ...(others.toList()..shuffle(_random)).take(3),
      ]..shuffle(_random),
    );
  }

  /// [entry]'s pattern cells, by card id: empty for a deck with no pattern.
  Map<String, _Cell> _cellsOf(DeckEntry entry) =>
      _cells.putIfAbsent(entry.id, () => _patternCells(entry.deck));

  static Map<String, _Cell> _patternCells(Deck deck) {
    final pattern = deck.pattern;
    if (pattern == null) return const <String, _Cell>{};
    String label(String slot) => pattern.slotLabels[slot] ?? slot;
    final cells = <String, _Cell>{};
    for (final row in pattern.entries) {
      bool shows(String slot, String form) =>
          row.forms[slot] == form ||
          (row.alternatives[slot]?.contains(form) ?? false);
      for (final (i, slot) in pattern.slots.indexed) {
        final form = row.forms[slot];
        if (form == null) continue;
        // Its own slot, and each slot whose form differs from it: a slot
        // spelled the same would be right too.
        final options = <String>{
          label(slot),
          for (final other in pattern.slots)
            if (row.forms[other] != null && !shows(other, form)) label(other),
        };
        cells[patternCardId(deck, row, i)] = (
          slot: label(slot),
          options: options.toList(),
          word: (lemma: row.lemma, reading: row.reading, gloss: row.gloss),
        );
      }
    }
    return cells;
  }

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

/// A pattern table's form: its slot's label, the labels a question about it
/// offers (its own first), and the word it is a form of.
typedef _Cell = ({String slot, List<String> options, PlacementWord word});
