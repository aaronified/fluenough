/// What a finished session announces (#323, decision 4 of the achievements
/// mockup): the badges earned since the learner last looked, at most two
/// cards and "and N more", and, the first time, the badges already earned by
/// past reviews, once and quietly. Pure Dart, no Flutter.
library;

import 'achievement.dart';

/// How many badges a summary shows in full before "and N more".
const int kAnnouncedCards = 2;

/// The badges a session summary shows.
class AchievementNews {
  const AchievementNews._({
    required this.fresh,
    required this.past,
    required this.courseIds,
    required this.appIds,
  });

  /// The badges of [report] not yet shown, split in two: [fresh] are earned
  /// at or after [since] (this session's), and [past] are the ones the
  /// reviews of before already earned, which only exist while a scope was
  /// never looked at ([seenCourse] or [seenApp] null, decision 4): they are
  /// celebrated once, quietly.
  ///
  /// A scope seen before announces every badge earned and not seen, whatever
  /// its date: a badge an older session earned but never showed (the app was
  /// closed) is not lost.
  factory AchievementNews.of(
    AchievementReport report, {
    required Set<String>? seenCourse,
    required Set<String>? seenApp,
    required DateTime since,
  }) {
    final fresh = <AchievementResult>[];
    final past = <AchievementResult>[];
    final courseIds = <String>{};
    final appIds = <String>{};
    for (final result in report.earned) {
      final seen = result.def.isAppWide ? seenApp : seenCourse;
      (result.def.isAppWide ? appIds : courseIds).add(result.def.id);
      if (seen != null && seen.contains(result.def.id)) continue;
      final firstLook = seen == null;
      if (firstLook && result.earnedAt!.isBefore(since)) {
        past.add(result);
      } else {
        fresh.add(result);
      }
    }
    return AchievementNews._(
      fresh: fresh,
      past: past,
      courseIds: courseIds,
      appIds: appIds,
    );
  }

  /// Earned this session or not yet shown, earliest first.
  final List<AchievementResult> fresh;

  /// Earned by past reviews, found at the first look, earliest first.
  final List<AchievementResult> past;

  /// Every earned badge of the course and of the app, seen or not: once the
  /// summary has shown the news, all of them are marked seen.
  final Set<String> courseIds;
  final Set<String> appIds;

  /// The fresh badges shown in full.
  List<AchievementResult> get shown => fresh.take(kAnnouncedCards).toList();

  /// How many fresh badges "and N more" stands for.
  int get more =>
      fresh.length > kAnnouncedCards ? fresh.length - kAnnouncedCards : 0;

  /// Whether there is anything to show.
  bool get isEmpty => fresh.isEmpty && past.isEmpty;
}
