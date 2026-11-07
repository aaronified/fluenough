// The replay harness of Find my level V3 (wiki/Plan-Placement-V3.md, the
// amendments and the revised gates): simulated learners and rogue guessers
// play whole runs against the joint model of lib/core/placement/joint_model.dart,
// asked by a picker, over a deterministic simulated item bank.
//
// The bank, the item formats and the guess rates here are STAND-INS for the
// item registry of build step 3. The real picker of step 4 ([V3Picker]) is
// plugged in by [V3SimPicker] over the admitted formats; [BaselinePicker]
// stays as the control of the mutation tests (a leaky picker the gates must
// catch). Gates that need later steps are listed in
// test/placement_v3_pending_gates_test.dart.
//
// Pure Dart (no Flutter), deterministic: a run is a function of its seed.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_picker.dart';

const String kLeakProfilePath =
    'test/fixtures/placement/adversary/leak_profile.json';

/// Whether the bank is the one the adversary attacked ("legacy") or what the
/// amended generators must produce ("fixed").
enum BankProfile { legacy, fixed }

/// What the device can do.
class Variant {
  const Variant({
    this.audio = true,
    this.mic = true,
    this.recogniser = false,
    this.label = '',
  });

  /// Text to speech works: Hear can be tested.
  final bool audio;

  /// A microphone exists: Say can be self-rated.
  final bool mic;

  /// A speech recogniser scores Say (otherwise Say is self-rated at best).
  final bool recogniser;

  final String label;

  static const Variant full = Variant(label: 'audio+mic');
  static const Variant noAudio = Variant(
    audio: false,
    mic: false,
    label: 'no-audio',
  );
  static const Variant noMic = Variant(mic: false, label: 'no-mic');
  static const Variant withRecogniser = Variant(
    recogniser: true,
    label: 'recogniser',
  );

  /// The skills the joint holds. Say is in the joint only when a recogniser
  /// scores it, or when [sayInJoint] asks for it (to test the self-rating
  /// rules).
  List<PlacementSkill> skills({bool sayInJoint = false}) => <PlacementSkill>[
    PlacementSkill.read,
    if (audio) PlacementSkill.hear,
    PlacementSkill.write,
    if (audio && mic && (recogniser || sayInJoint)) PlacementSkill.say,
  ];
}

/// One item format: which skills it needs and its slip, guess and time.
class FormatSpec {
  const FormatSpec(
    this.code,
    this.skills,
    this.slip,
    this.guess,
    this.seconds, {
    this.wordLevel = true,
  });

  final String code;
  final Set<PlacementSkill> skills;
  final double slip;
  final double guess;
  final double seconds;

  /// A word-level format: near-cognates are excluded from it.
  final bool wordLevel;
}

const _r = PlacementSkill.read;
const _h = PlacementSkill.hear;
const _w = PlacementSkill.write;
const _s = PlacementSkill.say;

/// The formats of the plan's inventory that the stand-in bank carries.
const Map<String, FormatSpec> kFormats = <String, FormatSpec>{
  'F2': FormatSpec('F2', {_r}, 0.05, 0.25, 6),
  'F3': FormatSpec('F3', {_r}, 0.05, 0.25, 6),
  'F4': FormatSpec('F4', {_w}, 0.05, 0.10, 15),
  'F5': FormatSpec('F5', {_r}, 0.10, 0.25, 8, wordLevel: false),
  'F6': FormatSpec('F6', {_r}, 0.10, 0.25, 8, wordLevel: false),
  'F7': FormatSpec('F7', {_w}, 0.15, 0.03, 12),
  'F8': FormatSpec('F8', {_w, _r}, 0.10, 0.05, 15, wordLevel: false),
  'F13': FormatSpec('F13', {_h}, 0.05, 0.25, 6),
  'F15': FormatSpec('F15', {_h}, 0.05, 0.50, 6),
  'F16': FormatSpec('F16', {_h, _w}, 0.10, 0.05, 15, wordLevel: false),
  'F17': FormatSpec('F17', {_h}, 0.10, 0.25, 8, wordLevel: false),
  'F18': FormatSpec('F18', {_s}, 0.15, 0.03, 10),
  'F1': FormatSpec('F1', {_r}, 0.10, 0.0, 3),
};

/// The format a bank profile uses for [code]: the legacy bank's word tiles,
/// sentence picks and clozes were the leaky versions.
String formatKey(String code, BankProfile profile) {
  if (profile == BankProfile.fixed) {
    return code == 'F4' ? 'F4decoys' : code;
  }
  return switch (code) {
    'F4' => 'F4',
    'F5' => 'F5legacy',
    'F6' => 'F6hint',
    _ => code,
  };
}

/// A card of the simulated path.
class SimCard {
  const SimCard(this.id, this.deck, this.cognate);
  final String id;
  final int deck;
  final bool cognate;
}

/// One askable item: a card in a format (or a yes/no pseudoword).
class SimItem {
  const SimItem(
    this.card,
    this.spec, {
    this.pseudo = false,
    this.yesNo = false,
    this.selfRated = false,
  });

  final SimCard card;
  final FormatSpec spec;
  final bool pseudo;
  final bool yesNo;
  final bool selfRated;

  String get id => '${card.id}:${spec.code}';
}

/// A deterministic simulated course: [deckCount] decks of [perDeck] cards,
/// a share of them near-cognates.
class SimBank {
  SimBank(this.language, this.deckCount, double cognateShare, {int perDeck = 8})
    : levels = PlacementLevels(deckCount, maxParts: 20) {
    final rng = math.Random(deckCount * 7919 + 13);
    for (var d = 0; d < deckCount; d++) {
      for (var i = 0; i < perDeck; i++) {
        cards.add(
          SimCard('$language$d.$i', d, rng.nextDouble() < cognateShare),
        );
      }
    }
  }

  final String language;
  final int deckCount;
  final PlacementLevels levels;
  final List<SimCard> cards = <SimCard>[];

  /// The cards whose deck lies in [from]..[to].
  Iterable<SimCard> between(int from, int to) =>
      cards.where((c) => c.deck >= from && c.deck <= to);
}

/// The data of one language of the leak profile fixture.
class LeakLanguage {
  LeakLanguage(
    this.code,
    Map<String, Object?> json, {
    this.audit = const <String, double>{},
  }) : deckCount = json['deckCount']! as int,
       cognateShare = (json['cognateShare']! as num).toDouble(),
       knownDeck = json['knownDeck']! as int,
       yesToUnknownReal = (json['yesToUnknownReal']! as num).toDouble(),
       yesToPseudo = (json['yesToPseudo']! as num).toDouble(),
       _tables = <BankProfile, Map<String, Object?>>{
         BankProfile.legacy: json['legacy']! as Map<String, Object?>,
         BankProfile.fixed: json['fixed']! as Map<String, Object?>,
       };

  final String code;
  final int deckCount;
  final double cognateShare;
  final int knownDeck;
  final double yesToUnknownReal;
  final double yesToPseudo;
  final Map<BankProfile, Map<String, Object?>> _tables;

  /// What the admission audit of the real item bank measured for a clean
  /// item of each format (test/fixtures/placement/adversary/audit_profile.json
  /// from tool/placement_audit.dart): the best solver's expected accuracy.
  /// It replaces the "fixed" table's assumed rate for those formats.
  final Map<String, double> audit;

  SimBank bank() => SimBank(code, deckCount, cognateShare);

  /// The gamer's accuracy beyond its words on format [code].
  double rate(String code, bool cognate, BankProfile profile, bool strong) {
    final measured = audit[code];
    if (profile == BankProfile.fixed && !cognate && measured != null) {
      // A gamer is never worse than guessing: the design guess is the floor.
      final floor = kFormats[code]?.guess ?? 0;
      final value = math.max(measured, floor);
      if (code != 'F4' || strong) return value;
    }
    var entry = _tables[profile]![code]! as Map<String, Object?>;
    if (entry.containsKey('weak')) {
      entry = entry[strong ? 'strong' : 'weak']! as Map<String, Object?>;
    }
    return (entry[cognate ? 'cognate' : 'clean']! as num).toDouble();
  }
}

const String kAuditProfilePath =
    'test/fixtures/placement/adversary/audit_profile.json';

/// The audit's clean-item accuracy per format and language.
Map<String, Map<String, double>> _auditRates() {
  final file = File(kAuditProfilePath);
  if (!file.existsSync()) return const <String, Map<String, double>>{};
  final json = jsonDecode(file.readAsStringSync())! as Map<String, Object?>;
  final langs = json['languages']! as Map<String, Object?>;
  final out = <String, Map<String, double>>{};
  for (final e in langs.entries) {
    final classes =
        (e.value! as Map<String, Object?>)['classes']! as Map<String, Object?>;
    final rates = <String, double>{};
    for (final c in classes.entries) {
      if (!c.key.endsWith(':clean')) continue;
      final entry = c.value! as Map<String, Object?>;
      if (entry['passes'] != true) continue;
      rates[c.key.substring(0, c.key.length - ':clean'.length)] =
          (entry['accuracy']! as num).toDouble();
    }
    out[e.key] = rates;
  }
  return out;
}

Map<String, LeakLanguage>? _leakCache;

/// The fixture's languages, `es` and `hi`.
Map<String, LeakLanguage> leakLanguages() {
  return _leakCache ??= () {
    final json =
        jsonDecode(File(kLeakProfilePath).readAsStringSync())!
            as Map<String, Object?>;
    final langs = json['languages']! as Map<String, Object?>;
    final audit = _auditRates();
    return <String, LeakLanguage>{
      for (final e in langs.entries)
        e.key: LeakLanguage(
          e.key,
          e.value! as Map<String, Object?>,
          audit: audit[e.key] ?? const <String, double>{},
        ),
    };
  }();
}

/// The class a learner who knows every deck up to [deck] sits in: the
/// highest class whose level is at most [deck] (0, `none`, for a negative).
int classKnowingUpTo(PlacementLevels levels, int deck) {
  var best = 0;
  for (var c = 1; c < levels.classCount; c++) {
    if (levels.levelOf(c) <= deck) best = c;
  }
  return best;
}

/// The class at a position of [tenth] tenths of the path (0 to 10).
int classAtTenth(PlacementLevels levels, double tenth) {
  if (tenth <= 0) return 1;
  var best = 1;
  for (var c = 1; c < levels.classCount; c++) {
    if (levels.tenthOf(c) <= tenth + 1e-9) best = c;
  }
  return best;
}

/// A simulated learner: what it truly knows, and how it answers.
class Persona {
  Persona(
    this.name, {
    required this.truth,
    this.language,
    this.strongSolver = false,
    this.leak = false,
    this.cognateLeak = true,
    this.cognateRight = false,
    this.cognateOnly = false,
    this.random = false,
    this.cheater = false,
    this.leakBump = 0,
    this.yesRate,
    this.selfRatesSame = false,
    this.honestSelfRating = false,
    this.falseAlarm = 0.08,
    this.profile = BankProfile.fixed,
  });

  final String name;

  /// The true class of each skill (0 is `none`); a skill left out is `none`.
  final Map<PlacementSkill, int> truth;

  /// The leak table, for a rule-using gamer.
  final LeakLanguage? language;
  final bool strongSolver;

  /// Whether items beyond the learner's knowledge are answered by the leak
  /// table of [language] (a gamer) rather than by guessing.
  final bool leak;

  /// Whether the gamer's leak table applies to near-cognates too (a
  /// test-wise-only learner has no cognate cue).
  final bool cognateLeak;

  /// A cognate-advantaged learner: near-cognates are answered right.
  final bool cognateRight;

  /// A learner that knows nothing and answers only cognates by the leak.
  final bool cognateOnly;

  /// Added to every leak rate (beyond-knowledge accuracy), to test how much
  /// more a gamer could do than the adversary measured.
  final double leakBump;

  /// A control for the gates themselves: answers every question right, so a
  /// gate that cannot see it is blind.
  final bool cheater;

  /// A learner that answers at random.
  final bool random;

  /// A yes-sayer's rate of saying yes to anything in a yes/no item.
  final double? yesRate;

  /// A self-rater: Say is always rated "same".
  final bool selfRatesSame;

  /// An honest self-rater rates Say right when it knows, and mostly right
  /// when it does not (self-rating is generous).
  final bool honestSelfRating;

  /// An honest learner's rate of saying yes to a word it does not know.
  final double falseAlarm;

  final BankProfile profile;

  int truthOf(PlacementSkill skill) => truth[skill] ?? 0;

  bool knows(PlacementLevels levels, SimItem item) {
    for (final skill in item.spec.skills) {
      if (!levels.knows(truthOf(skill), item.card.deck)) return false;
    }
    return true;
  }

  /// The learner's answer to [item].
  AnswerOutcome answer(PlacementLevels levels, SimItem item, math.Random rng) {
    AnswerOutcome yes(bool b) => b ? AnswerOutcome.right : AnswerOutcome.wrong;
    if (cheater) return AnswerOutcome.right;
    final known = knows(levels, item);
    if (item.pseudo) {
      final p =
          yesRate ??
          (random
              ? 0.5
              : leak
              ? language!.yesToPseudo
              : falseAlarm);
      return yes(rng.nextDouble() < p);
    }
    if (item.yesNo) {
      if (yesRate != null) return yes(rng.nextDouble() < yesRate!);
      if (known) return yes(rng.nextDouble() < 1 - item.spec.slip);
      final p = random
          ? 0.5
          : leak
          ? language!.yesToUnknownReal
          : falseAlarm;
      return yes(rng.nextDouble() < p);
    }
    if (item.selfRated) {
      if (selfRatesSame) return AnswerOutcome.right;
      if (random) return yes(rng.nextBool());
      if (honestSelfRating && known) return yes(rng.nextDouble() < 0.9);
      return yes(rng.nextDouble() < 0.3);
    }
    if (known) return yes(rng.nextDouble() >= item.spec.slip);
    if (cognateRight && item.card.cognate) return yes(rng.nextDouble() < 0.97);
    if (random) return yes(rng.nextDouble() < item.spec.guess);
    if (leak) {
      final key = item.spec.code;
      if (item.card.cognate && !cognateLeak) {
        return yes(rng.nextDouble() < item.spec.guess);
      }
      return yes(
        rng.nextDouble() <
            math.min(
              1.0,
              language!.rate(key, item.card.cognate, profile, strongSolver) +
                  leakBump,
            ),
      );
    }
    if (cognateOnly) {
      // Knows no words; only the cognates give anything away.
      if (item.card.cognate) {
        return yes(
          rng.nextDouble() <
              math.min(
                1.0,
                language!.rate(item.spec.code, true, profile, strongSolver) +
                    leakBump,
              ),
        );
      }
    }
    return yes(rng.nextDouble() < item.spec.guess);
  }
}

/// A deliberate weakening of the model, to prove the gates can fail: a gate
/// that still passes with the protection removed is blind.
class Mutation {
  const Mutation({
    this.calibration = GuessCalibration.seed,
    this.fixedGuess,
    this.noCeiling = false,
    this.label = 'as built',
  });

  /// The guess calibration the model is given.
  final GuessCalibration calibration;

  /// Every item is given this guess rate instead of the calibrated one.
  final double? fixedGuess;

  /// The start is the posterior's lower edge, with no proven-level ceiling.
  final bool noCeiling;

  final String label;
}

/// Everything a picker may look at.
class RunState {
  RunState({
    required this.model,
    required this.bank,
    required this.variant,
    required this.rng,
    required this.calibration,
    required this.profile,
    this.fixedGuess,
  });

  final JointPlacement model;
  final SimBank bank;
  final Variant variant;
  final math.Random rng;
  final GuessCalibration calibration;
  final BankProfile profile;
  final double? fixedGuess;

  final List<SimItem> asked = <SimItem>[];
  final Set<String> askedCards = <String>{};
  double seconds = 0;
  int pseudoAsked = 0;
  int selfRatedAsked = 0;

  int get items => asked.length;

  int formatRun(String code) {
    var n = 0;
    for (var i = asked.length - 1; i >= 0 && asked[i].spec.code == code; i--) {
      n++;
    }
    return n;
  }
}

/// A picker: the next item of a run, or null to stop. Any implementation can
/// be run by [runOnce]; the real one of build step 4 is plugged in here.
abstract class SimPicker {
  String get name;
  SimItem? next(RunState state);
}

/// The calibrated guess of an item in a bank profile.
double calibratedGuess(RunState s, SimItem item) =>
    s.fixedGuess ??
    s.calibration.guessFor(
      formatKey(item.spec.code, s.profile),
      item.card.cognate,
      item.spec.guess,
    );

/// A stand-in for the item registry: the model's view of [item].
JointItem toJointItem(RunState s, SimItem item) {
  final guess = calibratedGuess(s, item);
  final cognate = item.card.cognate;
  if (item.pseudo) {
    return JointItem.pseudoword(skills: item.spec.skills, cardId: item.id);
  }
  return JointItem(
    skills: item.spec.skills,
    deck: item.card.deck,
    slip: item.spec.slip,
    guess: item.yesNo ? 0 : guess,
    // A sentence item with a cognate counts half.
    weight: !item.spec.wordLevel && cognate ? 0.5 : 1,
    clean: !cognate && guess <= kCleanGuessMax,
    selfRated: item.selfRated,
    yesNo: item.yesNo ? YesNoRole.realWord : YesNoRole.notYesNo,
    cardId: item.id.replaceAll(':${item.spec.code}', ''),
  );
}

/// What one run came to, per skill.
class SkillResult {
  const SkillResult({
    required this.skill,
    required this.truth,
    required this.start,
    required this.low,
    required this.high,
    required this.median,
    required this.clean,
    required this.state,
    required this.rangeShown,
  });

  final PlacementSkill skill;
  final int truth;
  final int start;
  final int low;
  final int high;
  final int median;
  final int clean;
  final EvidenceState state;
  final bool rangeShown;

  /// How many classes the start is above the truth.
  int get over => start - truth;

  /// How many classes the lower edge of the range (the p10) is above the
  /// truth.
  int get lowOver => low - truth;
}

class RunResult {
  const RunResult({
    required this.skills,
    required this.items,
    required this.seconds,
    required this.repeatedCard,
    required this.tenth,
  });

  final Map<PlacementSkill, SkillResult> skills;
  final int items;
  final double seconds;

  /// Whether a card was asked twice (it must never be).
  final bool repeatedCard;

  /// The classes in one tenth of the path.
  final int tenth;
}

/// One simulated placement of [persona].
RunResult runOnce({
  required SimBank bank,
  required Persona persona,
  required SimPicker picker,
  required PlacementDeclaration? declaration,
  required Variant variant,
  required int seed,
  Mutation mutation = const Mutation(),
  bool sayInJoint = false,
}) {
  final rng = math.Random(seed * 100003 + 17);
  final model = JointPlacement(
    levels: bank.levels,
    skills: variant.skills(sayInJoint: sayInJoint),
    declaration: declaration,
  );
  final state = RunState(
    model: model,
    bank: bank,
    variant: variant,
    rng: rng,
    calibration: mutation.calibration,
    profile: persona.profile,
    fixedGuess: mutation.fixedGuess,
  );
  var repeated = false;
  while (true) {
    final item = picker.next(state);
    if (item == null) break;
    final cardKey = item.card.id;
    if (!item.pseudo && state.askedCards.contains(cardKey)) repeated = true;
    final outcome = persona.answer(bank.levels, item, rng);
    // A self-rated Say outside the joint is only recorded: it is never
    // evidence.
    if (!(item.selfRated && !model.skills.contains(PlacementSkill.say))) {
      model.observe(toJointItem(state, item), outcome);
    }
    state.asked.add(item);
    if (!item.pseudo) state.askedCards.add(cardKey);
    if (item.pseudo) state.pseudoAsked++;
    if (item.selfRated) state.selfRatedAsked++;
    state.seconds += item.spec.seconds;
    if (state.items > 80) break;
  }
  final readout = model.readout();
  final results = <PlacementSkill, SkillResult>{};
  for (final e in readout.skills.entries) {
    final r = e.value;
    results[e.key] = SkillResult(
      skill: e.key,
      truth: persona.truthOf(e.key),
      start: mutation.noCeiling ? r.lowClass : r.startClass,
      low: r.lowClass,
      high: r.highClass,
      median: r.medianClass,
      clean: r.cleanItems,
      state: r.state,
      rangeShown: r.rangeShown,
    );
  }
  return RunResult(
    skills: results,
    items: state.items,
    seconds: state.seconds,
    repeatedCard: repeated,
    tenth: math.max(1, bank.levels.parts ~/ 10),
  );
}

/// The stand-in picker. It rotates the skills, first locates a skill with two
/// items at the posterior median, then tries to PROVE the band at the
/// posterior's lower quartile: it asks items of that one band until four
/// clean ones are in (proven by 4 of 4 or 5 of 6) or two are wrong (then the
/// band below is tried). Formats rotate, near-cognates stay out of
/// word-level formats, a card is never asked twice, and it stops at the
/// plan's caps (40 items, 300 s, 14 touches a skill).
class BaselinePicker implements SimPicker {
  BaselinePicker({
    this.yesNoBlock = false,
    this.sayItems = 2,
    this.naive = false,
  });

  /// A control: asks every format, leaky or not, and lets near-cognates into
  /// word-level formats, as V3 did before the adversarial review.
  final bool naive;

  /// Whether Read opens with a yes/no block (8 pseudowords and 6 words).
  final bool yesNoBlock;

  /// How many self-rated Say items are asked when no recogniser scores Say.
  final int sayItems;

  @override
  String get name => 'baseline';

  static const int kMaxItems = 40;
  static const double kMaxSeconds = 300;
  static const int kSkillCap = 14;
  static const int kLocateItems = 1;

  /// The quantile of the posterior whose band is tried first.
  static const double kProveQuantile = 0.5;

  // Mixed formats first: one item then counts for two skills.
  static const Map<PlacementSkill, List<String>> _formats =
      <PlacementSkill, List<String>>{
        PlacementSkill.read: <String>['F2', 'F8', 'F5', 'F3', 'F6'],
        PlacementSkill.hear: <String>['F13', 'F16', 'F17', 'F15'],
        PlacementSkill.write: <String>['F8', 'F16', 'F7', 'F4'],
        PlacementSkill.say: <String>['F18'],
      };

  final Set<PlacementSkill> _finished = <PlacementSkill>{};

  @override
  SimItem? next(RunState s) {
    if (s.items >= kMaxItems || s.seconds >= kMaxSeconds) return null;
    final m = s.model;
    if (yesNoBlock && s.pseudoAsked < kMinPseudowords) {
      return SimItem(
        SimCard('pw${s.pseudoAsked}', 0, false),
        kFormats['F1']!,
        pseudo: true,
        yesNo: true,
      );
    }
    if (yesNoBlock && s.asked.where((i) => i.yesNo && !i.pseudo).length < 6) {
      final card = _pickCard(s, _band(s, PlacementSkill.read), true);
      if (card != null) return SimItem(card, kFormats['F1']!, yesNo: true);
    }
    var candidates = _open(s);
    if (candidates.isEmpty && _climb(s)) candidates = _open(s);
    candidates.sort((a, b) {
      final c = m.touchesOf(a).compareTo(m.touchesOf(b));
      return c != 0 ? c : a.index.compareTo(b.index);
    });
    for (final skill in candidates) {
      final item = _itemFor(s, skill);
      if (item != null) return item;
      _finished.add(skill);
    }
    // Say without a recogniser is rated by the learner: a few items, never
    // evidence and never extending the run.
    if (s.variant.audio &&
        s.variant.mic &&
        !s.variant.recogniser &&
        s.selfRatedAsked < sayItems) {
      return _sayItem(s, selfRated: true);
    }
    return null;
  }

  List<PlacementSkill> _open(RunState s) => <PlacementSkill>[
    for (final skill in s.model.skills)
      if (!(skill == PlacementSkill.say && !s.variant.recogniser) &&
          !_isDone(s, skill))
        skill,
  ];

  /// Whether the proven band holds the start down: the lower edge of a
  /// skill's posterior lies above it. Then the next band is tried, chosen as
  /// at the start.
  bool _climb(RunState s) {
    final band = _provingBand;
    final m = s.model;
    if (band == null || band >= 10) return false;
    final words = <PlacementSkill>[
      for (final k in m.skills)
        if (k != PlacementSkill.say && !_finished.contains(k)) k,
    ];
    if (words.isEmpty) return false;
    final ceiling = m.classOfBand(band);
    var held = false;
    for (final k in words) {
      if (m.touchesOf(k) >= kSkillCap) return false;
      if (_quantile(s, k, 0.1) > ceiling) held = true;
    }
    if (!held) return false;
    final next = words
        .map((k) => _bandOfClass(s, _quantile(s, k, kProveQuantile)))
        .reduce(math.max);
    _provingBand = math.max(band + 1, next);
    return true;
  }

  bool _isDone(RunState s, PlacementSkill skill) {
    final m = s.model;
    if (_finished.contains(skill) || m.touchesOf(skill) >= kSkillCap) {
      return true;
    }
    final band = _provingBand;
    if (band == null) return false;
    final proven = m.provenClass(skill);
    return proven != null && proven >= m.classOfBand(band);
  }

  /// The class at probability [p] of the skill's posterior.
  int _quantile(RunState s, PlacementSkill skill, double p) {
    final marginal = s.model.marginal(skill);
    var run = 0.0;
    var c = 0;
    while (c < marginal.length - 1 && run + marginal[c] < p) {
      run += marginal[c];
      c++;
    }
    return c;
  }

  int _bandOfClass(RunState s, int c) =>
      c <= 1 ? 0 : s.bank.levels.tenthOf(c).ceil();

  // The band every skill tries to prove: shared, so that a mixed item is a
  // clean item of both its skills.
  int? _provingBand;

  /// The band the next item of [skill] is asked in.
  int _band(RunState s, PlacementSkill skill) {
    final m = s.model;
    final words = <PlacementSkill>[
      for (final k in m.skills)
        if (k != PlacementSkill.say) k,
    ];
    if (m.touchesOf(skill) < kLocateItems && _provingBand == null) {
      // Locate: the middle of the first skill's posterior, for all skills.
      return _bandOfClass(s, _quantile(s, words.first, 0.5));
    }
    var band =
        _provingBand ??
        words
            .map((k) => _bandOfClass(s, _quantile(s, k, kProveQuantile)))
            .reduce(math.min);
    // A band where a skill has two wrong answers cannot be proven by it:
    // the next band down is tried, by all.
    while (band > 0) {
      var failed = false;
      for (final k in words) {
        final rec = m.bandRecord(k, band);
        if (rec.clean - rec.right >= 2) failed = true;
      }
      if (!failed) break;
      band--;
    }
    if (band == 0) {
      // Nothing of the first band is known: there is nothing to prove.
      for (final k in words) {
        final rec = m.bandRecord(k, 0);
        if (rec.clean >= kMinCleanItems && rec.clean - rec.right >= 2) {
          _finished.add(k);
        }
      }
    }
    _provingBand = band;
    return band;
  }

  SimCard? _pickCard(RunState s, int band, bool wordLevel) {
    final levels = s.bank.levels;
    final model = s.model;
    int deckOfTenth(int t) => t <= 0 ? 0 : levels.levelOf(model.classOfBand(t));
    for (var spread = 0; spread <= 4; spread++) {
      final from = band - spread <= 0 ? 0 : deckOfTenth(band - spread - 1) + 1;
      final to = deckOfTenth(math.min(10, band + spread));
      final pool = <SimCard>[
        for (final c in s.bank.between(from, to))
          if (!s.askedCards.contains(c.id) && !(wordLevel && c.cognate)) c,
      ];
      if (pool.isNotEmpty) return pool[s.rng.nextInt(pool.length)];
    }
    return null;
  }

  SimItem? _itemFor(RunState s, PlacementSkill skill) {
    if (skill == PlacementSkill.say) return _sayItem(s, selfRated: false);
    final formats = _formats[skill]!;
    final band = _band(s, skill);
    final start = s.model.touchesOf(skill);
    for (var k = 0; k < formats.length; k++) {
      final code = formats[(start + k) % formats.length];
      final spec = kFormats[code]!;
      if (s.formatRun(code) >= 2) continue;
      if (!s.variant.audio && spec.skills.contains(PlacementSkill.hear)) {
        continue;
      }
      // A format guessed more than a clean item may be is not asked: it
      // cannot count toward coverage or proof.
      final probe = SimItem(const SimCard('probe', 0, false), spec);
      if (!naive && calibratedGuess(s, probe) > kCleanGuessMax) continue;
      // A cognate sentence item is asked only when the model would use it: at
      // a calibrated guess of 0.9 or more it gives no evidence.
      final allowCognate =
          !spec.wordLevel &&
          s.fixedGuess == null &&
          s.calibration.usable(formatKey(code, s.profile), true, spec.guess);
      final card = _pickCard(s, band, naive ? false : !allowCognate);
      if (card == null) continue;
      return SimItem(card, spec);
    }
    return null;
  }

  SimItem? _sayItem(RunState s, {required bool selfRated}) {
    final band = selfRated ? 5 : _band(s, PlacementSkill.say);
    final card = _pickCard(s, band, true);
    if (card == null) return null;
    return SimItem(card, kFormats['F18']!, selfRated: selfRated);
  }
}

/// The formats the item bank admits (the audit's survivors of build step 3:
/// F2/F13/F3, F4, F7/F18, F8/F16, F9 and F1/F14 where admitted); the stand-in
/// bank carries them as [kFormats] entries.
const List<String> kAdmittedFormats = <String>[
  'F2',
  'F3',
  'F13',
  'F4',
  'F7',
  'F8',
  'F16',
  'F18',
  'F1',
];

/// The real picker ([V3Picker]) over the stand-in bank, restricted to the
/// admitted formats: the harness's candidate pool is every card in every
/// admitted format, with the calibrated guess of the run.
class V3SimPicker implements SimPicker {
  V3SimPicker({
    this.yesNoBlock = false,
    this.config,
    this.formats = kAdmittedFormats,
  });

  final bool yesNoBlock;
  final PickerConfig? config;
  final List<String> formats;

  V3Picker? _picker;
  final Map<String, SimItem> _items = <String, SimItem>{};

  /// The picker of the run in progress (for the soft-stop signal).
  V3Picker? get picker => _picker;

  @override
  String get name => 'v3';

  V3Picker _build(RunState s) {
    final candidates = <PickerCandidate>[];
    for (final code in formats) {
      final spec = kFormats[code]!;
      for (final card in s.bank.cards) {
        final item = SimItem(card, spec, yesNo: code == 'F1');
        _items[item.id] = item;
        final guess = code == 'F1' ? 0.0 : calibratedGuess(s, item);
        candidates.add(
          PickerCandidate(
            id: item.id,
            format: code,
            deck: card.deck,
            skills: spec.skills,
            seconds: spec.seconds,
            slip: spec.slip,
            guess: guess,
            conflictKeys: <String>{card.id},
            clean: !card.cognate && guess <= kCleanGuessMax,
            needsAudio:
                spec.skills.contains(PlacementSkill.hear) ||
                spec.skills.contains(PlacementSkill.say),
            needsMic: spec.skills.contains(PlacementSkill.say),
            yesNo: code == 'F1',
            payload: item,
          ),
        );
      }
    }
    if (yesNoBlock) {
      for (var i = 0; i < 12; i++) {
        final item = SimItem(
          SimCard('pw$i', 0, false),
          kFormats['F1']!,
          pseudo: true,
          yesNo: true,
        );
        _items[item.id] = item;
        candidates.add(
          PickerCandidate(
            id: item.id,
            format: 'F1',
            deck: 0,
            skills: const <PlacementSkill>{PlacementSkill.read},
            seconds: 3,
            slip: 0.1,
            guess: 0,
            conflictKeys: <String>{'pw$i'},
            pseudo: true,
            yesNo: true,
            payload: item,
          ),
        );
      }
    }
    return V3Picker(
      pool: CandidatePool(candidates, s.bank.levels),
      model: s.model,
      rng: s.rng,
      config:
          config ??
          PickerConfig(
            audio: s.variant.audio,
            mic: s.variant.mic,
            recogniser: s.variant.recogniser,
            yesNoBlock: yesNoBlock,
          ),
    );
  }

  @override
  SimItem? next(RunState s) {
    final p = _picker ??= _build(s);
    final c = p.next();
    if (c == null) return null;
    final item = c.payload! as SimItem;
    return c.selfRated ? SimItem(item.card, item.spec, selfRated: true) : item;
  }
}

/// The share of [values] for which [test] holds.
double share<T>(Iterable<T> values, bool Function(T) test) {
  var n = 0;
  var hit = 0;
  for (final v in values) {
    n++;
    if (test(v)) hit++;
  }
  return n == 0 ? 0 : hit / n;
}

/// The [p]-th percentile (0 to 1) of [values], by the nearest rank.
double percentile(List<num> values, double p) {
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  if (sorted.isEmpty) return 0;
  final i = math.min(sorted.length - 1, (p * sorted.length).ceil() - 1);
  return sorted[math.max(0, i)];
}

/// Runs [persona] [runs] times (seeds 1 to [runs]) in one cell.
List<RunResult> runCell({
  required SimBank bank,
  required Persona persona,
  required SimPicker Function() picker,
  required PlacementDeclaration? declaration,
  required Variant variant,
  required int runs,
  bool sayInJoint = false,
  int seedBase = 0,
  Mutation mutation = const Mutation(),
}) => <RunResult>[
  for (var seed = 1; seed <= runs; seed++)
    runOnce(
      bank: bank,
      persona: persona,
      picker: picker(),
      declaration: declaration,
      variant: variant,
      seed: seedBase + seed,
      sayInJoint: sayInJoint,
      mutation: mutation,
    ),
];

/// The three declarations of the gates: flat, amateur and advanced.
const List<PlacementDeclaration?> kDeclarations = <PlacementDeclaration?>[
  null,
  PlacementDeclaration.amateur,
  PlacementDeclaration.advanced,
];

String declarationName(PlacementDeclaration? d) => d?.name ?? 'flat';
