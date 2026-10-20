import 'dart:math';

import '../core/data/pattern_expander.dart';
import '../core/grading/answer_grader.dart';
import '../core/grading/romanised.dart';
import '../core/models/aksharas.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import 'deck_catalog.dart';

/// The word a form question shows a form of: its [lemma], romanised as
/// [reading] where the deck gives one, and its [gloss].
typedef PlacementWord = ({String lemma, String? reading, String gloss});

/// One placement question (#481, `docs/plans/placement-v2.md`): what the
/// learner sees and how an answer is judged. Each kind says whether an
/// answer is right; the page asks and passes on only right or wrong.
sealed class PlacementAsk {
  const PlacementAsk();

  /// The card the question is drawn from.
  Card get card;
}

/// A question to choose the answer to: [card]'s target, and [options] to
/// say what it is, [answer] among them: its meaning, its own `native`; or,
/// for a form of a pattern table's word ([formOf]), the form's label alone,
/// such as "plural, before a postposition", the word being said once, in the
/// question.
class PlacementQuestion extends PlacementAsk {
  PlacementQuestion({
    required this.card,
    required this.options,
    String? answer,
    this.formOf,
  }) : answer = answer ?? card.native;

  @override
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

/// Letters to match with what they are, in two columns (owner, 2026-10-20:
/// "Make one of them a match columns question"): [cards] down the first, in
/// order, and [answers], their `native`s, shuffled down the second.
class MatchQuestion extends PlacementAsk {
  MatchQuestion({required this.cards, required this.answers});

  final List<Card> cards;

  /// The second column, in the order shown.
  final List<String> answers;

  @override
  Card get card => cards.first;

  /// Whether [pairs], each of [cards]' index with the answer matched to it,
  /// pairs every card with what it is.
  bool isRight(Map<int, String> pairs) =>
      pairs.length == cards.length &&
      <int>[for (var i = 0; i < cards.length; i++) i]
          .every((i) => pairs[i] == cards[i].native);
}

/// A question answered by typing: a word in a script to write in Latin
/// letters ([TypeQuestion.transliterate]), or a meaning to write the word
/// for ([TypeQuestion.produce]). Graded as reviews grade typing: a reading
/// with its romanisation's spellings and folded marks (`RomanisedSpelling`),
/// a word with its alternatives and a typo allowed (`AnswerGrader`).
class TypeQuestion extends PlacementAsk {
  TypeQuestion.transliterate(
    this.card, {
    required String this.shown,
    required LanguageInfo this.language,
  }) : produce = false,
       articles = const <String>[];

  TypeQuestion.produce(this.card, {this.articles = const <String>[]})
    : produce = true,
      shown = null,
      language = null;

  @override
  final Card card;

  /// Whether the meaning is shown and the word typed.
  final bool produce;

  /// For a transliteration, the word as shown, in its script.
  final String? shown;

  /// For a transliteration, [shown]'s language in its script.
  final LanguageInfo? language;

  /// The leading articles a typed word may differ by.
  final List<String> articles;

  bool isRight(String typed, RomanisedSpelling romanised) {
    final readings = <String>[?card.reading, ...card.altReading];
    if (readings.isNotEmpty &&
        romanised.grade(typed, readings).outcome.isCorrect) {
      return true;
    }
    // The reading as the deck writes it, in its standard's letters (cāy
    // for chāy), is right too.
    final key = romanised.key(typed);
    if (key.isNotEmpty && readings.any((r) => romanised.key(r) == key)) {
      return true;
    }
    if (!produce) return false;
    return AnswerGrader(articles: articles)
        .grade(
          typed,
          card.target,
          alternates: <String>[...card.targetScripts.values, ...card.altTarget],
        )
        .outcome
        .isCorrect;
  }
}

/// A word heard, to choose among [options], words in its script: [answer],
/// [card]'s spelling there, is the one said, in [language]'s voice.
class HearQuestion extends PlacementAsk {
  HearQuestion({
    required this.card,
    required this.answer,
    required this.options,
    required this.language,
  });

  @override
  final Card card;
  final String answer;
  final List<String> options;
  final LanguageInfo language;

  bool isRight(String? chosen) => chosen == answer;
}

/// A word to read aloud (owner chose "Read a word aloud"): [shown], [card]'s
/// spelling in [language]'s script, heard by the speech recogniser and
/// graded as the speaking drill grades it, with no typo allowed.
class SayQuestion extends PlacementAsk {
  SayQuestion({
    required this.card,
    required this.shown,
    required this.language,
  });

  @override
  final Card card;
  final String shown;
  final LanguageInfo language;

  /// Whether any of [heard], what the recogniser heard, best first, is the
  /// word.
  bool isRight(List<String> heard) {
    const grader = AnswerGrader(typoDistance: 0, longTypoDistance: 0);
    final accepted = <String>[
      shown,
      card.target,
      ...card.targetScripts.values,
      ...card.altTarget,
    ];
    return heard.any(
      (h) => grader
          .grade(h, accepted.first, alternates: accepted.sublist(1))
          .outcome
          .isCorrect,
    );
  }
}

// -----------------------------------------------------------------------------
// The script check

/// What one of a script's decks teaches, as the script check places it: its
/// letters, its joined forms (vowel signs, conjuncts, a letter's shapes), or
/// reading words in it (its reading, spelling and passage decks).
enum ScriptDeckKind { letters, joined, reading }

/// What [entry], one of a course's decks that need the alphabet, teaches.
/// Read from its cards: a script deck most of whose cards are one letter
/// teaches letters; one most of whose cards are one akshara of several
/// characters, or a letter's shapes side by side, teaches joined forms;
/// anything else teaches reading.
ScriptDeckKind scriptDeckKind(DeckEntry entry) {
  if (!entry.isScript) return ScriptDeckKind.reading;
  var letters = 0;
  var joined = 0;
  var words = 0;
  for (final card in entry.cards) {
    final target = card.target.trim();
    if (target.isEmpty) continue;
    if (target.runes.length == 1) {
      letters++;
    } else if (target.contains(' ') || aksharasOf(target).length == 1) {
      joined++;
    } else {
      words++;
    }
  }
  if (letters >= joined && letters >= words && letters > 0) {
    return ScriptDeckKind.letters;
  }
  return joined >= words && joined > 0
      ? ScriptDeckKind.joined
      : ScriptDeckKind.reading;
}

/// How well the learner reads a script, by the level the check reached
/// (owner, 2026-10-20: "if any are wrong, user will be given another of the
/// same level, if that is wrong too, no need to continue, just place").
enum ScriptStanding {
  /// Stopped at the letters, or said they do not read it: from its first
  /// deck.
  newTo,

  /// Stopped at the joined letters: its letter decks are skipped.
  letters,

  /// Stopped at a word (levels 3 to 5): its letter and joined-letter decks
  /// are skipped, and it starts at its reading decks.
  joined,

  /// Every level passed: its decks are skipped.
  reads,
}

/// A word of the course spelled in a script: [card], [spelling] in it, in
/// [language], the card's deck's language in that script.
typedef ScriptWord = ({Card card, String spelling, LanguageInfo language});

/// The five levels of a script check, in the order asked (owner,
/// 2026-10-20): a simple letter, a composite, a longer word to write in
/// Latin letters, a word heard to choose, a word to read aloud. Without a
/// voice or with sound off, the heard word, and without a recogniser, the
/// word read aloud, are each a harder word or phrase to write in Latin
/// letters instead ([ScriptCheck]).
enum ScriptLevel { letter, joined, transliterate, hear, say }

/// One script's check (#481): five levels, one question each; a wrong
/// answer gets one more question of the same level, and a second wrong ends
/// the check there. The level reached places the script's decks
/// ([standing], [placedDeckIds]). The letters are a match-columns
/// question. Nothing here is recorded as a review.
///
/// A level with nothing to ask, as in a script without joined letters, is
/// passed as it is reached.
class ScriptCheck {
  ScriptCheck({
    required this.script,
    required this.decks,
    required List<ScriptWord> words,
    this.canHear = false,
    this.canSay = false,
    Random? random,
  }) : _random = random ?? Random(),
       _words = _distinctWords(words) {
    _ask();
  }

  /// The script's own code, such as `devanagari`.
  final String script;

  /// The course's decks in [script] that need the alphabet, in path order.
  final List<DeckEntry> decks;

  /// Whether a word can be heard: a voice for the script and sound on.
  final bool canHear;

  /// Whether a word read aloud can be heard by the recogniser.
  final bool canSay;

  final Random _random;
  final List<ScriptWord> _words;

  int _level = 0;
  bool _missed = false;
  bool _stopped = false;
  int _asked = 0;
  PlacementAsk? _question;
  final Set<String> _used = <String>{};

  /// The level being asked, or [ScriptLevel.values]' length once done.
  int get level => _level;

  /// How many questions have been answered.
  int get asked => _asked;

  bool get isFinished => _question == null;

  /// The question to answer, or null once [isFinished].
  PlacementAsk? get question => _question;

  /// The levels passed: all five once every one is.
  int get passed => _level;

  ScriptStanding get standing => switch (_level) {
    >= 5 => ScriptStanding.reads,
    >= 2 => ScriptStanding.joined,
    1 => ScriptStanding.letters,
    _ => ScriptStanding.newTo,
  };

  /// The decks the level reached places as known.
  Set<String> get placedDeckIds => placedFor(decks, standing);

  /// The decks of [decks] that [standing] places as known.
  static Set<String> placedFor(
    List<DeckEntry> decks,
    ScriptStanding standing,
  ) => <String>{
    for (final entry in decks)
      if (switch (standing) {
        ScriptStanding.newTo => false,
        ScriptStanding.letters =>
          scriptDeckKind(entry) == ScriptDeckKind.letters,
        ScriptStanding.joined =>
          scriptDeckKind(entry) != ScriptDeckKind.reading,
        ScriptStanding.reads => true,
      })
        entry.id,
  };

  /// Answers the current question, and moves on: to the next level when
  /// [right]; else to another question of the same level once, and to the
  /// end the second time.
  void answer(bool right) {
    if (_question == null) return;
    _asked++;
    if (right) {
      _level++;
      _missed = false;
      _ask();
    } else if (!_missed) {
      _missed = true;
      _ask(again: true);
    } else {
      _question = null;
    }
  }

  /// Ends the check where it is: the levels passed stay passed.
  void stop() {
    _stopped = true;
    _question = null;
  }

  /// Whether the learner ended the check before it was over.
  bool get stopped => _stopped;

  void _ask({bool again = false}) {
    while (_level < ScriptLevel.values.length) {
      final q = _build(ScriptLevel.values[_level]);
      if (q != null) {
        _question = q;
        return;
      }
      // A second question of a level that has no other: as a second miss.
      if (again) {
        _question = null;
        return;
      }
      // Nothing to ask at this level: passed.
      _level++;
    }
    _question = null;
  }

  List<Card> _cardsOf(ScriptDeckKind kind) => <Card>[
    for (final entry in decks)
      if (entry.isScript && scriptDeckKind(entry) == kind)
        for (final card in entry.cards)
          if (card.target.trim().isNotEmpty && card.native.isNotEmpty) card,
  ];

  PlacementAsk? _build(ScriptLevel level) => switch (level) {
    ScriptLevel.letter => _match(),
    ScriptLevel.joined => _joined(),
    ScriptLevel.transliterate => _transliterate(harder: false),
    ScriptLevel.hear => canHear ? _hear() : _transliterate(harder: true),
    ScriptLevel.say => canSay ? _say() : _transliterate(harder: true),
  };

  /// Four letters and what each is, none asked before.
  PlacementAsk? _match() {
    final pool = _fresh(_cardsOf(ScriptDeckKind.letters));
    final seenTarget = <String>{};
    final seenNative = <String>{};
    final picked = <Card>[
      for (final card in pool)
        if (seenTarget.add(card.target) && seenNative.add(card.native)) card,
    ].take(4).toList();
    if (picked.length < 2) return null;
    _used.addAll(picked.map((c) => c.id));
    return MatchQuestion(
      cards: picked,
      answers: <String>[for (final c in picked) c.native]..shuffle(_random),
    );
  }

  /// A joined letter, and what it is among four.
  PlacementAsk? _joined() {
    final all = _cardsOf(ScriptDeckKind.joined);
    final pool = _fresh(all);
    if (pool.isEmpty) return null;
    final card = pool.first;
    _used.add(card.id);
    final alsoRight = <String>{
      for (final c in all)
        if (c.target == card.target) c.native,
    };
    final wrong = (<String>{
      for (final c in all) c.native,
    }..removeAll(alsoRight)).toList()..shuffle(_random);
    if (wrong.isEmpty) return null;
    return PlacementQuestion(
      card: card,
      options: <String>[card.native, ...wrong.take(3)]..shuffle(_random),
    );
  }

  /// A word to write in Latin letters: one of three aksharas or more, or
  /// [harder], the longest left, a phrase where there is one.
  PlacementAsk? _transliterate({required bool harder}) {
    final pool = <ScriptWord>[
      for (final w in _words)
        if (!_used.contains(w.card.id) && w.card.reading != null) w,
    ];
    if (pool.isEmpty) return null;
    int length(ScriptWord w) =>
        aksharasOf(w.spelling.replaceAll(' ', '')).length;
    final ScriptWord word;
    if (harder) {
      pool.sort((a, b) => length(b).compareTo(length(a)));
      final longest = pool.take(5).toList()..shuffle(_random);
      word = longest.first;
    } else {
      final long = <ScriptWord>[
        for (final w in pool)
          if (!w.spelling.contains(' ') && length(w) >= 3) w,
      ]..shuffle(_random);
      if (long.isNotEmpty) {
        word = long.first;
      } else {
        pool.sort((a, b) => length(b).compareTo(length(a)));
        word = pool.first;
      }
    }
    _used.add(word.card.id);
    return TypeQuestion.transliterate(
      word.card,
      shown: word.spelling,
      language: word.language,
    );
  }

  /// A word heard, and four words in the script to choose it from.
  PlacementAsk? _hear() {
    final pool = <ScriptWord>[
      for (final w in _words)
        if (!_used.contains(w.card.id)) w,
    ]..shuffle(_random);
    if (pool.isEmpty) return null;
    final word = pool.first;
    final others = <String>{
      for (final w in _words)
        if (w.spelling != word.spelling) w.spelling,
    }.toList()..shuffle(_random);
    if (others.isEmpty) return _transliterate(harder: true);
    _used.add(word.card.id);
    return HearQuestion(
      card: word.card,
      answer: word.spelling,
      options: <String>[word.spelling, ...others.take(3)]..shuffle(_random),
      language: word.language,
    );
  }

  /// A word to read aloud.
  PlacementAsk? _say() {
    final pool = <ScriptWord>[
      for (final w in _words)
        if (!_used.contains(w.card.id) && !w.spelling.contains(' ')) w,
    ]..shuffle(_random);
    if (pool.isEmpty) return _transliterate(harder: true);
    final word = pool.first;
    _used.add(word.card.id);
    return SayQuestion(
      card: word.card,
      shown: word.spelling,
      language: word.language,
    );
  }

  List<Card> _fresh(List<Card> cards) => <Card>[
    for (final card in cards)
      if (!_used.contains(card.id)) card,
  ]..shuffle(_random);

  static List<ScriptWord> _distinctWords(List<ScriptWord> words) {
    final seen = <String>{};
    return <ScriptWord>[
      for (final w in words)
        if (seen.add(w.spelling)) w,
    ];
  }
}

/// The words of [decks] spelled in [script], for its check: each card of a
/// deck of words (not a table's form, nor a rule's), in the script, where
/// it has a reading to write.
List<ScriptWord> scriptWordsOf(Iterable<DeckEntry> decks, String script) =>
    <ScriptWord>[
      for (final entry in decks)
        if (entry.deck.kind == DeckKind.vocab && entry.deck.pattern == null)
          for (final card in entry.cards)
            if (card.rule == null && card.reading != null)
              if (card.targetIn(script, firstScript: entry.language.script)
                  case final spelling? when spelling.trim().isNotEmpty)
                (
                  card: card,
                  spelling: spelling,
                  language: entry.language.inScript(script),
                ),
    ];

// -----------------------------------------------------------------------------
// The deck walk

/// Where a [DeckWalk] is.
enum WalkPhase { forward, end, back, produce, done }

/// The walk along a course's word decks (#481; owner, 2026-10-20): one
/// question per deck, in path order; a wrong answer gets a second from the
/// same deck, and a second wrong ends the walk, placed before that deck.
/// Three decks cleared in a row at the first try skip the next; five jump
/// to the end. Wrong there, the walk steps back towards the start, by 2
/// decks, then 3 more, then 5, 8 and on (each step the last two together),
/// until an answer is right; then two or three typed questions from the
/// decks just after decide where it lands. Right at the end, they come from
/// the last decks.
///
/// So that placement stays short (owner, 2026-10-20: "I cannot be expected
/// to answer 100+ questions just to be placed when i mostly know a
/// language"), the forward walk asks at most [forwardLimit] questions, then
/// jumps to the end as five clean decks would; and the steps back grow, so
/// that the questions grow with the logarithm of the path's length, not
/// with it.
///
/// A deck with nothing to ask (a reading deck, whose questions need their
/// passage) is passed over, and placed with the decks around it.
class DeckWalk {
  DeckWalk(
    this.decks, {
    int start = 0,
    Random? random,
    this.forwardLimit = 8,
    this.typed = 3,
    this.articles = const <String>[],
  }) : _random = random ?? Random() {
    _askable = <int>[
      for (var i = 0; i < decks.length; i++)
        if (_pool(decks[i]).isNotEmpty) i,
    ];
    _everyMeaning = <String>{
      for (final entry in decks)
        for (final card in _askableCards(entry))
          if (!_isFormCell(card, entry)) card.native,
    };
    _start = start;
    _at = _askable.indexWhere((i) => i >= start);
    if (_at < 0) _at = _askable.length;
    _frontier = _at;
    _wrongAt = _askable.length;
    _askForward();
  }

  /// The course's word decks, in path order.
  final List<DeckEntry> decks;

  /// The most questions the forward walk asks before it jumps to the end.
  final int forwardLimit;

  /// How many typed questions settle where the walk lands.
  final int typed;

  /// The leading articles a typed word may differ by.
  final List<String> articles;

  final Random _random;
  late final int _start;

  /// The indexes in [decks] of the decks with something to ask.
  late final List<int> _askable;
  late final Set<String> _everyMeaning;

  /// Each pattern deck's cells by card id, found once.
  final Map<String, Map<String, _Cell>> _cells = <String, Map<String, _Cell>>{};
  final Map<String, List<Card>> _pools = <String, List<Card>>{};

  WalkPhase _phase = WalkPhase.forward;

  /// The askable deck being asked, by its place in [_askable].
  int _at = 0;

  /// The first askable deck not known yet: every one before it was cleared
  /// or skipped past.
  int _frontier = 0;

  /// The first askable deck answered wrong beyond [_frontier], or
  /// [_askable]'s length.
  int _wrongAt = 0;

  int _streak = 0;
  bool _second = false;
  int _forwardAsked = 0;
  int _stepA = 2;
  int _stepB = 3;
  List<int> _typedAt = const <int>[];
  int _typedIndex = 0;
  int? _landing;
  int? _missed;
  int _asked = 0;
  bool _stopped = false;
  PlacementAsk? _question;

  WalkPhase get phase => _phase;

  bool get isFinished => _phase == WalkPhase.done;

  /// The question to answer, or null once [isFinished].
  PlacementAsk? get question => _question;

  /// How many questions have been answered.
  int get asked => _asked;

  /// Whether the learner ended the walk before it was over.
  bool get stopped => _stopped;

  /// The deck the learner lands on, by its index in [decks]: every deck
  /// before it is placed. [decks]' length when every deck is. While the
  /// walk goes on, where it would land if it stopped now.
  int get landing => _landing ?? _deckIndex(_soFar);

  /// The deck answered wrong that the walk stopped at, by its index in
  /// [decks]; null where it stopped at none.
  int? get missed => _missed == null ? null : _askable[_missed!];

  /// The index in [decks] the walk started from.
  int get start => _start;

  /// The indexes in [decks] of the decks the walk can ask from, in order.
  List<int> get askableDecks => List<int>.unmodifiable(_askable);

  /// The deck the current question is from, by its index in [decks]; null
  /// once [isFinished].
  int? get asking {
    if (_question == null) return null;
    return _phase == WalkPhase.produce
        ? _askable[_typedAt[_typedIndex]]
        : _askable[_at];
  }

  /// The decks before [landing]: those placed as known.
  Set<String> get placedDeckIds => <String>{
    for (final entry in decks.take(landing)) entry.id,
  };

  /// Answers the current question, and moves on.
  void answer(bool right) {
    if (_question == null) return;
    _asked++;
    switch (_phase) {
      case WalkPhase.forward:
        _forwardAsked++;
        _answerForward(right);
      case WalkPhase.end || WalkPhase.back:
        if (right) {
          _produceAfter(_at);
        } else {
          _wrongAt = _at;
          _stepBack();
        }
      case WalkPhase.produce:
        if (right) {
          _typedIndex++;
          _askTyped();
        } else {
          _missed = _typedAt[_typedIndex];
          _land(_typedAt[_typedIndex]);
        }
      case WalkPhase.done:
    }
  }

  /// Ends the walk where it is: what it found so far stays.
  void stop() {
    if (isFinished) return;
    _stopped = true;
    _land(_soFar);
  }

  int get _soFar => _phase == WalkPhase.produce && _typedIndex < _typedAt.length
      ? max(_frontier, _typedAt[_typedIndex])
      : _frontier;

  int _deckIndex(int askable) =>
      askable >= _askable.length ? decks.length : _askable[askable];

  void _land(int askable) {
    _landing = _deckIndex(askable);
    _phase = WalkPhase.done;
    _question = null;
  }

  void _answerForward(bool right) {
    if (right) {
      final clean = !_second;
      _second = false;
      _streak = clean ? _streak + 1 : 0;
      _frontier = _at + 1;
      if (_streak >= 5) {
        _jumpToEnd();
        return;
      }
      // Three cleared in a row at the first try: the next deck is skipped,
      // as known.
      _at += clean && _streak == 3 ? 2 : 1;
      _frontier = min(_at, _askable.length);
      if (_forwardAsked >= forwardLimit) {
        _jumpToEnd();
        return;
      }
      _askForward();
    } else if (!_second) {
      _second = true;
      _streak = 0;
      final q = _choice(_at, 1);
      if (q == null) {
        _missed = _at;
        _land(_at);
      } else {
        _question = q;
      }
    } else {
      _missed = _at;
      _land(_at);
    }
  }

  void _askForward() {
    if (_at >= _askable.length) {
      _land(_askable.length);
      return;
    }
    _phase = WalkPhase.forward;
    _question = _choice(_at, 0);
  }

  void _jumpToEnd() {
    final end = _askable.length - 1;
    if (end < _frontier) {
      _land(_askable.length);
      return;
    }
    _phase = WalkPhase.end;
    _at = end;
    _question = _choice(end, 0);
  }

  void _stepBack() {
    final next = _at - _stepA;
    final grown = _stepA + _stepB;
    _stepA = _stepB;
    _stepB = grown;
    if (next < _frontier) {
      // Back to what is known: the typed questions start there.
      _produceAfter(_frontier - 1);
      return;
    }
    _phase = WalkPhase.back;
    _at = next;
    _question = _choice(next, 0);
  }

  /// The typed questions, from the decks after [point], the last deck known
  /// right; from the last decks where none follow it.
  void _produceAfter(int point) {
    final after = <int>[
      for (var i = point + 1; i < _wrongAt && i < _askable.length; i++)
        if (_typable(_askable[i]).isNotEmpty) i,
    ].take(typed).toList();
    if (after.length < 2 && _wrongAt == _askable.length) {
      final last = <int>[
        for (
          var i = _askable.length - 1;
          i >= _frontier && i > point - typed;
          i--
        )
          if (_typable(_askable[i]).isNotEmpty) i,
      ].take(typed).toList().reversed.toList();
      _typedAt = last;
    } else {
      _typedAt = after;
    }
    _typedIndex = 0;
    _phase = WalkPhase.produce;
    // Nothing to type: the walk lands after [point].
    _landAfterTyped = point + 1;
    _askTyped();
  }

  int _landAfterTyped = 0;

  void _askTyped() {
    if (_typedIndex >= _typedAt.length) {
      final past = _typedAt.isEmpty
          ? _landAfterTyped
          : max(_landAfterTyped, _typedAt.last + 1);
      final at = min(past, _wrongAt);
      // Landed on the deck missed on the way back: that is the one missed.
      if (at == _wrongAt && at < _askable.length) _missed = at;
      _land(at);
      return;
    }
    final entry = decks[_askable[_typedAt[_typedIndex]]];
    final cards = _typable(_askable[_typedAt[_typedIndex]]);
    final card = cards[_random.nextInt(cards.length)];
    _question = TypeQuestion.produce(
      card,
      articles: articles.isEmpty ? entry.language.articles : articles,
    );
  }

  /// The cards of deck [index] a meaning can be typed for: words, not a
  /// table's forms nor a rule's.
  List<Card> _typable(int index) {
    final entry = decks[index];
    return <Card>[
      for (final card in _pool(entry))
        if (!_isFormCell(card, entry)) card,
    ];
  }

  /// A question from askable deck [at]: its [nth] card, or null when it has
  /// no other.
  PlacementQuestion? _choice(int at, int nth) {
    final entry = decks[_askable[at]];
    final pool = _pool(entry);
    if (nth >= pool.length) return null;
    return _questionFor(pool[nth], entry);
  }

  /// [entry]'s cards to ask, one per meaning, in a random order.
  List<Card> _pool(DeckEntry entry) => _pools.putIfAbsent(
    entry.id,
    () => _distinctByMeaning(_askableCards(entry))..shuffle(_random),
  );

  PlacementQuestion _questionFor(Card card, DeckEntry deck) {
    if (_formQuestion(card, deck) case final question?) return question;
    // Forms coincide, in grammar above all: आप and वे both take हैं. A
    // meaning of another card spelled like this one would be right too, so
    // it is never offered as wrong.
    final alsoRight = <String>{
      for (final entry in decks)
        for (final c in _askableCards(entry))
          if (c.target == card.target) c.native,
    };
    final near = <String>{
      for (final c in deck.cards)
        if (!_isFormCell(c, deck)) c.native,
    }..removeAll(alsoRight);
    final far = Set<String>.of(_everyMeaning)
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
  List<Card> _askableCards(DeckEntry entry) {
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

  /// [cards] with one card per meaning, so that a deck never asks the same
  /// meaning twice.
  static List<Card> _distinctByMeaning(List<Card> cards) {
    final seen = <String>{};
    return <Card>[
      for (final card in cards)
        if (seen.add(card.native)) card,
    ];
  }
}

/// Whether a try again from where the last placement landed got much
/// further: at least one more deck (#481; "much further" is one deck or
/// more). While it does, the learner may try again from the new place.
bool gotFurther(int before, int after) => after >= before + 1;

/// A pattern table's form: its slot's label, the labels a question about it
/// offers (its own first), and the word it is a form of.
typedef _Cell = ({String slot, List<String> options, PlacementWord word});
