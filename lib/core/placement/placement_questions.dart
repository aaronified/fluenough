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

/// The name of a question in the plan (section 2.1 and 3.1).
enum PlacementVariant {
  k1('K1'),
  k1b('K1b'),
  k2('K2'),
  k2b('K2b'),
  w1('W1'),
  w1b('W1b'),
  w2('W2'),
  w2b('W2b'),
  g1('G1'),
  g1b('G1b'),
  g2('G2'),
  g2b('G2b'),
  g3('G3'),
  g3b('G3b'),
  r1('R1'),
  r2('R2'),
  r2b('R2b'),
  p1('P1'),
  p2('P2'),
  y1('Y1'),
  y2('Y2'),
  y3('Y3'),
  sr('SR'),
  srb('SRb'),
  sw('SW'),
  sx('SX'),
  sr2('SR2'),
  srb2('SRb2'),
  sw2('SW2'),
  sx2('SX2'),
  s1('S1'),
  s2('S2'),
  isolating('I1'),

  /// A top-up question for a skill short of the target.
  topUp('T'),

  /// A positioning probe.
  probe('V'),

  /// A grammar bisection probe.
  grammar('GR');

  const PlacementVariant(this.label);

  /// The plan's name for it: `K1`, `SR2`, `T`, `V`, `GR`.
  final String label;
}

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
    this.part,
    this.origin,
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
  final PlacementVariant variant;

  /// What the model takes the answer to be (its slip and guess rates).
  final PlacementQuestionKind kind;

  /// The skills a right answer is evidence for.
  final List<PlacementSkill> skills;

  /// The deck index to draw from.
  final int deck;

  /// [deck] as a percentile of the path, 0 to 100.
  final double percentile;

  final int shortlistPick;

  /// For a split, the part of the failed question it isolates (section 3.1);
  /// null for any other question. The question builder reads it to say what
  /// to remove from the failed question.
  final PlacementPart? part;

  /// For a split, the name of the base question whose miss it checks (`K1`,
  /// `W2`, ...); null for any other question.
  final PlacementVariant? origin;

  @override
  String toString() =>
      'Q$number ${variant.label} ${role.name} ${kind.name} '
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

  final PlacementVariant id;
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

  final PlacementVariant id;
  final PlacementPart part;
  final PlacementQuestionKind kind;
  final List<PlacementSkill> skills;
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

  PlacementBaseQuestion k1(PlacementVariant id) {
    final skills = _only(tested, const [read, PlacementSkill.script]);
    return PlacementBaseQuestion(
      id: id,
      topic: PlacementTopic.longRecognition,
      kind: english,
      skills: skills,
      splits: <PlacementSplit>[
        const PlacementSplit(
          PlacementVariant.s1,
          PlacementPart.meaning,
          pickOne,
          [read],
        ),
        PlacementSplit(
          PlacementVariant.s2,
          PlacementPart.script,
          pickOne,
          splitSkills(const [PlacementSkill.script], const [read]),
        ),
      ],
    );
  }

  PlacementBaseQuestion k2(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longRecognition,
    kind: english,
    skills: const [hear],
    splits: const <PlacementSplit>[
      PlacementSplit(PlacementVariant.s1, PlacementPart.sound, pickOne, [hear]),
      PlacementSplit(PlacementVariant.s2, PlacementPart.meaning, pickOne, [
        hear,
      ]),
    ],
  );

  PlacementBaseQuestion w1(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.complexWords,
    kind: pickOne,
    skills: const [read],
    splits: <PlacementSplit>[
      const PlacementSplit(
        PlacementVariant.s1,
        PlacementPart.meaning,
        pickOne,
        [read],
      ),
      PlacementSplit(
        PlacementVariant.s2,
        PlacementPart.sound,
        pickOne,
        splitSkills(const [hear], const [read]),
      ),
    ],
  );

  PlacementBaseQuestion w2(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.complexWords,
    kind: pickOne,
    skills: const [hear],
    splits: <PlacementSplit>[
      const PlacementSplit(
        PlacementVariant.s1,
        PlacementPart.meaning,
        pickOne,
        [hear],
      ),
      PlacementSplit(
        PlacementVariant.s2,
        PlacementPart.script,
        pickOne,
        splitSkills(const [read], const [hear]),
      ),
    ],
  );

  PlacementBaseQuestion g1(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.lateGrammar,
    kind: pickOne,
    skills: const [read],
    splits: const <PlacementSplit>[
      PlacementSplit(PlacementVariant.s1, PlacementPart.grammar, pickOne, [
        read,
      ]),
      PlacementSplit(PlacementVariant.s2, PlacementPart.grammar, pickOne, [
        read,
      ]),
    ],
  );

  PlacementBaseQuestion g2(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.lateGrammar,
    kind: PlacementQuestionKind.tilesSentence,
    skills: _only(tested, const [write, read]),
    splits: <PlacementSplit>[
      PlacementSplit(
        PlacementVariant.s1,
        PlacementPart.grammar,
        pickOne,
        splitSkills(const [read], const [write]),
      ),
      const PlacementSplit(
        PlacementVariant.s2,
        PlacementPart.spelling,
        tilesWord,
        [write],
      ),
    ],
  );

  PlacementBaseQuestion r1(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longReproduction,
    kind: PlacementQuestionKind.tilesSentence,
    skills: const [hear, write],
    splits: const <PlacementSplit>[
      PlacementSplit(PlacementVariant.s1, PlacementPart.sound, pickOne, [hear]),
      PlacementSplit(PlacementVariant.s2, PlacementPart.spelling, tilesWord, [
        write,
      ]),
    ],
  );

  PlacementBaseQuestion r2(PlacementVariant id) => PlacementBaseQuestion(
    id: id,
    topic: PlacementTopic.longReproduction,
    kind: PlacementQuestionKind.tilesSentence,
    skills: const [write],
    splits: const <PlacementSplit>[
      PlacementSplit(PlacementVariant.s1, PlacementPart.spelling, tilesWord, [
        write,
      ]),
      PlacementSplit(
        PlacementVariant.s2,
        PlacementPart.grammar,
        PlacementQuestionKind.pair,
        [write],
      ),
    ],
  );

  final out = <PlacementBaseQuestion>[];

  // Topic 1.
  if (reads && hears) {
    out
      ..add(k1(PlacementVariant.k1))
      ..add(k2(PlacementVariant.k2));
  } else if (reads) {
    out
      ..add(k1(PlacementVariant.k1))
      ..add(k1(PlacementVariant.k1b));
  } else if (hears) {
    out
      ..add(k2(PlacementVariant.k2))
      ..add(k2(PlacementVariant.k2b));
  }

  // Topic 5.
  if (reads && hears) {
    out
      ..add(w1(PlacementVariant.w1))
      ..add(w2(PlacementVariant.w2));
  } else if (reads) {
    out
      ..add(w1(PlacementVariant.w1))
      ..add(w1(PlacementVariant.w1b));
  } else if (hears) {
    out
      ..add(w2(PlacementVariant.w2))
      ..add(w2(PlacementVariant.w2b));
  }

  // Topic 3.
  if (reads && writes) {
    out
      ..add(g1(PlacementVariant.g1))
      ..add(g2(PlacementVariant.g2));
  } else if (reads) {
    out
      ..add(g1(PlacementVariant.g1))
      ..add(g1(PlacementVariant.g1b));
  } else if (writes) {
    out
      ..add(g2(PlacementVariant.g2))
      ..add(g2(PlacementVariant.g2b));
  } else if (hears) {
    // "Which of two sentences sounds right", two families.
    for (final id in const [PlacementVariant.g3, PlacementVariant.g3b]) {
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
        ..add(r1(PlacementVariant.r1))
        ..add(r2(PlacementVariant.r2));
    } else {
      out
        ..add(r2(PlacementVariant.r2))
        ..add(r2(PlacementVariant.r2b));
    }
  }

  // Topic 4.
  if (hears) {
    for (final id in const [PlacementVariant.p1, PlacementVariant.p2]) {
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
    for (final id in const [
      PlacementVariant.y1,
      PlacementVariant.y2,
      PlacementVariant.y3,
    ]) {
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
    final first = script == PlacementSkill.script;
    // The first script has K1 as well; the second one has only its own two
    // questions, so its read question asks for the meaning in English (a
    // production answer), which is what lets two scripts cost 17 questions.
    final readKind = first ? PlacementQuestionKind.pickMany : english;
    PlacementBaseQuestion scriptRead(PlacementVariant id) =>
        PlacementBaseQuestion(
          id: id,
          topic: PlacementTopic.scriptReadWrite,
          kind: readKind,
          skills: <PlacementSkill>[script, if (reads) read],
        );
    out.add(scriptRead(first ? PlacementVariant.sr : PlacementVariant.sr2));
    if (writes) {
      out.add(
        PlacementBaseQuestion(
          id: first ? PlacementVariant.sw : PlacementVariant.sw2,
          topic: PlacementTopic.scriptReadWrite,
          kind: tilesWord,
          skills: <PlacementSkill>[script, write],
        ),
      );
    } else {
      out.add(scriptRead(first ? PlacementVariant.srb : PlacementVariant.srb2));
    }
    if (extraScriptQuestion) {
      out.add(scriptRead(first ? PlacementVariant.sx : PlacementVariant.sx2));
    }
  }

  return out;
}
