import '../models/review_event.dart';
import '../scheduling/fsrs.dart';
import 'mastery.dart';

/// How well the pairs carrying one tag are known now (#678, owner,
/// 2026-10-23: Weakest tags use FSRS today, not the all-time share of right
/// answers).
class TagStrength {
  const TagStrength({
    required this.tag,
    required this.known,
    required this.taught,
    required this.recall,
  });

  final String tag;

  /// Taught pairs with the tag that are known now ([leavesKnown], the
  /// star's rule).
  final int known;

  /// Pairs with the tag answered at least once. Never zero.
  final int taught;

  /// The mean chance, 0 to 1, that FSRS gives of recalling those pairs now.
  final double recall;

  /// The share of the taught pairs that are not known now, 0 to 1: higher
  /// is weaker.
  double get weakness => (taught - known) / taught;

  /// The share known, 0 to 1.
  double get knownShare => known / taught;
}

/// The strength of every tag of the pairs in [reviews] (oldest first), at
/// [now], weakest first: the larger share of taught pairs not known, then
/// the lower mean recall now, then the tag's name. A tag with nothing taught
/// is not listed.
///
/// A pair is a card in one mode (script skills apart), taught once it has a
/// review and known by its last review as the star counts it. [tagsOf] says
/// which tags a review's card has; [parametersOf] gives the parameters that
/// schedule a review's pair (the default ones when null).
List<TagStrength> tagStrengths(
  Iterable<ReviewEvent> reviews, {
  required Iterable<String> Function(ReviewEvent review) tagsOf,
  required DateTime now,
  List<double> Function(ReviewEvent review)? parametersOf,
}) {
  final last = <String, ReviewEvent>{};
  for (final e in reviews.answered) {
    if (e.mode.isScript || masterySkillOf(e.mode) == null) continue;
    last['${e.mode.name}|${e.cardId}'] = e;
  }
  final known = <String, int>{};
  final taught = <String, int>{};
  final recall = <String, double>{};
  for (final e in last.values) {
    final parameters = parametersOf?.call(e) ?? Fsrs.w;
    final isKnown = leavesKnown(e, parameters: parameters);
    final chance = Fsrs.retrievability(e.after, now, parameters: parameters);
    for (final tag in tagsOf(e).toSet()) {
      taught[tag] = (taught[tag] ?? 0) + 1;
      if (isKnown) known[tag] = (known[tag] ?? 0) + 1;
      recall[tag] = (recall[tag] ?? 0) + chance;
    }
  }
  final strengths = <TagStrength>[
    for (final entry in taught.entries)
      TagStrength(
        tag: entry.key,
        known: known[entry.key] ?? 0,
        taught: entry.value,
        recall: recall[entry.key]! / entry.value,
      ),
  ];
  strengths.sort((a, b) {
    // Compared as products, so that equal shares tie exactly.
    final byShare =
        (b.taught - b.known) * a.taught - (a.taught - a.known) * b.taught;
    if (byShare != 0) return byShare;
    final byRecall = a.recall.compareTo(b.recall);
    return byRecall != 0 ? byRecall : a.tag.compareTo(b.tag);
  });
  return strengths;
}
