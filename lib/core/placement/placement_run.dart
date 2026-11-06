import 'dart:math' as math;

import 'assurance_model.dart';
import 'assurance_readout.dart';
import 'placement_questions.dart';
import 'question_outcome.dart';

// The run controller of "Find my level" (wiki/Plan-Placement-V2.md, sections
// 1, 3 and 5): a pure state machine. Give it the declaration, the size of the
// path, the skills in play and the answers so far; it says what to ask next,
// or that the run is done. It draws no item, shows nothing and keeps nothing:
// the answers are the whole state.

/// What a run needs to know before it starts.
class PlacementRunConfig {
  PlacementRunConfig({
    required this.deckCount,
    required Set<PlacementSkill> skills,
    this.declaration,
    this.seed = 0,
    this.pathCompleteToB1 = false,
    this.allDecksDownloaded = false,
    this.microphone = true,
    List<int> grammarUnitDecks = const <int>[],
    this.floorFirst = true,
    this.recheckInPositioning = true,
    this.extraScriptQuestion = false,
    this.promoteToExpert = true,
    bool? expertTrack,
  }) : skills = Set<PlacementSkill>.unmodifiable(skills),
       tested = Set<PlacementSkill>.unmodifiable(<PlacementSkill>{
         for (final skill in skills)
           if (microphone || skill != PlacementSkill.say) skill,
       }),
       grammarUnitDecks = List<int>.unmodifiable(grammarUnitDecks),
       expertTrack =
           expertTrack ??
           (declaration == null || declaration == PlacementDeclaration.expert);

  /// The decks of the path up to B1 (`CoursePath`, `walkDecks`).
  final int deckCount;

  /// The skills the learner marked as known.
  final Set<PlacementSkill> skills;

  /// [skills] this run can test: with no mic Say is "Not tested".
  final Set<PlacementSkill> tested;

  /// The first answer of the run; `null` when the run has no declaration (the
  /// flat comparison baseline). Beginner skips the run.
  final PlacementDeclaration? declaration;

  /// Seeds the one random choice of a run, [PlacementQuestionRequest.shortlistPick].
  final int seed;

  /// Verified precondition: the path is marked B1 and nothing up to it is
  /// still to be written.
  final bool pathCompleteToB1;

  /// Verified precondition: every deck of the language is downloaded.
  final bool allDecksDownloaded;

  /// Whether the speech recogniser works: with none, Say is not tested and K1
  /// and K2 are picks.
  final bool microphone;

  /// The deck indexes of the path's grammar units, ascending; none skips the
  /// grammar bisection of positioning.
  final List<int> grammarUnitDecks;

  /// After a skill's first positioning probe is closed, probe deck 0 next
  /// (section 5.3, point 7a; approved 2026-11-05).
  final bool floorFirst;

  /// Apply the recheck rule in positioning (section 9, question 5: yes). Off,
  /// a miss is just evidence ("model-only").
  final bool recheckInPositioning;

  /// The third script question of section 6.2, one more per script. The
  /// published counts (15, 13 and 17) do not include it.
  final bool extraScriptQuestion;

  /// Move a skill proved to be at the top class while positioning to the
  /// expert track for the topics it has not had (section 4.5).
  final bool promoteToExpert;

  /// Start on the expert track (Expert, or no declaration) rather than in
  /// positioning (Advanced, Amateur).
  final bool expertTrack;

  /// Whether Verified can open at all (section 4.3, condition a).
  bool get verifiedPossible => pathCompleteToB1 && allDecksDownloaded;
}

/// One answered question.
class PlacementAnswer {
  const PlacementAnswer(this.request, this.correct);

  final PlacementQuestionRequest request;
  final bool correct;
}

/// What the run knows about one skill (section 4.3 and 5.5).
class SkillAssurance {
  const SkillAssurance({
    required this.skill,
    required this.label,
    required this.mass,
    required this.leadingClass,
    required this.placedLevel,
    required this.questions,
  });

  final PlacementSkill skill;

  /// The name shown to the learner.
  final AssuranceLabel label;

  /// The probability of the leading class (0 when not tested).
  final double mass;

  /// The leading class (0 is `none`).
  final int leadingClass;

  /// The last deck index known, or -1 for none: the placed level.
  final int placedLevel;

  /// How many answers were evidence for this skill.
  final int questions;

  /// "Positioned at unit N": the learner knows units up to N and learns from
  /// N + 1; 0 for none.
  int get placedUnit => placedLevel + 1;

  bool get isVerified => label == AssuranceLabel.verified;
}

/// A gap found by a split (section 3.2).
class PlacementGap {
  const PlacementGap({
    required this.topic,
    required this.part,
    required this.skills,
    required this.deck,
  });

  final PlacementTopic topic;
  final PlacementPart part;

  /// The skills the gap stops being Verified (section 4.3, condition d).
  final List<PlacementSkill> skills;
  final int deck;
}

/// The state of a run after some answers: immutable. [answer] returns the
/// next state; nothing is stored anywhere. The state is rebuilt from the
/// answers, so the same answers always give the same state.
class PlacementRun {
  PlacementRun(
    this.config, {
    List<bool> results = const <bool>[],
    this.checkpointsKept = 0,
    List<PlacementUnavailable> unavailable = const <PlacementUnavailable>[],
  }) : results = List<bool>.unmodifiable(results),
       unavailableLog = List<PlacementUnavailable>.unmodifiable(unavailable);

  final PlacementRunConfig config;

  /// Right (true) or wrong (false) for each question asked, in order. "I
  /// don't know" is a wrong answer.
  final List<bool> results;

  /// How many checkpoints the learner has answered "Keep going" to.
  final int checkpointsKept;

  /// The questions the question builder could not build, in the order it
  /// said so ([markUnavailable]). Like [results], part of the state: the same
  /// answers and the same log always give the same run.
  final List<PlacementUnavailable> unavailableLog;

  late final _Engine _engine = _Engine(config, results, unavailableLog);

  /// The question to ask now, or null when the run is done (or skipped).
  PlacementQuestionRequest? get next => _engine.pending?.request;

  bool get isDone => next == null;

  /// Beginner: the run never starts and writes nothing (section 4.5).
  bool get isSkipped => config.declaration == PlacementDeclaration.beginner;

  /// How many questions have been asked.
  int get asked => results.length;

  /// Every answer so far with the question it answered.
  List<PlacementAnswer> get history =>
      List<PlacementAnswer>.unmodifiable(_engine.answers);

  /// The learner has just answered a multiple of 25 questions and has not yet
  /// chosen Keep going or Stop here (section 5.4). A run that is done never
  /// has one. This is the flag; showing the checkpoint is the UI's job.
  bool get checkpointDue =>
      !isDone && asked > 0 && asked % 25 == 0 && checkpointsKept < asked ~/ 25;

  /// The state after [correct] was the answer to [next].
  PlacementRun answer(bool correct) {
    if (isDone) throw StateError('the run is done: there is no question');
    return PlacementRun(
      config,
      results: <bool>[...results, correct],
      checkpointsKept: checkpointsKept,
      unavailable: unavailableLog,
    );
  }

  /// The question builder cannot build [next] from this learner's data (a
  /// topic with a data gap, see [PlacementUnavailableReason]). The run then
  /// uses the plan's stated fallback, counts nothing as asked, and moves on:
  ///
  /// - minimal pairs: Write tiles where the pair audio is untrusted or not
  ///   there, complex words where the language has no pair list;
  /// - any other base question: left out; its skills are then not covered,
  ///   so they cannot be Verified (section 4.3, condition c);
  /// - a split or a recheck: the check is dropped, the miss stays as the
  ///   evidence it was, and the skills of the question are unresolved: they
  ///   cannot be Verified (the plan is silent; an unsettled miss is not
  ///   proof);
  /// - a positioning probe or a top-up: the skill is left out of the run;
  /// - the grammar bisection: it ends.
  PlacementRun markUnavailable(PlacementUnavailableReason reason) {
    final current = next;
    if (current == null) {
      throw StateError('the run is done: there is no question');
    }
    return PlacementRun(
      config,
      results: results,
      checkpointsKept: checkpointsKept,
      unavailable: <PlacementUnavailable>[
        ...unavailableLog,
        PlacementUnavailable(
          afterAnswers: results.length,
          variant: current.variant,
          reason: reason,
        ),
      ],
    );
  }

  /// The learner chose Keep going at the checkpoint.
  PlacementRun keepGoing() => PlacementRun(
    config,
    results: results,
    checkpointsKept: asked ~/ 25,
    unavailable: unavailableLog,
  );

  /// The assurance of every skill, as it stands: a skill the learner did not
  /// mark, or that was not asked, is Not tested.
  Map<PlacementSkill, SkillAssurance> get readout => _engine.readout();

  /// The grammar level the bisection of positioning found, as a deck index,
  /// or null when it was not asked.
  int? get grammarDeck => _engine.grammarDeck;

  /// The gaps the splits found.
  List<PlacementGap> get gaps => List<PlacementGap>.unmodifiable(_engine.gaps);

  /// The base questions that were left out because no question could be built
  /// (and had no fallback), as their plan names.
  Set<PlacementVariant> get skippedQuestions =>
      Set<PlacementVariant>.of(_engine.skippedVariants);

  /// The skills with a miss that no check settled, because a split or a
  /// recheck could not be built ([markUnavailable]). They cannot be Verified.
  Set<PlacementSkill> get unresolvedSkills =>
      Set<PlacementSkill>.of(_engine.unresolvedSkills);

  /// The skills that have a closed case in this run.
  Set<PlacementSkill> get closedSkills =>
      Set<PlacementSkill>.of(_engine.closedSkills);

  /// The topics closed by a miss and failed checks.
  Set<PlacementTopic> get closedTopics =>
      Set<PlacementTopic>.of(_engine.closedTopics);

  /// The skills still on the expert track.
  Set<PlacementSkill> get expertSkills => Set<PlacementSkill>.of(_engine.track);

  /// The reporting posterior of [skill] (flat prior; the declaration is never
  /// in it), or null for a skill not tested.
  PlacementPosterior? posteriorOf(PlacementSkill skill) =>
      _engine.reporting[skill];

  /// The classes and levels of this run's path.
  PlacementLevels get levels => _engine.levels;
}

// ---------------------------------------------------------------------------

/// A request not yet numbered.
class _Spec {
  _Spec({
    required this.role,
    required this.topic,
    required this.variant,
    required this.kind,
    required this.skills,
    required this.deck,
    this.base,
    this.baseIndex = -1,
    this.half = false,
    this.updates = true,
    this.first = false,
    this.split,
    this.grammarIndex = -1,
    this.isFallback = false,
  });

  final PlacementQuestionRole role;
  final PlacementTopic topic;
  final PlacementVariant variant;
  final PlacementQuestionKind kind;
  final List<PlacementSkill> skills;
  final int deck;
  final PlacementBaseQuestion? base;
  final int baseIndex;

  /// A miss counts at half strength.
  final bool half;

  /// Whether the answer is evidence for the posterior (grammar is not).
  final bool updates;

  /// The first positioning probe of a skill.
  final bool first;
  final PlacementSplit? split;
  final int grammarIndex;

  /// Asked in place of a question the builder could not build.
  final bool isFallback;

  _Spec asRecheck() => _Spec(
    role: PlacementQuestionRole.recheck,
    topic: topic,
    variant: variant,
    kind: kind,
    skills: skills,
    deck: deck,
    base: base,
    baseIndex: baseIndex,
    updates: updates,
    first: first,
    grammarIndex: grammarIndex,
    isFallback: isFallback,
  );
}

class _Pending {
  const _Pending(this.spec, this.request);

  final _Spec spec;
  final PlacementQuestionRequest request;
}

/// An open check: the sequential recheck of a single-skill question, or the
/// two splits of a composite.
class _Case {
  _Case(this.origin);

  final _Spec origin;
  final List<bool> results = <bool>[];
  final List<_Spec> splitSpecs = <_Spec>[];
}

class _Positioning {
  bool floorPending = false;
  int probes = 0;
}

class _Grammar {
  int stage = 0;
  int firstIndex = 0;
  int? probeIndex;
  int? levelIndex;
  bool up = true;
  bool done = false;
}

class _Engine {
  _Engine(
    this.config,
    List<bool> results,
    List<PlacementUnavailable> unavailable,
  ) : levels = PlacementLevels(config.deckCount) {
    final tested = config.tested;
    final skipped = config.declaration == PlacementDeclaration.beginner;
    final flat = PlacementPosterior.flat(levels);
    final prior = PlacementPosterior(
      levels,
      askingPriorWeights(levels, config.declaration),
    );
    for (final skill in tested) {
      reporting[skill] = flat;
      asking[skill] = prior;
    }
    base = buildBaseQuestions(
      tested,
      microphone: config.microphone,
      extraScriptQuestion: config.extraScriptQuestion,
    );
    done = <Set<PlacementSkill>>[
      for (var i = 0; i < base.length; i++) <PlacementSkill>{},
    ];
    if (config.expertTrack) {
      track.addAll(tested);
    } else if (config.promoteToExpert) {
      canPromote.addAll(tested);
    }
    if (skipped) return;
    pending = _choose();
    var next = 0;
    var asked = 0;
    // The builder's "cannot build this" notes come between two answers: the
    // ones logged after [asked] answers are applied before the next answer.
    void drain() {
      while (next < unavailable.length &&
          unavailable[next].afterAnswers <= asked) {
        final current = pending;
        if (current == null) return;
        _unavailable(current, unavailable[next].reason);
        next++;
      }
    }

    drain();
    for (final result in results) {
      final current = pending;
      if (current == null) break;
      _apply(current, result);
      asked++;
      drain();
    }
  }

  static const double _leaveBelow = 0.20;
  static const double _promoteFrom = 0.50;
  static const List<PlacementSkill> _positioningOrder = <PlacementSkill>[
    PlacementSkill.hear,
    PlacementSkill.read,
    PlacementSkill.say,
    PlacementSkill.write,
    PlacementSkill.script,
    PlacementSkill.secondScript,
  ];

  final PlacementRunConfig config;
  final PlacementLevels levels;

  final Map<PlacementSkill, PlacementPosterior> reporting =
      <PlacementSkill, PlacementPosterior>{};
  final Map<PlacementSkill, PlacementPosterior> asking =
      <PlacementSkill, PlacementPosterior>{};
  final Map<PlacementSkill, int> evidence = <PlacementSkill, int>{};

  late final List<PlacementBaseQuestion> base;
  late final List<Set<PlacementSkill>> done;

  final Set<PlacementSkill> track = <PlacementSkill>{};
  final Set<PlacementSkill> canPromote = <PlacementSkill>{};
  final Set<PlacementTopic> closedTopics = <PlacementTopic>{};

  /// Base questions (by index) not asked because no question could be built.
  final Set<int> unavailableBase = <int>{};
  final Set<PlacementVariant> skippedVariants = <PlacementVariant>{};

  /// Skills left out of positioning and top-ups for the same reason.
  final Set<PlacementSkill> unavailableSkills = <PlacementSkill>{};
  final Set<PlacementSkill> closedSkills = <PlacementSkill>{};
  final Set<PlacementSkill> gapSkills = <PlacementSkill>{};

  /// Skills with a miss whose check (the two splits, or the recheck) could not
  /// be asked: the miss is neither forgiven nor closed, so the skill cannot
  /// be Verified.
  final Set<PlacementSkill> unresolvedSkills = <PlacementSkill>{};
  final List<PlacementGap> gaps = <PlacementGap>[];
  final List<PlacementAnswer> answers = <PlacementAnswer>[];

  final Map<PlacementSkill, _Positioning> _positioning =
      <PlacementSkill, _Positioning>{};
  final _Grammar _grammar = _Grammar();
  final List<_Spec> _forced = <_Spec>[];
  _Case? _case;

  _Pending? pending;
  int? grammarDeck;

  int get _top => levels.lastDeck;

  double _percentile(int deck) => _top == 0 ? 100 : deck * 100 / _top;

  _Pending _issue(_Spec spec) {
    final number = answers.length + 1;
    final random = math.Random(config.seed * 100003 + number);
    return _Pending(
      spec,
      PlacementQuestionRequest(
        number: number,
        role: spec.role,
        topic: spec.topic,
        variant: spec.variant,
        kind: spec.kind,
        skills: spec.skills,
        deck: spec.deck,
        percentile: _percentile(spec.deck),
        shortlistPick: random.nextInt(5),
        originVariant:
            spec.split != null || spec.role == PlacementQuestionRole.isolating
            ? spec.base?.id
            : null,
      ),
    );
  }

  // --- choosing the next question ------------------------------------------

  _Pending? _choose() {
    if (_forced.isNotEmpty) return _issue(_forced.removeAt(0));

    final baseSpec = _nextBase();
    if (baseSpec != null) return _issue(baseSpec);

    // Skills on the track that are short of the target get one more question
    // at a time; one that has fallen under 20% leaves for positioning.
    for (final skill in PlacementSkill.values) {
      if (!track.contains(skill) || unavailableSkills.contains(skill)) continue;
      final mass = reporting[skill]!.topMass;
      if (reachesTarget(mass)) continue;
      if (mass < _leaveBelow) {
        track.remove(skill);
        continue;
      }
      return _issue(
        _Spec(
          role: PlacementQuestionRole.topUp,
          topic: PlacementTopic.topUp,
          variant: PlacementVariant.topUp,
          kind: _vocabularyKind(skill),
          skills: <PlacementSkill>[skill],
          deck: _top,
        ),
      );
    }

    for (final skill in _positioningOrder) {
      if (!config.tested.contains(skill) || track.contains(skill)) continue;
      if (unavailableSkills.contains(skill)) continue;
      if (reachesTarget(reporting[skill]!.leadingMass)) continue;
      return _issue(_probe(skill));
    }

    return _grammarQuestion();
  }

  _Spec? _nextBase() {
    for (var i = 0; i < base.length; i++) {
      final question = base[i];
      if (closedTopics.contains(question.topic)) continue;
      if (unavailableBase.contains(i)) continue;
      final need = <PlacementSkill>[
        for (final skill in question.skills)
          if (track.contains(skill) && !done[i].contains(skill)) skill,
      ];
      if (need.isEmpty) continue;
      return _Spec(
        role: PlacementQuestionRole.base,
        topic: question.topic,
        variant: question.id,
        kind: question.kind,
        skills: need,
        deck: _top,
        base: question,
        baseIndex: i,
        half: question.halfOnMiss,
      );
    }
    return null;
  }

  PlacementQuestionKind _vocabularyKind(PlacementSkill skill) {
    switch (skill) {
      case PlacementSkill.say:
        return PlacementQuestionKind.say;
      case PlacementSkill.write:
        return PlacementQuestionKind.tilesWord;
      case PlacementSkill.read:
      case PlacementSkill.hear:
      case PlacementSkill.script:
      case PlacementSkill.secondScript:
        return PlacementQuestionKind.pickOne;
    }
  }

  _Spec _probe(PlacementSkill skill) {
    final state = _positioning.putIfAbsent(skill, _Positioning.new);
    final deck = state.floorPending
        ? levels.levels.first
        : askingDeck(asking[skill]!);
    final first = state.probes == 0;
    state.floorPending = false;
    state.probes += 1;
    return _Spec(
      role: PlacementQuestionRole.probe,
      topic: PlacementTopic.positioning,
      variant: PlacementVariant.probe,
      kind: _vocabularyKind(skill),
      skills: <PlacementSkill>[skill],
      deck: deck,
      first: first,
    );
  }

  PlacementSkill? get _grammarSkill {
    if (config.tested.contains(PlacementSkill.read)) return PlacementSkill.read;
    if (config.tested.contains(PlacementSkill.hear)) return PlacementSkill.hear;
    return null;
  }

  _Pending? _grammarQuestion() {
    final skill = _grammarSkill;
    final units = config.grammarUnitDecks;
    if (skill == null || units.isEmpty || _grammar.done) return null;
    if (track.contains(skill)) return null;
    final posterior = reporting[skill]!;
    if (posterior.placedLevel < 0) return null;
    if (_grammar.stage == 0) {
      var index = 0;
      for (var i = 0; i < units.length; i++) {
        if (units[i] <= posterior.placedLevel) index = i;
      }
      _grammar.firstIndex = index;
      _grammar.probeIndex = index;
    }
    final index = _grammar.probeIndex!;
    return _issue(
      _Spec(
        role: PlacementQuestionRole.grammar,
        topic: PlacementTopic.grammarLevel,
        variant: PlacementVariant.grammar,
        kind: PlacementQuestionKind.pickOne,
        skills: <PlacementSkill>[skill],
        deck: units[index],
        updates: false,
        grammarIndex: index,
      ),
    );
  }

  // --- a question the builder cannot build ----------------------------------

  void _unavailable(_Pending current, PlacementUnavailableReason reason) {
    final spec = current.spec;
    switch (spec.role) {
      case PlacementQuestionRole.base:
        unavailableBase.add(spec.baseIndex);
        final fallback = spec.isFallback ? null : _fallbackFor(spec, reason);
        if (fallback != null) {
          pending = _issue(fallback);
          return;
        }
        skippedVariants.add(spec.variant);
      case PlacementQuestionRole.split:
        // The check cannot be asked: the miss stays as evidence and nothing
        // is forgiven or closed.
        unresolvedSkills.addAll(_case?.origin.skills ?? spec.skills);
        _case = null;
        _forced.removeWhere((s) => s.role == PlacementQuestionRole.split);
      case PlacementQuestionRole.recheck:
        unresolvedSkills.addAll(_case?.origin.skills ?? spec.skills);
        _case = null;
      case PlacementQuestionRole.isolating:
        break;
      case PlacementQuestionRole.topUp:
      case PlacementQuestionRole.probe:
        unavailableSkills.addAll(spec.skills);
        track.removeAll(spec.skills);
        _forced.clear();
        _case = null;
      case PlacementQuestionRole.grammar:
        _grammar.done = true;
        // A first probe that could not be asked leaves no grammar level; a
        // later one keeps what the earlier probes found.
        if (_grammar.stage == 1) {
          grammarDeck = config.grammarUnitDecks[_grammar.levelIndex ?? 0];
        }
    }
    pending = _choose();
  }

  /// The plan's stated fallback for a base question (row l, row j and
  /// section 8, items 1, 2 and 4); null where there is none.
  _Spec? _fallbackFor(_Spec spec, PlacementUnavailableReason reason) {
    if (spec.topic != PlacementTopic.minimalPairs) return null;
    final base = spec.base;
    final noPairs =
        reason == PlacementUnavailableReason.noSoundsFile ||
        reason == PlacementUnavailableReason.noPairFound;
    if (noPairs && config.tested.contains(PlacementSkill.hear)) {
      // Complex words instead: a heard complex word, pick its meaning.
      return _Spec(
        role: PlacementQuestionRole.base,
        topic: spec.topic,
        variant: PlacementVariant.w2b,
        kind: PlacementQuestionKind.pickOne,
        skills: const <PlacementSkill>[PlacementSkill.hear],
        deck: spec.deck,
        base: base,
        baseIndex: spec.baseIndex,
        isFallback: true,
      );
    }
    if (config.tested.contains(PlacementSkill.write)) {
      // The pair audio is not trusted or not there: the same contrast as a
      // spelling question (Write tiles).
      return _Spec(
        role: PlacementQuestionRole.base,
        topic: spec.topic,
        variant: spec.variant,
        kind: PlacementQuestionKind.tilesWord,
        skills: const <PlacementSkill>[PlacementSkill.write],
        deck: spec.deck,
        base: base,
        baseIndex: spec.baseIndex,
        isFallback: true,
      );
    }
    return null;
  }

  // --- applying an answer ---------------------------------------------------

  void _apply(_Pending current, bool correct) {
    final spec = current.spec;
    answers.add(PlacementAnswer(current.request, correct));

    if (spec.updates) {
      final missWeight = spec.half ? 0.5 : 1.0;
      for (final skill in spec.skills) {
        final before = reporting[skill];
        if (before == null) continue;
        reporting[skill] = before.update(
          deck: spec.deck,
          kind: spec.kind,
          correct: correct,
          missWeight: missWeight,
        );
        evidence[skill] = (evidence[skill] ?? 0) + 1;
      }
      // What a meaning-bearing topic shows about the last deck's vocabulary
      // is read by the asking posterior of every skill (the plan's example 7:
      // the probes after a closed topic 1 start where the misses left the
      // prior).
      final shared =
          spec.topic == PlacementTopic.longRecognition ||
          spec.topic == PlacementTopic.complexWords;
      for (final skill in asking.keys.toList()) {
        if (!shared && !spec.skills.contains(skill)) continue;
        asking[skill] = asking[skill]!.update(
          deck: spec.deck,
          kind: spec.kind,
          correct: correct,
          missWeight: missWeight,
        );
      }
    }

    switch (spec.role) {
      case PlacementQuestionRole.base:
        _afterBase(spec, correct);
      case PlacementQuestionRole.split:
        _afterSplit(spec, correct);
      case PlacementQuestionRole.recheck:
        _afterRecheck(spec, correct);
      case PlacementQuestionRole.topUp:
      case PlacementQuestionRole.probe:
      case PlacementQuestionRole.grammar:
        if (correct) {
          _afterRight(spec);
        } else {
          _startRecheck(spec);
        }
      case PlacementQuestionRole.isolating:
        break;
    }

    pending = _choose();
  }

  void _afterBase(_Spec spec, bool correct) {
    for (final skill in spec.skills) {
      done[spec.baseIndex].add(skill);
    }
    if (correct) return;
    final question = spec.base!;
    if (question.splits.isEmpty) {
      _startRecheck(spec);
      return;
    }
    final open = _Case(spec);
    _case = open;
    for (final split in question.splits) {
      _forced.add(
        _Spec(
          role: PlacementQuestionRole.split,
          topic: spec.topic,
          variant: split.id,
          kind: split.kind,
          skills: split.skills,
          deck: _top,
          base: question,
          baseIndex: spec.baseIndex,
          split: split,
        ),
      );
    }
  }

  void _afterSplit(_Spec spec, bool correct) {
    final open = _case!;
    open.results.add(correct);
    open.splitSpecs.add(spec);
    if (open.results.length < 2) return;
    _case = null;
    final wrong = open.results.where((r) => !r).length;
    final origin = open.origin;
    if (wrong == 0) return; // a slip, forgiven
    if (wrong == 1) {
      final failed = open.splitSpecs[open.results.indexOf(false)].split!;
      // 4.3(d): a gap in any part stops its skills being Verified.
      final blocked = List<PlacementSkill>.of(failed.skills);
      gapSkills.addAll(blocked);
      gaps.add(
        PlacementGap(
          topic: origin.topic,
          part: failed.part,
          skills: blocked,
          deck: origin.deck,
        ),
      );
      return;
    }
    _closeBase(origin);
  }

  void _startRecheck(_Spec spec) {
    if (spec.role == PlacementQuestionRole.probe &&
        !config.recheckInPositioning) {
      return;
    }
    if (_abandoned(spec)) return;
    _case = _Case(spec);
    _forced.add(spec.asRecheck());
  }

  /// In positioning a skill that has reached the target needs nothing more,
  /// even in the middle of a recheck (section 5.3, point 4).
  bool _abandoned(_Spec spec) {
    if (spec.role != PlacementQuestionRole.probe &&
        !(spec.role == PlacementQuestionRole.recheck &&
            spec.topic == PlacementTopic.positioning)) {
      return false;
    }
    final skill = spec.skills.first;
    if (!reachesTarget(reporting[skill]!.leadingMass)) return false;
    _case = null;
    _forced.clear();
    return true;
  }

  void _afterRecheck(_Spec spec, bool correct) {
    final open = _case;
    if (open == null) return;
    open.results.add(correct);
    if (correct) {
      _case = null;
      _afterRight(open.origin);
      return;
    }
    if (open.origin.topic == PlacementTopic.positioning && _abandoned(spec)) {
      return;
    }
    if (open.results.length < 2) {
      _forced.add(spec.asRecheck());
      return;
    }
    _case = null;
    _closed(open.origin);
  }

  /// A question of positioning, a top-up or grammar answered right, or
  /// forgiven as a slip.
  void _afterRight(_Spec origin) {
    switch (origin.role) {
      case PlacementQuestionRole.probe:
        final skill = origin.skills.first;
        final posterior = reporting[skill]!;
        if (canPromote.contains(skill) &&
            posterior.leadingClass == levels.topClass &&
            posterior.leadingMass >= _promoteFrom) {
          canPromote.remove(skill);
          track.add(skill);
        }
      case PlacementQuestionRole.grammar:
        _grammarResult(origin, true);
      case PlacementQuestionRole.base:
      case PlacementQuestionRole.topUp:
      case PlacementQuestionRole.recheck:
      case PlacementQuestionRole.split:
      case PlacementQuestionRole.isolating:
        break;
    }
  }

  /// A case closed: a miss and every check wrong.
  void _closed(_Spec origin) {
    switch (origin.role) {
      case PlacementQuestionRole.base:
        _closeBase(origin);
      case PlacementQuestionRole.topUp:
        closedSkills.addAll(origin.skills);
        _leaveIfLow(origin.skills);
      case PlacementQuestionRole.probe:
        closedSkills.addAll(origin.skills);
        final state = _positioning[origin.skills.first];
        if (config.floorFirst &&
            origin.first &&
            state != null &&
            origin.deck > levels.levels.first) {
          state.floorPending = true;
        }
      case PlacementQuestionRole.grammar:
        _grammarResult(origin, false);
      case PlacementQuestionRole.recheck:
      case PlacementQuestionRole.split:
      case PlacementQuestionRole.isolating:
        break;
    }
  }

  void _closeBase(_Spec origin) {
    final question = origin.base!;
    closedTopics.add(origin.topic);
    closedSkills.addAll(question.skills);
    // After a closed single-skill case one question tells the two causes
    // apart; it is not rechecked and closes nothing (section 3.2).
    if (origin.topic == PlacementTopic.minimalPairs &&
        config.tested.contains(PlacementSkill.write)) {
      _forced.add(
        _Spec(
          role: PlacementQuestionRole.isolating,
          topic: origin.topic,
          variant: PlacementVariant.isolating,
          kind: PlacementQuestionKind.tilesWord,
          skills: const <PlacementSkill>[PlacementSkill.write],
          deck: _top,
          base: question,
          baseIndex: origin.baseIndex,
        ),
      );
    } else if (origin.topic == PlacementTopic.sayByMeaning &&
        config.tested.contains(PlacementSkill.hear)) {
      _forced.add(
        _Spec(
          role: PlacementQuestionRole.isolating,
          topic: origin.topic,
          variant: PlacementVariant.isolating,
          kind: PlacementQuestionKind.pickOne,
          skills: const <PlacementSkill>[PlacementSkill.hear],
          deck: _top,
          base: question,
          baseIndex: origin.baseIndex,
        ),
      );
    }
    // The vocabulary of the last deck is missing, or two topics have failed:
    // nobody is an expert here, every skill is positioned.
    if (origin.topic == PlacementTopic.longRecognition ||
        origin.topic == PlacementTopic.complexWords ||
        closedTopics.length >= 2) {
      track.clear();
      return;
    }
    _leaveIfLow(question.skills);
  }

  void _leaveIfLow(List<PlacementSkill> skills) {
    for (final skill in skills) {
      final posterior = reporting[skill];
      if (posterior != null && posterior.topMass < _leaveBelow) {
        track.remove(skill);
      }
    }
  }

  void _grammarResult(_Spec origin, bool right) {
    final units = config.grammarUnitDecks;
    final index = origin.grammarIndex;
    final last = units.length - 1;
    if (_grammar.stage == 0) {
      _grammar.stage = 1;
      if (right) {
        _grammar.levelIndex = index;
        _grammar.up = true;
        if (index < last) {
          _grammar.probeIndex = (index + last + 1) ~/ 2;
          return;
        }
      } else {
        _grammar.up = false;
        if (index > 0) {
          _grammar.probeIndex = index ~/ 2;
          return;
        }
        _grammar.levelIndex = 0;
      }
    } else if (right) {
      _grammar.levelIndex = index;
    } else if (!_grammar.up) {
      _grammar.levelIndex = 0;
    }
    _grammar.done = true;
    grammarDeck = units[_grammar.levelIndex ?? 0];
  }

  // --- the readout ------------------------------------------------------------

  bool _covered(PlacementSkill skill) {
    var any = false;
    for (var i = 0; i < base.length; i++) {
      if (!base[i].skills.contains(skill)) continue;
      any = true;
      if (!done[i].contains(skill)) return false;
    }
    return any;
  }

  Map<PlacementSkill, SkillAssurance> readout() {
    final out = <PlacementSkill, SkillAssurance>{};
    for (final skill in PlacementSkill.values) {
      // A second script is listed only when the language has one.
      if (skill == PlacementSkill.secondScript &&
          !config.skills.contains(skill)) {
        continue;
      }
      final posterior = reporting[skill];
      final questions = evidence[skill] ?? 0;
      if (posterior == null || questions == 0) {
        out[skill] = SkillAssurance(
          skill: skill,
          label: AssuranceLabel.notTested,
          mass: 0,
          leadingClass: 0,
          placedLevel: -1,
          questions: 0,
        );
        continue;
      }
      var label = labelForMass(posterior.leadingMass);
      if (label == AssuranceLabel.verySure &&
          config.verifiedPossible &&
          posterior.leadingClass == levels.topClass &&
          questions >= 3 &&
          _covered(skill) &&
          !closedSkills.contains(skill) &&
          !gapSkills.contains(skill) &&
          !unresolvedSkills.contains(skill)) {
        label = AssuranceLabel.verified;
      }
      out[skill] = SkillAssurance(
        skill: skill,
        label: label,
        mass: posterior.leadingMass,
        leadingClass: posterior.leadingClass,
        placedLevel: posterior.placedLevel,
        questions: questions,
      );
    }
    return out;
  }
}
