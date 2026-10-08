import '../core/scheduling/fsrs.dart';
import 'skill.dart';

/// What a drill session should cover. Passed to the drill route, which asks
/// `AppState.buildSession` for the matching queue.
class DrillRequest {
  const DrillRequest({
    this.deckIds,
    this.skill,
    this.skills,
    this.tags = const <String>{},
    this.newOnly = false,
    this.numbers = false,
    this.untaught = false,
    this.revise = false,
    this.lesson = false,
    this.language,
    this.limit,
  });

  /// Today's review: every deck the current profile learns, in every skill
  /// the learner has switched on. With [language], only that language's
  /// part of it: Start review and the summary take a learner through their
  /// languages one at a time. New words come in lessons, not here
  /// (ADR-0024).
  const DrillRequest.today({String? language}) : this(language: language);

  /// One deck: "Review all due", or with [skill] "Practise one skill", or
  /// with [tags] "Only these tags".
  DrillRequest.deck(
    String deckId, {
    Skill? skill,
    Set<String> tags = const <String>{},
  }) : this(deckIds: <String>{deckId}, skill: skill, tags: tags);

  /// A lesson (ADR-0024): new words from [language]'s pending units, or with
  /// [deckId] from that deck, taught, checked and practised.
  DrillRequest.lesson({required String language, String? deckId})
    : this(
        deckIds: deckId == null ? null : <String>{deckId},
        lesson: true,
        language: language,
      );

  /// Number practice in the language of [deckId], a number deck: generated
  /// numbers, drilled and not recorded (#54, ADR-0011).
  DrillRequest.numbers(String deckId)
    : this(deckIds: <String>{deckId}, numbers: true);

  /// One deck, in [skill] if given, its words taught or not: what is due
  /// and every new pair left, so that its new pairs are what is left to
  /// learn in it. No screen offers it: new words come in lessons.
  DrillRequest.untaught(String deckId, {Skill? skill})
    : this(deckIds: <String>{deckId}, skill: skill, untaught: true);

  /// Every card already learned in one deck, due or not, and not recorded:
  /// a finished deck's "Revise". Recording an early review would stretch
  /// its interval as if it had been remembered for the whole of it.
  DrillRequest.revise(String deckId, {Set<String> tags = const <String>{}})
    : this(deckIds: <String>{deckId}, tags: tags, revise: true);

  /// Quick revision, from Today (ADR-0029): [count] words the learner has
  /// been taught, from every language they learn, picked at random, each in
  /// a skill it has been reviewed in, due or not. Every answer is recorded:
  /// FSRS counts an early review for what it is, so a right one stretches
  /// the interval only a little, and a miss brings the card back sooner.
  ///
  /// With [skills], only those skills: "Spoken", or one skill.
  const DrillRequest.revision(int count, {Set<Skill>? skills})
    : this(revise: true, limit: count, skills: skills);

  /// Every word known in [skill], from every language learned, due or not:
  /// a skill's tile on Today with nothing due. Like a quick revision, every
  /// answer is recorded (ADR-0030, ADR-0033).
  const DrillRequest.reviseSkill(Skill skill)
    : this(revise: true, skill: skill);

  /// The decks to draw from, or null for every deck the current profile
  /// learns.
  final Set<String>? deckIds;

  /// One skill only, or null for every skill the learner has switched on.
  final Skill? skill;

  /// Only these skills, such as listening and speaking together; null for
  /// [skill], or every skill. Not given with [skill].
  final Set<Skill>? skills;

  /// The skills named by [skill] or [skills], or null for every skill the
  /// learner has switched on.
  Set<Skill>? get named => skills ?? (skill == null ? null : <Skill>{skill!});

  /// Only cards carrying at least one of these tags; empty means every card.
  final Set<String> tags;

  /// Leave out due reviews and drill only new pairs.
  final bool newOnly;

  /// Generated numbers instead of the decks' cards; nothing is recorded.
  final bool numbers;

  /// New pairs of words not taught yet are taken too.
  final bool untaught;

  /// Every reviewed pair counts as due and no new pair is taken; nothing is
  /// recorded.
  final bool revise;

  /// A lesson, in [language], from [deckIds] if given.
  final bool lesson;

  /// Only decks in this language, by code; null for every language.
  final String? language;

  /// At most this many words, picked at random: a quick revision. Null for
  /// all of them, in order.
  final int? limit;

  /// Whether answers are recorded although the session revises: a revision
  /// from Today, of every deck (ADR-0029, ADR-0030, as ADR-0033 amends
  /// them). A deck's Revise records nothing.
  bool get recordsRevision => revise && deckIds == null;

  @override
  String toString() =>
      'DrillRequest(decks: ${deckIds ?? 'all'}, skill: ${skill?.name}, '
      'skills: ${skills?.map((s) => s.name)}, '
      'tags: $tags, newOnly: $newOnly, numbers: $numbers, '
      'untaught: $untaught, revise: $revise, lesson: $lesson, '
      'language: $language, limit: $limit)';
}

/// One answer in a finished session, for the summary.
class SessionAnswer {
  const SessionAnswer({required this.skill, required this.grade});

  final Skill skill;

  /// The grade recorded, 0–5 ([Fsrs.ratingOf]). Minimal pairs, which the scheduler does
  /// not know yet, use the same scale.
  final int grade;

  /// Whether the answer counts as correct in the score: the same line FSRS
  /// draws, so "I knew it" on a near miss counts and "Again" does not.
  bool get correct => grade >= Fsrs.passingGrade;
}

/// A skill's line in the summary: how many of its answers were correct.
typedef SkillScore = ({Skill skill, int correct, int total});

/// A finished session, handed from the drill to the summary.
///
/// The answers themselves were already recorded, one at a time, as they were
/// given; this is only what the summary shows.
class SessionResult {
  SessionResult({
    required List<SessionAnswer> answers,
    required this.startedAt,
    required this.endedAt,
    this.language,
  }) : answers = List<SessionAnswer>.unmodifiable(answers);

  final List<SessionAnswer> answers;
  final DateTime startedAt;
  final DateTime endedAt;

  /// The language a one-language session was in, by code, so the summary
  /// can offer the next; null for a session over several or none.
  final String? language;

  /// This result, as the session in [language] gave it.
  SessionResult inLanguage(String? language) => SessionResult(
    answers: answers,
    startedAt: startedAt,
    endedAt: endedAt,
    language: language,
  );

  int get total => answers.length;

  int get correct => answers.where((a) => a.correct).length;

  /// Correct answers as a fraction, 0–1, or 0 for an empty session.
  double get accuracy => total == 0 ? 0 : correct / total;

  Duration get elapsed => endedAt.difference(startedAt);

  /// Whole minutes spent, rounded, and at least 1 for any session.
  int get minutes => total == 0
      ? 0
      : (elapsed.inSeconds / 60).round().clamp(1, 1 << 30).toInt();

  /// One score per skill drilled, in [Skill] order; skills not drilled are
  /// left out.
  List<SkillScore> get bySkill => <SkillScore>[
    for (final skill in Skill.values)
      if (answers.any((a) => a.skill == skill))
        (
          skill: skill,
          correct: answers.where((a) => a.skill == skill && a.correct).length,
          total: answers.where((a) => a.skill == skill).length,
        ),
  ];
}
