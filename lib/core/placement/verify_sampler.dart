import 'dart:math';

/// Where a [VerifySampler] is.
enum SamplerPhase { last, around, first, done }

/// The strategy of a verification run (owner, 2026-11-05: "Ask the last
/// deck. If known, sample around that till you find serious flaws. If not
/// known at all (2 questions min), go to 1st deck and keep sampling from
/// there."; "Keep placement question count within 25 questions."), a pure
/// state machine over the number of decks: it says which deck to ask next
/// ([deck]) and is told whether the answer was right ([answer]). The page
/// draws the question from that deck.
///
/// | State | Asks | Next |
/// |---|---|---|
/// | last | 2 questions of the last deck | one or two right: around; none right: first |
/// | around | one question of a deck, backward from the last at growing steps (every deck when there are at most [everyDeckUpTo]), then the first deck | a miss asks the deck again; a serious flaw ends; the end of the schedule ends, verified |
/// | first | the first deck, then forward at growing steps | a serious flaw ends at that deck; the end of the schedule ends, not verified |
///
/// A serious flaw is two misses in one deck (a miss is asked again), or
/// [maxMisses] misses over the run. A run never asks more than
/// [maxQuestions]; one that is cut short by the limit is not verified.
///
/// Verified means the run ended in the around state without a serious flaw
/// across the decks it sampled. It does not touch every deck.
class VerifySampler {
  VerifySampler(
    this.deckCount, {
    int seed = 0,
    this.maxQuestions = 25,
    this.maxMisses = 3,
    this.everyDeckUpTo = 20,
  }) : _random = Random(seed) {
    if (deckCount <= 0) {
      _phase = SamplerPhase.done;
      _landing = 0;
    } else {
      _deck = deckCount - 1;
    }
  }

  /// How many decks the language's path has up to B1.
  final int deckCount;

  /// The most questions one run asks.
  final int maxQuestions;

  /// The misses over a run that are a serious flaw.
  final int maxMisses;

  /// Up to this many decks, every deck is sampled.
  final int everyDeckUpTo;

  final Random _random;
  SamplerPhase _phase = SamplerPhase.last;
  int _deck = 0;
  int _asked = 0;
  int _misses = 0;
  int _askedOfLast = 0;
  int _rightOfLast = 0;
  bool _retry = false;
  int _step = 0;
  List<int> _schedule = const <int>[];
  int _landing = 0;
  int? _flawDeck;
  bool _verified = false;

  SamplerPhase get phase => _phase;
  bool get isFinished => _phase == SamplerPhase.done;

  /// How many questions have been answered.
  int get asked => _asked;

  /// The deck to ask the next question from, by index in the path's order;
  /// null once finished.
  int? get deck => isFinished ? null : _deck;

  /// Whether the run ended without a serious flaw over the decks it
  /// sampled, having reached the end of its schedule from a known last deck.
  bool get verified => _verified;

  /// The deck the run found a serious flaw in; null where there was none.
  int? get flawDeck => _flawDeck;

  /// The decks before this are placed as known: [deckCount] when verified,
  /// the flawed deck where one was found, else the first deck not known.
  int get landing => _landing;

  /// Answers the current question and moves on.
  void answer(bool right) {
    if (isFinished) return;
    _asked++;
    if (_phase == SamplerPhase.last) {
      _askedOfLast++;
      if (right) {
        _rightOfLast++;
      } else {
        _misses++;
      }
      if (_askedOfLast < 2) return;
      if (_rightOfLast == 0) {
        _misses = 0;
        _phase = SamplerPhase.first;
        _schedule = _forward();
        _step = 0;
        _next();
      } else {
        _phase = SamplerPhase.around;
        _schedule = _backward();
        _step = 0;
        if (_misses >= maxMisses) {
          _flaw(deckCount - 1);
        } else {
          _next();
        }
      }
      return;
    }
    if (right) {
      _retry = false;
      _next();
    } else {
      _misses++;
      if (_retry || _misses >= maxMisses) {
        _flaw(_deck);
      } else {
        _retry = true;
        _limit();
      }
    }
  }

  void _flaw(int deck) {
    _flawDeck = deck;
    _landing = deck;
    _phase = SamplerPhase.done;
  }

  /// Stops at the question limit: not verified, landing where it got to.
  void _limit() {
    if (_asked >= maxQuestions && !isFinished) {
      _landing = _phase == SamplerPhase.first ? _deck : 0;
      _phase = SamplerPhase.done;
    }
  }

  void _next() {
    if (_asked >= maxQuestions) {
      _limit();
      return;
    }
    if (_step >= _schedule.length) {
      if (_phase == SamplerPhase.around) {
        _verifiedEnd();
      } else {
        _end(deckCount - 1);
      }
      return;
    }
    _deck = _schedule[_step++];
  }

  void _verifiedEnd() {
    _verified = true;
    _landing = deckCount;
    _phase = SamplerPhase.done;
  }

  void _end(int landing) {
    _landing = landing;
    _phase = SamplerPhase.done;
  }

  /// The offsets 1, 2, 4, 7, 12, 20, ...: each step the last two together.
  Iterable<(int, int)> _offsets() sync* {
    var a = 1;
    var b = 1;
    var offset = 0;
    while (true) {
      offset += a;
      yield (offset, a);
      final next = a + b;
      a = b;
      b = next;
    }
  }

  /// The decks before the last, backward: every one for a short path, else
  /// at growing steps with a seeded nudge, ending at the first deck.
  List<int> _backward() {
    final last = deckCount - 1;
    if (deckCount <= everyDeckUpTo) {
      return <int>[for (var d = last - 1; d >= 0; d--) d];
    }
    final out = <int>[];
    for (final (offset, step) in _offsets()) {
      var d = last - offset + _random.nextInt(max(1, step));
      d = min(d, out.isEmpty ? last - 1 : out.last - 1);
      if (d <= 0) break;
      out.add(d);
    }
    out.add(0);
    return out;
  }

  /// The decks from the first, forward, to before the last.
  List<int> _forward() {
    final last = deckCount - 1;
    if (deckCount <= everyDeckUpTo) {
      return <int>[for (var d = 0; d < last; d++) d];
    }
    final out = <int>[0];
    for (final (offset, step) in _offsets()) {
      var d = offset - 1 + _random.nextInt(max(1, step));
      d = max(d, out.last + 1);
      if (d >= last) break;
      out.add(d);
    }
    return out;
  }
}
