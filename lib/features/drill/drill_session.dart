import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/grading/self_grade.dart';
import '../../core/models/drill_mode.dart';
import '../../core/numbers/number_practice.dart';
import '../../core/scheduling/session_queue.dart';
import '../../core/speech/speech_engine.dart';

/// Where the current card is: the design's `phase`.
enum DrillPhase {
  /// The card is shown and nothing has been answered.
  prompt,

  /// Recognition only: the meaning is shown and the learner rates recall.
  revealed,

  /// A typed answer is in, and the feedback is showing.
  feedback,
}

/// How a production answer is typed: in the language's own script, or in
/// Latin letters (#47, behind [Feature.translitInput]).
enum InputMode { script, translit }

/// A typed answer, once it is in.
class TypedAnswer {
  const TypedAnswer({
    required this.typed,
    required this.graded,
    required this.grade,
  });

  /// What the learner typed; empty after "Don't know".
  final String typed;

  /// The grader's verdict, or null when the learner chose "Don't know".
  final GradedAnswer? graded;

  /// The SM-2 grade recorded, or null while a near miss waits for the
  /// learner's judgement.
  final int? grade;

  bool get gaveUp => graded == null;

  bool get awaitsJudgement => grade == null;
}

/// One drill session: the queue, where the learner is in it, and what has
/// been answered (ADR-0007). The drill page's `State` owns it and disposes it
/// with the route.
///
/// Every answer is recorded through [AppState.record] the moment it is
/// given: a rating, a checked answer, "Don't know", or the verdict on a near
/// miss. Nothing waits for the end of the session, so ending part-way loses
/// nothing. A session that is not [recorded], number practice (#54) or
/// [revising] a finished deck, records nothing and only counts its answers
/// for the summary.
class DrillSession extends ChangeNotifier {
  DrillSession({
    required AppState state,
    required List<SessionItem> items,
    this._inputMode = InputMode.script,
    this.recorded = true,
    this.revising = false,
  }) : assert(items.isNotEmpty, 'an empty queue shows the empty state'),
       assert(!revising || !recorded, 'revising is never recorded'),
       _state = state,
       items = List<SessionItem>.unmodifiable(items),
       startedAt = state.now() {
    _watch.start();
  }

  final AppState _state;

  /// The whole session in the order it is drilled, built once at the start.
  final List<SessionItem> items;

  final DateTime startedAt;

  /// Whether answers go to the review log. False for number practice, which
  /// has no schedule, and for [revising]; recognition shows no intervals
  /// either.
  final bool recorded;

  /// Revising a finished deck's cards ahead of their dates. Titled with the
  /// deck, like a recorded session, but never [recorded]: an early review
  /// would stretch the card's interval.
  final bool revising;

  final List<SessionAnswer> _answers = <SessionAnswer>[];
  final Stopwatch _watch = Stopwatch();
  int _index = 0;
  DrillPhase _phase = DrillPhase.prompt;
  TypedAnswer? _answer;
  InputMode _inputMode;
  bool _slower = false;
  bool _playing = false;
  bool _hearing = false;
  SpeechFailure? _unheard;
  DateTime? _endedAt;
  bool _disposed = false;

  SessionItem get item => items[_index];

  /// The deck the current card comes from.
  DeckEntry get deck => _state.deckOf(item.card)!;

  Skill get skill => Skill.of(item.mode);

  /// The current card, 1-based, and how many the session has.
  int get position => _index + 1;
  int get total => items.length;

  /// How far the wave shows: the cards finished, plus half a card once the
  /// current one is answered, as the design draws it.
  double get progress =>
      (_index + (_phase == DrillPhase.prompt ? 0 : 0.5)) / items.length;

  DrillPhase get phase => _phase;

  /// The typed answer for the current card, once it is in.
  TypedAnswer? get answer => _answer;

  /// Every answer recorded so far, oldest first.
  List<SessionAnswer> get answers => List<SessionAnswer>.unmodifiable(_answers);

  bool get hasAnswers => _answers.isNotEmpty;

  /// Whether the last card has been answered.
  bool get finished => _endedAt != null;

  /// What the summary shows.
  SessionResult get result => SessionResult(
    answers: _answers,
    startedAt: startedAt,
    endedAt: _endedAt ?? _state.now(),
  );

  // ---------------------------------------------------------------------------
  // Recognition

  void reveal() {
    if (item.mode != DrillMode.recognition || _phase != DrillPhase.prompt) {
      return;
    }
    _phase = DrillPhase.revealed;
    notifyListeners();
  }

  /// What [grade] would schedule the card for, in days: the label under each
  /// rating button.
  int intervalFor(SelfGrade grade) {
    final card = item.card;
    return _state.progress
        .preview(
          card.deckId,
          card.id,
          item.mode,
          grade.toSm2Grade(),
          now: _state.now(),
        )
        .intervalDays;
  }

  /// Records the learner's rating and moves on.
  void rate(SelfGrade grade) {
    if (_phase != DrillPhase.revealed) return;
    _record(grade.toSm2Grade());
    _advance();
  }

  // ---------------------------------------------------------------------------
  // Typed answers: production and listening

  /// Whether this card can be typed as a transliteration: production of a
  /// card with a reading, in a script that needs one.
  bool get canTransliterate =>
      item.mode == DrillMode.production &&
      item.card.reading != null &&
      deck.language.needsReading;

  InputMode get inputMode => _inputMode;

  /// Whether the answer is being typed in Latin letters. Only ever true
  /// while [Feature.translitInput] is on.
  bool get transliterating =>
      canTransliterate &&
      _inputMode == InputMode.translit &&
      _state.features.isAvailable(Feature.translitInput);

  set inputMode(InputMode mode) {
    if (mode == _inputMode || _phase != DrillPhase.prompt) return;
    if (!_state.features.isAvailable(Feature.translitInput)) return;
    _inputMode = mode;
    notifyListeners();
  }

  /// The answers the grader accepts, the canonical one first.
  ///
  /// Typing a transliteration accepts the reading as well as the target:
  /// the direction #47 takes. Its per-language spelling variants are #47's
  /// to add.
  List<String> get acceptedAnswers {
    final accepted = item.card.acceptedAnswers(item.mode);
    final reading = item.card.reading;
    if (transliterating && reading != null) {
      return <String>[reading, ...accepted];
    }
    return accepted;
  }

  /// Whether the answer is a number in digits: a generated number heard.
  bool get typesDigits =>
      item.card is NumberCard && item.mode == DrillMode.listening;

  /// Grades [typed]. A near miss waits for [judge]; every other outcome is
  /// recorded now.
  ///
  /// Digits are right or wrong, never a typo: 2021 is not a slip for 2020.
  /// Spaces and commas in them are ignored, so 2,020 is 2020.
  void check(String typed) {
    if (_phase != DrillPhase.prompt || typed.trim().isEmpty) return;
    if (item.mode == DrillMode.recognition) return;
    final accepted = acceptedAnswers;
    final grader = typesDigits
        ? const AnswerGrader(typoDistance: 0, longTypoDistance: 0)
        : AnswerGrader(articles: deck.language.articles);
    final graded = grader.grade(
      typesDigits ? typed.replaceAll(RegExp(r'[\s,]'), '') : typed,
      accepted.first,
      alternates: accepted.sublist(1),
    );
    final grade = graded.outcome == AnswerOutcome.closeTypo
        ? null
        : graded.outcome.toSm2Grade();
    _answer = TypedAnswer(typed: typed, graded: graded, grade: grade);
    if (grade != null) _record(grade, answerGiven: typed);
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  /// "Don't know": shows the answer and records a failure.
  void dontKnow() {
    if (_phase != DrillPhase.prompt || item.mode == DrillMode.recognition) {
      return;
    }
    const grade = 1;
    _answer = const TypedAnswer(typed: '', graded: null, grade: grade);
    _record(grade);
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  /// The learner's verdict on a near miss: recorded, then on to the next.
  void judge(TypoJudgement judgement) {
    final answer = _answer;
    if (answer == null || !answer.awaitsJudgement) return;
    _record(judgement.toSm2Grade(), answerGiven: answer.typed);
    _advance();
  }

  /// "Continue", once the feedback is showing and the answer is recorded.
  void next() {
    if (_phase != DrillPhase.feedback || _answer?.awaitsJudgement != false) {
      return;
    }
    _advance();
  }

  // ---------------------------------------------------------------------------
  // Listening

  /// Whether "Slower" is on: the word plays at 0.7 times the speech rate.
  bool get slower => _slower;

  void toggleSlower() {
    _slower = !_slower;
    notifyListeners();
  }

  /// Whether the word is playing now.
  bool get playing => _playing;

  /// Speaks the current card's target at the learner's rate, or slower.
  Future<void> play() async {
    if (item.mode != DrillMode.listening) return;
    final playingIndex = _index;
    _playing = true;
    notifyListeners();
    try {
      await _state.speak(item.card.target, deck.language, slower: _slower);
    } finally {
      if (!_disposed && _index == playingIndex && _playing) {
        _playing = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Speaking (#89, ADR-0014)

  /// The confidence a reading other than the recogniser's best needs to be
  /// taken as what the learner said. One with no confidence given is not.
  static const double speechConfidence = 0.5;

  /// Whether the recogniser is listening now.
  bool get hearing => _hearing;

  /// Why the last listen gave nothing to grade, or null. Nothing is recorded
  /// for it: the learner can say it again.
  SpeechFailure? get unheard => _unheard;

  /// Listens for the current card's target and grades what was heard.
  Future<void> listen() async {
    if (item.mode != DrillMode.speaking ||
        _phase != DrillPhase.prompt ||
        _hearing) {
      return;
    }
    final listeningIndex = _index;
    _hearing = true;
    _unheard = null;
    notifyListeners();
    final heard = await _state.listenFor(deck.language);
    if (_disposed || _index != listeningIndex) return;
    _hearing = false;
    if (heard.failed) {
      _unheard = heard.failure ?? SpeechFailure.noMatch;
      notifyListeners();
      return;
    }
    checkSpoken(heard.alternatives);
  }

  /// Stops listening early; what was said so far is graded.
  Future<void> stopListening() => _state.stopListening();

  /// Grades what the recogniser heard, [alternatives] best first.
  ///
  /// The attempt counts if its best reading, or another the recogniser said
  /// it was fairly sure of, is an accepted answer: one noisy guess does not
  /// fail a learner, and an unscored one does not pass them. Matching is exact once normalised: a near miss in speech is a
  /// different word, not a typo.
  void checkSpoken(List<SpeechAlternative> alternatives) {
    if (_phase != DrillPhase.prompt ||
        item.mode != DrillMode.speaking ||
        alternatives.isEmpty) {
      return;
    }
    final accepted = acceptedAnswers;
    final grader = AnswerGrader(
      articles: deck.language.articles,
      typoDistance: 0,
      longTypoDistance: 0,
    );
    GradedAnswer gradeOf(SpeechAlternative a) =>
        grader.grade(a.text, accepted.first, alternates: accepted.sublist(1));
    var said = alternatives.first;
    var graded = gradeOf(said);
    if (!graded.outcome.isCorrect) {
      for (final other in alternatives.skip(1)) {
        final confidence = other.confidence;
        if (confidence == null || confidence < speechConfidence) continue;
        final g = gradeOf(other);
        if (g.outcome.isCorrect) {
          said = other;
          graded = g;
          break;
        }
      }
    }
    final grade = graded.outcome.toSm2Grade();
    _unheard = null;
    _answer = TypedAnswer(typed: said.text, graded: graded, grade: grade);
    _record(grade, answerGiven: said.text);
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  /// Moves on without recording anything, for a card that cannot be heard
  /// now. Declining to go online, when the phone cannot recognise the
  /// language by itself, holds for the language's other speaking cards in
  /// this session, so the question is not asked again on each.
  void skipUnheard() {
    if (item.mode != DrillMode.speaking || _phase != DrillPhase.prompt) return;
    if (_unheard == SpeechFailure.notOnDevice) {
      _declinedOnline.add(deck.language.code);
    }
    _advance();
  }

  /// Languages whose online question the learner declined in this session.
  final Set<String> _declinedOnline = <String>{};

  // ---------------------------------------------------------------------------

  void _record(int grade, {String? answerGiven}) {
    if (recorded) {
      _state.record(
        item,
        grade,
        elapsed: _watch.elapsed,
        answerGiven: answerGiven,
      );
    }
    _answers.add(SessionAnswer(skill: skill, grade: grade));
  }

  // ---------------------------------------------------------------------------
  // Can't speak now, can't listen now (#89)

  /// "Can't speak now" or "Can't listen now": the current card's skill is
  /// not for the rest of this session, in its language only when
  /// [onlyLanguage] is set. The card, and every later one the choice
  /// reaches, is skipped unrecorded. What it means beyond the session (a
  /// pause, or switching the skill off) is the caller's, in the settings.
  void skipSkill({String? onlyLanguage}) {
    if (_phase != DrillPhase.prompt) return;
    if (_hearing) _state.stopListening();
    _hearing = false;
    _notNow.add((skill, onlyLanguage));
    _advance();
  }

  final Set<(Skill, String?)> _notNow = <(Skill, String?)>{};

  /// Whether [item] can still be drilled: not set aside on this drill, its
  /// skill not paused since the session was built, and not a speaking card
  /// in a language found not to be heard at all, or whose online question
  /// the learner declined and has not since allowed.
  bool _drillable(SessionItem item) {
    final itemSkill = Skill.of(item.mode);
    final language = _state.deckOf(item.card)?.language;
    final code = language?.code;
    if (_notNow.contains((itemSkill, null)) ||
        _notNow.contains((itemSkill, code))) {
      return false;
    }
    if (_state.settings.isPaused(itemSkill, _state.now())) return false;
    if (item.mode != DrillMode.speaking || language == null) return true;
    return switch (_state.speechStatus(language)) {
      SpeechStatus.missing => false,
      SpeechStatus.onlineOnly => !_declinedOnline.contains(language.code),
      _ => true,
    };
  }

  void _advance() {
    if (_playing) _state.stopSpeaking();
    _playing = false;
    var next = _index + 1;
    while (next < items.length && !_drillable(items[next])) {
      next++;
    }
    if (next >= items.length) {
      _endedAt = _state.now();
      _watch.stop();
      notifyListeners();
      return;
    }
    _index = next;
    _phase = DrillPhase.prompt;
    _answer = null;
    _hearing = false;
    _unheard = null;
    _watch
      ..reset()
      ..start();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_playing) _state.stopSpeaking();
    if (_hearing) _state.stopListening();
    super.dispose();
  }
}
