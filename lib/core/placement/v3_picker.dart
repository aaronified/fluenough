import 'dart:math' as math;

import 'assurance_model.dart';
import 'drill_down.dart';
import 'item_bank.dart';
import 'item_registry.dart';
import 'joint_model.dart';
import 'placement_questions.dart';

// The item picker of "Find my level" V3 (wiki/Plan-Placement-V3.md, section
// (c) and the amendments): which item to ask next, from the items of the
// bank that passed the admission audit.
//
// For each skill in play it LOCATES the learner (two items by bisection over
// the tenths of the path), then PROVES a band (four clean items of one band,
// 4 of 4 or 5 of 6) at the located level, goes down a band when two answers
// of it are wrong, and climbs while the proven band holds the start down.
// The item of a step is the one with the most information per second among
// the admitted formats of the skill in focus, an item that also needs another
// skill counting for it too, with no more than two of one format in a row.
// A skill with fewer than four clean items is never left (the coverage floor).
// Hear and Say are asked only when the device can play and record; Say
// without a recogniser is rated by the learner a few times and is never
// evidence. Caps: 40 items and 300 s overall, 14 touches a skill; a soft stop
// signal at 22 items (the UI offers to stop, or to keep going once).
//
// The two-in-a-row format rule holds for every item the picker chooses; the
// yes/no block, a fixed opening of 14 yes/no items in one format, is the one
// exception (it is not chosen item by item). When nothing else can be asked
// the rule is relaxed rather than ending a skill short, and a skill is
// finished only when it has no askable candidate at all. A run says why it
// ended ([EndReason]): a run that ends before every tested skill has four
// clean items says [EndReason.coverageShort] and names the skills.
//
// Pure Dart, deterministic for a seeded generator.

/// The bonus for a mixed item in a run that began with the script gate.
const double kScriptRunMixedBonus = 0.4;

/// The values a run that began with a script gate uses in place of the
/// defaults of [PickerConfig] (build step 6 measured them on the Devanagari
/// cells only; a run with no gate keeps the defaults, which the other cells
/// were measured with): the optional Say rating is left out once the run
/// holds this many items, and a skill that stands apart from the others is
/// probed with this many clean items of a proven band.
const int kScriptRunSayRatingUntilItems = 24;
const int kScriptRunStandApartItems = 8;

/// The caps of a whole run (the script gate's items and time included).
const int kRunMaxItems = 40;
const double kRunMaxSeconds = 300;
const int kRunSoftStopItems = 22;

/// Formats the bank admits but the picker must not ask yet: S2 (word order)
/// needs a grammaticality check for languages whose word order is free, and
/// F9 (matching) a screen. A candidate of these formats is refused by the
/// pool, and never chosen.
const Set<String> kUnaskableFormats = <String>{'S2', 'F9'};

/// One askable item, as the picker sees it. The bank's items are turned into
/// these by the caller ([deck] and [skills] are the item's difficulty and
/// what a right answer is evidence for).
class PickerCandidate {
  const PickerCandidate({
    required this.id,
    required this.format,
    required this.deck,
    required this.skills,
    required this.seconds,
    required this.slip,
    required this.guess,
    required this.conflictKeys,
    this.clean = true,
    this.needsAudio = false,
    this.needsMic = false,
    this.pseudo = false,
    this.yesNo = false,
    this.selfRated = false,
    this.payload,
  });

  final String id;

  /// The format code (`F2`...).
  final String format;

  /// The deck index the item is asked at.
  final int deck;

  final Set<PlacementSkill> skills;

  /// The time it takes, in seconds (the plan's table).
  final double seconds;

  /// The slip and the calibrated guess of the item.
  final double slip;
  final double guess;

  /// The keys no two asked items may share: a card, a lemma.
  final Set<String> conflictKeys;

  /// Whether the item can count toward coverage and proof.
  final bool clean;

  final bool needsAudio;
  final bool needsMic;

  /// A yes/no pseudoword, and a yes/no item (real or pseudo).
  final bool pseudo;
  final bool yesNo;

  /// Whether the learner rates their own answer (Say without a recogniser).
  final bool selfRated;

  /// What the caller needs to turn the candidate back into its item.
  final Object? payload;

  /// The candidate of a bank item, its guess calibrated by [calibration].
  /// The real item travels in [payload].
  factory PickerCandidate.fromItem(
    RegItem item, {
    GuessCalibration calibration = GuessCalibration.seed,
  }) {
    final info = item.info;
    final cognate = item.cognateClass == 'cognate';
    final yes = item.format == 'F1' || item.format == 'F14';
    final guess = yes
        ? 0.0
        : calibration.guessFor(item.format, cognate, info.guess);
    return PickerCandidate(
      id: item.id,
      format: item.format,
      deck: item.deck,
      skills: info.skills,
      seconds: info.seconds,
      slip: info.slip,
      guess: guess,
      conflictKeys: item.conflictKeys,
      clean: !cognate && guess <= kCleanGuessMax,
      needsAudio: info.needsAudio,
      needsMic: info.needsMic,
      pseudo: item.pseudo,
      yesNo: yes,
      payload: item,
    );
  }

  /// The candidates of every admitted item of [bank].
  static List<PickerCandidate> fromBank(
    ItemBank bank, {
    GuessCalibration calibration = GuessCalibration.seed,
  }) => fromItems(bank.items, calibration: calibration);

  /// The candidates of admitted [items] (a bank's, or the same list built
  /// elsewhere and handed over).
  static List<PickerCandidate> fromItems(
    Iterable<RegItem> items, {
    GuessCalibration calibration = GuessCalibration.seed,
  }) => <PickerCandidate>[
    for (final i in items)
      if (!kUnaskableFormats.contains(i.format))
        PickerCandidate.fromItem(i, calibration: calibration),
  ];

  PickerCandidate asSelfRated() => PickerCandidate(
    id: id,
    format: format,
    deck: deck,
    skills: skills,
    seconds: seconds,
    slip: slip,
    guess: guess,
    conflictKeys: conflictKeys,
    clean: false,
    needsAudio: needsAudio,
    needsMic: needsMic,
    selfRated: true,
    payload: payload,
  );
}

/// The candidates, indexed by format and band (a tenth of the path).
class CandidatePool {
  CandidatePool(Iterable<PickerCandidate> candidates, this.levels) {
    for (final c in candidates) {
      assert(
        !kUnaskableFormats.contains(c.format),
        '${c.format} is not askable by the picker yet',
      );
      if (c.pseudo) {
        pseudo.add(c);
        continue;
      }
      final band = bandOfDeck(levels, c.deck);
      ((_byFormat[c.format] ??= <int, List<PickerCandidate>>{})[band] ??=
              <PickerCandidate>[])
          .add(c);
    }
  }

  final PlacementLevels levels;

  /// The yes/no pseudowords, in the order given.
  final List<PickerCandidate> pseudo = <PickerCandidate>[];

  final Map<String, Map<int, List<PickerCandidate>>> _byFormat =
      <String, Map<int, List<PickerCandidate>>>{};

  /// The format codes the pool has.
  Iterable<String> get formats => _byFormat.keys;

  /// The candidates of [format] in [band].
  List<PickerCandidate> of(String format, int band) =>
      _byFormat[format]?[band] ?? const <PickerCandidate>[];

  /// The band (0 to 10) a deck falls in: the same rule as the joint model's.
  static int bandOfDeck(PlacementLevels levels, int deck) {
    var c = 1;
    while (c < levels.topClass && levels.levelOf(c) < deck) {
      c++;
    }
    return levels.parts == 0 ? 10 : ((c - 1) * 10 / levels.parts).ceil();
  }
}

/// What the picker may do, and the caps of a run.
class PickerConfig {
  const PickerConfig({
    this.audio = true,
    this.mic = true,
    this.recogniser = false,
    this.yesNoBlock = false,
    this.sayItems = 1,
    this.sayRatingUntilSeconds = 180,
    this.sayRatingUntilItems = 40,
    this.mixedBonus = 0.3,
    this.climbQuantile = 0.12,
    this.climbTolerance = 0.0,
    this.strictRecord = true,
    this.mixedOpening = 2,
    this.mixedQuantile = 0.5,
    this.standApartItems = 14,
    this.drill = const DrillConfig(),
    this.maxItems = 40,
    this.maxSeconds = 300,
    this.skillCap = 14,
    this.softStopItems = 22,
    this.locateItems = 2,
  });

  /// The configuration of a run whose script gate has asked [gateItems]
  /// items in [gateSeconds] seconds (none when the language has no gate): the
  /// caps of the whole run less what the gate used, and, after a gate, the
  /// values the gate's cells were measured with.
  factory PickerConfig.forRun({
    required bool audio,
    required bool mic,
    required bool recogniser,
    int gateItems = 0,
    double gateSeconds = 0,
    bool yesNoBlock = false,
  }) {
    final gated = gateItems > 0;
    return PickerConfig(
      audio: audio,
      mic: mic,
      recogniser: recogniser,
      yesNoBlock: yesNoBlock,
      mixedBonus: gated ? kScriptRunMixedBonus : 0.3,
      sayRatingUntilItems: gated ? kScriptRunSayRatingUntilItems : 40,
      standApartItems: gated ? kScriptRunStandApartItems : 14,
      maxSeconds: kRunMaxSeconds - gateSeconds,
      maxItems: kRunMaxItems - gateItems,
      softStopItems: kRunSoftStopItems - gateItems,
    );
  }

  /// Text to speech works: Hear can be tested.
  final bool audio;

  /// A microphone exists: Say can be rated.
  final bool mic;

  /// A recogniser scores Say.
  final bool recogniser;

  /// Whether Read opens with yes/no items (eight pseudowords, six words).
  final bool yesNoBlock;

  /// How many self-rated Say items are asked when no recogniser scores Say.
  final int sayItems;

  /// The rating of Say is optional (never evidence): it is left out when the
  /// run is already longer than this, to keep the median run short.
  final double sayRatingUntilSeconds;

  /// ... and when it already has this many items (the rating is optional
  /// and never evidence, and it counts as an item against the 28 of the
  /// median gate).
  final int sayRatingUntilItems;

  /// A proven band is climbed from while this quantile of the posterior lies
  /// more than [climbTolerance] tenths above the proven ceiling.
  /// What an item that also proves another skill's band is worth, in bits
  /// (0.3; a run in a non-Latin script uses 0.4, [kScriptRunMixedBonus]: the
  /// gate's items count against the median gate of 28 and mixed items save
  /// items at a cost in seconds the cells can spare).
  final double mixedBonus;

  final double climbQuantile;
  final double climbTolerance;

  /// The clean items of a proven band asked while the joint prior still
  /// holds the skill's lower edge more than 6 classes under it (a skill that
  /// stands apart from the others, an ear-only learner).
  final int standApartItems;

  /// How many mixed items (an item of two skills: tiles of Read and Write,
  /// dictation of Hear and Write) open the run, at the middle of the
  /// posterior: cheap per skill, and the drill-down tells apart a miss.
  final int mixedOpening;

  /// Whether an item whose answer was not reported through
  /// [V3Picker.record] is an error (an assert in a debug run). When it is
  /// not, or in a release build, the drill-down is abandoned instead and the
  /// run goes on without it.
  final bool strictRecord;

  /// The quantile of the posterior the opening mixed items are asked at.
  final double mixedQuantile;

  /// The isolating drill-down ([DrillConfig.enabled] turns it off).
  final DrillConfig drill;

  final int maxItems;
  final double maxSeconds;
  final int skillCap;

  /// The item count at which the UI is told it may stop (it can keep going
  /// to the caps).
  final int softStopItems;

  /// The items a skill is located with before a band is proved.
  final int locateItems;

  /// This configuration with the device's abilities changed (the learner gave
  /// the microphone up, or the voice failed).
  PickerConfig withDevice({bool? audio, bool? mic, bool? recogniser}) =>
      PickerConfig(
        audio: audio ?? this.audio,
        mic: mic ?? this.mic,
        recogniser: recogniser ?? this.recogniser,
        yesNoBlock: yesNoBlock,
        sayItems: sayItems,
        sayRatingUntilSeconds: sayRatingUntilSeconds,
        sayRatingUntilItems: sayRatingUntilItems,
        mixedBonus: mixedBonus,
        climbQuantile: climbQuantile,
        climbTolerance: climbTolerance,
        strictRecord: strictRecord,
        mixedOpening: mixedOpening,
        mixedQuantile: mixedQuantile,
        standApartItems: standApartItems,
        drill: drill,
        maxItems: maxItems,
        maxSeconds: maxSeconds,
        skillCap: skillCap,
        softStopItems: softStopItems,
        locateItems: locateItems,
      );
}

/// Why a run ended.
enum EndReason {
  /// Every tested skill is proven, placed at the start or finished.
  complete,

  /// The item cap was reached.
  itemCap,

  /// The time cap was reached, or no item that still fits in the time left
  /// could be found.
  timeCap,

  /// A skill ran out of askable items (the admitted bank has no more).
  exhausted,

  /// The run ended before every tested skill had four clean items (see
  /// [V3Picker.shortSkills]); [V3Picker.endCause] says why it ended.
  coverageShort,
}

class _SkillState {
  int? proving;
  bool finished = false;
  int located = 0;
}

/// The picker of a run over [pool], reading [model].
class V3Picker {
  V3Picker({
    required this.pool,
    required this.model,
    required this.rng,
    this.config = const PickerConfig(),
  });

  final CandidatePool pool;
  final JointPlacement model;
  final math.Random rng;

  /// What the picker may do. It changes only through [giveUpMicrophone].
  PickerConfig config;

  final Map<PlacementSkill, _SkillState> _state =
      <PlacementSkill, _SkillState>{};
  final Set<String> _keys = <String>{};
  final List<PickerCandidate> asked = <PickerCandidate>[];
  double seconds = 0;
  int _pseudoAsked = 0;
  int _yesNoWords = 0;
  int _selfRated = 0;

  /// The drill-down of the run: its cases say which skill failed what.
  late final DrillDown drillDown = DrillDown(model, config: config.drill);

  // What the posterior thought before each item asked, and which items were
  // isolating items of a drill-down.
  final Map<String, ({Map<PlacementSkill, double> known, double all})> _pre =
      <String, ({Map<PlacementSkill, double> known, double all})>{};
  final Set<String> _isolating = <String>{};
  final Set<PlacementSkill> _intervalChecked = <PlacementSkill>{};
  int _mixedAsked = 0;
  PickerCandidate? _unrecorded;

  /// How many items were asked.
  int get items => asked.length;

  /// Whether the run has reached the soft stop: the UI may offer to stop
  /// (and to keep going, once).
  bool get softStop => items >= config.softStopItems;

  EndReason? _endReason;
  EndReason? _endCause;
  List<PlacementSkill> _short = const <PlacementSkill>[];

  /// Why the run ended (null while it goes on). [EndReason.coverageShort]
  /// wins over the others: a run that ends before every tested skill has
  /// four clean items says so.
  EndReason? get endReason => _endReason;

  /// The underlying cause when [endReason] is [EndReason.coverageShort].
  EndReason? get endCause => _endCause;

  /// The tested skills with fewer than four clean items at the end.
  List<PlacementSkill> get shortSkills => _short;

  /// Whether the run reached a hard cap.
  bool get atCap => items >= config.maxItems || seconds >= config.maxSeconds;

  _SkillState _of(PlacementSkill skill) =>
      _state.putIfAbsent(skill, _SkillState.new);

  /// The skills the picker tests: those of the model, without Say when no
  /// recogniser scores it (Say is then only rated, never evidence), and
  /// without Hear and Say when there is no audio.
  List<PlacementSkill> get _tested => <PlacementSkill>[
    for (final s in model.skills)
      if (!(s == PlacementSkill.say && !config.recogniser) &&
          !(s == PlacementSkill.hear && !config.audio))
        s,
  ];

  /// The next item, or null when the run is over (every tested skill done,
  /// or a cap reached).
  PickerCandidate? next() {
    if (_endReason != null) return null;
    if (items >= config.maxItems) return _end(EndReason.itemCap);
    if (seconds >= config.maxSeconds) return _end(EndReason.timeCap);
    if (config.yesNoBlock) {
      final block = _yesNoNext();
      if (block != null) return _take(block);
    }
    if (_unrecorded != null) {
      assert(
        !config.strictRecord,
        'The answer to ${_unrecorded!.id} was not reported: call record() '
        'after every item observed.',
      );
      // Release: the drill-down reads answers, so it is given up and the run
      // goes on with the rotation.
      _isolating.clear();
      drillDown.abandon();
      _unrecorded = null;
    }
    if (config.drill.enabled) {
      // A skill about to be finished with a wide or contradictory interval
      // is drilled.
      // (the widest interval first).
      final ready =
          <PlacementSkill>[
            for (final s in _tested)
              if (!_intervalChecked.contains(s) && _isDone(s)) s,
          ]..sort((a, b) {
            int width(PlacementSkill k) {
              final (lo, hi) = drillDown.interval(k);
              return hi - lo;
            }

            return width(b).compareTo(width(a));
          });
      for (final s in ready) {
        _intervalChecked.add(s);
        drillDown.checkInterval(s, seconds: seconds);
      }
      // The drill-down in progress gives the next item.
      while (true) {
        final skill = drillDown.next();
        if (skill == null) break;
        final c = _chooseIsolating(skill, drillDown.active!);
        if (c != null) {
          _isolating.add(c.id);
          final taken = _take(c);
          if (taken == null) _isolating.remove(c.id);
          return taken;
        }
        drillDown.noCandidate(skill);
      }
    }
    if (_mixedAsked < config.mixedOpening && asked.length < 4) {
      final c = _chooseMixed();
      if (c != null) {
        _mixedAsked++;
        final taken = _take(c);
        if (taken != null) return taken;
      }
      _mixedAsked = config.mixedOpening;
    }
    final open =
        <PlacementSkill>[
          for (final s in _tested)
            if (!_isDone(s)) s,
        ]..sort((a, b) {
          final c = model.touchesOf(a).compareTo(model.touchesOf(b));
          return c != 0 ? c : a.index.compareTo(b.index);
        });
    // First the rules as they are; then, when nothing else is askable, the
    // format-run rule and the "another skill probably fails" rule are
    // relaxed and the bank is searched in full. A skill is finished only when
    // it has no candidate at all.
    for (final relaxed in const <int>[0, 1, 2]) {
      for (final skill in open) {
        if (_of(skill).finished) continue;
        final c = _choose(skill, relaxed: relaxed);
        if (c != null) return _take(c);
      }
    }
    var exhausted = false;
    var noFit = false;
    for (final skill in open) {
      if (_of(skill).finished || _isDone(skill)) continue;
      if (_hasAny(skill, anySeconds: true)) {
        noFit = true;
      } else {
        _of(skill).finished = true;
        exhausted = true;
      }
    }
    if (noFit) return _end(EndReason.timeCap);
    // Say without a recogniser is rated by the learner a few times, never
    // evidence and never extending the run.
    if (config.audio &&
        config.mic &&
        !config.recogniser &&
        _selfRated < config.sayItems &&
        seconds <= config.sayRatingUntilSeconds &&
        items < config.sayRatingUntilItems) {
      final c = _selfRatedSay();
      if (c != null) {
        _selfRated++;
        final taken = _take(c);
        if (taken != null) return taken;
      }
    }
    return _end(exhausted ? EndReason.exhausted : EndReason.complete);
  }

  PickerCandidate? _end(EndReason cause) {
    _short = <PlacementSkill>[
      for (final s in _tested)
        if (model.cleanItemsOf(s) < kMinCleanItems) s,
    ];
    _endCause = cause;
    _endReason = _short.isEmpty ? cause : EndReason.coverageShort;
    return null;
  }

  /// Whether [skill] has any free, askable candidate in the whole pool (only
  /// those that fit the time left unless [anySeconds]).
  bool _hasAny(PlacementSkill skill, {bool anySeconds = false}) {
    final left = config.maxSeconds - seconds;
    for (final format in pool.formats) {
      for (var b = 0; b <= 10; b++) {
        for (final c in pool.of(format, b)) {
          if (!c.skills.contains(skill) || c.pseudo || c.yesNo) continue;
          if (!anySeconds && c.seconds > left) continue;
          if (_free(c) && _available(c)) return true;
        }
      }
    }
    return false;
  }

  /// The answer to [c], the item `next` returned, has been taken into the
  /// model (a `dontKnow` on an isolating item is read as an ordinary wrong
  /// answer, with the item's guess: the evidence is understated, which is
  /// safe): the drill-down reads it. The caller must call this after every
  /// item it observes (a self-rated item gives nothing to read).
  void record(PickerCandidate c, AnswerOutcome outcome) {
    if (identical(_unrecorded, c)) _unrecorded = null;
    if (!config.drill.enabled || c.selfRated || c.pseudo || c.yesNo) return;
    final right = outcome == AnswerOutcome.right;
    if (_isolating.remove(c.id)) {
      if (c.skills.length == 1) {
        drillDown.onIsolating(
          c.skills.first,
          right: right,
          slip: c.slip,
          guess: c.guess,
        );
      }
      return;
    }
    final pre = _pre[c.id];
    if (pre == null) return;
    drillDown.onAnswer(
      itemSkills: c.skills.toList(),
      deck: c.deck,
      band: CandidatePool.bandOfDeck(pool.levels, c.deck),
      right: right,
      preKnown: pre.known,
      preAll: pre.all,
      seconds: seconds,
      testable: _tested,
    );
  }

  /// The learner cannot speak now: Say is no longer asked or rated (what it
  /// already holds stays), and the run goes on with the other skills.
  void giveUpMicrophone() {
    config = config.withDevice(mic: false, recogniser: false);
  }

  /// [c] could not be shown (its sound would not play): it gives no evidence
  /// and nothing for the drill-down to read; it still counts as asked, so
  /// its card is never asked again and the caps hold.
  void skip(PickerCandidate c) {
    if (identical(_unrecorded, c)) _unrecorded = null;
    if (_isolating.remove(c.id)) drillDown.abandon();
    _pre.remove(c.id);
  }

  /// A mixed item for the opening: two or more tested skills, at the middle
  /// of the posterior of its first skill, the most information per second,
  /// and not of a format already used for a mixed item.
  PickerCandidate? _chooseMixed() {
    final budget = config.maxSeconds - seconds;
    final used = <String>{
      for (final a in asked)
        if (a.skills.length >= 2) a.format,
    };
    PickerCandidate? best;
    var bestScore = double.negativeInfinity;
    for (final format in pool.formats) {
      if (used.contains(format)) continue;
      for (final skill in _tested) {
        final band = _quantileBand(skill, config.mixedQuantile);
        for (final cand in _near(
          format,
          band,
          3,
          skill: skill,
          budget: budget,
        )) {
          if (cand.skills.length < 2 ||
              !cand.skills.every(_tested.contains) ||
              cand.pseudo ||
              cand.yesNo) {
            continue;
          }
          final score = (_information(cand) + 0.2) / cand.seconds;
          if (score > bestScore) {
            bestScore = score;
            best = cand;
          }
        }
      }
    }
    return best;
  }

  /// The isolating item for [skill] at the level of the drill-down in
  /// progress: a single-skill item of the admitted formats, near that level,
  /// the most information per second.
  PickerCandidate? _chooseIsolating(PlacementSkill skill, DrillCase c) {
    final band = CandidatePool.bandOfDeck(pool.levels, c.deck);
    final budget = config.maxSeconds - seconds;
    for (final exhaustive in const <bool>[false, true]) {
      PickerCandidate? best;
      var bestScore = double.negativeInfinity;
      for (final format in pool.formats) {
        if (!exhaustive && _formatRun(format) >= 2) continue;
        final near = _near(
          format,
          band,
          10,
          skill: skill,
          budget: budget,
          exhaustive: exhaustive,
        );
        for (final cand in near) {
          if (cand.skills.length != 1 || !cand.skills.contains(skill)) continue;
          if (cand.pseudo || cand.yesNo || cand.seconds > budget) continue;
          // At the level of the item that was missed: the nearest deck.
          final far = (cand.deck - c.deck).abs();
          final score = (_information(cand) + 0.2) / cand.seconds - 0.01 * far;
          if (score > bestScore) {
            bestScore = score;
            best = cand;
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  PickerCandidate? _take(PickerCandidate c) {
    // The choosers only offer items that fit the time left; this is the
    // last guard.
    if (seconds + c.seconds > config.maxSeconds) return null;
    asked.add(c);
    _unrecorded = c;
    if (config.drill.enabled) {
      _pre[c.id] = (
        known: <PlacementSkill, double>{
          for (final k in c.skills)
            if (model.skills.contains(k))
              k: model.probabilityKnown(<PlacementSkill>[k], c.deck),
        },
        all: c.skills.every(model.skills.contains)
            ? model.probabilityKnown(c.skills, c.deck)
            : 1.0,
      );
    }
    _keys.addAll(c.conflictKeys);
    seconds += c.seconds;
    if (c.pseudo) _pseudoAsked++;
    if (c.yesNo && !c.pseudo) _yesNoWords++;
    return c;
  }

  // ------------------------------------------------------------------ bands

  int _bandOfClass(int c) => c <= 1 ? 0 : model.levels.tenthOf(c).ceil();

  int _quantileBand(PlacementSkill skill, double p) {
    final m = model.marginal(skill);
    var run = 0.0;
    var c = 0;
    while (c < m.length - 1 && run + m[c] < p) {
      run += m[c];
      c++;
    }
    return _bandOfClass(c);
  }

  int _quantileClass(PlacementSkill skill, double p) {
    final m = model.marginal(skill);
    var run = 0.0;
    var c = 0;
    while (c < m.length - 1 && run + m[c] < p) {
      run += m[c];
      c++;
    }
    return c;
  }

  /// The highest band [skill] has a right clean answer in, and the lowest
  /// band it has a wrong one in (or null).
  ({int? right, int? wrong}) _answers(PlacementSkill skill) {
    int? right;
    int? wrong;
    for (var b = 0; b <= 10; b++) {
      final r = model.bandRecord(skill, b);
      if (r.clean == 0) continue;
      if (r.right > 0) right = b;
      if (r.clean - r.right > 0 && wrong == null) wrong = b;
    }
    return (right: right, wrong: wrong);
  }

  bool _isDone(PlacementSkill skill) {
    final st = _of(skill);
    if (st.finished || model.touchesOf(skill) >= config.skillCap) return true;
    // Nothing to prove: four clean items are in and the posterior sits at
    // the start of the path.
    if (_atStart(skill)) {
      st.finished = true;
      return true;
    }
    final band = st.proving;
    if (band == null) return false;
    final proven = model.provenClass(skill);
    if (proven == null || proven < model.classOfBand(band)) return false;
    // Proven, but the joint prior (a learner is often at one level in every
    // skill) still holds the skill down to the start: more clean items of
    // the proven band show that the skill really stands apart from the
    // others (an ear-only learner).
    if (band >= 3 &&
        _quantileClass(skill, 0.1) + 6 <= proven &&
        model.bandRecord(skill, band).clean < config.standApartItems) {
      return false;
    }
    // Proven: climb while the proven band holds the start down, that is,
    // while the lower edge of the posterior is above the ceiling.
    // The same when the middle of the posterior is two tenths above the
    // ceiling (the lower edge is held down by the joint prior).
    if (band < 10 &&
        (_quantileClass(skill, config.climbQuantile) >
                proven + (config.climbTolerance * _tenth).round() ||
            _quantileClass(skill, 0.5) > proven + 2 * _tenth)) {
      st.proving = math.max(band + 1, _quantileBand(skill, 0.5));
      return false;
    }
    return true;
  }

  /// The classes in a tenth of the path.
  int get _tenth => math.max(1, model.levels.parts ~/ 10);

  /// Whether the learner is at the start of the path for [skill]: at least
  /// four clean items are in and nine tenths of the posterior lie on the
  /// first class.
  bool _atStart(PlacementSkill skill) {
    if (model.cleanItemsOf(skill) < kMinCleanItems) return false;
    final m = model.marginal(skill);
    return m.length > 1 && m[0] + m[1] >= 0.9;
  }

  /// The band the next item of [skill] is asked in.
  int _band(PlacementSkill skill) {
    final st = _of(skill);
    if (st.proving == null) {
      final located = model.touchesOf(skill);
      if (located < config.locateItems) {
        // Bisection over the tenths: between the highest band answered right
        // and the one below the lowest answered wrong.
        final a = _answers(skill);
        if (a.right == null && a.wrong == null) {
          return _quantileBand(skill, 0.35);
        }
        final lo = a.right ?? 0;
        final hi = a.wrong == null ? 10 : math.max(lo, a.wrong! - 1);
        // Up fast from a right answer, halving from a wrong one.
        final step = a.wrong == null ? ((10 - lo) * 0.35).ceil() : null;
        return (step == null ? (lo + hi + 1) ~/ 2 : lo + step).clamp(0, 9);
      }
      final a = _answers(skill);
      final lo = a.right ?? 0;
      final hi = a.wrong == null ? 10 : math.max(0, a.wrong! - 1);
      // One lucky right answer high up does not set the band to prove: it is
      // never above what the posterior's 60th percentile supports.
      st.proving = lo > 0
          ? math.min(
              math.max(lo, math.min(hi, _quantileBand(skill, 0.35))),
              math.max(_quantileBand(skill, 0.6), math.min(lo, 3)),
            )
          : math.min(hi, _quantileBand(skill, 0.25));
    }
    // Skills one band apart prove the same band, so that a mixed item (an
    // item of two skills) is a clean item of both.
    for (final other in _tested) {
      if (other == skill) continue;
      final ob = _state[other]?.proving;
      if (ob == null || _isDoneQuiet(other)) continue;
      if ((ob - st.proving!).abs() == 1) {
        st.proving = math.max(ob, st.proving!);
        _of(other).proving = st.proving;
      }
    }
    var band = st.proving!;
    // A band where two answers are wrong cannot be proven: the one below is.
    while (band > 0) {
      final r = model.bandRecord(skill, band);
      final failed = r.clean - r.right;
      // Two wrong answers, or one wrong answer while the posterior already
      // sits lower: the band is left for the lower quarter of the posterior
      // (never more than one band up from a step down).
      if (failed >= 2 || (failed >= 1 && _quantileBand(skill, 0.5) < band)) {
        band = math.max(0, math.min(band - 1, _quantileBand(skill, 0.4)));
      } else {
        break;
      }
    }
    if (band == 0) {
      final r = model.bandRecord(skill, 0);
      if (r.clean >= kMinCleanItems && r.clean - r.right >= 2) {
        st.finished = true;
      }
    }
    st.proving = band;
    return band;
  }

  // ------------------------------------------------------------------ items

  bool _free(PickerCandidate c) =>
      c.conflictKeys.every((k) => !_keys.contains(k));

  int _formatRun(String format) {
    var n = 0;
    for (var i = asked.length - 1; i >= 0 && asked[i].format == format; i--) {
      n++;
    }
    return n;
  }

  bool _available(PickerCandidate c) {
    if (kUnaskableFormats.contains(c.format)) return false;
    // An item of a skill that is not in play (Read and Write when the script
    // gate found the script unreadable) is never asked.
    if (!c.skills.every(
      (k) => k == PlacementSkill.say || model.skills.contains(k),
    )) {
      return false;
    }
    if (c.needsAudio && !config.audio) return false;
    if (c.needsMic && !config.mic) return false;
    if (!c.clean || c.guess > kCleanGuessMax || c.guess >= kUnusableGuess) {
      return false;
    }
    return true;
  }

  /// Up to [n] free candidates of [format] near [band], the closest band
  /// first.
  List<PickerCandidate> _near(
    String format,
    int band,
    int n, {
    PlacementSkill? skill,
    double? budget,
    bool exhaustive = false,
  }) {
    final out = <PickerCandidate>[];
    bool ok(PickerCandidate c) =>
        (skill == null || c.skills.contains(skill)) &&
        (budget == null || c.seconds <= budget) &&
        _free(c) &&
        _available(c) &&
        !out.contains(c);
    final widest = exhaustive ? 10 : 3;
    for (var spread = 0; spread <= widest && out.length < n; spread++) {
      for (final b in <int>{band - spread, band + spread}) {
        if (b < 0 || b > 10) continue;
        final list = pool.of(format, b);
        if (list.isEmpty) continue;
        if (exhaustive) {
          // The whole band, from a random start: nothing free is missed.
          final start = rng.nextInt(list.length);
          for (var i = 0; i < list.length && out.length < n; i++) {
            final c = list[(start + i) % list.length];
            if (ok(c)) out.add(c);
          }
        } else {
          for (var tries = 0; tries < 24 && out.length < n; tries++) {
            final c = list[rng.nextInt(list.length)];
            if (ok(c)) out.add(c);
          }
        }
      }
    }
    return out;
  }

  static double _entropy(double p) {
    if (p <= 0 || p >= 1) return 0;
    return -(p * math.log(p) + (1 - p) * math.log(1 - p)) / math.ln2;
  }

  /// The information an answer to [c] gives about whether the learner knows
  /// it (mutual information, in bits).
  double _information(PickerCandidate c) {
    final q = model.probabilityKnown(c.skills, c.deck);
    final right = q * (1 - c.slip) + (1 - q) * c.guess;
    return _entropy(right) -
        q * _entropy(1 - c.slip) -
        (1 - q) * _entropy(c.guess);
  }

  /// [relaxed]: 0 the rules as they are; 1 the "another skill probably
  /// fails" rule lifted and the bank searched in full; 2 the format-run rule
  /// lifted too.
  PickerCandidate? _choose(PlacementSkill skill, {int relaxed = 0}) {
    final band = _band(skill);
    if (_isDone(skill)) return null;
    final budget = config.maxSeconds - seconds;
    PickerCandidate? best;
    var bestScore = double.negativeInfinity;
    for (final format in pool.formats) {
      if (relaxed < 2 && _formatRun(format) >= 2) continue;
      final near = _near(
        format,
        band,
        3,
        skill: relaxed > 0 ? skill : null,
        budget: budget,
        exhaustive: relaxed > 0,
      );
      for (final c in near) {
        if (!c.skills.contains(skill)) continue;
        if (c.pseudo || c.yesNo) continue;
        if (c.seconds > budget) continue;
        // The coverage and the proof of the other skills it needs are worth
        // something too: a mixed item is one item for two skills.
        var bonus = 0.0;
        var skip = false;
        for (final t in c.skills) {
          if (t == skill || !model.skills.contains(t)) continue;
          // An item another skill of the learner probably fails says little
          // about this one.
          if (relaxed == 0 &&
              model.probabilityKnown(<PlacementSkill>[t], c.deck) < 0.4) {
            skip = true;
            break;
          }
        }
        if (skip) continue;
        for (final t in c.skills) {
          if (t == skill || !_tested.contains(t)) continue;
          final p = _state[t]?.proving;
          if (p != null && !_isDoneQuiet(t) && PickerBandOf.of(pool, c) == p) {
            bonus += config.mixedBonus;
          } else if (p == null &&
              model.touchesOf(t) < config.locateItems &&
              _near_(c, band)) {
            // An item that also locates the other skill.
            bonus += config.mixedBonus;
          }
        }
        final score = (_information(c) + 0.2 + bonus) / c.seconds;
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
    }
    return best;
  }

  /// Whether [c] lies within one band of [band].
  bool _near_(PickerCandidate c, int band) =>
      (PickerBandOf.of(pool, c) - band).abs() <= 1;

  bool _isDoneQuiet(PlacementSkill skill) {
    final st = _state[skill];
    if (st == null) return false;
    if (st.finished) return true;
    final band = st.proving;
    if (band == null) return false;
    final proven = model.provenClass(skill);
    return proven != null && proven >= model.classOfBand(band);
  }

  PickerCandidate? _selfRatedSay() {
    for (final format in pool.formats) {
      for (final c in _near(format, 5, 6)) {
        if (c.skills.length == 1 && c.skills.contains(PlacementSkill.say)) {
          return c.asSelfRated();
        }
      }
    }
    return null;
  }

  PickerCandidate? _yesNoNext() {
    if (_pseudoAsked < kMinPseudowords && _pseudoAsked < pool.pseudo.length) {
      return pool.pseudo[_pseudoAsked];
    }
    if (_yesNoWords < 6) {
      final band = _band(PlacementSkill.read);
      for (final format in const <String>['F1']) {
        for (final c in _near(format, band, 6)) {
          if (c.yesNo) return c;
        }
      }
    }
    return null;
  }
}

/// The band of a candidate in a pool.
class PickerBandOf {
  static int of(CandidatePool pool, PickerCandidate c) =>
      CandidatePool.bandOfDeck(pool.levels, c.deck);
}
