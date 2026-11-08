import 'dart:math' as math;

import 'assurance_model.dart';
import 'item_registry.dart';
import 'joint_model.dart';
import 'placement_profile.dart';
import 'placement_data.dart';
import 'placement_questions.dart' show PlacementSkill;
import 'script_gate.dart';
import 'v3_grading.dart';
import 'v3_picker.dart';

// One "Find my level" V3 run in progress (wiki/Plan-Placement-V3.md, step 7):
// the script gate, the joint model and the picker working together, as the
// run page needs them. Pure Dart: no Flutter, no storage, no clock.
//
// The state of a run is the list of its [events] (one per answer): the same
// events give the same run (the seed fixes every choice), so a paused run is
// saved as its events and rebuilt by [V3Run.replay].

/// How the learner answers a question.
enum V3Mode {
  /// Pick one of [V3Question.options].
  pick,

  /// Put [V3Question.tiles] in order.
  tiles,

  /// Type the word.
  type,

  /// Type the unit left out of the word shown with a gap.
  gap,

  /// Yes, I know this word, or no.
  yesNo,

  /// Say the word (a recogniser scores it).
  say,

  /// Say the word and rate oneself (no recogniser: never evidence).
  rateSay,
}

/// One question as the screen shows it: plain data, no widgets.
class V3Question {
  const V3Question({
    required this.id,
    required this.format,
    required this.mode,
    this.shown,
    this.shownIsTarget = false,
    this.audio,
    this.options = const <String>[],
    this.optionsAreTarget = false,
    this.tiles = const <String>[],
    this.joiner = ' ',
    this.leadingMark = '',
    this.trailingMark = '',
    this.gapBefore = '',
    this.gapAfter = '',
    this.script = false,
    this.item,
    this.gateItem,
  });

  final String id;

  /// The format code (`F2`...).
  final String format;
  final V3Mode mode;

  /// What is shown: a word or sentence of the language (when [shownIsTarget])
  /// or an English meaning. Null for a question that is only heard.
  final String? shown;
  final bool shownIsTarget;

  /// The text to play, in the language learned; null for a question that is
  /// not heard.
  final String? audio;

  final List<String> options;

  /// Whether the options are words of the language (not meanings).
  final bool optionsAreTarget;

  final List<String> tiles;

  /// What joins the tiles of an answer: nothing for a word, a space for a
  /// sentence.
  final String joiner;
  final String leadingMark;
  final String trailingMark;

  /// For [V3Mode.gap]: the word's units before and after the gap.
  final String gapBefore;
  final String gapAfter;

  /// A question of the script gate.
  final bool script;

  /// The bank item (null for a gate question).
  final RegItem? item;
  final ScriptGateItem? gateItem;

  bool get isHeard => audio != null;
}

/// How a skill that was not placed came to be left out.
enum V3Why {
  /// Hear without a voice, or Say without a microphone.
  noDevice,

  /// Read or Write while the script cannot be read yet.
  needsScript,

  /// Say only rated by the learner, never evidence.
  selfRated,

  /// Not enough answers to place it.
  notEnough,
}

/// What the learner said about the script, when the run starts.
enum V3ScriptStart {
  /// Ask the letters of the gate.
  ask,

  /// The learner says they read the script ("I do read it"): the gate leans
  /// toward it, and still asks.
  declaredReads,

  /// No gate: the letters count as known (the learner re-checks after
  /// saying so, or the script is Latin).
  skip,
}

/// How many questions in a row whose sound would not play offer the learner
/// to carry on without sound.
const int kSkipsBeforeOfferingNoSound = 2;

/// A run of the V3 placement.
class V3Run {
  V3Run({
    required this.data,
    required Set<PlacementSkill> skills,
    required this.audio,
    required this.recogniser,
    required this.seed,
    this.declaration,
    this.scriptStart = V3ScriptStart.ask,
    this.yesNoBlock = false,
    this.startedWithStarter = false,
    this.fullItems,
    this.profile = PlacementProfile.defaults,
    required List<RegItem> items,
  }) : wanted = Set<PlacementSkill>.unmodifiable(skills),
       levels = PlacementLevels(data.deckCount, maxParts: 20),
       rng = math.Random(seed * 100003 + 17) {
    _items = items;
    final letters = scriptLettersOf(data);
    _gate = scriptStart == V3ScriptStart.skip || letters.length < 6
        ? ScriptGate.latin()
        : ScriptGate(
            letters,
            rng: rng,
            audio: audio,
            declaredReads: scriptStart == V3ScriptStart.declaredReads
                ? true
                : null,
          );
    _advance();
  }

  /// A run rebuilt from [events], as another run of the same arguments left
  /// it.
  factory V3Run.replay({
    required PlacementLanguageData data,
    required Set<PlacementSkill> skills,
    required bool audio,
    required bool recogniser,
    required int seed,
    required Iterable<String> events,
    PlacementDeclaration? declaration,
    V3ScriptStart scriptStart = V3ScriptStart.ask,
    bool yesNoBlock = false,
    bool startedWithStarter = false,
    List<RegItem>? fullItems,
    PlacementProfile profile = PlacementProfile.defaults,
    required List<RegItem> items,
  }) {
    final run = V3Run(
      data: data,
      skills: skills,
      audio: audio,
      recogniser: recogniser,
      seed: seed,
      declaration: declaration,
      scriptStart: scriptStart,
      yesNoBlock: yesNoBlock,
      startedWithStarter: startedWithStarter,
      fullItems: fullItems,
      profile: profile,
      items: items,
    );
    for (final e in events) {
      if (run.finished) break;
      run._replayEvent(e);
    }
    return run;
  }

  final PlacementLanguageData data;

  /// The skills the learner has in play.
  final Set<PlacementSkill> wanted;
  final bool audio;
  final bool recogniser;
  final int seed;
  final PlacementDeclaration? declaration;
  final V3ScriptStart scriptStart;

  /// Whether Read opens with a block of yes/no items (the picker's
  /// `yesNoBlock`; off in the app until the re-fit decides it).
  final bool yesNoBlock;

  /// Whether the run began with the first formats' items only (the rest of the
  /// bank was still being made). It then changes to the whole bank once, at
  /// the event `x` ([extendItems]); a run replayed from its events does the
  /// same at the same place, from [fullItems].
  final bool startedWithStarter;
  final List<RegItem>? fullItems;

  /// The calibration profile this run reads its constants from (the version is
  /// recorded with the placement).
  final PlacementProfile profile;
  bool _extended = false;
  final PlacementLevels levels;
  final math.Random rng;

  late List<RegItem> _items;
  late final ScriptGate _gate;
  JointPlacement? _model;
  V3Picker? _picker;
  ScriptGateResult? _gateResult;

  /// What the events were, in order: `r` right (or yes), `w` wrong (or no),
  /// `d` "I don't know", `u` the question could not be shown, `m` the
  /// microphone was given up, `k` keep going at the soft stop.
  final List<String> events = <String>[];

  V3Question? _question;
  PickerCandidate? _candidate;
  bool _gating = true;
  bool _finished = false;
  bool _keptGoing = false;
  bool _checkpoint = false;
  bool _micGivenUp = false;
  bool _audioDropped = false;
  int _skipsInARow = 0;
  int _answered = 0;
  double _seconds = 0;
  int _gateItems = 0;
  double _gateSeconds = 0;

  /// The current question, or null at a checkpoint or at the end.
  V3Question? get question => _checkpoint ? null : _question;

  /// Whether the run is at its soft stop and waits for "Keep going" or
  /// "See my result".
  bool get atCheckpoint => _checkpoint;

  bool get finished => _finished;

  /// How many questions were answered or skipped (the gate's included).
  int get answered => _answered;

  /// The 1-based number of the question shown.
  int get number => _answered + 1;

  /// The seconds the answered items nominally took (the run's own clock: the
  /// 5-minute budget).
  double get seconds => _seconds;

  /// The most items a run asks and the time it may take.
  int get maxItems => kRunMaxItems;
  double get maxSeconds => kRunMaxSeconds;

  /// How much of the run is used, 0 to 1 (the larger of items and time).
  double get progress => math.min(
    1.0,
    math.max(_answered / kRunMaxItems, _seconds / kRunMaxSeconds),
  );

  bool get inGate => _gating && !_finished;

  /// What the script gate found (null before it ends or without a gate).
  ScriptGateResult? get scriptResult => _gateResult;

  JointPlacement? get model => _model;
  V3Picker? get picker => _picker;

  /// The rest of the bank is ready (the run began with the clean items of its
  /// first formats): the picker may ask from all of it from now on.
  void extendItems(List<RegItem> items) {
    if (startedWithStarter && !_extended) {
      _extended = true;
      events.add('x');
    }
    _items = items;
    _picker?.replacePool(
      CandidatePool(PickerCandidate.fromItems(items, profile: profile), levels),
    );
  }

  /// Whether the learner gave the microphone up.
  bool get microphoneGivenUp => _micGivenUp;

  /// Whether the learner carried on without sound.
  bool get audioDropped => _audioDropped;

  /// Whether the sound failed [kSkipsBeforeOfferingNoSound] times in a row
  /// and the learner may be offered to carry on without it.
  bool get offerNoSound =>
      !_audioDropped && audio && _skipsInARow >= kSkipsBeforeOfferingNoSound;

  /// The skills the model reads (empty before the gate ends).
  List<PlacementSkill> get skillsInPlay =>
      _model?.skills ?? const <PlacementSkill>[];

  // ------------------------------------------------------------------ answers

  /// The learner picked option [index].
  void answerPick(int index) {
    final q = _question;
    if (q == null || _checkpoint) return;
    if (q.gateItem case final g?) {
      return _applyGate(index == g.correct);
    }
    _apply(gradePick(q.item!, index));
  }

  /// The learner placed tiles in the order [placed].
  void answerTiles(List<int> placed) {
    final q = _question;
    if (q?.item == null || _checkpoint) return;
    _apply(gradeTiles(q!.item!, placed));
  }

  /// The learner typed [text].
  void answerTyped(String text) {
    final q = _question;
    if (q?.item == null || _checkpoint) return;
    _apply(gradeTyped(q!.item!, text));
  }

  /// The learner said "yes, I know this word" ([yes]) or "no".
  void answerYesNo({required bool yes}) {
    final q = _question;
    if (q?.item == null || _checkpoint) return;
    _apply(gradeYesNo(yes: yes));
  }

  /// The recogniser heard [alternatives].
  void answerSaid(Iterable<String> alternatives) {
    final q = _question;
    if (q?.item == null || _checkpoint) return;
    _apply(gradeSaid(q!.item!, alternatives));
  }

  /// The learner rated their own Say ([good] or not): never evidence.
  void answerRated({required bool good}) {
    final q = _question;
    if (q?.item == null || _checkpoint) return;
    _apply(good ? AnswerOutcome.right : AnswerOutcome.wrong);
  }

  /// "I don't know": a miss that hides no guess. A gate question is a miss.
  void dontKnow() {
    final q = _question;
    if (q == null || _checkpoint) return;
    if (q.gateItem != null) return _applyGate(false);
    _apply(AnswerOutcome.dontKnow);
  }

  /// The question could not be shown (its sound would not play): it is left
  /// out, never a miss.
  void skipUnplayable() {
    final q = _question;
    if (q == null || _checkpoint) return;
    events.add('u');
    _skipsInARow++;
    if (q.gateItem != null) {
      // A gate item that cannot be played counts for nothing.
      _gate.skip();
      _gateItems++;
      _answered++;
      _advance();
      return;
    }
    _picker!.skip(_candidate!);
    _seconds += _candidate!.seconds;
    _answered++;
    _advance();
  }

  /// "I can't speak now": Say is no longer asked, and the question is left
  /// out.
  void giveUpMicrophone() {
    final q = _question;
    if (q == null || _checkpoint || _finished) return;
    _micGivenUp = true;
    _picker?.giveUpMicrophone();
    events.add('m');
    if (q.item != null && _candidate != null) {
      _picker!.skip(_candidate!);
      _seconds += _candidate!.seconds;
      _answered++;
      _advance();
    }
  }

  /// "Carry on without sound": Hear and Say are no longer asked, and the
  /// question is left out.
  void dropAudio() {
    final q = _question;
    if (q == null || _checkpoint || _finished || _audioDropped) return;
    _audioDropped = true;
    _skipsInARow = 0;
    _picker?.dropAudio();
    events.add('a');
    if (q.item != null && _candidate != null) {
      _picker!.skip(_candidate!);
      _seconds += _candidate!.seconds;
      _answered++;
      _advance();
    } else if (q.gateItem != null) {
      _gate.skip();
      _gateItems++;
      _answered++;
      _advance();
    }
  }

  /// "Keep going" at the soft stop.
  void keepGoing() {
    if (!_checkpoint) return;
    events.add('k');
    _keptGoing = true;
    _checkpoint = false;
  }

  /// "See my result" at the soft stop: the run ends with what it holds.
  void stop() {
    if (!_checkpoint) return;
    _checkpoint = false;
    _finished = true;
    _question = null;
  }

  // -------------------------------------------------------------- the engine

  void _replayEvent(String e) {
    switch (e) {
      case 'r':
        _replayOutcome(AnswerOutcome.right);
      case 'w':
        _replayOutcome(AnswerOutcome.wrong);
      case 'd':
        if (_question != null && !_checkpoint) dontKnow();
      case 'u':
        skipUnplayable();
      case 'm':
        giveUpMicrophone();
      case 'a':
        dropAudio();
      case 'x':
        if (fullItems != null) extendItems(fullItems!);
      case 'k':
        keepGoing();
    }
  }

  void _replayOutcome(AnswerOutcome outcome) {
    final q = _question;
    if (q == null || _checkpoint) return;
    if (q.gateItem != null) {
      _applyGate(outcome == AnswerOutcome.right);
    } else {
      _apply(outcome);
    }
  }

  void _applyGate(bool right) {
    _skipsInARow = 0;
    final g = _question!.gateItem!;
    events.add(right ? 'r' : 'w');
    _gate.record(right: right);
    _seconds += g.seconds;
    _gateItems++;
    _gateSeconds += g.seconds;
    _answered++;
    _advance();
  }

  void _apply(AnswerOutcome outcome) {
    _skipsInARow = 0;
    final c = _candidate!;
    events.add(switch (outcome) {
      AnswerOutcome.right => 'r',
      AnswerOutcome.wrong => 'w',
      AnswerOutcome.dontKnow => 'd',
    });
    final item = c.payload! as RegItem;
    // A self-rated Say outside the joint is only recorded: never evidence.
    final model = _model!;
    if (!(c.selfRated && !model.skills.contains(PlacementSkill.say))) {
      model.observe(
        item.toJointItem(
          calibration: GuessCalibration.seed.scaled(profile.guessScale),
          formatKey:
              profile.f4DecoyKey && item.format == 'F4' && item.decoyCount > 0
              ? 'F4decoys'
              : null,
          slipScale: profile.slipScale[item.format] ?? 1,
        ),
        outcome,
      );
    }
    _picker!.record(c, outcome);
    _seconds += c.seconds;
    _answered++;
    _advance();
  }

  /// Asks for the next question: the gate's, then the picker's.
  void _advance() {
    _checkpoint = false;
    if (_gating) {
      final g = _gate.next();
      if (g != null) {
        _candidate = null;
        _question = _gateQuestion(g);
        return;
      }
      _startPicker();
    }
    final c = _picker!.next();
    if (c == null) {
      _finished = true;
      _question = null;
      _candidate = null;
      return;
    }
    _candidate = c;
    _question = questionOf(c.payload! as RegItem, selfRated: c.selfRated);
    if (!_keptGoing && _picker!.softStop) _checkpoint = true;
  }

  void _startPicker() {
    _gating = false;
    final result = _gate.result;
    _gateResult = result;
    final base = <PlacementSkill>[
      for (final s in const <PlacementSkill>[
        PlacementSkill.read,
        PlacementSkill.hear,
        PlacementSkill.write,
        PlacementSkill.say,
      ])
        if (wanted.contains(s) &&
            (s != PlacementSkill.hear || audio) &&
            (s != PlacementSkill.say || (audio && recogniser)))
          s,
    ];
    final skills = result.skillsInPlay(
      base.isEmpty ? <PlacementSkill>[PlacementSkill.read] : base,
    );
    final model = JointPlacement(
      levels: levels,
      skills: skills,
      declaration: declaration,
      declarationWeight: profile.declarationWeight,
      temper: profile.temper,
      togetherShare: profile.togetherShare,
    );
    _model = model;
    final pool = CandidatePool(
      PickerCandidate.fromItems(_items, profile: profile),
      levels,
    );
    _picker = V3Picker(
      pool: pool,
      model: model,
      rng: rng,
      config: PickerConfig.forRun(
        audio: audio,
        mic: recogniser || audio,
        recogniser: recogniser && audio,
        yesNoBlock: yesNoBlock,
        profile: profile,
        gateItems: _gateItems,
        gateSeconds: _gateSeconds,
      ),
    );
  }

  // -------------------------------------------------------------- questions

  V3Question _gateQuestion(ScriptGateItem g) {
    final heard = g.kind == ScriptItemKind.soundToLetter;
    return V3Question(
      id: g.id,
      format: g.format,
      mode: V3Mode.pick,
      shown: heard ? null : g.prompt,
      shownIsTarget: true,
      // The letter is said by the voice (not its romanisation).
      audio: heard ? g.options[g.correct] : null,
      options: g.options,
      optionsAreTarget: !heard,
      script: true,
      gateItem: g,
    );
  }

  /// The screen's view of a bank [item]. A self-rated Say is asked as
  /// [V3Mode.rateSay].
  static V3Question questionOf(RegItem item, {bool selfRated = false}) {
    switch (item.format) {
      case 'F2':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.pick,
          shown: item.prompt,
          shownIsTarget: true,
          options: item.options,
          item: item,
        );
      case 'F13':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.pick,
          audio: item.prompt,
          options: item.options,
          item: item,
        );
      case 'F3':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.pick,
          shown: item.prompt,
          options: item.options,
          optionsAreTarget: true,
          item: item,
        );
      case 'F5':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.pick,
          shown: item.prompt,
          shownIsTarget: true,
          options: item.options,
          item: item,
        );
      case 'F17':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.pick,
          audio: item.prompt,
          options: item.options,
          item: item,
        );
      case 'F4':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.tiles,
          shown: item.prompt,
          tiles: item.tiles,
          joiner: '',
          item: item,
        );
      case 'F8':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.tiles,
          shown: item.prompt,
          tiles: item.tiles,
          leadingMark: item.leadingMark,
          trailingMark: item.trailingMark,
          item: item,
        );
      case 'F16':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.tiles,
          audio: item.prompt,
          tiles: item.tiles,
          leadingMark: item.leadingMark,
          trailingMark: item.trailingMark,
          item: item,
        );
      case 'F7':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.type,
          shown: item.prompt,
          item: item,
        );
      case 'F21':
        final units = item.answerTiles;
        final gap = item.gapIndex.clamp(0, units.length - 1);
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.gap,
          shown: item.prompt,
          gapBefore: units.take(gap).join(),
          gapAfter: units.skip(gap + 1).join(),
          item: item,
        );
      case 'F18':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: selfRated ? V3Mode.rateSay : V3Mode.say,
          shown: item.prompt,
          // A self-rated Say shows the word to say, so it can be rated.
          audio: null,
          item: item,
        );
      case 'F1':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.yesNo,
          shown: item.prompt,
          shownIsTarget: true,
          item: item,
        );
      case 'F14':
        return V3Question(
          id: item.id,
          format: item.format,
          mode: V3Mode.yesNo,
          audio: item.prompt,
          item: item,
        );
    }
    throw StateError('No screen for the format ${item.format}');
  }

  /// The letters of the course's scripts, as the script gate reads them
  /// (plain letters, then joined forms).
  static List<ScriptLetter> scriptLettersOf(
    PlacementLanguageData data,
  ) => <ScriptLetter>[
    for (final s in data.scripts) ...<ScriptLetter>[
      for (final c in s.letters)
        if ((c.reading ?? '').isNotEmpty) ScriptLetter(c.target, c.reading!),
      for (final c in s.joined)
        if ((c.reading ?? '').isNotEmpty)
          ScriptLetter(c.target, c.reading!, joined: true),
    ],
  ];
}
