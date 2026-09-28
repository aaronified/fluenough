import '../../app/app_state.dart';
import '../../app/memory_progress.dart';
import '../../app/skill.dart';
import '../../core/models/card.dart';

/// Finds the card a review was given on, or null if it has left its deck.
/// Retired cards are deleted (AGENTS.md rule 1), so history can outlive them.
typedef CardLookup = Card? Function(String deckId, String cardId);

/// A [CardLookup] over [state]'s catalog, indexed once.
CardLookup cardLookupOf(AppState state) {
  final cards = <String, Card>{
    for (final entry in state.decks)
      for (final card in entry.cards) '${entry.id}/${card.id}': card,
  };
  return (deckId, cardId) => cards['$deckId/$cardId'];
}

/// The time ranges Progress offers.
enum StatsRange {
  week(7),
  month(30),
  all(null);

  const StatsRange(this.days);

  /// Calendar days covered, ending today; null for every review.
  final int? days;
}

/// Correct answers out of those given, for one skill or one tag.
class Tally {
  const Tally(this.correct, this.total);

  final int correct;
  final int total;

  /// The share remembered, 0–1. [total] is never zero for a shown tally.
  double get ratio => total == 0 ? 0 : correct / total;
}

/// How many days the activity grid shows: twelve weeks.
const int kHeatmapWeeks = 12;
const int kHeatmapDays = kHeatmapWeeks * 7;

/// The number of colour steps in the grid, the empty one included.
const int kHeatmapLevels = 5;

/// Everything Progress shows, computed from the review log and the current
/// scheduling states. Nothing is stored; every number is rebuilt from
/// [ProgressStore.log], so nothing here can drift from it.
class StatsNumbers {
  StatsNumbers._({
    required this.reviews,
    required this.remembered,
    required this.streak,
    required this.longestStreak,
    required this.learned,
    required this.bySkill,
    required this.weakestTags,
    required this.heatmap,
  });

  /// The numbers for [range], ending on [now]'s calendar day.
  factory StatsNumbers.of(
    ProgressStore progress, {
    required DateTime now,
    required StatsRange range,
    required CardLookup cardOf,
    int tagCount = 3,
  }) {
    final log = progress.log;
    final today = dateOnly(now);
    final from = range.days == null ? null : addDays(today, 1 - range.days!);
    bool inRange(DateTime at) => from == null || !at.isBefore(from);

    final inside = <ReviewEvent>[
      for (final e in log)
        if (inRange(e.at)) e,
    ];

    final skills = <Skill, List<int>>{};
    final tags = <String, List<int>>{};
    var passed = 0;
    for (final e in inside) {
      final ok = e.passed ? 1 : 0;
      passed += ok;
      final s = skills.putIfAbsent(Skill.of(e.mode), () => <int>[0, 0]);
      s[0] += ok;
      s[1]++;
      for (final tag in cardOf(e.deckId, e.cardId)?.tags ?? const <String>[]) {
        final t = tags.putIfAbsent(tag, () => <int>[0, 0]);
        t[0] += ok;
        t[1]++;
      }
    }

    // A card is learned on its first remembered review, in any mode.
    final firstPass = <String, DateTime>{};
    for (final e in log.where((e) => e.passed)) {
      firstPass.putIfAbsent('${e.deckId}/${e.cardId}', () => e.at);
    }

    final weakest = tags.entries.toList()
      ..sort((a, b) {
        final byRatio = (a.value[0] / a.value[1]).compareTo(
          b.value[0] / b.value[1],
        );
        return byRatio != 0 ? byRatio : a.key.compareTo(b.key);
      });

    final firstDay = addDays(today, 1 - kHeatmapDays);
    final heatmap = List<int>.filled(kHeatmapDays, 0);
    for (final e in log) {
      final day = dateOnly(e.at);
      if (day.isBefore(firstDay) || day.isAfter(today)) continue;
      heatmap[_daysBetween(firstDay, day)]++;
    }

    return StatsNumbers._(
      reviews: inside.length,
      remembered: inside.isEmpty ? null : passed / inside.length,
      streak: progress.streakAt(now),
      longestStreak: _longestStreak(log),
      learned: firstPass.values.where(inRange).length,
      bySkill: <Skill, Tally>{
        for (final skill in Skill.values)
          if (skills[skill] case final t?) skill: Tally(t[0], t[1]),
      },
      weakestTags: <String, Tally>{
        for (final entry in weakest.take(tagCount))
          entry.key: Tally(entry.value[0], entry.value[1]),
      },
      heatmap: List<int>.unmodifiable(heatmap),
    );
  }

  /// Reviews given in the range.
  final int reviews;

  /// The share of [reviews] remembered (graded 3 or more), or null if there
  /// were none.
  final double? remembered;

  /// Consecutive days with a review, ending today or yesterday.
  final int streak;

  /// The longest run of consecutive days with a review, ever.
  final int longestStreak;

  /// Distinct cards first remembered in the range. For all time, every card
  /// ever remembered.
  final int learned;

  /// Correct answers per skill, for the skills practised in the range, in
  /// [Skill] order.
  final Map<Skill, Tally> bySkill;

  /// The tags with the lowest share remembered in the range, weakest first.
  /// Tags come from the cards' decks.
  final Map<String, Tally> weakestTags;

  /// Reviews per day for the last [kHeatmapDays] days, oldest first, ending
  /// today. Independent of the range.
  final List<int> heatmap;

  /// Days in [heatmap] with at least one review.
  int get activeDays => heatmap.where((n) => n > 0).length;

  /// Reviews in [heatmap].
  int get heatmapReviews => heatmap.fold(0, (sum, n) => sum + n);

  /// The colour step, 0 to [kHeatmapLevels] − 1, for a day with [count]
  /// reviews: 0 for none, then quarters of the busiest day.
  int levelOf(int count) {
    if (count <= 0) return 0;
    final busiest = heatmap.fold(0, (a, b) => a > b ? a : b);
    final steps = kHeatmapLevels - 1;
    return (count * steps / busiest).ceil().clamp(1, steps);
  }

  static int _longestStreak(List<ReviewEvent> log) {
    final days = <DateTime>{for (final e in log) dateOnly(e.at)}.toList()
      ..sort();
    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      run = previous != null && isSameDay(addDays(previous, 1), day)
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      previous = day;
    }
    return longest;
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}
