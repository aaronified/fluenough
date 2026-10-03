import 'dart:math' as math;

import '../../app/app_state.dart';
import '../../app/memory_progress.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';

/// How long the design allows for one card when it estimates a session:
/// "about 4 min" for 12 cards.
const int secondsPerCard = 20;

/// The skills Today draws a tile for, in the design's order. Minimal pairs
/// have no tile: they are drilled from their own decks (#31).
const List<Skill> todaySkills = <Skill>[
  Skill.recognition,
  Skill.production,
  Skill.listening,
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

/// Everything Today shows, computed from the state rather than drawn from the
/// design's sample numbers (streak 12, 8 new cards, and so on).
///
/// The count and the skill tiles come from `buildSession(DrillRequest.today())`,
/// the same queue Start review drills, so the number on the card is the
/// number of cards the session holds.
class TodayNumbers {
  const TodayNumbers({
    required this.hasDecks,
    required this.due,
    required this.bySkill,
    required this.noVoice,
    required this.streak,
    required this.newDone,
    required this.newLimit,
    required this.week,
    this.languages = const <LanguageInfo>[],
  });

  factory TodayNumbers.of(AppState state) {
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
    WeekDay dayOf(int back) {
      final date = addDays(today, -back);
      final status = progress.practisedOn(date)
          ? WeekDayStatus.done
          : back == 0
          ? WeekDayStatus.today
          : WeekDayStatus.other;
      return (date: date, status: status);
    }

    return TodayNumbers(
      hasDecks: decks.isNotEmpty,
      due: queue.length,
      bySkill: <Skill, int>{
        for (final skill in todaySkills)
          skill: skill.mode == null ? 0 : byMode[skill.mode] ?? 0,
      },
      noVoice: noVoice,
      streak: progress.streakAt(now),
      newDone: progress.newIntroducedOn(now),
      newLimit: state.settings.newCardsPerDay,
      week: <WeekDay>[for (var back = 6; back >= 0; back--) dayOf(back)],
      languages: state.todayLanguages,
    );
  }

  /// Whether the profile learns any language that has a deck.
  final bool hasDecks;

  /// Cards in today's session: due reviews and new cards within the cap.
  final int due;

  /// Today's session per skill, for every skill in [todaySkills].
  final Map<Skill, int> bySkill;

  /// Listening is on, but no language the profile learns has a voice on
  /// this phone.
  final bool noVoice;

  /// Days in a row with a review, ending today or yesterday.
  final int streak;

  /// New pairs introduced today, which the daily cap counts.
  final int newDone;

  /// The daily cap on new pairs, from Settings.
  final int newLimit;

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

  /// Nothing to drill now.
  bool get allDone => due == 0;

  /// The estimated length of today's session in whole minutes, at least 1
  /// for any session.
  int get minutes =>
      due == 0 ? 0 : math.max(1, (due * secondsPerCard / 60).round());
}
