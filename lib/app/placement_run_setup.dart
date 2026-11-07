import '../core/data/course_path.dart' show Milestone, PlanUnit;
import '../core/models/card.dart';
import '../core/models/deck.dart' show LanguageInfo;
import '../core/models/drill_mode.dart';
import '../core/placement/assurance_readout.dart';
import '../core/placement/placement_data.dart';
import '../core/placement/placement_questions.dart';
import '../core/placement/placement_run.dart';
import '../core/scheduling/placement_withdrawal.dart';
import '../core/scheduling/replay.dart' show LoggedReview, logged;
import 'app_state.dart';
import 'deck_catalog.dart';
import 'placement.dart';
import 'placement_credit.dart';
import 'placement_plan.dart';
import 'placement_recheck.dart';

/// A card whose review has a stability of this many days or more is one the
/// learner has learned in the app, so a run never asks it (plan, section
/// 2.2: "a stable card says learned in the app, not known before").
const double _stableDays = 30;

/// What one Find my level run reads of a course (wiki/Plan-Placement-V2.md,
/// section 11, "Not done in step 2"): the decks up to B1 in path order, as
/// the question builder wants them, and what the page needs to say and play
/// them.
class PlacementRunPlan {
  const PlacementRunPlan({
    required this.data,
    required this.decks,
    required this.scripts,
    required this.language,
    required this.native,
  });

  /// What the question builder reads.
  final PlacementLanguageData data;

  /// The word decks of [data], in the same order.
  final List<DeckEntry> decks;

  /// The scripts of the course that have a script check, in path order.
  final List<PlacementScript> scripts;

  /// The language learned, as its first deck writes it.
  final LanguageInfo language;

  /// The language the course is taught from: the "English" a long sentence is
  /// said back in.
  final LanguageInfo native;
}

/// Find my level's reading of a course, and the write at the end of a run.
extension PlacementRunSetup on AppState {
  /// [code]'s course as a run asks it, or null when it has no word deck.
  /// The decks stop at the unit marked B1 (section 1: "from the first A1
  /// deck to the unit marked B1"); a path with no B1 mark gives every deck.
  PlacementRunPlan? placementRunPlan(String code, {String? native}) {
    final words = walkDecks(code, native: native);
    if (words.isEmpty) return null;
    final path = pathOf(words.first);
    final plan = path?.plan ?? const <PlanUnit>[];
    var decks = words;
    final b1 = path?.milestoneIndex(Milestone.b1);
    if (b1 != null) {
      final upTo = <String>{
        for (final unit in plan.take(b1 + 1)) ...unit.decks,
      };
      final cut = <DeckEntry>[
        for (final entry in words)
          if (upTo.contains(entry.id)) entry,
      ];
      if (cut.isNotEmpty) decks = cut;
    }
    final marks = <int>[];
    for (final milestone in Milestone.values) {
      final end = path?.milestoneIndex(milestone);
      if (end == null) continue;
      final ids = <String>{
        for (final unit in plan.take(end + 1)) ...unit.decks,
      };
      final at = decks.lastIndexWhere((entry) => ids.contains(entry.id));
      if (at >= 0 && !marks.contains(at)) marks.add(at);
    }
    final families = <String, List<String>>{
      for (final unit in plan)
        for (final id in unit.decks) id: unit.grammar,
    };
    final scripts = placementScripts(code, native: native);
    final language = decks.first.language;
    final stable = <String>{
      for (final entry in decks)
        for (final card in entry.cards)
          if (DrillMode.values.any(
            (mode) =>
                (progress.stateOf(card.id, mode)?.stability ?? 0) >=
                _stableDays,
          ))
            card.id,
    };
    return PlacementRunPlan(
      data: PlacementLanguageData(
        language: code,
        decks: <PlacementDeck>[
          for (final entry in decks)
            PlacementDeck(
              id: entry.id,
              cards: entry.cards,
              grammarFamilies: families[entry.id] ?? const <String>[],
            ),
        ],
        scripts: <PlacementScriptData>[
          for (final script in scripts)
            PlacementScriptData(
              script: script.script,
              letters: _cardsOfKind(script, ScriptDeckKind.letters),
              joined: _cardsOfKind(script, ScriptDeckKind.joined),
              words: <PlacementScriptWord>[
                for (final word in script.words)
                  PlacementScriptWord(card: word.card, spelling: word.spelling),
              ],
            ),
        ],
        sounds: soundsFor(language),
        levelMarkDecks: marks,
        stableCardIds: stable,
      ),
      decks: decks,
      scripts: scripts,
      language: language,
      native: decks.first.deck.native,
    );
  }

  List<Card> _cardsOfKind(PlacementScript script, ScriptDeckKind kind) =>
      <Card>[
        for (final entry in script.decks)
          if (entry.isScript && scriptDeckKind(entry) == kind) ...entry.cards,
      ];

  /// What a run's end writes (section 5.5): for each tested skill, the decks
  /// up to its placed level are credited in its own modes through
  /// [creditPlacement]; the decks of the course's path count as placed up to
  /// the lowest of the word skills' levels, so that no skill is denied a
  /// lesson it still needs; a script placed at the top class is credited as
  /// read; and each skill's Verified mark is set to what the run found for
  /// the skills it tested, and left alone for the others.
  ///
  /// It only ever adds credit (a run that places a skill lower than an
  /// earlier one leaves the earlier credit, which the plan's section 4.4
  /// would ask about first; not built). It never changes a skill's Leave,
  /// Know or Learn.
  ///
  /// The code's paused run is dropped last, once all of this is written: a
  /// write that throws leaves the run to be carried on.
  ///
  /// With [recheck] (Check again, wiki Plan-Placement-V2, point 17.3) the
  /// credit above each tested skill's new level is withdrawn first, from
  /// every moment of the language, and the language's placed decks are
  /// replaced rather than added to; the moments that were unconfirmed are
  /// then confirmed. Every real review stays.
  void writePlacementRun(
    String code,
    PlacementRunPlan plan,
    PlacementRun run, {
    String? native,
    bool recheck = false,
  }) {
    final flagged = recheck ? unconfirmedMomentsOf(code) : const <int>{};
    _writeOutcome(code, plan, run, native: native, recheck: recheck);
    if (flagged.isNotEmpty) settings.keepPlacementMoments(code, flagged);
    settings.setPlacementRun(code, null);
  }

  void _writeOutcome(
    String code,
    PlacementRunPlan plan,
    PlacementRun run, {
    String? native,
    bool recheck = false,
  }) {
    final readout = run.readout;
    final tested = <PlacementSkill, SkillAssurance>{
      for (final MapEntry(:key, :value) in readout.entries)
        if (value.label != AssuranceLabel.notTested) key: value,
    };
    _writeSkillLabels(code, run, tested);
    if (tested.isEmpty) return;
    Set<String> idsUpTo(int level) => <String>{
      for (final entry in plan.decks.take(level + 1)) entry.id,
    };
    if (recheck) withdrawAboveNewLevel(code, plan, tested, run.levels.topClass);

    int? lowest;
    for (final skill in _wordSkills) {
      final found = tested[skill];
      if (found == null) continue;
      if (found.placedLevel >= 0) {
        creditPlacement(
          code,
          placed: idsUpTo(found.placedLevel),
          native: native,
          only: _modesOf(skill),
        );
      }
      lowest = lowest == null || found.placedLevel < lowest
          ? found.placedLevel
          : lowest;
    }

    final standings = <String, ScriptStanding>{};
    final scriptPlaced = <String>{};
    for (final (i, skill) in <PlacementSkill>[
      PlacementSkill.script,
      PlacementSkill.secondScript,
    ].indexed) {
      final found = tested[skill];
      if (found == null || i >= plan.scripts.length) continue;
      final script = plan.scripts[i];
      final standing = found.placedClass == run.levels.topClass
          ? ScriptStanding.reads
          : ScriptStanding.newTo;
      standings[script.script] = standing;
      scriptPlaced.addAll(ScriptCheck.placedFor(script.decks, standing));
    }
    if (scriptPlaced.isNotEmpty) {
      creditPlacement(
        code,
        placed: scriptPlaced,
        standings: standings,
        native: native,
        only: const <DrillMode>{},
      );
    }

    final wordDecks = <String>{for (final entry in plan.decks) entry.id};
    final testedScriptDecks = <String>{
      for (final (i, skill) in <PlacementSkill>[
        PlacementSkill.script,
        PlacementSkill.secondScript,
      ].indexed)
        if (tested.containsKey(skill) && i < plan.scripts.length)
          for (final entry in plan.scripts[i].decks) entry.id,
    };
    settings.placedDecks = <String>{
      for (final id in settings.placedDecks)
        // A check again replaces the language's placed decks: the words
        // when a word skill was tested, and the decks of a script tested.
        if (!recheck ||
            deckLanguage(id) != code ||
            (!(lowest != null && wordDecks.contains(id)) &&
                !testedScriptDecks.contains(id)))
          id,
      if (lowest != null && lowest >= 0) ...idsUpTo(lowest),
      ...scriptPlaced,
    };
    settings.setVerifiedSkills(code, <String>{
      for (final name in settings.verifiedSkillsOf(code))
        if (!tested.keys.any((skill) => skill.name == name)) name,
      for (final MapEntry(:key, :value) in tested.entries)
        if (value.isVerified) key.name,
    });
  }

  /// How sure each tested skill was, for the language's skill rows. A skill
  /// the run covered but could not test (no microphone, a sound that would
  /// not play) loses its stored label, so that an older run's name is never
  /// shown as if this run had found it; a skill the run did not cover keeps
  /// its label. The labels are not tied to the deck set they were found
  /// with: they stay until the next run covers the skill.
  void _writeSkillLabels(
    String code,
    PlacementRun run,
    Map<PlacementSkill, SkillAssurance> tested,
  ) {
    final covered = run.config.skills;
    settings.setSkillLabels(code, <String, String>{
      for (final MapEntry(:key, :value) in settings.skillLabelsOf(code).entries)
        if (!covered.any((skill) => skill.name == key)) key: value,
      for (final MapEntry(:key, :value) in tested.entries)
        key.name: value.label.name,
    });
  }

  static const List<PlacementSkill> _wordSkills = <PlacementSkill>[
    PlacementSkill.read,
    PlacementSkill.hear,
    PlacementSkill.say,
    PlacementSkill.write,
  ];

  /// The drills a skill's credit is written in: Read recognises words and
  /// grammar and reads passages, Write produces them, Hear listens, Say
  /// speaks.
  static Set<DrillMode> _modesOf(PlacementSkill skill) => switch (skill) {
    PlacementSkill.read => const <DrillMode>{
      DrillMode.recognition,
      DrillMode.reading,
      DrillMode.grammarUnderstood,
    },
    PlacementSkill.write => const <DrillMode>{
      DrillMode.production,
      DrillMode.grammar,
    },
    PlacementSkill.hear => const <DrillMode>{DrillMode.listening},
    PlacementSkill.say => const <DrillMode>{DrillMode.speaking},
    _ => const <DrillMode>{},
  };
}

/// The drills a skill's credit is written in: Read recognises words and
/// grammar and reads passages, Write produces them, Hear listens, Say speaks.
Set<DrillMode> placementModesOf(PlacementSkill skill) =>
    PlacementRunSetup._modesOf(skill);

/// The skills a run tested, by what each found; the names are the readout's.
typedef TestedSkills = Map<PlacementSkill, SkillAssurance>;

/// Takes back, for each tested skill, the credit above the level the run
/// found, from every moment of the language (point 17.3, step 1): word
/// skills by the decks above their placed level, in their modes; a script
/// skill by the decks its new standing does not place, in its script.
extension PlacementCreditWithdrawal on AppState {
  void withdrawAboveNewLevel(
    String code,
    PlacementRunPlan plan,
    TestedSkills tested,
    int topClass,
  ) {
    final moments = settings.placedAtOf(code);
    if (moments.isEmpty) return;
    final at = now();
    final index = <String, int>{
      for (final (i, entry) in plan.decks.indexed) entry.id: i,
    };
    final credited = <LoggedReview>[
      for (final e in progress.log)
        if (e.grade == 5 && deckLanguage(e.deckId) == code) logged(e),
    ];
    final found = <PlacementWithdrawal>[];
    for (final MapEntry(key: skill, value: result) in tested.entries) {
      final modes = placementModesOf(skill);
      if (modes.isEmpty) continue;
      final level = result.placedLevel;
      found.addAll(
        withdrawalsAbove(
          language: code,
          reviews: credited,
          moments: moments,
          modes: modes,
          script: null,
          above: (id) => (index[id] ?? -1) > level,
          at: at,
        ),
      );
    }
    for (final (i, skill) in <PlacementSkill>[
      PlacementSkill.script,
      PlacementSkill.secondScript,
    ].indexed) {
      final result = tested[skill];
      if (result == null || i >= plan.scripts.length) continue;
      final script = plan.scripts[i];
      final standing = result.placedClass == topClass
          ? ScriptStanding.reads
          : ScriptStanding.newTo;
      final placed = ScriptCheck.placedFor(script.decks, standing);
      final scriptDecks = <String>{
        for (final entry in script.decks)
          if (entry.isScript) entry.id,
      };
      found.addAll(
        withdrawalsAbove(
          language: code,
          reviews: credited,
          moments: moments,
          modes: const <DrillMode>{DrillMode.recognition, DrillMode.production},
          script: script.script,
          above: (id) => scriptDecks.contains(id) && !placed.contains(id),
          at: at,
        ),
      );
    }
    for (final w in found) {
      progress.withdrawCredit(w);
    }
  }
}
