import 'assurance_model.dart';
import 'generated_question.dart';
import 'guessability.dart';
import 'placement_data.dart';
import 'placement_questions.dart';
import 'placement_run.dart';
import 'question_builder.dart';
import 'question_outcome.dart';

// One "Find my level" run in progress (wiki/Plan-Placement-V2.md, section 5):
// the run controller ([PlacementRun]) and the question builder
// ([QuestionBuilder]) working together, as the run page of step 3 needs
// them. Pure: no Flutter, no storage, no clock.
//
// The state of a session is the list of [events] (answers, "Keep going" and
// "I can't speak now"): the same events always give the same session, so a
// paused run is saved as its events and rebuilt by replaying them
// ([PlacementSession.replay]).

/// What a session was asked to do, in the order it happened: `a1` an answer
/// that was right, `a0` one that was wrong, `k` Keep going at a checkpoint,
/// `m` the microphone was given up, `u` a question was skipped because its
/// sound could not be played.
typedef PlacementEvent = String;

/// The note a skipped Say question is logged with: nothing to play or hear.
const PlacementUnavailableReason _skippedSay =
    PlacementUnavailableReason.noAudio;

/// The most questions in a row the builder may fail to build before the run
/// is ended, so that a data gap can never loop.
const int _stuckAfter = 200;

class PlacementSession {
  PlacementSession(
    PlacementRunConfig config,
    this.data, {
    this.requireTrustedPairAudio = false,
    this.questionSource,
  }) : _config = config {
    _run = PlacementRun(_config);
    _builder = _newBuilder();
    _advance();
  }

  /// A session rebuilt from [events], as [events] of another session of the
  /// same [config] and [data] left it.
  factory PlacementSession.replay(
    PlacementRunConfig config,
    PlacementLanguageData data,
    Iterable<PlacementEvent> events, {
    bool requireTrustedPairAudio = false,
  }) {
    final session = PlacementSession(
      config,
      data,
      requireTrustedPairAudio: requireTrustedPairAudio,
    );
    for (final event in events) {
      switch (event) {
        case 'a1':
          if (session.question == null) return session;
          session.answer(true);
        case 'a0':
          if (session.question == null) return session;
          session.answer(false);
        case 'k':
          if (!session.atCheckpoint) return session;
          session.keepGoing();
        case 'm':
          session.dropMicrophone();
        case 'u':
          if (session.question == null) return session;
          session.skipUnplayable();
      }
    }
    return session;
  }

  final PlacementLanguageData data;
  final bool requireTrustedPairAudio;

  /// Where the questions come from instead of the builder (a question bank,
  /// for the replay harness); null builds them from [data].
  final QuestionSource? questionSource;

  PlacementRunConfig _config;
  late PlacementRun _run;
  late QuestionSource _builder;
  GeneratedQuestion? _question;
  bool _stuck = false;

  /// The microphone was given up after a Say question had been answered: the
  /// run cannot be rebuilt without it, so each later Say question is skipped.
  bool _skipSay = false;

  final List<PlacementEvent> _events = <PlacementEvent>[];

  /// The `itemIds` of each question built, in order, for the no-repeat set.
  final List<Set<String>> _askedLog = <Set<String>>[];

  /// The base question built for each variant, which a split or an isolating
  /// question checks.
  final Map<PlacementVariant, GeneratedQuestion> _lastBase =
      <PlacementVariant, GeneratedQuestion>{};

  QuestionSource _newBuilder() =>
      questionSource ??
      QuestionBuilder(
        data,
        tested: _config.tested,
        microphone: _config.microphone,
        requireTrustedPairAudio: requireTrustedPairAudio,
        seed: _config.seed,
      );

  PlacementRunConfig get config => _config;
  PlacementRun get run => _run;

  /// What happened, to save and replay.
  List<PlacementEvent> get events => List<PlacementEvent>.unmodifiable(_events);

  /// The question to show now, or null at a checkpoint or when the run is
  /// done.
  GeneratedQuestion? get question => _question;

  /// The learner has answered 25 questions (or 25 more) and chooses Keep
  /// going or Stop here (section 5.4).
  bool get atCheckpoint => _question == null && _run.checkpointDue;

  /// Every target has been reached, or the learner went as far as the data
  /// allows: there is nothing more to ask.
  bool get isDone => _question == null && !_run.checkpointDue;

  /// Whether the speech recogniser is still in use.
  bool get microphone => _config.microphone && !_skipSay;

  /// How many questions have been answered.
  int get asked => _run.asked;

  /// The assurance of every skill as it stands.
  Map<PlacementSkill, SkillAssurance> get readout => _run.readout;

  /// Answers the question on show ([question]).
  void answer(bool correct) {
    if (_question == null) {
      throw StateError('there is no question to answer');
    }
    _events.add(correct ? 'a1' : 'a0');
    _run = _run.answer(correct, guess: guessRateOf(_question!));
    _advance();
  }

  /// Keep going at a checkpoint.
  void keepGoing() {
    if (!atCheckpoint) throw StateError('there is no checkpoint');
    _events.add('k');
    _run = _run.keepGoing();
    _advance();
  }

  /// The question on show cannot be played (the voice failed): it is left
  /// out and never counts as a miss, like a Say question that cannot be
  /// asked ([PlacementRun.markUnavailable]), so the skill it was for is not
  /// proved rather than failed.
  void skipUnplayable() {
    if (_question == null) {
      throw StateError('there is no question to skip');
    }
    _events.add('u');
    _askedLog.removeLast();
    _run = _run.markUnavailable(PlacementUnavailableReason.noAudio);
    _advance();
  }

  /// "I can't speak now", or two listens in a row that heard nothing: a
  /// question the learner is not asked to say is never a miss (row j of
  /// section 6). With no Say answer given yet the run goes on as if there
  /// had been no microphone from the start (K1 and K2 become picks); after
  /// one, each Say question still to come is skipped, its skills left
  /// unproved (never failed).
  void dropMicrophone() {
    if (!microphone) return;
    _events.add('m');
    final current = _question;
    if (current != null) _askedLog.removeLast();
    // The English questions (K1 and K2) are said too: a spoken answer
    // already given cannot be rebuilt as a pick.
    final said = _run.history.any((a) => _needsMicrophone(a.request));
    if (said) {
      _skipSay = true;
    } else {
      _config = _config.copyWith(microphone: false);
      _run = PlacementRun(
        _config,
        results: _run.results,
        checkpointsKept: _run.checkpointsKept,
        unavailable: _run.unavailableLog,
        guesses: _run.guesses,
      );
      _builder = _newBuilder();
    }
    _advance();
  }

  bool _needsMicrophone(PlacementQuestionRequest request) =>
      request.kind == PlacementQuestionKind.say ||
      request.kind == PlacementQuestionKind.english;

  Set<String> get _asked => <String>{for (final ids in _askedLog) ...ids};

  void _advance() {
    _question = null;
    for (var i = 0; i < _stuckAfter; i++) {
      if (_run.checkpointDue) return;
      final request = _run.next;
      if (request == null) return;
      if (_skipSay && _needsMicrophone(request)) {
        _run = _run.markUnavailable(_skippedSay);
        continue;
      }
      final origin = request.originVariant;
      final outcome = _builder.build(
        request,
        asked: _asked,
        failed: origin == null ? null : _lastBase[origin],
      );
      switch (outcome) {
        case QuestionBuilt(:final question):
          _question = question;
          _askedLog.add(question.itemIds);
          if (request.role == PlacementQuestionRole.base) {
            _lastBase[request.variant] = question;
          }
          return;
        case QuestionUnavailable(:final reason):
          _run = _run.markUnavailable(reason);
      }
    }
    // Nothing could be built for 200 questions in a row: end the run with
    // what it has rather than loop.
    _stuck = true;
  }

  /// Whether the run ended because the data could not give any more
  /// questions, not because every target was reached.
  bool get endedForWantOfQuestions => _stuck;
}
