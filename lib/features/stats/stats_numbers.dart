import '../../app/app_state.dart';
import '../../app/memory_progress.dart';
import '../../app/skill.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';

/// Finds a card by its id, as [deckId] lists it if that deck still does,
/// or else as the first deck listing it does; null if no deck does. Retired
/// cards are deleted (AGENTS.md rule 1), so history can outlive them.
typedef CardLookup = Card? Function(String cardId, {String? deckId});

/// A [CardLookup] over [state]'s catalog, indexed once.
CardLookup cardLookupOf(AppState state) {
  final listed = <String, Card>{};
  final first = <String, Card>{};
  for (final entry in state.decks) {
    for (final card in entry.cards) {
      listed['${entry.id}/${card.id}'] = card;
      first.putIfAbsent(card.id, () => card);
    }
  }
  return (cardId, {deckId}) => listed['$deckId/$cardId'] ?? first[cardId];
}

/// Finds the language a deck teaches, by code, or null if it cannot tell.
typedef LanguageLookup = String? Function(String deckId);

/// A [LanguageLookup] over [state]'s catalog. A deck that has left it is
/// placed by its id, which names the language it teaches first
/// (`es-en-core-100`, #51), when the catalog has that language.
LanguageLookup languageLookupOf(AppState state) {
  final byDeck = <String, String>{
    for (final entry in state.decks) entry.id: entry.language.code,
  };
  final codes = <String>{for (final language in state.languages) language.code};
  return (deckId) {
    if (byDeck[deckId] case final code?) return code;
    final named = deckId.split('-').first;
    return codes.contains(named) ? named : null;
  };
}

/// The languages [progress]'s log has reviews in, most recently reviewed
/// first by the reviews' own times, since an imported backup can add older
/// reviews after newer ones. Languages last reviewed at the same moment keep
/// [languages]' order. Reviews whose language cannot be told count under
/// none of them, only under every language together.
List<LanguageInfo> practisedLanguages(
  ProgressStore progress, {
  required List<LanguageInfo> languages,
  required LanguageLookup languageOf,
}) {
  final latest = <String, DateTime>{};
  for (final e in progress.log) {
    final code = languageOf(e.deckId);
    if (code == null) continue;
    final at = latest[code];
    if (at == null || e.at.isAfter(at)) latest[code] = e.at;
  }
  final practised = <LanguageInfo>[
    for (final language in languages)
      if (latest.containsKey(language.code)) language,
  ];
  // List.sort is not stable, so ties fall back to the catalog's order.
  final rank = <String, int>{
    for (final (i, language) in practised.indexed) language.code: i,
  };
  return practised..sort((a, b) {
    final byTime = latest[b.code]!.compareTo(latest[a.code]!);
    return byTime != 0 ? byTime : rank[a.code]!.compareTo(rank[b.code]!);
  });
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

  /// The numbers for [range], ending on [now]'s calendar day: of every
  /// review, or of those on decks [deckFilter] keeps.
  factory StatsNumbers.of(
    ProgressStore progress, {
    required DateTime now,
    required StatsRange range,
    required CardLookup cardOf,
    bool Function(String deckId)? deckFilter,
    int tagCount = 3,
  }) {
    final log = deckFilter == null
        ? progress.log
        : <ReviewEvent>[
            for (final e in progress.log)
              if (deckFilter(e.deckId)) e,
          ];
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
      for (final tag
          in cardOf(e.cardId, deckId: e.deckId)?.tags ?? const <String>[]) {
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
      streak: streakIn(log, now),
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

  /// Consecutive days with a review, ending today or yesterday. Of the
  /// filtered reviews only, so one language's streak is its own.
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
