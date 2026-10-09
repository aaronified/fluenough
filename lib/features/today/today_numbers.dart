import 'dart:math' as math;

import '../../app/app_state.dart';
import '../../app/memory_progress.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart';
import '../../core/scheduling/ask.dart';
import '../../core/scheduling/skill_fit.dart';
import '../../ui/widgets/pace_parts.dart';

/// How long the design allows for one card when it estimates a session:
/// "about 4 min" for 12 cards.
const int secondsPerCard = 20;

/// The skills Today draws a tile for: Recognition, Hear, Say, Write and
/// Grammar (ADR-0034). Minimal pairs have none: they are drilled from their
/// own decks (#31). Speaking has one only while it is switched on
/// (ADR-0030).
const List<Skill> todaySkills = <Skill>[
  Skill.recognition,
  Skill.listening,
  Skill.speaking,
  Skill.production,
  Skill.grammar,
];

/// One day in Today's week row.
enum WeekDayStatus {
  /// At least one review that day, today included.
  done,

  /// Today, with no review yet.
  today,

  /// An earlier day with no review.
  other,
}

/// One of the last seven days, and whether it was practised.
typedef WeekDay = ({DateTime date, WeekDayStatus status});

/// A language's next lesson (ADR-0024): how many words it teaches, or
/// whether it is a passage to read, and whether today's is done already,
/// so that this one is another.
typedef TodayLesson = ({
  LanguageInfo language,
  int words,
  bool reading,
  bool done,
});

/// What Today shows of the learner's pace (ADR-0035,
/// "Shown prominently"): the strip on the due card, and a mark on each
/// adjusted skill's tile.
typedef TodayPace = ({
  /// The next 30 days' reviews in every skill of the languages learned,
  /// now and as at the start; null while they are worked out.
  ({int reviews, int was})? totals,

  /// Which way each adjusted skill moved, in the languages learned
  /// together. A skill not adjusted has none.
  Map<Skill, PaceDirection> marks,
});

/// [state]'s [TodayPace], or null before any skill is adjusted, which is
/// read from the stored fits alone: nothing is worked out until then.
///
/// Only [onScreen] does it ask for the paces to be worked out; else it
/// takes the last worked out, so that Today, built behind a drill or
/// another tab, starts no job for each answer recorded there.
TodayPace? todayPaceOf(AppState state, {bool onScreen = true}) {
  final pacing = state.pacing;
  if (!pacing.adjusted) return null;
  final paces = onScreen ? pacing.paces : pacing.latest;
  if (paces == null) {
    return (totals: null, marks: const <Skill, PaceDirection>{});
  }
  final learned = <SkillPace>[
    for (final p in paces.values)
      if (state.currentProfile.learns(p.key.language)) p,
  ];
  final shown = learned.isEmpty ? paces.values.toList() : learned;
  final all = SkillFit.together(shown);
  return (
    totals: all == null
        ? null
        : (reviews: all.now.reviews, was: all.start.reviews),
    marks: <Skill, PaceDirection>{
      for (final skill in todaySkills)
        if (SkillFit.together(<SkillPace>[
              for (final p in shown)
                if (p.adjusted && p.key.mode == skill.mode) p,
            ])
            case final moved?)
          skill: PaceDirection.of(moved.start, moved.now),
    },
  );
}

/// Everything Today shows, computed from the state rather than drawn from the
/// design's sample numbers (streak 12, 8 new cards, and so on).
///
/// The count and the skill tiles come from `buildSession(DrillRequest.today())`,
/// the same queue Start review drills. That queue holds one item per card
/// (`SessionQueue.build`), so the number on the card is the number of words
/// the session asks, whatever number of skills a word is due in.
class TodayNumbers {
  const TodayNumbers({
    required this.hasDecks,
    required this.due,
    required this.bySkill,
    required this.noVoice,
    required this.streak,
    required this.newWords,
    required this.week,
    this.languages = const <LanguageInfo>[],
    this.lessons = const <TodayLesson>[],
    this.dueIn = const <Skill, int>{},
    this.revisable = const <Skill, int>{},
    this.pace,
  });

  /// [onScreen]: whether Today is on view, so that the pace may be worked
  /// out ([todayPaceOf]).
  factory TodayNumbers.of(AppState state, {bool onScreen = true}) {
    final now = state.now();
    final progress = state.progress;
    final decks = state.profileDecks;
    final queue = state.buildSession(const DrillRequest.today());
    final byMode = queue.countByMode();

    // "No voice" only once every language has been asked about and none can
    // be spoken, so the tile does not flash it while the check runs.
    final languages = {for (final d in decks) d.language.code: d.language};
    final noVoice =
        decks.isNotEmpty &&
        state.settings.isEnabled(Skill.listening) &&
        languages.values.every(
          (l) => state.voiceStatus(l) == VoiceStatus.missing,
        );

    final today = dateOnly(now);
    // Words taught today: first drilled today, in any skill.
    final earlier = <String>{
      for (final e in progress.log)
        if (e.at.isBefore(today)) e.cardId,
    };
    final newWords = <String>{
      for (final e in progress.log)
        if (isSameDay(e.at, now) && !earlier.contains(e.cardId)) e.cardId,
    }.length;

    // Each language's next lesson, in the order the learner chose them.
    final chosen = state.settings.learningLanguages;
    final lessons = <TodayLesson>[
      for (final code in <String>[
        ...chosen.where(languages.containsKey),
        ...languages.keys.where((code) => !chosen.contains(code)),
      ])
        if (state.lessonFor(DrillRequest.lesson(language: code))
            case final items when items.isNotEmpty)
          (
            language: languages[code]!,
            words: items.where((i) => i.ask == Ask.teach).length,
            reading: items.first.card is QuestionCard,
            done: state.lessonDoneToday(code),
          ),
    ];
    WeekDay dayOf(int back) {
      final date = addDays(today, -back);
      final status = progress.practisedOn(date)
          ? WeekDayStatus.done
          : back == 0
          ? WeekDayStatus.today
          : WeekDayStatus.other;
      return (date: date, status: status);
    }

    final bySkill = <Skill, int>{
      for (final skill in todaySkills)
        if (skill != Skill.speaking ||
            (state.settings.isEnabled(skill) &&
                state.features.isAvailable(skill.feature)))
          skill: skill.mode == null ? 0 : byMode[skill.mode] ?? 0,
    };
    // A skill switched off is not reviewed from its tile either.
    final dueIn = <Skill, int>{
      for (final skill in bySkill.keys)
        skill: state.settings.isEnabled(skill)
            ? state.buildSession(DrillRequest(skill: skill)).length
            : 0,
    };
    return TodayNumbers(
      hasDecks: decks.isNotEmpty,
      due: queue.length,
      bySkill: bySkill,
      dueIn: dueIn,
      // A skill switched off has nothing to revise from its tile.
      revisable: <Skill, int>{
        for (final MapEntry(key: skill, value: due) in dueIn.entries)
          if (due == 0 && state.settings.isEnabled(skill))
            skill: state.revisableIn(<Skill>{skill}),
      },
      noVoice: noVoice,
      streak: progress.streakAt(now),
      newWords: newWords,
      week: <WeekDay>[for (var back = 6; back >= 0; back--) dayOf(back)],
      languages: state.todayLanguages,
      lessons: lessons,
      pace: todayPaceOf(state, onScreen: onScreen),
    );
  }

  /// Whether the profile learns any language that has a deck.
  final bool hasDecks;

  /// Words in today's session: due reviews, and the new skills of words
  /// already taught, each word once, in the one skill it is asked in. New
  /// words come in [lessons] (ADR-0024). A reading passage's questions are
  /// cards of their own (ADR-0019) and count one each.
  final int due;

  /// Today's session per skill, for each skill with a tile, in
  /// [todaySkills] order.
  final Map<Skill, int> bySkill;

  /// For each tile, how many cards a review of its skill alone holds, what
  /// tapping it starts (ADR-0030). It can be more than [bySkill]'s count: a
  /// word due in several skills is asked in one of them in today's session,
  /// but in each skill's own review.
  final Map<Skill, int> dueIn;

  /// For a tile whose skill has nothing due: how many words it can revise
  /// (ADR-0030). A skill not listed has none.
  final Map<Skill, int> revisable;

  /// Listening is on, but no language the profile learns has a voice on
  /// this phone.
  final bool noVoice;

  /// Days in a row with a review, ending today or yesterday.
  final int streak;

  /// Words taught today, in lessons.
  final int newWords;

  /// Each language's next lesson, in the order the learner chose them; a
  /// language with nothing left to teach has none.
  final List<TodayLesson> lessons;

  /// The last seven days, oldest first, ending today.
  final List<WeekDay> week;

  /// The languages with something to do today, in the order they are
  /// drilled: one session each, with a break between.
  final List<LanguageInfo> languages;

  /// What Start review runs: the first language's session when there is more
  /// than one, so that languages come one at a time.
  DrillRequest get start => languages.length > 1
      ? DrillRequest.today(language: languages.first.code)
      : const DrillRequest.today();

  /// The learner's pace, once some skill is adjusted; null before.
  final TodayPace? pace;

  /// Nothing to drill now.
  bool get allDone => due == 0;

  /// The estimated length of today's session in whole minutes, at least 1
  /// for any session.
  int get minutes =>
      due == 0 ? 0 : math.max(1, (due * secondsPerCard / 60).round());
}
