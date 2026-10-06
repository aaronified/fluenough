import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/grading/romanised.dart';
import '../../core/grading/self_grade.dart';
import '../../core/models/card.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/reading.dart';
import '../../core/models/sound_contrasts.dart';
import '../../core/numbers/number_practice.dart';
import '../../core/scheduling/session_queue.dart';
import '../../core/scheduling/sm2.dart';
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

/// How a typed answer is typed: in the language's own script, or in Latin
/// letters (#47, behind [Feature.translitInput]).
enum InputMode { script, translit }

/// A typed answer, once it is in.
class TypedAnswer {
  const TypedAnswer({
    required this.typed,
    required this.graded,
    required this.grade,
    this.contrast,
    this.heardCard,
  });

  /// What the learner typed; empty after "Don't know".
  final String typed;

  /// The grader's verdict, or null when the learner chose "Don't know".
  final GradedAnswer? graded;

  /// The SM-2 grade recorded, or null while a near miss waits for the
  /// learner's judgement.
  final int? grade;

  /// For a spoken answer that was wrong: the sound contrast the word heard
  /// differs from the answer by, if one does (#89, ADR-0015).
  final SoundContrast? contrast;

  /// The card whose target is the word heard instead, to say what it means.
  final Card? heardCard;

  bool get gaveUp => graded == null;

  bool get awaitsJudgement => grade == null;
}

/// One drill session: the queue, where the learner is in it, and what has
/// been answered (ADR-0007). The drill page's `State` owns it and disposes it
/// with the route.
///
/// Every answer is recorded through [AppState.record] the moment it is
/// given: a rating, a checked answer, "Don't know", the verdict on a near
/// miss, or a reading question's choice. Nothing waits for the end of the
/// session, so ending part-way loses nothing. A session that is not
/// [recorded], number practice (#54) or [revising] a finished deck, records
/// nothing and only counts its answers for the summary.
class DrillSession extends ChangeNotifier {
  DrillSession({
    required AppState state,
    required List<SessionItem> items,
    InputMode? inputMode,
    this.recorded = true,
    this.revising = false,
    this.recordsMisses = false,
    math.Random? random,
  }) : assert(items.isNotEmpty, 'an empty queue shows the empty state'),
       assert(!revising || !recorded, 'revising is never recorded'),
       _state = state,
       _chosenMode = inputMode,
       _random = random ?? state.random,
       items = List<SessionItem>.unmodifiable(items),
       startedAt = state.now(),
       _showingPassage = items.first.card is QuestionCard {
    _watch.start();
  }

  final AppState _state;

  /// Shuffles the options of a multiple-choice question (#148).
  final math.Random _random;

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

  /// Whether a wrong answer is recorded although the session is not: a
  /// quick revision (ADR-0029), where a lapse should bring the card back
  /// sooner, and a right answer, given early, should not stretch it.
  final bool recordsMisses;

  final List<SessionAnswer> _answers = <SessionAnswer>[];
  final Stopwatch _watch = Stopwatch();
  int _index = 0;
  DrillPhase _phase = DrillPhase.prompt;
  TypedAnswer? _answer;

  /// The input mode the learner, or a preset, chose; null for the
  /// language's own: [InputMode.translit] without its alphabet.
  InputMode? _chosenMode;
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
    if (item.mode != DrillMode.recognition ||
        ask != Ask.own ||
        _phase != DrillPhase.prompt) {
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
        .preview(card.id, item.mode, grade.toSm2Grade(), now: _state.now())
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

  /// Whether this card can be typed as a transliteration (#47): a
  /// production, listening or grammar card with a reading, in a script that
  /// needs one. Not on a deck that teaches the alphabet itself, whose
  /// prompts give the reading away ("k (ka)").
  bool get canTransliterate =>
      _typedModes.contains(item.mode) &&
      item.card is! NumberCard &&
      item.card.reading != null &&
      deck.language.needsReading &&
      !_state.needsAlphabet(deck);

  static const Set<DrillMode> _typedModes = <DrillMode>{
    DrillMode.production,
    DrillMode.listening,
    DrillMode.grammar,
  };

  /// The grade a right answer in Latin letters records (#47) for a learner
  /// learning the alphabet who is past its script units: they recalled the
  /// word but not how it is written. Before the script, or without the
  /// alphabet, it counts in full.
  static const int romanisedGrade = 3;

  /// Whether each language's script units are behind the learner, found
  /// once a session.
  final Map<String, bool> _scriptLearned = <String, bool>{};

  /// Whether the script is expected of the learner now: they learn the
  /// alphabet and are past its script units. Until then answers start in
  /// Latin letters and count in full.
  bool get expectsScript {
    final code = deck.language.code;
    return learnsAlphabet &&
        _scriptLearned.putIfAbsent(code, () => _state.scriptLearned(code));
  }

  /// Each language's romanised spelling, made once it is needed.
  final Map<String, RomanisedSpelling> _spellings =
      <String, RomanisedSpelling>{};

  RomanisedSpelling get _spelling {
    final language = deck.language;
    return _spellings.putIfAbsent(
      language.code,
      () => RomanisedSpelling(_state.romanisationFor(language)),
    );
  }

  /// [reading] as a learner types it, without ISO 15919's marks (ADR-0025):
  /// what the Latin-letters hint shows.
  String asTyped(String reading) => _spelling.asTyped(reading);

  /// Whether the current card's language is learned with its alphabet.
  bool get learnsAlphabet => _state.settings.learnsAlphabet(deck.language.code);

  /// Script, or Latin letters: as chosen, or else the script once it is
  /// [expectsScript], and Latin letters before.
  InputMode get inputMode =>
      _chosenMode ?? (expectsScript ? InputMode.script : InputMode.translit);

  /// Whether the answer is being typed in Latin letters. Only ever true
  /// while [Feature.translitInput] is on.
  bool get transliterating =>
      canTransliterate &&
      inputMode == InputMode.translit &&
      _state.features.isAvailable(Feature.translitInput);

  set inputMode(InputMode mode) {
    if (mode == inputMode || _phase != DrillPhase.prompt) return;
    if (!_state.features.isAvailable(Feature.translitInput)) return;
    _chosenMode = mode;
    // Words to put in order come in the other letters.
    _tiles = null;
    _placed.clear();
    notifyListeners();
  }

  /// The answers the grader accepts, the canonical one first: while
  /// [transliterating], the reading, then the target, which is accepted too.
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
    if (item.mode == DrillMode.recognition || question != null) return;
    if (ask != Ask.own) return;
    final accepted = item.card.acceptedAnswers(item.mode);
    final grader = typesDigits
        ? const AnswerGrader(typoDistance: 0, longTypoDistance: 0)
        : AnswerGrader(articles: deck.language.articles);
    var graded = grader.grade(
      typesDigits ? typed.replaceAll(RegExp(r'[\s,]'), '') : typed,
      accepted.first,
      alternates: accepted.sublist(1),
    );
    // In Latin letters, the reading in the language's scheme (#47). The
    // script is still accepted, and counts in full.
    var romanised = false;
    if (transliterating && graded.outcome != AnswerOutcome.exact) {
      final roman = _spelling.grade(typed, item.card.readings);
      if (roman.outcome.index < graded.outcome.index) {
        graded = roman;
        romanised = true;
      }
    }
    // A near miss that is word for word another card's answer is that
    // other word, not a slip: చేస్తావు for చేస్తాను is the wrong person.
    if (graded.outcome == AnswerOutcome.closeTypo &&
        _answersAnother(typed, romanised: romanised)) {
      graded = const GradedAnswer(AnswerOutcome.wrong, matched: null);
    }
    final grade = graded.outcome == AnswerOutcome.closeTypo
        ? null
        : romanised && graded.outcome.isCorrect && expectsScript
        ? romanisedGrade
        : graded.outcome.toSm2Grade();
    _answer = TypedAnswer(typed: typed, graded: graded, grade: grade);
    if (grade != null) _record(grade, answerGiven: typed);
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  /// Whether [typed] is exactly what another card of this deck accepts in
  /// this mode, or, [romanised], one of its readings: a different word or
  /// form, so never a typo.
  bool _answersAnother(String typed, {required bool romanised}) {
    final exact = AnswerGrader(
      articles: deck.language.articles,
      typoDistance: 0,
      longTypoDistance: 0,
    );
    final spelling = romanised ? _spelling : null;
    final key = spelling?.key(typed);
    for (final card in deck.cards) {
      if (card.id == item.card.id) continue;
      if (spelling != null) {
        if (card.readings.any((r) => spelling.key(r) == key)) return true;
        continue;
      }
      final answers = card.acceptedAnswers(item.mode);
      if (answers.isEmpty) continue;
      final graded = exact.grade(
        typed,
        answers.first,
        alternates: answers.sublist(1),
      );
      // Exact, or the same but for an accent or an article.
      if (graded.outcome != AnswerOutcome.wrong) return true;
    }
    return false;
  }

  /// "Don't know": shows the answer and records a failure.
  void dontKnow() {
    if (_phase != DrillPhase.prompt ||
        item.mode == DrillMode.recognition ||
        question != null ||
        ask.chooses ||
        ask == Ask.matchPairs) {
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
    if (_phase != DrillPhase.feedback) return;
    if (_choice == null &&
        _picked == null &&
        ask != Ask.matchPairs &&
        _answer?.awaitsJudgement != false) {
      return;
    }
    _advance();
  }

  // ---------------------------------------------------------------------------
  // Reading (#98, ADR-0019)

  /// The current card as a reading question, or null for any other card.
  QuestionCard? get question => switch (item.card) {
    final QuestionCard card => card,
    _ => null,
  };

  bool _showingPassage;

  /// Whether the passage shows on its own, before its first question: once
  /// for the questions about it that come together, read or heard.
  bool get showsPassage => _showingPassage;

  /// How many questions about the current passage, from this one on, come
  /// one after another in this session in this mode.
  int get passageQuestionsLeft {
    var count = 0;
    for (var i = _index; i < items.length; i++) {
      if (!_samePassage(items[_index], items[i])) break;
      count++;
    }
    return count;
  }

  /// From the passage to its first question. The clock starts again, so
  /// that reading the passage is not timed as the first answer.
  void toQuestions() {
    if (!_showingPassage) return;
    _showingPassage = false;
    _watch
      ..reset()
      ..start();
    notifyListeners();
  }

  int? _choice;

  /// The choice made on the current question, from 0, once it is made.
  int? get choice => _choice;

  List<int>? _choiceOrder;

  /// The order the current question's choices are shown in, as their
  /// indices. Options are shuffled each time a question is shown, so the
  /// answer is not always in the same place (#148); true and false keep
  /// their order.
  List<int> get choiceOrder {
    final q = question?.question;
    if (q == null) return const <int>[];
    if (q.isTrueFalse) return const <int>[0, 1];
    return _choiceOrder ??= List<int>.generate(q.choiceCount, (i) => i)
      ..shuffle(_random);
  }

  /// The language the current question is shown in: the best the learner
  /// speaks of those it is written in (#53).
  String get questionLanguage =>
      question!.question.languageFor(_state.settings.spokenLanguages);

  /// Chooses [choice] and records it at once: right or wrong, there is no
  /// near miss to judge.
  void choose(int choice) {
    final card = question;
    if (card == null || _showingPassage || _phase != DrillPhase.prompt) {
      return;
    }
    final q = card.question;
    if (choice < 0 || choice >= q.choiceCount) return;
    _choice = choice;
    _record(q.gradeFor(choice), answerGiven: q.logged(choice));
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  /// Whether the passage's text is showing: always when read; when heard,
  /// only once the question is answered.
  bool get showsPassageText =>
      item.mode != DrillMode.listening || _phase == DrillPhase.feedback;

  int? _playingSentence;

  /// The sentence playing now, or null while nothing is, or the whole
  /// passage is.
  int? get playingSentence => _playingSentence;

  /// Plays sentence [index] of the current passage.
  Future<void> playSentence(int index) async {
    final card = question;
    if (card == null || index < 0 || index >= card.passage.sentences.length) {
      return;
    }
    await _speakPassage(<String>[card.passage.sentences[index].text], index);
  }

  int _speaking = 0;

  /// Speaks [texts] in turn, stopping at a newer call or another card.
  Future<void> _speakPassage(List<String> texts, int? sentence) async {
    final call = ++_speaking;
    if (_playing) await _state.stopSpeaking();
    if (_disposed || call != _speaking) return;
    final at = _index;
    _playing = true;
    _playingSentence = sentence;
    notifyListeners();
    try {
      for (final text in texts) {
        if (_disposed || call != _speaking || _index != at) break;
        await _state.speak(text, deck.language, slower: _slower);
      }
    } finally {
      if (!_disposed && call == _speaking && _index == at) {
        _playing = false;
        _playingSentence = null;
        notifyListeners();
      }
    }
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

  /// Speaks the current card's target at the learner's rate, or slower: for
  /// a reading question, its whole passage, a sentence at a time. Every
  /// card's speaker plays through this, whatever its mode.
  Future<void> play() async {
    if (question case final card?) {
      return _speakPassage(<String>[
        for (final sentence in card.passage.sentences) sentence.text,
      ], null);
    }
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

  /// Speaks [card]'s target once, at the learner's rate: a word tile of a
  /// match, tapped while its speaker button is on (ADR-0032).
  Future<void> playCard(Card card) => _state.speak(
    card.target,
    _state.deckOf(card)?.language ?? deck.language,
    slower: _slower,
  );

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
    // A wrong word that is the answer with one sound changed: the feedback
    // names the sound (ADR-0014's rule: only a slip that changes the word).
    SoundContrast? contrast;
    Card? heardCard;
    if (!graded.outcome.isCorrect) {
      final sounds = _state.soundsFor(deck.language);
      if (sounds != null) {
        for (final answer in accepted) {
          contrast = sounds.between(said.text, answer);
          if (contrast != null) break;
        }
        if (contrast != null) {
          heardCard = _state.cardSaying(deck.language, said.text);
        }
      }
    }
    _unheard = null;
    _answer = TypedAnswer(
      typed: said.text,
      graded: graded,
      grade: grade,
      contrast: contrast,
      heardCard: heardCard,
    );
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
  // Teaching (ADR-0024)

  /// Whether the phone has a voice for the current card's language: whether
  /// its speaker shows. With sound off in Settings it still shows, greyed
  /// out ([soundOn]).
  bool get canPlay => _state.hasVoice(deck.language);

  /// Whether sound is on in Settings.
  bool get soundOn => _state.settings.soundOn;

  /// On from a card being taught. Nothing is recorded: its questions are.
  void learnt() {
    if (ask != Ask.teach) return;
    _advance();
  }

  // ---------------------------------------------------------------------------
  // Choosing, matching and rearranging (ADR-0024)

  /// How the current item is asked.
  Ask get ask => item.ask;

  /// How many options a choice question offers at most.
  static const int optionCount = 4;

  /// The grade a right choice or match records: right, but picked from a
  /// few rather than recalled.
  static const int choiceGrade = 4;

  List<Card>? _options;

  /// The current choice question's options, the card itself among them, in
  /// the order shown: up to [optionCount], the others from
  /// [AppState.choicePool], each showing something different.
  List<Card> get options => _options ??= _pickOptions();

  List<Card> _pickOptions() {
    final card = item.card;
    final pool = _state.choicePool(card, ask)..shuffle(_random);
    final shown = <String>{ask.optionOf(card)};
    final picked = <Card>[card];
    for (final other in pool) {
      if (picked.length == optionCount) break;
      if (shown.add(ask.optionOf(other))) picked.add(other);
    }
    return picked..shuffle(_random);
  }

  Card? _picked;

  /// The option picked on the current question, once it is.
  Card? get picked => _picked;

  /// Whether [option] is right: it shows what the card does.
  bool isRight(Card option) => ask.optionOf(option) == ask.optionOf(item.card);

  /// Picks [option] and records it at once: [choiceGrade] if right, 1 if
  /// not.
  void pick(Card option) {
    if (!ask.chooses || _phase != DrillPhase.prompt) return;
    _picked = option;
    _record(
      isRight(option) ? choiceGrade : 1,
      answerGiven: ask.optionOf(option),
    );
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  List<SessionItem>? _matchTargets;
  List<SessionItem>? _matchMeanings;

  /// The current match's items by their targets, and by their meanings,
  /// each in an order of its own.
  List<SessionItem> get matchTargets =>
      _matchTargets ??= <SessionItem>[...item.group]..shuffle(_random);
  List<SessionItem> get matchMeanings =>
      _matchMeanings ??= <SessionItem>[...item.group]..shuffle(_random);

  final Set<String> _matched = <String>{};
  final Set<String> _missed = <String>{};

  /// Whether [entry] of the current match is matched.
  bool isMatched(SessionItem entry) => _matched.contains(entry.card.id);

  /// Whether [entry]'s target was matched with a wrong meaning before.
  bool wasMissed(SessionItem entry) => _missed.contains(entry.card.id);

  /// Matches [target]'s target with [meaning]'s meaning, and returns
  /// whether that is right. A right match is recorded for [target] at
  /// once: [choiceGrade], or 1 if its target was matched wrongly before. A
  /// wrong one records nothing yet. Once all are matched, the feedback
  /// shows.
  bool match(SessionItem target, SessionItem meaning) {
    if (ask != Ask.matchPairs ||
        _phase != DrillPhase.prompt ||
        isMatched(target) ||
        isMatched(meaning)) {
      return false;
    }
    if (target.card.id != meaning.card.id) {
      _missed.add(target.card.id);
      notifyListeners();
      return false;
    }
    _matched.add(target.card.id);
    _recordItem(
      target,
      wasMissed(target) ? 1 : choiceGrade,
      answerGiven: meaning.card.native,
    );
    _watch
      ..reset()
      ..start();
    if (_matched.length == item.group.length) _phase = DrillPhase.feedback;
    notifyListeners();
    return true;
  }

  /// Whether the current card's words are put in order in Latin letters:
  /// while [transliterating], when its reading has as many words as it.
  bool get rearrangesReading {
    final reading = item.card.reading;
    return transliterating &&
        reading != null &&
        wordsOf(reading).length == wordsOf(item.card.target).length;
  }

  List<String> get _words =>
      tilesOf(rearrangesReading ? item.card.reading! : item.card.target);

  List<String>? _tiles;

  /// The current card's words to put in order, shuffled out of order where
  /// they can be.
  List<String> get tiles => _tiles ??= _shuffledWords();

  List<String> _shuffledWords() {
    final words = _words;
    final tiles = <String>[...words];
    for (var i = 0; i < 8 && listEquals(tiles, words); i++) {
      tiles.shuffle(_random);
    }
    return tiles;
  }

  final List<int> _placed = <int>[];

  /// The [tiles] placed so far, by index, in the order placed.
  List<int> get placed => List<int>.unmodifiable(_placed);

  /// Places tile [index] next in the answer.
  void place(int index) {
    if (ask != Ask.rearrange ||
        _phase != DrillPhase.prompt ||
        index < 0 ||
        index >= tiles.length ||
        _placed.contains(index)) {
      return;
    }
    _placed.add(index);
    notifyListeners();
  }

  /// Takes tile [index] out of the answer, back among the others.
  void unplace(int index) {
    if (_phase != DrillPhase.prompt || !_placed.remove(index)) return;
    notifyListeners();
  }

  /// Checks the words placed, once every tile is: right, recorded 5, if
  /// they read as the card's target or another it accepts, in Latin
  /// letters its readings; else 1.
  void checkOrder() {
    if (ask != Ask.rearrange ||
        _phase != DrillPhase.prompt ||
        _placed.length != tiles.length) {
      return;
    }
    final given = <String>[for (final i in _placed) tiles[i]].join(' ');
    final card = item.card;
    final accepted = rearrangesReading
        ? card.readings
        : card.acceptedAnswers(DrillMode.production);
    final right = accepted.any((a) => tilesOf(a).join(' ') == given);
    final grade = right
        ? AnswerOutcome.exact.toSm2Grade()
        : AnswerOutcome.wrong.toSm2Grade();
    _answer = TypedAnswer(
      typed: given,
      graded: right
          ? GradedAnswer(AnswerOutcome.exact, matched: given)
          : const GradedAnswer(AnswerOutcome.wrong, matched: null),
      grade: grade,
    );
    _record(grade, answerGiven: given);
    _phase = DrillPhase.feedback;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  void _record(int grade, {String? answerGiven}) =>
      _recordItem(item, grade, answerGiven: answerGiven);

  void _recordItem(SessionItem entry, int grade, {String? answerGiven}) {
    if (recorded || (recordsMisses && grade < Sm2.passingGrade)) {
      _state.record(
        entry,
        grade,
        elapsed: _watch.elapsed,
        answerGiven: answerGiven,
      );
    }
    _answers.add(SessionAnswer(skill: Skill.of(entry.mode), grade: grade));
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
  /// skill not paused since the session was built, not a listening card
  /// while sound is off, and not a speaking card in a language found not to
  /// be heard at all, or whose online question the learner declined and has
  /// not since allowed.
  bool _drillable(SessionItem item) {
    // A word is taught whatever comes of its questions.
    if (item.ask == Ask.teach) return true;
    if (item.mode == DrillMode.listening && !soundOn) return false;
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
    _playingSentence = null;
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
    // A passage shows once for its questions that come together, and again
    // when it comes back in the other mode.
    _showingPassage =
        items[next].card is QuestionCard &&
        !_samePassage(items[_index], items[next]);
    _index = next;
    _phase = DrillPhase.prompt;
    _answer = null;
    _choice = null;
    _choiceOrder = null;
    _options = null;
    _picked = null;
    _matchTargets = null;
    _matchMeanings = null;
    _matched.clear();
    _missed.clear();
    _tiles = null;
    _placed.clear();
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

/// Whether [a] and [b] ask about the same passage, in the same mode.
bool _samePassage(SessionItem a, SessionItem b) =>
    a.mode == b.mode &&
    a.card is QuestionCard &&
    (a.card as QuestionCard).sharesPassage(b.card);
