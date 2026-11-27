import '../../core/achievements/achievement.dart';

/// How a badge is drawn (the approved mockup): earned and filled with its
/// date, in progress with a ring and a count, locked and dashed, or dimmed
/// for a skill the learner marked Leave (decision 11).
enum BadgeShown { earned, progress, locked, left }

/// One badge and how it is shown.
class BadgeView {
  const BadgeView(this.result, this.shown);

  final AchievementResult result;
  final BadgeShown shown;

  AchievementDef get def => result.def;

  /// The ring's share, 0 to 1, for a badge in progress.
  double get fraction => result.fraction;
}

/// The badges of one chain, in order (the levels, the word counts, a skill's
/// Start and Master, the days in a row), shown as the mockup has it: only
/// the next badge of a chain shows progress, and the rest of the chain is
/// locked until it is earned. An earned badge is always earned, whatever
/// comes before it.
List<BadgeView> chainViews(Iterable<AchievementResult> chain) {
  final views = <BadgeView>[];
  var nextFound = false;
  for (final result in chain) {
    if (!result.earnable) {
      views.add(BadgeView(result, BadgeShown.left));
    } else if (result.isEarned) {
      views.add(BadgeView(result, BadgeShown.earned));
    } else if (!nextFound) {
      nextFound = true;
      views.add(
        BadgeView(
          result,
          result.have > 0 ? BadgeShown.progress : BadgeShown.locked,
        ),
      );
    } else {
      views.add(BadgeView(result, BadgeShown.locked));
    }
  }
  return views;
}
