import 'assurance_model.dart';

// The vocabulary of a "Find my level" run (wiki/Plan-Placement-V2.md,
// sections 2 and 3): skills, mastery topics, the questions of the expert
// track and the split questions that check a composite miss.

/// The skills a run tests: Script is the learner's script where the language
/// has one (a language with two, such as Hindustani, has a second).
enum PlacementSkill { read, hear, say, write, script, secondScript }

/// The mastery topics of section 2.1, plus the questions a run asks outside
/// them.
enum PlacementTopic {
  /// Topic 1: long-sentence recognition.
  longRecognition,

  /// Topic 2: long-sentence reproduction.
  longReproduction,

  /// Topic 3: late-stage grammar.
  lateGrammar,

  /// Topic 4: minimal pairs.
  minimalPairs,

  /// Topic 5: complex words.
  complexWords,

  /// Topic 6: Say, by the meaning of a word.
  sayByMeaning,

  /// Topic 7: script read and write.
  scriptReadWrite,

  /// An extra question for a skill still short of the target.
  topUp,

  /// A vocabulary question of positioning (section 5.3).
  positioning,

  /// The grammar bisection that ends positioning (section 5.3, point 6).
  grammarLevel,
}

/// Why a question is asked.
enum PlacementQuestionRole {
  /// A question of a mastery topic.
  base,

  /// One more of the same kind after a miss.
  recheck,

  /// One of the two single-part questions after a composite miss.
  split,

  /// The question after a closed case that tells hearing from spelling or
  /// pronunciation from vocabulary.
  isolating,

  /// An extra question for a skill short of the target.
  topUp,

  /// A positioning probe at a deck.
  probe,

  /// A grammar bisection probe.
  grammar,
}

/// The part of a skill a split question isolates (section 3.1). A gap in
/// [sound], [spelling] or [script] marks the skill it tests as not Verified.
enum PlacementPart { script, meaning, sound, spelling, grammar }

/// One question the run asks, as the next step of the controller.
///
/// The caller draws an item from the deck [deck] (a hard one of the last
/// deck for the expert track, see section 2.2), asks it, and says whether it
/// was answered right. [shortlistPick] (0 to 4) is a seeded choice among the
/// five hardest candidates, so two runs do not ask the same five.
class PlacementQuestionRequest {
  const PlacementQuestionRequest({
    required this.number,
    required this.role,
    required this.topic,
    required this.variant,
    required this.kind,
    required this.skills,
    required this.deck,
    required this.percentile,
    required this.shortlistPick,
  });

  /// 1 for the first question of the run.
  final int number;

  final PlacementQuestionRole role;

  final PlacementTopic topic;

  /// The question's name in the plan: `K1`, `K2`, `R1`, `R2`, `G1`, `G2`,
  /// `W1`, `W2`, `P1`, `P2`, `Y1` to `Y3`, `SR`, `SW`, `SX` (a second script
  /// adds a `2`), `S1` and `S2` for a split, `I1` for an isolating question,
  /// `T` for a top-up, `V` for a positioning probe, `GR` for grammar. A
  /// recheck keeps the name of the question it checks. Letters ending in `b`
  /// are the second question of a topic whose two kinds are not both
  /// available (a language with no script has no `K1`).
  final String variant;

  /// What the model takes the answer to be (its slip and guess rates).
  final PlacementQuestionKind kind;

  /// The skills a right answer is evidence for.
  final List<PlacementSkill> skills;

  /// The deck index to draw from.
  final int deck;

  /// [deck] as a percentile of the path, 0 to 100.
  final double percentile;

  final int shortlistPick;

  @override
  String toString() =>
      'Q$number $variant ${role.name} ${kind.name} '
      '${skills.map((s) => s.name).join('+')} deck $deck';
}

/// A question of the expert track (section 2.1), with its split (section
/// 3.1).
class PlacementBaseQuestion {
  const PlacementBaseQuestion({
    required this.id,
    required this.topic,
    required this.kind,
    required this.skills,
    this.splits = const <PlacementSplit>[],
  });

  final String id;
  final PlacementTopic topic;
  final PlacementQuestionKind kind;
  final List<PlacementSkill> skills;

  /// The two single-part questions that follow a miss; none for the
  /// single-skill topics (pairs, Say, script), which use the sequential
  /// recheck instead.
  final List<PlacementSplit> splits;

  /// A miss of a composite counts at half strength until a split says which
  /// part failed; a question for one skill is that skill's miss in full.
  bool get halfOnMiss => skills.length > 1 && splits.isNotEmpty;
}

/// A split question: a different item of the same topic that removes parts.
class PlacementSplit {
  const PlacementSplit(this.id, this.part, this.kind, this.skills);

  final String id;
  final PlacementPart part;
  final PlacementQuestionKind kind;
  final List<PlacementSkill> skills;

  /// Whether a gap found by this split blocks Verified for its skills.
  bool get blocksVerified =>
      part == PlacementPart.sound ||
      part == PlacementPart.spelling ||
      part == PlacementPart.script;
}

/// The number of base questions a topic asks at least (section 2.1).
int minimumQuestions(PlacementTopic topic) =>
    topic == PlacementTopic.sayByMeaning ? 3 : 2;

/// The order the topics are asked in: meaning-bearing topics first.
const List<PlacementTopic> placementTopicOrder = <PlacementTopic>[
  PlacementTopic.longRecognition,
  PlacementTopic.complexWords,
  PlacementTopic.lateGrammar,
  PlacementTopic.longReproduction,
  PlacementTopic.minimalPairs,
  PlacementTopic.sayByMeaning,
  PlacementTopic.scriptReadWrite,
];

List<PlacementSkill> _only(
  Set<PlacementSkill> tested,
  List<PlacementSkill> p,
) => <PlacementSkill>[
  for (final skill in p)
    if (tested.contains(skill)) skill,
];

/// The expert-track questions for the [tested] skills, in the order of
/// section 2.1 (topics 1, 5, 3, 2, 4, 6, 7).
///
/// A topic uses the variants that fit the known skills (rows g and j of
/// section 6): with no Hear a second written question takes the place of the
/// audio one, with no Write the reproduction topic is not asked, with no
/// mic K1 and K2 are picks. A clean run asks 15 questions for one script, 13
/// for none and 17 for two. [extraScriptQuestion] adds the third script
/// question of section 6.2 (one more per script).
List<PlacementBaseQuestion> buildBaseQuestions(
  Set<PlacementSkill> tested, {
  required bool microphone,
  bool extraScriptQuestion = false,
}) {
  final reads = tested.contains(PlacementSkill.read);
  final hears = tested.contains(PlacementSkill.hear);
  final writes = tested.contains(PlacementSkill.write);
  final says = tested.contains(PlacementSkill.say) && microphone;
  final english = microphone
      ? PlacementQuestionKind.english
      : PlacementQuestionKind.pickMany;

  // Skills of a split: the wanted ones that are tested, else the question's.
  List<PlacementSkill> splitSkills(
    List<PlacementSkill> wanted,
    List<PlacementSkill> fallback,
  ) {
    final skills = _only(tested, wanted);
    return skills.isEmpty ? fallback : skills;
  }

  const read = PlacementSkill.read;
  const hear = PlacementSkill.hear;
  const write = PlacementSkill.write;
  const pickOne = PlacementQuestionKind.pickOne;
  const tilesWord = PlacementQuestionKind.tilesWord;

  PlacementBaseQuestion k1(String id) {
    final skills = _only(tested, const [read, PlacementSkill.script]);
    return PlacementBaseQuestion(
      id: id,
      topic: PlacementTopic.longRecognition,
      kind: english,
      skills: skills,
      splits: <PlacementSplit>[
        const PlacementSplit('S1', PlacementPart.meaning, pickOne, [read]),
        PlacementSplit(
          'S2',
          PlacementPart.script,
          pickOne,
          splitSkills(const [PlacementSkill.script], const [read]),
        ),
      ],
    );
  }

  PlacementBaseQuestion k2(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longRecognition,
    kind: english,
    skills: const [hear],
    splits: const <PlacementSplit>[
      PlacementSplit('S1', PlacementPart.sound, pickOne, [hear]),
      PlacementSplit('S2', PlacementPart.meaning, pickOne, [hear]),
    ],
  );

  PlacementBaseQuestion w1(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.complexWords,
    kind: pickOne,
    skills: const [read],
    splits: <PlacementSplit>[
      const PlacementSplit('S1', PlacementPart.meaning, pickOne, [read]),
      PlacementSplit(
        'S2',
        PlacementPart.sound,
        pickOne,
        splitSkills(const [hear], const [read]),
      ),
    ],
  );

  PlacementBaseQuestion w2(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.complexWords,
    kind: pickOne,
    skills: const [hear],
    splits: <PlacementSplit>[
      const PlacementSplit('S1', PlacementPart.meaning, pickOne, [hear]),
      PlacementSplit(
        'S2',
        PlacementPart.script,
        pickOne,
        splitSkills(const [read], const [hear]),
      ),
    ],
  );

  PlacementBaseQuestion g1(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.lateGrammar,
    kind: pickOne,
    skills: const [read],
    splits: const <PlacementSplit>[
      PlacementSplit('S1', PlacementPart.grammar, pickOne, [read]),
      PlacementSplit('S2', PlacementPart.grammar, pickOne, [read]),
    ],
  );

  PlacementBaseQuestion g2(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.lateGrammar,
    kind: PlacementQuestionKind.tilesSentence,
    skills: _only(tested, const [write, read]),
    splits: <PlacementSplit>[
      PlacementSplit(
        'S1',
        PlacementPart.grammar,
        pickOne,
        splitSkills(const [read], const [write]),
      ),
      const PlacementSplit('S2', PlacementPart.spelling, tilesWord, [write]),
    ],
  );

  PlacementBaseQuestion r1(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longReproduction,
    kind: PlacementQuestionKind.tilesSentence,
    skills: const [hear, write],
    splits: const <PlacementSplit>[
      PlacementSplit('S1', PlacementPart.sound, pickOne, [hear]),
      PlacementSplit('S2', PlacementPart.spelling, tilesWord, [write]),
    ],
  );

  PlacementBaseQuestion r2(String id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longReproduction,
    kind: PlacementQuestionKind.tilesSentence,
    skills: const [write],
    splits: const <PlacementSplit>[
      PlacementSplit('S1', PlacementPart.spelling, tilesWord, [write]),
      PlacementSplit('S2', PlacementPart.grammar, PlacementQuestionKind.pair, [
        write,
      ]),
    ],
  );

  final out = <PlacementBaseQuestion>[];

  // Topic 1.
  if (reads && hears) {
    out
      ..add(k1('K1'))
      ..add(k2('K2'));
  } else if (reads) {
    out
      ..add(k1('K1'))
      ..add(k1('K1b'));
  } else if (hears) {
    out
      ..add(k2('K2'))
      ..add(k2('K2b'));
  }

  // Topic 5.
  if (reads && hears) {
    out
      ..add(w1('W1'))
      ..add(w2('W2'));
  } else if (reads) {
    out
      ..add(w1('W1'))
      ..add(w1('W1b'));
  } else if (hears) {
    out
      ..add(w2('W2'))
      ..add(w2('W2b'));
  }

  // Topic 3.
  if (reads && writes) {
    out
      ..add(g1('G1'))
      ..add(g2('G2'));
  } else if (reads) {
    out
      ..add(g1('G1'))
      ..add(g1('G1b'));
  } else if (writes) {
    out
      ..add(g2('G2'))
      ..add(g2('G2b'));
  } else if (hears) {
    // "Which of two sentences sounds right", two families.
    for (final id in const ['G3', 'G3b']) {
      out.add(
        PlacementBaseQuestion(
          id: id,
          topic: PlacementTopic.lateGrammar,
          kind: PlacementQuestionKind.pair,
          skills: const [hear],
        ),
      );
    }
  }

  // Topic 2 needs Write.
  if (writes) {
    if (hears) {
      out
        ..add(r1('R1'))
        ..add(r2('R2'));
    } else {
      out
        ..add(r2('R2'))
        ..add(r2('R2b'));
    }
  }

  // Topic 4.
  if (hears) {
    for (final id in const ['P1', 'P2']) {
      out.add(
        PlacementBaseQuestion(
          id: id,
          topic: PlacementTopic.minimalPairs,
          kind: PlacementQuestionKind.pair,
          skills: const [hear],
        ),
      );
    }
  }

  // Topic 6.
  if (says) {
    for (final id in const ['Y1', 'Y2', 'Y3']) {
      out.add(
        PlacementBaseQuestion(
          id: id,
          topic: PlacementTopic.sayByMeaning,
          kind: PlacementQuestionKind.say,
          skills: const [PlacementSkill.say],
        ),
      );
    }
  }

  // Topic 7, once for each script the learner reads.
  for (final script in const [
    PlacementSkill.script,
    PlacementSkill.secondScript,
  ]) {
    if (!tested.contains(script)) continue;
    final suffix = script == PlacementSkill.script ? '' : '2';
    // The first script has K1 as well; the second one has only its own two
    // questions, so its read question asks for the meaning in English (a
    // production answer), which is what lets two scripts cost 17 questions.
    final readKind = suffix.isEmpty ? PlacementQuestionKind.pickMany : english;
    PlacementBaseQuestion scriptRead(String id) => PlacementBaseQuestion(
      id: '$id$suffix',
      topic: PlacementTopic.scriptReadWrite,
      kind: readKind,
      skills: <PlacementSkill>[script, if (reads) read],
    );
    out.add(scriptRead('SR'));
    if (writes) {
      out.add(
        PlacementBaseQuestion(
          id: 'SW$suffix',
          topic: PlacementTopic.scriptReadWrite,
          kind: tilesWord,
          skills: <PlacementSkill>[script, write],
        ),
      );
    } else {
      out.add(scriptRead('SRb'));
    }
    if (extraScriptQuestion) out.add(scriptRead('SX'));
  }

  return out;
}
