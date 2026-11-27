/// The evaluator (#322): every achievement as a rule over the review log.
/// Pure Dart, no Flutter, so that it runs on an isolate and in a unit test
/// alike.
///
/// Nothing is stored. The state of each badge, and the date it was earned,
/// come from replaying the log ([KnownHistory]); a past review is therefore
/// celebrated once, at the date the rule was first met (decision 4), and
/// an earned badge is never taken back (decision 1): a card counts once it
/// has EVER been known, and [evaluateAchievements] keeps what it is given as
/// `earnedBefore` even if the decks have since grown.
library;

import '../data/course_path.dart' show Milestone;
import '../languages/language_skills.dart';
import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../private/private_ids.dart';
import '../progress/recent_answers.dart' show ParametersOfReview;
import '../scheduling/fsrs.dart';
import 'achievement.dart';
import 'achievement_catalogue.dart';
import 'achievement_facts.dart';
import 'known_history.dart';

List<double> _defaultParameters(ReviewEvent event) => Fsrs.w;

/// Evaluates the achievements of one language ([facts]; none for the
/// app-wide ones alone) over [log], oldest first, whatever the languages of
/// its reviews: the course rules read only [facts]'s language's reviews, the
/// streaks and answer counts read all of them (decision 3).
///
/// Placement credit is no answer: it counts for no streak, answer count or
/// first lesson, and it never makes a card known. [parametersOf] gives the
/// parameters that schedule a review's pair, as Progress does.
///
/// [earnedBefore] holds the ids and dates of badges already earned, such as
/// a previous report's [AchievementReport.earnedDates]: they stay earned,
/// at that date or the earlier one the log gives, even if a deck has grown
/// since and the rule no longer holds.
AchievementReport evaluateAchievements({
  required Iterable<ReviewEvent> log,
  AchievementFacts? facts,
  ParametersOfReview parametersOf = _defaultParameters,
  Map<String, DateTime> earnedBefore = const <String, DateTime>{},
}) {
  final answered = log.answered.toList();
  final language = facts?.language;
  final courseLog = <ReviewEvent>[
    if (language != null)
      for (final e in answered)
        if (languageOfId(e.cardId) == language) e,
  ];
  final evaluator = _Evaluator(
    facts: facts,
    history: KnownHistory.of(courseLog, parametersOf: parametersOf),
    courseLog: courseLog,
    answered: answered,
  );
  final defs = <AchievementDef>[
    if (facts != null) ...courseAchievementDefs(facts),
    ...appAchievementDefs(),
  ];
  return AchievementReport(<AchievementResult>[
    for (final def in defs) evaluator.resultOf(def, earnedBefore[def.id]),
  ]);
}

class _Evaluator {
  _Evaluator({
    required this.facts,
    required this.history,
    required this.courseLog,
    required List<ReviewEvent> answered,
  }) {
    _countAnswers(answered);
  }

  final AchievementFacts? facts;
  final KnownHistory history;
  final List<ReviewEvent> courseLog;

  /// The moment of each answer in all languages, oldest first, placement
  /// credit left out.
  final List<DateTime> _answerTimes = <DateTime>[];

  /// The first moment of each day with an answer, by day number.
  final Map<int, DateTime> _dayStart = <int, DateTime>{};

  /// The first moment a run of consecutive days reached each length.
  final Map<int, DateTime> _streakReached = <int, DateTime>{};
  int _longestStreak = 0;

  Set<String>? _wordIds;

  void _countAnswers(List<ReviewEvent> answered) {
    for (final e in answered) {
      if (e.isPlaced) continue;
      _answerTimes.add(e.at);
      final day = _dayNumber(e.at);
      final first = _dayStart[day];
      if (first == null || e.at.isBefore(first)) _dayStart[day] = e.at;
    }
    _answerTimes.sort();
    final days = _dayStart.keys.toList()..sort();
    var run = 0;
    int? before;
    for (final day in days) {
      run = before != null && before + 1 == day ? run + 1 : 1;
      before = day;
      if (run > _longestStreak) _longestStreak = run;
      _streakReached.putIfAbsent(run, () => _dayStart[day]!);
    }
  }

  static int _dayNumber(DateTime at) =>
      DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  AchievementResult resultOf(AchievementDef def, DateTime? before) {
    final skill = def.skill;
    final left = skill != null && (facts?.leave.contains(skill) ?? false);
    final found = left ? _notEarnable(def) : _rule(def);
    if (before == null) return found;
    final at = found.earnedAt;
    final earnedAt = at != null && at.isBefore(before) ? at : before;
    return AchievementResult(
      def: def,
      status: AchievementStatus.earned,
      have: found.need > 0 ? found.need : found.have,
      need: found.need,
      earnedAt: earnedAt,
      earnable: found.earnable,
    );
  }

  AchievementResult _notEarnable(AchievementDef def) => AchievementResult(
    def: def,
    status: AchievementStatus.locked,
    have: 0,
    need: 0,
    earnable: false,
  );

  AchievementResult _rule(AchievementDef def) {
    final facts = this.facts;
    switch (def.kind) {
      case AchievementKind.level:
        final mark = facts!.marks[def.level!]!;
        return _allKnown(def, facts.cardIdsUpTo(mark));
      case AchievementKind.wordCount:
        return _counted(def, _wordTimes(), def.target);
      case AchievementKind.skillStart:
        return _start(def, facts!);
      case AchievementKind.skillMaster:
        return _master(def, facts!);
      case AchievementKind.deckSet:
        final chosen = facts!.sets.firstWhere((s) => s.id == def.setId);
        final ids = <String>{};
        for (final deckId in chosen.decks) {
          final deck = facts.decks[deckId];
          if (deck != null) ids.addAll(deck.cards.map((c) => c.id));
        }
        return _allKnown(def, ids);
      case AchievementKind.other:
        return _other(def);
    }
  }

  /// Earned when every card of [ids] has been known; dated when the last
  /// was.
  AchievementResult _allKnown(AchievementDef def, Set<String> ids) {
    DateTime? last;
    var have = 0;
    for (final id in ids) {
      final at = history.cardKnownAt(id);
      if (at == null) continue;
      have++;
      if (last == null || at.isAfter(last)) last = at;
    }
    return _result(def, have, ids.length, have == ids.length ? last : null);
  }

  /// Earned when [times], sorted here, holds [need] moments; dated at the
  /// [need]th.
  AchievementResult _counted(
    AchievementDef def,
    Iterable<DateTime> times,
    int need,
  ) {
    final sorted = times.toList()..sort();
    final at = sorted.length >= need ? sorted[need - 1] : null;
    return _result(def, sorted.length, need, at);
  }

  AchievementResult _result(
    AchievementDef def,
    int have,
    int need,
    DateTime? earnedAt,
  ) {
    // Nothing to know is nothing earned: an empty bar never opens.
    final earned = earnedAt != null && need > 0;
    var status = AchievementStatus.locked;
    if (earned) {
      status = AchievementStatus.earned;
    } else if (have > 0) {
      status = AchievementStatus.inProgress;
    }
    return AchievementResult(
      def: def,
      status: status,
      have: have,
      need: need,
      earnedAt: earned ? earnedAt : null,
    );
  }

  /// The ids of the words of the path's decks.
  Set<String> get _words => _wordIds ??= <String>{
    for (final deck in facts!.decks.values)
      for (final card in deck.cards)
        if (card.isWord) card.id,
  };

  Iterable<DateTime> _wordTimes() => <DateTime>[
    for (final id in _words) ?history.cardKnownAt(id),
  ];

  // Skills ------------------------------------------------------------------

  static DrillMode _modeOf(SkillKind kind) => switch (kind) {
    SkillKind.hear => DrillMode.listening,
    SkillKind.speak => DrillMode.speaking,
    SkillKind.read => DrillMode.recognition,
    SkillKind.write => DrillMode.production,
    SkillKind.gesture => DrillMode.recognition,
  };

  /// The modes a skill's Master asks a card to be known in: a sign is
  /// recognised and made, so both.
  static List<DrillMode> _modesOf(SkillKind kind) {
    if (kind == SkillKind.gesture) {
      return const <DrillMode>[DrillMode.recognition, DrillMode.production];
    }
    return <DrillMode>[_modeOf(kind)];
  }

  AchievementResult _start(AchievementDef def, AchievementFacts facts) {
    final skill = def.skill!;
    switch (skill.kind) {
      case SkillKind.hear:
        // Hear and answer 10 audio cards.
        return _counted(
          def,
          history.passedIn(DrillMode.listening).values,
          kCardsForStart,
        );
      case SkillKind.speak:
        // Say an answer aloud and have it heard.
        return _counted(def, history.passedIn(DrillMode.speaking).values, 1);
      case SkillKind.read:
      case SkillKind.write:
        final mode = _modeOf(skill.kind);
        final times = <DateTime>[
          for (final id in _letters(facts, skill.script))
            ?history.pairKnownAt(id, mode),
        ];
        return _counted(def, times, kLettersForStart);
      case SkillKind.gesture:
        // Recognise and make 10 signs.
        final signs = <DateTime>[];
        for (final id in _words) {
          final seen = history.pairKnownAt(id, DrillMode.recognition);
          final made = history.pairKnownAt(id, DrillMode.production);
          if (seen == null || made == null) continue;
          signs.add(seen.isAfter(made) ? seen : made);
        }
        return _counted(def, signs, kCardsForStart);
    }
  }

  /// The letters a script's Start counts: the cards of its script decks, or,
  /// for a language with no such deck, its words.
  Iterable<String> _letters(AchievementFacts facts, String? script) {
    final ids = <String>{
      for (final deck in facts.decks.values)
        if (deck.isScript && (deck.script == null || deck.script == script))
          for (final card in deck.cards) card.id,
    };
    return ids.isEmpty ? _words : ids;
  }

  AchievementResult _master(AchievementDef def, AchievementFacts facts) {
    final skill = def.skill!;
    final end = skill.kind.isScript
        ? facts.marks[Milestone.a1]
        : facts.marks[Milestone.a2];
    final modes = _modesOf(skill.kind);
    var need = 0;
    var have = 0;
    DateTime? last;
    for (final deckId in facts.decksUpTo(end ?? 0)) {
      final deck = facts.decks[deckId];
      if (deck == null) continue;
      // A script deck of another script is not this skill's.
      if (skill.kind.isScript &&
          deck.isScript &&
          deck.script != null &&
          deck.script != skill.script) {
        continue;
      }
      for (final card in deck.cards) {
        if (!modes.every(card.asks)) continue;
        need++;
        var known = true;
        DateTime? at;
        for (final mode in modes) {
          final when = history.pairKnownAt(card.id, mode);
          if (when == null) {
            known = false;
            break;
          }
          if (at == null || when.isAfter(at)) at = when;
        }
        if (!known) continue;
        have++;
        if (last == null || at!.isAfter(last)) last = at;
      }
    }
    return _result(def, have, need, have == need ? last : null);
  }

  // Other -------------------------------------------------------------------

  AchievementResult _other(AchievementDef def) {
    switch (def.other!) {
      case AchievementOther.firstLesson:
        DateTime? first;
        for (final e in courseLog) {
          if (e.isPlaced) continue;
          if (first == null || e.at.isBefore(first)) first = e.at;
        }
        return _result(def, first == null ? 0 : 1, 1, first);
      case AchievementOther.streak:
        return _result(
          def,
          _longestStreak < def.target ? _longestStreak : def.target,
          def.target,
          _streakReached[def.target],
        );
      case AchievementOther.answers:
        final have = _answerTimes.length;
        return _result(
          def,
          have < def.target ? have : def.target,
          def.target,
          have >= def.target ? _answerTimes[def.target - 1] : null,
        );
    }
  }
}
