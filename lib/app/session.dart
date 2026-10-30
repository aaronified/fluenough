import '../core/scheduling/fsrs.dart';
import '../core/scheduling/script_split.dart';
import '../core/scheduling/study_hours.dart';
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
    this.daily = false,
    this.language,
    this.limit,
    this.cardIds,
    this.script = ScriptScope.any,
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

  /// The day's session in [language] (#521): the reviews and new words the
  /// daily minutes buy (#485), in one session on a clock (#886).
  const DrillRequest.daily({required String language})
    : this(daily: true, language: language);

  /// A lesson (ADR-0024): new words from [language]'s pending units, or with
  /// [deckId] from that deck, taught, checked and practised. With [tags], only
  /// words carrying one of them: a deck page's "+ Learn" as its tag chips
  /// filter it.
  DrillRequest.lesson({
    required String language,
    String? deckId,
    Set<String> tags = const <String>{},
  }) : this(
         deckIds: deckId == null ? null : <String>{deckId},
         lesson: true,
         language: language,
         tags: tags,
       );

  /// Practice of the words of one deck, as a deck page's Practice asks it:
  /// every word taught, due or not, in [skills] (every skill switched on when
  /// null), narrowed by [tags]. Like any revision, every answer is
  /// recorded (ADR-0033).
  DrillRequest.practice(
    String deckId, {
    Set<Skill>? skills,
    Set<String> tags = const <String>{},
  }) : this(
         deckIds: <String>{deckId},
         skills: skills,
         tags: tags,
         revise: true,
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

  /// Every card already learned in one deck, due or not: a finished deck's
  /// "Revise". Every answer is recorded, like a quick revision's (ADR-0033).
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
  ///
  /// With [script], the script decks' share: [ScriptScope.without] for a
  /// word skill's tile, [ScriptScope.only] for the Script tile.
  const DrillRequest.reviseSkill(
    Skill skill, {
    ScriptScope script = ScriptScope.any,
  }) : this(revise: true, skill: skill, script: script);

  /// Today's Script tile: the script decks' due Recognition and Write, script
  /// reading and writing together (owner, 2026-10-24). With [revise], every
  /// one already learned, due or not.
  const DrillRequest.script({bool revise = false})
    : this(script: ScriptScope.only, revise: revise);

  /// Practice of one [tag] from Progress's All tags page: up to [count]
  /// words the learner has been taught that carry it, picked at random, due
  /// or not. Only [language]'s, the one the bar at the top shows, or every
  /// language's when null. Every answer is recorded (ADR-0033).
  DrillRequest.tag(String tag, {required int count, String? language})
    : this(revise: true, tags: <String>{tag}, limit: count, language: language);

  /// The sounds of a word (ADR-0041): the IPA course's cards [cardIds], in
  /// their order, each taught, checked and practised as a lesson does. Every
  /// answer is recorded in the IPA course and scheduled with the rest of it.
  const DrillRequest.sounds(Set<String> cardIds) : this(cardIds: cardIds);

  /// The decks to draw from, or null for every deck the current profile
  /// learns.
  final Set<String>? deckIds;

  /// The IPA cards of a "sounds of this word" session, by id and in order;
  /// null for any other session.
  final Set<String>? cardIds;

  /// One skill only, or null for every skill the learner has switched on.
  final Skill? skill;

  /// Only these skills, such as listening and speaking together; null for
  /// [skill], or every skill. Not given with [skill].
  final Set<Skill>? skills;

  /// The skills named by [skill] or [skills], or null for every skill the
  /// learner has switched on.
  Set<Skill>? get named => skills ?? (skill == null ? null : <Skill>{skill!});

  /// Which part of the script decks the session takes: all of it, only the
  /// script decks' Recognition and Write, or everything else.
  final ScriptScope script;

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

  /// The day's mixed session in [language]: reviews, then new words, sized
  /// by the daily minutes ([AppState.nextDailyRound]).
  final bool daily;

  /// Only decks in this language, by code; null for every language.
  final String? language;

  /// At most this many words, picked at random: a quick revision. Null for
  /// all of them, in order.
  final int? limit;

  /// Whether answers are recorded although the session revises: every
  /// revision of cards, from Today, a finished deck's Revise or a tag
  /// (ADR-0029, ADR-0030, as ADR-0033 amends them). Only number practice,
  /// which has no cards, records nothing.
  bool get recordsRevision => revise;

  @override
  String toString() =>
      'DrillRequest(decks: ${deckIds ?? 'all'}, skill: ${skill?.name}, '
      'skills: ${skills?.map((s) => s.name)}, '
      'tags: $tags, newOnly: $newOnly, numbers: $numbers, '
      'untaught: $untaught, revise: $revise, lesson: $lesson, daily: $daily, '
      'language: $language, limit: $limit, cards: $cardIds, '
      'script: ${script.name})';
}

/// One answer in a finished session, for the summary.
class SessionAnswer {
  const SessionAnswer({required this.skill, required this.grade, this.time});

  final Skill skill;

  /// How long the answer took, from the question showing to the answer;
  /// null where it was not timed.
  final Duration? time;

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

  /// The time spent: each timed answer's time, capped as hours spent caps it
  /// (#227), so a pause or the app in the background adds nothing. A result
  /// whose answers are not timed gives the time between start and end.
  Duration get spent {
    if (answers.every((a) => a.time == null)) return elapsed;
    var sum = Duration.zero;
    for (final a in answers) {
      sum += StudyHours.capped(a.time ?? Duration.zero);
    }
    return sum;
  }

  /// Whole minutes spent, rounded, and at least 1 for any session.
  int get minutes =>
      total == 0 ? 0 : (spent.inSeconds / 60).round().clamp(1, 1 << 30).toInt();

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
